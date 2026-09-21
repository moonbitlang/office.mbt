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
