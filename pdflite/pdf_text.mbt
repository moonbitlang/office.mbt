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
  PdfExternalCMap(Int, PdfParsedCMap)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfCMapCodeSpace {
  length : Int
  first : Int
  last : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfParsedCMap {
  map : Array[(Int, PdfBytes)]
  cid_map : Array[(Int, Int)]
  notdef_map : Array[(Int, Int)]
  codespaces : Array[PdfCMapCodeSpace]
  usecmap : PdfName?
  wmode : Int?
  cmap_name : PdfName?
  cmap_type : Int?
  cid_system_info : PdfCIDSystemInfo?
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
pub fn PdfCMapEncoding::is_identity_v(self : PdfCMapEncoding) -> Bool {
  match self {
    PdfPredefinedCMap(name) => name == pdf_text_name("/Identity-V")
    _ => false
  }
}

///|
fn pdf_text_predefined_cmap_uses_two_byte_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  (
    (text.contains("-UCS2-") || text.contains("-UTF16-")) &&
    (text.has_suffix("-H") || text.has_suffix("-V"))
  ) ||
  pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(name)
}

///|
fn pdf_text_predefined_cmap_has_text_orientation(text : String) -> Bool {
  text == "/H" || text == "/V" || text.has_suffix("-H") || text.has_suffix("-V")
}

///|
fn pdf_text_predefined_cmap_is_vertical(name : PdfName) -> Bool {
  pdf_text_string_of_name(name).has_suffix("-V")
}

///|
fn pdf_text_predefined_cmap_uses_shift_jis_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("RKSJ")
}

///|
fn pdf_text_predefined_cmap_uses_hojo_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("Hojo-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
  name : PdfName,
) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  pdf_text_predefined_japan1_cid_ranges(name) is Some(_) &&
  !text.contains("RKSJ") &&
  !text.contains("EUC")
}

///|
fn pdf_text_predefined_cmap_uses_gb_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("GB-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_gbpc_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("GBpc-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_hkscs_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("HKscs-B5")
}

///|
fn pdf_text_predefined_cmap_uses_cns_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("CNS-EUC")
}

///|
fn pdf_text_predefined_cns_euc_cid_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  guard pdf_text_predefined_cmap_uses_cns_euc_charcodes(name) else {
    return None
  }
  if pdf_text_predefined_cmap_is_vertical(name) {
    Some(pdf_text_cns_euc_v_cid_ranges)
  } else {
    Some(pdf_text_cns_euc_h_cid_ranges)
  }
}

///|
fn pdf_text_predefined_cns1_b5_cid_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  let text = pdf_text_string_of_name(name)
  guard pdf_text_predefined_cmap_has_text_orientation(text) else { return None }
  if text.contains("ETenms-B5") {
    Some(pdf_text_etenms_b5_cid_ranges)
  } else if text.contains("HKdla-B5") {
    Some(pdf_text_hkdla_b5_cid_ranges)
  } else if text.contains("HKdlb-B5") {
    Some(pdf_text_hkdlb_b5_cid_ranges)
  } else if text.contains("HKgccs-B5") {
    Some(pdf_text_hkgccs_b5_cid_ranges)
  } else if text.contains("HKm314-B5") {
    Some(pdf_text_hkm314_b5_cid_ranges)
  } else if text.contains("HKm471-B5") {
    Some(pdf_text_hkm471_b5_cid_ranges)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_cmap_uses_cns1_b5_charcodes(name : PdfName) -> Bool {
  match pdf_text_predefined_cns1_b5_cid_ranges(name) {
    Some(_) => true
    None => false
  }
}

///|
fn pdf_text_predefined_cmap_uses_big5_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("B5")
}

///|
fn pdf_text_predefined_cmap_uses_b5pc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("B5pc")
}

///|
fn pdf_text_predefined_cmap_uses_uhc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("UHC")
}

///|
fn pdf_text_predefined_cmap_uses_ksc_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("KSC-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_kscpc_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("KSCpc-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_gbk2k_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("GBK2K")
}

///|
fn pdf_text_predefined_cmap_uses_gbk_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  (text.contains("GBK-EUC") || text.contains("GBKp-EUC"))
}

///|
fn pdf_text_predefined_cmap_uses_mixed_byte_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  (
    text.contains("-EUC-") ||
    text.has_prefix("/EUC-") ||
    text.contains("Hojo-EUC") ||
    text.contains("RKSJ") ||
    text.contains("B5") ||
    text.contains("UHC") ||
    text.contains("GBK")
  )
}

///|
fn pdf_text_predefined_rksj_single_byte_codepoint(code : Int) -> Int? {
  if code >= 0x00 && code <= 0x7F {
    Some(code)
  } else if code >= 0xA1 && code <= 0xDF {
    Some(0xFF61 + code - 0xA1)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_rksj_single_byte_charcode(codepoint : Int) -> Int? {
  if codepoint >= 0x00 && codepoint <= 0x7F {
    Some(codepoint)
  } else if codepoint >= 0xFF61 && codepoint <= 0xFF9F {
    Some(0xA1 + codepoint - 0xFF61)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_pair_table_lookup(
  table : Array[(Int, Int)],
  key : Int,
) -> Int? {
  let mut low = 0
  let mut high = table.length()
  while low < high {
    let mid = low + (high - low) / 2
    let entry = table[mid]
    if key < entry.0 {
      high = mid
    } else if key > entry.0 {
      low = mid + 1
    } else {
      return Some(entry.1)
    }
  }
  None
}

///|
fn pdf_text_predefined_pair_codepoints_table_lookup(
  table : Array[(Int, Array[Int])],
  key : Int,
) -> Array[Int]? {
  let mut low = 0
  let mut high = table.length()
  while low < high {
    let mid = low + (high - low) / 2
    let entry = table[mid]
    if key < entry.0 {
      high = mid
    } else if key > entry.0 {
      low = mid + 1
    } else {
      return Some(entry.1.copy())
    }
  }
  None
}

///|
fn pdf_text_predefined_japan1_direct_codepoint_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  let text = pdf_text_string_of_name(name)
  if text == "/90ms-RKSJ-H" {
    Some(pdf_text_japan1_90ms_rksj_codepoint_ranges)
  } else if text == "/90pv-RKSJ-H" {
    Some(pdf_text_japan1_90pv_rksj_codepoint_ranges)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_japan1_direct_codepoint_sequence_table(
  name : PdfName,
) -> Array[(Int, Array[Int])] {
  let text = pdf_text_string_of_name(name)
  if text == "/90pv-RKSJ-H" {
    pdf_text_japan1_90pv_rksj_codepoint_sequence_table
  } else {
    pdf_text_japan1_90ms_rksj_codepoint_sequence_table
  }
}

///|
fn pdf_text_predefined_japan1_direct_charcode_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  let text = pdf_text_string_of_name(name)
  if text == "/90ms-RKSJ-H" {
    Some(pdf_text_japan1_90ms_rksj_charcode_ranges)
  } else if text == "/90pv-RKSJ-H" {
    Some(pdf_text_japan1_90pv_rksj_charcode_ranges)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_japan1_cid_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  let text = pdf_text_string_of_name(name)
  guard pdf_text_predefined_cmap_has_text_orientation(text) else { return None }
  if text == "/H" {
    Some(pdf_text_japan1_h_cid_ranges)
  } else if text == "/V" {
    Some(pdf_text_japan1_v_cid_ranges)
  } else if text == "/78-H" {
    Some(pdf_text_japan1_78_h_cid_ranges)
  } else if text == "/78-V" {
    Some(pdf_text_japan1_78_v_cid_ranges)
  } else if text == "/78-EUC-H" {
    Some(pdf_text_japan1_78_euc_h_cid_ranges)
  } else if text == "/78-EUC-V" {
    Some(pdf_text_japan1_78_euc_v_cid_ranges)
  } else if text == "/78-RKSJ-H" {
    Some(pdf_text_japan1_78_rksj_h_cid_ranges)
  } else if text == "/78-RKSJ-V" {
    Some(pdf_text_japan1_78_rksj_v_cid_ranges)
  } else if text == "/78ms-RKSJ-H" {
    Some(pdf_text_japan1_78ms_rksj_h_cid_ranges)
  } else if text == "/78ms-RKSJ-V" {
    Some(pdf_text_japan1_78ms_rksj_v_cid_ranges)
  } else if text == "/83pv-RKSJ-H" {
    Some(pdf_text_japan1_83pv_rksj_h_cid_ranges)
  } else if text == "/90ms-RKSJ-H" {
    Some(pdf_text_japan1_90ms_rksj_h_cid_ranges)
  } else if text == "/90ms-RKSJ-V" {
    Some(pdf_text_japan1_90ms_rksj_v_cid_ranges)
  } else if text == "/90msp-RKSJ-H" {
    Some(pdf_text_japan1_90msp_rksj_h_cid_ranges)
  } else if text == "/90msp-RKSJ-V" {
    Some(pdf_text_japan1_90msp_rksj_v_cid_ranges)
  } else if text == "/90pv-RKSJ-H" {
    Some(pdf_text_japan1_90pv_rksj_h_cid_ranges)
  } else if text == "/90pv-RKSJ-V" {
    Some(pdf_text_japan1_90pv_rksj_v_cid_ranges)
  } else if text == "/Add-H" {
    Some(pdf_text_japan1_add_h_cid_ranges)
  } else if text == "/Add-V" {
    Some(pdf_text_japan1_add_v_cid_ranges)
  } else if text == "/Add-RKSJ-H" {
    Some(pdf_text_japan1_add_rksj_h_cid_ranges)
  } else if text == "/Add-RKSJ-V" {
    Some(pdf_text_japan1_add_rksj_v_cid_ranges)
  } else if text == "/EUC-H" {
    Some(pdf_text_japan1_euc_h_cid_ranges)
  } else if text == "/EUC-V" {
    Some(pdf_text_japan1_euc_v_cid_ranges)
  } else if text == "/Ext-H" {
    Some(pdf_text_japan1_ext_h_cid_ranges)
  } else if text == "/Ext-V" {
    Some(pdf_text_japan1_ext_v_cid_ranges)
  } else if text == "/Ext-RKSJ-H" {
    Some(pdf_text_japan1_ext_rksj_h_cid_ranges)
  } else if text == "/Ext-RKSJ-V" {
    Some(pdf_text_japan1_ext_rksj_v_cid_ranges)
  } else if text == "/Hojo-H" {
    Some(pdf_text_japan1_hojo_h_cid_ranges)
  } else if text == "/Hojo-V" {
    Some(pdf_text_japan1_hojo_v_cid_ranges)
  } else if text == "/Hojo-EUC-H" {
    Some(pdf_text_japan1_hojo_euc_h_cid_ranges)
  } else if text == "/Hojo-EUC-V" {
    Some(pdf_text_japan1_hojo_euc_v_cid_ranges)
  } else if text == "/NWP-H" {
    Some(pdf_text_japan1_nwp_h_cid_ranges)
  } else if text == "/NWP-V" {
    Some(pdf_text_japan1_nwp_v_cid_ranges)
  } else if text == "/RKSJ-H" {
    Some(pdf_text_japan1_rksj_h_cid_ranges)
  } else if text == "/RKSJ-V" {
    Some(pdf_text_japan1_rksj_v_cid_ranges)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_gb1_vertical_codepoint_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("GBK2K") {
    Some(pdf_text_gbk2k_vertical_codepoint_table)
  } else if text.contains("GBpc-EUC") {
    Some(pdf_text_gbpc_euc_vertical_codepoint_table)
  } else if text.contains("GBK-EUC") {
    Some(pdf_text_gbk_vertical_codepoint_table)
  } else if text.contains("GBKp-EUC") {
    Some(pdf_text_gbkp_vertical_codepoint_table)
  } else if text.contains("GB-EUC") {
    Some(pdf_text_gb_euc_vertical_codepoint_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_gb1_vertical_charcode_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("GBK2K") {
    Some(pdf_text_gbk2k_vertical_charcode_table)
  } else if text.contains("GBpc-EUC") {
    Some(pdf_text_gbpc_euc_vertical_charcode_table)
  } else if text.contains("GBK-EUC") {
    Some(pdf_text_gbk_vertical_charcode_table)
  } else if text.contains("GBKp-EUC") {
    Some(pdf_text_gbkp_vertical_charcode_table)
  } else if text.contains("GB-EUC") {
    Some(pdf_text_gb_euc_vertical_charcode_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_cns1_vertical_codepoint_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("ETenms-B5") {
    Some(pdf_text_etenms_b5_vertical_codepoint_table)
  } else if text.contains("HKscs-B5") {
    Some(pdf_text_hkscs_vertical_codepoint_table)
  } else if text.contains("HKdla-B5") {
    Some(pdf_text_hkdla_b5_vertical_codepoint_table)
  } else if text.contains("HKdlb-B5") {
    Some(pdf_text_hkdlb_b5_vertical_codepoint_table)
  } else if text.contains("HKgccs-B5") {
    Some(pdf_text_hkgccs_b5_vertical_codepoint_table)
  } else if text.contains("HKm314-B5") {
    Some(pdf_text_hkm314_b5_vertical_codepoint_table)
  } else if text.contains("HKm471-B5") {
    Some(pdf_text_hkm471_b5_vertical_codepoint_table)
  } else if text.contains("B5pc") {
    Some(pdf_text_b5pc_vertical_codepoint_table)
  } else if text.contains("ETen-B5") {
    Some(pdf_text_eten_b5_vertical_codepoint_table)
  } else if text.contains("B5") {
    Some(pdf_text_big5_vertical_codepoint_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_cns1_vertical_charcode_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("ETenms-B5") {
    Some(pdf_text_etenms_b5_vertical_charcode_table)
  } else if text.contains("HKscs-B5") {
    Some(pdf_text_hkscs_vertical_charcode_table)
  } else if text.contains("HKdla-B5") {
    Some(pdf_text_hkdla_b5_vertical_charcode_table)
  } else if text.contains("HKdlb-B5") {
    Some(pdf_text_hkdlb_b5_vertical_charcode_table)
  } else if text.contains("HKgccs-B5") {
    Some(pdf_text_hkgccs_b5_vertical_charcode_table)
  } else if text.contains("HKm314-B5") {
    Some(pdf_text_hkm314_b5_vertical_charcode_table)
  } else if text.contains("HKm471-B5") {
    Some(pdf_text_hkm471_b5_vertical_charcode_table)
  } else if text.contains("B5pc") {
    Some(pdf_text_b5pc_vertical_charcode_table)
  } else if text.contains("ETen-B5") {
    Some(pdf_text_eten_b5_vertical_charcode_table)
  } else if text.contains("B5") {
    Some(pdf_text_big5_vertical_charcode_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_korea1_vertical_codepoint_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("UHC") {
    Some(pdf_text_uhc_vertical_codepoint_table)
  } else if text.contains("KSCpc-EUC") {
    Some(pdf_text_kscpc_euc_vertical_codepoint_table)
  } else if text.contains("KSC-EUC") {
    Some(pdf_text_ksc_euc_vertical_codepoint_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_korea1_vertical_charcode_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("UHC") {
    Some(pdf_text_uhc_vertical_charcode_table)
  } else if text.contains("KSCpc-EUC") {
    Some(pdf_text_kscpc_euc_vertical_charcode_table)
  } else if text.contains("KSC-EUC") {
    Some(pdf_text_ksc_euc_vertical_charcode_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_vertical_codepoint(
  table : Array[(Int, Int)]?,
  code : Int,
) -> Int? {
  match table {
    Some(table) => pdf_text_predefined_pair_table_lookup(table, code)
    None => None
  }
}

///|
fn pdf_text_predefined_vertical_charcode(
  table : Array[(Int, Int)]?,
  codepoint : Int,
) -> Int? {
  match table {
    Some(table) => pdf_text_predefined_pair_table_lookup(table, codepoint)
    None => None
  }
}

///|
fn pdf_text_predefined_cid_range_lookup(
  ranges : Array[(Int, Int, Int)],
  code : Int,
) -> Int? {
  let mut low = 0
  let mut high = ranges.length()
  while low < high {
    let mid = low + (high - low) / 2
    let entry = ranges[mid]
    if code < entry.0 {
      high = mid
    } else if code > entry.1 {
      low = mid + 1
    } else {
      return Some(entry.2 + code - entry.0)
    }
  }
  None
}

///|
fn pdf_text_japan1_codepoints_of_cid(cid : Int) -> Array[Int]? {
  match
    pdf_text_predefined_cid_range_lookup(pdf_text_japan1_codepoint_ranges, cid) {
    Some(codepoint) => Some([codepoint])
    None =>
      pdf_text_predefined_pair_codepoints_table_lookup(
        pdf_text_japan1_codepoint_sequence_table, cid,
      )
  }
}

///|
fn pdf_text_predefined_japan1_codepoints(
  ranges : Array[(Int, Int, Int)],
  code : Int,
) -> Array[Int]? {
  match pdf_text_predefined_cid_range_lookup(ranges, code) {
    Some(cid) => pdf_text_japan1_codepoints_of_cid(cid)
    None => None
  }
}

///|
fn pdf_text_predefined_japan1_charcode(
  ranges : Array[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  for range in ranges {
    for code in range.0..<=range.1 {
      match pdf_text_japan1_codepoints_of_cid(range.2 + code - range.0) {
        Some([candidate]) if candidate == codepoint => return Some(code)
        _ => ()
      }
    }
  }
  None
}

///|
fn pdf_text_predefined_japan1_builtin_codepoints(
  name : PdfName,
  code : Int,
) -> Array[Int]? {
  match pdf_text_predefined_japan1_direct_codepoint_ranges(name) {
    Some(ranges) =>
      match pdf_text_predefined_cid_range_lookup(ranges, code) {
        Some(codepoint) => Some([codepoint])
        None =>
          pdf_text_predefined_pair_codepoints_table_lookup(
            pdf_text_predefined_japan1_direct_codepoint_sequence_table(name),
            code,
          )
      }
    None =>
      match pdf_text_predefined_japan1_cid_ranges(name) {
        Some(ranges) => pdf_text_predefined_japan1_codepoints(ranges, code)
        None => None
      }
  }
}

///|
fn pdf_text_predefined_japan1_builtin_charcode(
  name : PdfName,
  codepoint : Int,
) -> Int? {
  match pdf_text_predefined_japan1_direct_charcode_ranges(name) {
    Some(ranges) => pdf_text_predefined_cid_range_lookup(ranges, codepoint)
    None =>
      match pdf_text_predefined_japan1_cid_ranges(name) {
        Some(ranges) => pdf_text_predefined_japan1_charcode(ranges, codepoint)
        None => None
      }
  }
}

///|
fn pdf_text_cns1_codepoint_of_cid(cid : Int) -> Int? {
  guard cid >= 0 && cid < pdf_text_cns1_unicode_table.length() else {
    return None
  }
  let codepoint = pdf_text_cns1_unicode_table[cid]
  if codepoint == 0 {
    None
  } else {
    Some(codepoint)
  }
}

///|
fn pdf_text_gb1_codepoint_of_cid(cid : Int) -> Int? {
  guard cid >= 0 && cid < pdf_text_gb1_unicode_table.length() else {
    return None
  }
  let codepoint = pdf_text_gb1_unicode_table[cid]
  if codepoint == 0 {
    None
  } else {
    Some(codepoint)
  }
}

///|
fn pdf_text_predefined_cns1_codepoint(
  ranges : Array[(Int, Int, Int)],
  code : Int,
) -> Int? {
  match pdf_text_predefined_cid_range_lookup(ranges, code) {
    Some(cid) => pdf_text_cns1_codepoint_of_cid(cid)
    None => None
  }
}

///|
fn pdf_text_predefined_cns1_codepoint_linear(
  ranges : Array[(Int, Int, Int)],
  code : Int,
) -> Int? {
  for range in ranges {
    if code >= range.0 && code <= range.1 {
      return pdf_text_cns1_codepoint_of_cid(range.2 + code - range.0)
    }
  }
  None
}

///|
fn pdf_text_predefined_cns1_charcode(
  ranges : Array[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  for range in ranges {
    for code in range.0..<=range.1 {
      match pdf_text_cns1_codepoint_of_cid(range.2 + code - range.0) {
        Some(candidate) if candidate == codepoint => return Some(code)
        _ => ()
      }
    }
  }
  None
}

///|
fn pdf_text_predefined_cns1_builtin_codepoints(
  name : PdfName,
  code : Int,
) -> Array[Int]? {
  match
    pdf_text_predefined_vertical_codepoint(
      pdf_text_predefined_cns1_vertical_codepoint_table(name),
      code,
    ) {
    Some(codepoint) => Some([codepoint])
    None =>
      match pdf_text_predefined_cns1_b5_cid_ranges(name) {
        Some(ranges) =>
          match pdf_text_predefined_cns1_codepoint(ranges, code) {
            Some(codepoint) => Some([codepoint])
            None => None
          }
        None =>
          if pdf_text_predefined_cmap_uses_hkscs_charcodes(name) {
            match pdf_text_predefined_hkscs_codepoint(code) {
              Some(codepoint) => Some([codepoint])
              None => None
            }
          } else {
            match pdf_text_predefined_cns_euc_cid_ranges(name) {
              Some(ranges) =>
                match pdf_text_predefined_cns1_codepoint_linear(ranges, code) {
                  Some(codepoint) => Some([codepoint])
                  None => None
                }
              None =>
                if pdf_text_predefined_cmap_uses_b5pc_charcodes(name) {
                  match pdf_text_predefined_b5pc_codepoint(code) {
                    Some(codepoint) => Some([codepoint])
                    None => None
                  }
                } else if pdf_text_predefined_cmap_uses_big5_charcodes(name) {
                  match pdf_text_predefined_big5_codepoint(code) {
                    Some(codepoint) => Some([codepoint])
                    None => None
                  }
                } else {
                  None
                }
            }
          }
      }
  }
}

///|
fn pdf_text_predefined_cns1_builtin_charcode(
  name : PdfName,
  codepoint : Int,
) -> Int? {
  match
    pdf_text_predefined_vertical_charcode(
      pdf_text_predefined_cns1_vertical_charcode_table(name),
      codepoint,
    ) {
    Some(code) => Some(code)
    None =>
      match pdf_text_predefined_cns1_b5_cid_ranges(name) {
        Some(ranges) => pdf_text_predefined_cns1_charcode(ranges, codepoint)
        None =>
          if pdf_text_predefined_cmap_uses_hkscs_charcodes(name) {
            pdf_text_predefined_hkscs_charcode(codepoint)
          } else {
            match pdf_text_predefined_cns_euc_cid_ranges(name) {
              Some(ranges) =>
                pdf_text_predefined_cns1_charcode(ranges, codepoint)
              None =>
                if pdf_text_predefined_cmap_uses_b5pc_charcodes(name) {
                  pdf_text_predefined_b5pc_charcode(codepoint)
                } else if pdf_text_predefined_cmap_uses_big5_charcodes(name) {
                  pdf_text_predefined_big5_charcode(codepoint)
                } else {
                  None
                }
            }
          }
      }
  }
}

///|
fn pdf_text_predefined_gb1_codepoint(
  ranges : Array[(Int, Int, Int)],
  code : Int,
) -> Int? {
  match pdf_text_predefined_cid_range_lookup(ranges, code) {
    Some(cid) => pdf_text_gb1_codepoint_of_cid(cid)
    None => None
  }
}

///|
fn pdf_text_predefined_gb1_charcode(
  ranges : Array[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  let mut found : Int? = None
  for range in ranges {
    for code in range.0..<=range.1 {
      match pdf_text_gb1_codepoint_of_cid(range.2 + code - range.0) {
        Some(candidate) if candidate == codepoint =>
          match found {
            Some(current) =>
              if code.reinterpret_as_uint() < current.reinterpret_as_uint() {
                found = Some(code)
              }
            None => found = Some(code)
          }
        _ => ()
      }
    }
  }
  found
}

///|
fn pdf_text_predefined_gbk2k_codepoint(code : Int) -> Int? {
  pdf_text_predefined_gb1_codepoint(pdf_text_gbk2k_cid_ranges, code)
}

///|
fn pdf_text_predefined_gbk2k_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_gb1_charcode(pdf_text_gbk2k_cid_ranges, codepoint)
}

///|
fn pdf_text_predefined_gb_euc_codepoint(code : Int) -> Int? {
  if code >= 0x00 && code <= 0x7F {
    Some(code)
  } else {
    pdf_text_predefined_pair_table_lookup(pdf_text_gb_euc_codepoint_table, code)
  }
}

///|
fn pdf_text_predefined_gb_euc_charcode(codepoint : Int) -> Int? {
  if codepoint >= 0x00 && codepoint <= 0x7F {
    Some(codepoint)
  } else {
    pdf_text_predefined_pair_table_lookup(
      pdf_text_gb_euc_charcode_table, codepoint,
    )
  }
}

///|
fn pdf_text_predefined_gbpc_euc_codepoints(code : Int) -> Array[Int]? {
  pdf_text_predefined_pair_codepoints_table_lookup(
    pdf_text_gbpc_euc_codepoints_table, code,
  )
}

///|
fn pdf_text_predefined_gbpc_euc_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(
    pdf_text_gbpc_euc_charcode_table, codepoint,
  )
}

///|
fn pdf_text_predefined_big5_codepoint(code : Int) -> Int? {
  if code >= 0x00 && code <= 0x7F {
    Some(code)
  } else {
    pdf_text_predefined_pair_table_lookup(pdf_text_big5_codepoint_table, code)
  }
}

///|
fn pdf_text_predefined_big5_charcode(codepoint : Int) -> Int? {
  if codepoint >= 0x00 && codepoint <= 0x7F {
    Some(codepoint)
  } else {
    pdf_text_predefined_pair_table_lookup(
      pdf_text_big5_charcode_table, codepoint,
    )
  }
}

///|
fn pdf_text_predefined_b5pc_codepoint(code : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(pdf_text_b5pc_codepoint_table, code)
}

///|
fn pdf_text_predefined_b5pc_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(pdf_text_b5pc_charcode_table, codepoint)
}

///|
fn pdf_text_predefined_hkscs_codepoint(code : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(pdf_text_hkscs_codepoint_table, code)
}

///|
fn pdf_text_predefined_hkscs_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(
    pdf_text_hkscs_charcode_table, codepoint,
  )
}

///|
fn pdf_text_predefined_uhc_codepoint(code : Int) -> Int? {
  if code >= 0x00 && code <= 0x7F {
    Some(code)
  } else {
    pdf_text_predefined_pair_table_lookup(pdf_text_uhc_codepoint_table, code)
  }
}

///|
fn pdf_text_predefined_uhc_charcode(codepoint : Int) -> Int? {
  if codepoint >= 0x00 && codepoint <= 0x7F {
    Some(codepoint)
  } else {
    pdf_text_predefined_pair_table_lookup(
      pdf_text_uhc_charcode_table, codepoint,
    )
  }
}

///|
fn pdf_text_predefined_ksc_euc_codepoint(code : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(pdf_text_ksc_euc_codepoint_table, code)
}

///|
fn pdf_text_predefined_ksc_euc_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(
    pdf_text_ksc_euc_charcode_table, codepoint,
  )
}

///|
fn pdf_text_predefined_kscpc_euc_codepoints(code : Int) -> Array[Int]? {
  pdf_text_predefined_pair_codepoints_table_lookup(
    pdf_text_kscpc_euc_codepoints_table, code,
  )
}

///|
fn pdf_text_predefined_kscpc_euc_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(
    pdf_text_kscpc_euc_charcode_table, codepoint,
  )
}

///|
fn pdf_text_predefined_gbk_codepoint(code : Int) -> Int? {
  if code >= 0x00 && code <= 0x80 {
    Some(code)
  } else if code == 0xFF {
    Some(0xF8F5)
  } else {
    pdf_text_predefined_pair_table_lookup(pdf_text_gbk_codepoint_table, code)
  }
}

///|
fn pdf_text_predefined_gbk_charcode(codepoint : Int) -> Int? {
  if codepoint >= 0x00 && codepoint <= 0x80 {
    Some(codepoint)
  } else if codepoint == 0xF8F5 {
    Some(0xFF)
  } else {
    pdf_text_predefined_pair_table_lookup(
      pdf_text_gbk_charcode_table, codepoint,
    )
  }
}

///|
pub fn PdfCMapEncoding::uses_two_byte_codes(self : PdfCMapEncoding) -> Bool {
  match self {
    PdfPredefinedCMap(name) =>
      self.is_identity_h() ||
      self.is_identity_v() ||
      pdf_text_predefined_cmap_uses_two_byte_charcodes(name)
    PdfExternalCMap(_, parsed) =>
      if parsed.codespaces.length() == 0 {
        match parsed.usecmap {
          Some(name) =>
            name == pdf_text_name("/Identity-H") ||
            name == pdf_text_name("/Identity-V") ||
            pdf_text_predefined_cmap_uses_two_byte_charcodes(name)
          None => false
        }
      } else {
        for codespace in parsed.codespaces {
          if codespace.length != 2 {
            break false
          }
        } nobreak {
          true
        }
      }
    _ => false
  }
}

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
fn pdf_text_parsed_cmap_predefined_base(parsed : PdfParsedCMap) -> PdfName? {
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
) -> Array[Int] raise PdfError {
  guard parsed.codespaces.length() > 0 ||
    pdf_text_parsed_cmap_has_identity_base(parsed) else {
    match pdf_text_parsed_cmap_predefined_base(parsed) {
      Some(name) =>
        return pdf_text_predefined_cmap_charcodes_of_text(name, text)
      None => return [ for byte in text => byte.to_int() ]
    }
  }
  let output : Array[Int] = []
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
pub fn PdfCIDKeyedFont::is_identity_h(self : PdfCIDKeyedFont) -> Bool {
  self.encoding.is_identity_h()
}

///|
pub fn PdfCIDKeyedFont::is_identity_v(self : PdfCIDKeyedFont) -> Bool {
  self.encoding.is_identity_v()
}

///|
pub fn PdfCIDKeyedFont::uses_two_byte_codes(self : PdfCIDKeyedFont) -> Bool {
  self.encoding.uses_two_byte_codes()
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
pub fn PdfFont::is_identity_v(self : PdfFont) -> Bool {
  match self {
    PdfFontCIDKeyed(font) => font.is_identity_v()
    _ => false
  }
}

///|
pub fn PdfFont::uses_two_byte_codes(self : PdfFont) -> Bool {
  match self {
    PdfFontCIDKeyed(font) => font.uses_two_byte_codes()
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
        Some(number) =>
          try self.parse_cmap(PdfIndirect(number)) catch {
            _ => PdfCMap(number)
          } noraise {
            parsed => PdfExternalCMap(number, parsed)
          }
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
  guard stop >= start else { return None }
  let output : Array[Byte] = []
  let mut high : Int? = None
  let mut index = start
  while index < stop {
    let value = line[index].to_int()
    if pdf_is_whitespace_byte(value) {
      ()
    } else {
      match pdf_text_hex_digit_value(line[index]) {
        Some(nibble) =>
          match high {
            Some(high_nibble) => {
              output.push((high_nibble * 16 + nibble).to_byte())
              high = None
            }
            None => high = Some(nibble)
          }
        None => return None
      }
    }
    index += 1
  }
  match high {
    Some(high_nibble) => output.push((high_nibble * 16).to_byte())
    None => ()
  }
  Some(Bytes::from_array(output))
}

///|
fn pdf_text_skip_cmap_whitespace(line : BytesView, start : Int) -> Int {
  let mut index = start
  while index < line.length() && pdf_is_whitespace_byte(line[index].to_int()) {
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
fn pdf_text_index_of_ascii_from(
  line : BytesView,
  word : String,
  start : Int,
) -> Int? {
  guard start < line.length() else { return None }
  match pdf_text_index_of_ascii(line[start:], word) {
    Some(index) => Some(start + index)
    None => None
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
fn pdf_text_view_equals_ascii(view : BytesView, text : String) -> Bool {
  let expected = @ascii.encode(text)
  guard view.length() == expected.length() else { return false }
  for index in 0..<view.length() {
    if view[index] != expected[index] {
      break false
    }
  } nobreak {
    true
  }
}

///|
fn pdf_text_parse_cmap_int_after_token(data : BytesView, key : String) -> Int? {
  let cursor = byte_cursor_of_view(data)
  let mut expect_value = false
  for line in cursor.read_line_views() {
    let tokens = pdf_split_whitespace_tokens(line)
    for token in tokens {
      if expect_value {
        expect_value = false
        let parsed = try pdf_parse_ascii_int_view(token) catch {
          _ => None
        } noraise {
          value => Some(value)
        }
        match parsed {
          Some(value) => return Some(value)
          None => ()
        }
      }
      if pdf_text_view_equals_ascii(token, key) {
        expect_value = true
      }
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_parse_cmap_wmode(data : BytesView) -> Int? {
  pdf_text_parse_cmap_int_after_token(data, "/WMode")
}

///|
fn pdf_text_parse_cmap_name_token(token : BytesView) -> PdfName? {
  guard token.length() > 1 && token[0].to_int() == 47 else { return None }
  let bytes : Array[Byte] = [47]
  let mut index = 1
  while index < token.length() {
    let value = token[index].to_int()
    if value == 35 {
      guard index + 2 < token.length() else { return None }
      match
        (
          pdf_hex_value(token[index + 1].to_int()),
          pdf_hex_value(token[index + 2].to_int()),
        ) {
        (Some(high), Some(low)) => {
          bytes.push((high * 16 + low).to_byte())
          index += 3
        }
        _ => return None
      }
    } else {
      bytes.push(token[index])
      index += 1
    }
  }
  Some(pdf_name_of_bytes(Bytes::from_array(bytes)))
}

///|
fn pdf_text_parse_cmap_name_after_token(
  data : BytesView,
  key : String,
) -> PdfName? {
  let cursor = byte_cursor_of_view(data)
  let mut expect_value = false
  for line in cursor.read_line_views() {
    let tokens = pdf_split_whitespace_tokens(line)
    for token in tokens {
      if expect_value {
        expect_value = false
        match pdf_text_parse_cmap_name_token(token) {
          Some(name) => return Some(name)
          None => ()
        }
      }
      if pdf_text_view_equals_ascii(token, key) {
        expect_value = true
      }
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_parse_cmap_object_token(token : BytesView) -> PdfObject? {
  try pdf_parse_object_from_view(token) catch {
    _ => None
  } noraise {
    object => Some(object)
  }
}

///|
priv enum PdfTextCMapCIDSystemInfoKey {
  PdfTextCMapCIDSystemRegistry
  PdfTextCMapCIDSystemOrdering
  PdfTextCMapCIDSystemSupplement
}

///|
fn pdf_text_parse_cmap_cid_system_value(
  key : PdfTextCMapCIDSystemInfoKey,
  token : BytesView,
  registry : Array[PdfBytes],
  ordering : Array[PdfBytes],
  supplement : Array[Int],
) -> Unit {
  match (key, pdf_text_parse_cmap_object_token(token)) {
    (PdfTextCMapCIDSystemRegistry, Some(PdfString(value))) =>
      registry.push(value)
    (PdfTextCMapCIDSystemOrdering, Some(PdfString(value))) =>
      ordering.push(value)
    (PdfTextCMapCIDSystemSupplement, Some(PdfInteger(value))) =>
      supplement.push(value)
    _ => ()
  }
}

///|
fn pdf_text_parse_cmap_cid_system_info(data : BytesView) -> PdfCIDSystemInfo? {
  let cursor = byte_cursor_of_view(data)
  let registries : Array[PdfBytes] = []
  let orderings : Array[PdfBytes] = []
  let supplements : Array[Int] = []
  let mut seen_cid_system_info = false
  let mut expect_value : PdfTextCMapCIDSystemInfoKey? = None
  for line in cursor.read_line_views() {
    let tokens = pdf_split_whitespace_tokens(line)
    for token in tokens {
      if !seen_cid_system_info {
        if pdf_text_view_equals_ascii(token, "/CIDSystemInfo") {
          seen_cid_system_info = true
        }
        continue
      }
      match expect_value {
        Some(key) => {
          pdf_text_parse_cmap_cid_system_value(
            key, token, registries, orderings, supplements,
          )
          expect_value = None
          if registries.length() > 0 &&
            orderings.length() > 0 &&
            supplements.length() > 0 {
            return Some({
              registry: registries[0],
              ordering: orderings[0],
              supplement: supplements[0],
            })
          }
        }
        None => ()
      }
      if pdf_text_view_equals_ascii(token, "/Registry") {
        expect_value = Some(PdfTextCMapCIDSystemRegistry)
      } else if pdf_text_view_equals_ascii(token, "/Ordering") {
        expect_value = Some(PdfTextCMapCIDSystemOrdering)
      } else if pdf_text_view_equals_ascii(token, "/Supplement") {
        expect_value = Some(PdfTextCMapCIDSystemSupplement)
      }
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_parse_cmap_usecmap(data : BytesView) -> PdfName? {
  let cursor = byte_cursor_of_view(data)
  let mut previous_name : PdfName? = None
  for line in cursor.read_line_views() {
    let tokens = pdf_split_whitespace_tokens(line)
    for token in tokens {
      if pdf_text_view_equals_ascii(token, "usecmap") {
        match previous_name {
          Some(name) => return Some(name)
          None => ()
        }
      }
      previous_name = pdf_text_parse_cmap_name_token(token)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_cmap_end_marker(line : BytesView, start : Int) -> (Int, Int)? {
  let markers = [
    "endbfchar", "endbfrange", "endcidchar", "endcidrange", "endnotdefchar", "endnotdefrange",
    "endcodespacerange",
  ]
  let mut best : (Int, Int)? = None
  for marker in markers {
    match pdf_text_index_of_ascii_from(line, marker, start) {
      Some(index) => {
        let length = @ascii.encode(marker).length()
        match best {
          Some((best_index, _)) if best_index <= index => ()
          _ => best = Some((index, length))
        }
      }
      None => ()
    }
  }
  best
}

///|
fn pdf_text_cmap_section_line_views(line : BytesView) -> Array[BytesView] {
  let views : Array[BytesView] = []
  let mut start = 0
  while start < line.length() {
    match pdf_text_cmap_end_marker(line, start) {
      Some((index, length)) => {
        let stop = index + length
        views.push(line[start:stop])
        start = stop
      }
      None => {
        views.push(line[start:])
        break
      }
    }
  }
  views
}

///|
fn pdf_text_parse_cmap_hex_groups(line : BytesView) -> Array[PdfBytes]? {
  let groups : Array[PdfBytes] = []
  let mut index = 0
  while index < line.length() {
    index = pdf_text_skip_cmap_whitespace(line, index)
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
fn pdf_text_parse_cmap_hex_group_at(
  line : BytesView,
  start : Int,
) -> (PdfBytes, Int)? {
  let index = pdf_text_skip_cmap_whitespace(line, start)
  guard index < line.length() && line[index].to_int() == 60 else { return None }
  let body_start = index + 1
  let mut stop = body_start
  while stop < line.length() && line[stop].to_int() != 62 {
    stop += 1
  }
  guard stop < line.length() else { return None }
  match pdf_text_parse_hex_bytes(line, body_start, stop) {
    Some(bytes) => Some((bytes, stop + 1))
    None => None
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
fn pdf_text_parse_cmap_ascii_int_at(
  line : BytesView,
  start : Int,
) -> (Int, Int)? {
  let index = pdf_text_skip_cmap_whitespace(line, start)
  guard index < line.length() else { return None }
  let mut stop = index
  if line[stop].to_int() == 43 || line[stop].to_int() == 45 {
    stop += 1
  }
  let digit_start = stop
  while stop < line.length() {
    let value = line[stop].to_int()
    if value >= 48 && value <= 57 {
      stop += 1
    } else {
      break
    }
  }
  guard stop > digit_start else { return None }
  try pdf_parse_ascii_int_view(line[index:stop]) catch {
    _ => None
  } noraise {
    value => Some((value, stop))
  }
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
fn pdf_text_tounicode_bfrange_inline_entries(
  line : BytesView,
) -> Array[(Int, PdfBytes)]? {
  let entries : Array[(Int, PdfBytes)] = []
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_hex_group_at(line, after_source) {
          Some((stop, after_stop)) =>
            match
              (pdf_text_bytes_to_int(source[:]), pdf_text_bytes_to_int(stop[:])) {
              (Some(first), Some(last)) if first <= last => {
                index = pdf_text_skip_cmap_whitespace(line, after_stop)
                if index < line.length() && line[index].to_int() == 91 {
                  match pdf_text_index_of_byte(line, 93, index + 1) {
                    Some(close) => {
                      match
                        pdf_text_parse_cmap_hex_groups(line[index + 1:close]) {
                        Some(unicodes) =>
                          match
                            pdf_text_tounicode_bfrange_array_entries(
                              first,
                              last,
                              unicodes[:],
                            ) {
                            Some(line_entries) =>
                              for entry in line_entries {
                                entries.push(entry)
                              }
                            None => return None
                          }
                        None => return None
                      }
                      index = close + 1
                    }
                    None => return None
                  }
                } else {
                  match pdf_text_parse_cmap_hex_group_at(line, index) {
                    Some((unicode, after_unicode)) => {
                      for code in first..<=last {
                        match
                          pdf_text_add_to_big_endian_bytes(
                            unicode,
                            code - first,
                          ) {
                          Some(bytes) => entries.push((code, bytes))
                          None => return None
                        }
                      }
                      index = after_unicode
                    }
                    None => return None
                  }
                }
              }
              _ => return None
            }
          None => return None
        }
      None => break
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries)
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
fn pdf_text_tounicode_bfrange_array_entries(
  first : Int,
  last : Int,
  unicodes : ArrayView[PdfBytes],
) -> Array[(Int, PdfBytes)]? {
  guard first <= last && unicodes.length() == last - first + 1 else {
    return None
  }
  let entries : Array[(Int, PdfBytes)] = []
  for index in 0..<unicodes.length() {
    entries.push((first + index, unicodes[index]))
  }
  Some(entries)
}

///|
fn pdf_text_push_tounicode_bfchar_entry(
  entries : Array[(Int, PdfBytes)],
  source : PdfBytes,
  unicode : PdfBytes,
) -> Unit {
  match pdf_text_bytes_to_int(source[:]) {
    Some(code) => entries.push((code, unicode))
    None => ()
  }
}

///|
fn pdf_text_append_tounicode_bfchar_entries(
  entries : Array[(Int, PdfBytes)],
  pending_source : PdfBytes?,
  line : BytesView,
) -> PdfBytes? {
  let mut pending = pending_source
  match pdf_text_parse_cmap_hex_groups(line) {
    Some(groups) => {
      let mut index = 0
      match pending {
        Some(source) =>
          if groups.length() > 0 {
            pdf_text_push_tounicode_bfchar_entry(entries, source, groups[0])
            pending = None
            index = 1
          }
        None => ()
      }
      while index + 1 < groups.length() {
        pdf_text_push_tounicode_bfchar_entry(
          entries,
          groups[index],
          groups[index + 1],
        )
        index += 2
      }
      if index < groups.length() {
        pending = Some(groups[index])
      }
      pending
    }
    None => pending
  }
}

///|
fn pdf_text_tounicode_bfrange_entries_of_line(
  line : BytesView,
) -> Array[(Int, PdfBytes)]? {
  pdf_text_tounicode_bfrange_inline_entries(line)
}

///|
fn pdf_text_push_tounicode_bfrange_entries(
  entries : Array[(Int, PdfBytes)],
  line_entries : ArrayView[(Int, PdfBytes)],
) -> Unit {
  for entry in line_entries {
    entries.push(entry)
  }
}

///|
priv struct PdfTextCMapBFRangeArray {
  first : Int
  last : Int
  unicodes : Array[PdfBytes]
}

///|
fn pdf_text_extend_cmap_hex_groups(
  output : Array[PdfBytes],
  line : BytesView,
) -> Unit {
  match pdf_text_parse_cmap_hex_groups(line) {
    Some(groups) =>
      for group in groups {
        output.push(group)
      }
    None => ()
  }
}

///|
fn pdf_text_cmap_bfrange_array_line(line : BytesView) -> BytesView {
  match pdf_text_index_of_byte(line, 91, 0) {
    Some(open) => line[open + 1:]
    None => line
  }
}

///|
priv enum PdfTextCMapBFRangeArrayAppend {
  PdfTextCMapBFRangeArrayPending(PdfTextCMapBFRangeArray)
  PdfTextCMapBFRangeArrayClosed(BytesView)
}

///|
fn pdf_text_append_pending_bfrange_array(
  entries : Array[(Int, PdfBytes)],
  pending : PdfTextCMapBFRangeArray,
  line : BytesView,
) -> PdfTextCMapBFRangeArrayAppend {
  let content = pdf_text_cmap_bfrange_array_line(line)
  match pdf_text_index_of_byte(content, 93, 0) {
    Some(close) => {
      pdf_text_extend_cmap_hex_groups(pending.unicodes, content[0:close])
      match
        pdf_text_tounicode_bfrange_array_entries(
          pending.first,
          pending.last,
          pending.unicodes[:],
        ) {
        Some(line_entries) =>
          pdf_text_push_tounicode_bfrange_entries(entries, line_entries[:])
        None => ()
      }
      PdfTextCMapBFRangeArrayClosed(content[close + 1:])
    }
    None => {
      pdf_text_extend_cmap_hex_groups(pending.unicodes, content)
      PdfTextCMapBFRangeArrayPending(pending)
    }
  }
}

///|
priv enum PdfTextCMapBFRangeLineAppend {
  PdfTextCMapBFRangeLineDone
  PdfTextCMapBFRangeLinePending(PdfTextCMapBFRangeArray)
  PdfTextCMapBFRangeLineContinue(BytesView)
}

///|
fn pdf_text_append_tounicode_bfrange_entry(
  entries : Array[(Int, PdfBytes)],
  line : BytesView,
) -> PdfTextCMapBFRangeLineAppend {
  match pdf_text_parse_cmap_hex_group_at(line, 0) {
    Some((source, after_source)) =>
      match pdf_text_parse_cmap_hex_group_at(line, after_source) {
        Some((stop, after_stop)) =>
          match
            (pdf_text_bytes_to_int(source[:]), pdf_text_bytes_to_int(stop[:])) {
            (Some(first), Some(last)) if first <= last => {
              let value_start = pdf_text_skip_cmap_whitespace(line, after_stop)
              let pending : PdfTextCMapBFRangeArray = {
                first,
                last,
                unicodes: [],
              }
              if value_start >= line.length() {
                PdfTextCMapBFRangeLinePending(pending)
              } else if line[value_start].to_int() == 91 {
                match
                  pdf_text_append_pending_bfrange_array(
                    entries,
                    pending,
                    line[value_start + 1:],
                  ) {
                  PdfTextCMapBFRangeArrayClosed(rest) =>
                    PdfTextCMapBFRangeLineContinue(rest)
                  PdfTextCMapBFRangeArrayPending(pending) =>
                    PdfTextCMapBFRangeLinePending(pending)
                }
              } else {
                match pdf_text_parse_cmap_hex_group_at(line, value_start) {
                  Some((unicode, after_unicode)) => {
                    let line_entries : Array[(Int, PdfBytes)] = []
                    for code in first..<=last {
                      match
                        pdf_text_add_to_big_endian_bytes(unicode, code - first) {
                        Some(bytes) => line_entries.push((code, bytes))
                        None => return PdfTextCMapBFRangeLineDone
                      }
                    }
                    pdf_text_push_tounicode_bfrange_entries(
                      entries,
                      line_entries[:],
                    )
                    PdfTextCMapBFRangeLineContinue(line[after_unicode:])
                  }
                  None => PdfTextCMapBFRangeLineDone
                }
              }
            }
            _ => PdfTextCMapBFRangeLineDone
          }
        None => PdfTextCMapBFRangeLineDone
      }
    None => PdfTextCMapBFRangeLineDone
  }
}

///|
fn pdf_text_append_tounicode_bfrange_line(
  entries : Array[(Int, PdfBytes)],
  line : BytesView,
) -> PdfTextCMapBFRangeArray? {
  match pdf_text_tounicode_bfrange_entries_of_line(line) {
    Some(line_entries) => {
      pdf_text_push_tounicode_bfrange_entries(entries, line_entries[:])
      return None
    }
    None => ()
  }
  let mut current = line
  while current.length() > 0 {
    match pdf_text_append_tounicode_bfrange_entry(entries, current) {
      PdfTextCMapBFRangeLineDone => return None
      PdfTextCMapBFRangeLinePending(pending) => return Some(pending)
      PdfTextCMapBFRangeLineContinue(rest) => current = rest
    }
  }
  None
}

///|
priv enum PdfTextToUnicodeSection {
  PdfTextToUnicodeNone
  PdfTextToUnicodeBFChar
  PdfTextToUnicodeBFRange
}

///|
priv enum PdfTextCMapSection {
  PdfTextCMapNone
  PdfTextCMapCIDChar
  PdfTextCMapCIDRange
  PdfTextCMapNotDefChar
  PdfTextCMapNotDefRange
  PdfTextCMapCodeSpace
}

///|
fn pdf_text_cmap_contains_whitespace(data : BytesView) -> Bool {
  for byte in data {
    if pdf_is_whitespace_byte(byte.to_int()) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_text_cmap_without_whitespace(data : BytesView) -> PdfBytes {
  let output : Array[Byte] = []
  for byte in data {
    if !pdf_is_whitespace_byte(byte.to_int()) {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_text_parse_tounicode_sections(
  data : BytesView,
) -> Array[(Int, PdfBytes)]? {
  let cursor = byte_cursor_of_view(data)
  let entries : Array[(Int, PdfBytes)] = []
  let mut section = PdfTextToUnicodeNone
  let mut pending_bfchar_source : PdfBytes? = None
  let mut pending_bfrange_array : PdfTextCMapBFRangeArray? = None
  for raw_line in cursor.read_line_views() {
    for raw_segment in pdf_text_cmap_section_line_views(raw_line) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "beginbfchar") {
        Some(rest) => {
          section = PdfTextToUnicodeBFChar
          line = rest
        }
        None =>
          match pdf_text_after_ascii(raw_segment, "beginbfrange") {
            Some(rest) => {
              section = PdfTextToUnicodeBFRange
              line = rest
            }
            None => ()
          }
      }
      let end_bfchar = pdf_text_line_contains_ascii(line, "endbfchar")
      let end_bfrange = pdf_text_line_contains_ascii(line, "endbfrange")
      match pending_bfrange_array {
        Some(pending) =>
          match pdf_text_append_pending_bfrange_array(entries, pending, line) {
            PdfTextCMapBFRangeArrayClosed(rest) =>
              pending_bfrange_array = pdf_text_append_tounicode_bfrange_line(
                entries, rest,
              )
            PdfTextCMapBFRangeArrayPending(pending) =>
              pending_bfrange_array = Some(pending)
          }
        None =>
          match section {
            PdfTextToUnicodeBFChar =>
              pending_bfchar_source = pdf_text_append_tounicode_bfchar_entries(
                entries, pending_bfchar_source, line,
              )
            PdfTextToUnicodeBFRange =>
              pending_bfrange_array = pdf_text_append_tounicode_bfrange_line(
                entries, line,
              )
            PdfTextToUnicodeNone => ()
          }
      }
      if end_bfchar && section is PdfTextToUnicodeBFChar {
        section = PdfTextToUnicodeNone
        pending_bfchar_source = None
      }
      if end_bfrange && section is PdfTextToUnicodeBFRange {
        section = PdfTextToUnicodeNone
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
fn pdf_text_push_cmap_cidchar_entries(
  entries : Array[(Int, Int)],
  line : BytesView,
) -> Unit {
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_ascii_int_at(line, after_source) {
          Some((cid, after_cid)) => {
            match pdf_text_bytes_to_int(source[:]) {
              Some(code) => entries.push((code, cid))
              None => ()
            }
            index = after_cid
          }
          None => break
        }
      None => break
    }
  }
}

///|
fn pdf_text_push_cmap_cidrange_entries(
  entries : Array[(Int, Int)],
  line : BytesView,
) -> Unit {
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_hex_group_at(line, after_source) {
          Some((stop, after_stop)) =>
            match pdf_text_parse_cmap_ascii_int_at(line, after_stop) {
              Some((cid, after_cid)) => {
                match
                  (
                    pdf_text_bytes_to_int(source[:]),
                    pdf_text_bytes_to_int(stop[:]),
                  ) {
                  (Some(first), Some(last)) if first <= last =>
                    for code in first..<=last {
                      entries.push((code, cid + code - first))
                    }
                  _ => ()
                }
                index = after_cid
              }
              None => break
            }
          None => break
        }
      None => break
    }
  }
}

///|
fn pdf_text_push_cmap_codespace_entries(
  entries : Array[PdfCMapCodeSpace],
  line : BytesView,
) -> Unit {
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_hex_group_at(line, after_source) {
          Some((stop, after_stop)) => {
            match
              (pdf_text_bytes_to_int(source[:]), pdf_text_bytes_to_int(stop[:])) {
              (Some(first), Some(last)) if first <= last &&
                source.length() == stop.length() =>
                entries.push({ length: source.length(), first, last })
              _ => ()
            }
            index = after_stop
          }
          None => break
        }
      None => break
    }
  }
}

///|
fn pdf_text_parse_cmap_cid_sections(data : BytesView) -> Array[(Int, Int)]? {
  let cursor = byte_cursor_of_view(data)
  let entries : Array[(Int, Int)] = []
  let mut section = PdfTextCMapNone
  for raw_line in cursor.read_line_views() {
    for raw_segment in pdf_text_cmap_section_line_views(raw_line) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "begincidchar") {
        Some(rest) => {
          section = PdfTextCMapCIDChar
          line = rest
        }
        None =>
          match pdf_text_after_ascii(raw_segment, "begincidrange") {
            Some(rest) => {
              section = PdfTextCMapCIDRange
              line = rest
            }
            None => ()
          }
      }
      match section {
        PdfTextCMapCIDChar => pdf_text_push_cmap_cidchar_entries(entries, line)
        PdfTextCMapCIDRange =>
          pdf_text_push_cmap_cidrange_entries(entries, line)
        _ => ()
      }
      if pdf_text_line_contains_ascii(line, "endcidchar") &&
        section is PdfTextCMapCIDChar {
        section = PdfTextCMapNone
      }
      if pdf_text_line_contains_ascii(line, "endcidrange") &&
        section is PdfTextCMapCIDRange {
        section = PdfTextCMapNone
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
fn pdf_text_parse_cmap_notdef_sections(data : BytesView) -> Array[(Int, Int)]? {
  let cursor = byte_cursor_of_view(data)
  let entries : Array[(Int, Int)] = []
  let mut section = PdfTextCMapNone
  for raw_line in cursor.read_line_views() {
    for raw_segment in pdf_text_cmap_section_line_views(raw_line) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "beginnotdefchar") {
        Some(rest) => {
          section = PdfTextCMapNotDefChar
          line = rest
        }
        None =>
          match pdf_text_after_ascii(raw_segment, "beginnotdefrange") {
            Some(rest) => {
              section = PdfTextCMapNotDefRange
              line = rest
            }
            None => ()
          }
      }
      match section {
        PdfTextCMapNotDefChar =>
          pdf_text_push_cmap_cidchar_entries(entries, line)
        PdfTextCMapNotDefRange =>
          pdf_text_push_cmap_cidrange_entries(entries, line)
        _ => ()
      }
      if pdf_text_line_contains_ascii(line, "endnotdefchar") &&
        section is PdfTextCMapNotDefChar {
        section = PdfTextCMapNone
      }
      if pdf_text_line_contains_ascii(line, "endnotdefrange") &&
        section is PdfTextCMapNotDefRange {
        section = PdfTextCMapNone
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
fn pdf_text_parse_cmap_codespace_sections(
  data : BytesView,
) -> Array[PdfCMapCodeSpace]? {
  let cursor = byte_cursor_of_view(data)
  let entries : Array[PdfCMapCodeSpace] = []
  let mut section = PdfTextCMapNone
  for raw_line in cursor.read_line_views() {
    for raw_segment in pdf_text_cmap_section_line_views(raw_line) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "begincodespacerange") {
        Some(rest) => {
          section = PdfTextCMapCodeSpace
          line = rest
        }
        None => ()
      }
      match section {
        PdfTextCMapCodeSpace =>
          pdf_text_push_cmap_codespace_entries(entries, line)
        _ => ()
      }
      if pdf_text_line_contains_ascii(line, "endcodespacerange") &&
        section is PdfTextCMapCodeSpace {
        section = PdfTextCMapNone
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
fn pdf_text_parse_cmap_cids(data : BytesView) -> Array[(Int, Int)]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_cmap_cid_sections(data)
    let compact = pdf_text_cmap_without_whitespace(data)
    let compact_parsed = pdf_text_parse_cmap_cid_sections(compact[:])
    match (parsed, compact_parsed) {
      (Some(original_entries), Some(compact_entries)) =>
        if compact_entries.length() > original_entries.length() {
          Some(compact_entries)
        } else {
          Some(original_entries)
        }
      (None, Some(compact_entries)) => Some(compact_entries)
      _ => parsed
    }
  } else {
    pdf_text_parse_cmap_cid_sections(data)
  }
}

///|
fn pdf_text_parse_cmap_notdefs(data : BytesView) -> Array[(Int, Int)]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_cmap_notdef_sections(data)
    let compact = pdf_text_cmap_without_whitespace(data)
    let compact_parsed = pdf_text_parse_cmap_notdef_sections(compact[:])
    match (parsed, compact_parsed) {
      (Some(original_entries), Some(compact_entries)) =>
        if compact_entries.length() > original_entries.length() {
          Some(compact_entries)
        } else {
          Some(original_entries)
        }
      (None, Some(compact_entries)) => Some(compact_entries)
      _ => parsed
    }
  } else {
    pdf_text_parse_cmap_notdef_sections(data)
  }
}

///|
fn pdf_text_parse_cmap_codespaces(data : BytesView) -> Array[PdfCMapCodeSpace]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_cmap_codespace_sections(data)
    let compact = pdf_text_cmap_without_whitespace(data)
    let compact_parsed = pdf_text_parse_cmap_codespace_sections(compact[:])
    match (parsed, compact_parsed) {
      (Some(original_entries), Some(compact_entries)) =>
        if compact_entries.length() > original_entries.length() {
          Some(compact_entries)
        } else {
          Some(original_entries)
        }
      (None, Some(compact_entries)) => Some(compact_entries)
      _ => parsed
    }
  } else {
    pdf_text_parse_cmap_codespace_sections(data)
  }
}

///|
fn pdf_text_parse_tounicode(data : BytesView) -> Array[(Int, PdfBytes)]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_tounicode_sections(data)
    let compact = pdf_text_cmap_without_whitespace(data)
    let compact_parsed = pdf_text_parse_tounicode_sections(compact[:])
    match (parsed, compact_parsed) {
      (Some(original_entries), Some(compact_entries)) =>
        if compact_entries.length() > original_entries.length() {
          Some(compact_entries)
        } else {
          Some(original_entries)
        }
      (None, Some(compact_entries)) => Some(compact_entries)
      _ => parsed
    }
  } else {
    pdf_text_parse_tounicode_sections(data)
  }
}

///|
pub fn pdf_parse_cmap_data(data : BytesView) -> PdfParsedCMap {
  {
    map: match pdf_text_parse_tounicode(data) {
      Some(entries) => entries
      None => []
    },
    cid_map: match pdf_text_parse_cmap_cids(data) {
      Some(entries) => entries
      None => []
    },
    notdef_map: match pdf_text_parse_cmap_notdefs(data) {
      Some(entries) => entries
      None => []
    },
    codespaces: match pdf_text_parse_cmap_codespaces(data) {
      Some(entries) => entries
      None => []
    },
    usecmap: pdf_text_parse_cmap_usecmap(data),
    wmode: pdf_text_parse_cmap_wmode(data),
    cmap_name: pdf_text_parse_cmap_name_after_token(data, "/CMapName"),
    cmap_type: pdf_text_parse_cmap_int_after_token(data, "/CMapType"),
    cid_system_info: pdf_text_parse_cmap_cid_system_info(data),
  }
}

///|
fn pdf_text_cmap_seen_contains(seen : ArrayView[Int], number : Int) -> Bool {
  for seen_number in seen {
    if seen_number == number {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_text_tounicode_has_charcode(
  entries : ArrayView[(Int, PdfBytes)],
  code : Int,
) -> Bool {
  for entry in entries {
    if entry.0 == code {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_text_compose_tounicode_entries(
  current : ArrayView[(Int, PdfBytes)],
  inherited : ArrayView[(Int, PdfBytes)],
) -> Array[(Int, PdfBytes)] {
  let output : Array[(Int, PdfBytes)] = []
  for entry in current {
    output.push(entry)
  }
  for entry in inherited {
    if !pdf_text_tounicode_has_charcode(output[:], entry.0) {
      output.push(entry)
    }
  }
  output
}

///|
fn pdf_text_compose_cid_entries(
  current : ArrayView[(Int, Int)],
  inherited : ArrayView[(Int, Int)],
) -> Array[(Int, Int)] {
  let output : Array[(Int, Int)] = []
  for entry in current {
    output.push(entry)
  }
  for entry in inherited {
    if !pdf_text_cmap_has_charcode(output[:], entry.0) {
      output.push(entry)
    }
  }
  output
}

///|
fn pdf_text_compose_codespaces(
  current : ArrayView[PdfCMapCodeSpace],
  inherited : ArrayView[PdfCMapCodeSpace],
) -> Array[PdfCMapCodeSpace] {
  let output : Array[PdfCMapCodeSpace] = []
  for entry in current {
    output.push(entry)
  }
  for entry in inherited {
    output.push(entry)
  }
  output
}

///|
fn pdf_text_compose_parsed_cmap(
  current : PdfParsedCMap,
  inherited : PdfParsedCMap,
) -> PdfParsedCMap {
  {
    map: pdf_text_compose_tounicode_entries(current.map[:], inherited.map[:]),
    cid_map: pdf_text_compose_cid_entries(
      current.cid_map[:],
      inherited.cid_map[:],
    ),
    notdef_map: pdf_text_compose_cid_entries(
      current.notdef_map[:],
      inherited.notdef_map[:],
    ),
    codespaces: pdf_text_compose_codespaces(
      current.codespaces[:],
      inherited.codespaces[:],
    ),
    usecmap: match current.usecmap {
      Some(_) => current.usecmap
      None => inherited.usecmap
    },
    wmode: match current.wmode {
      Some(_) => current.wmode
      None => inherited.wmode
    },
    cmap_name: match current.cmap_name {
      Some(_) => current.cmap_name
      None => inherited.cmap_name
    },
    cmap_type: match current.cmap_type {
      Some(_) => current.cmap_type
      None => inherited.cmap_type
    },
    cid_system_info: match current.cid_system_info {
      Some(_) => current.cid_system_info
      None => inherited.cid_system_info
    },
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_wmode(
  self : PdfDocument,
  stream_object : PdfObject,
) -> Int? {
  match self.lookup_direct(pdf_text_name("/WMode"), stream_object) {
    Some(PdfInteger(value)) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_cmap_name(
  self : PdfDocument,
  stream_object : PdfObject,
) -> PdfName? {
  match self.lookup_direct(pdf_text_name("/CMapName"), stream_object) {
    Some(PdfNameObject(name)) => Some(name)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_cmap_type(
  self : PdfDocument,
  stream_object : PdfObject,
) -> Int? {
  match self.lookup_direct(pdf_text_name("/CMapType"), stream_object) {
    Some(PdfInteger(value)) => Some(value)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_usecmap_name(
  self : PdfDocument,
  stream_object : PdfObject,
) -> PdfName? {
  match self.lookup_direct(pdf_text_name("/UseCMap"), stream_object) {
    Some(PdfNameObject(name)) => Some(name)
    _ => None
  }
}

///|
fn PdfDocument::pdf_text_cmap_stream_dictionary_cid_system_info(
  self : PdfDocument,
  stream_object : PdfObject,
) -> PdfCIDSystemInfo? {
  match self.lookup_direct(pdf_text_name("/CIDSystemInfo"), stream_object) {
    Some(value) =>
      try self.read_cid_system_info(value) catch {
        _ => None
      } noraise {
        info => Some(info)
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_text_apply_cmap_stream_dictionary_metadata(
  self : PdfDocument,
  stream_object : PdfObject,
  parsed : PdfParsedCMap,
) -> PdfParsedCMap {
  {
    ..parsed,
    usecmap: match parsed.usecmap {
      Some(_) => parsed.usecmap
      None => self.pdf_text_cmap_stream_dictionary_usecmap_name(stream_object)
    },
    wmode: match parsed.wmode {
      Some(_) => parsed.wmode
      None => self.pdf_text_cmap_stream_dictionary_wmode(stream_object)
    },
    cmap_name: match parsed.cmap_name {
      Some(_) => parsed.cmap_name
      None => self.pdf_text_cmap_stream_dictionary_cmap_name(stream_object)
    },
    cmap_type: match parsed.cmap_type {
      Some(_) => parsed.cmap_type
      None => self.pdf_text_cmap_stream_dictionary_cmap_type(stream_object)
    },
    cid_system_info: match parsed.cid_system_info {
      Some(_) => parsed.cid_system_info
      None =>
        self.pdf_text_cmap_stream_dictionary_cid_system_info(stream_object)
    },
  }
}

///|
fn PdfDocument::pdf_text_decoded_cmap_stream_data_direct(
  self : PdfDocument,
  object : PdfObject,
) -> PdfBytes raise PdfError {
  match self.direct(object) {
    PdfStreamObject(stream) => {
      let decoded = match
        self.pdf_stream_first_filter_direct(stream.dictionary) {
        None => stream
        Some(_) => self.pdf_decode_stream_value_direct(stream)
      }
      pdf_stream_data_bytes(decoded.data)
    }
    _ => raise CMapEncodingExpected
  }
}

///|
fn PdfDocument::parse_cmap_with_seen(
  self : PdfDocument,
  cmap : PdfObject,
  seen : ArrayView[Int],
) -> PdfParsedCMap raise PdfError {
  let next_seen = match cmap {
    PdfIndirect(number) => {
      guard !pdf_text_cmap_seen_contains(seen, number) else {
        raise CMapEncodingExpected
      }
      let output = seen.to_owned()
      output.push(number)
      output
    }
    _ => seen.to_owned()
  }
  let bytes = self.pdf_text_decoded_cmap_stream_data_direct(cmap)
  let stream_object = self.direct(cmap)
  let parsed = self.pdf_text_apply_cmap_stream_dictionary_metadata(
    stream_object,
    pdf_parse_cmap_data(bytes[:]),
  )
  match
    (parsed.usecmap, stream_object.lookup_immediate(pdf_text_name("/UseCMap"))) {
    (None, Some(base)) =>
      match base {
        PdfIndirect(_) | PdfStreamObject(_) =>
          try self.parse_cmap_with_seen(base, next_seen[:]) catch {
            _ => parsed
          } noraise {
            inherited => pdf_text_compose_parsed_cmap(parsed, inherited)
          }
        _ => parsed
      }
    _ => parsed
  }
}

///|
pub fn PdfDocument::parse_cmap(
  self : PdfDocument,
  cmap : PdfObject,
) -> PdfParsedCMap raise PdfError {
  self.parse_cmap_with_seen(cmap, [])
}

///|
fn PdfDocument::pdf_text_tounicode_of_font(
  self : PdfDocument,
  font : PdfObject,
) -> Array[(Int, PdfBytes)]? {
  match self.lookup_direct(pdf_text_name("/ToUnicode"), font) {
    Some(PdfStreamObject(_) as stream) =>
      try self.parse_cmap(stream) catch {
        _ => None
      } noraise {
        parsed => if parsed.map.length() == 0 { None } else { Some(parsed.map) }
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
fn pdf_text_codepoints_of_tounicode_bytes_or_charcode(
  bytes : PdfBytes,
  code : Int,
) -> Array[Int] {
  try pdf_codepoints_of_utf16be(bytes[:]) catch {
    _ => [code]
  } noraise {
    codepoints => codepoints
  }
}

///|
fn pdf_text_lookup_tounicode_codepoints(
  tounicode : ArrayView[(Int, PdfBytes)],
  code : Int,
) -> Array[Int]? {
  match pdf_text_lookup_tounicode(tounicode, code) {
    Some(bytes) =>
      Some(pdf_text_codepoints_of_tounicode_bytes_or_charcode(bytes, code))
    None => None
  }
}

///|
fn pdf_text_reverse_lookup_tounicode_charcode(
  tounicode : ArrayView[(Int, PdfBytes)],
  codepoint : Int,
  shadow_first : ArrayView[(Int, Int)],
  shadow_second : ArrayView[(Int, Int)],
) -> Int? {
  for entry in tounicode {
    try pdf_codepoints_of_utf16be(entry.1[:]) catch {
      _ => ()
    } noraise {
      [single] if single == codepoint &&
        !pdf_text_cmap_has_charcode_in_any(shadow_first, shadow_second, entry.0) =>
        break Some(entry.0)
      _ => ()
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
fn pdf_text_standard_control_glyphname(code : Int) -> PdfName? {
  match code {
    9 => Some(pdf_text_name("/controlHT"))
    10 => Some(pdf_text_name("/controlLF"))
    12 => Some(pdf_text_name("/controlFF"))
    13 => Some(pdf_text_name("/controlCR"))
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
  match pdf_text_standard_control_glyphname(code) {
    Some(name) => Some(name)
    None =>
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
        0xA0 => Some(pdf_text_name("/dagger"))
        0xA1 => Some(pdf_text_name("/degree"))
        0xA2 => Some(pdf_text_name("/cent"))
        0xA3 => Some(pdf_text_name("/sterling"))
        0xA4 => Some(pdf_text_name("/section"))
        0xA5 => Some(pdf_text_name("/bullet"))
        0xA6 => Some(pdf_text_name("/paragraph"))
        0xA7 => Some(pdf_text_name("/germandbls"))
        0xA8 => Some(pdf_text_name("/registered"))
        0xA9 => Some(pdf_text_name("/copyright"))
        0xAA => Some(pdf_text_name("/trademark"))
        0xAB => Some(pdf_text_name("/acute"))
        0xAC => Some(pdf_text_name("/dieresis"))
        0xAE => Some(pdf_text_name("/AE"))
        0xAF => Some(pdf_text_name("/Oslash"))
        0xB1 => Some(pdf_text_name("/plusminus"))
        0xB4 => Some(pdf_text_name("/yen"))
        0xB5 => Some(pdf_text_name("/mu"))
        0xBB => Some(pdf_text_name("/ordfeminine"))
        0xBC => Some(pdf_text_name("/ordmasculine"))
        0xBE => Some(pdf_text_name("/ae"))
        0xBF => Some(pdf_text_name("/oslash"))
        0xC0 => Some(pdf_text_name("/questiondown"))
        0xC1 => Some(pdf_text_name("/exclamdown"))
        0xC2 => Some(pdf_text_name("/logicalnot"))
        0xC4 => Some(pdf_text_name("/florin"))
        0xC7 => Some(pdf_text_name("/guillemotleft"))
        0xC8 => Some(pdf_text_name("/guillemotright"))
        0xC9 => Some(pdf_text_name("/ellipsis"))
        0xCA => Some(pdf_text_name("/space"))
        0xCB => Some(pdf_text_name("/Agrave"))
        0xCC => Some(pdf_text_name("/Atilde"))
        0xCD => Some(pdf_text_name("/Otilde"))
        0xCE => Some(pdf_text_name("/OE"))
        0xCF => Some(pdf_text_name("/oe"))
        0xD0 => Some(pdf_text_name("/endash"))
        0xD1 => Some(pdf_text_name("/emdash"))
        0xD2 => Some(pdf_text_name("/quotedblleft"))
        0xD3 => Some(pdf_text_name("/quotedblright"))
        0xD4 => Some(pdf_text_name("/quoteleft"))
        0xD5 => Some(pdf_text_name("/quoteright"))
        0xD6 => Some(pdf_text_name("/divide"))
        0xD8 => Some(pdf_text_name("/ydieresis"))
        0xD9 => Some(pdf_text_name("/Ydieresis"))
        0xDA => Some(pdf_text_name("/fraction"))
        0xDB => Some(pdf_text_name("/currency"))
        0xDC => Some(pdf_text_name("/guilsinglleft"))
        0xDD => Some(pdf_text_name("/guilsinglright"))
        0xDE => Some(pdf_text_name("/fi"))
        0xDF => Some(pdf_text_name("/fl"))
        0xE0 => Some(pdf_text_name("/daggerdbl"))
        0xE1 => Some(pdf_text_name("/periodcentered"))
        0xE2 => Some(pdf_text_name("/quotesinglbase"))
        0xE3 => Some(pdf_text_name("/quotedblbase"))
        0xE4 => Some(pdf_text_name("/perthousand"))
        0xE5 => Some(pdf_text_name("/Acircumflex"))
        0xE6 => Some(pdf_text_name("/Ecircumflex"))
        0xE7 => Some(pdf_text_name("/Aacute"))
        0xE8 => Some(pdf_text_name("/Edieresis"))
        0xE9 => Some(pdf_text_name("/Egrave"))
        0xEA => Some(pdf_text_name("/Iacute"))
        0xEB => Some(pdf_text_name("/Icircumflex"))
        0xEC => Some(pdf_text_name("/Idieresis"))
        0xED => Some(pdf_text_name("/Igrave"))
        0xEE => Some(pdf_text_name("/Oacute"))
        0xEF => Some(pdf_text_name("/Ocircumflex"))
        0xF1 => Some(pdf_text_name("/Ograve"))
        0xF2 => Some(pdf_text_name("/Uacute"))
        0xF3 => Some(pdf_text_name("/Ucircumflex"))
        0xF4 => Some(pdf_text_name("/Ugrave"))
        0xF5 => Some(pdf_text_name("/dotlessi"))
        0xF6 => Some(pdf_text_name("/circumflex"))
        0xF7 => Some(pdf_text_name("/tilde"))
        0xF8 => Some(pdf_text_name("/macron"))
        0xF9 => Some(pdf_text_name("/breve"))
        0xFA => Some(pdf_text_name("/dotaccent"))
        0xFB => Some(pdf_text_name("/ring"))
        0xFC => Some(pdf_text_name("/cedilla"))
        0xFD => Some(pdf_text_name("/hungarumlaut"))
        0xFE => Some(pdf_text_name("/ogonek"))
        0xFF => Some(pdf_text_name("/caron"))
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
        0xA0 => Some(pdf_text_name("/space"))
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
        0xAD => Some(pdf_text_name("/hyphen"))
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
    0x20 => Some(pdf_text_name("/space"))
    0x21 => Some(pdf_text_name("/exclamsmall"))
    0x22 => Some(pdf_text_name("/Hungarumlautsmall"))
    0x23 => Some(pdf_text_name("/centoldstyle"))
    0x24 => Some(pdf_text_name("/dollaroldstyle"))
    0x26 => Some(pdf_text_name("/ampersandsmall"))
    0x27 => Some(pdf_text_name("/Acutesmall"))
    0x28 => Some(pdf_text_name("/parenleftsuperior"))
    0x29 => Some(pdf_text_name("/parenrightsuperior"))
    0x2A => Some(pdf_text_name("/twodotenleader"))
    0x2B => Some(pdf_text_name("/onedotenleader"))
    0x2C => Some(pdf_text_name("/comma"))
    0x2D => Some(pdf_text_name("/hyphen"))
    0x2E => Some(pdf_text_name("/period"))
    0x2F => Some(pdf_text_name("/fraction"))
    0x30 => Some(pdf_text_name("/zerooldstyle"))
    0x31 => Some(pdf_text_name("/oneoldstyle"))
    0x32 => Some(pdf_text_name("/twooldstyle"))
    0x33 => Some(pdf_text_name("/threeoldstyle"))
    0x34 => Some(pdf_text_name("/fouroldstyle"))
    0x35 => Some(pdf_text_name("/fiveoldstyle"))
    0x36 => Some(pdf_text_name("/sixoldstyle"))
    0x37 => Some(pdf_text_name("/sevenoldstyle"))
    0x38 => Some(pdf_text_name("/eightoldstyle"))
    0x39 => Some(pdf_text_name("/nineoldstyle"))
    0x3A => Some(pdf_text_name("/colon"))
    0x3B => Some(pdf_text_name("/semicolon"))
    0x3D => Some(pdf_text_name("/threequartersemdash"))
    0x3F => Some(pdf_text_name("/questionsmall"))
    0x44 => Some(pdf_text_name("/Ethsmall"))
    0x47 => Some(pdf_text_name("/onequarter"))
    0x48 => Some(pdf_text_name("/onehalf"))
    0x49 => Some(pdf_text_name("/threequarters"))
    0x4A => Some(pdf_text_name("/oneeighth"))
    0x4B => Some(pdf_text_name("/threeeighths"))
    0x4C => Some(pdf_text_name("/fiveeighths"))
    0x4D => Some(pdf_text_name("/seveneighths"))
    0x4E => Some(pdf_text_name("/onethird"))
    0x4F => Some(pdf_text_name("/twothirds"))
    0x56 => Some(pdf_text_name("/ff"))
    0x57 => Some(pdf_text_name("/fi"))
    0x58 => Some(pdf_text_name("/fl"))
    0x59 => Some(pdf_text_name("/ffi"))
    0x5A => Some(pdf_text_name("/ffl"))
    0x5B => Some(pdf_text_name("/parenleftinferior"))
    0x5D => Some(pdf_text_name("/parenrightinferior"))
    0x5E => Some(pdf_text_name("/Circumflexsmall"))
    0x5F => Some(pdf_text_name("/hypheninferior"))
    0x60 => Some(pdf_text_name("/Gravesmall"))
    0x61 => Some(pdf_text_name("/Asmall"))
    0x62 => Some(pdf_text_name("/Bsmall"))
    0x63 => Some(pdf_text_name("/Csmall"))
    0x64 => Some(pdf_text_name("/Dsmall"))
    0x65 => Some(pdf_text_name("/Esmall"))
    0x66 => Some(pdf_text_name("/Fsmall"))
    0x67 => Some(pdf_text_name("/Gsmall"))
    0x68 => Some(pdf_text_name("/Hsmall"))
    0x69 => Some(pdf_text_name("/Ismall"))
    0x6A => Some(pdf_text_name("/Jsmall"))
    0x6B => Some(pdf_text_name("/Ksmall"))
    0x6C => Some(pdf_text_name("/Lsmall"))
    0x6D => Some(pdf_text_name("/Msmall"))
    0x6E => Some(pdf_text_name("/Nsmall"))
    0x6F => Some(pdf_text_name("/Osmall"))
    0x70 => Some(pdf_text_name("/Psmall"))
    0x71 => Some(pdf_text_name("/Qsmall"))
    0x72 => Some(pdf_text_name("/Rsmall"))
    0x73 => Some(pdf_text_name("/Ssmall"))
    0x74 => Some(pdf_text_name("/Tsmall"))
    0x75 => Some(pdf_text_name("/Usmall"))
    0x76 => Some(pdf_text_name("/Vsmall"))
    0x77 => Some(pdf_text_name("/Wsmall"))
    0x78 => Some(pdf_text_name("/Xsmall"))
    0x79 => Some(pdf_text_name("/Ysmall"))
    0x7A => Some(pdf_text_name("/Zsmall"))
    0x7B => Some(pdf_text_name("/colonmonetary"))
    0x7C => Some(pdf_text_name("/onefitted"))
    0x7D => Some(pdf_text_name("/rupiah"))
    0x7E => Some(pdf_text_name("/Tildesmall"))
    0x81 => Some(pdf_text_name("/asuperior"))
    0x82 => Some(pdf_text_name("/centsuperior"))
    0x87 => Some(pdf_text_name("/Aacutesmall"))
    0x88 => Some(pdf_text_name("/Agravesmall"))
    0x89 => Some(pdf_text_name("/Acircumflexsmall"))
    0x8A => Some(pdf_text_name("/Adieresissmall"))
    0x8B => Some(pdf_text_name("/Atildesmall"))
    0x8C => Some(pdf_text_name("/Aringsmall"))
    0x8D => Some(pdf_text_name("/Ccedillasmall"))
    0x8E => Some(pdf_text_name("/Eacutesmall"))
    0x8F => Some(pdf_text_name("/Egravesmall"))
    0x90 => Some(pdf_text_name("/Ecircumflexsmall"))
    0x91 => Some(pdf_text_name("/Edieresissmall"))
    0x92 => Some(pdf_text_name("/Iacutesmall"))
    0x93 => Some(pdf_text_name("/Igravesmall"))
    0x94 => Some(pdf_text_name("/Icircumflexsmall"))
    0x95 => Some(pdf_text_name("/Idieresissmall"))
    0x96 => Some(pdf_text_name("/Ntildesmall"))
    0x97 => Some(pdf_text_name("/Oacutesmall"))
    0x98 => Some(pdf_text_name("/Ogravesmall"))
    0x99 => Some(pdf_text_name("/Ocircumflexsmall"))
    0x9A => Some(pdf_text_name("/Odieresissmall"))
    0x9B => Some(pdf_text_name("/Otildesmall"))
    0x9C => Some(pdf_text_name("/Uacutesmall"))
    0x9D => Some(pdf_text_name("/Ugravesmall"))
    0x9E => Some(pdf_text_name("/Ucircumflexsmall"))
    0x9F => Some(pdf_text_name("/Udieresissmall"))
    0xA1 => Some(pdf_text_name("/eightsuperior"))
    0xA2 => Some(pdf_text_name("/fourinferior"))
    0xA3 => Some(pdf_text_name("/threeinferior"))
    0xA4 => Some(pdf_text_name("/sixinferior"))
    0xA5 => Some(pdf_text_name("/eightinferior"))
    0xA6 => Some(pdf_text_name("/seveninferior"))
    0xA7 => Some(pdf_text_name("/Scaronsmall"))
    0xA9 => Some(pdf_text_name("/centinferior"))
    0xAA => Some(pdf_text_name("/twoinferior"))
    0xAC => Some(pdf_text_name("/Dieresissmall"))
    0xAE => Some(pdf_text_name("/Caronsmall"))
    0xAF => Some(pdf_text_name("/osuperior"))
    0xB0 => Some(pdf_text_name("/fiveinferior"))
    0xB2 => Some(pdf_text_name("/commainferior"))
    0xB3 => Some(pdf_text_name("/periodinferior"))
    0xB4 => Some(pdf_text_name("/Yacutesmall"))
    0xB6 => Some(pdf_text_name("/dollarinferior"))
    0xB9 => Some(pdf_text_name("/Thornsmall"))
    0xBB => Some(pdf_text_name("/nineinferior"))
    0xBC => Some(pdf_text_name("/zeroinferior"))
    0xBD => Some(pdf_text_name("/Zcaronsmall"))
    0xBE => Some(pdf_text_name("/AEsmall"))
    0xBF => Some(pdf_text_name("/Oslashsmall"))
    0xC0 => Some(pdf_text_name("/questiondownsmall"))
    0xC1 => Some(pdf_text_name("/oneinferior"))
    0xC2 => Some(pdf_text_name("/Lslashsmall"))
    0xC9 => Some(pdf_text_name("/Cedillasmall"))
    0xCF => Some(pdf_text_name("/OEsmall"))
    0xD0 => Some(pdf_text_name("/figuredash"))
    0xD6 => Some(pdf_text_name("/exclamdownsmall"))
    0xD8 => Some(pdf_text_name("/Ydieresissmall"))
    0xDA => Some(pdf_text_name("/onesuperior"))
    0xDB => Some(pdf_text_name("/twosuperior"))
    0xDC => Some(pdf_text_name("/threesuperior"))
    0xDD => Some(pdf_text_name("/foursuperior"))
    0xDE => Some(pdf_text_name("/fivesuperior"))
    0xDF => Some(pdf_text_name("/sixsuperior"))
    0xE0 => Some(pdf_text_name("/sevensuperior"))
    0xE1 => Some(pdf_text_name("/ninesuperior"))
    0xE2 => Some(pdf_text_name("/zerosuperior"))
    0xE4 => Some(pdf_text_name("/esuperior"))
    0xE5 => Some(pdf_text_name("/rsuperior"))
    0xE6 => Some(pdf_text_name("/tsuperior"))
    0xE9 => Some(pdf_text_name("/isuperior"))
    0xEA => Some(pdf_text_name("/ssuperior"))
    0xEB => Some(pdf_text_name("/dsuperior"))
    0xF1 => Some(pdf_text_name("/lsuperior"))
    0xF2 => Some(pdf_text_name("/Ogoneksmall"))
    0xF3 => Some(pdf_text_name("/Brevesmall"))
    0xF4 => Some(pdf_text_name("/Macronsmall"))
    0xF5 => Some(pdf_text_name("/bsuperior"))
    0xF6 => Some(pdf_text_name("/nsuperior"))
    0xF7 => Some(pdf_text_name("/msuperior"))
    0xF8 => Some(pdf_text_name("/commasuperior"))
    0xF9 => Some(pdf_text_name("/periodsuperior"))
    0xFA => Some(pdf_text_name("/Dotaccentsmall"))
    0xFB => Some(pdf_text_name("/Ringsmall"))
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
    0x3A => Some(pdf_text_name("/colon"))
    0x3B => Some(pdf_text_name("/semicolon"))
    0x3C => Some(pdf_text_name("/less"))
    0x3D => Some(pdf_text_name("/equal"))
    0x3E => Some(pdf_text_name("/greater"))
    0x3F => Some(pdf_text_name("/question"))
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
    0x4A => Some(pdf_text_name("/theta1"))
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
    0x56 => Some(pdf_text_name("/sigma1"))
    0x57 => Some(pdf_text_name("/Omega"))
    0x58 => Some(pdf_text_name("/Xi"))
    0x59 => Some(pdf_text_name("/Psi"))
    0x5A => Some(pdf_text_name("/Zeta"))
    0x5B => Some(pdf_text_name("/bracketleft"))
    0x5C => Some(pdf_text_name("/therefore"))
    0x5D => Some(pdf_text_name("/bracketright"))
    0x5E => Some(pdf_text_name("/perpendicular"))
    0x5F => Some(pdf_text_name("/underscore"))
    0x60 => Some(pdf_text_name("/radicalex"))
    0x61 => Some(pdf_text_name("/alpha"))
    0x62 => Some(pdf_text_name("/beta"))
    0x63 => Some(pdf_text_name("/chi"))
    0x64 => Some(pdf_text_name("/delta"))
    0x65 => Some(pdf_text_name("/epsilon"))
    0x66 => Some(pdf_text_name("/phi"))
    0x67 => Some(pdf_text_name("/gamma"))
    0x68 => Some(pdf_text_name("/eta"))
    0x69 => Some(pdf_text_name("/iota"))
    0x6A => Some(pdf_text_name("/phi1"))
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
    0x7B => Some(pdf_text_name("/braceleft"))
    0x7C => Some(pdf_text_name("/bar"))
    0x7D => Some(pdf_text_name("/braceright"))
    0x7E => Some(pdf_text_name("/similar"))
    0xA0 => Some(pdf_text_name("/Euro"))
    0xA1 => Some(pdf_text_name("/Upsilon1"))
    0xA2 => Some(pdf_text_name("/minute"))
    0xA3 => Some(pdf_text_name("/lessequal"))
    0xA4 => Some(pdf_text_name("/fraction"))
    0xA5 => Some(pdf_text_name("/infinity"))
    0xA6 => Some(pdf_text_name("/florin"))
    0xA7 => Some(pdf_text_name("/club"))
    0xA8 => Some(pdf_text_name("/diamond"))
    0xA9 => Some(pdf_text_name("/heart"))
    0xAA => Some(pdf_text_name("/spade"))
    0xAB => Some(pdf_text_name("/arrowboth"))
    0xAC => Some(pdf_text_name("/arrowleft"))
    0xAD => Some(pdf_text_name("/arrowup"))
    0xAE => Some(pdf_text_name("/arrowright"))
    0xAF => Some(pdf_text_name("/arrowdown"))
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
    0xBD => Some(pdf_text_name("/arrowvertex"))
    0xBE => Some(pdf_text_name("/arrowhorizex"))
    0xBF => Some(pdf_text_name("/carriagereturn"))
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
    0xD2 => Some(pdf_text_name("/registerserif"))
    0xD3 => Some(pdf_text_name("/copyrightserif"))
    0xD4 => Some(pdf_text_name("/trademarkserif"))
    0xD5 => Some(pdf_text_name("/product"))
    0xD6 => Some(pdf_text_name("/radical"))
    0xD7 => Some(pdf_text_name("/dotmath"))
    0xD8 => Some(pdf_text_name("/logicalnot"))
    0xD9 => Some(pdf_text_name("/logicaland"))
    0xDA => Some(pdf_text_name("/logicalor"))
    0xDB => Some(pdf_text_name("/arrowdblboth"))
    0xDC => Some(pdf_text_name("/arrowdblleft"))
    0xDD => Some(pdf_text_name("/arrowdblup"))
    0xDE => Some(pdf_text_name("/arrowdblright"))
    0xDF => Some(pdf_text_name("/arrowdbldown"))
    0xE0 => Some(pdf_text_name("/lozenge"))
    0xE1 => Some(pdf_text_name("/angleleft"))
    0xE2 => Some(pdf_text_name("/registersans"))
    0xE3 => Some(pdf_text_name("/copyrightsans"))
    0xE4 => Some(pdf_text_name("/trademarksans"))
    0xE5 => Some(pdf_text_name("/summation"))
    0xE6 => Some(pdf_text_name("/parenlefttp"))
    0xE7 => Some(pdf_text_name("/parenleftex"))
    0xE8 => Some(pdf_text_name("/parenleftbt"))
    0xE9 => Some(pdf_text_name("/bracketlefttp"))
    0xEA => Some(pdf_text_name("/bracketleftex"))
    0xEB => Some(pdf_text_name("/bracketleftbt"))
    0xEC => Some(pdf_text_name("/bracelefttp"))
    0xED => Some(pdf_text_name("/braceleftmid"))
    0xEE => Some(pdf_text_name("/braceleftbt"))
    0xEF => Some(pdf_text_name("/braceex"))
    0xF1 => Some(pdf_text_name("/angleright"))
    0xF2 => Some(pdf_text_name("/integral"))
    0xF3 => Some(pdf_text_name("/integraltp"))
    0xF4 => Some(pdf_text_name("/integralex"))
    0xF5 => Some(pdf_text_name("/integralbt"))
    0xF6 => Some(pdf_text_name("/parenrighttp"))
    0xF7 => Some(pdf_text_name("/parenrightex"))
    0xF8 => Some(pdf_text_name("/parenrightbt"))
    0xF9 => Some(pdf_text_name("/bracketrighttp"))
    0xFA => Some(pdf_text_name("/bracketrightex"))
    0xFB => Some(pdf_text_name("/bracketrightbt"))
    0xFC => Some(pdf_text_name("/bracerighttp"))
    0xFD => Some(pdf_text_name("/bracerightmid"))
    0xFE => Some(pdf_text_name("/bracerightbt"))
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
    0x5B => Some(pdf_text_name("/a54"))
    0x5C => Some(pdf_text_name("/a55"))
    0x5D => Some(pdf_text_name("/a56"))
    0x5E => Some(pdf_text_name("/a57"))
    0x5F => Some(pdf_text_name("/a58"))
    0x60 => Some(pdf_text_name("/a59"))
    0x61 => Some(pdf_text_name("/a60"))
    0x62 => Some(pdf_text_name("/a61"))
    0x63 => Some(pdf_text_name("/a62"))
    0x64 => Some(pdf_text_name("/a63"))
    0x65 => Some(pdf_text_name("/a64"))
    0x66 => Some(pdf_text_name("/a65"))
    0x67 => Some(pdf_text_name("/a66"))
    0x68 => Some(pdf_text_name("/a67"))
    0x69 => Some(pdf_text_name("/a68"))
    0x6A => Some(pdf_text_name("/a69"))
    0x6B => Some(pdf_text_name("/a70"))
    0x6C => Some(pdf_text_name("/a71"))
    0x6D => Some(pdf_text_name("/a72"))
    0x6E => Some(pdf_text_name("/a73"))
    0x6F => Some(pdf_text_name("/a74"))
    0x70 => Some(pdf_text_name("/a203"))
    0x71 => Some(pdf_text_name("/a75"))
    0x72 => Some(pdf_text_name("/a204"))
    0x73 => Some(pdf_text_name("/a76"))
    0x74 => Some(pdf_text_name("/a77"))
    0x75 => Some(pdf_text_name("/a78"))
    0x76 => Some(pdf_text_name("/a79"))
    0x77 => Some(pdf_text_name("/a81"))
    0x78 => Some(pdf_text_name("/a82"))
    0x79 => Some(pdf_text_name("/a83"))
    0x7A => Some(pdf_text_name("/a84"))
    0x7B => Some(pdf_text_name("/a97"))
    0x7C => Some(pdf_text_name("/a98"))
    0x7D => Some(pdf_text_name("/a99"))
    0x7E => Some(pdf_text_name("/a100"))
    0xA1 => Some(pdf_text_name("/a101"))
    0xA2 => Some(pdf_text_name("/a102"))
    0xA3 => Some(pdf_text_name("/a103"))
    0xA4 => Some(pdf_text_name("/a104"))
    0xA5 => Some(pdf_text_name("/a106"))
    0xA6 => Some(pdf_text_name("/a107"))
    0xA7 => Some(pdf_text_name("/a108"))
    0xA8 => Some(pdf_text_name("/a112"))
    0xA9 => Some(pdf_text_name("/a111"))
    0xAA => Some(pdf_text_name("/a110"))
    0xAB => Some(pdf_text_name("/a109"))
    0xAC => Some(pdf_text_name("/a120"))
    0xAD => Some(pdf_text_name("/a121"))
    0xAE => Some(pdf_text_name("/a122"))
    0xAF => Some(pdf_text_name("/a123"))
    0xB0 => Some(pdf_text_name("/a124"))
    0xB1 => Some(pdf_text_name("/a125"))
    0xB2 => Some(pdf_text_name("/a126"))
    0xB3 => Some(pdf_text_name("/a127"))
    0xB4 => Some(pdf_text_name("/a128"))
    0xB5 => Some(pdf_text_name("/a129"))
    0xB6 => Some(pdf_text_name("/a130"))
    0xB7 => Some(pdf_text_name("/a131"))
    0xB8 => Some(pdf_text_name("/a132"))
    0xB9 => Some(pdf_text_name("/a133"))
    0xBA => Some(pdf_text_name("/a134"))
    0xBB => Some(pdf_text_name("/a135"))
    0xBC => Some(pdf_text_name("/a136"))
    0xBD => Some(pdf_text_name("/a137"))
    0xBE => Some(pdf_text_name("/a138"))
    0xBF => Some(pdf_text_name("/a139"))
    0xC0 => Some(pdf_text_name("/a140"))
    0xC1 => Some(pdf_text_name("/a141"))
    0xC2 => Some(pdf_text_name("/a142"))
    0xC3 => Some(pdf_text_name("/a143"))
    0xC4 => Some(pdf_text_name("/a144"))
    0xC5 => Some(pdf_text_name("/a145"))
    0xC6 => Some(pdf_text_name("/a146"))
    0xC7 => Some(pdf_text_name("/a147"))
    0xC8 => Some(pdf_text_name("/a148"))
    0xC9 => Some(pdf_text_name("/a149"))
    0xCA => Some(pdf_text_name("/a150"))
    0xCB => Some(pdf_text_name("/a151"))
    0xCC => Some(pdf_text_name("/a152"))
    0xCD => Some(pdf_text_name("/a153"))
    0xCE => Some(pdf_text_name("/a154"))
    0xCF => Some(pdf_text_name("/a155"))
    0xD0 => Some(pdf_text_name("/a156"))
    0xD1 => Some(pdf_text_name("/a157"))
    0xD2 => Some(pdf_text_name("/a158"))
    0xD3 => Some(pdf_text_name("/a159"))
    0xD4 => Some(pdf_text_name("/a160"))
    0xD5 => Some(pdf_text_name("/a161"))
    0xD6 => Some(pdf_text_name("/a163"))
    0xD7 => Some(pdf_text_name("/a164"))
    0xD8 => Some(pdf_text_name("/a196"))
    0xD9 => Some(pdf_text_name("/a165"))
    0xDA => Some(pdf_text_name("/a192"))
    0xDB => Some(pdf_text_name("/a166"))
    0xDC => Some(pdf_text_name("/a167"))
    0xDD => Some(pdf_text_name("/a168"))
    0xDE => Some(pdf_text_name("/a169"))
    0xDF => Some(pdf_text_name("/a170"))
    0xE0 => Some(pdf_text_name("/a171"))
    0xE1 => Some(pdf_text_name("/a172"))
    0xE2 => Some(pdf_text_name("/a173"))
    0xE3 => Some(pdf_text_name("/a162"))
    0xE4 => Some(pdf_text_name("/a174"))
    0xE5 => Some(pdf_text_name("/a175"))
    0xE6 => Some(pdf_text_name("/a176"))
    0xE7 => Some(pdf_text_name("/a177"))
    0xE8 => Some(pdf_text_name("/a178"))
    0xE9 => Some(pdf_text_name("/a179"))
    0xEA => Some(pdf_text_name("/a193"))
    0xEB => Some(pdf_text_name("/a180"))
    0xEC => Some(pdf_text_name("/a199"))
    0xED => Some(pdf_text_name("/a181"))
    0xEE => Some(pdf_text_name("/a200"))
    0xEF => Some(pdf_text_name("/a182"))
    0xF1 => Some(pdf_text_name("/a201"))
    0xF2 => Some(pdf_text_name("/a183"))
    0xF3 => Some(pdf_text_name("/a184"))
    0xF4 => Some(pdf_text_name("/a197"))
    0xF5 => Some(pdf_text_name("/a185"))
    0xF6 => Some(pdf_text_name("/a194"))
    0xF7 => Some(pdf_text_name("/a198"))
    0xF8 => Some(pdf_text_name("/a186"))
    0xF9 => Some(pdf_text_name("/a195"))
    0xFA => Some(pdf_text_name("/a187"))
    0xFB => Some(pdf_text_name("/a188"))
    0xFC => Some(pdf_text_name("/a189"))
    0xFD => Some(pdf_text_name("/a190"))
    0xFE => Some(pdf_text_name("/a191"))
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
pub fn PdfEncoding::table(self : PdfEncoding) -> Array[(Int, PdfName)] {
  let output : Array[(Int, PdfName)] = []
  for code in 0..<256 {
    match self.pdf_text_glyphname_of_charcode(code) {
      Some(name) => output.push((code, name))
      None => ()
    }
  }
  output
}

///|
pub fn PdfEncoding::reverse_table(self : PdfEncoding) -> Array[(PdfName, Int)] {
  [
    for entry in self.table() => (entry.1, entry.0)
  ]
}

///|
pub fn pdf_table_of_encoding(encoding : PdfEncoding) -> Array[(Int, PdfName)] {
  encoding.table()
}

///|
pub fn pdf_reverse_table_of_encoding(
  encoding : PdfEncoding,
) -> Array[(PdfName, Int)] {
  encoding.reverse_table()
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
fn pdf_text_codepoint_of_basic_latin_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/A" => Some(65)
    "/B" => Some(66)
    "/C" => Some(67)
    "/D" => Some(68)
    "/E" => Some(69)
    "/F" => Some(70)
    "/G" => Some(71)
    "/H" => Some(72)
    "/I" => Some(73)
    "/J" => Some(74)
    "/K" => Some(75)
    "/L" => Some(76)
    "/M" => Some(77)
    "/N" => Some(78)
    "/O" => Some(79)
    "/P" => Some(80)
    "/Q" => Some(81)
    "/R" => Some(82)
    "/S" => Some(83)
    "/T" => Some(84)
    "/U" => Some(85)
    "/V" => Some(86)
    "/W" => Some(87)
    "/X" => Some(88)
    "/Y" => Some(89)
    "/Z" => Some(90)
    "/a" => Some(97)
    "/b" => Some(98)
    "/c" => Some(99)
    "/controlACK" => Some(6)
    "/controlBEL" => Some(7)
    "/controlBS" => Some(8)
    "/controlCAN" => Some(24)
    "/controlDC1" => Some(17)
    "/controlDC2" => Some(18)
    "/controlDC3" => Some(19)
    "/controlDC4" => Some(20)
    "/controlDEL" => Some(127)
    "/controlDLE" => Some(16)
    "/controlEM" => Some(25)
    "/controlENQ" => Some(5)
    "/controlEOT" => Some(4)
    "/controlESC" => Some(27)
    "/controlETB" => Some(23)
    "/controlETX" => Some(3)
    "/controlFS" => Some(28)
    "/controlGS" => Some(29)
    "/controlNAK" => Some(21)
    "/controlRS" => Some(30)
    "/controlSI" => Some(15)
    "/controlSO" => Some(14)
    "/controlSOT" => Some(2)
    "/controlSTX" => Some(1)
    "/controlSUB" => Some(26)
    "/controlSYN" => Some(22)
    "/controlUS" => Some(31)
    "/controlVT" => Some(11)
    "/d" => Some(100)
    "/e" => Some(101)
    "/f" => Some(102)
    "/g" => Some(103)
    "/h" => Some(104)
    "/i" => Some(105)
    "/j" => Some(106)
    "/k" => Some(107)
    "/l" => Some(108)
    "/m" => Some(109)
    "/n" => Some(110)
    "/o" => Some(111)
    "/p" => Some(112)
    "/q" => Some(113)
    "/r" => Some(114)
    "/s" => Some(115)
    "/spacehackarabic" => Some(32)
    "/t" => Some(116)
    "/u" => Some(117)
    "/v" => Some(118)
    "/verticalbar" => Some(124)
    "/w" => Some(119)
    "/x" => Some(120)
    "/y" => Some(121)
    "/z" => Some(122)
    _ => None
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
    "/zerooldstyle" => Some(0xF730)
    "/oneoldstyle" => Some(0xF731)
    "/twooldstyle" => Some(0xF732)
    "/threeoldstyle" => Some(0xF733)
    "/fouroldstyle" => Some(0xF734)
    "/fiveoldstyle" => Some(0xF735)
    "/sixoldstyle" => Some(0xF736)
    "/sevenoldstyle" => Some(0xF737)
    "/eightoldstyle" => Some(0xF738)
    "/nineoldstyle" => Some(0xF739)
    "/zeroinferior" => Some(0x2080)
    "/oneinferior" => Some(0x2081)
    "/twoinferior" => Some(0x2082)
    "/threeinferior" => Some(0x2083)
    "/fourinferior" => Some(0x2084)
    "/fiveinferior" => Some(0x2085)
    "/sixinferior" => Some(0x2086)
    "/seveninferior" => Some(0x2087)
    "/eightinferior" => Some(0x2088)
    "/nineinferior" => Some(0x2089)
    "/zerosuperior" => Some(0x2070)
    "/onesuperior" => Some(0x00B9)
    "/twosuperior" => Some(0x00B2)
    "/threesuperior" => Some(0x00B3)
    "/oneeighth" => Some(0x215B)
    "/threeeighths" => Some(0x215C)
    "/fiveeighths" => Some(0x215D)
    "/seveneighths" => Some(0x215E)
    "/onethird" => Some(0x2153)
    "/twothirds" => Some(0x2154)
    "/threequartersemdash" => Some(0xF6DE)
    "/foursuperior" => Some(0x2074)
    "/fivesuperior" => Some(0x2075)
    "/sixsuperior" => Some(0x2076)
    "/sevensuperior" => Some(0x2077)
    "/eightsuperior" => Some(0x2078)
    "/ninesuperior" => Some(0x2079)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_punctuation_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/space" => Some(32)
    "/blank" => Some(0x2423)
    "/controlHT" => Some(9)
    "/controlLF" => Some(10)
    "/controlFF" => Some(12)
    "/controlCR" => Some(13)
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
    "/nbspace" => Some(0x00A0)
    "/nonbreakingspace" => Some(0x00A0)
    "/guillemotleft" => Some(0x00AB)
    "/guillemotright" => Some(0x00BB)
    "/ff" => Some(0xFB00)
    "/fi" => Some(0xFB01)
    "/fl" => Some(0xFB02)
    "/ffi" => Some(0xFB03)
    "/ffl" => Some(0xFB04)
    "/periodcentered" => Some(0x00B7)
    "/middot" => Some(0x00B7)
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
    "/overscore" => Some(0x00AF)
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
    "/mu1" => Some(0x00B5)
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
    "/equalsuperior" => Some(0x207C)
    "/plussuperior" => Some(0x207A)
    "/sfthyphen" => Some(0x00AD)
    "/softhyphen" => Some(0x00AD)
    "/afii00208" => Some(0x2015)
    "/afii299" => Some(0x200E)
    "/afii300" => Some(0x200F)
    "/afii301" => Some(0x200D)
    "/afii61573" => Some(0x202C)
    "/afii61574" => Some(0x202D)
    "/afii61575" => Some(0x202E)
    "/afii61664" => Some(0x200C)
    "/asterism" => Some(0x2042)
    "/dbllowline" => Some(0x2017)
    "/dblverticalbar" => Some(0x2016)
    "/enspace" => Some(0x2002)
    "/exclamdbl" => Some(0x203C)
    "/horizontalbar" => Some(0x2015)
    "/hyphentwo" => Some(0x2010)
    "/overline" => Some(0x203E)
    "/primereversed" => Some(0x2035)
    "/quoteleftreversed" => Some(0x201B)
    "/quotereversed" => Some(0x201B)
    "/referencemark" => Some(0x203B)
    "/twodotleader" => Some(0x2025)
    "/underscoredbl" => Some(0x2017)
    "/zerowidthnonjoiner" => Some(0x200C)
    "/zerowidthspace" => Some(0x200B)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_ipa_extension_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Gsmallhook" => Some(0x029B)
    "/Rsmallinverted" => Some(0x0281)
    "/ascript" => Some(0x0251)
    "/ascriptturned" => Some(0x0252)
    "/aturned" => Some(0x0250)
    "/bhook" => Some(0x0253)
    "/bilabialclick" => Some(0x0298)
    "/ccurl" => Some(0x0255)
    "/cstretched" => Some(0x0297)
    "/dezh" => Some(0x02A4)
    "/dhook" => Some(0x0257)
    "/dotlessjstrokehook" => Some(0x0284)
    "/dtail" => Some(0x0256)
    "/dzaltone" => Some(0x02A3)
    "/dzcurl" => Some(0x02A5)
    "/eopen" => Some(0x025B)
    "/eopenclosed" => Some(0x029A)
    "/eopenreversed" => Some(0x025C)
    "/eopenreversedclosed" => Some(0x025E)
    "/eopenreversedhook" => Some(0x025D)
    "/ereversed" => Some(0x0258)
    "/esh" => Some(0x0283)
    "/eshcurl" => Some(0x0286)
    "/eshsquatreversed" => Some(0x0285)
    "/ezh" => Some(0x0292)
    "/ezhcurl" => Some(0x0293)
    "/gammalatinsmall" => Some(0x0263)
    "/ghook" => Some(0x0260)
    "/glottalstop" => Some(0x0294)
    "/glottalstopinverted" => Some(0x0296)
    "/glottalstopreversed" => Some(0x0295)
    "/glottalstopstroke" => Some(0x02A1)
    "/glottalstopstrokereversed" => Some(0x02A2)
    "/gscript" => Some(0x0261)
    "/henghook" => Some(0x0267)
    "/hhook" => Some(0x0266)
    "/hturned" => Some(0x0265)
    "/iotalatin" => Some(0x0269)
    "/istroke" => Some(0x0268)
    "/jcrossedtail" => Some(0x029D)
    "/jdotlessstroke" => Some(0x025F)
    "/kturned" => Some(0x029E)
    "/lbelt" => Some(0x026C)
    "/lezh" => Some(0x026E)
    "/lhookretroflex" => Some(0x026D)
    "/lmiddletilde" => Some(0x026B)
    "/mhook" => Some(0x0271)
    "/mlonglegturned" => Some(0x0270)
    "/mturned" => Some(0x026F)
    "/nhookleft" => Some(0x0272)
    "/nhookretroflex" => Some(0x0273)
    "/obarred" => Some(0x0275)
    "/omegalatinclosed" => Some(0x0277)
    "/oopen" => Some(0x0254)
    "/philatin" => Some(0x0278)
    "/qhook" => Some(0x02A0)
    "/ramshorn" => Some(0x0264)
    "/rfishhook" => Some(0x027E)
    "/rfishhookreversed" => Some(0x027F)
    "/rhook" => Some(0x027D)
    "/rhookturned" => Some(0x027B)
    "/rlongleg" => Some(0x027C)
    "/rlonglegturned" => Some(0x027A)
    "/rturned" => Some(0x0279)
    "/schwa" => Some(0x0259)
    "/schwahook" => Some(0x025A)
    "/shook" => Some(0x0282)
    "/tccurl" => Some(0x02A8)
    "/tesh" => Some(0x02A7)
    "/tretroflexhook" => Some(0x0288)
    "/ts" => Some(0x02A6)
    "/tturned" => Some(0x0287)
    "/ubar" => Some(0x0289)
    "/upsilonlatin" => Some(0x028A)
    "/vhook" => Some(0x028B)
    "/vturned" => Some(0x028C)
    "/wturned" => Some(0x028D)
    "/yturned" => Some(0x028E)
    "/zcurl" => Some(0x0291)
    "/zretroflexhook" => Some(0x0290)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_spacing_modifier_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Rsmallinvertedsuperior" => Some(0x02B6)
    "/acutelowmod" => Some(0x02CF)
    "/afii57929" => Some(0x02BC)
    "/afii64937" => Some(0x02BD)
    "/apostrophemod" => Some(0x02BC)
    "/arrowheaddownmod" => Some(0x02C5)
    "/arrowheadleftmod" => Some(0x02C2)
    "/arrowheadrightmod" => Some(0x02C3)
    "/arrowheadupmod" => Some(0x02C4)
    "/colontriangularhalfmod" => Some(0x02D1)
    "/colontriangularmod" => Some(0x02D0)
    "/commareversedmod" => Some(0x02BD)
    "/commaturnedmod" => Some(0x02BB)
    "/dblprimemod" => Some(0x02BA)
    "/downtackmod" => Some(0x02D5)
    "/firsttonechinese" => Some(0x02C9)
    "/fourthtonechinese" => Some(0x02CB)
    "/gammasuperior" => Some(0x02E0)
    "/glottalstopmod" => Some(0x02C0)
    "/glottalstopreversedmod" => Some(0x02C1)
    "/glottalstopreversedsuperior" => Some(0x02E4)
    "/gravelowmod" => Some(0x02CE)
    "/hhooksuperior" => Some(0x02B1)
    "/hsuperior" => Some(0x02B0)
    "/ilde" => Some(0x02DC)
    "/jsuperior" => Some(0x02B2)
    "/macronlowmod" => Some(0x02CD)
    "/minusmod" => Some(0x02D7)
    "/plusmod" => Some(0x02D6)
    "/primemod" => Some(0x02B9)
    "/rhookturnedsuperior" => Some(0x02B5)
    "/rhotichookmod" => Some(0x02DE)
    "/ringhalfleft" => Some(0x02BF)
    "/ringhalfleftcentered" => Some(0x02D3)
    "/ringhalfright" => Some(0x02BE)
    "/ringhalfrightcentered" => Some(0x02D2)
    "/rturnedsuperior" => Some(0x02B4)
    "/secondtonechinese" => Some(0x02CA)
    "/tonebarextrahighmod" => Some(0x02E5)
    "/tonebarextralowmod" => Some(0x02E9)
    "/tonebarhighmod" => Some(0x02E6)
    "/tonebarlowmod" => Some(0x02E8)
    "/tonebarmidmod" => Some(0x02E7)
    "/uptackmod" => Some(0x02D4)
    "/verticallinelowmod" => Some(0x02CC)
    "/verticallinemod" => Some(0x02C8)
    "/wsuperior" => Some(0x02B7)
    "/xsuperior" => Some(0x02E3)
    "/ysuperior" => Some(0x02B8)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_combining_mark_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/acutebelowcmb" => Some(0x0317)
    "/acutecmb" => Some(0x0301)
    "/acutecomb" => Some(0x0301)
    "/acutetonecmb" => Some(0x0341)
    "/brevebelowcmb" => Some(0x032E)
    "/brevecmb" => Some(0x0306)
    "/breveinvertedbelowcmb" => Some(0x032F)
    "/breveinvertedcmb" => Some(0x0311)
    "/breveinverteddoublecmb" => Some(0x0361)
    "/bridgebelowcmb" => Some(0x032A)
    "/bridgeinvertedbelowcmb" => Some(0x033A)
    "/candrabinducmb" => Some(0x0310)
    "/caronbelowcmb" => Some(0x032C)
    "/caroncmb" => Some(0x030C)
    "/cedillacmb" => Some(0x0327)
    "/circumflexbelowcmb" => Some(0x032D)
    "/circumflexcmb" => Some(0x0302)
    "/commaabovecmb" => Some(0x0313)
    "/commaaboverightcmb" => Some(0x0315)
    "/commareversedabovecmb" => Some(0x0314)
    "/commaturnedabovecmb" => Some(0x0312)
    "/dblarchinvertedbelowcmb" => Some(0x032B)
    "/dblgravecmb" => Some(0x030F)
    "/dbllowlinecmb" => Some(0x0333)
    "/dbloverlinecmb" => Some(0x033F)
    "/dblverticallineabovecmb" => Some(0x030E)
    "/dialytikatonoscmb" => Some(0x0344)
    "/dieresisbelowcmb" => Some(0x0324)
    "/dieresiscmb" => Some(0x0308)
    "/dotaccentcmb" => Some(0x0307)
    "/dotbelowcmb" => Some(0x0323)
    "/dotbelowcomb" => Some(0x0323)
    "/downtackbelowcmb" => Some(0x031E)
    "/gravebelowcmb" => Some(0x0316)
    "/gravecmb" => Some(0x0300)
    "/gravecomb" => Some(0x0300)
    "/gravetonecmb" => Some(0x0340)
    "/hookabovecomb" => Some(0x0309)
    "/hookcmb" => Some(0x0309)
    "/hookpalatalizedbelowcmb" => Some(0x0321)
    "/hookretroflexbelowcmb" => Some(0x0322)
    "/horncmb" => Some(0x031B)
    "/hungarumlautcmb" => Some(0x030B)
    "/koroniscmb" => Some(0x0343)
    "/leftangleabovecmb" => Some(0x031A)
    "/lefttackbelowcmb" => Some(0x0318)
    "/lowlinecmb" => Some(0x0332)
    "/macronbelowcmb" => Some(0x0331)
    "/macroncmb" => Some(0x0304)
    "/minusbelowcmb" => Some(0x0320)
    "/ogonekcmb" => Some(0x0328)
    "/overlinecmb" => Some(0x0305)
    "/perispomenigreekcmb" => Some(0x0342)
    "/plusbelowcmb" => Some(0x031F)
    "/righttackbelowcmb" => Some(0x0319)
    "/ringbelowcmb" => Some(0x0325)
    "/ringcmb" => Some(0x030A)
    "/ringhalfleftbelowcmb" => Some(0x031C)
    "/ringhalfrightbelowcmb" => Some(0x0339)
    "/seagullbelowcmb" => Some(0x033C)
    "/soliduslongoverlaycmb" => Some(0x0338)
    "/solidusshortoverlaycmb" => Some(0x0337)
    "/squarebelowcmb" => Some(0x033B)
    "/strokelongoverlaycmb" => Some(0x0336)
    "/strokeshortoverlaycmb" => Some(0x0335)
    "/tildebelowcmb" => Some(0x0330)
    "/tildecmb" => Some(0x0303)
    "/tildecomb" => Some(0x0303)
    "/tildedoublecmb" => Some(0x0360)
    "/tildeoverlaycmb" => Some(0x0334)
    "/tildeverticalcmb" => Some(0x033E)
    "/uptackbelowcmb" => Some(0x031D)
    "/verticallineabovecmb" => Some(0x030D)
    "/verticallinebelowcmb" => Some(0x0329)
    "/xabovecmb" => Some(0x033D)
    "/ypogegrammenigreekcmb" => Some(0x0345)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_currency_letterlike_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/afii08941" => Some(0x20A4)
    "/afii57636" => Some(0x20AA)
    "/colonsign" => Some(0x20A1)
    "/cruzeiro" => Some(0x20A2)
    "/dong" => Some(0x20AB)
    "/euro" => Some(0x20AC)
    "/franc" => Some(0x20A3)
    "/lira" => Some(0x20A4)
    "/newsheqelsign" => Some(0x20AA)
    "/peseta" => Some(0x20A7)
    "/sheqel" => Some(0x20AA)
    "/sheqelhebrew" => Some(0x20AA)
    "/won" => Some(0x20A9)
    "/Ohm" => Some(0x2126)
    "/afii61248" => Some(0x2105)
    "/afii61289" => Some(0x2113)
    "/afii61352" => Some(0x2116)
    "/angstrom" => Some(0x212B)
    "/careof" => Some(0x2105)
    "/centigrade" => Some(0x2103)
    "/estimated" => Some(0x212E)
    "/fahrenheit" => Some(0x2109)
    "/lsquare" => Some(0x2113)
    "/numero" => Some(0x2116)
    "/prescription" => Some(0x211E)
    "/telephone" => Some(0x2121)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_arrow_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/arrowdashdown" => Some(0x21E3)
    "/arrowdashleft" => Some(0x21E0)
    "/arrowdashright" => Some(0x21E2)
    "/arrowdashup" => Some(0x21E1)
    "/arrowdownleft" => Some(0x2199)
    "/arrowdownright" => Some(0x2198)
    "/arrowdownwhite" => Some(0x21E9)
    "/arrowleftdbl" => Some(0x21D0)
    "/arrowleftdblstroke" => Some(0x21CD)
    "/arrowleftoverright" => Some(0x21C6)
    "/arrowleftwhite" => Some(0x21E6)
    "/arrowrightdblstroke" => Some(0x21CF)
    "/arrowrightoverleft" => Some(0x21C4)
    "/arrowrightwhite" => Some(0x21E8)
    "/arrowtableft" => Some(0x21E4)
    "/arrowtabright" => Some(0x21E5)
    "/arrowupdn" => Some(0x2195)
    "/arrowupdnbse" => Some(0x21A8)
    "/arrowupdownbase" => Some(0x21A8)
    "/arrowupleft" => Some(0x2196)
    "/arrowupleftofdown" => Some(0x21C5)
    "/arrowupright" => Some(0x2197)
    "/arrowupwhite" => Some(0x21E7)
    "/capslock" => Some(0x21EA)
    "/dblarrowleft" => Some(0x21D4)
    "/dblarrowright" => Some(0x21D2)
    "/harpoonleftbarbup" => Some(0x21BC)
    "/harpoonrightbarbup" => Some(0x21C0)
    "/pagedown" => Some(0x21DF)
    "/pageup" => Some(0x21DE)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_greek_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Alphatonos" => Some(0x0386)
    "/Deicoptic" => Some(0x03EE)
    "/Deltagreek" => Some(0x0394)
    "/Digammagreek" => Some(0x03DC)
    "/Epsilontonos" => Some(0x0388)
    "/Etatonos" => Some(0x0389)
    "/Feicoptic" => Some(0x03E4)
    "/Gangiacoptic" => Some(0x03EA)
    "/Horicoptic" => Some(0x03E8)
    "/Iotadieresis" => Some(0x03AA)
    "/Iotatonos" => Some(0x038A)
    "/Kheicoptic" => Some(0x03E6)
    "/Koppagreek" => Some(0x03DE)
    "/Omegagreek" => Some(0x03A9)
    "/Omegatonos" => Some(0x038F)
    "/Omicrontonos" => Some(0x038C)
    "/Sampigreek" => Some(0x03E0)
    "/Sheicoptic" => Some(0x03E2)
    "/Shimacoptic" => Some(0x03EC)
    "/Stigmagreek" => Some(0x03DA)
    "/Upsilonacutehooksymbolgreek" => Some(0x03D3)
    "/Upsilondieresis" => Some(0x03AB)
    "/Upsilondieresishooksymbolgreek" => Some(0x03D4)
    "/Upsilonhooksymbol" => Some(0x03D2)
    "/Upsilontonos" => Some(0x038E)
    "/alphatonos" => Some(0x03AC)
    "/anoteleia" => Some(0x0387)
    "/betasymbolgreek" => Some(0x03D0)
    "/deicoptic" => Some(0x03EF)
    "/dialytikatonos" => Some(0x0385)
    "/dieresistonos" => Some(0x0385)
    "/epsilontonos" => Some(0x03AD)
    "/etatonos" => Some(0x03AE)
    "/feicoptic" => Some(0x03E5)
    "/gangiacoptic" => Some(0x03EB)
    "/horicoptic" => Some(0x03E9)
    "/iotadieresis" => Some(0x03CA)
    "/iotadieresistonos" => Some(0x0390)
    "/iotatonos" => Some(0x03AF)
    "/kappasymbolgreek" => Some(0x03F0)
    "/kheicoptic" => Some(0x03E7)
    "/mugreek" => Some(0x03BC)
    "/numeralsigngreek" => Some(0x0374)
    "/numeralsignlowergreek" => Some(0x0375)
    "/omegatonos" => Some(0x03CE)
    "/omicrontonos" => Some(0x03CC)
    "/phisymbolgreek" => Some(0x03D5)
    "/pisymbolgreek" => Some(0x03D6)
    "/questiongreek" => Some(0x037E)
    "/rhosymbolgreek" => Some(0x03F1)
    "/sheicoptic" => Some(0x03E3)
    "/shimacoptic" => Some(0x03ED)
    "/sigmafinal" => Some(0x03C2)
    "/sigmalunatesymbolgreek" => Some(0x03F2)
    "/thetasymbolgreek" => Some(0x03D1)
    "/tonos" => Some(0x0384)
    "/upsilondieresis" => Some(0x03CB)
    "/upsilondieresistonos" => Some(0x03B0)
    "/upsilontonos" => Some(0x03CD)
    "/yotgreek" => Some(0x03F3)
    "/ypogegrammeni" => Some(0x037A)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_armenian_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Aybarmenian" => Some(0x0531)
    "/Benarmenian" => Some(0x0532)
    "/Caarmenian" => Some(0x053E)
    "/Chaarmenian" => Some(0x0549)
    "/Cheharmenian" => Some(0x0543)
    "/Coarmenian" => Some(0x0551)
    "/Daarmenian" => Some(0x0534)
    "/Echarmenian" => Some(0x0535)
    "/Eharmenian" => Some(0x0537)
    "/Etarmenian" => Some(0x0538)
    "/Feharmenian" => Some(0x0556)
    "/Ghadarmenian" => Some(0x0542)
    "/Gimarmenian" => Some(0x0533)
    "/Hoarmenian" => Some(0x0540)
    "/Iniarmenian" => Some(0x053B)
    "/Jaarmenian" => Some(0x0541)
    "/Jheharmenian" => Some(0x054B)
    "/Keharmenian" => Some(0x0554)
    "/Kenarmenian" => Some(0x053F)
    "/Liwnarmenian" => Some(0x053C)
    "/Menarmenian" => Some(0x0544)
    "/Nowarmenian" => Some(0x0546)
    "/Oharmenian" => Some(0x0555)
    "/Peharmenian" => Some(0x054A)
    "/Piwrarmenian" => Some(0x0553)
    "/Raarmenian" => Some(0x054C)
    "/Reharmenian" => Some(0x0550)
    "/Seharmenian" => Some(0x054D)
    "/Shaarmenian" => Some(0x0547)
    "/Tiwnarmenian" => Some(0x054F)
    "/Toarmenian" => Some(0x0539)
    "/Vewarmenian" => Some(0x054E)
    "/Voarmenian" => Some(0x0548)
    "/Xeharmenian" => Some(0x053D)
    "/Yiarmenian" => Some(0x0545)
    "/Yiwnarmenian" => Some(0x0552)
    "/Zaarmenian" => Some(0x0536)
    "/Zhearmenian" => Some(0x053A)
    "/abbreviationmarkarmenian" => Some(0x055F)
    "/apostrophearmenian" => Some(0x055A)
    "/aybarmenian" => Some(0x0561)
    "/benarmenian" => Some(0x0562)
    "/caarmenian" => Some(0x056E)
    "/chaarmenian" => Some(0x0579)
    "/cheharmenian" => Some(0x0573)
    "/coarmenian" => Some(0x0581)
    "/commaarmenian" => Some(0x055D)
    "/daarmenian" => Some(0x0564)
    "/echarmenian" => Some(0x0565)
    "/echyiwnarmenian" => Some(0x0587)
    "/eharmenian" => Some(0x0567)
    "/emphasismarkarmenian" => Some(0x055B)
    "/etarmenian" => Some(0x0568)
    "/exclamarmenian" => Some(0x055C)
    "/feharmenian" => Some(0x0586)
    "/ghadarmenian" => Some(0x0572)
    "/gimarmenian" => Some(0x0563)
    "/hoarmenian" => Some(0x0570)
    "/iniarmenian" => Some(0x056B)
    "/jaarmenian" => Some(0x0571)
    "/jheharmenian" => Some(0x057B)
    "/keharmenian" => Some(0x0584)
    "/kenarmenian" => Some(0x056F)
    "/liwnarmenian" => Some(0x056C)
    "/menarmenian" => Some(0x0574)
    "/nowarmenian" => Some(0x0576)
    "/oharmenian" => Some(0x0585)
    "/peharmenian" => Some(0x057A)
    "/periodarmenian" => Some(0x0589)
    "/piwrarmenian" => Some(0x0583)
    "/questionarmenian" => Some(0x055E)
    "/raarmenian" => Some(0x057C)
    "/reharmenian" => Some(0x0580)
    "/ringhalfleftarmenian" => Some(0x0559)
    "/seharmenian" => Some(0x057D)
    "/shaarmenian" => Some(0x0577)
    "/tiwnarmenian" => Some(0x057F)
    "/toarmenian" => Some(0x0569)
    "/vewarmenian" => Some(0x057E)
    "/voarmenian" => Some(0x0578)
    "/xeharmenian" => Some(0x056D)
    "/yiarmenian" => Some(0x0575)
    "/yiwnarmenian" => Some(0x0582)
    "/zaarmenian" => Some(0x0566)
    "/zhearmenian" => Some(0x056A)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_devanagari_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/aadeva" => Some(0x0906)
    "/aavowelsigndeva" => Some(0x093E)
    "/abbreviationsigndeva" => Some(0x0970)
    "/acutedeva" => Some(0x0954)
    "/adeva" => Some(0x0905)
    "/aideva" => Some(0x0910)
    "/aivowelsigndeva" => Some(0x0948)
    "/anudattadeva" => Some(0x0952)
    "/anusvaradeva" => Some(0x0902)
    "/audeva" => Some(0x0914)
    "/auvowelsigndeva" => Some(0x094C)
    "/avagrahadeva" => Some(0x093D)
    "/badeva" => Some(0x092C)
    "/bhadeva" => Some(0x092D)
    "/cadeva" => Some(0x091A)
    "/candrabindudeva" => Some(0x0901)
    "/chadeva" => Some(0x091B)
    "/dadeva" => Some(0x0926)
    "/danda" => Some(0x0964)
    "/dbldanda" => Some(0x0965)
    "/ddadeva" => Some(0x0921)
    "/dddhadeva" => Some(0x095C)
    "/ddhadeva" => Some(0x0922)
    "/dhadeva" => Some(0x0927)
    "/ecandradeva" => Some(0x090D)
    "/ecandravowelsigndeva" => Some(0x0945)
    "/edeva" => Some(0x090F)
    "/eightdeva" => Some(0x096E)
    "/eshortdeva" => Some(0x090E)
    "/eshortvowelsigndeva" => Some(0x0946)
    "/evowelsigndeva" => Some(0x0947)
    "/fadeva" => Some(0x095E)
    "/fivedeva" => Some(0x096B)
    "/fourdeva" => Some(0x096A)
    "/gadeva" => Some(0x0917)
    "/ghadeva" => Some(0x0918)
    "/ghhadeva" => Some(0x095A)
    "/gravedeva" => Some(0x0953)
    "/hadeva" => Some(0x0939)
    "/ideva" => Some(0x0907)
    "/iideva" => Some(0x0908)
    "/iivowelsigndeva" => Some(0x0940)
    "/ivowelsigndeva" => Some(0x093F)
    "/jadeva" => Some(0x091C)
    "/jhadeva" => Some(0x091D)
    "/kadeva" => Some(0x0915)
    "/khadeva" => Some(0x0916)
    "/khhadeva" => Some(0x0959)
    "/ladeva" => Some(0x0932)
    "/lladeva" => Some(0x0933)
    "/llladeva" => Some(0x0934)
    "/llvocalicdeva" => Some(0x0961)
    "/llvocalicvowelsigndeva" => Some(0x0963)
    "/lvocalicdeva" => Some(0x090C)
    "/lvocalicvowelsigndeva" => Some(0x0962)
    "/madeva" => Some(0x092E)
    "/nadeva" => Some(0x0928)
    "/ngadeva" => Some(0x0919)
    "/ninedeva" => Some(0x096F)
    "/nnadeva" => Some(0x0923)
    "/nnnadeva" => Some(0x0929)
    "/nuktadeva" => Some(0x093C)
    "/nyadeva" => Some(0x091E)
    "/ocandradeva" => Some(0x0911)
    "/ocandravowelsigndeva" => Some(0x0949)
    "/odeva" => Some(0x0913)
    "/omdeva" => Some(0x0950)
    "/onedeva" => Some(0x0967)
    "/oshortdeva" => Some(0x0912)
    "/oshortvowelsigndeva" => Some(0x094A)
    "/ovowelsigndeva" => Some(0x094B)
    "/padeva" => Some(0x092A)
    "/phadeva" => Some(0x092B)
    "/qadeva" => Some(0x0958)
    "/radeva" => Some(0x0930)
    "/rhadeva" => Some(0x095D)
    "/rradeva" => Some(0x0931)
    "/rrvocalicdeva" => Some(0x0960)
    "/rrvocalicvowelsigndeva" => Some(0x0944)
    "/rvocalicdeva" => Some(0x090B)
    "/rvocalicvowelsigndeva" => Some(0x0943)
    "/sadeva" => Some(0x0938)
    "/sevendeva" => Some(0x096D)
    "/shadeva" => Some(0x0936)
    "/sixdeva" => Some(0x096C)
    "/ssadeva" => Some(0x0937)
    "/tadeva" => Some(0x0924)
    "/thadeva" => Some(0x0925)
    "/threedeva" => Some(0x0969)
    "/ttadeva" => Some(0x091F)
    "/tthadeva" => Some(0x0920)
    "/twodeva" => Some(0x0968)
    "/udattadeva" => Some(0x0951)
    "/udeva" => Some(0x0909)
    "/uudeva" => Some(0x090A)
    "/uuvowelsigndeva" => Some(0x0942)
    "/uvowelsigndeva" => Some(0x0941)
    "/vadeva" => Some(0x0935)
    "/viramadeva" => Some(0x094D)
    "/visargadeva" => Some(0x0903)
    "/yadeva" => Some(0x092F)
    "/yyadeva" => Some(0x095F)
    "/zadeva" => Some(0x095B)
    "/zerodeva" => Some(0x0966)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_thai_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/angkhankhuthai" => Some(0x0E5A)
    "/bahtthai" => Some(0x0E3F)
    "/bobaimaithai" => Some(0x0E1A)
    "/chochangthai" => Some(0x0E0A)
    "/chochanthai" => Some(0x0E08)
    "/chochingthai" => Some(0x0E09)
    "/chochoethai" => Some(0x0E0C)
    "/dochadathai" => Some(0x0E0E)
    "/dodekthai" => Some(0x0E14)
    "/eightthai" => Some(0x0E58)
    "/fivethai" => Some(0x0E55)
    "/fofanthai" => Some(0x0E1F)
    "/fofathai" => Some(0x0E1D)
    "/fongmanthai" => Some(0x0E4F)
    "/fourthai" => Some(0x0E54)
    "/hohipthai" => Some(0x0E2B)
    "/honokhukthai" => Some(0x0E2E)
    "/khokhaithai" => Some(0x0E02)
    "/khokhonthai" => Some(0x0E05)
    "/khokhuatthai" => Some(0x0E03)
    "/khokhwaithai" => Some(0x0E04)
    "/khomutthai" => Some(0x0E5B)
    "/khorakhangthai" => Some(0x0E06)
    "/kokaithai" => Some(0x0E01)
    "/lakkhangyaothai" => Some(0x0E45)
    "/lochulathai" => Some(0x0E2C)
    "/lolingthai" => Some(0x0E25)
    "/luthai" => Some(0x0E26)
    "/maichattawathai" => Some(0x0E4B)
    "/maiekthai" => Some(0x0E48)
    "/maihanakatthai" => Some(0x0E31)
    "/maitaikhuthai" => Some(0x0E47)
    "/maithothai" => Some(0x0E49)
    "/maitrithai" => Some(0x0E4A)
    "/maiyamokthai" => Some(0x0E46)
    "/momathai" => Some(0x0E21)
    "/ngonguthai" => Some(0x0E07)
    "/nikhahitthai" => Some(0x0E4D)
    "/ninethai" => Some(0x0E59)
    "/nonenthai" => Some(0x0E13)
    "/nonuthai" => Some(0x0E19)
    "/oangthai" => Some(0x0E2D)
    "/onethai" => Some(0x0E51)
    "/paiyannoithai" => Some(0x0E2F)
    "/phinthuthai" => Some(0x0E3A)
    "/phophanthai" => Some(0x0E1E)
    "/phophungthai" => Some(0x0E1C)
    "/phosamphaothai" => Some(0x0E20)
    "/poplathai" => Some(0x0E1B)
    "/roruathai" => Some(0x0E23)
    "/ruthai" => Some(0x0E24)
    "/saraaathai" => Some(0x0E32)
    "/saraaethai" => Some(0x0E41)
    "/saraaimaimalaithai" => Some(0x0E44)
    "/saraaimaimuanthai" => Some(0x0E43)
    "/saraamthai" => Some(0x0E33)
    "/saraathai" => Some(0x0E30)
    "/saraethai" => Some(0x0E40)
    "/saraiithai" => Some(0x0E35)
    "/saraithai" => Some(0x0E34)
    "/saraothai" => Some(0x0E42)
    "/saraueethai" => Some(0x0E37)
    "/sarauethai" => Some(0x0E36)
    "/sarauthai" => Some(0x0E38)
    "/sarauuthai" => Some(0x0E39)
    "/seventhai" => Some(0x0E57)
    "/sixthai" => Some(0x0E56)
    "/sorusithai" => Some(0x0E29)
    "/sosalathai" => Some(0x0E28)
    "/sosothai" => Some(0x0E0B)
    "/sosuathai" => Some(0x0E2A)
    "/thanthakhatthai" => Some(0x0E4C)
    "/thonangmonthothai" => Some(0x0E11)
    "/thophuthaothai" => Some(0x0E12)
    "/thothahanthai" => Some(0x0E17)
    "/thothanthai" => Some(0x0E10)
    "/thothongthai" => Some(0x0E18)
    "/thothungthai" => Some(0x0E16)
    "/threethai" => Some(0x0E53)
    "/topatakthai" => Some(0x0E0F)
    "/totaothai" => Some(0x0E15)
    "/twothai" => Some(0x0E52)
    "/wowaenthai" => Some(0x0E27)
    "/yamakkanthai" => Some(0x0E4E)
    "/yoyakthai" => Some(0x0E22)
    "/yoyingthai" => Some(0x0E0D)
    "/zerothai" => Some(0x0E50)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_math_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/allequal" => Some(0x224C)
    "/approaches" => Some(0x2250)
    "/approxequalorimage" => Some(0x2252)
    "/approximatelyequal" => Some(0x2245)
    "/asteriskmath" => Some(0x2217)
    "/asymptoticallyequal" => Some(0x2243)
    "/because" => Some(0x2235)
    "/bulletoperator" => Some(0x2219)
    "/circleot" => Some(0x2299)
    "/contourintegral" => Some(0x222E)
    "/curlyand" => Some(0x22CF)
    "/curlyor" => Some(0x22CE)
    "/dblintegral" => Some(0x222C)
    "/divides" => Some(0x2223)
    "/divisionslash" => Some(0x2215)
    "/ellipsisvertical" => Some(0x22EE)
    "/forall" => Some(0x2200)
    "/geometricallyequal" => Some(0x2251)
    "/greaterequalorless" => Some(0x22DB)
    "/greaterorequivalent" => Some(0x2273)
    "/greaterorless" => Some(0x2277)
    "/greateroverequal" => Some(0x2267)
    "/imageorapproximatelyequal" => Some(0x2253)
    "/increment" => Some(0x2206)
    "/lessequalorgreater" => Some(0x22DA)
    "/lessorequivalent" => Some(0x2272)
    "/lessorgreater" => Some(0x2276)
    "/lessoverequal" => Some(0x2266)
    "/minus" => Some(0x2212)
    "/minuscircle" => Some(0x2296)
    "/minusplus" => Some(0x2213)
    "/muchgreater" => Some(0x226B)
    "/muchless" => Some(0x226A)
    "/nabla" => Some(0x2207)
    "/notcontains" => Some(0x220C)
    "/notelementof" => Some(0x2209)
    "/notgreater" => Some(0x226F)
    "/notgreaternorequal" => Some(0x2271)
    "/notgreaternorless" => Some(0x2279)
    "/notidentical" => Some(0x2262)
    "/notless" => Some(0x226E)
    "/notlessnorequal" => Some(0x2270)
    "/notparallel" => Some(0x2226)
    "/notprecedes" => Some(0x2280)
    "/notsucceeds" => Some(0x2281)
    "/notsuperset" => Some(0x2285)
    "/orthogonal" => Some(0x221F)
    "/parallel" => Some(0x2225)
    "/pluscircle" => Some(0x2295)
    "/precedes" => Some(0x227A)
    "/proportion" => Some(0x2237)
    "/ratio" => Some(0x2236)
    "/reversedtilde" => Some(0x223D)
    "/rightangle" => Some(0x221F)
    "/righttriangle" => Some(0x22BF)
    "/subset" => Some(0x2282)
    "/subsetnotequal" => Some(0x228A)
    "/subsetorequal" => Some(0x2286)
    "/succeeds" => Some(0x227B)
    "/superset" => Some(0x2283)
    "/supersetnotequal" => Some(0x228B)
    "/supersetorequal" => Some(0x2287)
    "/tackdown" => Some(0x22A4)
    "/tackleft" => Some(0x22A3)
    "/thereexists" => Some(0x2203)
    "/tildeoperator" => Some(0x223C)
    "/timescircle" => Some(0x2297)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_number_form_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Oneroman" => Some(0x2160)
    "/Tworoman" => Some(0x2161)
    "/Threeroman" => Some(0x2162)
    "/Fourroman" => Some(0x2163)
    "/Fiveroman" => Some(0x2164)
    "/Sixroman" => Some(0x2165)
    "/Sevenroman" => Some(0x2166)
    "/Eightroman" => Some(0x2167)
    "/Nineroman" => Some(0x2168)
    "/Tenroman" => Some(0x2169)
    "/Elevenroman" => Some(0x216A)
    "/Twelveroman" => Some(0x216B)
    "/oneroman" => Some(0x2170)
    "/tworoman" => Some(0x2171)
    "/threeroman" => Some(0x2172)
    "/fourroman" => Some(0x2173)
    "/fiveroman" => Some(0x2174)
    "/sixroman" => Some(0x2175)
    "/sevenroman" => Some(0x2176)
    "/eightroman" => Some(0x2177)
    "/nineroman" => Some(0x2178)
    "/tenroman" => Some(0x2179)
    "/elevenroman" => Some(0x217A)
    "/twelveroman" => Some(0x217B)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_technical_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/arc" => Some(0x2312)
    "/clear" => Some(0x2327)
    "/control" => Some(0x2303)
    "/deleteleft" => Some(0x232B)
    "/deleteright" => Some(0x2326)
    "/house" => Some(0x2302)
    "/integralbottom" => Some(0x2321)
    "/integraltop" => Some(0x2320)
    "/logicalnotreversed" => Some(0x2310)
    "/option" => Some(0x2325)
    "/projective" => Some(0x2305)
    "/propellor" => Some(0x2318)
    "/revlogicalnot" => Some(0x2310)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_enclosed_alnum_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Acircle" => Some(0x24B6)
    "/Bcircle" => Some(0x24B7)
    "/Ccircle" => Some(0x24B8)
    "/Dcircle" => Some(0x24B9)
    "/Ecircle" => Some(0x24BA)
    "/Fcircle" => Some(0x24BB)
    "/Gcircle" => Some(0x24BC)
    "/Hcircle" => Some(0x24BD)
    "/Icircle" => Some(0x24BE)
    "/Jcircle" => Some(0x24BF)
    "/Kcircle" => Some(0x24C0)
    "/Lcircle" => Some(0x24C1)
    "/Mcircle" => Some(0x24C2)
    "/Ncircle" => Some(0x24C3)
    "/Ocircle" => Some(0x24C4)
    "/Pcircle" => Some(0x24C5)
    "/Qcircle" => Some(0x24C6)
    "/Rcircle" => Some(0x24C7)
    "/Scircle" => Some(0x24C8)
    "/Tcircle" => Some(0x24C9)
    "/Ucircle" => Some(0x24CA)
    "/Vcircle" => Some(0x24CB)
    "/Wcircle" => Some(0x24CC)
    "/Xcircle" => Some(0x24CD)
    "/Ycircle" => Some(0x24CE)
    "/Zcircle" => Some(0x24CF)
    "/acircle" => Some(0x24D0)
    "/aparen" => Some(0x249C)
    "/bcircle" => Some(0x24D1)
    "/bparen" => Some(0x249D)
    "/ccircle" => Some(0x24D2)
    "/cparen" => Some(0x249E)
    "/dcircle" => Some(0x24D3)
    "/dparen" => Some(0x249F)
    "/ecircle" => Some(0x24D4)
    "/eightcircle" => Some(0x2467)
    "/eighteencircle" => Some(0x2471)
    "/eighteenparen" => Some(0x2485)
    "/eighteenperiod" => Some(0x2499)
    "/eightparen" => Some(0x247B)
    "/eightperiod" => Some(0x248F)
    "/elevencircle" => Some(0x246A)
    "/elevenparen" => Some(0x247E)
    "/elevenperiod" => Some(0x2492)
    "/eparen" => Some(0x24A0)
    "/fcircle" => Some(0x24D5)
    "/fifteencircle" => Some(0x246E)
    "/fifteenparen" => Some(0x2482)
    "/fifteenperiod" => Some(0x2496)
    "/fivecircle" => Some(0x2464)
    "/fiveparen" => Some(0x2478)
    "/fiveperiod" => Some(0x248C)
    "/fourcircle" => Some(0x2463)
    "/fourparen" => Some(0x2477)
    "/fourperiod" => Some(0x248B)
    "/fourteencircle" => Some(0x246D)
    "/fourteenparen" => Some(0x2481)
    "/fourteenperiod" => Some(0x2495)
    "/fparen" => Some(0x24A1)
    "/gcircle" => Some(0x24D6)
    "/gparen" => Some(0x24A2)
    "/hcircle" => Some(0x24D7)
    "/hparen" => Some(0x24A3)
    "/icircle" => Some(0x24D8)
    "/iparen" => Some(0x24A4)
    "/jcircle" => Some(0x24D9)
    "/jparen" => Some(0x24A5)
    "/kcircle" => Some(0x24DA)
    "/kparen" => Some(0x24A6)
    "/lcircle" => Some(0x24DB)
    "/lparen" => Some(0x24A7)
    "/mcircle" => Some(0x24DC)
    "/mparen" => Some(0x24A8)
    "/ncircle" => Some(0x24DD)
    "/ninecircle" => Some(0x2468)
    "/nineparen" => Some(0x247C)
    "/nineperiod" => Some(0x2490)
    "/nineteencircle" => Some(0x2472)
    "/nineteenparen" => Some(0x2486)
    "/nineteenperiod" => Some(0x249A)
    "/nparen" => Some(0x24A9)
    "/ocircle" => Some(0x24DE)
    "/onecircle" => Some(0x2460)
    "/oneparen" => Some(0x2474)
    "/oneperiod" => Some(0x2488)
    "/oparen" => Some(0x24AA)
    "/pcircle" => Some(0x24DF)
    "/pparen" => Some(0x24AB)
    "/qcircle" => Some(0x24E0)
    "/qparen" => Some(0x24AC)
    "/rcircle" => Some(0x24E1)
    "/rparen" => Some(0x24AD)
    "/scircle" => Some(0x24E2)
    "/sevencircle" => Some(0x2466)
    "/sevenparen" => Some(0x247A)
    "/sevenperiod" => Some(0x248E)
    "/seventeencircle" => Some(0x2470)
    "/seventeenparen" => Some(0x2484)
    "/seventeenperiod" => Some(0x2498)
    "/sixcircle" => Some(0x2465)
    "/sixparen" => Some(0x2479)
    "/sixperiod" => Some(0x248D)
    "/sixteencircle" => Some(0x246F)
    "/sixteenparen" => Some(0x2483)
    "/sixteenperiod" => Some(0x2497)
    "/sparen" => Some(0x24AE)
    "/tcircle" => Some(0x24E3)
    "/tencircle" => Some(0x2469)
    "/tenparen" => Some(0x247D)
    "/tenperiod" => Some(0x2491)
    "/thirteencircle" => Some(0x246C)
    "/thirteenparen" => Some(0x2480)
    "/thirteenperiod" => Some(0x2494)
    "/threecircle" => Some(0x2462)
    "/threeparen" => Some(0x2476)
    "/threeperiod" => Some(0x248A)
    "/tparen" => Some(0x24AF)
    "/twelvecircle" => Some(0x246B)
    "/twelveparen" => Some(0x247F)
    "/twelveperiod" => Some(0x2493)
    "/twentycircle" => Some(0x2473)
    "/twentyparen" => Some(0x2487)
    "/twentyperiod" => Some(0x249B)
    "/twocircle" => Some(0x2461)
    "/twoparen" => Some(0x2475)
    "/twoperiod" => Some(0x2489)
    "/ucircle" => Some(0x24E4)
    "/uparen" => Some(0x24B0)
    "/vcircle" => Some(0x24E5)
    "/vparen" => Some(0x24B1)
    "/wcircle" => Some(0x24E6)
    "/wparen" => Some(0x24B2)
    "/xcircle" => Some(0x24E7)
    "/xparen" => Some(0x24B3)
    "/ycircle" => Some(0x24E8)
    "/yparen" => Some(0x24B4)
    "/zcircle" => Some(0x24E9)
    "/zparen" => Some(0x24B5)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_cjk_symbol_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/anglebracketleft" => Some(0x3008)
    "/anglebracketright" => Some(0x3009)
    "/blacklenticularbracketleft" => Some(0x3010)
    "/blacklenticularbracketright" => Some(0x3011)
    "/circlepostalmark" => Some(0x3036)
    "/cornerbracketleft" => Some(0x300C)
    "/cornerbracketright" => Some(0x300D)
    "/dblanglebracketleft" => Some(0x300A)
    "/dblanglebracketright" => Some(0x300B)
    "/dittomark" => Some(0x3003)
    "/eighthangzhou" => Some(0x3028)
    "/fivehangzhou" => Some(0x3025)
    "/fourhangzhou" => Some(0x3024)
    "/getamark" => Some(0x3013)
    "/ideographicclose" => Some(0x3006)
    "/ideographiccomma" => Some(0x3001)
    "/ideographiciterationmark" => Some(0x3005)
    "/ideographicperiod" => Some(0x3002)
    "/ideographicspace" => Some(0x3000)
    "/ideographiczero" => Some(0x3007)
    "/jis" => Some(0x3004)
    "/ninehangzhou" => Some(0x3029)
    "/onehangzhou" => Some(0x3021)
    "/postalmark" => Some(0x3012)
    "/postalmarkface" => Some(0x3020)
    "/quotedblprime" => Some(0x301E)
    "/quotedblprimereversed" => Some(0x301D)
    "/sevenhangzhou" => Some(0x3027)
    "/sixhangzhou" => Some(0x3026)
    "/threehangzhou" => Some(0x3023)
    "/tortoiseshellbracketleft" => Some(0x3014)
    "/tortoiseshellbracketright" => Some(0x3015)
    "/twentyhangzhou" => Some(0x5344)
    "/twohangzhou" => Some(0x3022)
    "/wavedash" => Some(0x301C)
    "/whitecornerbracketleft" => Some(0x300E)
    "/whitecornerbracketright" => Some(0x300F)
    "/whitelenticularbracketleft" => Some(0x3016)
    "/whitelenticularbracketright" => Some(0x3017)
    "/whitetortoiseshellbracketleft" => Some(0x3018)
    "/whitetortoiseshellbracketright" => Some(0x3019)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_hiragana_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/ahiragana" => Some(0x3042)
    "/asmallhiragana" => Some(0x3041)
    "/bahiragana" => Some(0x3070)
    "/behiragana" => Some(0x3079)
    "/bihiragana" => Some(0x3073)
    "/bohiragana" => Some(0x307C)
    "/buhiragana" => Some(0x3076)
    "/dahiragana" => Some(0x3060)
    "/dehiragana" => Some(0x3067)
    "/dihiragana" => Some(0x3062)
    "/dohiragana" => Some(0x3069)
    "/duhiragana" => Some(0x3065)
    "/ehiragana" => Some(0x3048)
    "/esmallhiragana" => Some(0x3047)
    "/gahiragana" => Some(0x304C)
    "/gehiragana" => Some(0x3052)
    "/gihiragana" => Some(0x304E)
    "/gohiragana" => Some(0x3054)
    "/guhiragana" => Some(0x3050)
    "/hahiragana" => Some(0x306F)
    "/hehiragana" => Some(0x3078)
    "/hihiragana" => Some(0x3072)
    "/hohiragana" => Some(0x307B)
    "/huhiragana" => Some(0x3075)
    "/ihiragana" => Some(0x3044)
    "/ismallhiragana" => Some(0x3043)
    "/iterationhiragana" => Some(0x309D)
    "/kahiragana" => Some(0x304B)
    "/kehiragana" => Some(0x3051)
    "/kihiragana" => Some(0x304D)
    "/kohiragana" => Some(0x3053)
    "/kuhiragana" => Some(0x304F)
    "/mahiragana" => Some(0x307E)
    "/mehiragana" => Some(0x3081)
    "/mihiragana" => Some(0x307F)
    "/mohiragana" => Some(0x3082)
    "/muhiragana" => Some(0x3080)
    "/nahiragana" => Some(0x306A)
    "/nehiragana" => Some(0x306D)
    "/nhiragana" => Some(0x3093)
    "/nihiragana" => Some(0x306B)
    "/nohiragana" => Some(0x306E)
    "/nuhiragana" => Some(0x306C)
    "/ohiragana" => Some(0x304A)
    "/osmallhiragana" => Some(0x3049)
    "/pahiragana" => Some(0x3071)
    "/pehiragana" => Some(0x307A)
    "/pihiragana" => Some(0x3074)
    "/pohiragana" => Some(0x307D)
    "/puhiragana" => Some(0x3077)
    "/rahiragana" => Some(0x3089)
    "/rehiragana" => Some(0x308C)
    "/rihiragana" => Some(0x308A)
    "/rohiragana" => Some(0x308D)
    "/ruhiragana" => Some(0x308B)
    "/sahiragana" => Some(0x3055)
    "/sehiragana" => Some(0x305B)
    "/semivoicedmarkkana" => Some(0x309C)
    "/sihiragana" => Some(0x3057)
    "/sohiragana" => Some(0x305D)
    "/suhiragana" => Some(0x3059)
    "/tahiragana" => Some(0x305F)
    "/tehiragana" => Some(0x3066)
    "/tihiragana" => Some(0x3061)
    "/tohiragana" => Some(0x3068)
    "/tuhiragana" => Some(0x3064)
    "/tusmallhiragana" => Some(0x3063)
    "/uhiragana" => Some(0x3046)
    "/usmallhiragana" => Some(0x3045)
    "/voicediterationhiragana" => Some(0x309E)
    "/voicedmarkkana" => Some(0x309B)
    "/vuhiragana" => Some(0x3094)
    "/wahiragana" => Some(0x308F)
    "/wasmallhiragana" => Some(0x308E)
    "/wehiragana" => Some(0x3091)
    "/wihiragana" => Some(0x3090)
    "/wohiragana" => Some(0x3092)
    "/yahiragana" => Some(0x3084)
    "/yasmallhiragana" => Some(0x3083)
    "/yohiragana" => Some(0x3088)
    "/yosmallhiragana" => Some(0x3087)
    "/yuhiragana" => Some(0x3086)
    "/yusmallhiragana" => Some(0x3085)
    "/zahiragana" => Some(0x3056)
    "/zehiragana" => Some(0x305C)
    "/zihiragana" => Some(0x3058)
    "/zohiragana" => Some(0x305E)
    "/zuhiragana" => Some(0x305A)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_katakana_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/akatakana" => Some(0x30A2)
    "/asmallkatakana" => Some(0x30A1)
    "/bakatakana" => Some(0x30D0)
    "/bekatakana" => Some(0x30D9)
    "/bikatakana" => Some(0x30D3)
    "/bokatakana" => Some(0x30DC)
    "/bukatakana" => Some(0x30D6)
    "/dakatakana" => Some(0x30C0)
    "/dekatakana" => Some(0x30C7)
    "/dikatakana" => Some(0x30C2)
    "/dokatakana" => Some(0x30C9)
    "/dotkatakana" => Some(0x30FB)
    "/dukatakana" => Some(0x30C5)
    "/ekatakana" => Some(0x30A8)
    "/esmallkatakana" => Some(0x30A7)
    "/gakatakana" => Some(0x30AC)
    "/gekatakana" => Some(0x30B2)
    "/gikatakana" => Some(0x30AE)
    "/gokatakana" => Some(0x30B4)
    "/gukatakana" => Some(0x30B0)
    "/hakatakana" => Some(0x30CF)
    "/hekatakana" => Some(0x30D8)
    "/hikatakana" => Some(0x30D2)
    "/hokatakana" => Some(0x30DB)
    "/hukatakana" => Some(0x30D5)
    "/ikatakana" => Some(0x30A4)
    "/ismallkatakana" => Some(0x30A3)
    "/iterationkatakana" => Some(0x30FD)
    "/kakatakana" => Some(0x30AB)
    "/kasmallkatakana" => Some(0x30F5)
    "/kekatakana" => Some(0x30B1)
    "/kesmallkatakana" => Some(0x30F6)
    "/kikatakana" => Some(0x30AD)
    "/kokatakana" => Some(0x30B3)
    "/kukatakana" => Some(0x30AF)
    "/makatakana" => Some(0x30DE)
    "/mekatakana" => Some(0x30E1)
    "/mikatakana" => Some(0x30DF)
    "/mokatakana" => Some(0x30E2)
    "/mukatakana" => Some(0x30E0)
    "/nakatakana" => Some(0x30CA)
    "/nekatakana" => Some(0x30CD)
    "/nikatakana" => Some(0x30CB)
    "/nkatakana" => Some(0x30F3)
    "/nokatakana" => Some(0x30CE)
    "/nukatakana" => Some(0x30CC)
    "/okatakana" => Some(0x30AA)
    "/osmallkatakana" => Some(0x30A9)
    "/pakatakana" => Some(0x30D1)
    "/pekatakana" => Some(0x30DA)
    "/pikatakana" => Some(0x30D4)
    "/pokatakana" => Some(0x30DD)
    "/prolongedkana" => Some(0x30FC)
    "/pukatakana" => Some(0x30D7)
    "/rakatakana" => Some(0x30E9)
    "/rekatakana" => Some(0x30EC)
    "/rikatakana" => Some(0x30EA)
    "/rokatakana" => Some(0x30ED)
    "/rukatakana" => Some(0x30EB)
    "/sakatakana" => Some(0x30B5)
    "/sekatakana" => Some(0x30BB)
    "/sikatakana" => Some(0x30B7)
    "/sokatakana" => Some(0x30BD)
    "/sukatakana" => Some(0x30B9)
    "/takatakana" => Some(0x30BF)
    "/tekatakana" => Some(0x30C6)
    "/tikatakana" => Some(0x30C1)
    "/tokatakana" => Some(0x30C8)
    "/tukatakana" => Some(0x30C4)
    "/tusmallkatakana" => Some(0x30C3)
    "/ukatakana" => Some(0x30A6)
    "/usmallkatakana" => Some(0x30A5)
    "/vakatakana" => Some(0x30F7)
    "/vekatakana" => Some(0x30F9)
    "/vikatakana" => Some(0x30F8)
    "/voicediterationkatakana" => Some(0x30FE)
    "/vokatakana" => Some(0x30FA)
    "/vukatakana" => Some(0x30F4)
    "/wakatakana" => Some(0x30EF)
    "/wasmallkatakana" => Some(0x30EE)
    "/wekatakana" => Some(0x30F1)
    "/wikatakana" => Some(0x30F0)
    "/wokatakana" => Some(0x30F2)
    "/yakatakana" => Some(0x30E4)
    "/yasmallkatakana" => Some(0x30E3)
    "/yokatakana" => Some(0x30E8)
    "/yosmallkatakana" => Some(0x30E7)
    "/yukatakana" => Some(0x30E6)
    "/yusmallkatakana" => Some(0x30E5)
    "/zakatakana" => Some(0x30B6)
    "/zekatakana" => Some(0x30BC)
    "/zikatakana" => Some(0x30B8)
    "/zokatakana" => Some(0x30BE)
    "/zukatakana" => Some(0x30BA)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_bopomofo_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/abopomofo" => Some(0x311A)
    "/aibopomofo" => Some(0x311E)
    "/anbopomofo" => Some(0x3122)
    "/angbopomofo" => Some(0x3124)
    "/aubopomofo" => Some(0x3120)
    "/bbopomofo" => Some(0x3105)
    "/cbopomofo" => Some(0x3118)
    "/chbopomofo" => Some(0x3114)
    "/dbopomofo" => Some(0x3109)
    "/ebopomofo" => Some(0x311C)
    "/ehbopomofo" => Some(0x311D)
    "/eibopomofo" => Some(0x311F)
    "/enbopomofo" => Some(0x3123)
    "/engbopomofo" => Some(0x3125)
    "/erbopomofo" => Some(0x3126)
    "/fbopomofo" => Some(0x3108)
    "/gbopomofo" => Some(0x310D)
    "/hbopomofo" => Some(0x310F)
    "/ibopomofo" => Some(0x3127)
    "/iubopomofo" => Some(0x3129)
    "/jbopomofo" => Some(0x3110)
    "/kbopomofo" => Some(0x310E)
    "/lbopomofo" => Some(0x310C)
    "/mbopomofo" => Some(0x3107)
    "/nbopomofo" => Some(0x310B)
    "/obopomofo" => Some(0x311B)
    "/oubopomofo" => Some(0x3121)
    "/pbopomofo" => Some(0x3106)
    "/qbopomofo" => Some(0x3111)
    "/rbopomofo" => Some(0x3116)
    "/sbopomofo" => Some(0x3119)
    "/shbopomofo" => Some(0x3115)
    "/tbopomofo" => Some(0x310A)
    "/ubopomofo" => Some(0x3128)
    "/xbopomofo" => Some(0x3112)
    "/zbopomofo" => Some(0x3117)
    "/zhbopomofo" => Some(0x3113)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_box_drawing_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/SF010000" => Some(0x250C)
    "/SF020000" => Some(0x2514)
    "/SF030000" => Some(0x2510)
    "/SF040000" => Some(0x2518)
    "/SF050000" => Some(0x253C)
    "/SF060000" => Some(0x252C)
    "/SF070000" => Some(0x2534)
    "/SF080000" => Some(0x251C)
    "/SF090000" => Some(0x2524)
    "/SF100000" => Some(0x2500)
    "/SF110000" => Some(0x2502)
    "/SF190000" => Some(0x2561)
    "/SF200000" => Some(0x2562)
    "/SF210000" => Some(0x2556)
    "/SF220000" => Some(0x2555)
    "/SF230000" => Some(0x2563)
    "/SF240000" => Some(0x2551)
    "/SF250000" => Some(0x2557)
    "/SF260000" => Some(0x255D)
    "/SF270000" => Some(0x255C)
    "/SF280000" => Some(0x255B)
    "/SF360000" => Some(0x255E)
    "/SF370000" => Some(0x255F)
    "/SF380000" => Some(0x255A)
    "/SF390000" => Some(0x2554)
    "/SF400000" => Some(0x2569)
    "/SF410000" => Some(0x2566)
    "/SF420000" => Some(0x2560)
    "/SF430000" => Some(0x2550)
    "/SF440000" => Some(0x256C)
    "/SF450000" => Some(0x2567)
    "/SF460000" => Some(0x2568)
    "/SF470000" => Some(0x2564)
    "/SF480000" => Some(0x2565)
    "/SF490000" => Some(0x2559)
    "/SF500000" => Some(0x2558)
    "/SF510000" => Some(0x2552)
    "/SF520000" => Some(0x2553)
    "/SF530000" => Some(0x256B)
    "/SF540000" => Some(0x256A)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_block_element_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/block" => Some(0x2588)
    "/dkshade" => Some(0x2593)
    "/dnblock" => Some(0x2584)
    "/lfblock" => Some(0x258C)
    "/ltshade" => Some(0x2591)
    "/rtblock" => Some(0x2590)
    "/shade" => Some(0x2592)
    "/shadedark" => Some(0x2593)
    "/shadelight" => Some(0x2591)
    "/shademedium" => Some(0x2592)
    "/upblock" => Some(0x2580)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_geometric_shape_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/H18533" => Some(0x25CF)
    "/H18543" => Some(0x25AA)
    "/H18551" => Some(0x25AB)
    "/H22073" => Some(0x25A1)
    "/blackcircle" => Some(0x25CF)
    "/blackdiamond" => Some(0x25C6)
    "/blackdownpointingtriangle" => Some(0x25BC)
    "/blackleftpointingpointer" => Some(0x25C4)
    "/blackleftpointingtriangle" => Some(0x25C0)
    "/blacklowerlefttriangle" => Some(0x25E3)
    "/blacklowerrighttriangle" => Some(0x25E2)
    "/blackrectangle" => Some(0x25AC)
    "/blackrightpointingpointer" => Some(0x25BA)
    "/blackrightpointingtriangle" => Some(0x25B6)
    "/blacksmallsquare" => Some(0x25AA)
    "/blacksquare" => Some(0x25A0)
    "/blackupperlefttriangle" => Some(0x25E4)
    "/blackupperrighttriangle" => Some(0x25E5)
    "/blackuppointingsmalltriangle" => Some(0x25B4)
    "/blackuppointingtriangle" => Some(0x25B2)
    "/bulletinverse" => Some(0x25D8)
    "/bullseye" => Some(0x25CE)
    "/circle" => Some(0x25CB)
    "/circlewithlefthalfblack" => Some(0x25D0)
    "/circlewithrighthalfblack" => Some(0x25D1)
    "/dottedcircle" => Some(0x25CC)
    "/filledbox" => Some(0x25A0)
    "/filledrect" => Some(0x25AC)
    "/fisheye" => Some(0x25C9)
    "/invbullet" => Some(0x25D8)
    "/invcircle" => Some(0x25D9)
    "/largecircle" => Some(0x25EF)
    "/openbullet" => Some(0x25E6)
    "/squarediagonalcrosshatchfill" => Some(0x25A9)
    "/squarehorizontalfill" => Some(0x25A4)
    "/squareorthogonalcrosshatchfill" => Some(0x25A6)
    "/squareupperlefttolowerrightfill" => Some(0x25A7)
    "/squareupperrighttolowerleftfill" => Some(0x25A8)
    "/squareverticalfill" => Some(0x25A5)
    "/squarewhitewithsmallblack" => Some(0x25A3)
    "/triagdn" => Some(0x25BC)
    "/triaglf" => Some(0x25C4)
    "/triagrt" => Some(0x25BA)
    "/triagup" => Some(0x25B2)
    "/whitebullet" => Some(0x25E6)
    "/whitecircle" => Some(0x25CB)
    "/whitecircleinverse" => Some(0x25D9)
    "/whitediamond" => Some(0x25C7)
    "/whitediamondcontainingblacksmalldiamond" => Some(0x25C8)
    "/whitedownpointingsmalltriangle" => Some(0x25BF)
    "/whitedownpointingtriangle" => Some(0x25BD)
    "/whiteleftpointingsmalltriangle" => Some(0x25C3)
    "/whiteleftpointingtriangle" => Some(0x25C1)
    "/whiterightpointingsmalltriangle" => Some(0x25B9)
    "/whiterightpointingtriangle" => Some(0x25B7)
    "/whitesmallsquare" => Some(0x25AB)
    "/whitesquare" => Some(0x25A1)
    "/whiteuppointingsmalltriangle" => Some(0x25B5)
    "/whiteuppointingtriangle" => Some(0x25B3)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_misc_symbol_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/beamedsixteenthnotes" => Some(0x266C)
    "/blacksmilingface" => Some(0x263B)
    "/blackstar" => Some(0x2605)
    "/clubsuitblack" => Some(0x2663)
    "/clubsuitwhite" => Some(0x2667)
    "/compass" => Some(0x263C)
    "/diamondsuitwhite" => Some(0x2662)
    "/earth" => Some(0x2641)
    "/eighthnotebeamed" => Some(0x266B)
    "/female" => Some(0x2640)
    "/heartsuitblack" => Some(0x2665)
    "/heartsuitwhite" => Some(0x2661)
    "/hotsprings" => Some(0x2668)
    "/invsmileface" => Some(0x263B)
    "/male" => Some(0x2642)
    "/mars" => Some(0x2642)
    "/musicalnote" => Some(0x266A)
    "/musicalnotedbl" => Some(0x266B)
    "/musicflatsign" => Some(0x266D)
    "/musicsharpsign" => Some(0x266F)
    "/pointingindexdownwhite" => Some(0x261F)
    "/pointingindexleftwhite" => Some(0x261C)
    "/pointingindexrightwhite" => Some(0x261E)
    "/pointingindexupwhite" => Some(0x261D)
    "/quarternote" => Some(0x2669)
    "/smileface" => Some(0x263A)
    "/spadesuitblack" => Some(0x2660)
    "/spadesuitwhite" => Some(0x2664)
    "/sun" => Some(0x263C)
    "/telephoneblack" => Some(0x260E)
    "/venus" => Some(0x2640)
    "/whitesmilingface" => Some(0x263A)
    "/whitestar" => Some(0x2606)
    "/whitetelephone" => Some(0x260F)
    "/yinyang" => Some(0x262F)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_latin_extended_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Abreve" => Some(0x0102)
    "/Amacron" => Some(0x0100)
    "/Aogonek" => Some(0x0104)
    "/Cacute" => Some(0x0106)
    "/Ccaron" => Some(0x010C)
    "/Ccircumflex" => Some(0x0108)
    "/Cdot" => Some(0x010A)
    "/Cdotaccent" => Some(0x010A)
    "/Dcaron" => Some(0x010E)
    "/Dcroat" => Some(0x0110)
    "/Dslash" => Some(0x0110)
    "/Ebreve" => Some(0x0114)
    "/Ecaron" => Some(0x011A)
    "/Edot" => Some(0x0116)
    "/Edotaccent" => Some(0x0116)
    "/Emacron" => Some(0x0112)
    "/Eng" => Some(0x014A)
    "/Eogonek" => Some(0x0118)
    "/Gbreve" => Some(0x011E)
    "/Gcedilla" => Some(0x0122)
    "/Gcircumflex" => Some(0x011C)
    "/Gcommaaccent" => Some(0x0122)
    "/Gdot" => Some(0x0120)
    "/Gdotaccent" => Some(0x0120)
    "/Hbar" => Some(0x0126)
    "/Hcircumflex" => Some(0x0124)
    "/IJ" => Some(0x0132)
    "/Ibreve" => Some(0x012C)
    "/Idot" => Some(0x0130)
    "/Idotaccent" => Some(0x0130)
    "/Imacron" => Some(0x012A)
    "/Iogonek" => Some(0x012E)
    "/Itilde" => Some(0x0128)
    "/Jcircumflex" => Some(0x0134)
    "/Kcedilla" => Some(0x0136)
    "/Kcommaaccent" => Some(0x0136)
    "/Lacute" => Some(0x0139)
    "/Lcaron" => Some(0x013D)
    "/Lcedilla" => Some(0x013B)
    "/Lcommaaccent" => Some(0x013B)
    "/Ldot" => Some(0x013F)
    "/Ldotaccent" => Some(0x013F)
    "/Nacute" => Some(0x0143)
    "/Ncaron" => Some(0x0147)
    "/Ncedilla" => Some(0x0145)
    "/Ncommaaccent" => Some(0x0145)
    "/Obreve" => Some(0x014E)
    "/Odblacute" => Some(0x0150)
    "/Ohungarumlaut" => Some(0x0150)
    "/Omacron" => Some(0x014C)
    "/Racute" => Some(0x0154)
    "/Rcaron" => Some(0x0158)
    "/Rcedilla" => Some(0x0156)
    "/Rcommaaccent" => Some(0x0156)
    "/Sacute" => Some(0x015A)
    "/Scedilla" => Some(0x015E)
    "/Scircumflex" => Some(0x015C)
    "/Tbar" => Some(0x0166)
    "/Tcaron" => Some(0x0164)
    "/Tcedilla" => Some(0x0162)
    "/Tcommaaccent" => Some(0x0162)
    "/Ubreve" => Some(0x016C)
    "/Udblacute" => Some(0x0170)
    "/Uhungarumlaut" => Some(0x0170)
    "/Umacron" => Some(0x016A)
    "/Uogonek" => Some(0x0172)
    "/Uring" => Some(0x016E)
    "/Utilde" => Some(0x0168)
    "/Wcircumflex" => Some(0x0174)
    "/Ycircumflex" => Some(0x0176)
    "/Zacute" => Some(0x0179)
    "/Zdot" => Some(0x017B)
    "/Zdotaccent" => Some(0x017B)
    "/abreve" => Some(0x0103)
    "/amacron" => Some(0x0101)
    "/aogonek" => Some(0x0105)
    "/cacute" => Some(0x0107)
    "/ccaron" => Some(0x010D)
    "/ccircumflex" => Some(0x0109)
    "/cdot" => Some(0x010B)
    "/cdotaccent" => Some(0x010B)
    "/dcaron" => Some(0x010F)
    "/dcroat" => Some(0x0111)
    "/dmacron" => Some(0x0111)
    "/ebreve" => Some(0x0115)
    "/ecaron" => Some(0x011B)
    "/edot" => Some(0x0117)
    "/edotaccent" => Some(0x0117)
    "/emacron" => Some(0x0113)
    "/eng" => Some(0x014B)
    "/eogonek" => Some(0x0119)
    "/gbreve" => Some(0x011F)
    "/gcedilla" => Some(0x0123)
    "/gcircumflex" => Some(0x011D)
    "/gcommaaccent" => Some(0x0123)
    "/gdot" => Some(0x0121)
    "/gdotaccent" => Some(0x0121)
    "/hbar" => Some(0x0127)
    "/hcircumflex" => Some(0x0125)
    "/ibreve" => Some(0x012D)
    "/ij" => Some(0x0133)
    "/imacron" => Some(0x012B)
    "/iogonek" => Some(0x012F)
    "/itilde" => Some(0x0129)
    "/jcircumflex" => Some(0x0135)
    "/kcedilla" => Some(0x0137)
    "/kcommaaccent" => Some(0x0137)
    "/kgreenlandic" => Some(0x0138)
    "/lacute" => Some(0x013A)
    "/lcaron" => Some(0x013E)
    "/lcedilla" => Some(0x013C)
    "/lcommaaccent" => Some(0x013C)
    "/ldot" => Some(0x0140)
    "/ldotaccent" => Some(0x0140)
    "/longs" => Some(0x017F)
    "/nacute" => Some(0x0144)
    "/napostrophe" => Some(0x0149)
    "/ncaron" => Some(0x0148)
    "/ncedilla" => Some(0x0146)
    "/ncommaaccent" => Some(0x0146)
    "/obreve" => Some(0x014F)
    "/odblacute" => Some(0x0151)
    "/ohungarumlaut" => Some(0x0151)
    "/omacron" => Some(0x014D)
    "/quoterightn" => Some(0x0149)
    "/racute" => Some(0x0155)
    "/rcaron" => Some(0x0159)
    "/rcedilla" => Some(0x0157)
    "/rcommaaccent" => Some(0x0157)
    "/sacute" => Some(0x015B)
    "/scedilla" => Some(0x015F)
    "/scircumflex" => Some(0x015D)
    "/slong" => Some(0x017F)
    "/tbar" => Some(0x0167)
    "/tcaron" => Some(0x0165)
    "/tcedilla" => Some(0x0163)
    "/tcommaaccent" => Some(0x0163)
    "/ubreve" => Some(0x016D)
    "/udblacute" => Some(0x0171)
    "/uhungarumlaut" => Some(0x0171)
    "/umacron" => Some(0x016B)
    "/uogonek" => Some(0x0173)
    "/uring" => Some(0x016F)
    "/utilde" => Some(0x0169)
    "/wcircumflex" => Some(0x0175)
    "/ycircumflex" => Some(0x0177)
    "/zacute" => Some(0x017A)
    "/zdot" => Some(0x017C)
    "/zdotaccent" => Some(0x017C)
    "/AEacute" => Some(0x01FC)
    "/AEmacron" => Some(0x01E2)
    "/Acaron" => Some(0x01CD)
    "/Adblgrave" => Some(0x0200)
    "/Adieresismacron" => Some(0x01DE)
    "/Adotmacron" => Some(0x01E0)
    "/Ainvertedbreve" => Some(0x0202)
    "/Aringacute" => Some(0x01FA)
    "/Bhook" => Some(0x0181)
    "/Btopbar" => Some(0x0182)
    "/Chook" => Some(0x0187)
    "/DZ" => Some(0x01F1)
    "/DZcaron" => Some(0x01C4)
    "/Dafrican" => Some(0x0189)
    "/Dhook" => Some(0x018A)
    "/Dtopbar" => Some(0x018B)
    "/Dz" => Some(0x01F2)
    "/Dzcaron" => Some(0x01C5)
    "/Edblgrave" => Some(0x0204)
    "/Einvertedbreve" => Some(0x0206)
    "/Eopen" => Some(0x0190)
    "/Ereversed" => Some(0x018E)
    "/Esh" => Some(0x01A9)
    "/Ezh" => Some(0x01B7)
    "/Ezhcaron" => Some(0x01EE)
    "/Ezhreversed" => Some(0x01B8)
    "/Fhook" => Some(0x0191)
    "/Gacute" => Some(0x01F4)
    "/Gammaafrican" => Some(0x0194)
    "/Gcaron" => Some(0x01E6)
    "/Ghook" => Some(0x0193)
    "/Gstroke" => Some(0x01E4)
    "/Icaron" => Some(0x01CF)
    "/Idblgrave" => Some(0x0208)
    "/Iinvertedbreve" => Some(0x020A)
    "/Iotaafrican" => Some(0x0196)
    "/Istroke" => Some(0x0197)
    "/Kcaron" => Some(0x01E8)
    "/Khook" => Some(0x0198)
    "/LJ" => Some(0x01C7)
    "/Lj" => Some(0x01C8)
    "/Mturned" => Some(0x019C)
    "/NJ" => Some(0x01CA)
    "/Nhookleft" => Some(0x019D)
    "/Nj" => Some(0x01CB)
    "/Ocaron" => Some(0x01D1)
    "/Ocenteredtilde" => Some(0x019F)
    "/Odblgrave" => Some(0x020C)
    "/Ohorn" => Some(0x01A0)
    "/Oi" => Some(0x01A2)
    "/Oinvertedbreve" => Some(0x020E)
    "/Oogonek" => Some(0x01EA)
    "/Oogonekmacron" => Some(0x01EC)
    "/Oopen" => Some(0x0186)
    "/Oslashacute" => Some(0x01FE)
    "/Ostrokeacute" => Some(0x01FE)
    "/Phook" => Some(0x01A4)
    "/Rdblgrave" => Some(0x0210)
    "/Rinvertedbreve" => Some(0x0212)
    "/Schwa" => Some(0x018F)
    "/Scommaaccent" => Some(0x0218)
    "/Thook" => Some(0x01AC)
    "/Tonefive" => Some(0x01BC)
    "/Tonesix" => Some(0x0184)
    "/Tonetwo" => Some(0x01A7)
    "/Tretroflexhook" => Some(0x01AE)
    "/Ucaron" => Some(0x01D3)
    "/Udblgrave" => Some(0x0214)
    "/Udieresisacute" => Some(0x01D7)
    "/Udieresiscaron" => Some(0x01D9)
    "/Udieresisgrave" => Some(0x01DB)
    "/Udieresismacron" => Some(0x01D5)
    "/Uhorn" => Some(0x01AF)
    "/Uinvertedbreve" => Some(0x0216)
    "/Upsilonafrican" => Some(0x01B1)
    "/Vhook" => Some(0x01B2)
    "/Yhook" => Some(0x01B3)
    "/Zstroke" => Some(0x01B5)
    "/acaron" => Some(0x01CE)
    "/adblgrave" => Some(0x0201)
    "/adieresismacron" => Some(0x01DF)
    "/adotmacron" => Some(0x01E1)
    "/aeacute" => Some(0x01FD)
    "/aemacron" => Some(0x01E3)
    "/ainvertedbreve" => Some(0x0203)
    "/aringacute" => Some(0x01FB)
    "/bstroke" => Some(0x0180)
    "/btopbar" => Some(0x0183)
    "/chook" => Some(0x0188)
    "/clickalveolar" => Some(0x01C2)
    "/clickdental" => Some(0x01C0)
    "/clicklateral" => Some(0x01C1)
    "/clickretroflex" => Some(0x01C3)
    "/deltaturned" => Some(0x018D)
    "/dtopbar" => Some(0x018C)
    "/dz" => Some(0x01F3)
    "/dzcaron" => Some(0x01C6)
    "/edblgrave" => Some(0x0205)
    "/einvertedbreve" => Some(0x0207)
    "/eshreversedloop" => Some(0x01AA)
    "/eturned" => Some(0x01DD)
    "/ezhcaron" => Some(0x01EF)
    "/ezhreversed" => Some(0x01B9)
    "/ezhtail" => Some(0x01BA)
    "/gacute" => Some(0x01F5)
    "/gcaron" => Some(0x01E7)
    "/glottalinvertedstroke" => Some(0x01BE)
    "/gstroke" => Some(0x01E5)
    "/hv" => Some(0x0195)
    "/icaron" => Some(0x01D0)
    "/idblgrave" => Some(0x0209)
    "/iinvertedbreve" => Some(0x020B)
    "/jcaron" => Some(0x01F0)
    "/kcaron" => Some(0x01E9)
    "/khook" => Some(0x0199)
    "/lambdastroke" => Some(0x019B)
    "/lbar" => Some(0x019A)
    "/lj" => Some(0x01C9)
    "/nj" => Some(0x01CC)
    "/nlegrightlong" => Some(0x019E)
    "/ocaron" => Some(0x01D2)
    "/odblgrave" => Some(0x020D)
    "/ohorn" => Some(0x01A1)
    "/oi" => Some(0x01A3)
    "/oinvertedbreve" => Some(0x020F)
    "/oogonek" => Some(0x01EB)
    "/oogonekmacron" => Some(0x01ED)
    "/oslashacute" => Some(0x01FF)
    "/ostrokeacute" => Some(0x01FF)
    "/phook" => Some(0x01A5)
    "/rdblgrave" => Some(0x0211)
    "/rinvertedbreve" => Some(0x0213)
    "/scommaaccent" => Some(0x0219)
    "/thook" => Some(0x01AD)
    "/tonefive" => Some(0x01BD)
    "/tonesix" => Some(0x0185)
    "/tonetwo" => Some(0x01A8)
    "/tpalatalhook" => Some(0x01AB)
    "/twostroke" => Some(0x01BB)
    "/ucaron" => Some(0x01D4)
    "/udblgrave" => Some(0x0215)
    "/udieresisacute" => Some(0x01D8)
    "/udieresiscaron" => Some(0x01DA)
    "/udieresisgrave" => Some(0x01DC)
    "/udieresismacron" => Some(0x01D6)
    "/uhorn" => Some(0x01B0)
    "/uinvertedbreve" => Some(0x0217)
    "/wynn" => Some(0x01BF)
    "/yhook" => Some(0x01B4)
    "/yr" => Some(0x01A6)
    "/zstroke" => Some(0x01B6)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_hangul_compat_jamo_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/aekorean" => Some(0x3150)
    "/akorean" => Some(0x314F)
    "/araeaekorean" => Some(0x318E)
    "/araeakorean" => Some(0x318D)
    "/chieuchkorean" => Some(0x314A)
    "/cieuckorean" => Some(0x3148)
    "/ekorean" => Some(0x3154)
    "/eokorean" => Some(0x3153)
    "/eukorean" => Some(0x3161)
    "/hangulfiller" => Some(0x3164)
    "/hieuhkorean" => Some(0x314E)
    "/ieungkorean" => Some(0x3147)
    "/ikorean" => Some(0x3163)
    "/kapyeounmieumkorean" => Some(0x3171)
    "/kapyeounphieuphkorean" => Some(0x3184)
    "/kapyeounpieupkorean" => Some(0x3178)
    "/kapyeounssangpieupkorean" => Some(0x3179)
    "/khieukhkorean" => Some(0x314B)
    "/kiyeokkorean" => Some(0x3131)
    "/kiyeoksioskorean" => Some(0x3133)
    "/mieumkorean" => Some(0x3141)
    "/mieumpansioskorean" => Some(0x3170)
    "/mieumpieupkorean" => Some(0x316E)
    "/mieumsioskorean" => Some(0x316F)
    "/nieuncieuckorean" => Some(0x3135)
    "/nieunhieuhkorean" => Some(0x3136)
    "/nieunkorean" => Some(0x3134)
    "/nieunpansioskorean" => Some(0x3168)
    "/nieunsioskorean" => Some(0x3167)
    "/nieuntikeutkorean" => Some(0x3166)
    "/oekorean" => Some(0x315A)
    "/okorean" => Some(0x3157)
    "/pansioskorean" => Some(0x317F)
    "/phieuphkorean" => Some(0x314D)
    "/pieupcieuckorean" => Some(0x3176)
    "/pieupkiyeokkorean" => Some(0x3172)
    "/pieupkorean" => Some(0x3142)
    "/pieupsioskiyeokkorean" => Some(0x3174)
    "/pieupsioskorean" => Some(0x3144)
    "/pieupsiostikeutkorean" => Some(0x3175)
    "/pieupthieuthkorean" => Some(0x3177)
    "/pieuptikeutkorean" => Some(0x3173)
    "/rieulhieuhkorean" => Some(0x3140)
    "/rieulkiyeokkorean" => Some(0x313A)
    "/rieulkiyeoksioskorean" => Some(0x3169)
    "/rieulkorean" => Some(0x3139)
    "/rieulmieumkorean" => Some(0x313B)
    "/rieulpansioskorean" => Some(0x316C)
    "/rieulphieuphkorean" => Some(0x313F)
    "/rieulpieupkorean" => Some(0x313C)
    "/rieulpieupsioskorean" => Some(0x316B)
    "/rieulsioskorean" => Some(0x313D)
    "/rieulthieuthkorean" => Some(0x313E)
    "/rieultikeutkorean" => Some(0x316A)
    "/rieulyeorinhieuhkorean" => Some(0x316D)
    "/sioscieuckorean" => Some(0x317E)
    "/sioskiyeokkorean" => Some(0x317A)
    "/sioskorean" => Some(0x3145)
    "/siosnieunkorean" => Some(0x317B)
    "/siospieupkorean" => Some(0x317D)
    "/siostikeutkorean" => Some(0x317C)
    "/ssangcieuckorean" => Some(0x3149)
    "/ssanghieuhkorean" => Some(0x3185)
    "/ssangieungkorean" => Some(0x3180)
    "/ssangkiyeokkorean" => Some(0x3132)
    "/ssangnieunkorean" => Some(0x3165)
    "/ssangpieupkorean" => Some(0x3143)
    "/ssangsioskorean" => Some(0x3146)
    "/ssangtikeutkorean" => Some(0x3138)
    "/thieuthkorean" => Some(0x314C)
    "/tikeutkorean" => Some(0x3137)
    "/ukorean" => Some(0x315C)
    "/waekorean" => Some(0x3159)
    "/wakorean" => Some(0x3158)
    "/wekorean" => Some(0x315E)
    "/weokorean" => Some(0x315D)
    "/wikorean" => Some(0x315F)
    "/yaekorean" => Some(0x3152)
    "/yakorean" => Some(0x3151)
    "/yekorean" => Some(0x3156)
    "/yeokorean" => Some(0x3155)
    "/yeorinhieuhkorean" => Some(0x3186)
    "/yesieungkorean" => Some(0x3181)
    "/yesieungpansioskorean" => Some(0x3183)
    "/yesieungsioskorean" => Some(0x3182)
    "/yikorean" => Some(0x3162)
    "/yoikorean" => Some(0x3189)
    "/yokorean" => Some(0x315B)
    "/yoyaekorean" => Some(0x3188)
    "/yoyakorean" => Some(0x3187)
    "/yuikorean" => Some(0x318C)
    "/yukorean" => Some(0x3160)
    "/yuyekorean" => Some(0x318B)
    "/yuyeokorean" => Some(0x318A)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_enclosed_cjk_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/chieuchacirclekorean" => Some(0x3277)
    "/chieuchaparenkorean" => Some(0x3217)
    "/chieuchcirclekorean" => Some(0x3269)
    "/chieuchparenkorean" => Some(0x3209)
    "/cieucacirclekorean" => Some(0x3276)
    "/cieucaparenkorean" => Some(0x3216)
    "/cieuccirclekorean" => Some(0x3268)
    "/cieucparenkorean" => Some(0x3208)
    "/cieucuparenkorean" => Some(0x321C)
    "/eightideographicparen" => Some(0x3227)
    "/fiveideographicparen" => Some(0x3224)
    "/fourideographicparen" => Some(0x3223)
    "/hieuhacirclekorean" => Some(0x327B)
    "/hieuhaparenkorean" => Some(0x321B)
    "/hieuhcirclekorean" => Some(0x326D)
    "/hieuhparenkorean" => Some(0x320D)
    "/ideographearthcircle" => Some(0x328F)
    "/ideographfirecircle" => Some(0x328B)
    "/ideographicallianceparen" => Some(0x323F)
    "/ideographiccallparen" => Some(0x323A)
    "/ideographiccentrecircle" => Some(0x32A5)
    "/ideographiccongratulationparen" => Some(0x3237)
    "/ideographiccorrectcircle" => Some(0x32A3)
    "/ideographicearthparen" => Some(0x322F)
    "/ideographicenterpriseparen" => Some(0x323D)
    "/ideographicexcellentcircle" => Some(0x329D)
    "/ideographicfestivalparen" => Some(0x3240)
    "/ideographicfinancialcircle" => Some(0x3296)
    "/ideographicfinancialparen" => Some(0x3236)
    "/ideographicfireparen" => Some(0x322B)
    "/ideographichaveparen" => Some(0x3232)
    "/ideographichighcircle" => Some(0x32A4)
    "/ideographiclaborcircle" => Some(0x3298)
    "/ideographiclaborparen" => Some(0x3238)
    "/ideographicleftcircle" => Some(0x32A7)
    "/ideographiclowcircle" => Some(0x32A6)
    "/ideographicmedicinecircle" => Some(0x32A9)
    "/ideographicmetalparen" => Some(0x322E)
    "/ideographicmoonparen" => Some(0x322A)
    "/ideographicnameparen" => Some(0x3234)
    "/ideographicprintcircle" => Some(0x329E)
    "/ideographicreachparen" => Some(0x3243)
    "/ideographicrepresentparen" => Some(0x3239)
    "/ideographicresourceparen" => Some(0x323E)
    "/ideographicrightcircle" => Some(0x32A8)
    "/ideographicsecretcircle" => Some(0x3299)
    "/ideographicselfparen" => Some(0x3242)
    "/ideographicsocietyparen" => Some(0x3233)
    "/ideographicspecialparen" => Some(0x3235)
    "/ideographicstockparen" => Some(0x3231)
    "/ideographicstudyparen" => Some(0x323B)
    "/ideographicsunparen" => Some(0x3230)
    "/ideographicsuperviseparen" => Some(0x323C)
    "/ideographicwaterparen" => Some(0x322C)
    "/ideographicwoodparen" => Some(0x322D)
    "/ideographmetalcircle" => Some(0x328E)
    "/ideographmooncircle" => Some(0x328A)
    "/ideographnamecircle" => Some(0x3294)
    "/ideographsuncircle" => Some(0x3290)
    "/ideographwatercircle" => Some(0x328C)
    "/ideographwoodcircle" => Some(0x328D)
    "/ieungacirclekorean" => Some(0x3275)
    "/ieungaparenkorean" => Some(0x3215)
    "/ieungcirclekorean" => Some(0x3267)
    "/ieungparenkorean" => Some(0x3207)
    "/khieukhacirclekorean" => Some(0x3278)
    "/khieukhaparenkorean" => Some(0x3218)
    "/khieukhcirclekorean" => Some(0x326A)
    "/khieukhparenkorean" => Some(0x320A)
    "/kiyeokacirclekorean" => Some(0x326E)
    "/kiyeokaparenkorean" => Some(0x320E)
    "/kiyeokcirclekorean" => Some(0x3260)
    "/kiyeokparenkorean" => Some(0x3200)
    "/koreanstandardsymbol" => Some(0x327F)
    "/mieumacirclekorean" => Some(0x3272)
    "/mieumaparenkorean" => Some(0x3212)
    "/mieumcirclekorean" => Some(0x3264)
    "/mieumparenkorean" => Some(0x3204)
    "/nieunacirclekorean" => Some(0x326F)
    "/nieunaparenkorean" => Some(0x320F)
    "/nieuncirclekorean" => Some(0x3261)
    "/nieunparenkorean" => Some(0x3201)
    "/nineideographicparen" => Some(0x3228)
    "/oneideographicparen" => Some(0x3220)
    "/phieuphacirclekorean" => Some(0x327A)
    "/phieuphaparenkorean" => Some(0x321A)
    "/phieuphcirclekorean" => Some(0x326C)
    "/phieuphparenkorean" => Some(0x320C)
    "/pieupacirclekorean" => Some(0x3273)
    "/pieupaparenkorean" => Some(0x3213)
    "/pieupcirclekorean" => Some(0x3265)
    "/pieupparenkorean" => Some(0x3205)
    "/rieulacirclekorean" => Some(0x3271)
    "/rieulaparenkorean" => Some(0x3211)
    "/rieulcirclekorean" => Some(0x3263)
    "/rieulparenkorean" => Some(0x3203)
    "/sevenideographicparen" => Some(0x3226)
    "/siosacirclekorean" => Some(0x3274)
    "/siosaparenkorean" => Some(0x3214)
    "/sioscirclekorean" => Some(0x3266)
    "/siosparenkorean" => Some(0x3206)
    "/sixideographicparen" => Some(0x3225)
    "/tenideographicparen" => Some(0x3229)
    "/thieuthacirclekorean" => Some(0x3279)
    "/thieuthaparenkorean" => Some(0x3219)
    "/thieuthcirclekorean" => Some(0x326B)
    "/thieuthparenkorean" => Some(0x320B)
    "/threeideographicparen" => Some(0x3222)
    "/tikeutacirclekorean" => Some(0x3270)
    "/tikeutaparenkorean" => Some(0x3210)
    "/tikeutcirclekorean" => Some(0x3262)
    "/tikeutparenkorean" => Some(0x3202)
    "/twoideographicparen" => Some(0x3221)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_private_use_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Acute" => Some(0xF6C9)
    "/Caron" => Some(0xF6CA)
    "/Dieresis" => Some(0xF6CB)
    "/DieresisAcute" => Some(0xF6CC)
    "/DieresisGrave" => Some(0xF6CD)
    "/Grave" => Some(0xF6CE)
    "/Hungarumlaut" => Some(0xF6CF)
    "/LL" => Some(0xF6BF)
    "/Macron" => Some(0xF6D0)
    "/afii10063" => Some(0xF6C4)
    "/afii10064" => Some(0xF6C5)
    "/afii10192" => Some(0xF6C6)
    "/afii10831" => Some(0xF6C7)
    "/afii10832" => Some(0xF6C8)
    "/apple" => Some(0xF8FF)
    "/commaaccent" => Some(0xF6C3)
    "/cyrBreve" => Some(0xF6D1)
    "/cyrFlex" => Some(0xF6D2)
    "/cyrbreve" => Some(0xF6D4)
    "/cyrflex" => Some(0xF6D5)
    "/dblGrave" => Some(0xF6D3)
    "/dblgrave" => Some(0xF6D6)
    "/dieresisacute" => Some(0xF6D7)
    "/dieresisgrave" => Some(0xF6D8)
    "/dollarsuperior" => Some(0xF6E4)
    "/dotlessj" => Some(0xF6BE)
    "/ll" => Some(0xF6C0)
    "/maichattawalowleftthai" => Some(0xF895)
    "/maichattawalowrightthai" => Some(0xF894)
    "/maichattawaupperleftthai" => Some(0xF893)
    "/maieklowleftthai" => Some(0xF88C)
    "/maieklowrightthai" => Some(0xF88B)
    "/maiekupperleftthai" => Some(0xF88A)
    "/maihanakatleftthai" => Some(0xF884)
    "/maitaikhuleftthai" => Some(0xF889)
    "/maitholowleftthai" => Some(0xF88F)
    "/maitholowrightthai" => Some(0xF88E)
    "/maithoupperleftthai" => Some(0xF88D)
    "/maitrilowleftthai" => Some(0xF892)
    "/maitrilowrightthai" => Some(0xF891)
    "/maitriupperleftthai" => Some(0xF890)
    "/nikhahitleftthai" => Some(0xF899)
    "/saraiileftthai" => Some(0xF886)
    "/saraileftthai" => Some(0xF885)
    "/saraueeleftthai" => Some(0xF888)
    "/saraueleftthai" => Some(0xF887)
    "/thanthakhatlowleftthai" => Some(0xF898)
    "/thanthakhatlowrightthai" => Some(0xF897)
    "/thanthakhatupperleftthai" => Some(0xF896)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_expert_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/AEsmall" => Some(0xF7E6)
    "/Aacutesmall" => Some(0xF7E1)
    "/Acircumflexsmall" => Some(0xF7E2)
    "/Acutesmall" => Some(0xF7B4)
    "/Adieresissmall" => Some(0xF7E4)
    "/Agravesmall" => Some(0xF7E0)
    "/Aringsmall" => Some(0xF7E5)
    "/Asmall" => Some(0xF761)
    "/Atildesmall" => Some(0xF7E3)
    "/Brevesmall" => Some(0xF6F4)
    "/Bsmall" => Some(0xF762)
    "/Caronsmall" => Some(0xF6F5)
    "/Ccedillasmall" => Some(0xF7E7)
    "/Cedillasmall" => Some(0xF7B8)
    "/Circumflexsmall" => Some(0xF6F6)
    "/Csmall" => Some(0xF763)
    "/Dieresissmall" => Some(0xF7A8)
    "/Dotaccentsmall" => Some(0xF6F7)
    "/Dsmall" => Some(0xF764)
    "/Eacutesmall" => Some(0xF7E9)
    "/Ecircumflexsmall" => Some(0xF7EA)
    "/Edieresissmall" => Some(0xF7EB)
    "/Egravesmall" => Some(0xF7E8)
    "/Esmall" => Some(0xF765)
    "/Ethsmall" => Some(0xF7F0)
    "/Fsmall" => Some(0xF766)
    "/Gravesmall" => Some(0xF760)
    "/Gsmall" => Some(0xF767)
    "/Hsmall" => Some(0xF768)
    "/Hungarumlautsmall" => Some(0xF6F8)
    "/Iacutesmall" => Some(0xF7ED)
    "/Icircumflexsmall" => Some(0xF7EE)
    "/Idieresissmall" => Some(0xF7EF)
    "/Igravesmall" => Some(0xF7EC)
    "/Ismall" => Some(0xF769)
    "/Jsmall" => Some(0xF76A)
    "/Ksmall" => Some(0xF76B)
    "/Lslashsmall" => Some(0xF6F9)
    "/Lsmall" => Some(0xF76C)
    "/Macronsmall" => Some(0xF7AF)
    "/Msmall" => Some(0xF76D)
    "/Nsmall" => Some(0xF76E)
    "/Ntildesmall" => Some(0xF7F1)
    "/OEsmall" => Some(0xF6FA)
    "/Oacutesmall" => Some(0xF7F3)
    "/Ocircumflexsmall" => Some(0xF7F4)
    "/Odieresissmall" => Some(0xF7F6)
    "/Ogoneksmall" => Some(0xF6FB)
    "/Ogravesmall" => Some(0xF7F2)
    "/Oslashsmall" => Some(0xF7F8)
    "/Osmall" => Some(0xF76F)
    "/Otildesmall" => Some(0xF7F5)
    "/Psmall" => Some(0xF770)
    "/Qsmall" => Some(0xF771)
    "/Ringsmall" => Some(0xF6FC)
    "/Rsmall" => Some(0xF772)
    "/Scaronsmall" => Some(0xF6FD)
    "/Ssmall" => Some(0xF773)
    "/Thornsmall" => Some(0xF7FE)
    "/Tildesmall" => Some(0xF6FE)
    "/Tsmall" => Some(0xF774)
    "/Uacutesmall" => Some(0xF7FA)
    "/Ucircumflexsmall" => Some(0xF7FB)
    "/Udieresissmall" => Some(0xF7FC)
    "/Ugravesmall" => Some(0xF7F9)
    "/Usmall" => Some(0xF775)
    "/Vsmall" => Some(0xF776)
    "/Wsmall" => Some(0xF777)
    "/Xsmall" => Some(0xF778)
    "/Yacutesmall" => Some(0xF7FD)
    "/Ydieresissmall" => Some(0xF7FF)
    "/Ysmall" => Some(0xF779)
    "/Zcaronsmall" => Some(0xF6FF)
    "/Zsmall" => Some(0xF77A)
    "/ampersandsmall" => Some(0xF726)
    "/asuperior" => Some(0xF6E9)
    "/bsuperior" => Some(0xF6EA)
    "/centinferior" => Some(0xF6DF)
    "/centoldstyle" => Some(0xF7A2)
    "/centsuperior" => Some(0xF6E0)
    "/colonmonetary" => Some(0x20A1)
    "/commainferior" => Some(0xF6E1)
    "/commasuperior" => Some(0xF6E2)
    "/dollarinferior" => Some(0xF6E3)
    "/dollaroldstyle" => Some(0xF724)
    "/dsuperior" => Some(0xF6EB)
    "/esuperior" => Some(0xF6EC)
    "/exclamdownsmall" => Some(0xF7A1)
    "/exclamsmall" => Some(0xF721)
    "/figuredash" => Some(0x2012)
    "/hypheninferior" => Some(0xF6E5)
    "/hyphensuperior" => Some(0xF6E6)
    "/isuperior" => Some(0xF6ED)
    "/lsuperior" => Some(0xF6EE)
    "/msuperior" => Some(0xF6EF)
    "/nsuperior" => Some(0x207F)
    "/onedotenleader" => Some(0x2024)
    "/onefitted" => Some(0xF6DC)
    "/osuperior" => Some(0xF6F0)
    "/parenleftinferior" => Some(0x208D)
    "/parenleftsuperior" => Some(0x207D)
    "/parenrightinferior" => Some(0x208E)
    "/parenrightsuperior" => Some(0x207E)
    "/periodinferior" => Some(0xF6E7)
    "/periodsuperior" => Some(0xF6E8)
    "/questiondownsmall" => Some(0xF7BF)
    "/questionsmall" => Some(0xF73F)
    "/rsuperior" => Some(0xF6F1)
    "/rupiah" => Some(0xF6DD)
    "/ssuperior" => Some(0xF6F2)
    "/tsuperior" => Some(0xF6F3)
    "/twodotenleader" => Some(0x2025)
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
    "/Upsilon" => Some(0x03A5)
    "/Upsilon1" => Some(0x03D2)
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
    "/theta" => Some(0x03B8)
    "/theta1" => Some(0x03D1)
    "/iota" => Some(0x03B9)
    "/kappa" => Some(0x03BA)
    "/lambda" => Some(0x03BB)
    "/mu" => Some(0x03BC)
    "/nu" => Some(0x03BD)
    "/xi" => Some(0x03BE)
    "/omicron" => Some(0x03BF)
    "/pi" => Some(0x03C0)
    "/rho" => Some(0x03C1)
    "/sigma" => Some(0x03C3)
    "/sigma1" => Some(0x03C2)
    "/tau" => Some(0x03C4)
    "/upsilon" => Some(0x03C5)
    "/phi" => Some(0x03C6)
    "/phi1" => Some(0x03D5)
    "/chi" => Some(0x03C7)
    "/psi" => Some(0x03C8)
    "/omega" => Some(0x03C9)
    "/omega1" => Some(0x03D6)
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
    "/arrowdown" => Some(0x2193)
    "/degree" => Some(0x00B0)
    "/minute" => Some(0x2032)
    "/plusminus" => Some(0x00B1)
    "/second" => Some(0x2033)
    "/florin" => Some(0x0192)
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
    "/radicalex" => Some(0xF8E5)
    "/arrowvertex" => Some(0xF8E6)
    "/arrowhorizex" => Some(0xF8E7)
    "/carriagereturn" => Some(0x21B5)
    "/arrowdblup" => Some(0x21D1)
    "/angleleft" => Some(0x2329)
    "/angleright" => Some(0x232A)
    "/registerserif" => Some(0xF6DA)
    "/copyrightserif" => Some(0xF6D9)
    "/trademarkserif" => Some(0xF6DB)
    "/registersans" => Some(0xF8E8)
    "/copyrightsans" => Some(0xF8E9)
    "/trademarksans" => Some(0xF8EA)
    "/parenlefttp" => Some(0xF8EB)
    "/parenleftex" => Some(0xF8EC)
    "/parenleftbt" => Some(0xF8ED)
    "/bracketlefttp" => Some(0xF8EE)
    "/bracketleftex" => Some(0xF8EF)
    "/bracketleftbt" => Some(0xF8F0)
    "/bracelefttp" => Some(0xF8F1)
    "/braceleftmid" => Some(0xF8F2)
    "/braceleftbt" => Some(0xF8F3)
    "/braceex" => Some(0xF8F4)
    "/integral" => Some(0x222B)
    "/integraltp" => Some(0x2320)
    "/integralex" => Some(0xF8F5)
    "/integralbt" => Some(0x2321)
    "/parenrighttp" => Some(0xF8F6)
    "/parenrightex" => Some(0xF8F7)
    "/parenrightbt" => Some(0xF8F8)
    "/bracketrighttp" => Some(0xF8F9)
    "/bracketrightex" => Some(0xF8FA)
    "/bracketrightbt" => Some(0xF8FB)
    "/bracerighttp" => Some(0xF8FC)
    "/bracerightmid" => Some(0xF8FD)
    "/bracerightbt" => Some(0xF8FE)
    "/lozenge" => Some(0x25CA)
    "/spade" => Some(0x2660)
    "/club" => Some(0x2663)
    "/heart" => Some(0x2665)
    "/diamond" => Some(0x2666)
    _ => None
  }
}

///|
fn pdf_text_codepoint_of_half_fullwidth_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Amonospace" => Some(0xFF21)
    "/Bmonospace" => Some(0xFF22)
    "/Cmonospace" => Some(0xFF23)
    "/Dmonospace" => Some(0xFF24)
    "/Emonospace" => Some(0xFF25)
    "/Fmonospace" => Some(0xFF26)
    "/Gmonospace" => Some(0xFF27)
    "/Hmonospace" => Some(0xFF28)
    "/Imonospace" => Some(0xFF29)
    "/Jmonospace" => Some(0xFF2A)
    "/Kmonospace" => Some(0xFF2B)
    "/Lmonospace" => Some(0xFF2C)
    "/Mmonospace" => Some(0xFF2D)
    "/Nmonospace" => Some(0xFF2E)
    "/Omonospace" => Some(0xFF2F)
    "/Pmonospace" => Some(0xFF30)
    "/Qmonospace" => Some(0xFF31)
    "/Rmonospace" => Some(0xFF32)
    "/Smonospace" => Some(0xFF33)
    "/Tmonospace" => Some(0xFF34)
    "/Umonospace" => Some(0xFF35)
    "/Vmonospace" => Some(0xFF36)
    "/Wmonospace" => Some(0xFF37)
    "/Xmonospace" => Some(0xFF38)
    "/Ymonospace" => Some(0xFF39)
    "/Zmonospace" => Some(0xFF3A)
    "/akatakanahalfwidth" => Some(0xFF71)
    "/amonospace" => Some(0xFF41)
    "/ampersandmonospace" => Some(0xFF06)
    "/asciicircummonospace" => Some(0xFF3E)
    "/asciitildemonospace" => Some(0xFF5E)
    "/asmallkatakanahalfwidth" => Some(0xFF67)
    "/asteriskmonospace" => Some(0xFF0A)
    "/atmonospace" => Some(0xFF20)
    "/backslashmonospace" => Some(0xFF3C)
    "/barmonospace" => Some(0xFF5C)
    "/bmonospace" => Some(0xFF42)
    "/braceleftmonospace" => Some(0xFF5B)
    "/bracerightmonospace" => Some(0xFF5D)
    "/bracketleftmonospace" => Some(0xFF3B)
    "/bracketrightmonospace" => Some(0xFF3D)
    "/centmonospace" => Some(0xFFE0)
    "/cmonospace" => Some(0xFF43)
    "/colonmonospace" => Some(0xFF1A)
    "/commamonospace" => Some(0xFF0C)
    "/cornerbracketlefthalfwidth" => Some(0xFF62)
    "/cornerbracketrighthalfwidth" => Some(0xFF63)
    "/dmonospace" => Some(0xFF44)
    "/dollarmonospace" => Some(0xFF04)
    "/eightmonospace" => Some(0xFF18)
    "/ekatakanahalfwidth" => Some(0xFF74)
    "/emonospace" => Some(0xFF45)
    "/equalmonospace" => Some(0xFF1D)
    "/esmallkatakanahalfwidth" => Some(0xFF6A)
    "/exclammonospace" => Some(0xFF01)
    "/fivemonospace" => Some(0xFF15)
    "/fmonospace" => Some(0xFF46)
    "/fourmonospace" => Some(0xFF14)
    "/gmonospace" => Some(0xFF47)
    "/gravemonospace" => Some(0xFF40)
    "/greatermonospace" => Some(0xFF1E)
    "/hakatakanahalfwidth" => Some(0xFF8A)
    "/hekatakanahalfwidth" => Some(0xFF8D)
    "/hikatakanahalfwidth" => Some(0xFF8B)
    "/hmonospace" => Some(0xFF48)
    "/hokatakanahalfwidth" => Some(0xFF8E)
    "/hukatakanahalfwidth" => Some(0xFF8C)
    "/hyphenmonospace" => Some(0xFF0D)
    "/ideographiccommaleft" => Some(0xFF64)
    "/ikatakanahalfwidth" => Some(0xFF72)
    "/imonospace" => Some(0xFF49)
    "/ismallkatakanahalfwidth" => Some(0xFF68)
    "/jmonospace" => Some(0xFF4A)
    "/kakatakanahalfwidth" => Some(0xFF76)
    "/katahiraprolongmarkhalfwidth" => Some(0xFF70)
    "/kekatakanahalfwidth" => Some(0xFF79)
    "/kikatakanahalfwidth" => Some(0xFF77)
    "/kmonospace" => Some(0xFF4B)
    "/kokatakanahalfwidth" => Some(0xFF7A)
    "/kukatakanahalfwidth" => Some(0xFF78)
    "/lessmonospace" => Some(0xFF1C)
    "/lmonospace" => Some(0xFF4C)
    "/macronmonospace" => Some(0xFFE3)
    "/makatakanahalfwidth" => Some(0xFF8F)
    "/mekatakanahalfwidth" => Some(0xFF92)
    "/middledotkatakanahalfwidth" => Some(0xFF65)
    "/mikatakanahalfwidth" => Some(0xFF90)
    "/mmonospace" => Some(0xFF4D)
    "/mokatakanahalfwidth" => Some(0xFF93)
    "/mukatakanahalfwidth" => Some(0xFF91)
    "/nakatakanahalfwidth" => Some(0xFF85)
    "/nekatakanahalfwidth" => Some(0xFF88)
    "/nikatakanahalfwidth" => Some(0xFF86)
    "/ninemonospace" => Some(0xFF19)
    "/nkatakanahalfwidth" => Some(0xFF9D)
    "/nmonospace" => Some(0xFF4E)
    "/nokatakanahalfwidth" => Some(0xFF89)
    "/nukatakanahalfwidth" => Some(0xFF87)
    "/numbersignmonospace" => Some(0xFF03)
    "/okatakanahalfwidth" => Some(0xFF75)
    "/omonospace" => Some(0xFF4F)
    "/onemonospace" => Some(0xFF11)
    "/osmallkatakanahalfwidth" => Some(0xFF6B)
    "/parenleftmonospace" => Some(0xFF08)
    "/parenrightmonospace" => Some(0xFF09)
    "/percentmonospace" => Some(0xFF05)
    "/periodhalfwidth" => Some(0xFF61)
    "/periodmonospace" => Some(0xFF0E)
    "/plusmonospace" => Some(0xFF0B)
    "/pmonospace" => Some(0xFF50)
    "/qmonospace" => Some(0xFF51)
    "/questionmonospace" => Some(0xFF1F)
    "/quotedblmonospace" => Some(0xFF02)
    "/quotesinglemonospace" => Some(0xFF07)
    "/rakatakanahalfwidth" => Some(0xFF97)
    "/rekatakanahalfwidth" => Some(0xFF9A)
    "/rikatakanahalfwidth" => Some(0xFF98)
    "/rmonospace" => Some(0xFF52)
    "/rokatakanahalfwidth" => Some(0xFF9B)
    "/rukatakanahalfwidth" => Some(0xFF99)
    "/sakatakanahalfwidth" => Some(0xFF7B)
    "/sekatakanahalfwidth" => Some(0xFF7E)
    "/semicolonmonospace" => Some(0xFF1B)
    "/semivoicedmarkkanahalfwidth" => Some(0xFF9F)
    "/sevenmonospace" => Some(0xFF17)
    "/sikatakanahalfwidth" => Some(0xFF7C)
    "/sixmonospace" => Some(0xFF16)
    "/slashmonospace" => Some(0xFF0F)
    "/smonospace" => Some(0xFF53)
    "/sokatakanahalfwidth" => Some(0xFF7F)
    "/sterlingmonospace" => Some(0xFFE1)
    "/sukatakanahalfwidth" => Some(0xFF7D)
    "/takatakanahalfwidth" => Some(0xFF80)
    "/tekatakanahalfwidth" => Some(0xFF83)
    "/threemonospace" => Some(0xFF13)
    "/tikatakanahalfwidth" => Some(0xFF81)
    "/tmonospace" => Some(0xFF54)
    "/tokatakanahalfwidth" => Some(0xFF84)
    "/tukatakanahalfwidth" => Some(0xFF82)
    "/tusmallkatakanahalfwidth" => Some(0xFF6F)
    "/twomonospace" => Some(0xFF12)
    "/ukatakanahalfwidth" => Some(0xFF73)
    "/umonospace" => Some(0xFF55)
    "/underscoremonospace" => Some(0xFF3F)
    "/usmallkatakanahalfwidth" => Some(0xFF69)
    "/vmonospace" => Some(0xFF56)
    "/voicedmarkkanahalfwidth" => Some(0xFF9E)
    "/wakatakanahalfwidth" => Some(0xFF9C)
    "/wmonospace" => Some(0xFF57)
    "/wokatakanahalfwidth" => Some(0xFF66)
    "/wonmonospace" => Some(0xFFE6)
    "/xmonospace" => Some(0xFF58)
    "/yakatakanahalfwidth" => Some(0xFF94)
    "/yasmallkatakanahalfwidth" => Some(0xFF6C)
    "/yenmonospace" => Some(0xFFE5)
    "/ymonospace" => Some(0xFF59)
    "/yokatakanahalfwidth" => Some(0xFF96)
    "/yosmallkatakanahalfwidth" => Some(0xFF6E)
    "/yukatakanahalfwidth" => Some(0xFF95)
    "/yusmallkatakanahalfwidth" => Some(0xFF6D)
    "/zeromonospace" => Some(0xFF10)
    "/zmonospace" => Some(0xFF5A)
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
    "/a54" => Some(0x273B)
    "/a55" => Some(0x273C)
    "/a56" => Some(0x273D)
    "/a57" => Some(0x273E)
    "/a58" => Some(0x273F)
    "/a59" => Some(0x2740)
    "/a60" => Some(0x2741)
    "/a61" => Some(0x2742)
    "/a62" => Some(0x2743)
    "/a63" => Some(0x2744)
    "/a64" => Some(0x2745)
    "/a65" => Some(0x2746)
    "/a66" => Some(0x2747)
    "/a67" => Some(0x2748)
    "/a68" => Some(0x2749)
    "/a69" => Some(0x274A)
    "/a70" => Some(0x274B)
    "/a71" => Some(0x25CF)
    "/a72" => Some(0x274D)
    "/a73" => Some(0x25A0)
    "/a74" => Some(0x274F)
    "/a203" => Some(0x2750)
    "/a75" => Some(0x2751)
    "/a204" => Some(0x2752)
    "/a76" => Some(0x25B2)
    "/a77" => Some(0x25BC)
    "/a78" => Some(0x25C6)
    "/a79" => Some(0x2756)
    "/a81" => Some(0x25D7)
    "/a82" => Some(0x2758)
    "/a83" => Some(0x2759)
    "/a84" => Some(0x275A)
    "/a97" => Some(0x275B)
    "/a98" => Some(0x275C)
    "/a99" => Some(0x275D)
    "/a100" => Some(0x275E)
    "/a101" => Some(0x2761)
    "/a102" => Some(0x2762)
    "/a103" => Some(0x2763)
    "/a104" => Some(0x2764)
    "/a106" => Some(0x2765)
    "/a107" => Some(0x2766)
    "/a108" => Some(0x2767)
    "/a112" => Some(0x2663)
    "/a111" => Some(0x2666)
    "/a110" => Some(0x2665)
    "/a109" => Some(0x2660)
    "/a89" => Some(0x2768)
    "/a90" => Some(0x2769)
    "/a93" => Some(0x276A)
    "/a94" => Some(0x276B)
    "/a91" => Some(0x276C)
    "/a92" => Some(0x276D)
    "/a205" => Some(0x276E)
    "/a85" => Some(0x276F)
    "/a206" => Some(0x2770)
    "/a86" => Some(0x2771)
    "/a87" => Some(0x2772)
    "/a88" => Some(0x2773)
    "/a95" => Some(0x2774)
    "/a96" => Some(0x2775)
    "/a120" => Some(0x2460)
    "/a121" => Some(0x2461)
    "/a122" => Some(0x2462)
    "/a123" => Some(0x2463)
    "/a124" => Some(0x2464)
    "/a125" => Some(0x2465)
    "/a126" => Some(0x2466)
    "/a127" => Some(0x2467)
    "/a128" => Some(0x2468)
    "/a129" => Some(0x2469)
    "/a130" => Some(0x2776)
    "/a131" => Some(0x2777)
    "/a132" => Some(0x2778)
    "/a133" => Some(0x2779)
    "/a134" => Some(0x277A)
    "/a135" => Some(0x277B)
    "/a136" => Some(0x277C)
    "/a137" => Some(0x277D)
    "/a138" => Some(0x277E)
    "/a139" => Some(0x277F)
    "/a140" => Some(0x2780)
    "/a141" => Some(0x2781)
    "/a142" => Some(0x2782)
    "/a143" => Some(0x2783)
    "/a144" => Some(0x2784)
    "/a145" => Some(0x2785)
    "/a146" => Some(0x2786)
    "/a147" => Some(0x2787)
    "/a148" => Some(0x2788)
    "/a149" => Some(0x2789)
    "/a150" => Some(0x278A)
    "/a151" => Some(0x278B)
    "/a152" => Some(0x278C)
    "/a153" => Some(0x278D)
    "/a154" => Some(0x278E)
    "/a155" => Some(0x278F)
    "/a156" => Some(0x2790)
    "/a157" => Some(0x2791)
    "/a158" => Some(0x2792)
    "/a159" => Some(0x2793)
    "/a160" => Some(0x2794)
    "/a161" => Some(0x2192)
    "/a163" => Some(0x2194)
    "/a164" => Some(0x2195)
    "/a196" => Some(0x2798)
    "/a165" => Some(0x2799)
    "/a192" => Some(0x279A)
    "/a166" => Some(0x279B)
    "/a167" => Some(0x279C)
    "/a168" => Some(0x279D)
    "/a169" => Some(0x279E)
    "/a170" => Some(0x279F)
    "/a171" => Some(0x27A0)
    "/a172" => Some(0x27A1)
    "/a173" => Some(0x27A2)
    "/a162" => Some(0x27A3)
    "/a174" => Some(0x27A4)
    "/a175" => Some(0x27A5)
    "/a176" => Some(0x27A6)
    "/a177" => Some(0x27A7)
    "/a178" => Some(0x27A8)
    "/a179" => Some(0x27A9)
    "/a193" => Some(0x27AA)
    "/a180" => Some(0x27AB)
    "/a199" => Some(0x27AC)
    "/a181" => Some(0x27AD)
    "/a200" => Some(0x27AE)
    "/a182" => Some(0x27AF)
    "/a201" => Some(0x27B1)
    "/a183" => Some(0x27B2)
    "/a184" => Some(0x27B3)
    "/a197" => Some(0x27B4)
    "/a185" => Some(0x27B5)
    "/a194" => Some(0x27B6)
    "/a198" => Some(0x27B7)
    "/a186" => Some(0x27B8)
    "/a195" => Some(0x27B9)
    "/a187" => Some(0x27BA)
    "/a188" => Some(0x27BB)
    "/a189" => Some(0x27BC)
    "/a190" => Some(0x27BD)
    "/a191" => Some(0x27BE)
    "/arrowrightheavy" => Some(0x279E)
    "/checkmark" => Some(0x2713)
    "/onecircleinversesansserif" => Some(0x278A)
    "/twocircleinversesansserif" => Some(0x278B)
    "/threecircleinversesansserif" => Some(0x278C)
    "/fourcircleinversesansserif" => Some(0x278D)
    "/fivecircleinversesansserif" => Some(0x278E)
    "/sixcircleinversesansserif" => Some(0x278F)
    "/sevencircleinversesansserif" => Some(0x2790)
    "/eightcircleinversesansserif" => Some(0x2791)
    "/ninecircleinversesansserif" => Some(0x2792)
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
fn pdf_text_upper_hex_letter(byte : Byte) -> Bool {
  let value = byte.to_int()
  value >= 65 && value <= 70
}

///|
fn pdf_text_truetype_control_high_byte(value : Int) -> Bool {
  value == 0x8A ||
  value == 0x8B ||
  value == 0x8C ||
  value == 0x9A ||
  value == 0x9B ||
  value == 0x9C
}

///|
fn pdf_text_truetype_windows_high_byte_table() -> Array[(Int, Int)] {
  [
    (0x82, 0x201A),
    (0x83, 0x0192),
    (0x84, 0x201E),
    (0x85, 0x2026),
    (0x86, 0x2020),
    (0x87, 0x2021),
    (0x88, 0x02C6),
    (0x89, 0x2030),
    (0x8A, 0x0160),
    (0x8B, 0x2039),
    (0x8C, 0x0152),
    (0x91, 0x2018),
    (0x92, 0x2019),
    (0x93, 0x201C),
    (0x94, 0x201D),
    (0x95, 0x2022),
    (0x96, 0x2013),
    (0x97, 0x2014),
    (0x98, 0x02DC),
    (0x99, 0x2122),
    (0x9A, 0x0161),
    (0x9B, 0x203A),
    (0x9C, 0x0153),
    (0x9F, 0x0178),
  ]
}

///|
fn pdf_text_truetype_high_byte_codepoint(value : Int, low_hex : Byte) -> Int? {
  if pdf_text_upper_hex_letter(low_hex) &&
    pdf_text_truetype_control_high_byte(value) {
    Some(value)
  } else {
    for entry in pdf_text_truetype_windows_high_byte_table() {
      if entry.0 == value {
        break Some(entry.1)
      }
    } nobreak {
      None
    }
  }
}

///|
fn pdf_text_truetype_glyphname_codepoints(base : BytesView) -> Array[Int]? {
  guard base.length() == 4 && base[0].to_int() == 47 && base[1].to_int() == 71 else {
    return None
  }
  let high = match pdf_text_hex_digit_value(base[2]) {
    Some(value) => value
    None => return None
  }
  let low = match pdf_text_hex_digit_value(base[3]) {
    Some(value) => value
    None => return None
  }
  let value = high * 16 + low
  if base[2].to_int() == 65 && base[3].to_int() == 54 {
    Some([0x00B6])
  } else if value == 0x6D && pdf_text_upper_hex_letter(base[3]) {
    Some([0x002D])
  } else if (value >= 0x20 && value <= 0x7E) || (value >= 0xA0 && value <= 0xFF) {
    Some([value])
  } else {
    match pdf_text_truetype_high_byte_codepoint(value, base[3]) {
      Some(codepoint) => Some([codepoint])
      None => None
    }
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
fn pdf_text_codepoint_of_agl_base_glyphname(base_name : PdfName) -> Int? {
  match pdf_text_codepoint_of_basic_latin_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_digit_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_punctuation_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_ipa_extension_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_spacing_modifier_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_combining_mark_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_currency_letterlike_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_arrow_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_greek_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_cyrillic_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_armenian_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_hebrew_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_arabic_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_devanagari_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_bengali_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_gurmukhi_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_gujarati_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_thai_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_math_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_number_form_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_technical_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_enclosed_alnum_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_cjk_symbol_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_hiragana_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_katakana_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_bopomofo_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_hangul_compat_jamo_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_enclosed_cjk_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_cjk_compat_square_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_presentation_form_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_box_drawing_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_block_element_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_geometric_shape_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_misc_symbol_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_latin_extended_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_latin_ext_additional_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_private_use_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_expert_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_symbol_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  match pdf_text_codepoint_of_half_fullwidth_glyphname(base_name) {
    Some(codepoint) => return Some(codepoint)
    None => ()
  }
  pdf_text_codepoint_of_dingbat_glyphname(base_name)
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
          match pdf_text_truetype_glyphname_codepoints(base) {
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
                match pdf_text_codepoints_of_agl_sequence_glyphname(base_name) {
                  Some(codepoints) => Some(codepoints)
                  None =>
                    match pdf_text_codepoint_of_agl_base_glyphname(base_name) {
                      Some(codepoint) => Some([codepoint])
                      None => None
                    }
                }
              }
          }
      }
  }
}

///|
fn pdf_text_codepoint_of_agl_symbol_conflict_glyphname(name : PdfName) -> Int? {
  match pdf_text_string_of_name(name) {
    "/Delta" => Some(0x2206)
    "/Omega" => Some(0x2126)
    "/mu" => Some(0x00B5)
    _ => None
  }
}

///|
fn PdfFont::pdf_text_uses_symbol_codepoints(self : PdfFont) -> Bool {
  match self {
    PdfFontStandard(data) =>
      data.font == PdfSymbol && data.encoding == PdfImplicitInFontFile
    _ => false
  }
}

///|
fn PdfFont::pdf_text_codepoints_of_glyphname(
  self : PdfFont,
  glyphname : PdfName,
) -> Array[Int]? {
  if self.pdf_text_uses_symbol_codepoints() {
    pdf_text_codepoints_of_glyphname(glyphname)
  } else {
    match pdf_text_codepoint_of_agl_symbol_conflict_glyphname(glyphname) {
      Some(codepoint) => Some([codepoint])
      None => pdf_text_codepoints_of_glyphname(glyphname)
    }
  }
}

///|
fn PdfFont::pdf_text_glyphname_has_single_codepoint(
  self : PdfFont,
  glyphname : PdfName,
  codepoint : Int,
) -> Bool {
  match self.pdf_text_codepoints_of_glyphname(glyphname) {
    Some([single]) if single == codepoint => true
    _ => false
  }
}

///|
fn PdfEncoding::pdf_text_has_macexpert_base(self : PdfEncoding) -> Bool {
  match self {
    PdfMacExpertEncoding => true
    PdfCustomEncoding(base, _) => base.pdf_text_has_macexpert_base()
    PdfFillUndefinedWithStandard(base) => base.pdf_text_has_macexpert_base()
    _ => false
  }
}

///|
fn PdfFont::pdf_text_has_macexpert_base(self : PdfFont) -> Bool {
  match self {
    PdfFontStandard(data) => data.encoding.pdf_text_has_macexpert_base()
    PdfFontSimple(font) => font.encoding.pdf_text_has_macexpert_base()
    PdfFontCIDKeyed(_) => false
  }
}

///|
fn PdfFont::pdf_text_macexpert_duplicate_charcode(
  self : PdfFont,
  codepoint : Int,
) -> Int? {
  if codepoint == 0xF6E6 && self.pdf_text_has_macexpert_base() {
    Some(0x5F)
  } else {
    None
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
  pdf_text_tounicode_has_charcode(parsed.map[:], code) ||
  pdf_text_cmap_has_charcode_in_any(
    parsed.cid_map[:],
    parsed.notdef_map[:],
    code,
  )
}

///|
fn PdfFont::pdf_text_external_cmap_codepoints(
  self : PdfFont,
  code : Int,
) -> Array[Int]? {
  match self {
    PdfFontCIDKeyed(font) =>
      match font.encoding {
        PdfExternalCMap(_, parsed) =>
          match pdf_text_lookup_cmap_cid(parsed.cid_map[:], code) {
            Some(cid) => Some([cid])
            None =>
              match pdf_text_lookup_cmap_cid(parsed.notdef_map[:], code) {
                Some(cid) => Some([cid])
                None =>
                  match
                    pdf_text_lookup_tounicode_codepoints(parsed.map[:], code) {
                    Some(codepoints) => Some(codepoints)
                    None =>
                      match pdf_text_parsed_cmap_predefined_base(parsed) {
                        Some(name) => {
                          let base_font : PdfFont = PdfFontCIDKeyed({
                            ..font,
                            encoding: PdfPredefinedCMap(name),
                          })
                          match
                            base_font.pdf_text_predefined_builtin_codepoints(
                              code,
                            ) {
                            Some(codepoints) => Some(codepoints)
                            None => None
                          }
                        }
                        None =>
                          if pdf_text_parsed_cmap_has_identity_base(parsed) &&
                            code >= 0 &&
                            code <= 0xFFFF {
                            Some([code])
                          } else {
                            None
                          }
                      }
                  }
              }
          }
        _ => None
      }
    _ => None
  }
}

///|
fn PdfFont::pdf_text_external_cmap_charcode(self : PdfFont, cid : Int) -> Int? {
  match self {
    PdfFontCIDKeyed(font) =>
      match font.encoding {
        PdfExternalCMap(_, parsed) =>
          match pdf_text_reverse_lookup_cmap_cid(parsed.cid_map[:], cid) {
            Some(code) => Some(code)
            None =>
              match
                pdf_text_reverse_lookup_cmap_cid(parsed.notdef_map[:], cid) {
                Some(code) =>
                  if pdf_text_cmap_has_charcode(parsed.cid_map[:], code) {
                    None
                  } else {
                    Some(code)
                  }
                None =>
                  match
                    pdf_text_reverse_lookup_tounicode_charcode(
                      parsed.map[:],
                      cid,
                      parsed.cid_map[:],
                      parsed.notdef_map[:],
                    ) {
                    Some(code) => Some(code)
                    None =>
                      match pdf_text_parsed_cmap_predefined_base(parsed) {
                        Some(name) => {
                          let base_font : PdfFont = PdfFontCIDKeyed({
                            ..font,
                            encoding: PdfPredefinedCMap(name),
                          })
                          match
                            base_font.pdf_text_predefined_builtin_charcode(cid) {
                            Some(code) =>
                              if pdf_text_parsed_cmap_has_explicit_charcode(
                                  parsed, code,
                                ) {
                                None
                              } else {
                                Some(code)
                              }
                            None => None
                          }
                        }
                        None =>
                          if pdf_text_parsed_cmap_has_identity_base(parsed) &&
                            cid >= 0 &&
                            cid <= 0xFFFF &&
                            !pdf_text_parsed_cmap_has_explicit_charcode(
                              parsed, cid,
                            ) {
                            Some(cid)
                          } else {
                            None
                          }
                      }
                  }
              }
          }
        _ => None
      }
    _ => None
  }
}

///|
fn PdfFont::pdf_text_predefined_builtin_codepoints(
  self : PdfFont,
  code : Int,
) -> Array[Int]? {
  match self {
    PdfFontCIDKeyed(font) =>
      match font.encoding {
        PdfPredefinedCMap(name) =>
          match pdf_text_predefined_japan1_builtin_codepoints(name, code) {
            Some(codepoints) => Some(codepoints)
            None =>
              if pdf_text_predefined_cmap_uses_shift_jis_charcodes(name) {
                match pdf_text_predefined_rksj_single_byte_codepoint(code) {
                  Some(codepoint) => Some([codepoint])
                  None => None
                }
              } else if pdf_text_predefined_cmap_uses_gb_euc_charcodes(name) {
                match
                  pdf_text_predefined_vertical_codepoint(
                    pdf_text_predefined_gb1_vertical_codepoint_table(name),
                    code,
                  ) {
                  Some(codepoint) => Some([codepoint])
                  None =>
                    match pdf_text_predefined_gb_euc_codepoint(code) {
                      Some(codepoint) => Some([codepoint])
                      None => None
                    }
                }
              } else if pdf_text_predefined_cmap_uses_gbpc_euc_charcodes(name) {
                match
                  pdf_text_predefined_vertical_codepoint(
                    pdf_text_predefined_gb1_vertical_codepoint_table(name),
                    code,
                  ) {
                  Some(codepoint) => Some([codepoint])
                  None => pdf_text_predefined_gbpc_euc_codepoints(code)
                }
              } else {
                match pdf_text_predefined_cns1_builtin_codepoints(name, code) {
                  Some(codepoints) => Some(codepoints)
                  None =>
                    if pdf_text_predefined_cmap_uses_uhc_charcodes(name) {
                      match
                        pdf_text_predefined_vertical_codepoint(
                          pdf_text_predefined_korea1_vertical_codepoint_table(
                            name,
                          ),
                          code,
                        ) {
                        Some(codepoint) => Some([codepoint])
                        None =>
                          match pdf_text_predefined_uhc_codepoint(code) {
                            Some(codepoint) => Some([codepoint])
                            None => None
                          }
                      }
                    } else if pdf_text_predefined_cmap_uses_ksc_euc_charcodes(
                        name,
                      ) {
                      match
                        pdf_text_predefined_vertical_codepoint(
                          pdf_text_predefined_korea1_vertical_codepoint_table(
                            name,
                          ),
                          code,
                        ) {
                        Some(codepoint) => Some([codepoint])
                        None =>
                          match pdf_text_predefined_ksc_euc_codepoint(code) {
                            Some(codepoint) => Some([codepoint])
                            None => None
                          }
                      }
                    } else if pdf_text_predefined_cmap_uses_kscpc_euc_charcodes(
                        name,
                      ) {
                      match
                        pdf_text_predefined_vertical_codepoint(
                          pdf_text_predefined_korea1_vertical_codepoint_table(
                            name,
                          ),
                          code,
                        ) {
                        Some(codepoint) => Some([codepoint])
                        None => pdf_text_predefined_kscpc_euc_codepoints(code)
                      }
                    } else if pdf_text_predefined_cmap_uses_gbk2k_charcodes(
                        name,
                      ) {
                      match
                        pdf_text_predefined_vertical_codepoint(
                          pdf_text_predefined_gb1_vertical_codepoint_table(name),
                          code,
                        ) {
                        Some(codepoint) => Some([codepoint])
                        None =>
                          match pdf_text_predefined_gbk2k_codepoint(code) {
                            Some(codepoint) => Some([codepoint])
                            None => None
                          }
                      }
                    } else if pdf_text_predefined_cmap_uses_gbk_charcodes(name) {
                      match
                        pdf_text_predefined_vertical_codepoint(
                          pdf_text_predefined_gb1_vertical_codepoint_table(name),
                          code,
                        ) {
                        Some(codepoint) => Some([codepoint])
                        None =>
                          match pdf_text_predefined_gbk_codepoint(code) {
                            Some(codepoint) => Some([codepoint])
                            None => None
                          }
                      }
                    } else {
                      None
                    }
                }
              }
          }
        _ => None
      }
    _ => None
  }
}

///|
fn PdfFont::pdf_text_predefined_builtin_charcode(
  self : PdfFont,
  codepoint : Int,
) -> Int? {
  match self {
    PdfFontCIDKeyed(font) =>
      match font.encoding {
        PdfPredefinedCMap(name) =>
          match pdf_text_predefined_japan1_builtin_charcode(name, codepoint) {
            Some(code) => Some(code)
            None =>
              if pdf_text_predefined_cmap_uses_shift_jis_charcodes(name) {
                pdf_text_predefined_rksj_single_byte_charcode(codepoint)
              } else if pdf_text_predefined_cmap_uses_gb_euc_charcodes(name) {
                match
                  pdf_text_predefined_vertical_charcode(
                    pdf_text_predefined_gb1_vertical_charcode_table(name),
                    codepoint,
                  ) {
                  Some(code) => Some(code)
                  None => pdf_text_predefined_gb_euc_charcode(codepoint)
                }
              } else if pdf_text_predefined_cmap_uses_gbpc_euc_charcodes(name) {
                match
                  pdf_text_predefined_vertical_charcode(
                    pdf_text_predefined_gb1_vertical_charcode_table(name),
                    codepoint,
                  ) {
                  Some(code) => Some(code)
                  None => pdf_text_predefined_gbpc_euc_charcode(codepoint)
                }
              } else {
                match
                  pdf_text_predefined_cns1_builtin_charcode(name, codepoint) {
                  Some(code) => Some(code)
                  None =>
                    if pdf_text_predefined_cmap_uses_uhc_charcodes(name) {
                      match
                        pdf_text_predefined_vertical_charcode(
                          pdf_text_predefined_korea1_vertical_charcode_table(
                            name,
                          ),
                          codepoint,
                        ) {
                        Some(code) => Some(code)
                        None => pdf_text_predefined_uhc_charcode(codepoint)
                      }
                    } else if pdf_text_predefined_cmap_uses_ksc_euc_charcodes(
                        name,
                      ) {
                      match
                        pdf_text_predefined_vertical_charcode(
                          pdf_text_predefined_korea1_vertical_charcode_table(
                            name,
                          ),
                          codepoint,
                        ) {
                        Some(code) => Some(code)
                        None => pdf_text_predefined_ksc_euc_charcode(codepoint)
                      }
                    } else if pdf_text_predefined_cmap_uses_kscpc_euc_charcodes(
                        name,
                      ) {
                      match
                        pdf_text_predefined_vertical_charcode(
                          pdf_text_predefined_korea1_vertical_charcode_table(
                            name,
                          ),
                          codepoint,
                        ) {
                        Some(code) => Some(code)
                        None =>
                          pdf_text_predefined_kscpc_euc_charcode(codepoint)
                      }
                    } else if pdf_text_predefined_cmap_uses_gbk2k_charcodes(
                        name,
                      ) {
                      match
                        pdf_text_predefined_vertical_charcode(
                          pdf_text_predefined_gb1_vertical_charcode_table(name),
                          codepoint,
                        ) {
                        Some(code) => Some(code)
                        None => pdf_text_predefined_gbk2k_charcode(codepoint)
                      }
                    } else if pdf_text_predefined_cmap_uses_gbk_charcodes(name) {
                      match
                        pdf_text_predefined_vertical_charcode(
                          pdf_text_predefined_gb1_vertical_charcode_table(name),
                          codepoint,
                        ) {
                        Some(code) => Some(code)
                        None => pdf_text_predefined_gbk_charcode(codepoint)
                      }
                    } else {
                      None
                    }
                }
              }
          }
        _ => None
      }
    _ => None
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
  let output : Array[Int] = []
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
  if pdf_text_predefined_cmap_uses_mixed_byte_charcodes(name) {
    pdf_text_predefined_mixed_byte_charcodes(name, text)
  } else {
    let output : Array[Int] = []
    if name == pdf_text_name("/Identity-H") ||
      name == pdf_text_name("/Identity-V") ||
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
          if pdf_text_predefined_cmap_uses_mixed_byte_charcodes(name) {
            pdf_text_predefined_mixed_byte_charcodes(name, text)
          } else {
            self.pdf_text_fixed_or_single_byte_charcodes_of_text(text)
          }
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
  let output : Array[Int] = []
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

///|
pub fn PdfTextExtractor::glyphnames_and_codepoints_of_text(
  self : PdfTextExtractor,
  text : BytesView,
) -> Array[PdfTextGlyph] raise PdfError {
  [
    for code in self.font.pdf_text_charcodes_of_text(text) => {
      self.pdf_text_glyph_of_charcode(code)
    }
  ]
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
      match self.font.pdf_text_predefined_builtin_charcode(codepoint) {
        Some(code) => Some(code)
        None =>
          match self.font.pdf_text_external_cmap_charcode(codepoint) {
            Some(code) => Some(code)
            None =>
              for code in 0..<256 {
                match self.font.pdf_text_glyphname_of_charcode(code) {
                  Some(glyphname) =>
                    if self.font.pdf_text_glyphname_has_single_codepoint(
                        glyphname, codepoint,
                      ) {
                      break Some(code)
                    }
                  _ => ()
                }
              } nobreak {
                self.font.pdf_text_macexpert_duplicate_charcode(codepoint)
              }
          }
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
fn pdf_text_rectangle_object(rectangle : PdfRectangle) -> PdfObject {
  PdfArray([
    PdfReal(rectangle.min_x),
    PdfReal(rectangle.min_y),
    PdfReal(rectangle.max_x),
    PdfReal(rectangle.max_y),
  ])
}

///|
fn pdf_text_type3_charprocs_object(
  charprocs : ArrayView[(PdfName, PdfObject)],
) -> PdfObject {
  PdfDictionary([ for entry in charprocs => entry ])
}

///|
fn pdf_text_type3_resources_entries(
  resources : PdfObject,
) -> Array[(PdfName, PdfObject)] {
  match resources {
    PdfDictionary(entries) if entries.length() == 0 => []
    _ => [(pdf_text_name("/Resources"), resources)]
  }
}

///|
fn pdf_text_type3_metrics_entries(
  firstchar : Int,
  lastchar : Int,
  widths : ArrayView[Int],
) -> Array[(PdfName, PdfObject)] {
  if widths.length() == 0 {
    [
      (pdf_text_name("/FirstChar"), PdfInteger(0)),
      (pdf_text_name("/LastChar"), PdfInteger(0)),
      (pdf_text_name("/Widths"), PdfArray([PdfReal(0.0)])),
    ]
  } else {
    [
      (pdf_text_name("/FirstChar"), PdfInteger(firstchar)),
      (pdf_text_name("/LastChar"), PdfInteger(lastchar)),
      (
        pdf_text_name("/Widths"),
        PdfArray([ for width in widths => PdfInteger(width) ]),
      ),
    ]
  }
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
  firstchar : Int,
  lastchar : Int,
  widths : ArrayView[Int],
  encoding : PdfEncoding,
) -> PdfObject raise PdfError {
  PdfDictionary(
    [
      (pdf_text_name("/Type"), PdfNameObject(pdf_text_name("/Font"))),
      (pdf_text_name("/Subtype"), PdfNameObject(pdf_text_name("/Type3"))),
      (pdf_text_name("/FontBBox"), pdf_text_rectangle_object(data.fontbbox)),
      (pdf_text_name("/FontMatrix"), pdf_object_of_matrix(data.fontmatrix)),
      (
        pdf_text_name("/CharProcs"),
        pdf_text_type3_charprocs_object(data.charprocs),
      ),
      ..pdf_text_type3_resources_entries(data.resources),
      ..pdf_text_type3_metrics_entries(firstchar, lastchar, widths),
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
    PdfFontSimple(
      {
        fonttype: PdfType3(data),
        firstchar,
        lastchar,
        widths,
        encoding,
        fontdescriptor,
        ..,
      }
    ) =>
      match fontdescriptor {
        Some(_) =>
          self.pdf_text_add_font_object(
            self.pdf_text_make_type3_font(
              data, firstchar, lastchar, widths, encoding,
            ),
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
