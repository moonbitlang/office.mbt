///|
/// Parsed standard-font data with its active character encoding.
///
/// Standard 14 fonts do not carry embedded metrics in normal PDF files, so
/// extraction combines the font identity with the chosen simple-font encoding.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfStandardFontData {
  font : PdfStandardFont
  encoding : PdfEncoding
}

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
#derive(Debug, Eq, ToJson)
pub(all) enum PdfFontFile {
  PdfFontFile(Int32)
  PdfFontFile2(Int32)
  PdfFontFile3(Int32)
}

///|
/// Parsed PDF font descriptor metrics and optional embedded font metadata.
///
/// Numeric fields use PDF glyph-space units. `tounicode` stores decoded
/// `/ToUnicode` mappings when the surrounding font dictionary provides them,
/// so text extraction can prefer explicit Unicode mappings over glyph names.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfFontDescriptor {
  ascent : Double
  descent : Double
  avgwidth : Double
  maxwidth : Double
  flags : Int32
  fontbbox : @geometry.PdfRectangle
  italicangle : Double
  capheight : Double
  xheight : Double
  stemv : Double
  fontfile : PdfFontFile?
  charset : Array[@core.PdfName]?
  tounicode : Array[(Int32, @core.PdfBytes)]?
}

///|
/// Type 3 font glyph-program data.
///
/// `charprocs` keeps glyph names paired with their drawing streams and
/// `resources` is the Type 3 resource dictionary used when interpreting those
/// glyph programs.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfType3Glyphs {
  fontbbox : @geometry.PdfRectangle
  fontmatrix : @geometry.TransformMatrix
  charprocs : Array[(@core.PdfName, @syntax.PdfObject)]
  resources : @syntax.PdfObject
}

///|
/// Simple-font subtype recognized by the PDF text layer.
///
/// Type 1, MMType1, Type 3, and TrueType fonts all use one-byte character
/// codes after their encoding differences have been applied.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfSimpleFontType {
  PdfType1
  PdfMMType1
  PdfType3(PdfType3Glyphs)
  PdfTrueType
}

///|
/// Parsed simple-font dictionary.
///
/// The record preserves declared widths and descriptors when present. Missing
/// metrics are resolved from standard-font fallback data where possible.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfSimpleFont {
  fonttype : PdfSimpleFontType
  basefont : @core.PdfName?
  firstchar : Int32
  lastchar : Int32
  widths : Array[Int32]
  fontdescriptor : PdfFontDescriptor?
  fontmetrics : Array[Double]?
  encoding : PdfEncoding
}

///|
/// CID-system identity from a CIDFont or CMap dictionary.
///
/// `registry` and `ordering` are stored as PDF bytes because PDF strings are
/// byte sequences, not MoonBit `String` values.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfCIDSystemInfo {
  registry : @core.PdfBytes
  ordering : @core.PdfBytes
  supplement : Int32
}

///|
/// Vertical metrics for a CID in a composite font.
///
/// The fields correspond to the PDF `/W2` tuple: vertical width and horizontal
/// displacement vector components.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfCIDVerticalWidth {
  width : Double
  vx : Double
  vy : Double
}

///|
/// Parsed descendant CIDFont data for a Type 0 composite font.
///
/// Width arrays are normalized into explicit CID-to-width entries while
/// preserving the PDF default horizontal and vertical widths.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfCompositeCIDFont {
  cid_system_info : PdfCIDSystemInfo
  cid_basefont : @core.PdfName
  cid_fontdescriptor : PdfFontDescriptor
  cid_widths : Array[(Int32, Double)]
  cid_widths2 : Array[(Int32, PdfCIDVerticalWidth)]
  cid_default_width : Double
  cid_default_width2 : Array[Double]
}

///|
/// CMap source used by a Type 0 font.
///
/// A CMap may be predefined by name, referenced as an external stream object,
/// or parsed from that external stream together with its mapping tables.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfCMapEncoding {
  PdfPredefinedCMap(@core.PdfName)
  PdfCMap(Int32)
  PdfExternalCMap(Int32, PdfParsedCMap)
}

///|
/// One parsed CMap code-space range.
///
/// `length` is the character-code byte length, and `first`/`last` are the
/// inclusive packed-byte bounds accepted by that range.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfCMapCodeSpace {
  length : Int32
  first : Int32
  last : Int32
}

///|
/// Parsed CMap or ToUnicode stream data.
///
/// `map` stores character-code to UTF-16BE bytes from `bfchar`/`bfrange`,
/// `cid_map` stores character-code to CID mappings, and `notdef_map` stores
/// notdef fallback CIDs. Optional metadata is taken from the stream body or
/// stream dictionary when available.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfParsedCMap {
  map : Array[(Int32, @core.PdfBytes)]
  cid_map : Array[(Int32, Int32)]
  notdef_map : Array[(Int32, Int32)]
  codespaces : Array[PdfCMapCodeSpace]
  usecmap : @core.PdfName?
  wmode : Int32?
  cmap_name : @core.PdfName?
  cmap_type : Int32?
  cid_system_info : PdfCIDSystemInfo?
}

///|
/// Parsed Type 0 font with descendant CIDFont and CMap encoding.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfCIDKeyedFont {
  basefont : @core.PdfName
  composite : PdfCompositeCIDFont
  encoding : PdfCMapEncoding
}

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
