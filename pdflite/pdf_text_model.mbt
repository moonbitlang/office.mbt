///|
/// Parsed standard-font data with its active character encoding.
///
/// Standard 14 fonts do not carry embedded metrics in normal PDF files, so
/// extraction combines the font identity with the chosen simple-font encoding.
pub(all) struct PdfStandardFontData {
  font : PdfStandardFont
  encoding : PdfEncoding
} derive(Debug, Eq, ToJson)

///|
/// Return a compact debug label for this standard font data.
pub fn PdfStandardFontData::debug_name(self : PdfStandardFontData) -> String {
  "StandardFont " + self.font.name()
}

///|
/// Reference to an embedded font program stream in a font descriptor.
///
/// The integer is the object number for `/FontFile`, `/FontFile2`, or
/// `/FontFile3`; the constructor records which descriptor key supplied it.
pub(all) enum PdfFontFile {
  PdfFontFile(Int)
  PdfFontFile2(Int)
  PdfFontFile3(Int)
} derive(Debug, Eq, ToJson)

///|
/// Parsed PDF font descriptor metrics and optional embedded font metadata.
///
/// Numeric fields use PDF glyph-space units. `tounicode` stores decoded
/// `/ToUnicode` mappings when the surrounding font dictionary provides them,
/// so text extraction can prefer explicit Unicode mappings over glyph names.
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
/// Type 3 font glyph-program data.
///
/// `charprocs` keeps glyph names paired with their drawing streams and
/// `resources` is the Type 3 resource dictionary used when interpreting those
/// glyph programs.
pub(all) struct PdfType3Glyphs {
  fontbbox : PdfRectangle
  fontmatrix : TransformMatrix
  charprocs : Array[(PdfName, PdfObject)]
  resources : PdfObject
} derive(Debug, Eq, ToJson)

///|
/// Simple-font subtype recognized by the PDF text layer.
///
/// Type 1, MMType1, Type 3, and TrueType fonts all use one-byte character
/// codes after their encoding differences have been applied.
pub(all) enum PdfSimpleFontType {
  PdfType1
  PdfMMType1
  PdfType3(PdfType3Glyphs)
  PdfTrueType
} derive(Debug, Eq, ToJson)

///|
/// Parsed simple-font dictionary.
///
/// The record preserves declared widths and descriptors when present. Missing
/// metrics are resolved from standard-font fallback data where possible.
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
/// CID-system identity from a CIDFont or CMap dictionary.
///
/// `registry` and `ordering` are stored as PDF bytes because PDF strings are
/// byte sequences, not MoonBit `String` values.
pub(all) struct PdfCIDSystemInfo {
  registry : PdfBytes
  ordering : PdfBytes
  supplement : Int
} derive(Debug, Eq, ToJson)

///|
/// Vertical metrics for a CID in a composite font.
///
/// The fields correspond to the PDF `/W2` tuple: vertical width and horizontal
/// displacement vector components.
pub(all) struct PdfCIDVerticalWidth {
  width : Double
  vx : Double
  vy : Double
} derive(Debug, Eq, ToJson)

///|
/// Parsed descendant CIDFont data for a Type 0 composite font.
///
/// Width arrays are normalized into explicit CID-to-width entries while
/// preserving the PDF default horizontal and vertical widths.
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
/// CMap source used by a Type 0 font.
///
/// A CMap may be predefined by name, referenced as an external stream object,
/// or parsed from that external stream together with its mapping tables.
pub(all) enum PdfCMapEncoding {
  PdfPredefinedCMap(PdfName)
  PdfCMap(Int)
  PdfExternalCMap(Int, PdfParsedCMap)
} derive(Debug, Eq, ToJson)

///|
/// One parsed CMap code-space range.
///
/// `length` is the character-code byte length, and `first`/`last` are the
/// inclusive packed-byte bounds accepted by that range.
pub(all) struct PdfCMapCodeSpace {
  length : Int
  first : Int
  last : Int
} derive(Debug, Eq, ToJson)

///|
/// Parsed CMap or ToUnicode stream data.
///
/// `map` stores character-code to UTF-16BE bytes from `bfchar`/`bfrange`,
/// `cid_map` stores character-code to CID mappings, and `notdef_map` stores
/// notdef fallback CIDs. Optional metadata is taken from the stream body or
/// stream dictionary when available.
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
/// Parsed Type 0 font with descendant CIDFont and CMap encoding.
pub(all) struct PdfCIDKeyedFont {
  basefont : PdfName
  composite : PdfCompositeCIDFont
  encoding : PdfCMapEncoding
} derive(Debug, Eq, ToJson)

///|
/// Return a compact debug label containing the Type 0 base font name.
pub fn PdfCIDKeyedFont::debug_name(self : PdfCIDKeyedFont) -> String {
  "CIDKeyedFont " + pdf_text_string_of_name(self.basefont)
}

///|
/// Test whether this CMap encoding is the predefined `/Identity-H` map.
pub fn PdfCMapEncoding::is_identity_h(self : PdfCMapEncoding) -> Bool {
  match self {
    PdfPredefinedCMap(name) => name == pdf_text_identity_h_name
    _ => false
  }
}

///|
/// Test whether this CMap encoding is the predefined `/Identity-V` map.
pub fn PdfCMapEncoding::is_identity_v(self : PdfCMapEncoding) -> Bool {
  match self {
    PdfPredefinedCMap(name) => name == pdf_text_identity_v_name
    _ => false
  }
}
