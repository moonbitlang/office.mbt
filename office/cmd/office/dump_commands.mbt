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
async fn run_dump(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let mode = office_validate_output_mode(matches)
  let source = read_office_package(file, cancelled=office_async_cancelled)
  guard source.format is Xlsx else {
    // DOCX dump lands in a later slice of #167; refuse rather than
    // produce a partial artifact
    raise CliFailure(
      @lib.protocol_error(
        "office.dump.unsupported_format",
        "dump currently supports XLSX packages only",
        details=Json::object({ "format": Json::string(source.format.name()) }),
      ),
    )
  }
  let workbook = open_xlsx_read_package(
    source,
    cancelled=office_async_cancelled,
  )
  let envelope = @dump.dump_xlsx_workbook(
    workbook,
    source_file=file,
    source_bytes=source.bytes.length(),
    source_sha256=Some(@lib.sha256_hex(source.bytes)),
    cancelled=office_async_cancelled,
  ) catch {
    error if office_async_cancelled() => raise error
    error => raise dump_failure(error, file)
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
        about="path to an .xlsx file",
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
