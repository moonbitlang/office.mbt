///|
fn pdf_addtext_afm_header_value(
  data : @afm.PdfAfmData,
  key : String,
) -> String? {
  let key_bytes = @ascii.encode(key)
  for entry in data.headers {
    if @afm.pdf_afm_view_equals(entry.0, key_bytes) {
      return Some(@ascii.decode_lossy(entry.1))
    }
  }
  None
}

///|
fn pdf_addtext_parse_double(text : String) -> Double? {
  let parsed : Result[Double, Error] = try @strconv.from_str(text) catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match parsed {
    Ok(value) => Some(value)
    Err(_) => None
  }
}

///|
fn pdf_addtext_standard_cap_height(fontname : String) -> Double? {
  match pdf_standard_font_of_name("/" + fontname) {
    Some(font) => {
      let data = font.afm_data()
      match pdf_addtext_afm_header_value(data, "CapHeight") {
        Some(value) =>
          match pdf_addtext_parse_double(value) {
            Some(parsed) => Some(parsed)
            None => Some(0.0)
          }
        None => Some(0.0)
      }
    }
    None => None
  }
}

///|
/// Return the cap height used by cpdf add-text URL link rectangles.
///
/// Explicit simple-font descriptors win. Otherwise `fontname` is resolved as a
/// Standard 14 font name without a leading slash, matching cpdf's fallback.
pub fn pdf_addtext_cap_height(font : PdfFont?, fontname : String) -> Double? {
  match font {
    Some(PdfFontSimple({ fontdescriptor: Some(descriptor), .. })) =>
      Some(descriptor.capheight)
    _ => pdf_addtext_standard_cap_height(fontname)
  }
}
