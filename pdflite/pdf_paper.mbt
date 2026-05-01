///|
pub(all) struct PaperSize {
  unit : PdfUnit
  width : Double
  height : Double
} derive(Debug, Eq, ToJson)

///|
pub fn paper_size_make(
  unit : PdfUnit,
  width : Double,
  height : Double,
) -> PaperSize {
  { unit, width, height }
}

///|
pub fn PaperSize::unit(self : PaperSize) -> PdfUnit {
  self.unit
}

///|
pub fn PaperSize::width(self : PaperSize) -> Double {
  self.width
}

///|
pub fn PaperSize::height(self : PaperSize) -> Double {
  self.height
}

///|
pub fn PaperSize::landscape(self : PaperSize) -> PaperSize {
  { unit: self.unit, width: self.height, height: self.width }
}

///|
pub let paper_a0 : PaperSize = paper_size_make(Millimetre, 841.0, 1189.0)

///|
pub let paper_a1 : PaperSize = paper_size_make(Millimetre, 594.0, 841.0)

///|
pub let paper_a2 : PaperSize = paper_size_make(Millimetre, 420.0, 594.0)

///|
pub let paper_a3 : PaperSize = paper_size_make(Millimetre, 297.0, 420.0)

///|
pub let paper_a4 : PaperSize = paper_size_make(Millimetre, 210.0, 297.0)

///|
pub let paper_a5 : PaperSize = paper_size_make(Millimetre, 148.0, 210.0)

///|
pub let paper_a6 : PaperSize = paper_size_make(Millimetre, 105.0, 148.0)

///|
pub let paper_a7 : PaperSize = paper_size_make(Millimetre, 74.0, 105.0)

///|
pub let paper_a8 : PaperSize = paper_size_make(Millimetre, 52.0, 74.0)

///|
pub let paper_a9 : PaperSize = paper_size_make(Millimetre, 37.0, 52.0)

///|
pub let paper_a10 : PaperSize = paper_size_make(Millimetre, 26.0, 37.0)

///|
pub let paper_usletter : PaperSize = paper_size_make(Inch, 8.5, 11.0)

///|
pub let paper_uslegal : PaperSize = paper_size_make(Inch, 8.5, 14.0)
