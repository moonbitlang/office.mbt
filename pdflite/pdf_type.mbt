///|
/// Element stream consumed by the cpdftype layout pipeline.
///
/// `PdfTypeText` stores raw one-byte PDF charcodes, matching the OCaml
/// `char list` representation rather than Unicode text.
pub(all) enum PdfTypeElement {
  PdfTypeText(PdfBytes)
  PdfTypeHGlue(Double)
  PdfTypeVGlue(Double)
  PdfTypeNewLine
  PdfTypeNewPage
  PdfTypeFont(String, PdfFont, Double)
  PdfTypeBeginDest(PdfDestination, String?)
  PdfTypeEndDest
  PdfTypeBeginDocument
  PdfTypeTag(String, Int)
  PdfTypeEndTag
} derive(Debug, Eq, ToJson)

///|
/// Pages and per-page structure tags produced by the cpdftype typesetter.
pub(all) struct PdfTypeTypesetResult {
  pages : Array[PdfPage]
  tags : Array[Array[(String, Int)]]
} derive(Debug, Eq, ToJson)

///|
priv struct PdfTypeTypesetState {
  mut xpos : Double
  mut ypos : Double
  mut width_table : Array[Double]
  mut font : PdfFont?
  mut font_id : String?
  mut font_size : Double
  mut dest : (PdfDestination, String?)?
  mut mcid : Int
  mut ops : Array[PdfContentOp]
  fonts : Array[(String, Int)]
  mut page_font_numbers : Array[Int]
  mut page_annotations : Array[PdfObject]
  mut dest_rectangles : Array[(Double, Double, Double, Double)]
  pages : Array[PdfPage]
  mut tags : Array[(String, Int)]
  tags_out : Array[Array[(String, Int)]]
}
