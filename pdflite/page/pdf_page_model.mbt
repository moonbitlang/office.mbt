///|
/// Page rotation normalized to the four rotations allowed by PDF page dictionaries.
pub(all) enum PdfPageRotation {
  Rotate0
  Rotate90
  Rotate180
  Rotate270
} derive(Debug, Eq, ToJson)

///|
/// In-memory page description used by page-tree read and write helpers.
///
/// `content` stores stream objects or indirect stream references. `mediabox`,
/// `resources`, and `rest` preserve PDF objects so byte-oriented dictionary
/// data is not forced through MoonBit strings.
pub(all) struct PdfPage {
  content : Array[PdfObject]
  mediabox : PdfObject
  resources : PdfObject
  rotate : PdfPageRotation
  rest : PdfObject
} derive(Debug, Eq, ToJson)

///|
/// Convert a normalized page rotation to the integer stored in `/Rotate`.
pub fn pdf_page_int_of_rotation(rotation : PdfPageRotation) -> Int {
  match rotation {
    Rotate0 => 0
    Rotate90 => 90
    Rotate180 => 180
    Rotate270 => 270
  }
}

///|
/// Convert a PDF `/Rotate` integer to a normalized rotation.
///
/// Multiples equivalent to 0, 90, 180, and 270 degrees are accepted. Other
/// values raise `PdfError::PageRotationExpected`.
pub fn pdf_page_rotation_of_int(value : Int) -> PdfPageRotation raise PdfError {
  match value % 360 {
    0 => Rotate0
    90 | -270 => Rotate90
    180 | -180 => Rotate180
    270 | -90 => Rotate270
    _ => raise PageRotationExpected(value)
  }
}

///|
/// Build a PDF rectangle object for a named paper size.
///
/// The rectangle is `[0 0 width height]` in points.
pub fn pdf_page_rectangle_of_paper(paper : PaperSize) -> PdfObject {
  PdfArray([
    PdfReal(0.0),
    PdfReal(0.0),
    PdfReal(@geometry.unit_points(paper.width(), paper.unit())),
    PdfReal(@geometry.unit_points(paper.height(), paper.unit())),
  ])
}

///|
/// Build a blank page using an explicit PDF rectangle object as `/MediaBox`.
pub fn pdf_page_custom(rectangle : PdfObject) -> PdfPage {
  {
    content: [],
    mediabox: rectangle,
    resources: PdfDictionary([]),
    rotate: Rotate0,
    rest: PdfDictionary([]),
  }
}

///|
/// Build a blank page for a named paper size.
pub fn pdf_page_blank(paper : PaperSize) -> PdfPage {
  pdf_page_custom(pdf_page_rectangle_of_paper(paper))
}
