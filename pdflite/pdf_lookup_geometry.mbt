///|
fn double_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn double_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// The object is resolved first. PDF real numbers are returned directly and PDF
/// integers are widened to `Double`; any other object raises `@core.PdfError::NumberExpected`.
pub fn PdfDocument::get_number(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Double raise @core.PdfError {
  match self.direct(object) {
    PdfReal(value) => value
    PdfInteger(value) => value.to_double()
    _ => raise NumberExpected
  }
}

///|
/// Parse and normalize a PDF rectangle array.
///
/// The input must resolve to an array of four numeric objects. Coordinates are
/// normalized so the result always has lower bounds in `min_x`/`min_y` and
/// upper bounds in `max_x`/`max_y`. Non-array inputs raise `@core.PdfError::RectangleExpected`;
/// malformed numeric entries raise `@core.PdfError::BadRectangle`.
pub fn PdfDocument::parse_rectangle(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> @geometry.PdfRectangle raise @core.PdfError {
  match self.direct(object) {
    PdfArray(values) if values.length() == 4 => {
      let x0 = try? self.get_number(values[0])
      let y0 = try? self.get_number(values[1])
      let x1 = try? self.get_number(values[2])
      let y1 = try? self.get_number(values[3])
      match (x0, y0, x1, y1) {
        (Ok(x0), Ok(y0), Ok(x1), Ok(y1)) =>
          {
            min_x: double_min(x0, x1),
            min_y: double_min(y0, y1),
            max_x: double_max(x0, x1),
            max_y: double_max(y0, y1),
          }
        _ => raise BadRectangle
      }
    }
    _ => raise RectangleExpected
  }
}

///|
/// Transform a rectangle and return the bounding PDF rectangle array.
///
/// All four corners are transformed with `matrix`, then the axis-aligned bounds
/// of those transformed points are written as `[minX minY maxX maxY]`.
pub fn PdfDocument::transform_rect(
  self : PdfDocument,
  matrix : @geometry.TransformMatrix,
  object : @syntax.PdfObject,
) -> @syntax.PdfObject raise @core.PdfError {
  let rectangle = self.parse_rectangle(object)
  let p0 = matrix.apply(@geometry.point2(rectangle.min_x, rectangle.min_y))
  let p1 = matrix.apply(@geometry.point2(rectangle.max_x, rectangle.max_y))
  let p2 = matrix.apply(@geometry.point2(rectangle.min_x, rectangle.max_y))
  let p3 = matrix.apply(@geometry.point2(rectangle.max_x, rectangle.min_y))
  PdfArray([
    PdfReal(double_min(double_min(p0.x, p1.x), double_min(p2.x, p3.x))),
    PdfReal(double_min(double_min(p0.y, p1.y), double_min(p2.y, p3.y))),
    PdfReal(double_max(double_max(p0.x, p1.x), double_max(p2.x, p3.x))),
    PdfReal(double_max(double_max(p0.y, p1.y), double_max(p2.y, p3.y))),
  ])
}

///|
fn PdfDocument::pdf_transform_number_or_none(
  self : PdfDocument,
  object : @syntax.PdfObject,
) -> Double? {
  try self.get_number(object) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn PdfDocument::pdf_transform_quadpoint_chunk(
  self : PdfDocument,
  matrix : @geometry.TransformMatrix,
  values : ArrayView[@syntax.PdfObject],
  start : Int,
) -> Array[@syntax.PdfObject] {
  let numbers : Array[Double] = []
  let mut valid = true
  for index in start..<(start + 8) {
    match self.pdf_transform_number_or_none(values[index]) {
      Some(value) => numbers.push(value)
      None => valid = false
    }
  }
  if valid {
    let output : Array[@syntax.PdfObject] = []
    for index in 0..<4 {
      let point = matrix.apply(
        @geometry.point2(numbers[index * 2], numbers[index * 2 + 1]),
      )
      output.push(PdfReal(point.x))
      output.push(PdfReal(point.y))
    }
    output
  } else {
    [
      for index in start..<(start + 8) => values[index]
    ]
  }
}

///|
/// Transform PDF annotation quadpoints in groups of eight coordinates.
///
/// Each complete group is interpreted as four `(x, y)` pairs and transformed by
/// `matrix`. A complete group containing a non-numeric value is preserved
/// unchanged, as is any trailing partial group. Non-array inputs are returned
/// unchanged.
pub fn PdfDocument::transform_quadpoints(
  self : PdfDocument,
  matrix : @geometry.TransformMatrix,
  object : @syntax.PdfObject,
) -> @syntax.PdfObject {
  match self.direct(object) {
    PdfArray(values) => {
      let output : Array[@syntax.PdfObject] = []
      let mut start = 0
      while start < values.length() {
        if start + 8 <= values.length() {
          for value in self.pdf_transform_quadpoint_chunk(matrix, values, start) {
            output.push(value)
          }
        } else {
          for index in start..<values.length() {
            output.push(values[index])
          }
        }
        start += 8
      }
      PdfArray(output)
    }
    _ => object
  }
}

///|
/// Read a transformation matrix from a dictionary entry.
///
/// If `key` is absent, the identity matrix is returned. Present values must be
/// arrays of six numbers in PDF matrix order `[a b c d e f]`; malformed arrays
/// raise `@core.PdfError::MatrixMalformed`, and non-numeric entries raise `@core.PdfError::NumberExpected`.
pub fn PdfDocument::parse_matrix(
  self : PdfDocument,
  key : @core.PdfName,
  object : @syntax.PdfObject,
) -> @geometry.TransformMatrix raise @core.PdfError {
  match self.lookup_direct(key, object) {
    None => @geometry.transform_identity_matrix
    Some(PdfArray(values)) if values.length() == 6 =>
      {
        a: self.get_number(values[0]),
        b: self.get_number(values[1]),
        c: self.get_number(values[2]),
        d: self.get_number(values[3]),
        e: self.get_number(values[4]),
        f: self.get_number(values[5]),
      }
    _ => raise MatrixMalformed
  }
}

///|
/// Convert a transformation matrix into its six-number PDF array form.
pub fn pdf_object_of_matrix(
  matrix : @geometry.TransformMatrix,
) -> @syntax.PdfObject {
  PdfArray([
    PdfReal(matrix.a),
    PdfReal(matrix.b),
    PdfReal(matrix.c),
    PdfReal(matrix.d),
    PdfReal(matrix.e),
    PdfReal(matrix.f),
  ])
}
