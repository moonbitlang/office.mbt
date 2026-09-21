///|
fn pdflite_cmd_merge_command() -> @argparse.Command {
  Command(
    "merge",
    about="Merge PDF files in the supplied order.",
    positionals=[
      PositionArg(
        "output",
        about="Output PDF path.",
        num_args=@argparse.ValueRange::single(),
      ),
      PositionArg(
        "inputs",
        about="Input PDF paths, in output page order.",
        num_args=ValueRange(lower=2),
      ),
    ],
    options=[
      OptionArg(
        "pages",
        long="pages",
        action=Append,
        about="Repeat once per input, in input order; use all for whole files.",
      ),
    ],
    flags=[
      FlagArg(
        "retain-numbering",
        about="Preserve original page-label numbering.",
      ),
      FlagArg(
        "remove-duplicate-fonts",
        about="Remove duplicate font resources.",
      ),
      FlagArg(
        "add-toplevel-document",
        about="Wrap retained structure trees in Document elements.",
      ),
      FlagArg("drop-bookmarks", about="Do not retain bookmarks."),
      FlagArg(
        "drop-optional-content",
        about="Do not retain optional content groups.",
      ),
      FlagArg("drop-acroforms", about="Do not retain AcroForms."),
      FlagArg(
        "drop-named-destinations",
        about="Do not retain named destinations.",
      ),
      FlagArg(
        "drop-name-dictionary",
        about="Do not retain other name dictionary entries.",
      ),
      FlagArg(
        "drop-structure-tree",
        about="Do not retain tagged structure trees.",
      ),
      FlagArg("drop-info", about="Do not retain document information."),
      FlagArg(
        "drop-catalog-entries",
        about="Do not retain additional catalog entries.",
      ),
    ],
  )
}

///|
async fn pdflite_cmd_merge_selected(
  output : String,
  inputs : Array[String],
  options : @argparse.Matches,
  passwords? : PdflitePasswords = { user: None, owner: None, },
) -> Unit {
  let specs = options.values.get("pages").unwrap_or([])
  guard specs.is_empty() || specs.length() == inputs.length() else {
    raise Usage(
      "--pages must be omitted or repeated exactly once per input PDF",
    )
  }
  let documents : Array[@pdf.PdfDocument] = []
  let ranges : Array[Array[Int]] = []
  for index, input in inputs {
    let document = pdflite_cmd_load(input, passwords~)
    let pages = pdflite_cmd_select_pages(
      document,
      if specs.is_empty() {
        "all"
      } else {
        specs[index]
      },
    )
    documents.push(document)
    ranges.push(pages)
  }
  let merged = @pdf.pdf_merge_documents(
    documents,
    ranges,
    retain_numbering=pdflite_cmd_flag_value(options, "retain-numbering"),
    remove_duplicate_fonts=pdflite_cmd_flag_value(
      options, "remove-duplicate-fonts",
    ),
    add_toplevel_document=pdflite_cmd_flag_value(
      options, "add-toplevel-document",
    ),
    retain_bookmarks=!pdflite_cmd_flag_value(options, "drop-bookmarks"),
    retain_optional_content=!pdflite_cmd_flag_value(
      options, "drop-optional-content",
    ),
    retain_acroforms=!pdflite_cmd_flag_value(options, "drop-acroforms"),
    retain_named_destinations=!pdflite_cmd_flag_value(
      options, "drop-named-destinations",
    ),
    retain_name_dictionary=!pdflite_cmd_flag_value(
      options, "drop-name-dictionary",
    ),
    retain_structure_tree=!pdflite_cmd_flag_value(
      options, "drop-structure-tree",
    ),
    retain_info=!pdflite_cmd_flag_value(options, "drop-info"),
    retain_catalog_entries=!pdflite_cmd_flag_value(
      options, "drop-catalog-entries",
    ),
  )
  let expected = ranges.fold(init=0, (count, pages) => count + pages.length())
  let bytes = @pdf.pdf_write_document(merged)
  match pdflite_cmd_verify_merged_bytes(bytes, expected) {
    Ok(_) => ()
    Err(message) => raise Runtime(message)
  }
  match pdflite_cmd_write_output_file(output, bytes) {
    Ok(_) => ()
    Err(message) => raise Runtime(message)
  }
}

///|
async fn pdflite_cmd_merge_run(
  output : String,
  inputs : Array[String],
  options : @argparse.Matches,
  passwords? : PdflitePasswords = { user: None, owner: None, },
) -> Int {
  pdflite_cmd_merge_selected(output, inputs, options, passwords~) catch {
    err => return pdflite_cmd_operation_error(err)
  }
  pdflite_cmd_exit_ok
}
