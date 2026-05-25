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
/// Source-spelled compatibility wrapper for cpdfclip's null GPC polygon.
pub fn pdf_nullpoly() -> PdfClipPolygon {
  pdf_clip_null_polygon()
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
/// Source-spelled compatibility wrapper for cpdfclip's rectangle polygon.
pub fn pdf_gpc_polygon_of_box(
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
) -> PdfClipPolygon {
  pdf_clip_polygon_of_box(xmin, xmax, ymin, ymax)
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

///|
/// Source-spelled compatibility wrapper for cpdfclip's polygon builder.
pub fn pdf_make_gpcpolygon(
  holes : ArrayView[Bool],
  vertex_arrays : ArrayView[Array[PdfClipVertex]],
) -> PdfClipPolygon raise PdfError {
  pdf_clip_make_polygon(holes, vertex_arrays)
}

///|
fn pdf_clip_float_text(value : Double) -> String {
  let scaled = (value * 1000000.0).round().to_int()
  let negative = scaled < 0
  let magnitude = if negative { -scaled } else { scaled }
  let whole = magnitude / 1000000
  let fraction = magnitude % 1000000
  let mut fraction_text = fraction.to_string()
  while fraction_text.length() < 6 {
    fraction_text = "0" + fraction_text
  }
  (if negative { "-" } else { "" }) + whole.to_string() + "." + fraction_text
}

///|
fn pdf_gpcml_write_ascii(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  let mut current = position
  for byte in @ascii.encode(text) {
    output[current] = byte
    current += 1
  }
  current
}

///|
fn pdf_gpcml_write_vertex(
  output : Array[Byte],
  position : Int,
  vertex : PdfClipVertex,
) -> Int {
  let mut current = pdf_gpcml_write_ascii(output, position, "    {x = ")
  current = pdf_gpcml_write_ascii(
    output,
    current,
    pdf_clip_float_text(vertex.x),
  )
  current = pdf_gpcml_write_ascii(output, current, ", y = ")
  current = pdf_gpcml_write_ascii(
    output,
    current,
    pdf_clip_float_text(vertex.y),
  )
  pdf_gpcml_write_ascii(output, current, "}\n")
}

///|
fn pdf_gpcml_write_contour(
  output : Array[Byte],
  position : Int,
  contour : PdfClipContour,
) -> Int {
  let mut current = pdf_gpcml_write_ascii(output, position, "  Contour with ")
  current = pdf_gpcml_write_ascii(
    output,
    current,
    contour.vertices.length().to_string(),
  )
  current = pdf_gpcml_write_ascii(output, current, " vertices and hole ")
  current = pdf_gpcml_write_ascii(
    output,
    current,
    contour.hole_flag().to_string(),
  )
  output[current] = 10
  current += 1
  for vertex in contour.vertices {
    current = pdf_gpcml_write_vertex(output, current, vertex)
  }
  current
}

///|
fn pdf_gpcml_text_length(text : String) -> Int {
  @ascii.encode(text).length()
}

///|
fn pdf_gpcml_vertex_text_length(vertex : PdfClipVertex) -> Int {
  pdf_gpcml_text_length("    {x = ") +
  pdf_gpcml_text_length(pdf_clip_float_text(vertex.x)) +
  pdf_gpcml_text_length(", y = ") +
  pdf_gpcml_text_length(pdf_clip_float_text(vertex.y)) +
  pdf_gpcml_text_length("}\n")
}

///|
fn pdf_gpcml_contour_text_length(contour : PdfClipContour) -> Int {
  let mut length = pdf_gpcml_text_length("  Contour with ") +
    pdf_gpcml_text_length(contour.vertices.length().to_string()) +
    pdf_gpcml_text_length(" vertices and hole ") +
    pdf_gpcml_text_length(contour.hole_flag().to_string()) +
    1
  for vertex in contour.vertices {
    length += pdf_gpcml_vertex_text_length(vertex)
  }
  length
}

///|
fn pdf_gpcml_polygon_text_length(polygon : PdfClipPolygon) -> Int {
  let mut length = pdf_gpcml_text_length("Contours: ") +
    pdf_gpcml_text_length(polygon.contours.length().to_string()) +
    1
  for contour in polygon.contours {
    length += pdf_gpcml_contour_text_length(contour)
  }
  length
}

///|
/// Return the text cpdfclip's debug polygon printer writes to stdout.
pub fn pdf_gpcml_printpolygon(polygon : PdfClipPolygon) -> PdfBytes {
  let output = Array::make(pdf_gpcml_polygon_text_length(polygon), b'\x00')
  let mut position = pdf_gpcml_write_ascii(output, 0, "Contours: ")
  position = pdf_gpcml_write_ascii(
    output,
    position,
    polygon.contours.length().to_string(),
  )
  output[position] = 10
  position += 1
  for contour in polygon.contours {
    position = pdf_gpcml_write_contour(output, position, contour)
  }
  Bytes::from_array(output)
}
