///|
/// Ceiling on the dump document `office replay` will read.
let office_replay_max_input_bytes : Int = 64 * 1024 * 1024

///|
/// Ceiling on the workbook `office replay` will publish.
let office_replay_max_output_bytes : Int = 64 * 1024 * 1024

///|
async fn run_replay(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let output = required_value(matches, "output")
  let overwrite = matches.flags.get_or_default("overwrite", false)
  let mode = office_validate_output_mode(matches)
  let bytes = read_bounded_file(
    file,
    office_replay_max_input_bytes,
    "office.replay.dump_read_failed",
    "dump document",
    limit_code="office.replay.resource_limit",
  )
  let text = @utf8.decode(bytes, ignore_bom=true) catch {
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.replay.invalid_dump", "dump document is not valid UTF-8",
        ),
      )
  }
  let document = @json.parse(text) catch {
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.replay.invalid_dump", "dump document is not valid JSON",
        ),
      )
  }
  let envelope = @dump.parse_dump_envelope(document) catch {
    @dump.DumpParseError(reason) =>
      raise CliFailure(
        @lib.protocol_error(
          "office.replay.invalid_dump",
          "malformed dump: " + bounded_text(reason, 200),
        ),
      )
  }
  // the destination extension must match the replayed format so the
  // published artifact is unambiguous
  let expected_suffix = match envelope.format {
    "xlsx" => ".xlsx"
    "docx" => ".docx"
    _ => ""
  }
  if expected_suffix != "" && !output.to_lower().has_suffix(expected_suffix) {
    raise CliFailure(
      @lib.protocol_error(
        "office.invalid_arguments",
        "--output must end in \{expected_suffix} for a \{envelope.format} dump",
      ),
    )
  }
  let payload = match envelope.format {
    "xlsx" => {
      let workbook = @dump.replay_xlsx_dump(envelope) catch {
        error => raise replay_engine_failure(error)
      }
      @xlsx.write(workbook) catch {
        _ =>
          raise CliFailure(
            @lib.protocol_error(
              "office.replay.write_failed", "could not serialize the replayed workbook",
            ),
          )
      }
    }
    "docx" =>
      @dump.replay_docx_dump(envelope) catch {
        error => raise replay_engine_failure(error)
      }
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.replay.unsupported_format",
          "replay supports XLSX and DOCX dumps",
          details=Json::object({
            "format": Json::string(bounded_text(envelope.format, 40)),
          }),
        ),
      )
  }
  if payload.length() > office_replay_max_output_bytes {
    raise CliFailure(
      @lib.protocol_error(
        "office.replay.resource_limit",
        "replayed workbook exceeds the configured limit",
        details=Json::object({
          "resource": Json::string("replay_output_bytes"),
          "limit": Json::number(office_replay_max_output_bytes.to_double()),
          "actual": Json::number(payload.length().to_double()),
        }),
      ),
    )
  }
  if overwrite {
    @afs.remove(output) catch {
      _ => ()
    }
  }
  @transaction.atomic_write_new(output, payload) catch {
    @transaction.TransactionError(..) as error =>
      raise transaction_failure(error)
    error => raise error
  }
  let report = Json::object({
    "schema": Json::string(@lib.SCHEMA_REPLAY_RESULT),
    "format": Json::string(envelope.format),
    "output": Json::string(bounded_text(output, 160)),
    "bytes_written": Json::number(payload.length().to_double()),
    "ops_applied": Json::number(envelope.ops.length().to_double()),
  })
  match mode {
    JsonDocument => println(@lib.output_success(report).stringify(indent=2))
    JsonLines => println(@lib.output_success(report).stringify())
    Human =>
      println(
        "replayed \{envelope.ops.length()} op(s) to " +
        human_text(output, 160) +
        " (\{payload.length()} bytes)",
      )
  }
}

///|
fn replay_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("replay") {
    Some(command) => command.summary
    None => "Replay an office.dump/1 document into an XLSX workbook"
  }
  Command(
    "replay",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="path to an office.dump/1 JSON document",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    options=[
      OptionArg(
        "output",
        long="output",
        about="destination path (.xlsx or .docx, matching the dump)",
      ),
    ],
    flags=[
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

///|
/// Maps a replay engine error to a bounded protocol failure, shared by
/// both format paths.
fn replay_engine_failure(error : @dump.ReplayError) -> CliFailure {
  match error {
    ReplayInvalidFormat(reason) =>
      CliFailure(
        @lib.protocol_error(
          "office.replay.invalid_dump",
          "dump cannot be replayed: " + bounded_text(reason, 200),
        ),
      )
    ReplayFailed(reason) =>
      CliFailure(
        @lib.protocol_error(
          "office.replay.failed",
          "replay failed: " + bounded_text(reason, 200),
        ),
      )
  }
}
