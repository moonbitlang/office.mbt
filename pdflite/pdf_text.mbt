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
  pdf_text_index_of_ascii(line, word) != None
}

///|
fn pdf_text_index_of_ascii(line : BytesView, word : String) -> Int? {
  let needle = @ascii.encode(word)
  guard needle.length() > 0 && line.length() >= needle.length() else {
    return None
  }
  for index in 0..<=(line.length() - needle.length()) {
    let mut matched = true
    for offset in 0..<needle.length() {
      if line[index + offset] != needle[offset] {
        matched = false
      }
    }
    if matched {
      break Some(index)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_after_ascii(line : BytesView, word : String) -> BytesView? {
  match pdf_text_index_of_ascii(line, word) {
    Some(index) => {
      let word_length = @ascii.encode(word).length()
      Some(line[index + word_length:])
    }
    None => None
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
fn pdf_text_tounicode_bfchar_entries_of_line(
  line : BytesView,
) -> Array[(Int, PdfBytes)]? {
  match pdf_text_parse_cmap_hex_groups(line) {
    Some(groups) if groups.length() % 2 == 0 => {
      let entries : Array[(Int, PdfBytes)] = []
      let mut index = 0
      while index < groups.length() {
        match pdf_text_bytes_to_int(groups[index][:]) {
          Some(code) => entries.push((code, groups[index + 1]))
          None => return None
        }
        index += 2
      }
      Some(entries)
    }
    _ => None
  }
}

///|
fn pdf_text_tounicode_bfrange_entries_of_line(
  line : BytesView,
) -> Array[(Int, PdfBytes)]? {
  match pdf_text_parse_cmap_hex_groups(line) {
    Some(groups) if groups.length() % 3 == 0 => {
      let entries : Array[(Int, PdfBytes)] = []
      let mut index = 0
      while index < groups.length() {
        match
          (
            pdf_text_bytes_to_int(groups[index][:]),
            pdf_text_bytes_to_int(groups[index + 1][:]),
          ) {
          (Some(first), Some(last)) if first <= last =>
            for code in first..<=last {
              match
                pdf_text_add_to_big_endian_bytes(
                  groups[index + 2],
                  code - first,
                ) {
                Some(bytes) => entries.push((code, bytes))
                None => return None
              }
            }
          _ => return None
        }
        index += 3
      }
      Some(entries)
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
  for raw_line in cursor.read_line_views() {
    let mut line = raw_line
    if pdf_text_line_contains_ascii(raw_line, "beginbfchar") {
      section = PdfTextCMapBFChar
      match pdf_text_after_ascii(raw_line, "beginbfchar") {
        Some(rest) => line = rest
        None => ()
      }
    } else if pdf_text_line_contains_ascii(raw_line, "beginbfrange") {
      section = PdfTextCMapBFRange
      match pdf_text_after_ascii(raw_line, "beginbfrange") {
        Some(rest) => line = rest
        None => ()
      }
    }
    let end_bfchar = pdf_text_line_contains_ascii(line, "endbfchar")
    let end_bfrange = pdf_text_line_contains_ascii(line, "endbfrange")
    match section {
      PdfTextCMapBFChar =>
        match pdf_text_tounicode_bfchar_entries_of_line(line) {
          Some(line_entries) =>
            for entry in line_entries {
              entries.push(entry)
            }
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
    if end_bfchar && section is PdfTextCMapBFChar {
      section = PdfTextCMapNone
    }
    if end_bfrange && section is PdfTextCMapBFRange {
      section = PdfTextCMapNone
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
        0xC1 => Some(pdf_text_name("/grave"))
        0xC2 => Some(pdf_text_name("/acute"))
        0xC3 => Some(pdf_text_name("/circumflex"))
        0xC4 => Some(pdf_text_name("/tilde"))
        0xC5 => Some(pdf_text_name("/macron"))
        0xC6 => Some(pdf_text_name("/breve"))
        0xC7 => Some(pdf_text_name("/dotaccent"))
        0xC8 => Some(pdf_text_name("/dieresis"))
        0xCA => Some(pdf_text_name("/ring"))
        0xCB => Some(pdf_text_name("/cedilla"))
        0xCD => Some(pdf_text_name("/hungarumlaut"))
        0xCE => Some(pdf_text_name("/ogonek"))
        0xCF => Some(pdf_text_name("/caron"))
        0xD0 => Some(pdf_text_name("/emdash"))
        0xE1 => Some(pdf_text_name("/AE"))
        0xE3 => Some(pdf_text_name("/ordfeminine"))
        0xE8 => Some(pdf_text_name("/Lslash"))
        0xE9 => Some(pdf_text_name("/Oslash"))
        0xEA => Some(pdf_text_name("/OE"))
        0xEB => Some(pdf_text_name("/ordmasculine"))
        0xF1 => Some(pdf_text_name("/ae"))
        0xF5 => Some(pdf_text_name("/dotlessi"))
        0xF8 => Some(pdf_text_name("/lslash"))
        0xFA => Some(pdf_text_name("/oe"))
        0xFB => Some(pdf_text_name("/germandbls"))
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
        0x92 => Some(pdf_text_name("/iacute"))
        0x93 => Some(pdf_text_name("/igrave"))
        0x94 => Some(pdf_text_name("/icircumflex"))
        0x95 => Some(pdf_text_name("/idieresis"))
        0x96 => Some(pdf_text_name("/ntilde"))
        0x97 => Some(pdf_text_name("/oacute"))
        0x98 => Some(pdf_text_name("/ograve"))
        0x99 => Some(pdf_text_name("/ocircumflex"))
        0x9A => Some(pdf_text_name("/odieresis"))
        0x9B => Some(pdf_text_name("/otilde"))
        0x9C => Some(pdf_text_name("/uacute"))
        0x9D => Some(pdf_text_name("/ugrave"))
        0x9E => Some(pdf_text_name("/ucircumflex"))
        0x9F => Some(pdf_text_name("/udieresis"))
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
        0xA1 => Some(pdf_text_name("/exclamdown"))
        0xA2 => Some(pdf_text_name("/cent"))
        0xA3 => Some(pdf_text_name("/sterling"))
        0xA4 => Some(pdf_text_name("/currency"))
        0xA5 => Some(pdf_text_name("/yen"))
        0xA6 => Some(pdf_text_name("/brokenbar"))
        0xA7 => Some(pdf_text_name("/section"))
        0xA8 => Some(pdf_text_name("/dieresis"))
        0xA9 => Some(pdf_text_name("/copyright"))
        0xAA => Some(pdf_text_name("/ordfeminine"))
        0xAB => Some(pdf_text_name("/guillemotleft"))
        0xAC => Some(pdf_text_name("/logicalnot"))
        0xAE => Some(pdf_text_name("/registered"))
        0xAF => Some(pdf_text_name("/macron"))
        0xB0 => Some(pdf_text_name("/degree"))
        0xB1 => Some(pdf_text_name("/plusminus"))
        0xB2 => Some(pdf_text_name("/twosuperior"))
        0xB3 => Some(pdf_text_name("/threesuperior"))
        0xB4 => Some(pdf_text_name("/acute"))
        0xB5 => Some(pdf_text_name("/mu"))
        0xB6 => Some(pdf_text_name("/paragraph"))
        0xB7 => Some(pdf_text_name("/periodcentered"))
        0xB8 => Some(pdf_text_name("/cedilla"))
        0xB9 => Some(pdf_text_name("/onesuperior"))
        0xBA => Some(pdf_text_name("/ordmasculine"))
        0xBB => Some(pdf_text_name("/guillemotright"))
        0xBC => Some(pdf_text_name("/onequarter"))
        0xBD => Some(pdf_text_name("/onehalf"))
        0xBE => Some(pdf_text_name("/threequarters"))
        0xBF => Some(pdf_text_name("/questiondown"))
        0xC0 => Some(pdf_text_name("/Agrave"))
        0xC1 => Some(pdf_text_name("/Aacute"))
        0xC2 => Some(pdf_text_name("/Acircumflex"))
        0xC3 => Some(pdf_text_name("/Atilde"))
        0xC4 => Some(pdf_text_name("/Adieresis"))
        0xC5 => Some(pdf_text_name("/Aring"))
        0xC6 => Some(pdf_text_name("/AE"))
        0xC7 => Some(pdf_text_name("/Ccedilla"))
        0xC8 => Some(pdf_text_name("/Egrave"))
        0xC9 => Some(pdf_text_name("/Eacute"))
        0xCA => Some(pdf_text_name("/Ecircumflex"))
        0xCB => Some(pdf_text_name("/Edieresis"))
        0xCC => Some(pdf_text_name("/Igrave"))
        0xCD => Some(pdf_text_name("/Iacute"))
        0xCE => Some(pdf_text_name("/Icircumflex"))
        0xCF => Some(pdf_text_name("/Idieresis"))
        0xD0 => Some(pdf_text_name("/Eth"))
        0xD1 => Some(pdf_text_name("/Ntilde"))
        0xD2 => Some(pdf_text_name("/Ograve"))
        0xD3 => Some(pdf_text_name("/Oacute"))
        0xD4 => Some(pdf_text_name("/Ocircumflex"))
        0xD5 => Some(pdf_text_name("/Otilde"))
        0xD6 => Some(pdf_text_name("/Odieresis"))
        0xD7 => Some(pdf_text_name("/multiply"))
        0xD8 => Some(pdf_text_name("/Oslash"))
        0xD9 => Some(pdf_text_name("/Ugrave"))
        0xDA => Some(pdf_text_name("/Uacute"))
        0xDB => Some(pdf_text_name("/Ucircumflex"))
        0xDC => Some(pdf_text_name("/Udieresis"))
        0xDD => Some(pdf_text_name("/Yacute"))
        0xDE => Some(pdf_text_name("/Thorn"))
        0xDF => Some(pdf_text_name("/germandbls"))
        0xE0 => Some(pdf_text_name("/agrave"))
        0xE1 => Some(pdf_text_name("/aacute"))
        0xE2 => Some(pdf_text_name("/acircumflex"))
        0xE3 => Some(pdf_text_name("/atilde"))
        0xE4 => Some(pdf_text_name("/adieresis"))
        0xE5 => Some(pdf_text_name("/aring"))
        0xE6 => Some(pdf_text_name("/ae"))
        0xE7 => Some(pdf_text_name("/ccedilla"))
        0xE8 => Some(pdf_text_name("/egrave"))
        0xE9 => Some(pdf_text_name("/eacute"))
        0xEA => Some(pdf_text_name("/ecircumflex"))
        0xEB => Some(pdf_text_name("/edieresis"))
        0xEC => Some(pdf_text_name("/igrave"))
        0xED => Some(pdf_text_name("/iacute"))
        0xEE => Some(pdf_text_name("/icircumflex"))
        0xEF => Some(pdf_text_name("/idieresis"))
        0xF0 => Some(pdf_text_name("/eth"))
        0xF1 => Some(pdf_text_name("/ntilde"))
        0xF2 => Some(pdf_text_name("/ograve"))
        0xF3 => Some(pdf_text_name("/oacute"))
        0xF4 => Some(pdf_text_name("/ocircumflex"))
        0xF5 => Some(pdf_text_name("/otilde"))
        0xF6 => Some(pdf_text_name("/odieresis"))
        0xF7 => Some(pdf_text_name("/divide"))
        0xF8 => Some(pdf_text_name("/oslash"))
        0xF9 => Some(pdf_text_name("/ugrave"))
        0xFA => Some(pdf_text_name("/uacute"))
        0xFB => Some(pdf_text_name("/ucircumflex"))
        0xFC => Some(pdf_text_name("/udieresis"))
        0xFD => Some(pdf_text_name("/yacute"))
        0xFE => Some(pdf_text_name("/thorn"))
        0xFF => Some(pdf_text_name("/ydieresis"))
        _ => None
      }
  }
}

///|
fn pdf_text_macexpert_glyphname(code : Int) -> PdfName? {
  match code {
    0x56 => Some(pdf_text_name("/ff"))
    0x57 => Some(pdf_text_name("/fi"))
    0x58 => Some(pdf_text_name("/fl"))
    0x59 => Some(pdf_text_name("/ffi"))
    0x5A => Some(pdf_text_name("/ffl"))
    _ => None
  }
}

///|
fn pdf_text_symbol_glyphname(code : Int) -> PdfName? {
  match code {
    0x20 => Some(pdf_text_name("/space"))
    0x21 => Some(pdf_text_name("/exclam"))
    0x22 => Some(pdf_text_name("/universal"))
    0x23 => Some(pdf_text_name("/numbersign"))
    0x24 => Some(pdf_text_name("/existential"))
    0x25 => Some(pdf_text_name("/percent"))
    0x26 => Some(pdf_text_name("/ampersand"))
    0x27 => Some(pdf_text_name("/suchthat"))
    0x28 => Some(pdf_text_name("/parenleft"))
    0x29 => Some(pdf_text_name("/parenright"))
    0x2A => Some(pdf_text_name("/asteriskmath"))
    0x2B => Some(pdf_text_name("/plus"))
    0x2C => Some(pdf_text_name("/comma"))
    0x2D => Some(pdf_text_name("/minus"))
    0x2E => Some(pdf_text_name("/period"))
    0x2F => Some(pdf_text_name("/slash"))
    0x30 => Some(pdf_text_name("/zero"))
    0x31 => Some(pdf_text_name("/one"))
    0x32 => Some(pdf_text_name("/two"))
    0x33 => Some(pdf_text_name("/three"))
    0x34 => Some(pdf_text_name("/four"))
    0x35 => Some(pdf_text_name("/five"))
    0x36 => Some(pdf_text_name("/six"))
    0x37 => Some(pdf_text_name("/seven"))
    0x38 => Some(pdf_text_name("/eight"))
    0x39 => Some(pdf_text_name("/nine"))
    0x3D => Some(pdf_text_name("/equal"))
    0x40 => Some(pdf_text_name("/congruent"))
    0x41 => Some(pdf_text_name("/Alpha"))
    0x42 => Some(pdf_text_name("/Beta"))
    0x43 => Some(pdf_text_name("/Chi"))
    0x44 => Some(pdf_text_name("/Delta"))
    0x45 => Some(pdf_text_name("/Epsilon"))
    0x46 => Some(pdf_text_name("/Phi"))
    0x47 => Some(pdf_text_name("/Gamma"))
    0x48 => Some(pdf_text_name("/Eta"))
    0x49 => Some(pdf_text_name("/Iota"))
    0x4B => Some(pdf_text_name("/Kappa"))
    0x4C => Some(pdf_text_name("/Lambda"))
    0x4D => Some(pdf_text_name("/Mu"))
    0x4E => Some(pdf_text_name("/Nu"))
    0x4F => Some(pdf_text_name("/Omicron"))
    0x50 => Some(pdf_text_name("/Pi"))
    0x51 => Some(pdf_text_name("/Theta"))
    0x52 => Some(pdf_text_name("/Rho"))
    0x53 => Some(pdf_text_name("/Sigma"))
    0x54 => Some(pdf_text_name("/Tau"))
    0x55 => Some(pdf_text_name("/Upsilon"))
    0x57 => Some(pdf_text_name("/Omega"))
    0x58 => Some(pdf_text_name("/Xi"))
    0x59 => Some(pdf_text_name("/Psi"))
    0x5A => Some(pdf_text_name("/Zeta"))
    0x5C => Some(pdf_text_name("/therefore"))
    0x5E => Some(pdf_text_name("/perpendicular"))
    0x61 => Some(pdf_text_name("/alpha"))
    0x62 => Some(pdf_text_name("/beta"))
    0x63 => Some(pdf_text_name("/chi"))
    0x64 => Some(pdf_text_name("/delta"))
    0x65 => Some(pdf_text_name("/epsilon"))
    0x66 => Some(pdf_text_name("/phi"))
    0x67 => Some(pdf_text_name("/gamma"))
    0x68 => Some(pdf_text_name("/eta"))
    0x69 => Some(pdf_text_name("/iota"))
    0x6B => Some(pdf_text_name("/kappa"))
    0x6C => Some(pdf_text_name("/lambda"))
    0x6D => Some(pdf_text_name("/mu"))
    0x6E => Some(pdf_text_name("/nu"))
    0x6F => Some(pdf_text_name("/omicron"))
    0x70 => Some(pdf_text_name("/pi"))
    0x71 => Some(pdf_text_name("/theta"))
    0x72 => Some(pdf_text_name("/rho"))
    0x73 => Some(pdf_text_name("/sigma"))
    0x74 => Some(pdf_text_name("/tau"))
    0x75 => Some(pdf_text_name("/upsilon"))
    0x76 => Some(pdf_text_name("/omega1"))
    0x77 => Some(pdf_text_name("/omega"))
    0x78 => Some(pdf_text_name("/xi"))
    0x79 => Some(pdf_text_name("/psi"))
    0x7A => Some(pdf_text_name("/zeta"))
    0x7E => Some(pdf_text_name("/similar"))
    0xA0 => Some(pdf_text_name("/Euro"))
    0xA1 => Some(pdf_text_name("/Upsilon1"))
    0xA3 => Some(pdf_text_name("/lessequal"))
    0xA5 => Some(pdf_text_name("/infinity"))
    0xA7 => Some(pdf_text_name("/club"))
    0xA8 => Some(pdf_text_name("/diamond"))
    0xA9 => Some(pdf_text_name("/heart"))
    0xAA => Some(pdf_text_name("/spade"))
    0xAB => Some(pdf_text_name("/arrowboth"))
    0xAC => Some(pdf_text_name("/arrowleft"))
    0xAD => Some(pdf_text_name("/arrowup"))
    0xAE => Some(pdf_text_name("/arrowright"))
    0xB0 => Some(pdf_text_name("/degree"))
    0xB1 => Some(pdf_text_name("/plusminus"))
    0xB2 => Some(pdf_text_name("/second"))
    0xB3 => Some(pdf_text_name("/greaterequal"))
    0xB4 => Some(pdf_text_name("/multiply"))
    0xB5 => Some(pdf_text_name("/proportional"))
    0xB6 => Some(pdf_text_name("/partialdiff"))
    0xB7 => Some(pdf_text_name("/bullet"))
    0xB8 => Some(pdf_text_name("/divide"))
    0xB9 => Some(pdf_text_name("/notequal"))
    0xBA => Some(pdf_text_name("/equivalence"))
    0xBB => Some(pdf_text_name("/approxequal"))
    0xBC => Some(pdf_text_name("/ellipsis"))
    0xC0 => Some(pdf_text_name("/aleph"))
    0xC1 => Some(pdf_text_name("/Ifraktur"))
    0xC2 => Some(pdf_text_name("/Rfraktur"))
    0xC3 => Some(pdf_text_name("/weierstrass"))
    0xC4 => Some(pdf_text_name("/circlemultiply"))
    0xC5 => Some(pdf_text_name("/circleplus"))
    0xC6 => Some(pdf_text_name("/emptyset"))
    0xC7 => Some(pdf_text_name("/intersection"))
    0xC8 => Some(pdf_text_name("/union"))
    0xC9 => Some(pdf_text_name("/propersuperset"))
    0xCA => Some(pdf_text_name("/reflexsuperset"))
    0xCB => Some(pdf_text_name("/notsubset"))
    0xCC => Some(pdf_text_name("/propersubset"))
    0xCD => Some(pdf_text_name("/reflexsubset"))
    0xCE => Some(pdf_text_name("/element"))
    0xCF => Some(pdf_text_name("/notelement"))
    0xD0 => Some(pdf_text_name("/angle"))
    0xD1 => Some(pdf_text_name("/gradient"))
    0xD5 => Some(pdf_text_name("/product"))
    0xD6 => Some(pdf_text_name("/radical"))
    0xD7 => Some(pdf_text_name("/dotmath"))
    0xD8 => Some(pdf_text_name("/logicalnot"))
    0xD9 => Some(pdf_text_name("/logicaland"))
    0xDA => Some(pdf_text_name("/logicalor"))
    0xDB => Some(pdf_text_name("/arrowdblboth"))
    0xDC => Some(pdf_text_name("/arrowdblleft"))
    0xDE => Some(pdf_text_name("/arrowdblright"))
    0xDF => Some(pdf_text_name("/arrowdbldown"))
    0xE0 => Some(pdf_text_name("/lozenge"))
    0xE5 => Some(pdf_text_name("/summation"))
    _ => None
  }
}

///|
fn pdf_text_zapfdingbats_glyphname(code : Int) -> PdfName? {
  match code {
    0x20 => Some(pdf_text_name("/space"))
    0x21 => Some(pdf_text_name("/a1"))
    0x22 => Some(pdf_text_name("/a2"))
    0x23 => Some(pdf_text_name("/a202"))
    0x24 => Some(pdf_text_name("/a3"))
    0x25 => Some(pdf_text_name("/a4"))
    0x26 => Some(pdf_text_name("/a5"))
    0x27 => Some(pdf_text_name("/a119"))
    0x28 => Some(pdf_text_name("/a118"))
    0x29 => Some(pdf_text_name("/a117"))
    0x2A => Some(pdf_text_name("/a11"))
    0x2B => Some(pdf_text_name("/a12"))
    0x2C => Some(pdf_text_name("/a13"))
    0x2D => Some(pdf_text_name("/a14"))
    0x2E => Some(pdf_text_name("/a15"))
    0x2F => Some(pdf_text_name("/a16"))
    0x30 => Some(pdf_text_name("/a105"))
    0x31 => Some(pdf_text_name("/a17"))
    0x32 => Some(pdf_text_name("/a18"))
    0x33 => Some(pdf_text_name("/a19"))
    0x34 => Some(pdf_text_name("/a20"))
    0x35 => Some(pdf_text_name("/a21"))
    0x36 => Some(pdf_text_name("/a22"))
    0x37 => Some(pdf_text_name("/a23"))
    0x38 => Some(pdf_text_name("/a24"))
    0x39 => Some(pdf_text_name("/a25"))
    0x3A => Some(pdf_text_name("/a26"))
    0x3B => Some(pdf_text_name("/a27"))
    0x3C => Some(pdf_text_name("/a28"))
    0x3D => Some(pdf_text_name("/a6"))
    0x3E => Some(pdf_text_name("/a7"))
    0x3F => Some(pdf_text_name("/a8"))
    0x40 => Some(pdf_text_name("/a9"))
    0x41 => Some(pdf_text_name("/a10"))
    0x42 => Some(pdf_text_name("/a29"))
    0x43 => Some(pdf_text_name("/a30"))
    0x44 => Some(pdf_text_name("/a31"))
    0x45 => Some(pdf_text_name("/a32"))
    0x46 => Some(pdf_text_name("/a33"))
    0x47 => Some(pdf_text_name("/a34"))
    0x48 => Some(pdf_text_name("/a35"))
    0x49 => Some(pdf_text_name("/a36"))
    0x4A => Some(pdf_text_name("/a37"))
    0x4B => Some(pdf_text_name("/a38"))
    0x4C => Some(pdf_text_name("/a39"))
    0x4D => Some(pdf_text_name("/a40"))
    0x4E => Some(pdf_text_name("/a41"))
    0x4F => Some(pdf_text_name("/a42"))
    0x50 => Some(pdf_text_name("/a43"))
    0x51 => Some(pdf_text_name("/a44"))
    0x52 => Some(pdf_text_name("/a45"))
    0x53 => Some(pdf_text_name("/a46"))
    0x54 => Some(pdf_text_name("/a47"))
    0x55 => Some(pdf_text_name("/a48"))
    0x56 => Some(pdf_text_name("/a49"))
    0x57 => Some(pdf_text_name("/a50"))
    0x58 => Some(pdf_text_name("/a51"))
    0x59 => Some(pdf_text_name("/a52"))
    0x5A => Some(pdf_text_name("/a53"))
    0xA1 => Some(pdf_text_name("/a101"))
    0xA2 => Some(pdf_text_name("/a102"))
    0xA3 => Some(pdf_text_name("/a103"))
    0xA4 => Some(pdf_text_name("/a104"))
    0xA5 => Some(pdf_text_name("/a106"))
    _ => None
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
    PdfImplicitInFontFile => None
    PdfStandardEncoding => pdf_text_standard_glyphname(code)
    PdfMacRomanEncoding => pdf_text_macroman_glyphname(code)
    PdfWinAnsiEncoding => pdf_text_winansi_glyphname(code)
    PdfMacExpertEncoding => pdf_text_macexpert_glyphname(code)
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
fn PdfStandardFontData::pdf_text_glyphname_of_charcode(
  self : PdfStandardFontData,
  code : Int,
) -> PdfName? {
  match self.encoding {
    PdfImplicitInFontFile =>
      match self.font {
        PdfSymbol => pdf_text_symbol_glyphname(code)
        PdfZapfDingbats => pdf_text_zapfdingbats_glyphname(code)
        _ => PdfStandardEncoding.pdf_text_glyphname_of_charcode(code)
      }
    _ => self.encoding.pdf_text_glyphname_of_charcode(code)
  }
}

///|
fn PdfFont::pdf_text_glyphname_of_charcode(
  self : PdfFont,
  code : Int,
) -> PdfName? {
  match self {
    PdfFontStandard(data) => data.pdf_text_glyphname_of_charcode(code)
    PdfFontSimple(font) => font.encoding.pdf_text_glyphname_of_charcode(code)
    PdfFontCIDKeyed(_) => None
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
    "/ff" => Some(0xFB00)
    "/fi" => Some(0xFB01)
    "/fl" => Some(0xFB02)
    "/ffi" => Some(0xFB03)
    "/ffl" => Some(0xFB04)
    "/periodcentered" => Some(0x00B7)
    "/paragraph" => Some(0x00B6)
    "/questiondown" => Some(0x00BF)
    "/Agrave" => Some(0x00C0)
    "/Aacute" => Some(0x00C1)
    "/Acircumflex" => Some(0x00C2)
    "/Atilde" => Some(0x00C3)
    "/AE" => Some(0x00C6)
    "/Egrave" => Some(0x00C8)
    "/Ecircumflex" => Some(0x00CA)
    "/Edieresis" => Some(0x00CB)
    "/Igrave" => Some(0x00CC)
    "/Iacute" => Some(0x00CD)
    "/Icircumflex" => Some(0x00CE)
    "/Idieresis" => Some(0x00CF)
    "/Eth" => Some(0x00D0)
    "/Ograve" => Some(0x00D2)
    "/Oacute" => Some(0x00D3)
    "/Ocircumflex" => Some(0x00D4)
    "/Otilde" => Some(0x00D5)
    "/Oslash" => Some(0x00D8)
    "/Ugrave" => Some(0x00D9)
    "/Uacute" => Some(0x00DA)
    "/Ucircumflex" => Some(0x00DB)
    "/Yacute" => Some(0x00DD)
    "/Thorn" => Some(0x00DE)
    "/germandbls" => Some(0x00DF)
    "/ae" => Some(0x00E6)
    "/eth" => Some(0x00F0)
    "/oslash" => Some(0x00F8)
    "/yacute" => Some(0x00FD)
    "/thorn" => Some(0x00FE)
    "/ydieresis" => Some(0x00FF)
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
    "/brokenbar" => Some(0x00A6)
    "/dieresis" => Some(0x00A8)
    "/ordfeminine" => Some(0x00AA)
    "/logicalnot" => Some(0x00AC)
    "/registered" => Some(0x00AE)
    "/macron" => Some(0x00AF)
    "/breve" => Some(0x02D8)
    "/dotaccent" => Some(0x02D9)
    "/ring" => Some(0x02DA)
    "/hungarumlaut" => Some(0x02DD)
    "/ogonek" => Some(0x02DB)
    "/caron" => Some(0x02C7)
    "/dotlessi" => Some(0x0131)
    "/Lslash" => Some(0x0141)
    "/lslash" => Some(0x0142)
    "/degree" => Some(0x00B0)
    "/twosuperior" => Some(0x00B2)
    "/threesuperior" => Some(0x00B3)
    "/acute" => Some(0x00B4)
    "/cedilla" => Some(0x00B8)
    "/onesuperior" => Some(0x00B9)
    "/ordmasculine" => Some(0x00BA)
    "/onequarter" => Some(0x00BC)
    "/onehalf" => Some(0x00BD)
    "/threequarters" => Some(0x00BE)
    "/iacute" => Some(0x00ED)
    "/igrave" => Some(0x00EC)
    "/icircumflex" => Some(0x00EE)
    "/idieresis" => Some(0x00EF)
    "/ntilde" => Some(0x00F1)
    "/oacute" => Some(0x00F3)
    "/ograve" => Some(0x00F2)
    "/ocircumflex" => Some(0x00F4)
    "/odieresis" => Some(0x00F6)
    "/otilde" => Some(0x00F5)
    "/uacute" => Some(0x00FA)
    "/ugrave" => Some(0x00F9)
    "/ucircumflex" => Some(0x00FB)
    "/udieresis" => Some(0x00FC)
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
fn pdf_text_codepoint_of_symbol_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Alpha" => Some(0x0391)
    "/Beta" => Some(0x0392)
    "/Gamma" => Some(0x0393)
    "/Delta" => Some(0x0394)
    "/Epsilon" => Some(0x0395)
    "/Zeta" => Some(0x0396)
    "/Eta" => Some(0x0397)
    "/Theta" => Some(0x0398)
    "/Iota" => Some(0x0399)
    "/Kappa" => Some(0x039A)
    "/Lambda" => Some(0x039B)
    "/Mu" => Some(0x039C)
    "/Nu" => Some(0x039D)
    "/Xi" => Some(0x039E)
    "/Omicron" => Some(0x039F)
    "/Pi" => Some(0x03A0)
    "/Rho" => Some(0x03A1)
    "/Sigma" => Some(0x03A3)
    "/Tau" => Some(0x03A4)
    "/Upsilon" | "/Upsilon1" => Some(0x03A5)
    "/Phi" => Some(0x03A6)
    "/Chi" => Some(0x03A7)
    "/Psi" => Some(0x03A8)
    "/Omega" => Some(0x03A9)
    "/alpha" => Some(0x03B1)
    "/beta" => Some(0x03B2)
    "/gamma" => Some(0x03B3)
    "/delta" => Some(0x03B4)
    "/epsilon" => Some(0x03B5)
    "/zeta" => Some(0x03B6)
    "/eta" => Some(0x03B7)
    "/theta" | "/theta1" => Some(0x03B8)
    "/iota" => Some(0x03B9)
    "/kappa" => Some(0x03BA)
    "/lambda" => Some(0x03BB)
    "/mu" => Some(0x03BC)
    "/nu" => Some(0x03BD)
    "/xi" => Some(0x03BE)
    "/omicron" => Some(0x03BF)
    "/pi" => Some(0x03C0)
    "/rho" => Some(0x03C1)
    "/sigma" | "/sigma1" => Some(0x03C3)
    "/tau" => Some(0x03C4)
    "/upsilon" => Some(0x03C5)
    "/phi" | "/phi1" => Some(0x03C6)
    "/chi" => Some(0x03C7)
    "/psi" => Some(0x03C8)
    "/omega" | "/omega1" => Some(0x03C9)
    "/universal" => Some(0x2200)
    "/existential" => Some(0x2203)
    "/suchthat" => Some(0x220B)
    "/congruent" => Some(0x2245)
    "/therefore" => Some(0x2234)
    "/perpendicular" => Some(0x22A5)
    "/similar" => Some(0x223C)
    "/aleph" => Some(0x2135)
    "/Ifraktur" => Some(0x2111)
    "/Rfraktur" => Some(0x211C)
    "/weierstrass" => Some(0x2118)
    "/circlemultiply" => Some(0x2297)
    "/circleplus" => Some(0x2295)
    "/emptyset" => Some(0x2205)
    "/intersection" => Some(0x2229)
    "/union" => Some(0x222A)
    "/propersuperset" => Some(0x2283)
    "/reflexsuperset" => Some(0x2287)
    "/notsubset" => Some(0x2284)
    "/propersubset" => Some(0x2282)
    "/reflexsubset" => Some(0x2286)
    "/element" => Some(0x2208)
    "/notelement" => Some(0x2209)
    "/angle" => Some(0x2220)
    "/gradient" => Some(0x2207)
    "/product" => Some(0x220F)
    "/dotmath" => Some(0x22C5)
    "/logicalnot" => Some(0x00AC)
    "/logicaland" => Some(0x2227)
    "/logicalor" => Some(0x2228)
    "/arrowdblboth" => Some(0x21D4)
    "/arrowdblleft" => Some(0x21D0)
    "/arrowdblright" => Some(0x21D2)
    "/arrowdbldown" => Some(0x21D3)
    "/lessequal" => Some(0x2264)
    "/infinity" => Some(0x221E)
    "/arrowboth" => Some(0x2194)
    "/arrowleft" => Some(0x2190)
    "/arrowup" => Some(0x2191)
    "/arrowright" => Some(0x2192)
    "/degree" => Some(0x00B0)
    "/plusminus" => Some(0x00B1)
    "/second" => Some(0x2033)
    "/greaterequal" => Some(0x2265)
    "/multiply" => Some(0x00D7)
    "/proportional" => Some(0x221D)
    "/partialdiff" => Some(0x2202)
    "/divide" => Some(0x00F7)
    "/notequal" => Some(0x2260)
    "/equivalence" => Some(0x2261)
    "/approxequal" => Some(0x2248)
    "/summation" => Some(0x2211)
    "/radical" => Some(0x221A)
    "/lozenge" => Some(0x25CA)
    "/spade" => Some(0x2660)
    "/club" => Some(0x2663)
    "/heart" => Some(0x2665)
    "/diamond" => Some(0x2666)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_dingbat_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/a1" => Some(0x2701)
    "/a2" => Some(0x2702)
    "/a202" => Some(0x2703)
    "/a3" => Some(0x2704)
    "/a4" => Some(0x260E)
    "/a5" => Some(0x2706)
    "/a119" => Some(0x2707)
    "/a118" => Some(0x2708)
    "/a117" => Some(0x2709)
    "/a11" => Some(0x261B)
    "/a12" => Some(0x261E)
    "/a13" => Some(0x270C)
    "/a14" => Some(0x270D)
    "/a15" => Some(0x270E)
    "/a16" => Some(0x270F)
    "/a105" => Some(0x2710)
    "/a17" => Some(0x2711)
    "/a18" => Some(0x2712)
    "/a19" => Some(0x2713)
    "/a20" => Some(0x2714)
    "/a21" => Some(0x2715)
    "/a22" => Some(0x2716)
    "/a23" => Some(0x2717)
    "/a24" => Some(0x2718)
    "/a25" => Some(0x2719)
    "/a26" => Some(0x271A)
    "/a27" => Some(0x271B)
    "/a28" => Some(0x271C)
    "/a6" => Some(0x271D)
    "/a7" => Some(0x271E)
    "/a8" => Some(0x271F)
    "/a9" => Some(0x2720)
    "/a10" => Some(0x2721)
    "/a29" => Some(0x2722)
    "/a30" => Some(0x2723)
    "/a31" => Some(0x2724)
    "/a32" => Some(0x2725)
    "/a33" => Some(0x2726)
    "/a34" => Some(0x2727)
    "/a35" => Some(0x2605)
    "/a36" => Some(0x2729)
    "/a37" => Some(0x272A)
    "/a38" => Some(0x272B)
    "/a39" => Some(0x272C)
    "/a40" => Some(0x272D)
    "/a41" => Some(0x272E)
    "/a42" => Some(0x272F)
    "/a43" => Some(0x2730)
    "/a44" => Some(0x2731)
    "/a45" => Some(0x2732)
    "/a46" => Some(0x2733)
    "/a47" => Some(0x2734)
    "/a48" => Some(0x2735)
    "/a49" => Some(0x2736)
    "/a50" => Some(0x2737)
    "/a51" => Some(0x2738)
    "/a52" => Some(0x2739)
    "/a53" => Some(0x273A)
    "/a101" => Some(0x2761)
    "/a102" => Some(0x2762)
    "/a103" => Some(0x2763)
    "/a104" => Some(0x2764)
    "/a106" => Some(0x2765)
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
                  None =>
                    match pdf_text_codepoint_of_symbol_glyphname(base_name) {
                      Some(codepoint) => Some([codepoint])
                      None =>
                        match
                          pdf_text_codepoint_of_dingbat_glyphname(base_name) {
                          Some(codepoint) => Some([codepoint])
                          None => None
                        }
                    }
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
  match self.font.pdf_text_glyphname_of_charcode(code) {
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
      for code in 0..<256 {
        match self.font.pdf_text_glyphname_of_charcode(code) {
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
