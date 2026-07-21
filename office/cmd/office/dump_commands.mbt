///|
/// Maps a dump library error to a bounded protocol failure.
fn dump_failure(error : Error, file : String) -> CliFailure {
  match error {
    @dump.DumpCancelled =>
      CliFailure(@lib.protocol_error("office.cancelled", "dump was cancelled"))
    @dump.DumpUnsupported(reason) =>
      CliFailure(
        @lib.protocol_error(
          "office.dump.unsupported",
          "cannot dump this package: " + bounded_text(reason, 200),
          details=Json::object({ "file": Json::string(bounded_text(file, 160)) }),
        ),
      )
    @dump.DumpSelfCheckFailed(reason) =>
      CliFailure(
        @lib.protocol_error(
          "office.dump.self_check_failed",
          "dump produced an op the batch engine rejects: " +
          bounded_text(reason, 200),
          details=Json::object({ "file": Json::string(bounded_text(file, 160)) }),
        ),
      )
    _ =>
      CliFailure(
        @lib.protocol_error(
          "office.dump.failed",
          "dump failed: " + bounded_text(error.to_string(), 200),
          details=Json::object({ "file": Json::string(bounded_text(file, 160)) }),
        ),
      )
  }
}

///|
/// Opens a DOCX package through the same tolerant, budgeted annotated
/// reader the validate/issues commands use.
async fn open_docx_annotated_package(
  source : OfficeReadPackage,
) -> @docx.DocxAnnotatedResult {
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
  @docx.read_docx_annotated_archive_tolerant_limited(
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
}

///|
async fn run_dump(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let mode = office_validate_output_mode(matches)
  let source = read_office_package(file, cancelled=office_async_cancelled)
  let envelope = match source.format {
    Xlsx => {
      let workbook = open_xlsx_read_package(
        source,
        cancelled=office_async_cancelled,
      )
      @dump.dump_xlsx_workbook(
        workbook,
        source_file=file,
        source_bytes=source.bytes.length(),
        source_sha256=Some(@lib.sha256_hex(source.bytes)),
        cancelled=office_async_cancelled,
      ) catch {
        error if office_async_cancelled() => raise error
        error => raise dump_failure(error, file)
      }
    }
    Docx => {
      let annotated = open_docx_annotated_package(source)
      @dump.dump_docx_document(
        annotated,
        source_file=file,
        source_bytes=source.bytes.length(),
        source_sha256=Some(@lib.sha256_hex(source.bytes)),
        cancelled=office_async_cancelled,
      ) catch {
        error if office_async_cancelled() => raise error
        error => raise dump_failure(error, file)
      }
    }
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.dump.unsupported_format",
          "dump supports XLSX and DOCX packages",
          details=Json::object({ "format": Json::string(source.format.name()) }),
        ),
      )
  }
  match mode {
    JsonDocument => println(envelope.to_json_document().stringify(indent=2))
    JsonLines =>
      for line in envelope.to_jsonl_lines() {
        println(line)
      }
    Human =>
      println(
        "\{source.format.name()} dump: \{envelope.ops.length()} op(s), " +
        "\{envelope.residual.length()} residual, " +
        "\{envelope.warnings.length()} warning(s)",
      )
  }
}

///|
fn dump_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("dump") {
    Some(command) => command.summary
    None => "Dump a package as a replayable semantic op stream"
  }
  Command(
    "dump",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="path to an .xlsx or .docx file",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    flags=[
      FlagArg(
        "json",
        long="json",
        about="print the office.dump/1 JSON document",
      ),
      FlagArg(
        "jsonl",
        long="jsonl",
        about="print the streaming office.dump/1 JSONL form",
      ),
    ],
  )
}
