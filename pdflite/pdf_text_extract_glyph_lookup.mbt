///|
fn pdf_text_notdef_name() -> @core.PdfName {
  pdf_text_name(".notdef")
}

///|
fn pdf_text_tounicode_glyphname(bytes : @core.PdfBytes) -> @core.PdfName {
  let output : Array[Byte] = [47]
  for byte in bytes {
    output.push(byte)
  }
  @core.pdf_name_of_bytes(Bytes::from_array(output))
}

///|
fn PdfTextExtractor::pdf_text_encoded_glyph_of_charcode(
  self : PdfTextExtractor,
  code : Int,
) -> PdfTextGlyph {
  match self.font.pdf_text_glyphname_of_charcode(code) {
    Some(glyphname) =>
      match self.font.pdf_text_codepoints_of_glyphname(glyphname) {
        Some(codepoints) => { glyphname, codepoints }
        None => { glyphname, codepoints: [code] }
      }
    None => { glyphname: pdf_text_notdef_name(), codepoints: [code] }
  }
}

///|
fn pdf_text_lookup_cmap_cid(map : ArrayView[(Int, Int)], code : Int) -> Int? {
  for entry in map {
    if entry.0 == code {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_reverse_lookup_cmap_cid(
  map : ArrayView[(Int, Int)],
  cid : Int,
) -> Int? {
  for entry in map {
    if entry.1 == cid {
      break Some(entry.0)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_cmap_has_charcode(map : ArrayView[(Int, Int)], code : Int) -> Bool {
  for entry in map {
    if entry.0 == code {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_text_cmap_has_charcode_in_any(
  first : ArrayView[(Int, Int)],
  second : ArrayView[(Int, Int)],
  code : Int,
) -> Bool {
  pdf_text_cmap_has_charcode(first, code) ||
  pdf_text_cmap_has_charcode(second, code)
}

///|
fn pdf_text_parsed_cmap_has_explicit_charcode(
  parsed : PdfParsedCMap,
  code : Int,
) -> Bool {
  pdf_text_tounicode_has_charcode(parsed.map, code) ||
  pdf_text_cmap_has_charcode_in_any(parsed.cid_map, parsed.notdef_map, code)
}

///|
fn PdfTextExtractor::pdf_text_glyph_of_charcode(
  self : PdfTextExtractor,
  code : Int,
) -> PdfTextGlyph {
  match self.font.pdf_text_tounicode() {
    Some(tounicode) =>
      match pdf_text_lookup_tounicode(tounicode, code) {
        Some(bytes) =>
          try pdf_codepoints_of_utf16be(bytes) catch {
            _ => { glyphname: pdf_text_notdef_name(), codepoints: [code] }
          } noraise {
            codepoints =>
              { glyphname: pdf_text_tounicode_glyphname(bytes), codepoints }
          }
        None => { glyphname: pdf_text_notdef_name(), codepoints: [code] }
      }
    None =>
      match self.font.pdf_text_predefined_builtin_codepoints(code) {
        Some(codepoints) => { glyphname: pdf_text_notdef_name(), codepoints }
        None =>
          match self.font.pdf_text_external_cmap_codepoints(code) {
            Some(codepoints) =>
              { glyphname: pdf_text_notdef_name(), codepoints }
            None => self.pdf_text_encoded_glyph_of_charcode(code)
          }
      }
  }
}
