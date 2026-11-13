///|
/// Partial path under construction while interpreting path-building content
/// operators.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfContentPartialPath {
  PdfContentNoPartialPath
  PdfContentPartialPath(PdfContentPartialPathState)
}

///|
/// Mutable data for an open PDF path subpath.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentPartialPathState {
  start_point : Point2
  current_point : Point2
  segments : Array[PdfPathSegment]
  subpaths : Array[PdfPathSubpath]
}

///|
/// Result of applying a path-painting operator to the current partial path.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentPathOpResult {
  partial_path : PdfContentPartialPath
  drawn_path : PdfDrawnPath?
}

///|
/// Result of applying a clipping-path operator to the current partial path.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfContentClippingOpResult {
  partial_path : PdfContentPartialPath
  clipping_path : Array[PdfPath]
}

///|
/// Return an empty partial path state.
pub fn pdf_content_no_partial_path() -> PdfContentPartialPath {
  PdfContentNoPartialPath
}
