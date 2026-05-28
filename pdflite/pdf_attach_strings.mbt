///|
fn pdf_attach_is_path_separator(code_unit : UInt16) -> Bool {
  let value = code_unit.to_int()
  value == 47 || value == 92
}

///|
fn pdf_attach_basename(path : String) -> String {
  let mut start = 0
  for index in 0..<path.length() {
    if pdf_attach_is_path_separator(path.at(index)) {
      start = index + 1
    }
  }
  path[start:].to_owned()
}

///|
fn pdf_attach_pdfdoc_string(text : String) -> PdfBytes raise PdfError {
  pdf_pdfdocstring_of_utf8(@utf8.encode(text))
}

///|
fn pdf_attach_string_of_pdfdoc_string(
  bytes : BytesView,
) -> String raise PdfError {
  let utf8_bytes = pdf_utf8_of_pdfdocstring(bytes)
  @utf8.decode(utf8_bytes) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_attach_relationship_name(relationship : String) -> PdfName {
  if relationship.has_prefix("/") {
    pdf_attach_name(relationship)
  } else {
    pdf_attach_name("/" + relationship)
  }
}

///|
fn pdf_attach_relationship_text(name : PdfName) -> String? {
  let decoded : Result[String, Error] = try? @ascii.decode(name.view())
  match decoded {
    Ok(text) => Some(text)
    Err(_) => None
  }
}

///|
fn pdf_attach_is_unsafe_filename_codepoint(codepoint : Int) -> Bool {
  codepoint == 47 ||
  codepoint == 63 ||
  codepoint == 60 ||
  codepoint == 62 ||
  codepoint == 92 ||
  codepoint == 58 ||
  codepoint == 42 ||
  codepoint == 124 ||
  codepoint == 34 ||
  codepoint == 94 ||
  codepoint == 43 ||
  codepoint == 61 ||
  codepoint < 32 ||
  codepoint == 127
}

///|
/// Remove characters which are unsafe in attachment dump filenames.
///
/// Input and output are Unicode text. This mirrors cpdf's filtering set and
/// intentionally preserves a leading dot, matching the source behavior.
pub fn pdf_attachment_remove_unsafe_characters(
  text : String,
) -> String raise PdfError {
  let codepoints = pdf_codepoints_of_utf8(@utf8.encode(text))
  let output : Array[Int] = Array::new(capacity=codepoints.length())
  for codepoint in codepoints {
    if !pdf_attach_is_unsafe_filename_codepoint(codepoint) {
      output.push(codepoint)
    }
  }
  pdf_attach_string_of_pdfdoc_string(
    pdf_pdfdocstring_of_utf8(pdf_utf8_of_codepoints(output)),
  )
}

///|
/// Source-spelled compatibility alias for cpdfattach's filename sanitizer.
pub fn pdf_remove_unsafe_characters(text : String) -> String raise PdfError {
  pdf_attachment_remove_unsafe_characters(text)
}
