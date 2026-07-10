// A pure, bounded A1-style range parser shared by the JSON read surface and
// the CLI (`style`, `get --json`, batch ops). Bounded so a pathological range
// like A1:XFD1048576 cannot exhaust memory when expanded.

///|
/// Maximum number of cells a parsed range may cover when expanded.
pub const MAX_RANGE_CELLS : Int64 = 100_000

///|
/// A normalized, inclusive rectangular cell range (1-based coordinates,
/// `lo <= hi` on both axes).
pub struct CellRange {
  col_lo : Int
  row_lo : Int
  col_hi : Int
  row_hi : Int
} derive(Eq, @debug.Debug)

///|
/// Raised when a syntactically valid range covers more than
/// `MAX_RANGE_CELLS` cells.
pub suberror RangeError {
  RangeTooLarge(range~ : String, count~ : Int64)
} derive(@debug.Debug)

///|
impl Show for RangeError with fn output(self, logger) {
  match self {
    RangeTooLarge(range~, count~) =>
      logger.write_string(
        "range \{range} covers \{count} cells; max is \{MAX_RANGE_CELLS}",
      )
  }
}

///|
/// Parses a single cell (`A1`) or an `A1:B2`-style range into a normalized
/// `CellRange`. Corner order is irrelevant (`B2:A1` equals `A1:B2`). Raises
/// `@xlsx.XlsxError` for malformed cell references and `RangeError` when the
/// range exceeds `MAX_RANGE_CELLS`.
pub fn parse_range(target : String) -> CellRange raise {
  match target.find(":") {
    None => {
      let (col, row) = @xlsx.cell_name_to_coordinates(target)
      { col_lo: col, row_lo: row, col_hi: col, row_hi: row }
    }
    Some(index) => {
      let (c1, r1) = @xlsx.cell_name_to_coordinates(target[:index])
      let (c2, r2) = @xlsx.cell_name_to_coordinates(target[index + 1:])
      let range : CellRange = {
        col_lo: if c1 < c2 {
          c1
        } else {
          c2
        },
        row_lo: if r1 < r2 {
          r1
        } else {
          r2
        },
        col_hi: if c1 > c2 {
          c1
        } else {
          c2
        },
        row_hi: if r1 > r2 {
          r1
        } else {
          r2
        },
      }
      if range.cell_count() > MAX_RANGE_CELLS {
        raise RangeTooLarge(range=target, count=range.cell_count())
      }
      range
    }
  }
}

///|
/// Number of cells the range covers. Computed in `Int64`: a full
/// A1:XFD1048576 range is ~1.7e10, which would overflow 32-bit `Int` and
/// wrap past the cap, defeating the guard.
pub fn CellRange::cell_count(self : CellRange) -> Int64 {
  (self.col_hi - self.col_lo + 1).to_int64() *
  (self.row_hi - self.row_lo + 1).to_int64()
}

///|
/// The individual cell references the range covers, in row-major order.
pub fn CellRange::cells(
  self : CellRange,
) -> Array[String] raise @xlsx.XlsxError {
  let cells = []
  for row in self.row_lo..<=self.row_hi {
    for col in self.col_lo..<=self.col_hi {
      cells.push(@xlsx.coordinates_to_cell_name(col, row))
    }
  }
  cells
}

///|
/// The normalized `A1`-style reference: a single cell name for a one-cell
/// range, otherwise `A1:B2` with the top-left corner first.
pub fn CellRange::range_ref(self : CellRange) -> String raise @xlsx.XlsxError {
  let start = @xlsx.coordinates_to_cell_name(self.col_lo, self.row_lo)
  if self.col_lo == self.col_hi && self.row_lo == self.row_hi {
    start
  } else {
    start + ":" + @xlsx.coordinates_to_cell_name(self.col_hi, self.row_hi)
  }
}
