///|
/// Ceiling on the template data document `office template` will read.
let office_template_max_data_bytes : Int = 8 * 1024 * 1024

///|
fn template_findings_json(
  findings : Array[@office_xlsx.XlsxTemplateFinding],
) -> Json {
  Json::array(
    findings.map(entry => {
      Json::object({
        "location": Json::string(bounded_text(entry.location, 160)),
        "detail": Json::string(bounded_text(entry.detail, 160)),
      })
    }),
  )
}

///|
/// The office.template/1 record, shared by the success envelope and the
/// strict-refusal failure details.
fn template_report_json(
  file : String,
  data_file : String,
  output : String,
  report : @office_xlsx.XlsxTemplateReport,
  transaction? : Json,
) -> Json {
  let fields : Map[String, Json] = {
    "schema": Json::string(@lib.SCHEMA_TEMPLATE_RESULT),
    "file": Json::string(bounded_text(file, 160)),
    "format": Json::string("xlsx"),
    "data_file": Json::string(bounded_text(data_file, 160)),
    "output": Json::string(bounded_text(output, 160)),
    "placeholders_found": Json::number(report.placeholders_found.to_double()),
    "replaced": Json::number(report.replaced.to_double()),
    "escapes_applied": Json::number(report.escapes_applied.to_double()),
    "distinct_keys_used": Json::number(report.distinct_keys_used.to_double()),
    "missing": template_findings_json(report.missing),
    "unused": Json::array(
      report.unused.map(key => Json::string(bounded_text(key, 80))),
    ),
    "malformed": template_findings_json(report.malformed),
    "unsupported": template_findings_json(report.unsupported),
    "locations": template_findings_json(report.locations),
    "locations_truncated": Json::boolean(report.locations_truncated),
    "missing_total": Json::number(report.missing_total.to_double()),
    "malformed_total": Json::number(report.malformed_total.to_double()),
    "unsupported_total": Json::number(report.unsupported_total.to_double()),
    "unused_total": Json::number(report.unused_total.to_double()),
  }
  match transaction {
    Some(value) => fields["transaction"] = value
    None => ()
  }
  Json::object(fields)
}

///|
async fn run_template(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let data_file = required_value(matches, "data")
  let output = required_value(matches, "out")
  let allow_missing = matches.flags.get_or_default("allow-missing", false)
  let mode = office_validate_output_mode(matches)
  guard output.to_lower().has_suffix(".xlsx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--out must end in .xlsx (template v1 is XLSX-only)",
      ),
    )
  }
  let data_bytes = read_bounded_file(
    data_file,
    office_template_max_data_bytes,
    "office.template.data_read_failed",
    "template data document",
    limit_code="office.template.resource_limit",
  )
  let data_text = @utf8.decode(data_bytes, ignore_bom=true) catch {
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.template.invalid_data", "template data document is not valid UTF-8",
        ),
      )
  }
  let values = @template.parse_template_data(data_text) catch {
    @template.TemplateDataError(reason) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.template.invalid_data",
          "invalid template data: " + bounded_text(reason, 200),
        ),
      )
  }
  let options = @transaction.transaction_options(
    file,
    output_path=output,
    dry_run=matches.flags.get_or_default("dry-run", false),
    overwrite=matches.flags.get_or_default("overwrite", false),
  ) catch {
    error => raise transaction_failure(error)
  }
  let result = @office_xlsx.transact_template(options, values, allow_missing~) catch {
    @office_xlsx.XlsxTemplateRefused(report) => {
      // strict findings: precedence malformed > unsupported > missing
      let (code, message) = if report.malformed.length() > 0 {
        (
          "office.template.malformed_placeholder", "the template carries malformed placeholders",
        )
      } else if report.unsupported.length() > 0 {
        (
          "office.template.unsupported_context", "the template carries placeholders in unsupported contexts",
        )
      } else {
        (
          "office.template.missing_keys", "the data document does not supply every placeholder key",
        )
      }
      raise CliFailure(
        @lib.protocol_error(
          code,
          message,
          details=template_report_json(file, data_file, output, report),
        ),
      )
    }
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error if @async.is_being_cancelled() => raise error
    error =>
      raise unexpected_cli_failure(
        "office.template.failed", "template transaction", error,
      )
  }
  let record = template_report_json(
    file,
    data_file,
    output,
    result.report,
    transaction=result.transaction.to_json(),
  )
  match mode {
    JsonDocument => println(@lib.output_success(record).stringify(indent=2))
    JsonLines => println(@lib.output_success(record).stringify())
    Human =>
      println(
        "template: \{result.report.replaced} replaced, " +
        "\{result.report.missing.length()} missing, " +
        "\{result.report.unused.length()} unused -> " +
        human_text(output, 160),
      )
  }
}

///|
fn template_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("template") {
    Some(command) => command.summary
    None => "Merge strict template data into an Office document"
  }
  Command(
    "template",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="existing .xlsx template package",
        num_args=@argparse.ValueRange::single(),
      ),
      PositionArg(
        "data",
        about="office.template.data/1 JSON document",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[
      OptionArg(
        "out",
        long="out",
        about="destination .xlsx path (the template is never modified)",
      ),
    ],
    flags=[
      FlagArg("dry-run", long="dry-run", about="validate without publishing"),
      FlagArg(
        "overwrite",
        long="overwrite",
        about="replace an existing destination",
      ),
      FlagArg(
        "allow-missing",
        long="allow-missing",
        about="keep unresolved placeholders as literals instead of failing",
      ),
      FlagArg("json", long="json", about="print office.output/1 JSON"),
      FlagArg("jsonl", long="jsonl", about="print one office.output/1 line"),
    ],
  )
}
