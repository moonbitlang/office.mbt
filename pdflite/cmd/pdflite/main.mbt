///|
let pdflite_cmd_version = "0.1.38"

///|
let pdflite_cmd_exit_ok = 0

///|
let pdflite_cmd_exit_runtime_error = 1

///|
let pdflite_cmd_exit_usage_error = 2

///|
priv struct PdfliteCmdInfoReport {
  path : String
  version : String
  pages : Int
  objects : Int
  encrypted : Bool
}

///|
priv enum PdfliteCmd {
  PdfliteCmdDetailedInfo(@argparse.Matches)
  PdfliteCmdPages(@argparse.Matches)
  PdfliteCmdFonts(@argparse.Matches)
  PdfliteCmdLabels(@argparse.Matches)
  PdfliteCmdBookmarks(@argparse.Matches)
  PdfliteCmdMetadata(@argparse.Matches)
  PdfliteCmdExtract(String, String, String, Bool, Bool)
  PdfliteCmdInfo(String, Bool)
  PdfliteCmdMerge(String, Array[String], @argparse.Matches)
  PdfliteCmdDecrypt(String, String)
  PdfliteCmdRewrite(String, String)
  PdfliteCmdValidate(String)
}

///|
fn pdflite_cmd_command() -> @argparse.Command {
  Command(
    "pdflite",
    about="Inspect and rewrite PDF files.",
    version="pdflite " + pdflite_cmd_version,
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
          FlagArg("json", about="Print metadata as JSON."),
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

///|
fn pdflite_cmd_from_matches(matches : @argparse.Matches) -> PdfliteCmd raise {
  match matches.subcommand {
    Some(("extract", subcommand)) =>
      PdfliteCmdExtract(
        pdflite_cmd_single_value(subcommand, "input"),
        pdflite_cmd_single_value(subcommand, "output"),
        pdflite_cmd_single_value(subcommand, "pages"),
        pdflite_cmd_flag_value(subcommand, "retain-numbering"),
        pdflite_cmd_flag_value(subcommand, "process-struct-tree"),
      )
    Some(("info", subcommand)) if pdflite_cmd_flag_value(subcommand, "detailed") =>
      PdfliteCmdDetailedInfo(subcommand)
    Some(("info", subcommand)) =>
      PdfliteCmdInfo(
        pdflite_cmd_single_value(subcommand, "input"),
        pdflite_cmd_flag_value(subcommand, "json"),
      )
    Some(("bookmarks", subcommand)) => PdfliteCmdBookmarks(subcommand)
    Some(("labels", subcommand)) => PdfliteCmdLabels(subcommand)
    Some(("fonts", subcommand)) => PdfliteCmdFonts(subcommand)
    Some(("pages", subcommand)) => PdfliteCmdPages(subcommand)
    Some(("metadata", subcommand)) => PdfliteCmdMetadata(subcommand)
    Some(("merge", subcommand)) =>
      PdfliteCmdMerge(
        pdflite_cmd_single_value(subcommand, "output"),
        pdflite_cmd_multiple_values(subcommand, "inputs"),
        subcommand,
      )
    Some(("decrypt", subcommand)) =>
      PdfliteCmdDecrypt(
        pdflite_cmd_single_value(subcommand, "input"),
        pdflite_cmd_single_value(subcommand, "output"),
      )
    Some(("rewrite", subcommand)) =>
      PdfliteCmdRewrite(
        pdflite_cmd_single_value(subcommand, "input"),
        pdflite_cmd_single_value(subcommand, "output"),
      )
    Some(("validate", subcommand)) =>
      PdfliteCmdValidate(pdflite_cmd_single_value(subcommand, "input"))
    Some((name, _)) => fail("unexpected subcommand: " + name)
    None => fail("argparse did not return a subcommand")
  }
}

///|
async fn main {
  let all_args = @env.args()
  let args = if all_args.is_empty() { all_args[:] } else { all_args[1:] }
  let code = pdflite_cmd_run(args)
  if code != 0 {
    @sys.exit(code)
  }
}

///|
async fn pdflite_cmd_run(args : ArrayView[String]) -> Int {
  let matches = pdflite_cmd_command().parse(argv=args, env=Map([])) catch {
    err => {
      @stdio.stderr.write(err.to_string() + "\n")
      return pdflite_cmd_exit_usage_error
    }
  }
  let command = pdflite_cmd_from_matches(matches) catch {
    err => return pdflite_cmd_operation_error(err)
  }
  let passwords = pdflite_cmd_passwords(matches) catch {
    err => return pdflite_cmd_operation_error(err)
  }
  let result = match command {
    PdfliteCmdDecrypt(input, output) => {
      let passwords = if passwords.user is None && passwords.owner is None {
        { user: Some(@utf8.encode("")), owner: None, }
      } else {
        passwords
      }
      pdflite_cmd_rewrite_file(input, output, passwords~)
    }
    PdfliteCmdDetailedInfo(options) =>
      return pdflite_cmd_detailed_info_run(options, passwords~)
    PdfliteCmdPages(options) =>
      return pdflite_cmd_pages_run(options, passwords~)
    PdfliteCmdFonts(options) =>
      return pdflite_cmd_fonts_run(options, passwords~)
    PdfliteCmdLabels(options) =>
      return pdflite_cmd_labels_run(options, passwords~)
    PdfliteCmdBookmarks(options) =>
      return pdflite_cmd_bookmarks_run(options, passwords~)
    PdfliteCmdMetadata(options) =>
      return pdflite_cmd_metadata_run(options, passwords~)
    PdfliteCmdExtract(
      input_path,
      output_path,
      pages,
      retain_numbering,
      process_struct_tree
    ) =>
      return pdflite_cmd_extract_file(
        input_path,
        output_path,
        pages,
        retain_numbering,
        process_struct_tree,
        passwords~,
      )
    PdfliteCmdInfo(input_path, json) =>
      pdflite_cmd_info_file(input_path, json, passwords~)
    PdfliteCmdMerge(output_path, input_paths, options) =>
      return pdflite_cmd_merge_run(
        output_path,
        input_paths,
        options,
        passwords~,
      )
    PdfliteCmdRewrite(input_path, output_path) =>
      pdflite_cmd_rewrite_file(input_path, output_path, passwords~)
    PdfliteCmdValidate(input_path) =>
      pdflite_cmd_validate_file(input_path, passwords~)
  }
  match result {
    Ok(_) => pdflite_cmd_exit_ok
    Err(message) => {
      @stdio.stderr.write("pdflite: " + message + "\n")
      pdflite_cmd_exit_runtime_error
    }
  }
}

///|
async fn pdflite_cmd_read_document(
  input_path : String,
  passwords? : PdflitePasswords = { user: None, owner: None, },
) -> Result[@pdf.PdfDocument, String] {
  let bytes = @fs.read_file(input_path).binary() catch {
    err => return Err("cannot read '" + input_path + "': " + err.to_string())
  }
  let document = pdflite_cmd_read_with_passwords(bytes, passwords) catch {
    err =>
      return Err(
        "cannot parse PDF '" + input_path + "': " + @core.pdf_error_summary(err),
      )
  }
  Ok(document)
}

///|
fn pdflite_cmd_info_report(
  input_path : String,
  document : @pdf.PdfDocument,
) -> Result[PdfliteCmdInfoReport, String] {
  let page_count = document.endpage() catch {
    err =>
      return Err(
        "cannot read page tree for '" +
        input_path +
        "': " +
        @core.pdf_error_summary(err),
      )
  }
  let (major, minor) = document.version()
  Ok({
    path: input_path,
    version: major.to_string() + "." + minor.to_string(),
    pages: page_count,
    objects: document.object_count(),
    encrypted: document.is_encrypted(),
  })
}

///|
fn pdflite_cmd_info_text(report : PdfliteCmdInfoReport) -> String {
  "path: " +
  report.path +
  "\nversion: " +
  report.version +
  "\npages: " +
  report.pages.to_string() +
  "\nobjects: " +
  report.objects.to_string() +
  "\nencrypted: " +
  report.encrypted.to_string() +
  "\n"
}

///|
fn pdflite_cmd_json_number(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn pdflite_cmd_info_json_text(report : PdfliteCmdInfoReport) -> String {
  Json::object({
    "encrypted": Json::boolean(report.encrypted),
    "objects": pdflite_cmd_json_number(report.objects),
    "pages": pdflite_cmd_json_number(report.pages),
    "path": Json::string(report.path),
    "version": Json::string(report.version),
  }).stringify() +
  "\n"
}

///|
async fn pdflite_cmd_info_file(
  input_path : String,
  json : Bool,
  passwords? : PdflitePasswords = { user: None, owner: None, },
) -> Result[Unit, String] {
  let document = match pdflite_cmd_read_document(input_path, passwords~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let report = match pdflite_cmd_info_report(input_path, document) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let text = if json {
    pdflite_cmd_info_json_text(report)
  } else {
    pdflite_cmd_info_text(report)
  }
  @stdio.stdout.write(text)
  Ok(())
}

///|
fn pdflite_cmd_write_document_bytes(
  document : @pdf.PdfDocument,
  source_path : String,
) -> Result[Bytes, String] {
  let output = @pdf.pdf_write_document(document) catch {
    err =>
      return Err(
        "cannot rewrite PDF '" +
        source_path +
        "': " +
        @core.pdf_error_summary(err),
      )
  }
  Ok(output)
}

///|
fn pdflite_cmd_verify_rewritten_bytes(
  output : Bytes,
  source_path : String,
) -> Result[Unit, String] {
  let rewritten = @pdf.pdf_read_document_from_bytes(output) catch {
    err =>
      return Err(
        "rewritten PDF from '" +
        source_path +
        "' does not parse: " +
        @core.pdf_error_summary(err),
      )
  }
  let _ = rewritten.endpage() catch {
    err =>
      return Err(
        "rewritten PDF from '" +
        source_path +
        "' has an unreadable page tree: " +
        @core.pdf_error_summary(err),
      )
  }
  Ok(())
}

///|
fn pdflite_cmd_verify_merged_bytes(
  output : Bytes,
  expected_page_count : Int,
) -> Result[Unit, String] {
  let merged = @pdf.pdf_read_document_from_bytes(output) catch {
    err =>
      return Err("merged PDF does not parse: " + @core.pdf_error_summary(err))
  }
  let page_count = merged.endpage() catch {
    err =>
      return Err(
        "merged PDF has an unreadable page tree: " +
        @core.pdf_error_summary(err),
      )
  }
  if page_count == expected_page_count {
    Ok(())
  } else {
    Err(
      "merged PDF has " +
      page_count.to_string() +
      " pages; expected " +
      expected_page_count.to_string(),
    )
  }
}

///|
async fn pdflite_cmd_write_output_file(
  output_path : String,
  output : Bytes,
) -> Result[Unit, String] {
  @fs.write_file(
    output_path,
    output,
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
    err => return Err("cannot write '" + output_path + "': " + err.to_string())
  }
  Ok(())
}

///|
async fn pdflite_cmd_rewrite_file(
  input_path : String,
  output_path : String,
  passwords? : PdflitePasswords = { user: None, owner: None, },
) -> Result[Unit, String] {
  let document = match pdflite_cmd_read_document(input_path, passwords~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let output = match pdflite_cmd_write_document_bytes(document, input_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match pdflite_cmd_verify_rewritten_bytes(output, input_path) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  pdflite_cmd_write_output_file(output_path, output)
}

///|
async fn pdflite_cmd_validate_file(
  input_path : String,
  passwords? : PdflitePasswords = { user: None, owner: None, },
) -> Result[Unit, String] {
  let document = match pdflite_cmd_read_document(input_path, passwords~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let report = match pdflite_cmd_info_report(input_path, document) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let output = match pdflite_cmd_write_document_bytes(document, input_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match pdflite_cmd_verify_rewritten_bytes(output, input_path) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  @stdio.stdout.write(
    "valid: " + input_path + "\n" + pdflite_cmd_info_text(report),
  )
  Ok(())
}
