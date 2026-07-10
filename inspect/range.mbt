// A pure, bounded A1-style range parser shared by the JSON read surface and
// the CLI (`style`, `get --json`, batch ops). Bounded so a pathological range
// like A1:XFD1048576 cannot exhaust memory when expanded, and strict so a
// malformed reference is rejected instead of silently aliasing to a valid
// cell (the tolerant workbook parser skips `$` anywhere and lets long column
// names wrap its accumulator).

///|
/// Maximum number of cells a parsed range may cover when expanded.
pub const MAX_RANGE_CELLS : Int64 = 100_000

///|
/// Largest column (XFD) and row of the xlsx grid.
const MAX_COL : Int = 16_384

///|
const MAX_ROW : Int = 1_048_576

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
/// Raised for a range that exceeds `MAX_RANGE_CELLS` or a reference that is
/// not a well-formed in-grid A1-style cell name.
pub suberror RangeError {
  RangeTooLarge(range~ : String, count~ : Int64)
  MalformedRef(ref_~ : String)
} derive(@debug.Debug)

///|
pub impl Show for RangeError with fn output(self, logger) {
  match self {
    RangeTooLarge(range~, count~) =>
      logger.write_string(
        "range \{range} covers \{count} cells; max is \{MAX_RANGE_CELLS}",
      )
    MalformedRef(ref_~) =>
      logger.write_string("invalid cell reference '\{ref_}'")
  }
}

///|
/// Parses a single cell (`A1`) or an `A1:B2`-style range into a normalized
/// `CellRange`. Corner order is irrelevant (`B2:A1` equals `A1:B2`); `$`
/// anchors (`$A$1`) are accepted. Raises `RangeError` for a malformed or
/// out-of-grid reference and for a range exceeding `MAX_RANGE_CELLS`.
pub fn parse_range(target : String) -> CellRange raise RangeError {
  match target.find(":") {
    None => {
      let (col, row) = parse_cell_ref(target[:], full=target)
      { col_lo: col, row_lo: row, col_hi: col, row_hi: row }
    }
    Some(index) => {
      let (c1, r1) = parse_cell_ref(target[:index], full=target)
      let (c2, r2) = parse_cell_ref(target[index + 1:], full=target)
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
/// Strictly parses one `[$]AA[$]11`-style reference into 1-based
/// `(col, row)`. `full~` is the whole user input, echoed in errors.
fn parse_cell_ref(
  reference : StringView,
  full~ : String,
) -> (Int, Int) raise RangeError {
  let mut pos = 0
  let len = reference.length()
  fn at(i : Int) -> UInt16 {
    reference[i]
  }

  if pos < len && at(pos) == '$' {
    pos += 1
  }
  // Column letters: at most 3 (XFD is the last column).
  let col_start = pos
  while pos < len && at(pos) is ('A'..='Z' | 'a'..='z') {
    pos += 1
  }
  let letters = pos - col_start
  if letters < 1 || letters > 3 {
    raise MalformedRef(ref_=full)
  }
  let mut col = 0
  for i in col_start..<pos {
    let c = at(i).to_int()
    let upper = if c >= 'a'.to_int() { c - 32 } else { c }
    col = col * 26 + (upper - 'A'.to_int() + 1)
  }
  if pos < len && at(pos) == '$' {
    pos += 1
  }
  // Row digits: at most 7 (1048576 is the last row), no other trailing text.
  let row_start = pos
  while pos < len && at(pos) is ('0'..='9') {
    pos += 1
  }
  let digits = pos - row_start
  if digits < 1 || digits > 7 || pos != len {
    raise MalformedRef(ref_=full)
  }
  let mut row = 0
  for i in row_start..<pos {
    row = row * 10 + (at(i).to_int() - '0'.to_int())
  }
  if row < 1 || row > MAX_ROW || col > MAX_COL {
    raise MalformedRef(ref_=full)
  }
  (col, row)
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
