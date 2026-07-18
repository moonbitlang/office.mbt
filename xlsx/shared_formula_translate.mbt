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
priv struct FormulaTranslationBudget {
  maximum_work_units : Int
  cancelled : () -> Bool
  mut work_units : Int
  mut next_checkpoint : Int
}

///|
fn FormulaTranslationBudget::new(
  maximum_work_units : Int,
  cancelled : () -> Bool,
) -> FormulaTranslationBudget {
  { maximum_work_units, cancelled, work_units: 0, next_checkpoint: 0 }
}

///|
fn FormulaTranslationBudget::checkpoint(
  self : FormulaTranslationBudget,
) -> Unit raise XlsxError {
  if (self.cancelled)() {
    raise ReadCancelled
  }
}

///|
fn FormulaTranslationBudget::charge_work(
  self : FormulaTranslationBudget,
  amount : Int,
) -> Unit raise XlsxError {
  if amount <= 0 {
    return
  }
  let (actual, exceeded) = read_budget_actual(
    self.work_units,
    amount,
    self.maximum_work_units,
  )
  if exceeded {
    raise ResourceLimitExceeded(
      kind="shared_formula_work_units",
      limit=self.maximum_work_units,
      actual~,
    )
  }
  self.work_units = actual
  if self.work_units >= self.next_checkpoint {
    self.checkpoint()
    self.next_checkpoint = if self.work_units > 0x7fffffff - 4096 {
      0x7fffffff
    } else {
      self.work_units + 4096
    }
  }
}

///|
priv struct FormulaTranslationOutput {
  builder : StringBuilder
  budget : FormulaTranslationBudget
  maximum_chars : Int
  mut chars : Int
}

///|
fn FormulaTranslationOutput::new(
  size_hint : Int,
  maximum_chars : Int,
  budget : FormulaTranslationBudget,
) -> FormulaTranslationOutput {
  { builder: StringBuilder::new(size_hint~), budget, maximum_chars, chars: 0 }
}

///|
fn FormulaTranslationOutput::charge_chars(
  self : FormulaTranslationOutput,
  amount : Int,
) -> Unit raise XlsxError {
  let (actual, exceeded) = read_budget_actual(
    self.chars,
    amount,
    self.maximum_chars,
  )
  if exceeded {
    raise ResourceLimitExceeded(
      kind="shared_formula_output_chars",
      limit=self.maximum_chars,
      actual~,
    )
  }
  self.chars = actual
}

///|
fn FormulaTranslationOutput::write_char(
  self : FormulaTranslationOutput,
  character : Char,
) -> Unit raise XlsxError {
  let width = if character.to_int() > 0xffff { 2 } else { 1 }
  self.budget.charge_work(width)
  self.charge_chars(width)
  self.builder.write_char(character)
}

///|
fn FormulaTranslationOutput::write_string(
  self : FormulaTranslationOutput,
  value : String,
) -> Unit raise XlsxError {
  let width = value.length()
  self.budget.charge_work(width)
  self.charge_chars(width)
  self.builder.write_string(value)
}

///|
fn formula_character(
  chars : ArrayView[Char],
  index : Int,
  budget : FormulaTranslationBudget,
) -> Char raise XlsxError {
  let character = chars[index]
  budget.charge_work(if character.to_int() > 0xffff { 2 } else { 1 })
  character
}

///|
fn FormulaTranslationOutput::write_formula_chars(
  self : FormulaTranslationOutput,
  chars : ArrayView[Char],
  start : Int,
  end : Int,
) -> Unit raise XlsxError {
  for index in start..<end {
    self.write_char(formula_character(chars, index, self.budget))
  }
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
  budget : FormulaTranslationBudget,
) -> Bool raise XlsxError {
  start == 0 ||
  !formula_reference_word_char(formula_character(chars, start - 1, budget))
}

///|
fn formula_reference_end_boundary(
  chars : ArrayView[Char],
  end : Int,
  budget : FormulaTranslationBudget,
) -> Bool raise XlsxError {
  if end >= chars.length() {
    return true
  }
  let character = formula_character(chars, end, budget)
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
  budget : FormulaTranslationBudget,
) -> Int? raise XlsxError {
  let mut column = 0
  for index in start..<end {
    let character = formula_character(chars, index, budget).to_ascii_uppercase()
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
  budget : FormulaTranslationBudget,
) -> Int? raise XlsxError {
  if start >= end {
    return None
  }
  let mut value = 0
  for index in start..<end {
    let character = formula_character(chars, index, budget)
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
  budget : FormulaTranslationBudget,
) -> FormulaCellToken? raise XlsxError {
  if start < 0 || start >= chars.length() {
    return None
  }
  let mut index = start
  let absolute_column = formula_character(chars, index, budget) == '$'
  if absolute_column {
    index += 1
  }
  let column_start = index
  while index < chars.length() {
    if !formula_character(chars, index, budget).is_ascii_alphabetic() {
      break
    }
    index += 1
  }
  let column_end = index
  if column_end == column_start || column_end - column_start > 3 {
    return None
  }
  let absolute_row = if index < chars.length() {
    formula_character(chars, index, budget) == '$'
  } else {
    false
  }
  if absolute_row {
    index += 1
  }
  let row_start = index
  while index < chars.length() {
    if !formula_character(chars, index, budget).is_ascii_digit() {
      break
    }
    index += 1
  }
  let row_end = index
  guard formula_column_number(chars, column_start, column_end, budget)
    is Some(column) &&
    formula_bounded_decimal(chars, row_start, row_end, excel_max_rows, budget)
    is Some(row) else {
    return None
  }
  Some({
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
  budget : FormulaTranslationBudget,
) -> FormulaColumnToken? raise XlsxError {
  if start < 0 || start >= chars.length() {
    return None
  }
  let mut index = start
  let absolute = formula_character(chars, index, budget) == '$'
  if absolute {
    index += 1
  }
  let letters_start = index
  while index < chars.length() {
    if !formula_character(chars, index, budget).is_ascii_alphabetic() {
      break
    }
    index += 1
  }
  let letters_end = index
  if letters_end == letters_start || letters_end - letters_start > 3 {
    return None
  }
  guard formula_column_number(chars, letters_start, letters_end, budget)
    is Some(column) else {
    return None
  }
  Some({ start, end: index, absolute, column })
}

///|
fn parse_formula_row_token(
  chars : ArrayView[Char],
  start : Int,
  budget : FormulaTranslationBudget,
) -> FormulaRowToken? raise XlsxError {
  if start < 0 || start >= chars.length() {
    return None
  }
  let mut index = start
  let absolute = formula_character(chars, index, budget) == '$'
  if absolute {
    index += 1
  }
  let digits_start = index
  while index < chars.length() {
    if !formula_character(chars, index, budget).is_ascii_digit() {
      break
    }
    index += 1
  }
  let digits_end = index
  guard formula_bounded_decimal(
      chars, digits_start, digits_end, excel_max_rows, budget,
    )
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
fn write_shifted_formula_cell(
  chars : ArrayView[Char],
  token : FormulaCellToken,
  column_delta : Int,
  row_delta : Int,
  out : FormulaTranslationOutput,
) -> Unit raise XlsxError {
  let shifted_column = if token.absolute_column {
    None
  } else {
    formula_shifted_column(token.column, column_delta)
  }
  let shifted_row = if token.absolute_row {
    None
  } else {
    formula_shifted_row(token.row, row_delta)
  }
  if (!token.absolute_column && shifted_column is None) ||
    (!token.absolute_row && shifted_row is None) {
    out.write_string("#REF!")
    return
  }
  if token.absolute_column {
    out.write_char('$')
    out.write_formula_chars(chars, token.column_start, token.column_end)
  } else {
    out.write_string(shifted_column.unwrap())
  }
  if token.absolute_row {
    out.write_char('$')
    out.write_formula_chars(chars, token.row_start, token.row_end)
  } else {
    out.write_string(shifted_row.unwrap())
  }
}

///|
fn write_shifted_formula_column(
  chars : ArrayView[Char],
  token : FormulaColumnToken,
  delta : Int,
  out : FormulaTranslationOutput,
) -> Unit raise XlsxError {
  if token.absolute {
    out.write_formula_chars(chars, token.start, token.end)
  } else {
    out.write_string(
      formula_shifted_column(token.column, delta).unwrap_or("#REF!"),
    )
  }
}

///|
fn write_shifted_formula_row(
  chars : ArrayView[Char],
  token : FormulaRowToken,
  delta : Int,
  out : FormulaTranslationOutput,
) -> Unit raise XlsxError {
  if token.absolute {
    out.write_formula_chars(chars, token.start, token.end)
  } else {
    out.write_string(formula_shifted_row(token.row, delta).unwrap_or("#REF!"))
  }
}

///|
fn formula_range_separator_end(
  chars : ArrayView[Char],
  start : Int,
  budget : FormulaTranslationBudget,
) -> Int? raise XlsxError {
  let mut index = start
  while index < chars.length() {
    if !formula_character(chars, index, budget).is_ascii_whitespace() {
      break
    }
    index += 1
  }
  if index >= chars.length() || formula_character(chars, index, budget) != ':' {
    return None
  }
  index += 1
  while index < chars.length() {
    if !formula_character(chars, index, budget).is_ascii_whitespace() {
      break
    }
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
  out : FormulaTranslationOutput,
) -> Int? raise XlsxError {
  let budget = out.budget
  guard formula_reference_start_boundary(chars, start, budget) &&
    parse_formula_cell_token(chars, start, budget) is Some(first) else {
    return None
  }
  match formula_range_separator_end(chars, first.end, budget) {
    Some(second_start) =>
      match parse_formula_cell_token(chars, second_start, budget) {
        Some(second) if formula_reference_end_boundary(
            chars,
            second.end,
            budget,
          ) => {
          write_shifted_formula_cell(chars, first, column_delta, row_delta, out)
          out.write_formula_chars(chars, first.end, second_start)
          write_shifted_formula_cell(
            chars, second, column_delta, row_delta, out,
          )
          return Some(second.end)
        }
        _ => ()
      }
    None => ()
  }
  if !formula_reference_end_boundary(chars, first.end, budget) {
    return None
  }
  write_shifted_formula_cell(chars, first, column_delta, row_delta, out)
  Some(first.end)
}

///|
fn translate_formula_column_range_at(
  chars : ArrayView[Char],
  start : Int,
  column_delta : Int,
  out : FormulaTranslationOutput,
) -> Int? raise XlsxError {
  let budget = out.budget
  guard formula_reference_start_boundary(chars, start, budget) &&
    parse_formula_column_token(chars, start, budget) is Some(first) &&
    formula_range_separator_end(chars, first.end, budget) is Some(second_start) &&
    parse_formula_column_token(chars, second_start, budget) is Some(second) &&
    formula_reference_end_boundary(chars, second.end, budget) else {
    return None
  }
  write_shifted_formula_column(chars, first, column_delta, out)
  out.write_formula_chars(chars, first.end, second.start)
  write_shifted_formula_column(chars, second, column_delta, out)
  Some(second.end)
}

///|
fn translate_formula_row_range_at(
  chars : ArrayView[Char],
  start : Int,
  row_delta : Int,
  out : FormulaTranslationOutput,
) -> Int? raise XlsxError {
  let budget = out.budget
  guard formula_reference_start_boundary(chars, start, budget) &&
    parse_formula_row_token(chars, start, budget) is Some(first) &&
    formula_range_separator_end(chars, first.end, budget) is Some(second_start) &&
    parse_formula_row_token(chars, second_start, budget) is Some(second) &&
    formula_reference_end_boundary(chars, second.end, budget) else {
    return None
  }
  write_shifted_formula_row(chars, first, row_delta, out)
  out.write_formula_chars(chars, first.end, second.start)
  write_shifted_formula_row(chars, second, row_delta, out)
  Some(second.end)
}

///|
fn copy_formula_quoted_token(
  chars : ArrayView[Char],
  start : Int,
  quote : Char,
  out : FormulaTranslationOutput,
) -> Int raise XlsxError {
  let mut index = start
  out.write_char(formula_character(chars, index, out.budget))
  index += 1
  while index < chars.length() {
    let character = formula_character(chars, index, out.budget)
    out.write_char(character)
    index += 1
    if character == quote {
      if index < chars.length() &&
        formula_character(chars, index, out.budget) == quote {
        out.write_char(formula_character(chars, index, out.budget))
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
  out : FormulaTranslationOutput,
) -> Int raise XlsxError {
  let mut depth = 0
  let mut index = start
  while index < chars.length() {
    let character = formula_character(chars, index, out.budget)
    out.write_char(character)
    index += 1
    if character == '\'' && index < chars.length() {
      // Structured-reference column names use apostrophe to escape syntax
      // characters (notably `[` and `]`). The escaped character is data, so it
      // must not affect bracket nesting or become eligible for A1 translation.
      out.write_char(formula_character(chars, index, out.budget))
      index += 1
    } else if character == '[' {
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
  budget : FormulaTranslationBudget,
) -> Int? raise XlsxError {
  if start < 0 ||
    start >= chars.length() ||
    !formula_reference_start_boundary(chars, start, budget) {
    return None
  }
  let mut index = start
  while index < chars.length() {
    if !formula_unquoted_sheet_name_char(
        formula_character(chars, index, budget),
      ) {
      break
    }
    index += 1
  }
  if index == start ||
    index >= chars.length() ||
    formula_character(chars, index, budget) != ':' {
    return None
  }
  index += 1
  let second_start = index
  while index < chars.length() {
    if !formula_unquoted_sheet_name_char(
        formula_character(chars, index, budget),
      ) {
      break
    }
    index += 1
  }
  if index == second_start ||
    index >= chars.length() ||
    formula_character(chars, index, budget) != '!' {
    return None
  }
  Some(index + 1)
}

///|
fn validate_shared_formula_limits(
  maximum_input_chars : Int,
  maximum_output_chars : Int,
  maximum_work_units : Int,
) -> Unit raise XlsxError {
  if maximum_input_chars < 0 ||
    maximum_output_chars < 0 ||
    maximum_work_units < 0 {
    raise InvalidOptions(
      msg="shared formula translation limits cannot be negative",
    )
  }
}

///|
/// Applies Excel copy semantics to A1 references while preserving formula
/// text outside reference tokens. The input ceiling is checked before the
/// bounded character copy is allocated; every scan and write charges work,
/// every write charges output, and long tokens poll cancellation.
fn translate_shared_formula_limited(
  formula : String,
  column_delta : Int,
  row_delta : Int,
  maximum_input_chars : Int,
  maximum_output_chars : Int,
  maximum_work_units : Int,
  cancelled : () -> Bool,
) -> (String, Int) raise XlsxError {
  validate_shared_formula_limits(
    maximum_input_chars, maximum_output_chars, maximum_work_units,
  )
  let input_chars = formula.length()
  if input_chars > maximum_input_chars {
    raise ResourceLimitExceeded(
      kind="shared_formula_input_chars",
      limit=maximum_input_chars,
      actual=input_chars,
    )
  }
  let budget = FormulaTranslationBudget::new(maximum_work_units, cancelled)
  budget.checkpoint()
  // Charge the scalar materialization before allocating it. Subsequent reads
  // and writes are charged separately so adversarial rescans remain bounded.
  budget.charge_work(input_chars)
  if formula == "" || (column_delta == 0 && row_delta == 0) {
    if input_chars > maximum_output_chars {
      raise ResourceLimitExceeded(
        kind="shared_formula_output_chars",
        limit=maximum_output_chars,
        actual=input_chars,
      )
    }
    return (formula, budget.work_units)
  }
  let chars = formula.to_array()
  budget.checkpoint()
  let out = FormulaTranslationOutput::new(
    input_chars.min(maximum_output_chars),
    maximum_output_chars,
    budget,
  )
  let mut index = 0
  while index < chars.length() {
    let character = formula_character(chars, index, budget)
    if character == '"' || character == '\'' {
      index = copy_formula_quoted_token(chars, index, character, out)
      continue
    }
    if character == '[' {
      index = copy_formula_bracket_token(chars, index, out)
      continue
    }
    match formula_unquoted_3d_qualifier_end(chars, index, budget) {
      Some(end) => {
        out.write_formula_chars(chars, index, end)
        index = end
        continue
      }
      None => ()
    }
    let translated = match
      translate_formula_cell_reference_at(
        chars, index, column_delta, row_delta, out,
      ) {
      Some(next) => Some(next)
      None =>
        match
          translate_formula_column_range_at(chars, index, column_delta, out) {
          Some(next) => Some(next)
          None => translate_formula_row_range_at(chars, index, row_delta, out)
        }
    }
    match translated {
      Some(next) => index = next
      None => {
        out.write_char(character)
        index += 1
      }
    }
  }
  (out.builder.to_string(), budget.work_units)
}

///|
fn translate_shared_formula(
  formula : String,
  column_delta : Int,
  row_delta : Int,
) -> String {
  let (translated, _) = try! translate_shared_formula_limited(
    formula,
    column_delta,
    row_delta,
    0x7fffffff,
    0x7fffffff,
    0x7fffffff,
    () => false,
  )
  translated
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
/// Resolves formula text at a follower coordinate with explicit input,
/// output, work, and cancellation limits. The returned work count lets a
/// caller maintain one aggregate translation budget across many cells.
pub fn SharedFormulaMaster::translate_to_limited(
  self : SharedFormulaMaster,
  row : Int,
  column : Int,
  maximum_input_chars~ : Int,
  maximum_output_chars~ : Int,
  maximum_work_units~ : Int,
  cancelled? : () -> Bool = () => false,
) -> (String, Int) raise XlsxError {
  ignore(cell_ref_from(row, column))
  if !self.contains_coordinate(row, column) {
    raise InvalidXml(msg="shared formula follower is outside the master range")
  }
  translate_shared_formula_limited(
    self.formula,
    column - self.column,
    row - self.row,
    maximum_input_chars,
    maximum_output_chars,
    maximum_work_units,
    cancelled,
  )
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
  let (translated, _) = self.translate_to_limited(
    row,
    column,
    maximum_input_chars=0x7fffffff,
    maximum_output_chars=0x7fffffff,
    maximum_work_units=0x7fffffff,
  )
  translated
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
test "shared formulas preserve apostrophe-escaped structured-reference brackets" {
  inspect(
    translate_shared_formula("Table1[']A1]+B1", 1, 0),
    content="Table1[']A1]+C1",
  )
  inspect(
    translate_shared_formula("Table1['[A1]+B1", 1, 0),
    content="Table1['[A1]+C1",
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

///|
test "shared formula limits reject input output and work independently" {
  try
    translate_shared_formula_limited("A1", 1, 0, 1, 10, 100, () => false)
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      inspect(kind, content="shared_formula_input_chars")
      assert_eq(limit, 1)
      assert_eq(actual, 2)
    }
    _ => fail("unexpected shared formula input limit error")
  } noraise {
    _ => fail("expected shared formula input limit")
  }
  try
    translate_shared_formula_limited("A1", 1, 0, 10, 1, 100, () => false)
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      inspect(kind, content="shared_formula_output_chars")
      assert_eq(limit, 1)
      assert_true(actual > limit)
    }
    _ => fail("unexpected shared formula output limit error")
  } noraise {
    _ => fail("expected shared formula output limit")
  }
  try
    translate_shared_formula_limited("A1", 1, 0, 10, 10, 2, () => false)
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      inspect(kind, content="shared_formula_work_units")
      assert_eq(limit, 2)
      assert_true(actual > limit)
    }
    _ => fail("unexpected shared formula work limit error")
  } noraise {
    _ => fail("expected shared formula work limit")
  }
}

///|
test "shared formula translation polls inside long quoted tokens" {
  let checks = [0]
  let formula = "\"" + "a".repeat(9000) + "\"+A1"
  try
    translate_shared_formula_limited(formula, 1, 0, 10000, 10000, 100000, () => {
      checks[0] = checks[0] + 1
      checks[0] >= 4
    })
  catch {
    ReadCancelled => assert_true(checks[0] >= 4)
    _ => fail("unexpected shared formula cancellation error")
  } noraise {
    _ => fail("expected shared formula cancellation")
  }
}
