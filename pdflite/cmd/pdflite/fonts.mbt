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
      FlagArg("json", about="Print JSON."),
      FlagArg("missing", about="Only report fonts without embedded programs."),
    ],
  )
}

///|
async fn pdflite_cmd_fonts_execute(args : @argparse.Matches) -> Unit {
  let document = pdflite_cmd_load(pdflite_cmd_single_value(args, "input"))
  let pages = pdflite_cmd_select_pages(
    document,
    pdflite_cmd_single_value(args, "pages"),
  )
  let json = pdflite_cmd_flag_value(args, "json")
  let bytes = if pdflite_cmd_flag_value(args, "missing") {
    if json {
      let entries = document.missing_fonts(pages)
      @utf8.encode(entries.to_json().stringify() + "\n")
    } else {
      document.missing_fonts_text(pages)
    }
  } else {
    document.print_fonts(pages, json~)
  }
  pdflite_cmd_emit(bytes, pdflite_cmd_optional_value(args, "output"))
}

///|
async fn pdflite_cmd_fonts_run(options : @argparse.Matches) -> Int {
  pdflite_cmd_fonts_execute(options) catch {
    err => return pdflite_cmd_operation_error(err)
  }
  pdflite_cmd_exit_ok
}
