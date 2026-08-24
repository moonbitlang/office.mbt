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
/// The extended script schema: everything `docx.edit/1` accepts, plus
/// the addressed `set_run_text` operation (#462 A3). Programs stay
/// homogeneous -- one script replaces text, resolves revisions, or sets
/// run text, never a mixture.
pub const SCHEMA_DOCX_EDIT_V2 : String = "docx.edit/2"

///|
/// Largest `at` run path, in UTF-16 code units.
pub const MAX_EDIT_RUN_PATH_UNITS : Int = 4096

///|
/// The versioned result schema emitted by `office edit`.
pub const SCHEMA_DOCX_EDIT_RESULT : String = "office.docx.edit/1"

///|
/// The result schema for `docx.edit/2` scripts: the same envelope with
/// per-entry `at`/`expect`/`text` keys (null when inapplicable).
pub const SCHEMA_DOCX_EDIT_RESULT_V2 : String = "office.docx.edit/2"

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
/// Largest `id` or `author` a revision selector may carry, in UTF-16 code
/// units. Both are matched against attributes the source spelled, so a
/// selector longer than any legal attribute can only ever match nothing.
pub const MAX_REVISION_SELECTOR_UNITS : Int = 4096

///|
/// The parser-owned operation vocabulary, in stable order.
let docx_edit_operation_names : Array[String] = [
  "replace_text", "accept_revision", "reject_revision", "set_run_text",
]

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
/// One parsed revision-resolution operation. The selector fields are
/// CONJUNCTIVE: every field the script spells must match, so `{"author":
/// "Reviewer", "type": "del"}` selects Reviewer's deletions and nothing else.
/// `all` is the explicit "no filter" form and may not be combined.
priv struct DocxRevisionOp {
  // true accepts the selected revisions, false rejects them
  accept : Bool
  id : String?
  author : String?
  kind : String?
  all : Bool
}

///|
/// A script resolves revisions or replaces text, never both.
///
/// The two op families resolve their byte spans against the SAME immutable
/// source snapshot, so a replacement landing inside a revision that the same
/// script removes has no defined outcome. Refusing the combination at parse
/// time makes the intent explicit — the caller runs two transactions and sees
/// each result — and mirrors the session's existing rule that semantic and
/// generic plans may not be composed.
priv enum DocxEditProgram {
  ReplaceProgram(Array[DocxReplaceOp])
  RevisionProgram(Array[DocxRevisionOp])
  SetRunTextProgram(Array[DocxSetRunTextOp])
}

///|
/// One addressed whole-run replacement: the body-relative run path, the
/// run's expected reader-visible text, and the replacement.
priv struct DocxSetRunTextOp {
  at : String
  expect : String
  text : String
}

///|
/// A parsed, validated `docx.edit/1` or `docx.edit/2` script.
pub struct DocxEditScript {
  priv program : DocxEditProgram
  priv schema : String
}

///|
/// The schema the script declared (`docx.edit/1` or `docx.edit/2`), so
/// the surface can emit the matching versioned result schema.
pub fn DocxEditScript::schema(self : DocxEditScript) -> String {
  self.schema
}

///|
/// Number of operations in the script.
pub fn DocxEditScript::length(self : DocxEditScript) -> Int {
  match self.program {
    ReplaceProgram(ops) => ops.length()
    RevisionProgram(ops) => ops.length()
    SetRunTextProgram(ops) => ops.length()
  }
}

///|
/// One operation's outcome. `find`/`replace`/`occurrence` describe a
/// `replace_text` op; `selector_*` describe a revision op. Exactly one family
/// is meaningful per entry, and the serializer nulls out the other.
pub(all) struct DocxEditOpResult {
  op : String
  find : String
  replace : String
  occurrence : Int?
  // set_run_text only; all three absent for other ops. `find`/`replace`
  // stay empty for set_run_text -- the /1 fields are never overloaded.
  at : String?
  expect : String?
  text : String?
  // revision selector, as spelled; `selector_all` is the explicit no-filter
  // form. All absent/false for replace_text.
  selector_id : String?
  selector_author : String?
  selector_type : String?
  selector_all : Bool
  // replace_text: occurrences seen in editable stories, whether or not they
  // were selected by `occurrence`. Revision ops: revisions this selector
  // matched, whether or not they could be resolved.
  mut matched : Int
  // spans actually rewritten
  mut replacements : Int
  // revisions this op resolved. Two ops selecting the SAME revision with the
  // same action each count it, while the report total counts it once.
  mut resolved : Int
} derive(Eq, @debug.Debug)

///|
/// The complete literal-edit outcome.
pub(all) struct DocxEditReport {
  mut ops_applied : Int
  mut replacements : Int
  // distinct tracked-change elements resolved across every operation
  mut revisions_resolved : Int
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
  op? : String = "replace_text",
) -> String raise DocxEditParseError {
  guard params.get(key) is Some(String(value)) else {
    raise docx_edit_parse_error(op + " params needs a string \"" + key + "\"")
  }
  if required_nonempty && value.length() == 0 {
    raise docx_edit_parse_error(op + " \"" + key + "\" must not be empty")
  }
  if value.length() > limit {
    raise docx_edit_parse_error(
      "\{op} \"\{key}\" is \{value.length()} units; the limit is \{limit}",
    )
  }
  if !docx_edit_text_ok(value) {
    raise docx_edit_parse_error(
      op +
      " \"" +
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
  guard schema == SCHEMA_DOCX_EDIT || schema == SCHEMA_DOCX_EDIT_V2 else {
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
  let replacements : Array[DocxReplaceOp] = []
  let revisions : Array[DocxRevisionOp] = []
  let run_texts : Array[DocxSetRunTextOp] = []
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
    if kind == "set_run_text" {
      guard schema == SCHEMA_DOCX_EDIT_V2 else {
        raise docx_edit_parse_error(
          "op \"set_run_text\" needs \"schema\": \"" +
          SCHEMA_DOCX_EDIT_V2 +
          "\"",
        )
      }
      guard replacements.is_empty() && revisions.is_empty() else {
        raise docx_edit_parse_error(
          "ops[\{index}] mixes set_run_text with another operation family; a script stays homogeneous",
        )
      }
      docx_edit_reject_unknown(
        params,
        ["at", "expect", "text"],
        "ops[\{index}].params",
      )
      let at = parse_docx_run_address(
        docx_edit_text_field(
          params,
          "at",
          MAX_EDIT_RUN_PATH_UNITS,
          required_nonempty=true,
          op="set_run_text",
        ),
        index,
      )
      let expect = docx_edit_text_field(
        params,
        "expect",
        MAX_EDIT_REPLACE_UNITS,
        required_nonempty=false,
        op="set_run_text",
      )
      let text = docx_edit_text_field(
        params,
        "text",
        MAX_EDIT_REPLACE_UNITS,
        required_nonempty=false,
        op="set_run_text",
      )
      run_texts.push({ at, expect, text })
      continue
    }
    guard run_texts.is_empty() else {
      raise docx_edit_parse_error(
        "ops[\{index}] mixes \"" +
        kind +
        "\" with set_run_text; a script stays homogeneous",
      )
    }
    if kind is ("accept_revision" | "reject_revision") {
      guard replacements.is_empty() else {
        raise docx_edit_parse_error(
          "ops[\{index}] mixes \"" +
          kind +
          "\" with replace_text; a script resolves revisions or replaces text, never both",
        )
      }
      revisions.push(
        parse_docx_revision_op(params, kind == "accept_revision", index),
      )
      continue
    }
    guard revisions.is_empty() else {
      raise docx_edit_parse_error(
        "ops[\{index}] mixes replace_text with a revision op; a script resolves revisions or replaces text, never both",
      )
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
    replacements.push({ find, replace, occurrence })
  }
  if !run_texts.is_empty() {
    { program: SetRunTextProgram(run_texts), schema }
  } else if revisions.is_empty() {
    { program: ReplaceProgram(replacements), schema }
  } else {
    { program: RevisionProgram(revisions), schema }
  }
}

///|
/// Validates and normalizes one `set_run_text` address. Accepted forms:
/// the canonical query selector (`/docx/body/p[1]/r[2]`) and its
/// body-relative form (`p[1]/r[2]`). Segments are `kind[ordinal]` with
/// kind in {p, r, tbl, tr, tc} and ordinal >= 1; the path must end in a
/// run segment. The normalized body-relative form is returned, so
/// agents can paste `office query` paths directly.
fn parse_docx_run_address(
  value : String,
  index : Int,
) -> String raise DocxEditParseError {
  let canonical_prefix = "/docx/body/"
  let relative = if value.has_prefix(canonical_prefix) {
    value[canonical_prefix.length():].to_owned()
  } else {
    value
  }
  fn refuse(reason : String) -> DocxEditParseError {
    docx_edit_parse_error(
      "ops[\{index}].params.at " +
      reason +
      "; expected a run path like \"p[3]/r[2]\" or \"/docx/body/p[3]/r[2]\"",
    )
  }
  if relative.length() == 0 {
    raise refuse("is empty")
  }
  let segments = relative.split("/").collect()
  let mut last_kind = ""
  for segment_view in segments {
    let segment = segment_view.to_owned()
    guard segment.find("[") is Some(open_at) && segment.has_suffix("]") else {
      raise refuse("carries a segment without an ordinal (\"\{segment}\")")
    }
    let kind = segment[:open_at].to_owned()
    guard kind is ("p" | "r" | "tbl" | "tr" | "tc") else {
      raise refuse("carries an unsupported segment kind (\"\{kind}\")")
    }
    let ordinal_text = segment[open_at + 1:segment.length() - 1].to_owned()
    if ordinal_text.length() == 0 {
      raise refuse("carries an empty ordinal (\"\{segment}\")")
    }
    let mut ordinal = 0
    for character in ordinal_text {
      guard character >= '0' && character <= '9' else {
        raise refuse("carries a non-numeric ordinal (\"\{segment}\")")
      }
      ordinal = ordinal * 10 + (character.to_int() - '0'.to_int())
      if ordinal > MAX_EDIT_OCCURRENCE {
        raise refuse("carries an ordinal past \{MAX_EDIT_OCCURRENCE}")
      }
    }
    if ordinal < 1 {
      raise refuse("carries ordinal 0; ordinals start at 1")
    }
    last_kind = kind
  }
  if last_kind != "r" {
    raise refuse("must end in a run segment")
  }
  relative
}

///|
/// Parses one `accept_revision`/`reject_revision` params object.
fn parse_docx_revision_op(
  params : Map[String, Json],
  accept : Bool,
  index : Int,
) -> DocxRevisionOp raise DocxEditParseError {
  docx_edit_reject_unknown(
    params,
    ["id", "author", "type", "all"],
    "ops[\{index}].params",
  )
  fn selector_text(key : String) -> String? raise DocxEditParseError {
    match params.get(key) {
      None => None
      Some(String(value)) => {
        if value.length() == 0 {
          raise docx_edit_parse_error(
            "ops[\{index}].params.\{key} must not be empty",
          )
        }
        if value.length() > MAX_REVISION_SELECTOR_UNITS {
          raise docx_edit_parse_error(
            "ops[\{index}].params.\{key} is \{value.length()} units; the limit is \{MAX_REVISION_SELECTOR_UNITS}",
          )
        }
        if !docx_edit_text_ok(value) {
          raise docx_edit_parse_error(
            "ops[\{index}].params.\{key} carries characters no XML attribute can spell",
          )
        }
        Some(value)
      }
      _ =>
        raise docx_edit_parse_error(
          "ops[\{index}].params.\{key} must be a string when present",
        )
    }
  }

  let id = selector_text("id")
  let author = selector_text("author")
  let kind = match selector_text("type") {
    None => None
    Some(value) => {
      guard value is ("ins" | "del") else {
        raise docx_edit_parse_error(
          "ops[\{index}].params.type must be \"ins\" or \"del\"",
        )
      }
      Some(value)
    }
  }
  let all = match params.get("all") {
    None => false
    // `all: false` is never written on purpose: it reads like a selector but
    // constrains nothing, so it is rejected rather than silently ignored.
    Some(True) => true
    _ =>
      raise docx_edit_parse_error(
        "ops[\{index}].params.all must be true when present; omit it to select by id, author, or type",
      )
  }
  if all && (id is Some(_) || author is Some(_) || kind is Some(_)) {
    raise docx_edit_parse_error(
      "ops[\{index}].params.all cannot be combined with id, author, or type",
    )
  }
  if !all && id is None && author is None && kind is None {
    raise docx_edit_parse_error(
      "ops[\{index}].params needs at least one of id, author, type, or all",
    )
  }
  { accept, id, author, kind, all }
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
  match script.program {
    ReplaceProgram(ops) => transact_docx_replace(options, ops, allow_unmatched~)
    RevisionProgram(ops) =>
      transact_docx_revisions(options, ops, allow_unmatched~)
    // Addressed ops have no unmatched-tolerance: an address that does
    // not resolve refuses the whole transaction, always.
    SetRunTextProgram(ops) => transact_docx_set_run_text(options, ops)
  }
}

///|
/// The addressed run-replacement half of `transact_docx_edit` (#462 A3):
/// each op queues one whole-run replacement through the session, in
/// script order against the SAME immutable snapshot. The first refusal
/// aborts the transaction typed; nothing is published on any refusal.
async fn transact_docx_set_run_text(
  options : @transaction.TransactionOptions,
  ops : Array[DocxSetRunTextOp],
) -> DocxEditResult {
  let collected : Ref[DocxEditReport?] = Ref(None)
  let transaction = transact_docx(options, session => {
    let results = ops.map(op => {
      (
        {
          op: "set_run_text",
          find: "",
          replace: "",
          occurrence: None,
          at: Some(op.at),
          expect: Some(op.expect),
          text: Some(op.text),
          selector_id: None,
          selector_author: None,
          selector_type: None,
          selector_all: false,
          matched: 0,
          replacements: 0,
          resolved: 0,
        } : DocxEditOpResult)
    })
    let mut replacements = 0
    for index, op in ops {
      let receipt = session.queue_run_text_replacement(
        at_relative=op.at,
        expect=op.expect,
        text=op.text,
      )
      results[index].matched = 1
      results[index].replacements = receipt.edit_count()
      replacements += receipt.edit_count()
    }
    collected.val = Some({
      ops_applied: ops.length(),
      replacements,
      revisions_resolved: 0,
      results,
      unmatched: [],
      unmatched_total: 0,
      unsupported: [],
      unsupported_total: 0,
      conflicts: [],
      conflicts_total: 0,
      locations: [],
      locations_truncated: false,
      stories_scanned: ["/body"],
      changed: replacements > 0,
    })
  })
  guard collected.val is Some(report) else {
    raise docx_failure(
      "office.docx.edit_internal", "the edit transaction returned no report",
    )
  }
  { report, transaction }
}

///|
/// The literal find & replace half of `transact_docx_edit`.
async fn transact_docx_replace(
  options : @transaction.TransactionOptions,
  ops : Array[DocxReplaceOp],
  allow_unmatched~ : Bool,
) -> DocxEditResult {
  let collected : Ref[DocxEditReport?] = Ref(None)
  let report = transact_docx(options, session => {
    let results = ops.map(op => {
      (
        {
          op: "replace_text",
          find: op.find,
          replace: op.replace,
          occurrence: op.occurrence,
          at: None,
          expect: None,
          text: None,
          selector_id: None,
          selector_author: None,
          selector_type: None,
          selector_all: false,
          matched: 0,
          replacements: 0,
          resolved: 0,
        } : DocxEditOpResult)
    })
    let state : DocxEditState = {
      report: {
        ops_applied: ops.length(),
        replacements: 0,
        revisions_resolved: 0,
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
      ops,
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
