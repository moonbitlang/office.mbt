///|
fn pdf2md_command() -> @argparse.Command {
  Command("pdf2md", about="Extract Markdown text from a PDF file.", positionals=[
    PositionArg(
      "input",
      about="Input PDF path.",
      num_args=@argparse.ValueRange::single(),
    ),
    PositionArg(
      "output",
      about="Output Markdown path.",
      num_args=@argparse.ValueRange::single(),
    ),
  ])
}

///|
fn pdf2md_single_value(
  matches : @argparse.Matches,
  name : String,
) -> String raise {
  match matches.values.get(name) {
    Some(values) if values.length() == 1 => values[0]
    _ => fail("argparse did not return one value for " + name)
  }
}

///|
fn pdf2md_parse_args(argv : ArrayView[String]) -> (String, String) raise {
  let command = pdf2md_command()
  let matches = command.parse(argv~, env=Map([]))
  (
    pdf2md_single_value(matches, "input"),
    pdf2md_single_value(matches, "output"),
  )
}

///|
async fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  let (input_path, output_path) = pdf2md_parse_args(args)
  pdf2md_convert_file(input_path, output_path)
}

///|
async fn pdf2md_convert_file(input_path : String, output_path : String) -> Unit {
  let markdown = @markdown.pdf_bytes_to_markdown(
    @fs.read_file(input_path).binary(),
  )
  @fs.write_file(
    output_path,
    @utf8.encode(markdown),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
}
