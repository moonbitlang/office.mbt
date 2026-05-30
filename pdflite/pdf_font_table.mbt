///|
fn PdfDocument::pdf_font_table_target_font(
  self : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfObject raise PdfError {
  let font = self.font_from_name(font_name, page_number)
  let mut selected = font
  match font {
    PdfDictionary(entries) =>
      for entry in entries {
        match self.lookup_direct(pdf_text_base_font_key_name, entry.1) {
          Some(PdfNameObject(name)) if pdf_util_string_from_name(name) ==
            font_name => selected = entry.1
          _ => ()
        }
      }
    _ => ()
  }
  selected
}

///|
fn pdf_font_table_charset(font : PdfFont) -> Array[PdfName]? {
  match font {
    PdfFontSimple({ fontdescriptor: Some({ charset: Some(charset), .. }), .. }) =>
      Some(charset)
    _ => None
  }
}

///|
fn pdf_font_table_text_bytes(
  font : PdfFont,
  code : Int,
) -> PdfBytes raise PdfError {
  if font.uses_two_byte_codes() {
    Bytes::from_array([pdf_byte_of_int(0), pdf_byte_of_int(code)])
  } else {
    Bytes::from_array([pdf_byte_of_int(code)])
  }
}

///|
fn pdf_font_table_strip_name_slash(name : PdfName) -> String {
  let text = pdf_util_string_from_name(name) catch {
    _ => @ascii.decode_lossy(name.bytes())
  }
  if text.has_prefix("/") {
    text[1:].to_owned()
  } else {
    text
  }
}

///|
fn pdf_font_table_glyphnames_text(glyphnames : ArrayView[PdfName]) -> String {
  let mut text = ""
  for glyphname in glyphnames {
    text = text + pdf_font_table_strip_name_slash(glyphname)
  }
  text
}

///|
fn pdf_font_table_in_charset(
  glyphnames : String,
  charset : ArrayView[PdfName],
) -> Bool {
  for name in charset {
    if pdf_font_table_strip_name_slash(name) == glyphnames {
      return true
    }
  }
  false
}

///|
fn pdf_font_table_utf8_text(
  codepoints : ArrayView[Int],
) -> String raise PdfError {
  let bytes = pdf_utf8_of_codepoints(codepoints)
  @utf8.decode(bytes) catch {
    _ => ""
  }
}

///|
fn pdf_font_table_unicode_fields(
  codepoints : ArrayView[Int],
) -> (String, String, String) raise PdfError {
  match codepoints {
    [codepoint] => {
      let data = pdf_unicode_data_lookup(codepoint)
      let unicode = match data {
        Some(data) => data.code_value
        None => ""
      }
      let unicode_name = match data {
        Some(data) => data.character_name
        None => ""
      }
      let is_control = match data {
        Some(data) => data.general_category == "Cc"
        None => false
      }
      let utf8 = if is_control {
        "<nonprintable>"
      } else {
        pdf_font_table_utf8_text(codepoints)
      }
      (unicode, utf8, unicode_name)
    }
    _ => ("***multiple", pdf_font_table_utf8_text(codepoints), "***multiple")
  }
}

///|
fn pdf_font_table_entry(
  font : PdfFont,
  extractor : PdfTextExtractor,
  code : Int,
) -> @font.PdfFontTableEntry? raise PdfError {
  let text = pdf_font_table_text_bytes(font, code)
  let glyphnames = extractor.glyphnames_of_text(text)
  let glyphnames_text = pdf_font_table_glyphnames_text(glyphnames)
  if glyphnames_text == ".notdef" {
    None
  } else {
    match pdf_font_table_charset(font) {
      Some(charset) if !pdf_font_table_in_charset(glyphnames_text, charset) =>
        None
      _ => {
        let codepoints = extractor.codepoints_of_text(text)
        let (unicode, utf8, unicode_name) = pdf_font_table_unicode_fields(
          codepoints,
        )
        Some({ code, unicode, utf8, unicode_name, glyphnames: glyphnames_text })
      }
    }
  }
}

///|
/// Return cpdf's font encoding table rows for one named page font.
///
/// This is the in-memory counterpart to cpdf's `print_font_table`. Font names
/// use the same page resource path syntax as `font_from_name`, such as `/F1`.
pub fn PdfDocument::font_table(
  self : PdfDocument,
  font_name : String,
  page_number : Int,
) -> Array[@font.PdfFontTableEntry] raise PdfError {
  let font_object = self.pdf_font_table_target_font(font_name, page_number)
  let font = self.read_font(font_object)
  let extractor = font.text_extractor()
  let output : Array[@font.PdfFontTableEntry] = []
  for code in 0..<256 {
    match pdf_font_table_entry(font, extractor, code) {
      Some(entry) => output.push(entry)
      None => ()
    }
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::font_table`.
pub fn pdf_font_table(
  document : PdfDocument,
  font_name : String,
  page_number : Int,
) -> Array[@font.PdfFontTableEntry] raise PdfError {
  document.font_table(font_name, page_number)
}

///|
fn pdf_font_write_table_line(
  output : Array[Byte],
  position : Int,
  entry : @font.PdfFontTableEntry,
) -> Int {
  let mut current = pdf_font_write_utf8(
    output,
    position,
    entry.code.to_string(),
  )
  current = pdf_font_write_utf8(output, current, " = U+")
  current = pdf_font_write_utf8(output, current, entry.unicode)
  current = pdf_font_write_utf8(output, current, " (")
  current = pdf_font_write_utf8(output, current, entry.utf8)
  current = pdf_font_write_utf8(output, current, " - ")
  current = pdf_font_write_utf8(output, current, entry.unicode_name)
  current = pdf_font_write_utf8(output, current, ") = ")
  current = pdf_font_write_utf8(output, current, entry.glyphnames)
  output[current] = 10
  current + 1
}

///|
fn pdf_font_table_line_length(entry : @font.PdfFontTableEntry) -> Int {
  pdf_font_utf8_length(entry.code.to_string()) +
  pdf_font_utf8_length(entry.unicode) +
  pdf_font_utf8_length(entry.utf8) +
  pdf_font_utf8_length(entry.unicode_name) +
  pdf_font_utf8_length(entry.glyphnames) +
  15
}

///|
fn pdf_font_table_text_length(
  entries : ArrayView[@font.PdfFontTableEntry],
) -> Int {
  let mut length = 0
  for entry in entries {
    length += pdf_font_table_line_length(entry)
  }
  length
}

///|
/// Render cpdf's plain-text font encoding table for one named page font.
pub fn PdfDocument::font_table_text(
  self : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfBytes raise PdfError {
  let entries = self.font_table(font_name, page_number)
  let output = Array::make(pdf_font_table_text_length(entries), b'\x00')
  let mut position = 0
  for entry in entries {
    position = pdf_font_write_table_line(output, position, entry)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::font_table_text`.
pub fn pdf_font_table_text(
  document : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfBytes raise PdfError {
  document.font_table_text(font_name, page_number)
}

///|
/// Return the bytes cpdf's `print_font_table` would print.
pub fn PdfDocument::print_font_table(
  self : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfBytes raise PdfError {
  self.font_table_text(font_name, page_number)
}

///|
/// Compatibility wrapper matching cpdffont's `print_font_table`.
pub fn pdf_print_font_table(
  document : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfBytes raise PdfError {
  document.print_font_table(font_name, page_number)
}
