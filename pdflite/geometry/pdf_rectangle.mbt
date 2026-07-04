///|
/// A normalized rectangle in PDF user-space coordinates.
///
/// `min_x` and `min_y` are always the lower bounds, and `max_x` and
/// `max_y` are always the upper bounds. Parsers normalize PDF rectangle arrays
/// whose coordinates are written in the opposite order.
pub(all) struct PdfRectangle {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
} derive(Debug, Eq, ToJson)
