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
  mode : String
  requested_text : String?
  requested_within : String?
  requested_nth : Int?
  requested_range : (Int, Int)?
  resolved_within : String?
  selected : Array[Int]
  spans : Array[@word.DocxFormatSpan]
  affected : Array[@word.DocxFormatAffected]
  runs_changed : Int
  runs_already_satisfied : Int
  splits : Int
  byte_edits : Int
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
  self.selected
}

///|
/// The selected spans.
pub fn DocxFormatReport::spans(
  self : DocxFormatReport,
) -> Array[@word.DocxFormatSpan] {
  self.spans
}

///|
/// The affected paragraphs, with the projections they must still read.
pub fn DocxFormatReport::affected(
  self : DocxFormatReport,
) -> Array[@word.DocxFormatAffected] {
  self.affected
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
/// A signed package's signature covers the parts being edited, so any
/// edit invalidates it silently. Enforced protection is the author's
/// standing instruction that the document is not to be changed. And a
/// document in tracked-changes mode expects every edit to arrive as a
/// revision — writing an untracked one would misrepresent it as the
/// author's own text. None of these is a formatting question, which is
/// why this lives beside the session rather than inside the planner:
/// every mutating verb should reach it.
pub fn docx_mutation_preflight(
  archive : @zip.Archive,
) -> Unit raise @transaction.TransactionError {
  for entry in archive.entries() {
    let name = entry.name()
    if name.has_prefix("_xmlsignatures/") {
      raise @transaction.transaction_failure(
        "office.docx.signed_package", "this package carries a digital signature, which any edit would invalidate",
      )
    }
  }
  guard archive.get("word/settings.xml") is Some(settings) else { return }
  let text = @utf8.decode(settings) catch { _ => return }
  if docx_settings_enforces_protection(text) {
    raise @transaction.transaction_failure(
      "office.docx.protected_document", "this document enforces editing protection; unprotect it before formatting",
    )
  }
  if docx_settings_tracks_revisions(text) {
    raise @transaction.transaction_failure(
      "office.docx.track_revisions", "this document records revisions; formatting it would write an untracked change",
    )
  }
}

///|
/// Whether `w:documentProtection` is present AND enforced. An
/// unenforced protection element is a stored preference, not an
/// instruction.
fn docx_settings_enforces_protection(settings : String) -> Bool {
  guard settings.contains("documentProtection") else { return false }
  match docx_settings_attribute(settings, "documentProtection", "enforcement") {
    Some(value) => value is ("1" | "true" | "on")
    None => false
  }
}

///|
/// Whether the document is in tracked-changes mode. The element's own
/// `w:val` may turn it off, and an absent val means on.
fn docx_settings_tracks_revisions(settings : String) -> Bool {
  guard settings.contains("trackRevisions") else { return false }
  match docx_settings_attribute(settings, "trackRevisions", "val") {
    Some(value) => value is ("1" | "true" | "on")
    None => true
  }
}

///|
/// One attribute of one settings element, read lexically over the
/// part's bytes: the element by local name, the attribute by local
/// name, both prefix-blind because a settings part may bind WML under
/// any prefix.
fn docx_settings_attribute(
  settings : String,
  element : String,
  attribute : String,
) -> String? {
  let bytes = @utf8.encode(settings)
  let limit = bytes.length()
  fn space(at : Int) -> Bool {
    bytes[at] is (b' ' | b'\t' | b'\n' | b'\r')
  }

  fn text(from : Int, to : Int) -> String {
    let builder = StringBuilder()
    for index in from..<to {
      if bytes[index] < b'\x80' {
        builder.write_char(bytes[index].to_int().unsafe_to_char())
      }
    }
    builder.to_string()
  }

  fn local_of(qname : String) -> String {
    let mut colon = -1
    for index, unit in qname.code_units() {
      if unit.to_int() == ':'.to_int() {
        colon = index
      }
    }
    if colon < 0 {
      qname
    } else {
      qname.substring(start=colon + 1, end=qname.length()).to_string()
    }
  }

  let mut at = 0
  while at < limit {
    if bytes[at] != b'<' {
      at += 1
      continue
    }
    at += 1
    if at < limit &&
      (bytes[at] == b'/' || bytes[at] == b'!' || bytes[at] == b'?') {
      continue
    }
    let name_start = at
    while at < limit && bytes[at] != b'>' && bytes[at] != b'/' && !space(at) {
      at += 1
    }
    if local_of(text(name_start, at)) != element {
      continue
    }
    // Inside this element's open tag: read its attributes.
    while at < limit && bytes[at] != b'>' {
      while at < limit && (space(at) || bytes[at] == b'/') {
        at += 1
      }
      if at >= limit || bytes[at] == b'>' {
        break
      }
      let attribute_start = at
      while at < limit && bytes[at] != b'=' && !space(at) && bytes[at] != b'>' {
        at += 1
      }
      let found = local_of(text(attribute_start, at))
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
      if found == attribute {
        return Some(text(value_start, at))
      }
      at += 1
    }
    // The first element of this name answers; a settings part carries
    // one of each, and guessing among duplicates is not this
    // preflight's business.
    return None
  }
  None
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
/// The three-check readback.
///
/// Formatting never moves text, so the projection check alone would
/// pass on a document where nothing happened — and the direct-format
/// check alone would pass on one where far too much did. Together with
/// preservation they say: the paragraph still reads the same, the
/// selected spans carry the request EXPLICITLY, and no other formatting
/// in the paragraph changed.
fn format_readback_validator(
  before : Ref[@word.DocxAnnotatedResult?],
  affected : Ref[Array[@word.DocxFormatAffected]],
  spans : Ref[Array[@word.DocxFormatSpan]],
  format : @word.DocxDirectFormat,
) -> @transaction.TransactionValidator raise @transaction.TransactionError {
  @transaction.transaction_validator("office-docx-format-readback", (
    candidate_format,
    _bytes,
    archive,
  ) => {
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
    let story = annotated.main_story_source()
    // (1) Every affected paragraph still projects what it did.
    for entry in affected.val {
      match
        @word.docx_paragraph_projection(annotated, story, path=entry.path()) {
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
    for span in spans.val {
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
    // (3) Nothing else about the paragraph's formatting moved.
    guard before.val is Some(original) else {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_unreadable",
          docx_validator_message(
            "the format readback has no pre-edit snapshot to compare against",
          ),
        ),
      )
      return findings
    }
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
  })
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
  let before : Ref[@word.DocxAnnotatedResult?] = Ref(None)
  let affected : Ref[Array[@word.DocxFormatAffected]] = Ref([])
  let spans : Ref[Array[@word.DocxFormatSpan]] = Ref([])
  let readback = format_readback_validator(before, affected, spans, format)
  let transaction = transact_docx(
    options,
    session => {
      // Before anything is planned: the conditions under which this
      // toolkit declines to change a document at all.
      docx_mutation_preflight(session.archive)
      before.val = Some(session.annotated)
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
      affected.val = receipt.affected()
      spans.val = receipt.spans()
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
