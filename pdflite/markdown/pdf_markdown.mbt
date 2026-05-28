///|
fn pdf_markdown_page_text(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  font_cache : PdfMarkdownFontCache,
) -> String raise {
  pdf_markdown_string_of_codepoints(
    pdf_markdown_text_codepoints_of_page(document, page, font_cache),
  )
}

///|
fn pdf_markdown_readable_document(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  if document.is_encrypted() {
    match document.decrypt_with_passwords() {
      Some(result) => result.document
      None => fail("encrypted PDF requires a password")
    }
  } else {
    document
  }
}

///|
/// Convert a parsed PDF document to a best-effort Markdown text dump.
///
/// The output contains one `# Page N` section per page. Text is extracted from
/// page content streams and nested form XObjects using the document's font
/// encodings. Encrypted documents are decrypted only when they can be opened
/// without an explicit password.
pub fn pdf_document_to_markdown(
  document : @pdflite.PdfDocument,
) -> String raise {
  let document = pdf_markdown_readable_document(document)
  let pages = document.pages_of_pagetree()
  let output = Buffer()
  let font_cache = pdf_markdown_font_cache()
  for index in 0..<pages.length() {
    if index > 0 {
      output.write_string_utf16le("\n\n")
    }
    output.write_string_utf16le("# Page ")
    output.write_string_utf16le((index + 1).to_string())
    output.write_string_utf16le("\n\n")
    output.write_string_utf16le(
      pdf_markdown_page_text(document, pages[index], font_cache),
    )
  }
  output.write_string_utf16le("\n")
  output.to_string()
}

///|
/// Read PDF bytes and convert the resulting document with `pdf_document_to_markdown`.
pub fn pdf_bytes_to_markdown(data : Bytes) -> String raise {
  pdf_document_to_markdown(@pdflite.pdf_read_document_from_bytes(data))
}
