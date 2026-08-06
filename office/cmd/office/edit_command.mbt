///|
/// The `office edit` command: literal find & replace over the text of an
/// EXISTING DOCX through a strict docx.edit/1 script. Distinct from
/// `office template` (which substitutes `{{key}}` placeholders from a
/// data document) and from `office annotate` (which touches only
/// comments): the needle is ordinary literal text, matched across run
/// boundaries, and the replacement is spliced into the source snapshot
/// byte-span by byte-span so all unrelated OOXML is preserved.

///|
/// Ceiling on the edit script document `office edit` will read.
let office_edit_max_script_bytes : Int = 4 * 1024 * 1024

///|
fn edit_findings_json(
  findings : Array[@office_docx.DocxTemplateFinding],
) -> Json {
  Json::array(
    findings.map(entry => {
      Json::object({
        "location": Json::string(bounded_text(entry.location, 160)),
        "detail": Json::string(bounded_text(entry.detail, 200)),
      })
    }),
  )
}

///|
/// The office.docx.edit/1 record, shared by the success envelope and the
/// strict-refusal failure details.
fn edit_report_json(
  file : String,
  script_file : String,
  output : String,
  report : @office_docx.DocxEditReport,
  transaction? : Json,
) -> Json {
  let results = report.results.map(entry => {
    let fields : Map[String, Json] = {
      "op": Json::string(entry.op),
      "find": Json::string(bounded_text(entry.find, 160)),
      "replace": Json::string(bounded_text(entry.replace, 160)),
      "matched": Json::number(entry.matched.to_double()),
      "replacements": Json::number(entry.replacements.to_double()),
    }
    fields["occurrence"] = match entry.occurrence {
      Some(ordinal) => Json::number(ordinal.to_double())
      None => Json::null()
    }
    Json::object(fields)
  })
  let fields : Map[String, Json] = {
    "schema": Json::string(@office_docx.SCHEMA_DOCX_EDIT_RESULT),
    "file": Json::string(bounded_text(file, 160)),
    "format": Json::string("docx"),
    "script_file": Json::string(bounded_text(script_file, 160)),
    "output": Json::string(bounded_text(output, 160)),
    "ops_applied": Json::number(report.ops_applied.to_double()),
    "replacements": Json::number(report.replacements.to_double()),
    "results": Json::array(results),
    "unmatched": edit_findings_json(report.unmatched),
    "unmatched_total": Json::number(report.unmatched_total.to_double()),
    "unsupported": edit_findings_json(report.unsupported),
    "unsupported_total": Json::number(report.unsupported_total.to_double()),
    "conflicts": edit_findings_json(report.conflicts),
    "conflicts_total": Json::number(report.conflicts_total.to_double()),
    "locations": edit_findings_json(report.locations),
    "locations_truncated": Json::boolean(report.locations_truncated),
    "stories_scanned": Json::array(
      report.stories_scanned.map(story => Json::string(story)),
    ),
  }
  match transaction {
    Some(value) => fields["transaction"] = value
    None => ()
  }
  Json::object(fields)
}

///|
async fn run_edit(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let script_file = required_value(matches, "script")
  let output = required_value(matches, "out")
  let allow_unmatched = matches.flags.get_or_default("allow-unmatched", false)
  let mode = office_validate_output_mode(matches)
  guard file.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "office edit requires a .docx document",
      ),
    )
  }
  guard output.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--out must end in .docx to match the edited format",
      ),
    )
  }
  let script_bytes = read_bounded_file(
    script_file,
    office_edit_max_script_bytes,
    "office.edit.script_read_failed",
    "edit script",
    limit_code="office.edit.resource_limit",
  )
  let script_text = @utf8.decode(script_bytes, ignore_bom=true) catch {
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.edit.invalid_script", "edit script is not valid UTF-8",
        ),
      )
  }
  let script = @office_docx.parse_docx_edit_script(script_text) catch {
    DocxEditParseError(reason) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.edit.invalid_script",
          "invalid edit script: " + bounded_text(reason, 200),
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
  let result = @office_docx.transact_docx_edit(
    options,
    script,
    allow_unmatched~,
  ) catch {
    @office_docx.DocxEditRefused(report) => {
      // strict findings: precedence unsupported > conflicts > unmatched
      let (code, message) = if report.unsupported_total > 0 {
        (
          "office.edit.unsupported_context", "a match reaches content the edit cannot rewrite safely",
        )
      } else if report.conflicts_total > 0 {
        (
          "office.edit.overlapping_matches", "two operations match overlapping text",
        )
      } else {
        (
          "office.edit.unmatched_find", "an operation did not find the occurrences it requires",
        )
      }
      raise CliFailure(
        @lib.protocol_error(
          code,
          message,
          details=edit_report_json(file, script_file, output, report),
        ),
      )
    }
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error if @async.is_being_cancelled() => raise error
    error =>
      raise unexpected_cli_failure(
        "office.edit.failed", "edit transaction", error,
      )
  }
  let record = edit_report_json(
    file,
    script_file,
    output,
    result.report,
    transaction=result.transaction.to_json(),
  )
  match mode {
    JsonDocument => println(@lib.output_success(record).stringify(indent=2))
    JsonLines => println(@lib.output_success(record).stringify())
    Human =>
      println(
        "edit: \{result.report.replacements} replacement(s) across " +
        "\{result.report.ops_applied} op(s) -> " +
        human_text(output, 160),
      )
  }
}

///|
fn edit_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("edit") {
    Some(command) => command.summary
    None =>
      "Replace literal text in an existing DOCX through a strict edit script"
  }
  Command(
    "edit",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="existing .docx package (never modified in place)",
        num_args=@argparse.ValueRange::single(),
      ),
      PositionArg(
        "script",
        about="docx.edit/1 JSON document",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[
      OptionArg(
        "out",
        long="out",
        about="destination .docx path (never modified in place)",
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
        "allow-unmatched",
        long="allow-unmatched",
        about="report ops that found too few occurrences instead of failing",
      ),
      FlagArg("json", long="json", about="print office.output/1 JSON"),
      FlagArg("jsonl", long="jsonl", about="print one office.output/1 line"),
    ],
  )
}
