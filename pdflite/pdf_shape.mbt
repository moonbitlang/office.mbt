///|
/// Fill rule for a cpdf-style path.
pub(all) enum PdfPathWindingRule {
  PdfPathEvenOdd
  PdfPathNonZero
} derive(Debug, Eq, ToJson)

///|
/// One straight or Bezier path segment.
pub(all) enum PdfPathSegment {
  PdfPathStraight(Point2, Point2)
  PdfPathBezier(Point2, Point2, Point2, Point2)
} derive(Debug, Eq, ToJson)

///|
/// Whether a subpath is a hole in the containing path.
pub(all) enum PdfPathHole {
  PdfPathHole
  PdfPathNotHole
} derive(Debug, Eq, ToJson)

///|
/// Whether a subpath is open or closed.
pub(all) enum PdfPathClosure {
  PdfPathClosed
  PdfPathOpen
} derive(Debug, Eq, ToJson)

///|
/// A cpdf-style subpath.
pub(all) struct PdfPathSubpath {
  hole : PdfPathHole
  closure : PdfPathClosure
  segments : Array[PdfPathSegment]
} derive(Debug, Eq, ToJson)

///|
/// A cpdf-style path.
pub(all) struct PdfPath {
  winding_rule : PdfPathWindingRule
  subpaths : Array[PdfPathSubpath]
} derive(Debug, Eq, ToJson)

///|
/// A cpdfcontent drawn path, pairing path geometry with paint flags.
pub(all) struct PdfDrawnPath {
  stroked : Bool
  filled : Bool
  path : PdfPath
} derive(Debug, Eq, ToJson)
