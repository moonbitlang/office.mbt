///|
/// Element stream consumed by the cpdftype layout pipeline.
///
/// `PdfTypeText` stores raw one-byte PDF charcodes, matching the OCaml
/// `char list` representation rather than Unicode text.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfTypeElement {
  PdfTypeText(@core.PdfBytes)
  PdfTypeHGlue(Double)
  PdfTypeVGlue(Double)
  PdfTypeNewLine
  PdfTypeNewPage
  PdfTypeFont(String, PdfFont, Double)
  PdfTypeBeginDest(@destination.PdfDestination, String?)
  PdfTypeEndDest
  PdfTypeBeginDocument
  PdfTypeTag(String, Int32)
  PdfTypeEndTag
}

///|
/// Pages and per-page structure tags produced by the cpdftype typesetter.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfTypeTypesetResult {
  pages : Array[@page.PdfPage]
  tags : Array[Array[(String, Int32)]]
}

///|
priv struct PdfTypeTypesetState {
  mut xpos : Double
  mut ypos : Double
  mut width_table : Array[Double]
  mut font : PdfFont?
  mut font_id : String?
  mut font_size : Double
  mut dest : (@destination.PdfDestination, String?)?
  mut mcid : Int32
  mut ops : Array[@content.PdfContentOp]
  fonts : Array[(String, Int32)]
  mut page_font_numbers : Array[Int32]
  mut page_annotations : Array[@syntax.PdfObject]
  mut dest_rectangles : Array[(Double, Double, Double, Double)]
  pages : Array[@page.PdfPage]
  mut tags : Array[(String, Int32)]
  tags_out : Array[Array[(String, Int32)]]
}
