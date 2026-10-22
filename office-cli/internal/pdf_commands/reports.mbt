///|
fn pdflite_cmd_pages_command() -> @argparse.Command {
  Command(
    "pages",
    about="Print dimensions, boxes, and rotation for selected pages.",
    positionals=[pdflite_cmd_path("input")],
    options=[
      OptionArg(
        "pages",
        long="pages",
        default_values=["all"],
        about="1-based page selection.",
      ),
      OptionArg(
        "output",
        long="output",
        about="Output file; defaults to stdout.",
      ),
    ],
  )
}

