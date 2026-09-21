///|
let pdflite_cmd_metadata_fields : Array[(String, String)] = [
  ("title", "/Title"),
  ("author", "/Author"),
  ("subject", "/Subject"),
  ("keywords", "/Keywords"),
  ("creator", "/Creator"),
  ("producer", "/Producer"),
  ("creation-date", "/CreationDate"),
  ("modification-date", "/ModDate"),
]

///|
fn pdflite_cmd_metadata_command() -> @argparse.Command {
  Command(
    "metadata",
    about="Read and edit Info fields and XMP metadata.",
    subcommand_required=true,
    subcommands=[
      Command(
        "get",
        about="Print standard Info fields as JSON.",
        positionals=[pdflite_cmd_path("input")],
        options=[
          OptionArg(
            "output",
            long="output",
            about="Write JSON to a file instead of stdout.",
          ),
        ],
      ),
      Command(
        "set",
        about="Set one or more standard Info fields.",
        positionals=[pdflite_cmd_path("input"), pdflite_cmd_path("output")],
        options=pdflite_cmd_metadata_fields.map(field => {
          OptionArg(field.0, long=field.0, about=field.1)
        }),
        flags=[
          FlagArg("xmp-also", about="Also update XMP, creating it if absent."),
        ],
      ),
      Command(
        "export",
        about="Export the catalog XMP XML bytes.",
        positionals=[pdflite_cmd_path("input")],
        options=[
          OptionArg(
            "output",
            long="output",
            about="Write XML to a file instead of stdout.",
          ),
        ],
      ),
      Command("import", about="Replace catalog XMP from an XML file.", positionals=[
        pdflite_cmd_path("input"),
        pdflite_cmd_path("output"),
        pdflite_cmd_path("xml"),
      ]),
      Command(
        "remove",
        about="Remove Info and/or XMP metadata.",
        positionals=[pdflite_cmd_path("input"), pdflite_cmd_path("output")],
        options=[
          OptionArg(
            "scope",
            long="scope",
            default_values=["all"],
            about="info, xmp, or all (default).",
          ),
        ],
      ),
    ],
  )
}

///|
async fn pdflite_cmd_metadata_execute(
  options : @argparse.Matches,
  passwords? : PdflitePasswords = { user: None, owner: None, },
) -> Unit {
  let (action, args) = pdflite_cmd_action(options)
  let input = pdflite_cmd_single_value(args, "input")
  let document = pdflite_cmd_load(input, passwords~)
  match action {
    "get" => {
      let fields : Map[String, Json] = Map([])
      for field in pdflite_cmd_metadata_fields {
        fields.set(field.0, Json::string(document.info_utf8_string(field.1)))
      }
      pdflite_cmd_emit(
        @utf8.encode(Json::object(fields).stringify() + "\n"),
        pdflite_cmd_optional_value(args, "output"),
      )
    }
    "export" => {
      guard document.metadata() is Some(bytes) else {
        raise Runtime("input PDF has no catalog XMP metadata")
      }
      pdflite_cmd_emit(bytes, pdflite_cmd_optional_value(args, "output"))
    }
    "set" => {
      let fields = pdflite_cmd_metadata_fields.filter(field => {
        pdflite_cmd_optional_value(args, field.0) is Some(_)
      })
      guard !fields.is_empty() else {
        raise Usage("metadata set requires at least one field option")
      }
      let xmp_also = pdflite_cmd_flag_value(args, "xmp-also")
      let mut updated = if xmp_also && document.metadata() is None {
        document.create_metadata()
      } else {
        document
      }
      for field in fields {
        let value = pdflite_cmd_single_value(args, field.0)
        let bytes = @pdf.pdf_pdfdocstring_of_utf8(@utf8.encode(value))
        updated = updated.set_info_entry_string(
          (field.1, PdfString(bytes), 1),
          xmp_also~,
        )
      }
      pdflite_cmd_save(updated, pdflite_cmd_single_value(args, "output"))
    }
    "import" => {
      let bytes = @fs.read_file(pdflite_cmd_single_value(args, "xml")).binary()
      ignore(@pdf.pdf_xmltree_of_bytes(bytes))
      pdflite_cmd_save(
        document.set_metadata_from_bytes(bytes),
        pdflite_cmd_single_value(args, "output"),
      )
    }
    "remove" => {
      let scope = pdflite_cmd_single_value(args, "scope")
      guard scope == "info" || scope == "xmp" || scope == "all" else {
        raise Usage("--scope must be info, xmp, or all")
      }
      let updated = if scope == "info" {
        document.copy()
      } else {
        document.remove_all_metadata()
      }
      if scope != "xmp" {
        updated.set_trailer_dict(
          updated
          .trailer_dict()
          .remove_dict_entry(@core.pdf_name_of_bytes(@utf8.encode("/Info"))),
        )
      }
      pdflite_cmd_save(updated, pdflite_cmd_single_value(args, "output"))
    }
    _ => raise Usage("unknown metadata action: \{action}")
  }
}

///|
async fn pdflite_cmd_metadata_run(
  options : @argparse.Matches,
  passwords? : PdflitePasswords = { user: None, owner: None, },
) -> Int {
  pdflite_cmd_metadata_execute(options, passwords~) catch {
    err => return pdflite_cmd_operation_error(err)
  }
  pdflite_cmd_exit_ok
}
