///|
fn xlsx_batch_failure(message : String, script : String) -> CliFailure {
  CliFailure(
    @lib.protocol_error(
      "office.xlsx.invalid_batch_script",
      bounded_text(message, 480),
      details=Json::object({ "script": Json::string(bounded_text(script, 160)) }),
    ),
  )
}

///|
fn xlsx_batch_stats_json(stats : @batch.BatchPlanStats) -> Json {
  Json::object({
    "operation_count": Json::number(stats.operation_count.to_double()),
    "touched_cells": Json::number(stats.touched_cells.to_double()),
    "style_cells": Json::number(stats.style_cells.to_double()),
    "row_column_lines": Json::number(stats.row_column_lines.to_double()),
    "new_style_records": Json::number(stats.new_style_records.to_double()),
  })
}

///|
fn xlsx_batch_result_json(result : @office_xlsx.XlsxBatchResult) -> Json {
  Json::object({
    "schema": Json::string(@lib.SCHEMA_XLSX_BATCH_RESULT),
    "stats": xlsx_batch_stats_json(result.stats),
    "transaction": result.transaction.to_json(),
  })
}

///|
fn xlsx_create_result_json(result : @office_xlsx.XlsxCreateResult) -> Json {
  Json::object({
    "schema": Json::string(@lib.SCHEMA_XLSX_CREATE_RESULT),
    "sheet": Json::string(result.sheet),
    "transaction": result.transaction.to_json(),
  })
}

///|
fn transaction_warnings(
  report : @transaction.TransactionReport,
) -> Array[@lib.ProtocolWarning] {
  let warnings = []
  for warning in report.warning_records() {
    warnings.push(warning)
  }
  warnings
}

///|
fn xlsx_operation_count_text(count : Int) -> String {
  if count == 1 {
    "1 operation"
  } else {
    "\{count} operations"
  }
}

///|
fn xlsx_cell_count_text(count : Int64) -> String {
  if count == 1L {
    "1 touched cell"
  } else {
    "\{count} touched cells"
  }
}

///|
fn print_xlsx_create_result(
  matches : @argparse.Matches,
  output : String,
  result : @office_xlsx.XlsxCreateResult,
) -> Unit {
  if matches.flags.get_or_default("json", false) {
    println(
      @lib.output_success(
        xlsx_create_result_json(result),
        warnings=transaction_warnings(result.transaction),
      ).stringify(indent=2),
    )
  } else {
    let subject = if result.transaction.committed {
      "created XLSX sheet"
    } else {
      "XLSX sheet"
    }
    println(
      "\{human_transaction_status(result.transaction)}: \{subject} \"\{human_text(result.sheet, 80)}\" -> \{human_text(output, 160)}",
    )
  }
}

///|
fn print_xlsx_batch_result(
  matches : @argparse.Matches,
  destination : String,
  result : @office_xlsx.XlsxBatchResult,
) -> Unit {
  if matches.flags.get_or_default("json", false) {
    println(
      @lib.output_success(
        xlsx_batch_result_json(result),
        warnings=transaction_warnings(result.transaction),
      ).stringify(indent=2),
    )
  } else {
    println(
      "\{human_transaction_status(result.transaction)}: \{xlsx_operation_count_text(result.stats.operation_count)}, \{xlsx_cell_count_text(result.stats.touched_cells)} -> \{human_text(destination, 160)}",
    )
  }
}

///|
fn checked_xlsx_create_options(
  matches : @argparse.Matches,
) -> @transaction.CreateTransactionOptions raise CliFailure {
  @transaction.create_transaction_options(
    required_value(matches, "output"),
    dry_run=matches.flags.get_or_default("dry-run", false),
    overwrite=matches.flags.get_or_default("overwrite", false),
  ) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error =>
      raise unexpected_cli_failure(
        "office.xlsx.create_failed", "XLSX creation option validation", error,
      )
  }
}

///|
async fn run_create_xlsx(matches : @argparse.Matches) -> Unit {
  let output = required_value(matches, "output")
  let sheet = optional_value(matches, "sheet").unwrap_or("Sheet1")
  let result = @office_xlsx.create_workbook(
    checked_xlsx_create_options(matches),
    sheet,
  ) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error if @async.is_being_cancelled() => raise error
    error =>
      raise unexpected_cli_failure(
        "office.xlsx.create_failed", "XLSX creation", error,
      )
  }
  print_xlsx_create_result(matches, output, result)
}

///|
async fn run_xlsx_batch(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let script = required_value(matches, "script")
  let encoded = read_bounded_file(
    script,
    @batch.MAX_BATCH_SCRIPT_BYTES,
    "office.xlsx.batch_script_read_failed",
    "batch script",
    limit_code="office.xlsx.resource_limit",
  )
  let plan = @office_xlsx.parse_batch(encoded) catch {
    BatchError(message) => raise xlsx_batch_failure(message, script)
  }
  let result = @office_xlsx.transact_batch(
    checked_transaction_options(matches),
    plan,
  ) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error if @async.is_being_cancelled() => raise error
    error =>
      raise unexpected_cli_failure(
        "office.xlsx.batch_failed", "XLSX batch transaction", error,
      )
  }
  let destination = optional_value(matches, "out").unwrap_or(file)
  print_xlsx_batch_result(matches, destination, result)
}

///|
fn create_command() -> @argparse.Command {
  Command(
    "create",
    about="Create a validated Office document atomically",
    subcommand_required=true,
    subcommands=[
      Command(
        "xlsx",
        about="Create a validated workbook with one worksheet",
        positionals=[
          PositionArg(
            "output",
            about="new .xlsx destination",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
        options=[
          OptionArg(
            "sheet",
            long="sheet",
            about="name of the first worksheet",
            default_values=["Sheet1"],
          ),
        ],
        flags=[
          FlagArg(
            "dry-run",
            long="dry-run",
            about="validate without publishing",
          ),
          FlagArg(
            "overwrite",
            long="overwrite",
            about="replace an existing regular-file destination",
          ),
          FlagArg("json", long="json", about="print office.output/1 JSON"),
        ],
      ),
    ],
  )
}

///|
fn batch_command() -> @argparse.Command {
  Command(
    "batch",
    about="Apply one strict XLSX operation script transactionally",
    positionals=[
      PositionArg(
        "file",
        about="existing .xlsx package",
        num_args=@argparse.ValueRange::single(),
      ),
      PositionArg(
        "script",
        about="strict xlsx.batch/1 JSON script",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[
      OptionArg(
        "out",
        long="out",
        about="publish to a separate .xlsx path instead of replacing the input",
      ),
    ],
    flags=[
      FlagArg("dry-run", long="dry-run", about="validate without publishing"),
      FlagArg(
        "overwrite",
        long="overwrite",
        about="allow replacement of an existing separate --out destination",
      ),
      FlagArg("json", long="json", about="print office.output/1 JSON"),
    ],
  )
}

///|
async fn run_create(matches : @argparse.Matches) -> Unit {
  match matches.subcommand {
    Some(("xlsx", values)) => run_create_xlsx(values)
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "create requires the xlsx document format",
        ),
      )
  }
}
