///|
/// A URL span parsed from cpdf add-text `%URL[text|url]` markup.
///
/// `start` and `end` are byte offsets in the visible output line, matching
/// OCaml cpdf's `String.length` accounting.
pub(all) struct PdfAddTextUrl {
  url : String
  start : Int
  end : Int
} derive(Debug, Eq, ToJson)

///|
/// One add-text line after stripping `%URL[text|url]` markup.
pub(all) struct PdfAddTextUrlLine {
  text : String
  urls : Array[PdfAddTextUrl]
} derive(Debug, Eq, ToJson)

///|
/// Transformed geometry for one add-text URL annotation.
pub(all) struct PdfAddTextUrlAnnotationGeometry {
  p0 : Point2
  p1 : Point2
  p2 : Point2
  p3 : Point2
  rectangle : PdfRectangle
} derive(Debug, Eq, ToJson)

///|
/// Resolved placement values for one cpdf add-text line.
pub(all) struct PdfAddTextLinePlacement {
  origin : Point2
  base_rotation : Double
  text_rotation : Double
  rotation_offset : Point2
  horizontal_offset : Double
  vertical_offset : Double
  justification_offset : Double
} derive(Debug, Eq, ToJson)

///|
/// Width measurements for one cpdf add-text line and its expanded paragraph.
pub(all) struct PdfAddTextLineWidths {
  text_width : Double
  widths : Array[Double]
  longest_width : Double
} derive(Debug, Eq, ToJson)

///|
/// One cpdf add-text line after replacement expansion, URL stripping, width
/// measurement, and placement resolution.
pub(all) struct PdfAddTextPreparedLine {
  text : String
  text_bytes : PdfBytes
  urls : Array[PdfAddTextUrl]
  expanded_lines : Array[String]
  expanded_line_bytes : Array[PdfBytes]
  widths : PdfAddTextLineWidths
  placement : PdfAddTextLinePlacement
} derive(Debug, Eq, ToJson)

///|
/// Page resources prepared for one cpdf add-text line.
pub(all) struct PdfAddTextResourceSetup {
  resources : PdfObject
  font_dictionary : PdfObject
  unique_fontname : PdfName
  unique_fontnames : Array[PdfName]
  extgstate_name : PdfName?
} derive(Debug, Eq, ToJson)

///|
/// Values used to build cpdf add-text replacement callbacks.
pub(all) struct PdfAddTextReplacementValues {
  page_number : Int
  end_page : Int
  filename : String
  page_label : String
  end_label : String
  bates : Int
  bates_pad : Int?
  bookmarks : Array[String]
} derive(Debug, Eq, ToJson)
