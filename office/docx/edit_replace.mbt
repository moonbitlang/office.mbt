///|
/// Literal find & replace over the text of an EXISTING DOCX, through the
/// same preservation-safe D1 edit session the template merge uses: byte-
/// span rewrites of individual `<w:t>` runs on the immutable source
/// snapshot, never a document rewrite. Matches may span run boundaries
/// (Word splits text freely) and the replacement inherits the formatting
/// of the run the match STARTED in, exactly like a `{{key}}` merge.
///
/// The needle is LITERAL — no regular expressions, no wildcards, no
/// escaping — matching what `office query --text` accepts.
///
/// Strict by default: a match that cannot be rewritten safely, two ops
/// whose matches overlap, and an op that finds fewer occurrences than it
/// requires all refuse publication with a bounded report. Nothing is
/// ever guessed and nothing is published on any refusal.

///|
/// The versioned input script schema consumed by `office edit`.
pub const SCHEMA_DOCX_EDIT : String = "docx.edit/1"

///|
/// The versioned result schema emitted by `office edit`.
pub const SCHEMA_DOCX_EDIT_RESULT : String = "office.docx.edit/1"

///|
/// Largest number of edit operations in one script. The scan cost is
/// ops x document length, so this bounds the work together with the
/// scan budget below.
pub const MAX_EDIT_OPS : Int = 64

///|
/// Largest `find` needle, in UTF-16 code units.
pub const MAX_EDIT_FIND_UNITS : Int = 4096

///|
/// Largest `replace` text, in UTF-16 code units.
pub const MAX_EDIT_REPLACE_UNITS : Int = 65536

///|
/// Largest accepted `occurrence` ordinal.
pub const MAX_EDIT_OCCURRENCE : Int = 1_000_000

///|
/// Total code units of scanning work one edit transaction may charge.
pub const MAX_EDIT_SCAN_UNITS : Int = 64 * 1024 * 1024

///|
let docx_edit_finding_limit : Int = 64

///|
/// The parser-owned operation vocabulary, in stable order.
let docx_edit_operation_names : Array[String] = ["replace_text"]

///|
/// Returns the edit operation vocabulary accepted by this build.
pub fn docx_edit_operation_names_list() -> Array[String] {
  docx_edit_operation_names.copy()
}

///|
/// Errors raised while parsing a `docx.edit/1` script.
pub suberror DocxEditParseError {
  DocxEditParseError(String)
} derive(@debug.Debug)

///|
/// One parsed literal replacement operation.
priv struct DocxReplaceOp {
  find : String
  replace : String
  // None replaces EVERY occurrence in document order; Some(n) replaces
  // only the nth (1-based) and leaves the rest untouched
  occurrence : Int?
}

///|
/// A parsed, validated `docx.edit/1` script.
pub struct DocxEditScript {
  priv ops : Array[DocxReplaceOp]
}

///|
/// Number of operations in the script.
pub fn DocxEditScript::length(self : DocxEditScript) -> Int {
  self.ops.length()
}

///|
/// One operation's outcome.
pub(all) struct DocxEditOpResult {
  op : String
  find : String
  replace : String
  occurrence : Int?
  // occurrences seen in editable stories, whether or not they were
  // selected by `occurrence`
  mut matched : Int
  // spans actually rewritten
  mut replacements : Int
} derive(Eq, @debug.Debug)

///|
/// The complete literal-edit outcome.
pub(all) struct DocxEditReport {
  mut ops_applied : Int
  mut replacements : Int
  results : Array[DocxEditOpResult]
  unmatched : Array[DocxTemplateFinding]
  mut unmatched_total : Int
  unsupported : Array[DocxTemplateFinding]
  mut unsupported_total : Int
  conflicts : Array[DocxTemplateFinding]
  mut conflicts_total : Int
  locations : Array[DocxTemplateFinding]
  mut locations_truncated : Bool
  stories_scanned : Array[String]
  mut changed : Bool
} derive(Eq, @debug.Debug)

///|
/// Raised when strict findings refuse publication.
pub suberror DocxEditRefused {
  DocxEditRefused(DocxEditReport)
} derive(@debug.Debug)

///|
/// Result of one strict literal-edit transaction.
pub struct DocxEditResult {
  report : DocxEditReport
  transaction : @transaction.TransactionReport
}

///|
fn docx_edit_parse_error(message : String) -> DocxEditParseError {
  DocxEditParseError(message)
}

///|
/// Rejects any object member outside the allowed set — a misspelled
/// field must fail loudly, never be silently ignored.
fn docx_edit_reject_unknown(
  fields : Map[String, Json],
  allowed : Array[String],
  context : String,
) -> Unit raise DocxEditParseError {
  for key, _ in fields {
    if !allowed.contains(key) {
      raise docx_edit_parse_error(
        context + " has unknown member \"" + key + "\"",
      )
    }
  }
}

///|
/// Whether a needle or replacement can survive the run serializer:
/// C0 controls (tab included — Word spells a tab as `<w:tab/>`, which is
/// a separator the scanner can never match through), raw CR and LF
/// (paragraphs are the hard-break unit), unpaired surrogates, and the
/// XML non-characters are all rejected at parse time.
fn docx_edit_text_ok(text : String) -> Bool {
  for unit in text {
    let code = unit.to_int()
    if code < 0x20 || code == 0x7F {
      return false
    }
    // iteration combines surrogate pairs, so a surrogate seen here is
    // unpaired
    if (code >= 0xD800 && code <= 0xDFFF) || code == 0xFFFE || code == 0xFFFF {
      return false
    }
  }
  true
}

///|
fn docx_edit_text_field(
  params : Map[String, Json],
  key : String,
  limit : Int,
  required_nonempty~ : Bool,
) -> String raise DocxEditParseError {
  guard params.get(key) is Some(String(value)) else {
    raise docx_edit_parse_error(
      "replace_text params needs a string \"" + key + "\"",
    )
  }
  if required_nonempty && value.length() == 0 {
    raise docx_edit_parse_error(
      "replace_text \"" + key + "\" must not be empty",
    )
  }
  if value.length() > limit {
    raise docx_edit_parse_error(
      "replace_text \"\{key}\" is \{value.length()} units; the limit is \{limit}",
    )
  }
  if !docx_edit_text_ok(value) {
    raise docx_edit_parse_error(
      "replace_text \"" +
      key +
      "\" carries characters the run serializer cannot match or emit (control characters, line breaks, unpaired surrogates, or XML non-characters)",
    )
  }
  value
}

///|
/// Parses and validates a `docx.edit/1` document.
pub fn parse_docx_edit_script(
  text : String,
) -> DocxEditScript raise DocxEditParseError {
  let document = @json.parse(text) catch {
    _ => raise docx_edit_parse_error("edit script is not valid JSON")
  }
  guard document is Object(fields) else {
    raise docx_edit_parse_error("edit script must be a JSON object")
  }
  docx_edit_reject_unknown(fields, ["schema", "ops"], "the edit script")
  guard fields.get("schema") is Some(String(schema)) else {
    raise docx_edit_parse_error(
      "edit script needs \"schema\": \"" + SCHEMA_DOCX_EDIT + "\"",
    )
  }
  guard schema == SCHEMA_DOCX_EDIT else {
    raise docx_edit_parse_error("unsupported edit schema \"" + schema + "\"")
  }
  guard fields.get("ops") is Some(Array(items)) else {
    raise docx_edit_parse_error("edit script needs an \"ops\" array")
  }
  if items.length() == 0 {
    raise docx_edit_parse_error("edit script needs at least one operation")
  }
  if items.length() > MAX_EDIT_OPS {
    raise docx_edit_parse_error(
      "ops carries \{items.length()} entries; the limit is \{MAX_EDIT_OPS}",
    )
  }
  let ops : Array[DocxReplaceOp] = []
  for index, item in items {
    guard item is Object(entry) else {
      raise docx_edit_parse_error("ops[\{index}] must be an object")
    }
    docx_edit_reject_unknown(entry, ["op", "params"], "ops[\{index}]")
    guard entry.get("op") is Some(String(kind)) && kind.length() > 0 else {
      raise docx_edit_parse_error(
        "ops[\{index}] needs a non-empty string \"op\"",
      )
    }
    if !docx_edit_operation_names.contains(kind) {
      raise docx_edit_parse_error("unknown op \"" + kind + "\"")
    }
    guard entry.get("params") is Some(Object(params)) else {
      raise docx_edit_parse_error("ops[\{index}] needs a \"params\" object")
    }
    docx_edit_reject_unknown(
      params,
      ["find", "replace", "occurrence"],
      "ops[\{index}].params",
    )
    let find = docx_edit_text_field(
      params,
      "find",
      MAX_EDIT_FIND_UNITS,
      required_nonempty=true,
    )
    let replace = docx_edit_text_field(
      params,
      "replace",
      MAX_EDIT_REPLACE_UNITS,
      required_nonempty=false,
    )
    let occurrence = match params.get("occurrence") {
      None => None
      Some(Number(value, ..)) => {
        let ordinal = value.to_int()
        if value != value || ordinal.to_double() != value {
          raise docx_edit_parse_error(
            "ops[\{index}].params.occurrence must be a plain integer",
          )
        }
        if ordinal < 1 || ordinal > MAX_EDIT_OCCURRENCE {
          raise docx_edit_parse_error(
            "ops[\{index}].params.occurrence must be between 1 and \{MAX_EDIT_OCCURRENCE}",
          )
        }
        Some(ordinal)
      }
      _ =>
        raise docx_edit_parse_error(
          "ops[\{index}].params.occurrence must be a number when present",
        )
    }
    ops.push({ find, replace, occurrence })
  }
  { ops, }
}

///|
/// Shared mutable state for one edit pass.
priv struct DocxEditState {
  report : DocxEditReport
  ops : Array[DocxReplaceOp]
  budget : Ref[Int]
  edits : Array[DocxRunEdit]
  checks : Array[DocxRunEdit]
}

///|
fn DocxEditState::note_unsupported(
  self : DocxEditState,
  location : String,
  detail : String,
) -> Unit {
  self.report.unsupported_total += 1
  if self.report.unsupported.length() < docx_edit_finding_limit {
    self.report.unsupported.push({ location, detail })
  }
}

///|
fn DocxEditState::note_conflict(
  self : DocxEditState,
  location : String,
  detail : String,
) -> Unit {
  self.report.conflicts_total += 1
  if self.report.conflicts.length() < docx_edit_finding_limit {
    self.report.conflicts.push({ location, detail })
  }
}

///|
/// True when the accumulated findings refuse publication.
fn DocxEditReport::blocked(
  self : DocxEditReport,
  allow_unmatched : Bool,
) -> Bool {
  self.unsupported_total > 0 ||
  self.conflicts_total > 0 ||
  (self.unmatched_total > 0 && !allow_unmatched)
}

///|
/// Scans one paragraph's piece stream for every op's needle. Matches are
/// collected against the ORIGINAL text of one immutable snapshot — ops
/// never see each other's output — so two ops whose matches overlap are
/// ambiguous and refuse instead of racing.
fn DocxEditState::scan_paragraph(
  self : DocxEditState,
  story : String,
  part : String,
  paragraph_path : String,
  children : Array[@document.DocumentElement],
) -> Unit raise {
  let location = "/docx" + story + "/" + paragraph_path
  let pieces = docx_paragraph_pieces(paragraph_path, children)
  guard pieces.length() > 0 else { return }
  let texts = pieces.map(piece => piece.text)
  // (linear start, linear end, op index, span) for every span this
  // paragraph accepts, in op order
  let accepted : Array[(Int, Int, Int, @template.TemplateSpan)] = []
  for op_index, op in self.ops {
    let result = self.report.results[op_index]
    for span in @template.scan_literal(texts, op.find, self.budget) {
      result.matched += 1
      let selected = match op.occurrence {
        None => true
        Some(target) => target == result.matched
      }
      if !selected {
        continue
      }
      match docx_span_safety(pieces, span) {
        SpanUnrewritable => {
          self.note_unsupported(
            location, "a match overlaps content the edit cannot rewrite",
          )
          continue
        }
        SpanCrossesParent => {
          self.note_unsupported(
            location, "a match crosses a hyperlink boundary",
          )
          continue
        }
        SpanSafe => ()
      }
      accepted.push(
        (
          docx_piece_position(pieces, span.start_segment, span.start_offset),
          docx_piece_position(pieces, span.end_segment, span.end_offset),
          op_index,
          span,
        ),
      )
    }
  }
  guard accepted.length() > 0 else { return }
  // ambiguity gate: two accepted spans covering the same text have no
  // defined outcome, so the whole transaction refuses rather than
  // letting op order decide silently
  let ordered = accepted.copy()
  ordered.sort_by((left, right) => left.0 - right.0)
  let mut conflicting = false
  for index in 1..<ordered.length() {
    if ordered[index].0 < ordered[index - 1].1 {
      conflicting = true
      let earlier = self.ops[ordered[index - 1].2].find
      let later = self.ops[ordered[index].2].find
      self.note_conflict(
        location,
        "matches for \"" + earlier + "\" and \"" + later + "\" overlap",
      )
    }
  }
  if conflicting {
    return
  }
  let rewrites : Array[DocxSpanRewrite] = []
  for entry in accepted {
    let (_, _, op_index, span) = entry
    docx_collect_span_checks(
      pieces,
      span,
      story~,
      part~,
      location~,
      self.checks,
    )
    rewrites.push({ span, replacement: self.ops[op_index].replace })
    self.report.results[op_index].replacements += 1
    self.report.replacements += 1
    if self.report.locations.length() < docx_edit_finding_limit {
      self.report.locations.push({ location, detail: self.ops[op_index].find })
    } else {
      self.report.locations_truncated = true
    }
  }
  docx_plan_span_rewrites(
    pieces,
    rewrites,
    story~,
    part~,
    location~,
    self.edits,
  )
}

///|
/// Flags needles present in stories the v1 edit does not rewrite. A
/// silently skipped match would be a fidelity lie, so it refuses.
fn DocxEditState::flag_out_of_scope(
  self : DocxEditState,
  what : String,
  bodies : Array[(String, Array[@document.DocumentElement])],
) -> Unit {
  for entry in bodies {
    let (id, body) = entry
    let joined = docx_story_joined_text(body)
    for op in self.ops {
      if joined.contains(op.find) {
        self.note_unsupported(
          "/docx/\{what}[\{id}]",
          "matches in \{what} stories are not editable in v1",
        )
        break
      }
    }
  }
}

///|
/// Applies a literal edit script to a DOCX package through the D1 edit
/// session. Strict findings refuse publication with the full report; the
/// input is never modified (a distinct output is enforced by the
/// transaction layer).
pub async fn transact_docx_edit(
  options : @transaction.TransactionOptions,
  script : DocxEditScript,
  allow_unmatched~ : Bool,
) -> DocxEditResult {
  let collected : Ref[DocxEditReport?] = Ref(None)
  let report = transact_docx(options, session => {
    let results = script.ops.map(op => {
      (
        {
          op: "replace_text",
          find: op.find,
          replace: op.replace,
          occurrence: op.occurrence,
          matched: 0,
          replacements: 0,
        } : DocxEditOpResult)
    })
    let state : DocxEditState = {
      report: {
        ops_applied: script.ops.length(),
        replacements: 0,
        results,
        unmatched: [],
        unmatched_total: 0,
        unsupported: [],
        unsupported_total: 0,
        conflicts: [],
        conflicts_total: 0,
        locations: [],
        locations_truncated: false,
        stories_scanned: [],
        changed: false,
      },
      ops: script.ops,
      budget: Ref(MAX_EDIT_SCAN_UNITS),
      edits: [],
      checks: [],
    }
    let annotated = session.annotated()
    let result = annotated.result()
    guard result.document is Document(children~, ..) else {
      raise docx_failure(
        "office.docx.edit_internal", "the reader returned a non-document root",
      )
    }
    // stories in scope: body, then headers and footers in source order
    let stories : Array[(String, String, Array[@document.DocumentElement])] = [
      ("/body", annotated.main_story_source().part(), children),
    ]
    for index, source in annotated.header_story_sources() {
      if index < result.headers.length() {
        stories.push(
          ("/header[\{index + 1}]", source.part(), result.headers[index].body),
        )
      }
    }
    for index, source in annotated.footer_story_sources() {
      if index < result.footers.length() {
        stories.push(
          ("/footer[\{index + 1}]", source.part(), result.footers[index].body),
        )
      }
    }
    for entry in stories {
      let (story, part, story_children) = entry
      state.report.stories_scanned.push(story)
      let paragraphs : Array[(String, Array[@document.DocumentElement])] = []
      docx_collect_paragraphs(story_children, "", paragraphs)
      for paragraph in paragraphs {
        let (path, paragraph_children) = paragraph
        state.scan_paragraph(story, part, path, paragraph_children) catch {
          @template.TemplateScanBudgetExceeded(_) =>
            raise docx_failure(
              "office.docx.resource_limit", "edit scan work exceeds the configured ceiling",
            )
          error => raise error
        }
      }
    }
    state.flag_out_of_scope("footnotes", annotated.footnote_bodies())
    state.flag_out_of_scope("endnotes", annotated.endnote_bodies())
    state.flag_out_of_scope("comments", annotated.comment_bodies())
    for index, entry in state.report.results {
      let required = match entry.occurrence {
        Some(target) => target
        None => 1
      }
      if entry.matched < required {
        state.report.unmatched_total += 1
        if state.report.unmatched.length() < docx_edit_finding_limit {
          state.report.unmatched.push({
            location: "ops[\{index}]",
            detail: "\"" +
            entry.find +
            "\" occurs \{entry.matched} time(s); \{required} required",
          })
        }
      }
    }
    docx_fidelity_check_runs(state.checks, session, annotated, (
      location,
      detail,
    ) => state.note_unsupported(location, detail))
    docx_emit_run_edits(
      state.edits,
      session,
      annotated,
      () => state.report.blocked(allow_unmatched),
      () => state.report.changed = true,
    )
    collected.val = Some(state.report)
    if state.report.blocked(allow_unmatched) {
      raise docx_failure(
        "office.docx.edit_refused", "strict edit findings refuse publication",
      )
    }
  }) catch {
    error =>
      match collected.val {
        Some(edit) if edit.blocked(allow_unmatched) =>
          raise DocxEditRefused(edit)
        _ => raise error
      }
  }
  guard collected.val is Some(edit) else {
    raise docx_failure(
      "office.docx.edit_internal", "the edit produced no report",
    )
  }
  { report: edit, transaction: report }
}
