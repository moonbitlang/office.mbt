///|
fn pdf_markdown_name(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_markdown_font_key_name : @pdflite.PdfName = pdf_markdown_name("/Font")

///|
fn pdf_markdown_font_key() -> @pdflite.PdfName {
  pdf_markdown_font_key_name
}

///|
fn pdf_markdown_font_resource(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  font_name : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  match document.lookup_direct(pdf_markdown_font_key(), resources) {
    Some(fonts) => document.lookup_direct(font_name, fonts)
    None => None
  }
}

///|
fn pdf_markdown_last_codepoint(output : Array[Int]) -> Int? {
  if output.length() == 0 {
    None
  } else {
    Some(output[output.length() - 1])
  }
}

///|
fn pdf_markdown_trim_trailing_spaces(output : Array[Int]) -> Unit {
  while output.length() > 0 && output[output.length() - 1] == 0x20 {
    ignore(output.pop())
  }
}

///|
fn pdf_markdown_push_line_break(output : Array[Int]) -> Unit {
  pdf_markdown_trim_trailing_spaces(output)
  match pdf_markdown_last_codepoint(output) {
    None | Some(0x0A) => ()
    Some(_) => output.push(0x0A)
  }
}

///|
fn pdf_markdown_push_word_space(output : Array[Int]) -> Unit {
  match pdf_markdown_last_codepoint(output) {
    None | Some(0x0A) | Some(0x20) => ()
    Some(_) => output.push(0x20)
  }
}

///|
fn pdf_markdown_tj_adjustment_is_word_space(value : Double) -> Bool {
  value <= -200.0
}

///|
fn pdf_markdown_push_extracted_text(
  output : Array[Int],
  extractor : @pdflite.PdfTextExtractor?,
  text : @pdflite.PdfBytes,
) -> Unit raise {
  match extractor {
    Some(extractor) =>
      for codepoint in extractor.codepoints_of_text(text[:]) {
        output.push(codepoint)
      }
    None => ()
  }
}

///|
fn pdf_markdown_text_codepoints_of_page(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> Array[Int] raise {
  let output : Array[Int] = []
  let mut extractor : @pdflite.PdfTextExtractor? = None
  for
    op in document.parse_content_ops_with_resources(
      page.resources,
      page.content,
    ) {
    match op {
      Op_Tf(font_name, _) =>
        match pdf_markdown_font_resource(document, page.resources, font_name) {
          Some(font) => extractor = Some(document.text_extractor_of_font(font))
          None => extractor = None
        }
      Op_Tj(text) => pdf_markdown_push_extracted_text(output, extractor, text)
      Op_TJ(PdfArray(items)) =>
        for item in items {
          match item {
            PdfString(text) =>
              pdf_markdown_push_extracted_text(output, extractor, text)
            PdfReal(value) if pdf_markdown_tj_adjustment_is_word_space(value) =>
              pdf_markdown_push_word_space(output)
            _ => ()
          }
        }
      Op_quote(text) => {
        pdf_markdown_push_line_break(output)
        pdf_markdown_push_extracted_text(output, extractor, text)
      }
      Op_double_quote(_, _, text) => {
        pdf_markdown_push_line_break(output)
        pdf_markdown_push_extracted_text(output, extractor, text)
      }
      Op_Tstar | Op_Td(_, _) | Op_TD(_, _) =>
        pdf_markdown_push_line_break(output)
      _ => ()
    }
  }
  output
}

///|
fn pdf_markdown_is_space(codepoint : Int) -> Bool {
  codepoint == 0x09 || codepoint == 0x0C || codepoint == 0x20
}

///|
fn pdf_markdown_normalize_codepoints(codepoints : ArrayView[Int]) -> Array[Int] {
  let output : Array[Int] = []
  let mut pending_space = false
  for codepoint in codepoints {
    match codepoint {
      0x0A | 0x0D => {
        pdf_markdown_push_line_break(output)
        pending_space = false
      }
      _ =>
        if pdf_markdown_is_space(codepoint) {
          if output.length() > 0 {
            pending_space = true
          }
        } else {
          if pending_space &&
            output.length() > 0 &&
            pdf_markdown_last_codepoint(output) != Some(0x0A) {
            output.push(0x20)
          }
          output.push(codepoint)
          pending_space = false
        }
    }
  }
  pdf_markdown_trim_trailing_spaces(output)
  while pdf_markdown_last_codepoint(output) == Some(0x0A) {
    ignore(output.pop())
  }
  output
}

///|
fn pdf_markdown_string_of_codepoints(
  codepoints : ArrayView[Int],
) -> String raise {
  let normalized = pdf_markdown_normalize_codepoints(codepoints)
  let bytes = @pdflite.pdf_utf8_of_codepoints(normalized)
  @utf8.decode_lossy(bytes[:])
}

///|
fn pdf_markdown_page_text(
  document : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> String raise {
  pdf_markdown_string_of_codepoints(
    pdf_markdown_text_codepoints_of_page(document, page)[:],
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
pub fn pdf_document_to_markdown(
  document : @pdflite.PdfDocument,
) -> String raise {
  let document = pdf_markdown_readable_document(document)
  let pages = document.pages_of_pagetree()
  let output = @buffer.new()
  for index in 0..<pages.length() {
    if index > 0 {
      output.write_string("\n\n")
    }
    output.write_string("# Page ")
    output.write_string((index + 1).to_string())
    output.write_string("\n\n")
    output.write_string(pdf_markdown_page_text(document, pages[index]))
  }
  output.write_string("\n")
  output.to_string()
}

///|
pub fn pdf_bytes_to_markdown(data : Bytes) -> String raise {
  pdf_document_to_markdown(@pdflite.pdf_read_document_from_bytes(data))
}
