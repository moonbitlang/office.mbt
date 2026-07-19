///|
/// Ceiling on findings carried by one validate/issues response, matching the
/// bounded-report style of the transaction validators feeding it.
let office_finding_report_limit : Int = 128

///|
/// Ceiling on message characters retained per finding.
let office_finding_message_chars : Int = 512

///|
/// Ceiling on stored cells scanned per workbook while deriving XLSX formula
/// findings; reuses the shared parser-item allowance.
let office_issues_max_scanned_cells : Int = office_read_max_parser_items

///|
/// Ceiling on cached formula-error findings reported per workbook.
let office_issues_max_formula_findings : Int = 64

///|
/// One normalized validate/issues finding in the office.finding/1 shape.
priv struct OfficeFinding {
  severity : String
  code : String
  message : String
  location : String?
}

///|
fn office_finding(
  severity : String,
  code : String,
  message : String,
  location? : String,
) -> OfficeFinding {
  {
    severity,
    code,
    message: bounded_text(message, office_finding_message_chars),
    location,
  }
}

///|
fn office_finding_json(finding : OfficeFinding) -> Json {
  let fields : Map[String, Json] = {
    "severity": Json::string(finding.severity),
    "code": Json::string(finding.code),
    "message": Json::string(finding.message),
  }
  match finding.location {
    Some(location) => fields["location"] = Json::string(location)
    None => ()
  }
  Json::object(fields)
}

///|
fn office_findings_json(findings : Array[OfficeFinding]) -> Json {
  Json::array(findings.map(office_finding_json))
}

///|
/// Runs the exact archive-backed package validator used by mutation
/// transactions for the detected format, so read-only verdicts cannot drift
/// from the pre-commit gate.
fn office_package_gate_findings(
  source : OfficeReadPackage,
) -> Array[OfficeFinding] raise {
  let validator = try {
    match source.format {
      Xlsx => @office_xlsx.package_validator()
      Docx => @office_docx.package_validator()
    }
  } catch {
    error =>
      raise CliFailure(
        @lib.protocol_error(
          "office.validation_unavailable",
          "package validator could not be constructed: " +
          bounded_text("\{error}", 240),
        ),
      )
  }
  // mirror the transaction call shape: candidate bytes plus an isolated
  // archive fork, so byte-aware or archive-mutating validators keep
  // read-only and pre-commit verdicts aligned
  let raw = (validator.validate)(
    source.format,
    source.bytes,
    source.archive.fork(),
  ) catch {
    error if office_async_cancelled() => raise error
    error =>
      raise CliFailure(
        @lib.protocol_error(
          "office.\{source.format.name()}.validation_failed",
          "package validation could not run to completion: " +
          bounded_text("\{error}", 240),
          details=Json::object({
            "file": Json::string(bounded_text(source.file, 160)),
          }),
        ),
      )
  }
  let findings : Array[OfficeFinding] = []
  for finding in raw {
    if findings.length() >= office_finding_report_limit {
      break
    }
    findings.push(office_finding("error", finding.code, finding.message))
  }
  findings
}

///|
/// Scans stored cells for cached formula error values (#REF!, #NAME?, ...)
/// and reports them as bounded, actionable warnings with cell locations.
fn office_xlsx_formula_findings(
  source : OfficeReadPackage,
  findings : Array[OfficeFinding],
  cancelled? : () -> Bool = office_async_cancelled,
) -> Unit raise {
  let workbook = open_xlsx_read_package(source, cancelled~)
  let mut scanned = 0
  let mut reported = 0
  let mut omitted = 0
  for worksheet in workbook.sheets() {
    let sheet_name = worksheet.name()
    let (max_row, max_col) = worksheet.used_bounds_limited(
      maximum_stored_cells=office_issues_max_scanned_cells,
      cancelled~,
    ) catch {
      ReadCancelled as error => raise error
      _ => continue
    }
    for row in 1..<=max_row {
      for column in 1..<=max_col {
        if scanned >= office_issues_max_scanned_cells {
          return office_push_formula_omission(findings, omitted, scanned=true)
        }
        scanned += 1
        if scanned % 1024 == 0 {
          check_office_read_cancelled(cancelled)
        }
        // only formula-backed cells qualify: a literal error cell carries no
        // cached formula result and is not an actionable formula finding
        let formula_info = worksheet.get_cell_formula_info_rc(row, column) catch {
          ReadCancelled as error => raise error
          _ => None
        }
        guard formula_info is Some(_) else { continue }
        let reference = @xlsx.coordinates_to_cell_name(column, row) catch {
          _ => continue
        }
        match (worksheet.get_cell_value_raw(reference) catch { _ => None }) {
          Some(Error(text)) =>
            if reported < office_issues_max_formula_findings {
              reported += 1
              findings.push(
                office_finding(
                  "warning",
                  "office.xlsx.formula_error_value",
                  "cell caches formula error value " + bounded_text(text, 16),
                  location="\{sheet_name}!\{reference}",
                ),
              )
            } else {
              omitted += 1
            }
          _ => ()
        }
      }
    }
  }
  office_push_formula_omission(findings, omitted, scanned=false)
}

///|
fn office_push_formula_omission(
  findings : Array[OfficeFinding],
  omitted : Int,
  scanned~ : Bool,
) -> Unit {
  if omitted > 0 {
    findings.push(
      office_finding(
        "warning",
        "office.xlsx.formula_findings_omitted",
        "\{omitted} additional cached formula error values were omitted from the bounded report",
      ),
    )
  }
  if scanned {
    findings.push(
      office_finding(
        "warning", "office.xlsx.formula_scan_truncated", "the cached formula error scan stopped at the bounded cell allowance",
      ),
    )
  }
}

///|
/// Harvests the tolerant DOCX reader's bounded diagnostics as warnings.
fn office_docx_reader_findings(
  source : OfficeReadPackage,
  findings : Array[OfficeFinding],
) -> Unit raise {
  let main_document_part = validate_docx_read_archive(
    source.file,
    source.archive,
    cancelled=office_async_cancelled,
  )
  let xml_budget = @xml.xml_read_budget(
    max_source_units=docx_cli_max_xml_source_units,
    max_tokens=docx_cli_max_xml_tokens,
    max_materialized_chars=docx_cli_max_xml_materialized_chars,
    max_token_chars=docx_cli_max_xml_token_chars,
    cancelled=office_async_cancelled,
  )
  let annotated = @docx.read_docx_annotated_archive_tolerant_limited(
    source.archive,
    xml_budget,
    max_diagnostics=docx_cli_max_warnings,
    max_diagnostic_chars=office_finding_message_chars,
    expected_main_document_path=main_document_part,
  ) catch {
    error => {
      check_office_read_cancelled(office_async_cancelled)
      raise docx_reader_failure(error, source.file)
    }
  }
  // annotation warnings are already merged into the package messages by the
  // reader; classify them under their specific code exactly once and keep
  // the remaining reader diagnostics under the generic code
  let annotation_texts : Set[String] = Set([])
  for warning in annotated.annotations().warnings() {
    annotation_texts.add(warning)
  }
  for message in annotated.result().messages {
    if findings.length() >= office_finding_report_limit {
      break
    }
    let text = match message {
      Error(text) => text
      Warning(text) => text
    }
    let code = if annotation_texts.contains(text) {
      "office.docx.annotation_warning"
    } else {
      "office.docx.reader_diagnostic"
    }
    findings.push(office_finding("warning", code, text))
  }
}

///|
fn office_finding_counts(findings : Array[OfficeFinding]) -> (Int, Int) {
  let mut errors = 0
  let mut warnings = 0
  for finding in findings {
    if finding.severity == "error" {
      errors += 1
    } else {
      warnings += 1
    }
  }
  (errors, warnings)
}

///|
fn office_validate_data(
  schema : String,
  source : OfficeReadPackage,
  findings : Array[OfficeFinding],
) -> Json {
  let (errors, warnings) = office_finding_counts(findings)
  Json::object({
    "schema": Json::string(schema),
    "file": Json::string(bounded_text(source.file, 160)),
    "format": Json::string(source.format.name()),
    "valid": Json::boolean(errors == 0),
    "findings": office_findings_json(findings),
    "error_count": Json::number(errors.to_double()),
    "warning_count": Json::number(warnings.to_double()),
  })
}

///|
fn office_render_findings_human(findings : Array[OfficeFinding]) -> Unit {
  for finding in findings {
    let location = match finding.location {
      Some(value) => " [" + human_text(value, 160) + "]"
      None => ""
    }
    let message = human_text(finding.message, office_finding_message_chars)
    println("\{finding.severity} \{finding.code}\{location}: \{message}")
  }
}

///|
fn office_validate_output_mode(matches : @argparse.Matches) -> OutputMode raise {
  let json = matches.flags.get_or_default("json", false)
  let jsonl = matches.flags.get_or_default("jsonl", false)
  if json && jsonl {
    raise CliFailure(
      @lib.protocol_error(
        "office.output_mode_conflict", "--json and --jsonl are mutually exclusive",
      ),
    )
  }
  if json {
    JsonDocument
  } else if jsonl {
    JsonLines
  } else {
    Human
  }
}

///|
async fn run_validate(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let mode = office_validate_output_mode(matches)
  let source = read_office_package(file, cancelled=office_async_cancelled)
  let findings = office_package_gate_findings(source)
  let data = office_validate_data(@lib.SCHEMA_VALIDATE_RESULT, source, findings)
  let (errors, _) = office_finding_counts(findings)
  if errors > 0 {
    raise office_validation_failure(source, errors, data)
  }
  match mode {
    JsonDocument => println(@lib.output_success(data).stringify(indent=2))
    JsonLines => println(@lib.output_success(data).stringify())
    Human => println("valid \{source.format.name()}")
  }
}

///|
/// The non-zero validate verdict still carries the complete bounded
/// office.validate/1 record in the failure envelope's details.
fn office_validation_failure(
  source : OfficeReadPackage,
  errors : Int,
  data : Json,
) -> CliFailure {
  CliFailure(
    @lib.protocol_error(
      "office.validation_failed",
      "\{source.format.name().to_upper()} package failed validation with \{errors} finding(s)",
      details=data,
    ),
  )
}

///|
async fn run_issues(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let mode = office_validate_output_mode(matches)
  let source = read_office_package(file, cancelled=office_async_cancelled)
  let findings = office_package_gate_findings(source)
  // actionable non-fatal findings never mask package invalidity: they are
  // collected only when the shared gate accepted the package
  if findings.is_empty() {
    match source.format {
      Xlsx => office_xlsx_formula_findings(source, findings)
      Docx => office_docx_reader_findings(source, findings)
    }
  }
  let data = office_validate_data(@lib.SCHEMA_ISSUES_RESULT, source, findings)
  match mode {
    JsonDocument => println(@lib.output_success(data).stringify(indent=2))
    JsonLines => println(@lib.output_success(data).stringify())
    Human => {
      let (errors, warnings) = office_finding_counts(findings)
      office_render_findings_human(findings)
      println(
        "\{source.format.name()}: \{errors} error(s), \{warnings} warning(s)",
      )
    }
  }
}

///|
fn validate_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("validate") {
    Some(command) => command.summary
    None => "Validate an XLSX or DOCX package with the mutation gate"
  }
  Command(
    "validate",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="path to an .xlsx or .docx file",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    flags=[
      FlagArg("json", long="json", about="print office.output/1 JSON"),
      FlagArg("jsonl", long="jsonl", about="print one office.output/1 line"),
    ],
  )
}

///|
fn issues_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("issues") {
    Some(command) => command.summary
    None => "Report bounded actionable findings for an XLSX or DOCX package"
  }
  Command(
    "issues",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="path to an .xlsx or .docx file",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    flags=[
      FlagArg("json", long="json", about="print office.output/1 JSON"),
      FlagArg("jsonl", long="jsonl", about="print one office.output/1 line"),
    ],
  )
}
