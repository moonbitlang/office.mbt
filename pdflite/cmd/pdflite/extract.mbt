///|
priv suberror PdfliteExtractError {
  InvalidPages(String)
  ExtractFailed(String)
}

///|
fn pdflite_cmd_extract_bytes(
  document : @pdflite.PdfDocument,
  spec : String,
  retain_numbering : Bool,
  process_struct_tree : Bool,
) -> Bytes raise PdfliteExtractError {
  let count = document.endpage() catch {
    err =>
      raise ExtractFailed(
        "cannot read page tree: \{@core.pdf_error_summary(err)}",
      )
  }
  guard spec != "" else { raise InvalidPages("--pages must not be empty") }
  let pages = @pagespec.pdf_parse_pagespec_for_count(
    count,
    spec,
    strict_bounds=true,
  ) catch {
    err =>
      raise InvalidPages(
        "invalid --pages '\{spec}' for \{count} pages: \{@core.pdf_error_summary(err)}",
      )
  }
  guard !pages.is_empty() else {
    raise InvalidPages("--pages selects no pages")
  }
  let extracted = document.pdf_of_pages(
    pages,
    retain_numbering~,
    process_struct_tree~,
  ) catch {
    err =>
      raise ExtractFailed(
        "cannot extract PDF pages: \{@core.pdf_error_summary(err)}",
      )
  }
  let output = @pdflite.pdf_write_document(extracted) catch {
    err =>
      raise ExtractFailed(
        "cannot write extracted PDF: \{@core.pdf_error_summary(err)}",
      )
  }
  let verified = @pdflite.pdf_read_document_from_bytes(output) catch {
    err =>
      raise ExtractFailed(
        "extracted PDF does not parse: \{@core.pdf_error_summary(err)}",
      )
  }
  let actual_count = verified.endpage() catch {
    err =>
      raise ExtractFailed(
        "extracted PDF has an unreadable page tree: \{@core.pdf_error_summary(err)}",
      )
  }
  guard actual_count == pages.length() else {
    raise ExtractFailed("extracted PDF page count does not match selection")
  }
  output
}

///|
async fn pdflite_cmd_extract_file(
  input_path : String,
  output_path : String,
  spec : String,
  retain_numbering : Bool,
  process_struct_tree : Bool,
) -> Int {
  let document = match pdflite_cmd_read_document(input_path) {
    Ok(document) => document
    Err(message) => {
      @stdio.stderr.write("pdflite: \{message}\n")
      return pdflite_cmd_exit_runtime_error
    }
  }
  let output = pdflite_cmd_extract_bytes(
    document, spec, retain_numbering, process_struct_tree,
  ) catch {
    InvalidPages(message) => {
      @stdio.stderr.write("pdflite: \{message}\n")
      return pdflite_cmd_exit_usage_error
    }
    ExtractFailed(message) => {
      @stdio.stderr.write("pdflite: \{message}\n")
      return pdflite_cmd_exit_runtime_error
    }
  }
  match pdflite_cmd_write_output_file(output_path, output) {
    Ok(_) => pdflite_cmd_exit_ok
    Err(message) => {
      @stdio.stderr.write("pdflite: \{message}\n")
      pdflite_cmd_exit_runtime_error
    }
  }
}
