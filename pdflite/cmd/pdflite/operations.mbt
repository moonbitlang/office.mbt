///|
priv suberror PdfliteOperationError {
  Usage(String)
  Runtime(String)
}

///|
fn pdflite_cmd_select_pages(
  document : @pdf.PdfDocument,
  spec : String,
) -> Array[Int] raise {
  let count = document.endpage()
  guard spec != "" else { raise Usage("page specification must not be empty") }
  let pages = @pagespec.pdf_parse_pagespec_for_count(
    count,
    spec,
    strict_bounds=true,
  ) catch {
    err =>
      raise Usage(
        "invalid page specification '\{spec}': \{@core.pdf_error_summary(err)}",
      )
  }
  guard !pages.is_empty() else {
    raise Usage("page specification selects no pages")
  }
  pages
}

///|
async fn pdflite_cmd_load(input : String) -> @pdf.PdfDocument {
  match pdflite_cmd_read_document(input) {
    Ok(document) => document
    Err(message) => raise Runtime(message)
  }
}

///|
async fn pdflite_cmd_operation_error(err : Error) -> Int {
  let (code, message) = match err {
    PdfliteOperationError::Usage(message) =>
      (pdflite_cmd_exit_usage_error, message)
    PdfliteOperationError::Runtime(message) =>
      (pdflite_cmd_exit_runtime_error, message)
    _ => (pdflite_cmd_exit_runtime_error, err.to_string())
  }
  @stdio.stderr.write("pdflite: \{message}\n")
  code
}

///|
fn pdflite_cmd_optional_value(
  matches : @argparse.Matches,
  name : String,
) -> String? {
  matches.values.get(name).bind(values => values.get(0))
}

///|
fn pdflite_cmd_path(name : String) -> @argparse.PositionArg {
  PositionArg(name, about=name, num_args=@argparse.ValueRange::single())
}

///|
fn pdflite_cmd_action(
  options : @argparse.Matches,
) -> (String, @argparse.Matches) raise {
  guard options.subcommand is Some(action) else {
    raise Usage("a subcommand is required")
  }
  action
}

///|
async fn pdflite_cmd_save(document : @pdf.PdfDocument, output : String) -> Unit {
  let bytes = @pdf.pdf_write_document(document)
  match pdflite_cmd_verify_rewritten_bytes(bytes, output) {
    Ok(_) => ()
    Err(message) => raise Runtime(message)
  }
  match pdflite_cmd_write_output_file(output, bytes) {
    Ok(_) => ()
    Err(message) => raise Runtime(message)
  }
}

///|
async fn pdflite_cmd_emit(bytes : Bytes, output : String?) -> Unit {
  guard output is Some(path) else {
    @stdio.stdout.write(bytes)
    return
  }
  match pdflite_cmd_write_output_file(path, bytes) {
    Ok(_) => ()
    Err(message) => raise Runtime(message)
  }
}
