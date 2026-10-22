///|
/// The complete existing-PDF command family mounted as office pdf.
pub fn command() -> @argparse.Command {
  Command(
    "pdf",
    about="Inspect and rewrite PDF files.",
    options=[
      OptionArg(
        "password",
        long="password",
        global=true,
        about="User password (UTF-8).",
        conflicts_with=["password-file"],
      ),
      OptionArg(
        "password-file",
        long="password-file",
        global=true,
        about="File containing exact user password bytes.",
      ),
      OptionArg(
        "owner-password",
        long="owner-password",
        global=true,
        about="Owner password (UTF-8).",
        conflicts_with=["owner-password-file"],
      ),
      OptionArg(
        "owner-password-file",
        long="owner-password-file",
        global=true,
        about="File containing exact owner password bytes.",
      ),
    ],
    flags=[
      FlagArg("json", global=true, about="Print office.output/1 JSON."),
      FlagArg("jsonl", global=true, about="Print one office.output/1 line."),
      FlagArg("dry-run", global=true, about="Validate without writing any file."),
      FlagArg("overwrite", global=true, about="Replace an existing destination."),
    ],
    subcommand_required=true,
    disable_help_subcommand=true,
    subcommands=[
      Command(
        "extract",
        about="Extract selected pages into a new PDF file.",
        positionals=[
          PositionArg(
            "input",
            about="Input PDF path.",
            num_args=@argparse.ValueRange::single(),
          ),
          PositionArg(
            "output",
            about="Output PDF path.",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
        options=[
          OptionArg(
            "pages",
            long="pages",
            required=true,
            about="1-based page specification, e.g. 1-3,5 or 3,1,3.",
          ),
        ],
        flags=[
          FlagArg(
            "retain-numbering",
            about="Preserve original page-label numbering.",
          ),
          FlagArg(
            "process-struct-tree",
            about="Trim tagged structure references to deleted pages.",
          ),
        ],
      ),
      Command(
        "info",
        about="Print basic metadata for one PDF file.",
        positionals=[
          PositionArg(
            "input",
            about="Input PDF path.",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
        flags=[
          FlagArg("detailed", about="Print full document information."),
        ],
      ),
      Command("decrypt", about="Write an unencrypted PDF.", positionals=[
        pdflite_cmd_path("input"),
        pdflite_cmd_path("output"),
      ]),
      pdflite_cmd_merge_command(),
      pdflite_cmd_pages_command(),
      pdflite_cmd_fonts_command(),
      pdflite_cmd_labels_command(),
      pdflite_cmd_metadata_command(),
      pdflite_cmd_bookmarks_command(),
      Command("rewrite", about="Parse, write, and verify a PDF file.", positionals=[
        PositionArg(
          "input",
          about="Input PDF path.",
          num_args=@argparse.ValueRange::single(),
        ),
        PositionArg(
          "output",
          about="Output PDF path.",
          num_args=@argparse.ValueRange::single(),
        ),
      ]),
      Command(
        "validate",
        about="Parse and round-trip a PDF without writing a file.",
        positionals=[
          PositionArg(
            "input",
            about="Input PDF path.",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
    ],
  )
}


///|
fn pdflite_cmd_single_value(
  matches : @argparse.Matches,
  name : String,
) -> String raise {
  match matches.values.get(name) {
    Some(values) if values.length() == 1 => values[0]
    _ => fail("argparse did not return one value for " + name)
  }
}


///|
fn pdflite_cmd_multiple_values(
  matches : @argparse.Matches,
  name : String,
) -> Array[String] raise {
  guard matches.values.get(name) is Some(values) else {
    fail("argparse did not return multiple values for " + name)
  }
  guard values.length() >= 2 else {
    fail("argparse did not return multiple values for " + name)
  }
  values
}


///|
fn pdflite_cmd_flag_value(matches : @argparse.Matches, name : String) -> Bool {
  matches.flags.get(name).unwrap_or(false)
}

