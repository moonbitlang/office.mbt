///|
fn pdflite_cmd_labels_command() -> @argparse.Command {
  Command(
    "labels",
    about="Export, replace, or remove page labels.",
    subcommand_required=true,
    subcommands=[
      Command(
        "export",
        about="Export page-label ranges as JSON.",
        positionals=[pdflite_cmd_path("input")],
        options=[
          OptionArg(
            "output",
            long="output",
            about="Output file; defaults to stdout.",
          ),
        ],
      ),
      Command("import", about="Replace page-label ranges from JSON.", positionals=[
        pdflite_cmd_path("input"),
        pdflite_cmd_path("output"),
        pdflite_cmd_path("labels"),
      ]),
      Command("remove", about="Remove page labels.", positionals=[
        pdflite_cmd_path("input"),
        pdflite_cmd_path("output"),
      ]),
    ],
  )
}

///|
async fn pdflite_cmd_labels_execute(options : @argparse.Matches) -> Unit {
  let (action, args) = pdflite_cmd_action(options)
  let document = pdflite_cmd_load(pdflite_cmd_single_value(args, "input"))
  match action {
    "export" => {
      let rows : Array[Json] = []
      for label in document.read_page_labels() {
        let prefix = label.label_prefix
          .map(bytes => {
            Json::string(@utf8.decode(@pdf.pdf_utf8_of_pdfdocstring(bytes)))
          })
          .unwrap_or(Json::null())
        rows.push(
          Json::object({
            "labelstyle": Json::string(label.label_style.debug_name()),
            "labelprefix": prefix,
            "startpage": pdflite_cmd_json_number(label.start_page),
            "startvalue": pdflite_cmd_json_number(label.start_value),
          }),
        )
      }
      pdflite_cmd_emit(
        @utf8.encode(Json::array(rows).stringify() + "\n"),
        pdflite_cmd_optional_value(args, "output"),
      )
    }
    "import" => {
      let bytes = @fs.read_file(pdflite_cmd_single_value(args, "labels")).binary()
      let updated = document.add_page_labels_json(
        @json.parse(@utf8.decode(bytes)),
      )
      let count = document.endpage()
      let labels = updated.read_page_labels()
      for index, label in labels {
        guard label.start_page >= 1 &&
          label.start_page <= count &&
          label.start_value >= 1 else {
          raise Usage(
            "label startpage must be in the document and startvalue must be positive",
          )
        }
        if index > 0 && label.start_page <= labels[index - 1].start_page {
          raise Usage("label start pages must be unique and increasing")
        }
      }
      pdflite_cmd_save(updated, pdflite_cmd_single_value(args, "output"))
    }
    "remove" =>
      pdflite_cmd_save(
        document.remove_page_labels(),
        pdflite_cmd_single_value(args, "output"),
      )
    _ => raise Usage("unknown labels action: \{action}")
  }
}

///|
async fn pdflite_cmd_labels_run(options : @argparse.Matches) -> Int {
  pdflite_cmd_labels_execute(options) catch {
    err => return pdflite_cmd_operation_error(err)
  }
  pdflite_cmd_exit_ok
}
