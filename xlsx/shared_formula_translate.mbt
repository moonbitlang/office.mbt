///|
/// One non-empty shared-formula master. The coordinate is retained because
/// OOXML stores follower formulas as relative translations of this cell, not
/// as copies of the master's literal text.
pub struct SharedFormulaMaster {
  priv formula : String
  priv row : Int
  priv column : Int
  priv row_lo : Int
  priv column_lo : Int
  priv row_hi : Int
  priv column_hi : Int
}

///|
priv struct FormulaCellToken {
  start : Int
  end : Int
  column_start : Int
  column_end : Int
  row_start : Int
  row_end : Int
  absolute_column : Bool
  absolute_row : Bool
  column : Int
  row : Int
}

///|
priv struct FormulaColumnToken {
  start : Int
  end : Int
  absolute : Bool
  column : Int
}

///|
priv struct FormulaRowToken {
  start : Int
  end : Int
  absolute : Bool
  row : Int
}

///|
fn formula_chars_text(
  chars : ArrayView[Char],
  start : Int,
  end : Int,
) -> String {
  let out = StringBuilder::new()
  for index in start..<end {
    out.write_char(chars[index])
  }
  out.to_string()
}

///|
fn formula_reference_word_char(character : Char) -> Bool {
  character.is_ascii_alphabetic() ||
  character.is_ascii_digit() ||
  character == '_' ||
  character == '.' ||
  character == '$' ||
  character == '\\' ||
  character == '?' ||
  character.to_int() > 0x7f
}

///|
fn formula_reference_start_boundary(
  chars : ArrayView[Char],
  start : Int,
) -> Bool {
  start == 0 || !formula_reference_word_char(chars[start - 1])
}

///|
fn formula_reference_end_boundary(chars : ArrayView[Char], end : Int) -> Bool {
  if end >= chars.length() {
    return true
  }
  let character = chars[end]
  !formula_reference_word_char(character) &&
  character != '(' &&
  character != '[' &&
  character != '!'
}

///|
fn formula_column_number(
  chars : ArrayView[Char],
  start : Int,
  end : Int,
) -> Int? {
  let mut column = 0
  for index in start..<end {
    let character = chars[index].to_ascii_uppercase()
    if !character.is_ascii_alphabetic() {
      return None
    }
    column = column * 26 + character.to_int() - 'A'.to_int() + 1
    if column > excel_max_cols {
      return None
    }
  }
  if column > 0 {
    Some(column)
  } else {
    None
  }
}

///|
fn formula_bounded_decimal(
  chars : ArrayView[Char],
  start : Int,
  end : Int,
  maximum : Int,
) -> Int? {
  if start >= end {
    return None
  }
  let mut value = 0
  for index in start..<end {
    let character = chars[index]
    if !character.is_ascii_digit() {
      return None
    }
    let digit = character.to_int() - '0'.to_int()
    if value > (maximum - digit) / 10 {
      return None
    }
    value = value * 10 + digit
  }
  if value > 0 && value <= maximum {
    Some(value)
  } else {
    None
  }
}

///|
fn parse_formula_cell_token(
  chars : ArrayView[Char],
  start : Int,
) -> FormulaCellToken? {
  if start < 0 || start >= chars.length() {
    return None
  }
  let mut index = start
  let absolute_column = chars[index] == '$'
  if absolute_column {
    index += 1
  }
  let column_start = index
  while index < chars.length() && chars[index].is_ascii_alphabetic() {
    index += 1
  }
  let column_end = index
  if column_end == column_start || column_end - column_start > 3 {
    return None
  }
  let absolute_row = index < chars.length() && chars[index] == '$'
  if absolute_row {
    index += 1
  }
  let row_start = index
  while index < chars.length() && chars[index].is_ascii_digit() {
    index += 1
  }
  let row_end = index
  guard formula_column_number(chars, column_start, column_end) is Some(column) &&
    formula_bounded_decimal(chars, row_start, row_end, excel_max_rows)
    is Some(row) else {
    return None
  }
  Some({
    start,
    end: index,
    column_start,
    column_end,
    row_start,
    row_end,
    absolute_column,
    absolute_row,
    column,
    row,
  })
}

///|
fn parse_formula_column_token(
  chars : ArrayView[Char],
  start : Int,
) -> FormulaColumnToken? {
  if start < 0 || start >= chars.length() {
    return None
  }
  let mut index = start
  let absolute = chars[index] == '$'
  if absolute {
    index += 1
  }
  let letters_start = index
  while index < chars.length() && chars[index].is_ascii_alphabetic() {
    index += 1
  }
  let letters_end = index
  if letters_end == letters_start || letters_end - letters_start > 3 {
    return None
  }
  guard formula_column_number(chars, letters_start, letters_end) is Some(column) else {
    return None
  }
  Some({ start, end: index, absolute, column })
}

///|
fn parse_formula_row_token(
  chars : ArrayView[Char],
  start : Int,
) -> FormulaRowToken? {
  if start < 0 || start >= chars.length() {
    return None
  }
  let mut index = start
  let absolute = chars[index] == '$'
  if absolute {
    index += 1
  }
  let digits_start = index
  while index < chars.length() && chars[index].is_ascii_digit() {
    index += 1
  }
  let digits_end = index
  guard formula_bounded_decimal(chars, digits_start, digits_end, excel_max_rows)
    is Some(row) else {
    return None
  }
  Some({ start, end: index, absolute, row })
}

///|
fn formula_shifted_column(column : Int, delta : Int) -> String? {
  let shifted = column + delta
  if shifted < 1 || shifted > excel_max_cols {
    None
  } else {
    Some(format_column_name_unchecked(shifted))
  }
}

///|
fn formula_shifted_row(row : Int, delta : Int) -> String? {
  let shifted = row + delta
  if shifted < 1 || shifted > excel_max_rows {
    None
  } else {
    Some(shifted.to_string())
  }
}

///|
fn shifted_formula_cell_text(
  chars : ArrayView[Char],
  token : FormulaCellToken,
  column_delta : Int,
  row_delta : Int,
) -> String? {
  let out = StringBuilder::new()
  if token.absolute_column {
    out.write_char('$')
    for index in token.column_start..<token.column_end {
      out.write_char(chars[index])
    }
  } else {
    guard formula_shifted_column(token.column, column_delta) is Some(column) else {
      return None
    }
    out.write_string(column)
  }
  if token.absolute_row {
    out.write_char('$')
    for index in token.row_start..<token.row_end {
      out.write_char(chars[index])
    }
  } else {
    guard formula_shifted_row(token.row, row_delta) is Some(row) else {
      return None
    }
    out.write_string(row)
  }
  Some(out.to_string())
}

///|
fn shifted_formula_column_text(
  chars : ArrayView[Char],
  token : FormulaColumnToken,
  delta : Int,
) -> String? {
  if token.absolute {
    return Some(formula_chars_text(chars, token.start, token.end))
  }
  formula_shifted_column(token.column, delta)
}

///|
fn shifted_formula_row_text(
  chars : ArrayView[Char],
  token : FormulaRowToken,
  delta : Int,
) -> String? {
  if token.absolute {
    return Some(formula_chars_text(chars, token.start, token.end))
  }
  formula_shifted_row(token.row, delta)
}

///|
fn formula_range_separator_end(chars : ArrayView[Char], start : Int) -> Int? {
  let mut index = start
  while index < chars.length() && chars[index].is_ascii_whitespace() {
    index += 1
  }
  if index >= chars.length() || chars[index] != ':' {
    return None
  }
  index += 1
  while index < chars.length() && chars[index].is_ascii_whitespace() {
    index += 1
  }
  Some(index)
}

///|
fn translate_formula_cell_reference_at(
  chars : ArrayView[Char],
  start : Int,
  column_delta : Int,
  row_delta : Int,
) -> (String, Int)? {
  guard formula_reference_start_boundary(chars, start) &&
    parse_formula_cell_token(chars, start) is Some(first) else {
    return None
  }
  match formula_range_separator_end(chars, first.end) {
    Some(second_start) =>
      match parse_formula_cell_token(chars, second_start) {
        Some(second) if formula_reference_end_boundary(chars, second.end) => {
          let first_text = shifted_formula_cell_text(
            chars, first, column_delta, row_delta,
          )
          let second_text = shifted_formula_cell_text(
            chars, second, column_delta, row_delta,
          )
          return Some(
            (
              first_text.unwrap_or("#REF!") +
              formula_chars_text(chars, first.end, second.start) +
              second_text.unwrap_or("#REF!"),
              second.end,
            ),
          )
        }
        _ => ()
      }
    None => ()
  }
  if !formula_reference_end_boundary(chars, first.end) {
    return None
  }
  Some(
    (
      shifted_formula_cell_text(chars, first, column_delta, row_delta).unwrap_or(
        "#REF!",
      ),
      first.end,
    ),
  )
}

///|
fn translate_formula_column_range_at(
  chars : ArrayView[Char],
  start : Int,
  column_delta : Int,
) -> (String, Int)? {
  guard formula_reference_start_boundary(chars, start) &&
    parse_formula_column_token(chars, start) is Some(first) &&
    formula_range_separator_end(chars, first.end) is Some(second_start) &&
    parse_formula_column_token(chars, second_start) is Some(second) &&
    formula_reference_end_boundary(chars, second.end) else {
    return None
  }
  let first_text = shifted_formula_column_text(chars, first, column_delta)
  let second_text = shifted_formula_column_text(chars, second, column_delta)
  Some(
    (
      first_text.unwrap_or("#REF!") +
      formula_chars_text(chars, first.end, second.start) +
      second_text.unwrap_or("#REF!"),
      second.end,
    ),
  )
}

///|
fn translate_formula_row_range_at(
  chars : ArrayView[Char],
  start : Int,
  row_delta : Int,
) -> (String, Int)? {
  guard formula_reference_start_boundary(chars, start) &&
    parse_formula_row_token(chars, start) is Some(first) &&
    formula_range_separator_end(chars, first.end) is Some(second_start) &&
    parse_formula_row_token(chars, second_start) is Some(second) &&
    formula_reference_end_boundary(chars, second.end) else {
    return None
  }
  let first_text = shifted_formula_row_text(chars, first, row_delta)
  let second_text = shifted_formula_row_text(chars, second, row_delta)
  Some(
    (
      first_text.unwrap_or("#REF!") +
      formula_chars_text(chars, first.end, second.start) +
      second_text.unwrap_or("#REF!"),
      second.end,
    ),
  )
}

///|
fn copy_formula_quoted_token(
  chars : ArrayView[Char],
  start : Int,
  quote : Char,
  out : StringBuilder,
) -> Int {
  let mut index = start
  out.write_char(chars[index])
  index += 1
  while index < chars.length() {
    let character = chars[index]
    out.write_char(character)
    index += 1
    if character == quote {
      if index < chars.length() && chars[index] == quote {
        out.write_char(chars[index])
        index += 1
      } else {
        break
      }
    }
  }
  index
}

///|
fn copy_formula_bracket_token(
  chars : ArrayView[Char],
  start : Int,
  out : StringBuilder,
) -> Int {
  let mut depth = 0
  let mut index = start
  while index < chars.length() {
    let character = chars[index]
    out.write_char(character)
    index += 1
    if character == '[' {
      depth += 1
    } else if character == ']' {
      depth -= 1
      if depth == 0 {
        break
      }
    }
  }
  index
}

///|
fn formula_unquoted_sheet_name_char(character : Char) -> Bool {
  character.is_ascii_alphabetic() ||
  character.is_ascii_digit() ||
  character == '_' ||
  character == '.' ||
  character == '$' ||
  character.to_int() > 0x7f
}

///|
/// Returns the end of an unquoted 3-D sheet qualifier such as
/// `Sheet1:Sheet3!`. Sheet names that happen to look like A1 coordinates must
/// remain opaque; only the cell/range after `!` participates in copy
/// translation.
fn formula_unquoted_3d_qualifier_end(
  chars : ArrayView[Char],
  start : Int,
) -> Int? {
  if start < 0 ||
    start >= chars.length() ||
    !formula_reference_start_boundary(chars, start) {
    return None
  }
  let mut index = start
  while index < chars.length() && formula_unquoted_sheet_name_char(chars[index]) {
    index += 1
  }
  if index == start || index >= chars.length() || chars[index] != ':' {
    return None
  }
  index += 1
  let second_start = index
  while index < chars.length() && formula_unquoted_sheet_name_char(chars[index]) {
    index += 1
  }
  if index == second_start || index >= chars.length() || chars[index] != '!' {
    return None
  }
  Some(index + 1)
}

///|
/// Applies Excel copy semantics to A1 references while preserving formula
/// text outside reference tokens. Double-quoted literals, quoted sheet names,
/// unquoted 3-D sheet ranges, structured-reference brackets, and
/// external-workbook brackets are copied verbatim. Cell/range, whole-column,
/// and whole-row references honor `$` anchors; translations outside the XLSX
/// grid become `#REF!`.
fn translate_shared_formula(
  formula : String,
  column_delta : Int,
  row_delta : Int,
) -> String {
  if formula == "" || (column_delta == 0 && row_delta == 0) {
    return formula
  }
  let chars = formula.to_array()
  let out = StringBuilder::new()
  let mut index = 0
  while index < chars.length() {
    let character = chars[index]
    if character == '"' || character == '\'' {
      index = copy_formula_quoted_token(chars, index, character, out)
      continue
    }
    if character == '[' {
      index = copy_formula_bracket_token(chars, index, out)
      continue
    }
    match formula_unquoted_3d_qualifier_end(chars, index) {
      Some(end) => {
        for position in index..<end {
          out.write_char(chars[position])
        }
        index = end
        continue
      }
      None => ()
    }
    let translated = match
      translate_formula_cell_reference_at(chars, index, column_delta, row_delta) {
      Some(value) => Some(value)
      None =>
        match translate_formula_column_range_at(chars, index, column_delta) {
          Some(value) => Some(value)
          None => translate_formula_row_range_at(chars, index, row_delta)
        }
    }
    match translated {
      Some((text, next)) => {
        out.write_string(text)
        index = next
      }
      None => {
        out.write_char(character)
        index += 1
      }
    }
  }
  out.to_string()
}

///|
fn SharedFormulaMaster::contains_coordinate(
  self : SharedFormulaMaster,
  row : Int,
  column : Int,
) -> Bool {
  row >= self.row_lo &&
  row <= self.row_hi &&
  column >= self.column_lo &&
  column <= self.column_hi
}

///|
/// Resolves the formula text represented by this shared master at a follower
/// coordinate. Coordinates outside the master's declared shared range are
/// rejected as malformed OOXML.
pub fn SharedFormulaMaster::translate_to(
  self : SharedFormulaMaster,
  row : Int,
  column : Int,
) -> String raise XlsxError {
  ignore(cell_ref_from(row, column))
  if !self.contains_coordinate(row, column) {
    raise InvalidXml(msg="shared formula follower is outside the master range")
  }
  translate_shared_formula(self.formula, column - self.column, row - self.row)
}

///|
test "shared formulas translate relative A1 references without touching literals" {
  let formula =
    #|D1+$D1+D$1+$D$1+SUM(D1:E2)+'Q1'!D1+"D1"+Table1[D1]+A:A+$A:B+1:1+$1:2+LOG10(100)+A1!B2+[Book.xlsx]Sheet1!C3
  inspect(
    translate_shared_formula(formula, 2, 2),
    content=(
      #|F3+$D3+F$1+$D$1+SUM(F3:G4)+'Q1'!F3+"D1"+Table1[D1]+C:C+$A:D+3:3+$1:4+LOG10(100)+A1!D4+[Book.xlsx]Sheet1!E5
    ),
  )
}

///|
test "shared formulas emit REF for translated coordinates outside the grid" {
  inspect(
    translate_shared_formula("A1:XFD1048576", -1, 1),
    content="#REF!:#REF!",
  )
  inspect(translate_shared_formula("A1:B2", -1, 0), content="#REF!:A2")
  inspect(translate_shared_formula("XFD1", 1, 0), content="#REF!")
}

///|
test "shared formulas preserve unquoted 3-D sheet qualifiers" {
  let formula =
    #|SUM(Q1:Q4!A1)+SUM(Sheet_1:Sheet_4!B2:C3)+SUM([Book.xlsx]Q1:Q4!$D4)
  inspect(
    translate_shared_formula(formula, 2, 1),
    content=(
      #|SUM(Q1:Q4!C2)+SUM(Sheet_1:Sheet_4!D3:E4)+SUM([Book.xlsx]Q1:Q4!$D5)
    ),
  )
}
