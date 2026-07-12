///|
fn cell_ref_to_rc(reference : StringView) -> (Int, Int) raise XlsxError {
  let len = reference.length()
  let mut idx = 0
  if idx < len && reference[idx] == '$' {
    idx = idx + 1
  }
  let mut col = 0
  let mut has_col = false
  while idx < len {
    let u0 = reference[idx]
    if u0 is ('A'..='Z') || u0 is ('a'..='z') {
      let upper = if u0 is ('a'..='z') { u0 - 32 } else { u0 }
      col = col * 26 + (upper.to_int() - ('A' : UInt16).to_int() + 1)
      has_col = true
      idx = idx + 1
      continue
    }
    break
  }
  if !has_col {
    raise InvalidCellRef(value=reference.to_owned())
  }
  if idx < len && reference[idx] == '$' {
    idx = idx + 1
  }
  let mut row = 0
  let mut has_row = false
  while idx < len {
    let u0 = reference[idx]
    if u0 is ('0'..='9') {
      has_row = true
      row = row * 10 + (u0.to_int() - ('0' : UInt16).to_int())
      idx = idx + 1
      continue
    }
    raise InvalidCellRef(value=reference.to_owned())
  }
  if col == 0 || !has_row {
    raise InvalidCellRef(value=reference.to_owned())
  }
  if row <= 0 {
    raise InvalidCellRef(value=reference.to_owned())
  }
  (row, col)
}

///|
fn cell_ref_from(row : Int, col : Int) -> String raise XlsxError {
  if row <= 0 || col <= 0 {
    raise InvalidCellRef(value="\{col}:\{row}")
  }
  // Reject out-of-grid coordinates rather than emit an invalid reference like
  // "A1048577". Every worksheet cell/range/anchor coordinate is within the
  // grid, so this only fires on a bug (e.g. a shift that overflows the sheet) —
  // a backstop against writing a malformed package.
  if row > cell_ref_max_rows || col > cell_ref_max_cols {
    raise InvalidCellRef(value="\{col}:\{row}")
  }
  "\{column_number_to_name(col)}\{row}"
}

///|
/// Converts a column-letter reference to its 1-based column number, e.g.
/// `"A"` -> 1, `"Z"` -> 26, `"AA"` -> 27. Letters are case-insensitive.
/// Inverse of `column_number_to_name`.
///
/// Raises `InvalidCellRef` if `name` is empty, contains any non-letter
/// character, or is long enough that the column number overflows.
pub fn column_name_to_number(name : StringView) -> Int raise XlsxError {
  if name == "" {
    raise InvalidCellRef(value=name.to_owned())
  }
  let mut value = 0
  for c in name {
    let u0 = c.to_int()
    if u0 is ('A'..='Z') {
      value = value * 26 + (u0 - 'A'.to_int() + 1)
    } else if u0 is ('a'..='z') {
      value = value * 26 + (u0 - 'a'.to_int() + 1)
    } else {
      raise InvalidCellRef(value=name.to_owned())
    }
  }
  if value <= 0 {
    raise InvalidCellRef(value=name.to_owned())
  }
  value
}

///|
/// Converts a 1-based column number to its letter reference, e.g. `1` -> `"A"`,
/// `26` -> `"Z"`, `27` -> `"AA"`. Inverse of `column_name_to_number`.
///
/// Raises `InvalidCellRef` if `col` is less than 1.
pub fn column_number_to_name(col : Int) -> String raise XlsxError {
  if col <= 0 {
    raise InvalidCellRef(value="\{col}")
  }
  let mut n = col
  let mut len = 0
  while n > 0 {
    len = len + 1
    n = (n - 1) / 26
  }
  let out : FixedArray[Char] = FixedArray::make(len, 'A')
  let mut idx = len - 1
  n = col
  while true {
    let rem = (n - 1) % 26
    out[idx] = Int::unsafe_to_char('A'.to_int() + rem)
    n = (n - 1) / 26
    if n == 0 {
      break
    }
    idx = idx - 1
  }
  let sb = StringBuilder::new()
  for c in out {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
let cell_ref_max_rows = 1048576

///|
let cell_ref_max_cols = 16384

///|
/// Splits a cell reference into its column letters and 1-based row number, e.g.
/// `"AB12"` -> `("AB", 12)`. Column letters are upper-cased and absolute-
/// reference `$` markers are ignored, so `"$C$5"` -> `("C", 5)`.
///
/// Raises `InvalidCellRef` if `cell` is empty, is missing either the column or
/// the row part, has letters following digits, contains an unexpected
/// character, has a row of 0, or has a row number too large to parse.
pub fn split_cell_name(cell : StringView) -> (String, Int) raise XlsxError {
  let text = cell.to_owned()
  if text == "" {
    raise InvalidCellRef(value=text)
  }
  let col_sb = StringBuilder::new()
  let row_sb = StringBuilder::new()
  let mut seen_digit = false
  for c in text {
    if !seen_digit && (c.is_ascii_alphabetic() || c == '$') {
      if c.is_ascii_alphabetic() {
        col_sb.write_char(c.to_ascii_uppercase())
      }
    } else if c.is_ascii_digit() {
      seen_digit = true
      row_sb.write_char(c)
    } else {
      raise InvalidCellRef(value=text)
    }
  }
  let col = col_sb.to_string()
  let row_text = row_sb.to_string()
  if col == "" || row_text == "" {
    raise InvalidCellRef(value=text)
  }
  let row = @string.parse_int(row_text, base=10) catch {
    _ => raise InvalidCellRef(value=text)
  }
  if row <= 0 {
    raise InvalidCellRef(value=text)
  }
  (col, row)
}

///|
/// Joins column letters and a 1-based row number into a cell reference, e.g.
/// `("A", 2)` -> `"A2"`. The column is normalized (lowercase letters are
/// upper-cased), so `("a", 2)` also yields `"A2"`. Inverse of
/// `split_cell_name`.
///
/// Raises `InvalidCellRef` if `col` is not valid column letters or `row` is
/// less than 1.
pub fn join_cell_name(col : StringView, row : Int) -> String raise XlsxError {
  let col_number = column_name_to_number(col)
  if row <= 0 {
    raise InvalidCellRef(value="\{col}:\{row}")
  }
  let col_name = column_number_to_name(col_number)
  "\{col_name}\{row}"
}

///|
/// Converts a cell reference to `(column, row)` coordinates, both 1-based, e.g.
/// `"C5"` -> `(3, 5)`. The tuple is column-first, not row-first. Inverse of
/// `coordinates_to_cell_name`.
///
/// Raises `InvalidCellRef` if `cell` is malformed, its row exceeds 1048576, or
/// its column exceeds 16384 (the sheet grid limits).
pub fn cell_name_to_coordinates(
  cell : StringView,
) -> (Int, Int) raise XlsxError {
  let (col_name, row) = split_cell_name(cell)
  if row > cell_ref_max_rows {
    raise InvalidCellRef(value=cell.to_owned())
  }
  let col = column_name_to_number(col_name)
  if col > cell_ref_max_cols {
    raise InvalidCellRef(value=cell.to_owned())
  }
  (col, row)
}

///|
/// Converts 1-based `(col, row)` coordinates to a cell reference, e.g.
/// `(3, 5)` -> `"C5"`. When `abs` is true each part is prefixed with `$` to form
/// an absolute reference, so `(3, 5)` -> `"$C$5"`. Inverse of
/// `cell_name_to_coordinates`.
///
/// Raises `InvalidCellRef` if `col` or `row` is less than 1, the row exceeds
/// 1048576, or the column exceeds 16384.
pub fn coordinates_to_cell_name(
  col : Int,
  row : Int,
  abs? : Bool = false,
) -> String raise XlsxError {
  if col <= 0 || row <= 0 {
    raise InvalidCellRef(value="\{col}:\{row}")
  }
  if row > cell_ref_max_rows || col > cell_ref_max_cols {
    raise InvalidCellRef(value="\{col}:\{row}")
  }
  let col_name = column_number_to_name(col)
  let sign = if abs { "$" } else { "" }
  "\{sign}\{col_name}\{sign}\{row}"
}
