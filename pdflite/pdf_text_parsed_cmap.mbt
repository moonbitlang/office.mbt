///|
fn pdf_text_parsed_cmap_codespace_charcode(
  codespace : PdfCMapCodeSpace,
  text : BytesView,
  index : Int,
) -> Int? {
  guard codespace.length > 0 && index + codespace.length <= text.length() else {
    return None
  }
  let mut code = 0
  for offset in 0..<codespace.length {
    code = (code << 8) | text[index + offset].to_int()
  }
  if code >= codespace.first && code <= codespace.last {
    Some(code)
  } else {
    None
  }
}

///|
fn pdf_text_parsed_cmap_next_charcode(
  parsed : PdfParsedCMap,
  text : BytesView,
  index : Int,
) -> (Int, Int)? {
  let mut best : (Int, Int)? = None
  for codespace in parsed.codespaces {
    match pdf_text_parsed_cmap_codespace_charcode(codespace, text, index) {
      Some(code) =>
        match best {
          Some((_, length)) if length >= codespace.length => ()
          _ => best = Some((code, codespace.length))
        }
      None => ()
    }
  }
  best
}

///|
fn pdf_text_identity_codespace() -> PdfCMapCodeSpace {
  { length: 2, first: 0x0000, last: 0xFFFF }
}

///|
fn pdf_text_parsed_cmap_has_identity_base(parsed : PdfParsedCMap) -> Bool {
  match parsed.usecmap {
    Some(name) => {
      let encoding = PdfPredefinedCMap(name)
      encoding.is_identity_h() || encoding.is_identity_v()
    }
    None => false
  }
}

///|
fn pdf_text_parsed_cmap_predefined_base(
  parsed : PdfParsedCMap,
) -> @core.PdfName? {
  match parsed.usecmap {
    Some(name) if !pdf_text_parsed_cmap_has_identity_base(parsed) => Some(name)
    _ => None
  }
}

///|
fn pdf_text_parsed_cmap_identity_charcode(
  parsed : PdfParsedCMap,
  text : BytesView,
  index : Int,
) -> (Int, Int)? {
  guard pdf_text_parsed_cmap_has_identity_base(parsed) else { return None }
  match
    pdf_text_parsed_cmap_codespace_charcode(
      pdf_text_identity_codespace(),
      text,
      index,
    ) {
    Some(code) => Some((code, 2))
    None => None
  }
}

///|
fn pdf_text_parsed_cmap_charcodes_of_text(
  parsed : PdfParsedCMap,
  text : BytesView,
) -> Array[Int] raise @core.PdfError {
  guard parsed.codespaces.length() > 0 ||
    pdf_text_parsed_cmap_has_identity_base(parsed) else {
    match pdf_text_parsed_cmap_predefined_base(parsed) {
      Some(name) =>
        return pdf_text_predefined_cmap_charcodes_of_text(name, text)
      None => return [ for byte in text => byte.to_int() ]
    }
  }
  let output : Array[Int] = Array::new(capacity=text.length())
  let mut index = 0
  while index < text.length() {
    let next = match pdf_text_parsed_cmap_next_charcode(parsed, text, index) {
      Some((local_code, length)) =>
        match pdf_text_parsed_cmap_identity_charcode(parsed, text, index) {
          Some((identity_code, identity_length)) if identity_length > length =>
            Some((identity_code, identity_length))
          _ => Some((local_code, length))
        }
      None => pdf_text_parsed_cmap_identity_charcode(parsed, text, index)
    }
    match next {
      Some((code, length)) => {
        output.push(code)
        index += length
      }
      None => raise BadText
    }
  }
  output
}

///|
/// Test whether this Type 0 font uses `/Identity-H`.
pub fn PdfCIDKeyedFont::is_identity_h(self : PdfCIDKeyedFont) -> Bool {
  self.encoding.is_identity_h()
}

///|
/// Test whether this Type 0 font uses `/Identity-V`.
pub fn PdfCIDKeyedFont::is_identity_v(self : PdfCIDKeyedFont) -> Bool {
  self.encoding.is_identity_v()
}

///|
/// Return true when this Type 0 font uses fixed two-byte character codes.
pub fn PdfCIDKeyedFont::uses_two_byte_codes(self : PdfCIDKeyedFont) -> Bool {
  self.encoding.uses_two_byte_codes()
}
