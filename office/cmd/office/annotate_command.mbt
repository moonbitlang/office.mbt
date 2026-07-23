///|
/// The `office annotate` command (#164 D4): preservation-safe comment
/// mutation of an existing DOCX through a strict docx.annotation-batch/1
/// script. Distinct from `office batch` (XLSX cell mutation) and from
/// fresh DOCX authoring: this preserves the body and touches only comment
/// and relationship parts.

///|
let office_annotation_max_script_bytes : Int = 4 * 1024 * 1024

///|
/// The office.docx.annotation-batch/1 result record.
fn annotation_report_json(
  file : String,
  output : String,
  report : @office_docx.DocxAnnotationReport,
  transaction? : Json,
) -> Json {
  let results = report.results.map(entry => {
    Json::object({
      "op": Json::string(entry.op),
      "comment_id": Json::string(bounded_text(entry.comment_id, 80)),
      "done": match entry.done {
        Some(flag) => Json::boolean(flag)
        None => Json::null()
      },
    })
  })
  let labels = report.labels.map(pair => {
    let (label, id) = pair
    Json::object({
      "label": Json::string(bounded_text(label, 80)),
      "comment_id": Json::string(bounded_text(id, 80)),
    })
  })
  let fields : Map[String, Json] = {
    "schema": Json::string(@office_docx.SCHEMA_ANNOTATION_RESULT),
    "file": Json::string(bounded_text(file, 160)),
    "format": Json::string("docx"),
    "output": Json::string(bounded_text(output, 160)),
    "ops_applied": Json::number(report.ops_applied.to_double()),
    "results": Json::array(results),
    "labels": Json::array(labels),
    "changed_parts": Json::array(
      report.changed_parts.map(part => Json::string(bounded_text(part, 160))),
    ),
  }
  match transaction {
    Some(value) => fields["transaction"] = value
    None => ()
  }
  Json::object(fields)
}

///|
async fn run_annotate(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let script_file = required_value(matches, "script")
  let output = required_value(matches, "out")
  let mode = office_validate_output_mode(matches)
  guard file.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "office annotate requires a .docx template",
      ),
    )
  }
  guard output.to_lower().has_suffix(".docx") else {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments", "--out must end in .docx to match the annotated format",
      ),
    )
  }
  let script_bytes = read_bounded_file(
    script_file,
    office_annotation_max_script_bytes,
    "office.annotate.script_read_failed",
    "annotation script",
    limit_code="office.annotate.resource_limit",
  )
  let script_text = @utf8.decode(script_bytes, ignore_bom=true) catch {
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.annotate.invalid_script", "annotation script is not valid UTF-8",
        ),
      )
  }
  let batch = @office_docx.parse_annotation_batch(script_text) catch {
    @office_docx.DocxAnnotationParseError(reason) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.annotate.invalid_script",
          "invalid annotation script: " + bounded_text(reason, 200),
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
  let result = @office_docx.transact_docx_annotations(options, batch) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error if @async.is_being_cancelled() => raise error
    error =>
      raise unexpected_cli_failure(
        "office.annotate.failed", "annotation transaction", error,
      )
  }
  let record = annotation_report_json(
    file,
    output,
    result.report,
    transaction=result.transaction.to_json(),
  )
  match mode {
    JsonDocument => println(@lib.output_success(record).stringify(indent=2))
    JsonLines => println(@lib.output_success(record).stringify())
    Human =>
      println(
        "annotate: \{result.report.ops_applied} op(s) -> " +
        human_text(output, 160),
      )
  }
}

///|
fn annotate_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("annotate") {
    Some(command) => command.summary
    None => "Mutate DOCX comments through a strict annotation script"
  }
  Command(
    "annotate",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="existing .docx package (never modified in place)",
        num_args=@argparse.ValueRange::single(),
      ),
      PositionArg(
        "script",
        about="docx.annotation-batch/1 JSON document",
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
      FlagArg("json", long="json", about="print office.output/1 JSON"),
      FlagArg("jsonl", long="jsonl", about="print one office.output/1 line"),
    ],
  )
}
