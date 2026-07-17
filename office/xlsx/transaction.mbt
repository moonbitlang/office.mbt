///|
let xlsx_transaction_validator_name = "office-xlsx-bounded"

///|
let xlsx_transaction_max_findings = 64

///|
let xlsx_transaction_max_message_chars = 480

///|
/// The A4 transaction reserves 64 MiB for format-specific parser and serializer
/// state. The public Office policy constants divide that reserve between
/// bounded decoded XML/cell objects, the generated uncompressed archive, and
/// transient serializer indexes.

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
fn xlsx_read_limits() -> @engine.ReadLimits raise @engine.XlsxError {
  @engine.ReadLimits::with_values(
    max_xml_part_bytes=@office.XLSX_TRANSACTION_MAX_CANDIDATE_ENTRY_BYTES,
    max_total_xml_bytes=@office.XLSX_TRANSACTION_MAX_DECODED_XML_BYTES,
    max_xml_markup_tokens=@office.XLSX_TRANSACTION_MAX_XML_MARKUP_TOKENS,
    max_materialized_cells=@office.XLSX_TRANSACTION_MAX_MATERIALIZED_CELLS,
    max_materialized_row_column_dimensions=@office.XLSX_TRANSACTION_MAX_ROW_COLUMN_LINES,
  )
}

///|
fn read_transaction_workbook(
  archive : @zip.Archive,
) -> @engine.Workbook raise @transaction.TransactionError {
  @engine.read_bounded_archive(archive, limits=xlsx_read_limits()) catch {
    ResourceLimitExceeded(kind~, limit~, actual~) =>
      raise xlsx_transaction_failure(
        "office.transaction.resource_limit_exceeded",
        "XLSX source parsing exceeded its bounded materialization policy",
        details=Json::object({
          "phase": Json::string("source parsing"),
          "kind": Json::string(kind),
          "limit": Json::number(limit.to_double()),
          "actual": Json::number(actual.to_double()),
        }),
      )
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
  budget : @transaction.TransactionBudget,
) -> Bytes raise @transaction.TransactionError {
  let maximum = budget.max_candidate_package_bytes()
  if maximum <= 0 {
    raise xlsx_transaction_failure(
      "office.transaction.resource_limit_exceeded",
      "no live-memory allowance remains for an XLSX candidate package",
      details=Json::object({
        "phase": Json::string("candidate package"),
        "kind": Json::string("package_bytes"),
        "limit": Json::number(0.0),
        "actual": Json::number(1.0),
      }),
    )
  }
  let entry_limit = if budget.max_entry_uncompressed_bytes() <
    @office.XLSX_TRANSACTION_MAX_CANDIDATE_ENTRY_BYTES {
    budget.max_entry_uncompressed_bytes()
  } else {
    @office.XLSX_TRANSACTION_MAX_CANDIDATE_ENTRY_BYTES
  }
  let archive_limit = if budget.max_total_uncompressed_bytes() <
    @office.XLSX_TRANSACTION_MAX_CANDIDATE_ARCHIVE_BYTES {
    budget.max_total_uncompressed_bytes()
  } else {
    @office.XLSX_TRANSACTION_MAX_CANDIDATE_ARCHIVE_BYTES
  }
  let limits = @engine.WriteLimits::with_values(
    max_output_bytes=maximum,
    max_archive_entries=budget.max_archive_entries(),
    max_entry_uncompressed_bytes=entry_limit,
    max_total_uncompressed_bytes=archive_limit,
  ) catch {
    error =>
      raise xlsx_transaction_failure(
        "office.transaction.invalid_contract",
        "could not construct the bounded XLSX write policy: " +
        bounded_xlsx_message(repr(error), xlsx_transaction_max_message_chars),
      )
  }
  @engine.write_limited(workbook, limits) catch {
    ResourceLimitExceeded(kind~, limit~, actual~) =>
      raise xlsx_transaction_failure(
        "office.transaction.resource_limit_exceeded",
        "XLSX candidate serialization exceeded its bounded construction policy",
        details=Json::object({
          "phase": Json::string("candidate serialization"),
          "kind": Json::string(kind),
          "limit": Json::number(limit.to_double()),
          "actual": Json::number(actual.to_double()),
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
fn enforce_batch_materialization_budget(
  workbook : @engine.Workbook,
  stats : @batch.BatchPlanStats,
) -> Unit raise @transaction.TransactionError {
  let existing = workbook.materialized_cell_count().to_int64()
  let maximum = @office.XLSX_TRANSACTION_MAX_MATERIALIZED_CELLS.to_int64()
  let requested = existing + stats.touched_cells
  if requested > maximum {
    raise xlsx_transaction_failure(
      "office.transaction.resource_limit_exceeded",
      "XLSX batch could exceed the bounded workbook cell materialization allowance",
      details=Json::object({
        "phase": Json::string("batch application"),
        "kind": Json::string("materialized_cells"),
        "limit": Json::number(maximum.to_double()),
        "actual": Json::number(requested.to_double()),
      }),
    )
  }
  let existing_lines = workbook
    .materialized_row_column_dimension_count()
    .to_int64()
  let requested_lines = existing_lines + stats.row_column_lines
  if requested_lines > @office.XLSX_TRANSACTION_MAX_ROW_COLUMN_LINES.to_int64() {
    raise xlsx_transaction_failure(
      "office.transaction.resource_limit_exceeded",
      "XLSX batch could exceed the bounded row/column materialization allowance",
      details=Json::object({
        "phase": Json::string("batch application"),
        "kind": Json::string("row_column_lines"),
        "limit": Json::number(
          @office.XLSX_TRANSACTION_MAX_ROW_COLUMN_LINES.to_double(),
        ),
        "actual": Json::number(requested_lines.to_double()),
      }),
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
      enforce_batch_materialization_budget(workbook, stats)
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
        let candidate = serialize_transaction_workbook(workbook, budget)
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
      ignore(
        workbook.add_sheet(sheet) catch {
          error =>
            raise xlsx_transaction_failure(
              "office.xlsx.invalid_sheet_name",
              "could not create the first worksheet: " +
              bounded_xlsx_message(
                repr(error),
                xlsx_transaction_max_message_chars,
              ),
            )
        },
      )
      @transaction.transaction_mutation(
        serialize_transaction_workbook(workbook, budget),
      )
    },
    validators=[validator],
  )
  { sheet, transaction: report }
}
