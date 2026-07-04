///|
/// A paper size expressed in a declared unit.
///
/// Width and height are stored as given; conversion to PDF points happens at
/// page-construction boundaries.
pub(all) struct PaperSize {
  unit : PdfUnit
  width : Double
  height : Double
} derive(Debug, Eq, ToJson)

///|
/// Creates a paper size from a unit, width, and height.
pub fn paper_size_make(
  unit : PdfUnit,
  width : Double,
  height : Double,
) -> PaperSize {
  { unit, width, height }
}

///|
/// Returns the unit used by this paper size.
pub fn PaperSize::unit(self : PaperSize) -> PdfUnit {
  self.unit
}

///|
/// Returns the paper width in this size's unit.
pub fn PaperSize::width(self : PaperSize) -> Double {
  self.width
}

///|
/// Returns the paper height in this size's unit.
pub fn PaperSize::height(self : PaperSize) -> Double {
  self.height
}

///|
/// Returns the same paper dimensions with width and height swapped.
pub fn PaperSize::landscape(self : PaperSize) -> PaperSize {
  { unit: self.unit, width: self.height, height: self.width }
}

///|
/// ISO A0 paper, 841 mm by 1189 mm.
pub let paper_a0 : PaperSize = paper_size_make(Millimetre, 841.0, 1189.0)

///|
/// ISO A1 paper, 594 mm by 841 mm.
pub let paper_a1 : PaperSize = paper_size_make(Millimetre, 594.0, 841.0)

///|
/// ISO A2 paper, 420 mm by 594 mm.
pub let paper_a2 : PaperSize = paper_size_make(Millimetre, 420.0, 594.0)

///|
/// ISO A3 paper, 297 mm by 420 mm.
pub let paper_a3 : PaperSize = paper_size_make(Millimetre, 297.0, 420.0)

///|
/// ISO A4 paper, 210 mm by 297 mm.
pub let paper_a4 : PaperSize = paper_size_make(Millimetre, 210.0, 297.0)

///|
/// ISO A5 paper, 148 mm by 210 mm.
pub let paper_a5 : PaperSize = paper_size_make(Millimetre, 148.0, 210.0)

///|
/// ISO A6 paper, 105 mm by 148 mm.
pub let paper_a6 : PaperSize = paper_size_make(Millimetre, 105.0, 148.0)

///|
/// ISO A7 paper, 74 mm by 105 mm.
pub let paper_a7 : PaperSize = paper_size_make(Millimetre, 74.0, 105.0)

///|
/// ISO A8 paper, 52 mm by 74 mm.
pub let paper_a8 : PaperSize = paper_size_make(Millimetre, 52.0, 74.0)

///|
/// ISO A9 paper, 37 mm by 52 mm.
pub let paper_a9 : PaperSize = paper_size_make(Millimetre, 37.0, 52.0)

///|
/// ISO A10 paper, 26 mm by 37 mm.
pub let paper_a10 : PaperSize = paper_size_make(Millimetre, 26.0, 37.0)

///|
/// US Letter paper, 8.5 inches by 11 inches.
pub let paper_usletter : PaperSize = paper_size_make(Inch, 8.5, 11.0)

///|
/// US Legal paper, 8.5 inches by 14 inches.
pub let paper_uslegal : PaperSize = paper_size_make(Inch, 8.5, 14.0)
