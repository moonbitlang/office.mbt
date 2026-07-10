///|
/// `docx convert <input> [output]` — converts a document to HTML or Markdown
/// via the shared runner. Same semantics as the published `docx2html` binary:
/// stdout by default, a file when `output` is given, a directory (document +
/// extracted images) with `--output-dir`.
async fn run_convert(matches : @argparse.Matches) -> Unit {
  let input_path = match first_value(matches, "input") {
    Some(value) => value
    None =>
      raise @cli.CliError(
        "error: the following required argument was not provided: 'input'",
      )
  }
  let output_path = first_value(matches, "output")
  let output_dir = first_value(matches, "output-dir")
  if output_path is Some(_) && output_dir is Some(_) {
    raise @cli.CliError(
      "error: output path and --output-dir are mutually exclusive",
    )
  }
  let output_format = match first_value(matches, "output-format") {
    Some(value) => @cli.parse_output_format(value)
    None => Html
  }
  @cli.run_conversion(
    {
      input_path,
      output_path,
      output_dir,
      style_map_path: first_value(matches, "style-map"),
      output_format,
      pretty_print: matches.flags.get_or_default("pretty-print", false),
    },
    program="docx",
  )
}

///|
fn convert_command() -> @argparse.Command {
  Command(
    "convert",
    about="Convert a document to HTML or Markdown",
    flags=[FlagArg("pretty-print", about="Pretty-print generated HTML.")],
    options=[
      OptionArg(
        "style-map",
        long="style-map",
        about="Read Mammoth style-map lines from a file.",
      ),
      OptionArg(
        "output-format",
        long="output-format",
        about="Output format: html or markdown.",
        default_values=["html"],
      ),
      OptionArg(
        "output-dir",
        long="output-dir",
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
fn first_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) => if values.length() > 0 { Some(values[0]) } else { None }
    None => None
  }
}
