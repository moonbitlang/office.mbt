// `office format` — the transactional span-formatting verb (F2b).
//
// The engine plans; this file makes the plan a TRANSACTION: a shared
// mutation preflight the whole DOCX surface has been missing, a
// three-check readback (the paragraph still projects what it did, the
// selected spans carry the request explicitly, and nothing else about
// their formatting moved), and atomic publication with nothing written
// on any refusal.

///|
/// What one formatting transaction did.
pub struct DocxFormatReport {
  priv mode : String
  priv requested_text : String?
  priv requested_within : String?
  priv requested_nth : Int?
  priv requested_range : (Int, Int)?
  priv resolved_within : String?
  priv selected : Array[Int]
  priv spans : Array[@word.DocxFormatSpan]
  priv affected : Array[@word.DocxFormatAffected]
  priv runs_changed : Int
  priv runs_already_satisfied : Int
  priv splits : Int
  priv byte_edits : Int
}

///|
/// `text` or `range` — which selector produced the spans.
pub fn DocxFormatReport::mode(self : DocxFormatReport) -> String {
  self.mode
}

///|
/// The needle the caller asked for, in text mode.
pub fn DocxFormatReport::requested_text(self : DocxFormatReport) -> String? {
  self.requested_text
}

///|
/// The scope the caller asked for, as SPELLED.
pub fn DocxFormatReport::requested_within(self : DocxFormatReport) -> String? {
  self.requested_within
}

///|
/// The ordinal the caller selected, if any.
pub fn DocxFormatReport::requested_nth(self : DocxFormatReport) -> Int? {
  self.requested_nth
}

///|
/// The explicit range the caller addressed, in range mode.
pub fn DocxFormatReport::requested_range(
  self : DocxFormatReport,
) -> (Int, Int)? {
  self.requested_range
}

///|
/// The scan path a stable `p[id="…"]` scope resolved to; None when the
/// scope was ordinal or absent — the receipt names both spellings so an
/// agent can re-anchor.
pub fn DocxFormatReport::resolved_within(self : DocxFormatReport) -> String? {
  self.resolved_within
}

///|
/// The candidate ordinals formatted, in document order.
pub fn DocxFormatReport::selected(self : DocxFormatReport) -> Array[Int] {
  self.selected.copy()
}

///|
/// The selected spans.
pub fn DocxFormatReport::spans(
  self : DocxFormatReport,
) -> Array[@word.DocxFormatSpan] {
  self.spans.copy()
}

///|
/// The affected paragraphs, with the projections they must still read.
pub fn DocxFormatReport::affected(
  self : DocxFormatReport,
) -> Array[@word.DocxFormatAffected] {
  self.affected.copy()
}

///|
/// The paragraphs this transaction touched, by path.
pub fn DocxFormatReport::affected_paths(
  self : DocxFormatReport,
) -> Array[String] {
  self.affected.map(entry => entry.path())
}

///|
/// How many runs were rewritten.
pub fn DocxFormatReport::runs_changed(self : DocxFormatReport) -> Int {
  self.runs_changed
}

///|
/// How many touched runs already held every requested property.
pub fn DocxFormatReport::runs_already_satisfied(self : DocxFormatReport) -> Int {
  self.runs_already_satisfied
}

///|
/// How many runs were clone-split.
pub fn DocxFormatReport::splits(self : DocxFormatReport) -> Int {
  self.splits
}

///|
/// How many byte edits the plan carried. Zero means the document
/// already held the request everywhere it was asked.
pub fn DocxFormatReport::byte_edits(self : DocxFormatReport) -> Int {
  self.byte_edits
}

///|
pub struct DocxFormatResult {
  report : DocxFormatReport
  transaction : @transaction.TransactionReport
}

///|
pub fn DocxFormatResult::report(self : DocxFormatResult) -> DocxFormatReport {
  self.report
}

///|
pub fn DocxFormatResult::transaction(
  self : DocxFormatResult,
) -> @transaction.TransactionReport {
  self.transaction
}

///|
/// The shared DOCX mutation preflight: the conditions under which this
/// toolkit declines to change a document at all.
///
/// A signature covers the parts being edited, so any edit invalidates
/// it and this toolkit cannot re-sign. Enforced protection is the
/// author's standing instruction that the document is not to be
/// changed. And a document recording revisions expects every edit to
/// arrive as one — writing an untracked edit would misrepresent it as
/// the author's own text.
///
/// None of these is a formatting question, which is why this runs on
/// the SHARED mutation path: every verb that changes a DOCX reaches it.
pub fn docx_mutation_preflight(
  archive : @zip.Archive,
) -> Unit raise @transaction.TransactionError {
  // Signatures are identified by CONTENT TYPE, not by where they are
  // stored: OPC lets a package name its signature parts freely, so a
  // path prefix would both miss a signature kept elsewhere and refuse
  // an unsigned package that merely has an origin part.
  if docx_package_declares_signature(archive) {
    raise @transaction.transaction_failure(
      "office.docx.signed_package", "this package carries a digital signature, which any edit would invalidate",
    )
  }
  guard docx_settings_part(archive) is Some(settings_name) else { return }
  guard archive.get(settings_name) is Some(settings) else { return }
  // An unreadable settings part cannot be cleared: a preflight that
  // cannot see its own evidence refuses rather than proceeds.
  let text = @utf8.decode(settings) catch {
    _ =>
      raise @transaction.transaction_failure(
        "office.docx.settings_unreadable", "this document's settings part could not be read, so its editing protections cannot be checked",
      )
  }
  match
    docx_settings_flag(
      text,
      "documentProtection",
      "enforcement",
      absent_means_on=false,
    ) {
    Enabled =>
      raise @transaction.transaction_failure(
        "office.docx.protected_document", "this document enforces editing protection; unprotect it before editing",
      )
    Ambiguous =>
      raise @transaction.transaction_failure(
        "office.docx.settings_ambiguous", "this document declares its editing protection more than once, with different values",
      )
    Disabled | Missing => ()
  }
  match
    docx_settings_flag(text, "trackRevisions", "val", absent_means_on=true) {
    Enabled =>
      raise @transaction.transaction_failure(
        "office.docx.track_revisions", "this document records revisions; editing it would write an untracked change",
      )
    Ambiguous =>
      raise @transaction.transaction_failure(
        "office.docx.settings_ambiguous", "this document declares revision tracking more than once, with different values",
      )
    Disabled | Missing => ()
  }
}

///|
/// Whether the package declares a digital SIGNATURE part. An origin or
/// certificate part alone is not a signature: a package may carry the
/// scaffolding before anything is signed.
fn docx_package_declares_signature(archive : @zip.Archive) -> Bool {
  guard archive.get("[Content_Types].xml") is Some(types) else { return false }
  let text = @utf8.decode(types) catch { _ => return false }
  text.contains(
    "application/vnd.openxmlformats-package.digital-signature-xmlsignature+xml",
  )
}

///|
/// The settings part's name, found through the main document's
/// RELATIONSHIPS rather than assumed: OPC part names are not
/// predictable, and an unreferenced `word/settings.xml` is not this
/// document's settings.
fn docx_settings_part(archive : @zip.Archive) -> String? {
  guard archive.get("word/_rels/document.xml.rels") is Some(rels) else {
    return None
  }
  let text = @utf8.decode(rels) catch { _ => return None }
  let bytes = @utf8.encode(text)
  let limit = bytes.length()
  let mut at = 0
  while at < limit {
    if bytes[at] != b'<' {
      at += 1
      continue
    }
    let element_start = at
    while at < limit && bytes[at] != b'>' {
      at += 1
    }
    let element = docx_ascii_text(bytes, element_start, at)
    at += 1
    guard element.contains("Relationship") else { continue }
    guard element.contains(
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings",
    ) else {
      continue
    }
    guard docx_attribute_of(element, "Target") is Some(target) else { continue }
    // Targets in the document part's rels are relative to `word/`; an
    // absolute one names the part outright.
    if target.has_prefix("/") {
      return Some(target.substring(start=1, end=target.length()).to_string())
    }
    return Some("word/" + target)
  }
  None
}

///|
/// One attribute of an open tag's text, by exact name.
fn docx_attribute_of(element : String, attribute : String) -> String? {
  let bytes = @utf8.encode(element)
  let limit = bytes.length()
  let mut at = 0
  while at < limit {
    while at < limit && bytes[at] != b'=' {
      at += 1
    }
    guard at < limit else { break }
    let mut name_end = at
    while name_end > 0 && docx_is_space(bytes[name_end - 1]) {
      name_end -= 1
    }
    let mut name_start = name_end
    while name_start > 0 &&
          !docx_is_space(bytes[name_start - 1]) &&
          bytes[name_start - 1] != b'<' {
      name_start -= 1
    }
    at += 1
    while at < limit && docx_is_space(bytes[at]) {
      at += 1
    }
    guard at < limit && (bytes[at] == b'"' || bytes[at] == b'\'') else { break }
    let quote = bytes[at]
    at += 1
    let value_start = at
    while at < limit && bytes[at] != quote {
      at += 1
    }
    if docx_ascii_text(bytes, name_start, name_end) == attribute {
      return Some(docx_ascii_text(bytes, value_start, at))
    }
    at += 1
  }
  None
}

///|
fn docx_is_space(byte : Byte) -> Bool {
  byte is (b' ' | b'\t' | b'\n' | b'\r')
}

///|
fn docx_ascii_text(bytes : Bytes, from : Int, to : Int) -> String {
  let builder = StringBuilder()
  for index in from..<to {
    if bytes[index] < b'\x80' {
      builder.write_char(bytes[index].to_int().unsafe_to_char())
    }
  }
  builder.to_string()
}

///|
/// What a settings flag says.
priv enum DocxSettingsFlag {
  Missing
  Disabled
  Enabled
  Ambiguous
}

///|
/// Read one WML settings flag: the element by local name UNDER THE WML
/// namespace, its attribute by local name, entity references in the
/// value expanded, comments skipped, and DUPLICATES that disagree
/// reported rather than resolved — a preflight never picks a winner.
fn docx_settings_flag(
  settings : String,
  element : String,
  attribute : String,
  absent_means_on~ : Bool,
) -> DocxSettingsFlag {
  let bytes = @utf8.encode(settings)
  let limit = bytes.length()
  // The prefixes bound to WML anywhere in this part: a settings part
  // declares them at its root, and a flag under another vocabulary is
  // not this document's setting.
  let wml : Map[String, Bool] = Map([])
  let mut scan = 0
  while scan < limit {
    if bytes[scan] != b'x' {
      scan += 1
      continue
    }
    let candidate = docx_ascii_text(bytes, scan, @cmp.minimum(scan + 6, limit))
    if candidate == "xmlns:" || candidate == "xmlns=" {
      let mut cursor = scan + 6
      let name_start = scan + 6
      while cursor < limit && bytes[cursor] != b'=' {
        cursor += 1
      }
      let prefix = if candidate == "xmlns=" {
        ""
      } else {
        docx_ascii_text(bytes, name_start, cursor)
      }
      while cursor < limit && bytes[cursor] != b'"' && bytes[cursor] != b'\'' {
        cursor += 1
      }
      if cursor < limit {
        let quote = bytes[cursor]
        cursor += 1
        let value_start = cursor
        while cursor < limit && bytes[cursor] != quote {
          cursor += 1
        }
        let uri = docx_ascii_text(bytes, value_start, cursor)
        if uri == "http://schemas.openxmlformats.org/wordprocessingml/2006/main" ||
          uri == "http://purl.oclc.org/ooxml/wordprocessingml/main" {
          wml[prefix] = true
        }
      }
      scan = cursor
      continue
    }
    scan += 1
  }
  let mut verdict = Missing
  let mut at = 0
  while at < limit {
    if bytes[at] != b'<' {
      at += 1
      continue
    }
    // Comments and processing instructions carry no elements.
    if at + 3 < limit &&
      bytes[at + 1] == b'!' &&
      bytes[at + 2] == b'-' &&
      bytes[at + 3] == b'-' {
      at += 4
      while at + 2 < limit &&
            !(bytes[at] == b'-' &&
            bytes[at + 1] == b'-' &&
            bytes[at + 2] == b'>') {
        at += 1
      }
      at += 3
      continue
    }
    if at + 1 < limit && (bytes[at + 1] == b'!' || bytes[at + 1] == b'?') {
      while at < limit && bytes[at] != b'>' {
        at += 1
      }
      at += 1
      continue
    }
    let element_start = at
    while at < limit && bytes[at] != b'>' {
      at += 1
    }
    let open_tag = docx_ascii_text(
      bytes,
      element_start,
      @cmp.minimum(at + 1, limit),
    )
    at += 1
    let mut name_end = 1
    let units = open_tag.length()
    while name_end < units &&
          !(open_tag.substring(start=name_end, end=name_end + 1).to_string()
          is (" " | "\t" | "\n" | "\r" | ">" | "/")) {
      name_end += 1
    }
    let qname = open_tag.substring(start=1, end=name_end).to_string()
    let (prefix, local) = match docx_split_qname(qname) {
      (found_prefix, found_local) => (found_prefix, found_local)
    }
    guard local == element && wml.get(prefix) == Some(true) else { continue }
    let reading = match docx_attribute_local(open_tag, attribute) {
      Some(value) =>
        if docx_expand_entities(value) is ("1" | "true" | "on") {
          Enabled
        } else {
          Disabled
        }
      None => if absent_means_on { Enabled } else { Disabled }
    }
    verdict = match verdict {
      Missing => reading
      Enabled => if reading is Enabled { Enabled } else { Ambiguous }
      Disabled => if reading is Disabled { Disabled } else { Ambiguous }
      Ambiguous => Ambiguous
    }
  }
  verdict
}

///|
fn docx_split_qname(qname : String) -> (String, String) {
  let units = qname.code_units()
  for index in 0..<units.length() {
    if units[index].to_int() == ':'.to_int() {
      return (
        qname.substring(start=0, end=index).to_string(),
        qname.substring(start=index + 1, end=qname.length()).to_string(),
      )
    }
  }
  ("", qname)
}

///|
/// One attribute of an open tag, matched by LOCAL name.
fn docx_attribute_local(open_tag : String, attribute : String) -> String? {
  let bytes = @utf8.encode(open_tag)
  let limit = bytes.length()
  let mut at = 1
  while at < limit && !docx_is_space(bytes[at]) && bytes[at] != b'>' {
    at += 1
  }
  while at < limit {
    while at < limit && (docx_is_space(bytes[at]) || bytes[at] == b'/') {
      at += 1
    }
    if at >= limit || bytes[at] == b'>' {
      break
    }
    let name_start = at
    while at < limit &&
          bytes[at] != b'=' &&
          !docx_is_space(bytes[at]) &&
          bytes[at] != b'>' {
      at += 1
    }
    let (_, local) = docx_split_qname(docx_ascii_text(bytes, name_start, at))
    while at < limit &&
          bytes[at] != b'"' &&
          bytes[at] != b'\'' &&
          bytes[at] != b'>' {
      at += 1
    }
    if at >= limit || bytes[at] == b'>' {
      break
    }
    let quote = bytes[at]
    at += 1
    let value_start = at
    while at < limit && bytes[at] != quote {
      at += 1
    }
    if local == attribute {
      return Some(docx_ascii_text(bytes, value_start, at))
    }
    at += 1
  }
  None
}

///|
/// Expand the entity references a settings value may spell its flag
/// with: `&#49;` is as much a `1` as `1` is.
fn docx_expand_entities(value : String) -> String {
  let bytes = @utf8.encode(value)
  let limit = bytes.length()
  let builder = StringBuilder()
  let mut at = 0
  while at < limit {
    if bytes[at] != b'&' {
      if bytes[at] < b'\x80' {
        builder.write_char(bytes[at].to_int().unsafe_to_char())
      }
      at += 1
      continue
    }
    let mut cursor = at + 1
    while cursor < limit && bytes[cursor] != b';' && cursor - at < 12 {
      cursor += 1
    }
    guard cursor < limit && bytes[cursor] == b';' else {
      builder.write_char('&')
      at += 1
      continue
    }
    let body = docx_ascii_text(bytes, at + 1, cursor)
    if body.has_prefix("#") {
      let digits = if body.has_prefix("#x") || body.has_prefix("#X") {
        body.substring(start=2, end=body.length()).to_string()
      } else {
        body.substring(start=1, end=body.length()).to_string()
      }
      let base = if body.has_prefix("#x") || body.has_prefix("#X") {
        16
      } else {
        10
      }
      let mut code = 0
      let mut valid = digits.length() > 0
      for unit in digits.code_units() {
        let digit = unit.to_int()
        let value = if digit >= '0'.to_int() && digit <= '9'.to_int() {
          digit - '0'.to_int()
        } else if digit >= 'a'.to_int() && digit <= 'f'.to_int() {
          digit - 'a'.to_int() + 10
        } else if digit >= 'A'.to_int() && digit <= 'F'.to_int() {
          digit - 'A'.to_int() + 10
        } else {
          -1
        }
        if value < 0 || value >= base {
          valid = false
        } else {
          code = code * base + value
        }
      }
      if valid && code > 0 && code < 0x80 {
        builder.write_char(code.unsafe_to_char())
      }
    } else {
      match body {
        "amp" => builder.write_char('&')
        "lt" => builder.write_char('<')
        "gt" => builder.write_char('>')
        "quot" => builder.write_char('"')
        "apos" => builder.write_char('\'')
        _ => ()
      }
    }
    at = cursor + 1
  }
  builder.to_string()
}

///|
/// Plans and queues one formatting batch over the session snapshot.
pub fn DocxEditSession::queue_format(
  self : DocxEditSession,
  format~ : @word.DocxDirectFormat,
  text? : String,
  within? : String,
  nth? : Int,
  range? : (Int, Int),
) -> (@word.DocxFormatReceipt, String?) raise @transaction.TransactionError {
  // A stable `p[id="…"]` scope resolves against THIS transaction's
  // snapshot, with the same typed refusals the read surfaces give.
  let resolved_within : String? = match within {
    Some(scope) => Some(resolve_stable_replace_scope(self, scope))
    None => None
  }
  let (plan, receipt) = @word.plan_docx_format(
    self.annotated,
    self.annotated.main_story_source(),
    format~,
    text?,
    within?=resolved_within,
    nth?,
    range?,
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  self.queue_plan(plan)
  (
    receipt,
    match (within, resolved_within) {
      (Some(requested), Some(resolved)) if requested != resolved =>
        Some(resolved)
      _ => None
    },
  )
}

///|
/// What the plan saw before it acted, kept so the readback judges the
/// edit against the document that was planned against rather than
/// against whatever the candidate happens to say.
///
/// Formatting never moves text, so the projection check alone would
/// pass on a document where nothing happened — and the direct-format
/// check alone would pass on one where far too much did. Together with
/// preservation they say: the paragraph still reads the same, the
/// selected spans carry the request EXPLICITLY, and no other formatting
/// in the paragraph changed.
priv struct FormatReadbackSnapshot {
  before : @word.DocxAnnotatedResult
  affected : Array[@word.DocxFormatAffected]
  spans : Array[@word.DocxFormatSpan]
}

///|
/// The three-check readback, as a validator.
fn format_readback_validator(
  snapshot : Ref[FormatReadbackSnapshot?],
  format : @word.DocxDirectFormat,
) -> @transaction.TransactionValidator raise @transaction.TransactionError {
  @transaction.transaction_validator("office-docx-format-readback", (
    candidate_format,
    _bytes,
    archive,
  ) => format_readback_findings(snapshot, format, candidate_format, archive))
}

///|
/// The three checks themselves, named rather than anonymous so the tests
/// can put a DOCTORED candidate in front of the very judgment the
/// transaction runs, instead of in front of a copy of it.
fn format_readback_findings(
  snapshot : Ref[FormatReadbackSnapshot?],
  format : @word.DocxDirectFormat,
  candidate_format : @office.DocumentFormat,
  archive : @zip.Archive,
) -> Array[@transaction.ValidationFinding] raise {
  let findings : Array[@transaction.ValidationFinding] = []
  if candidate_format != Docx {
    findings.push(
      @transaction.validation_finding(
        "docx.format.wrong_format", "format readback received a non-DOCX candidate",
      ),
    )
    return findings
  }
  let annotated = @word.read_docx_annotated_archive_limited(
    archive,
    candidate_xml_budget(),
  ) catch {
    error => {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_unreadable",
          docx_validator_message(
            "candidate could not be re-read for the format readback: \{docx_error_message(error)}",
          ),
        ),
      )
      return findings
    }
  }
  // A validator that cannot see what it is judging must never pass:
  // the snapshot is captured inside the session, and its ABSENCE is
  // a finding rather than an empty comparison.
  guard snapshot.val is Some(captured) else {
    findings.push(
      @transaction.validation_finding(
        "docx.format.readback_uncaptured",
        docx_validator_message(
          "the format readback has no plan-time snapshot to compare against",
        ),
      ),
    )
    return findings
  }
  let story = annotated.main_story_source()
  // (1) Every affected paragraph still projects what it did.
  for entry in captured.affected {
    match @word.docx_paragraph_projection(annotated, story, path=entry.path()) {
      Some(actual) =>
        if actual != entry.expected() {
          findings.push(
            @transaction.validation_finding(
              "docx.format.readback_mismatch",
              docx_validator_message(
                "paragraph \{entry.path()} reads back differently than the plan expected",
              ),
            ),
          )
        }
      None =>
        findings.push(
          @transaction.validation_finding(
            "docx.format.readback_missing",
            docx_validator_message(
              "paragraph \{entry.path()} no longer resolves in the candidate",
            ),
          ),
        )
    }
  }
  // The spans of each affected paragraph, grouped once.
  let by_paragraph : Map[String, Array[(Int, Int)]] = Map([])
  for span in captured.spans {
    let ranges = match by_paragraph.get(span.path()) {
      Some(existing) => existing
      None => {
        let created : Array[(Int, Int)] = []
        by_paragraph[span.path()] = created
        created
      }
    }
    ranges.push((span.start(), span.end()))
  }
  // (2) The selected spans carry the request EXPLICITLY.
  for entry in by_paragraph {
    let (path, ranges) = entry
    let verdict = @word.docx_paragraph_direct_format_spans(
      annotated,
      story,
      path~,
      spans=ranges,
      format~,
    ) catch {
      error => Some("could not be judged: \{docx_error_message(error)}")
    }
    if verdict is Some(discrepancy) {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_unformatted",
          docx_validator_message(
            "paragraph \{path} does not carry the requested formatting: \{discrepancy}",
          ),
        ),
      )
    }
  }
  // Every paragraph judged one way must be judged the other: a
  // paragraph in `affected` with no spans would go unformatted-checked,
  // and a span whose paragraph is not affected would go
  // unprojection-checked.
  let affected_paths : Map[String, Bool] = Map([])
  for entry in captured.affected {
    if affected_paths.get(entry.path()) is Some(_) {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_inconsistent",
          docx_validator_message(
            "paragraph \{entry.path()} appears twice in the plan's affected list",
          ),
        ),
      )
    }
    affected_paths[entry.path()] = true
  }
  for entry in by_paragraph {
    if affected_paths.get(entry.0) is None {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_inconsistent",
          docx_validator_message(
            "paragraph \{entry.0} carries selected spans but the plan did not report it as affected",
          ),
        ),
      )
    }
  }
  for path in affected_paths {
    if by_paragraph.get(path.0) is None {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_inconsistent",
          docx_validator_message(
            "paragraph \{path.0} was reported as affected but carries no selected span",
          ),
        ),
      )
    }
  }
  // (3) Nothing else about the paragraph's formatting moved.
  let original = captured.before
  let original_story = original.main_story_source()
  for entry in by_paragraph {
    let (path, ranges) = entry
    let verdict = @word.docx_paragraph_format_preserved(
      original,
      original_story,
      annotated,
      story,
      path~,
      spans=ranges,
      format~,
    ) catch {
      error => Some("could not be compared: \{docx_error_message(error)}")
    }
    if verdict is Some(discrepancy) {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_collateral",
          docx_validator_message(
            "paragraph \{path} changed formatting nobody asked for: \{discrepancy}",
          ),
        ),
      )
    }
  }
  findings
}

///|
/// One complete formatting transaction.
///
/// The policy points live HERE, not in the engine, because they are
/// caller policy about outcomes rather than facts about documents:
///
/// - the shared mutation preflight refuses a signed, protected, or
///   revision-tracking document before anything is planned;
/// - `expect` asserts the SELECTED span count; a mismatch refuses
///   before anything is published;
/// - zero selected without `allow_zero` refuses;
/// - a semantic no-op still runs every refusal and every readback, and
///   reports `changed=false` from the transaction rather than guessing;
/// - `preflight` lets the caller refuse over the REPORT it is about to
///   receive, before validation and publication.
pub async fn transact_docx_format(
  options : @transaction.TransactionOptions,
  format~ : @word.DocxDirectFormat,
  text? : String,
  within? : String,
  nth? : Int,
  range? : (Int, Int),
  expect? : Int,
  allow_zero? : Bool = false,
  preflight? : (DocxFormatReport) -> Unit raise,
) -> DocxFormatResult {
  let collected : Ref[DocxFormatReport?] = Ref(None)
  let snapshot : Ref[FormatReadbackSnapshot?] = Ref(None)
  let readback = format_readback_validator(snapshot, format)
  let transaction = transact_docx(
    options,
    session => {
      let before = session.annotated
      let (receipt, resolved_within) = session.queue_format(
        format~,
        text?,
        within?,
        nth?,
        range?,
      )
      // `expect` is checked FIRST, so `--expect 0` can hold: an
      // explicit assertion of zero is a satisfiable claim.
      let selected_count = receipt.spans().length()
      match expect {
        Some(count) =>
          if selected_count != count {
            raise @transaction.transaction_failure(
              "office.format.expect_mismatch",
              "expected \{count} span(s) but \{selected_count} were selected",
            )
          }
        None =>
          if selected_count == 0 && !allow_zero {
            raise @transaction.transaction_failure(
              "office.format.no_match", "no span was selected; pass allow-zero to treat that as success, or expect 0 to assert it",
            )
          }
      }
      snapshot.val = Some({
        before,
        affected: receipt.affected(),
        spans: receipt.spans(),
      })
      let report : DocxFormatReport = {
        mode: receipt.mode(),
        requested_text: receipt.requested_text(),
        requested_within: within,
        requested_nth: receipt.requested_nth(),
        requested_range: receipt.requested_range(),
        resolved_within,
        selected: receipt.selected(),
        spans: receipt.spans(),
        affected: receipt.affected(),
        runs_changed: receipt.runs_changed(),
        runs_already_satisfied: receipt.runs_already_satisfied(),
        splits: receipt.splits(),
        byte_edits: receipt.byte_edits(),
      }
      match preflight {
        Some(check) => check(report)
        None => ()
      }
      collected.val = Some(report)
    },
    validators=[readback],
  )
  guard collected.val is Some(report) else {
    raise docx_failure(
      "office.docx.edit_internal", "the format transaction returned no report",
    )
  }
  { report, transaction, }
}
