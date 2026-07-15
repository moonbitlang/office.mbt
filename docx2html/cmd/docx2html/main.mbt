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
    | @docx.Unsupported(message~)
    | @docx.ResourceLimit(message~, ..) =>
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
    err => raise CliError(err.to_string())
  }
  if matches.flags.get_or_default("help", false) {
    return Help
  }
  let input_path = match first_value(matches, "input") {
    Some(value) => value
    None =>
      raise CliError(
        "error: the following required argument was not provided: 'input'\n\n" +
        render_cli_help(),
      )
  }
  let output_path = first_value(matches, "output")
  let output_dir = first_value(matches, "output-dir")
  if output_path is Some(_) && output_dir is Some(_) {
    raise CliError(
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

///|
fn expect_cli_error(args : Array[String], prefix : String) -> Unit raise {
  try parse_cli_args(args) catch {
    CliError(message) => inspect(message.has_prefix(prefix), content="true")
  } noraise {
    _ => fail("expected CLI error")
  }
}

///|
test "CLI parser accepts default stdout HTML conversion" {
  debug_inspect(
    parse_cli_args(["docx2html", "input.docx"]),
    content=(
      #|Run(
      #|  {
      #|    input_path: "input.docx",
      #|    output_path: None,
      #|    output_dir: None,
      #|    style_map_path: None,
      #|    output_format: Html,
      #|    pretty_print: false,
      #|  },
      #|)
    ),
  )
}

///|
test "CLI parser accepts help without input path" {
  debug_inspect(parse_cli_args(["docx2html", "--help"]), content="Help")
  debug_inspect(parse_cli_args(["docx2html", "-h"]), content="Help")
  debug_inspect(
    parse_cli_args(["docx2html", "input.docx", "--help"]),
    content="Help",
  )
}

///|
test "CLI parser accepts Mammoth-style options" {
  debug_inspect(
    parse_cli_args([
      "docx2html", "--style-map", "style-map", "--output-format=markdown", "--pretty-print",
      "input.docx", "output.md",
    ]),
    content=(
      #|Run(
      #|  {
      #|    input_path: "input.docx",
      #|    output_path: Some("output.md"),
      #|    output_dir: None,
      #|    style_map_path: Some("style-map"),
      #|    output_format: Markdown,
      #|    pretty_print: true,
      #|  },
      #|)
    ),
  )
}

///|
test "CLI parser accepts alternate option value forms" {
  debug_inspect(
    parse_cli_args([
      "docx2html", "--style-map=style-map", "--output-format", "markdown", "--output-dir=out",
      "input.docx",
    ]),
    content=(
      #|Run(
      #|  {
      #|    input_path: "input.docx",
      #|    output_path: None,
      #|    output_dir: Some("out"),
      #|    style_map_path: Some("style-map"),
      #|    output_format: Markdown,
      #|    pretty_print: false,
      #|  },
      #|)
    ),
  )
}

///|
test "CLI parser rejects malformed arguments" {
  expect_cli_error(["docx2html"], "error: 'input' requires at least 1 values")
  expect_cli_error(
    ["docx2html", "--style-map"],
    "error: a value is required for '--style-map'",
  )
  expect_cli_error(
    ["docx2html", "--style-map", "--help", "input.docx"],
    "error: a value is required for '--style-map'",
  )
  expect_cli_error(
    ["docx2html", "--output-dir"],
    "error: a value is required for '--output-dir'",
  )
  expect_cli_error(
    ["docx2html", "--output-format"],
    "error: a value is required for '--output-format'",
  )
  expect_cli_error(
    ["docx2html", "--output-format=pdf", "input.docx"],
    "Unsupported output format: pdf",
  )
  expect_cli_error(
    ["docx2html", "--wat", "input.docx"],
    "error: unexpected argument '--wat' found",
  )
  expect_cli_error(
    ["docx2html", "input.docx", "one.html", "two.html"],
    "error: unexpected value 'two.html' for '<output>' found",
  )
}

///|
test "CLI parser rejects output path with output dir" {
  try
    parse_cli_args([
      "docx2html", "--output-dir", "out", "input.docx", "output.html",
    ])
  catch {
    CliError(message) =>
      inspect(
        message.has_prefix(
          "error: output path and --output-dir are mutually exclusive",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected CLI error")
  }
}
