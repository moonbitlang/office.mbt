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
  priv original : Bytes
  priv archive : @zip.Archive
  priv annotated : @word.DocxAnnotatedResult
  priv fingerprints : Array[DocxPartFingerprint]
  priv max_candidate_package_bytes : Int
  priv mut plan : @splice.SplicePlan
}

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
/// Opens a DOCX edit session only from the bounded archive provenance supplied
/// by `office/transaction`. The source receives strict OPC validation and one
/// archive-backed annotation/span index without a second ZIP inflation.
pub fn open_edit_session(
  original : Bytes,
  archive : @zip.Archive,
  budget : @transaction.TransactionBudget,
) -> DocxEditSession raise @transaction.TransactionError {
  if !budget.source_archive_is_bounded(original, archive) {
    raise docx_failure(
      "office.docx.unbounded_source", "DOCX edit sessions require the pristine bounded archive supplied by office/transaction",
    )
  }
  let archive = archive.fork()
  let findings = @opc.validate_docx_archive(archive)
  if !findings.is_empty() {
    let duplicate = findings.search_by(fn(finding) {
      finding.has_prefix("duplicate entry name:")
    })
    let code = if duplicate is Some(_) {
      "office.docx.duplicate_part"
    } else {
      "office.docx.invalid_package"
    }
    raise docx_failure(
      code,
      "source DOCX failed strict package validation",
      details=Json::object({
        "finding_count": Json::number(findings.length().to_double()),
        "first_finding": Json::string(bounded_docx_text(findings[0], 320)),
      }),
    )
  }
  let annotated = @word.read_docx_annotated_archive(archive) catch {
    error =>
      raise docx_failure(
        "office.docx.invalid_package",
        "source DOCX could not be indexed: \{docx_error_message(error)}",
      )
  }
  {
    original,
    archive,
    annotated,
    fingerprints: source_fingerprints(archive),
    max_candidate_package_bytes: budget.max_candidate_package_bytes(),
    plan: @splice.SplicePlan::new(),
  }
}

///|
/// Exact immutable source package bytes owned by this session.
pub fn DocxEditSession::source_bytes(self : DocxEditSession) -> Bytes {
  self.original
}

///|
/// One immutable source part payload, when present.
pub fn DocxEditSession::source_part(
  self : DocxEditSession,
  part : String,
) -> Bytes? {
  self.archive.get(part)
}

///|
/// Package, annotation, and original-byte span indexes for this source.
pub fn DocxEditSession::annotated(
  self : DocxEditSession,
) -> @word.DocxAnnotatedResult {
  self.annotated
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
  let unpinned = plan.unpinned_edited_parts()
  if !unpinned.is_empty() {
    raise docx_failure(
      "office.docx.unpinned_plan",
      "preservation-safe DOCX sessions require exact source bytes for every edited part",
      details=Json::object({
        "parts": Json::array(
          unpinned.map(fn(part) { Json::string(bounded_docx_text(part, 320)) }),
        ),
      }),
    )
  }
  let candidate = self.plan.copy()
  candidate.merge(plan) catch {
    error => raise mapped_plan_failure(error)
  }
  candidate.check_against(self.archive, require_pins=true) catch {
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
pub fn DocxEditSession::finish(
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
    let raw = @opc.validate_docx_archive(archive)
    let findings : Array[@transaction.ValidationFinding] = []
    let limit = if raw.length() <= 64 { raw.length() } else { 63 }
    for index in 0..<limit {
      findings.push(
        @transaction.validation_finding(
          "docx.package.invalid",
          docx_validator_message(raw[index]),
        ),
      )
    }
    if raw.length() > 64 {
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
    (format, original, archive, budget) => {
      if format != Docx {
        raise docx_failure(
          "office.docx.wrong_format",
          "DOCX edit transaction received a \{format.name()} package",
        )
      }
      let session = open_edit_session(original, archive, budget)
      edit(session)
      session.finish()
    },
    validators~,
  )
}
