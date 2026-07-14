///|
/// A stable, descriptive fingerprint for one source package part. Edit plans
/// additionally retain the exact immutable source bytes, so stale detection
/// does not rely on CRC collision resistance.
pub struct DocxPartFingerprint {
  priv part : String
  priv byte_length : Int
  priv crc32 : UInt
}

///|
/// Canonical relative ZIP entry name of the fingerprinted part.
pub fn DocxPartFingerprint::part(self : DocxPartFingerprint) -> String {
  self.part
}

///|
/// Uncompressed source payload length.
pub fn DocxPartFingerprint::byte_length(self : DocxPartFingerprint) -> Int {
  self.byte_length
}

///|
/// CRC-32 of the uncompressed source payload.
pub fn DocxPartFingerprint::crc32(self : DocxPartFingerprint) -> UInt {
  self.crc32
}

///|
/// A preservation-safe DOCX edit session over one immutable transaction
/// snapshot. All queued spans use original-part coordinates; the aggregate
/// plan is replaced only after a fully checked merge.
pub struct DocxEditSession {
  priv archive : @zip.Archive
  priv annotated : @word.DocxAnnotatedResult
  priv fingerprints : Array[DocxPartFingerprint]
  priv max_candidate_package_bytes : Int
  priv splice_limits : @splice.SpliceLimits
  priv mut plan : @splice.SplicePlan
}

///|
let candidate_xml_source_units : Int = 8 * 1024 * 1024

///|
let candidate_xml_tokens : Int = 131_072

///|
let candidate_xml_materialized_chars : Int = 8 * 1024 * 1024

///|
let candidate_xml_token_chars : Int = 8 * 1024 * 1024

///|
fn bounded_docx_text(text : String, limit : Int) -> String {
  let output = StringBuilder::new()
  let mut count = 0
  for character in text {
    if count == limit {
      output.write_string("…") |> ignore
      break
    }
    output.write_char(character) |> ignore
    count = count + 1
  }
  output.to_string()
}

///|
fn docx_error_message(error : @docxcore.DocxError) -> String {
  match error {
    InvalidZip(message~)
    | InvalidXml(message~)
    | MissingPart(message~)
    | Unsupported(message~) => message
  }
}

///|
fn is_xml_resource_finding(message : String) -> Bool {
  message.contains("XML source budget exceeded") ||
  message.contains("XML token budget exceeded") ||
  message.contains("XML token length budget exceeded") ||
  message.contains("XML materialized character budget exceeded")
}

///|
fn docx_failure(
  code : String,
  message : String,
  details? : Json,
) -> @transaction.TransactionError raise @transaction.TransactionError {
  let message = bounded_docx_text(message, 480)
  match details {
    Some(value) =>
      @transaction.transaction_failure(code, message, details=value)
    None => @transaction.transaction_failure(code, message)
  }
}

///|
fn mapped_plan_failure(
  error : @docxcore.DocxError,
) -> @transaction.TransactionError raise @transaction.TransactionError {
  let message = docx_error_message(error)
  let code = if message.contains("duplicate zip entries") ||
    message.contains("duplicate ZIP entry") {
    "office.docx.duplicate_part"
  } else if message.contains("splice plan is stale") ||
    message.contains("different source bytes") ||
    message.contains("conflicting source bytes") {
    "office.docx.stale_plan"
  } else if message.contains("overlap") {
    "office.docx.overlapping_edits"
  } else if message.contains("past the part") ||
    message.contains("cannot start at") ||
    message.contains("before its start") {
    "office.docx.invalid_range"
  } else if message.contains("malformed XML") {
    "office.docx.invalid_edit"
  } else if message.contains("UTF-16") ||
    message.contains("valid UTF-8") ||
    message.contains("declares encoding") ||
    message.contains("XML declaration") {
    "office.docx.unsupported_encoding"
  } else if message.contains("without pinned source bytes") {
    "office.docx.unpinned_plan"
  } else if message.contains("does not contain") ||
    message.contains("no longer present") ||
    message.contains("missing") {
    "office.docx.missing_part"
  } else if message.contains("output limit") {
    "office.docx.output_limit"
  } else if message.contains(" limit") ||
    message.contains("maximum addressable part size") {
    "office.docx.resource_limit"
  } else {
    "office.docx.invalid_plan"
  }
  docx_failure(code, message)
}

///|
fn source_fingerprints(archive : @zip.Archive) -> Array[DocxPartFingerprint] {
  let result : Array[DocxPartFingerprint] = []
  for entry in archive.entries() {
    result.push({
      part: entry.name(),
      byte_length: entry.data().length(),
      crc32: @zip.crc32(entry.data()),
    })
  }
  result.sort_by(fn(left, right) { left.part.compare(right.part) })
  result
}

///|
/// Opens a DOCX edit session only inside `transact_docx`, from its private
/// bounded archive and opaque mutation budget. The source receives strict OPC
/// validation and one archive-backed annotation/span index without a second
/// ZIP inflation.
fn open_edit_session(
  archive : @zip.Archive,
  budget : @transaction.TransactionBudget,
) -> DocxEditSession raise @transaction.TransactionError {
  let archive = archive.fork()
  let (findings, findings_truncated) = @opc.validate_docx_archive_limited(
    archive,
    max_findings=budget.max_validation_findings(),
    max_message_chars=budget.max_validation_message_chars(),
    max_xml_source_units=budget.max_splice_materialized_bytes(),
    max_xml_tokens=budget.max_splice_xml_tokens(),
    max_xml_materialized_chars=budget.max_splice_materialized_bytes(),
    max_xml_token_chars=budget.max_splice_materialized_bytes(),
  )
  if !findings.is_empty() {
    let duplicate = findings.search_by(fn(finding) {
      finding.has_prefix("duplicate entry name:")
    })
    let resource_limited = findings.search_by(is_xml_resource_finding)
    let code = if duplicate is Some(_) {
      "office.docx.duplicate_part"
    } else if resource_limited is Some(_) {
      "office.docx.resource_limit"
    } else {
      "office.docx.invalid_package"
    }
    raise docx_failure(
      code,
      "source DOCX failed strict package validation",
      details=Json::object({
        "reported_finding_count": Json::number(findings.length().to_double()),
        "findings_truncated": Json::boolean(findings_truncated),
        "first_finding": Json::string(bounded_docx_text(findings[0], 320)),
      }),
    )
  }
  let xml_budget = @xml.xml_read_budget(
    max_source_units=budget.max_splice_materialized_bytes(),
    max_tokens=budget.max_splice_xml_tokens(),
    max_materialized_chars=budget.max_splice_materialized_bytes(),
    max_token_chars=budget.max_splice_materialized_bytes(),
  )
  let annotated = @word.read_docx_annotated_archive_limited(archive, xml_budget) catch {
    error => {
      let message = docx_error_message(error)
      raise docx_failure(
        if is_xml_resource_finding(message) {
          "office.docx.resource_limit"
        } else {
          "office.docx.invalid_package"
        },
        "source DOCX could not be indexed: \{message}",
      )
    }
  }
  let splice_limits = @splice.splice_limits(
    max_archive_entries=budget.max_archive_entries(),
    max_changed_parts=budget.max_preservation_parts(),
    max_part_name_chars=budget.max_part_name_chars(),
    max_entry_uncompressed_bytes=budget.max_entry_uncompressed_bytes(),
    max_total_uncompressed_bytes=budget.max_total_uncompressed_bytes(),
    max_materialized_bytes=budget.max_splice_materialized_bytes(),
    max_xml_tokens=budget.max_splice_xml_tokens(),
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  {
    archive,
    annotated,
    fingerprints: source_fingerprints(archive),
    max_candidate_package_bytes: budget.max_candidate_package_bytes(),
    splice_limits,
    plan: @splice.SplicePlan::new(),
  }
}

///|
/// Package, annotation, and original-byte span indexes for this source.
pub fn DocxEditSession::annotated(
  self : DocxEditSession,
) -> @word.DocxAnnotatedResult {
  self.annotated
}

///|
/// Plans and atomically queues one comment addition against the session's
/// already materialized archive. No package bytes are exposed or reinflated.
pub fn DocxEditSession::queue_comment_addition(
  self : DocxEditSession,
  at_relative~ : String,
  to_relative~ : String,
  spec : @word.CommentSpec,
) -> String raise @transaction.TransactionError {
  let (plan, comment_id) = @word.plan_comment_addition_archive(
    self.annotated,
    self.archive,
    at_relative~,
    to_relative~,
    spec,
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  self.queue_plan(plan)
  comment_id
}

///|
/// Plans and atomically queues one comment reply against the session archive.
pub fn DocxEditSession::queue_comment_reply(
  self : DocxEditSession,
  parent_id~ : String,
  spec : @word.CommentSpec,
) -> String raise @transaction.TransactionError {
  let (plan, comment_id) = @word.plan_comment_reply_archive(
    self.annotated,
    self.archive,
    parent_id~,
    spec,
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  self.queue_plan(plan)
  comment_id
}

///|
/// Plans and atomically queues a comment resolve/unresolve operation against
/// the session archive.
pub fn DocxEditSession::queue_comment_resolution(
  self : DocxEditSession,
  comment_id~ : String,
  done~ : Bool,
) -> Unit raise @transaction.TransactionError {
  let plan = @word.plan_comment_resolution_archive(
    self.annotated,
    self.archive,
    comment_id~,
    done~,
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  self.queue_plan(plan)
}

///|
/// Sorted descriptive fingerprints for every source part.
pub fn DocxEditSession::source_part_fingerprints(
  self : DocxEditSession,
) -> Array[DocxPartFingerprint] {
  self.fingerprints.copy()
}

///|
/// Sorted exact preservation manifest currently planned for the transaction.
pub fn DocxEditSession::pending_parts(self : DocxEditSession) -> Array[String] {
  self.plan.declared_parts()
}

///|
/// True when finalization will explicitly reuse the transaction's exact input
/// bytes and allocate no candidate package.
pub fn DocxEditSession::is_noop(self : DocxEditSession) -> Bool {
  self.plan.is_empty()
}

///|
/// Atomically adopts a source-pinned splice plan. Unpinned edits are rejected;
/// stale sources, overlaps, ranges, encodings, and XML well-formedness are
/// checked against an isolated candidate before the session state changes.
pub fn DocxEditSession::queue_plan(
  self : DocxEditSession,
  plan : @splice.SplicePlan,
) -> Unit raise @transaction.TransactionError {
  // Bound and validate the incoming plan before copying any of its maps or
  // arrays into session state. This also rejects unpinned/stale sources.
  plan.check_against(self.archive, require_pins=true, limits=self.splice_limits) catch {
    error => raise mapped_plan_failure(error)
  }
  let candidate = self.plan.copy()
  candidate.merge(plan) catch {
    error => raise mapped_plan_failure(error)
  }
  candidate.check_against(
    self.archive,
    require_pins=true,
    limits=self.splice_limits,
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  self.plan = candidate
}

///|
/// Queues one original-coordinate edit and pins it to the exact current source
/// part. Use `queue_plan` when several edits must become valid atomically.
pub fn DocxEditSession::queue_span_edit(
  self : DocxEditSession,
  part : String,
  start~ : Int,
  end~ : Int,
  replacement : Bytes,
) -> Unit raise @transaction.TransactionError {
  guard self.archive.get(part) is Some(source) else {
    raise docx_failure(
      "office.docx.missing_part",
      "source DOCX does not contain part '\{bounded_docx_text(part, 320)}'",
    )
  }
  let edit = @splice.span_edit(start~, end~, replacement) catch {
    error => raise mapped_plan_failure(error)
  }
  let plan = @splice.SplicePlan::new()
  plan.pin_part(part, source) catch {
    error => raise mapped_plan_failure(error)
  }
  plan.edit_part(part, edit)
  self.queue_plan(plan)
}

///|
/// Queues one whole new package part. Relationship and content-type edits must
/// be declared in the same or another queued plan; the DOCX validator enforces
/// the resulting package before publication.
pub fn DocxEditSession::queue_added_part(
  self : DocxEditSession,
  part : String,
  bytes : Bytes,
) -> Unit raise @transaction.TransactionError {
  let plan = @splice.SplicePlan::new()
  plan.add_part(part, bytes) catch {
    error => raise mapped_plan_failure(error)
  }
  self.queue_plan(plan)
}

///|
/// Builds the opaque A4 mutation result. A true no-op reuses the transaction's
/// exact input buffer; edited candidates use the transaction output ceiling and
/// carry the exact sorted part manifest for the authoritative preservation
/// report.
fn DocxEditSession::finish(
  self : DocxEditSession,
) -> @transaction.TransactionMutation raise @transaction.TransactionError {
  let declared = self.plan.declared_parts()
  if self.plan.is_empty() {
    return @transaction.transaction_reuse_original_with_manifest([])
  }
  let candidate = @splice.splice_docx_archive(
    self.archive,
    self.plan,
    max_output_bytes=self.max_candidate_package_bytes,
    require_pins=true,
    limits=self.splice_limits,
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  @transaction.transaction_mutation_with_manifest(candidate, declared)
}

///|
fn docx_validator_message(text : String) -> String {
  bounded_docx_text(text, 480)
}

///|
/// Builds the strict archive-backed DOCX validator used by edit transactions.
/// It consumes the already inflated candidate archive and emits at most 64
/// bounded findings under one stable validator identity.
pub fn package_validator() -> @transaction.TransactionValidator raise @transaction.TransactionError {
  @transaction.transaction_validator("office-docx-package", (
    format,
    _bytes,
    archive,
  ) => {
    if format != Docx {
      return [
        @transaction.validation_finding(
          "docx.package.wrong_format", "DOCX package validator received a non-DOCX candidate",
        ),
      ]
    }
    let (raw, truncated) = @opc.validate_docx_archive_limited(
      archive,
      max_findings=64,
      max_message_chars=512,
      max_xml_source_units=candidate_xml_source_units,
      max_xml_tokens=candidate_xml_tokens,
      max_xml_materialized_chars=candidate_xml_materialized_chars,
      max_xml_token_chars=candidate_xml_token_chars,
    )
    let findings : Array[@transaction.ValidationFinding] = []
    let limit = if truncated && raw.length() == 64 { 63 } else { raw.length() }
    for index in 0..<limit {
      findings.push(
        @transaction.validation_finding(
          "docx.package.invalid",
          docx_validator_message(raw[index]),
        ),
      )
    }
    if truncated {
      findings.push(
        @transaction.validation_finding(
          "docx.package.additional_findings", "additional DOCX package findings were omitted from the bounded report",
        ),
      )
    }
    findings
  })
}

///|
/// Runs a complete async DOCX transaction: bounded read, session construction,
/// caller edits, strict candidate validation, preservation enforcement, source
/// conflict detection, and atomic publication. The returned transaction report
/// is the authoritative preservation report.
pub async fn transact_docx(
  options : @transaction.TransactionOptions,
  edit : (DocxEditSession) -> Unit raise,
  validators? : Array[@transaction.TransactionValidator] = [],
) -> @transaction.TransactionReport {
  let validators = validators.copy()
  validators.insert(0, package_validator())
  @transaction.transact(
    options,
    (format, _original, archive, budget) => {
      if format != Docx {
        raise docx_failure(
          "office.docx.wrong_format",
          "DOCX edit transaction received a \{format.name()} package",
        )
      }
      let session = open_edit_session(archive, budget)
      edit(session)
      session.finish()
    },
    validators~,
  )
}
