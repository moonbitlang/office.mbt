///|
fn markdown_cmd_command() -> @argparse.Command {
  @argparse.Command(
    "pdflite-markdown",
    about="Extract Markdown text from a PDF file.",
    positionals=[
      @argparse.PositionArg(
        "input",
        about="Input PDF path.",
        num_args=@argparse.ValueRange::single(),
      ),
      @argparse.PositionArg(
        "output",
        about="Output Markdown path.",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  )
}

///|
fn markdown_cmd_single_value(
  matches : @argparse.Matches,
  name : String,
) -> String raise {
  match matches.values.get(name) {
    Some(values) if values.length() == 1 => values[0]
    _ => fail("argparse did not return one value for " + name)
  }
}

///|
fn markdown_cmd_parse_args(argv? : ArrayView[String]) -> (String, String) raise {
  let command = markdown_cmd_command()
  let matches = match argv {
    Some(argv) => command.parse(argv~, env={})
    None => command.parse()
  }
  (
    markdown_cmd_single_value(matches, "input"),
    markdown_cmd_single_value(matches, "output"),
  )
}

///|
async fn main {
  let (input_path, output_path) = markdown_cmd_parse_args()
  markdown_cmd_convert_file(input_path, output_path)
}

///|
async fn markdown_cmd_convert_file(
  input_path : String,
  output_path : String,
) -> Unit {
  let markdown = @markdown.pdf_bytes_to_markdown(
    @fs.read_file(input_path).binary(),
  )
  @fs.write_file(output_path, @utf8.encode(markdown), create=0o644)
}
