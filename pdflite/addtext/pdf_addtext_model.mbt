///|
/// A URL span parsed from cpdf add-text `%URL[text|url]` markup.
///
/// `start` and `end` are byte offsets in the visible output line, matching
/// OCaml cpdf's `String.length` accounting.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfAddTextUrl {
  url : String
  start : Int32
  end : Int32
}

///|
/// One add-text line after stripping `%URL[text|url]` markup.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfAddTextUrlLine {
  text : String
  urls : Array[PdfAddTextUrl]
}

///|
/// Transformed geometry for one add-text URL annotation.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfAddTextUrlAnnotationGeometry {
  p0 : Point2
  p1 : Point2
  p2 : Point2
  p3 : Point2
  rectangle : PdfRectangle
}

///|
/// Resolved placement values for one cpdf add-text line.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfAddTextLinePlacement {
  origin : Point2
  base_rotation : Double
  text_rotation : Double
  rotation_offset : Point2
  horizontal_offset : Double
  vertical_offset : Double
  justification_offset : Double
}

///|
/// Width measurements for one cpdf add-text line and its expanded paragraph.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfAddTextLineWidths {
  text_width : Double
  widths : Array[Double]
  longest_width : Double
}

///|
/// One cpdf add-text line after replacement expansion, URL stripping, width
/// measurement, and placement resolution.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfAddTextPreparedLine {
  text : String
  text_bytes : PdfBytes
  urls : Array[PdfAddTextUrl]
  expanded_lines : Array[String]
  expanded_line_bytes : Array[PdfBytes]
  widths : PdfAddTextLineWidths
  placement : PdfAddTextLinePlacement
}

///|
/// Page resources prepared for one cpdf add-text line.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfAddTextResourceSetup {
  resources : PdfObject
  font_dictionary : PdfObject
  unique_fontname : PdfName
  unique_fontnames : Array[PdfName]
  extgstate_name : PdfName?
}

///|
/// Values used to build cpdf add-text replacement callbacks.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfAddTextReplacementValues {
  page_number : Int32
  end_page : Int32
  filename : String
  page_label : String
  end_label : String
  bates : Int32
  bates_pad : Int32?
  bookmarks : Array[String]
}
