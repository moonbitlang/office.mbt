///|
/// One `/Differences` entry in a simple-font encoding dictionary.
///
/// `code` is the one-byte character code that maps to `name`.
pub(all) struct PdfEncodingDifference {
  name : @core.PdfName
  code : Int
} derive(Debug, Eq, ToJson)

///|
/// Simple-font character encoding.
///
/// `PdfCustomEncoding` layers `/Differences` over a base encoding.
/// `PdfFillUndefinedWithStandard` models TrueType behavior where undefined
/// entries fall back to StandardEncoding.
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
/// Parsed font model used by text extraction and font writing.
pub(all) enum PdfFont {
  PdfFontStandard(PdfStandardFontData)
  PdfFontSimple(PdfSimpleFont)
  PdfFontCIDKeyed(PdfCIDKeyedFont)
} derive(Debug, Eq, ToJson)

///|
/// Text extractor bound to a parsed font.
///
/// The extractor converts PDF text-string bytes to character codes, glyph
/// names, and Unicode codepoints according to the font's encoding data.
pub(all) struct PdfTextExtractor {
  font : PdfFont
} derive(Debug, Eq, ToJson)

///|
/// Extracted glyph result for one character code.
///
/// `glyphname` is the resolved PDF glyph name and `codepoints` is the Unicode
/// scalar sequence inferred from ToUnicode, CMap, or Adobe glyph-list data.
pub(all) struct PdfTextGlyph {
  glyphname : @core.PdfName
  codepoints : Array[Int]
} derive(Debug, Eq, ToJson)
