///|
/// `docx create <output>` — writes a minimal, schema-valid blank document
/// (one empty paragraph, Normal style, Letter page). The write foundation's
/// only authoring surface until the content writers land; both validation
/// tiers gate its output in tests.
async fn run_create(matches : @argparse.Matches) -> Unit {
  let output = required_value(matches, "output")
  @afs.write_file(
    output,
    @docx2html.new_blank_docx(),
    create_mode=CreateOrTruncate,
  )
  println("created \{output}")
}

///|
fn create_command() -> @argparse.Command {
  Command("create", about="Create a new blank .docx document", positionals=[
    PositionArg(
      "output",
      about="Output .docx path.",
      num_args=ValueRange(lower=1, upper=1),
    ),
  ])
}
