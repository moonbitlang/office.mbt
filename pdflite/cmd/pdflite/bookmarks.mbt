///|
fn pdflite_cmd_bookmarks_command() -> @argparse.Command {
  Command(
    "bookmarks",
    about="Export, replace, or remove bookmarks.",
    subcommand_required=true,
    subcommands=[
      Command(
        "export",
        about="Export bookmarks as JSON or cpdf text.",
        positionals=[pdflite_cmd_path("input")],
        options=[
          OptionArg(
            "output",
            long="output",
            about="Output file; defaults to stdout.",
          ),
        ],
        flags=[
          FlagArg(
            "text",
            about="Use cpdf text format instead of JSON with preserved actions.",
          ),
        ],
      ),
      Command(
        "import",
        about="Replace bookmarks from JSON or cpdf text.",
        positionals=[
          pdflite_cmd_path("input"),
          pdflite_cmd_path("output"),
          pdflite_cmd_path("bookmarks"),
        ],
        flags=[FlagArg("text", about="Read cpdf text format instead of JSON.")],
      ),
      Command("remove", about="Remove all bookmarks.", positionals=[
        pdflite_cmd_path("input"),
        pdflite_cmd_path("output"),
      ]),
    ],
  )
}

///|
async fn pdflite_cmd_bookmarks_execute(
  options : @argparse.Matches,
  passwords? : PdflitePasswords = { user: None, owner: None, },
) -> Unit {
  let (action, args) = pdflite_cmd_action(options)
  let document = pdflite_cmd_load(
    pdflite_cmd_single_value(args, "input"),
    passwords~,
  )
  match action {
    "export" => {
      let bytes = if pdflite_cmd_flag_value(args, "text") {
        document.list_bookmarks(pdflite_cmd_select_pages(document, "all"))
      } else {
        document.bookmarks_json_blob(json_preserve_actions=true)
      }
      pdflite_cmd_emit(bytes, pdflite_cmd_optional_value(args, "output"))
    }
    "import" => {
      let bytes = @fs.read_file(pdflite_cmd_single_value(args, "bookmarks")).binary()
      let updated = if pdflite_cmd_flag_value(args, "text") {
        document.add_bookmarks_from_text(bytes, verify=true)
      } else {
        document.add_bookmarks_from_json(
          @json.parse(@utf8.decode(bytes)),
          verify=true,
        )
      }
      pdflite_cmd_save(updated, pdflite_cmd_single_value(args, "output"))
    }
    "remove" =>
      pdflite_cmd_save(
        document.remove_bookmarks(),
        pdflite_cmd_single_value(args, "output"),
      )
    _ => raise Usage("unknown bookmarks action: \{action}")
  }
}

///|
async fn pdflite_cmd_bookmarks_run(
  options : @argparse.Matches,
  passwords? : PdflitePasswords = { user: None, owner: None, },
) -> Int {
  pdflite_cmd_bookmarks_execute(options, passwords~) catch {
    err => return pdflite_cmd_operation_error(err)
  }
  pdflite_cmd_exit_ok
}
