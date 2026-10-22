///|
fn pdflite_cmd_fonts_command() -> @argparse.Command {
  Command(
    "fonts",
    about="List fonts or diagnose missing embedded font programs.",
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
    flags=[
      FlagArg("missing", about="Only report fonts without embedded programs."),
    ],
  )
}
