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
fn required_value(
  matches : @argparse.Matches,
  name : String,
) -> String raise CliError {
  match matches.values.get(name) {
    Some([value, ..]) => value
    _ =>
      raise CliError(
        "error: the following required argument was not provided: '\{name}'",
      )
  }
}

///|
async fn run_identify(matches : @argparse.Matches) -> Unit {
  let file = required_value(matches, "file")
  let data = @afs.read_file(file).binary()
  let format = @lib.detect_format(file, data)
  if matches.flags.get_or_default("json", false) {
    println(
      Json::object({
        "schema": Json::string("office.identify/1"),
        "file": Json::string(file),
        "format": Json::string(format.name()),
      }).stringify(indent=2),
    )
  } else {
    println(format.name())
  }
}

///|
fn build_command() -> @argparse.Command {
  Command(
    "office",
    about="Create, inspect, and edit XLSX and DOCX documents",
    subcommand_required=true,
    subcommands=[
      Command(
        "identify",
        about="Identify a structurally valid XLSX or DOCX package",
        positionals=[
          PositionArg(
            "file",
            about="path to an .xlsx or .docx file",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
        flags=[FlagArg("json", long="json", about="print versioned JSON")],
      ),
    ],
  )
}

///|
async fn run_cli() -> Unit {
  let argv = @env.args()
  let args = if argv.length() > 0 { argv[1:].to_owned() } else { [] }
  let command = build_command()
  let matches = command.parse(argv=args, env=Map([]))
  match matches.subcommand {
    Some(("identify", values)) => run_identify(values)
    _ => println(command.render_help())
  }
}

///|
async fn main {
  run_cli() catch {
    err => {
      let message = err.to_string()
      raise CliError(
        if message.has_prefix("error:") {
          message
        } else {
          "office: " + message
        },
      )
    }
  }
}
