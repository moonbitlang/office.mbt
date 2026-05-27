///|
let pdflite_cmd_version = "0.1.29"

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
  PdfliteCmdInfo(String, Bool)
  PdfliteCmdRewrite(String, String)
  PdfliteCmdValidate(String)
}

///|
fn pdflite_cmd_command() -> @argparse.Command {
  Command(
    "pdflite",
    about="Inspect and rewrite PDF files.",
    version="pdflite " + pdflite_cmd_version,
    subcommand_required=true,
    disable_help_subcommand=true,
    subcommands=[
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
        flags=[FlagArg("json", about="Print metadata as JSON.")],
      ),
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
fn pdflite_cmd_flag_value(matches : @argparse.Matches, name : String) -> Bool {
  matches.flags.get(name).unwrap_or(false)
}

///|
fn pdflite_cmd_parse_args(args : ArrayView[String]) -> PdfliteCmd raise {
  let matches = pdflite_cmd_command().parse(argv=args, env={})
  match matches.subcommand {
    Some(("info", subcommand)) =>
      PdfliteCmdInfo(
        pdflite_cmd_single_value(subcommand, "input"),
        pdflite_cmd_flag_value(subcommand, "json"),
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
  let command = pdflite_cmd_parse_args(args) catch {
    err => {
      @stdio.stderr.write(err.to_string() + "\n")
      return pdflite_cmd_exit_usage_error
    }
  }
  let result = match command {
    PdfliteCmdInfo(input_path, json) => pdflite_cmd_info_file(input_path, json)
    PdfliteCmdRewrite(input_path, output_path) =>
      pdflite_cmd_rewrite_file(input_path, output_path)
    PdfliteCmdValidate(input_path) => pdflite_cmd_validate_file(input_path)
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
) -> Result[@pdflite.PdfDocument, String] {
  let bytes = @fs.read_file(input_path).binary() catch {
    err => return Err("cannot read '" + input_path + "': " + err.to_string())
  }
  let document = @pdflite.pdf_read_document_from_bytes(bytes) catch {
    err =>
      return Err(
        "cannot parse PDF '" + input_path + "': " + @debug.to_string(err),
      )
  }
  Ok(document)
}

///|
fn pdflite_cmd_info_report(
  input_path : String,
  document : @pdflite.PdfDocument,
) -> Result[PdfliteCmdInfoReport, String] {
  let page_count = document.endpage() catch {
    err =>
      return Err(
        "cannot read page tree for '" +
        input_path +
        "': " +
        @debug.to_string(err),
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
) -> Result[Unit, String] {
  let document = match pdflite_cmd_read_document(input_path) {
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
  document : @pdflite.PdfDocument,
  source_path : String,
) -> Result[Bytes, String] {
  let output = @pdflite.pdf_write_document(document) catch {
    err =>
      return Err(
        "cannot rewrite PDF '" + source_path + "': " + @debug.to_string(err),
      )
  }
  Ok(output)
}

///|
fn pdflite_cmd_verify_rewritten_bytes(
  output : Bytes,
  source_path : String,
) -> Result[Unit, String] {
  let rewritten = @pdflite.pdf_read_document_from_bytes(output) catch {
    err =>
      return Err(
        "rewritten PDF from '" +
        source_path +
        "' does not parse: " +
        @debug.to_string(err),
      )
  }
  let _ = rewritten.endpage() catch {
    err =>
      return Err(
        "rewritten PDF from '" +
        source_path +
        "' has an unreadable page tree: " +
        @debug.to_string(err),
      )
  }
  Ok(())
}

///|
async fn pdflite_cmd_rewrite_file(
  input_path : String,
  output_path : String,
) -> Result[Unit, String] {
  let document = match pdflite_cmd_read_document(input_path) {
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
  @fs.write_file(output_path, output, create=0o644) catch {
    err => return Err("cannot write '" + output_path + "': " + err.to_string())
  }
  Ok(())
}

///|
async fn pdflite_cmd_validate_file(input_path : String) -> Result[Unit, String] {
  let document = match pdflite_cmd_read_document(input_path) {
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
