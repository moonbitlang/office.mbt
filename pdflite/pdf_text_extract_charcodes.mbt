///|
fn pdf_text_push_two_byte_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  guard index + 1 < text.length() else { raise BadText }
  output.push((text[index].to_int() << 8) | text[index + 1].to_int())
  index + 2
}

///|
fn pdf_text_push_three_byte_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  guard index + 2 < text.length() else { raise BadText }
  output.push(
    (((text[index].to_int() << 8) | text[index + 1].to_int()) << 8) |
    text[index + 2].to_int(),
  )
  index + 3
}

///|
fn pdf_text_push_four_byte_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  guard index + 3 < text.length() else { raise BadText }
  output.push(
    (
      (
        (((text[index].to_int() << 8) | text[index + 1].to_int()) << 8) |
        text[index + 2].to_int()
      ) <<
      8
    ) |
    text[index + 3].to_int(),
  )
  index + 4
}

///|
fn pdf_text_push_utf8_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  let first = text[index].to_int()
  let (length, code) = if first >> 7 == 0 {
    (1, first)
  } else if first >> 5 == 0b110 {
    guard index + 1 < text.length() else { raise InvalidUTF8 }
    (2, pdf_text_pack_two_bytes(first, text[index + 1].to_int()))
  } else if first >> 4 == 0b1110 {
    guard index + 2 < text.length() else { raise InvalidUTF8 }
    (3, pdf_text_pack_bytes_as_charcode(text[index:index + 3]))
  } else if first >> 3 == 0b11110 {
    guard index + 3 < text.length() else { raise InvalidUTF8 }
    (
      4,
      pdf_text_pack_four_bytes(
        first,
        text[index + 1].to_int(),
        text[index + 2].to_int(),
        text[index + 3].to_int(),
      ),
    )
  } else {
    raise InvalidUTF8
  }
  guard pdf_text_predefined_utf8_codepoints(code) is Some(_) else {
    raise InvalidUTF8
  }
  output.push(code)
  index + length
}

///|
fn pdf_text_push_utf16_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  let first = pdf_text_pack_two_bytes(
    text[index].to_int(),
    text[index + 1].to_int(),
  )
  if first >= 0xD800 && first <= 0xDBFF {
    guard index + 3 < text.length() else { raise InvalidUTF16BE }
    let second = pdf_text_pack_two_bytes(
      text[index + 2].to_int(),
      text[index + 3].to_int(),
    )
    guard second >= 0xDC00 && second <= 0xDFFF else { raise InvalidUTF16BE }
    output.push(
      pdf_text_pack_four_bytes(
        first >> 8,
        first & 0xFF,
        second >> 8,
        second & 0xFF,
      ),
    )
    index + 4
  } else if first >= 0xDC00 && first <= 0xDFFF {
    raise InvalidUTF16BE
  } else {
    output.push(first)
    index + 2
  }
}

///|
fn pdf_text_push_utf32_charcode(
  output : Array[Int],
  text : BytesView,
  index : Int,
) -> Int raise PdfError {
  guard index + 3 < text.length() else { raise BadText }
  let code = pdf_text_pack_four_bytes(
    text[index].to_int(),
    text[index + 1].to_int(),
    text[index + 2].to_int(),
    text[index + 3].to_int(),
  )
  guard pdf_text_valid_unicode_codepoint(code) else {
    raise InvalidUnicodeCodepoint(code)
  }
  output.push(code)
  index + 4
}

///|
fn pdf_text_shift_jis_lead_byte(byte : Int) -> Bool {
  (byte >= 0x81 && byte <= 0x9F) || (byte >= 0xE0 && byte <= 0xFC)
}

///|
fn pdf_text_gbk2k_four_byte_prefix(first : Int, second : Int) -> Bool {
  first >= 0x81 && first <= 0xFE && second >= 0x30 && second <= 0x39
}

///|
fn pdf_text_predefined_mixed_byte_charcodes(
  name : PdfName,
  text : BytesView,
) -> Array[Int] raise PdfError {
  let output : Array[Int] = Array::new(capacity=text.length())
  let shift_jis = pdf_text_predefined_cmap_uses_shift_jis_charcodes(name)
  let b5pc = pdf_text_predefined_cmap_uses_b5pc_charcodes(name)
  let cns1_b5 = pdf_text_predefined_cmap_uses_cns1_b5_charcodes(name)
  let cns_euc = pdf_text_predefined_cmap_uses_cns_euc_charcodes(name)
  let hkscs = pdf_text_predefined_cmap_uses_hkscs_charcodes(name)
  let gbpc_euc = pdf_text_predefined_cmap_uses_gbpc_euc_charcodes(name)
  let hojo_euc = pdf_text_predefined_cmap_uses_hojo_euc_charcodes(name)
  let ksc_euc = pdf_text_predefined_cmap_uses_ksc_euc_charcodes(name)
  let kscpc_euc = pdf_text_predefined_cmap_uses_kscpc_euc_charcodes(name)
  let gbk2k = pdf_text_predefined_cmap_uses_gbk2k_charcodes(name)
  let gbk = pdf_text_predefined_cmap_uses_gbk_charcodes(name)
  let mut index = 0
  while index < text.length() {
    let first = text[index].to_int()
    if shift_jis {
      if pdf_text_shift_jis_lead_byte(first) {
        index = pdf_text_push_two_byte_charcode(output, text, index)
      } else {
        output.push(first)
        index += 1
      }
    } else if hojo_euc {
      index = pdf_text_push_three_byte_charcode(output, text, index)
    } else if gbk2k &&
      index + 1 < text.length() &&
      pdf_text_gbk2k_four_byte_prefix(first, text[index + 1].to_int()) {
      index = pdf_text_push_four_byte_charcode(output, text, index)
    } else if cns_euc && first == 0x8E {
      index = pdf_text_push_four_byte_charcode(output, text, index)
    } else if first < 0x80 ||
      (cns_euc && first == 0x80) ||
      (
        b5pc &&
        (
          first == 0x80 ||
          (first >= 0x83 && first <= 0xA0) ||
          (first >= 0xFD && first <= 0xFF)
        )
      ) ||
      (
        gbpc_euc &&
        (
          first == 0x80 ||
          (first >= 0x83 && first <= 0xA0) ||
          (first >= 0xFD && first <= 0xFF)
        )
      ) ||
      (ksc_euc && first == 0x80) ||
      (
        kscpc_euc &&
        ((first >= 0x80 && first <= 0x9F) || first == 0xFE || first == 0xFF)
      ) ||
      (cns1_b5 && first == 0x80) ||
      (hkscs && first == 0x80) ||
      (gbk && (first == 0x80 || first == 0xFF)) {
      output.push(first)
      index += 1
    } else {
      index = pdf_text_push_two_byte_charcode(output, text, index)
    }
  }
  output
}

///|
fn pdf_text_predefined_cmap_charcodes_of_text(
  name : PdfName,
  text : BytesView,
) -> Array[Int] raise PdfError {
  if pdf_text_predefined_cmap_uses_utf8_charcodes(name) {
    let output : Array[Int] = Array::new(capacity=text.length())
    let mut index = 0
    while index < text.length() {
      index = pdf_text_push_utf8_charcode(output, text, index)
    }
    output
  } else if pdf_text_predefined_cmap_uses_utf16_charcodes(name) {
    guard text.length() % 2 == 0 else { raise BadText }
    let output : Array[Int] = Array::new(capacity=text.length() / 2)
    let mut index = 0
    while index < text.length() {
      index = pdf_text_push_utf16_charcode(output, text, index)
    }
    output
  } else if pdf_text_predefined_cmap_uses_utf32_charcodes(name) {
    guard text.length() % 4 == 0 else { raise BadText }
    let output : Array[Int] = Array::new(capacity=text.length() / 4)
    let mut index = 0
    while index < text.length() {
      index = pdf_text_push_utf32_charcode(output, text, index)
    }
    output
  } else if pdf_text_predefined_cmap_uses_mixed_byte_charcodes(name) {
    pdf_text_predefined_mixed_byte_charcodes(name, text)
  } else {
    let output : Array[Int] = Array::new(capacity=text.length())
    if name == pdf_text_identity_h_name ||
      name == pdf_text_identity_v_name ||
      pdf_text_predefined_cmap_uses_two_byte_charcodes(name) {
      guard text.length() % 2 == 0 else { raise BadText }
      let mut index = 0
      while index < text.length() {
        index = pdf_text_push_two_byte_charcode(output, text, index)
      }
    } else {
      for byte in text {
        output.push(byte.to_int())
      }
    }
    output
  }
}

///|
fn PdfFont::pdf_text_charcodes_of_text(
  self : PdfFont,
  text : BytesView,
) -> Array[Int] raise PdfError {
  match self {
    PdfFontCIDKeyed(font) =>
      match font.encoding {
        PdfPredefinedCMap(name) =>
          pdf_text_predefined_cmap_charcodes_of_text(name, text)
        PdfExternalCMap(_, parsed) =>
          pdf_text_parsed_cmap_charcodes_of_text(parsed, text)
        _ => self.pdf_text_fixed_or_single_byte_charcodes_of_text(text)
      }
    _ => self.pdf_text_fixed_or_single_byte_charcodes_of_text(text)
  }
}

///|
fn PdfFont::pdf_text_fixed_or_single_byte_charcodes_of_text(
  self : PdfFont,
  text : BytesView,
) -> Array[Int] raise PdfError {
  let output : Array[Int] = Array::new(capacity=text.length())
  if self.uses_two_byte_codes() {
    guard text.length() % 2 == 0 else { raise BadText }
    let mut index = 0
    while index < text.length() {
      index = pdf_text_push_two_byte_charcode(output, text, index)
    }
  } else {
    for byte in text {
      output.push(byte.to_int())
    }
  }
  output
}
