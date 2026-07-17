///|
let xlsx_transaction_validator_name = "office-xlsx-bounded"

///|
let xlsx_transaction_max_findings = 64

///|
let xlsx_transaction_max_message_chars = 480

///|
priv suberror LimitedXlsxWrite {
  LimitedXlsxWrite
}

///|
fn bounded_xlsx_message(text : String, limit : Int) -> String {
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
fn xlsx_transaction_failure(
  code : String,
  message : String,
  details? : Json,
) -> @transaction.TransactionError raise @transaction.TransactionError {
  match details {
    Some(value) =>
      @transaction.transaction_failure(code, message, details=value)
    None => @transaction.transaction_failure(code, message)
  }
}

///|
fn xlsx_read_limits() -> @engine.ReadLimits {
  @engine.ReadLimits::new()
}

///|
fn read_transaction_workbook(
  archive : @zip.Archive,
) -> @engine.Workbook raise @transaction.TransactionError {
  @engine.read_bounded_archive(archive, limits=xlsx_read_limits()) catch {
    error =>
      raise xlsx_transaction_failure(
        "office.xlsx.invalid_package",
        "could not read the bounded XLSX package: " +
        bounded_xlsx_message(repr(error), xlsx_transaction_max_message_chars),
      )
  }
}

///|
fn serialize_transaction_workbook(
  workbook : @engine.Workbook,
  maximum : Int,
) -> Bytes raise @transaction.TransactionError {
  let limit_hit = Ref(false)
  workbook.set_zip_writer(archive => {
    @zip.write_limited(archive, max_output_bytes=maximum) catch {
      OutputLimitExceeded(_) => {
        limit_hit.val = true
        raise LimitedXlsxWrite
      }
      error => raise error
    }
  })
  @excel.write(workbook) catch {
    _ if limit_hit.val =>
      raise xlsx_transaction_failure(
        "office.transaction.resource_limit_exceeded",
        "serialized XLSX candidate exceeds the transaction package allowance",
        details=Json::object({
          "phase": Json::string("candidate package"),
          "kind": Json::string("package_bytes"),
          "limit": Json::number(maximum.to_double()),
        }),
      )
    error =>
      raise xlsx_transaction_failure(
        "office.xlsx.serialization_failed",
        "could not serialize XLSX candidate: " +
        bounded_xlsx_message(repr(error), xlsx_transaction_max_message_chars),
      )
  }
}

///|
fn xlsx_transaction_validator() -> @transaction.TransactionValidator raise @transaction.TransactionError {
  @transaction.transaction_validator(xlsx_transaction_validator_name, (
    format,
    _bytes,
    archive,
  ) => {
    if !(format is Xlsx) {
      raise xlsx_transaction_failure(
        "office.xlsx.format_mismatch",
        "XLSX validation received a \{format.name()} candidate",
      )
    }
    // A complete bounded parse catches semantic/package-graph defects the
    // format-neutral portable detector intentionally does not interpret.
    ignore(read_transaction_workbook(archive.fork()))
    let problems = @engine.validate_ooxml_bounded_archive(
      archive,
      limits=xlsx_read_limits(),
    )
    let findings = []
    let retained = if problems.length() < xlsx_transaction_max_findings {
      problems.length()
    } else {
      xlsx_transaction_max_findings - 1
    }
    for index in 0..<retained {
      findings.push(
        @transaction.validation_finding(
          "office.xlsx.package",
          bounded_xlsx_message(
            problems[index],
            xlsx_transaction_max_message_chars,
          ),
        ),
      )
    }
    if problems.length() > retained {
      findings.push(
        @transaction.validation_finding(
          "office.xlsx.package_findings_omitted", "additional XLSX package findings were omitted after the bounded validator limit",
        ),
      )
    }
    findings
  })
}

///|
fn full_rewrite_warning() -> @office.ProtocolWarning {
  @office.protocol_warning(
    "office.xlsx.full_rewrite", "XLSX batch mutation performs a full workbook serialization; the transaction preservation report is authoritative for changed, added, removed, and unchanged part payloads",
  )
}

///|
/// Result of one strict XLSX batch transaction.
pub struct XlsxBatchResult {
  stats : @batch.BatchPlanStats
  transaction : @transaction.TransactionReport
}

///|
/// Result of one fresh XLSX creation transaction.
pub struct XlsxCreateResult {
  sheet : String
  transaction : @transaction.TransactionReport
}

///|
/// Parses one encoded, strict and resource-bounded `xlsx.batch/1` plan.
pub fn parse_batch(
  data : BytesView,
) -> @batch.BatchPlan raise @batch.BatchError {
  @batch.parse_script_bytes(data)
}

///|
/// Applies a parsed plan to an existing XLSX package through the shared Office
/// transaction boundary. A true in-place zero-op plan reuses the exact source
/// bytes; a separate `output_path` still publishes a validated copy.
pub async fn transact_batch(
  options : @transaction.TransactionOptions,
  plan : @batch.BatchPlan,
) -> XlsxBatchResult {
  let stats = plan.stats()
  let validator = xlsx_transaction_validator()
  let report = @transaction.transact(
    options,
    (format, _bytes, archive, budget) => {
      if !(format is Xlsx) {
        raise xlsx_transaction_failure(
          "office.xlsx.format_mismatch",
          "office batch requires an XLSX package, received \{format.name()}",
        )
      }
      let workbook = read_transaction_workbook(archive)
      plan.apply(workbook) catch {
        BatchError(message) =>
          raise xlsx_transaction_failure(
            "office.xlsx.batch_operation_failed",
            bounded_xlsx_message(message, xlsx_transaction_max_message_chars),
          )
      }
      if plan.operation_count() == 0 {
        @transaction.transaction_reuse_original()
      } else {
        let candidate = serialize_transaction_workbook(
          workbook,
          budget.max_candidate_package_bytes(),
        )
        @transaction.transaction_mutation(candidate, warnings=[
          full_rewrite_warning(),
        ])
      }
    },
    validators=[validator],
  )
  { stats, transaction: report }
}

///|
/// Creates one fresh XLSX workbook with exactly one named worksheet, validates
/// the complete candidate and publishes it atomically unless this is a dry run.
pub async fn create_workbook(
  options : @transaction.CreateTransactionOptions,
  sheet : String,
) -> XlsxCreateResult {
  let validator = xlsx_transaction_validator()
  let report = @transaction.transact_create(
    options,
    Xlsx,
    budget => {
      let workbook = @excel.new_workbook()
      ignore(workbook.add_sheet(sheet))
      @transaction.transaction_mutation(
        serialize_transaction_workbook(
          workbook,
          budget.max_candidate_package_bytes(),
        ),
      )
    },
    validators=[validator],
  )
  { sheet, transaction: report }
}
