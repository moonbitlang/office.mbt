///|
/// Boolean polygon operation used by cpdf's GPC-backed clipping helpers.
pub(all) enum PdfClipOperation {
  PdfClipDifference
  PdfClipIntersection
  PdfClipExclusiveOr
  PdfClipUnion
} derive(Debug, Eq, ToJson)

///|
/// A vertex in a cpdf/GPC polygon contour.
pub(all) struct PdfClipVertex {
  x : Double
  y : Double
} derive(Debug, Eq, ToJson)

///|
/// One contour in a cpdf/GPC polygon.
///
/// `hole=true` matches cpdf's `1` hole flag. `hole=false` matches cpdf's `0`
/// exterior-contour flag.
pub(all) struct PdfClipContour {
  hole : Bool
  vertices : Array[PdfClipVertex]
} derive(Debug, Eq, ToJson)

///|
/// A cpdf/GPC polygon represented as an ordered list of contours.
pub(all) struct PdfClipPolygon {
  contours : Array[PdfClipContour]
} derive(Debug, Eq, ToJson)

///|
/// Build a cpdf/GPC polygon vertex.
pub fn pdf_clip_vertex(x : Double, y : Double) -> PdfClipVertex {
  { x, y }
}

///|
/// Build a cpdf/GPC polygon contour, copying the input vertex view.
pub fn pdf_clip_contour(
  hole : Bool,
  vertices : ArrayView[PdfClipVertex],
) -> PdfClipContour {
  { hole, vertices: vertices.to_owned() }
}

///|
/// Build a cpdf/GPC polygon, copying the input contours and their vertices.
pub fn pdf_clip_polygon(contours : ArrayView[PdfClipContour]) -> PdfClipPolygon {
  let copied : Array[PdfClipContour] = []
  for contour in contours {
    copied.push(pdf_clip_contour(contour.hole, contour.vertices))
  }
  { contours: copied }
}

///|
/// Return the cpdf null GPC polygon.
pub fn pdf_clip_null_polygon() -> PdfClipPolygon {
  { contours: [] }
}

///|
/// Number of contours in this polygon.
pub fn PdfClipPolygon::num_contours(self : PdfClipPolygon) -> Int {
  self.contours.length()
}

///|
/// Number of vertices in this contour.
pub fn PdfClipContour::num_vertices(self : PdfClipContour) -> Int {
  self.vertices.length()
}

///|
/// Return cpdf's integer hole flag for this contour.
pub fn PdfClipContour::hole_flag(self : PdfClipContour) -> Int {
  if self.hole {
    1
  } else {
    0
  }
}

///|
/// Return the integer operation code used by cpdf's GPC binding.
pub fn PdfClipOperation::gpc_code(self : PdfClipOperation) -> Int {
  match self {
    PdfClipDifference => 0
    PdfClipIntersection => 1
    PdfClipExclusiveOr => 2
    PdfClipUnion => 3
  }
}

///|
/// Build the cpdf/GPC rectangle polygon for `[xmin, xmax] x [ymin, ymax]`.
pub fn pdf_clip_polygon_of_box(
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
) -> PdfClipPolygon {
  pdf_clip_polygon([
    pdf_clip_contour(false, [
      pdf_clip_vertex(xmin, ymin),
      pdf_clip_vertex(xmax, ymin),
      pdf_clip_vertex(xmax, ymax),
      pdf_clip_vertex(xmin, ymax),
    ]),
  ])
}

///|
/// Build a cpdf/GPC polygon from parallel hole flags and vertex arrays.
///
/// Raises `PdfError::BadNumberArgument` when the inputs have different lengths.
pub fn pdf_clip_make_polygon(
  holes : ArrayView[Bool],
  vertex_arrays : ArrayView[Array[PdfClipVertex]],
) -> PdfClipPolygon raise PdfError {
  if holes.length() != vertex_arrays.length() {
    raise BadNumberArgument("pdf_clip_make_polygon: unequal length inputs")
  }
  let contours : Array[PdfClipContour] = []
  for index in 0..<holes.length() {
    contours.push(pdf_clip_contour(holes[index], vertex_arrays[index]))
  }
  pdf_clip_polygon(contours)
}
