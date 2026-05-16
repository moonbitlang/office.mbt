///|
/// Position keywords used by cpdf-style text and layout operations.
pub(all) enum PdfPosition {
  PdfPositionPosCentre(Double, Double)
  PdfPositionPosLeft(Double, Double)
  PdfPositionPosRight(Double, Double)
  PdfPositionTop(Double)
  PdfPositionTopLeft(Double, Double)
  PdfPositionTopRight(Double, Double)
  PdfPositionLeft(Double)
  PdfPositionBottomLeft(Double, Double)
  PdfPositionBottom(Double)
  PdfPositionBottomRight(Double, Double)
  PdfPositionRight(Double)
  PdfPositionDiagonal
  PdfPositionReverseDiagonal
  PdfPositionCentre
} derive(Debug, Eq, ToJson)

///|
/// Absolute placement calculated from a position keyword and page bounds.
pub(all) struct PdfCalculatedPosition {
  x : Double
  y : Double
  rotation : Double
} derive(Debug, Eq, ToJson)

///|
fn pdf_position_fixed_six_fraction(value : Int) -> String {
  let mut output = ""
  let mut divisor = 100000
  while divisor > 0 {
    output = output + (value / divisor % 10).to_string()
    divisor /= 10
  }
  output
}

///|
fn pdf_position_fixed_six(value : Double) -> String {
  let sign = if value < 0.0 { "-" } else { "" }
  let magnitude = if value < 0.0 { -value } else { value }
  let scaled = (magnitude * 1000000.0).round().to_int()
  sign +
  (scaled / 1000000).to_string() +
  "." +
  pdf_position_fixed_six_fraction(scaled % 1000000)
}

///|
fn pdf_position_debug_two(
  name : String,
  first : Double,
  second : Double,
) -> String {
  name +
  " " +
  pdf_position_fixed_six(first) +
  " " +
  pdf_position_fixed_six(second)
}

///|
fn pdf_position_debug_one(name : String, value : Double) -> String {
  name + " " + pdf_position_fixed_six(value)
}

///|
/// Return the cpdf debug spelling for a position keyword.
pub fn pdf_string_of_position(position : PdfPosition) -> String {
  match position {
    PdfPositionPosCentre(x, y) => pdf_position_debug_two("PosCentre", x, y)
    PdfPositionPosLeft(x, y) => pdf_position_debug_two("PosLeft", x, y)
    PdfPositionPosRight(x, y) => pdf_position_debug_two("PosRight", x, y)
    PdfPositionTop(distance) => pdf_position_debug_one("Top", distance)
    PdfPositionTopLeft(x, y) => pdf_position_debug_two("TopLeft", x, y)
    PdfPositionTopRight(x, y) => pdf_position_debug_two("TopRight", x, y)
    PdfPositionLeft(distance) => pdf_position_debug_one("Left", distance)
    PdfPositionBottomLeft(x, y) => pdf_position_debug_two("BottomLeft", x, y)
    PdfPositionBottom(distance) => pdf_position_debug_one("Bottom", distance)
    PdfPositionBottomRight(x, y) => pdf_position_debug_two("BottomRight", x, y)
    PdfPositionRight(distance) => pdf_position_debug_one("Right", distance)
    PdfPositionDiagonal => "Diagonal"
    PdfPositionReverseDiagonal => "Reverse Diagonal"
    PdfPositionCentre => "Centre"
  }
}

///|
fn pdf_position_distance(ignore_distance : Bool, distance : Double) -> Double {
  if ignore_distance {
    0.0
  } else {
    distance
  }
}

///|
fn pdf_position_calculated(
  x : Double,
  y : Double,
  rotation : Double,
) -> PdfCalculatedPosition {
  { x, y, rotation }
}

///|
fn pdf_position_diagonal(
  bounds : PdfRectangle,
  text_width : Double,
) -> PdfCalculatedPosition {
  let angle = @math.atan(
    (bounds.max_y - bounds.min_y) / (bounds.max_x - bounds.min_x),
  )
  let center_x = (bounds.max_x + bounds.min_x) / 2.0
  let center_y = (bounds.max_y + bounds.min_y) / 2.0
  let half_width = text_width / 2.0
  let dx = half_width * @math.cos(angle)
  let dy = half_width * @math.sin(angle)
  pdf_position_calculated(center_x - dx, center_y - dy, angle)
}

///|
fn pdf_position_reverse_diagonal(
  bounds : PdfRectangle,
  text_width : Double,
) -> PdfCalculatedPosition {
  let angle = @math.atan(
    (bounds.max_y - bounds.min_y) / (bounds.max_x - bounds.min_x),
  )
  let center_x = (bounds.max_x + bounds.min_x) / 2.0
  let center_y = (bounds.max_y + bounds.min_y) / 2.0
  let half_width = text_width / 2.0
  let dx = half_width * @math.cos(angle)
  let dy = half_width * @math.sin(angle)
  pdf_position_calculated(
    center_x - dx,
    bounds.max_y + bounds.min_y - (center_y - dy),
    angle - (2.0 * @math.PI - (@math.PI - 2.0 * angle) * 2.0 / 2.0) + @math.PI,
  )
}

///|
/// Calculate the absolute placement for text of `text_width` in `bounds`.
///
/// When `ignore_distance` is true, edge-distance values in the position are
/// treated as zero, matching cpdf's `calculate_position` behavior.
pub fn pdf_calculate_position(
  ignore_distance : Bool,
  text_width : Double,
  bounds : PdfRectangle,
  position : PdfPosition,
) -> PdfCalculatedPosition {
  let rotation = 0.0
  match position {
    PdfPositionCentre =>
      pdf_position_calculated(
        (bounds.min_x + bounds.max_x) / 2.0 - text_width / 2.0,
        (bounds.min_y + bounds.max_y) / 2.0,
        rotation,
      )
    PdfPositionDiagonal => pdf_position_diagonal(bounds, text_width)
    PdfPositionReverseDiagonal =>
      pdf_position_reverse_diagonal(bounds, text_width)
    PdfPositionPosLeft(x, y) =>
      pdf_position_calculated(bounds.min_x + x, bounds.min_y + y, rotation)
    PdfPositionPosCentre(x, y) =>
      pdf_position_calculated(
        bounds.min_x + x - text_width / 2.0,
        bounds.min_y + y,
        rotation,
      )
    PdfPositionPosRight(x, y) =>
      pdf_position_calculated(
        bounds.min_x + x - text_width,
        bounds.min_y + y,
        rotation,
      )
    PdfPositionTop(distance) => {
      let d = pdf_position_distance(ignore_distance, distance)
      pdf_position_calculated(
        (bounds.min_x + bounds.max_x) / 2.0 - text_width / 2.0,
        bounds.max_y - d,
        rotation,
      )
    }
    PdfPositionTopLeft(x, y) => {
      let x = pdf_position_distance(ignore_distance, x)
      let y = pdf_position_distance(ignore_distance, y)
      pdf_position_calculated(bounds.min_x + x, bounds.max_y - y, rotation)
    }
    PdfPositionTopRight(x, y) => {
      let x = pdf_position_distance(ignore_distance, x)
      let y = pdf_position_distance(ignore_distance, y)
      pdf_position_calculated(
        bounds.max_x - x - text_width,
        bounds.max_y - y,
        rotation,
      )
    }
    PdfPositionLeft(distance) => {
      let d = pdf_position_distance(ignore_distance, distance)
      pdf_position_calculated(
        bounds.min_x + d,
        (bounds.max_y + bounds.min_y) / 2.0,
        rotation,
      )
    }
    PdfPositionBottomLeft(x, y) => {
      let x = pdf_position_distance(ignore_distance, x)
      let y = pdf_position_distance(ignore_distance, y)
      pdf_position_calculated(bounds.min_x + x, bounds.min_y + y, rotation)
    }
    PdfPositionBottom(distance) => {
      let d = pdf_position_distance(ignore_distance, distance)
      pdf_position_calculated(
        (bounds.min_x + bounds.max_x) / 2.0 - text_width / 2.0,
        bounds.min_y + d,
        rotation,
      )
    }
    PdfPositionBottomRight(x, y) => {
      let x = pdf_position_distance(ignore_distance, x)
      let y = pdf_position_distance(ignore_distance, y)
      pdf_position_calculated(
        bounds.max_x - x - text_width,
        bounds.min_y + y,
        rotation,
      )
    }
    PdfPositionRight(distance) => {
      let d = pdf_position_distance(ignore_distance, distance)
      pdf_position_calculated(
        bounds.max_x - d - text_width,
        (bounds.max_y + bounds.min_y) / 2.0,
        rotation,
      )
    }
  }
}
