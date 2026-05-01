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
  tounicode : Array[(Int, PdfBytes)]?
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
pub fn PdfCMapEncoding::is_identity_h(self : PdfCMapEncoding) -> Bool {
  match self {
    PdfPredefinedCMap(name) => name == pdf_text_name("/Identity-H")
    _ => false
  }
}

///|
pub fn PdfCIDKeyedFont::is_identity_h(self : PdfCIDKeyedFont) -> Bool {
  self.encoding.is_identity_h()
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
pub(all) struct PdfTextExtractor {
  font : PdfFont
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfTextGlyph {
  glyphname : PdfName
  codepoints : Array[Int]
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
pub fn PdfFont::is_identity_h(self : PdfFont) -> Bool {
  match self {
    PdfFontCIDKeyed(font) => font.is_identity_h()
    _ => false
  }
}

///|
pub fn PdfFont::text_extractor(self : PdfFont) -> PdfTextExtractor {
  { font: self }
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
fn pdf_text_empty_font_descriptor() -> PdfFontDescriptor {
  {
    ascent: 0.0,
    descent: 0.0,
    avgwidth: 0.0,
    maxwidth: 0.0,
    flags: 0,
    fontbbox: pdf_text_zero_rectangle(),
    italicangle: 0.0,
    capheight: 0.0,
    xheight: 0.0,
    stemv: 0.0,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
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
        ..pdf_text_empty_font_descriptor(),
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
        fontbbox,
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
fn pdf_text_hex_digit_value(byte : Byte) -> Int? {
  let value = byte.to_int()
  if value >= 48 && value <= 57 {
    Some(value - 48)
  } else if value >= 65 && value <= 70 {
    Some(value - 55)
  } else if value >= 97 && value <= 102 {
    Some(value - 87)
  } else {
    None
  }
}

///|
fn pdf_text_parse_hex_bytes(
  line : BytesView,
  start : Int,
  stop : Int,
) -> PdfBytes? {
  guard stop >= start && (stop - start) % 2 == 0 else { return None }
  let output : Array[Byte] = []
  let mut index = start
  while index < stop {
    match
      (
        pdf_text_hex_digit_value(line[index]),
        pdf_text_hex_digit_value(line[index + 1]),
      ) {
      (Some(high), Some(low)) => output.push((high * 16 + low).to_byte())
      _ => break None
    }
    index += 2
  } nobreak {
    Some(Bytes::from_array(output))
  }
}

///|
fn pdf_text_skip_horizontal_space(line : BytesView, start : Int) -> Int {
  let mut index = start
  while index < line.length() &&
        (line[index].to_int() == 32 || line[index].to_int() == 9) {
    index += 1
  }
  index
}

///|
fn pdf_text_line_contains_ascii(line : BytesView, word : String) -> Bool {
  let needle = @ascii.encode(word)
  guard needle.length() > 0 && line.length() >= needle.length() else {
    return false
  }
  for index in 0..<=(line.length() - needle.length()) {
    let mut matched = true
    for offset in 0..<needle.length() {
      if line[index + offset] != needle[offset] {
        matched = false
      }
    }
    if matched {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_text_parse_cmap_hex_groups(line : BytesView) -> Array[PdfBytes]? {
  let groups : Array[PdfBytes] = []
  let mut index = 0
  while index < line.length() {
    index = pdf_text_skip_horizontal_space(line, index)
    if index >= line.length() {
      break
    }
    if line[index].to_int() != 60 {
      break
    }
    let start = index + 1
    let mut stop = start
    while stop < line.length() && line[stop].to_int() != 62 {
      stop += 1
    }
    guard stop < line.length() else { return None }
    match pdf_text_parse_hex_bytes(line, start, stop) {
      Some(bytes) => groups.push(bytes)
      None => return None
    }
    index = stop + 1
  }
  if groups.length() == 0 {
    None
  } else {
    Some(groups)
  }
}

///|
fn pdf_text_bytes_to_int(bytes : BytesView) -> Int? {
  guard bytes.length() > 0 else { return None }
  let mut value = 0
  for byte in bytes {
    value = (value << 8) | byte.to_int()
  }
  Some(value)
}

///|
fn pdf_text_index_of_byte(line : BytesView, target : Int, start : Int) -> Int? {
  let mut index = start
  while index < line.length() {
    if line[index].to_int() == target {
      break Some(index)
    }
    index += 1
  } nobreak {
    None
  }
}

///|
fn pdf_text_parse_cmap_hex_array(line : BytesView) -> Array[PdfBytes]? {
  match
    (pdf_text_index_of_byte(line, 91, 0), pdf_text_index_of_byte(line, 93, 0)) {
    (Some(start), Some(stop)) if stop > start =>
      pdf_text_parse_cmap_hex_groups(line[start + 1:stop])
    _ => None
  }
}

///|
fn pdf_text_add_to_big_endian_bytes(
  bytes : PdfBytes,
  increment : Int,
) -> PdfBytes? {
  guard increment >= 0 else { return None }
  let output = bytes.to_array()
  let mut carry = increment
  let mut index = output.length()
  while index > 0 && carry > 0 {
    index -= 1
    let sum = output[index].to_int() + carry % 256
    output[index] = (sum % 256).to_byte()
    carry = carry / 256 + sum / 256
  }
  if carry == 0 {
    Some(Bytes::from_array(output))
  } else {
    None
  }
}

///|
fn pdf_text_tounicode_bfchar_entry_of_line(
  line : BytesView,
) -> (Int, PdfBytes)? {
  match pdf_text_parse_cmap_hex_groups(line) {
    Some([source, unicode]) =>
      match pdf_text_bytes_to_int(source[:]) {
        Some(code) => Some((code, unicode))
        None => None
      }
    _ => None
  }
}

///|
fn pdf_text_tounicode_bfrange_entries_of_line(
  line : BytesView,
) -> Array[(Int, PdfBytes)]? {
  match pdf_text_parse_cmap_hex_groups(line) {
    Some([source, stop, unicode]) =>
      match (pdf_text_bytes_to_int(source[:]), pdf_text_bytes_to_int(stop[:])) {
        (Some(first), Some(last)) if first <= last => {
          let entries : Array[(Int, PdfBytes)] = []
          for code in first..<=last {
            match pdf_text_add_to_big_endian_bytes(unicode, code - first) {
              Some(bytes) => entries.push((code, bytes))
              None => return None
            }
          }
          Some(entries)
        }
        _ => None
      }
    Some([source, stop]) =>
      match
        (
          pdf_text_bytes_to_int(source[:]),
          pdf_text_bytes_to_int(stop[:]),
          pdf_text_parse_cmap_hex_array(line),
        ) {
        (Some(first), Some(last), Some(unicodes)) if first <= last &&
          unicodes.length() == last - first + 1 => {
          let entries : Array[(Int, PdfBytes)] = []
          for index in 0..<unicodes.length() {
            entries.push((first + index, unicodes[index]))
          }
          Some(entries)
        }
        _ => None
      }
    _ => None
  }
}

///|
priv enum PdfTextCMapSection {
  PdfTextCMapNone
  PdfTextCMapBFChar
  PdfTextCMapBFRange
}

///|
fn pdf_text_parse_tounicode(data : BytesView) -> Array[(Int, PdfBytes)]? {
  let cursor = byte_cursor_of_view(data)
  let entries : Array[(Int, PdfBytes)] = []
  let mut section = PdfTextCMapNone
  for line in cursor.read_line_views() {
    if pdf_text_line_contains_ascii(line, "beginbfchar") {
      section = PdfTextCMapBFChar
    } else if pdf_text_line_contains_ascii(line, "endbfchar") {
      section = PdfTextCMapNone
    } else if pdf_text_line_contains_ascii(line, "beginbfrange") {
      section = PdfTextCMapBFRange
    } else if pdf_text_line_contains_ascii(line, "endbfrange") {
      section = PdfTextCMapNone
    } else {
      match section {
        PdfTextCMapBFChar =>
          match pdf_text_tounicode_bfchar_entry_of_line(line) {
            Some(entry) => entries.push(entry)
            None => ()
          }
        PdfTextCMapBFRange =>
          match pdf_text_tounicode_bfrange_entries_of_line(line) {
            Some(line_entries) =>
              for entry in line_entries {
                entries.push(entry)
              }
            None => ()
          }
        PdfTextCMapNone => ()
      }
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries)
  }
}

///|
fn pdf_text_decoded_stream_data(object : PdfObject) -> PdfBytes? {
  match object {
    PdfStreamObject({ dictionary, data: StreamGot(bytes) }) =>
      try pdf_stream_first_filter(dictionary) catch {
        _ => None
      } noraise {
        None => Some(bytes)
        Some(_) =>
          try pdf_decode_stream(object) catch {
            _ => None
          } noraise {
            PdfStreamObject({ data: StreamGot(decoded), .. }) => Some(decoded)
            _ => None
          }
      }
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_tounicode_of_font(
  self : PdfDocument,
  font : PdfObject,
) -> Array[(Int, PdfBytes)]? {
  match self.lookup_direct(pdf_text_name("/ToUnicode"), font) {
    Some(PdfStreamObject(_) as stream) =>
      match pdf_text_decoded_stream_data(stream) {
        Some(bytes) => pdf_text_parse_tounicode(bytes[:])
        None => None
      }
    _ => None
  }
}

///|
fn PdfFontDescriptor::pdf_text_with_tounicode(
  self : PdfFontDescriptor,
  tounicode : Array[(Int, PdfBytes)],
) -> PdfFontDescriptor {
  { ..self, tounicode: Some(tounicode) }
}

///|
fn PdfFont::pdf_text_with_tounicode(
  self : PdfFont,
  tounicode : Array[(Int, PdfBytes)]?,
) -> PdfFont {
  match tounicode {
    None => self
    Some(tounicode) =>
      match self {
        PdfFontSimple(simple) => {
          let descriptor = match simple.fontdescriptor {
            Some(descriptor) => descriptor
            None => pdf_text_empty_font_descriptor()
          }
          PdfFontSimple({
            ..simple,
            fontdescriptor: Some(descriptor.pdf_text_with_tounicode(tounicode)),
          })
        }
        PdfFontCIDKeyed(cid_font) => {
          let composite = {
            ..cid_font.composite,
            cid_fontdescriptor: cid_font.composite.cid_fontdescriptor.pdf_text_with_tounicode(
              tounicode,
            ),
          }
          PdfFontCIDKeyed({ ..cid_font, composite, })
        }
        PdfFontStandard(_) => self
      }
  }
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
  let read = if self.is_standard14_font(font) {
    PdfFontStandard(self.read_standard14_font(font))
  } else if self.is_simple_font(font) {
    PdfFontSimple(self.read_simple_font(font))
  } else if self.is_cidkeyed_font(font) {
    PdfFontCIDKeyed(self.read_cidkeyed_font(font))
  } else {
    raise FontTypeExpected
  }
  read.pdf_text_with_tounicode(self.pdf_text_tounicode_of_font(font))
}

///|
pub fn PdfDocument::text_extractor_of_font(
  self : PdfDocument,
  font : PdfObject,
) -> PdfTextExtractor raise PdfError {
  self.read_font(font).text_extractor()
}

///|
fn PdfFont::pdf_text_tounicode(self : PdfFont) -> Array[(Int, PdfBytes)]? {
  match self {
    PdfFontSimple(
      { fontdescriptor: Some({ tounicode: Some(tounicode), .. }), .. }
    ) => Some(tounicode)
    PdfFontCIDKeyed(
      {
        composite: {
          cid_fontdescriptor: { tounicode: Some(tounicode), .. },
          ..,
        },
        ..,
      }
    ) => Some(tounicode)
    _ => None
  }
}

///|
fn pdf_text_lookup_tounicode(
  tounicode : ArrayView[(Int, PdfBytes)],
  code : Int,
) -> PdfBytes? {
  for entry in tounicode {
    if entry.0 == code {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_single_byte_glyphname(value : Int) -> PdfName {
  let output : Array[Byte] = [47, value.to_byte()]
  pdf_name_of_bytes(Bytes::from_array(output))
}

///|
fn pdf_text_ascii_digit_glyphname(code : Int) -> PdfName? {
  match code {
    48 => Some(pdf_text_name("/zero"))
    49 => Some(pdf_text_name("/one"))
    50 => Some(pdf_text_name("/two"))
    51 => Some(pdf_text_name("/three"))
    52 => Some(pdf_text_name("/four"))
    53 => Some(pdf_text_name("/five"))
    54 => Some(pdf_text_name("/six"))
    55 => Some(pdf_text_name("/seven"))
    56 => Some(pdf_text_name("/eight"))
    57 => Some(pdf_text_name("/nine"))
    _ => None
  }
}

///|
fn pdf_text_ascii_punctuation_glyphname(
  code : Int,
  standard_quotes : Bool,
) -> PdfName? {
  match code {
    32 => Some(pdf_text_name("/space"))
    33 => Some(pdf_text_name("/exclam"))
    34 => Some(pdf_text_name("/quotedbl"))
    35 => Some(pdf_text_name("/numbersign"))
    36 => Some(pdf_text_name("/dollar"))
    37 => Some(pdf_text_name("/percent"))
    38 => Some(pdf_text_name("/ampersand"))
    39 if standard_quotes => Some(pdf_text_name("/quoteright"))
    39 => Some(pdf_text_name("/quotesingle"))
    40 => Some(pdf_text_name("/parenleft"))
    41 => Some(pdf_text_name("/parenright"))
    42 => Some(pdf_text_name("/asterisk"))
    43 => Some(pdf_text_name("/plus"))
    44 => Some(pdf_text_name("/comma"))
    45 => Some(pdf_text_name("/hyphen"))
    46 => Some(pdf_text_name("/period"))
    47 => Some(pdf_text_name("/slash"))
    58 => Some(pdf_text_name("/colon"))
    59 => Some(pdf_text_name("/semicolon"))
    60 => Some(pdf_text_name("/less"))
    61 => Some(pdf_text_name("/equal"))
    62 => Some(pdf_text_name("/greater"))
    63 => Some(pdf_text_name("/question"))
    64 => Some(pdf_text_name("/at"))
    91 => Some(pdf_text_name("/bracketleft"))
    92 => Some(pdf_text_name("/backslash"))
    93 => Some(pdf_text_name("/bracketright"))
    94 => Some(pdf_text_name("/asciicircum"))
    95 => Some(pdf_text_name("/underscore"))
    96 if standard_quotes => Some(pdf_text_name("/quoteleft"))
    96 => Some(pdf_text_name("/grave"))
    123 => Some(pdf_text_name("/braceleft"))
    124 => Some(pdf_text_name("/bar"))
    125 => Some(pdf_text_name("/braceright"))
    126 => Some(pdf_text_name("/asciitilde"))
    _ => None
  }
}

///|
fn pdf_text_basic_latin_glyphname(
  code : Int,
  standard_quotes : Bool,
) -> PdfName? {
  if (code >= 65 && code <= 90) || (code >= 97 && code <= 122) {
    Some(pdf_text_single_byte_glyphname(code))
  } else {
    match pdf_text_ascii_digit_glyphname(code) {
      Some(name) => Some(name)
      None => pdf_text_ascii_punctuation_glyphname(code, standard_quotes)
    }
  }
}

///|
fn pdf_text_standard_glyphname(code : Int) -> PdfName? {
  match pdf_text_basic_latin_glyphname(code, true) {
    Some(name) => Some(name)
    None =>
      match code {
        0xA1 => Some(pdf_text_name("/exclamdown"))
        0xA2 => Some(pdf_text_name("/cent"))
        0xA3 => Some(pdf_text_name("/sterling"))
        0xA4 => Some(pdf_text_name("/fraction"))
        0xA5 => Some(pdf_text_name("/yen"))
        0xA6 => Some(pdf_text_name("/florin"))
        0xA7 => Some(pdf_text_name("/section"))
        0xA8 => Some(pdf_text_name("/currency"))
        0xA9 => Some(pdf_text_name("/quotesingle"))
        0xAA => Some(pdf_text_name("/quotedblleft"))
        0xAB => Some(pdf_text_name("/guillemotleft"))
        0xAC => Some(pdf_text_name("/guilsinglleft"))
        0xAD => Some(pdf_text_name("/guilsinglright"))
        0xAE => Some(pdf_text_name("/fi"))
        0xAF => Some(pdf_text_name("/fl"))
        0xB1 => Some(pdf_text_name("/endash"))
        0xB2 => Some(pdf_text_name("/dagger"))
        0xB3 => Some(pdf_text_name("/daggerdbl"))
        0xB4 => Some(pdf_text_name("/periodcentered"))
        0xB6 => Some(pdf_text_name("/paragraph"))
        0xB7 => Some(pdf_text_name("/bullet"))
        0xB8 => Some(pdf_text_name("/quotesinglbase"))
        0xB9 => Some(pdf_text_name("/quotedblbase"))
        0xBA => Some(pdf_text_name("/quotedblright"))
        0xBB => Some(pdf_text_name("/guillemotright"))
        0xBC => Some(pdf_text_name("/ellipsis"))
        0xBD => Some(pdf_text_name("/perthousand"))
        0xBF => Some(pdf_text_name("/questiondown"))
        _ => None
      }
  }
}

///|
fn pdf_text_macroman_glyphname(code : Int) -> PdfName? {
  match pdf_text_basic_latin_glyphname(code, false) {
    Some(name) => Some(name)
    None =>
      match code {
        0x80 => Some(pdf_text_name("/Adieresis"))
        0x81 => Some(pdf_text_name("/Aring"))
        0x82 => Some(pdf_text_name("/Ccedilla"))
        0x83 => Some(pdf_text_name("/Eacute"))
        0x84 => Some(pdf_text_name("/Ntilde"))
        0x85 => Some(pdf_text_name("/Odieresis"))
        0x86 => Some(pdf_text_name("/Udieresis"))
        0x87 => Some(pdf_text_name("/aacute"))
        0x88 => Some(pdf_text_name("/agrave"))
        0x89 => Some(pdf_text_name("/acircumflex"))
        0x8A => Some(pdf_text_name("/adieresis"))
        0x8B => Some(pdf_text_name("/atilde"))
        0x8C => Some(pdf_text_name("/aring"))
        0x8D => Some(pdf_text_name("/ccedilla"))
        0x8E => Some(pdf_text_name("/eacute"))
        0x8F => Some(pdf_text_name("/egrave"))
        0x90 => Some(pdf_text_name("/ecircumflex"))
        0x91 => Some(pdf_text_name("/edieresis"))
        _ => None
      }
  }
}

///|
fn pdf_text_winansi_glyphname(code : Int) -> PdfName? {
  match pdf_text_basic_latin_glyphname(code, false) {
    Some(name) => Some(name)
    None =>
      match code {
        0x80 => Some(pdf_text_name("/Euro"))
        0x82 => Some(pdf_text_name("/quotesinglbase"))
        0x83 => Some(pdf_text_name("/florin"))
        0x84 => Some(pdf_text_name("/quotedblbase"))
        0x85 => Some(pdf_text_name("/ellipsis"))
        0x86 => Some(pdf_text_name("/dagger"))
        0x87 => Some(pdf_text_name("/daggerdbl"))
        0x88 => Some(pdf_text_name("/circumflex"))
        0x89 => Some(pdf_text_name("/perthousand"))
        0x8A => Some(pdf_text_name("/Scaron"))
        0x8B => Some(pdf_text_name("/guilsinglleft"))
        0x8C => Some(pdf_text_name("/OE"))
        0x8E => Some(pdf_text_name("/Zcaron"))
        0x91 => Some(pdf_text_name("/quoteleft"))
        0x92 => Some(pdf_text_name("/quoteright"))
        0x93 => Some(pdf_text_name("/quotedblleft"))
        0x94 => Some(pdf_text_name("/quotedblright"))
        0x95 => Some(pdf_text_name("/bullet"))
        0x96 => Some(pdf_text_name("/endash"))
        0x97 => Some(pdf_text_name("/emdash"))
        0x98 => Some(pdf_text_name("/tilde"))
        0x99 => Some(pdf_text_name("/trademark"))
        0x9A => Some(pdf_text_name("/scaron"))
        0x9B => Some(pdf_text_name("/guilsinglright"))
        0x9C => Some(pdf_text_name("/oe"))
        0x9E => Some(pdf_text_name("/zcaron"))
        0x9F => Some(pdf_text_name("/Ydieresis"))
        0xA9 => Some(pdf_text_name("/copyright"))
        0xE9 => Some(pdf_text_name("/eacute"))
        _ => None
      }
  }
}

///|
fn pdf_text_difference_glyphname(
  differences : ArrayView[PdfEncodingDifference],
  code : Int,
) -> PdfName? {
  let mut found : PdfName? = None
  for difference in differences {
    if difference.code == code {
      found = Some(difference.name)
    }
  }
  found
}

///|
fn PdfEncoding::pdf_text_glyphname_of_charcode(
  self : PdfEncoding,
  code : Int,
) -> PdfName? {
  match self {
    PdfImplicitInFontFile | PdfMacExpertEncoding => None
    PdfStandardEncoding => pdf_text_standard_glyphname(code)
    PdfMacRomanEncoding => pdf_text_macroman_glyphname(code)
    PdfWinAnsiEncoding => pdf_text_winansi_glyphname(code)
    PdfCustomEncoding(base, differences) =>
      match pdf_text_difference_glyphname(differences, code) {
        Some(name) => Some(name)
        None => base.pdf_text_glyphname_of_charcode(code)
      }
    PdfFillUndefinedWithStandard(base) =>
      match base.pdf_text_glyphname_of_charcode(code) {
        Some(name) => Some(name)
        None => PdfStandardEncoding.pdf_text_glyphname_of_charcode(code)
      }
  }
}

///|
fn pdf_text_codepoint_of_digit_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/zero" => Some(48)
    "/one" => Some(49)
    "/two" => Some(50)
    "/three" => Some(51)
    "/four" => Some(52)
    "/five" => Some(53)
    "/six" => Some(54)
    "/seven" => Some(55)
    "/eight" => Some(56)
    "/nine" => Some(57)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_punctuation_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/space" => Some(32)
    "/exclam" => Some(33)
    "/quotedbl" => Some(34)
    "/numbersign" => Some(35)
    "/dollar" => Some(36)
    "/percent" => Some(37)
    "/ampersand" => Some(38)
    "/quotesingle" => Some(39)
    "/quoteright" => Some(0x2019)
    "/parenleft" => Some(40)
    "/parenright" => Some(41)
    "/asterisk" => Some(42)
    "/plus" => Some(43)
    "/comma" => Some(44)
    "/hyphen" => Some(45)
    "/period" => Some(46)
    "/slash" => Some(47)
    "/colon" => Some(58)
    "/semicolon" => Some(59)
    "/less" => Some(60)
    "/equal" => Some(61)
    "/greater" => Some(62)
    "/question" => Some(63)
    "/at" => Some(64)
    "/bracketleft" => Some(91)
    "/backslash" => Some(92)
    "/bracketright" => Some(93)
    "/asciicircum" => Some(94)
    "/underscore" => Some(95)
    "/grave" => Some(96)
    "/quoteleft" => Some(0x2018)
    "/braceleft" => Some(123)
    "/bar" => Some(124)
    "/braceright" => Some(125)
    "/asciitilde" => Some(126)
    "/Euro" => Some(0x20AC)
    "/exclamdown" => Some(0x00A1)
    "/cent" => Some(0x00A2)
    "/sterling" => Some(0x00A3)
    "/fraction" => Some(0x2044)
    "/yen" => Some(0x00A5)
    "/section" => Some(0x00A7)
    "/currency" => Some(0x00A4)
    "/guillemotleft" => Some(0x00AB)
    "/guillemotright" => Some(0x00BB)
    "/fi" => Some(0xFB01)
    "/fl" => Some(0xFB02)
    "/periodcentered" => Some(0x00B7)
    "/paragraph" => Some(0x00B6)
    "/questiondown" => Some(0x00BF)
    "/Adieresis" => Some(0x00C4)
    "/Aring" => Some(0x00C5)
    "/Ccedilla" => Some(0x00C7)
    "/Eacute" => Some(0x00C9)
    "/Ntilde" => Some(0x00D1)
    "/Odieresis" => Some(0x00D6)
    "/Udieresis" => Some(0x00DC)
    "/aacute" => Some(0x00E1)
    "/agrave" => Some(0x00E0)
    "/acircumflex" => Some(0x00E2)
    "/adieresis" => Some(0x00E4)
    "/atilde" => Some(0x00E3)
    "/aring" => Some(0x00E5)
    "/ccedilla" => Some(0x00E7)
    "/egrave" => Some(0x00E8)
    "/ecircumflex" => Some(0x00EA)
    "/edieresis" => Some(0x00EB)
    "/quotesinglbase" => Some(0x201A)
    "/florin" => Some(0x0192)
    "/quotedblbase" => Some(0x201E)
    "/ellipsis" => Some(0x2026)
    "/dagger" => Some(0x2020)
    "/daggerdbl" => Some(0x2021)
    "/circumflex" => Some(0x02C6)
    "/perthousand" => Some(0x2030)
    "/Scaron" => Some(0x0160)
    "/guilsinglleft" => Some(0x2039)
    "/OE" => Some(0x0152)
    "/Zcaron" => Some(0x017D)
    "/quotedblleft" => Some(0x201C)
    "/quotedblright" => Some(0x201D)
    "/bullet" => Some(0x2022)
    "/endash" => Some(0x2013)
    "/emdash" => Some(0x2014)
    "/tilde" => Some(0x02DC)
    "/trademark" => Some(0x2122)
    "/scaron" => Some(0x0161)
    "/guilsinglright" => Some(0x203A)
    "/oe" => Some(0x0153)
    "/zcaron" => Some(0x017E)
    "/Ydieresis" => Some(0x0178)
    "/copyright" => Some(0x00A9)
    "/eacute" => Some(0x00E9)
    _ => None
  }
}

///|
fn pdf_text_glyphname_base_bytes(name : PdfName) -> BytesView {
  let bytes = name.bytes()
  let mut end = bytes.length()
  let mut index = 0
  while index < bytes.length() {
    if bytes[index].to_int() == 46 {
      end = index
      break
    }
    index += 1
  }
  bytes[:end]
}

///|
fn pdf_text_valid_unicode_scalar(codepoint : Int) -> Bool {
  codepoint >= 0 &&
  codepoint <= 0x10FFFF &&
  !(codepoint >= 0xD800 && codepoint <= 0xDFFF)
}

///|
fn pdf_text_parse_hex_codepoint(
  bytes : BytesView,
  start : Int,
  stop : Int,
) -> Int? {
  guard stop > start else { return None }
  let mut value = 0
  for index in start..<stop {
    match pdf_text_hex_digit_value(bytes[index]) {
      Some(digit) => value = value * 16 + digit
      None => return None
    }
  }
  if pdf_text_valid_unicode_scalar(value) {
    Some(value)
  } else {
    None
  }
}

///|
fn pdf_text_uni_glyphname_codepoints(base : BytesView) -> Array[Int]? {
  guard base.length() > 4 &&
    base[0].to_int() == 47 &&
    base[1].to_int() == 117 &&
    base[2].to_int() == 110 &&
    base[3].to_int() == 105 &&
    (base.length() - 4) % 4 == 0 else {
    return None
  }
  let output : Array[Int] = []
  let mut index = 4
  while index < base.length() {
    match pdf_text_parse_hex_codepoint(base, index, index + 4) {
      Some(codepoint) => output.push(codepoint)
      None => return None
    }
    index += 4
  }
  Some(output)
}

///|
fn pdf_text_u_glyphname_codepoints(base : BytesView) -> Array[Int]? {
  guard base.length() >= 6 &&
    base.length() <= 8 &&
    base[0].to_int() == 47 &&
    base[1].to_int() == 117 else {
    return None
  }
  match pdf_text_parse_hex_codepoint(base, 2, base.length()) {
    Some(codepoint) => Some([codepoint])
    None => None
  }
}

///|
fn pdf_text_glyphname_base_name(name : PdfName, base : BytesView) -> PdfName {
  if base.length() == name.byte_length() {
    name
  } else {
    pdf_name_of_bytes(base.to_owned())
  }
}

///|
fn pdf_text_codepoints_of_glyphname(name : PdfName) -> Array[Int]? {
  let base = pdf_text_glyphname_base_bytes(name)
  match pdf_text_uni_glyphname_codepoints(base) {
    Some(codepoints) => Some(codepoints)
    None =>
      match pdf_text_u_glyphname_codepoints(base) {
        Some(codepoints) => Some(codepoints)
        None =>
          if base.length() == 2 && base[0].to_int() == 47 {
            let value = base[1].to_int()
            if (value >= 65 && value <= 90) || (value >= 97 && value <= 122) {
              Some([value])
            } else {
              None
            }
          } else {
            let base_name = pdf_text_glyphname_base_name(name, base)
            match pdf_text_codepoint_of_digit_glyphname(base_name) {
              Some(codepoint) => Some([codepoint])
              None =>
                match pdf_text_codepoint_of_punctuation_glyphname(base_name) {
                  Some(codepoint) => Some([codepoint])
                  None => None
                }
            }
          }
      }
  }
}

///|
fn pdf_text_glyphname_has_single_codepoint(
  glyphname : PdfName,
  codepoint : Int,
) -> Bool {
  match pdf_text_codepoints_of_glyphname(glyphname) {
    Some([single]) if single == codepoint => true
    _ => false
  }
}

///|
fn PdfEncoding::pdf_text_charcode_of_codepoint(
  self : PdfEncoding,
  codepoint : Int,
) -> Int? {
  match self {
    PdfImplicitInFontFile | PdfMacExpertEncoding => None
    _ =>
      for code in 0..<256 {
        match self.pdf_text_glyphname_of_charcode(code) {
          Some(glyphname) if pdf_text_glyphname_has_single_codepoint(
              glyphname, codepoint,
            ) => break Some(code)
          _ => ()
        }
      } nobreak {
        None
      }
  }
}

///|
fn PdfFont::pdf_text_encoding(self : PdfFont) -> PdfEncoding {
  match self {
    PdfFontStandard(font) => font.encoding
    PdfFontSimple(font) => font.encoding
    PdfFontCIDKeyed(_) => PdfImplicitInFontFile
  }
}

///|
fn pdf_text_notdef_name() -> PdfName {
  pdf_text_name(".notdef")
}

///|
fn pdf_text_tounicode_glyphname(bytes : PdfBytes) -> PdfName {
  let output : Array[Byte] = [47]
  for byte in bytes {
    output.push(byte)
  }
  pdf_name_of_bytes(Bytes::from_array(output))
}

///|
fn PdfTextExtractor::pdf_text_encoded_glyph_of_charcode(
  self : PdfTextExtractor,
  code : Int,
) -> PdfTextGlyph {
  match self.font.pdf_text_encoding().pdf_text_glyphname_of_charcode(code) {
    Some(glyphname) =>
      match pdf_text_codepoints_of_glyphname(glyphname) {
        Some(codepoints) => { glyphname, codepoints }
        None => { glyphname, codepoints: [code] }
      }
    None => { glyphname: pdf_text_notdef_name(), codepoints: [code] }
  }
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
          try pdf_codepoints_of_utf16be(bytes[:]) catch {
            _ => { glyphname: pdf_text_notdef_name(), codepoints: [code] }
          } noraise {
            codepoints =>
              { glyphname: pdf_text_tounicode_glyphname(bytes), codepoints }
          }
        None => { glyphname: pdf_text_notdef_name(), codepoints: [code] }
      }
    None => self.pdf_text_encoded_glyph_of_charcode(code)
  }
}

///|
pub fn PdfTextExtractor::glyphnames_and_codepoints_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[PdfTextGlyph] raise PdfError {
  let output : Array[PdfTextGlyph] = []
  if self.font.is_identity_h() {
    guard text.length() % 2 == 0 else { raise BadText }
    let mut index = 0
    while index < text.length() {
      let code = (text[index].to_int() << 8) | text[index + 1].to_int()
      output.push(self.pdf_text_glyph_of_charcode(code))
      index += 2
    }
  } else {
    for byte in text {
      output.push(self.pdf_text_glyph_of_charcode(byte.to_int()))
    }
  }
  output
}

///|
pub fn PdfTextExtractor::codepoints_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[Int] raise PdfError {
  let output : Array[Int] = []
  for glyph in self.glyphnames_and_codepoints_of_text(text) {
    for codepoint in glyph.codepoints {
      output.push(codepoint)
    }
  }
  output
}

///|
pub fn PdfTextExtractor::glyphnames_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[PdfName] raise PdfError {
  [
    for glyph in self.glyphnames_and_codepoints_of_text(text) => glyph.glyphname
  ]
}

///|
pub fn PdfTextExtractor::charcode_of_codepoint(
  self : PdfTextExtractor,
  codepoint : Int,
) -> Int? {
  match self.font.pdf_text_tounicode() {
    Some(tounicode) =>
      for entry in tounicode {
        try pdf_codepoints_of_utf16be(entry.1[:]) catch {
          _ => ()
        } noraise {
          [single] if single == codepoint => break Some(entry.0)
          _ => ()
        }
      } nobreak {
        None
      }
    None =>
      self.font.pdf_text_encoding().pdf_text_charcode_of_codepoint(codepoint)
  }
}

///|
pub fn PdfDocument::write_encoding(
  self : PdfDocument,
  encoding : PdfEncoding,
) -> Int raise PdfError {
  match encoding {
    PdfCustomEncoding(PdfImplicitInFontFile, differences) => {
      let values : Array[PdfObject] = []
      for difference in differences {
        values.push(PdfInteger(difference.code))
        values.push(PdfNameObject(difference.name))
      }
      self.add_object(
        PdfDictionary([
          (pdf_text_name("/Type"), PdfNameObject(pdf_text_name("/Encoding"))),
          (pdf_text_name("/Differences"), PdfArray(values)),
        ]),
      )
    }
    _ => raise EncodingWriteUnsupported
  }
}

///|
pub fn pdf_make_font(
  fontname : PdfName,
  encoding : PdfEncoding,
) -> PdfObject raise PdfError {
  match encoding.pdf_name() {
    Some(encoding_name) =>
      PdfDictionary([
        (pdf_text_name("/Type"), PdfNameObject(pdf_text_name("/Font"))),
        (pdf_text_name("/Subtype"), PdfNameObject(pdf_text_name("/Type1"))),
        (pdf_text_name("/Encoding"), PdfNameObject(encoding_name)),
        (pdf_text_name("/BaseFont"), PdfNameObject(fontname)),
      ])
    None => raise EncodingWriteUnsupported
  }
}

///|
fn pdf_text_zero_rectangle_object() -> PdfObject {
  PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(0.0), PdfReal(0.0)])
}

///|
fn pdf_text_zero_font_matrix_object() -> PdfObject {
  PdfArray([
    PdfReal(0.0),
    PdfReal(0.0),
    PdfReal(0.0),
    PdfReal(0.0),
    PdfReal(0.0),
    PdfReal(0.0),
  ])
}

///|
fn pdf_text_type3_charprocs_object(
  charprocs : ArrayView[(PdfName, PdfObject)],
) -> PdfObject {
  PdfDictionary([ for entry in charprocs => (entry.0, PdfNull) ])
}

///|
fn PdfDocument::pdf_text_type3_encoding_entries(
  self : PdfDocument,
  encoding : PdfEncoding,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match encoding {
    PdfImplicitInFontFile => []
    _ =>
      [(pdf_text_name("/Encoding"), PdfIndirect(self.write_encoding(encoding)))]
  }
}

///|
fn PdfDocument::pdf_text_make_type3_font(
  self : PdfDocument,
  data : PdfType3Glyphs,
  encoding : PdfEncoding,
) -> PdfObject raise PdfError {
  PdfDictionary(
    [
      (pdf_text_name("/Type"), PdfNameObject(pdf_text_name("/Font"))),
      (pdf_text_name("/Subtype"), PdfNameObject(pdf_text_name("/Type3"))),
      (pdf_text_name("/FontBBox"), pdf_text_zero_rectangle_object()),
      (pdf_text_name("/FontMatrix"), pdf_text_zero_font_matrix_object()),
      (
        pdf_text_name("/CharProcs"),
        pdf_text_type3_charprocs_object(data.charprocs),
      ),
      (pdf_text_name("/FirstChar"), PdfInteger(0)),
      (pdf_text_name("/LastChar"), PdfInteger(0)),
      (pdf_text_name("/Widths"), PdfArray([PdfReal(0.0)])),
      ..self.pdf_text_type3_encoding_entries(encoding),
    ],
  )
}

///|
fn pdf_text_integer_of_double(value : Double) -> PdfObject {
  PdfInteger(value.to_int())
}

///|
fn pdf_text_font_descriptor_bbox_object(fontbbox : PdfRectangle) -> PdfObject {
  PdfArray([
    pdf_text_integer_of_double(fontbbox.min_x),
    pdf_text_integer_of_double(fontbbox.min_y),
    pdf_text_integer_of_double(fontbbox.max_x),
    pdf_text_integer_of_double(fontbbox.max_y),
  ])
}

///|
fn pdf_text_fontfile2_number(fontfile : PdfFontFile?) -> Int? {
  match fontfile {
    Some(PdfFontFile2(number)) => Some(number)
    _ => None
  }
}

///|
fn pdf_text_true_type_encoding_name(encoding : PdfEncoding) -> PdfName? {
  match encoding {
    PdfFillUndefinedWithStandard(base) => base.pdf_name()
    _ => encoding.pdf_name()
  }
}

///|
fn pdf_text_tounicode_preamble() -> String {
  "/CIDInit /ProcSet findresource begin\n" +
  "12 dict begin\n" +
  "begincmap\n" +
  "/CIDSystemInfo <<\n" +
  "  /Registry (Adobe)\n" +
  "  /Ordering (UCS)\n" +
  "  /Supplement 0\n" +
  ">> def\n" +
  "/CMapName /Adobe-Identity-UCS def\n" +
  "/CMapType 2 def\n" +
  "1 begincodespacerange\n" +
  "<00><FF>\n" +
  "endcodespacerange\n"
}

///|
fn pdf_text_tounicode_postamble() -> String {
  "endbfrange\n" +
  "endcmap\n" +
  "CMapName currentdict /CMap defineresource pop\n" +
  "end\n" +
  "end\n"
}

///|
fn pdf_text_tounicode_sorted(
  entries : ArrayView[(Int, PdfBytes)],
) -> Array[(Int, PdfBytes)] {
  let sorted = [ for entry in entries => entry ]
  sorted.sort_by(fn(left, right) { left.0.compare(right.0) })
  sorted
}

///|
fn pdf_text_hex_int_min2(value : Int) -> String {
  let text = value.to_string(radix=16)
  if text.length() == 1 {
    "0" + text
  } else {
    text
  }
}

///|
fn pdf_text_push_hex_bytes(output : Array[Byte], bytes : BytesView) -> Unit {
  for byte in bytes {
    let value = byte.to_int()
    output.push(pdf_writer_hex_digit(value / 16))
    output.push(pdf_writer_hex_digit(value % 16))
  }
}

///|
fn PdfDocument::pdf_text_write_tounicode(
  self : PdfDocument,
  entries : ArrayView[(Int, PdfBytes)],
) -> Int {
  let sorted = pdf_text_tounicode_sorted(entries)
  let output : Array[Byte] = []
  pdf_writer_push_ascii(output, pdf_text_tounicode_preamble())
  pdf_writer_push_ascii(output, sorted.length().to_string())
  pdf_writer_push_ascii(output, " beginbfrange\n")
  let mut charcode = 33
  for entry in sorted {
    pdf_writer_push_ascii(output, "<")
    pdf_writer_push_ascii(output, pdf_text_hex_int_min2(charcode))
    pdf_writer_push_ascii(output, "><")
    pdf_writer_push_ascii(output, pdf_text_hex_int_min2(charcode))
    pdf_writer_push_ascii(output, "><")
    pdf_text_push_hex_bytes(output, entry.1[:])
    pdf_writer_push_ascii(output, ">\n")
    charcode += 1
  }
  pdf_writer_push_ascii(output, pdf_text_tounicode_postamble())
  let bytes = Bytes::from_array(output)
  self.add_object(
    pdf_stream(
      PdfDictionary([(pdf_text_name("/Length"), PdfInteger(bytes.length()))]),
      StreamGot(bytes),
    ),
  )
}

///|
fn PdfDocument::pdf_text_make_true_type_font(
  self : PdfDocument,
  basefont : PdfName,
  firstchar : Int,
  lastchar : Int,
  widths : Array[Int],
  descriptor : PdfFontDescriptor,
  encoding : PdfEncoding,
) -> PdfObject raise PdfError {
  let ttf = match pdf_text_fontfile2_number(descriptor.fontfile) {
    Some(number) => number
    None => raise FontWriteUnsupported
  }
  let fontdescriptor = PdfDictionary([
    (pdf_text_name("/Type"), PdfNameObject(pdf_text_name("/FontDescriptor"))),
    (pdf_text_name("/FontName"), PdfNameObject(basefont)),
    (pdf_text_name("/Flags"), PdfInteger(descriptor.flags)),
    (
      pdf_text_name("/FontBBox"),
      pdf_text_font_descriptor_bbox_object(descriptor.fontbbox),
    ),
    (
      pdf_text_name("/ItalicAngle"),
      pdf_text_integer_of_double(descriptor.italicangle),
    ),
    (pdf_text_name("/Ascent"), pdf_text_integer_of_double(descriptor.ascent)),
    (pdf_text_name("/Descent"), pdf_text_integer_of_double(descriptor.descent)),
    (
      pdf_text_name("/CapHeight"),
      pdf_text_integer_of_double(descriptor.capheight),
    ),
    (pdf_text_name("/StemV"), pdf_text_integer_of_double(descriptor.stemv)),
    (pdf_text_name("/XHeight"), pdf_text_integer_of_double(descriptor.xheight)),
    (
      pdf_text_name("/AvgWidth"),
      pdf_text_integer_of_double(descriptor.avgwidth),
    ),
    (
      pdf_text_name("/MaxWidth"),
      pdf_text_integer_of_double(descriptor.maxwidth),
    ),
    (pdf_text_name("/FontFile2"), PdfIndirect(ttf)),
  ])
  let fontdescriptor_number = self.add_object(fontdescriptor)
  let tounicode_entry = match descriptor.tounicode {
    Some(tounicode) =>
      [
        (
          pdf_text_name("/ToUnicode"),
          PdfIndirect(self.pdf_text_write_tounicode(tounicode)),
        ),
      ]
    None => {
      let encoding_name = match pdf_text_true_type_encoding_name(encoding) {
        Some(name) => name
        None => raise EncodingWriteUnsupported
      }
      [(pdf_text_name("/Encoding"), PdfNameObject(encoding_name))]
    }
  }
  PdfDictionary(
    [
      (pdf_text_name("/Type"), PdfNameObject(pdf_text_name("/Font"))),
      (pdf_text_name("/Subtype"), PdfNameObject(pdf_text_name("/TrueType"))),
      (pdf_text_name("/BaseFont"), PdfNameObject(basefont)),
      (pdf_text_name("/FontDescriptor"), PdfIndirect(fontdescriptor_number)),
      (pdf_text_name("/FirstChar"), PdfInteger(firstchar)),
      (pdf_text_name("/LastChar"), PdfInteger(lastchar)),
      (
        pdf_text_name("/Widths"),
        PdfArray([ for width in widths => PdfInteger(width) ]),
      ),
      ..tounicode_entry,
    ],
  )
}

///|
fn PdfDocument::pdf_text_add_font_object(
  self : PdfDocument,
  object : PdfObject,
  objnum : Int?,
) -> Int {
  match objnum {
    Some(number) => {
      self.add_object_given_number(number, object)
      number
    }
    None => self.add_object(object)
  }
}

///|
pub fn PdfDocument::write_font(
  self : PdfDocument,
  font : PdfFont,
  objnum? : Int? = None,
) -> Int raise PdfError {
  match font {
    PdfFontStandard({ font, encoding }) =>
      self.pdf_text_add_font_object(
        pdf_make_font(font.pdf_name(), encoding),
        objnum,
      )
    PdfFontSimple({ fonttype: PdfType3(data), encoding, fontdescriptor, .. }) =>
      match fontdescriptor {
        Some(_) =>
          self.pdf_text_add_font_object(
            self.pdf_text_make_type3_font(data, encoding),
            objnum,
          )
        None => raise FontWriteUnsupported
      }
    PdfFontSimple(
      {
        fonttype: PdfTrueType,
        basefont: Some(basefont),
        firstchar,
        lastchar,
        widths,
        fontdescriptor: Some(descriptor),
        encoding,
        ..,
      }
    ) =>
      self.pdf_text_add_font_object(
        self.pdf_text_make_true_type_font(
          basefont, firstchar, lastchar, widths, descriptor, encoding,
        ),
        objnum,
      )
    _ => raise FontWriteUnsupported
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
