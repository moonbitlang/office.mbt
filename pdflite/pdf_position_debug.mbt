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
pub fn pdf_string_of_position(position : @geometry.PdfPosition) -> String {
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
