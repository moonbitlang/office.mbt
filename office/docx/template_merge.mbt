///|
/// The DOCX template merge: substitutes `{{key}}` placeholders in run
/// text through the preservation-safe D1 edit session — byte-span edits
/// on the exact source snapshot, never a document rewrite. Placeholders
/// may span run boundaries (Word splits text freely); the value inherits
/// the formatting of the run where the placeholder starts. Strict by
/// default, mirroring the XLSX merge: malformed placeholders,
/// unsupported contexts, and missing keys (unless allowed) refuse
/// publication with bounded findings.

///|
pub(all) struct DocxTemplateFinding {
  location : String
  detail : String
} derive(Eq, @debug.Debug)

///|
pub(all) struct DocxTemplateReport {
  mut placeholders_found : Int
  mut replaced : Int
  mut escapes_applied : Int
  mut distinct_keys_used : Int
  missing : Array[DocxTemplateFinding]
  unused : Array[String]
  malformed : Array[DocxTemplateFinding]
  unsupported : Array[DocxTemplateFinding]
  locations : Array[DocxTemplateFinding]
  mut locations_truncated : Bool
  mut missing_total : Int
  mut malformed_total : Int
  mut unsupported_total : Int
  mut unused_total : Int
  stories_scanned : Array[String]
  mut changed : Bool
} derive(Eq, @debug.Debug)

///|
/// Raised when strict findings refuse publication.
pub suberror DocxTemplateRefused {
  DocxTemplateRefused(DocxTemplateReport)
} derive(@debug.Debug)

///|
let docx_template_finding_limit : Int = 64

///|
let docx_template_scan_budget : Int = 4 * 1024 * 1024

///|
/// Decodes a run's content byte region as a sequence of `<w:t>` elements
/// only, entity-decoding text. Returns None when the region holds
/// anything else (symbols, field instructions, nested markup, unknown
/// entities) — the fail-closed fidelity gate before any rewrite.
fn docx_decode_text_region(region : String) -> String? {
  let out = StringBuilder::new()
  let mut index = 0
  let units = region
  let length = units.length()
  while index < length {
    // expect an opening <w:t ...> tag
    guard units[index].to_int() == '<'.to_int() else { return None }
    let open_end = find_unit(units, index, '>'.to_int())
    guard open_end is Some(open_close) else { return None }
    let tag = units[index:open_close].to_owned()
    guard tag == "<w:t" || tag.has_prefix("<w:t ") || tag.has_prefix("<w:t\t") else {
      return None
    }
    // self-closing form contributes nothing
    if units[open_close - 1].to_int() == '/'.to_int() {
      index = open_close + 1
      continue
    }
    index = open_close + 1
    // text until </w:t>: copy plain stretches whole (string-level copies
    // keep surrogate pairs intact), decode entities one at a time
    for ;; {
      guard index < length else { return None }
      let unit = units[index].to_int()
      if unit == '<'.to_int() {
        let close = units[index:].to_owned()
        guard close.has_prefix("</w:t>") else { return None }
        index += 6
        break
      }
      if unit == '&'.to_int() {
        let semi = find_unit(units, index, ';'.to_int())
        guard semi is Some(entity_end) else { return None }
        let entity = units[index:entity_end + 1].to_owned()
        match entity {
          "&amp;" => out.write_char('&')
          "&lt;" => out.write_char('<')
          "&gt;" => out.write_char('>')
          "&quot;" => out.write_char('"')
          "&apos;" => out.write_char('\'')
          _ => {
            // numeric references only; anything else is unknown
            guard decode_numeric_entity(entity) is Some(text) else {
              return None
            }
            out.write_string(text)
          }
        }
        index = entity_end + 1
        continue
      }
      let mut stop = index
      while stop < length &&
            units[stop].to_int() != '<'.to_int() &&
            units[stop].to_int() != '&'.to_int() {
        stop += 1
      }
      out.write_string(units[index:stop].to_owned())
      index = stop
    }
  }
  Some(out.to_string())
}

///|
fn find_unit(text : String, from : Int, wanted : Int) -> Int? {
  let mut index = from
  while index < text.length() {
    if text[index].to_int() == wanted {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn decode_numeric_entity(entity : String) -> String? {
  guard entity.has_prefix("&#") && entity.has_suffix(";") else { return None }
  let body = entity[2:entity.length() - 1].to_owned()
  let mut value = 0
  if body.has_prefix("x") || body.has_prefix("X") {
    for unit in body[1:body.length()].to_owned() {
      let code = unit.to_int()
      let digit = if code >= '0'.to_int() && code <= '9'.to_int() {
        code - '0'.to_int()
      } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
        code - 'a'.to_int() + 10
      } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
        code - 'A'.to_int() + 10
      } else {
        return None
      }
      value = value * 16 + digit
      if value > 0x10FFFF {
        return None
      }
    }
  } else {
    if body.length() == 0 {
      return None
    }
    for unit in body {
      let code = unit.to_int()
      guard code >= '0'.to_int() && code <= '9'.to_int() else { return None }
      value = value * 10 + (code - '0'.to_int())
      if value > 0x10FFFF {
        return None
      }
    }
  }
  guard value > 0 &&
    !(value >= 0xD800 && value <= 0xDFFF) &&
    value != 0xFFFE &&
    value != 0xFFFF else {
    return None
  }
  // range and non-character checks above make this conversion safe
  Some(value.unsafe_to_char().to_string())
}

///|
fn docx_escape_text(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
/// Collects every paragraph in a story with its scanner-identical
/// relative path (ordinals among same-kind direct siblings, recursing
/// through tables).
fn docx_collect_paragraphs(
  children : Array[@document.DocumentElement],
  prefix : String,
  out : Array[(String, Array[@document.DocumentElement])],
) -> Unit {
  let mut paragraphs = 0
  let mut tables = 0
  for child in children {
    match child {
      Paragraph(children~, ..) => {
        paragraphs += 1
        out.push((prefix + "p[\{paragraphs}]", children))
      }
      Table(children=rows, ..) => {
        tables += 1
        let mut row_index = 0
        for row in rows {
          match row {
            TableRow(children=cells, ..) => {
              row_index += 1
              let mut cell_index = 0
              for cell in cells {
                match cell {
                  TableCell(children=blocks, ..) => {
                    cell_index += 1
                    docx_collect_paragraphs(
                      blocks,
                      prefix +
                      "tbl[\{tables}]/tr[\{row_index}]/tc[\{cell_index}]/",
                      out,
                    )
                  }
                  _ => ()
                }
              }
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
  }
}

///|
/// Shared mutable state for one merge pass.
priv struct DocxMergeState {
  report : DocxTemplateReport
  values : Map[String, @template.TemplateValue]
  used_keys : Set[String]
  budget : Ref[Int]
  edits : Array[DocxRunEdit]
  // every run a match or escape touches — including interior zero-width
  // runs a span crosses (the reader drops in-run pictures, leaving an
  // empty run the model cannot distinguish from truly empty; only the
  // byte-fidelity gate can see the difference) and runs covered by
  // MISSING-key matches (their stored bytes must still round-trip or
  // the paragraph is an unsupported context, which outranks missing)
  checks : Array[DocxRunEdit]
  allow_missing : Bool
}

///|
fn DocxMergeState::note_unsupported(
  self : DocxMergeState,
  location : String,
  detail : String,
) -> Unit {
  self.report.unsupported_total += 1
  if self.report.unsupported.length() < docx_template_finding_limit {
    self.report.unsupported.push({ location, detail })
  }
}

///|
/// Scans one paragraph's piece stream for placeholders and escapes. One
/// scan keeps full grammar context across every run boundary: a match or
/// escape touching any unrewritable piece, or straddling a hyperlink
/// boundary, refuses, so no split shape can silently survive and no
/// counting is needed.
fn DocxMergeState::scan_paragraph(
  self : DocxMergeState,
  story : String,
  part : String,
  paragraph_path : String,
  children : Array[@document.DocumentElement],
) -> Unit raise {
  let location = "/docx" + story + "/" + paragraph_path
  let pieces = docx_paragraph_pieces(paragraph_path, children)
  guard pieces.length() > 0 else { return }
  // split-proof prefilter: single code units cannot straddle pieces
  let mut interesting = false
  for piece in pieces {
    if piece.text.contains("{") || piece.text.contains("\\") {
      interesting = true
      break
    }
  }
  guard interesting else { return }
  let scan = @template.scan_placeholders(
    pieces.map(piece => piece.text),
    self.budget,
  )
  self.report.placeholders_found += scan.matches.length()
  for entry in scan.malformed {
    self.report.malformed_total += 1
    if self.report.malformed.length() < docx_template_finding_limit {
      self.report.malformed.push({ location, detail: entry.reason })
    }
  }
  guard scan.matches.length() > 0 || scan.escapes.length() > 0 else { return }
  if scan.malformed.length() > 0 {
    // a paragraph with any malformed site is never edited
    return
  }
  let mut region_missing = false
  let accepted : Array[DocxSpanRewrite] = []
  for matched in scan.matches {
    match docx_span_safety(pieces, matched.span) {
      SpanUnrewritable => {
        self.note_unsupported(
          location, "placeholder overlaps content the merge cannot rewrite",
        )
        continue
      }
      SpanCrossesParent => {
        self.note_unsupported(
          location, "placeholder crosses a hyperlink boundary",
        )
        continue
      }
      SpanSafe => ()
    }
    // every run this span touches joins the byte-fidelity set,
    // regardless of key presence (unsupported outranks missing)
    docx_collect_span_checks(
      pieces,
      matched.span,
      story~,
      part~,
      location~,
      self.checks,
    )
    match self.values.get(matched.key) {
      Some(value) => {
        self.used_keys.add(matched.key)
        if self.report.locations.length() < docx_template_finding_limit {
          self.report.locations.push({ location, detail: matched.key })
        } else {
          self.report.locations_truncated = true
        }
        accepted.push({ span: matched.span, replacement: value.render() })
      }
      None => {
        region_missing = true
        self.report.missing_total += 1
        if self.report.missing.length() < docx_template_finding_limit {
          self.report.missing.push({ location, detail: matched.key })
        }
      }
    }
  }
  // an escape needing a rewrite in unrewritable content refuses too: its
  // backslash or braces would otherwise survive or corrupt
  let ok_escapes : Array[DocxSpanRewrite] = []
  for span in scan.escapes {
    match docx_span_safety(pieces, span) {
      SpanUnrewritable =>
        self.note_unsupported(
          location, "escape sequence overlaps content the merge cannot rewrite",
        )
      SpanCrossesParent =>
        self.note_unsupported(
          location, "escape sequence crosses a hyperlink boundary",
        )
      SpanSafe => {
        docx_collect_span_checks(
          pieces,
          span,
          story~,
          part~,
          location~,
          self.checks,
        )
        ok_escapes.push({ span, replacement: "{{" })
      }
    }
  }
  if region_missing && !self.allow_missing {
    // the command will refuse; no edits from this paragraph
    return
  }
  guard accepted.length() > 0 || ok_escapes.length() > 0 else { return }
  let rewrites = accepted.copy()
  for escape in ok_escapes {
    rewrites.push(escape)
  }
  docx_plan_span_rewrites(
    pieces,
    rewrites,
    story~,
    part~,
    location~,
    self.edits,
  )
  self.report.replaced += accepted.length()
  self.report.escapes_applied += ok_escapes.length()
}

///|
/// Flags brace pairs in stories the v1 merge does not rewrite.
fn DocxMergeState::flag_out_of_scope(
  self : DocxMergeState,
  what : String,
  bodies : Array[(String, Array[@document.DocumentElement])],
) -> Unit {
  for entry in bodies {
    let (id, body) = entry
    // text is JOINED before the brace check — a pair split across runs
    // must flag exactly like an unsplit one. Paragraph boundaries and
    // opaque children insert separators so a pair can never straddle
    // them.
    if docx_story_joined_text(body).contains("{{") {
      self.note_unsupported(
        "/docx/\{what}[\{id}]",
        "placeholders in \{what} stories are not substitutable in v1",
      )
    }
  }
}

///|
/// Result of one strict DOCX template transaction.
pub struct DocxTemplateResult {
  report : DocxTemplateReport
  transaction : @transaction.TransactionReport
}

///|
/// Merges template data into a DOCX package through the D1 edit session.
/// Strict findings refuse publication with the full report; the template
/// is never modified (distinct output enforced by the transaction layer).
pub async fn transact_docx_template(
  options : @transaction.TransactionOptions,
  values : Map[String, @template.TemplateValue],
  allow_missing~ : Bool,
) -> DocxTemplateResult {
  let collected : Ref[DocxTemplateReport?] = Ref(None)
  let report = transact_docx(options, session => {
    let state : DocxMergeState = {
      report: {
        placeholders_found: 0,
        replaced: 0,
        escapes_applied: 0,
        distinct_keys_used: 0,
        missing: [],
        unused: [],
        malformed: [],
        unsupported: [],
        locations: [],
        locations_truncated: false,
        missing_total: 0,
        malformed_total: 0,
        unsupported_total: 0,
        unused_total: 0,
        stories_scanned: [],
        changed: false,
      },
      values,
      used_keys: Set([]),
      budget: Ref(docx_template_scan_budget),
      edits: [],
      checks: [],
      allow_missing,
    }
    let annotated = session.annotated()
    let result = annotated.result()
    guard result.document is Document(children~, ..) else {
      raise docx_failure(
        "office.docx.template_internal", "the reader returned a non-document root",
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
              "office.docx.resource_limit", "template scan work exceeds the configured ceiling",
            )
          error => raise error
        }
      }
    }
    state.flag_out_of_scope("footnotes", annotated.footnote_bodies())
    state.flag_out_of_scope("endnotes", annotated.endnote_bodies())
    state.flag_out_of_scope("comments", annotated.comment_bodies())
    for key, _ in values {
      if !state.used_keys.contains(key) {
        state.report.unused_total += 1
        if state.report.unused.length() < docx_template_finding_limit {
          state.report.unused.push(key)
        }
      }
    }
    state.report.distinct_keys_used = state.used_keys.length()
    docx_run_fidelity_pass(state, session, annotated)
    docx_emit_scalar_edits(state, session, annotated)
    collected.val = Some(state.report)
    if state.report.malformed_total > 0 ||
      state.report.unsupported_total > 0 ||
      (state.report.missing_total > 0 && !allow_missing) {
      raise docx_failure(
        "office.docx.template_refused", "strict template findings refuse publication",
      )
    }
  }) catch {
    error =>
      match collected.val {
        Some(merge) if merge.malformed_total > 0 ||
          merge.unsupported_total > 0 ||
          (merge.missing_total > 0 && !allow_missing) =>
          raise DocxTemplateRefused(merge)
        _ => raise error
      }
  }
  guard collected.val is Some(merge) else {
    raise docx_failure(
      "office.docx.template_internal", "the merge produced no report",
    )
  }
  { report: merge, transaction: report }
}

///|
/// The byte-fidelity gate over the full touch set: every run ANY match
/// or escape touches must store bytes that decode to exactly its model
/// text — including interior zero-width runs a span crosses (dropped
/// in-run pictures live there) and runs under missing-key matches
/// (unsupported outranks missing). Shared by the scalar and document
/// drivers so their guarantees cannot drift.
fn docx_run_fidelity_pass(
  state : DocxMergeState,
  session : DocxEditSession,
  annotated : @word.DocxAnnotatedResult,
) -> Unit {
  docx_fidelity_check_runs(state.checks, session, annotated, (location, detail) => {
    state.note_unsupported(location, detail)
  })
}

///|
/// Emits the scalar pass's run rewrites; each queue re-checks the
/// refusal totals so a refused merge never mutates. Shared by both
/// drivers.
fn docx_emit_scalar_edits(
  state : DocxMergeState,
  session : DocxEditSession,
  annotated : @word.DocxAnnotatedResult,
) -> Unit raise {
  // emission: fidelity already ran over the full check set (edited
  // runs are a subset of it); the refusal totals gate every queue
  docx_emit_run_edits(
    state.edits,
    session,
    annotated,
    () => {
      state.report.malformed_total > 0 ||
      state.report.unsupported_total > 0 ||
      (state.report.missing_total > 0 && !state.allow_missing)
    },
    () => state.report.changed = true,
  )
}
