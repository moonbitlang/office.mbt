// Agent-oriented structured reads: `outline` prints a versioned JSON
// document map built by the `docx2html/inspect` library package; see
// docs/agent-json-schemas.md for the normative payload spec.

///|
/// `docx outline <file>` — prints the `docx.outline/1` structure map.
async fn run_outline(matches : @argparse.Matches) -> Unit {
  let file = match first_value(matches, "file") {
    Some(value) => value
    None =>
      raise @cli.CliError(
        "error: the following required argument was not provided: 'file'",
      )
  }
  let data = @afs.read_file(file).binary()
  let result = @docx2html.read_docx_with_messages(data)
  println(
    @inspect.outline(result.document, file~, messages=result.messages).stringify(
      indent=2,
    ),
  )
}

///|
fn outline_command() -> @argparse.Command {
  Command("outline", about="Print a document structure map as JSON", positionals=[
    PositionArg(
      "file",
      about="Input .docx file.",
      num_args=ValueRange(lower=1, upper=1),
    ),
  ])
}
