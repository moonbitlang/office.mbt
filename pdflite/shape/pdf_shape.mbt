///|
/// Fill rule for a cpdf-style path.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfPathWindingRule {
  PdfPathEvenOdd
  PdfPathNonZero
}

///|
/// One straight or Bezier path segment.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfPathSegment {
  PdfPathStraight(Point2, Point2)
  PdfPathBezier(Point2, Point2, Point2, Point2)
}

///|
/// Whether a subpath is a hole in the containing path.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfPathHole {
  PdfPathHole
  PdfPathNotHole
}

///|
/// Whether a subpath is open or closed.
#derive(Debug, Eq, ToJson)
pub(all) enum PdfPathClosure {
  PdfPathClosed
  PdfPathOpen
}

///|
/// A cpdf-style subpath.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfPathSubpath {
  hole : PdfPathHole
  closure : PdfPathClosure
  segments : Array[PdfPathSegment]
}

///|
/// A cpdf-style path.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfPath {
  winding_rule : PdfPathWindingRule
  subpaths : Array[PdfPathSubpath]
}

///|
/// A cpdfcontent drawn path, pairing path geometry with paint flags.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfDrawnPath {
  stroked : Bool
  filled : Bool
  path : PdfPath
}
