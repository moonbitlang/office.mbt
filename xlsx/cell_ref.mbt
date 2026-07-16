///|
fn bounded_radix_step(
  value : Int,
  digit : Int,
  radix : Int,
  limit : Int,
) -> Int? {
  if value > (limit - digit) / radix {
    None
  } else {
    Some(value * radix + digit)
  }
}

///|
fn try_parse_column_name(name : StringView) -> Int? {
  if name == "" {
    return None
  }
  let mut value = 0
  for ch in name {
    let code = ch.to_int()
    let digit = if code is ('A'..='Z') {
      code - 'A'.to_int() + 1
    } else if code is ('a'..='z') {
      code - 'a'.to_int() + 1
    } else {
      return None
    }
    match bounded_radix_step(value, digit, 26, cell_ref_max_cols) {
      Some(next) => value = next
      None => return None
    }
  }
  Some(value)
}

///|
fn try_parse_row_number(text : StringView) -> Int? {
  if text == "" {
    return None
  }
  let mut value = 0
  for ch in text {
    if !ch.is_ascii_digit() {
      return None
    }
    let digit = ch.to_int() - '0'.to_int()
    match bounded_radix_step(value, digit, 10, cell_ref_max_rows) {
      Some(next) => value = next
      None => return None
    }
  }
  if value == 0 {
    None
  } else {
    Some(value)
  }
}

///|
fn try_parse_cell_ref_parts(reference : StringView) -> (Int, Int, Bool, Bool)? {
  let len = reference.length()
  let mut idx = 0
  let mut abs_col = false
  if idx < len && reference[idx] == '$' {
    abs_col = true
    idx = idx + 1
  }
  let mut col = 0
  let mut has_col = false
  while idx < len {
    let unit = reference[idx]
    if unit is ('A'..='Z') || unit is ('a'..='z') {
      let upper = if unit is ('a'..='z') { unit - 32 } else { unit }
      let digit = upper.to_int() - ('A' : UInt16).to_int() + 1
      match bounded_radix_step(col, digit, 26, cell_ref_max_cols) {
        Some(next) => col = next
        None => return None
      }
      has_col = true
      idx = idx + 1
    } else {
      break
    }
  }
  if !has_col {
    return None
  }
  let mut abs_row = false
  if idx < len && reference[idx] == '$' {
    abs_row = true
    idx = idx + 1
  }
  let mut row = 0
  let mut has_row = false
  while idx < len {
    let unit = reference[idx]
    if !(unit is ('0'..='9')) {
      return None
    }
    let digit = unit.to_int() - ('0' : UInt16).to_int()
    match bounded_radix_step(row, digit, 10, cell_ref_max_rows) {
      Some(next) => row = next
      None => return None
    }
    has_row = true
    idx = idx + 1
  }
  if !has_row || row == 0 {
    return None
  }
  Some((row, col, abs_col, abs_row))
}

///|
fn parse_cell_ref_parts(
  reference : StringView,
) -> (Int, Int, Bool, Bool) raise XlsxError {
  match try_parse_cell_ref_parts(reference) {
    Some(parts) => parts
    None => raise InvalidCellRef(value=reference.to_owned())
  }
}

///|
fn cell_ref_to_rc(reference : StringView) -> (Int, Int) raise XlsxError {
  let (row, col, _abs_col, _abs_row) = parse_cell_ref_parts(reference)
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
/// character, or names a column beyond XFD (16,384).
pub fn column_name_to_number(name : StringView) -> Int raise XlsxError {
  match try_parse_column_name(name) {
    Some(value) => value
    None => raise InvalidCellRef(value=name.to_owned())
  }
}

///|
fn format_column_name_unchecked(col : Int) -> String {
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
  for ch in out {
    sb.write_char(ch)
  }
  sb.to_string()
}

///|
/// Converts a 1-based column number to its letter reference, e.g. `1` -> `"A"`,
/// `26` -> `"Z"`, `27` -> `"AA"`. Inverse of `column_name_to_number`.
///
/// Raises `InvalidCellRef` if `col` is less than 1 or greater than 16,384.
pub fn column_number_to_name(col : Int) -> String raise XlsxError {
  if col <= 0 || col > cell_ref_max_cols {
    raise InvalidCellRef(value="\{col}")
  }
  format_column_name_unchecked(col)
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
/// character, or lies outside A1:XFD1048576.
pub fn split_cell_name(cell : StringView) -> (String, Int) raise XlsxError {
  let (row, col, _abs_col, _abs_row) = parse_cell_ref_parts(cell)
  (format_column_name_unchecked(col), row)
}

///|
/// Joins column letters and a 1-based row number into a cell reference, e.g.
/// `("A", 2)` -> `"A2"`. The column is normalized (lowercase letters are
/// upper-cased), so `("a", 2)` also yields `"A2"`. Inverse of
/// `split_cell_name`.
///
/// Raises `InvalidCellRef` if `col` is outside A:XFD or `row` is outside
/// 1:1048576.
pub fn join_cell_name(col : StringView, row : Int) -> String raise XlsxError {
  let col_number = column_name_to_number(col)
  cell_ref_from(row, col_number)
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
  let (row, col, _abs_col, _abs_row) = parse_cell_ref_parts(cell)
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

///|
test "cell reference conversions" {
  let pairs : Array[(String, (Int, Int))] = [
    ("A1", (1, 1)),
    ("Z1", (1, 26)),
    ("AA1", (1, 27)),
    ("AB10", (10, 28)),
    ("ZZ2", (2, 702)),
    ("AAA3", (3, 703)),
  ]
  for _, pair in pairs {
    let (reference, (row, col)) = pair
    let (r, c) = cell_ref_to_rc(reference)
    inspect(r == row && c == col, content="true")
    let round = cell_ref_from(row, col)
    inspect(round == reference, content="true")
  }
  @test.assert_raise(() => cell_ref_to_rc("1A"))
}

///|
test "worksheet cell access" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_cell_rc(2, 3, "value")
  debug_inspect(sheet.get_cell("C2"), content="Some(\"value\")")
  debug_inspect(sheet.get_cell_rc(2, 3), content="Some(\"value\")")
  sheet.set_cell("C2", "updated")
  debug_inspect(sheet.get_cell_rc(2, 3), content="Some(\"updated\")")
}

///|
test "workbook cell access" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "hello")
  debug_inspect(workbook.get_cell("Sheet1", "A1"), content="Some(\"hello\")")
  workbook.set_cell_rc("Sheet1", 2, 2, "world")
  debug_inspect(workbook.get_cell("Sheet1", "B2"), content="Some(\"world\")")
  @test.assert_raise(() => workbook.get_cell("Missing", "A1"))
}

///|
test "cell ref conversions edge cases" {
  debug_inspect(
    cell_ref_to_rc("$A$1"),
    content=(
      #|(1, 1)
    ),
  )
  inspect(
    cell_ref_from(1, 1),
    content=(
      #|A1
    ),
  )
  inspect(
    column_name_to_number("A"),
    content=(
      #|1
    ),
  )
  inspect(
    column_name_to_number("aa"),
    content=(
      #|27
    ),
  )
  inspect(
    column_number_to_name(1),
    content=(
      #|A
    ),
  )
  inspect(
    column_number_to_name(27),
    content=(
      #|AA
    ),
  )
  debug_inspect(
    split_cell_name("$b$12"),
    content=(
      #|("B", 12)
    ),
  )
  inspect(
    join_cell_name("b", 12),
    content=(
      #|B12
    ),
  )
  debug_inspect(
    cell_name_to_coordinates("$XFD$1048576"),
    content=(
      #|(16384, 1048576)
    ),
  )
  inspect(
    coordinates_to_cell_name(1, 1),
    content=(
      #|A1
    ),
  )
  inspect(
    coordinates_to_cell_name(1, 1, abs=true),
    content=(
      #|$A$1
    ),
  )
}

///|
test "cell ref invalid inputs" {
  let bad_refs = [
    "", "$", "1A", "A", "A0", "A-1", "A1!", "!", "$A$", "$$A1", "A$0",
  ]
  for r in bad_refs {
    let result : Result[(Int, Int), Error] = Ok(cell_ref_to_rc(r)) catch {
      e => Err(e)
    }
    inspect(
      result is Err(_),
      content=(
        #|true
      ),
    )
  }
  let bad_cols = ["", "A1", "A!", "1", "A A"]
  for c in bad_cols {
    let result : Result[Int, Error] = Ok(column_name_to_number(c)) catch {
      e => Err(e)
    }
    inspect(
      result is Err(_),
      content=(
        #|true
      ),
    )
  }
  let result_neg : Result[String, Error] = Ok(column_number_to_name(0)) catch {
    e => Err(e)
  }
  inspect(
    result_neg is Err(_),
    content=(
      #|true
    ),
  )
  let split_bad = ["", "1", "A0", "A-1", "A!", "A 1"]
  for c in split_bad {
    let result : Result[(String, Int), Error] = Ok(split_cell_name(c)) catch {
      e => Err(e)
    }
    inspect(
      result is Err(_),
      content=(
        #|true
      ),
    )
  }
  let coord_bad : Result[(Int, Int), Error] = Ok(
    cell_name_to_coordinates("XFE1"),
  ) catch {
    e => Err(e)
  }
  inspect(
    coord_bad is Err(_),
    content=(
      #|true
    ),
  )
  let row_oob : Result[(Int, Int), Error] = Ok(
    cell_name_to_coordinates("A1048577"),
  ) catch {
    e => Err(e)
  }
  inspect(
    row_oob is Err(_),
    content=(
      #|true
    ),
  )
  let out_of_range : Result[String, Error] = Ok(
    coordinates_to_cell_name(16385, 1),
  ) catch {
    e => Err(e)
  }
  inspect(
    out_of_range is Err(_),
    content=(
      #|true
    ),
  )
}

///|
test "cell ref row/col guards and split overflow row parse" {
  @test.assert_raise(() => cell_ref_from(0, 1))

  @test.assert_raise(() => join_cell_name("A", 0))

  let huge_row = "A" + "9".repeat(5000)
  let split_overflow : Result[(String, Int), Error] = Ok(
    split_cell_name(huge_row),
  ) catch {
    e => Err(e)
  }
  inspect(split_overflow is Err(_), content="true")
}

///|
test "cell ref column-name overflow guard" {
  let mut overflowed = false
  for n in 1..<512 {
    let name = "Z".repeat(n)
    let parsed : Result[Int, Error] = Ok(column_name_to_number(name)) catch {
      e => Err(e)
    }
    if parsed is Err(XlsxError::InvalidCellRef(_)) {
      overflowed = true
      break
    }
  }
  inspect(overflowed, content="true")
}
