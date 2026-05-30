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
