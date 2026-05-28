///|
/// The built-in PDF standard 14 font faces.
///
/// These values name the base fonts that a conforming PDF reader is expected
/// to know without an embedded font program. The variants match the canonical
/// PDF names used in `/BaseFont` entries.
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
/// Return the canonical standard-font name without the leading PDF slash.
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
/// Compatibility wrapper for `PdfStandardFont::name`.
pub fn pdf_string_of_standard_font(font : PdfStandardFont) -> String {
  font.name()
}

///|
fn pdf_text_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_text_static_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_text_slash_name : PdfName = pdf_text_static_name("/")

///|
let pdf_text_times_roman_name : PdfName = pdf_text_static_name("/Times-Roman")

///|
let pdf_text_times_new_roman_name : PdfName = pdf_text_static_name(
  "/TimesNewRoman",
)

///|
let pdf_text_times_bold_name : PdfName = pdf_text_static_name("/Times-Bold")

///|
let pdf_text_times_new_roman_bold_name : PdfName = pdf_text_static_name(
  "/TimesNewRoman,Bold",
)

///|
let pdf_text_times_italic_name : PdfName = pdf_text_static_name("/Times-Italic")

///|
let pdf_text_times_new_roman_italic_name : PdfName = pdf_text_static_name(
  "/TimesNewRoman,Italic",
)

///|
let pdf_text_times_bold_italic_name : PdfName = pdf_text_static_name(
  "/Times-BoldItalic",
)

///|
let pdf_text_times_new_roman_bold_italic_name : PdfName = pdf_text_static_name(
  "/TimesNewRoman,BoldItalic",
)

///|
let pdf_text_helvetica_name : PdfName = pdf_text_static_name("/Helvetica")

///|
let pdf_text_arial_name : PdfName = pdf_text_static_name("/Arial")

///|
let pdf_text_helvetica_bold_name : PdfName = pdf_text_static_name(
  "/Helvetica-Bold",
)

///|
let pdf_text_arial_bold_name : PdfName = pdf_text_static_name("/Arial,Bold")

///|
let pdf_text_helvetica_oblique_name : PdfName = pdf_text_static_name(
  "/Helvetica-Oblique",
)

///|
let pdf_text_arial_italic_name : PdfName = pdf_text_static_name("/Arial,Italic")

///|
let pdf_text_helvetica_bold_oblique_name : PdfName = pdf_text_static_name(
  "/Helvetica-BoldOblique",
)

///|
let pdf_text_arial_bold_italic_name : PdfName = pdf_text_static_name(
  "/Arial,BoldItalic",
)

///|
let pdf_text_courier_name : PdfName = pdf_text_static_name("/Courier")

///|
let pdf_text_courier_new_name : PdfName = pdf_text_static_name("/CourierNew")

///|
let pdf_text_courier_bold_name : PdfName = pdf_text_static_name("/Courier-Bold")

///|
let pdf_text_courier_new_bold_name : PdfName = pdf_text_static_name(
  "/CourierNew,Bold",
)

///|
let pdf_text_courier_oblique_name : PdfName = pdf_text_static_name(
  "/Courier-Oblique",
)

///|
let pdf_text_courier_new_italic_name : PdfName = pdf_text_static_name(
  "/CourierNew,Italic",
)

///|
let pdf_text_courier_bold_oblique_name : PdfName = pdf_text_static_name(
  "/Courier-BoldOblique",
)

///|
let pdf_text_courier_new_bold_italic_name : PdfName = pdf_text_static_name(
  "/CourierNew,BoldItalic",
)

///|
let pdf_text_symbol_name : PdfName = pdf_text_static_name("/Symbol")

///|
let pdf_text_zapf_dingbats_name : PdfName = pdf_text_static_name(
  "/ZapfDingbats",
)

///|
let pdf_text_identity_h_name : PdfName = pdf_text_static_name("/Identity-H")

///|
let pdf_text_identity_v_name : PdfName = pdf_text_static_name("/Identity-V")

///|
let pdf_text_standard_encoding_name : PdfName = pdf_text_static_name(
  "/StandardEncoding",
)

///|
let pdf_text_mac_roman_encoding_name : PdfName = pdf_text_static_name(
  "/MacRomanEncoding",
)

///|
let pdf_text_win_ansi_encoding_name : PdfName = pdf_text_static_name(
  "/WinAnsiEncoding",
)

///|
let pdf_text_mac_expert_encoding_name : PdfName = pdf_text_static_name(
  "/MacExpertEncoding",
)

///|
let pdf_text_font_file_key_name : PdfName = pdf_text_static_name("/FontFile")

///|
let pdf_text_font_file2_key_name : PdfName = pdf_text_static_name("/FontFile2")

///|
let pdf_text_font_file3_key_name : PdfName = pdf_text_static_name("/FontFile3")

///|
let pdf_text_charset_key_name : PdfName = pdf_text_static_name("/CharSet")

///|
let pdf_text_font_descriptor_key_name : PdfName = pdf_text_static_name(
  "/FontDescriptor",
)

///|
let pdf_text_font_bbox_key_name : PdfName = pdf_text_static_name("/FontBBox")

///|
let pdf_text_ascent_key_name : PdfName = pdf_text_static_name("/Ascent")

///|
let pdf_text_descent_key_name : PdfName = pdf_text_static_name("/Descent")

///|
let pdf_text_avg_width_key_name : PdfName = pdf_text_static_name("/AvgWidth")

///|
let pdf_text_max_width_key_name : PdfName = pdf_text_static_name("/MaxWidth")

///|
let pdf_text_flags_key_name : PdfName = pdf_text_static_name("/Flags")

///|
let pdf_text_italic_angle_key_name : PdfName = pdf_text_static_name(
  "/ItalicAngle",
)

///|
let pdf_text_cap_height_key_name : PdfName = pdf_text_static_name("/CapHeight")

///|
let pdf_text_xheight_key_name : PdfName = pdf_text_static_name("/XHeight")

///|
let pdf_text_stemv_key_name : PdfName = pdf_text_static_name("/StemV")

///|
let pdf_text_subtype_key_name : PdfName = pdf_text_static_name("/Subtype")

///|
let pdf_text_type3_name : PdfName = pdf_text_static_name("/Type3")

///|
let pdf_text_missing_width_key_name : PdfName = pdf_text_static_name(
  "/MissingWidth",
)

///|
let pdf_text_widths_key_name : PdfName = pdf_text_static_name("/Widths")

///|
let pdf_text_first_char_key_name : PdfName = pdf_text_static_name("/FirstChar")

///|
let pdf_text_last_char_key_name : PdfName = pdf_text_static_name("/LastChar")

///|
let pdf_text_charprocs_key_name : PdfName = pdf_text_static_name("/CharProcs")

///|
let pdf_text_resources_key_name : PdfName = pdf_text_static_name("/Resources")

///|
let pdf_text_font_matrix_key_name : PdfName = pdf_text_static_name(
  "/FontMatrix",
)

///|
let pdf_text_type1_name : PdfName = pdf_text_static_name("/Type1")

///|
let pdf_text_mmtype1_name : PdfName = pdf_text_static_name("/MMType1")

///|
let pdf_text_true_type_name_value : PdfName = pdf_text_static_name("/TrueType")

///|
let pdf_text_base_font_key_name : PdfName = pdf_text_static_name("/BaseFont")

///|
let pdf_text_font_name : PdfName = pdf_text_static_name("/Font")

///|
let pdf_text_encoding_key_name : PdfName = pdf_text_static_name("/Encoding")

///|
let pdf_text_base_encoding_key_name : PdfName = pdf_text_static_name(
  "/BaseEncoding",
)

///|
let pdf_text_differences_key_name : PdfName = pdf_text_static_name(
  "/Differences",
)

///|
let pdf_text_type0_name : PdfName = pdf_text_static_name("/Type0")

///|
let pdf_text_registry_key_name : PdfName = pdf_text_static_name("/Registry")

///|
let pdf_text_ordering_key_name : PdfName = pdf_text_static_name("/Ordering")

///|
let pdf_text_supplement_key_name : PdfName = pdf_text_static_name("/Supplement")

///|
let pdf_text_w_key_name : PdfName = pdf_text_static_name("/W")

///|
let pdf_text_w2_key_name : PdfName = pdf_text_static_name("/W2")

///|
let pdf_text_dw_key_name : PdfName = pdf_text_static_name("/DW")

///|
let pdf_text_dw2_key_name : PdfName = pdf_text_static_name("/DW2")

///|
let pdf_text_cid_system_info_key_name : PdfName = pdf_text_static_name(
  "/CIDSystemInfo",
)

///|
let pdf_text_descendant_fonts_key_name : PdfName = pdf_text_static_name(
  "/DescendantFonts",
)

///|
let pdf_text_wmode_key_name : PdfName = pdf_text_static_name("/WMode")

///|
let pdf_text_cmap_name_key_name : PdfName = pdf_text_static_name("/CMapName")

///|
let pdf_text_cmap_type_key_name : PdfName = pdf_text_static_name("/CMapType")

///|
let pdf_text_usecmap_key_name : PdfName = pdf_text_static_name("/UseCMap")

///|
let pdf_text_tounicode_key_name : PdfName = pdf_text_static_name("/ToUnicode")

///|
let pdf_text_type_key_name : PdfName = pdf_text_static_name("/Type")

///|
let pdf_text_font_name_key_name : PdfName = pdf_text_static_name("/FontName")

///|
let pdf_text_length_key_name : PdfName = pdf_text_static_name("/Length")

///|
fn pdf_text_static_single_byte_glyph_name(value : Int) -> PdfName {
  let bytes : FixedArray[Byte] = [47, value.to_byte()]
  pdf_name_of_bytes(Bytes::from_array(bytes))
}

///|
let pdf_text_glyph_space_name : PdfName = pdf_text_static_name("/space")

///|
fn pdf_text_ascii_basic_latin_glyph_name_for_cache(
  code : Int,
  standard_quotes : Bool,
) -> PdfName? {
  match code {
    32 => Some(pdf_text_glyph_space_name)
    33 => Some(pdf_text_static_name("/exclam"))
    34 => Some(pdf_text_static_name("/quotedbl"))
    35 => Some(pdf_text_static_name("/numbersign"))
    36 => Some(pdf_text_static_name("/dollar"))
    37 => Some(pdf_text_static_name("/percent"))
    38 => Some(pdf_text_static_name("/ampersand"))
    39 if standard_quotes => Some(pdf_text_static_name("/quoteright"))
    39 => Some(pdf_text_static_name("/quotesingle"))
    40 => Some(pdf_text_static_name("/parenleft"))
    41 => Some(pdf_text_static_name("/parenright"))
    42 => Some(pdf_text_static_name("/asterisk"))
    43 => Some(pdf_text_static_name("/plus"))
    44 => Some(pdf_text_static_name("/comma"))
    45 => Some(pdf_text_static_name("/hyphen"))
    46 => Some(pdf_text_static_name("/period"))
    47 => Some(pdf_text_static_name("/slash"))
    48 => Some(pdf_text_static_name("/zero"))
    49 => Some(pdf_text_static_name("/one"))
    50 => Some(pdf_text_static_name("/two"))
    51 => Some(pdf_text_static_name("/three"))
    52 => Some(pdf_text_static_name("/four"))
    53 => Some(pdf_text_static_name("/five"))
    54 => Some(pdf_text_static_name("/six"))
    55 => Some(pdf_text_static_name("/seven"))
    56 => Some(pdf_text_static_name("/eight"))
    57 => Some(pdf_text_static_name("/nine"))
    58 => Some(pdf_text_static_name("/colon"))
    59 => Some(pdf_text_static_name("/semicolon"))
    60 => Some(pdf_text_static_name("/less"))
    61 => Some(pdf_text_static_name("/equal"))
    62 => Some(pdf_text_static_name("/greater"))
    63 => Some(pdf_text_static_name("/question"))
    64 => Some(pdf_text_static_name("/at"))
    code if code >= 65 && code <= 90 =>
      Some(pdf_text_static_single_byte_glyph_name(code))
    91 => Some(pdf_text_static_name("/bracketleft"))
    92 => Some(pdf_text_static_name("/backslash"))
    93 => Some(pdf_text_static_name("/bracketright"))
    94 => Some(pdf_text_static_name("/asciicircum"))
    95 => Some(pdf_text_static_name("/underscore"))
    96 if standard_quotes => Some(pdf_text_static_name("/quoteleft"))
    96 => Some(pdf_text_static_name("/grave"))
    code if code >= 97 && code <= 122 =>
      Some(pdf_text_static_single_byte_glyph_name(code))
    123 => Some(pdf_text_static_name("/braceleft"))
    124 => Some(pdf_text_static_name("/bar"))
    125 => Some(pdf_text_static_name("/braceright"))
    126 => Some(pdf_text_static_name("/asciitilde"))
    _ => None
  }
}

///|
let pdf_text_standard_basic_latin_glyph_names : FixedArray[PdfName?] = FixedArray::makei(
  127,
  code => pdf_text_ascii_basic_latin_glyph_name_for_cache(code, true),
)

///|
let pdf_text_plain_basic_latin_glyph_names : FixedArray[PdfName?] = FixedArray::makei(
  127,
  code => pdf_text_ascii_basic_latin_glyph_name_for_cache(code, false),
)

///|
let pdf_text_glyph_control_ht_name : PdfName = pdf_text_static_name(
  "/controlHT",
)

///|
let pdf_text_glyph_control_lf_name : PdfName = pdf_text_static_name(
  "/controlLF",
)

///|
let pdf_text_glyph_control_ff_name : PdfName = pdf_text_static_name(
  "/controlFF",
)

///|
let pdf_text_glyph_control_cr_name : PdfName = pdf_text_static_name(
  "/controlCR",
)

///|
fn pdf_text_cached_basic_latin_glyphname(
  code : Int,
  standard_quotes : Bool,
) -> PdfName? {
  if code < 0 || code > 126 {
    None
  } else if standard_quotes {
    pdf_text_standard_basic_latin_glyph_names[code]
  } else {
    pdf_text_plain_basic_latin_glyph_names[code]
  }
}

///|
fn pdf_text_string_of_name(name : PdfName) -> String {
  @ascii.decode_lossy(name.bytes())
}

///|
/// Return the canonical PDF name object for this standard font.
///
/// The returned name includes the leading slash in the underlying `PdfName`
/// bytes and is suitable for `/BaseFont` dictionary entries.
pub fn PdfStandardFont::pdf_name(self : PdfStandardFont) -> PdfName {
  match self {
    PdfTimesRoman => pdf_text_times_roman_name
    PdfTimesBold => pdf_text_times_bold_name
    PdfTimesItalic => pdf_text_times_italic_name
    PdfTimesBoldItalic => pdf_text_times_bold_italic_name
    PdfHelvetica => pdf_text_helvetica_name
    PdfHelveticaBold => pdf_text_helvetica_bold_name
    PdfHelveticaOblique => pdf_text_helvetica_oblique_name
    PdfHelveticaBoldOblique => pdf_text_helvetica_bold_oblique_name
    PdfCourier => pdf_text_courier_name
    PdfCourierBold => pdf_text_courier_bold_name
    PdfCourierOblique => pdf_text_courier_oblique_name
    PdfCourierBoldOblique => pdf_text_courier_bold_oblique_name
    PdfSymbol => pdf_text_symbol_name
    PdfZapfDingbats => pdf_text_zapf_dingbats_name
  }
}

///|
/// Recognize a standard 14 font from an ASCII PDF font name.
///
/// `name` is expected to include the leading slash, for example
/// `"/Helvetica"`. Common Microsoft aliases such as `/Arial` and
/// `/TimesNewRoman` are accepted for CamlPDF compatibility.
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
/// Recognize a standard 14 font from a byte-oriented PDF name.
///
/// This is the allocation-light variant used while parsing font dictionaries.
/// It accepts the canonical PDF names and the same common aliases as
/// `pdf_standard_font_of_name`.
pub fn pdf_standard_font_of_pdf_name(name : PdfName) -> PdfStandardFont? {
  match name {
    name if name == pdf_text_times_roman_name ||
      name == pdf_text_times_new_roman_name => Some(PdfTimesRoman)
    name if name == pdf_text_times_bold_name ||
      name == pdf_text_times_new_roman_bold_name => Some(PdfTimesBold)
    name if name == pdf_text_times_italic_name ||
      name == pdf_text_times_new_roman_italic_name => Some(PdfTimesItalic)
    name if name == pdf_text_times_bold_italic_name ||
      name == pdf_text_times_new_roman_bold_italic_name =>
      Some(PdfTimesBoldItalic)
    name if name == pdf_text_helvetica_name || name == pdf_text_arial_name =>
      Some(PdfHelvetica)
    name if name == pdf_text_helvetica_bold_name ||
      name == pdf_text_arial_bold_name => Some(PdfHelveticaBold)
    name if name == pdf_text_helvetica_oblique_name ||
      name == pdf_text_arial_italic_name => Some(PdfHelveticaOblique)
    name if name == pdf_text_helvetica_bold_oblique_name ||
      name == pdf_text_arial_bold_italic_name => Some(PdfHelveticaBoldOblique)
    name if name == pdf_text_courier_name || name == pdf_text_courier_new_name =>
      Some(PdfCourier)
    name if name == pdf_text_courier_bold_name ||
      name == pdf_text_courier_new_bold_name => Some(PdfCourierBold)
    name if name == pdf_text_courier_oblique_name ||
      name == pdf_text_courier_new_italic_name => Some(PdfCourierOblique)
    name if name == pdf_text_courier_bold_oblique_name ||
      name == pdf_text_courier_new_bold_italic_name =>
      Some(PdfCourierBoldOblique)
    name if name == pdf_text_symbol_name => Some(PdfSymbol)
    name if name == pdf_text_zapf_dingbats_name => Some(PdfZapfDingbats)
    _ => None
  }
}

///|
/// Return a synthetic baseline adjustment for simple standard-font placement.
///
/// The value is derived from the font ascent-like metrics used by the original
/// CamlPDF helpers and is expressed in glyph-space units.
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
/// Return the standard-font `StemV` descriptor value used when writing fonts.
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
/// Return PDF font descriptor flags for this standard font.
///
/// The flags distinguish symbolic fonts, fixed-pitch Courier faces, and the
/// nonsymbolic roman faces according to the PDF font descriptor bit layout.
pub fn PdfStandardFont::flags(self : PdfStandardFont) -> Int {
  match self {
    PdfSymbol => 65541
    PdfZapfDingbats => 4
    PdfCourier | PdfCourierBold | PdfCourierOblique | PdfCourierBoldOblique =>
      33
    _ => 32
  }
}
