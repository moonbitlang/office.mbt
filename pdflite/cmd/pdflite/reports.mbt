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
    flags=[FlagArg("json", about="Print JSON.")],
  )
}

///|
async fn pdflite_cmd_report(args : @argparse.Matches, per_page : Bool) -> Unit {
  let document = pdflite_cmd_load(pdflite_cmd_single_value(args, "input"))
  let json = pdflite_cmd_flag_value(args, "json")
  let bytes = if per_page {
    let pages = pdflite_cmd_select_pages(
      document,
      pdflite_cmd_single_value(args, "pages"),
    )
    if json {
      document.page_info_json_blob(pages)
    } else {
      document.page_info_text(pages)
    }
  } else if json {
    document.info_json_blob()
  } else {
    document.info_blob()
  }
  pdflite_cmd_emit(bytes, pdflite_cmd_optional_value(args, "output"))
}

///|
async fn pdflite_cmd_pages_run(options : @argparse.Matches) -> Int {
  pdflite_cmd_report(options, true) catch {
    err => return pdflite_cmd_operation_error(err)
  }
  pdflite_cmd_exit_ok
}

///|
async fn pdflite_cmd_detailed_info_run(options : @argparse.Matches) -> Int {
  pdflite_cmd_report(options, false) catch {
    err => return pdflite_cmd_operation_error(err)
  }
  pdflite_cmd_exit_ok
}
