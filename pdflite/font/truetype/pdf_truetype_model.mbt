///|
/// TrueType table-directory record.
pub(all) struct PdfTrueTypeTableRecord {
  tag : String
  checksum : UInt
  offset : Int
  length : Int
} derive(Debug, Eq, ToJson)

///|
/// Core metrics extracted from TrueType `head`, `hhea`, `hmtx`, and `maxp`.
pub(all) struct PdfTrueTypeMetrics {
  units_per_em : Int
  minx : Int
  miny : Int
  maxx : Int
  maxy : Int
  index_to_loc_format : Int
  num_glyphs : Int
  num_of_long_hor_metrics : Int
  advance_widths : Array[Int]
  max_width : Int
} derive(Debug, Eq, ToJson)

///|
/// Font descriptor metrics derived from TrueType tables.
pub(all) struct PdfTrueTypeDescriptorMetrics {
  ascent : Int
  descent : Int
  capheight : Int
  xheight : Int
  avgwidth : Int
  italicangle : Int
  nonsymbolic_flags : Int
  symbolic_flags : Int
} derive(Debug, Eq, ToJson)

///|
/// Mapping from a Unicode codepoint to a TrueType glyph index.
pub(all) struct PdfTrueTypeCMapGlyph {
  codepoint : Int
  glyph_index : Int
} derive(Debug, Eq, ToJson)

///|
/// Byte range for one glyph inside the TrueType `glyf` table.
pub(all) struct PdfTrueTypeGlyphByteRange {
  glyph_index : Int
  start_offset : Int
  end_offset : Int
} derive(Debug, Eq, ToJson)

///|
/// Result of splitting a TrueType Unicode subset into cpdf's main and higher
/// subset groups.
pub(all) struct PdfTrueTypeSubsetPartition {
  main_subset : Array[Int]
  higher_subsets : Array[Array[Int]]
} derive(Debug, Eq, ToJson)

///|
/// Rebuilt subset-table bytes and their unpadded logical length.
pub(all) struct PdfTrueTypeSubsetTable {
  length : Int
  bytes : Bytes
} derive(Debug, Eq)

///|
/// One subset record returned by cpdf-style TrueType parsing.
pub(all) struct PdfTrueTypeParsedSubset {
  flags : Int
  minx : Int
  miny : Int
  maxx : Int
  maxy : Int
  italicangle : Int
  ascent : Int
  descent : Int
  capheight : Int
  stemv : Int
  xheight : Int
  avgwidth : Int
  maxwidth : Int
  firstchar : Int
  lastchar : Int
  widths : Array[Int]
  subset_fontfile : Bytes
  subset : Array[Int]
  tounicode : Array[(Int, Bytes)]?
} derive(Debug, Eq)
