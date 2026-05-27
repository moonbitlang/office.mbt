///|
let pdflite_cmd_version = "0.1.29"

///|
priv enum PdfliteCmd {
  PdfliteCmdInfo(String)
  PdfliteCmdRewrite(String, String)
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
      Command("info", about="Print basic metadata for one PDF file.", positionals=[
        PositionArg(
          "input",
          about="Input PDF path.",
          num_args=@argparse.ValueRange::single(),
        ),
      ]),
      Command("rewrite", about="Parse and write a PDF file.", positionals=[
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
fn pdflite_cmd_parse_args(args : ArrayView[String]) -> PdfliteCmd raise {
  let matches = pdflite_cmd_command().parse(argv=args, env={})
  match matches.subcommand {
    Some(("info", subcommand)) =>
      PdfliteCmdInfo(pdflite_cmd_single_value(subcommand, "input"))
    Some(("rewrite", subcommand)) =>
      PdfliteCmdRewrite(
        pdflite_cmd_single_value(subcommand, "input"),
        pdflite_cmd_single_value(subcommand, "output"),
      )
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
      return 2
    }
  }
  let result = match command {
    PdfliteCmdInfo(input_path) => pdflite_cmd_info_file(input_path)
    PdfliteCmdRewrite(input_path, output_path) =>
      pdflite_cmd_rewrite_file(input_path, output_path)
  }
  match result {
    Ok(_) => 0
    Err(message) => {
      @stdio.stderr.write("pdflite: " + message + "\n")
      1
    }
  }
}

///|
async fn pdflite_cmd_info_file(input_path : String) -> Result[Unit, String] {
  let bytes = @fs.read_file(input_path).binary() catch {
    err => return Err(err.to_string())
  }
  let document = @pdflite.pdf_read_document_from_bytes(bytes) catch {
    err => return Err(@debug.to_string(err))
  }
  let page_count = document.endpage() catch {
    err => return Err(@debug.to_string(err))
  }
  let text = pdflite_cmd_info_text(input_path, document, page_count)
  @stdio.stdout.write(text)
  Ok(())
}

///|
fn pdflite_cmd_info_text(
  input_path : String,
  document : @pdflite.PdfDocument,
  page_count : Int,
) -> String {
  let (major, minor) = document.version()
  "path: " +
  input_path +
  "\nversion: " +
  major.to_string() +
  "." +
  minor.to_string() +
  "\npages: " +
  page_count.to_string() +
  "\nobjects: " +
  document.object_count().to_string() +
  "\nencrypted: " +
  document.is_encrypted().to_string() +
  "\n"
}

///|
async fn pdflite_cmd_rewrite_file(
  input_path : String,
  output_path : String,
) -> Result[Unit, String] {
  let bytes = @fs.read_file(input_path).binary() catch {
    err => return Err(err.to_string())
  }
  let document = @pdflite.pdf_read_document_from_bytes(bytes) catch {
    err => return Err(@debug.to_string(err))
  }
  let output = @pdflite.pdf_write_document(document) catch {
    err => return Err(@debug.to_string(err))
  }
  @fs.write_file(output_path, output, create=0o644) catch {
    err => return Err(err.to_string())
  }
  Ok(())
}
