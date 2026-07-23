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
  format : String,
  report : @office_xlsx.XlsxTemplateReport,
  transaction? : Json,
  stories? : Array[String],
  regions? : Array[Json] = [],
) -> Json {
  let fields : Map[String, Json] = {
    "schema": Json::string(@lib.SCHEMA_TEMPLATE_RESULT),
    "file": Json::string(bounded_text(file, 160)),
    "format": Json::string(format),
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
    "regions": Json::array(regions),
    "regions_total": Json::number(regions.length().to_double()),
  }
  match stories {
    Some(list) =>
      fields["stories_scanned"] = Json::array(
        list.map(story => Json::string(story)),
      )
    None => ()
  }
  match transaction {
    Some(value) => fields["transaction"] = value
    None => ()
  }
  Json::object(fields)
}

///|
/// Bridges the DOCX report into the shared XLSX report shape so one
/// JSON builder serves both formats (the record schemas are identical
/// except for locations grammar and stories_scanned).
fn docx_report_as_shared(
  report : @office_docx.DocxTemplateReport,
) -> @office_xlsx.XlsxTemplateReport {
  {
    placeholders_found: report.placeholders_found,
    replaced: report.replaced,
    escapes_applied: report.escapes_applied,
    distinct_keys_used: report.distinct_keys_used,
    missing: report.missing.map(entry => {
      (
        { location: entry.location, detail: entry.detail } :
        @office_xlsx.XlsxTemplateFinding)
    }),
    unused: report.unused,
    malformed: report.malformed.map(entry => {
      (
        { location: entry.location, detail: entry.detail } :
        @office_xlsx.XlsxTemplateFinding)
    }),
    unsupported: report.unsupported.map(entry => {
      (
        { location: entry.location, detail: entry.detail } :
        @office_xlsx.XlsxTemplateFinding)
    }),
    locations: report.locations.map(entry => {
      (
        { location: entry.location, detail: entry.detail } :
        @office_xlsx.XlsxTemplateFinding)
    }),
    locations_truncated: report.locations_truncated,
    missing_total: report.missing_total,
    malformed_total: report.malformed_total,
    unsupported_total: report.unsupported_total,
    unused_total: report.unused_total,
    changed: report.changed,
  }
}

///|
/// Serializes XLSX repeated-region outcomes into the shared regions
/// array; `output_rows` gives the final placement after all insertions.
fn xlsx_regions_json(
  regions : Array[@office_xlsx.XlsxRegionOutcome],
) -> Array[Json] {
  regions.map(region => {
    Json::object({
      "name": Json::string(bounded_text(region.name, 80)),
      "source_location": Json::string(bounded_text(region.source_location, 160)),
      "records": Json::number(region.records.to_double()),
      "replaced": Json::number(region.replaced.to_double()),
      "escapes_applied": Json::number(region.escapes_applied.to_double()),
      "output_rows": Json::object({
        "start": Json::number(region.output_rows_start.to_double()),
        "count": Json::number(region.output_rows_count.to_double()),
      }),
    })
  })
}

///|
/// Serializes DOCX repeated-region outcomes into the shared regions
/// array (a DOCX region emits one cloned row block, no sheet coords).
fn docx_regions_json(
  regions : Array[@office_docx.DocxRegionOutcome],
) -> Array[Json] {
  regions.map(region => {
    Json::object({
      "name": Json::string(bounded_text(region.name, 80)),
      "source_location": Json::string(bounded_text(region.source_location, 160)),
      "records": Json::number(region.records.to_double()),
      "replaced": Json::number(region.replaced.to_double()),
      "escapes_applied": Json::number(region.escapes_applied.to_double()),
    })
  })
}

///|
async fn run_template(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let data_file = required_value(matches, "data")
  let output = required_value(matches, "out")
  let allow_missing = matches.flags.get_or_default("allow-missing", false)
  let mode = office_validate_output_mode(matches)
  // dispatch by the template's extension; each transaction re-validates
  // the actual package format internally
  let is_docx = file.to_lower().has_suffix(".docx")
  let expected_suffix = if is_docx { ".docx" } else { ".xlsx" }
  guard output.to_lower().has_suffix(expected_suffix) else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments",
        "--out must end in \{expected_suffix} to match the template format",
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
  let data = @template.parse_template_document(data_text) catch {
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
  fn refusal(
    report : @office_xlsx.XlsxTemplateReport,
    format : String,
    stories : Array[String]?,
  ) -> CliFailure {
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
    CliFailure(
      @lib.protocol_error(
        code,
        message,
        details=template_report_json(
          file,
          data_file,
          output,
          format,
          report,
          stories?,
        ),
      ),
    )
  }
  let record = if is_docx {
    let result = @office_docx.transact_docx_template_document(
      options,
      data,
      allow_missing~,
    ) catch {
      @office_docx.DocxTemplateRefused(report) =>
        raise refusal(
          docx_report_as_shared(report),
          "docx",
          Some(report.stories_scanned),
        )
      @transaction.TransactionError(..) as error =>
        raise transaction_failure(error)
      error if @async.is_being_cancelled() => raise error
      error =>
        raise unexpected_cli_failure(
          "office.template.failed", "template transaction", error,
        )
    }
    template_report_json(
      file,
      data_file,
      output,
      "docx",
      docx_report_as_shared(result.report),
      transaction=result.transaction.to_json(),
      stories=result.report.stories_scanned,
      regions=docx_regions_json(result.regions),
    )
  } else {
    let result = @office_xlsx.transact_template_document(
      options,
      data,
      allow_missing~,
    ) catch {
      @office_xlsx.XlsxTemplateRefused(report) =>
        raise refusal(report, "xlsx", None)
      @transaction.TransactionError(..) as error =>
        raise transaction_failure(error)
      error if @async.is_being_cancelled() => raise error
      error =>
        raise unexpected_cli_failure(
          "office.template.failed", "template transaction", error,
        )
    }
    template_report_json(
      file,
      data_file,
      output,
      "xlsx",
      result.report,
      transaction=result.transaction.to_json(),
      regions=xlsx_regions_json(result.regions),
    )
  }
  match mode {
    JsonDocument => println(@lib.output_success(record).stringify(indent=2))
    JsonLines => println(@lib.output_success(record).stringify())
    Human => {
      let replaced = match record {
        Object(fields) =>
          match fields.get("replaced") {
            Some(Number(count, ..)) => count.to_int()
            _ => 0
          }
        _ => 0
      }
      let missing = match record {
        Object(fields) =>
          match fields.get("missing_total") {
            Some(Number(count, ..)) => count.to_int()
            _ => 0
          }
        _ => 0
      }
      let unused = match record {
        Object(fields) =>
          match fields.get("unused_total") {
            Some(Number(count, ..)) => count.to_int()
            _ => 0
          }
        _ => 0
      }
      println(
        "template: \{replaced} replaced, " +
        "\{missing} missing, " +
        "\{unused} unused -> " +
        human_text(output, 160),
      )
    }
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
        about="existing .xlsx or .docx template package",
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
        about="destination path matching the template format (never modified in place)",
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
