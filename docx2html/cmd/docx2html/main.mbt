// The published flag-only converter binary. Argument parsing and the exact
// legacy help/error surface live here; the conversion runner itself is shared
// with `cmd/docx` via `internal/cli` and must stay behavior-identical.

///|
enum CliCommand {
  Run(@cli.CliOptions)
  Help
} derive(Debug, Eq)

///|
async fn main {
  // Any failure is turned into a `CliError` that escapes `main`: this prints
  // the message once and exits non-zero on both native and wasm (which has no
  // `exit()` and no stderr). `CliError` messages already carry their own
  // prefix; everything else is labelled `docx2html:`.
  run_main() catch {
    @cli.CliError(_) as err => raise err
    @docx.InvalidZip(message~)
    | @docx.InvalidXml(message~)
    | @docx.MissingPart(message~)
    | @docx.Unsupported(message~) =>
      raise @cli.CliError("docx2html: " + message)
    err => raise @cli.CliError("docx2html: " + err.to_string())
  }
}

///|
async fn run_main() -> Unit {
  match parse_cli_args(@env.args()) {
    Help => println(render_cli_help())
    Run(options) => @cli.run_conversion(options)
  }
}

///|
fn parse_cli_args(args : Array[String]) -> CliCommand raise @cli.CliError {
  let argv = cli_argv(args)
  if argv_is_help_only(argv) {
    return Help
  }
  let matches = cli_command().parse(argv~, env=Map([])) catch {
    err => raise @cli.CliError(err.to_string())
  }
  if matches.flags.get_or_default("help", false) {
    return Help
  }
  let input_path = match first_value(matches, "input") {
    Some(value) => value
    None =>
      raise @cli.CliError(
        "error: the following required argument was not provided: 'input'\n\n" +
        render_cli_help(),
      )
  }
  let output_path = first_value(matches, "output")
  let output_dir = first_value(matches, "output-dir")
  if output_path is Some(_) && output_dir is Some(_) {
    raise @cli.CliError(
      "error: output path and --output-dir are mutually exclusive\n\n" +
      render_cli_help(),
    )
  }
  let output_format = match first_value(matches, "output-format") {
    Some(value) => @cli.parse_output_format(value)
    None => Html
  }
  Run({
    input_path,
    output_path,
    output_dir,
    style_map_path: first_value(matches, "style-map"),
    output_format,
    pretty_print: matches.flags.get_or_default("pretty-print", false),
  })
}

///|
fn cli_command() -> @argparse.Command {
  Command(
    "docx2html",
    about="Convert DOCX documents to HTML or Markdown.",
    disable_help_flag=true,
    flags=[
      FlagArg("help", short='h', long="help", about="Show help information."),
      FlagArg("pretty-print", about="Pretty-print generated HTML."),
    ],
    options=[
      OptionArg("style-map", about="Read Mammoth style-map lines from a file."),
      OptionArg("output-format", about="Output format: html or markdown.", default_values=[
        "html",
      ]),
      OptionArg(
        "output-dir",
        about="Write converted output and extracted images into a directory.",
      ),
    ],
    positionals=[
      PositionArg(
        "input",
        about="Input .docx file.",
        num_args=ValueRange(lower=1, upper=1),
      ),
      PositionArg(
        "output",
        about="Output file. Defaults to stdout unless --output-dir is set.",
        num_args=ValueRange(lower=0, upper=1),
      ),
    ],
  )
}

///|
fn cli_argv(args : Array[String]) -> Array[String] {
  let argv = []
  for index in 1..<args.length() {
    argv.push(args[index])
  }
  argv
}

///|
fn argv_is_help_only(argv : Array[String]) -> Bool {
  argv.length() == 1 && (argv[0] == "--help" || argv[0] == "-h")
}

///|
fn first_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) => if values.length() > 0 { Some(values[0]) } else { None }
    None => None
  }
}

///|
fn render_cli_help() -> String {
  cli_command().render_help()
}
