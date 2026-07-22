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
/// One text-bearing run segment inside a scan region.
priv struct DocxRunSegment {
  run_path : String
  // paragraph-relative parent identity: "" for direct runs, else the
  // hyperlink path segment — placeholder matches may not cross parents
  parent : String
  text : String
}

///|
/// One planned rewrite for a run.
priv struct DocxRunEdit {
  story : String
  part : String
  run_path : String
  paragraph_location : String
  original_text : String
  final_text : String
}

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
  let body = entity.substring(start=2, end=entity.length() - 1)
  let mut value = 0
  if body.has_prefix("x") || body.has_prefix("X") {
    for unit in body.substring(start=1, end=body.length()) {
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
/// Whether a run holds only Text children (the scannable, rewritable
/// shape). Runs carrying tabs, breaks, images, or references are opaque
/// boundaries: their text is never scanned and a brace pair inside one
/// is an unsupported context.
fn docx_pure_text_run(
  children : Array[@document.DocumentElement],
) -> (Bool, String) {
  let text = StringBuilder::new()
  for child in children {
    match child {
      Text(value) => text.write_string(value)
      _ => return (false, text.to_string())
    }
  }
  (true, text.to_string())
}

///|
/// Shared mutable state for one merge pass.
priv struct DocxMergeState {
  report : DocxTemplateReport
  values : Map[String, @template.TemplateValue]
  used_keys : Set[String]
  budget : Ref[Int]
  edits : Array[DocxRunEdit]
  allow_missing : Bool
}

///|
fn DocxMergeState::scan_region(
  self : DocxMergeState,
  story : String,
  part : String,
  paragraph_location : String,
  segments : Array[DocxRunSegment],
) -> Unit raise {
  guard segments.length() > 0 else { return }
  let mut interesting = false
  for segment in segments {
    if segment.text.contains("{{") || segment.text.contains("\\") {
      interesting = true
      break
    }
  }
  guard interesting else { return }
  let texts = segments.map(segment => segment.text)
  let scan = @template.scan_placeholders(texts, self.budget)
  self.report.placeholders_found += scan.matches.length()
  for entry in scan.malformed {
    self.report.malformed_total += 1
    if self.report.malformed.length() < docx_template_finding_limit {
      self.report.malformed.push({
        location: paragraph_location,
        detail: entry.reason,
      })
    }
  }
  guard scan.matches.length() > 0 || scan.escapes.length() > 0 else { return }
  if scan.malformed.length() > 0 {
    // a region with any malformed site is never edited
    return
  }
  // resolve matches: parent agreement + key presence
  let mut region_missing = false
  let accepted : Array[@template.PlaceholderMatch] = []
  for matched in scan.matches {
    let start_parent = segments[matched.span.start_segment].parent
    let mut crosses = false
    let mut cursor = matched.span.start_segment
    while cursor <= matched.span.end_segment && cursor < segments.length() {
      if segments[cursor].parent != start_parent {
        crosses = true
        break
      }
      cursor += 1
    }
    if crosses {
      self.report.unsupported_total += 1
      if self.report.unsupported.length() < docx_template_finding_limit {
        self.report.unsupported.push({
          location: paragraph_location,
          detail: "placeholder crosses a hyperlink boundary",
        })
      }
      continue
    }
    match self.values.get(matched.key) {
      Some(_) => {
        self.used_keys.add(matched.key)
        if self.report.locations.length() < docx_template_finding_limit {
          self.report.locations.push({
            location: paragraph_location,
            detail: matched.key,
          })
        } else {
          self.report.locations_truncated = true
        }
        accepted.push(matched)
      }
      None => {
        region_missing = true
        self.report.missing_total += 1
        if self.report.missing.length() < docx_template_finding_limit {
          self.report.missing.push({
            location: paragraph_location,
            detail: matched.key,
          })
        }
      }
    }
  }
  if region_missing && !self.allow_missing {
    // the command will refuse; no edits from this region
    return
  }
  guard accepted.length() > 0 || scan.escapes.length() > 0 else { return }
  // rebuild each segment's final text from the pieces intersecting it;
  // a piece contributes its replacement only in its START segment and
  // erases its covered range everywhere else
  for index, segment in segments {
    let original = segment.text
    let length = original.length()
    // (local_start, local_end, replacement)
    let pieces : Array[(Int, Int, String)] = []
    for matched in accepted {
      let span = matched.span
      if span.start_segment <= index && index <= span.end_segment {
        let local_start = if span.start_segment == index {
          span.start_offset
        } else {
          0
        }
        let local_end = if span.end_segment == index {
          span.end_offset
        } else {
          length
        }
        let replacement = if span.start_segment == index {
          match self.values.get(matched.key) {
            Some(value) => value.render()
            None => original.substring(start=local_start, end=local_end)
          }
        } else {
          ""
        }
        pieces.push((local_start, local_end, replacement))
      }
    }
    for span in scan.escapes {
      if span.start_segment <= index && index <= span.end_segment {
        let local_start = if span.start_segment == index {
          span.start_offset
        } else {
          0
        }
        let local_end = if span.end_segment == index {
          span.end_offset
        } else {
          length
        }
        let replacement = if span.start_segment == index { "{{" } else { "" }
        pieces.push((local_start, local_end, replacement))
      }
    }
    if pieces.length() == 0 {
      continue
    }
    pieces.sort_by((a, b) => a.0 - b.0)
    let builder = StringBuilder::new()
    let mut cursor = 0
    for piece in pieces {
      let (local_start, local_end, replacement) = piece
      builder.write_string(original.substring(start=cursor, end=local_start))
      builder.write_string(replacement)
      cursor = local_end
    }
    builder.write_string(original.substring(start=cursor, end=length))
    let final_text = builder.to_string()
    if final_text != original {
      self.edits.push({
        story,
        part,
        run_path: segment.run_path,
        paragraph_location,
        original_text: original,
        final_text,
      })
    }
  }
  // counters reflect applied work: every accepted PRESENT match and
  // every escape lands in an emitted or identity rebuild above
  for matched in accepted {
    if self.values.get(matched.key) is Some(_) {
      self.report.replaced += 1
    }
  }
  self.report.escapes_applied += scan.escapes.length()
}

///|
/// Builds the scan regions of one paragraph: maximal sequences of
/// pure-text runs (direct or inside hyperlinks). Opaque runs — those
/// carrying tabs, breaks, images, or references — close the current
/// region; a brace pair inside one is an unsupported context.
fn DocxMergeState::scan_paragraph(
  self : DocxMergeState,
  story : String,
  part : String,
  paragraph_path : String,
  children : Array[@document.DocumentElement],
) -> Unit raise {
  let location = "/docx" + story + "/" + paragraph_path
  let region : Array[DocxRunSegment] = []
  let mut runs = 0
  let mut hyperlinks = 0
  let flush = () => {
    if region.length() > 0 {
      self.scan_region(story, part, location, region.copy())
      region.clear()
    }
  }
  let handle_run = (
    run_children : Array[@document.DocumentElement],
    run_path : String,
    parent : String,
  ) => {
    let (pure, text) = docx_pure_text_run(run_children)
    if pure {
      region.push({ run_path, parent, text })
    } else {
      flush()
      if text.contains("{{") {
        self.report.unsupported_total += 1
        if self.report.unsupported.length() < docx_template_finding_limit {
          self.report.unsupported.push({
            location,
            detail: "placeholder inside a run carrying non-text content",
          })
        }
      }
    }
  }
  for child in children {
    match child {
      Run(children=run_children, ..) => {
        runs += 1
        handle_run(run_children, paragraph_path + "/r[\{runs}]", "")
      }
      Hyperlink(children=link_children, ..) => {
        hyperlinks += 1
        let link_segment = "hyperlink[\{hyperlinks}]"
        let mut link_runs = 0
        for grand in link_children {
          match grand {
            Run(children=run_children, ..) => {
              link_runs += 1
              handle_run(
                run_children,
                paragraph_path + "/" + link_segment + "/r[\{link_runs}]",
                link_segment,
              )
            }
            _ => flush()
          }
        }
      }
      Text(value) => {
        // bare text under a paragraph has no run to rewrite
        flush()
        if value.contains("{{") {
          self.report.unsupported_total += 1
          if self.report.unsupported.length() < docx_template_finding_limit {
            self.report.unsupported.push({
              location,
              detail: "placeholder outside any text run",
            })
          }
        }
      }
      _ => flush()
    }
  }
  flush()
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
    let mut found = false
    fn walk(element : @document.DocumentElement) -> Unit {
      match element {
        Text(value) => if value.contains("{{") { found = true }
        Paragraph(children~, ..)
        | Run(children~, ..)
        | Hyperlink(children~, ..)
        | Table(children~, ..)
        | TableRow(children~, ..)
        | TableCell(children~, ..) =>
          for child in children {
            walk(child)
          }
        _ => ()
      }
    }
    for element in body {
      walk(element)
    }
    if found {
      self.report.unsupported_total += 1
      if self.report.unsupported.length() < docx_template_finding_limit {
        self.report.unsupported.push({
          location: "/docx/\{what}[\{id}]",
          detail: "placeholders in \{what} stories are not substitutable in v1",
        })
      }
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
  let collected : Ref[DocxTemplateReport?] = Ref::new(None)
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
      used_keys: Set::new(),
      budget: Ref::new(docx_template_scan_budget),
      edits: [],
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
    state.report.distinct_keys_used = state.used_keys.size()
    // fidelity gate + emission: every edited run's stored bytes must
    // decode to exactly its model text before any rewrite is queued
    for edit in state.edits {
      guard annotated.story_run_span(edit.story, edit.run_path) is Some(span) else {
        state.report.unsupported_total += 1
        if state.report.unsupported.length() < docx_template_finding_limit {
          state.report.unsupported.push({
            location: edit.paragraph_location,
            detail: "a matched run has no byte span in the source snapshot",
          })
        }
        continue
      }
      guard (span.content_start(), span.close_tag_start())
        is (Some(content_start), Some(close_tag_start)) else {
        state.report.unsupported_total += 1
        if state.report.unsupported.length() < docx_template_finding_limit {
          state.report.unsupported.push({
            location: edit.paragraph_location,
            detail: "a matched run is stored in a form without rewritable content",
          })
        }
        continue
      }
      guard session.archive.get(edit.part) is Some(part_bytes) else {
        state.report.unsupported_total += 1
        if state.report.unsupported.length() < docx_template_finding_limit {
          state.report.unsupported.push({
            location: edit.paragraph_location,
            detail: "the source part bytes for a matched run are unavailable",
          })
        }
        continue
      }
      let region = @utf8.decode(part_bytes[content_start:close_tag_start]) catch {
        _ => {
          state.report.unsupported_total += 1
          if state.report.unsupported.length() < docx_template_finding_limit {
            state.report.unsupported.push({
              location: edit.paragraph_location,
              detail: "stored run content is not decodable text",
            })
          }
          continue
        }
      }
      match docx_decode_text_region(region) {
        Some(decoded) if decoded == edit.original_text => ()
        _ => {
          state.report.unsupported_total += 1
          if state.report.unsupported.length() < docx_template_finding_limit {
            state.report.unsupported.push({
              location: edit.paragraph_location,
              detail: "stored run content does not round-trip to its model text",
            })
          }
          continue
        }
      }
      if state.report.malformed_total > 0 ||
        state.report.unsupported_total > 0 ||
        (state.report.missing_total > 0 && !allow_missing) {
        continue
      }
      if edit.final_text == "" {
        session.queue_span_edit(
          edit.part,
          start=span.byte_start(),
          end=span.byte_end(),
          b"",
        )
      } else {
        let replacement = "<w:t xml:space=\"preserve\">" +
          docx_escape_text(edit.final_text) +
          "</w:t>"
        session.queue_span_edit(
          edit.part,
          start=content_start,
          end=close_tag_start,
          @utf8.encode(replacement),
        )
      }
      state.report.changed = true
    }
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
