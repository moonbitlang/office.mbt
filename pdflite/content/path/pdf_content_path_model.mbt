///|
/// Partial path under construction while interpreting path-building content
/// operators.
pub(all) enum PdfContentPartialPath {
  PdfContentNoPartialPath
  PdfContentPartialPath(PdfContentPartialPathState)
} derive(Debug, Eq, ToJson)

///|
/// Mutable data for an open PDF path subpath.
pub(all) struct PdfContentPartialPathState {
  start_point : Point2
  current_point : Point2
  segments : Array[PdfPathSegment]
  subpaths : Array[PdfPathSubpath]
} derive(Debug, Eq, ToJson)

///|
/// Result of applying a path-painting operator to the current partial path.
pub(all) struct PdfContentPathOpResult {
  partial_path : PdfContentPartialPath
  drawn_path : PdfDrawnPath?
} derive(Debug, Eq, ToJson)

///|
/// Result of applying a clipping-path operator to the current partial path.
pub(all) struct PdfContentClippingOpResult {
  partial_path : PdfContentPartialPath
  clipping_path : Array[PdfPath]
} derive(Debug, Eq, ToJson)

///|
/// Return an empty partial path state.
pub fn pdf_content_no_partial_path() -> PdfContentPartialPath {
  PdfContentNoPartialPath
}
