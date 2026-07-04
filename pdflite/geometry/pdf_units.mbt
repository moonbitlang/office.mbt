///|
/// Units accepted by page and geometry helpers.
///
/// PDF coordinates are ultimately expressed in points, but the public API keeps
/// common paper and layout units explicit at call sites.
pub(all) enum PdfUnit {
  PdfPoint
  Inch
  Centimetre
  Millimetre
} derive(Debug, Eq, ToJson)

///|
/// Converts a value from `unit` to PDF points.
pub fn unit_points(value : Double, unit : PdfUnit) -> Double {
  match unit {
    PdfPoint => value
    Inch => value * 72.0
    Centimetre => value * 28.3465
    Millimetre => value * 2.83465
  }
}

///|
/// Converts a value from `unit` to inches.
pub fn unit_inches(value : Double, unit : PdfUnit) -> Double {
  match unit {
    Inch => value
    PdfPoint => value / 72.0
    Centimetre => value / 2.54
    Millimetre => value / 25.4
  }
}

///|
/// Converts a value from `unit` to centimetres.
///
/// The `PdfPoint` path preserves CamlPDF's historical conversion constant for
/// compatibility with existing output.
pub fn unit_centimetres(value : Double, unit : PdfUnit) -> Double {
  match unit {
    Centimetre => value
    Inch => value * 2.54
    Millimetre => value / 10.0
    // Preserve CamlPDF's historical constant; it differs from points(Centimetre).
    PdfPoint => value / 28.3456
  }
}

///|
/// Converts a value from `unit` to millimetres.
pub fn unit_millimetres(value : Double, unit : PdfUnit) -> Double {
  unit_centimetres(value, unit) * 10.0
}
