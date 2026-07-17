///|
suberror CliError {
  CliError(String)
}

///|
impl Show for CliError with fn output(self, logger) {
  match self {
    CliError(message) => logger.write_string(message)
  }
}

///|
suberror CliFailure {
  CliFailure(@lib.ProtocolError)
}

///|
fn required_value(
  matches : @argparse.Matches,
  name : String,
) -> String raise CliFailure {
  match matches.values.get(name) {
    Some([value, ..]) => value
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments",
          "required argument '\{name}' was not provided",
          details=Json::object({ "argument": Json::string(name) }),
        ),
      )
  }
}

///|
fn identify_error(
  error : @lib.OfficeError,
  file : String,
) -> @lib.ProtocolError {
  let bounded_file = bounded_text(file, 160)
  match error {
    UnsupportedFileExtension(_) =>
      @lib.protocol_error(
        "office.unsupported_extension",
        "unsupported file extension for '\{bounded_file}' (expected .xlsx or .docx)",
        details=Json::object({
          "file": Json::string(bounded_file),
          "expected_extensions": Json::array([
            Json::string("docx"),
            Json::string("xlsx"),
          ]),
        }),
      )
    InvalidPackage(message) =>
      @lib.protocol_error(
        "office.invalid_package",
        "invalid Office package: " + bounded_text(message, 240),
        details=Json::object({ "file": Json::string(bounded_file) }),
      )
    FormatMismatch(expected~, actual~) =>
      @lib.protocol_error(
        "office.format_mismatch",
        "file extension says \{expected.name()}, but package content is \{actual.name()}",
        details=Json::object({
          "file": Json::string(bounded_file),
          "expected": Json::string(expected.name()),
          "actual": Json::string(actual.name()),
        }),
      )
  }
}

///|
async fn run_identify(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let data = @afs.read_file(file).binary() catch {
    error if @async.is_being_cancelled() => raise error
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.file_read_failed",
          "could not read input file: " + bounded_text(file, 160),
          details=Json::object({ "file": Json::string(bounded_text(file, 160)) }),
        ),
      )
  }
  let format = @lib.detect_format(file, data) catch {
    error => raise CliFailure(identify_error(error, file))
  }
  if matches.flags.get_or_default("json", false) {
    println(
      @lib.output_success(
        Json::object({
          "schema": Json::string("office.identify/1"),
          "file": Json::string(file),
          "format": Json::string(format.name()),
        }),
      ).stringify(indent=2),
    )
  } else {
    println(format.name())
  }
}

///|
fn identify_command() -> @argparse.Command {
  let summary = match @lib.find_capability_command("identify") {
    Some(command) => command.summary
    None => "Identify a structurally valid XLSX or DOCX package"
  }
  Command(
    "identify",
    about=summary,
    positionals=[
      PositionArg(
        "file",
        about="path to an .xlsx or .docx file",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
    flags=[FlagArg("json", long="json", about="print office.output/1 JSON")],
  )
}

///|
fn build_command() -> @argparse.Command {
  Command(
    "office",
    about="Create, inspect, and edit XLSX and DOCX documents",
    disable_help_subcommand=true,
    subcommand_required=true,
    subcommands=[
      help_command(),
      identify_command(),
      outline_command(),
      get_command(),
      text_command(),
      query_command(),
      raw_command(),
    ],
  )
}

///|
fn is_implemented_command(name : StringView) -> Bool {
  match name {
    "help" | "identify" | "outline" | "get" | "text" | "query" | "raw" => true
    _ => false
  }
}

///|
async fn run_cli(args : Array[String]) -> Unit {
  let command = build_command()
  let matches = command.parse(argv=args, env=Map([]))
  match matches.subcommand {
    Some((name, values)) if is_implemented_command(name) =>
      match name {
        "help" => run_help(values)
        "identify" => run_identify(values)
        "outline" => run_docx_outline(values)
        "get" => run_docx_get(values)
        "text" => run_docx_text(values)
        "query" => run_docx_query(values)
        "raw" => run_raw(values)
        _ => ()
      }
    _ =>
      raise CliFailure(
        @lib.protocol_error(
          "office.invalid_arguments", "an implemented subcommand is required; try 'office help'",
        ),
      )
  }
}

///|
async fn main {
  let argv = @env.args()
  let args = if argv.length() > 0 { argv[1:].to_owned() } else { [] }
  let mode = output_mode_from_args(args)
  let (has_json, has_jsonl) = output_flags_from_args(args)
  try {
    if has_json && has_jsonl {
      raise CliFailure(
        @lib.protocol_error(
          "office.output_mode_conflict",
          "--json and --jsonl are mutually exclusive",
          details=Json::object({
            "options": Json::array([
              Json::string("--json"),
              Json::string("--jsonl"),
            ]),
          }),
        ),
      )
    }
    run_cli(args)
  } catch {
    error if @async.is_being_cancelled() => raise error
    CliFailure(error) => raise CliError(render_failure(error, mode))
    error => {
      let message = normalize_argument_error(error.to_string())
      raise CliError(
        render_failure(
          @lib.protocol_error("office.invalid_arguments", message),
          mode,
        ),
      )
    }
  }
}
