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
pub(all) struct PdfStandardFontData {
  font : PdfStandardFont
  encoding : PdfEncoding
} derive(Debug, Eq, ToJson)

///|
pub fn PdfStandardFontData::debug_name(self : PdfStandardFontData) -> String {
  "StandardFont " + self.font.name()
}

///|
pub(all) enum PdfFontFile {
  PdfFontFile(Int)
  PdfFontFile2(Int)
  PdfFontFile3(Int)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfFontDescriptor {
  ascent : Double
  descent : Double
  avgwidth : Double
  maxwidth : Double
  flags : Int
  fontbbox : PdfRectangle
  italicangle : Double
  capheight : Double
  xheight : Double
  stemv : Double
  fontfile : PdfFontFile?
  charset : Array[PdfName]?
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfType3Glyphs {
  fontbbox : PdfRectangle
  fontmatrix : TransformMatrix
  charprocs : Array[(PdfName, PdfObject)]
  resources : PdfObject
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfSimpleFontType {
  PdfType1
  PdfMMType1
  PdfType3(PdfType3Glyphs)
  PdfTrueType
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfSimpleFont {
  fonttype : PdfSimpleFontType
  basefont : PdfName?
  firstchar : Int
  lastchar : Int
  widths : Array[Int]
  fontdescriptor : PdfFontDescriptor?
  fontmetrics : Array[Double]?
  encoding : PdfEncoding
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfCIDSystemInfo {
  registry : PdfBytes
  ordering : PdfBytes
  supplement : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfCIDVerticalWidth {
  width : Double
  vx : Double
  vy : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfCompositeCIDFont {
  cid_system_info : PdfCIDSystemInfo
  cid_basefont : PdfName
  cid_fontdescriptor : PdfFontDescriptor
  cid_widths : Array[(Int, Double)]
  cid_widths2 : Array[(Int, PdfCIDVerticalWidth)]
  cid_default_width : Double
  cid_default_width2 : Array[Double]
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfCMapEncoding {
  PdfPredefinedCMap(PdfName)
  PdfCMap(Int)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfCIDKeyedFont {
  basefont : PdfName
  composite : PdfCompositeCIDFont
  encoding : PdfCMapEncoding
} derive(Debug, Eq, ToJson)

///|
pub fn PdfCIDKeyedFont::debug_name(self : PdfCIDKeyedFont) -> String {
  "CIDKeyedFont " + pdf_text_string_of_name(self.basefont)
}

///|
pub fn PdfSimpleFontType::debug_name(self : PdfSimpleFontType) -> String {
  match self {
    PdfType1 => "Type 1"
    PdfMMType1 => "MM Type 1"
    PdfType3(data) => {
      let mut text = "Type 3: charprocs for"
      for entry in data.charprocs {
        let (name, _) = entry
        text = text + pdf_text_string_of_name(name)
      }
      text
    }
    PdfTrueType => "Truetype"
  }
}

///|
pub fn PdfSimpleFont::debug_name(self : PdfSimpleFont) -> String {
  let basefont = match self.basefont {
    Some(name) => pdf_text_string_of_name(name)
    None => ""
  }
  "fonttype = " +
  self.fonttype.debug_name() +
  "\nbasefont " +
  basefont +
  "\nencoding is " +
  self.encoding.debug_name() +
  "\n"
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
pub(all) enum PdfFont {
  PdfFontStandard(PdfStandardFontData)
  PdfFontSimple(PdfSimpleFont)
  PdfFontCIDKeyed(PdfCIDKeyedFont)
} derive(Debug, Eq, ToJson)

///|
pub fn PdfFont::debug_name(self : PdfFont) -> String {
  match self {
    PdfFontStandard(font) => font.debug_name()
    PdfFontSimple(font) => "SimpleFont " + font.debug_name()
    PdfFontCIDKeyed(font) => font.debug_name()
  }
}

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
fn pdf_text_find_immediate_indirect(object : PdfObject, key : PdfName) -> Int? {
  match object.dictionary_view() {
    Some(entries) =>
      for entry in entries {
        let (name, value) = entry
        if name == key {
          break match value {
            PdfIndirect(number) => Some(number)
            _ => None
          }
        }
      } nobreak {
        None
      }
    None => None
  }
}

///|
fn pdf_text_fontfile_of_descriptor(descriptor : PdfObject) -> PdfFontFile? {
  match
    pdf_text_find_immediate_indirect(descriptor, pdf_text_name("/FontFile")) {
    Some(number) => Some(PdfFontFile(number))
    None =>
      match
        pdf_text_find_immediate_indirect(
          descriptor,
          pdf_text_name("/FontFile2"),
        ) {
        Some(number) => Some(PdfFontFile2(number))
        None =>
          match
            pdf_text_find_immediate_indirect(
              descriptor,
              pdf_text_name("/FontFile3"),
            ) {
            Some(number) => Some(PdfFontFile3(number))
            None => None
          }
      }
  }
}

///|
fn pdf_text_zero_rectangle() -> PdfRectangle {
  { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 }
}

///|
fn PdfDocument::pdf_text_optional_number(
  self : PdfDocument,
  key : PdfName,
  object : PdfObject,
) -> Double raise PdfError {
  match self.lookup_direct(key, object) {
    Some(value) => self.get_number(value)
    None => 0.0
  }
}

///|
fn pdf_text_parse_charset(bytes : BytesView) -> Array[PdfName] raise PdfError {
  let cursor = byte_cursor_of_view(bytes)
  let names : Array[PdfName] = []
  let mut done = false
  while !done {
    cursor.drop_pdf_whitespace()
    match cursor.lex_pdf_name() {
      LexName(name) =>
        if name == pdf_text_name("/") {
          done = true
        } else {
          names.push(name)
        }
      _ => done = true
    }
  }
  names
}

///|
fn PdfDocument::pdf_text_font_charset(
  self : PdfDocument,
  descriptor : PdfObject,
) -> Array[PdfName]? raise PdfError {
  match self.lookup_direct(pdf_text_name("/CharSet"), descriptor) {
    Some(PdfString(bytes)) => Some(pdf_text_parse_charset(bytes[:]))
    _ => None
  }
}

///|
pub fn PdfDocument::read_font_descriptor(
  self : PdfDocument,
  font : PdfObject,
) -> PdfFontDescriptor? raise PdfError {
  match self.lookup_direct(pdf_text_name("/FontDescriptor"), font) {
    None => None
    Some(descriptor) => {
      let fontbbox = match
        self.lookup_direct(pdf_text_name("/FontBBox"), descriptor) {
        Some(value) => self.parse_rectangle(value)
        None => pdf_text_zero_rectangle()
      }
      Some({
        ascent: self.pdf_text_optional_number(
          pdf_text_name("/Ascent"),
          descriptor,
        ),
        descent: self.pdf_text_optional_number(
          pdf_text_name("/Descent"),
          descriptor,
        ),
        avgwidth: self.pdf_text_optional_number(
          pdf_text_name("/AvgWidth"),
          descriptor,
        ),
        maxwidth: self.pdf_text_optional_number(
          pdf_text_name("/MaxWidth"),
          descriptor,
        ),
        flags: 0,
        fontbbox,
        italicangle: 0.0,
        capheight: 0.0,
        xheight: 0.0,
        stemv: 0.0,
        fontfile: pdf_text_fontfile_of_descriptor(descriptor),
        charset: self.pdf_text_font_charset(descriptor),
      })
    }
  }
}

///|
fn PdfDocument::pdf_text_font_metrics_descriptor(
  self : PdfDocument,
  font : PdfObject,
) -> PdfObject? {
  match self.lookup_direct(pdf_text_name("/Subtype"), font) {
    Some(PdfNameObject(subtype)) if subtype == pdf_text_name("/Type3") =>
      Some(font)
    _ => self.lookup_direct(pdf_text_name("/FontDescriptor"), font)
  }
}

///|
fn PdfDocument::pdf_text_font_char_bound(
  self : PdfDocument,
  font : PdfObject,
  key : PdfName,
  error : PdfError,
) -> Int raise PdfError {
  match self.lookup_direct(key, font) {
    Some(PdfInteger(value)) if value >= 0 && value <= 255 => value
    _ => raise error
  }
}

///|
fn PdfDocument::pdf_text_font_missing_width(
  self : PdfDocument,
  descriptor : PdfObject,
) -> Double raise PdfError {
  match self.lookup_direct(pdf_text_name("/MissingWidth"), descriptor) {
    Some(value) => self.get_number(value)
    None => 0.0
  }
}

///|
fn PdfDocument::pdf_text_font_widths_array(
  self : PdfDocument,
  font : PdfObject,
) -> Array[PdfObject] raise PdfError {
  match self.lookup_direct(pdf_text_name("/Widths"), font) {
    Some(PdfArray(values)) => values
    _ => raise FontWidthsExpected
  }
}

///|
pub fn PdfDocument::read_font_metrics(
  self : PdfDocument,
  font : PdfObject,
) -> Array[Double]? raise PdfError {
  match self.pdf_text_font_metrics_descriptor(font) {
    None => None
    Some(descriptor) => {
      let firstchar = self.pdf_text_font_char_bound(
        font,
        pdf_text_name("/FirstChar"),
        FontFirstCharExpected,
      )
      let lastchar = self.pdf_text_font_char_bound(
        font,
        pdf_text_name("/LastChar"),
        FontLastCharExpected,
      )
      guard lastchar >= firstchar else { raise FontWidthsExpected }
      let widths = self.pdf_text_font_widths_array(font)
      guard widths.length() == lastchar - firstchar + 1 else {
        raise FontWidthsExpected
      }
      let missingwidth = self.pdf_text_font_missing_width(descriptor)
      let metrics : Array[Double] = []
      for _ in 0..<firstchar {
        metrics.push(missingwidth)
      }
      for width in widths {
        metrics.push(
          self.get_number(width) catch {
            _ => raise FontWidthExpected
          },
        )
      }
      for _ in 0..<(255 - lastchar) {
        metrics.push(missingwidth)
      }
      Some(metrics)
    }
  }
}

///|
fn PdfDocument::pdf_text_read_type3_glyphs(
  self : PdfDocument,
  font : PdfObject,
) -> PdfType3Glyphs raise PdfError {
  let fontbbox = match self.lookup_direct(pdf_text_name("/FontBBox"), font) {
    Some(value) =>
      self.parse_rectangle(value) catch {
        _ => pdf_text_zero_rectangle()
      }
    None => pdf_text_zero_rectangle()
  }
  let charprocs = match self.lookup_direct(pdf_text_name("/CharProcs"), font) {
    Some(PdfDictionary(entries)) => entries
    _ => raise FontCharProcsExpected
  }
  let resources = match self.lookup_direct(pdf_text_name("/Resources"), font) {
    Some(value) => value
    None => PdfDictionary([])
  }
  {
    fontbbox,
    fontmatrix: self.parse_matrix(pdf_text_name("/FontMatrix"), font),
    charprocs,
    resources,
  }
}

///|
fn PdfDocument::pdf_text_simple_font_type_of_name(
  self : PdfDocument,
  font : PdfObject,
  subtype : PdfName,
) -> PdfSimpleFontType? raise PdfError {
  if subtype == pdf_text_name("/Type1") {
    Some(PdfType1)
  } else if subtype == pdf_text_name("/MMType1") {
    Some(PdfMMType1)
  } else if subtype == pdf_text_name("/Type3") {
    Some(PdfType3(self.pdf_text_read_type3_glyphs(font)))
  } else if subtype == pdf_text_name("/TrueType") {
    Some(PdfTrueType)
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_text_read_basefont(
  self : PdfDocument,
  font : PdfObject,
) -> PdfName? {
  match self.lookup_direct(pdf_text_name("/BaseFont"), font) {
    Some(PdfNameObject(name)) => Some(name)
    _ => None
  }
}

///|
pub fn PdfDocument::read_simple_font(
  self : PdfDocument,
  font : PdfObject,
) -> PdfSimpleFont raise PdfError {
  match self.lookup_direct(pdf_text_name("/Subtype"), font) {
    Some(PdfNameObject(subtype)) =>
      match self.pdf_text_simple_font_type_of_name(font, subtype) {
        Some(fonttype) =>
          {
            fonttype,
            basefont: self.pdf_text_read_basefont(font),
            firstchar: 0,
            lastchar: 0,
            widths: [],
            fontdescriptor: self.read_font_descriptor(font),
            fontmetrics: self.read_font_metrics(font),
            encoding: self.read_encoding(font),
          }
        None => raise FontSubtypeExpected
      }
    _ => raise FontSubtypeExpected
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
fn pdf_text_is_standard14_subtype_name(name : PdfName) -> Bool {
  name == pdf_text_name("/Type1") || name == pdf_text_name("/TrueType")
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
pub fn PdfDocument::is_standard14_font(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_name("/Subtype"), font) {
    Some(PdfNameObject(subtype)) if pdf_text_is_standard14_subtype_name(subtype) =>
      match self.lookup_direct(pdf_text_name("/BaseFont"), font) {
        Some(PdfNameObject(base_font)) =>
          pdf_standard_font_of_pdf_name(base_font) != None &&
          self.lookup_direct(pdf_text_name("/Widths"), font) == None
        _ => false
      }
    _ => false
  }
}

///|
pub fn PdfDocument::is_simple_font(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_name("/Subtype"), font) {
    Some(PdfNameObject(subtype)) =>
      pdf_text_is_simple_font_subtype_name(subtype)
    _ => false
  }
}

///|
pub fn PdfDocument::is_cidkeyed_font(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_name("/Subtype"), font) {
    Some(PdfNameObject(subtype)) => subtype == pdf_text_name("/Type0")
    _ => false
  }
}

///|
fn PdfDocument::pdf_text_cid_string_entry(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  error : PdfError,
) -> PdfBytes raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(PdfString(bytes)) => bytes
    _ => raise error
  }
}

///|
pub fn PdfDocument::read_cid_system_info(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfCIDSystemInfo raise PdfError {
  {
    registry: self.pdf_text_cid_string_entry(
      dictionary,
      pdf_text_name("/Registry"),
      CIDRegistryExpected,
    ),
    ordering: self.pdf_text_cid_string_entry(
      dictionary,
      pdf_text_name("/Ordering"),
      CIDOrderingExpected,
    ),
    supplement: match
      self.lookup_direct(pdf_text_name("/Supplement"), dictionary) {
      Some(PdfInteger(value)) => value
      _ => raise CIDSupplementExpected
    },
  }
}

///|
fn PdfDocument::pdf_text_cid_number(
  self : PdfDocument,
  value : PdfObject,
  error : PdfError,
) -> Double raise PdfError {
  self.get_number(value) catch {
    _ => raise error
  }
}

///|
fn PdfDocument::pdf_text_read_cid_widths(
  self : PdfDocument,
  values : ArrayView[PdfObject],
) -> Array[(Int, Double)] raise PdfError {
  let output : Array[(Int, Double)] = []
  let mut index = 0
  while index < values.length() {
    match self.direct(values[index]) {
      PdfInteger(first_code) => {
        guard index + 1 < values.length() else { raise CIDWidthsExpected }
        match self.direct(values[index + 1]) {
          PdfArray(widths) => {
            for offset in 0..<widths.length() {
              output.push(
                (
                  first_code + offset,
                  self.pdf_text_cid_number(widths[offset], CIDWidthsExpected),
                ),
              )
            }
            index += 2
          }
          PdfInteger(last_code) => {
            guard index + 2 < values.length() && last_code >= first_code else {
              raise CIDWidthsExpected
            }
            let width = self.pdf_text_cid_number(
              values[index + 2],
              CIDWidthsExpected,
            )
            for code in first_code..<=last_code {
              output.push((code, width))
            }
            index += 3
          }
          _ => raise CIDWidthsExpected
        }
      }
      _ => raise CIDWidthsExpected
    }
  }
  output
}

///|
fn PdfDocument::pdf_text_read_cid_widths2(
  self : PdfDocument,
  values : ArrayView[PdfObject],
) -> Array[(Int, PdfCIDVerticalWidth)] raise PdfError {
  let output : Array[(Int, PdfCIDVerticalWidth)] = []
  let mut index = 0
  while index < values.length() {
    match self.direct(values[index]) {
      PdfInteger(first_code) => {
        guard index + 1 < values.length() else { raise CIDWidths2Expected }
        match self.direct(values[index + 1]) {
          PdfArray(widths) => {
            guard widths.length() % 3 == 0 else { raise CIDWidths2Expected }
            let mut code = first_code
            let mut width_index = 0
            while width_index < widths.length() {
              output.push(
                (
                  code,
                  {
                    width: self.pdf_text_cid_number(
                      widths[width_index],
                      CIDWidths2Expected,
                    ),
                    vx: self.pdf_text_cid_number(
                      widths[width_index + 1],
                      CIDWidths2Expected,
                    ),
                    vy: self.pdf_text_cid_number(
                      widths[width_index + 2],
                      CIDWidths2Expected,
                    ),
                  },
                ),
              )
              code += 1
              width_index += 3
            }
            index += 2
          }
          PdfInteger(last_code) => {
            guard index + 4 < values.length() && last_code >= first_code else {
              raise CIDWidths2Expected
            }
            let width = {
              width: self.pdf_text_cid_number(
                values[index + 2],
                CIDWidths2Expected,
              ),
              vx: self.pdf_text_cid_number(
                values[index + 3],
                CIDWidths2Expected,
              ),
              vy: self.pdf_text_cid_number(
                values[index + 4],
                CIDWidths2Expected,
              ),
            }
            for code in first_code..<=last_code {
              output.push((code, width))
            }
            index += 5
          }
          _ => raise CIDWidths2Expected
        }
      }
      _ => raise CIDWidths2Expected
    }
  }
  output
}

///|
fn PdfDocument::pdf_text_cid_widths(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Array[(Int, Double)] raise PdfError {
  match self.lookup_direct(pdf_text_name("/W"), dictionary) {
    Some(PdfArray(values)) => self.pdf_text_read_cid_widths(values)
    _ => []
  }
}

///|
fn PdfDocument::pdf_text_cid_widths2(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Array[(Int, PdfCIDVerticalWidth)] raise PdfError {
  match self.lookup_direct(pdf_text_name("/W2"), dictionary) {
    Some(PdfArray(values)) => self.pdf_text_read_cid_widths2(values)
    _ => []
  }
}

///|
fn PdfDocument::pdf_text_cid_default_width(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Double raise PdfError {
  match self.lookup_direct(pdf_text_name("/DW"), dictionary) {
    Some(value) => self.pdf_text_cid_number(value, CIDWidthsExpected)
    None => 1000.0
  }
}

///|
fn PdfDocument::pdf_text_cid_default_width2(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Array[Double] raise PdfError {
  match self.lookup_direct(pdf_text_name("/DW2"), dictionary) {
    Some(PdfArray(values)) => {
      let output : Array[Double] = []
      for value in values {
        output.push(self.pdf_text_cid_number(value, CIDWidths2Expected))
      }
      output
    }
    _ => [880.0, -1000.0]
  }
}

///|
fn PdfDocument::pdf_text_read_descendant(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfCompositeCIDFont raise PdfError {
  let cid_system_info = match
    self.lookup_direct(pdf_text_name("/CIDSystemInfo"), dictionary) {
    Some(system_info) => self.read_cid_system_info(system_info)
    None => raise CIDSystemInfoExpected
  }
  let cid_basefont = match
    self.lookup_direct(pdf_text_name("/BaseFont"), dictionary) {
    Some(PdfNameObject(name)) => name
    _ => raise CIDBaseFontExpected
  }
  let cid_fontdescriptor = match self.read_font_descriptor(dictionary) {
    Some(fontdescriptor) => fontdescriptor
    None => raise CIDFontDescriptorExpected
  }
  {
    cid_system_info,
    cid_basefont,
    cid_fontdescriptor,
    cid_widths: self.pdf_text_cid_widths(dictionary),
    cid_widths2: self.pdf_text_cid_widths2(dictionary),
    cid_default_width: self.pdf_text_cid_default_width(dictionary),
    cid_default_width2: self.pdf_text_cid_default_width2(dictionary),
  }
}

///|
fn PdfDocument::pdf_text_read_cmap_encoding(
  self : PdfDocument,
  font : PdfObject,
) -> PdfCMapEncoding raise PdfError {
  match self.lookup_direct(pdf_text_name("/Encoding"), font) {
    Some(PdfNameObject(name)) => PdfPredefinedCMap(name)
    Some(PdfStreamObject(_)) =>
      match pdf_text_find_immediate_indirect(font, pdf_text_name("/Encoding")) {
        Some(number) => PdfCMap(number)
        None => raise CMapEncodingExpected
      }
    _ => raise CMapEncodingExpected
  }
}

///|
pub fn PdfDocument::read_cidkeyed_font(
  self : PdfDocument,
  font : PdfObject,
) -> PdfCIDKeyedFont raise PdfError {
  let basefont = match self.lookup_direct(pdf_text_name("/BaseFont"), font) {
    Some(PdfNameObject(name)) => name
    _ => raise BaseFontExpected
  }
  let composite = match
    self.lookup_direct(pdf_text_name("/DescendantFonts"), font) {
    Some(PdfArray([descendant])) =>
      self.pdf_text_read_descendant(self.direct(descendant))
    _ => raise DescendantFontExpected
  }
  { basefont, composite, encoding: self.pdf_text_read_cmap_encoding(font) }
}

///|
pub fn PdfDocument::read_standard14_font(
  self : PdfDocument,
  font : PdfObject,
) -> PdfStandardFontData raise PdfError {
  match self.lookup_direct(pdf_text_name("/BaseFont"), font) {
    Some(PdfNameObject(base_font)) =>
      match pdf_standard_font_of_pdf_name(base_font) {
        Some(standard_font) =>
          { font: standard_font, encoding: self.read_encoding(font) }
        None => raise StandardFontExpected
      }
    _ => raise BaseFontExpected
  }
}

///|
pub fn PdfDocument::read_font(
  self : PdfDocument,
  font : PdfObject,
) -> PdfFont raise PdfError {
  if self.is_standard14_font(font) {
    PdfFontStandard(self.read_standard14_font(font))
  } else if self.is_simple_font(font) {
    PdfFontSimple(self.read_simple_font(font))
  } else if self.is_cidkeyed_font(font) {
    PdfFontCIDKeyed(self.read_cidkeyed_font(font))
  } else {
    raise FontTypeExpected
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

///|
fn pdf_text_check_unicode_codepoint(codepoint : Int) -> Unit raise PdfError {
  if codepoint < 0 ||
    codepoint > 0x10FFFF ||
    (codepoint >= 0xD800 && codepoint <= 0xDFFF) {
    raise InvalidUnicodeCodepoint(codepoint)
  }
}

///|
pub fn pdf_utf8_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  for codepoint in codepoints {
    pdf_text_check_unicode_codepoint(codepoint)
    if codepoint <= 0x7F {
      output.push(pdf_byte_of_int(codepoint))
    } else if codepoint <= 0x7FF {
      output.push(pdf_byte_of_int((codepoint >> 6) | 0xC0))
      output.push(pdf_byte_of_int((codepoint & 0x3F) | 0x80))
    } else if codepoint <= 0xFFFF {
      output.push(pdf_byte_of_int((codepoint >> 12) | 0xE0))
      output.push(pdf_byte_of_int(((codepoint >> 6) & 0x3F) | 0x80))
      output.push(pdf_byte_of_int((codepoint & 0x3F) | 0x80))
    } else {
      output.push(pdf_byte_of_int((codepoint >> 18) | 0xF0))
      output.push(pdf_byte_of_int(((codepoint >> 12) & 0x3F) | 0x80))
      output.push(pdf_byte_of_int(((codepoint >> 6) & 0x3F) | 0x80))
      output.push(pdf_byte_of_int((codepoint & 0x3F) | 0x80))
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_text_is_utf8_continuation(byte : Int) -> Bool {
  byte >> 6 == 0b10
}

///|
fn pdf_text_push_utf8_codepoint(
  output : Array[Int],
  codepoint : Int,
  min_codepoint : Int,
) -> Unit raise PdfError {
  pdf_text_check_unicode_codepoint(codepoint)
  guard codepoint >= min_codepoint else { raise InvalidUTF8 }
  output.push(codepoint)
}

///|
pub fn pdf_codepoints_of_utf8(bytes : BytesView) -> Array[Int] raise PdfError {
  let output : Array[Int] = []
  let mut index = 0
  while index < bytes.length() {
    let first = bytes[index].to_int()
    if first >> 7 == 0 {
      output.push(first)
      index += 1
    } else if first >> 5 == 0b110 {
      guard index + 1 < bytes.length() else { raise InvalidUTF8 }
      let b1 = bytes[index + 1].to_int()
      guard pdf_text_is_utf8_continuation(b1) else { raise InvalidUTF8 }
      pdf_text_push_utf8_codepoint(
        output,
        ((first & 0x1F) << 6) | (b1 & 0x3F),
        0x80,
      )
      index += 2
    } else if first >> 4 == 0b1110 {
      guard index + 2 < bytes.length() else { raise InvalidUTF8 }
      let b1 = bytes[index + 1].to_int()
      let b2 = bytes[index + 2].to_int()
      guard pdf_text_is_utf8_continuation(b1) &&
        pdf_text_is_utf8_continuation(b2) else {
        raise InvalidUTF8
      }
      pdf_text_push_utf8_codepoint(
        output,
        ((first & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F),
        0x800,
      )
      index += 3
    } else if first >> 3 == 0b11110 {
      guard index + 3 < bytes.length() else { raise InvalidUTF8 }
      let b1 = bytes[index + 1].to_int()
      let b2 = bytes[index + 2].to_int()
      let b3 = bytes[index + 3].to_int()
      guard pdf_text_is_utf8_continuation(b1) &&
        pdf_text_is_utf8_continuation(b2) &&
        pdf_text_is_utf8_continuation(b3) else {
        raise InvalidUTF8
      }
      pdf_text_push_utf8_codepoint(
        output,
        ((first & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F),
        0x10000,
      )
      index += 4
    } else {
      raise InvalidUTF8
    }
  }
  output
}

///|
fn pdf_codepoint_of_pdfdocencoding_byte_option(value : Int) -> Int? {
  match value {
    0x09 => Some(0x0009)
    0x0A => Some(0x000A)
    0x0C => Some(0x000C)
    0x0D => Some(0x000D)
    0x18 => Some(0x02D8)
    0x19 => Some(0x02C7)
    0x1A => Some(0x02C6)
    0x1B => Some(0x02D9)
    0x1C => Some(0x02DD)
    0x1D => Some(0x02DB)
    0x1E => Some(0x02DA)
    0x1F => Some(0x02DC)
    0x20..=0x7E => Some(value)
    0x80 => Some(0x2022)
    0x81 => Some(0x2020)
    0x82 => Some(0x2021)
    0x83 => Some(0x2026)
    0x84 => Some(0x2014)
    0x85 => Some(0x2013)
    0x86 => Some(0x0192)
    0x87 => Some(0x2044)
    0x88 => Some(0x2039)
    0x89 => Some(0x203A)
    0x8A => Some(0x2212)
    0x8B => Some(0x2030)
    0x8C => Some(0x201E)
    0x8D => Some(0x201C)
    0x8E => Some(0x201D)
    0x8F => Some(0x2018)
    0x90 => Some(0x2019)
    0x91 => Some(0x201A)
    0x92 => Some(0x2122)
    0x93 => Some(0xFB02)
    0x95 => Some(0x0141)
    0x96 => Some(0x0152)
    0x97 => Some(0x0160)
    0x98 => Some(0x0178)
    0x99 => Some(0x017D)
    0x9A => Some(0x0131)
    0x9B => Some(0x0142)
    0x9C => Some(0x0153)
    0x9D => Some(0x0161)
    0x9E => Some(0x017E)
    0xA0 => Some(0x20AC)
    0xA1..=0xAC => Some(value)
    0xAE..=0xFF => Some(value)
    _ => None
  }
}

///|
pub fn pdf_codepoint_of_pdfdocencoding_byte(value : Int) -> Int raise PdfError {
  match pdf_codepoint_of_pdfdocencoding_byte_option(value) {
    Some(codepoint) => codepoint
    None => raise InvalidPDFDocEncoding(value)
  }
}

///|
pub fn pdf_codepoints_of_pdfdocencoding(
  bytes : BytesView,
) -> Array[Int] raise PdfError {
  let codepoints : Array[Int] = []
  for byte in bytes {
    codepoints.push(pdf_codepoint_of_pdfdocencoding_byte(byte.to_int()))
  }
  codepoints
}

///|
pub fn pdf_pdfdocencoding_byte_of_codepoint(codepoint : Int) -> Byte? {
  if codepoint == 0xFB01 {
    Some(0x93)
  } else {
    for value in 0..<=255 {
      match pdf_codepoint_of_pdfdocencoding_byte_option(value) {
        Some(decoded) if decoded == codepoint => break Some(value.to_byte())
        _ => ()
      }
    } nobreak {
      None
    }
  }
}

///|
pub fn pdf_pdfdocencoding_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes? {
  let output : Array[Byte] = []
  for codepoint in codepoints {
    match pdf_pdfdocencoding_byte_of_codepoint(codepoint) {
      Some(byte) => output.push(byte)
      None => break None
    }
  } nobreak {
    Some(Bytes::from_array(output))
  }
}

///|
pub fn pdf_pdfdocstring_of_codepoints(
  codepoints : ArrayView[Int],
) -> PdfBytes raise PdfError {
  match pdf_pdfdocencoding_of_codepoints(codepoints) {
    Some(encoded) => encoded
    None => pdf_utf16be_of_codepoints(codepoints)
  }
}

///|
pub fn pdf_codepoints_of_pdfdocstring(
  bytes : BytesView,
) -> Array[Int] raise PdfError {
  if pdf_is_unicode_string(bytes) {
    pdf_codepoints_of_utf16be(bytes[2:])
  } else {
    pdf_codepoints_of_pdfdocencoding(bytes)
  }
}

///|
pub fn pdf_utf8_of_pdfdocstring(bytes : BytesView) -> PdfBytes raise PdfError {
  pdf_utf8_of_codepoints(pdf_codepoints_of_pdfdocstring(bytes))
}

///|
pub fn pdf_pdfdocstring_of_utf8(bytes : BytesView) -> PdfBytes raise PdfError {
  pdf_pdfdocstring_of_codepoints(pdf_codepoints_of_utf8(bytes))
}

///|
pub fn pdf_simplify_utf16be(bytes : BytesView) -> PdfBytes raise PdfError {
  if pdf_is_unicode_string(bytes) {
    pdf_pdfdocstring_of_codepoints(pdf_codepoints_of_pdfdocstring(bytes))
  } else {
    bytes.to_owned()
  }
}
