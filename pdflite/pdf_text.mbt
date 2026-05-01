///|
pub(all) enum PdfStandardFont {
  PdfTimesRoman
  PdfTimesBold
  PdfTimesItalic
  PdfTimesBoldItalic
  PdfHelvetica
  PdfHelveticaBold
  PdfHelveticaOblique
  PdfHelveticaBoldOblique
  PdfCourier
  PdfCourierBold
  PdfCourierOblique
  PdfCourierBoldOblique
  PdfSymbol
  PdfZapfDingbats
} derive(Debug, Eq, ToJson)

///|
pub fn PdfStandardFont::name(self : PdfStandardFont) -> String {
  match self {
    PdfTimesRoman => "Times-Roman"
    PdfTimesBold => "Times-Bold"
    PdfTimesItalic => "Times-Italic"
    PdfTimesBoldItalic => "Times-BoldItalic"
    PdfHelvetica => "Helvetica"
    PdfHelveticaBold => "Helvetica-Bold"
    PdfHelveticaOblique => "Helvetica-Oblique"
    PdfHelveticaBoldOblique => "Helvetica-BoldOblique"
    PdfCourier => "Courier"
    PdfCourierBold => "Courier-Bold"
    PdfCourierOblique => "Courier-Oblique"
    PdfCourierBoldOblique => "Courier-BoldOblique"
    PdfSymbol => "Symbol"
    PdfZapfDingbats => "ZapfDingbats"
  }
}

///|
fn pdf_text_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_text_string_of_name(name : PdfName) -> String {
  @ascii.decode_lossy(name.bytes()[:])
}

///|
pub fn PdfStandardFont::pdf_name(self : PdfStandardFont) -> PdfName {
  pdf_text_name("/" + self.name())
}

///|
pub fn pdf_standard_font_of_name(name : String) -> PdfStandardFont? {
  match name {
    "/Times-Roman" | "/TimesNewRoman" => Some(PdfTimesRoman)
    "/Times-Bold" | "/TimesNewRoman,Bold" => Some(PdfTimesBold)
    "/Times-Italic" | "/TimesNewRoman,Italic" => Some(PdfTimesItalic)
    "/Times-BoldItalic" | "/TimesNewRoman,BoldItalic" =>
      Some(PdfTimesBoldItalic)
    "/Helvetica" | "/Arial" => Some(PdfHelvetica)
    "/Helvetica-Bold" | "/Arial,Bold" => Some(PdfHelveticaBold)
    "/Helvetica-Oblique" | "/Arial,Italic" => Some(PdfHelveticaOblique)
    "/Helvetica-BoldOblique" | "/Arial,BoldItalic" =>
      Some(PdfHelveticaBoldOblique)
    "/Courier" | "/CourierNew" => Some(PdfCourier)
    "/Courier-Bold" | "/CourierNew,Bold" => Some(PdfCourierBold)
    "/Courier-Oblique" | "/CourierNew,Italic" => Some(PdfCourierOblique)
    "/Courier-BoldOblique" | "/CourierNew,BoldItalic" =>
      Some(PdfCourierBoldOblique)
    "/Symbol" => Some(PdfSymbol)
    "/ZapfDingbats" => Some(PdfZapfDingbats)
    _ => None
  }
}

///|
pub fn pdf_standard_font_of_pdf_name(name : PdfName) -> PdfStandardFont? {
  match name {
    name if name == pdf_text_name("/Times-Roman") ||
      name == pdf_text_name("/TimesNewRoman") => Some(PdfTimesRoman)
    name if name == pdf_text_name("/Times-Bold") ||
      name == pdf_text_name("/TimesNewRoman,Bold") => Some(PdfTimesBold)
    name if name == pdf_text_name("/Times-Italic") ||
      name == pdf_text_name("/TimesNewRoman,Italic") => Some(PdfTimesItalic)
    name if name == pdf_text_name("/Times-BoldItalic") ||
      name == pdf_text_name("/TimesNewRoman,BoldItalic") =>
      Some(PdfTimesBoldItalic)
    name if name == pdf_text_name("/Helvetica") ||
      name == pdf_text_name("/Arial") => Some(PdfHelvetica)
    name if name == pdf_text_name("/Helvetica-Bold") ||
      name == pdf_text_name("/Arial,Bold") => Some(PdfHelveticaBold)
    name if name == pdf_text_name("/Helvetica-Oblique") ||
      name == pdf_text_name("/Arial,Italic") => Some(PdfHelveticaOblique)
    name if name == pdf_text_name("/Helvetica-BoldOblique") ||
      name == pdf_text_name("/Arial,BoldItalic") =>
      Some(PdfHelveticaBoldOblique)
    name if name == pdf_text_name("/Courier") ||
      name == pdf_text_name("/CourierNew") => Some(PdfCourier)
    name if name == pdf_text_name("/Courier-Bold") ||
      name == pdf_text_name("/CourierNew,Bold") => Some(PdfCourierBold)
    name if name == pdf_text_name("/Courier-Oblique") ||
      name == pdf_text_name("/CourierNew,Italic") => Some(PdfCourierOblique)
    name if name == pdf_text_name("/Courier-BoldOblique") ||
      name == pdf_text_name("/CourierNew,BoldItalic") =>
      Some(PdfCourierBoldOblique)
    name if name == pdf_text_name("/Symbol") => Some(PdfSymbol)
    name if name == pdf_text_name("/ZapfDingbats") => Some(PdfZapfDingbats)
    _ => None
  }
}

///|
pub fn PdfStandardFont::baseline_adjustment(self : PdfStandardFont) -> Int {
  match self {
    PdfTimesRoman => 662 / 2
    PdfTimesBold => 676 / 2
    PdfTimesItalic => 653 / 2
    PdfTimesBoldItalic => 669 / 2
    PdfHelvetica
    | PdfHelveticaBold
    | PdfHelveticaOblique
    | PdfHelveticaBoldOblique => 718 / 2
    PdfCourier | PdfCourierBold | PdfCourierOblique | PdfCourierBoldOblique =>
      562 / 2
    PdfSymbol => 673 / 2
    PdfZapfDingbats => 705 / 2
  }
}

///|
pub fn PdfStandardFont::stemv(self : PdfStandardFont) -> Int {
  match self {
    PdfTimesRoman => 116
    PdfTimesBold => 122
    PdfTimesItalic => 105
    PdfTimesBoldItalic => 108
    PdfHelvetica => 114
    PdfHelveticaBold => 123
    PdfHelveticaOblique => 127
    PdfHelveticaBoldOblique => 136
    PdfCourier => 88
    PdfCourierBold => 93
    PdfCourierOblique => 100
    PdfCourierBoldOblique => 104
    PdfSymbol => 0
    PdfZapfDingbats => 125
  }
}

///|
pub fn PdfStandardFont::flags(self : PdfStandardFont) -> Int {
  match self {
    PdfSymbol => 65541
    PdfZapfDingbats => 4
    PdfCourier | PdfCourierBold | PdfCourierOblique | PdfCourierBoldOblique =>
      33
    _ => 32
  }
}

///|
pub(all) struct PdfEncodingDifference {
  name : PdfName
  code : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfEncoding {
  PdfImplicitInFontFile
  PdfStandardEncoding
  PdfMacRomanEncoding
  PdfWinAnsiEncoding
  PdfMacExpertEncoding
  PdfCustomEncoding(PdfEncoding, Array[PdfEncodingDifference])
  PdfFillUndefinedWithStandard(PdfEncoding)
} derive(Debug, Eq, ToJson)

///|
pub fn PdfEncoding::debug_name(self : PdfEncoding) -> String {
  match self {
    PdfImplicitInFontFile => "ImplicitInFontFile"
    PdfStandardEncoding => "StandardEncoding"
    PdfMacRomanEncoding => "MacRomanEncoding"
    PdfWinAnsiEncoding => "WinAnsiEncoding"
    PdfMacExpertEncoding => "MacExpertEncoding"
    PdfCustomEncoding(base, differences) => {
      let mut text = "CustomEncoding with base " +
        base.debug_name() +
        " and differences "
      for difference in differences {
        text = text +
          difference.code.to_string() +
          " -> " +
          pdf_text_string_of_name(difference.name) +
          ", "
      }
      text
    }
    PdfFillUndefinedWithStandard(base) =>
      "FillUndefinedWithStandard " + base.debug_name()
  }
}

///|
pub fn PdfEncoding::pdf_name(self : PdfEncoding) -> PdfName? {
  match self {
    PdfStandardEncoding => Some(pdf_text_name("/StandardEncoding"))
    PdfMacRomanEncoding => Some(pdf_text_name("/MacRomanEncoding"))
    PdfWinAnsiEncoding => Some(pdf_text_name("/WinAnsiEncoding"))
    PdfMacExpertEncoding => Some(pdf_text_name("/MacExpertEncoding"))
    _ => None
  }
}

///|
pub fn pdf_encoding_of_name(name : PdfName) -> PdfEncoding? {
  match name {
    name if name == pdf_text_name("/StandardEncoding") =>
      Some(PdfStandardEncoding)
    name if name == pdf_text_name("/MacRomanEncoding") =>
      Some(PdfMacRomanEncoding)
    name if name == pdf_text_name("/WinAnsiEncoding") =>
      Some(PdfWinAnsiEncoding)
    name if name == pdf_text_name("/MacExpertEncoding") =>
      Some(PdfMacExpertEncoding)
    _ => None
  }
}

///|
fn pdf_text_dictionary_has_key(object : PdfObject, key : PdfName) -> Bool {
  match object.dictionary_view() {
    Some(entries) =>
      for entry in entries {
        let (name, _) = entry
        if name == key {
          break true
        }
      } nobreak {
        false
      }
    None => false
  }
}

///|
fn PdfDocument::pdf_text_font_is_embedded(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_name("/FontDescriptor"), font) {
    Some(descriptor) =>
      pdf_text_dictionary_has_key(descriptor, pdf_text_name("/FontFile")) ||
      pdf_text_dictionary_has_key(descriptor, pdf_text_name("/FontFile2")) ||
      pdf_text_dictionary_has_key(descriptor, pdf_text_name("/FontFile3"))
    None => false
  }
}

///|
fn PdfDocument::pdf_text_font_is_symbolic(
  self : PdfDocument,
  font : PdfObject,
) -> Bool raise PdfError {
  match self.lookup_direct(pdf_text_name("/FontDescriptor"), font) {
    Some(descriptor) =>
      match self.lookup_direct(pdf_text_name("/Flags"), descriptor) {
        Some(PdfInteger(flags)) => (flags & (1 << 3)) > 0
        _ => raise FontFlagsExpected
      }
    None => false
  }
}

///|
fn PdfDocument::pdf_text_default_base_encoding(
  self : PdfDocument,
  font : PdfObject,
) -> PdfEncoding raise PdfError {
  if self.pdf_text_font_is_embedded(font) ||
    self.pdf_text_font_is_symbolic(font) {
    PdfImplicitInFontFile
  } else {
    PdfStandardEncoding
  }
}

///|
fn PdfDocument::read_encoding_base(
  self : PdfDocument,
  encoding_dictionary : PdfObject,
  font : PdfObject,
) -> PdfEncoding raise PdfError {
  match
    self.lookup_direct(pdf_text_name("/BaseEncoding"), encoding_dictionary) {
    Some(PdfNameObject(name)) =>
      match pdf_encoding_of_name(name) {
        Some(encoding) => encoding
        None => raise EncodingExpected
      }
    Some(_) => raise EncodingExpected
    None => self.pdf_text_default_base_encoding(font)
  }
}

///|
fn PdfDocument::read_encoding_differences(
  self : PdfDocument,
  differences : PdfObject,
) -> Array[PdfEncodingDifference] raise PdfError {
  match self.direct(differences) {
    PdfArray(values) => {
      let output : Array[PdfEncodingDifference] = []
      let mut next_code : Int? = None
      for value in values {
        match self.direct(value) {
          PdfInteger(code) => next_code = Some(code)
          PdfNameObject(name) =>
            match next_code {
              Some(code) => {
                output.push({ name, code })
                next_code = Some(code + 1)
              }
              None => raise EncodingDifferencesMalformed
            }
          _ => raise EncodingDifferencesMalformed
        }
      }
      output
    }
    _ => raise EncodingDifferencesMalformed
  }
}

///|
fn pdf_text_is_true_type_name(name : PdfName) -> Bool {
  name == pdf_text_name("/TrueType")
}

///|
fn pdf_text_is_simple_font_subtype_name(name : PdfName) -> Bool {
  name == pdf_text_name("/Type1") ||
  name == pdf_text_name("/MMType1") ||
  name == pdf_text_name("/Type3") ||
  name == pdf_text_name("/TrueType")
}

///|
pub fn PdfDocument::read_encoding(
  self : PdfDocument,
  font : PdfObject,
) -> PdfEncoding raise PdfError {
  match self.lookup_direct(pdf_text_name("/Encoding"), font) {
    Some(PdfNameObject(name)) =>
      match pdf_encoding_of_name(name) {
        Some(encoding) => encoding
        None => PdfImplicitInFontFile
      }
    Some(PdfDictionary(_) as encoding_dictionary) =>
      match self.lookup_direct(pdf_text_name("/Subtype"), font) {
        Some(PdfNameObject(subtype)) if pdf_text_is_simple_font_subtype_name(
            subtype,
          ) => {
          let base = self.read_encoding_base(encoding_dictionary, font)
          let encoding = match
            self.lookup_direct(
              pdf_text_name("/Differences"),
              encoding_dictionary,
            ) {
            Some(differences) =>
              PdfCustomEncoding(
                base,
                self.read_encoding_differences(differences),
              )
            None => base
          }
          if pdf_text_is_true_type_name(subtype) {
            PdfFillUndefinedWithStandard(encoding)
          } else {
            encoding
          }
        }
        _ => raise FontSubtypeExpected
      }
    Some(_) => PdfImplicitInFontFile
    None => PdfImplicitInFontFile
  }
}

///|
pub fn pdf_is_unicode_string(bytes : BytesView) -> Bool {
  bytes.length() >= 2 && bytes[0].to_int() == 0xFE && bytes[1].to_int() == 0xFF
}

///|
fn pdf_text_push_utf16be_unit(
  output : Array[Byte],
  value : Int,
) -> Unit raise PdfError {
  output.push(pdf_byte_of_int((value >> 8) & 0xFF))
  output.push(pdf_byte_of_int(value & 0xFF))
}

///|
fn pdf_text_push_utf16be_codepoint(
  output : Array[Byte],
  codepoint : Int,
) -> Unit raise PdfError {
  if codepoint < 0 ||
    codepoint > 0x10FFFF ||
    (codepoint >= 0xD800 && codepoint <= 0xDFFF) {
    raise InvalidUnicodeCodepoint(codepoint)
  }
  if codepoint < 0x10000 {
    pdf_text_push_utf16be_unit(output, codepoint)
  } else {
    let shifted = codepoint - 0x10000
    pdf_text_push_utf16be_unit(output, 0xD800 | (shifted >> 10))
    pdf_text_push_utf16be_unit(output, 0xDC00 | (shifted & 0x3FF))
  }
}

///|
pub fn pdf_utf16be_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  output.push(pdf_byte_of_int(0xFE))
  output.push(pdf_byte_of_int(0xFF))
  for codepoint in codepoints {
    pdf_text_push_utf16be_codepoint(output, codepoint)
  }
  Bytes::from_array(output)
}

///|
fn pdf_text_utf16be_unit(bytes : BytesView, index : Int) -> Int raise PdfError {
  guard index + 1 < bytes.length() else { raise InvalidUTF16BE }
  (bytes[index].to_int() << 8) | bytes[index + 1].to_int()
}

///|
pub fn pdf_codepoints_of_utf16be(
  bytes : BytesView,
) -> Array[Int] raise PdfError {
  let codepoints : Array[Int] = []
  let mut index = 0
  while index < bytes.length() {
    let w1 = pdf_text_utf16be_unit(bytes, index)
    index += 2
    if w1 >= 0xD800 && w1 <= 0xDBFF {
      let w2 = pdf_text_utf16be_unit(bytes, index)
      guard w2 >= 0xDC00 && w2 <= 0xDFFF else { raise InvalidUTF16BE }
      index += 2
      codepoints.push((((w1 & 0x3FF) << 10) | (w2 & 0x3FF)) + 0x10000)
    } else if w1 >= 0xDC00 && w1 <= 0xDFFF {
      raise InvalidUTF16BE
    } else {
      codepoints.push(w1)
    }
  }
  codepoints
}
