///|
/// Chop selected pages into an `x` by `y` grid.
///
/// The page crop box is preferred when present. Chopped pages receive only a
/// new media box; inherited/crop/trim/bleed/art boxes and annotations are
/// removed from each generated piece, matching cpdf's chop behavior.
pub fn PdfDocument::chop(
  self : PdfDocument,
  x : Int,
  y : Int,
  columns : Bool,
  btt : Bool,
  rtl : Bool,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  pdf_chop_validate_grid(x, y)
  self.pdf_chop_inner(0.0, x, y, columns, btt, rtl, page_numbers, "chop")
}

///|
/// Chop selected pages horizontally or vertically at `line`.
pub fn PdfDocument::chop_hv(
  self : PdfDocument,
  is_h : Bool,
  line : Double,
  columns : Bool,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  self.pdf_chop_inner(
    line,
    if is_h {
      0
    } else {
      1
    },
    if is_h {
      1
    } else {
      0
    },
    columns,
    false,
    false,
    page_numbers,
    if is_h {
      "chop_h"
    } else {
      "chop_v"
    },
  )
}

///|
/// Compatibility wrapper for `PdfDocument::chop`.
pub fn pdf_chop(
  document : PdfDocument,
  x : Int,
  y : Int,
  columns : Bool,
  btt : Bool,
  rtl : Bool,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.chop(x, y, columns, btt, rtl, page_numbers)
}

///|
/// Compatibility wrapper matching cpdfchop's source argument order.
pub fn pdf_chop_cpdf_order(
  x : Int,
  y : Int,
  columns : Bool,
  btt : Bool,
  rtl : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.chop(x, y, columns, btt, rtl, page_numbers)
}

///|
/// Compatibility wrapper for `PdfDocument::chop_hv`.
pub fn pdf_chop_hv(
  document : PdfDocument,
  is_h : Bool,
  line : Double,
  columns : Bool,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.chop_hv(is_h, line, columns, page_numbers)
}

///|
/// Compatibility wrapper matching cpdfchop's source argument order.
pub fn pdf_chop_hv_cpdf_order(
  is_h : Bool,
  line : Double,
  columns : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.chop_hv(is_h, line, columns, page_numbers)
}
