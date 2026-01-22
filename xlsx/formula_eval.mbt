///|
let formula_error_div = "#DIV/0!"

///|
let formula_error_name = "#NAME?"

///|
let formula_error_null = "#NULL!"

///|
let formula_error_na = "#N/A"

///|
let formula_error_value = "#VALUE!"

///|
let formula_error_ref = "#REF!"

///|
let formula_error_num = "#NUM!"

///|
let formula_error_spill = "#SPILL!"

///|
let formula_error_getting_data = "#GETTING_DATA"

///|
let formula_error_calc = "#CALC!"

///|
let excel_max_rows = 1048576

///|
let excel_max_cols = 16384

///|
let max_financial_iterations = 128

///|
let financial_precision = 1.0e-8

///|
let rate_max_iterations = 100

///|
let rate_precision = 1.0e-6

///|
let xirr_max_iterations = 50

///|
let xirr_precision = 1.0e-10

///|
let category_weight_and_mass = 0

///|
let category_distance = 1

///|
let category_time = 2

///|
let category_pressure = 3

///|
let category_force = 4

///|
let category_energy = 5

///|
let category_power = 6

///|
let category_magnetism = 7

///|
let category_temperature = 8

///|
let category_volume_and_liquid_measure = 9

///|
let category_area = 10

///|
let category_information = 11

///|
let category_speed = 12

///|
let rand_state : @random.Rand = @random.Rand::new()

///|
priv enum FormulaValue {
  Number(Double)
  String(String)
  Bool(Bool)
  Error(String)
  Empty
  List(Array[FormulaValue])
}

///|
priv enum UnaryOp {
  Plus
  Minus
  Percent
}

///|
priv enum BinaryOp {
  Add
  Sub
  Mul
  Div
  Pow
  Concat
  Eq
  Ne
  Lt
  Le
  Gt
  Ge
}

///|
priv enum Expr {
  Number(Double)
  String(String)
  Bool(Bool)
  Cell(String, String)
  Range(String, String, String)
  Unary(UnaryOp, Expr)
  Binary(BinaryOp, Expr, Expr)
  FuncCall(String, Array[Expr])
  List(Array[Expr])
}

///|
priv enum FormulaCriteriaType {
  Unset
  Eq
  Ne
  Le
  Ge
  Lt
  Gt
  Regexp
}

///|
priv struct FormulaCriteria {
  kind : FormulaCriteriaType
  condition : FormulaValue
}

///|
priv struct CalcContext {
  visiting : Map[String, Bool]
  mut depth : Int
  max_depth : Int
  mut current_sheet : String
  mut current_ref : String
}

///|
priv struct RangeValues {
  values : Array[FormulaValue]
  rows : Int
  cols : Int
}

///|
priv struct RomanNumeral {
  n : Double
  s : String
}

///|
priv struct CellIndex {
  row : Int
  col : Int
}

///|
fn CalcContext::new() -> CalcContext {
  { visiting: {}, depth: 0, max_depth: 128, current_sheet: "", current_ref: "" }
}

///|
fn RangeValues::get(self : RangeValues, row : Int, col : Int) -> FormulaValue? {
  if row < 0 || col < 0 || row >= self.rows || col >= self.cols {
    None
  } else {
    Some(self.values[row * self.cols + col])
  }
}

///|
priv struct FormulaParser {
  chars : Array[Char]
  mut pos : Int
}

///|
fn FormulaParser::new(text : String) -> FormulaParser {
  { chars: text.to_array(), pos: 0 }
}

///|
fn FormulaParser::at_end(self : FormulaParser) -> Bool {
  self.pos >= self.chars.length()
}

///|
fn FormulaParser::peek(self : FormulaParser) -> Char? {
  if self.pos < self.chars.length() {
    Some(self.chars[self.pos])
  } else {
    None
  }
}

///|
fn FormulaParser::advance(self : FormulaParser) -> Char? {
  let ch = self.peek()
  if ch is Some(_) {
    self.pos = self.pos + 1
  }
  ch
}

///|
fn FormulaParser::consume(self : FormulaParser) -> Unit {
  ignore(self.advance())
}

///|
fn FormulaParser::skip_spaces(self : FormulaParser) -> Unit {
  while self.pos < self.chars.length() &&
        self.chars[self.pos].is_ascii_whitespace() {
    self.pos = self.pos + 1
  }
}

///|
fn parse_formula_expr(formula : StringView) -> Expr raise XlsxError {
  let text = formula.to_string()
  let normalized = if text.has_prefix("=") {
    (text[1:] catch { _ => "" }).to_string()
  } else {
    text
  }
  let parser = FormulaParser::new(normalized)
  let expr = parser.parse_expression()
  parser.skip_spaces()
  if !parser.at_end() {
    raise XlsxError::InvalidXml(msg="formula parse error")
  }
  expr
}

///|
fn FormulaParser::parse_expression(
  self : FormulaParser,
) -> Expr raise XlsxError {
  let mut expr = self.parse_concat()
  self.skip_spaces()
  while true {
    let op = match self.peek() {
      Some('=') => Some(BinaryOp::Eq)
      Some('<') => {
        let start = self.pos
        self.consume()
        match self.peek() {
          Some('=') => {
            self.consume()
            Some(BinaryOp::Le)
          }
          Some('>') => {
            self.consume()
            Some(BinaryOp::Ne)
          }
          _ => {
            self.pos = start
            Some(BinaryOp::Lt)
          }
        }
      }
      Some('>') => {
        let start = self.pos
        self.consume()
        match self.peek() {
          Some('=') => {
            self.consume()
            Some(BinaryOp::Ge)
          }
          _ => {
            self.pos = start
            Some(BinaryOp::Gt)
          }
        }
      }
      _ => None
    }
    match op {
      Some(bin) => {
        match bin {
          BinaryOp::Eq => self.consume()
          BinaryOp::Lt | BinaryOp::Gt => self.consume()
          _ => ()
        }
        let right = self.parse_concat()
        expr = Expr::Binary(bin, expr, right)
      }
      None => break
    }
    self.skip_spaces()
  }
  expr
}

///|
fn FormulaParser::parse_concat(self : FormulaParser) -> Expr raise XlsxError {
  let mut expr = self.parse_add_sub()
  self.skip_spaces()
  while self.peek() == Some('&') {
    self.consume()
    let right = self.parse_add_sub()
    expr = Expr::Binary(BinaryOp::Concat, expr, right)
    self.skip_spaces()
  }
  expr
}

///|
fn FormulaParser::parse_add_sub(self : FormulaParser) -> Expr raise XlsxError {
  let mut expr = self.parse_mul_div()
  self.skip_spaces()
  while true {
    let op = match self.peek() {
      Some('+') => Some(BinaryOp::Add)
      Some('-') => Some(BinaryOp::Sub)
      _ => None
    }
    match op {
      Some(bin) => {
        self.consume()
        let right = self.parse_mul_div()
        expr = Expr::Binary(bin, expr, right)
      }
      None => break
    }
    self.skip_spaces()
  }
  expr
}

///|
fn FormulaParser::parse_mul_div(self : FormulaParser) -> Expr raise XlsxError {
  let mut expr = self.parse_pow()
  self.skip_spaces()
  while true {
    let op = match self.peek() {
      Some('*') => Some(BinaryOp::Mul)
      Some('/') => Some(BinaryOp::Div)
      _ => None
    }
    match op {
      Some(bin) => {
        self.consume()
        let right = self.parse_pow()
        expr = Expr::Binary(bin, expr, right)
      }
      None => break
    }
    self.skip_spaces()
  }
  expr
}

///|
fn FormulaParser::parse_pow(self : FormulaParser) -> Expr raise XlsxError {
  let mut expr = self.parse_unary()
  self.skip_spaces()
  if self.peek() == Some('^') {
    self.consume()
    let right = self.parse_pow()
    expr = Expr::Binary(BinaryOp::Pow, expr, right)
  }
  expr
}

///|
fn FormulaParser::parse_unary(self : FormulaParser) -> Expr raise XlsxError {
  self.skip_spaces()
  match self.peek() {
    Some('+') => {
      self.consume()
      Expr::Unary(UnaryOp::Plus, self.parse_unary())
    }
    Some('-') => {
      self.consume()
      Expr::Unary(UnaryOp::Minus, self.parse_unary())
    }
    _ => self.parse_postfix()
  }
}

///|
fn FormulaParser::parse_postfix(self : FormulaParser) -> Expr raise XlsxError {
  let mut expr = self.parse_primary()
  self.skip_spaces()
  while self.peek() == Some('%') {
    self.consume()
    expr = Expr::Unary(UnaryOp::Percent, expr)
    self.skip_spaces()
  }
  expr
}

///|
fn FormulaParser::parse_primary(self : FormulaParser) -> Expr raise XlsxError {
  self.skip_spaces()
  match self.peek() {
    Some('\'') => self.parse_quoted_sheet_ref()
    Some('(') => {
      self.consume()
      let expr = self.parse_expression()
      self.skip_spaces()
      match self.advance() {
        Some(')') => expr
        _ => raise XlsxError::InvalidXml(msg="formula missing )")
      }
    }
    Some('"') => self.parse_string()
    Some('{') => self.parse_list()
    Some(ch) =>
      if ch.is_ascii_digit() {
        if self.is_row_range_start() {
          self.parse_row_range()
        } else {
          self.parse_number()
        }
      } else if ch == '.' {
        self.parse_number()
      } else {
        self.parse_identifier_expr()
      }
    None => raise XlsxError::InvalidXml(msg="formula empty")
  }
}

///|
fn FormulaParser::parse_quoted_sheet_ref(
  self : FormulaParser,
) -> Expr raise XlsxError {
  let sheet = self.parse_quoted_sheet_name()
  self.skip_spaces()
  if self.peek() != Some('!') {
    raise XlsxError::InvalidXml(msg="formula sheet reference missing !")
  }
  self.consume()
  let cell_token = self.parse_identifier_token()
  if self.peek() == Some(':') {
    self.consume()
    let (start_ref, _start_end) = parse_range_ref_token(cell_token)
    let end_token = self.parse_identifier_token()
    let (_end_start, end_ref) = parse_range_ref_token(end_token)
    return Expr::Range(sheet, start_ref, end_ref)
  }
  let cell_ref = match parse_cell_ref_token(cell_token) {
    Some(value) => value
    None => raise XlsxError::InvalidCellRef(value=cell_token)
  }
  Expr::Cell(sheet, cell_ref)
}

///|
fn FormulaParser::parse_quoted_sheet_name(
  self : FormulaParser,
) -> String raise XlsxError {
  self.consume()
  let sb = StringBuilder::new()
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    self.consume()
    if ch == '\'' {
      if self.peek() == Some('\'') {
        sb.write_char('\'')
        self.consume()
      } else {
        return sb.to_string()
      }
    } else {
      sb.write_char(ch)
    }
  }
  raise XlsxError::InvalidXml(msg="formula sheet name not closed")
}

///|
fn FormulaParser::parse_string(self : FormulaParser) -> Expr {
  self.consume()
  let sb = StringBuilder::new()
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    self.consume()
    if ch == '"' {
      match self.peek() {
        Some('"') => {
          sb.write_char('"')
          self.consume()
        }
        _ => break
      }
    } else {
      sb.write_char(ch)
    }
  }
  Expr::String(sb.to_string())
}

///|
fn FormulaParser::parse_list(self : FormulaParser) -> Expr raise XlsxError {
  self.consume()
  let items : Array[Expr] = []
  while true {
    self.skip_spaces()
    if self.peek() == Some('}') {
      self.consume()
      break
    }
    let value = self.parse_expression()
    items.push(value)
    self.skip_spaces()
    match self.peek() {
      Some(',') | Some(';') => self.consume()
      Some('}') => {
        self.consume()
        break
      }
      _ => raise XlsxError::InvalidXml(msg="formula list invalid")
    }
  }
  Expr::List(items)
}

///|
fn FormulaParser::parse_number(self : FormulaParser) -> Expr raise XlsxError {
  let sb = StringBuilder::new()
  let mut seen_dot = false
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch.is_ascii_digit() {
      sb.write_char(ch)
      self.consume()
      continue
    }
    if ch == '.' && !seen_dot {
      seen_dot = true
      sb.write_char(ch)
      self.consume()
      continue
    }
    if ch == 'e' || ch == 'E' {
      sb.write_char(ch)
      self.consume()
      match self.peek() {
        Some('+') | Some('-') => sb.write_char(self.advance().unwrap_or('+'))
        _ => ()
      }
      continue
    }
    break
  }
  let text = sb.to_string()
  let value = @strconv.parse_double(text) catch {
    _ => raise XlsxError::InvalidXml(msg="formula number invalid")
  }
  Expr::Number(value)
}

///|
fn FormulaParser::parse_identifier_expr(
  self : FormulaParser,
) -> Expr raise XlsxError {
  let ident = self.parse_identifier_token()
  let upper = ident.to_upper()
  self.skip_spaces()
  if self.peek() == Some('!') {
    self.consume()
    let cell_token = self.parse_identifier_token()
    if self.peek() == Some(':') {
      self.consume()
      let (start_ref, _start_end) = parse_range_ref_token(cell_token)
      let end_token = self.parse_identifier_token()
      let (_end_start, end_ref) = parse_range_ref_token(end_token)
      return Expr::Range(ident, start_ref, end_ref)
    }
    let cell_ref = match parse_cell_ref_token(cell_token) {
      Some(value) => value
      None => raise XlsxError::InvalidCellRef(value=cell_token)
    }
    return Expr::Cell(ident, cell_ref)
  }
  if self.peek() == Some('(') {
    self.consume()
    let args : Array[Expr] = []
    self.skip_spaces()
    if self.peek() == Some(')') {
      self.consume()
    } else {
      while true {
        args.push(self.parse_expression())
        self.skip_spaces()
        match self.peek() {
          Some(',') => self.consume()
          Some(')') => {
            self.consume()
            break
          }
          _ => raise XlsxError::InvalidXml(msg="formula args invalid")
        }
      }
    }
    return Expr::FuncCall(upper, args)
  }
  if self.peek() == Some(':') {
    self.consume()
    let (start_ref, _start_end) = parse_range_ref_token(ident)
    let end_token = self.parse_identifier_token()
    let (_end_start, end_ref) = parse_range_ref_token(end_token)
    return Expr::Range("", start_ref, end_ref)
  }
  match parse_cell_ref_token(ident) {
    Some(value) =>
      if self.peek() == Some(':') {
        self.consume()
        let (start_ref, _start_end) = parse_range_ref_token(value)
        let end_token = self.parse_identifier_token()
        let (_end_start, end_ref) = parse_range_ref_token(end_token)
        Expr::Range("", start_ref, end_ref)
      } else {
        Expr::Cell("", value)
      }
    None =>
      match upper {
        "TRUE" => Expr::Bool(true)
        "FALSE" => Expr::Bool(false)
        _ => Expr::FuncCall(upper, [])
      }
  }
}

///|
fn FormulaParser::parse_identifier_token(self : FormulaParser) -> String {
  let sb = StringBuilder::new()
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch.is_ascii_alphabetic() ||
      ch.is_ascii_digit() ||
      ch == '_' ||
      ch == '.' ||
      ch == '$' {
      sb.write_char(ch)
      self.consume()
    } else {
      break
    }
  }
  sb.to_string()
}

///|
fn FormulaParser::parse_row_token(self : FormulaParser) -> String {
  let sb = StringBuilder::new()
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch.is_ascii_digit() {
      sb.write_char(ch)
      self.consume()
    } else {
      break
    }
  }
  sb.to_string()
}

///|
fn FormulaParser::is_row_range_start(self : FormulaParser) -> Bool {
  let mut idx = self.pos
  let mut saw_digit = false
  while idx < self.chars.length() {
    let ch = self.chars[idx]
    if ch.is_ascii_digit() {
      saw_digit = true
      idx = idx + 1
      continue
    }
    break
  }
  if !saw_digit {
    return false
  }
  while idx < self.chars.length() {
    let ch = self.chars[idx]
    if ch.is_ascii_whitespace() {
      idx = idx + 1
      continue
    }
    return ch == ':'
  }
  false
}

///|
fn FormulaParser::parse_row_range(self : FormulaParser) -> Expr raise XlsxError {
  let start_token = self.parse_row_token()
  if start_token == "" {
    raise XlsxError::InvalidXml(msg="formula row range invalid")
  }
  self.skip_spaces()
  if self.peek() != Some(':') {
    raise XlsxError::InvalidXml(msg="formula row range invalid")
  }
  self.consume()
  self.skip_spaces()
  let end_token = self.parse_row_token()
  if end_token == "" {
    raise XlsxError::InvalidXml(msg="formula row range invalid")
  }
  let (start_ref, _start_end) = parse_range_ref_token(start_token)
  let (_end_start, end_ref) = parse_range_ref_token(end_token)
  Expr::Range("", start_ref, end_ref)
}

///|
fn parse_cell_ref_token(token : StringView) -> String? {
  let col_sb = StringBuilder::new()
  let row_sb = StringBuilder::new()
  let mut seen_digit = false
  for ch in token {
    if ch == '$' {
      continue
    }
    if !seen_digit && ch.is_ascii_alphabetic() {
      col_sb.write_char(ch.to_ascii_uppercase())
    } else if ch.is_ascii_digit() {
      seen_digit = true
      row_sb.write_char(ch)
    } else {
      return None
    }
  }
  let col = col_sb.to_string()
  let row = row_sb.to_string()
  if col == "" || row == "" {
    return None
  }
  Some("\{col}\{row}")
}

///|
fn parse_range_ref_token(
  token : StringView,
) -> (String, String) raise XlsxError {
  match parse_cell_ref_token(token) {
    Some(value) => return (value, value)
    None => ()
  }
  let col_sb = StringBuilder::new()
  let row_sb = StringBuilder::new()
  for ch in token {
    if ch == '$' {
      continue
    }
    if ch.is_ascii_alphabetic() {
      col_sb.write_char(ch.to_ascii_uppercase())
    } else if ch.is_ascii_digit() {
      row_sb.write_char(ch)
    } else {
      raise XlsxError::InvalidCellRef(value=token.to_string())
    }
  }
  let col = col_sb.to_string()
  let row = row_sb.to_string()
  if col != "" && row == "" {
    let col_index = column_name_to_number(col) catch {
      _ => raise XlsxError::InvalidCellRef(value=token.to_string())
    }
    if col_index <= 0 || col_index > excel_max_cols {
      raise XlsxError::InvalidCellRef(value=token.to_string())
    }
    let start_ref = cell_ref_from(1, col_index)
    let end_ref = cell_ref_from(excel_max_rows, col_index)
    return (start_ref, end_ref)
  }
  if row != "" && col == "" {
    let row_index = @strconv.parse_int(row, base=10) catch {
      _ => raise XlsxError::InvalidCellRef(value=token.to_string())
    }
    if row_index <= 0 || row_index > excel_max_rows {
      raise XlsxError::InvalidCellRef(value=token.to_string())
    }
    let start_ref = cell_ref_from(row_index, 1)
    let end_ref = cell_ref_from(row_index, excel_max_cols)
    return (start_ref, end_ref)
  }
  raise XlsxError::InvalidCellRef(value=token.to_string())
}

///|

///|
fn address_a1(row : Int, col : Int, abs_num : Int) -> String raise XlsxError {
  let col_name = column_name_from_number(col)
  match abs_num {
    1 => "$\{col_name}$\{row}"
    2 => "\{col_name}$\{row}"
    3 => "$\{col_name}\{row}"
    4 => "\{col_name}\{row}"
    _ => raise XlsxError::InvalidCellRef(value="address")
  }
}

///|
fn address_r1c1(row : Int, col : Int, abs_num : Int) -> String {
  match abs_num {
    1 => "R\{row}C\{col}"
    2 => "R\{row}C[\{col}]"
    3 => "R[\{row}]C\{col}"
    4 => "R[\{row}]C[\{col}]"
    _ => "R\{row}C\{col}"
  }
}

///|
fn parse_r1c1_token(text : StringView) -> (Int, Int)? {
  let chars = text.to_array()
  if chars.length() < 3 || chars[0] != 'R' {
    return None
  }
  let row_sb = StringBuilder::new()
  let mut idx = 1
  while idx < chars.length() && chars[idx].is_ascii_digit() {
    row_sb.write_char(chars[idx])
    idx = idx + 1
  }
  let row_text = row_sb.to_string()
  if row_text == "" {
    return None
  }
  if idx >= chars.length() || chars[idx] != 'C' {
    return None
  }
  idx = idx + 1
  let col_sb = StringBuilder::new()
  while idx < chars.length() && chars[idx].is_ascii_digit() {
    col_sb.write_char(chars[idx])
    idx = idx + 1
  }
  let col_text = col_sb.to_string()
  if col_text == "" || idx != chars.length() {
    return None
  }
  let row = @strconv.parse_int(row_text, base=10) catch { _ => return None }
  let col = @strconv.parse_int(col_text, base=10) catch { _ => return None }
  Some((row, col))
}

///|
fn unquote_sheet_name(text : String) -> String {
  if text.length() < 2 {
    return text
  }
  if !text.has_prefix("'") || !text.has_suffix("'") {
    return text
  }
  let inner = text.unsafe_substring(start=1, end=text.length() - 1)
  let sb = StringBuilder::new()
  let chars = inner.to_array()
  let mut idx = 0
  while idx < chars.length() {
    let ch = chars[idx]
    if ch == '\'' && idx + 1 < chars.length() && chars[idx + 1] == '\'' {
      sb.write_char('\'')
      idx = idx + 2
    } else {
      sb.write_char(ch)
      idx = idx + 1
    }
  }
  sb.to_string()
}

///|
fn split_sheet_ref(text : String) -> (String, String) {
  match text.rev_find("!") {
    Some(idx) => {
      let sheet = text.unsafe_substring(start=0, end=idx)
      let ref_text = text.unsafe_substring(start=idx + 1, end=text.length())
      (unquote_sheet_name(sheet), ref_text)
    }
    None => ("", text)
  }
}

///|
fn ref_bounds_opt(expr : Expr) -> (Int, Int, Int, Int)? raise XlsxError {
  match expr {
    Expr::Cell(_, reference) => {
      let (row, col) = cell_ref_to_rc(reference)
      Some((row, col, row, col))
    }
    Expr::Range(_, start_ref, end_ref) => {
      let (row1, col1) = cell_ref_to_rc(start_ref)
      let (row2, col2) = cell_ref_to_rc(end_ref)
      Some((row1, col1, row2, col2))
    }
    _ => None
  }
}

///|
fn current_cell_rc(ctx : CalcContext) -> (Int, Int)? raise XlsxError {
  if ctx.current_ref == "" {
    None
  } else {
    Some(cell_ref_to_rc(ctx.current_ref))
  }
}

///|
fn formula_text_value(
  workbook : Workbook,
  sheet_name : String,
  expr : Expr,
) -> FormulaValue raise XlsxError {
  let (target_sheet, reference) = match expr {
    Expr::Cell(sheet, reference) =>
      if sheet == "" {
        (sheet_name, reference)
      } else {
        (sheet, reference)
      }
    Expr::Range(sheet, start_ref, _) =>
      if sheet == "" {
        (sheet_name, start_ref)
      } else {
        (sheet, start_ref)
      }
    _ => return FormulaValue::Error(formula_error_value)
  }
  let sheet = match workbook.sheet(target_sheet) {
    Some(value) => value
    None => return FormulaValue::Error(formula_error_value)
  }
  let formula = sheet.get_cell_formula(reference) catch {
    _ => return FormulaValue::Error(formula_error_value)
  }
  let text = match formula {
    Some(value) => value
    None => ""
  }
  FormulaValue::String(text)
}

///|
fn range_vector(range : RangeValues) -> Array[FormulaValue]? {
  if range.rows == 1 {
    let out : Array[FormulaValue] = []
    for col in 0..<range.cols {
      out.push(range.values[col])
    }
    Some(out)
  } else if range.cols == 1 {
    let out : Array[FormulaValue] = []
    for row in 0..<range.rows {
      out.push(range.values[row * range.cols])
    }
    Some(out)
  } else {
    None
  }
}

///|
fn range_column(range : RangeValues, index : Int) -> Array[FormulaValue]? {
  if index < 0 || index >= range.cols {
    return None
  }
  let out : Array[FormulaValue] = []
  for row in 0..<range.rows {
    out.push(range.values[row * range.cols + index])
  }
  Some(out)
}

///|
fn range_row(range : RangeValues, index : Int) -> Array[FormulaValue]? {
  if index < 0 || index >= range.rows {
    return None
  }
  let out : Array[FormulaValue] = []
  let offset = index * range.cols
  for col in 0..<range.cols {
    out.push(range.values[offset + col])
  }
  Some(out)
}

///|
fn transpose_range_values(range : RangeValues) -> RangeValues {
  let out : Array[FormulaValue] = []
  for col in 0..<range.cols {
    for row in 0..<range.rows {
      out.push(range.values[row * range.cols + col])
    }
  }
  { values: out, rows: range.cols, cols: range.rows }
}

///|
fn is_munit_func(name : String) -> Bool {
  name == "MUNIT" || name == "_XLFN.MUNIT"
}

///|
fn munit_dimension(value : FormulaValue) -> Result[Int, FormulaValue] {
  match value_as_number(value) {
    Ok(num) =>
      if num < 0.0 {
        Err(FormulaValue::Error(formula_error_value))
      } else {
        Ok(Double::to_int(trunc_double(num)))
      }
    Err(err) => Err(err)
  }
}

///|
fn munit_range_values(dimension : Int) -> RangeValues {
  let out : Array[FormulaValue] = []
  for row in 0..<dimension {
    for col in 0..<dimension {
      let value = if row == col { 1.0 } else { 0.0 }
      out.push(FormulaValue::Number(value))
    }
  }
  { values: out, rows: dimension, cols: dimension }
}

///|
fn munit_range_values_from_expr(
  workbook : Workbook,
  sheet_name : String,
  args : Array[Expr],
  ctx : CalcContext,
) -> RangeValues raise XlsxError {
  if args.length() != 1 {
    return {
      values: [FormulaValue::Error(formula_error_value)],
      rows: 1,
      cols: 1,
    }
  }
  let dimension_value = eval_expr(workbook, sheet_name, args[0], ctx)
  match munit_dimension(dimension_value) {
    Ok(dimension) => munit_range_values(dimension)
    Err(err) => { values: [err], rows: 1, cols: 1 }
  }
}

///|
fn transpose_range_values_from_expr(
  workbook : Workbook,
  sheet_name : String,
  args : Array[Expr],
  ctx : CalcContext,
) -> RangeValues raise XlsxError {
  if args.length() != 1 {
    return {
      values: [FormulaValue::Error(formula_error_value)],
      rows: 1,
      cols: 1,
    }
  }
  let arg_expr = args[0]
  let arg_value = eval_expr(workbook, sheet_name, arg_expr, ctx)
  let base_range = range_from_expr_or_value(
    workbook, sheet_name, arg_expr, arg_value, ctx,
  )
  transpose_range_values(base_range)
}

///|
fn number_matrix_from_range(
  range : RangeValues,
  require_square : Bool,
) -> Result[Array[Array[Double]], FormulaValue] {
  if range.rows <= 0 || range.cols <= 0 {
    return Err(FormulaValue::Error(formula_error_value))
  }
  if require_square && range.rows != range.cols {
    return Err(FormulaValue::Error(formula_error_value))
  }
  let out : Array[Array[Double]] = []
  for row in 0..<range.rows {
    let row_values : Array[Double] = []
    let offset = row * range.cols
    for col in 0..<range.cols {
      let value = range.values[offset + col]
      match value {
        FormulaValue::Number(num) => row_values.push(num)
        FormulaValue::Bool(flag) =>
          row_values.push(if flag { 1.0 } else { 0.0 })
        _ => return Err(FormulaValue::Error(formula_error_value))
      }
    }
    out.push(row_values)
  }
  Ok(out)
}

///|
fn matrix_minor(
  matrix : Array[Array[Double]],
  index : Int,
) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  for row in 0..<matrix.length() {
    if row == 0 {
      continue
    }
    let values : Array[Double] = []
    for col in 0..<matrix[row].length() {
      if col == index {
        continue
      }
      values.push(matrix[row][col])
    }
    out.push(values)
  }
  out
}

///|
fn matrix_det(matrix : Array[Array[Double]]) -> Double {
  if matrix.length() == 2 {
    let m00 = matrix[0][0]
    let m01 = matrix[0][1]
    let m10 = matrix[1][0]
    let m11 = matrix[1][1]
    return m00 * m11 - m10 * m01
  }
  let mut result = 0.0
  let mut sign = 1.0
  for col in 0..<matrix.length() {
    result = result +
      sign * matrix[0][col] * matrix_det(matrix_minor(matrix, col))
    sign = sign * -1.0
  }
  result
}

///|
fn matrix_minor_at(
  matrix : Array[Array[Double]],
  remove_row : Int,
  remove_col : Int,
) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  for row in 0..<matrix.length() {
    if row == remove_row {
      continue
    }
    let values : Array[Double] = []
    for col in 0..<matrix[row].length() {
      if col == remove_col {
        continue
      }
      values.push(matrix[row][col])
    }
    out.push(values)
  }
  out
}

///|
fn matrix_cofactor(
  matrix : Array[Array[Double]],
  row : Int,
  col : Int,
) -> Double {
  let sign = if (row + col) % 2 == 0 { 1.0 } else { -1.0 }
  sign * matrix_det(matrix_minor_at(matrix, row, col))
}

///|
fn matrix_adjugate(matrix : Array[Array[Double]]) -> Array[Array[Double]] {
  let size = matrix.length()
  let out : Array[Array[Double]] = []
  for _ in 0..<size {
    out.push(Array::make(size, 0.0))
  }
  for row in 0..<size {
    for col in 0..<size {
      out[row][col] = matrix_cofactor(matrix, col, row)
    }
  }
  out
}

///|
fn matrix_values(matrix : Array[Array[Double]]) -> Array[FormulaValue] {
  let out : Array[FormulaValue] = []
  for row in 0..<matrix.length() {
    for col in 0..<matrix[row].length() {
      out.push(FormulaValue::Number(matrix[row][col]))
    }
  }
  out
}

///|
fn matrix_multiply(
  left : Array[Array[Double]],
  right : Array[Array[Double]],
) -> Result[Array[Array[Double]], FormulaValue] {
  let rows = left.length()
  let cols = left[0].length()
  let right_rows = right.length()
  let right_cols = right[0].length()
  if cols != right_rows {
    return Err(FormulaValue::Error(formula_error_value))
  }
  let out : Array[Array[Double]] = []
  for row in 0..<rows {
    let values = Array::make(right_cols, 0.0)
    for col in 0..<right_cols {
      let mut sum = 0.0
      for idx in 0..<right_rows {
        sum = sum + left[row][idx] * right[idx][col]
      }
      values[col] = sum
    }
    out.push(values)
  }
  Ok(out)
}

///|
fn new_matrix(cols : Int, rows : Int) -> Array[Array[Double]] {
  if cols <= 0 || rows <= 0 {
    return []
  }
  let out : Array[Array[Double]] = []
  for _ in 0..<cols {
    out.push(Array::make(rows, 0.0))
  }
  out
}

///|
fn approx_sub(a : Double, b : Double) -> Double {
  if ((a < 0.0 && b < 0.0) || (a > 0.0 && b > 0.0)) &&
    Double::abs(a - b) < 2.22045e-016 {
    0.0
  } else {
    a - b
  }
}

///|
fn matrix_clone(matrix : Array[Array[Double]]) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  for col in 0..<matrix.length() {
    let column = matrix[col]
    let copy = Array::make(column.length(), 0.0)
    for row in 0..<column.length() {
      copy[row] = column[row]
    }
    out.push(copy)
  }
  out
}

///|
fn transpose_number_matrix(
  matrix : Array[Array[Double]],
) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  for row in 0..<matrix.length() {
    for col in 0..<matrix[row].length() {
      while out.length() <= col {
        out.push([])
      }
      let column = out[col]
      while column.length() <= row {
        column.push(0.0)
      }
      column[row] = matrix[row][col]
    }
  }
  out
}

///|
priv struct TrendGrowthMatrixInfo {
  trend_type : Int
  n_cx : Int
  n_cy : Int
  n_rx : Int
  n_ry : Int
  m : Int
  n : Int
  mtx_x : Array[Array[Double]]
  mtx_y : Array[Array[Double]]
}

///|
fn prepare_trend_growth_mtx_x(
  mtx_x : Array[Array[Double]],
) -> Result[Array[Array[Double]], FormulaValue] {
  let out : Array[Array[Double]] = []
  for row in 0..<mtx_x.length() {
    for col in 0..<mtx_x[row].length() {
      let value = mtx_x[row][col]
      if value == 0.0 {
        return Err(FormulaValue::Error(formula_error_num))
      }
      while out.length() <= col {
        out.push([])
      }
      let column = out[col]
      while column.length() <= row {
        column.push(0.0)
      }
      column[row] = value
    }
  }
  Ok(out)
}

///|
fn prepare_trend_growth_mtx_y(
  b_log : Bool,
  mtx_y : Array[Array[Double]],
) -> Result[Array[Array[Double]], FormulaValue] {
  let out : Array[Array[Double]] = []
  for row in 0..<mtx_y.length() {
    for col in 0..<mtx_y[row].length() {
      let value = mtx_y[row][col]
      if value == 0.0 {
        return Err(FormulaValue::Error(formula_error_num))
      }
      while out.length() <= col {
        out.push([])
      }
      let column = out[col]
      while column.length() <= row {
        column.push(0.0)
      }
      column[row] = value
    }
  }
  if !b_log {
    return Ok(out)
  }
  let log_out : Array[Array[Double]] = []
  for row in 0..<mtx_y.length() {
    for col in 0..<mtx_y[row].length() {
      let value = mtx_y[row][col]
      if value <= 0.0 {
        return Err(FormulaValue::Error(formula_error_num))
      }
      while log_out.length() <= col {
        log_out.push([])
      }
      let column = log_out[col]
      while column.length() <= row {
        column.push(0.0)
      }
      column[row] = @math.ln(value)
    }
  }
  Ok(log_out)
}

///|
fn prepare_trend_growth(
  b_log : Bool,
  mtx_x : Array[Array[Double]],
  mtx_y : Array[Array[Double]],
) -> Result[TrendGrowthMatrixInfo, FormulaValue] {
  let n_ry = mtx_y.length()
  let n_cy = mtx_y[0].length()
  let cnt_y = n_cy * n_ry
  let new_y = match prepare_trend_growth_mtx_y(b_log, mtx_y) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let mut new_x : Array[Array[Double]] = []
  let mut n_rx = 0
  let mut n_cx = 0
  let mut trend_type = 0
  let mut m = 0
  let mut n = 0
  if mtx_x.length() != 0 {
    n_rx = mtx_x.length()
    n_cx = mtx_x[0].length()
    new_x = match prepare_trend_growth_mtx_x(mtx_x) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    if n_cx == n_cy && n_rx == n_ry {
      trend_type = 1
      m = 1
      n = cnt_y
    } else if n_cy != 1 && n_ry != 1 {
      return Err(FormulaValue::Error(formula_error_ref))
    } else if n_cy == 1 {
      if n_rx != n_ry {
        return Err(FormulaValue::Error(formula_error_ref))
      }
      trend_type = 2
      m = n_cx
      n = n_ry
    } else if n_cx != n_cy {
      return Err(FormulaValue::Error(formula_error_ref))
    } else {
      trend_type = 3
      m = n_rx
      n = n_cy
    }
  } else {
    new_x = new_matrix(n_cy, n_ry)
    n_cx = n_cy
    n_rx = n_ry
    let mut value = 1.0
    for row in 0..<n_ry {
      for col in 0..<n_cy {
        new_x[col][row] = value
        value = value + 1.0
      }
    }
    trend_type = 1
    m = 1
    n = cnt_y
  }
  Ok(TrendGrowthMatrixInfo::{
    trend_type,
    n_cx,
    n_cy,
    n_rx,
    n_ry,
    m,
    n,
    mtx_x: new_x,
    mtx_y: new_y,
  })
}

///|
fn calc_position(mtx : Array[Array[Double]], idx : Int) -> (Int, Int) {
  let row_size = mtx[0].length()
  let col = if row_size > 1 { idx / row_size } else { idx }
  let row = idx - col * row_size
  (row, col)
}

///|
fn get_double(mtx : Array[Array[Double]], idx : Int) -> Double {
  let (row, col) = calc_position(mtx, idx)
  mtx[col][row]
}

///|
fn put_double(mtx : Array[Array[Double]], idx : Int, value : Double) -> Unit {
  let (row, col) = calc_position(mtx, idx)
  mtx[col][row] = value
}

///|
fn calc_mean_over_all(mtx : Array[Array[Double]], n : Int) -> Double {
  let mut sum = 0.0
  for col in 0..<mtx.length() {
    for row in 0..<mtx[col].length() {
      sum = sum + mtx[col][row]
    }
  }
  sum / Double::from_int(n)
}

///|
fn calc_sum_product(
  mtx_a : Array[Array[Double]],
  mtx_b : Array[Array[Double]],
  m : Int,
) -> Double {
  let mut sum = 0.0
  for idx in 0..<m {
    sum = sum + get_double(mtx_a, idx) * get_double(mtx_b, idx)
  }
  sum
}

///|
fn calc_column_means(
  mtx_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
  c : Int,
  r : Int,
) -> Unit {
  for i in 0..<c {
    let mut sum = 0.0
    for k in 0..<r {
      sum = sum + mtx_x[i][k]
    }
    put_double(mtx_res, i, sum / Double::from_int(r))
  }
}

///|
fn calc_columns_delta(
  mtx : Array[Array[Double]],
  column_means : Array[Array[Double]],
  c : Int,
  r : Int,
) -> Unit {
  for i in 0..<c {
    for k in 0..<r {
      mtx[i][k] = approx_sub(mtx[i][k], get_double(column_means, i))
    }
  }
}

///|
fn calc_sign(value : Double) -> Double {
  if value > 0.0 {
    1.0
  } else {
    -1.0
  }
}

///|
fn calc_cols_maximum_norm(
  mtx_a : Array[Array[Double]],
  c : Int,
  r : Int,
  n : Int,
) -> Double {
  let mut norm = 0.0
  for row in r..<n {
    let value = Double::abs(mtx_a[c][row])
    if norm < value {
      norm = value
    }
  }
  norm
}

///|
fn calc_fast_mult(
  mtx_a : Array[Array[Double]],
  mtx_b : Array[Array[Double]],
  mtx_r : Array[Array[Double]],
  n : Int,
  m : Int,
  l : Int,
) -> Unit {
  for row in 0..<n {
    for col in 0..<l {
      let mut sum = 0.0
      for k in 0..<m {
        sum = sum + mtx_a[k][row] * mtx_b[col][k]
      }
      mtx_r[col][row] = sum
    }
  }
}

///|
fn calc_rows_euclidean_norm(
  mtx_a : Array[Array[Double]],
  c : Int,
  r : Int,
  n : Int,
) -> Double {
  let mut norm = 0.0
  for row in r..<n {
    let value = mtx_a[c][row]
    norm = norm + value * value
  }
  Double::sqrt(norm)
}

///|
fn calc_rows_sum_product(
  mtx_a : Array[Array[Double]],
  a : Int,
  mtx_b : Array[Array[Double]],
  b : Int,
  r : Int,
  n : Int,
) -> Double {
  let mut result = 0.0
  for row in r..<n {
    result = result + mtx_a[a][row] * mtx_b[b][row]
  }
  result
}

///|
fn calc_solve_with_upper_right_triangle(
  mtx_a : Array[Array[Double]],
  vec_r : Array[Double],
  mtx_s : Array[Array[Double]],
  k : Int,
  b_is_transposed : Bool,
) -> Unit {
  for idx in 0..<k {
    let row_p1 = k - idx
    let row = row_p1 - 1
    let mut sum = get_double(mtx_s, row)
    for col in row_p1..<k {
      if b_is_transposed {
        sum = sum - mtx_a[row][col] * get_double(mtx_s, col)
      } else {
        sum = sum - mtx_a[col][row] * get_double(mtx_s, col)
      }
    }
    put_double(mtx_s, row, sum / vec_r[row])
  }
}

///|
fn calc_row_qr_decomposition(
  mtx_a : Array[Array[Double]],
  vec_r : Array[Double],
  k : Int,
  n : Int,
) -> Bool {
  for col in 0..<k {
    let scale = calc_cols_maximum_norm(mtx_a, col, col, n)
    if scale == 0.0 {
      return false
    }
    for row in col..<n {
      mtx_a[col][row] = mtx_a[col][row] / scale
    }
    let euclid = calc_rows_euclidean_norm(mtx_a, col, col, n)
    let factor = 1.0 / euclid / (euclid + Double::abs(mtx_a[col][col]))
    let signum = calc_sign(mtx_a[col][col])
    mtx_a[col][col] = mtx_a[col][col] + signum * euclid
    vec_r[col] = -signum * scale * euclid
    for c in (col + 1)..<k {
      let sum = calc_rows_sum_product(mtx_a, col, mtx_a, c, col, n)
      for row in col..<n {
        mtx_a[c][row] = mtx_a[c][row] - sum * factor * mtx_a[col][row]
      }
    }
  }
  true
}

///|
fn calc_apply_cols_householder_transformation(
  mtx_a : Array[Array[Double]],
  r : Int,
  mtx_y : Array[Array[Double]],
  n : Int,
) -> Unit {
  let denominator = calc_cols_sum_product(mtx_a, r, mtx_a, r, r, n)
  let numerator = calc_cols_sum_product(mtx_a, r, mtx_y, 0, r, n)
  let factor = 2.0 * (numerator / denominator)
  for col in r..<n {
    put_double(mtx_y, col, get_double(mtx_y, col) - factor * mtx_a[col][r])
  }
}

///|
fn calc_row_means(
  mtx_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
  c : Int,
  r : Int,
) -> Unit {
  for k in 0..<r {
    let mut sum = 0.0
    for i in 0..<c {
      sum = sum + mtx_x[i][k]
    }
    mtx_res[k][0] = sum / Double::from_int(c)
  }
}

///|
fn calc_rows_delta(
  mtx : Array[Array[Double]],
  row_means : Array[Array[Double]],
  c : Int,
  r : Int,
) -> Unit {
  for k in 0..<r {
    for i in 0..<c {
      mtx[i][k] = approx_sub(mtx[i][k], row_means[k][0])
    }
  }
}

///|
fn calc_column_maximum_norm(
  mtx_a : Array[Array[Double]],
  r : Int,
  c : Int,
  n : Int,
) -> Double {
  let mut norm = 0.0
  for col in c..<n {
    let value = Double::abs(mtx_a[col][r])
    if norm < value {
      norm = value
    }
  }
  norm
}

///|
fn calc_cols_euclidean_norm(
  mtx_a : Array[Array[Double]],
  r : Int,
  c : Int,
  n : Int,
) -> Double {
  let mut norm = 0.0
  for col in c..<n {
    let value = mtx_a[col][r]
    norm = norm + value * value
  }
  Double::sqrt(norm)
}

///|
fn calc_cols_sum_product(
  mtx_a : Array[Array[Double]],
  a : Int,
  mtx_b : Array[Array[Double]],
  b : Int,
  c : Int,
  n : Int,
) -> Double {
  let mut result = 0.0
  for col in c..<n {
    result = result + mtx_a[col][a] * mtx_b[col][b]
  }
  result
}

///|
fn calc_col_qr_decomposition(
  mtx_a : Array[Array[Double]],
  vec_r : Array[Double],
  k : Int,
  n : Int,
) -> Bool {
  for row in 0..<k {
    let scale = calc_column_maximum_norm(mtx_a, row, row, n)
    if scale == 0.0 {
      return false
    }
    for col in row..<n {
      mtx_a[col][row] = mtx_a[col][row] / scale
    }
    let euclid = calc_cols_euclidean_norm(mtx_a, row, row, n)
    let factor = 1.0 / euclid / (euclid + Double::abs(mtx_a[row][row]))
    let signum = calc_sign(mtx_a[row][row])
    mtx_a[row][row] = mtx_a[row][row] + signum * euclid
    vec_r[row] = -signum * scale * euclid
    for r in (row + 1)..<k {
      let sum = calc_cols_sum_product(mtx_a, row, mtx_a, r, row, n)
      for col in row..<n {
        mtx_a[col][r] = mtx_a[col][r] - sum * factor * mtx_a[col][row]
      }
    }
  }
  true
}

///|
fn calc_apply_rows_householder_transformation(
  mtx_a : Array[Array[Double]],
  c : Int,
  mtx_y : Array[Array[Double]],
  n : Int,
) -> Unit {
  let denominator = calc_rows_sum_product(mtx_a, c, mtx_a, c, c, n)
  let numerator = calc_rows_sum_product(mtx_a, c, mtx_y, 0, c, n)
  let factor = 2.0 * (numerator / denominator)
  for row in c..<n {
    put_double(mtx_y, row, get_double(mtx_y, row) - factor * mtx_a[c][row])
  }
}

///|
fn calc_trend_growth_simple_regression(
  b_constant : Bool,
  b_growth : Bool,
  mtx_y : Array[Array[Double]],
  mtx_x : Array[Array[Double]],
  new_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
  mean_y : Double,
  n : Int,
) -> Unit {
  let mut mean_x = 0.0
  if b_constant {
    mean_x = calc_mean_over_all(mtx_x, n)
    for col in 0..<mtx_x.length() {
      for row in 0..<mtx_x[col].length() {
        mtx_x[col][row] = approx_sub(mtx_x[col][row], mean_x)
      }
    }
  }
  let sum_xy = calc_sum_product(mtx_x, mtx_y, n)
  let sum_x2 = calc_sum_product(mtx_x, mtx_x, n)
  let slope = sum_xy / sum_x2
  if b_constant {
    let intercept = mean_y - slope * mean_x
    for col in 0..<mtx_res.length() {
      for row in 0..<mtx_res[col].length() {
        let help = new_x[col][row] * slope + intercept
        mtx_res[col][row] = if b_growth { @math.exp(help) } else { help }
      }
    }
  } else {
    for col in 0..<mtx_res.length() {
      for row in 0..<mtx_res[col].length() {
        let help = new_x[col][row] * slope
        mtx_res[col][row] = if b_growth { @math.exp(help) } else { help }
      }
    }
  }
}

///|
fn calc_trend_growth_multiple_regression_part1(
  b_constant : Bool,
  b_growth : Bool,
  mtx_y : Array[Array[Double]],
  mtx_x : Array[Array[Double]],
  new_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
  mean_y : Double,
  r_xn : Int,
  k : Int,
  n : Int,
) -> Unit {
  let vec_r = Array::make(n, 0.0)
  let means = new_matrix(k, 1)
  let slopes = new_matrix(1, k)
  if means.length() == 0 || slopes.length() == 0 {
    return
  }
  if b_constant {
    calc_column_means(mtx_x, means, k, n)
    calc_columns_delta(mtx_x, means, k, n)
  }
  if !calc_row_qr_decomposition(mtx_x, vec_r, k, n) {
    return
  }
  let mut is_singular = false
  for row in 0..<k {
    if vec_r[row] == 0.0 {
      is_singular = true
    }
  }
  if is_singular {
    return
  }
  for col in 0..<k {
    calc_apply_rows_householder_transformation(mtx_x, col, mtx_y, n)
  }
  for col in 0..<k {
    put_double(slopes, col, get_double(mtx_y, col))
  }
  calc_solve_with_upper_right_triangle(mtx_x, vec_r, slopes, k, false)
  calc_fast_mult(new_x, slopes, mtx_res, r_xn, k, 1)
  if b_constant {
    let intercept = mean_y - calc_sum_product(means, slopes, k)
    for row in 0..<r_xn {
      mtx_res[0][row] = mtx_res[0][row] + intercept
    }
  }
  if b_growth {
    for idx in 0..<r_xn {
      put_double(mtx_res, idx, @math.exp(get_double(mtx_res, idx)))
    }
  }
}

///|
fn calc_trend_growth_multiple_regression_part2(
  b_constant : Bool,
  b_growth : Bool,
  mtx_y : Array[Array[Double]],
  mtx_x : Array[Array[Double]],
  new_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
  mean_y : Double,
  n_cxn : Int,
  k : Int,
  n : Int,
) -> Unit {
  let vec_r = Array::make(n, 0.0)
  let means = new_matrix(k, 1)
  let slopes = new_matrix(k, 1)
  if means.length() == 0 || slopes.length() == 0 {
    return
  }
  if b_constant {
    calc_row_means(mtx_x, means, n, k)
    calc_rows_delta(mtx_x, means, n, k)
  }
  if !calc_col_qr_decomposition(mtx_x, vec_r, k, n) {
    return
  }
  let mut is_singular = false
  for row in 0..<k {
    if vec_r[row] == 0.0 {
      is_singular = true
    }
  }
  if is_singular {
    return
  }
  for row in 0..<k {
    calc_apply_cols_householder_transformation(mtx_x, row, mtx_y, n)
  }
  for col in 0..<k {
    put_double(slopes, col, get_double(mtx_y, col))
  }
  calc_solve_with_upper_right_triangle(mtx_x, vec_r, slopes, k, true)
  calc_fast_mult(slopes, new_x, mtx_res, 1, k, n_cxn)
  if b_constant {
    let intercept = mean_y - calc_sum_product(means, slopes, k)
    for col in 0..<n_cxn {
      mtx_res[col][0] = mtx_res[col][0] + intercept
    }
  }
  if b_growth {
    for idx in 0..<n_cxn {
      put_double(mtx_res, idx, @math.exp(get_double(mtx_res, idx)))
    }
  }
}

///|
fn calc_trend_growth_regression(
  b_constant : Bool,
  b_growth : Bool,
  trend_type : Int,
  n_cxn : Int,
  n_rxn : Int,
  k : Int,
  n : Int,
  mtx_y : Array[Array[Double]],
  mtx_x : Array[Array[Double]],
  new_x : Array[Array[Double]],
  mtx_res : Array[Array[Double]],
) -> Unit {
  if mtx_res.length() == 0 {
    return
  }
  let mut mean_y = 0.0
  let mut work_x = mtx_x
  let mut work_y = mtx_y
  if b_constant {
    work_x = matrix_clone(mtx_x)
    work_y = matrix_clone(mtx_y)
    mean_y = calc_mean_over_all(work_y, n)
    for col in 0..<work_y.length() {
      for row in 0..<work_y[col].length() {
        work_y[col][row] = approx_sub(work_y[col][row], mean_y)
      }
    }
  }
  match trend_type {
    1 =>
      calc_trend_growth_simple_regression(
        b_constant, b_growth, work_y, work_x, new_x, mtx_res, mean_y, n,
      )
    2 =>
      calc_trend_growth_multiple_regression_part1(
        b_constant, b_growth, work_y, work_x, new_x, mtx_res, mean_y, n_rxn, k, n,
      )
    _ =>
      calc_trend_growth_multiple_regression_part2(
        b_constant, b_growth, work_y, work_x, new_x, mtx_res, mean_y, n_cxn, k, n,
      )
  }
}

///|
fn calc_trend_growth(
  mtx_y : Array[Array[Double]],
  mtx_x : Array[Array[Double]],
  new_x : Array[Array[Double]],
  b_constant : Bool,
  b_growth : Bool,
) -> Result[Array[Array[Double]], FormulaValue] {
  let info = match prepare_trend_growth(b_growth, mtx_x, mtx_y) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let trend_type = info.trend_type
  let mut n_cxn = info.n_cx
  let mut n_rxn = info.n_rx
  let k = info.m
  let n = info.n
  let work_x = info.mtx_x
  let work_y = info.mtx_y
  if (b_constant && n < k + 1) || (!b_constant && n < k) || n < 1 || k < 1 {
    return Ok([])
  }
  let mut work_new_x = new_x
  if work_new_x.length() == 0 {
    work_new_x = matrix_clone(work_x)
  } else {
    n_rxn = work_new_x[0].length()
    n_cxn = work_new_x.length()
    if (trend_type == 2 && k != n_cxn) || (trend_type == 3 && k != n_rxn) {
      return Ok([])
    }
  }
  let mtx_res = match trend_type {
    1 => new_matrix(n_cxn, n_rxn)
    2 => new_matrix(1, n_rxn)
    _ => new_matrix(n_cxn, 1)
  }
  calc_trend_growth_regression(
    b_constant, b_growth, trend_type, n_cxn, n_rxn, k, n, work_y, work_x, work_new_x,
    mtx_res,
  )
  Ok(mtx_res)
}

///|
fn unique_row_key(
  range : RangeValues,
  row : Int,
) -> Result[String, FormulaValue] {
  let sb = StringBuilder::new()
  let start = row * range.cols
  for col in 0..<range.cols {
    let value = range.values[start + col]
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return Err(FormulaValue::Error(err))
      _ => sb.write_view(formula_value_string(value))
    }
  }
  Ok(sb.to_string())
}

///|
fn unique_range_values(
  range : RangeValues,
  by_col : Bool,
  exactly_once : Bool,
) -> Result[RangeValues, FormulaValue] {
  let base = if by_col { transpose_range_values(range) } else { range }
  let counts : Map[String, Int] = {}
  for row in 0..<base.rows {
    let key = match unique_row_key(base, row) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    match counts.get(key) {
      Some(count) => counts[key] = count + 1
      None => counts[key] = 1
    }
  }
  let out : Array[FormulaValue] = []
  let mut kept_rows = 0
  for row in 0..<base.rows {
    let key = match unique_row_key(base, row) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let count = match counts.get(key) {
      Some(value) => value
      None => 0
    }
    let keep = if exactly_once { count == 1 } else { count >= 1 }
    if keep {
      let start = row * base.cols
      for col in 0..<base.cols {
        out.push(base.values[start + col])
      }
      kept_rows = kept_rows + 1
    }
    ignore(counts.remove(key))
  }
  let mut result = { values: out, rows: kept_rows, cols: base.cols }
  if by_col {
    result = transpose_range_values(result)
  }
  Ok(result)
}

///|
fn sequence_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 1 || values.length() > 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let rows = match value_as_int(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cols = if values.length() >= 2 {
    match value_as_int(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1
  }
  if rows <= 0 || cols <= 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let start = if values.length() >= 3 {
    match value_as_number(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1.0
  }
  let step = if values.length() == 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1.0
  }
  let out : Array[FormulaValue] = []
  for row in 0..<rows {
    for col in 0..<cols {
      let idx = row * cols + col
      let value = start + step * Double::from_int(idx)
      out.push(FormulaValue::Number(value))
    }
  }
  FormulaValue::List(out)
}

///|
fn randarray_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() > 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let rows = if values.length() >= 1 {
    match value_as_int(values[0]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1
  }
  let cols = if values.length() >= 2 {
    match value_as_int(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1
  }
  if rows <= 0 || cols <= 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let min = if values.length() >= 3 {
    match value_as_number(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let max = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1.0
  }
  let whole_number = if values.length() == 5 {
    match value_as_bool(values[4]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  } else {
    false
  }
  if min > max {
    return FormulaValue::Error(formula_error_value)
  }
  let out : Array[FormulaValue] = []
  if whole_number {
    let min_int = Double::to_int(trunc_double(min))
    let max_int = Double::to_int(trunc_double(max))
    if min_int > max_int {
      return FormulaValue::Error(formula_error_value)
    }
    let range = max_int - min_int + 1
    for _i in 0..<(rows * cols) {
      let rand_value = if range > 0 { rand_state.int(limit=range) } else { 0 }
      out.push(FormulaValue::Number(Double::from_int(rand_value + min_int)))
    }
  } else {
    let span = max - min
    for _i in 0..<(rows * cols) {
      let value = min + rand_state.double() * span
      out.push(FormulaValue::Number(value))
    }
  }
  FormulaValue::List(out)
}

///|
fn slice_range_values(
  range : RangeValues,
  row_start : Int,
  row_count : Int,
  col_start : Int,
  col_count : Int,
) -> Result[RangeValues, FormulaValue] {
  if row_count <= 0 || col_count <= 0 {
    return Err(FormulaValue::Error(formula_error_value))
  }
  if row_start < 0 || col_start < 0 {
    return Err(FormulaValue::Error(formula_error_value))
  }
  if row_start + row_count > range.rows || col_start + col_count > range.cols {
    return Err(FormulaValue::Error(formula_error_value))
  }
  let out : Array[FormulaValue] = []
  for row in 0..<row_count {
    let offset = (row_start + row) * range.cols + col_start
    for col in 0..<col_count {
      out.push(range.values[offset + col])
    }
  }
  Ok({ values: out, rows: row_count, cols: col_count })
}

///|
fn take_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 || values.length() > 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let rows_value = match value_as_int(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cols_value = if values.length() == 3 {
    match value_as_int(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let rows_count = if rows_value == 0 { range.rows } else { rows_value }
  let cols_count = if values.length() == 3 {
    if cols_value == 0 {
      range.cols
    } else {
      cols_value
    }
  } else {
    range.cols
  }
  if rows_count == 0 || cols_count == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let row_count = Double::abs(Double::from_int(rows_count)).to_int()
  let col_count = Double::abs(Double::from_int(cols_count)).to_int()
  if row_count > range.rows || col_count > range.cols {
    return FormulaValue::Error(formula_error_value)
  }
  let row_start = if rows_count > 0 { 0 } else { range.rows - row_count }
  let col_start = if cols_count > 0 { 0 } else { range.cols - col_count }
  match slice_range_values(range, row_start, row_count, col_start, col_count) {
    Ok(result) => FormulaValue::List(result.values)
    Err(err) => err
  }
}

///|
fn drop_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 || values.length() > 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let rows_value = match value_as_int(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cols_value = if values.length() == 3 {
    match value_as_int(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let drop_rows = Double::abs(Double::from_int(rows_value)).to_int()
  let drop_cols = Double::abs(Double::from_int(cols_value)).to_int()
  if drop_rows > range.rows || drop_cols > range.cols {
    return FormulaValue::Error(formula_error_value)
  }
  let row_start = if rows_value >= 0 { drop_rows } else { 0 }
  let col_start = if cols_value >= 0 { drop_cols } else { 0 }
  let row_count = range.rows - drop_rows
  let col_count = range.cols - drop_cols
  match slice_range_values(range, row_start, row_count, col_start, col_count) {
    Ok(result) => FormulaValue::List(result.values)
    Err(err) => err
  }
}

///|
fn flatten_range_values(
  range : RangeValues,
  scan_by_column : Bool,
  ignore : Int,
) -> Result[Array[FormulaValue], FormulaValue] {
  let out : Array[FormulaValue] = []
  let keep_value = fn(value : FormulaValue) -> Result[Bool, FormulaValue] {
    match normalize_scalar(value) {
      FormulaValue::Error(err) =>
        if ignore == 2 || ignore == 3 {
          Ok(false)
        } else {
          Err(FormulaValue::Error(err))
        }
      FormulaValue::Empty =>
        if ignore == 1 || ignore == 3 {
          Ok(false)
        } else {
          Ok(true)
        }
      _ => Ok(true)
    }
  }
  if scan_by_column {
    for col in 0..<range.cols {
      for row in 0..<range.rows {
        let value = range.values[row * range.cols + col]
        match keep_value(value) {
          Ok(true) => out.push(value)
          Ok(false) => ()
          Err(err) => return Err(err)
        }
      }
    }
  } else {
    for row in 0..<range.rows {
      let offset = row * range.cols
      for col in 0..<range.cols {
        let value = range.values[offset + col]
        match keep_value(value) {
          Ok(true) => out.push(value)
          Ok(false) => ()
          Err(err) => return Err(err)
        }
      }
    }
  }
  if out.length() == 0 {
    Err(FormulaValue::Error(formula_error_calc))
  } else {
    Ok(out)
  }
}

///|
fn choose_indices(
  values : ArrayView[FormulaValue],
  total : Int,
) -> Result[Array[Int], FormulaValue] {
  let out : Array[Int] = []
  for value in values {
    let idx = match value_as_int(value) {
      Ok(num) => num
      Err(err) => return Err(err)
    }
    if idx == 0 {
      return Err(FormulaValue::Error(formula_error_value))
    }
    let resolved = if idx > 0 { idx - 1 } else { total + idx }
    if resolved < 0 || resolved >= total {
      return Err(FormulaValue::Error(formula_error_value))
    }
    out.push(resolved)
  }
  if out.length() == 0 {
    Err(FormulaValue::Error(formula_error_value))
  } else {
    Ok(out)
  }
}

///|
fn stack_from_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
  horizontal : Bool,
) -> FormulaValue raise XlsxError {
  if values.length() == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let ranges : Array[RangeValues] = []
  let mut max_rows = 0
  let mut max_cols = 0
  for i in 0..<values.length() {
    let range = range_from_expr_or_value(
      workbook,
      sheet_name,
      args[i],
      values[i],
      ctx,
    )
    if range.rows > max_rows {
      max_rows = range.rows
    }
    if range.cols > max_cols {
      max_cols = range.cols
    }
    ranges.push(range)
  }
  let mut total_rows = if horizontal { max_rows } else { 0 }
  let mut total_cols = if horizontal { 0 } else { max_cols }
  for range in ranges {
    if horizontal {
      total_cols = total_cols + range.cols
    } else {
      total_rows = total_rows + range.rows
    }
  }
  if total_rows == 0 || total_cols == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let out : Array[FormulaValue] = Array::make(
    total_rows * total_cols,
    FormulaValue::Empty,
  )
  if horizontal {
    let mut col_offset = 0
    for range in ranges {
      for row in 0..<total_rows {
        for col in 0..<range.cols {
          let value = if row < range.rows {
            range.values[row * range.cols + col]
          } else {
            FormulaValue::Error(formula_error_na)
          }
          let idx = row * total_cols + col_offset + col
          out[idx] = value
        }
      }
      col_offset = col_offset + range.cols
    }
  } else {
    let mut row_offset = 0
    for range in ranges {
      for row in 0..<range.rows {
        let out_row = row_offset + row
        for col in 0..<total_cols {
          let value = if col < range.cols {
            range.values[row * range.cols + col]
          } else {
            FormulaValue::Error(formula_error_na)
          }
          let idx = out_row * total_cols + col
          out[idx] = value
        }
      }
      row_offset = row_offset + range.rows
    }
  }
  FormulaValue::List(out)
}

///|
fn choosecols_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let indices = match choose_indices(values.sub(start=1), range.cols) {
    Ok(list) => list
    Err(err) => return err
  }
  let out : Array[FormulaValue] = []
  for row in 0..<range.rows {
    let offset = row * range.cols
    for col in indices {
      out.push(range.values[offset + col])
    }
  }
  FormulaValue::List(out)
}

///|
fn chooserows_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let indices = match choose_indices(values.sub(start=1), range.rows) {
    Ok(list) => list
    Err(err) => return err
  }
  let out : Array[FormulaValue] = []
  for row in indices {
    let offset = row * range.cols
    for col in 0..<range.cols {
      out.push(range.values[offset + col])
    }
  }
  FormulaValue::List(out)
}

///|
fn expand_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 || values.length() > 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let rows = match value_as_int(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cols = if values.length() >= 3 {
    match value_as_int(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    range.cols
  }
  if rows < range.rows || cols < range.cols || rows <= 0 || cols <= 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let pad_value = if values.length() == 4 {
    match normalize_scalar(values[3]) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::List(_) => return FormulaValue::Error(formula_error_value)
      value => value
    }
  } else {
    FormulaValue::Error(formula_error_na)
  }
  let out : Array[FormulaValue] = Array::make(rows * cols, pad_value)
  for row in 0..<range.rows {
    let in_offset = row * range.cols
    let out_offset = row * cols
    for col in 0..<range.cols {
      out[out_offset + col] = range.values[in_offset + col]
    }
  }
  FormulaValue::List(out)
}

///|
fn wrap_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
  by_rows : Bool,
) -> FormulaValue raise XlsxError {
  if values.length() < 2 || values.length() > 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let vector = match range_vector(range) {
    Some(list) => list
    None => return FormulaValue::Error(formula_error_value)
  }
  let count = match value_as_int(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if count <= 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let pad_value = if values.length() == 3 {
    match normalize_scalar(values[2]) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::List(_) => return FormulaValue::Error(formula_error_value)
      value => value
    }
  } else {
    FormulaValue::Error(formula_error_na)
  }
  let total = vector.length()
  let rows = if by_rows {
    let full = (total + count - 1) / count
    full
  } else {
    count
  }
  let cols = if by_rows {
    count
  } else {
    let full = (total + count - 1) / count
    full
  }
  let out : Array[FormulaValue] = Array::make(rows * cols, pad_value)
  for i in 0..<total {
    let row = if by_rows { i / count } else { i % count }
    let col = if by_rows { i % count } else { i / count }
    out[row * cols + col] = vector[i]
  }
  FormulaValue::List(out)
}

///|
fn tocol_torow_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
  scan_by_column_default : Bool,
) -> FormulaValue raise XlsxError {
  if values.length() < 1 || values.length() > 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let ignore = if values.length() >= 2 {
    match value_as_int(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0
  }
  if ignore < 0 || ignore > 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let scan_by_column = if values.length() == 3 {
    match value_as_bool(values[2]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  } else {
    scan_by_column_default
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  match flatten_range_values(range, scan_by_column, ignore) {
    Ok(list) => FormulaValue::List(list)
    Err(err) => err
  }
}

///|
fn sort_range_values(
  range : RangeValues,
  sort_index : Int,
  sort_order : Int,
) -> Result[RangeValues, FormulaValue] {
  if sort_index < 1 || sort_index > range.cols {
    return Err(FormulaValue::Error(formula_error_value))
  }
  if sort_order != 1 && sort_order != -1 {
    return Err(FormulaValue::Error(formula_error_value))
  }
  let entries : Array[(Int, FormulaValue)] = []
  let key_col = sort_index - 1
  for row in 0..<range.rows {
    let key = match range.get(row, key_col) {
      Some(value) => value
      None => return Err(FormulaValue::Error(formula_error_value))
    }
    match key {
      FormulaValue::Error(err) => return Err(FormulaValue::Error(err))
      _ => entries.push((row, key))
    }
  }
  entries.sort_by((left, right) => {
    let (left_idx, left_key) = left
    let (right_idx, right_key) = right
    let cmp = match compare_values(left_key, right_key) {
      Ok(value) => value
      Err(_) => 0
    }
    if cmp == 0 {
      left_idx - right_idx
    } else {
      sort_order * cmp
    }
  })
  let out : Array[FormulaValue] = []
  for entry in entries {
    let (row, _) = entry
    let offset = row * range.cols
    for col in 0..<range.cols {
      out.push(range.values[offset + col])
    }
  }
  Ok({ values: out, rows: range.rows, cols: range.cols })
}

///|
fn sortby_vector(
  range : RangeValues,
  expected_len : Int,
) -> Result[Array[FormulaValue], FormulaValue] {
  let vector = match range_vector(range) {
    Some(list) => list
    None => return Err(FormulaValue::Error(formula_error_value))
  }
  if vector.length() != expected_len {
    return Err(FormulaValue::Error(formula_error_value))
  }
  for value in vector {
    match value {
      FormulaValue::Error(err) => return Err(FormulaValue::Error(err))
      _ => ()
    }
  }
  Ok(vector)
}

///|
fn sortby_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() < 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let sort_by_rows = range.rows > 1 || range.cols == 1
  let expected_len = if sort_by_rows { range.rows } else { range.cols }
  let key_sets : Array[(Array[FormulaValue], Int)] = []
  let mut idx = 1
  while idx < args.length() {
    let key_range = range_from_expr_or_value(
      workbook,
      sheet_name,
      args[idx],
      values[idx],
      ctx,
    )
    let key_vector = match sortby_vector(key_range, expected_len) {
      Ok(list) => list
      Err(err) => return err
    }
    let sort_order = if idx + 1 < values.length() {
      match value_as_int(values[idx + 1]) {
        Ok(num) => num
        Err(err) => return err
      }
    } else {
      1
    }
    if sort_order != 1 && sort_order != -1 {
      return FormulaValue::Error(formula_error_value)
    }
    key_sets.push((key_vector, sort_order))
    idx = idx + 2
  }
  if key_sets.length() == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let entries : Array[Int] = []
  for i in 0..<expected_len {
    entries.push(i)
  }
  entries.sort_by((left, right) => {
    let mut cmp = 0
    for item in key_sets {
      let (keys, order) = item
      let left_key = keys[left]
      let right_key = keys[right]
      let key_cmp = match compare_values(left_key, right_key) {
        Ok(value) => value
        Err(_) => 0
      }
      if key_cmp != 0 {
        cmp = order * key_cmp
        break
      }
    }
    if cmp == 0 {
      left - right
    } else {
      cmp
    }
  })
  let out : Array[FormulaValue] = []
  if sort_by_rows {
    for row in entries {
      let offset = row * range.cols
      for col in 0..<range.cols {
        out.push(range.values[offset + col])
      }
    }
    FormulaValue::List(out)
  } else {
    for col in entries {
      for row in 0..<range.rows {
        out.push(range.values[row * range.cols + col])
      }
    }
    FormulaValue::List(out)
  }
}

///|
fn sort_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() < 1 || args.length() > 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let sort_index = if values.length() >= 2 {
    match value_as_int(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1
  }
  let sort_order = if values.length() >= 3 {
    match value_as_int(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    1
  }
  let by_col = if values.length() == 4 {
    match value_as_bool(values[3]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  } else {
    false
  }
  if sort_index < 1 {
    return FormulaValue::Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let base = if by_col { transpose_range_values(range) } else { range }
  match sort_range_values(base, sort_index, sort_order) {
    Ok(sorted) => {
      let result = if by_col { transpose_range_values(sorted) } else { sorted }
      FormulaValue::List(result.values)
    }
    Err(err) => err
  }
}

///|
fn filter_range_values(
  range : RangeValues,
  mask : RangeValues,
  if_empty : FormulaValue?,
) -> FormulaValue {
  let values = match range_vector(range) {
    Some(list) => list
    None => return FormulaValue::Error(formula_error_value)
  }
  let include_values = match range_vector(mask) {
    Some(list) => list
    None => return FormulaValue::Error(formula_error_value)
  }
  if values.length() != include_values.length() {
    return FormulaValue::Error(formula_error_value)
  }
  let out : Array[FormulaValue] = []
  for i in 0..<values.length() {
    let keep = match value_as_bool(include_values[i]) {
      Ok(flag) => flag
      Err(err) => return err
    }
    if keep {
      out.push(values[i])
    }
  }
  if out.length() == 0 {
    match if_empty {
      Some(value) => value
      None => FormulaValue::Error(formula_error_calc)
    }
  } else {
    FormulaValue::List(out)
  }
}

///|
fn filter_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() < 2 || args.length() > 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let mask = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[1],
    values[1],
    ctx,
  )
  let if_empty = if args.length() == 3 { Some(values[2]) } else { None }
  filter_range_values(range, mask, if_empty)
}

///|
fn sorted_numbers_from_range(
  range : RangeValues,
) -> Result[Array[Double], FormulaValue] {
  let numbers : Array[Double] = []
  for col in 0..<range.cols {
    for row in 0..<range.rows {
      let value = range.values[row * range.cols + col]
      match normalize_scalar(value) {
        FormulaValue::Error(err) => return Err(FormulaValue::Error(err))
        FormulaValue::Number(num) => numbers.push(num)
        _ => ()
      }
    }
  }
  numbers.sort()
  Ok(numbers)
}

///|
fn frequency_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if args.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let data_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let bins_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[1],
    values[1],
    ctx,
  )
  let data = match sorted_numbers_from_range(data_range) {
    Ok(list) => list
    Err(err) => return err
  }
  let bins = match sorted_numbers_from_range(bins_range) {
    Ok(list) => list
    Err(err) => return err
  }
  let out : Array[FormulaValue] = []
  let mut idx = 0
  for bin in bins {
    let mut count = 0
    while idx < data.length() && data[idx] <= bin {
      count = count + 1
      idx = idx + 1
    }
    out.push(FormulaValue::Number(Double::from_int(count)))
  }
  out.push(FormulaValue::Number(Double::from_int(data.length() - idx)))
  if out.length() > 2 {
    let temp = out[1]
    out[1] = out[2]
    out[2] = temp
  }
  FormulaValue::List(out)
}

///|
fn range_from_expr_or_value(
  workbook : Workbook,
  sheet_name : String,
  expr : Expr,
  value : FormulaValue,
  ctx : CalcContext,
) -> RangeValues raise XlsxError {
  let range_from_value = fn(value : FormulaValue) -> RangeValues {
    match value {
      FormulaValue::List(list) =>
        if list.length() == 0 {
          { rows: 1, cols: 1, values: [FormulaValue::Empty] }
        } else {
          { rows: 1, cols: list.length(), values: list }
        }
      _ => { rows: 1, cols: 1, values: [value] }
    }
  }
  match expr {
    Expr::Range(_, _, _) | Expr::Cell(_, _) =>
      eval_range_expr(workbook, sheet_name, expr, ctx)
    Expr::FuncCall(name, args) =>
      if is_munit_func(name) {
        munit_range_values_from_expr(workbook, sheet_name, args, ctx)
      } else if name == "TRANSPOSE" {
        transpose_range_values_from_expr(workbook, sheet_name, args, ctx)
      } else {
        range_from_value(value)
      }
    _ => range_from_value(value)
  }
}

///|
fn formula_value_from_cell_value(value : CellValue) -> FormulaValue {
  match value {
    CellValue::Numeric(num) => FormulaValue::Number(num)
    CellValue::String(text) => FormulaValue::String(text)
    CellValue::Bool(value) => FormulaValue::Bool(value)
    CellValue::Error(text) => FormulaValue::Error(text)
  }
}

///|
fn formula_value_to_cell(value : FormulaValue) -> (CellValueType, String) {
  match value {
    FormulaValue::Number(num) => (CellValueType::Number, format_number(num))
    FormulaValue::String(text) => (CellValueType::String, text)
    FormulaValue::Bool(value) =>
      (CellValueType::Bool, if value { "1" } else { "0" })
    FormulaValue::Error(text) => (CellValueType::Error, text)
    FormulaValue::Empty => (CellValueType::String, "")
    FormulaValue::List(list) =>
      if list.length() > 0 {
        formula_value_to_cell(list[0])
      } else {
        (CellValueType::String, "")
      }
  }
}

///|
fn is_negative_zero(value : Double) -> Bool {
  if value != 0.0 {
    return false
  }
  let inv = 1.0 / value
  inv.is_inf() && inv < 0.0
}

///|
fn format_number(value : Double) -> String {
  if is_negative_zero(value) {
    return "-0"
  }
  let text = value.to_string()
  if text.contains("e") || text.contains("E") {
    return text
  }
  if !text.contains(".") {
    return text
  }
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && chars[end - 1] == '0' {
    end = end - 1
  }
  if end > 0 && chars[end - 1] == '.' {
    end = end - 1
  }
  let sb = StringBuilder::new()
  for i in 0..<end {
    sb.write_char(chars[i])
  }
  let trimmed = sb.to_string()
  if trimmed == "" {
    "0"
  } else {
    trimmed
  }
}

///|
fn formula_value_string(value : FormulaValue) -> String {
  match value {
    FormulaValue::String(text) => text
    FormulaValue::Number(num) => format_number(num)
    FormulaValue::Bool(value) => if value { "TRUE" } else { "FALSE" }
    FormulaValue::Error(text) => text
    FormulaValue::Empty => ""
    FormulaValue::List(list) =>
      if list.length() > 0 {
        formula_value_string(list[0])
      } else {
        ""
      }
  }
}

///|
fn value_as_string(value : FormulaValue) -> Result[String, FormulaValue] {
  match normalize_scalar(value) {
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    _ => Ok(formula_value_string(value))
  }
}

///|
fn char_from_code(code : Int) -> String {
  String::from_array([code.unsafe_to_char()])
}

///|
fn code_value(name : String, value : FormulaValue) -> FormulaValue {
  let text = match value_as_string(value) {
    Ok(value) => value
    Err(err) => return err
  }
  if text.length() == 0 {
    return if name == "CODE" {
      FormulaValue::Number(0.0)
    } else {
      FormulaValue::Error(formula_error_value)
    }
  }
  match text.get_char(0) {
    Some(ch) => FormulaValue::Number(Double::from_int(ch.to_int()))
    None =>
      if name == "CODE" {
        FormulaValue::Number(0.0)
      } else {
        FormulaValue::Error(formula_error_value)
      }
  }
}

///|
fn clean_text_value(value : FormulaValue) -> FormulaValue {
  let text = match value_as_string(value) {
    Ok(value) => value
    Err(err) => return err
  }
  let sb = StringBuilder::new()
  for ch in text {
    if ch.to_int() > 31 {
      sb.write_char(ch)
    }
  }
  FormulaValue::String(sb.to_string())
}

///|
let hex_digits : Array[Char] = "0123456789ABCDEF".to_array()

///|
fn encode_url_byte(sb : StringBuilder, byte : Byte) -> Unit {
  let value = byte.to_int()
  if (value >= 0x30 && value <= 0x39) ||
    (value >= 0x41 && value <= 0x5a) ||
    (value >= 0x61 && value <= 0x7a) ||
    value == 0x2d ||
    value == 0x2e ||
    value == 0x5f ||
    value == 0x7e {
    sb.write_char(Int::unsafe_to_char(value))
  } else {
    sb.write_char('%')
    sb.write_char(hex_digits[value / 16])
    sb.write_char(hex_digits[value % 16])
  }
}

///|
fn encode_url_value(value : FormulaValue) -> FormulaValue {
  let text = match value_as_string(value) {
    Ok(value) => value
    Err(err) => return err
  }
  let bytes = @encoding/utf8.encode(text)
  let sb = StringBuilder::new()
  for byte in bytes {
    encode_url_byte(sb, byte)
  }
  FormulaValue::String(sb.to_string())
}

///|
let th0 = "ศูนย์"

///|
let th1 = "หนึ่ง"

///|
let th2 = "สอง"

///|
let th3 = "สาม"

///|
let th4 = "สี่"

///|
let th5 = "ห้า"

///|
let th6 = "หก"

///|
let th7 = "เจ็ด"

///|
let th8 = "แปด"

///|
let th9 = "เก้า"

///|
let th10 = "สิบ"

///|
let th11 = "เอ็ด"

///|
let th20 = "ยี่"

///|
let th1e2 = "ร้อย"

///|
let th1e3 = "พัน"

///|
let th1e4 = "หมื่น"

///|
let th1e5 = "แสน"

///|
let th1e6 = "ล้าน"

///|
let thDot0 = "ถ้วน"

///|
let thBaht = "บาท"

///|
let thSatang = "สตางค์"

///|
let thMinus = "ลบ"

///|
let bahttext_digits : Array[String] = [
  th0, th1, th2, th3, th4, th5, th6, th7, th8, th9,
]

///|
fn bahttext_append_digit(text : String, digit : Int) -> String {
  if digit >= 0 && digit <= 9 {
    text + bahttext_digits[digit]
  } else {
    text
  }
}

///|
fn bahttext_append_pow10(text : String, digit : Int, pow10 : Int) -> String {
  let mut out = bahttext_append_digit(text, digit)
  match pow10 {
    2 => out = out + th1e2
    3 => out = out + th1e3
    4 => out = out + th1e4
    5 => out = out + th1e5
    _ => ()
  }
  out
}

///|
fn bahttext_append_block(text : String, val : Int) -> String {
  let mut out = text
  let mut value = val
  if value >= 100000 {
    out = bahttext_append_pow10(out, value / 100000, 5)
    value = value % 100000
  }
  if value >= 10000 {
    out = bahttext_append_pow10(out, value / 10000, 4)
    value = value % 10000
  }
  if value >= 1000 {
    out = bahttext_append_pow10(out, value / 1000, 3)
    value = value % 1000
  }
  if value >= 100 {
    out = bahttext_append_pow10(out, value / 100, 2)
    value = value % 100
  }
  if value > 0 {
    let n10 = value / 10
    let n1 = value % 10
    if n10 >= 1 {
      if n10 >= 3 {
        out = bahttext_append_digit(out, n10)
      } else if n10 == 2 {
        out = out + th20
      }
      out = out + th10
    }
    if n10 > 0 && n1 == 1 {
      out = out + th11
    } else if n1 > 0 {
      out = bahttext_append_digit(out, n1)
    }
  }
  out
}

///|
fn bahttext_split_block(val : Double, size : Double) -> (Double, Int) {
  let (integer, frac) = modf_double((val + 0.1) / size)
  let frac_value = frac * size + 0.1
  (integer, Double::to_int(trunc_double(frac_value)))
}

///|
fn bahttext_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return FormulaValue::Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let minus = number < 0.0
  let num = Double::floor(Double::abs(number) * 100.0 + 0.5)
  let (baht, satang) = bahttext_split_block(num, 100.0)
  let mut text = ""
  let mut baht_value = baht
  if baht_value == 0.0 {
    if satang == 0 {
      text = text + th0
    }
  } else {
    while baht_value > 0.0 {
      let (next_baht, n_block) = bahttext_split_block(baht_value, 1.0e6)
      let mut block = ""
      if n_block > 0 {
        block = bahttext_append_block(block, n_block)
      }
      if next_baht > 0.0 {
        block = th1e6 + block
      }
      text = block + text
      baht_value = next_baht
    }
  }
  if text.length() > 0 {
    text = text + thBaht
  }
  if satang == 0 {
    text = text + thDot0
  } else {
    text = bahttext_append_block(text, satang)
    text = text + thSatang
  }
  if minus {
    text = thMinus + text
  }
  FormulaValue::String(text)
}

///|
fn value_as_int(value : FormulaValue) -> Result[Int, FormulaValue] {
  match value_as_number(value) {
    Ok(num) => Ok(Double::to_int(trunc_double(num)))
    Err(err) => Err(err)
  }
}

///|
fn find_substring_from(text : String, pattern : String, start : Int) -> Int? {
  let len = text.length()
  if start < 0 || start > len {
    return None
  }
  if pattern.length() == 0 {
    return Some(start)
  }
  let tail = text.unsafe_substring(start~, end=len)
  match tail.find(pattern) {
    Some(idx) => Some(start + idx)
    None => None
  }
}

///|
fn split_text_parts(
  text : String,
  delimiter : String,
  ignore_empty : Bool,
  ignore_case : Bool,
) -> Array[String] {
  let parts : Array[String] = []
  if delimiter.length() == 0 {
    return parts
  }
  let search_text = if ignore_case { text.to_lower() } else { text }
  let search_delim = if ignore_case { delimiter.to_lower() } else { delimiter }
  let delim_len = delimiter.length()
  let mut pos = 0
  while true {
    match find_substring_from(search_text, search_delim, pos) {
      Some(idx) => {
        let part = text.unsafe_substring(start=pos, end=idx)
        if !ignore_empty || part != "" {
          parts.push(part)
        }
        pos = idx + delim_len
      }
      None => break
    }
  }
  let tail = text.unsafe_substring(start=pos, end=text.length())
  if !ignore_empty || tail != "" {
    parts.push(tail)
  }
  parts
}

///|
fn wildcard_match_prefix(
  text : String,
  pattern : String,
  text_idx : Int,
  pattern_idx : Int,
  memo : Map[(Int, Int), Bool],
) -> Bool {
  match memo.get((text_idx, pattern_idx)) {
    Some(result) => return result
    None => ()
  }
  let text_len = text.length()
  let pattern_len = pattern.length()
  let result = if pattern_idx == pattern_len {
    true
  } else {
    let token = pattern[pattern_idx]
    if token == '~' {
      if pattern_idx + 1 >= pattern_len {
        if text_idx < text_len && text[text_idx] == '~' {
          wildcard_match_prefix(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 1,
            memo,
          )
        } else {
          false
        }
      } else {
        let next = pattern[pattern_idx + 1]
        if text_idx < text_len && text[text_idx] == next {
          wildcard_match_prefix(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 2,
            memo,
          )
        } else {
          false
        }
      }
    } else if token == '*' {
      if wildcard_match_prefix(text, pattern, text_idx, pattern_idx + 1, memo) {
        true
      } else if text_idx < text_len {
        wildcard_match_prefix(text, pattern, text_idx + 1, pattern_idx, memo)
      } else {
        false
      }
    } else if token == '?' {
      if text_idx < text_len {
        wildcard_match_prefix(
          text,
          pattern,
          text_idx + 1,
          pattern_idx + 1,
          memo,
        )
      } else {
        false
      }
    } else if text_idx < text_len && text[text_idx] == token {
      wildcard_match_prefix(text, pattern, text_idx + 1, pattern_idx + 1, memo)
    } else {
      false
    }
  }
  memo[(text_idx, pattern_idx)] = result
  result
}

///|
fn wildcard_match_full_prefix(
  text : String,
  pattern : String,
  text_idx : Int,
  pattern_idx : Int,
  memo : Map[(Int, Int), Bool],
) -> Bool {
  match memo.get((text_idx, pattern_idx)) {
    Some(result) => return result
    None => ()
  }
  let text_len = text.length()
  let pattern_len = pattern.length()
  let result = if pattern_idx == pattern_len {
    text_idx == text_len
  } else {
    let token = pattern[pattern_idx]
    if token == '~' {
      if pattern_idx + 1 >= pattern_len {
        if text_idx < text_len && text[text_idx] == '~' {
          wildcard_match_full_prefix(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 1,
            memo,
          )
        } else {
          false
        }
      } else {
        let next = pattern[pattern_idx + 1]
        if text_idx < text_len && text[text_idx] == next {
          wildcard_match_full_prefix(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 2,
            memo,
          )
        } else {
          false
        }
      }
    } else if token == '*' {
      if wildcard_match_full_prefix(
          text,
          pattern,
          text_idx,
          pattern_idx + 1,
          memo,
        ) {
        true
      } else if text_idx < text_len {
        wildcard_match_full_prefix(
          text,
          pattern,
          text_idx + 1,
          pattern_idx,
          memo,
        )
      } else {
        false
      }
    } else if token == '?' {
      if text_idx < text_len {
        wildcard_match_full_prefix(
          text,
          pattern,
          text_idx + 1,
          pattern_idx + 1,
          memo,
        )
      } else {
        false
      }
    } else if text_idx < text_len && text[text_idx] == token {
      wildcard_match_full_prefix(
        text,
        pattern,
        text_idx + 1,
        pattern_idx + 1,
        memo,
      )
    } else {
      false
    }
  }
  memo[(text_idx, pattern_idx)] = result
  result
}

///|
fn wildcard_match_full(text : String, pattern : String) -> Bool {
  let memo : Map[(Int, Int), Bool] = {}
  wildcard_match_full_prefix(text, pattern, 0, 0, memo)
}

///|
fn wildcard_find(text : String, pattern : String, start : Int) -> Int? {
  let len = text.length()
  if start < 0 || start > len {
    return None
  }
  for idx in start..<=len {
    let memo : Map[(Int, Int), Bool] = {}
    if wildcard_match_prefix(text, pattern, idx, 0, memo) {
      return Some(idx)
    }
  }
  None
}

///|
fn bytes_to_string(bytes : BytesView) -> String {
  let sb = StringBuilder::new()
  for b in bytes {
    sb.write_char(Int::unsafe_to_char(b.to_int()))
  }
  sb.to_string()
}

///|
fn dbcs_byte_len_char(ch : Char) -> Int {
  if ch.to_int() <= 0x7f {
    1
  } else {
    2
  }
}

///|
fn dbcs_byte_length(text : String) -> Int {
  let mut total = 0
  for ch in text {
    total = total + dbcs_byte_len_char(ch)
  }
  total
}

///|
fn dbcs_enabled(workbook : Workbook) -> Bool {
  let lang = workbook.core_properties().language
  if lang == "" {
    return false
  }
  let normalized = lang.to_lower().replace(old="_", new="-")
  normalized == "ja-jp" || normalized == "zh-cn" || normalized == "zh-tw"
}

///|
fn dbcs_convert(text : String) -> String {
  let sb = StringBuilder::new()
  for ch in text {
    let r = ch.to_int()
    let code = if r == 32 { 12288 } else { r + 65248 }
    if (code < 32 || code > 126) && r != 165 && code < 65381 {
      sb.write_char(Int::unsafe_to_char(code))
    } else {
      sb.write_char(ch)
    }
  }
  sb.to_string()
}

///|
fn dbcs_index_from_offset(text : String, start_num : Int) -> Int? {
  if start_num <= 0 {
    return None
  }
  let chars = text.to_array()
  let mut offset = 1
  for i in 0..<chars.length() {
    let len = dbcs_byte_len_char(chars[i])
    let end = offset + len - 1
    if start_num <= end {
      return Some(i)
    }
    offset = offset + len
  }
  None
}

///|
fn dbcs_byte_offset_for_index(text : String, index : Int) -> Int {
  let chars = text.to_array()
  let mut offset = 1
  let mut i = 0
  while i < index && i < chars.length() {
    offset = offset + dbcs_byte_len_char(chars[i])
    i = i + 1
  }
  offset
}

///|
fn wildcard_match_prefix_dbcs(
  text : String,
  pattern : String,
  text_idx : Int,
  pattern_idx : Int,
  memo : Map[(Int, Int), Bool],
) -> Bool {
  match memo.get((text_idx, pattern_idx)) {
    Some(result) => return result
    None => ()
  }
  let text_len = text.length()
  let pattern_len = pattern.length()
  let result = if pattern_idx == pattern_len {
    true
  } else {
    let token = pattern[pattern_idx]
    if token == '~' {
      if pattern_idx + 1 >= pattern_len {
        if text_idx < text_len && text[text_idx] == '~' {
          wildcard_match_prefix_dbcs(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 1,
            memo,
          )
        } else {
          false
        }
      } else {
        let next = pattern[pattern_idx + 1]
        if text_idx < text_len && text[text_idx] == next {
          wildcard_match_prefix_dbcs(
            text,
            pattern,
            text_idx + 1,
            pattern_idx + 2,
            memo,
          )
        } else {
          false
        }
      }
    } else if token == '*' {
      if wildcard_match_prefix_dbcs(
          text,
          pattern,
          text_idx,
          pattern_idx + 1,
          memo,
        ) {
        true
      } else if text_idx < text_len {
        wildcard_match_prefix_dbcs(
          text,
          pattern,
          text_idx + 1,
          pattern_idx,
          memo,
        )
      } else {
        false
      }
    } else if token == '?' {
      if text_idx < text_len && text[text_idx].to_int() <= 0x7f {
        wildcard_match_prefix_dbcs(
          text,
          pattern,
          text_idx + 1,
          pattern_idx + 1,
          memo,
        )
      } else {
        false
      }
    } else if text_idx < text_len && text[text_idx] == token {
      wildcard_match_prefix_dbcs(
        text,
        pattern,
        text_idx + 1,
        pattern_idx + 1,
        memo,
      )
    } else {
      false
    }
  }
  memo[(text_idx, pattern_idx)] = result
  result
}

///|
fn wildcard_find_dbcs(text : String, pattern : String, start : Int) -> Int? {
  let len = text.length()
  if start < 0 || start > len {
    return None
  }
  for idx in start..<=len {
    let memo : Map[(Int, Int), Bool] = {}
    if wildcard_match_prefix_dbcs(text, pattern, idx, 0, memo) {
      return Some(idx)
    }
  }
  None
}

///|
fn find_dbcs(
  text : String,
  pattern : String,
  start_num : Int,
  wildcard : Bool,
) -> Int? {
  if start_num <= 0 {
    return None
  }
  let total = dbcs_byte_length(text)
  if start_num > total {
    return None
  }
  if pattern.length() == 0 {
    return Some(start_num)
  }
  let start_idx = match dbcs_index_from_offset(text, start_num) {
    Some(idx) => idx
    None => return None
  }
  let found_idx = if wildcard {
    wildcard_find_dbcs(text, pattern, start_idx)
  } else {
    find_substring_from(text, pattern, start_idx)
  }
  match found_idx {
    Some(idx) => Some(dbcs_byte_offset_for_index(text, idx))
    None => None
  }
}

///|
fn concat_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let sb = StringBuilder::new()
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      _ => sb.write_view(formula_value_string(value))
    }
  }
  FormulaValue::String(sb.to_string())
}

///|
fn proper_case(text : String) -> String {
  let sb = StringBuilder::new()
  let mut prev_letter = false
  for ch in text {
    let is_letter = ch.is_ascii_alphabetic()
    if !prev_letter && is_letter {
      sb.write_char(ch.to_ascii_uppercase())
    } else {
      sb.write_char(ch.to_ascii_lowercase())
    }
    prev_letter = is_letter
  }
  sb.to_string()
}

///|
fn decimal_places_from_text(text : String) -> Int {
  match text.find(".") {
    Some(pos) => {
      let tail = text.unsafe_substring(start=pos + 1, end=text.length())
      let mut count = 0
      for ch in tail {
        if ch.is_ascii_digit() {
          count = count + 1
        } else {
          break
        }
      }
      count
    }
    None => 0
  }
}

///|
fn textjoin_collect_value(
  value : FormulaValue,
  ignore_empty : Bool,
  out : Array[String],
) -> Result[Unit, FormulaValue] {
  match value {
    FormulaValue::List(list) => {
      for item in list {
        match textjoin_collect_value(item, ignore_empty, out) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      Ok(())
    }
    _ =>
      match normalize_scalar(value) {
        FormulaValue::Error(err) => Err(FormulaValue::Error(err))
        FormulaValue::Empty =>
          if !ignore_empty {
            out.push("")
            Ok(())
          } else {
            Ok(())
          }
        FormulaValue::String(text) =>
          if text != "" || !ignore_empty {
            out.push(text)
            Ok(())
          } else {
            Ok(())
          }
        FormulaValue::Number(_) | FormulaValue::Bool(_) => {
          out.push(formula_value_string(value))
          Ok(())
        }
        FormulaValue::List(_) => Ok(())
      }
  }
}

///|
fn textsplit_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 2 || values.length() > 6 {
    return FormulaValue::Error(formula_error_value)
  }
  let text = match value_as_string(values[0]) {
    Ok(value) => value
    Err(err) => return err
  }
  let col_delimiter = match value_as_string(values[1]) {
    Ok(value) => value
    Err(err) => return err
  }
  if col_delimiter == "" {
    return FormulaValue::Error(formula_error_value)
  }
  let row_delimiter = if values.length() >= 3 {
    match value_as_string(values[2]) {
      Ok(value) => value
      Err(err) => return err
    }
  } else {
    ""
  }
  let ignore_empty = if values.length() >= 4 {
    match value_as_bool(values[3]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  } else {
    false
  }
  let match_mode = if values.length() >= 5 {
    match value_as_int(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0
  }
  if match_mode != 0 && match_mode != 1 {
    return FormulaValue::Error(formula_error_value)
  }
  let ignore_case = match_mode == 1
  let pad_value = if values.length() == 6 {
    match normalize_scalar(values[5]) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::List(_) => return FormulaValue::Error(formula_error_value)
      value => value
    }
  } else {
    FormulaValue::Error(formula_error_na)
  }
  let row_texts = if row_delimiter == "" {
    [text]
  } else {
    split_text_parts(text, row_delimiter, ignore_empty, ignore_case)
  }
  let rows : Array[Array[String]] = []
  let mut max_cols = 0
  for row_text in row_texts {
    let cols = split_text_parts(
      row_text, col_delimiter, ignore_empty, ignore_case,
    )
    if cols.length() > max_cols {
      max_cols = cols.length()
    }
    rows.push(cols)
  }
  let out : Array[FormulaValue] = []
  for row in rows {
    for col in 0..<max_cols {
      if col < row.length() {
        out.push(FormulaValue::String(row[col]))
      } else {
        out.push(pad_value)
      }
    }
  }
  FormulaValue::List(out)
}

///|
fn text_after_before_index(
  text : String,
  delimiter : String,
  instance_num : Int,
  match_mode : Int,
  match_end : Bool,
) -> Int? {
  if instance_num == 0 {
    return None
  }
  let search_text = if match_mode == 1 { text.to_lower() } else { text }
  let search_delim = if match_mode == 1 {
    delimiter.to_lower()
  } else {
    delimiter
  }
  let mut found = -1
  let mut start_pos = if instance_num < 0 { search_text.length() } else { 0 }
  let count = if instance_num < 0 { -instance_num } else { instance_num }
  for i in 0..<count {
    if instance_num > 0 {
      match find_substring_from(search_text, search_delim, start_pos) {
        Some(idx) => {
          found = idx
          start_pos = idx + search_delim.length()
        }
        None =>
          if match_end && i == count - 1 {
            found = search_text.length()
          } else {
            return None
          }
      }
    } else {
      let slice = search_text.unsafe_substring(start=0, end=start_pos)
      match slice.rev_find(search_delim) {
        Some(idx) => {
          found = idx
          start_pos = idx
        }
        None =>
          if match_end && i == count - 1 {
            found = 0
          } else {
            return None
          }
      }
    }
  }
  Some(found)
}

///|
fn compare_strings(left : String, right : String) -> Int {
  let l = left.to_array()
  let r = right.to_array()
  let limit = if l.length() < r.length() { l.length() } else { r.length() }
  for i in 0..<limit {
    if l[i] != r[i] {
      return l[i].to_int() - r[i].to_int()
    }
  }
  l.length() - r.length()
}

///|
fn value_rank(value : FormulaValue) -> Int {
  match value {
    FormulaValue::Number(_) => 0
    FormulaValue::Empty => 0
    FormulaValue::String(_) => 1
    FormulaValue::Bool(_) => 2
    FormulaValue::Error(_) => 3
    FormulaValue::List(_) => 4
  }
}

///|
fn compare_values(
  lhs : FormulaValue,
  rhs : FormulaValue,
) -> Result[Int, FormulaValue] {
  match (lhs, rhs) {
    (FormulaValue::Error(err), _) => Err(FormulaValue::Error(err))
    (_, FormulaValue::Error(err)) => Err(FormulaValue::Error(err))
    _ => {
      let left = normalize_scalar(lhs)
      let right = normalize_scalar(rhs)
      let lrank = value_rank(left)
      let rrank = value_rank(right)
      if lrank != rrank {
        return Ok(if lrank < rrank { -1 } else { 1 })
      }
      match (left, right) {
        (FormulaValue::Number(a), FormulaValue::Number(b)) =>
          Ok(if a < b { -1 } else if a > b { 1 } else { 0 })
        (FormulaValue::String(a), FormulaValue::String(b)) =>
          Ok(compare_strings(a, b))
        (FormulaValue::Bool(a), FormulaValue::Bool(b)) =>
          Ok(if a == b { 0 } else if !a && b { -1 } else { 1 })
        _ => Ok(0)
      }
    }
  }
}

///|
fn compare_lookup_values(
  lhs : FormulaValue,
  rhs : FormulaValue,
) -> Result[Int?, FormulaValue] {
  match (lhs, rhs) {
    (FormulaValue::Error(err), _) => Err(FormulaValue::Error(err))
    (_, FormulaValue::Error(err)) => Err(FormulaValue::Error(err))
    _ => {
      let left = normalize_scalar(lhs)
      let right = normalize_scalar(rhs)
      let lrank = value_rank(left)
      let rrank = value_rank(right)
      if lrank != rrank {
        return Ok(None)
      }
      match (left, right) {
        (FormulaValue::Number(a), FormulaValue::Number(b)) =>
          Ok(Some(if a < b { -1 } else if a > b { 1 } else { 0 }))
        (FormulaValue::String(a), FormulaValue::String(b)) =>
          Ok(Some(compare_strings(a, b)))
        (FormulaValue::Bool(a), FormulaValue::Bool(b)) =>
          Ok(Some(if a == b { 0 } else if !a && b { -1 } else { 1 }))
        _ => Ok(None)
      }
    }
  }
}

///|
fn match_range_value(
  lookup : FormulaValue,
  range : RangeValues,
  match_type : Int,
) -> FormulaValue {
  let values = match range_vector(range) {
    Some(list) => list
    None => return FormulaValue::Error(formula_error_na)
  }
  if match_type != 0 && match_type != 1 && match_type != -1 {
    return FormulaValue::Error(formula_error_na)
  }
  match lookup {
    FormulaValue::Error(err) => return FormulaValue::Error(err)
    _ => ()
  }
  if match_type == 0 {
    for i in 0..<values.length() {
      match compare_values(values[i], lookup) {
        Ok(0) => return FormulaValue::Number(Double::from_int(i + 1))
        Ok(_) => ()
        Err(err) => return err
      }
    }
    return FormulaValue::Error(formula_error_na)
  }
  let mut best_idx : Int? = None
  for i in 0..<values.length() {
    match compare_values(values[i], lookup) {
      Ok(cmp) =>
        if match_type == 1 {
          if cmp <= 0 {
            best_idx = Some(i)
          }
        } else if cmp >= 0 {
          best_idx = Some(i)
        }
      Err(err) => return err
    }
  }
  match best_idx {
    Some(idx) => FormulaValue::Number(Double::from_int(idx + 1))
    None => FormulaValue::Error(formula_error_na)
  }
}

///|
fn lookup_range_flag(value : FormulaValue) -> Result[Bool, FormulaValue] {
  match normalize_scalar(value) {
    FormulaValue::Bool(flag) => Ok(flag)
    FormulaValue::Number(num) => Ok(num != 0.0)
    FormulaValue::Empty => Ok(false)
    FormulaValue::String(text) => {
      let parsed = @strconv.parse_bool(text) catch {
        _ => return Err(FormulaValue::Error(formula_error_value))
      }
      Ok(parsed)
    }
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    FormulaValue::List(_) => Err(FormulaValue::Error(formula_error_value))
  }
}

///|
fn vlookup_value(
  lookup : FormulaValue,
  table : RangeValues,
  col_index : Int,
  range_lookup : Bool,
) -> FormulaValue {
  match lookup {
    FormulaValue::Error(err) => return FormulaValue::Error(err)
    _ => ()
  }
  if col_index <= 0 {
    return FormulaValue::Error(formula_error_value)
  }
  if col_index > table.cols {
    return FormulaValue::Error(formula_error_ref)
  }
  if range_lookup {
    let mut best_row : Int? = None
    for row in 0..<table.rows {
      let key = table.values[row * table.cols]
      match compare_values(key, lookup) {
        Ok(cmp) => if cmp <= 0 { best_row = Some(row) }
        Err(err) => return err
      }
    }
    match best_row {
      Some(row) => table.values[row * table.cols + (col_index - 1)]
      None => FormulaValue::Error(formula_error_na)
    }
  } else {
    for row in 0..<table.rows {
      let key = table.values[row * table.cols]
      match compare_values(key, lookup) {
        Ok(0) => return table.values[row * table.cols + (col_index - 1)]
        Ok(_) => ()
        Err(err) => return err
      }
    }
    FormulaValue::Error(formula_error_na)
  }
}

///|
fn hlookup_value(
  lookup : FormulaValue,
  table : RangeValues,
  row_index : Int,
  range_lookup : Bool,
) -> FormulaValue {
  match lookup {
    FormulaValue::Error(err) => return FormulaValue::Error(err)
    _ => ()
  }
  match lookup {
    FormulaValue::List(list) =>
      if list.length() > 1 {
        return FormulaValue::Error(formula_error_na)
      }
    _ => ()
  }
  if row_index <= 0 {
    return FormulaValue::Error(formula_error_value)
  }
  if row_index > table.rows {
    return FormulaValue::Error(formula_error_ref)
  }
  if range_lookup {
    let mut best_col : Int? = None
    for col in 0..<table.cols {
      let key = table.values[col]
      match compare_values(key, lookup) {
        Ok(cmp) => if cmp <= 0 { best_col = Some(col) }
        Err(err) => return err
      }
    }
    match best_col {
      Some(col) => table.values[(row_index - 1) * table.cols + col]
      None => FormulaValue::Error(formula_error_na)
    }
  } else {
    for col in 0..<table.cols {
      let key = table.values[col]
      match compare_values(key, lookup) {
        Ok(0) => return table.values[(row_index - 1) * table.cols + col]
        Ok(_) => ()
        Err(err) => return err
      }
    }
    FormulaValue::Error(formula_error_na)
  }
}

///|
fn lookup_best_index(
  lookup : FormulaValue,
  values : Array[FormulaValue],
) -> Result[Int?, FormulaValue] {
  let mut best_idx : Int? = None
  for i in 0..<values.length() {
    match compare_lookup_values(values[i], lookup) {
      Ok(Some(cmp)) =>
        if cmp <= 0 {
          match best_idx {
            None => best_idx = Some(i)
            Some(best) =>
              match compare_values(values[i], values[best]) {
                Ok(order) => if order > 0 { best_idx = Some(i) }
                Err(err) => return Err(err)
              }
          }
        }
      Ok(None) => ()
      Err(err) => return Err(err)
    }
  }
  Ok(best_idx)
}

///|
fn xlookup_find_index(
  lookup : FormulaValue,
  values : Array[FormulaValue],
  match_mode : Int,
  search_mode : Int,
) -> Result[Int?, FormulaValue] {
  match lookup {
    FormulaValue::Error(err) => return Err(FormulaValue::Error(err))
    _ => ()
  }
  if values.length() == 0 {
    return Ok(None)
  }
  if match_mode == 2 {
    let pattern_text = match value_as_string(lookup) {
      Ok(text) => text.to_lower()
      Err(err) => return Err(err)
    }
    let mut idx = if search_mode == -1 || search_mode == -2 {
      values.length() - 1
    } else {
      0
    }
    let end = if search_mode == -1 || search_mode == -2 {
      -1
    } else {
      values.length()
    }
    while idx != end {
      let target_text = match value_as_string(values[idx]) {
        Ok(text) => text.to_lower()
        Err(err) => return Err(err)
      }
      if wildcard_match_full(target_text, pattern_text) {
        return Ok(Some(idx))
      }
      idx = if search_mode == -1 || search_mode == -2 {
        idx - 1
      } else {
        idx + 1
      }
    }
    return Ok(None)
  }
  if match_mode == 0 {
    let mut idx = if search_mode == -1 || search_mode == -2 {
      values.length() - 1
    } else {
      0
    }
    let end = if search_mode == -1 || search_mode == -2 {
      -1
    } else {
      values.length()
    }
    while idx != end {
      match compare_values(values[idx], lookup) {
        Ok(0) => return Ok(Some(idx))
        Ok(_) => ()
        Err(err) => return Err(err)
      }
      idx = if search_mode == -1 || search_mode == -2 {
        idx - 1
      } else {
        idx + 1
      }
    }
    return Ok(None)
  }
  if match_mode != -1 && match_mode != 1 {
    return Err(FormulaValue::Error(formula_error_value))
  }
  let mut best_idx : Int? = None
  for i in 0..<values.length() {
    match compare_values(values[i], lookup) {
      Ok(cmp) =>
        if (match_mode == -1 && cmp <= 0) || (match_mode == 1 && cmp >= 0) {
          match best_idx {
            None => best_idx = Some(i)
            Some(best) =>
              match compare_values(values[i], values[best]) {
                Ok(order) =>
                  if (match_mode == -1 && order > 0) ||
                    (match_mode == 1 && order < 0) {
                    best_idx = Some(i)
                  }
                Err(err) => return Err(err)
              }
          }
        }
      Err(err) => return Err(err)
    }
  }
  Ok(best_idx)
}

///|
fn normalize_scalar(value : FormulaValue) -> FormulaValue {
  match value {
    FormulaValue::List(list) =>
      if list.length() > 0 {
        normalize_scalar(list[0])
      } else {
        FormulaValue::Empty
      }
    _ => value
  }
}

///|
fn value_as_number(value : FormulaValue) -> Result[Double, FormulaValue] {
  match normalize_scalar(value) {
    FormulaValue::Number(num) => Ok(num)
    FormulaValue::Bool(flag) => Ok(if flag { 1.0 } else { 0.0 })
    FormulaValue::Empty => Ok(0.0)
    FormulaValue::String(text) => {
      let parsed = @strconv.parse_double(text) catch {
        _ => return Err(FormulaValue::Error(formula_error_value))
      }
      Ok(parsed)
    }
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    FormulaValue::List(_) => Err(FormulaValue::Error(formula_error_value))
  }
}

///|
fn value_as_number_text(value : FormulaValue) -> Result[Double, FormulaValue] {
  match normalize_scalar(value) {
    FormulaValue::Number(num) => Ok(num)
    FormulaValue::Bool(flag) => Ok(if flag { 1.0 } else { 0.0 })
    FormulaValue::Empty => Ok(0.0)
    FormulaValue::String(text) =>
      match parse_value_number(text) {
        Some(num) => Ok(num)
        None => Err(FormulaValue::Error(formula_error_value))
      }
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    FormulaValue::List(_) => Err(FormulaValue::Error(formula_error_value))
  }
}

///|
fn parse_double_opt(text : StringView) -> Double? {
  let parsed = @strconv.parse_double(text) catch { _ => return None }
  Some(parsed)
}

///|
fn parse_value_number(text : String) -> Double? {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return Some(0.0)
  }
  let mut negative = false
  let mut body = trimmed
  if body.has_prefix("(") && body.has_suffix(")") && body.length() >= 2 {
    negative = true
    body = (body[1:body.length() - 1] catch { _ => body }).to_string()
  }
  let mut percent = false
  if body.has_suffix("%") && body.length() >= 1 {
    percent = true
    body = (body[:body.length() - 1] catch { _ => body }).to_string()
  }
  let sb = StringBuilder::new()
  for ch in body {
    if ch != ',' {
      sb.write_char(ch)
    }
  }
  let cleaned = sb.to_string().trim().to_string()
  if cleaned == "" {
    return None
  }
  let parsed = @strconv.parse_double(cleaned) catch { _ => return None }
  let mut value = if percent { parsed / 100.0 } else { parsed }
  if negative {
    value = -value
  }
  Some(value)
}

///|
priv struct Complex {
  real : Double
  imag : Double
}

///|
fn complex_new(real : Double, imag : Double) -> Complex {
  { real, imag }
}

///|
fn complex_add(left : Complex, right : Complex) -> Complex {
  { real: left.real + right.real, imag: left.imag + right.imag }
}

///|
fn complex_sub(left : Complex, right : Complex) -> Complex {
  { real: left.real - right.real, imag: left.imag - right.imag }
}

///|
fn complex_mul(left : Complex, right : Complex) -> Complex {
  {
    real: left.real * right.real - left.imag * right.imag,
    imag: left.real * right.imag + left.imag * right.real,
  }
}

///|
fn complex_div(left : Complex, right : Complex) -> Complex {
  let denom = right.real * right.real + right.imag * right.imag
  {
    real: (left.real * right.real + left.imag * right.imag) / denom,
    imag: (left.imag * right.real - left.real * right.imag) / denom,
  }
}

///|
fn complex_scale(value : Complex, factor : Double) -> Complex {
  { real: value.real * factor, imag: value.imag * factor }
}

///|
fn complex_abs(value : Complex) -> Double {
  Double::sqrt(value.real * value.real + value.imag * value.imag)
}

///|
fn complex_arg(value : Complex) -> Double {
  @math.atan2(value.imag, value.real)
}

///|
fn complex_conj(value : Complex) -> Complex {
  { real: value.real, imag: -value.imag }
}

///|
fn complex_exp(value : Complex) -> Complex {
  let scale = @math.exp(value.real)
  { real: scale * @math.cos(value.imag), imag: scale * @math.sin(value.imag) }
}

///|
fn complex_log(value : Complex) -> Complex {
  { real: @math.ln(complex_abs(value)), imag: complex_arg(value) }
}

///|
fn complex_pow(base : Complex, exponent : Complex) -> Complex {
  complex_exp(complex_mul(exponent, complex_log(base)))
}

///|
fn complex_sqrt(value : Complex) -> Complex {
  let r = complex_abs(value)
  let real = Double::sqrt((r + value.real) / 2.0)
  let sign = if value.imag < 0.0 { -1.0 } else { 1.0 }
  let imag = sign * Double::sqrt((r - value.real) / 2.0)
  { real, imag }
}

///|
fn complex_sin(value : Complex) -> Complex {
  {
    real: @math.sin(value.real) * @math.cosh(value.imag),
    imag: @math.cos(value.real) * @math.sinh(value.imag),
  }
}

///|
fn complex_cos(value : Complex) -> Complex {
  {
    real: @math.cos(value.real) * @math.cosh(value.imag),
    imag: -@math.sin(value.real) * @math.sinh(value.imag),
  }
}

///|
fn complex_tan(value : Complex) -> Complex {
  complex_div(complex_sin(value), complex_cos(value))
}

///|
fn complex_sinh(value : Complex) -> Complex {
  {
    real: @math.sinh(value.real) * @math.cos(value.imag),
    imag: @math.cosh(value.real) * @math.sin(value.imag),
  }
}

///|
fn complex_cosh(value : Complex) -> Complex {
  {
    real: @math.cosh(value.real) * @math.cos(value.imag),
    imag: @math.sinh(value.real) * @math.sin(value.imag),
  }
}

///|
fn complex_is_invalid(value : Complex) -> Bool {
  Double::is_nan(value.real) ||
  Double::is_nan(value.imag) ||
  Double::is_inf(value.real) ||
  Double::is_inf(value.imag)
}

///|
fn complex_suffix_from_text(text : String) -> String {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return "i"
  }
  let chars = trimmed.to_array()
  let last = chars[chars.length() - 1]
  let sb = StringBuilder::new()
  sb.write_char(last)
  sb.to_string()
}

///|
fn normalize_complex_text(text : StringView) -> String {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return ""
  }
  let lower = trimmed.to_lower()
  let mut normalized = lower.replace_all(old="j", new="i")
  if normalized == "i" {
    normalized = "1i"
  }
  normalized = normalized.replace_all(old="+i", new="+1i")
  normalized = normalized.replace_all(old="-i", new="-1i")
  normalized
}

///|
fn split_complex_body(body : String) -> (String, String) {
  let chars = body.to_array()
  let mut split = -1
  let mut idx = 1
  while idx < chars.length() {
    let ch = chars[idx]
    if (ch == '+' || ch == '-') &&
      chars[idx - 1] != 'e' &&
      chars[idx - 1] != 'E' {
      split = idx
    }
    idx = idx + 1
  }
  if split < 0 {
    ("0", body)
  } else {
    let left = body.unsafe_substring(start=0, end=split)
    let right = body.unsafe_substring(start=split, end=body.length())
    (left, right)
  }
}

///|
fn parse_complex_text(text : StringView) -> Result[Complex, FormulaValue] {
  let normalized = normalize_complex_text(text)
  if normalized == "" {
    return Err(FormulaValue::Error(formula_error_num))
  }
  if normalized.has_suffix("i") {
    let body = normalized.unsafe_substring(start=0, end=normalized.length() - 1)
    let (real_text, imag_text) = split_complex_body(body)
    match (parse_double_opt(real_text), parse_double_opt(imag_text)) {
      (Some(real), Some(imag)) => Ok(complex_new(real, imag))
      _ => Err(FormulaValue::Error(formula_error_num))
    }
  } else {
    match parse_double_opt(normalized) {
      Some(real) => Ok(complex_new(real, 0.0))
      None => Err(FormulaValue::Error(formula_error_num))
    }
  }
}

///|
fn parse_complex_value(value : FormulaValue) -> Result[Complex, FormulaValue] {
  match value_as_string(value) {
    Ok(text) => parse_complex_text(text)
    Err(err) => Err(err)
  }
}

///|
fn parse_complex_value_with_suffix(
  value : FormulaValue,
) -> Result[(Complex, String), FormulaValue] {
  match value_as_string(value) {
    Ok(text) => {
      let suffix = complex_suffix_from_text(text)
      match parse_complex_text(text) {
        Ok(num) => Ok((num, suffix))
        Err(err) => Err(err)
      }
    }
    Err(err) => Err(err)
  }
}

///|
fn complex_to_string(value : Complex, suffix : String) -> String {
  let real_raw = round_significant_digits(value.real, 15)
  let imag_raw = round_significant_digits(value.imag, 15)
  let real = if real_raw == 0.0 { 0.0 } else { real_raw }
  let imag = if imag_raw == 0.0 { 0.0 } else { imag_raw }
  let real_text = format_number(real)
  if imag == 0.0 {
    return real_text
  }
  let abs_imag = if imag < 0.0 { -imag } else { imag }
  let imag_text = format_number(abs_imag)
  let imag_part = if imag_text == "1" { suffix } else { imag_text + suffix }
  if real == 0.0 {
    if imag < 0.0 {
      return "-" + imag_part
    }
    return imag_part
  }
  let join = if imag < 0.0 { "-" } else { "+" }
  real_text + join + imag_part
}

///|
fn parse_date_parts(text : String) -> (Int, Int, Int)? {
  let trimmed = text.trim().to_string()
  if trimmed == "" {
    return None
  }
  let parts : Array[String] = []
  let mut current = StringBuilder::new()
  for ch in trimmed {
    if ch.is_ascii_digit() {
      current.write_char(ch)
    } else if ch == '/' || ch == '-' {
      let part = current.to_string()
      if part == "" {
        return None
      }
      parts.push(part)
      current = StringBuilder::new()
    } else if ch.is_ascii_whitespace() {
      continue
    } else {
      return None
    }
  }
  let last = current.to_string()
  if last == "" {
    return None
  }
  parts.push(last)
  if parts.length() != 3 {
    return None
  }
  let p0 = @strconv.parse_int(parts[0], base=10) catch { _ => return None }
  let p1 = @strconv.parse_int(parts[1], base=10) catch { _ => return None }
  let p2 = @strconv.parse_int(parts[2], base=10) catch { _ => return None }
  let year = if parts[0].length() == 4 {
    p0
  } else if parts[2].length() == 4 {
    p2
  } else if p2 <= 29 {
    2000 + p2
  } else {
    1900 + p2
  }
  let month = if parts[0].length() == 4 { p1 } else { p0 }
  let day = if parts[0].length() == 4 { p2 } else { p1 }
  Some((year, month, day))
}

///|
fn parse_time_parts(text : String) -> (Int, Int, Int)? {
  let trimmed = text.trim().to_upper()
  if trimmed == "" {
    return None
  }
  let mut is_pm = false
  let mut is_am = false
  let mut core = trimmed
  if core.has_suffix("AM") {
    is_am = true
    core = (core[:core.length() - 2] catch { _ => core }).trim().to_string()
  } else if core.has_suffix("PM") {
    is_pm = true
    core = (core[:core.length() - 2] catch { _ => core }).trim().to_string()
  }
  let parts : Array[String] = []
  let mut current = StringBuilder::new()
  for ch in core {
    if ch.is_ascii_digit() {
      current.write_char(ch)
    } else if ch == ':' {
      let part = current.to_string()
      if part == "" {
        return None
      }
      parts.push(part)
      current = StringBuilder::new()
    } else if ch.is_ascii_whitespace() {
      continue
    } else {
      return None
    }
  }
  let last = current.to_string()
  if last == "" {
    return None
  }
  parts.push(last)
  if parts.length() == 0 || parts.length() > 3 {
    return None
  }
  let hour = @strconv.parse_int(parts[0], base=10) catch { _ => return None }
  let minute = if parts.length() >= 2 {
    @strconv.parse_int(parts[1], base=10) catch {
      _ => return None
    }
  } else {
    0
  }
  let second = if parts.length() == 3 {
    @strconv.parse_int(parts[2], base=10) catch {
      _ => return None
    }
  } else {
    0
  }
  let mut hours = hour
  if is_am {
    if hours == 12 {
      hours = 0
    }
  } else if is_pm {
    if hours < 12 {
      hours = hours + 12
    }
  }
  Some((hours, minute, second))
}

///|
fn strip_hex_prefix(text : String) -> String {
  if text.length() > 2 && (text.has_prefix("0x") || text.has_prefix("0X")) {
    let chars = text.to_array()
    let sb = StringBuilder::new()
    for i in 2..<chars.length() {
      sb.write_char(chars[i])
    }
    sb.to_string()
  } else {
    text
  }
}

///|
fn value_as_bool(value : FormulaValue) -> Result[Bool, FormulaValue] {
  match normalize_scalar(value) {
    FormulaValue::Bool(flag) => Ok(flag)
    FormulaValue::Number(num) => Ok(num == 1.0)
    FormulaValue::Empty => Ok(false)
    FormulaValue::String(text) => {
      let parsed = @strconv.parse_bool(text) catch {
        _ => return Err(FormulaValue::Error(formula_error_value))
      }
      Ok(parsed)
    }
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    FormulaValue::List(_) => Err(FormulaValue::Error(formula_error_value))
  }
}

///|
fn value_as_number_opt(value : FormulaValue) -> Double? {
  match normalize_scalar(value) {
    FormulaValue::Number(num) => Some(num)
    FormulaValue::Bool(flag) => Some(if flag { 1.0 } else { 0.0 })
    FormulaValue::String(text) => parse_double_opt(text)
    _ => None
  }
}

///|
fn is_digits(text : StringView) -> Bool {
  if text == "" {
    return false
  }
  for ch in text {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn parse_criteria_number(text : StringView) -> Double? {
  match text.strip_suffix("%") {
    Some(stripped) =>
      match parse_double_opt(stripped) {
        Some(num) => Some(num / 100.0)
        None => None
      }
    None => parse_double_opt(text)
  }
}

///|
fn build_criteria_pattern(text : StringView) -> String {
  let chars = text.to_array()
  let sb = StringBuilder::new()
  let mut idx = 0
  while idx < chars.length() {
    let ch = chars[idx]
    if ch == '~' {
      if idx + 1 < chars.length() {
        let next = chars[idx + 1]
        sb.write_char(next)
        idx = idx + 2
      } else {
        sb.write_char('~')
        idx = idx + 1
      }
    } else if ch == '*' {
      sb.write_char('.')
      sb.write_char('*')
      idx = idx + 1
    } else if ch == '?' {
      sb.write_char('.')
      idx = idx + 1
    } else {
      sb.write_char(ch)
      idx = idx + 1
    }
  }
  sb.to_string()
}

///|
fn parse_formula_criteria(value : FormulaValue) -> FormulaCriteria {
  let text = formula_value_string(value)
  if text == "" {
    return { kind: FormulaCriteriaType::Unset, condition: FormulaValue::Empty }
  }
  if is_digits(text) {
    return {
      kind: FormulaCriteriaType::Eq,
      condition: match parse_criteria_number(text) {
        Some(num) => FormulaValue::Number(num)
        None => FormulaValue::String(text)
      },
    }
  }
  let mut condition_text = text
  let kind = if text.has_prefix("<>") {
    condition_text = (text[2:] catch { _ => "" }).to_string()
    FormulaCriteriaType::Ne
  } else if text.has_prefix("<=") {
    condition_text = (text[2:] catch { _ => "" }).to_string()
    FormulaCriteriaType::Le
  } else if text.has_prefix(">=") {
    condition_text = (text[2:] catch { _ => "" }).to_string()
    FormulaCriteriaType::Ge
  } else if text.has_prefix("<") {
    condition_text = (text[1:] catch { _ => "" }).to_string()
    FormulaCriteriaType::Lt
  } else if text.has_prefix(">") {
    condition_text = (text[1:] catch { _ => "" }).to_string()
    FormulaCriteriaType::Gt
  } else if text.has_prefix("=") {
    condition_text = (text[1:] catch { _ => "" }).to_string()
    FormulaCriteriaType::Eq
  } else {
    FormulaCriteriaType::Regexp
  }
  match kind {
    FormulaCriteriaType::Regexp => ()
    _ =>
      return {
        kind,
        condition: match parse_criteria_number(condition_text) {
          Some(num) => FormulaValue::Number(num)
          None => FormulaValue::String(condition_text)
        },
      }
  }
  let pattern = ".*" + build_criteria_pattern(condition_text) + ".*"
  let mut condition : FormulaValue = FormulaValue::String(pattern)
  match parse_double_opt(pattern) {
    Some(num) => condition = FormulaValue::Number(num)
    None => ()
  }
  { kind, condition }
}

///|
fn formula_criteria_condition_is_string(criteria : FormulaCriteria) -> Bool {
  match criteria.condition {
    FormulaValue::String(_) => true
    _ => false
  }
}

///|
fn compare_criteria_values(left : FormulaValue, right : FormulaValue) -> Int? {
  let lhs = normalize_scalar(left)
  let rhs = normalize_scalar(right)
  match (lhs, rhs) {
    (FormulaValue::Number(a), FormulaValue::Number(b)) =>
      Some(if a < b { -1 } else if a > b { 1 } else { 0 })
    (FormulaValue::Bool(a), FormulaValue::Bool(b)) => {
      let la = if a { 1.0 } else { 0.0 }
      let rb = if b { 1.0 } else { 0.0 }
      Some(if la < rb { -1 } else if la > rb { 1 } else { 0 })
    }
    (FormulaValue::Bool(a), FormulaValue::Number(b)) => {
      let la = if a { 1.0 } else { 0.0 }
      Some(if la < b { -1 } else if la > b { 1 } else { 0 })
    }
    (FormulaValue::Number(a), FormulaValue::Bool(b)) => {
      let rb = if b { 1.0 } else { 0.0 }
      Some(if a < rb { -1 } else if a > rb { 1 } else { 0 })
    }
    (FormulaValue::String(a), FormulaValue::String(b)) =>
      Some(compare_strings(a, b))
    (FormulaValue::String(_), FormulaValue::Number(_) | FormulaValue::Bool(_)) =>
      Some(1)
    (FormulaValue::Number(_) | FormulaValue::Bool(_), FormulaValue::String(_)) =>
      Some(-1)
    _ => None
  }
}

///|
fn regex_match_from(
  text : Array[Char],
  pattern : Array[Char],
  i : Int,
  j : Int,
  memo : Map[(Int, Int), Bool],
) -> Bool {
  match memo.get((i, j)) {
    Some(result) => return result
    None => ()
  }
  let result = if j == pattern.length() {
    i == text.length()
  } else if j + 1 < pattern.length() &&
    pattern[j] == '.' &&
    pattern[j + 1] == '*' {
    if regex_match_from(text, pattern, i, j + 2, memo) {
      true
    } else if i < text.length() {
      regex_match_from(text, pattern, i + 1, j, memo)
    } else {
      false
    }
  } else if i < text.length() && (pattern[j] == '.' || pattern[j] == text[i]) {
    regex_match_from(text, pattern, i + 1, j + 1, memo)
  } else {
    false
  }
  memo[(i, j)] = result
  result
}

///|
fn regex_like_match(text : StringView, pattern : StringView) -> Bool {
  let text_chars = text.to_array()
  let pattern_chars = pattern.to_array()
  let memo : Map[(Int, Int), Bool] = {}
  regex_match_from(text_chars, pattern_chars, 0, 0, memo)
}

///|
fn formula_criteria_eval(
  value : FormulaValue,
  criteria : FormulaCriteria,
) -> Bool {
  match criteria.kind {
    FormulaCriteriaType::Unset => false
    FormulaCriteriaType::Eq =>
      formula_value_string(value) == formula_value_string(criteria.condition)
    FormulaCriteriaType::Ne =>
      formula_value_string(value) != formula_value_string(criteria.condition)
    FormulaCriteriaType::Regexp =>
      regex_like_match(
        formula_value_string(value),
        formula_value_string(criteria.condition),
      )
    FormulaCriteriaType::Lt
    | FormulaCriteriaType::Le
    | FormulaCriteriaType::Gt
    | FormulaCriteriaType::Ge =>
      match compare_criteria_values(value, criteria.condition) {
        Some(result) =>
          match criteria.kind {
            FormulaCriteriaType::Lt => result < 0
            FormulaCriteriaType::Le => result <= 0
            FormulaCriteriaType::Gt => result > 0
            FormulaCriteriaType::Ge => result >= 0
            _ => false
          }
        None => false
      }
  }
}

///|
priv struct CalcDatabase {
  mut row : Int
  col : Int
  index_map : Map[Int, Int]
  database : RangeValues
  criteria : RangeValues
}

///|
fn calc_database_column_index(
  database : RangeValues,
  field : FormulaValue,
) -> Int {
  let normalized = normalize_scalar(field)
  match normalized {
    FormulaValue::Error(_) => return -1
    _ => ()
  }
  match value_as_number_opt(normalized) {
    Some(num) => return Double::to_int(trunc_double(num)) - 1
    None => ()
  }
  let field_text = formula_value_string(normalized).to_lower()
  if field_text == "" {
    return -1
  }
  for idx in 0..<database.cols {
    match database.get(0, idx) {
      Some(value) =>
        if formula_value_string(value).to_lower() == field_text {
          return idx
        }
      None => ()
    }
  }
  -1
}

///|
fn calc_database_new(
  database : RangeValues,
  field : FormulaValue,
  criteria : RangeValues,
) -> CalcDatabase? {
  let invalid = database.rows < 2 ||
    database.cols < 1 ||
    criteria.rows < 2 ||
    criteria.cols < 1
  if invalid {
    return None
  }
  let mut col = -1
  let normalized_field = normalize_scalar(field)
  let has_field = match normalized_field {
    FormulaValue::Empty => false
    _ => true
  }
  if has_field {
    col = calc_database_column_index(database, field)
    if col < 0 || col >= database.cols {
      return None
    }
  }
  Some(CalcDatabase::{ row: 0, col, index_map: {}, database, criteria })
}

///|
fn calc_database_value(db : CalcDatabase) -> FormulaValue {
  if db.col == -1 {
    match db.database.get(db.row, db.database.cols - 1) {
      Some(value) => value
      None => FormulaValue::Empty
    }
  } else {
    match db.database.get(db.row, db.col) {
      Some(value) => value
      None => FormulaValue::Empty
    }
  }
}

///|
fn calc_database_criteria_eval(db : CalcDatabase) -> Bool {
  let columns = db.criteria.cols
  let rows = db.criteria.rows
  if db.index_map.get(0) is None {
    for j in 0..<columns {
      let header = match db.criteria.get(0, j) {
        Some(value) => value
        None => FormulaValue::Empty
      }
      let idx = calc_database_column_index(db.database, header)
      if idx < 0 {
        return false
      }
      db.index_map[j] = idx
    }
  }
  let mut matched = false
  let mut i = 1
  while !matched && i < rows {
    let mut row_match = true
    let mut j = 0
    while row_match && j < columns {
      let criteria_value = match db.criteria.get(i, j) {
        Some(value) => value
        None => FormulaValue::Empty
      }
      if formula_value_string(criteria_value) != "" {
        let criteria = parse_formula_criteria(criteria_value)
        let col_index = match db.index_map.get(j) {
          Some(value) => value
          None => return false
        }
        let cell = match db.database.get(db.row, col_index) {
          Some(value) => value
          None => FormulaValue::Empty
        }
        if !formula_criteria_eval(cell, criteria) {
          row_match = false
        }
      }
      j = j + 1
    }
    if row_match {
      matched = true
    }
    i = i + 1
  }
  matched
}

///|
fn calc_database_next(db : CalcDatabase) -> Bool {
  let rows = db.database.rows
  let mut matched = false
  while !matched && db.row < rows {
    db.row = db.row + 1
    if db.row < rows {
      matched = calc_database_criteria_eval(db)
    }
  }
  matched
}

///|
fn database_collect_values(
  database : RangeValues,
  field : FormulaValue,
  criteria : RangeValues,
) -> Result[Array[FormulaValue], FormulaValue] {
  let db = match calc_database_new(database, field, criteria) {
    Some(value) => value
    None => return Err(FormulaValue::Error(formula_error_value))
  }
  let values : Array[FormulaValue] = []
  while calc_database_next(db) {
    values.push(calc_database_value(db))
  }
  Ok(values)
}

///|
fn database_count_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut count = 0
  for value in values {
    match normalize_scalar(value) {
      FormulaValue::Number(_) => count = count + 1
      FormulaValue::String(text) =>
        match parse_double_opt(text) {
          Some(_) => count = count + 1
          None => ()
        }
      FormulaValue::Bool(_) => ()
      FormulaValue::Error(_) => ()
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  FormulaValue::Number(Double::from_int(count))
}

///|
fn database_values(
  name : String,
  database : RangeValues,
  field : FormulaValue,
  criteria : RangeValues,
) -> FormulaValue {
  let values = match database_collect_values(database, field, criteria) {
    Ok(items) => items
    Err(err) => return err
  }
  match name {
    "DMAX" => max_values(values)
    "DMIN" => min_values(values)
    "DPRODUCT" => product_values(values)
    "DSUM" => sum_values(values)
    "DSTDEV" => stdev_values(false, values)
    "DSTDEVP" =>
      match variance_values(values, false, false) {
        FormulaValue::Number(variance) => {
          let result = @math.pow(variance, 0.5)
          FormulaValue::Number(round_significant_digits(result, 15))
        }
        FormulaValue::Error(err) => FormulaValue::Error(err)
        _ => FormulaValue::Error(formula_error_value)
      }
    "DVAR" => variance_values(values, true, false)
    "DVARP" => variance_values(values, false, false)
    _ => average_values(values)
  }
}

///|
fn dcount_values(
  name : String,
  database : RangeValues,
  field : FormulaValue,
  criteria : RangeValues,
) -> FormulaValue {
  let values = match database_collect_values(database, field, criteria) {
    Ok(items) => items
    Err(err) => return err
  }
  if name == "DCOUNT" {
    database_count_values(values)
  } else {
    counta_values(values)
  }
}

///|
fn dget_values(
  database : RangeValues,
  field : FormulaValue,
  criteria : RangeValues,
) -> FormulaValue {
  let db = match calc_database_new(database, field, criteria) {
    Some(value) => value
    None => return FormulaValue::Error(formula_error_value)
  }
  let mut value = FormulaValue::Error(formula_error_value)
  if calc_database_next(db) {
    value = calc_database_value(db)
    if calc_database_next(db) {
      return FormulaValue::Error(formula_error_num)
    }
  }
  value
}

///|
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn trunc_double(value : Double) -> Double {
  if value < 0.0 {
    -Double::floor(-value)
  } else {
    Double::floor(value)
  }
}

///|
fn modf_double(value : Double) -> (Double, Double) {
  let truncated = trunc_double(value)
  (truncated, value - truncated)
}

///|
fn normalize_year_month(year : Int, month : Int) -> (Int, Int) {
  let mut y = year
  let mut m = month
  while m <= 0 {
    m = m + 12
    y = y - 1
  }
  while m > 12 {
    m = m - 12
    y = y + 1
  }
  (y, m)
}

///|
fn normalize_date_parts(year : Int, month : Int, day : Int) -> (Int, Int, Int) {
  let (year_value, month_value) = normalize_year_month(year, month)
  let mut y = year_value
  let mut m = month_value
  let mut d = day
  while d <= 0 {
    m = m - 1
    if m <= 0 {
      m = 12
      y = y - 1
    }
    d = d + days_in_month(y, m)
  }
  let mut dim = days_in_month(y, m)
  while d > dim {
    d = d - dim
    m = m + 1
    if m > 12 {
      m = 1
      y = y + 1
    }
    dim = days_in_month(y, m)
  }
  (y, m, d)
}

///|
fn days_before_year(year : Int) -> Int {
  let mut days = 0
  let mut y = 1900
  if year >= 1900 {
    while y < year {
      let inc = if is_leap_year(y) { 366 } else { 365 }
      days = days + inc
      y = y + 1
    }
  } else {
    while y > year {
      y = y - 1
      let dec = if is_leap_year(y) { 366 } else { 365 }
      days = days - dec
    }
  }
  days
}

///|
fn days_before_month(year : Int, month : Int) -> Int {
  let mut days = 0
  for m in 1..<month {
    days = days + days_in_month(year, m)
  }
  days
}

///|
fn excel_serial_from_date(year : Int, month : Int, day : Int) -> Double? {
  if year < 0 || year > 9999 {
    return None
  }
  let (y, m, d) = normalize_date_parts(year, month, day)
  if y < 0 || y > 9999 {
    return None
  }
  let mut days = days_before_year(y)
  days = days + days_before_month(y, m)
  days = days + (d - 1)
  let mut serial = days + 1
  if serial >= 60 {
    serial = serial + 1
  }
  if serial < 0 {
    None
  } else {
    Some(Double::from_int(serial))
  }
}

///|
fn excel_time_fraction(hours : Int, minutes : Int, seconds : Int) -> Double? {
  if hours < 0 || minutes < 0 || seconds < 0 {
    return None
  }
  let total = hours * 3600 + minutes * 60 + seconds
  let wrapped = total % 86400
  Some(Double::from_int(wrapped) / 86400.0)
}

///|
fn excel_serial_parts(
  value : FormulaValue,
) -> Result[(Int, Int, Int, Int, Int, Int), FormulaValue] {
  match value_as_number(value) {
    Ok(num) =>
      match excel_serial_to_parts(num) {
        Some(parts) => Ok(parts)
        None => Err(FormulaValue::Error(formula_error_num))
      }
    Err(err) => Err(err)
  }
}

///|
fn date_parts_from_serial(serial : Double) -> (Int, Int, Int)? {
  match excel_serial_to_parts(serial) {
    Some((year, month, day, _, _, _)) => Some((year, month, day))
    None => None
  }
}

///|
fn value_as_date_serial(value : FormulaValue) -> Result[Double, FormulaValue] {
  match normalize_scalar(value) {
    FormulaValue::Number(num) =>
      if num < 0.0 {
        Err(FormulaValue::Error(formula_error_num))
      } else {
        Ok(num)
      }
    FormulaValue::Bool(flag) => Ok(if flag { 1.0 } else { 0.0 })
    FormulaValue::Empty => Ok(0.0)
    FormulaValue::String(text) => {
      let trimmed = text.trim().to_string()
      match parse_date_parts(trimmed) {
        Some((year, month, day)) =>
          match excel_serial_from_date(year, month, day) {
            Some(serial) => Ok(serial)
            None => Err(FormulaValue::Error(formula_error_value))
          }
        None =>
          match parse_value_number(trimmed) {
            Some(num) =>
              if num < 0.0 {
                Err(FormulaValue::Error(formula_error_num))
              } else {
                Ok(num)
              }
            None => Err(FormulaValue::Error(formula_error_value))
          }
      }
    }
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    FormulaValue::List(_) => Err(FormulaValue::Error(formula_error_value))
  }
}

///|
fn date_parts_from_value(
  value : FormulaValue,
) -> Result[(Int, Int, Int), FormulaValue] {
  match value_as_date_serial(value) {
    Ok(serial) =>
      match date_parts_from_serial(serial) {
        Some(parts) => Ok(parts)
        None => Err(FormulaValue::Error(formula_error_num))
      }
    Err(err) => Err(err)
  }
}

///|
fn days_in_year(year : Int) -> Int {
  if is_leap_year(year) {
    366
  } else {
    365
  }
}

///|
fn day_of_year(year : Int, month : Int, day : Int) -> Int {
  days_before_month(year, month) + day
}

///|
fn weekday_monday1(year : Int, month : Int, day : Int) -> Int {
  let mut days = days_before_year(year)
  days = days + days_before_month(year, month)
  days = days + (day - 1)
  let mut idx = days % 7
  if idx < 0 {
    idx = idx + 7
  }
  idx + 1
}

///|
fn weekday_sun1(year : Int, month : Int, day : Int) -> Int {
  let monday = weekday_monday1(year, month, day)
  if monday == 7 {
    1
  } else {
    monday + 1
  }
}

///|
fn iso_week_number(year : Int, month : Int, day : Int) -> Int? {
  let serial = match excel_serial_from_date(year, month, day) {
    Some(value) => value
    None => return None
  }
  let weekday = weekday_monday1(year, month, day)
  let thursday_serial = serial + Double::from_int(4 - weekday)
  let (iso_year, _, _) = match date_parts_from_serial(thursday_serial) {
    Some(parts) => parts
    None => return None
  }
  let week1_serial = match excel_serial_from_date(iso_year, 1, 4) {
    Some(value) => value
    None => return None
  }
  let week1_weekday = weekday_monday1(iso_year, 1, 4)
  let week1_thursday = week1_serial + Double::from_int(4 - week1_weekday)
  let offset = (thursday_serial - week1_thursday) / 7.0
  Some(Double::to_int(Double::floor(offset)) + 1)
}

///|
fn weekend_mask_from_value(
  value : FormulaValue,
) -> Result[(Array[Int], Int), FormulaValue] {
  let weekend_mask : Array[Int] = [0, 0, 0, 0, 0, 0, 0]
  let mut workdays = 0
  let parse_code = fn(code : Int) -> Result[Unit, FormulaValue] {
    let indices = match code {
      1 => [5, 6]
      2 => [6, 0]
      3 => [0, 1]
      4 => [1, 2]
      5 => [2, 3]
      6 => [3, 4]
      7 => [4, 5]
      11 => [6]
      12 => [0]
      13 => [1]
      14 => [2]
      15 => [3]
      16 => [4]
      17 => [5]
      _ => return Err(FormulaValue::Error(formula_error_value))
    }
    for idx in indices {
      weekend_mask[idx] = 1
    }
    Ok(())
  }
  match normalize_scalar(value) {
    FormulaValue::String(text) => {
      let trimmed = text.trim().to_string()
      if trimmed.length() == 7 {
        let mut idx = 0
        for ch in trimmed {
          if ch == '0' {
            weekend_mask[idx] = 0
          } else if ch == '1' {
            weekend_mask[idx] = 1
          } else {
            return Err(FormulaValue::Error(formula_error_value))
          }
          idx = idx + 1
        }
      } else {
        match parse_value_number(trimmed) {
          Some(num) => {
            let code = Double::to_int(trunc_double(num))
            match parse_code(code) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          }
          None => return Err(FormulaValue::Error(formula_error_value))
        }
      }
    }
    _ =>
      match value_as_number(value) {
        Ok(num) => {
          let code = Double::to_int(trunc_double(num))
          match parse_code(code) {
            Ok(_) => ()
            Err(err) => return Err(err)
          }
        }
        Err(err) => return Err(err)
      }
  }
  for mask in weekend_mask {
    if mask == 0 {
      workdays = workdays + 1
    }
  }
  Ok((weekend_mask, workdays))
}

///|
fn is_workday_mask(weekend_mask : Array[Int], serial : Double) -> Bool {
  match date_parts_from_serial(serial) {
    Some((year, month, day)) => {
      let weekday = weekday_monday1(year, month, day)
      weekend_mask[weekday - 1] == 0
    }
    None => false
  }
}

///|
fn collect_holidays(value : FormulaValue) -> Array[Int] {
  let holidays : Array[Int] = []
  for item in flatten_values([value]) {
    match value_as_date_serial(item) {
      Ok(serial) => holidays.push(Double::to_int(Double::ceil(serial)))
      Err(_) => ()
    }
  }
  holidays
}

///|
fn workday_intl_adjust(
  end_date : Int,
  sign : Int,
  holidays : Array[Int],
  weekend_mask : Array[Int],
  start_serial : Double,
) -> Int {
  let mut adjusted = end_date
  for holiday in holidays {
    if sign > 0 {
      if holiday > adjusted {
        break
      }
      if holiday > Double::to_int(Double::ceil(start_serial)) {
        if is_workday_mask(weekend_mask, Double::from_int(holiday)) {
          adjusted = adjusted + sign
          while !is_workday_mask(weekend_mask, Double::from_int(adjusted)) {
            adjusted = adjusted + sign
          }
        }
      }
    } else {
      if holiday < adjusted {
        continue
      }
      if holiday < Double::to_int(Double::ceil(start_serial)) {
        if is_workday_mask(weekend_mask, Double::from_int(holiday)) {
          adjusted = adjusted + sign
          while !is_workday_mask(weekend_mask, Double::from_int(adjusted)) {
            adjusted = adjusted + sign
          }
        }
      }
    }
  }
  adjusted
}

///|
fn networkdays_intl_value(
  start_serial : Double,
  end_serial : Double,
  weekend_value : FormulaValue,
  holidays : Array[Int],
) -> FormulaValue {
  holidays.sort()
  let (weekend_mask, workdays) = match weekend_mask_from_value(weekend_value) {
    Ok(value) => value
    Err(err) => return err
  }
  if workdays == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let mut start = start_serial
  let mut end = end_serial
  let mut sign = 1
  if start > end {
    sign = -1
    let temp = start
    start = end
    end = temp
  }
  let offset = end - start
  let weeks = Double::to_int(Double::floor(offset / 7.0))
  let mut count = weeks * workdays
  let mut days_mod = Double::to_int(Double::floor(offset)) % 7
  while days_mod >= 0 {
    if is_workday_mask(weekend_mask, end - Double::from_int(days_mod)) {
      count = count + 1
    }
    days_mod = days_mod - 1
  }
  for holiday in holidays {
    let holiday_serial = Double::from_int(holiday)
    if is_workday_mask(weekend_mask, holiday_serial) &&
      holiday_serial >= start &&
      holiday_serial <= end {
      count = count - 1
    }
  }
  FormulaValue::Number(Double::from_int(sign * count))
}

///|
fn workday_intl_value(
  start_serial : Double,
  days : Double,
  weekend_value : FormulaValue,
  holidays : Array[Int],
) -> FormulaValue {
  holidays.sort()
  if days == 0.0 {
    return FormulaValue::Number(Double::ceil(start_serial))
  }
  let (weekend_mask, workdays) = match weekend_mask_from_value(weekend_value) {
    Ok(value) => value
    Err(err) => return err
  }
  if workdays == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let mut sign = 1
  if days < 0.0 {
    sign = -1
  }
  let days_int = Double::to_int(trunc_double(days))
  let offset = days_int / workdays
  let mut days_mod = days_int % workdays
  let mut end_date = Double::to_int(Double::ceil(start_serial)) + offset * 7
  if days_mod == 0 {
    while !is_workday_mask(weekend_mask, Double::from_int(end_date)) {
      end_date = end_date - sign
    }
  } else {
    while days_mod != 0 {
      end_date = end_date + sign
      if is_workday_mask(weekend_mask, Double::from_int(end_date)) {
        if days_mod < 0 {
          days_mod = days_mod + 1
        } else {
          days_mod = days_mod - 1
        }
      }
    }
  }
  let adjusted = workday_intl_adjust(
    end_date, sign, holidays, weekend_mask, start_serial,
  )
  FormulaValue::Number(Double::from_int(adjusted))
}

///|
fn yearfrac_basis_cond(
  sy : Int,
  sm : Int,
  sd : Int,
  ey : Int,
  em : Int,
  ed : Int,
) -> Bool {
  (is_leap_year(sy) && (sm < 2 || (sm == 2 && sd <= 29))) ||
  (is_leap_year(ey) && (em > 2 || (em == 2 && ed == 29)))
}

///|
fn yearfrac_basis0(
  start_serial : Double,
  end_serial : Double,
) -> (Double, Double) {
  let (sy, sm, sd) = match date_parts_from_serial(start_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let (ey, em, ed) = match date_parts_from_serial(end_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let mut start_day = sd
  let mut end_day = ed
  if start_day == 31 {
    start_day = 30
  }
  if start_day == 30 && end_day == 31 {
    end_day = 30
  } else if sm == 2 && start_day == days_in_month(sy, sm) {
    start_day = 30
    if em == 2 && end_day == days_in_month(ey, em) {
      end_day = 30
    }
  }
  let diff = (ey - sy) * 360 + (em - sm) * 30 + (end_day - start_day)
  (Double::from_int(diff), 360.0)
}

///|
fn yearfrac_basis1(
  start_serial : Double,
  end_serial : Double,
) -> (Double, Double) {
  let (sy, sm, sd) = match date_parts_from_serial(start_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let (ey, em, ed) = match date_parts_from_serial(end_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let day_diff = end_serial - start_serial
  let is_year_different = sy != ey
  let days_in_year_value = if is_year_different &&
    (ey != sy + 1 || sm < em || (sm == em && sd < ed)) {
    let mut day_count = 0
    for y in sy..<=ey {
      day_count = day_count + days_in_year(y)
    }
    Double::from_int(day_count) / Double::from_int(ey - sy + 1)
  } else if !is_year_different && is_leap_year(sy) {
    366.0
  } else if is_year_different && yearfrac_basis_cond(sy, sm, sd, ey, em, ed) {
    366.0
  } else {
    365.0
  }
  (day_diff, days_in_year_value)
}

///|
fn yearfrac_basis4(
  start_serial : Double,
  end_serial : Double,
) -> (Double, Double) {
  let (sy, sm, sd) = match date_parts_from_serial(start_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let (ey, em, ed) = match date_parts_from_serial(end_serial) {
    Some(parts) => parts
    None => return (0.0, 0.0)
  }
  let mut start_day = sd
  let mut end_day = ed
  if start_day == 31 {
    start_day = 30
  }
  if end_day == 31 {
    end_day = 30
  }
  let diff = (ey - sy) * 360 + (em - sm) * 30 + (end_day - start_day)
  (Double::from_int(diff), 360.0)
}

///|
fn yearfrac_value(
  start_serial : Double,
  end_serial : Double,
  basis : Int,
) -> FormulaValue {
  if start_serial == end_serial {
    return FormulaValue::Number(0.0)
  }
  let (day_diff, days_in_year) = match basis {
    0 => yearfrac_basis0(start_serial, end_serial)
    1 => yearfrac_basis1(start_serial, end_serial)
    2 => (end_serial - start_serial, 360.0)
    3 => (end_serial - start_serial, 365.0)
    4 => yearfrac_basis4(start_serial, end_serial)
    _ => return FormulaValue::Error(formula_error_num)
  }
  if days_in_year == 0.0 {
    FormulaValue::Error(formula_error_value)
  } else {
    FormulaValue::Number(day_diff / days_in_year)
  }
}

///|
fn gcd_double(left : Double, right : Double) -> Double {
  let mut x = trunc_double(left)
  let mut y = trunc_double(right)
  if x == 0.0 {
    return y
  }
  if y == 0.0 {
    return x
  }
  while x != y {
    if x > y {
      x = x - y
    } else {
      y = y - x
    }
  }
  x
}

///|
fn lcm_double(left : Double, right : Double) -> Double {
  let x = trunc_double(left)
  let y = trunc_double(right)
  if x == 0.0 && y == 0.0 {
    return 0.0
  }
  x * y / gcd_double(x, y)
}

///|
fn round_half_away_from_zero(value : Double) -> Double {
  if value < 0.0 {
    -Double::floor(-value + 0.5)
  } else {
    Double::floor(value + 0.5)
  }
}

///|
fn round_significant_digits(value : Double, digits : Int) -> Double {
  if value == 0.0 {
    return 0.0
  }
  let abs_value = Double::abs(value)
  let exponent = Double::floor(@math.log10(abs_value))
  let scale = @math.pow(10.0, Double::from_int(digits - 1) - exponent)
  round_half_away_from_zero(value * scale) / scale
}

///|
fn round_chisq_result(value : Double) -> Double {
  let abs_value = Double::abs(value)
  if abs_value >= 0.1 || abs_value < 0.01 {
    round_significant_digits(value, 15)
  } else {
    value
  }
}

///|
fn number_or_num_error(value : Double) -> FormulaValue {
  if Double::is_nan(value) || Double::is_inf(value) {
    FormulaValue::Error(formula_error_num)
  } else {
    FormulaValue::Number(value)
  }
}

///|
fn weibull_value(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let alpha = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let beta = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if alpha <= 0.0 || beta <= 0.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let exponent = @math.pow(x / beta, alpha)
  if cumulative {
    let result = 1.0 - @math.exp(-exponent)
    number_or_num_error(round_significant_digits(result, 15))
  } else {
    let denom = @math.pow(beta, alpha)
    let result = alpha /
      denom *
      @math.pow(x, alpha - 1.0) *
      @math.exp(-exponent)
    number_or_num_error(round_significant_digits(result, 15))
  }
}

///|
fn get_beta_helper_cont_frac(fx : Double, fa : Double, fb : Double) -> Double {
  let mut a1 = 1.0
  let mut b1 = 1.0
  let mut b2 = 1.0 - (fa + fb) / (fa + 1.0) * fx
  let mut a2 = 0.0
  let mut fnorm = 1.0
  let mut cf = 1.0
  if b2 == 0.0 {
    a2 = 0.0
    fnorm = 1.0
    cf = 1.0
  } else {
    a2 = 1.0
    fnorm = 1.0 / b2
    cf = a2 * fnorm
  }
  let mut cfnew = 1.0
  let mut rm = 1.0
  let max_iter = 50000.0
  let mach_eps = 2.22045e-016
  let mut finished = false
  while rm < max_iter && !finished {
    let apl2m = fa + 2.0 * rm
    let d2m = rm * (fb - rm) * fx / ((apl2m - 1.0) * apl2m)
    let d2m1 = -(fa + rm) * (fa + fb + rm) * fx / (apl2m * (apl2m + 1.0))
    a1 = (a2 + d2m * a1) * fnorm
    b1 = (b2 + d2m * b1) * fnorm
    a2 = a1 + d2m1 * a2 * fnorm
    b2 = b1 + d2m1 * b2 * fnorm
    if b2 != 0.0 {
      fnorm = 1.0 / b2
      cfnew = a2 * fnorm
      finished = Double::abs(cf - cfnew) < Double::abs(cf) * mach_eps
    }
    cf = cfnew
    rm = rm + 1.0
  }
  cf
}

///|
fn get_lanczos_sum(fz : Double) -> Double {
  let num : Array[Double] = [
    23531376880.41075968857200767445163675473, 42919803642.64909876895789904700198885093,
    35711959237.35566804944018545154716670596, 17921034426.03720969991975575445893111267,
    6039542586.35202800506429164430729792107, 1439720407.311721673663223072794912393972,
    248874557.8620541565114603864132294232163, 31426415.58540019438061423162831820536287,
    2876370.628935372441225409051620849613599, 186056.2653952234950402949897160456992822,
    8071.672002365816210638002902272250613822, 210.8242777515793458725097339207133627117,
    2.506628274631000270164908177133837338626,
  ]
  let denom : Array[Double] = [
    0.0, 39916800.0, 120543840.0, 150917976.0, 105258076.0, 45995730.0, 13339535.0,
    2637558.0, 357423.0, 32670.0, 1925.0, 66.0, 1.0,
  ]
  let mut sum_num = 0.0
  let mut sum_denom = 0.0
  if fz <= 1.0 {
    sum_num = num[12]
    sum_denom = denom[12]
    for i in 0..<12 {
      let idx = 11 - i
      sum_num = sum_num * fz + num[idx]
      sum_denom = sum_denom * fz + denom[idx]
    }
  } else {
    let z_inv = 1.0 / fz
    sum_num = num[0]
    sum_denom = denom[0]
    for i in 1..<=12 {
      sum_num = sum_num * z_inv + num[i]
      sum_denom = sum_denom * z_inv + denom[i]
    }
  }
  sum_num / sum_denom
}

///|
fn get_log_beta(falpha : Double, fbeta : Double) -> Double {
  let mut fa = falpha
  let mut fb = fbeta
  if falpha > fbeta {
    fa = falpha
    fb = fbeta
  } else {
    fa = fbeta
    fb = falpha
  }
  let fg = 6.024680040776729583740234375
  let fgm = fg - 0.5
  let mut lanczos = get_lanczos_sum(fa)
  lanczos = lanczos / get_lanczos_sum(fa + fb)
  lanczos = lanczos * get_lanczos_sum(fb)
  let mut log_lanczos = @math.ln(lanczos)
  let fabgm = fa + fb + fgm
  log_lanczos = log_lanczos +
    0.5 * (@math.ln(fabgm) - @math.ln(fa + fgm) - @math.ln(fb + fgm))
  let temp_a = fb / (fa + fgm)
  let temp_b = fa / (fb + fgm)
  let mut result = -fa * @math.ln_1p(temp_a) - fb * @math.ln_1p(temp_b) - fgm
  result = result + log_lanczos
  result
}

///|
fn get_beta(falpha : Double, fbeta : Double) -> Double {
  @math.exp(get_log_beta(falpha, fbeta))
}

///|
fn get_beta_dist_pdf(fx : Double, fa : Double, fb : Double) -> Double {
  if fx <= 0.0 || fx >= 1.0 {
    return 0.0
  }
  let log_dbl_max = @math.ln(1.79769e+308)
  let log_dbl_min = @math.ln(2.22507e-308)
  let mut log_y = @math.ln(0.5 - fx + 0.5)
  if fx < 0.1 {
    log_y = @math.ln_1p(-fx)
  }
  let log_x = @math.ln(fx)
  let a_log_x = (fa - 1.0) * log_x
  let b_log_y = (fb - 1.0) * log_y
  let log_beta = get_log_beta(fa, fb)
  if a_log_x < log_dbl_max &&
    a_log_x > log_dbl_min &&
    b_log_y < log_dbl_max &&
    b_log_y > log_dbl_min &&
    log_beta < log_dbl_max &&
    log_beta > log_dbl_min &&
    a_log_x + b_log_y < log_dbl_max &&
    a_log_x + b_log_y > log_dbl_min {
    @math.pow(fx, fa - 1.0) *
    @math.pow(0.5 - fx + 0.5, fb - 1.0) /
    get_beta(fa, fb)
  } else {
    @math.exp(a_log_x + b_log_y - log_beta)
  }
}

///|
fn get_beta_dist(fxin : Double, falpha : Double, fbeta : Double) -> Double {
  if fxin <= 0.0 {
    return 0.0
  }
  if fxin >= 1.0 {
    return 1.0
  }
  if fbeta == 1.0 {
    return @math.pow(fxin, falpha)
  }
  if falpha == 1.0 {
    return -@math.expm1(fbeta * @math.ln_1p(-fxin))
  }
  let mut fy = 0.5 - fxin + 0.5
  let mut f_x = fxin
  let mut ln_x = @math.ln(fxin)
  let mut ln_y = @math.ln_1p(-fxin)
  let mut fa = falpha
  let mut fb = fbeta
  let reflect = fxin > falpha / (falpha + fbeta)
  if reflect {
    fa = fbeta
    fb = falpha
    f_x = fy
    fy = fxin
    ln_x = ln_y
    ln_y = @math.ln(fxin)
  }
  let mut result = get_beta_helper_cont_frac(f_x, fa, fb) / fa
  let fp = fa / (fa + fb)
  let fq = fb / (fa + fb)
  let temp = if fa > 1.0 && fb > 1.0 && fp < 0.97 && fq < 0.97 {
    get_beta_dist_pdf(f_x, fa, fb) * f_x * fy
  } else {
    @math.exp(fa * ln_x + fb * ln_y - get_log_beta(fa, fb))
  }
  result = result * temp
  if reflect {
    result = 0.5 - result + 0.5
  }
  result
}

///|
fn get_t_dist(t : Double, df : Double, ntype : Double) -> Double {
  match ntype {
    1.0 => 0.5 * get_beta_dist(df / (df + t * t), df / 2.0, 0.5)
    2.0 => get_beta_dist(df / (df + t * t), df / 2.0, 0.5)
    3.0 =>
      @math.pow(1.0 + t * t / df, -(df + 1.0) / 2.0) /
      (Double::sqrt(df) * get_beta(0.5, df / 2.0))
    4.0 => {
      let x = df / (t * t + df)
      let r = 0.5 * get_beta_dist(x, 0.5 * df, 0.5)
      if t < 0.0 {
        r
      } else {
        1.0 - r
      }
    }
    _ => 0.0
  }
}

///|
fn get_gamma_series(fa : Double, fx : Double) -> Double {
  let half_eps = 2.22045e-016 / 2.0
  let mut denom = fa
  let mut summand = 1.0 / fa
  let mut sum = summand
  let mut count = 1
  while summand / sum > half_eps && count <= 10000 {
    denom = denom + 1.0
    summand = summand * fx / denom
    sum = sum + summand
    count = count + 1
  }
  sum
}

///|
fn get_gamma_cont_fraction(fa : Double, fx : Double) -> Double {
  let big_inv = 2.22045e-016
  let half_eps = big_inv / 2.0
  let big = 1.0 / big_inv
  let mut count = 0.0
  let mut y = 1.0 - fa
  let mut denom = fx + 2.0 - fa
  let mut pkm1 = fx + 1.0
  let mut pkm2 = 1.0
  let mut qkm1 = denom * fx
  let mut qkm2 = fx
  let mut approx = pkm1 / qkm1
  let mut finished = false
  while !finished && count < 10000.0 {
    count = count + 1.0
    y = y + 1.0
    denom = denom + 2.0
    let num = y * count
    let f1 = pkm1 * denom
    let f2 = pkm2 * num
    let pk = f1 - f2
    let f3 = qkm1 * denom
    let f4 = qkm2 * num
    let qk = f3 - f4
    if qk != 0.0 {
      let r = pk / qk
      finished = Double::abs((approx - r) / r) <= half_eps
      approx = r
    }
    pkm2 = pkm1
    pkm1 = pk
    qkm2 = qkm1
    qkm1 = qk
    if Double::abs(pk) > big {
      pkm2 = pkm2 * big_inv
      pkm1 = pkm1 * big_inv
      qkm2 = qkm2 * big_inv
      qkm1 = qkm1 * big_inv
    }
  }
  approx
}

///|
fn get_log_gamma_helper(fz : Double) -> Double {
  let fg = 6.024680040776729583740234375
  let zg_help = fz + fg - 0.5
  @math.ln(get_lanczos_sum(fz)) + (fz - 0.5) * @math.ln(zg_help) - zg_help
}

///|
fn get_gamma_helper(fz : Double) -> Double {
  let fg = 6.024680040776729583740234375
  let zg_help = fz + fg - 0.5
  let half_power = @math.pow(zg_help, fz / 2.0 - 0.25)
  let mut gamma = get_lanczos_sum(fz)
  gamma = gamma * half_power
  gamma = gamma / @math.exp(zg_help)
  gamma = gamma * half_power
  if fz <= 20.0 && fz == Double::floor(fz) {
    gamma = round_half_away_from_zero(gamma)
  }
  gamma
}

///|
fn get_log_gamma(fz : Double) -> Double {
  let max_gamma_argument = 171.624376956302
  if fz >= max_gamma_argument {
    return get_log_gamma_helper(fz)
  }
  if fz >= 1.0 {
    return @math.ln(get_gamma_helper(fz))
  }
  if fz >= 0.5 {
    return @math.ln(get_gamma_helper(fz + 1.0) / fz)
  }
  get_log_gamma_helper(fz + 2.0) - @math.ln(fz + 1.0) - @math.ln(fz)
}

///|
fn get_gamma(fz : Double) -> Double {
  @math.exp(get_log_gamma(fz))
}

///|
fn get_low_reg_igamma(fa : Double, fx : Double) -> Double {
  let ln_factor = fa * @math.ln(fx) - fx - get_log_gamma(fa)
  let factor = @math.exp(ln_factor)
  if fx > fa + 1.0 {
    1.0 - factor * get_gamma_cont_fraction(fa, fx)
  } else {
    factor * get_gamma_series(fa, fx)
  }
}

///|
fn get_chisq_dist_cdf(fx : Double, fdf : Double) -> Double {
  if fx <= 0.0 {
    return 0.0
  }
  get_low_reg_igamma(fdf / 2.0, fx / 2.0)
}

///|
fn get_chisq_dist_pdf(fx : Double, fdf : Double) -> Double {
  if fdf * fx > 1391000.0 {
    return @math.exp(
      (0.5 * fdf - 1.0) * @math.ln(fx * 0.5) -
      0.5 * fx -
      @math.ln(2.0) -
      get_log_gamma(0.5 * fdf),
    )
  }
  let mut count = 0.0
  let mut value = 0.0
  let fdf_mod = fdf - Double::floor(fdf / 2.0) * 2.0
  if fdf_mod < 0.5 {
    value = 0.5
    count = 2.0
  } else {
    value = 1.0 / Double::sqrt(fx * 2.0 * @math.PI)
    count = 1.0
  }
  while count < fdf {
    value = value * fx / count
    count = count + 2.0
  }
  if fx >= 1425.0 {
    @math.exp(@math.ln(value) - fx / 2.0)
  } else {
    value * @math.exp(-fx / 2.0)
  }
}

///|
fn get_norm_s_dist(value : Double) -> Double {
  0.5 * erfc_double(-value / Double::sqrt(2.0))
}

///|
fn norm_pdf(value : Double, mean : Double, std_dev : Double) -> Double {
  let z = (value - mean) / std_dev
  let denom = Double::sqrt(2.0 * @math.PI) * std_dev
  @math.exp(-0.5 * z * z) / denom
}

///|
fn norm_cdf(value : Double, mean : Double, std_dev : Double) -> Double {
  get_norm_s_dist((value - mean) / std_dev)
}

///|
let norminv_a : Array[Double] = [
  -39.69683028665376, 220.9460984245205, -275.9285104469687, 138.357751867269, -30.66479806614716,
  2.506628277459239,
]

///|
let norminv_b : Array[Double] = [
  -54.47609879822406, 161.5858368580409, -155.6989798598866, 66.80131188771972, -13.28068155288572,
]

///|
let norminv_c : Array[Double] = [
  -0.007784894002430293, -0.3223964580411365, -2.400758277161838, -2.549732539343734,
  4.374664141464968, 2.938163982698783,
]

///|
let norminv_d : Array[Double] = [
  0.007784695709041462, 0.3224671290700398, 2.445134137142996, 3.754408661907416,
]

///|
fn norminv_double(prob : Double) -> Result[Double, FormulaValue] {
  let p_low = 0.02425
  let p_high = 1.0 - p_low
  if prob > 0.0 && prob < p_low {
    let q = Double::sqrt(-2.0 * @math.ln(prob))
    let numerator = (
        (
          ((norminv_c[0] * q + norminv_c[1]) * q + norminv_c[2]) * q +
          norminv_c[3]
        ) *
        q +
        norminv_c[4]
      ) *
      q +
      norminv_c[5]
    let denominator = (
        ((norminv_d[0] * q + norminv_d[1]) * q + norminv_d[2]) * q +
        norminv_d[3]
      ) *
      q +
      1.0
    Ok(numerator / denominator)
  } else if prob >= p_low && prob <= p_high {
    let q = prob - 0.5
    let r = q * q
    let numerator = (
        (
          (
            ((norminv_a[0] * r + norminv_a[1]) * r + norminv_a[2]) * r +
            norminv_a[3]
          ) *
          r +
          norminv_a[4]
        ) *
        r +
        norminv_a[5]
      ) *
      q
    let denominator = (
        (
          ((norminv_b[0] * r + norminv_b[1]) * r + norminv_b[2]) * r +
          norminv_b[3]
        ) *
        r +
        norminv_b[4]
      ) *
      r +
      1.0
    Ok(numerator / denominator)
  } else if prob > p_high && prob < 1.0 {
    let q = Double::sqrt(-2.0 * @math.ln(1.0 - prob))
    let numerator = (
        (
          ((norminv_c[0] * q + norminv_c[1]) * q + norminv_c[2]) * q +
          norminv_c[3]
        ) *
        q +
        norminv_c[4]
      ) *
      q +
      norminv_c[5]
    let denominator = (
        ((norminv_d[0] * q + norminv_d[1]) * q + norminv_d[2]) * q +
        norminv_d[3]
      ) *
      q +
      1.0
    Ok(-numerator / denominator)
  } else {
    Err(FormulaValue::Error(formula_error_num))
  }
}

///|
fn get_chidist(x : Double, degrees : Double) -> Double {
  let log_sqrt_pi = @math.ln(Double::sqrt(@math.PI))
  let sqrt_pi = 1.0 / Double::sqrt(@math.PI)
  let mut e = 0.0
  let mut s = 0.0
  let mut z = 0.0
  let mut c = 0.0
  let mut y = 0.0
  let a = x / 2.0
  let mut x1 = x
  let even = Double::to_int(trunc_double(degrees)) % 2 == 0
  if degrees > 1.0 {
    y = @math.exp(-a)
  }
  s = 2.0 * get_norm_s_dist(-Double::sqrt(x1))
  if even {
    s = y
  }
  if degrees > 2.0 {
    x1 = (degrees - 1.0) / 2.0
    z = if even { 1.0 } else { 0.5 }
    if a > 20.0 {
      e = if even { 0.0 } else { log_sqrt_pi }
      c = @math.ln(a)
      while z <= x1 {
        e = @math.ln(z) + e
        s = s + @math.exp(c * z - a - e)
        z = z + 1.0
      }
      return s
    }
    e = if even { 1.0 } else { sqrt_pi / Double::sqrt(a) }
    c = 0.0
    while z <= x1 {
      e = e * (a / z)
      c = c + e
      z = z + 1.0
    }
    return c * y + s
  }
  s
}

///|
fn get_f_dist_cdf(x : Double, deg1 : Double, deg2 : Double) -> Double {
  1.0 - get_beta_dist(deg2 / (deg2 + deg1 * x), deg2 / 2.0, deg1 / 2.0)
}

///|
fn get_f_dist_pdf(x : Double, deg1 : Double, deg2 : Double) -> Double {
  let half_sum = (deg1 + deg2) / 2.0
  let gamma_num = get_gamma(half_sum)
  let gamma_den = get_gamma(deg1 / 2.0) * get_gamma(deg2 / 2.0)
  let scale = @math.pow(deg1 / deg2, deg1 / 2.0)
  let numerator = @math.pow(x, (deg1 - 2.0) / 2.0)
  let denominator = @math.pow(1.0 + deg1 / deg2 * x, half_sum)
  gamma_num / gamma_den * scale * (numerator / denominator)
}

///|
fn get_f_dist_rt(x : Double, deg1 : Double, deg2 : Double) -> Double {
  1.0 - get_beta_dist(deg1 * x / (deg1 * x + deg2), deg1 / 2.0, deg2 / 2.0)
}

///|
fn has_change_of_sign(u : Double, w : Double) -> Bool {
  (u < 0.0 && w > 0.0) || (u > 0.0 && w < 0.0)
}

///|
priv enum InverseKind {
  TDist
  ChiSq
}

///|
priv struct InverseIterator {
  fp : Double
  fdf : Double
  nt : Double
  kind : InverseKind
}

///|
fn InverseIterator::call(self : InverseIterator, x : Double) -> Double {
  match self.kind {
    InverseKind::ChiSq => self.fp - get_chisq_dist_cdf(x, self.fdf)
    InverseKind::TDist => self.fp - get_t_dist(x, self.fdf, self.nt)
  }
}

///|
fn inverse_quadratic_interpolation(
  iterator : InverseIterator,
  ax_in : Double,
  ay_in : Double,
  bx_in : Double,
  by_in : Double,
) -> Double {
  let y_eps = 1.0e-307
  let x_eps = 2.22045e-016
  let mut ax = ax_in
  let mut ay = ay_in
  let mut bx = bx_in
  let mut by = by_in
  let mut px = ax
  let mut py = ay
  let mut qx = bx
  let mut qy = by
  let mut rx = ax
  let mut ry = ay
  let mut sx = 0.5 * (ax + bx)
  let mut has_to_interpolate = true
  let mut count = 0
  while count < 500 &&
        Double::abs(ry) > y_eps &&
        bx - ax >
        (if Double::abs(ax) > Double::abs(bx) {
          Double::abs(ax)
        } else {
          Double::abs(bx)
        }) *
        x_eps {
    if has_to_interpolate {
      if py != qy && qy != ry && ry != py {
        sx = px * ry * qy / (ry - py) / (qy - py) +
          rx * qy * py / (qy - ry) / (py - ry) +
          qx * py * ry / (py - qy) / (ry - qy)
        has_to_interpolate = ax < sx && sx < bx
      } else {
        has_to_interpolate = false
      }
    }
    if !has_to_interpolate {
      sx = 0.5 * (ax + bx)
      qx = bx
      qy = by
      has_to_interpolate = true
    }
    px = qx
    qx = rx
    rx = sx
    py = qy
    qy = ry
    ry = iterator.call(rx)
    if has_change_of_sign(ay, ry) {
      bx = rx
      by = ry
    } else {
      ax = rx
      ay = ry
    }
    has_to_interpolate = has_to_interpolate &&
      Double::abs(ry) * 2.0 <= Double::abs(qy)
    count = count + 1
  }
  rx
}

///|
fn calc_iterate_inverse(
  iterator : InverseIterator,
  ax_in : Double,
  bx_in : Double,
) -> Double {
  let mut ax = ax_in
  let mut bx = bx_in
  let mut ay = iterator.call(ax)
  let mut by = iterator.call(bx)
  let mut count = 0
  while count < 1000 && !has_change_of_sign(ay, by) {
    if Double::abs(ay) <= Double::abs(by) {
      let temp = ax
      ax = ax + 2.0 * (ax - bx)
      if ax < 0.0 {
        ax = 0.0
      }
      bx = temp
      by = ay
      ay = iterator.call(ax)
    } else {
      let temp = bx
      bx = bx + 2.0 * (bx - ax)
      ax = temp
      ay = by
      by = iterator.call(bx)
    }
    count = count + 1
  }
  if ay == 0.0 || by == 0.0 {
    0.0
  } else {
    inverse_quadratic_interpolation(iterator, ax, ay, bx, by)
  }
}

///|
fn erf_double(value : Double) -> Double {
  if value == 0.0 {
    return 0.0
  }
  let mut x = value
  let mut sign = 1.0
  if x < 0.0 {
    sign = -1.0
    x = -x
  }
  let x2 = x * x
  let mut term = x
  let mut sum = term
  let mut n = 1
  let max_iter = 2000
  let threshold = @math.pow(10.0, -18.0)
  while n < max_iter && Double::abs(term) > threshold {
    let n_int = n
    let numerator = -x2 * Double::from_int(2 * n_int - 1)
    let denominator = Double::from_int(n_int * (2 * n_int + 1))
    term = term * numerator / denominator
    sum = sum + term
    n = n + 1
  }
  let scale = 2.0 / Double::sqrt(@math.PI)
  sign * scale * sum
}

///|
fn erfc_double(value : Double) -> Double {
  1.0 - erf_double(value)
}

///|
fn fisher_value(value : FormulaValue) -> FormulaValue {
  let num = match value_as_number(value) {
    Ok(num) => num
    Err(err) => return err
  }
  if num <= -1.0 || num >= 1.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let result = 0.5 * @math.ln((1.0 + num) / (1.0 - num))
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn fisherinv_value(value : FormulaValue) -> FormulaValue {
  let num = match value_as_number(value) {
    Ok(num) => num
    Err(err) => return err
  }
  let exp_val = @math.exp(2.0 * num)
  let result = (exp_val - 1.0) / (exp_val + 1.0)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn bessel_bassel(x : Double, n : Double, modified : Bool) -> Double {
  let mut x1 = x * 0.5
  let x2 = x1 * x1
  x1 = @math.pow(x1, n)
  let mut n1 = factorial_double(n)
  let mut n2 = 1.0
  let mut n3 = 0.0
  let mut n4 = n
  let mut add = false
  let mut result = x1 / n1
  let mut prev = result * 0.9
  let mut iter = 100
  while result != prev && iter != 0 {
    x1 = x1 * x2
    n3 = n3 + 1.0
    n1 = n1 * n3
    n4 = n4 + 1.0
    n2 = n2 * n4
    prev = result
    let term = x1 / n1 / n2
    if modified || add {
      result = result + term
    } else {
      result = result - term
    }
    iter = iter - 1
    add = !add
  }
  result
}

///|
fn bessel_i(x : Double, n : Double) -> Double {
  bessel_bassel(x, n, true)
}

///|
fn bessel_j(x : Double, n : Double) -> Double {
  bessel_bassel(x, n, false)
}

///|
fn bessel_k0(x : Double) -> Double {
  if x <= 2.0 {
    let n2 = x * 0.5
    let y = n2 * n2
    -@math.ln(n2) * bessel_i(x, 0.0) +
    (
      -0.57721566 +
      y *
      (
        0.42278420 +
        y *
        (
          0.23069756 +
          y * (0.0348859 + y * (0.00262698 + y * (0.0001075 + y * 0.0000074)))
        )
      )
    )
  } else {
    let y = 2.0 / x
    @math.exp(-x) /
    Double::sqrt(x) *
    (
      1.25331414 +
      y *
      (
        -0.07832358 +
        y *
        (
          0.02189568 +
          y *
          (-0.01062446 + y * (0.00587872 + y * (-0.0025154 + y * 0.00053208)))
        )
      )
    )
  }
}

///|
fn bessel_k1(x : Double) -> Double {
  if x <= 2.0 {
    let n2 = x * 0.5
    let y = n2 * n2
    @math.ln(n2) * bessel_i(x, 1.0) +
    (
      1.0 +
      y *
      (
        0.15443144 +
        y *
        (
          -0.67278579 +
          y *
          (
            -0.18156897 +
            y * (-0.01919402 + y * (-0.00110404 + y * -0.00004686))
          )
        )
      )
    ) /
    x
  } else {
    let y = 2.0 / x
    @math.exp(-x) /
    Double::sqrt(x) *
    (
      1.25331414 +
      y *
      (
        0.23498619 +
        y *
        (
          -0.0365562 +
          y *
          (0.01504268 + y * (-0.00780353 + y * (0.00325614 + y * -0.00068245)))
        )
      )
    )
  }
}

///|
fn bessel_k2(x : Double, n : Double) -> Double {
  let tox = 2.0 / x
  let mut bkm = bessel_k0(x)
  let mut bk = bessel_k1(x)
  let mut bkp = 0.0
  let mut i = 1.0
  while i < n {
    bkp = bkm + i * tox * bk
    bkm = bk
    bk = bkp
    i = i + 1.0
  }
  bk
}

///|
fn bessel_y0(x : Double) -> Double {
  if x < 8.0 {
    let y = x * x
    let f1 = -2957821389.0 +
      y *
      (
        7062834065.0 +
        y *
        (
          -512359803.6 +
          y * (10879881.29 + y * (-86327.92757 + y * 228.4622733))
        )
      )
    let f2 = 40076544269.0 +
      y *
      (
        745249964.8 +
        y * (7189466.438 + y * (47447.26470 + y * (226.1030244 + y)))
      )
    f1 / f2 + 0.636619772 * bessel_j(x, 0.0) * @math.ln(x)
  } else {
    let z = 8.0 / x
    let y = z * z
    let xx = x - 0.785398164
    let f1 = 1.0 +
      y *
      (
        -0.001098628627 +
        y *
        (0.00002734510407 + y * (-0.000002073370639 + y * 0.0000002093887211))
      )
    let f2 = -0.01562499995 +
      y *
      (
        0.0001430488765 +
        y *
        (
          -0.000006911147651 +
          y * (0.0000007621095161 + y * -0.0000000934945152)
        )
      )
    Double::sqrt(0.636619772 / x) *
    (@math.sin(xx) * f1 + z * @math.cos(xx) * f2)
  }
}

///|
fn bessel_y1(x : Double) -> Double {
  if x < 8.0 {
    let y = x * x
    let f1 = x *
      (
        -4900604943000.0 +
        y *
        (
          1275274390000.0 +
          y *
          (
            -51534381390.0 +
            y * (734926455.1 + y * (-4237922.726 + y * 8511.937935))
          )
        )
      )
    let f2 = 24995805700000.0 +
      y *
      (
        424441966400.0 +
        y *
        (
          3733650367.0 +
          y * (22459040.02 + y * (102042.605 + y * (354.9632885 + y)))
        )
      )
    f1 / f2 + 0.636619772 * (bessel_j(x, 1.0) * @math.ln(x) - 1.0 / x)
  } else {
    Double::sqrt(0.636619772 / x) * @math.sin(x - 2.356194491)
  }
}

///|
fn bessel_y2(x : Double, n : Double) -> Double {
  let tox = 2.0 / x
  let mut bym = bessel_y0(x)
  let mut by = bessel_y1(x)
  let mut byp = 0.0
  let mut i = 1.0
  while i < n {
    byp = i * tox * by - bym
    bym = by
    by = byp
    i = i + 1.0
  }
  by
}

///|
fn round_with_digits(value : Double, digits : Int) -> Double {
  if digits >= 0 {
    let scale = Double::from_int(pow10_int(digits))
    round_half_away_from_zero(value * scale) / scale
  } else {
    let scale = Double::from_int(pow10_int(-digits))
    round_half_away_from_zero(value / scale) * scale
  }
}

///|
fn round_down_with_digits(value : Double, digits : Int) -> Double {
  if digits >= 0 {
    let scale = Double::from_int(pow10_int(digits))
    trunc_double(value * scale) / scale
  } else {
    let scale = Double::from_int(pow10_int(-digits))
    trunc_double(value / scale) * scale
  }
}

///|
fn round_up_with_digits(value : Double, digits : Int) -> Double {
  if digits >= 0 {
    let scale = Double::from_int(pow10_int(digits))
    let scaled = value * scale
    let truncated = trunc_double(scaled)
    let adjusted = if scaled == truncated {
      truncated
    } else if scaled > 0.0 {
      truncated + 1.0
    } else {
      truncated - 1.0
    }
    adjusted / scale
  } else {
    let scale = Double::from_int(pow10_int(-digits))
    let scaled = value / scale
    let truncated = trunc_double(scaled)
    let adjusted = if scaled == truncated {
      truncated
    } else if scaled > 0.0 {
      truncated + 1.0
    } else {
      truncated - 1.0
    }
    adjusted * scale
  }
}

///|
fn trim_excel_text(text : StringView) -> String {
  let sb = StringBuilder::new()
  let mut seen_text = false
  let mut pending_space = false
  for ch in text {
    if ch.is_ascii_whitespace() {
      if seen_text {
        pending_space = true
      }
    } else {
      if pending_space {
        sb.write_char(' ')
        pending_space = false
      }
      sb.write_char(ch)
      seen_text = true
    }
  }
  sb.to_string()
}

///|
fn eval_expr(
  workbook : Workbook,
  sheet_name : String,
  expr : Expr,
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  match expr {
    Expr::Number(num) => FormulaValue::Number(num)
    Expr::String(text) => FormulaValue::String(text)
    Expr::Bool(value) => FormulaValue::Bool(value)
    Expr::Cell(sheet, reference) =>
      resolve_cell_value(
        workbook,
        if sheet == "" {
          sheet_name
        } else {
          sheet
        },
        reference,
        ctx,
      )
    Expr::Range(sheet, start_ref, end_ref) =>
      FormulaValue::List(
        collect_range_values(
          workbook,
          if sheet == "" {
            sheet_name
          } else {
            sheet
          },
          start_ref,
          end_ref,
          ctx,
        ),
      )
    Expr::Unary(op, inner) =>
      eval_unary(op, eval_expr(workbook, sheet_name, inner, ctx))
    Expr::Binary(op, left, right) =>
      eval_binary(
        op,
        eval_expr(workbook, sheet_name, left, ctx),
        eval_expr(workbook, sheet_name, right, ctx),
      )
    Expr::FuncCall(name, args) =>
      eval_function(workbook, sheet_name, name, args, ctx)
    Expr::List(items) => {
      let out : Array[FormulaValue] = []
      for item in items {
        out.push(eval_expr(workbook, sheet_name, item, ctx))
      }
      FormulaValue::List(out)
    }
  }
}

///|
fn eval_unary(op : UnaryOp, value : FormulaValue) -> FormulaValue {
  match op {
    UnaryOp::Plus => value
    UnaryOp::Minus =>
      match value_as_number(value) {
        Ok(num) => FormulaValue::Number(-num)
        Err(err) => err
      }
    UnaryOp::Percent =>
      match value_as_number(value) {
        Ok(num) => FormulaValue::Number(num / 100.0)
        Err(err) => err
      }
  }
}

///|
fn eval_binary(
  op : BinaryOp,
  left : FormulaValue,
  right : FormulaValue,
) -> FormulaValue {
  match op {
    BinaryOp::Concat =>
      FormulaValue::String(
        formula_value_string(left) + formula_value_string(right),
      )
    BinaryOp::Eq
    | BinaryOp::Ne
    | BinaryOp::Lt
    | BinaryOp::Le
    | BinaryOp::Gt
    | BinaryOp::Ge =>
      match compare_values(left, right) {
        Ok(result) => {
          let ok = match op {
            BinaryOp::Eq => result == 0
            BinaryOp::Ne => result != 0
            BinaryOp::Lt => result < 0
            BinaryOp::Le => result <= 0
            BinaryOp::Gt => result > 0
            BinaryOp::Ge => result >= 0
            _ => false
          }
          FormulaValue::Bool(ok)
        }
        Err(err) => err
      }
    _ =>
      match (value_as_number(left), value_as_number(right)) {
        (Ok(lhs), Ok(rhs)) =>
          match op {
            BinaryOp::Add => FormulaValue::Number(lhs + rhs)
            BinaryOp::Sub => FormulaValue::Number(lhs - rhs)
            BinaryOp::Mul => FormulaValue::Number(lhs * rhs)
            BinaryOp::Div =>
              if rhs == 0.0 {
                FormulaValue::Error(formula_error_div)
              } else {
                FormulaValue::Number(lhs / rhs)
              }
            BinaryOp::Pow => FormulaValue::Number(@math.pow(lhs, rhs))
            _ => FormulaValue::Error(formula_error_value)
          }
        (Err(err), _) => err
        (_, Err(err)) => err
      }
  }
}

///|
fn eval_function(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if name == "ROW" {
    return if args.length() == 0 {
      match current_cell_rc(ctx) {
        Some((row, _col)) => FormulaValue::Number(Double::from_int(row))
        None => FormulaValue::Error(formula_error_value)
      }
    } else if args.length() == 1 {
      match ref_bounds_opt(args[0]) {
        Some((row1, _col1, row2, _col2)) => {
          let row = if row1 < row2 { row1 } else { row2 }
          FormulaValue::Number(Double::from_int(row))
        }
        None => FormulaValue::Error(formula_error_value)
      }
    } else {
      FormulaValue::Error(formula_error_value)
    }
  }
  if name == "COLUMN" {
    return if args.length() == 0 {
      match current_cell_rc(ctx) {
        Some((_row, col)) => FormulaValue::Number(Double::from_int(col))
        None => FormulaValue::Error(formula_error_value)
      }
    } else if args.length() == 1 {
      match ref_bounds_opt(args[0]) {
        Some((_row1, col1, _row2, col2)) => {
          let col = if col1 < col2 { col1 } else { col2 }
          FormulaValue::Number(Double::from_int(col))
        }
        None => FormulaValue::Error(formula_error_value)
      }
    } else {
      FormulaValue::Error(formula_error_value)
    }
  }
  if name == "ROWS" {
    return if args.length() == 1 {
      match ref_bounds_opt(args[0]) {
        Some((row1, _col1, row2, _col2)) => {
          let min_row = if row1 < row2 { row1 } else { row2 }
          let max_row = if row1 > row2 { row1 } else { row2 }
          FormulaValue::Number(Double::from_int(max_row - min_row + 1))
        }
        None => FormulaValue::Error(formula_error_value)
      }
    } else {
      FormulaValue::Error(formula_error_value)
    }
  }
  if name == "COLUMNS" {
    return if args.length() == 1 {
      match ref_bounds_opt(args[0]) {
        Some((_row1, col1, _row2, col2)) => {
          let min_col = if col1 < col2 { col1 } else { col2 }
          let max_col = if col1 > col2 { col1 } else { col2 }
          FormulaValue::Number(Double::from_int(max_col - min_col + 1))
        }
        None => FormulaValue::Error(formula_error_value)
      }
    } else {
      FormulaValue::Error(formula_error_value)
    }
  }
  if name == "FORMULATEXT" {
    return if args.length() == 1 {
      formula_text_value(workbook, sheet_name, args[0])
    } else {
      FormulaValue::Error(formula_error_value)
    }
  }
  let values : Array[FormulaValue] = []
  for arg in args {
    values.push(eval_expr(workbook, sheet_name, arg, ctx))
  }
  match name {
    "TRUE" => FormulaValue::Bool(true)
    "FALSE" => FormulaValue::Bool(false)
    "SUM" => sum_values(values)
    "SUBTOTAL" => subtotal_values(values)
    "PRODUCT" => product_values(values)
    "AVERAGE" => average_values(values)
    "AVERAGEA" => averagea_values(values)
    "STDEV" | "STDEV.S" =>
      if values.length() >= 1 {
        stdev_values(false, values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "STDEVA" =>
      if values.length() >= 1 {
        stdev_values(true, values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "STDEVP" | "STDEV.P" =>
      if values.length() >= 1 {
        match variance_values(values, false, false) {
          FormulaValue::Number(variance) => {
            let result = @math.pow(variance, 0.5)
            FormulaValue::Number(round_significant_digits(result, 15))
          }
          FormulaValue::Error(err) => FormulaValue::Error(err)
          _ => FormulaValue::Error(formula_error_value)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "STDEVPA" =>
      if values.length() >= 1 {
        match variance_values(values, false, true) {
          FormulaValue::Number(variance) => {
            let result = @math.pow(variance, 0.5)
            FormulaValue::Number(round_significant_digits(result, 15))
          }
          FormulaValue::Error(err) => FormulaValue::Error(err)
          _ => FormulaValue::Error(formula_error_value)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "VAR" | "VAR.S" =>
      if values.length() >= 1 {
        variance_values(values, true, false)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "VARA" =>
      if values.length() >= 1 {
        variance_values(values, true, true)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "VARP" | "VAR.P" =>
      if values.length() >= 1 {
        variance_values(values, false, false)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "VARPA" =>
      if values.length() >= 1 {
        variance_values(values, false, true)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TRIMMEAN" => trimmean_values(values)
    "AVEDEV" =>
      if values.length() >= 1 {
        avedev_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DEVSQ" =>
      if values.length() >= 1 {
        devsq_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "GEOMEAN" =>
      if values.length() >= 1 {
        geomean_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "HARMEAN" =>
      if values.length() >= 1 {
        harmean_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "KURT" =>
      if values.length() >= 1 {
        kurt_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SKEW" =>
      if values.length() >= 1 {
        skew_values("SKEW", values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SKEW.P" =>
      if values.length() >= 1 {
        skew_values("SKEW.P", values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "STANDARDIZE" =>
      if values.length() == 3 {
        standardize_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "LARGE" =>
      if values.length() == 2 {
        kth_values("LARGE", values[0], values[1])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SMALL" =>
      if values.length() == 2 {
        kth_values("SMALL", values[0], values[1])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MODE" =>
      if values.length() >= 1 {
        mode_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MODE.SNGL" =>
      if values.length() >= 1 {
        mode_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MODE.MULT" =>
      if values.length() >= 1 {
        mode_mult_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "PERCENTILE" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(k) =>
            if k < 0.0 || k > 1.0 {
              FormulaValue::Error(formula_error_na)
            } else {
              percentile_values(values[0], k, false, false)
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "PERCENTILE.INC" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(k) =>
            if k < 0.0 || k > 1.0 {
              FormulaValue::Error(formula_error_na)
            } else {
              percentile_values(values[0], k, false, false)
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "PERCENTILE.EXC" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(k) =>
            if k <= 0.0 || k >= 1.0 {
              FormulaValue::Error(formula_error_num)
            } else {
              percentile_values(values[0], k, true, true)
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "PERCENTRANK" =>
      if values.length() == 2 || values.length() == 3 {
        match value_as_number(values[1]) {
          Ok(x) => {
            let significance = if values.length() == 3 {
              match value_as_number(values[2]) {
                Ok(num) => num
                Err(err) => return err
              }
            } else {
              3.0
            }
            percentrank_values("PERCENTRANK", values[0], x, significance)
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "PERCENTRANK.INC" =>
      if values.length() == 2 || values.length() == 3 {
        match value_as_number(values[1]) {
          Ok(x) => {
            let significance = if values.length() == 3 {
              match value_as_number(values[2]) {
                Ok(num) => num
                Err(err) => return err
              }
            } else {
              3.0
            }
            percentrank_values("PERCENTRANK.INC", values[0], x, significance)
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "PERCENTRANK.EXC" =>
      if values.length() == 2 || values.length() == 3 {
        match value_as_number(values[1]) {
          Ok(x) => {
            let significance = if values.length() == 3 {
              match value_as_number(values[2]) {
                Ok(num) => num
                Err(err) => return err
              }
            } else {
              3.0
            }
            percentrank_values("PERCENTRANK.EXC", values[0], x, significance)
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "QUARTILE" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(quart) => quartile_values("QUARTILE", values[0], quart, false)
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "QUARTILE.INC" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(quart) => quartile_values("QUARTILE.INC", values[0], quart, false)
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "QUARTILE.EXC" =>
      if values.length() == 2 {
        match value_as_number(values[1]) {
          Ok(quart) => quartile_values("QUARTILE.EXC", values[0], quart, true)
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "RANK" | "RANK.EQ" =>
      if values.length() == 2 || values.length() == 3 {
        let order = if values.length() == 3 {
          match value_as_number(values[2]) {
            Ok(num) => Some(num)
            Err(err) => return err
          }
        } else {
          None
        }
        rank_values(values[0], values[1], order)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SIGN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            FormulaValue::Number(
              if num < 0.0 {
                -1.0
              } else if num > 0.0 {
                1.0
              } else {
                0.0
              },
            )
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SERIESSUM" =>
      if values.length() == 4 {
        let x = match value_as_number(values[0]) {
          Ok(num) => num
          Err(err) => return err
        }
        let n = match value_as_number(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let m = match value_as_number(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        let coefficients = list_from_value(values[3])
        let mut result = 0.0
        let mut idx = 0.0
        for coefficient in coefficients {
          if formula_value_string(coefficient) == "" {
            continue
          }
          let num = match value_as_number(coefficient) {
            Ok(num) => num
            Err(err) => return err
          }
          result = result + num * @math.pow(x, n + m * idx)
          idx = idx + 1.0
        }
        FormulaValue::Number(round_significant_digits(result, 15))
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "CORREL" =>
      if values.length() == 2 {
        correl_values(values[0], values[1])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "COVAR" =>
      if values.length() == 2 {
        covar_values("COVAR", values[0], values[1])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "COVARIANCE.P" =>
      if values.length() == 2 {
        covar_values("COVARIANCE.P", values[0], values[1])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "COVARIANCE.S" =>
      if values.length() == 2 {
        covar_values("COVARIANCE.S", values[0], values[1])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "PEARSON" =>
      if values.length() == 2 {
        pearson_product_values("PEARSON", values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "RSQ" =>
      if values.length() == 2 {
        pearson_product_values("RSQ", values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SLOPE" =>
      if values.length() == 2 {
        pearson_product_values("SLOPE", values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "INTERCEPT" =>
      if values.length() == 2 {
        pearson_product_values("INTERCEPT", values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "FORECAST" =>
      if values.length() == 3 {
        pearson_product_values("FORECAST", values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "FORECAST.LINEAR" =>
      if values.length() == 3 {
        pearson_product_values("FORECAST.LINEAR", values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "GROWTH" =>
      trend_growth_values(workbook, sheet_name, "GROWTH", args, values, ctx)
    "TREND" =>
      trend_growth_values(workbook, sheet_name, "TREND", args, values, ctx)
    "FISHER" =>
      if values.length() == 1 {
        fisher_value(values[0])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "FISHERINV" =>
      if values.length() == 1 {
        fisherinv_value(values[0])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "STEYX" =>
      if values.length() == 2 {
        steyx_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MEDIAN" => median_values(values)
    "MIN" => min_values(values)
    "MAX" => max_values(values)
    "MINA" => mina_values(values)
    "MAXA" => maxa_values(values)
    "COUNT" => count_values(values)
    "COUNTA" => counta_values(values)
    "COUNTBLANK" =>
      if args.length() == 1 {
        let range_values = eval_range_expr(workbook, sheet_name, args[0], ctx)
        countblank_values(range_values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "FREQUENCY" => frequency_values(workbook, sheet_name, args, values, ctx)
    "COUNTIF" =>
      if args.length() == 2 {
        let range_values = eval_range_expr(workbook, sheet_name, args[0], ctx)
        countif_values(range_values, values[1])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "COUNTIFS" =>
      if args.length() >= 2 {
        if args.length() % 2 != 0 {
          FormulaValue::Error(formula_error_na)
        } else {
          let ranges : Array[RangeValues] = []
          let criterias : Array[FormulaCriteria] = []
          for i in 0..<(args.length() / 2) {
            let range_values = eval_range_expr(
              workbook,
              sheet_name,
              args[i * 2],
              ctx,
            )
            ranges.push(range_values)
            criterias.push(parse_formula_criteria(values[i * 2 + 1]))
          }
          let matches = ifs_match(ranges, criterias)
          FormulaValue::Number(Double::from_int(matches.length()))
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DAVERAGE"
    | "DMAX"
    | "DMIN"
    | "DPRODUCT"
    | "DSTDEV"
    | "DSTDEVP"
    | "DSUM"
    | "DVAR"
    | "DVARP" =>
      if args.length() == 3 {
        let database = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let criteria = eval_range_expr(workbook, sheet_name, args[2], ctx)
        database_values(name, database, values[1], criteria)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DCOUNT" | "DCOUNTA" =>
      if args.length() >= 2 && args.length() <= 3 {
        let database = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let field = if args.length() == 3 {
          match args[1] {
            Expr::FuncCall(name, _) if name == "" => FormulaValue::Empty
            _ => values[1]
          }
        } else {
          FormulaValue::Empty
        }
        let criteria_idx = if args.length() == 3 { 2 } else { 1 }
        let criteria = eval_range_expr(
          workbook,
          sheet_name,
          args[criteria_idx],
          ctx,
        )
        dcount_values(name, database, field, criteria)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DGET" =>
      if args.length() == 3 {
        let database = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let criteria = eval_range_expr(workbook, sheet_name, args[2], ctx)
        dget_values(database, values[1], criteria)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SUMIF" =>
      if args.length() == 2 || args.length() == 3 {
        let range_values = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let sum_range = if args.length() == 3 {
          Some(eval_range_expr(workbook, sheet_name, args[2], ctx))
        } else {
          None
        }
        sumif_values(range_values, values[1], sum_range)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SUMPRODUCT" =>
      if args.length() >= 1 {
        let ranges : Array[RangeValues] = []
        let scalars : Array[FormulaValue] = []
        let mut has_range = false
        let mut has_scalar = false
        for i in 0..<args.length() {
          match args[i] {
            Expr::Range(_, _, _) | Expr::Cell(_, _) => {
              has_range = true
              ranges.push(eval_range_expr(workbook, sheet_name, args[i], ctx))
            }
            _ =>
              match values[i] {
                FormulaValue::Error(err) => return FormulaValue::Error(err)
                _ => {
                  has_scalar = true
                  scalars.push(values[i])
                }
              }
          }
        }
        if has_range && has_scalar {
          FormulaValue::Error(formula_error_value)
        } else if has_range {
          sumproduct_values(ranges)
        } else {
          sumproduct_scalars(scalars)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SUMSQ" => sumsq_values(values)
    "SUMX2MY2" =>
      if args.length() == 2 {
        let left = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let right = eval_range_expr(workbook, sheet_name, args[1], ctx)
        sumx_values("SUMX2MY2", left, right)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SUMX2PY2" =>
      if args.length() == 2 {
        let left = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let right = eval_range_expr(workbook, sheet_name, args[1], ctx)
        sumx_values("SUMX2PY2", left, right)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SUMXMY2" =>
      if args.length() == 2 {
        let left = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let right = eval_range_expr(workbook, sheet_name, args[1], ctx)
        sumx_values("SUMXMY2", left, right)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SUMIFS" =>
      if args.length() >= 3 {
        if args.length() % 2 != 1 {
          FormulaValue::Error(formula_error_na)
        } else {
          let sum_range = eval_range_expr(workbook, sheet_name, args[0], ctx)
          let ranges : Array[RangeValues] = []
          let criterias : Array[FormulaCriteria] = []
          for i in 0..<((args.length() - 1) / 2) {
            let offset = 1 + i * 2
            let range_values = eval_range_expr(
              workbook,
              sheet_name,
              args[offset],
              ctx,
            )
            ranges.push(range_values)
            criterias.push(parse_formula_criteria(values[offset + 1]))
          }
          let matches = ifs_match(ranges, criterias)
          let mut sum = 0.0
          for cell in matches {
            match sum_range.get(cell.row, cell.col) {
              Some(value) =>
                match value_as_number_opt(value) {
                  Some(num) => sum = sum + num
                  None => ()
                }
              None => return FormulaValue::Error(formula_error_value)
            }
          }
          FormulaValue::Number(sum)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "AVERAGEIF" =>
      if args.length() == 2 || args.length() == 3 {
        let range_values = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let average_range = if args.length() == 3 {
          Some(eval_range_expr(workbook, sheet_name, args[2], ctx))
        } else {
          None
        }
        averageif_values(range_values, values[1], average_range)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "AVERAGEIFS" =>
      if args.length() >= 3 {
        if args.length() % 2 != 1 {
          FormulaValue::Error(formula_error_na)
        } else {
          let average_range = eval_range_expr(
            workbook,
            sheet_name,
            args[0],
            ctx,
          )
          let ranges : Array[RangeValues] = []
          let criterias : Array[FormulaCriteria] = []
          for i in 0..<((args.length() - 1) / 2) {
            let offset = 1 + i * 2
            let range_values = eval_range_expr(
              workbook,
              sheet_name,
              args[offset],
              ctx,
            )
            ranges.push(range_values)
            criterias.push(parse_formula_criteria(values[offset + 1]))
          }
          let matches = ifs_match(ranges, criterias)
          let mut sum = 0.0
          let mut count = 0
          for cell in matches {
            match average_range.get(cell.row, cell.col) {
              Some(value) =>
                match value_as_number_opt(value) {
                  Some(num) => {
                    sum = sum + num
                    count = count + 1
                  }
                  None => ()
                }
              None => return FormulaValue::Error(formula_error_value)
            }
          }
          if count == 0 {
            FormulaValue::Error(formula_error_div)
          } else {
            FormulaValue::Number(sum / Double::from_int(count))
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MAXIFS" =>
      if args.length() >= 3 {
        if args.length() % 2 != 1 {
          FormulaValue::Error(formula_error_na)
        } else {
          let max_range = eval_range_expr(workbook, sheet_name, args[0], ctx)
          let ranges : Array[RangeValues] = []
          let criterias : Array[FormulaCriteria] = []
          for i in 0..<((args.length() - 1) / 2) {
            let offset = 1 + i * 2
            let range_values = eval_range_expr(
              workbook,
              sheet_name,
              args[offset],
              ctx,
            )
            ranges.push(range_values)
            criterias.push(parse_formula_criteria(values[offset + 1]))
          }
          let matches = ifs_match(ranges, criterias)
          maxifs_values(max_range, matches)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MINIFS" =>
      if args.length() >= 3 {
        if args.length() % 2 != 1 {
          FormulaValue::Error(formula_error_na)
        } else {
          let min_range = eval_range_expr(workbook, sheet_name, args[0], ctx)
          let ranges : Array[RangeValues] = []
          let criterias : Array[FormulaCriteria] = []
          for i in 0..<((args.length() - 1) / 2) {
            let offset = 1 + i * 2
            let range_values = eval_range_expr(
              workbook,
              sheet_name,
              args[offset],
              ctx,
            )
            ranges.push(range_values)
            criterias.push(parse_formula_criteria(values[offset + 1]))
          }
          let matches = ifs_match(ranges, criterias)
          minifs_values(min_range, matches)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "GCD" => gcd_values(values)
    "LCM" => lcm_values(values)
    "COMBIN" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(chosen)) => combin_values(num, chosen)
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "COMBINA" | "_XLFN.COMBINA" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(chosen)) => {
            let n = trunc_double(num)
            let k = trunc_double(chosen)
            if n < k {
              FormulaValue::Error(formula_error_value)
            } else if n == 0.0 {
              FormulaValue::Number(n)
            } else {
              combin_values(n + k - 1.0, n - 1.0)
            }
          }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "COMPLEX" =>
      if values.length() < 2 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 3 {
        FormulaValue::Error(formula_error_value)
      } else {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(real), Ok(imag)) => {
            let mut suffix = "i"
            if values.length() == 3 {
              match value_as_string(values[2]) {
                Ok(text) => {
                  let lower = text.to_lower()
                  if lower != "i" && lower != "j" {
                    return FormulaValue::Error(formula_error_value)
                  }
                  suffix = lower
                }
                Err(err) => return err
              }
            }
            FormulaValue::String(
              complex_to_string(complex_new(real, imag), suffix),
            )
          }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      }
    "FACT" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num < 0.0 {
              FormulaValue::Error(formula_error_num)
            } else {
              FormulaValue::Number(factorial_double(num))
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "FACTDOUBLE" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num < 0.0 {
              FormulaValue::Error(formula_error_num)
            } else {
              FormulaValue::Number(double_factorial_double(num))
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MULTINOMIAL" => multinomial_values(values)
    "MDETERM" =>
      if values.length() == 1 {
        let range = range_from_expr_or_value(
          workbook,
          sheet_name,
          args[0],
          values[0],
          ctx,
        )
        match number_matrix_from_range(range, true) {
          Ok(matrix) => FormulaValue::Number(matrix_det(matrix))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MINVERSE" =>
      if values.length() == 1 {
        let range = range_from_expr_or_value(
          workbook,
          sheet_name,
          args[0],
          values[0],
          ctx,
        )
        match number_matrix_from_range(range, true) {
          Ok(matrix) => {
            let det_value = matrix_det(matrix)
            if det_value == 0.0 {
              FormulaValue::Error(formula_error_num)
            } else {
              let adj = matrix_adjugate(matrix)
              let scale = 1.0 / det_value
              for row in 0..<adj.length() {
                for col in 0..<adj[row].length() {
                  let value = adj[row][col]
                  if value == 0.0 && scale < 0.0 {
                    adj[row][col] = -0.0
                  } else {
                    adj[row][col] = value * scale
                  }
                }
              }
              FormulaValue::List(matrix_values(adj))
            }
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MMULT" =>
      if values.length() == 2 {
        match (values[0], values[1]) {
          (FormulaValue::Number(lhs), FormulaValue::Number(rhs)) =>
            FormulaValue::Number(lhs * rhs)
          _ => {
            let left_range = range_from_expr_or_value(
              workbook,
              sheet_name,
              args[0],
              values[0],
              ctx,
            )
            let right_range = range_from_expr_or_value(
              workbook,
              sheet_name,
              args[1],
              values[1],
              ctx,
            )
            match
              (
                number_matrix_from_range(left_range, false),
                number_matrix_from_range(right_range, false),
              ) {
              (Ok(left), Ok(right)) =>
                match matrix_multiply(left, right) {
                  Ok(matrix) => FormulaValue::List(matrix_values(matrix))
                  Err(err) => err
                }
              (Err(err), _) => err
              (_, Err(err)) => err
            }
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MUNIT" | "_XLFN.MUNIT" =>
      if values.length() == 1 {
        match munit_dimension(values[0]) {
          Ok(dimension) =>
            FormulaValue::List(munit_range_values(dimension).values)
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TRANSPOSE" =>
      if args.length() == 1 {
        let base_range = range_from_expr_or_value(
          workbook,
          sheet_name,
          args[0],
          values[0],
          ctx,
        )
        FormulaValue::List(transpose_range_values(base_range).values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "PERMUT" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(chosen)) =>
            if num < chosen {
              FormulaValue::Error(formula_error_na)
            } else {
              let result = factorial_double(num) /
                factorial_double(num - chosen)
              FormulaValue::Number(round_half_away_from_zero(result))
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "PERMUTATIONA" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(chosen)) => {
            let number = Double::floor(num)
            let number_chosen = Double::floor(chosen)
            if number < 0.0 || number_chosen < 0.0 {
              FormulaValue::Error(formula_error_na)
            } else {
              FormulaValue::Number(@math.pow(number, number_chosen))
            }
          }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ABS" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => FormulaValue::Number(abs_double(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "INT" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => FormulaValue::Number(Double::floor(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "LN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => FormulaValue::Number(@math.ln(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "EXP" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => FormulaValue::Number(@math.exp(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DECIMAL" | "_XLFN.DECIMAL" =>
      if values.length() == 2 {
        match (value_as_string(values[0]), value_as_number(values[1])) {
          (Ok(text), Ok(radix)) => {
            let base = Double::to_int(trunc_double(radix))
            let text_value = strip_hex_prefix(text)
            let parsed = @strconv.parse_int(text_value, base~) catch {
              _ => return FormulaValue::Error(formula_error_value)
            }
            FormulaValue::Number(Double::from_int(parsed))
          }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ROMAN" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) => {
            let mut form = 0
            if values.length() == 2 {
              match value_as_number(values[1]) {
                Ok(raw) => {
                  let mut mode = Double::to_int(trunc_double(raw))
                  if mode < 0 {
                    mode = 0
                  } else if mode > 4 {
                    mode = 4
                  }
                  form = mode
                }
                Err(err) => return err
              }
            }
            FormulaValue::String(roman_string(num, form))
          }
          Err(err) => err
        }
      }
    "ARABIC" | "_XLFN.ARABIC" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => arabic_string_value(text)
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "BASE" => base_values(values)
    "BIN2DEC" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(_) =>
            match value_as_string(values[0]) {
              Ok(text) => bin2dec_string(text)
              Err(err) => err
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "BIN2HEX" =>
      if values.length() < 1 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(_) =>
            match value_as_string(values[0]) {
              Ok(text) => {
                let decimal = bin2dec_string(text)
                match decimal {
                  FormulaValue::Error(_) => decimal
                  _ => {
                    let new_values : Array[FormulaValue] = [decimal]
                    if values.length() == 2 {
                      new_values.push(values[1])
                    }
                    dec2x_values("BIN2HEX", new_values)
                  }
                }
              }
              Err(err) => err
            }
          Err(err) => err
        }
      }
    "BIN2OCT" =>
      if values.length() < 1 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(_) =>
            match value_as_string(values[0]) {
              Ok(text) => {
                let decimal = bin2dec_string(text)
                match decimal {
                  FormulaValue::Error(_) => decimal
                  _ => {
                    let new_values : Array[FormulaValue] = [decimal]
                    if values.length() == 2 {
                      new_values.push(values[1])
                    }
                    dec2x_values("BIN2OCT", new_values)
                  }
                }
              }
              Err(err) => err
            }
          Err(err) => err
        }
      }
    "DEC2BIN" => dec2x_values("DEC2BIN", values)
    "DEC2HEX" => dec2x_values("DEC2HEX", values)
    "DEC2OCT" => dec2x_values("DEC2OCT", values)
    "HEX2BIN" =>
      if values.length() < 1 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_string(values[0]) {
          Ok(text) => {
            let decimal = hex2dec_string(text)
            match decimal {
              FormulaValue::Error(_) => decimal
              _ => {
                let new_values : Array[FormulaValue] = [decimal]
                if values.length() == 2 {
                  new_values.push(values[1])
                }
                dec2x_values("HEX2BIN", new_values)
              }
            }
          }
          Err(err) => err
        }
      }
    "HEX2DEC" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => hex2dec_string(text)
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "HEX2OCT" =>
      if values.length() < 1 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_string(values[0]) {
          Ok(text) => {
            let decimal = hex2dec_string(text)
            match decimal {
              FormulaValue::Error(_) => decimal
              _ => {
                let new_values : Array[FormulaValue] = [decimal]
                if values.length() == 2 {
                  new_values.push(values[1])
                }
                dec2x_values("HEX2OCT", new_values)
              }
            }
          }
          Err(err) => err
        }
      }
    "OCT2BIN" =>
      if values.length() < 1 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(_) =>
            match value_as_string(values[0]) {
              Ok(text) => {
                let decimal = oct2dec_string(text)
                let new_values : Array[FormulaValue] = [decimal]
                if values.length() == 2 {
                  new_values.push(values[1])
                }
                dec2x_values("OCT2BIN", new_values)
              }
              Err(err) => err
            }
          Err(err) => err
        }
      }
    "OCT2DEC" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(_) =>
            match value_as_string(values[0]) {
              Ok(text) => oct2dec_string(text)
              Err(err) => err
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "OCT2HEX" =>
      if values.length() < 1 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(_) =>
            match value_as_string(values[0]) {
              Ok(text) => {
                let decimal = oct2dec_string(text)
                let new_values : Array[FormulaValue] = [decimal]
                if values.length() == 2 {
                  new_values.push(values[1])
                }
                dec2x_values("OCT2HEX", new_values)
              }
              Err(err) => err
            }
          Err(err) => err
        }
      }
    "BESSELI" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(x), Ok(n)) => number_or_num_error(bessel_i(x, n))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "BESSELJ" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(x), Ok(n)) => number_or_num_error(bessel_j(x, n))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "BESSELK" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(x), Ok(n)) =>
            if x <= 0.0 || n < 0.0 {
              FormulaValue::Error(formula_error_num)
            } else {
              let order = Double::floor(n)
              let result = if order == 0.0 {
                bessel_k0(x)
              } else if order == 1.0 {
                bessel_k1(x)
              } else {
                bessel_k2(x, n)
              }
              number_or_num_error(result)
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "BESSELY" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(x), Ok(n)) =>
            if x <= 0.0 || n < 0.0 {
              FormulaValue::Error(formula_error_num)
            } else {
              let order = Double::floor(n)
              let result = if order == 0.0 {
                bessel_y0(x)
              } else if order == 1.0 {
                bessel_y1(x)
              } else {
                bessel_y2(x, n)
              }
              number_or_num_error(result)
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DELTA" =>
      if values.length() < 1 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        let number1 = match value_as_number(values[0]) {
          Ok(num) => num
          Err(err) => return err
        }
        let number2 = if values.length() == 2 {
          match value_as_number(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          0.0
        }
        FormulaValue::Number(if number1 == number2 { 1.0 } else { 0.0 })
      }
    "ERF" =>
      if values.length() < 1 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(lower) =>
            if values.length() == 2 {
              match value_as_number(values[1]) {
                Ok(upper) =>
                  number_or_num_error(erf_double(upper) - erf_double(lower))
                Err(err) => err
              }
            } else {
              number_or_num_error(erf_double(lower))
            }
          Err(err) => err
        }
      }
    "ERFdotPRECISE" | "ERF.PRECISE" | "_XLFN.ERF.PRECISE" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(value) => number_or_num_error(erf_double(value))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ERFC" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(value) => number_or_num_error(erfc_double(value))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ERFCdotPRECISE" | "ERFC.PRECISE" | "_XLFN.ERFC.PRECISE" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(value) => number_or_num_error(erfc_double(value))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "WEIBULL" => weibull_value(values)
    "WEIBULLdotDIST" | "WEIBULL.DIST" | "_XLFN.WEIBULL.DIST" =>
      weibull_value(values)
    "BETAdotDIST" | "BETA.DIST" | "_XLFN.BETA.DIST" => beta_dist_values(values)
    "BETADIST" => betadist_values(values)
    "BETAINV" => betainv_values(values)
    "BETAdotINV" | "BETA.INV" | "_XLFN.BETA.INV" => betainv_values(values)
    "CONFIDENCE" => confidence_values(values)
    "CONFIDENCEdotNORM" | "CONFIDENCE.NORM" | "_XLFN.CONFIDENCE.NORM" =>
      confidence_values(values)
    "CONFIDENCEdotT" | "CONFIDENCE.T" | "_XLFN.CONFIDENCE.T" =>
      confidence_t_values(values)
    "NORMdotDIST" | "NORM.DIST" | "_XLFN.NORM.DIST" => normdist_values(values)
    "NORMDIST" => normdist_values(values)
    "NORMdotINV" | "NORM.INV" | "_XLFN.NORM.INV" => norminv_values(values)
    "NORMINV" => norminv_values(values)
    "NORMdotSdotDIST" | "NORM.S.DIST" | "_XLFN.NORM.S.DIST" =>
      norm_s_dist_values(values)
    "NORMSDIST" => norms_dist_values(values)
    "NORMdotSdotINV" | "NORM.S.INV" | "_XLFN.NORM.S.INV" =>
      norm_s_inv_values(values)
    "NORMSINV" => norms_inv_values(values)
    "LOGNORMdotDIST" | "LOGNORM.DIST" | "_XLFN.LOGNORM.DIST" =>
      lognorm_dist_values(values)
    "LOGNORMDIST" => lognormdist_values(values)
    "LOGINV" => loginv_values(values)
    "LOGNORMdotINV" | "LOGNORM.INV" | "_XLFN.LOGNORM.INV" =>
      loginv_values(values)
    "GAMMA" => gamma_value(values)
    "GAMMAdotDIST" | "GAMMA.DIST" | "_XLFN.GAMMA.DIST" =>
      gamma_dist_values(values)
    "GAMMADIST" => gamma_dist_values(values)
    "GAMMAdotINV" | "GAMMA.INV" | "_XLFN.GAMMA.INV" => gamma_inv_values(values)
    "GAMMAINV" => gamma_inv_values(values)
    "GAMMALN" => gammaln_values(values)
    "GAMMALNdotPRECISE" | "GAMMALN.PRECISE" | "_XLFN.GAMMALN.PRECISE" =>
      gammaln_precise_values(values)
    "EXPONdotDIST" | "EXPON.DIST" | "_XLFN.EXPON.DIST" =>
      expon_dist_values(values)
    "EXPONDIST" => expon_dist_values(values)
    "POISSONdotDIST" | "POISSON.DIST" | "_XLFN.POISSON.DIST" =>
      poisson_values(values)
    "POISSON" => poisson_values(values)
    "PROB" => prob_values(values)
    "BINOMdotDIST" | "BINOM.DIST" | "_XLFN.BINOM.DIST" =>
      binomdist_values(values)
    "BINOMDIST" => binomdist_values(values)
    "BINOMdotDISTdotRANGE" | "BINOM.DIST.RANGE" | "_XLFN.BINOM.DIST.RANGE" =>
      binom_dist_range_values(values)
    "BINOMdotINV" | "BINOM.INV" | "_XLFN.BINOM.INV" => binom_inv_values(values)
    "CRITBINOM" => binom_inv_values(values)
    "HYPGEOMdotDIST" | "HYPGEOM.DIST" | "_XLFN.HYPGEOM.DIST" =>
      hypgeom_dist_values(values)
    "HYPGEOMDIST" => hypgeomdist_values(values)
    "NEGBINOMdotDIST" | "NEGBINOM.DIST" | "_XLFN.NEGBINOM.DIST" =>
      negbinom_dist_values(values)
    "NEGBINOMDIST" => negbinomdist_values(values)
    "GAUSS" => gauss_value(values)
    "PHI" => phi_value(values)
    "CHIDIST" => chidist_values(values)
    "CHIINV" => chiinv_values(values)
    "CHISQdotDIST" | "CHISQ.DIST" | "_XLFN.CHISQ.DIST" =>
      chisq_dist_values(values)
    "CHISQdotDISTdotRT" | "CHISQ.DIST.RT" | "_XLFN.CHISQ.DIST.RT" =>
      chidist_values(values)
    "CHISQdotINV" | "CHISQ.INV" | "_XLFN.CHISQ.INV" => chisq_inv_values(values)
    "CHISQdotINVdotRT" | "CHISQ.INV.RT" | "_XLFN.CHISQ.INV.RT" =>
      chiinv_values(values)
    "CHITEST" => chitest_values(workbook, sheet_name, args, values, ctx)
    "CHISQdotTEST" | "CHISQ.TEST" | "_XLFN.CHISQ.TEST" =>
      chitest_values(workbook, sheet_name, args, values, ctx)
    "FdotDIST" | "F.DIST" | "_XLFN.F.DIST" => fdist_values(values)
    "FDIST" => fdist_rt_values(values)
    "FdotDISTdotRT" | "F.DIST.RT" | "_XLFN.F.DIST.RT" => fdist_rt_values(values)
    "FdotINV" | "F.INV" | "_XLFN.F.INV" => finv_values(values)
    "FdotINVdotRT" | "F.INV.RT" | "_XLFN.F.INV.RT" => finv_rt_values(values)
    "FINV" => finv_rt_values(values)
    "FTEST" => ftest_values(workbook, sheet_name, args, values, ctx)
    "FdotTEST" | "F.TEST" | "_XLFN.F.TEST" =>
      ftest_values(workbook, sheet_name, args, values, ctx)
    "ACCRINT" => accrint_values(values)
    "ACCRINTM" => accrintm_values(values)
    "AMORDEGRC" => amordegrc_values(values)
    "AMORLINC" => amorlinc_values(values)
    "COUPDAYBS" => coupdaybs_values(values)
    "COUPDAYS" => coupdays_values(values)
    "COUPDAYSNC" => coupdaysnc_values(values)
    "COUPNCD" => coupncd_values(values)
    "COUPNUM" => coupnum_values(values)
    "COUPPCD" => couppcd_values(values)
    "CUMIPMT" => cumip_values("CUMIPMT", values)
    "CUMPRINC" => cumip_values("CUMPRINC", values)
    "DURATION" => duration_values(values)
    "DB" => db_values(values)
    "DDB" => ddb_values(values)
    "FV" => fv_values(values)
    "FVSCHEDULE" => fvschedule_values(values)
    "DISC" => disc_intrate_values("DISC", values)
    "INTRATE" => disc_intrate_values("INTRATE", values)
    "IRR" => irr_values(values)
    "MDURATION" => mduration_values(values)
    "MIRR" => mirr_values(values)
    "DOLLAR" => dollar_values(values)
    "DOLLARDE" => dollar_fraction_values("DOLLARDE", values)
    "DOLLARFR" => dollar_fraction_values("DOLLARFR", values)
    "EFFECT" => effect_values(values)
    "CONVERT" => convert_values(values)
    "EUROCONVERT" => euroconvert_values(values)
    "IPMT" => ipmt_values("IPMT", values)
    "ISPMT" => ispmt_values(values)
    "NOMINAL" => nominal_values(values)
    "NPER" => nper_values(values)
    "NPV" => npv_values(values)
    "ODDFPRICE" => oddfprice_values(values)
    "ODDFYIELD" => oddfyield_values(values)
    "ODDLPRICE" => oddl_values("ODDLPRICE", values)
    "ODDLYIELD" => oddl_values("ODDLYIELD", values)
    "PDURATION" => pduration_values(values)
    "PMT" => pmt_values(values)
    "PPMT" => ipmt_values("PPMT", values)
    "PRICE" => price_yield_values("PRICE", values)
    "PRICEDISC" => pricedisc_values(values)
    "PRICEMAT" => pricemat_values(values)
    "PV" => pv_values(values)
    "RATE" => rate_values(values)
    "RRI" => rri_values(values)
    "SLN" => sln_values(values)
    "SYD" => syd_values(values)
    "TBILLEQ" => tbilleq_values(values)
    "TBILLPRICE" => tbillprice_values(values)
    "TBILLYIELD" => tbillyield_values(values)
    "XIRR" => xirr_values(values)
    "XNPV" => xnpv_values(values)
    "YIELD" => price_yield_values("YIELD", values)
    "YIELDDISC" => yielddisc_values(values)
    "YIELDMAT" => yieldmat_values(values)
    "VDB" => vdb_values(values)
    "TdotDIST" | "T.DIST" | "_XLFN.T.DIST" => tdist_values(values)
    "TdotDISTdot2T" | "T.DIST.2T" | "_XLFN.T.DIST.2T" => tdist_2t_values(values)
    "TdotDISTdotRT" | "T.DIST.RT" | "_XLFN.T.DIST.RT" => tdist_rt_values(values)
    "TDIST" => tdist_legacy_values(values)
    "TdotINV" | "T.INV" | "_XLFN.T.INV" => tinv_values(values)
    "TdotINVdot2T" | "T.INV.2T" | "_XLFN.T.INV.2T" => tinv_2t_values(values)
    "TINV" => tinv_2t_values(values)
    "TdotTEST" | "T.TEST" | "_XLFN.T.TEST" => ttest_values(values)
    "TTEST" => ttest_values(values)
    "ZdotTEST" | "Z.TEST" | "_XLFN.Z.TEST" => ztest_values(values)
    "ZTEST" => ztest_values(values)
    "GESTEP" =>
      if values.length() < 1 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        let number = match value_as_number(values[0]) {
          Ok(num) => num
          Err(err) => return err
        }
        let step = if values.length() == 2 {
          match value_as_number(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          0.0
        }
        FormulaValue::Number(if number >= step { 1.0 } else { 0.0 })
      }
    "BITAND" => bitwise_values("BITAND", values)
    "BITLSHIFT" => bitwise_values("BITLSHIFT", values)
    "BITOR" => bitwise_values("BITOR", values)
    "BITRSHIFT" => bitwise_values("BITRSHIFT", values)
    "BITXOR" => bitwise_values("BITXOR", values)
    "ACOS" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.acos(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ACOSH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.acosh(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ACOT" | "_XLFN.ACOT" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.PI / 2.0 - @math.atan(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ACOTH" | "_XLFN.ACOTH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.atanh(1.0 / num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ASIN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.asin(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ASINH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.asinh(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ATAN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.atan(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ATANH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.atanh(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ATAN2" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(y), Ok(x)) => number_or_num_error(@math.atan2(x, y))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "COS" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.cos(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "COSH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.cosh(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SIN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.sin(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SINH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.sinh(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TAN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.tan(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TANH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.tanh(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "COT" | "_XLFN.COT" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num == 0.0 {
              FormulaValue::Error(formula_error_div)
            } else {
              number_or_num_error(1.0 / @math.tan(num))
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "COTH" | "_XLFN.COTH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num == 0.0 {
              FormulaValue::Error(formula_error_div)
            } else {
              let exp_pos = @math.exp(num)
              let exp_neg = @math.exp(-num)
              number_or_num_error((exp_pos + exp_neg) / (exp_pos - exp_neg))
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "CSC" | "_XLFN.CSC" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num == 0.0 {
              FormulaValue::Error(formula_error_div)
            } else {
              number_or_num_error(1.0 / @math.sin(num))
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "CSCH" | "_XLFN.CSCH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num == 0.0 {
              FormulaValue::Error(formula_error_div)
            } else {
              number_or_num_error(1.0 / @math.sinh(num))
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SEC" | "_XLFN.SEC" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(@math.cos(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SECH" | "_XLFN.SECH" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => number_or_num_error(1.0 / @math.cosh(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DEGREES" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num == 0.0 {
              FormulaValue::Error(formula_error_div)
            } else {
              FormulaValue::Number(180.0 / @math.PI * num)
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "RADIANS" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => FormulaValue::Number(@math.PI / 180.0 * num)
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "RAND" =>
      if values.length() == 0 {
        FormulaValue::Number(rand_state.double())
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "RANDARRAY" => randarray_values(values)
    "RANDBETWEEN" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(bottom), Ok(top)) =>
            if top < bottom {
              FormulaValue::Error(formula_error_num)
            } else {
              let bottom_int = Double::to_int(trunc_double(bottom))
              let top_int = Double::to_int(trunc_double(top))
              let range = top_int - bottom_int + 1
              let rand_value = if range > 0 {
                rand_state.int(limit=range)
              } else {
                0
              }
              FormulaValue::Number(Double::from_int(rand_value + bottom_int))
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "PI" =>
      if values.length() == 0 {
        FormulaValue::Number(@math.PI)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SQRTPI" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => FormulaValue::Number(@math.pow(num * @math.PI, 0.5))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "LOG" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) => {
            let mut base = 10.0
            if values.length() == 2 {
              match value_as_number(values[1]) {
                Ok(value) => base = value
                Err(err) => return err
              }
            }
            if num == 0.0 || base == 0.0 {
              FormulaValue::Error(formula_error_num)
            } else if base == 1.0 {
              FormulaValue::Error(formula_error_div)
            } else {
              FormulaValue::Number(@math.ln(num) / @math.ln(base))
            }
          }
          Err(err) => err
        }
      }
    "LOG10" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => FormulaValue::Number(@math.log10(num))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMABS" =>
      if values.length() == 1 {
        match parse_complex_value(values[0]) {
          Ok(num) =>
            number_or_num_error(round_significant_digits(complex_abs(num), 15))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMAGINARY" =>
      if values.length() == 1 {
        match parse_complex_value(values[0]) {
          Ok(num) => number_or_num_error(round_significant_digits(num.imag, 15))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMARGUMENT" =>
      if values.length() == 1 {
        match parse_complex_value(values[0]) {
          Ok(num) =>
            number_or_num_error(round_significant_digits(complex_arg(num), 15))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMCONJUGATE" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            FormulaValue::String(complex_to_string(complex_conj(num), suffix))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMCOS" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            FormulaValue::String(complex_to_string(complex_cos(num), suffix))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMCOSH" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            FormulaValue::String(complex_to_string(complex_cosh(num), suffix))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMCOT" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            FormulaValue::String(
              complex_to_string(
                complex_div(complex_cos(num), complex_sin(num)),
                suffix,
              ),
            )
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMCSC" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) => {
            let result = complex_div(complex_new(1.0, 0.0), complex_sin(num))
            if complex_is_invalid(result) {
              FormulaValue::Error(formula_error_num)
            } else {
              FormulaValue::String(complex_to_string(result, suffix))
            }
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMCSCH" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) => {
            let result = complex_div(complex_new(1.0, 0.0), complex_sinh(num))
            if complex_is_invalid(result) {
              FormulaValue::Error(formula_error_num)
            } else {
              FormulaValue::String(complex_to_string(result, suffix))
            }
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMDIV" =>
      if values.length() == 2 {
        match
          (
            parse_complex_value_with_suffix(values[0]),
            parse_complex_value(values[1]),
          ) {
          (Ok((left, suffix)), Ok(right)) => {
            let result = complex_div(left, right)
            if complex_is_invalid(result) {
              FormulaValue::Error(formula_error_num)
            } else {
              FormulaValue::String(complex_to_string(result, suffix))
            }
          }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMEXP" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            FormulaValue::String(complex_to_string(complex_exp(num), suffix))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMLN" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) => {
            let result = complex_log(num)
            if complex_is_invalid(result) {
              FormulaValue::Error(formula_error_num)
            } else {
              FormulaValue::String(complex_to_string(result, suffix))
            }
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMLOG10" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) => {
            let result = complex_scale(complex_log(num), 1.0 / @math.ln(10.0))
            if complex_is_invalid(result) {
              FormulaValue::Error(formula_error_num)
            } else {
              FormulaValue::String(complex_to_string(result, suffix))
            }
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMLOG2" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) => {
            let result = complex_scale(complex_log(num), 1.0 / @math.ln(2.0))
            if complex_is_invalid(result) {
              FormulaValue::Error(formula_error_num)
            } else {
              FormulaValue::String(complex_to_string(result, suffix))
            }
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMPOWER" =>
      if values.length() == 2 {
        match
          (
            parse_complex_value_with_suffix(values[0]),
            parse_complex_value(values[1]),
          ) {
          (Ok((base, suffix)), Ok(exponent)) =>
            if base.real == 0.0 &&
              base.imag == 0.0 &&
              exponent.real == 0.0 &&
              exponent.imag == 0.0 {
              FormulaValue::Error(formula_error_num)
            } else {
              let result = complex_pow(base, exponent)
              if complex_is_invalid(result) {
                FormulaValue::Error(formula_error_num)
              } else {
                FormulaValue::String(complex_to_string(result, suffix))
              }
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMPRODUCT" => {
      let mut product = complex_new(1.0, 0.0)
      for value in flatten_values(values) {
        match value {
          FormulaValue::Error(err) => return FormulaValue::Error(err)
          FormulaValue::Empty => ()
          FormulaValue::Number(num) =>
            product = complex_mul(product, complex_new(num, 0.0))
          FormulaValue::Bool(flag) => {
            let num = if flag { 1.0 } else { 0.0 }
            product = complex_mul(product, complex_new(num, 0.0))
          }
          FormulaValue::String(text) =>
            if text == "" {
              ()
            } else {
              match parse_complex_text(text) {
                Ok(num) => product = complex_mul(product, num)
                Err(err) => return err
              }
            }
          FormulaValue::List(_) => ()
        }
      }
      FormulaValue::String(complex_to_string(product, "i"))
    }
    "IMREAL" =>
      if values.length() == 1 {
        match parse_complex_value(values[0]) {
          Ok(num) => FormulaValue::String(format_number(num.real))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMSEC" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) => {
            let result = complex_div(complex_new(1.0, 0.0), complex_cos(num))
            FormulaValue::String(complex_to_string(result, suffix))
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMSECH" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) => {
            let result = complex_div(complex_new(1.0, 0.0), complex_cosh(num))
            FormulaValue::String(complex_to_string(result, suffix))
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMSIN" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            FormulaValue::String(complex_to_string(complex_sin(num), suffix))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMSINH" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            FormulaValue::String(complex_to_string(complex_sinh(num), suffix))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMSQRT" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            FormulaValue::String(complex_to_string(complex_sqrt(num), suffix))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMSUB" =>
      if values.length() == 2 {
        match (parse_complex_value(values[0]), parse_complex_value(values[1])) {
          (Ok(left), Ok(right)) =>
            FormulaValue::String(
              complex_to_string(complex_sub(left, right), "i"),
            )
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMSUM" =>
      if values.length() >= 1 {
        let mut result = complex_new(0.0, 0.0)
        for value in flatten_values(values) {
          match value {
            FormulaValue::Error(err) => return FormulaValue::Error(err)
            _ =>
              match parse_complex_value(value) {
                Ok(num) => result = complex_add(result, num)
                Err(err) => return err
              }
          }
        }
        FormulaValue::String(complex_to_string(result, "i"))
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IMTAN" =>
      if values.length() == 1 {
        match parse_complex_value_with_suffix(values[0]) {
          Ok((num, suffix)) =>
            FormulaValue::String(complex_to_string(complex_tan(num), suffix))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "FLOOR" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(significance)) =>
            if significance < 0.0 && num >= 0.0 {
              FormulaValue::Error(formula_error_num)
            } else {
              let (whole, frac) = modf_double(num / significance)
              let mut val = whole
              if frac != 0.0 && num < 0.0 && frac < 0.0 {
                val = val - 1.0
              }
              FormulaValue::Number(val * significance)
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "CEILING" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) => {
            let mut significance = if num < 0.0 { -1.0 } else { 1.0 }
            if values.length() > 1 {
              match value_as_number(values[1]) {
                Ok(value) => significance = value
                Err(err) => return err
              }
            }
            if significance < 0.0 && num > 0.0 {
              FormulaValue::Error(formula_error_value)
            } else if values.length() == 1 {
              FormulaValue::Number(Double::ceil(num))
            } else {
              let (whole, frac) = modf_double(num / significance)
              let mut val = whole
              if frac > 0.0 {
                val = val + 1.0
              }
              FormulaValue::Number(val * significance)
            }
          }
          Err(err) => err
        }
      }
    "CEILINGdotMATH" | "CEILING.MATH" | "_XLFN.CEILING.MATH" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 3 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) =>
            if values.length() == 1 {
              FormulaValue::Number(Double::ceil(num))
            } else {
              let mut significance = if num < 0.0 { -1.0 } else { 1.0 }
              let mut mode = 1.0
              match value_as_number(values[1]) {
                Ok(value) => significance = value
                Err(err) => return err
              }
              if values.length() > 2 {
                match value_as_number(values[2]) {
                  Ok(value) => mode = value
                  Err(err) => return err
                }
              }
              let (whole, frac) = modf_double(num / significance)
              let mut val = whole
              if frac != 0.0 {
                if num > 0.0 {
                  val = val + 1.0
                } else if mode < 0.0 {
                  val = val - 1.0
                }
              }
              FormulaValue::Number(val * significance)
            }
          Err(err) => err
        }
      }
    "CEILINGdotPRECISE" | "CEILING.PRECISE" | "_XLFN.CEILING.PRECISE" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) =>
            if values.length() == 1 {
              FormulaValue::Number(Double::ceil(num))
            } else {
              match value_as_number(values[1]) {
                Ok(significance) => {
                  let abs_significance = abs_double(significance)
                  if abs_significance == 0.0 {
                    FormulaValue::Number(0.0)
                  } else {
                    let (whole, frac) = modf_double(num / abs_significance)
                    let mut val = whole
                    if frac != 0.0 && num > 0.0 {
                      val = val + 1.0
                    }
                    FormulaValue::Number(val * abs_significance)
                  }
                }
                Err(err) => err
              }
            }
          Err(err) => err
        }
      }
    "FLOORdotMATH" | "FLOOR.MATH" | "_XLFN.FLOOR.MATH" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 3 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) =>
            if values.length() == 1 {
              FormulaValue::Number(Double::floor(num))
            } else {
              let mut significance = if num < 0.0 { -1.0 } else { 1.0 }
              let mut mode = 1.0
              match value_as_number(values[1]) {
                Ok(value) => significance = value
                Err(err) => return err
              }
              if values.length() > 2 {
                match value_as_number(values[2]) {
                  Ok(value) => mode = value
                  Err(err) => return err
                }
              }
              let (whole, frac) = modf_double(num / significance)
              let mut val = whole
              if frac != 0.0 && num < 0.0 && mode > 0.0 {
                val = val - 1.0
              }
              FormulaValue::Number(val * significance)
            }
          Err(err) => err
        }
      }
    "FLOORdotPRECISE" | "FLOOR.PRECISE" | "_XLFN.FLOOR.PRECISE" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) =>
            if values.length() == 1 {
              FormulaValue::Number(Double::floor(num))
            } else {
              match value_as_number(values[1]) {
                Ok(significance) => {
                  let abs_significance = abs_double(significance)
                  if abs_significance == 0.0 {
                    FormulaValue::Number(0.0)
                  } else {
                    let (whole, frac) = modf_double(num / abs_significance)
                    let mut val = whole
                    if frac != 0.0 && num < 0.0 {
                      val = val - 1.0
                    }
                    FormulaValue::Number(val * abs_significance)
                  }
                }
                Err(err) => err
              }
            }
          Err(err) => err
        }
      }
    "ISOdotCEILING" | "ISO.CEILING" | "_XLFN.ISO.CEILING" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_value)
      } else if values.length() > 2 {
        FormulaValue::Error(formula_error_value)
      } else {
        match value_as_number(values[0]) {
          Ok(num) =>
            if values.length() == 1 {
              FormulaValue::Number(Double::ceil(num))
            } else {
              match value_as_number(values[1]) {
                Ok(significance) => {
                  let abs_significance = abs_double(significance)
                  if abs_significance == 0.0 {
                    FormulaValue::Number(0.0)
                  } else {
                    let (whole, frac) = modf_double(num / abs_significance)
                    let mut val = whole
                    if frac != 0.0 && num > 0.0 {
                      val = val + 1.0
                    }
                    FormulaValue::Number(val * abs_significance)
                  }
                }
                Err(err) => err
              }
            }
          Err(err) => err
        }
      }
    "TRUNC" =>
      if values.length() == 1 || values.length() == 2 {
        match value_as_number(values[0]) {
          Ok(num) => {
            let digits = if values.length() == 2 {
              match value_as_number(values[1]) {
                Ok(value) => Double::to_int(value)
                Err(err) => return err
              }
            } else {
              0
            }
            FormulaValue::Number(round_down_with_digits(num, digits))
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ROUND" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(digits)) =>
            FormulaValue::Number(round_with_digits(num, Double::to_int(digits)))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ROUNDUP" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(digits)) =>
            FormulaValue::Number(
              round_up_with_digits(num, Double::to_int(digits)),
            )
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ROUNDDOWN" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(digits)) =>
            FormulaValue::Number(
              round_down_with_digits(num, Double::to_int(digits)),
            )
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SQRT" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num < 0.0 {
              FormulaValue::Error(formula_error_num)
            } else {
              FormulaValue::Number(@math.pow(num, 0.5))
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "POWER" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(lhs), Ok(rhs)) => FormulaValue::Number(@math.pow(lhs, rhs))
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "EVEN" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => {
            let sign = num < 0.0
            let (whole, frac) = modf_double(num / 2.0)
            let mut val = whole * 2.0
            if frac != 0.0 {
              if sign {
                val = val - 2.0
              } else {
                val = val + 2.0
              }
            }
            FormulaValue::Number(val)
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ODD" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num == 0.0 {
              FormulaValue::Number(1.0)
            } else {
              let sign = num < 0.0
              let (whole, frac) = modf_double((num - 1.0) / 2.0)
              let mut val = whole * 2.0 + 1.0
              if frac != 0.0 {
                if sign {
                  val = val - 2.0
                } else {
                  val = val + 2.0
                }
              }
              FormulaValue::Number(val)
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MROUND" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(multiple)) =>
            if multiple == 0.0 {
              FormulaValue::Error(formula_error_num)
            } else if (multiple < 0.0 && num > 0.0) ||
              (multiple > 0.0 && num < 0.0) {
              FormulaValue::Error(formula_error_num)
            } else {
              let (whole, frac) = modf_double(num / multiple)
              let mut rounded = whole
              if trunc_double(frac + 0.5) > 0.0 {
                rounded = rounded + 1.0
              }
              FormulaValue::Number(rounded * multiple)
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MOD" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(divisor)) =>
            if divisor == 0.0 {
              FormulaValue::Error(formula_error_div)
            } else {
              let quotient = num / divisor
              let truncated = Double::floor(quotient)
              FormulaValue::Number(num - divisor * truncated)
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "QUOTIENT" =>
      if values.length() == 2 {
        match (value_as_number(values[0]), value_as_number(values[1])) {
          (Ok(num), Ok(divisor)) =>
            if divisor == 0.0 {
              FormulaValue::Error(formula_error_div)
            } else {
              FormulaValue::Number(trunc_double(num / divisor))
            }
          (Err(err), _) => err
          (_, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "AND" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_value)
      } else {
        for value in flatten_values(values) {
          match value_as_bool(value) {
            Ok(flag) => if !flag { return FormulaValue::Bool(false) }
            Err(err) => return err
          }
        }
        FormulaValue::Bool(true)
      }
    "OR" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_value)
      } else {
        for value in flatten_values(values) {
          match value_as_bool(value) {
            Ok(flag) => if flag { return FormulaValue::Bool(true) }
            Err(err) => return err
          }
        }
        FormulaValue::Bool(false)
      }
    "NOT" =>
      if values.length() == 1 {
        match value_as_bool(values[0]) {
          Ok(flag) => FormulaValue::Bool(!flag)
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "XOR" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_value)
      } else {
        let mut count = 0
        let mut ok = false
        for value in flatten_values(values) {
          match normalize_scalar(value) {
            FormulaValue::Error(err) => return FormulaValue::Error(err)
            FormulaValue::Number(num) => {
              ok = true
              if num != 0.0 {
                count = count + 1
              }
            }
            FormulaValue::Bool(flag) => {
              ok = true
              if flag {
                count = count + 1
              }
            }
            FormulaValue::String(text) => {
              let parsed = @strconv.parse_bool(text) catch {
                _ => return FormulaValue::Error(formula_error_value)
              }
              ok = true
              if parsed {
                count = count + 1
              }
            }
            FormulaValue::Empty => ()
            FormulaValue::List(_) => ()
          }
        }
        if !ok {
          FormulaValue::Error(formula_error_value)
        } else {
          FormulaValue::Bool(count % 2 != 0)
        }
      }
    "LEN" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => FormulaValue::Number(Double::from_int(text.length()))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "LENB" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) =>
            FormulaValue::Number(Double::from_int(dbcs_byte_length(text)))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "LOWER" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => FormulaValue::String(text.to_lower())
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "UPPER" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => FormulaValue::String(text.to_upper())
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "PROPER" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => FormulaValue::String(proper_case(text))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DBCS" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) =>
            if dbcs_enabled(workbook) {
              FormulaValue::String(dbcs_convert(text))
            } else {
              FormulaValue::String(text)
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TRIM" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => FormulaValue::String(trim_excel_text(text))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "LEFT" =>
      if values.length() == 1 || values.length() == 2 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let count = if values.length() == 2 {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if count < 0 {
          FormulaValue::Error(formula_error_value)
        } else {
          let len = text.length()
          let end = if count > len { len } else { count }
          let start = 0
          FormulaValue::String(text.unsafe_substring(start~, end~))
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "LEFTB" =>
      if values.length() == 1 || values.length() == 2 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let count = if values.length() == 2 {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if count < 0 {
          FormulaValue::Error(formula_error_value)
        } else {
          let bytes = @encoding/utf8.encode(text)
          let len = bytes.length()
          if count >= len {
            FormulaValue::String(text)
          } else {
            FormulaValue::String(bytes_to_string(bytes[0:count]))
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "RIGHT" =>
      if values.length() == 1 || values.length() == 2 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let count = if values.length() == 2 {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if count < 0 {
          FormulaValue::Error(formula_error_value)
        } else {
          let len = text.length()
          let start = if count >= len { 0 } else { len - count }
          let end = len
          FormulaValue::String(text.unsafe_substring(start~, end~))
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "RIGHTB" =>
      if values.length() == 1 || values.length() == 2 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let count = if values.length() == 2 {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if count < 0 {
          FormulaValue::Error(formula_error_value)
        } else {
          let bytes = @encoding/utf8.encode(text)
          let len = bytes.length()
          if count >= len {
            FormulaValue::String(text)
          } else {
            let start = len - count
            FormulaValue::String(bytes_to_string(bytes[start:len]))
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MID" =>
      if values.length() == 3 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let count = match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        if start_num <= 0 || count < 0 {
          FormulaValue::Error(formula_error_value)
        } else {
          let len = text.length()
          if start_num > len {
            FormulaValue::String("")
          } else {
            let start = start_num - 1
            let mut end = start + count
            if end > len {
              end = len
            }
            FormulaValue::String(text.unsafe_substring(start~, end~))
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MIDB" =>
      if values.length() == 3 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let count = match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        if start_num <= 0 || count < 0 {
          FormulaValue::Error(formula_error_value)
        } else if count == 0 {
          FormulaValue::String("")
        } else if start_num > dbcs_byte_length(text) {
          FormulaValue::String("")
        } else {
          let sb = StringBuilder::new()
          let mut offset = 0
          let mut taken = 0
          for ch in text {
            if taken == count {
              break
            }
            offset = offset + 1
            let mut dbcs = false
            if dbcs_byte_len_char(ch) == 2 {
              dbcs = true
              offset = offset + 1
            }
            if offset + 1 > start_num {
              if dbcs {
                if taken + 2 > count {
                  let bytes = @encoding/utf8.encode(String::from_array([ch]))
                  if bytes.length() > 0 {
                    sb.write_char(Int::unsafe_to_char(bytes[0].to_int()))
                  }
                  break
                }
                sb.write_char(ch)
                taken = taken + 2
              } else {
                sb.write_char(ch)
                taken = taken + 1
              }
            }
          }
          FormulaValue::String(sb.to_string())
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "REPT" =>
      if values.length() == 2 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let times = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        if times < 0 {
          FormulaValue::Error(formula_error_value)
        } else if times == 0 || text.length() == 0 {
          FormulaValue::String("")
        } else if text.length() > max_cell_chars / times {
          FormulaValue::Error(formula_error_value)
        } else {
          FormulaValue::String(text.repeat(times))
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "REPLACE" =>
      if values.length() == 4 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let count = match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        let new_text = match value_as_string(values[3]) {
          Ok(text) => text
          Err(err) => return err
        }
        if start_num <= 0 || count < 0 {
          FormulaValue::Error(formula_error_value)
        } else {
          let len = text.length()
          let mut start = start_num - 1
          if start > len {
            start = len
          }
          let mut end = start + count
          if end > len {
            end = len
          }
          let sb = StringBuilder::new()
          sb.write_view(text.unsafe_substring(start=0, end=start))
          sb.write_view(new_text)
          sb.write_view(text.unsafe_substring(start=end, end=len))
          FormulaValue::String(sb.to_string())
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "REPLACEB" =>
      if values.length() == 4 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let count = match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        let new_text = match value_as_string(values[3]) {
          Ok(text) => text
          Err(err) => return err
        }
        if start_num <= 0 || count < 0 {
          FormulaValue::Error(formula_error_value)
        } else {
          let bytes = @encoding/utf8.encode(text)
          let len = bytes.length()
          let mut start = start_num - 1
          if start > len {
            start = len
          }
          let mut end = start + count
          if end > len {
            end = len
          }
          let sb = StringBuilder::new()
          sb.write_view(bytes_to_string(bytes[0:start]))
          sb.write_view(new_text)
          sb.write_view(bytes_to_string(bytes[end:len]))
          FormulaValue::String(sb.to_string())
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SUBSTITUTE" =>
      if values.length() == 3 || values.length() == 4 {
        let text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let old_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        let new_text = match value_as_string(values[2]) {
          Ok(text) => text
          Err(err) => return err
        }
        if old_text.length() == 0 {
          FormulaValue::Error(formula_error_value)
        } else if values.length() == 4 {
          let instance = match value_as_int(values[3]) {
            Ok(num) => num
            Err(err) => return err
          }
          if instance <= 0 {
            FormulaValue::Error(formula_error_value)
          } else {
            let mut index = 0
            let mut count = 0
            let len = text.length()
            let pattern_len = old_text.length()
            while true {
              match find_substring_from(text, old_text, index) {
                Some(found) => {
                  count = count + 1
                  if count == instance {
                    let sb = StringBuilder::new()
                    sb.write_view(text.unsafe_substring(start=0, end=found))
                    sb.write_view(new_text)
                    let tail_start = found + pattern_len
                    sb.write_view(
                      text.unsafe_substring(start=tail_start, end=len),
                    )
                    return FormulaValue::String(sb.to_string())
                  }
                  index = found + pattern_len
                }
                None => break
              }
            }
            FormulaValue::String(text)
          }
        } else {
          let mut index = 0
          let len = text.length()
          let pattern_len = old_text.length()
          let sb = StringBuilder::new()
          while true {
            match find_substring_from(text, old_text, index) {
              Some(found) => {
                sb.write_view(text.unsafe_substring(start=index, end=found))
                sb.write_view(new_text)
                index = found + pattern_len
              }
              None => {
                sb.write_view(text.unsafe_substring(start=index, end=len))
                break
              }
            }
          }
          FormulaValue::String(sb.to_string())
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "FIND" =>
      if values.length() == 2 || values.length() == 3 {
        let find_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let within_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = if values.length() == 3 {
          match value_as_int(values[2]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if start_num <= 0 {
          FormulaValue::Error(formula_error_value)
        } else {
          let start = start_num - 1
          let len = within_text.length()
          if start > len {
            FormulaValue::Error(formula_error_value)
          } else if find_text.length() == 0 {
            FormulaValue::Number(Double::from_int(start_num))
          } else {
            match find_substring_from(within_text, find_text, start) {
              Some(idx) => FormulaValue::Number(Double::from_int(idx + 1))
              None => FormulaValue::Error(formula_error_value)
            }
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "FINDB" =>
      if values.length() == 2 || values.length() == 3 {
        let find_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let within_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = if values.length() == 3 {
          match value_as_int(values[2]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        match find_dbcs(within_text, find_text, start_num, false) {
          Some(value) => FormulaValue::Number(Double::from_int(value))
          None => FormulaValue::Error(formula_error_value)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SEARCH" =>
      if values.length() == 2 || values.length() == 3 {
        let find_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let within_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = if values.length() == 3 {
          match value_as_int(values[2]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if start_num <= 0 {
          FormulaValue::Error(formula_error_value)
        } else {
          let start = start_num - 1
          let lower_text = within_text.to_lower()
          let lower_find = find_text.to_lower()
          let len = lower_text.length()
          if start > len {
            FormulaValue::Error(formula_error_value)
          } else if lower_find.length() == 0 {
            FormulaValue::Number(Double::from_int(start_num))
          } else {
            match wildcard_find(lower_text, lower_find, start) {
              Some(idx) => FormulaValue::Number(Double::from_int(idx + 1))
              None => FormulaValue::Error(formula_error_value)
            }
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SEARCHB" =>
      if values.length() == 2 || values.length() == 3 {
        let find_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let within_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        let start_num = if values.length() == 3 {
          match value_as_int(values[2]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        let lower_find = find_text.to_lower()
        let lower_text = within_text.to_lower()
        match find_dbcs(lower_text, lower_find, start_num, true) {
          Some(value) => FormulaValue::Number(Double::from_int(value))
          None => FormulaValue::Error(formula_error_value)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "EXACT" =>
      if values.length() == 2 {
        let left = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let right = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        FormulaValue::Bool(left == right)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "FIXED" =>
      if values.length() >= 1 && values.length() <= 3 {
        let number = match value_as_number(values[0]) {
          Ok(num) => num
          Err(err) => return err
        }
        let mut decimals = if values.length() == 1 {
          decimal_places_from_text(formula_value_string(values[0]))
        } else {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        }
        if decimals < 0 {
          decimals = 0
        }
        let no_commas = if values.length() == 3 {
          match value_as_bool(values[2]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          false
        }
        FormulaValue::String(format_fixed_number(number, decimals, !no_commas))
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "VALUE" =>
      if values.length() == 1 {
        match value_as_number_text(values[0]) {
          Ok(num) => FormulaValue::Number(num)
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "VALUETOTEXT" =>
      if values.length() == 1 || values.length() == 2 {
        let format = if values.length() == 2 {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          0
        }
        if format != 0 && format != 1 {
          FormulaValue::Error(formula_error_value)
        } else {
          let text = formula_value_string(values[0])
          match value_as_number(values[0]) {
            Ok(_) => FormulaValue::String(text)
            Err(_) =>
              if format == 1 {
                FormulaValue::String("\"" + text + "\"")
              } else {
                FormulaValue::String(text)
              }
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TEXT" =>
      if values.length() == 2 {
        let format_text = match value_as_string(values[1]) {
          Ok(text) => text
          Err(err) => return err
        }
        match value_as_number_text(values[0]) {
          Ok(num) =>
            FormulaValue::String(
              format_number_code(format_number(num), format_text),
            )
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ARRAYTOTEXT" =>
      if values.length() == 1 || values.length() == 2 {
        let format = if values.length() == 2 {
          match value_as_int(values[1]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          0
        }
        if format != 0 && format != 1 {
          return FormulaValue::Error(formula_error_value)
        }
        let range = match args[0] {
          Expr::Range(_, _, _) | Expr::Cell(_, _) =>
            eval_range_expr(workbook, sheet_name, args[0], ctx)
          _ => RangeValues::{ rows: 1, cols: 1, values: [values[0]] }
        }
        let rows : Array[String] = []
        for row in 0..<range.rows {
          let cells : Array[String] = []
          for col in 0..<range.cols {
            let value = range.values[row * range.cols + col]
            match normalize_scalar(value) {
              FormulaValue::Error(err) => return FormulaValue::Error(err)
              _ => {
                let text = formula_value_string(value)
                match value_as_number(value) {
                  Ok(_) => cells.push(text)
                  Err(_) =>
                    if format == 1 {
                      cells.push("\"" + text + "\"")
                    } else {
                      cells.push(text)
                    }
                }
              }
            }
          }
          let joined = if format == 1 {
            cells.join(",")
          } else {
            cells.join(", ")
          }
          rows.push(joined)
        }
        if format == 1 {
          FormulaValue::String("{" + rows.join(";") + "}")
        } else {
          FormulaValue::String(rows.join(", "))
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TEXTAFTER" | "TEXTBEFORE" =>
      if values.length() >= 2 && values.length() <= 6 {
        let text = match value_as_string(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let delimiter = match value_as_string(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        if text == "" {
          return FormulaValue::Error(formula_error_na)
        }
        let instance_num = if values.length() >= 3 {
          match value_as_int(values[2]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if instance_num == 0 ||
          instance_num > text.length() ||
          -instance_num > text.length() {
          return FormulaValue::Error(formula_error_value)
        }
        let match_mode = if values.length() >= 4 {
          match value_as_int(values[3]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          0
        }
        if match_mode != 0 && match_mode != 1 {
          return FormulaValue::Error(formula_error_value)
        }
        let match_end = if values.length() >= 5 {
          match value_as_bool(values[4]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          false
        }
        let if_not_found = if values.length() == 6 {
          values[5]
        } else {
          FormulaValue::Empty
        }
        let idx_opt = text_after_before_index(
          text, delimiter, instance_num, match_mode, match_end,
        )
        let idx = match idx_opt {
          Some(value) => value
          None => return if_not_found
        }
        if idx < 0 {
          return if_not_found
        }
        if name == "TEXTAFTER" {
          let start = idx + delimiter.length()
          if start >= text.length() {
            FormulaValue::Empty
          } else {
            FormulaValue::String(
              text.unsafe_substring(start~, end=text.length()),
            )
          }
        } else if idx <= 0 {
          FormulaValue::String("")
        } else {
          FormulaValue::String(text.unsafe_substring(start=0, end=idx))
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TEXTSPLIT" =>
      if values.length() >= 2 && values.length() <= 6 {
        textsplit_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TEXTJOIN" =>
      if values.length() >= 3 {
        let delimiter = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let ignore_empty = match value_as_bool(values[1]) {
          Ok(flag) => flag
          Err(err) => return err
        }
        let parts : Array[String] = []
        for i in 2..<values.length() {
          match textjoin_collect_value(values[i], ignore_empty, parts) {
            Ok(_) => ()
            Err(err) => return err
          }
        }
        let result = parts.join(delimiter)
        if result.length() > max_cell_chars {
          FormulaValue::Error(formula_error_value)
        } else {
          FormulaValue::String(result)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SEQUENCE" => sequence_values(values)
    "TAKE" => take_values(workbook, sheet_name, args, values, ctx)
    "DROP" => drop_values(workbook, sheet_name, args, values, ctx)
    "CHOOSECOLS" => choosecols_values(workbook, sheet_name, args, values, ctx)
    "CHOOSEROWS" => chooserows_values(workbook, sheet_name, args, values, ctx)
    "HSTACK" => stack_from_values(workbook, sheet_name, args, values, ctx, true)
    "VSTACK" =>
      stack_from_values(workbook, sheet_name, args, values, ctx, false)
    "EXPAND" => expand_values(workbook, sheet_name, args, values, ctx)
    "WRAPROWS" => wrap_values(workbook, sheet_name, args, values, ctx, true)
    "WRAPCOLS" => wrap_values(workbook, sheet_name, args, values, ctx, false)
    "TOCOL" =>
      tocol_torow_values(workbook, sheet_name, args, values, ctx, false)
    "TOROW" =>
      tocol_torow_values(workbook, sheet_name, args, values, ctx, false)
    "SORT" => sort_values(workbook, sheet_name, args, values, ctx)
    "SORTBY" | "_XLFN.SORTBY" =>
      sortby_values(workbook, sheet_name, args, values, ctx)
    "FILTER" => filter_values(workbook, sheet_name, args, values, ctx)
    "UNIQUE" =>
      if args.length() >= 1 && args.length() <= 3 {
        let by_col = if args.length() >= 2 {
          match value_as_bool(values[1]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          false
        }
        let exactly_once = if args.length() == 3 {
          match value_as_bool(values[2]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          false
        }
        let range = match args[0] {
          Expr::Range(_, _, _) | Expr::Cell(_, _) =>
            eval_range_expr(workbook, sheet_name, args[0], ctx)
          _ =>
            match values[0] {
              FormulaValue::Error(err) => return FormulaValue::Error(err)
              FormulaValue::List(list) =>
                if list.length() == 0 {
                  return FormulaValue::Error(formula_error_value)
                } else {
                  { rows: 1, cols: list.length(), values: list }
                }
              _ => { rows: 1, cols: 1, values: [values[0]] }
            }
        }
        match unique_range_values(range, by_col, exactly_once) {
          Ok(result) => FormulaValue::List(result.values)
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DATE" =>
      if values.length() == 3 {
        match
          (
            value_as_int(values[0]),
            value_as_int(values[1]),
            value_as_int(values[2]),
          ) {
          (Ok(year), Ok(month), Ok(day)) =>
            match excel_serial_from_date(year, month, day) {
              Some(serial) => FormulaValue::Number(serial)
              None => FormulaValue::Error(formula_error_num)
            }
          (Err(err), _, _) => err
          (_, Err(err), _) => err
          (_, _, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TIME" =>
      if values.length() == 3 {
        match
          (
            value_as_int(values[0]),
            value_as_int(values[1]),
            value_as_int(values[2]),
          ) {
          (Ok(hours), Ok(minutes), Ok(seconds)) =>
            match excel_time_fraction(hours, minutes, seconds) {
              Some(value) => FormulaValue::Number(value)
              None => FormulaValue::Error(formula_error_num)
            }
          (Err(err), _, _) => err
          (_, Err(err), _) => err
          (_, _, Err(err)) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DATEVALUE" =>
      if values.length() == 1 {
        let text = match value_as_string(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        match parse_date_parts(text) {
          Some((year, month, day)) =>
            match excel_serial_from_date(year, month, day) {
              Some(serial) => FormulaValue::Number(serial)
              None => FormulaValue::Error(formula_error_value)
            }
          None => FormulaValue::Error(formula_error_value)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TIMEVALUE" =>
      if values.length() == 1 {
        let text = match value_as_string(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        match parse_time_parts(text) {
          Some((hours, minutes, seconds)) =>
            match excel_time_fraction(hours, minutes, seconds) {
              Some(value) => FormulaValue::Number(value)
              None => FormulaValue::Error(formula_error_value)
            }
          None => FormulaValue::Error(formula_error_value)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DATEDIF" =>
      if values.length() == 3 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let end_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        if start_serial > end_serial {
          FormulaValue::Error(formula_error_num)
        } else if start_serial == end_serial {
          FormulaValue::Number(0.0)
        } else {
          let unit = match value_as_string(values[2]) {
            Ok(text) => text.to_lower()
            Err(err) => return err
          }
          let (sy, sm, sd) = match date_parts_from_serial(start_serial) {
            Some(parts) => parts
            None => return FormulaValue::Error(formula_error_num)
          }
          let (ey, em, ed) = match date_parts_from_serial(end_serial) {
            Some(parts) => parts
            None => return FormulaValue::Error(formula_error_num)
          }
          match unit {
            "y" => {
              let mut diff = ey - sy
              if em < sm || (em == sm && ed < sd) {
                diff = diff - 1
              }
              FormulaValue::Number(Double::from_int(diff))
            }
            "m" => {
              let mut diff = (ey - sy) * 12 + (em - sm)
              if ed < sd {
                diff = diff - 1
              }
              FormulaValue::Number(Double::from_int(diff))
            }
            "d" => FormulaValue::Number(end_serial - start_serial)
            "ym" => {
              let mut diff = em - sm
              if ed < sd {
                diff = diff - 1
              }
              if diff < 0 {
                diff = diff + 12
              }
              FormulaValue::Number(Double::from_int(diff))
            }
            "yd" => {
              let mut target_year = sy
              if em < sm || (em == sm && ed < sd) {
                target_year = sy + 1
              }
              let start_base = match excel_serial_from_date(sy, sm, sd) {
                Some(value) => value
                None => return FormulaValue::Error(formula_error_num)
              }
              let end_base = match excel_serial_from_date(target_year, em, ed) {
                Some(value) => value
                None => return FormulaValue::Error(formula_error_num)
              }
              FormulaValue::Number(end_base - start_base)
            }
            "md" => {
              let diff = if ed >= sd {
                ed - sd
              } else {
                let (prev_year, prev_month) = normalize_year_month(ey, em - 1)
                let dim = days_in_month(prev_year, prev_month)
                dim - sd + ed
              }
              FormulaValue::Number(Double::from_int(diff))
            }
            _ => FormulaValue::Error(formula_error_value)
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DAYS" =>
      if values.length() == 2 {
        let end_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let start_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        FormulaValue::Number(end_serial - start_serial)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DAYS360" =>
      if values.length() == 2 || values.length() == 3 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let end_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        let (sy, sm, sd) = match date_parts_from_serial(start_serial) {
          Some(parts) => parts
          None => return FormulaValue::Error(formula_error_num)
        }
        let (ey, em, ed) = match date_parts_from_serial(end_serial) {
          Some(parts) => parts
          None => return FormulaValue::Error(formula_error_num)
        }
        let mut start_day = sd
        let mut end_day = ed
        let end_year = ey
        let mut end_month = em
        let use_european = if values.length() == 3 {
          match value_as_bool(values[2]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          false
        }
        if use_european {
          if start_day == 31 {
            start_day = 30
          }
          if end_day == 31 {
            end_day = 30
          }
        } else {
          if days_in_month(sy, sm) == start_day {
            start_day = 30
          }
          if end_day > 30 {
            if start_day < 30 {
              end_month = end_month + 1
              end_day = 1
            } else {
              end_day = 30
            }
          }
        }
        let (norm_year, norm_month) = normalize_year_month(end_year, end_month)
        let diff = (norm_year - sy) * 360 +
          (norm_month - sm) * 30 +
          (end_day - start_day)
        FormulaValue::Number(Double::from_int(diff))
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISOWEEKNUM" =>
      if values.length() == 1 {
        let (year, month, day) = match date_parts_from_value(values[0]) {
          Ok(parts) => parts
          Err(err) => return err
        }
        match iso_week_number(year, month, day) {
          Some(week) => FormulaValue::Number(Double::from_int(week))
          None => FormulaValue::Error(formula_error_num)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "EDATE" =>
      if values.length() == 2 {
        let (year, month, day) = match date_parts_from_value(values[0]) {
          Ok(parts) => parts
          Err(err) => return err
        }
        let months = match value_as_number(values[1]) {
          Ok(num) => Double::to_int(trunc_double(num))
          Err(err) => return err
        }
        let (new_year, new_month) = normalize_year_month(year, month + months)
        let max_day = days_in_month(new_year, new_month)
        let new_day = if day > max_day { max_day } else { day }
        match excel_serial_from_date(new_year, new_month, new_day) {
          Some(serial) => FormulaValue::Number(serial)
          None => FormulaValue::Error(formula_error_num)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "EOMONTH" =>
      if values.length() == 2 {
        let (year, month, _) = match date_parts_from_value(values[0]) {
          Ok(parts) => parts
          Err(err) => return err
        }
        let months = match value_as_number(values[1]) {
          Ok(num) => Double::to_int(trunc_double(num))
          Err(err) => return err
        }
        let (new_year, new_month) = normalize_year_month(year, month + months)
        let new_day = days_in_month(new_year, new_month)
        match excel_serial_from_date(new_year, new_month, new_day) {
          Some(serial) => FormulaValue::Number(serial)
          None => FormulaValue::Error(formula_error_num)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "YEARFRAC" =>
      if values.length() == 2 || values.length() == 3 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let end_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        let basis = if values.length() == 3 {
          match value_as_number(values[2]) {
            Ok(num) => Double::to_int(trunc_double(num))
            Err(err) => return err
          }
        } else {
          0
        }
        yearfrac_value(start_serial, end_serial, basis)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "WEEKDAY" =>
      if values.length() == 1 || values.length() == 2 {
        let (year, month, day) = match date_parts_from_value(values[0]) {
          Ok(parts) => parts
          Err(err) => return err
        }
        let mut return_type = 1
        if values.length() == 2 {
          return_type = match value_as_number(values[1]) {
            Ok(num) => Double::to_int(trunc_double(num))
            Err(err) => return err
          }
        }
        if return_type == 2 {
          return_type = 11
        }
        let weekday = weekday_sun1(year, month, day)
        if return_type == 1 {
          FormulaValue::Number(Double::from_int(weekday))
        } else if return_type == 3 {
          let value = (weekday + 6 - 1) % 7
          FormulaValue::Number(Double::from_int(value))
        } else if return_type >= 11 && return_type <= 17 {
          let value = (weekday + 6 - (return_type - 10)) % 7 + 1
          FormulaValue::Number(Double::from_int(value))
        } else {
          FormulaValue::Error(formula_error_value)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "WEEKNUM" =>
      if values.length() == 1 || values.length() == 2 {
        let (year, month, day) = match date_parts_from_value(values[0]) {
          Ok(parts) => parts
          Err(err) => return err
        }
        let mut return_type = 1
        if values.length() == 2 {
          return_type = match value_as_number(values[1]) {
            Ok(num) => Double::to_int(trunc_double(num))
            Err(err) => return err
          }
        }
        let days = day_of_year(year, month, day)
        let mut week_mod = days % 7
        if week_mod == 0 {
          week_mod = 7
        }
        let mut week_num = (days + 6) / 7
        let first_weekday = weekday_sun1(year, 1, 1) - 1
        let offset = match return_type {
          1 | 17 => 0
          2 | 11 | 21 => 1
          12 | 13 | 14 | 15 | 16 => return_type - 10
          _ => return FormulaValue::Error(formula_error_num)
        }
        let mut padding = offset + 7 - first_weekday
        if padding > 7 {
          padding = padding - 7
        }
        if week_mod > padding {
          week_num = week_num + 1
        }
        if return_type == 21 && (first_weekday == 0 || first_weekday > 4) {
          week_num = week_num - 1
          if week_num < 1 {
            week_num = 52
            let prev_first_weekday = weekday_sun1(year - 1, 1, 1) - 1
            if prev_first_weekday < 4 {
              week_num = week_num + 1
            }
          }
        }
        FormulaValue::Number(Double::from_int(week_num))
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "NETWORKDAYS" =>
      if values.length() == 2 || values.length() == 3 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let end_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        let holidays = if values.length() == 3 {
          collect_holidays(values[2])
        } else {
          []
        }
        networkdays_intl_value(
          start_serial,
          end_serial,
          FormulaValue::Number(1.0),
          holidays,
        )
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "NETWORKDAYS.INTL" =>
      if values.length() >= 2 && values.length() <= 4 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let end_serial = match value_as_date_serial(values[1]) {
          Ok(value) => value
          Err(err) => return err
        }
        let weekend_value = if values.length() >= 3 {
          values[2]
        } else {
          FormulaValue::Number(1.0)
        }
        let holidays = if values.length() == 4 {
          collect_holidays(values[3])
        } else {
          []
        }
        networkdays_intl_value(
          start_serial, end_serial, weekend_value, holidays,
        )
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "WORKDAY" =>
      if values.length() == 2 || values.length() == 3 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let days = match value_as_number(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let holidays = if values.length() == 3 {
          collect_holidays(values[2])
        } else {
          []
        }
        workday_intl_value(
          start_serial,
          days,
          FormulaValue::Number(1.0),
          holidays,
        )
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "WORKDAY.INTL" =>
      if values.length() >= 2 && values.length() <= 4 {
        let start_serial = match value_as_date_serial(values[0]) {
          Ok(value) => value
          Err(err) => return err
        }
        let days = match value_as_number(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let weekend_value = if values.length() >= 3 {
          values[2]
        } else {
          FormulaValue::Number(1.0)
        }
        let holidays = if values.length() == 4 {
          collect_holidays(values[3])
        } else {
          []
        }
        workday_intl_value(start_serial, days, weekend_value, holidays)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "NOW" =>
      if values.length() == 0 {
        let now_ms = @env.now()
        let total_seconds = UInt64::to_double(now_ms) / 1000.0
        let days = Double::floor(total_seconds / 86400.0)
        let seconds_in_day = total_seconds - days * 86400.0
        let serial = days + 25569.0 + seconds_in_day / 86400.0
        FormulaValue::Number(serial)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TODAY" =>
      if values.length() == 0 {
        let now_ms = @env.now()
        let total_seconds = UInt64::to_double(now_ms) / 1000.0
        let days = Double::floor(total_seconds / 86400.0)
        FormulaValue::Number(days + 25569.0)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "YEAR" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((year, _, _, _, _, _)) =>
            FormulaValue::Number(Double::from_int(year))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MONTH" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((_, month, _, _, _, _)) =>
            FormulaValue::Number(Double::from_int(month))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "DAY" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((_, _, day, _, _, _)) =>
            FormulaValue::Number(Double::from_int(day))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "HOUR" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((_, _, _, hour, _, _)) =>
            FormulaValue::Number(Double::from_int(hour))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MINUTE" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((_, _, _, _, minute, _)) =>
            FormulaValue::Number(Double::from_int(minute))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SECOND" =>
      if values.length() == 1 {
        match excel_serial_parts(values[0]) {
          Ok((_, _, _, _, _, second)) =>
            FormulaValue::Number(Double::from_int(second))
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "INDEX" =>
      if args.length() == 2 || args.length() == 3 {
        let range = eval_range_expr(workbook, sheet_name, args[0], ctx)
        let row_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        let col_num = if args.length() == 3 {
          match value_as_int(values[2]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if row_num <= 0 || col_num <= 0 {
          FormulaValue::Error(formula_error_value)
        } else if row_num > range.rows || col_num > range.cols {
          FormulaValue::Error(formula_error_ref)
        } else {
          let index = (row_num - 1) * range.cols + (col_num - 1)
          range.values[index]
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "MATCH" =>
      if args.length() == 2 || args.length() == 3 {
        let lookup = values[0]
        let range = eval_range_expr(workbook, sheet_name, args[1], ctx)
        let match_type = if args.length() == 3 {
          match value_as_int(values[2]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        match_range_value(lookup, range, match_type)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "VLOOKUP" =>
      if args.length() == 3 || args.length() == 4 {
        let lookup = values[0]
        let table = eval_range_expr(workbook, sheet_name, args[1], ctx)
        let col_index = match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        let range_lookup = if args.length() == 4 {
          match lookup_range_flag(values[3]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          true
        }
        vlookup_value(lookup, table, col_index, range_lookup)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "HLOOKUP" =>
      if args.length() == 3 || args.length() == 4 {
        let lookup = values[0]
        let table = eval_range_expr(workbook, sheet_name, args[1], ctx)
        let row_index = match value_as_int(values[2]) {
          Ok(num) => num
          Err(err) => return err
        }
        let range_lookup = if args.length() == 4 {
          match lookup_range_flag(values[3]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          true
        }
        hlookup_value(lookup, table, row_index, range_lookup)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "LOOKUP" =>
      if args.length() == 2 || args.length() == 3 {
        let lookup = values[0]
        if args.length() == 2 {
          let array_range = range_from_expr_or_value(
            workbook,
            sheet_name,
            args[1],
            values[1],
            ctx,
          )
          if array_range.rows == 0 || array_range.cols == 0 {
            return FormulaValue::Error(formula_error_value)
          }
          if array_range.rows == 1 || array_range.cols == 1 {
            let lookup_vec = match range_vector(array_range) {
              Some(list) => list
              None => return FormulaValue::Error(formula_error_na)
            }
            let idx = match lookup_best_index(lookup, lookup_vec) {
              Ok(value) => value
              Err(err) => return err
            }
            match idx {
              Some(i) => lookup_vec[i]
              None => FormulaValue::Error(formula_error_na)
            }
          } else {
            let use_cols = array_range.rows >= array_range.cols
            let lookup_vec = if use_cols {
              range_column(array_range, 0)
            } else {
              range_row(array_range, 0)
            }
            let result_vec = if use_cols {
              range_column(array_range, array_range.cols - 1)
            } else {
              range_row(array_range, array_range.rows - 1)
            }
            let lookup_list = match lookup_vec {
              Some(list) => list
              None => return FormulaValue::Error(formula_error_na)
            }
            let result_list = match result_vec {
              Some(list) => list
              None => return FormulaValue::Error(formula_error_na)
            }
            let idx = match lookup_best_index(lookup, lookup_list) {
              Ok(value) => value
              Err(err) => return err
            }
            match idx {
              Some(i) =>
                if i >= result_list.length() {
                  FormulaValue::Error(formula_error_na)
                } else {
                  result_list[i]
                }
              None => FormulaValue::Error(formula_error_na)
            }
          }
        } else {
          let lookup_range = range_from_expr_or_value(
            workbook,
            sheet_name,
            args[1],
            values[1],
            ctx,
          )
          let result_range = range_from_expr_or_value(
            workbook,
            sheet_name,
            args[2],
            values[2],
            ctx,
          )
          if lookup_range.rows == 0 ||
            lookup_range.cols == 0 ||
            result_range.rows == 0 ||
            result_range.cols == 0 {
            return FormulaValue::Error(formula_error_value)
          }
          let lookup_list = match range_vector(lookup_range) {
            Some(list) => list
            None => return FormulaValue::Error(formula_error_na)
          }
          let result_list = match range_vector(result_range) {
            Some(list) => list
            None => return FormulaValue::Error(formula_error_na)
          }
          if lookup_list.length() != result_list.length() {
            return FormulaValue::Error(formula_error_na)
          }
          let idx = match lookup_best_index(lookup, lookup_list) {
            Ok(value) => value
            Err(err) => return err
          }
          match idx {
            Some(i) => result_list[i]
            None => FormulaValue::Error(formula_error_na)
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "XLOOKUP" =>
      if args.length() >= 3 && args.length() <= 6 {
        let lookup = values[0]
        let lookup_range = range_from_expr_or_value(
          workbook,
          sheet_name,
          args[1],
          values[1],
          ctx,
        )
        let return_range = range_from_expr_or_value(
          workbook,
          sheet_name,
          args[2],
          values[2],
          ctx,
        )
        let if_not_found = if args.length() >= 4 {
          values[3]
        } else {
          FormulaValue::Error(formula_error_na)
        }
        let match_mode = if args.length() >= 5 {
          match value_as_int(values[4]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          0
        }
        let search_mode = if args.length() >= 6 {
          match value_as_int(values[5]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if match_mode != -1 &&
          match_mode != 0 &&
          match_mode != 1 &&
          match_mode != 2 {
          return FormulaValue::Error(formula_error_value)
        }
        if search_mode != 1 &&
          search_mode != -1 &&
          search_mode != 2 &&
          search_mode != -2 {
          return FormulaValue::Error(formula_error_value)
        }
        let is_row = lookup_range.rows == 1
        let is_col = lookup_range.cols == 1
        if !is_row && !is_col {
          return FormulaValue::Error(formula_error_value)
        }
        let lookup_list = if is_row {
          range_row(lookup_range, 0)
        } else {
          range_column(lookup_range, 0)
        }
        let lookup_values = match lookup_list {
          Some(list) => list
          None => return FormulaValue::Error(formula_error_value)
        }
        let match_idx = match
          xlookup_find_index(lookup, lookup_values, match_mode, search_mode) {
          Ok(value) => value
          Err(err) => return err
        }
        let idx = match match_idx {
          Some(value) => value
          None => return if_not_found
        }
        if is_row {
          if return_range.cols != lookup_range.cols {
            return FormulaValue::Error(formula_error_value)
          }
          if return_range.rows == 1 {
            return_range.values[idx]
          } else {
            match range_column(return_range, idx) {
              Some(list) => FormulaValue::List(list)
              None => FormulaValue::Error(formula_error_value)
            }
          }
        } else {
          if return_range.rows != lookup_range.rows {
            return FormulaValue::Error(formula_error_value)
          }
          if return_range.cols == 1 {
            return_range.values[idx * return_range.cols]
          } else {
            match range_row(return_range, idx) {
              Some(list) => FormulaValue::List(list)
              None => FormulaValue::Error(formula_error_value)
            }
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ADDRESS" =>
      if values.length() >= 2 && values.length() <= 5 {
        let row_num = match value_as_int(values[0]) {
          Ok(num) => num
          Err(err) => return err
        }
        let col_num = match value_as_int(values[1]) {
          Ok(num) => num
          Err(err) => return err
        }
        if row_num <= 0 || col_num <= 0 {
          return FormulaValue::Error(formula_error_value)
        }
        let abs_num = if values.length() >= 3 {
          match value_as_int(values[2]) {
            Ok(num) => num
            Err(err) => return err
          }
        } else {
          1
        }
        if abs_num < 1 || abs_num > 4 {
          return FormulaValue::Error(formula_error_value)
        }
        let a1 = if values.length() >= 4 {
          match value_as_bool(values[3]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          true
        }
        let sheet_text = if values.length() == 5 {
          match value_as_string(values[4]) {
            Ok(text) => text
            Err(err) => return err
          }
        } else {
          ""
        }
        let address = if a1 {
          address_a1(row_num, col_num, abs_num) catch {
            _ => return FormulaValue::Error(formula_error_value)
          }
        } else {
          address_r1c1(row_num, col_num, abs_num)
        }
        let text = if sheet_text == "" {
          address
        } else {
          sheet_text + "!" + address
        }
        FormulaValue::String(text)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "INDIRECT" =>
      if values.length() == 1 || values.length() == 2 {
        let ref_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let a1 = if values.length() == 2 {
          match value_as_bool(values[1]) {
            Ok(flag) => flag
            Err(err) => return err
          }
        } else {
          true
        }
        let (sheet_text, ref_part) = split_sheet_ref(ref_text)
        let target_sheet = if sheet_text == "" {
          sheet_name
        } else {
          sheet_text
        }
        if a1 {
          match ref_part.find(":") {
            Some(idx) => {
              let start_token = ref_part.unsafe_substring(start=0, end=idx)
              let end_token = ref_part.unsafe_substring(
                start=idx + 1,
                end=ref_part.length(),
              )
              let (start_ref, _start_end) = parse_range_ref_token(start_token) catch {
                _ => return FormulaValue::Error(formula_error_ref)
              }
              let (_end_start, end_ref) = parse_range_ref_token(end_token) catch {
                _ => return FormulaValue::Error(formula_error_ref)
              }
              FormulaValue::List(
                collect_range_values(
                  workbook, target_sheet, start_ref, end_ref, ctx,
                ),
              )
            }
            None =>
              match parse_cell_ref_token(ref_part) {
                Some(reference) =>
                  resolve_cell_value(workbook, target_sheet, reference, ctx)
                None => {
                  let (start_ref, end_ref) = parse_range_ref_token(ref_part) catch {
                    _ => return FormulaValue::Error(formula_error_ref)
                  }
                  FormulaValue::List(
                    collect_range_values(
                      workbook, target_sheet, start_ref, end_ref, ctx,
                    ),
                  )
                }
              }
          }
        } else {
          match ref_part.find(":") {
            Some(idx) => {
              let start_token = ref_part.unsafe_substring(start=0, end=idx)
              let end_token = ref_part.unsafe_substring(
                start=idx + 1,
                end=ref_part.length(),
              )
              let (row1, col1) = match parse_r1c1_token(start_token) {
                Some(value) => value
                None => return FormulaValue::Error(formula_error_ref)
              }
              let (row2, col2) = match parse_r1c1_token(end_token) {
                Some(value) => value
                None => return FormulaValue::Error(formula_error_ref)
              }
              let start_ref = cell_ref_from(row1, col1) catch {
                _ => return FormulaValue::Error(formula_error_ref)
              }
              let end_ref = cell_ref_from(row2, col2) catch {
                _ => return FormulaValue::Error(formula_error_ref)
              }
              FormulaValue::List(
                collect_range_values(
                  workbook, target_sheet, start_ref, end_ref, ctx,
                ),
              )
            }
            None =>
              match parse_r1c1_token(ref_part) {
                Some((row, col)) => {
                  let reference = cell_ref_from(row, col) catch {
                    _ => return FormulaValue::Error(formula_error_ref)
                  }
                  resolve_cell_value(workbook, target_sheet, reference, ctx)
                }
                None => FormulaValue::Error(formula_error_ref)
              }
          }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "CHAR" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => {
            let code = Double::to_int(trunc_double(num))
            if code < 0 || code > max_field_length {
              FormulaValue::Error(formula_error_value)
            } else {
              FormulaValue::String(char_from_code(code))
            }
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "UNICHAR" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) =>
            if num <= 0.0 || num > 55295.0 {
              FormulaValue::Error(formula_error_value)
            } else {
              let code = Double::to_int(trunc_double(num))
              FormulaValue::String(char_from_code(code))
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "CLEAN" =>
      if values.length() == 1 {
        clean_text_value(values[0])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ENCODEURL" =>
      if values.length() == 1 {
        encode_url_value(values[0])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "BAHTTEXT" =>
      if values.length() == 1 {
        bahttext_values(values)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "CODE" =>
      if values.length() == 1 {
        code_value("CODE", values[0])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "UNICODE" =>
      if values.length() == 1 {
        code_value("UNICODE", values[0])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "HYPERLINK" =>
      if values.length() == 1 || values.length() == 2 {
        match value_as_string(values[values.length() - 1]) {
          Ok(text) => FormulaValue::String(text)
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "CHOOSE" =>
      if values.length() >= 2 {
        let index_text = match value_as_string(values[0]) {
          Ok(text) => text
          Err(err) => return err
        }
        let idx = @strconv.parse_int(index_text, base=10) catch {
          _ => return FormulaValue::Error(formula_error_value)
        }
        if values.length() <= idx {
          FormulaValue::Error(formula_error_value)
        } else if idx <= 0 {
          values[0]
        } else {
          values[idx]
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "CONCAT" | "CONCATENATE" => concat_values(values)
    "IF" =>
      if values.length() >= 2 {
        match value_as_bool(values[0]) {
          Ok(cond) =>
            if cond {
              values[1]
            } else if values.length() >= 3 {
              values[2]
            } else {
              FormulaValue::Bool(false)
            }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IFERROR" =>
      if values.length() == 2 {
        match normalize_scalar(values[0]) {
          FormulaValue::Error(_) => values[1]
          FormulaValue::Empty => FormulaValue::Number(0.0)
          _ => values[0]
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IFNA" =>
      if values.length() == 2 {
        match normalize_scalar(values[0]) {
          FormulaValue::Error(err) =>
            if err == formula_error_na {
              values[1]
            } else {
              values[0]
            }
          _ => values[0]
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "IFS" =>
      if values.length() < 2 || values.length() % 2 != 0 {
        FormulaValue::Error(formula_error_value)
      } else {
        for i in 0..<(values.length() / 2) {
          match value_as_bool(values[i * 2]) {
            Ok(flag) => if flag { return values[i * 2 + 1] }
            Err(err) => return err
          }
        }
        FormulaValue::Error(formula_error_na)
      }
    "SWITCH" =>
      if values.length() < 3 {
        FormulaValue::Error(formula_error_value)
      } else {
        let target = values[0]
        let arg_count = values.length() - 1
        let switch_count = arg_count / 2
        let has_default = arg_count % 2 != 0
        let mut result = if has_default {
          values[values.length() - 1]
        } else {
          FormulaValue::Error(formula_error_na)
        }
        for i in 0..<switch_count {
          let match_value = values[1 + i * 2]
          match compare_values(target, match_value) {
            Ok(0) => {
              result = values[1 + i * 2 + 1]
              break
            }
            Ok(_) => ()
            Err(err) => return err
          }
        }
        result
      }
    "ISBLANK" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          FormulaValue::Empty => FormulaValue::Bool(true)
          _ => FormulaValue::Bool(false)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISERR" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          FormulaValue::Error(err) =>
            FormulaValue::Bool(
              is_known_error_code(err) && err != formula_error_na,
            )
          _ => FormulaValue::Bool(false)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISEVEN" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          FormulaValue::Empty => FormulaValue::Bool(true)
          _ =>
            match value_as_number(values[0]) {
              Ok(num) => {
                let even = if num == 1.0 {
                  false
                } else {
                  num == num / 2.0 * 2.0
                }
                FormulaValue::Bool(even)
              }
              Err(err) => err
            }
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISODD" =>
      if values.length() == 1 {
        match value_as_number(values[0]) {
          Ok(num) => {
            let n = Double::to_int(num)
            FormulaValue::Bool(n != n / 2 * 2)
          }
          Err(err) => err
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISERROR" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          FormulaValue::Error(err) =>
            FormulaValue::Bool(is_known_error_code(err))
          _ => FormulaValue::Bool(false)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISLOGICAL" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          FormulaValue::Bool(_) => FormulaValue::Bool(true)
          FormulaValue::String(text) =>
            FormulaValue::Bool(text == "TRUE" || text == "FALSE")
          _ => FormulaValue::Bool(false)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISNA" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          FormulaValue::Error(err) =>
            FormulaValue::Bool(err == formula_error_na)
          _ => FormulaValue::Bool(false)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISNUMBER" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          FormulaValue::Number(_) => FormulaValue::Bool(true)
          _ => FormulaValue::Bool(false)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISTEXT" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          FormulaValue::String(text) =>
            match parse_double_opt(text) {
              Some(_) => FormulaValue::Bool(false)
              None => FormulaValue::Bool(true)
            }
          _ => FormulaValue::Bool(false)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISNONTEXT" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          FormulaValue::String(_) => FormulaValue::Bool(false)
          _ => FormulaValue::Bool(true)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISREF" =>
      if args.length() == 1 {
        FormulaValue::Bool(is_ref_expr(args[0]))
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ISFORMULA" =>
      if args.length() == 1 {
        match args[0] {
          Expr::Cell(sheet, reference) => {
            let target_sheet = if sheet == "" { sheet_name } else { sheet }
            FormulaValue::Bool(
              cell_has_formula(workbook, target_sheet, reference),
            )
          }
          _ => FormulaValue::Bool(false)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "ERRORdotTYPE" | "ERROR.TYPE" =>
      if values.length() == 1 {
        error_type_value(values[0])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SHEET" =>
      if args.length() == 0 {
        match sheet_index_opt(workbook, sheet_name) {
          Some(index) => FormulaValue::Number(Double::from_int(index + 1))
          None => FormulaValue::Error(formula_error_na)
        }
      } else if args.length() == 1 {
        let target_sheet = match args[0] {
          Expr::Cell(sheet, _) => if sheet == "" { sheet_name } else { sheet }
          Expr::Range(sheet, _, _) =>
            if sheet == "" {
              sheet_name
            } else {
              sheet
            }
          _ => formula_value_string(values[0])
        }
        match sheet_index_opt(workbook, target_sheet) {
          Some(index) => FormulaValue::Number(Double::from_int(index + 1))
          None => FormulaValue::Error(formula_error_na)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "SHEETS" =>
      if args.length() == 0 {
        FormulaValue::Number(Double::from_int(workbook.sheets().length()))
      } else if args.length() == 1 {
        match args[0] {
          Expr::Cell(_, _) | Expr::Range(_, _, _) => FormulaValue::Number(1.0)
          _ => FormulaValue::Error(formula_error_na)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "TYPE" =>
      if values.length() == 1 {
        type_value(values[0])
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "T" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          FormulaValue::Error(err) => FormulaValue::Error(err)
          FormulaValue::Number(_) => FormulaValue::String("")
          FormulaValue::String(text) => FormulaValue::String(text)
          FormulaValue::Bool(flag) =>
            FormulaValue::String(if flag { "TRUE" } else { "FALSE" })
          FormulaValue::Empty => FormulaValue::String("")
          FormulaValue::List(_) => FormulaValue::String("")
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "NA" =>
      if values.length() == 0 {
        FormulaValue::Error(formula_error_na)
      } else {
        FormulaValue::Error(formula_error_value)
      }
    "N" =>
      if values.length() == 1 {
        match normalize_scalar(values[0]) {
          FormulaValue::Error(err) => FormulaValue::Error(err)
          FormulaValue::Number(num) => FormulaValue::Number(num)
          FormulaValue::Bool(flag) =>
            FormulaValue::Number(if flag { 1.0 } else { 0.0 })
          FormulaValue::String(text) =>
            match parse_double_opt(text) {
              Some(num) => FormulaValue::Number(num)
              None =>
                if text == "TRUE" {
                  FormulaValue::Number(1.0)
                } else {
                  FormulaValue::Number(0.0)
                }
            }
          FormulaValue::Empty => FormulaValue::Number(0.0)
          FormulaValue::List(_) => FormulaValue::Number(0.0)
        }
      } else {
        FormulaValue::Error(formula_error_value)
      }
    _ => FormulaValue::Error(formula_error_name)
  }
}

///|
fn sum_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut sum = 0.0
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Number(num) => sum = sum + num
      FormulaValue::Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        sum = sum + num
      }
      FormulaValue::String(text) =>
        match parse_double_opt(text) {
          Some(num) => sum = sum + num
          None => ()
        }
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  FormulaValue::Number(sum)
}

///|
fn sumsq_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut sum = 0.0
  for value in values {
    match value {
      FormulaValue::List(list) =>
        for cell in list {
          match cell {
            FormulaValue::Number(num) => sum = sum + num * num
            FormulaValue::String(text) =>
              if text == "" {
                ()
              } else {
                match parse_double_opt(text) {
                  Some(num) => sum = sum + num * num
                  None => return FormulaValue::Error(formula_error_value)
                }
              }
            FormulaValue::Bool(_) =>
              return FormulaValue::Error(formula_error_value)
            FormulaValue::Error(_) =>
              return FormulaValue::Error(formula_error_value)
            FormulaValue::Empty => ()
            FormulaValue::List(_) => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          FormulaValue::Number(num) => sum = sum + num * num
          FormulaValue::Bool(flag) => {
            let num = if flag { 1.0 } else { 0.0 }
            sum = sum + num * num
          }
          FormulaValue::String(text) =>
            if text == "" {
              ()
            } else {
              match parse_double_opt(text) {
                Some(num) => sum = sum + num * num
                None => return FormulaValue::Error(formula_error_value)
              }
            }
          FormulaValue::Error(_) => ()
          FormulaValue::Empty => ()
          FormulaValue::List(_) => ()
        }
    }
  }
  FormulaValue::Number(sum)
}

///|
fn gcd_lcm_collect(
  value : FormulaValue,
  numbers : Array[Double],
  allow_empty_string : Bool,
) -> Result[Unit, FormulaValue] {
  match value {
    FormulaValue::List(list) => {
      for item in list {
        match gcd_lcm_collect(item, numbers, allow_empty_string) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      Ok(())
    }
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    FormulaValue::Number(num) => {
      numbers.push(num)
      Ok(())
    }
    FormulaValue::Bool(flag) => {
      numbers.push(if flag { 1.0 } else { 0.0 })
      Ok(())
    }
    FormulaValue::String(text) =>
      if text == "" {
        if allow_empty_string {
          Ok(())
        } else {
          Err(FormulaValue::Error(formula_error_value))
        }
      } else {
        match parse_double_opt(text) {
          Some(num) => {
            numbers.push(num)
            Ok(())
          }
          None => Err(FormulaValue::Error(formula_error_value))
        }
      }
    FormulaValue::Empty => {
      numbers.push(0.0)
      Ok(())
    }
  }
}

///|
fn gcd_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let numbers : Array[Double] = []
  for value in values {
    match gcd_lcm_collect(value, numbers, false) {
      Ok(_) => ()
      Err(err) => return err
    }
  }
  if numbers.length() == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  if numbers[0] < 0.0 {
    return FormulaValue::Error(formula_error_value)
  }
  if numbers.length() == 1 {
    return FormulaValue::Number(numbers[0])
  }
  let mut result = numbers[0]
  for i in 1..<numbers.length() {
    if numbers[i] < 0.0 {
      return FormulaValue::Error(formula_error_value)
    }
    result = gcd_double(result, numbers[i])
  }
  FormulaValue::Number(result)
}

///|
fn lcm_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let numbers : Array[Double] = []
  for value in values {
    match gcd_lcm_collect(value, numbers, true) {
      Ok(_) => ()
      Err(err) => return err
    }
  }
  if numbers.length() == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  if numbers[0] < 0.0 {
    return FormulaValue::Error(formula_error_value)
  }
  if numbers.length() == 1 {
    return FormulaValue::Number(numbers[0])
  }
  let mut result = numbers[0]
  for i in 1..<numbers.length() {
    if numbers[i] < 0.0 {
      return FormulaValue::Error(formula_error_value)
    }
    result = lcm_double(result, numbers[i])
  }
  FormulaValue::Number(result)
}

///|
let roman_table : Array[Array[RomanNumeral]] = [
  [
    { n: 1000.0, s: "M" },
    { n: 900.0, s: "CM" },
    { n: 500.0, s: "D" },
    { n: 400.0, s: "CD" },
    { n: 100.0, s: "C" },
    { n: 90.0, s: "XC" },
    { n: 50.0, s: "L" },
    { n: 40.0, s: "XL" },
    { n: 10.0, s: "X" },
    { n: 9.0, s: "IX" },
    { n: 5.0, s: "V" },
    { n: 4.0, s: "IV" },
    { n: 1.0, s: "I" },
  ],
  [
    { n: 1000.0, s: "M" },
    { n: 950.0, s: "LM" },
    { n: 900.0, s: "CM" },
    { n: 500.0, s: "D" },
    { n: 450.0, s: "LD" },
    { n: 400.0, s: "CD" },
    { n: 100.0, s: "C" },
    { n: 95.0, s: "VC" },
    { n: 90.0, s: "XC" },
    { n: 50.0, s: "L" },
    { n: 45.0, s: "VL" },
    { n: 40.0, s: "XL" },
    { n: 10.0, s: "X" },
    { n: 9.0, s: "IX" },
    { n: 5.0, s: "V" },
    { n: 4.0, s: "IV" },
    { n: 1.0, s: "I" },
  ],
  [
    { n: 1000.0, s: "M" },
    { n: 990.0, s: "XM" },
    { n: 950.0, s: "LM" },
    { n: 900.0, s: "CM" },
    { n: 500.0, s: "D" },
    { n: 490.0, s: "XD" },
    { n: 450.0, s: "LD" },
    { n: 400.0, s: "CD" },
    { n: 100.0, s: "C" },
    { n: 99.0, s: "IC" },
    { n: 90.0, s: "XC" },
    { n: 50.0, s: "L" },
    { n: 45.0, s: "VL" },
    { n: 40.0, s: "XL" },
    { n: 10.0, s: "X" },
    { n: 9.0, s: "IX" },
    { n: 5.0, s: "V" },
    { n: 4.0, s: "IV" },
    { n: 1.0, s: "I" },
  ],
  [
    { n: 1000.0, s: "M" },
    { n: 995.0, s: "VM" },
    { n: 990.0, s: "XM" },
    { n: 950.0, s: "LM" },
    { n: 900.0, s: "CM" },
    { n: 500.0, s: "D" },
    { n: 495.0, s: "VD" },
    { n: 490.0, s: "XD" },
    { n: 450.0, s: "LD" },
    { n: 400.0, s: "CD" },
    { n: 100.0, s: "C" },
    { n: 99.0, s: "IC" },
    { n: 90.0, s: "XC" },
    { n: 50.0, s: "L" },
    { n: 45.0, s: "VL" },
    { n: 40.0, s: "XL" },
    { n: 10.0, s: "X" },
    { n: 9.0, s: "IX" },
    { n: 5.0, s: "V" },
    { n: 4.0, s: "IV" },
    { n: 1.0, s: "I" },
  ],
  [
    { n: 1000.0, s: "M" },
    { n: 999.0, s: "IM" },
    { n: 995.0, s: "VM" },
    { n: 990.0, s: "XM" },
    { n: 950.0, s: "LM" },
    { n: 900.0, s: "CM" },
    { n: 500.0, s: "D" },
    { n: 499.0, s: "ID" },
    { n: 495.0, s: "VD" },
    { n: 490.0, s: "XD" },
    { n: 450.0, s: "LD" },
    { n: 400.0, s: "CD" },
    { n: 100.0, s: "C" },
    { n: 99.0, s: "IC" },
    { n: 90.0, s: "XC" },
    { n: 50.0, s: "L" },
    { n: 45.0, s: "VL" },
    { n: 40.0, s: "XL" },
    { n: 10.0, s: "X" },
    { n: 9.0, s: "IX" },
    { n: 5.0, s: "V" },
    { n: 4.0, s: "IV" },
    { n: 1.0, s: "I" },
  ],
]

///|
fn roman_string(value : Double, form : Int) -> String {
  let table = roman_table[form]
  let sb = StringBuilder::new()
  let mut remaining = trunc_double(value)
  for numeral in table {
    while remaining >= numeral.n {
      sb.write_view(numeral.s)
      remaining = remaining - numeral.n
    }
  }
  sb.to_string()
}

///|
let bitwise_max_value : Double = @math.pow(2.0, 48.0) - 1.0

///|
fn bitwise_number(value : FormulaValue) -> Result[Double, FormulaValue] {
  match normalize_scalar(value) {
    FormulaValue::Number(num) => Ok(num)
    FormulaValue::Bool(flag) => Ok(if flag { 1.0 } else { 0.0 })
    FormulaValue::Empty => Ok(0.0)
    FormulaValue::String(text) =>
      match parse_double_opt(text) {
        Some(num) => Ok(num)
        None => Err(FormulaValue::Error(formula_error_num))
      }
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    FormulaValue::List(_) => Err(FormulaValue::Error(formula_error_num))
  }
}

///|
fn bitwise_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  match (bitwise_number(values[0]), bitwise_number(values[1])) {
    (Ok(num1), Ok(num2)) =>
      if num1 < 0.0 ||
        num1 > bitwise_max_value ||
        num2 < 0.0 ||
        num2 > bitwise_max_value {
        FormulaValue::Error(formula_error_num)
      } else {
        let a = Double::to_int(trunc_double(num1))
        let b = Double::to_int(trunc_double(num2))
        let result = match name {
          "BITAND" => Int::land(a, b)
          "BITOR" => Int::lor(a, b)
          "BITXOR" => Int::lxor(a, b)
          "BITLSHIFT" => a << b
          "BITRSHIFT" => a >> b
          _ => 0
        }
        FormulaValue::Number(Double::from_int(result))
      }
    (Err(err), _) => err
    (_, Err(err)) => err
  }
}

///|
fn arabic_char_value(ch : Char) -> Int {
  match ch {
    'I' => 1
    'V' => 5
    'X' => 10
    'L' => 50
    'C' => 100
    'D' => 500
    'M' => 1000
    _ => 0
  }
}

///|
fn arabic_string_value(text : String) -> FormulaValue {
  if count_utf16_units(text) > 255 {
    return FormulaValue::Error(formula_error_value)
  }
  let upper = text.to_upper()
  let chars = upper.to_array()
  if chars.length() == 0 {
    return FormulaValue::Number(0.0)
  }
  let mut index = chars.length() - 1
  let mut actual_start = 0
  while index >= 0 && chars[index] == ' ' {
    index = index - 1
  }
  while actual_start <= index && chars[actual_start] == ' ' {
    actual_start = actual_start + 1
  }
  let mut is_negative = false
  if actual_start <= index && chars[actual_start] == '-' {
    is_negative = true
    actual_start = actual_start + 1
  }
  if actual_start > index {
    return FormulaValue::Number(0.0)
  }
  let mut number = 0
  let mut subtract_number = 0
  let mut prev_char_value = -1
  while index >= actual_start {
    let start_index = index
    let start_char = chars[start_index]
    index = index - 1
    while index >= actual_start && chars[index] == start_char {
      index = index - 1
    }
    let current_char_value = arabic_char_value(start_char)
    let current_part_value = (start_index - index) * current_char_value
    if current_char_value >= prev_char_value {
      number = number + current_part_value - subtract_number
      prev_char_value = current_char_value
      subtract_number = 0
    } else {
      subtract_number = subtract_number + current_part_value
    }
  }
  if subtract_number != 0 {
    number = number - subtract_number
  }
  if is_negative {
    number = -number
  }
  FormulaValue::Number(Double::from_int(number))
}

///|
fn base_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 2 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let radix = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let base = Double::to_int(trunc_double(radix))
  if base < 2 || base > 36 {
    return FormulaValue::Error(formula_error_value)
  }
  let mut min_length = 0
  if values.length() == 3 {
    match value_as_string(values[2]) {
      Ok(text) =>
        min_length = @strconv.parse_int(text, base=10) catch {
          _ => return FormulaValue::Error(formula_error_value)
        }
      Err(err) => return err
    }
  }
  let number_int = Double::to_int(trunc_double(number))
  let mut text = Int::to_string(number_int, radix=base).to_upper()
  if min_length > text.length() {
    let pad = "0".repeat(min_length - text.length())
    text = pad + text
  }
  FormulaValue::String(text)
}

///|
fn dec2x_limits(name : String) -> (Double, Double, Int) {
  match name {
    "DEC2BIN" | "HEX2BIN" | "OCT2BIN" => (511.0, -512.0, 2)
    "BIN2HEX" | "DEC2HEX" | "OCT2HEX" => (549755813887.0, -549755813888.0, 16)
    "BIN2OCT" | "DEC2OCT" | "HEX2OCT" => (536870911.0, -536870912.0, 8)
    _ => (0.0, 0.0, 10)
  }
}

///|
fn dec2x_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() < 1 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let decimal = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let (max_limit, min_limit, base) = dec2x_limits(name)
  if decimal < min_limit || decimal > max_limit {
    return FormulaValue::Error(formula_error_num)
  }
  let decimal_int = Double::to_int64(trunc_double(decimal))
  let raw = Int64::reinterpret_as_uint64(decimal_int)
  let mut digits = UInt64::to_string(raw, radix=base)
  if values.length() == 2 {
    let places_num = match value_as_number(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
    if places_num < 0.0 || places_num > 10.0 {
      return FormulaValue::Error(formula_error_num)
    }
    let places = Double::to_int(trunc_double(places_num))
    if digits.length() > places {
      return FormulaValue::Error(formula_error_num)
    }
    let pad = "0".repeat(places - digits.length())
    digits = pad + digits
    return FormulaValue::String(digits.to_upper())
  }
  if decimal < 0.0 && digits.length() > 10 {
    let chars = digits.to_array()
    let start = chars.length() - 10
    let sb = StringBuilder::new()
    for i in start..<chars.length() {
      sb.write_char(chars[i])
    }
    return FormulaValue::String(sb.to_string().to_upper())
  }
  FormulaValue::String(digits.to_upper())
}

///|
fn bin2dec_string(text : String) -> FormulaValue {
  let chars = text.to_array()
  let mut decimal = 0.0
  let length = chars.length()
  for i in 1..<=length {
    let idx = length - i
    let ch = chars[idx]
    if i == 10 && ch == '1' {
      decimal = decimal + @math.pow(-2.0, Double::from_int(i - 1))
      continue
    }
    if ch == '1' {
      decimal = decimal + @math.pow(2.0, Double::from_int(i - 1))
      continue
    }
    if ch != '0' {
      return FormulaValue::Error(formula_error_num)
    }
  }
  FormulaValue::Number(decimal)
}

///|
fn hex_digit_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn hex2dec_string(text : String) -> FormulaValue {
  let chars = text.to_array()
  let mut decimal = 0.0
  let length = chars.length()
  for i in 1..<=length {
    let idx = length - i
    let ch = chars[idx]
    match hex_digit_value(ch) {
      Some(value) => {
        if i == 10 && ch == 'F' {
          decimal = decimal + @math.pow(-16.0, Double::from_int(i - 1))
          continue
        }
        decimal = decimal +
          Double::from_int(value) * @math.pow(16.0, Double::from_int(i - 1))
      }
      None => return FormulaValue::Error(formula_error_num)
    }
  }
  FormulaValue::Number(decimal)
}

///|
fn oct2dec_string(text : String) -> FormulaValue {
  let chars = text.to_array()
  let mut decimal = 0.0
  let length = chars.length()
  for i in 1..<=length {
    let idx = length - i
    let ch = chars[idx]
    let digit = @strconv.parse_int(String::from_array([ch]), base=10) catch {
      _ => return FormulaValue::Error(formula_error_num)
    }
    if digit < 0 || digit > 7 {
      return FormulaValue::Error(formula_error_num)
    }
    if i == 10 && ch == '7' {
      decimal = decimal + @math.pow(-8.0, Double::from_int(i - 1))
      continue
    }
    decimal = decimal +
      Double::from_int(digit) * @math.pow(8.0, Double::from_int(i - 1))
  }
  FormulaValue::Number(decimal)
}

///|
fn combin_values(number : Double, chosen : Double) -> FormulaValue {
  let n = trunc_double(number)
  let k = trunc_double(chosen)
  if k > n {
    return FormulaValue::Error(formula_error_value)
  }
  if k == n || k == 0.0 {
    return FormulaValue::Number(1.0)
  }
  let mut val = 1.0
  let k_int = Double::to_int(k)
  for i in 1..<=k_int {
    let c = Double::from_int(i)
    val = val * (n + 1.0 - c) / c
  }
  FormulaValue::Number(Double::ceil(val))
}

///|
fn factorial_double(number : Double) -> Double {
  let n = trunc_double(number)
  if n < 2.0 {
    return 1.0
  }
  let n_int = Double::to_int(n)
  let mut value = 1.0
  for i in 2..<=n_int {
    value = value * Double::from_int(i)
  }
  value
}

///|
fn binom_coeff_double(n : Double, k : Double) -> Double {
  factorial_double(n) / (factorial_double(k) * factorial_double(n - k))
}

///|
fn double_factorial_double(number : Double) -> Double {
  let n = trunc_double(number)
  if n < 2.0 {
    return 1.0
  }
  let mut value = 1.0
  let mut i = Double::to_int(n)
  while i > 1 {
    value = value * Double::from_int(i)
    i = i - 2
  }
  value
}

///|
fn multinomial_collect(
  value : FormulaValue,
  numbers : Array[Double],
) -> Result[Unit, FormulaValue] {
  match value {
    FormulaValue::List(list) => {
      for item in list {
        match multinomial_collect(item, numbers) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      }
      Ok(())
    }
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    FormulaValue::Number(num) => {
      numbers.push(num)
      Ok(())
    }
    FormulaValue::Bool(flag) => {
      numbers.push(if flag { 1.0 } else { 0.0 })
      Ok(())
    }
    FormulaValue::String(text) =>
      if text == "" {
        Ok(())
      } else {
        match parse_double_opt(text) {
          Some(num) => {
            numbers.push(num)
            Ok(())
          }
          None => Err(FormulaValue::Error(formula_error_value))
        }
      }
    FormulaValue::Empty => Ok(())
  }
}

///|
fn multinomial_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match multinomial_collect(value, numbers) {
      Ok(_) => ()
      Err(err) => return err
    }
  }
  let mut numerator = 0.0
  let mut denominator = 1.0
  for num in numbers {
    numerator = numerator + num
    denominator = denominator * factorial_double(num)
  }
  FormulaValue::Number(factorial_double(numerator) / denominator)
}

///|
fn product_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut product = 1.0
  for value in values {
    match value {
      FormulaValue::List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            FormulaValue::Error(err) => return FormulaValue::Error(err)
            FormulaValue::Number(num) => product = product * num
            FormulaValue::Bool(_) => ()
            FormulaValue::String(_) => ()
            FormulaValue::Empty => ()
            FormulaValue::List(_) => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          FormulaValue::Error(err) => return FormulaValue::Error(err)
          FormulaValue::Number(num) => product = product * num
          FormulaValue::Bool(flag) => {
            let num = if flag { 1.0 } else { 0.0 }
            product = product * num
          }
          FormulaValue::String(text) =>
            match parse_double_opt(text) {
              Some(num) => product = product * num
              None => return FormulaValue::Error(formula_error_value)
            }
          FormulaValue::Empty => ()
          FormulaValue::List(_) => ()
        }
    }
  }
  FormulaValue::Number(product)
}

///|
fn average_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut sum = 0.0
  let mut count = 0
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Number(num) => {
        sum = sum + num
        count = count + 1
      }
      FormulaValue::String(text) =>
        match parse_double_opt(text) {
          Some(num) => {
            sum = sum + num
            count = count + 1
          }
          None => ()
        }
      FormulaValue::Bool(_) => ()
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  if count == 0 {
    FormulaValue::Error(formula_error_div)
  } else {
    FormulaValue::Number(sum / Double::from_int(count))
  }
}

///|
fn averagea_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut sum = 0.0
  let mut count = 0
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Number(num) => {
        sum = sum + num
        count = count + 1
      }
      FormulaValue::Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        sum = sum + num
        count = count + 1
      }
      FormulaValue::String(text) =>
        if text == "" {
          ()
        } else if text == "TRUE" || text == "FALSE" {
          let num = if text == "TRUE" { 1.0 } else { 0.0 }
          sum = sum + num
          count = count + 1
        } else {
          match parse_double_opt(text) {
            Some(num) => {
              sum = sum + num
              count = count + 1
            }
            None => count = count + 1
          }
        }
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  if count == 0 {
    FormulaValue::Error(formula_error_div)
  } else {
    FormulaValue::Number(sum / Double::from_int(count))
  }
}

///|
fn stdev_add(
  sum : Double,
  count : Int,
  value : Double,
  mean : Double,
) -> (Double, Int) {
  let delta = value - mean
  let next_sum = if sum < 0.0 { delta * delta } else { sum + delta * delta }
  (next_sum, count + 1)
}

///|
fn stdev_values(
  stdeva : Bool,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  let mean_value = if stdeva {
    averagea_values(values)
  } else {
    average_values(values)
  }
  let mean = match mean_value {
    FormulaValue::Number(num) => num
    FormulaValue::Error(err) => return FormulaValue::Error(err)
    _ => return FormulaValue::Error(formula_error_value)
  }
  let mut sum = -1.0
  let mut count = -1
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Number(num) => {
        let (next_sum, next_count) = stdev_add(sum, count, num, mean)
        sum = next_sum
        count = next_count
      }
      FormulaValue::Bool(flag) =>
        if stdeva {
          let num = if flag { 1.0 } else { 0.0 }
          let (next_sum, next_count) = stdev_add(sum, count, num, mean)
          sum = next_sum
          count = next_count
        }
      FormulaValue::String(text) =>
        if text == "TRUE" || text == "FALSE" {
          if stdeva {
            let num = if text == "TRUE" { 1.0 } else { 0.0 }
            let (next_sum, next_count) = stdev_add(sum, count, num, mean)
            sum = next_sum
            count = next_count
          }
        } else {
          match parse_double_opt(text) {
            Some(num) => {
              let (next_sum, next_count) = stdev_add(sum, count, num, mean)
              sum = next_sum
              count = next_count
            }
            None => ()
          }
        }
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  if count > 0 && sum >= 0.0 {
    let result = @math.pow(sum / Double::from_int(count), 0.5)
    FormulaValue::Number(round_significant_digits(result, 15))
  } else {
    FormulaValue::Error(formula_error_div)
  }
}

///|
fn variance_values(
  values : ArrayView[FormulaValue],
  sample : Bool,
  count_text_zero : Bool,
) -> FormulaValue {
  let mut sum = 0.0
  let mut sum_sq = 0.0
  let mut count = 0
  let minimum = if sample { 1 } else { 0 }
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Empty => ()
      FormulaValue::Number(num) => {
        sum = sum + num
        sum_sq = sum_sq + num * num
        count = count + 1
      }
      FormulaValue::Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        sum = sum + num
        sum_sq = sum_sq + num * num
        count = count + 1
      }
      FormulaValue::String(text) =>
        if text == "" {
          ()
        } else if text == "TRUE" || text == "FALSE" {
          let num = if text == "TRUE" { 1.0 } else { 0.0 }
          sum = sum + num
          sum_sq = sum_sq + num * num
          count = count + 1
        } else {
          match parse_double_opt(text) {
            Some(num) => {
              sum = sum + num
              sum_sq = sum_sq + num * num
              count = count + 1
            }
            None => if count_text_zero { count = count + 1 } else { () }
          }
        }
      FormulaValue::List(_) => ()
    }
  }
  if count > minimum {
    let count_d = Double::from_int(count)
    let min_d = Double::from_int(minimum)
    let variance = (sum_sq * count_d - sum * sum) /
      (count_d * (count_d - min_d))
    FormulaValue::Number(round_significant_digits(variance, 15))
  } else {
    FormulaValue::Error(formula_error_div)
  }
}

///|
fn trimmean_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let percent = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if percent < 0.0 || percent >= 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let numbers : Array[Double] = []
  let list_values : Array[FormulaValue] = [values[0]]
  for value in flatten_values(list_values) {
    match normalize_scalar(value) {
      FormulaValue::Number(num) => numbers.push(num)
      _ => ()
    }
  }
  if numbers.length() == 0 {
    return FormulaValue::Error(formula_error_div)
  }
  numbers.sort()
  let discard = Double::floor(
    Double::from_int(numbers.length()) * percent / 2.0,
  ).to_int()
  let start = discard
  let end = numbers.length() - discard
  if end <= start {
    return FormulaValue::Error(formula_error_div)
  }
  let mut sum = 0.0
  let mut count = 0
  for i in start..<end {
    sum = sum + numbers[i]
    count = count + 1
  }
  if count == 0 {
    FormulaValue::Error(formula_error_div)
  } else {
    FormulaValue::Number(sum / Double::from_int(count))
  }
}

///|
fn beta_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 4 || values.length() > 6 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let alpha = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let beta = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if alpha <= 0.0 || beta <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  let mut a = 0.0
  let mut b = 1.0
  if values.length() > 4 {
    a = match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if values.length() == 6 {
    b = match value_as_number(values[5]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if x < a || x > b {
    return FormulaValue::Error(formula_error_num)
  }
  if a == b {
    return FormulaValue::Error(formula_error_num)
  }
  let scale = b - a
  let normalized = (x - a) / scale
  let raw = if cumulative {
    get_beta_dist(normalized, alpha, beta)
  } else {
    get_beta_dist_pdf(normalized, alpha, beta) / scale
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn betadist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 || values.length() > 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let alpha = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let beta = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if alpha <= 0.0 || beta <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let mut a = 0.0
  let mut b = 1.0
  if values.length() > 3 {
    a = match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if values.length() == 5 {
    b = match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if x < a || x > b {
    return FormulaValue::Error(formula_error_num)
  }
  if a == b {
    return FormulaValue::Error(formula_error_num)
  }
  let normalized = (x - a) / (b - a)
  let raw = get_beta_dist(normalized, alpha, beta)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn get_beta_inv(probability : Double, alpha : Double, beta : Double) -> Double {
  if probability <= 0.0 {
    return 0.0
  }
  if probability >= 1.0 {
    return 1.0
  }
  let mut low = 0.0
  let mut high = 1.0
  let mut mid = 0.5
  for _ in 0..<200 {
    mid = (low + high) * 0.5
    let cdf = get_beta_dist(mid, alpha, beta)
    if cdf > probability {
      high = mid
    } else {
      low = mid
    }
  }
  mid
}

///|
fn betainv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 || values.length() > 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability >= 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let alpha = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let beta = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if alpha <= 0.0 || beta <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let mut a = 0.0
  let mut b = 1.0
  if values.length() > 3 {
    a = match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if values.length() == 5 {
    b = match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  if a == b {
    return FormulaValue::Error(formula_error_num)
  }
  let mid = get_beta_inv(probability, alpha, beta)
  let scaled = a + mid * (b - a)
  number_or_num_error(round_significant_digits(scaled, 15))
}

///|
fn normdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if std_dev < 0.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let raw = if cumulative {
    norm_cdf(x, mean, std_dev)
  } else {
    norm_pdf(x, mean, std_dev)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn norminv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability > 1.0 {
    return FormulaValue::Error(formula_error_na)
  }
  if std_dev < 0.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let inv = match norminv_double(probability) {
    Ok(value) => value
    Err(err) => return err
  }
  let raw = inv * std_dev + mean
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn norm_s_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[1]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  let raw = if cumulative { get_norm_s_dist(x) } else { norm_pdf(x, 0.0, 1.0) }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn norms_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  number_or_num_error(round_significant_digits(get_norm_s_dist(x), 15))
}

///|
fn norm_s_inv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return FormulaValue::Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability > 1.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let inv = match norminv_double(probability) {
    Ok(value) => value
    Err(err) => return err
  }
  number_or_num_error(round_significant_digits(inv, 15))
}

///|
fn norms_inv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  norm_s_inv_values(values)
}

///|
fn confidence_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let alpha = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let size = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if alpha <= 0.0 || alpha >= 1.0 || std_dev <= 0.0 || size < 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let inv = match norminv_double(alpha / 2.0) {
    Ok(value) => value
    Err(err) => return err
  }
  let raw = -inv * (std_dev / Double::sqrt(size))
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn confidence_t_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let alpha = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let size = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if alpha <= 0.0 || alpha >= 1.0 || std_dev <= 0.0 || size < 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  if size == 1.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let iterator = InverseIterator::{
    fp: alpha,
    fdf: size - 1.0,
    nt: 2.0,
    kind: InverseKind::TDist,
  }
  let result = calc_iterate_inverse(iterator, size / 2.0, size)
  let raw = std_dev * result / Double::sqrt(size)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn loginv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability >= 1.0 || std_dev <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let inv = match norminv_double(probability) {
    Ok(value) => value
    Err(err) => return err
  }
  let raw = @math.exp(mean + std_dev * inv)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gamma_value(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return FormulaValue::Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if number <= 0.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let raw = get_gamma(number)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gamma_pdf(x : Double, alpha : Double, beta : Double) -> Double {
  let denom = @math.pow(beta, alpha) * get_gamma(alpha)
  @math.pow(x, alpha - 1.0) * @math.exp(-x / beta) / denom
}

///|
fn gamma_cdf(x : Double, alpha : Double, beta : Double) -> Double {
  get_low_reg_igamma(alpha, x / beta)
}

///|
fn gamma_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let alpha = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let beta = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if x < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  if alpha <= 0.0 || beta <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = if cumulative {
    gamma_cdf(x, alpha, beta)
  } else {
    gamma_pdf(x, alpha, beta)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gammainv_double(
  probability : Double,
  alpha : Double,
  beta : Double,
) -> Double {
  let mut x_lo = 0.0
  let mut x_hi = alpha * beta * 5.0
  let mut dx = 1024.0
  let mut x = 1.0
  let mut x_new = 1.0
  let mut result = 0.0
  let mut count = 0
  while Double::abs(dx) > 8.88e-016 && count <= 256 {
    result = gamma_cdf(x, alpha, beta)
    let diff = result - probability
    if diff == 0.0 {
      dx = 0.0
    } else if diff < 0.0 {
      x_lo = x
    } else {
      x_hi = x
    }
    let pdf = gamma_pdf(x, alpha, beta)
    if pdf != 0.0 {
      dx = diff / pdf
      x_new = x - dx
    }
    if x_new < x_lo || x_new > x_hi || pdf == 0.0 {
      x_new = (x_lo + x_hi) / 2.0
      dx = x_new - x
    }
    x = x_new
    count = count + 1
  }
  x
}

///|
fn gamma_inv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let alpha = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let beta = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability >= 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  if alpha <= 0.0 || beta <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = gammainv_double(probability, alpha, beta)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gammaln_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x <= 0.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let raw = get_log_gamma(x)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gammaln_precise_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = get_log_gamma(x)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn lognorm_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if x <= 0.0 || std_dev <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  if cumulative {
    let z = (@math.ln(x) - mean) / std_dev
    return number_or_num_error(round_significant_digits(get_norm_s_dist(z), 15))
  }
  let denom = Double::sqrt(2.0 * @math.PI) * std_dev * x
  let exponent = -(@math.pow(@math.ln(x) - mean, 2.0) /
    (2.0 * std_dev * std_dev))
  let raw = @math.exp(exponent) / denom
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn lognormdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let std_dev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x <= 0.0 || std_dev <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let z = (@math.ln(x) - mean) / std_dev
  number_or_num_error(round_significant_digits(get_norm_s_dist(z), 15))
}

///|
fn expon_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let lambda = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[2]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if x < 0.0 || lambda <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = if cumulative {
    1.0 - @math.exp(-lambda * x)
  } else {
    lambda * @math.exp(-lambda * x)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn poisson_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[2]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if x < 0.0 || mean <= 0.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let raw = if cumulative {
    let mut sum = 0.0
    let limit = Double::to_int(Double::floor(x))
    for i in 0..<=limit {
      let i_double = Double::from_int(i)
      sum = sum + @math.pow(mean, i_double) / factorial_double(i_double)
    }
    @math.exp(-mean) * sum
  } else {
    @math.exp(-mean) * @math.pow(mean, x) / factorial_double(x)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn binomdist_double(x : Double, n : Double, p : Double) -> Double {
  binom_coeff_double(n, x) * @math.pow(p, x) * @math.pow(1.0 - p, n - x)
}

///|
fn binominv_double(n : Double, p : Double, alpha : Double) -> Double {
  let q = 1.0 - p
  let mut i = 0.0
  let mut sum = 0.0
  let n = Double::floor(n)
  if q > p {
    let mut factor = @math.pow(q, n)
    sum = factor
    while i < n && sum < alpha {
      factor = factor * (n - i) / (i + 1.0) * p / q
      sum = sum + factor
      i = i + 1.0
    }
    return i
  }
  let mut factor = @math.pow(p, n)
  sum = 1.0 - factor
  while i < n && sum >= alpha {
    factor = factor * (n - i) / (i + 1.0) * q / p
    sum = sum - factor
    i = i + 1.0
  }
  n - i
}

///|
fn binomdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let successes = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let trials = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if successes < 0.0 || successes > trials {
    return FormulaValue::Error(formula_error_num)
  }
  let probability = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability > 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  let raw = if cumulative {
    let mut sum = 0.0
    let limit = Double::to_int(Double::floor(successes))
    for i in 0..<=limit {
      let i_double = Double::from_int(i)
      sum = sum + binomdist_double(i_double, trials, probability)
    }
    sum
  } else {
    binomdist_double(successes, trials, probability)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn binom_dist_range_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let trials = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let probability = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability > 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let number_s = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if number_s < 0.0 || number_s > trials {
    return FormulaValue::Error(formula_error_num)
  }
  let number_s2 = if values.length() == 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    number_s
  }
  if number_s2 < 0.0 || number_s2 > trials {
    return FormulaValue::Error(formula_error_num)
  }
  let mut sum = 0.0
  let mut i = number_s
  while i <= number_s2 {
    sum = sum + binomdist_double(i, trials, probability)
    i = i + 1.0
  }
  number_or_num_error(round_significant_digits(sum, 15))
}

///|
fn binom_inv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let trials = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if trials < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let probability = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability >= 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let alpha = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if alpha <= 0.0 || alpha >= 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = binominv_double(trials, probability, alpha)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn hypgeom_args_invalid(
  sample_s : Double,
  number_sample : Double,
  population_s : Double,
  number_pop : Double,
) -> Bool {
  let upper = if number_sample < population_s {
    number_sample
  } else {
    population_s
  }
  let lower_raw = number_sample - number_pop + population_s
  let lower = if lower_raw > 0.0 { lower_raw } else { 0.0 }
  sample_s < 0.0 ||
  sample_s > upper ||
  sample_s < lower ||
  number_sample <= 0.0 ||
  number_sample > number_pop ||
  population_s <= 0.0 ||
  population_s > number_pop ||
  number_pop <= 0.0
}

///|
fn hypgeom_raw(
  sample_s : Double,
  number_sample : Double,
  population_s : Double,
  number_pop : Double,
) -> Double {
  binom_coeff_double(population_s, sample_s) *
  binom_coeff_double(number_pop - population_s, number_sample - sample_s) /
  binom_coeff_double(number_pop, number_sample)
}

///|
fn hypgeom_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let sample_s = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_sample = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let population_s = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_pop = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if hypgeom_args_invalid(sample_s, number_sample, population_s, number_pop) {
    return FormulaValue::Error(formula_error_num)
  }
  let cumulative = match value_as_bool(values[4]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  let raw = if cumulative {
    let mut sum = 0.0
    let limit = Double::to_int(Double::floor(sample_s))
    for i in 0..<=limit {
      let i_double = Double::from_int(i)
      sum = sum + hypgeom_raw(i_double, number_sample, population_s, number_pop)
    }
    sum
  } else {
    hypgeom_raw(sample_s, number_sample, population_s, number_pop)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn hypgeomdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let sample_s = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_sample = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let population_s = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let number_pop = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if hypgeom_args_invalid(sample_s, number_sample, population_s, number_pop) {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = hypgeom_raw(sample_s, number_sample, population_s, number_pop)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn negbinom_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let failures = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let successes = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let probability = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if failures < 0.0 || successes < 1.0 || probability < 0.0 || probability > 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = if cumulative {
    1.0 - get_beta_dist(1.0 - probability, failures + 1.0, successes)
  } else {
    binom_coeff_double(failures + successes - 1.0, successes - 1.0) *
    @math.pow(probability, successes) *
    @math.pow(1.0 - probability, failures)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn negbinomdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let failures = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let successes = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let probability = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if failures < 0.0 || successes < 1.0 || probability < 0.0 || probability > 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = binom_coeff_double(failures + successes - 1.0, successes - 1.0) *
    @math.pow(probability, successes) *
    @math.pow(1.0 - probability, failures)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn gauss_value(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let raw = get_norm_s_dist(x) - 0.5
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn phi_value(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 1 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let raw = 0.39894228040143268 * @math.exp(-(x * x) / 2.0)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn tdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[2]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if cumulative {
    if degrees < 1.0 {
      return FormulaValue::Error(formula_error_num)
    }
    let raw = get_t_dist(x, degrees, 4.0)
    return number_or_num_error(round_significant_digits(raw, 14))
  }
  if degrees < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  if degrees == 0.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let raw = get_t_dist(x, degrees, 3.0)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn tdist_2t_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x < 0.0 || degrees < 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = get_t_dist(x, degrees, 2.0)
  number_or_num_error(round_significant_digits(raw, 14))
}

///|
fn tdist_rt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if degrees < 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let mut value = get_t_dist(x, degrees, 1.0)
  if x < 0.0 {
    value = 1.0 - value
  }
  number_or_num_error(round_significant_digits(value, 14))
}

///|
fn tdist_legacy_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let tails = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x < 0.0 || degrees < 1.0 || (tails != 1.0 && tails != 2.0) {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = get_t_dist(x, degrees, tails)
  number_or_num_error(round_significant_digits(raw, 14))
}

///|
fn tinv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability >= 1.0 || degrees < 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let iterator = if probability < 0.5 {
    InverseIterator::{
      fp: 1.0 - probability,
      fdf: degrees,
      nt: 4.0,
      kind: InverseKind::TDist,
    }
  } else {
    InverseIterator::{
      fp: probability,
      fdf: degrees,
      nt: 4.0,
      kind: InverseKind::TDist,
    }
  }
  let mut result = calc_iterate_inverse(iterator, degrees / 2.0, degrees)
  if probability < 0.5 {
    result = -result
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn tinv_2t_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability > 1.0 || degrees < 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let iterator = InverseIterator::{
    fp: probability,
    fdf: degrees,
    nt: 2.0,
    kind: InverseKind::TDist,
  }
  let result = calc_iterate_inverse(iterator, degrees / 2.0, degrees)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn number_strict_opt(value : FormulaValue) -> Double? {
  match normalize_scalar(value) {
    FormulaValue::Number(num) => Some(num)
    _ => None
  }
}

///|
fn ttest_unpaired(
  array1 : ArrayView[FormulaValue],
  array2 : ArrayView[FormulaValue],
  unequal : Bool,
) -> (Double, Double, Bool) {
  let mut sum1 = 0.0
  let mut sum_sqr1 = 0.0
  let mut cnt1 = 0.0
  for value in array1 {
    match number_strict_opt(value) {
      Some(num) => {
        sum1 = sum1 + num
        sum_sqr1 = sum_sqr1 + num * num
        cnt1 = cnt1 + 1.0
      }
      None => ()
    }
  }
  let mut sum2 = 0.0
  let mut sum_sqr2 = 0.0
  let mut cnt2 = 0.0
  for value in array2 {
    match number_strict_opt(value) {
      Some(num) => {
        sum2 = sum2 + num
        sum_sqr2 = sum_sqr2 + num * num
        cnt2 = cnt2 + 1.0
      }
      None => ()
    }
  }
  if cnt1 < 2.0 || cnt2 < 2.0 {
    return (0.0, 0.0, false)
  }
  if unequal {
    let fs1 = (sum_sqr1 - sum1 * sum1 / cnt1) / (cnt1 - 1.0) / cnt1
    let fs2 = (sum_sqr2 - sum2 * sum2 / cnt2) / (cnt2 - 1.0) / cnt2
    if fs1 + fs2 == 0.0 {
      return (0.0, 0.0, false)
    }
    let c = fs1 / (fs1 + fs2)
    let t_value = Double::abs(sum1 / cnt1 - sum2 / cnt2) /
      Double::sqrt(fs1 + fs2)
    let df = 1.0 / (c * c / (cnt1 - 1.0) + (1.0 - c) * (1.0 - c) / (cnt2 - 1.0))
    return (t_value, df, true)
  }
  let fs1 = (sum_sqr1 - sum1 * sum1 / cnt1) / (cnt1 - 1.0)
  let fs2 = (sum_sqr2 - sum2 * sum2 / cnt2) / (cnt2 - 1.0)
  let denom = (cnt1 - 1.0) * fs1 + (cnt2 - 1.0) * fs2
  let t_value = Double::abs(sum1 / cnt1 - sum2 / cnt2) /
    Double::sqrt(denom) *
    Double::sqrt(cnt1 * cnt2 * (cnt1 + cnt2 - 2.0) / (cnt1 + cnt2))
  let df = cnt1 + cnt2 - 2.0
  (t_value, df, true)
}

///|
fn ttest_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let (array1, array2) = match (values[0], values[1]) {
    (FormulaValue::List(left), FormulaValue::List(right)) => (left, right)
    _ => return FormulaValue::Error(formula_error_num)
  }
  let tails = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let test_type = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if tails != 1.0 && tails != 2.0 {
    return FormulaValue::Error(formula_error_num)
  }
  if test_type != 1.0 && test_type != 2.0 && test_type != 3.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let (t_value, df) = if test_type == 1.0 {
    if array1.length() != array2.length() {
      return FormulaValue::Error(formula_error_na)
    }
    let mut sum1 = 0.0
    let mut sum2 = 0.0
    let mut sum_sqr_d = 0.0
    let mut cnt = 0.0
    for i in 0..<array1.length() {
      match (number_strict_opt(array1[i]), number_strict_opt(array2[i])) {
        (Some(lhs), Some(rhs)) => {
          sum1 = sum1 + lhs
          sum2 = sum2 + rhs
          let diff = lhs - rhs
          sum_sqr_d = sum_sqr_d + diff * diff
          cnt = cnt + 1.0
        }
        _ => ()
      }
    }
    if cnt < 1.0 {
      return FormulaValue::Error(formula_error_num)
    }
    let sum_d = sum1 - sum2
    let divider = cnt * sum_sqr_d - sum_d * sum_d
    if divider == 0.0 {
      return FormulaValue::Error(formula_error_div)
    }
    let t_val = Double::abs(sum_d) * Double::sqrt((cnt - 1.0) / divider)
    (t_val, cnt - 1.0)
  } else {
    let (t_val, df_val, ok) = ttest_unpaired(array1, array2, test_type == 3.0)
    if !ok {
      return FormulaValue::Error(formula_error_num)
    }
    (t_val, df_val)
  }
  let result = get_t_dist(t_value, df, tails)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn ztest_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 2 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let avg_input : Array[FormulaValue] = [values[0]]
  let mean = match average_values(avg_input) {
    FormulaValue::Number(num) => num
    FormulaValue::Error(_) => return FormulaValue::Error(formula_error_na)
    _ => return FormulaValue::Error(formula_error_na)
  }
  let x = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let sigma = if values.length() == 3 {
    match value_as_number(values[2]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    let stdev_input : Array[FormulaValue] = [values[0]]
    match stdev_values(false, stdev_input) {
      FormulaValue::Number(num) => num
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      _ => return FormulaValue::Error(formula_error_div)
    }
  }
  let list = list_from_value(values[0])
  let count = Double::from_int(list.length())
  let denom = sigma / Double::sqrt(count)
  if denom == 0.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let z = (mean - x) / denom
  let result = 1.0 - get_norm_s_dist(z)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn prob_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let (x_range, prob_range) = match (values[0], values[1]) {
    (FormulaValue::List(xs), FormulaValue::List(ps)) => (xs, ps)
    _ => return FormulaValue::Error(formula_error_num)
  }
  if x_range.length() == 0 || prob_range.length() == 0 {
    return FormulaValue::Error(formula_error_num)
  }
  if x_range.length() != prob_range.length() {
    return FormulaValue::Error(formula_error_na)
  }
  let lower = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let upper = if values.length() == 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    lower
  }
  let mut sum = 0.0
  let mut res = 0.0
  for i in 0..<x_range.length() {
    match (normalize_scalar(x_range[i]), normalize_scalar(prob_range[i])) {
      (FormulaValue::Number(x), FormulaValue::Number(p)) => {
        if p < 0.0 || p > 1.0 {
          return FormulaValue::Error(formula_error_num)
        }
        sum = sum + p
        if x >= lower && x <= upper {
          res = res + p
        }
      }
      _ => return FormulaValue::Error(formula_error_num)
    }
  }
  if Double::abs(sum - 1.0) > 1.0e-7 {
    return FormulaValue::Error(formula_error_num)
  }
  number_or_num_error(round_significant_digits(res, 15))
}

///|
fn chidist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = round_chisq_result(get_chidist(x, degrees))
  number_or_num_error(result)
}

///|
fn chiinv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability > 1.0 || degrees < 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  if probability == 1.0 {
    return FormulaValue::Number(0.0)
  }
  let iterator = InverseIterator::{
    fp: 1.0 - probability,
    fdf: degrees,
    nt: 0.0,
    kind: InverseKind::ChiSq,
  }
  let result = calc_iterate_inverse(iterator, degrees / 2.0, degrees)
  number_or_num_error(result)
}

///|
fn chisq_dist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[2]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if x < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if degrees < 1.0 || degrees >= max_deg {
    return FormulaValue::Error(formula_error_num)
  }
  if cumulative {
    number_or_num_error(get_chisq_dist_cdf(x, degrees))
  } else {
    number_or_num_error(get_chisq_dist_pdf(x, degrees))
  }
}

///|
fn chisq_inv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let degrees = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability < 0.0 || probability >= 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if degrees < 1.0 || degrees > max_deg {
    return FormulaValue::Error(formula_error_num)
  }
  if probability == 0.0 {
    return FormulaValue::Number(0.0)
  }
  let iterator = InverseIterator::{
    fp: probability,
    fdf: degrees,
    nt: 0.0,
    kind: InverseKind::ChiSq,
  }
  let result = calc_iterate_inverse(iterator, degrees / 2.0, degrees)
  number_or_num_error(result)
}

///|
fn chitest_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let actual_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let expected_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[1],
    values[1],
    ctx,
  )
  if actual_range.rows == 0 || actual_range.cols == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  if actual_range.rows != expected_range.rows ||
    actual_range.cols != expected_range.cols {
    return FormulaValue::Error(formula_error_na)
  }
  if actual_range.rows * actual_range.cols == 1 {
    return FormulaValue::Error(formula_error_na)
  }
  let mut result = 0.0
  for idx in 0..<actual_range.values.length() {
    let actual = match value_as_number(actual_range.values[idx]) {
      Ok(num) => num
      Err(err) => return err
    }
    let expected = match value_as_number(expected_range.values[idx]) {
      Ok(num) => num
      Err(err) => return err
    }
    if expected == 0.0 {
      return FormulaValue::Error(formula_error_div)
    }
    if expected < 0.0 {
      return FormulaValue::Error(formula_error_num)
    }
    let diff = actual - expected
    result = result + diff * diff / expected
  }
  let degrees = if actual_range.rows == 1 {
    actual_range.cols - 1
  } else if actual_range.cols == 1 {
    actual_range.rows - 1
  } else {
    (actual_range.cols - 1) * (actual_range.rows - 1)
  }
  if degrees <= 0 {
    return FormulaValue::Error(formula_error_na)
  }
  let value = round_chisq_result(get_chidist(result, Double::from_int(degrees)))
  number_or_num_error(value)
}

///|
fn fdist_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let cumulative = match value_as_bool(values[3]) {
    Ok(flag) => flag
    Err(err) => return err
  }
  if x < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if deg1 < 1.0 || deg1 >= max_deg {
    return FormulaValue::Error(formula_error_num)
  }
  if deg2 < 1.0 || deg2 >= max_deg {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = if cumulative {
    get_f_dist_cdf(x, deg1, deg2)
  } else {
    get_f_dist_pdf(x, deg1, deg2)
  }
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn fdist_rt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if x < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if deg1 < 1.0 || deg1 >= max_deg {
    return FormulaValue::Error(formula_error_num)
  }
  if deg2 < 1.0 || deg2 >= max_deg {
    return FormulaValue::Error(formula_error_num)
  }
  let raw = get_f_dist_rt(x, deg1, deg2)
  number_or_num_error(round_significant_digits(raw, 15))
}

///|
fn finv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability > 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if deg1 < 1.0 || deg1 >= max_deg {
    return FormulaValue::Error(formula_error_num)
  }
  if deg2 < 1.0 || deg2 >= max_deg {
    return FormulaValue::Error(formula_error_num)
  }
  let beta_inv = get_beta_inv(1.0 - probability, deg2 / 2.0, deg1 / 2.0)
  let result = (1.0 / beta_inv - 1.0) * (deg2 / deg1)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn finv_rt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let probability = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg1 = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let deg2 = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if probability <= 0.0 || probability > 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let max_deg = @math.pow(10.0, 10.0)
  if deg1 < 1.0 || deg1 >= max_deg {
    return FormulaValue::Error(formula_error_num)
  }
  if deg2 < 1.0 || deg2 >= max_deg {
    return FormulaValue::Error(formula_error_num)
  }
  let beta_inv = get_beta_inv(probability, deg2 / 2.0, deg1 / 2.0)
  let result = (1.0 / beta_inv - 1.0) * (deg2 / deg1)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn ftest_collect(values : Array[FormulaValue]) -> (Double, Double) {
  let mut n = 0.0
  let mut mean = 0.0
  let mut accu = 0.0
  for value in values {
    match value_as_number_opt(value) {
      Some(num) => {
        let x = num - mean
        let y = x / (n + 1.0)
        mean = mean + y
        accu = accu + n * x * y
        n = n + 1.0
      }
      None => ()
    }
  }
  (n, accu)
}

///|
fn ftest_values(
  workbook : Workbook,
  sheet_name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let left_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let right_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[1],
    values[1],
    ctx,
  )
  let (n1, accu1) = ftest_collect(left_range.values)
  if n1 <= 1.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let f1 = accu1 / (n1 - 1.0)
  if f1 == 0.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let (n2, accu2) = ftest_collect(right_range.values)
  if n2 <= 1.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let f2 = accu2 / (n2 - 1.0)
  if f2 == 0.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let fd = get_f_dist_rt(f1 / f2, n1 - 1.0, n2 - 1.0)
  let mut probability = (1.0 - fd) * 2.0
  if probability > 1.0 {
    probability = 2.0 - probability
  }
  number_or_num_error(round_significant_digits(probability, 15))
}

///|
fn value_as_number_opt_financial(value : FormulaValue) -> Double? {
  match normalize_scalar(value) {
    FormulaValue::Number(num) => Some(num)
    FormulaValue::Bool(flag) => Some(if flag { 1.0 } else { 0.0 })
    FormulaValue::Empty => Some(0.0)
    FormulaValue::String(text) => parse_double_opt(text)
    FormulaValue::Error(_) => Some(0.0)
    FormulaValue::List(_) => None
  }
}

///|
fn value_as_number_financial(value : FormulaValue) -> Double {
  match value_as_number_opt_financial(value) {
    Some(num) => num
    None => 0.0
  }
}

///|
fn validate_frequency(freq : Double) -> Bool {
  freq == 1.0 || freq == 2.0 || freq == 4.0
}

///|
fn get_year_days(year : Int, basis : Int) -> Int {
  match basis {
    1 => if is_leap_year(year) { 366 } else { 365 }
    3 => 365
    _ => 360
  }
}

///|
fn is_30_basis_method(basis : Int) -> Bool {
  basis == 0 || basis == 4
}

///|
fn get_days_in_month_range(from_month : Int, to_month : Int) -> Int {
  if from_month > to_month {
    return 0
  }
  (to_month - from_month + 1) * 30
}

///|
fn get_day_on_basis(year : Int, month : Int, day : Int, basis : Int) -> Int {
  if !is_30_basis_method(basis) {
    return day
  }
  let dim = days_in_month(year, month)
  if day > 30 || day >= dim {
    30
  } else {
    day
  }
}

///|
fn coupdays_between(
  from_serial : Double,
  to_serial : Double,
  basis : Int,
) -> Double {
  let (from_year, from_month, from_day_raw) = match
    date_parts_from_serial(from_serial) {
    Some(parts) => parts
    None => return 0.0
  }
  let (to_year, to_month, to_day_raw) = match
    date_parts_from_serial(to_serial) {
    Some(parts) => parts
    None => return 0.0
  }
  let mut from_day = get_day_on_basis(
    from_year, from_month, from_day_raw, basis,
  )
  let mut to_day = get_day_on_basis(to_year, to_month, to_day_raw, basis)
  if !is_30_basis_method(basis) {
    let from_adj = match
      excel_serial_from_date(from_year, from_month, from_day) {
      Some(serial) => serial
      None => return 0.0
    }
    let to_adj = match excel_serial_from_date(to_year, to_month, to_day) {
      Some(serial) => serial
      None => return 0.0
    }
    return to_adj - from_adj
  }
  if basis == 0 {
    if (from_month == 2 || from_day < 30) && to_day_raw == 31 {
      to_day = 31
    }
  } else {
    if from_month == 2 && from_day == 30 {
      from_day = days_in_month(from_year, 2)
    }
    if to_month == 2 && to_day == 30 {
      to_day = days_in_month(to_year, 2)
    }
  }
  let mut days = 0
  if from_year < to_year || (from_year == to_year && from_month < to_month) {
    days = 30 - from_day + 1
    from_day = 1
    let mut year = from_year
    let mut month = from_month + 1
    if month > 12 {
      month = 1
      year = year + 1
    }
    if year < to_year {
      days = days + get_days_in_month_range(month, 12)
      year = year + 1
      month = 1
    }
    days = days + get_days_in_month_range(month, to_month - 1)
  }
  days = days + to_day - from_day
  if days > 0 {
    Double::from_int(days)
  } else {
    0.0
  }
}

///|
fn coupon_date_serial(
  name : String,
  settlement_serial : Double,
  maturity_serial : Double,
  frequency : Double,
) -> Result[Double, FormulaValue] {
  let (settle_year, settle_month, settle_day) = match
    date_parts_from_serial(settlement_serial) {
    Some(parts) => parts
    None => return Err(FormulaValue::Error(formula_error_value))
  }
  let (mat_year, mat_month, mat_day) = match
    date_parts_from_serial(maturity_serial) {
    Some(parts) => parts
    None => return Err(FormulaValue::Error(formula_error_value))
  }
  let maturity_months = (mat_year - settle_year) * 12 +
    (mat_month - settle_month)
  let coupon = 12 / Double::to_int(trunc_double(frequency))
  let mod_months = maturity_months % coupon
  let mut year = settle_year
  let mut month = settle_month
  if mod_months == 0 && settle_day >= mat_day {
    month = month + coupon
  } else {
    month = month + mod_months
  }
  if name != "COUPNCD" {
    month = month - coupon
  }
  let (year_norm, month_norm) = normalize_year_month(year, month)
  year = year_norm
  month = month_norm
  let mut day = mat_day
  let days = days_in_month(year, month)
  if days_in_month(mat_year, mat_month) == mat_day {
    day = days
  } else if day > 27 && day > days {
    day = days
  }
  match excel_serial_from_date(year, month, day) {
    Some(serial) => Ok(serial)
    None => Err(FormulaValue::Error(formula_error_num))
  }
}

///|
fn prepare_coupon_args(
  values : ArrayView[FormulaValue],
) -> Result[(Double, Double, Double, Int), FormulaValue] {
  if values.length() != 3 && values.length() != 4 {
    return Err(FormulaValue::Error(formula_error_value))
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if settlement >= maturity {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let frequency = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if !validate_frequency(frequency) {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let basis = if values.length() == 4 {
    match value_as_number(values[3]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return Err(err)
    }
  } else {
    0
  }
  Ok((settlement, maturity, frequency, basis))
}

///|
fn coupdaybs_value(
  settlement : Double,
  maturity : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  let pcd = match
    coupon_date_serial("COUPPCD", settlement, maturity, frequency) {
    Ok(serial) => serial
    Err(err) => return Err(err)
  }
  Ok(coupdays_between(pcd, settlement, basis))
}

///|
fn coupdays_value(
  settlement : Double,
  maturity : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  if basis == 1 {
    let pcd = match
      coupon_date_serial("COUPPCD", settlement, maturity, frequency) {
      Ok(serial) => serial
      Err(err) => return Err(err)
    }
    let months = 12 / Double::to_int(trunc_double(frequency))
    let next = match date_parts_from_serial(pcd) {
      Some((year, month, day)) => {
        let (new_year, new_month, new_day) = normalize_date_parts(
          year,
          month + months,
          day,
        )
        match excel_serial_from_date(new_year, new_month, new_day) {
          Some(serial) => serial
          None => return Err(FormulaValue::Error(formula_error_num))
        }
      }
      None => return Err(FormulaValue::Error(formula_error_value))
    }
    return Ok(coupdays_between(pcd, next, basis))
  }
  let year_days = get_year_days(0, basis)
  Ok(Double::from_int(year_days) / frequency)
}

///|
fn coupdaysnc_value(
  settlement : Double,
  maturity : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  let ncd = match
    coupon_date_serial("COUPNCD", settlement, maturity, frequency) {
    Ok(serial) => serial
    Err(err) => return Err(err)
  }
  Ok(coupdays_between(settlement, ncd, basis))
}

///|
fn coupnum_value(
  settlement : Double,
  maturity : Double,
  frequency : Double,
) -> Result[Double, FormulaValue] {
  match yearfrac_value(settlement, maturity, 0) {
    FormulaValue::Number(num) => Ok(Double::ceil(num * frequency))
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    _ => Err(FormulaValue::Error(formula_error_value))
  }
}

///|
fn yearfrac_number(
  start_serial : Double,
  end_serial : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  match yearfrac_value(start_serial, end_serial, basis) {
    FormulaValue::Number(num) => Ok(num)
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    _ => Err(FormulaValue::Error(formula_error_value))
  }
}

///|
fn round_half_up(value : Double) -> Double {
  if value < 0.0 {
    -Double::from_int(Double::to_int(trunc_double(-value + 0.5)))
  } else {
    Double::from_int(Double::to_int(trunc_double(value + 0.5)))
  }
}

///|
fn amor_date_serial(value : FormulaValue) -> Result[Double, FormulaValue] {
  let normalized = normalize_scalar(value)
  match normalized {
    FormulaValue::String(text) => {
      let trimmed = text.trim().to_string()
      if trimmed == "" {
        Err(FormulaValue::Error(formula_error_value))
      } else {
        value_as_date_serial(FormulaValue::String(trimmed))
      }
    }
    _ => value_as_date_serial(normalized)
  }
}

///|
priv struct AmorArgs {
  cost : Double
  date_purchased : Double
  first_period : Double
  salvage : Double
  period : Int
  rate : Double
  basis : Int
}

///|
fn prepare_amor_args(
  values : ArrayView[FormulaValue],
) -> Result[AmorArgs, FormulaValue] {
  if values.length() != 6 && values.length() != 7 {
    return Err(FormulaValue::Error(formula_error_value))
  }
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(_) => return Err(FormulaValue::Error(formula_error_value))
  }
  if cost < 0.0 {
    return Err(FormulaValue::Error(formula_error_value))
  }
  let date_purchased = match amor_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let first_period = match amor_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if first_period < date_purchased {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let salvage = match value_as_number(values[3]) {
    Ok(num) => num
    Err(_) => return Err(FormulaValue::Error(formula_error_num))
  }
  if salvage < 0.0 || salvage > cost {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let period_value = match value_as_number(values[4]) {
    Ok(num) => num
    Err(_) => return Err(FormulaValue::Error(formula_error_num))
  }
  if period_value < 0.0 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let rate = match value_as_number(values[5]) {
    Ok(num) => num
    Err(_) => return Err(FormulaValue::Error(formula_error_num))
  }
  if rate < 0.0 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let basis_value = if values.length() == 7 {
    match value_as_number(values[6]) {
      Ok(num) => num
      Err(_) => return Err(FormulaValue::Error(formula_error_num))
    }
  } else {
    0.0
  }
  Ok(AmorArgs::{
    cost,
    date_purchased,
    first_period,
    salvage,
    period: Double::to_int(trunc_double(period_value)),
    rate,
    basis: Double::to_int(trunc_double(basis_value)),
  })
}

///|
fn amordegrc_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let args = match prepare_amor_args(values) {
    Ok(value) => value
    Err(err) => return err
  }
  if args.rate >= 0.5 {
    return FormulaValue::Error(formula_error_num)
  }
  let assets_life = 1.0 / args.rate
  let mut amor_coeff = 2.5
  if assets_life < 3.0 {
    amor_coeff = 1.0
  } else if assets_life < 5.0 {
    amor_coeff = 1.5
  } else if assets_life <= 6.0 {
    amor_coeff = 2.0
  }
  let rate = args.rate * amor_coeff
  let frac = match
    yearfrac_number(args.date_purchased, args.first_period, args.basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut cost = args.cost
  let mut n_rate = round_half_up(frac * cost * rate)
  cost = cost - n_rate
  if args.period == 0 {
    return number_or_num_error(round_significant_digits(n_rate, 15))
  }
  let mut rest = cost - args.salvage
  for idx in 0..<args.period {
    n_rate = round_half_up(cost * rate)
    rest = rest - n_rate
    if rest < 0.0 {
      let remaining = args.period - idx
      if remaining == 1 {
        return number_or_num_error(
          round_significant_digits(round_half_up(cost * 0.5), 15),
        )
      }
      return FormulaValue::Number(0.0)
    }
    cost = cost - n_rate
  }
  number_or_num_error(round_significant_digits(n_rate, 15))
}

///|
fn amorlinc_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let args = match prepare_amor_args(values) {
    Ok(value) => value
    Err(err) => return err
  }
  let frac = match
    yearfrac_number(args.date_purchased, args.first_period, args.basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let rate1 = frac * args.cost * args.rate
  if args.period == 0 {
    return number_or_num_error(round_significant_digits(rate1, 15))
  }
  let rate2 = args.cost * args.rate
  if rate2 == 0.0 {
    return FormulaValue::Number(0.0)
  }
  let delta = args.cost - args.salvage
  let periods = Double::to_int(trunc_double((delta - rate1) / rate2))
  if args.period <= periods {
    return number_or_num_error(round_significant_digits(rate2, 15))
  }
  if args.period - 1 == periods {
    let result = delta - rate2 * Double::from_int(periods) - rate1
    return number_or_num_error(round_significant_digits(result, 15))
  }
  FormulaValue::Number(0.0)
}

///|
priv struct ConversionUnit {
  group : Int
  allow_prefix : Bool
}

///|
let conversion_units : Map[String, ConversionUnit] = {
  "g": ConversionUnit::{ group: category_weight_and_mass, allow_prefix: true },
  "sg": ConversionUnit::{ group: category_weight_and_mass, allow_prefix: false },
  "lbm": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "u": ConversionUnit::{ group: category_weight_and_mass, allow_prefix: true },
  "ozm": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "grain": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "cwt": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "shweight": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "uk_cwt": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "lcwt": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "hweight": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "stone": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "ton": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "uk_ton": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "LTON": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "brton": ConversionUnit::{
    group: category_weight_and_mass,
    allow_prefix: false,
  },
  "m": ConversionUnit::{ group: category_distance, allow_prefix: true },
  "mi": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "Nmi": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "in": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "ft": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "yd": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "ang": ConversionUnit::{ group: category_distance, allow_prefix: true },
  "ell": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "ly": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "parsec": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "pc": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "Pica": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "Picapt": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "pica": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "survey_mi": ConversionUnit::{ group: category_distance, allow_prefix: false },
  "yr": ConversionUnit::{ group: category_time, allow_prefix: false },
  "day": ConversionUnit::{ group: category_time, allow_prefix: false },
  "d": ConversionUnit::{ group: category_time, allow_prefix: false },
  "hr": ConversionUnit::{ group: category_time, allow_prefix: false },
  "mn": ConversionUnit::{ group: category_time, allow_prefix: false },
  "min": ConversionUnit::{ group: category_time, allow_prefix: false },
  "sec": ConversionUnit::{ group: category_time, allow_prefix: true },
  "s": ConversionUnit::{ group: category_time, allow_prefix: true },
  "Pa": ConversionUnit::{ group: category_pressure, allow_prefix: true },
  "p": ConversionUnit::{ group: category_pressure, allow_prefix: true },
  "atm": ConversionUnit::{ group: category_pressure, allow_prefix: true },
  "at": ConversionUnit::{ group: category_pressure, allow_prefix: true },
  "mmHg": ConversionUnit::{ group: category_pressure, allow_prefix: true },
  "psi": ConversionUnit::{ group: category_pressure, allow_prefix: true },
  "Torr": ConversionUnit::{ group: category_pressure, allow_prefix: true },
  "N": ConversionUnit::{ group: category_force, allow_prefix: true },
  "dyn": ConversionUnit::{ group: category_force, allow_prefix: true },
  "dy": ConversionUnit::{ group: category_force, allow_prefix: true },
  "lbf": ConversionUnit::{ group: category_force, allow_prefix: false },
  "pond": ConversionUnit::{ group: category_force, allow_prefix: true },
  "J": ConversionUnit::{ group: category_energy, allow_prefix: true },
  "e": ConversionUnit::{ group: category_energy, allow_prefix: true },
  "c": ConversionUnit::{ group: category_energy, allow_prefix: true },
  "cal": ConversionUnit::{ group: category_energy, allow_prefix: true },
  "eV": ConversionUnit::{ group: category_energy, allow_prefix: true },
  "ev": ConversionUnit::{ group: category_energy, allow_prefix: true },
  "HPh": ConversionUnit::{ group: category_energy, allow_prefix: false },
  "hh": ConversionUnit::{ group: category_energy, allow_prefix: false },
  "Wh": ConversionUnit::{ group: category_energy, allow_prefix: true },
  "wh": ConversionUnit::{ group: category_energy, allow_prefix: true },
  "flb": ConversionUnit::{ group: category_energy, allow_prefix: false },
  "BTU": ConversionUnit::{ group: category_energy, allow_prefix: false },
  "btu": ConversionUnit::{ group: category_energy, allow_prefix: false },
  "HP": ConversionUnit::{ group: category_power, allow_prefix: false },
  "h": ConversionUnit::{ group: category_power, allow_prefix: false },
  "W": ConversionUnit::{ group: category_power, allow_prefix: true },
  "w": ConversionUnit::{ group: category_power, allow_prefix: true },
  "PS": ConversionUnit::{ group: category_power, allow_prefix: false },
  "T": ConversionUnit::{ group: category_magnetism, allow_prefix: true },
  "ga": ConversionUnit::{ group: category_magnetism, allow_prefix: true },
  "C": ConversionUnit::{ group: category_temperature, allow_prefix: false },
  "cel": ConversionUnit::{ group: category_temperature, allow_prefix: false },
  "F": ConversionUnit::{ group: category_temperature, allow_prefix: false },
  "fah": ConversionUnit::{ group: category_temperature, allow_prefix: false },
  "K": ConversionUnit::{ group: category_temperature, allow_prefix: false },
  "kel": ConversionUnit::{ group: category_temperature, allow_prefix: false },
  "Rank": ConversionUnit::{ group: category_temperature, allow_prefix: false },
  "Reau": ConversionUnit::{ group: category_temperature, allow_prefix: false },
  "l": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: true,
  },
  "L": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: true,
  },
  "lt": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: true,
  },
  "tsp": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "tspm": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "tbs": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "oz": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "cup": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "pt": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "us_pt": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "uk_pt": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "qt": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "uk_qt": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "gal": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "uk_gal": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "ang3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: true,
  },
  "ang^3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: true,
  },
  "barrel": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "bushel": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "in3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "in^3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "ft3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "ft^3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "ly3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "ly^3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "m3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: true,
  },
  "m^3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: true,
  },
  "mi3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "mi^3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "yd3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "yd^3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "Nmi3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "Nmi^3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "Pica3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "Pica^3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "Picapt3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "Picapt^3": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "GRT": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "regton": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "MTON": ConversionUnit::{
    group: category_volume_and_liquid_measure,
    allow_prefix: false,
  },
  "ha": ConversionUnit::{ group: category_area, allow_prefix: true },
  "uk_acre": ConversionUnit::{ group: category_area, allow_prefix: false },
  "us_acre": ConversionUnit::{ group: category_area, allow_prefix: false },
  "ang2": ConversionUnit::{ group: category_area, allow_prefix: true },
  "ang^2": ConversionUnit::{ group: category_area, allow_prefix: true },
  "ar": ConversionUnit::{ group: category_area, allow_prefix: true },
  "ft2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "ft^2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "in2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "in^2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "ly2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "ly^2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "m2": ConversionUnit::{ group: category_area, allow_prefix: true },
  "m^2": ConversionUnit::{ group: category_area, allow_prefix: true },
  "Morgen": ConversionUnit::{ group: category_area, allow_prefix: false },
  "mi2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "mi^2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "Nmi2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "Nmi^2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "Pica2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "Pica^2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "Picapt2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "Picapt^2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "yd2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "yd^2": ConversionUnit::{ group: category_area, allow_prefix: false },
  "byte": ConversionUnit::{ group: category_information, allow_prefix: true },
  "bit": ConversionUnit::{ group: category_information, allow_prefix: true },
  "m/s": ConversionUnit::{ group: category_speed, allow_prefix: true },
  "m/sec": ConversionUnit::{ group: category_speed, allow_prefix: true },
  "m/h": ConversionUnit::{ group: category_speed, allow_prefix: true },
  "m/hr": ConversionUnit::{ group: category_speed, allow_prefix: true },
  "mph": ConversionUnit::{ group: category_speed, allow_prefix: false },
  "admkn": ConversionUnit::{ group: category_speed, allow_prefix: false },
  "kn": ConversionUnit::{ group: category_speed, allow_prefix: false },
}

///|
let conversion_multipliers : Map[String, Double] = {
  "Y": 1.0e24,
  "Z": 1.0e21,
  "E": 1.0e18,
  "P": 1.0e15,
  "T": 1.0e12,
  "G": 1.0e9,
  "M": 1.0e6,
  "k": 1.0e3,
  "h": 1.0e2,
  "e": 1.0e1,
  "da": 1.0e1,
  "d": 1.0e-1,
  "c": 1.0e-2,
  "m": 1.0e-3,
  "u": 1.0e-6,
  "n": 1.0e-9,
  "p": 1.0e-12,
  "f": 1.0e-15,
  "a": 1.0e-18,
  "z": 1.0e-21,
  "y": 1.0e-24,
  "Yi": @math.pow(2.0, 80.0),
  "Zi": @math.pow(2.0, 70.0),
  "Ei": @math.pow(2.0, 60.0),
  "Pi": @math.pow(2.0, 50.0),
  "Ti": @math.pow(2.0, 40.0),
  "Gi": @math.pow(2.0, 30.0),
  "Mi": @math.pow(2.0, 20.0),
  "ki": @math.pow(2.0, 10.0),
}

///|
fn build_unit_conversions() -> Map[Int, Map[String, Double]] {
  let conversions : Map[Int, Map[String, Double]] = {}
  conversions[category_weight_and_mass] = {
    "g": 1.0,
    "sg": 6.85217658567918e-05,
    "lbm": 2.20462262184878e-03,
    "u": 6.02214179421676e+23,
    "ozm": 3.52739619495804e-02,
    "grain": 1.54323583529414e+01,
    "cwt": 2.20462262184878e-05,
    "shweight": 2.20462262184878e-05,
    "uk_cwt": 1.96841305522212e-05,
    "lcwt": 1.96841305522212e-05,
    "hweight": 1.96841305522212e-05,
    "stone": 1.57473044417770e-04,
    "ton": 1.10231131092439e-06,
    "uk_ton": 9.84206527611061e-07,
    "LTON": 9.84206527611061e-07,
    "brton": 9.84206527611061e-07,
  }
  conversions[category_distance] = {
    "m": 1.0,
    "mi": 6.21371192237334e-04,
    "Nmi": 5.39956803455724e-04,
    "in": 3.93700787401575e+01,
    "ft": 3.28083989501312e+00,
    "yd": 1.09361329833771e+00,
    "ang": 1.0e+10,
    "ell": 8.74890638670166e-01,
    "ly": 1.05700083402462e-16,
    "parsec": 3.24077928966473e-17,
    "pc": 3.24077928966473e-17,
    "Pica": 2.83464566929134e+03,
    "Picapt": 2.83464566929134e+03,
    "pica": 2.36220472440945e+02,
    "survey_mi": 6.21369949494950e-04,
  }
  conversions[category_time] = {
    "yr": 3.16880878140289e-08,
    "day": 1.15740740740741e-05,
    "d": 1.15740740740741e-05,
    "hr": 2.77777777777778e-04,
    "mn": 1.66666666666667e-02,
    "min": 1.66666666666667e-02,
    "sec": 1.0,
    "s": 1.0,
  }
  conversions[category_pressure] = {
    "Pa": 1.0,
    "p": 1.0,
    "atm": 9.86923266716013e-06,
    "at": 9.86923266716013e-06,
    "mmHg": 7.50063755419211e-03,
    "psi": 1.45037737730209e-04,
    "Torr": 7.50061682704170e-03,
  }
  conversions[category_force] = {
    "N": 1.0,
    "dyn": 1.0e+5,
    "dy": 1.0e+5,
    "lbf": 2.24808923655339e-01,
    "pond": 1.01971621297793e+02,
  }
  conversions[category_energy] = {
    "J": 1.0,
    "e": 9.99999519343231e+06,
    "c": 2.39006249473467e-01,
    "cal": 2.38846190642017e-01,
    "eV": 6.24145700000000e+18,
    "ev": 6.24145700000000e+18,
    "HPh": 3.72506430801000e-07,
    "hh": 3.72506430801000e-07,
    "Wh": 2.77777916238711e-04,
    "wh": 2.77777916238711e-04,
    "flb": 2.37304222192651e+01,
    "BTU": 9.47815067349015e-04,
    "btu": 9.47815067349015e-04,
  }
  conversions[category_power] = {
    "HP": 1.0,
    "h": 1.0,
    "W": 7.45699871582270e+02,
    "w": 7.45699871582270e+02,
    "PS": 1.01386966542400e+00,
  }
  conversions[category_magnetism] = { "T": 1.0, "ga": 10000.0 }
  conversions[category_volume_and_liquid_measure] = {
    "l": 1.0,
    "L": 1.0,
    "lt": 1.0,
    "tsp": 2.02884136211058e+02,
    "tspm": 2.0e+02,
    "tbs": 6.76280454036860e+01,
    "oz": 3.38140227018430e+01,
    "cup": 4.22675283773038e+00,
    "pt": 2.11337641886519e+00,
    "us_pt": 2.11337641886519e+00,
    "uk_pt": 1.75975398639270e+00,
    "qt": 1.05668820943259e+00,
    "uk_qt": 8.79876993196351e-01,
    "gal": 2.64172052358148e-01,
    "uk_gal": 2.19969248299088e-01,
    "ang3": 1.0e+27,
    "ang^3": 1.0e+27,
    "barrel": 6.28981077043211e-03,
    "bushel": 2.83775932584017e-02,
    "in3": 6.10237440947323e+01,
    "in^3": 6.10237440947323e+01,
    "ft3": 3.53146667214886e-02,
    "ft^3": 3.53146667214886e-02,
    "ly3": 1.18093498844171e-51,
    "ly^3": 1.18093498844171e-51,
    "m3": 1.0e-03,
    "m^3": 1.0e-03,
    "mi3": 2.39912758578928e-13,
    "mi^3": 2.39912758578928e-13,
    "yd3": 1.30795061931439e-03,
    "yd^3": 1.30795061931439e-03,
    "Nmi3": 1.57426214685811e-13,
    "Nmi^3": 1.57426214685811e-13,
    "Pica3": 2.27769904358706e+07,
    "Pica^3": 2.27769904358706e+07,
    "Picapt3": 2.27769904358706e+07,
    "Picapt^3": 2.27769904358706e+07,
    "GRT": 3.53146667214886e-04,
    "regton": 3.53146667214886e-04,
    "MTON": 8.82866668037215e-04,
  }
  conversions[category_area] = {
    "ha": 1.0,
    "uk_acre": 2.47105381467165e+00,
    "us_acre": 2.47104393046628e+00,
    "ang2": 1.0e+24,
    "ang^2": 1.0e+24,
    "ar": 1.0e+02,
    "ft2": 1.07639104167097e+05,
    "ft^2": 1.07639104167097e+05,
    "in2": 1.55000310000620e+07,
    "in^2": 1.55000310000620e+07,
    "ly2": 1.11725076312873e-28,
    "ly^2": 1.11725076312873e-28,
    "m2": 1.0e+04,
    "m^2": 1.0e+04,
    "Morgen": 4.0e+00,
    "mi2": 3.86102158542446e-03,
    "mi^2": 3.86102158542446e-03,
    "Nmi2": 2.91553349598123e-03,
    "Nmi^2": 2.91553349598123e-03,
    "Pica2": 8.03521607043214e+10,
    "Pica^2": 8.03521607043214e+10,
    "Picapt2": 8.03521607043214e+10,
    "Picapt^2": 8.03521607043214e+10,
    "yd2": 1.19599004630108e+04,
    "yd^2": 1.19599004630108e+04,
  }
  conversions[category_information] = { "bit": 1.0, "byte": 0.125 }
  conversions[category_speed] = {
    "m/s": 1.0,
    "m/sec": 1.0,
    "m/h": 3.60e+03,
    "m/hr": 3.60e+03,
    "mph": 2.23693629205440e+00,
    "admkn": 1.94260256941567e+00,
    "kn": 1.94384449244060e+00,
  }
  conversions
}

///|
let unit_conversions : Map[Int, Map[String, Double]] = build_unit_conversions()

///|
fn get_unit_details(uom_text : String) -> (String, Int, Double, Bool) {
  if uom_text.length() == 0 {
    return ("", 0, 0.0, false)
  }
  match conversion_units.get(uom_text) {
    Some(unit) => return (uom_text, unit.group, 1.0, true)
    None => ()
  }
  let mut uom = uom_text
  let mut multiplier_type = uom.unsafe_substring(start=0, end=1)
  uom = uom.unsafe_substring(start=1, end=uom.length())
  match
    (conversion_units.get(uom), conversion_multipliers.get(multiplier_type)) {
    (Some(unit), Some(multiplier)) =>
      if !unit.allow_prefix {
        return ("", 0, 0.0, false)
      } else {
        return (uom, unit.group, multiplier, true)
      }
    _ => ()
  }
  if uom.length() > 0 {
    multiplier_type = multiplier_type + uom.unsafe_substring(start=0, end=1)
    uom = uom.unsafe_substring(start=1, end=uom.length())
  }
  match
    (conversion_units.get(uom), conversion_multipliers.get(multiplier_type)) {
    (Some(unit), Some(multiplier)) =>
      if !unit.allow_prefix {
        ("", 0, 0.0, false)
      } else {
        (uom, unit.group, multiplier, true)
      }
    _ => ("", 0, 0.0, false)
  }
}

///|
fn resolve_temperature_synonyms(uom : String) -> String {
  match uom {
    "fah" => "F"
    "cel" => "C"
    "kel" => "K"
    _ => uom
  }
}

///|
fn convert_temperature(
  from_uom : String,
  to_uom : String,
  value : Double,
) -> Double {
  let from_unit = resolve_temperature_synonyms(from_uom)
  let to_unit = resolve_temperature_synonyms(to_uom)
  if from_unit == to_unit {
    return value
  }
  let mut result = value
  match from_unit {
    "F" => result = (result - 32.0) / 1.8 + 273.15
    "C" => result = result + 273.15
    "Rank" => result = result / 1.8
    "Reau" => result = result * 1.25 + 273.15
    _ => ()
  }
  match to_unit {
    "F" => result = (result - 273.15) * 1.8 + 32.0
    "C" => result = result - 273.15
    "Rank" => result = result * 1.8
    "Reau" => result = (result - 273.15) * 0.8
    _ => ()
  }
  result
}

///|
fn convert_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let from_unit = match value_as_string(values[1]) {
    Ok(value) => value
    Err(err) => return err
  }
  let to_unit = match value_as_string(values[2]) {
    Ok(value) => value
    Err(err) => return err
  }
  let (from_uom, from_category, from_multiplier, ok1) = get_unit_details(
    from_unit,
  )
  let (to_uom, to_category, to_multiplier, ok2) = get_unit_details(to_unit)
  if !ok1 || !ok2 || from_category != to_category {
    return FormulaValue::Error(formula_error_na)
  }
  let value = number * from_multiplier
  let result = if from_uom == to_uom && from_multiplier == to_multiplier {
    value / from_multiplier
  } else if from_uom == to_uom {
    value / to_multiplier
  } else if from_category == category_temperature {
    convert_temperature(from_uom, to_uom, value)
  } else {
    let conversions = match unit_conversions.get(from_category) {
      Some(map) => map
      None => return FormulaValue::Error(formula_error_na)
    }
    let from_conversion = match conversions.get(from_uom) {
      Some(num) => num
      None => return FormulaValue::Error(formula_error_na)
    }
    let to_conversion = match conversions.get(to_uom) {
      Some(num) => num
      None => return FormulaValue::Error(formula_error_na)
    }
    let base_value = value * (1.0 / from_conversion)
    base_value * to_conversion / to_multiplier
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn euroconvert_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let source_currency = match value_as_string(values[1]) {
    Ok(text) => text.to_upper()
    Err(err) => return err
  }
  let target_currency = match value_as_string(values[2]) {
    Ok(text) => text.to_upper()
    Err(err) => return err
  }
  let mut full_precision = false
  if values.length() >= 4 {
    full_precision = match value_as_bool(values[3]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  }
  let mut triangulation_precision = 0.0
  if values.length() == 5 {
    triangulation_precision = match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  }
  let convert_table : Map[String, (Double, Int)] = {
    "EUR": (1.0, 2),
    "ATS": (13.7603, 2),
    "BEF": (40.3399, 0),
    "DEM": (1.95583, 2),
    "ESP": (166.386, 0),
    "FIM": (5.94573, 2),
    "FRF": (6.55957, 2),
    "IEP": (0.787564, 2),
    "ITL": (1936.27, 0),
    "LUF": (40.3399, 0),
    "NLG": (2.20371, 2),
    "PTE": (200.482, 2),
    "GRD": (340.750, 2),
    "SIT": (239.640, 2),
    "MTL": (0.429300, 2),
    "CYP": (0.585274, 2),
    "SKK": (30.1260, 2),
    "EEK": (15.6466, 2),
    "LVL": (0.702804, 2),
    "LTL": (3.45280, 2),
  }
  let (source_rate, _source_decimals) = match
    convert_table.get(source_currency) {
    Some(value) => value
    None => return FormulaValue::Error(formula_error_value)
  }
  let (target_rate, target_decimals) = match
    convert_table.get(target_currency) {
    Some(value) => value
    None => return FormulaValue::Error(formula_error_value)
  }
  if source_currency == target_currency {
    return FormulaValue::Number(number)
  }
  let mut result = if source_currency == "EUR" {
    number * target_rate
  } else {
    let mut intermediate = number / source_rate
    if triangulation_precision != 0.0 {
      let ratio = @math.pow(10.0, triangulation_precision)
      intermediate = Double::round(intermediate * ratio) / ratio
    }
    intermediate * target_rate
  }
  if !full_precision {
    let ratio = @math.pow(10.0, Double::from_int(target_decimals))
    result = Double::round(result * ratio) / ratio
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn fv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pmt = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let typ = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  if typ != 0.0 && typ != 1.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let result = if rate != 0.0 {
    let factor = @math.pow(1.0 + rate, nper)
    -pv * factor - pmt * (1.0 + rate * typ) * (factor - 1.0) / rate
  } else {
    -pv - pmt * nper
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn fvschedule_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let principal = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let schedule = flatten_values([values[1]])
  let mut result = principal
  for value in schedule {
    match normalize_scalar(value) {
      FormulaValue::Empty => ()
      FormulaValue::Error(_) => ()
      FormulaValue::String(text) =>
        if text == "" {
          ()
        } else {
          match parse_double_opt(text) {
            Some(num) => result = result * (1.0 + num)
            None => return FormulaValue::Error(formula_error_value)
          }
        }
      _ =>
        match value_as_number(value) {
          Ok(num) => result = result * (1.0 + num)
          Err(err) => return err
        }
    }
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn calc_npv(rate : Double, values : ArrayView[FormulaValue]) -> Double {
  let mut result = 0.0
  let mut period = 1
  for value in values {
    match value_as_number_opt_financial(value) {
      Some(num) => {
        result = result + num / @math.pow(1.0 + rate, Double::from_int(period))
        period = period + 1
      }
      None => ()
    }
  }
  result
}

///|
fn npv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut result = 0.0
  let mut period = 1
  for idx in 1..<values.length() {
    match value_as_number_opt_financial(values[idx]) {
      Some(num) => {
        result = result + num / @math.pow(1.0 + rate, Double::from_int(period))
        period = period + 1
      }
      None => ()
    }
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn pv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pmt = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let typ = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let result = if rate == 0.0 {
    -pmt * nper - fv
  } else {
    let factor = @math.pow(1.0 + rate, nper)
    ((1.0 - factor) / rate * pmt * (1.0 + rate * typ) - fv) / factor
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn calc_rate(
  nper : Double,
  pmt : Double,
  pv : Double,
  fv : Double,
  typ : Double,
  guess : Double,
) -> Double {
  let mut rate = guess
  let mut iter = 0
  let mut is_close = false
  while iter < rate_max_iterations && !is_close {
    let t1 = @math.pow(rate + 1.0, nper)
    let t2 = @math.pow(rate + 1.0, nper - 1.0)
    let rt = rate * typ + 1.0
    let p0 = pmt * (t1 - 1.0)
    let f1 = fv + t1 * pv + p0 * rt / rate
    let n1 = nper * t2 * pv
    let n2 = p0 * rt / @math.pow(rate, 2.0)
    let f2 = n1 - n2
    let f3 = (nper * pmt * t2 * rt + p0 * typ) / rate
    let delta = f1 / (f2 + f3)
    if Double::abs(delta) < rate_precision {
      is_close = true
    }
    iter = iter + 1
    rate = rate - delta
  }
  rate
}

///|
fn rate_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 6 {
    return FormulaValue::Error(formula_error_value)
  }
  let nper = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pmt = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let mut typ = 0.0
  if values.length() >= 5 {
    match value_as_number(values[4]) {
      Ok(num) => if num != 0.0 { typ = 1.0 }
      Err(err) => return err
    }
  }
  let guess = if values.length() == 6 {
    match value_as_number(values[5]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.1
  }
  let result = calc_rate(nper, pmt, pv, fv, typ, guess)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn irr_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 1 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let list_values = flatten_values([values[0]])
  let guess = if values.length() == 2 {
    match value_as_number(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.1
  }
  let mut x1 = 0.0
  let mut x2 = guess
  let mut f1 = calc_npv(x1, list_values)
  let mut f2 = calc_npv(x2, list_values)
  for _ in 0..<max_financial_iterations {
    if f1 * f2 < 0.0 {
      break
    }
    if Double::abs(f1) < Double::abs(f2) {
      x1 = x1 + 1.6 * (x1 - x2)
      f1 = calc_npv(x1, list_values)
      continue
    }
    x2 = x2 + 1.6 * (x2 - x1)
    f2 = calc_npv(x2, list_values)
  }
  if f1 * f2 > 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let f = calc_npv(x1, list_values)
  let mut rtb = 0.0
  let mut dx = 0.0
  if f < 0.0 {
    rtb = x1
    dx = x2 - x1
  } else {
    rtb = x2
    dx = x1 - x2
  }
  let mut x_mid = rtb
  for _ in 0..<max_financial_iterations {
    dx = dx * 0.5
    x_mid = rtb + dx
    let f_mid = calc_npv(x_mid, list_values)
    if f_mid <= 0.0 {
      rtb = x_mid
    }
    if Double::abs(f_mid) < financial_precision ||
      Double::abs(dx) < financial_precision {
      break
    }
  }
  number_or_num_error(round_significant_digits(x_mid, 15))
}

///|
fn mirr_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let list_values = flatten_values([values[0]])
  let finance_rate = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let reinvest_rate = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let n = list_values.length()
  let fr = 1.0 + finance_rate
  let rr = 1.0 + reinvest_rate
  let mut npv_pos = 0.0
  let mut npv_neg = 0.0
  for idx in 0..<n {
    let value = value_as_number_financial(list_values[idx])
    if value >= 0.0 {
      npv_pos = npv_pos + value / @math.pow(rr, Double::from_int(idx))
    } else {
      npv_neg = npv_neg + value / @math.pow(fr, Double::from_int(idx))
    }
  }
  if npv_neg == 0.0 || npv_pos == 0.0 || reinvest_rate <= -1.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let result = @math.pow(
      -npv_pos * @math.pow(rr, Double::from_int(n)) / (npv_neg * rr),
      1.0 / (Double::from_int(n) - 1.0),
    ) -
    1.0
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn prepare_x_args(
  values : Array[FormulaValue],
  dates : Array[FormulaValue],
) -> Result[(Array[Double], Array[Double]), FormulaValue] {
  let value_args : Array[Double] = []
  for value in values {
    match value_as_number(value) {
      Ok(num) => value_args.push(num)
      Err(err) => return Err(err)
    }
  }
  if value_args.length() < 2 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let date_args : Array[Double] = []
  let mut last_date = 0.0
  for date in dates {
    match normalize_scalar(date) {
      FormulaValue::Empty =>
        return Err(FormulaValue::Error(formula_error_value))
      _ =>
        match value_as_number(date) {
          Ok(num) => {
            if num < last_date {
              return Err(FormulaValue::Error(formula_error_value))
            }
            date_args.push(num)
            last_date = num
          }
          Err(err) => return Err(err)
        }
    }
  }
  if value_args.length() != date_args.length() {
    return Err(FormulaValue::Error(formula_error_num))
  }
  Ok((value_args, date_args))
}

///|
fn xirr_part1(
  values : Array[Double],
  dates : Array[Double],
  rate : Double,
) -> Double {
  let r = rate + 1.0
  let mut result = values[0]
  let first_date = dates[0]
  for idx in 1..<values.length() {
    result = result +
      values[idx] / @math.pow(r, (dates[idx] - first_date) / 365.0)
  }
  result
}

///|
fn xirr_part2(
  values : Array[Double],
  dates : Array[Double],
  rate : Double,
) -> Double {
  let r = rate + 1.0
  let mut result = 0.0
  let first_date = dates[0]
  for idx in 1..<values.length() {
    let frac = (dates[idx] - first_date) / 365.0
    result = result - frac * values[idx] / @math.pow(r, frac + 1.0)
  }
  result
}

///|
fn xirr_compute(
  values : Array[Double],
  dates : Array[Double],
  guess : Double,
) -> FormulaValue {
  let mut has_positive = false
  let mut has_negative = false
  for value in values {
    if value > 0.0 {
      has_positive = true
    }
    if value < 0.0 {
      has_negative = true
    }
  }
  if !has_positive || !has_negative {
    return FormulaValue::Error(formula_error_num)
  }
  let mut result = guess
  let mut count = 0
  let mut failed = false
  while true {
    let result_value = xirr_part1(values, dates, result)
    let new_rate = result - result_value / xirr_part2(values, dates, result)
    let eps_rate = Double::abs(new_rate - result)
    result = new_rate
    count = count + 1
    if eps_rate <= xirr_precision || Double::abs(result_value) <= xirr_precision {
      break
    }
    if count > xirr_max_iterations {
      failed = true
      break
    }
  }
  if failed || Double::is_nan(result) || Double::is_inf(result) {
    return FormulaValue::Error(formula_error_num)
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn xirr_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 && values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let raw_values = flatten_values([values[0]])
  let raw_dates = flatten_values([values[1]])
  let (value_args, date_args) = match prepare_x_args(raw_values, raw_dates) {
    Ok(result) => result
    Err(err) => return err
  }
  let mut guess = 0.0
  if values.length() == 3 {
    match value_as_number(values[2]) {
      Ok(num) => {
        if num <= -1.0 {
          return FormulaValue::Error(formula_error_value)
        }
        guess = num
      }
      Err(_) => return FormulaValue::Error(formula_error_num)
    }
  }
  xirr_compute(value_args, date_args, guess)
}

///|
fn xnpv_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate <= 0.0 {
    return FormulaValue::Error(formula_error_value)
  }
  let raw_values = flatten_values([values[1]])
  let raw_dates = flatten_values([values[2]])
  let (value_args, date_args) = match prepare_x_args(raw_values, raw_dates) {
    Ok(result) => result
    Err(err) => return err
  }
  let date1 = date_args[0]
  let mut result = 0.0
  for idx in 0..<value_args.length() {
    result = result +
      value_args[idx] / @math.pow(1.0 + rate, (date_args[idx] - date1) / 365.0)
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn dollar_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let number = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut decimals = 2
  let mut rounded = number
  if values.length() == 2 {
    let decimals_value = match value_as_number(values[1]) {
      Ok(num) => num
      Err(err) => return err
    }
    if decimals_value >= 128.0 {
      return FormulaValue::Error(formula_error_value)
    }
    let digits = Double::to_int(decimals_value)
    if digits < 0 {
      rounded = round_down_with_digits(number, digits)
      decimals = 0
    } else {
      decimals = digits
    }
  }
  let symbol = "$"
  let abs_value = abs_double(rounded)
  let formatted = format_fixed_number(abs_value, decimals, true)
  if rounded < 0.0 {
    FormulaValue::String("(\{symbol}\{formatted})")
  } else {
    FormulaValue::String("\{symbol}\{formatted}")
  }
}

///|
fn dollar_fraction_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let dollar = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let frac = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if frac < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  if frac == 0.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let (_whole, cents_raw) = modf_double(dollar)
  let mut cents = cents_raw
  let exponent = Double::ceil(@math.log10(frac))
  if name == "DOLLARDE" {
    cents = cents / frac
    cents = cents * @math.pow(10.0, exponent)
  } else {
    cents = cents * frac
    cents = cents * @math.pow(10.0, -exponent)
  }
  let result = Double::floor(dollar) + cents
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn effect_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let npery = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate <= 0.0 || npery < 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let result = @math.pow(1.0 + rate / npery, npery) - 1.0
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn nominal_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let npery = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate <= 0.0 || npery < 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let result = npery * (@math.pow(rate + 1.0, 1.0 / npery) - 1.0)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn nper_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pmt = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let typ = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  if typ != 0.0 && typ != 1.0 {
    return FormulaValue::Error(formula_error_na)
  }
  if pmt == 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let result = if rate != 0.0 {
    let term = pmt * (1.0 + rate * typ) / rate
    @math.ln((term - fv) / (pv + term)) / @math.ln(1.0 + rate)
  } else {
    (-pv - fv) / pmt
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn calc_pmt(
  rate : Double,
  nper : Double,
  pv : Double,
  fv : Double,
  typ : Double,
) -> Double {
  if rate != 0.0 {
    let factor = @math.pow(1.0 + rate, nper)
    (-fv - pv * factor) / (1.0 + rate * typ) / ((factor - 1.0) / rate)
  } else {
    (-pv - fv) / nper
  }
}

///|
fn pmt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 3 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = if values.length() >= 4 {
    match value_as_number(values[3]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let typ = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  if typ != 0.0 && typ != 1.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let result = calc_pmt(rate, nper, pv, fv, typ)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn calc_ipmt(
  typ : Double,
  per : Double,
  pmt : Double,
  pv : Double,
  rate : Double,
) -> (Double, Double) {
  let mut capital = pv
  let mut interest = 0.0
  let mut principal = 0.0
  let per_int = Double::to_int(per)
  let mut i = 1
  while i <= per_int {
    if typ != 0.0 && i == 1 {
      interest = 0.0
    } else {
      interest = -capital * rate
    }
    principal = pmt - interest
    capital = capital + principal
    i = i + 1
  }
  (interest, principal)
}

///|
fn ipmt_values(name : String, values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 4 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 6 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let per = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = if values.length() >= 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  let typ = if values.length() == 6 {
    match value_as_number(values[5]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    0.0
  }
  if typ != 0.0 && typ != 1.0 {
    return FormulaValue::Error(formula_error_na)
  }
  if per <= 0.0 || per > nper {
    return FormulaValue::Error(formula_error_na)
  }
  let payment = calc_pmt(rate, nper, pv, fv, typ)
  let (interest, principal) = calc_ipmt(typ, per, payment, pv, rate)
  let value = if name == "IPMT" { interest } else { principal }
  number_or_num_error(round_significant_digits(value, 15))
}

///|
fn cumip_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 6 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let start = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let end = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  let typ = match value_as_number(values[5]) {
    Ok(num) => num
    Err(err) => return err
  }
  if typ != 0.0 && typ != 1.0 {
    return FormulaValue::Error(formula_error_na)
  }
  if start < 1.0 || start > end {
    return FormulaValue::Error(formula_error_na)
  }
  let mut total = 0.0
  let mut per = start
  while per <= end {
    let args : Array[FormulaValue] = [
      FormulaValue::Number(rate),
      FormulaValue::Number(per),
      FormulaValue::Number(nper),
      FormulaValue::Number(pv),
      FormulaValue::Number(0.0),
      FormulaValue::Number(typ),
    ]
    let result = ipmt_values(
      if name == "CUMIPMT" {
        "IPMT"
      } else {
        "PPMT"
      },
      args,
    )
    match result {
      FormulaValue::Number(num) => total = total + num
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      _ => return FormulaValue::Error(formula_error_value)
    }
    per = per + 1.0
  }
  number_or_num_error(round_significant_digits(total, 15))
}

///|
fn ispmt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let per = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let nper = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut pr = pv
  let payment = pv / nper
  let mut num = 0.0
  let per_int = Double::to_int(per)
  let nper_int = Double::to_int(nper)
  let mut i = 0
  while i <= per_int {
    num = rate * pr * -1.0
    pr = pr - payment
    if i == nper_int {
      num = 0.0
    }
    i = i + 1
  }
  number_or_num_error(round_significant_digits(num, 15))
}

///|
fn rri_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let nper = match value_as_number(values[0]) {
    Ok(num) => num
    Err(_) => return FormulaValue::Error(formula_error_num)
  }
  let pv = match value_as_number(values[1]) {
    Ok(num) => num
    Err(_) => return FormulaValue::Error(formula_error_num)
  }
  let fv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(_) => return FormulaValue::Error(formula_error_num)
  }
  if nper <= 0.0 || pv <= 0.0 || fv < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let result = @math.pow(fv / pv, 1.0 / nper) - 1.0
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn sln_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(_) => return FormulaValue::Error(formula_error_num)
  }
  let salvage = match value_as_number(values[1]) {
    Ok(num) => num
    Err(_) => return FormulaValue::Error(formula_error_num)
  }
  let life = match value_as_number(values[2]) {
    Ok(num) => num
    Err(_) => return FormulaValue::Error(formula_error_num)
  }
  if life <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let result = (cost - salvage) / life
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn syd_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(_) => return FormulaValue::Error(formula_error_num)
  }
  let salvage = match value_as_number(values[1]) {
    Ok(num) => num
    Err(_) => return FormulaValue::Error(formula_error_num)
  }
  let life = match value_as_number(values[2]) {
    Ok(num) => num
    Err(_) => return FormulaValue::Error(formula_error_num)
  }
  let per = match value_as_number(values[3]) {
    Ok(num) => num
    Err(_) => return FormulaValue::Error(formula_error_num)
  }
  if life <= 0.0 || per <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  if per > life {
    return FormulaValue::Error(formula_error_num)
  }
  let result = (cost - salvage) *
    (life - per + 1.0) *
    2.0 /
    (life * (life + 1.0))
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn db_args_invalid(
  cost : Double,
  salvage : Double,
  life : Double,
  period : Double,
) -> Bool {
  cost <= 0.0 || salvage / cost < 0.0 || life <= 0.0 || period < 1.0
}

///|
fn db_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 4 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let salvage = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let life = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let period = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let month = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    12.0
  }
  if cost == 0.0 {
    return FormulaValue::Number(0.0)
  }
  if db_args_invalid(cost, salvage, life, period) || month < 1.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let dr_raw = 1.0 - @math.pow(salvage / cost, 1.0 / life)
  let dr = Double::round(dr_raw * 1000.0) / 1000.0
  let mut pd = 0.0
  let mut depreciation = 0.0
  let period_int = Double::to_int(trunc_double(period))
  let life_limit = Double::to_int(trunc_double(life + 1.0))
  for per in 1..<=period_int {
    if per == 1 {
      depreciation = cost * dr * month / 12.0
    } else if per == life_limit {
      depreciation = (cost - pd) * dr * (12.0 - month) / 12.0
    } else {
      depreciation = (cost - pd) * dr
    }
    pd = pd + depreciation
  }
  number_or_num_error(round_significant_digits(depreciation, 15))
}

///|
fn ddb_double(
  cost : Double,
  salvage : Double,
  life : Double,
  period : Double,
  factor : Double,
) -> Double {
  let mut pd = 0.0
  let mut depreciation = 0.0
  let period_int = Double::to_int(trunc_double(period))
  for _ in 1..<=period_int {
    let term = (cost - pd) * (factor / life)
    let cap = cost - salvage - pd
    depreciation = if term < cap { term } else { cap }
    pd = pd + depreciation
  }
  depreciation
}

///|
fn ddb_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 4 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let salvage = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let life = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let period = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let factor = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => num
      Err(err) => return err
    }
  } else {
    2.0
  }
  if cost == 0.0 {
    return FormulaValue::Number(0.0)
  }
  if db_args_invalid(cost, salvage, life, period) ||
    factor <= 0.0 ||
    period > life {
    return FormulaValue::Error(formula_error_na)
  }
  let depreciation = ddb_double(cost, salvage, life, period, factor)
  number_or_num_error(round_significant_digits(depreciation, 15))
}

///|
fn prepare_vdb_args(values : ArrayView[FormulaValue]) -> FormulaValue {
  let cost = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  if cost < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let salvage = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if salvage < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let life = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if life <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let start_period = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if start_period < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let end_period = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  if start_period > end_period {
    return FormulaValue::Error(formula_error_num)
  }
  if end_period > life {
    return FormulaValue::Error(formula_error_num)
  }
  let factor = if values.length() > 5 {
    match value_as_number(values[5]) {
      Ok(num) => num
      Err(_) => return FormulaValue::Error(formula_error_num)
    }
  } else {
    2.0
  }
  if factor < 0.0 {
    return FormulaValue::Error(formula_error_value)
  }
  FormulaValue::List([
    FormulaValue::Number(cost),
    FormulaValue::Number(salvage),
    FormulaValue::Number(life),
    FormulaValue::Number(start_period),
    FormulaValue::Number(end_period),
    FormulaValue::Number(factor),
  ])
}

///|
fn vdb_partial(
  cost : Double,
  salvage : Double,
  life : Double,
  life1 : Double,
  period : Double,
  factor : Double,
) -> Double {
  let end_int = Double::ceil(period)
  let mut cs = cost - salvage
  let mut now_sln = false
  let mut vdb_total = 0.0
  let mut ddb = 0.0
  let mut sln = 0.0
  let mut term = 0.0
  let mut i = 1.0
  while i <= end_int {
    if !now_sln {
      ddb = ddb_double(cost, salvage, life, i, factor)
      sln = cs / (life1 - i + 1.0)
      if sln > ddb && i != end_int {
        term = sln
        now_sln = true
      } else {
        term = ddb
        cs = cs - ddb
      }
    } else {
      term = sln
    }
    if i == end_int {
      term = term * (period + 1.0 - end_int)
    }
    vdb_total = vdb_total + term
    i = i + 1.0
  }
  vdb_total
}

///|
fn vdb_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 5 || values.length() > 7 {
    return FormulaValue::Error(formula_error_value)
  }
  let prepared = prepare_vdb_args(values)
  let list = match prepared {
    FormulaValue::List(items) => items
    FormulaValue::Error(err) => return FormulaValue::Error(err)
    _ => return FormulaValue::Error(formula_error_value)
  }
  let cost = match list[0] {
    FormulaValue::Number(num) => num
    _ => return FormulaValue::Error(formula_error_value)
  }
  let salvage = match list[1] {
    FormulaValue::Number(num) => num
    _ => return FormulaValue::Error(formula_error_value)
  }
  let life = match list[2] {
    FormulaValue::Number(num) => num
    _ => return FormulaValue::Error(formula_error_value)
  }
  let start_period = match list[3] {
    FormulaValue::Number(num) => num
    _ => return FormulaValue::Error(formula_error_value)
  }
  let end_period = match list[4] {
    FormulaValue::Number(num) => num
    _ => return FormulaValue::Error(formula_error_value)
  }
  let factor = match list[5] {
    FormulaValue::Number(num) => num
    _ => return FormulaValue::Error(formula_error_value)
  }
  let no_switch = if values.length() > 6 {
    match value_as_bool(values[6]) {
      Ok(flag) => flag
      Err(_) => return FormulaValue::Error(formula_error_num)
    }
  } else {
    false
  }
  let start_int = Double::floor(start_period)
  let end_int = Double::ceil(end_period)
  if no_switch {
    let mut vdb_total = 0.0
    let mut i = start_int + 1.0
    while i <= end_int {
      let mut term = ddb_double(cost, salvage, life, i, factor)
      if i == start_int + 1.0 {
        let upper = if end_period < start_int + 1.0 {
          end_period
        } else {
          start_int + 1.0
        }
        term = term * (upper - start_period)
      } else if i == end_int {
        term = term * (end_period + 1.0 - end_int)
      }
      vdb_total = vdb_total + term
      i = i + 1.0
    }
    return number_or_num_error(round_significant_digits(vdb_total, 15))
  }
  let adjusted_cost = cost -
    vdb_partial(cost, salvage, life, life, start_period, factor)
  let result = vdb_partial(
    adjusted_cost,
    salvage,
    life,
    life - start_period,
    end_period - start_period,
    factor,
  )
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn pduration_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let rate = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pv = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let fv = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate <= 0.0 || pv <= 0.0 || fv <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let result = (@math.ln(fv) - @math.ln(pv)) / @math.ln(1.0 + rate)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn accrint_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 6 || values.length() > 8 {
    return FormulaValue::Error(formula_error_value)
  }
  let issue = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let settlement = match value_as_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let rate = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let par = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  let frequency = match value_as_number(values[5]) {
    Ok(num) => num
    Err(err) => return err
  }
  if !validate_frequency(frequency) {
    return FormulaValue::Error(formula_error_num)
  }
  let basis = if values.length() >= 7 {
    match value_as_number(values[6]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  if values.length() == 8 {
    match value_as_bool(values[7]) {
      Ok(_) => ()
      Err(err) => return err
    }
  }
  let frac = match yearfrac_number(issue, settlement, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = par * rate * frac
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn accrintm_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 && values.length() != 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let issue = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let settlement = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if settlement < issue {
    return FormulaValue::Error(formula_error_num)
  }
  let rate = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let par = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if par <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let basis = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let frac = match yearfrac_number(issue, settlement, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = frac * rate * par
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn coupdaybs_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match coupdaybs_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  FormulaValue::Number(result)
}

///|
fn coupdays_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match coupdays_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  FormulaValue::Number(result)
}

///|
fn coupdaysnc_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match coupdaysnc_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  FormulaValue::Number(result)
}

///|
fn coupncd_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, _basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match
    coupon_date_serial("COUPNCD", settlement, maturity, frequency) {
    Ok(serial) => serial
    Err(err) => return err
  }
  FormulaValue::Number(result)
}

///|
fn coupnum_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, _basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match coupnum_value(settlement, maturity, frequency) {
    Ok(num) => num
    Err(err) => return err
  }
  FormulaValue::Number(result)
}

///|
fn couppcd_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, frequency, _basis) = match
    prepare_coupon_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match
    coupon_date_serial("COUPPCD", settlement, maturity, frequency) {
    Ok(serial) => serial
    Err(err) => return err
  }
  FormulaValue::Number(result)
}

///|
fn disc_intrate_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 4 && values.length() != 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if maturity <= settlement {
    return FormulaValue::Error(formula_error_num)
  }
  let pr_investment = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if pr_investment <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let redemption = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if redemption <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let basis = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let frac = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = if name == "INTRATE" {
    (redemption - pr_investment) / pr_investment / frac
  } else {
    (redemption - pr_investment) / redemption / frac
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn prepare_duration_args(
  values : ArrayView[FormulaValue],
) -> Result[(Double, Double, Double, Double, Double, Int), FormulaValue] {
  if values.length() != 5 && values.length() != 6 {
    return Err(FormulaValue::Error(formula_error_value))
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if settlement >= maturity {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let coupon = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if coupon < 0.0 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let yld = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if yld < 0.0 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let frequency = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if !validate_frequency(frequency) {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let basis = if values.length() == 6 {
    match value_as_number(values[5]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return Err(err)
    }
  } else {
    0
  }
  Ok((settlement, maturity, coupon, yld, frequency, basis))
}

///|
fn duration_calc(
  settlement : Double,
  maturity : Double,
  coupon : Double,
  yld : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  let frac = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let coups = match coupnum_value(settlement, maturity, frequency) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let coupon_cash = coupon * 100.0 / frequency
  let mut yld_factor = yld / frequency
  yld_factor = yld_factor + 1.0
  let diff = frac * frequency - coups
  let mut duration = 0.0
  let mut price = 0.0
  let coups_int = Double::to_int(trunc_double(coups))
  let mut t = 1
  while t < coups_int {
    let t_value = Double::from_int(t)
    let t_diff = t_value + diff
    let add = coupon_cash / @math.pow(yld_factor, t_diff)
    price = price + add
    duration = duration + t_diff * add
    t = t + 1
  }
  let add = (coupon_cash + 100.0) / @math.pow(yld_factor, coups + diff)
  price = price + add
  duration = duration + (coups + diff) * add
  Ok(duration / price / frequency)
}

///|
fn duration_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, coupon, yld, frequency, basis) = match
    prepare_duration_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match
    duration_calc(settlement, maturity, coupon, yld, frequency, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn mduration_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let (settlement, maturity, coupon, yld, frequency, basis) = match
    prepare_duration_args(values) {
    Ok(args) => args
    Err(err) => return err
  }
  let duration = match
    duration_calc(settlement, maturity, coupon, yld, frequency, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = duration / (1.0 + yld / frequency)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn price_value(
  settlement : Double,
  maturity : Double,
  rate : Double,
  yld : Double,
  redemption : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  if settlement >= maturity {
    return Err(FormulaValue::Error(formula_error_num))
  }
  if basis < 0 || basis > 4 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let e = match coupdays_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let dsc = match coupdaysnc_value(settlement, maturity, frequency, basis) {
    Ok(num) => num / e
    Err(err) => return Err(err)
  }
  let n = match coupnum_value(settlement, maturity, frequency) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let a = match coupdaybs_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let rate_per = rate / frequency
  let yld_per = yld / frequency
  let mut result = 0.0
  if n > 1.0 {
    let p1 = 1.0 + yld_per
    result = redemption / @math.pow(p1, n - 1.0 + dsc)
    result = result - 100.0 * rate_per * a / e
    let t1 = 100.0 * rate_per
    let t2 = 1.0 + yld_per
    let n_int = Double::to_int(trunc_double(n))
    for k in 0..<n_int {
      let k_value = Double::from_int(k)
      result = result + t1 / @math.pow(t2, k_value + dsc)
    }
  } else {
    let dsc_value = e - a
    let t1 = 100.0 * rate_per + redemption
    let t2 = yld_per * (dsc_value / e) + 1.0
    let t3 = 100.0 * rate_per * (a / e)
    result = t1 / t2 - t3
  }
  Ok(result)
}

///|
fn yield_value(
  settlement : Double,
  maturity : Double,
  rate : Double,
  pr : Double,
  redemption : Double,
  frequency : Double,
  basis : Int,
) -> FormulaValue {
  if settlement >= maturity {
    return FormulaValue::Error(formula_error_num)
  }
  let mut yield1 = 0.0
  let mut yield2 = 1.0
  let mut price1 = match
    price_value(
      settlement, maturity, rate, yield1, redemption, frequency, basis,
    ) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut price2 = match
    price_value(
      settlement, maturity, rate, yield2, redemption, frequency, basis,
    ) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut yield_n = (yield2 - yield1) * 0.5
  let mut price_n = 0.0
  let mut iter = 0
  while iter < 100 && price_n != pr {
    price_n = match
      price_value(
        settlement, maturity, rate, yield_n, redemption, frequency, basis,
      ) {
      Ok(num) => num
      Err(err) => return err
    }
    if pr == price1 {
      return number_or_num_error(round_significant_digits(yield1, 15))
    } else if pr == price2 {
      return number_or_num_error(round_significant_digits(yield2, 15))
    } else if pr == price_n {
      return number_or_num_error(round_significant_digits(yield_n, 15))
    } else if pr < price2 {
      yield2 = yield2 * 2.0
      price2 = match
        price_value(
          settlement, maturity, rate, yield2, redemption, frequency, basis,
        ) {
        Ok(num) => num
        Err(err) => return err
      }
      yield_n = (yield2 - yield1) * 0.5
    } else {
      if pr < price_n {
        yield1 = yield_n
        price1 = price_n
      } else {
        yield2 = yield_n
        price2 = price_n
      }
      let f1 = (yield2 - yield1) * ((pr - price2) / (price1 - price2))
      yield_n = yield2 - f1
    }
    iter = iter + 1
  }
  number_or_num_error(round_significant_digits(yield_n, 15))
}

///|
fn check_price_yield_args(
  name : String,
  rate : Double,
  pr_yld : Double,
  redemption : Double,
  frequency : Double,
) -> FormulaValue {
  if rate < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  if name == "PRICE" {
    if pr_yld < 0.0 || redemption <= 0.0 {
      return FormulaValue::Error(formula_error_num)
    }
  } else if pr_yld <= 0.0 || redemption < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  if !validate_frequency(frequency) {
    return FormulaValue::Error(formula_error_num)
  }
  FormulaValue::Empty
}

///|
fn price_yield_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 6 && values.length() != 7 {
    return FormulaValue::Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let rate = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pr_yld = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  let redemption = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  let frequency = match value_as_number(values[5]) {
    Ok(num) => num
    Err(err) => return err
  }
  let check = check_price_yield_args(name, rate, pr_yld, redemption, frequency)
  match check {
    FormulaValue::Empty => ()
    _ => return check
  }
  let basis = if values.length() == 7 {
    match value_as_number(values[6]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  if name == "PRICE" {
    let result = match
      price_value(
        settlement, maturity, rate, pr_yld, redemption, frequency, basis,
      ) {
      Ok(num) => num
      Err(err) => return err
    }
    return number_or_num_error(round_significant_digits(result, 15))
  }
  yield_value(settlement, maturity, rate, pr_yld, redemption, frequency, basis)
}

///|
fn pricedisc_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 && values.length() != 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  if maturity <= settlement {
    return FormulaValue::Error(formula_error_num)
  }
  let discount = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if discount <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let redemption = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if redemption <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let basis = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let frac = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = redemption * (1.0 - discount * frac)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn pricemat_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 5 && values.length() != 6 {
    return FormulaValue::Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let issue = match value_as_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if settlement >= maturity {
    return FormulaValue::Error(formula_error_num)
  }
  if issue >= settlement {
    return FormulaValue::Error(formula_error_num)
  }
  let rate = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let yld = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  if yld < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let basis = if values.length() == 6 {
    match value_as_number(values[5]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let dsm = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let dis = match yearfrac_number(issue, settlement, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let dim = match yearfrac_number(issue, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = ((1.0 + dim * rate) / (1.0 + dsm * yld) - dis * rate) * 100.0
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn tbilleq_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let dsm = maturity - settlement
  if dsm > 365.0 || maturity <= settlement {
    return FormulaValue::Error(formula_error_num)
  }
  let discount = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if discount <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let result = 365.0 * discount / (360.0 - discount * dsm)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn tbillprice_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let dsm = maturity - settlement
  if dsm > 365.0 || maturity <= settlement {
    return FormulaValue::Error(formula_error_num)
  }
  let discount = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if discount <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let result = 100.0 * (1.0 - discount * dsm / 360.0)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn tbillyield_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let dsm = maturity - settlement
  if dsm > 365.0 || maturity <= settlement {
    return FormulaValue::Error(formula_error_num)
  }
  let pr = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if pr <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let result = (100.0 - pr) / pr * (360.0 / dsm)
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn yielddisc_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 4 && values.length() != 5 {
    return FormulaValue::Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let pr = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if pr <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let redemption = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if redemption <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let basis = if values.length() == 5 {
    match value_as_number(values[4]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let frac = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let result = (redemption / pr - 1.0) / frac
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn yieldmat_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 5 && values.length() != 6 {
    return FormulaValue::Error(formula_error_value)
  }
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let issue = match value_as_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if issue >= settlement {
    return FormulaValue::Error(formula_error_num)
  }
  let rate = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return err
  }
  if rate < 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let pr = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return err
  }
  if pr <= 0.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let basis = if values.length() == 6 {
    match value_as_number(values[5]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return err
    }
  } else {
    0
  }
  let dim = match yearfrac_number(issue, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let dis = match yearfrac_number(issue, settlement, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let dsm = match yearfrac_number(settlement, maturity, basis) {
    Ok(num) => num
    Err(err) => return err
  }
  let numerator = 1.0 + dim * rate
  let denominator = pr / 100.0 + dis * rate
  let result = (numerator / denominator - 1.0) / dsm
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn aggr_between(
  start_period : Double,
  end_period : Double,
  initial_value : Array[Double],
  f : (Array[Double], Double) -> Array[Double],
) -> Array[Double] {
  let mut value = initial_value
  let start_int = Double::to_int(trunc_double(start_period))
  let end_int = Double::to_int(trunc_double(end_period))
  if start_int <= end_int {
    let mut idx = start_int
    while idx <= end_int {
      value = f(value, Double::from_int(idx))
      idx = idx + 1
    }
  } else {
    let mut idx = start_int
    while idx >= end_int {
      value = f(value, Double::from_int(idx))
      if idx == end_int {
        break
      }
      idx = idx - 1
    }
  }
  value
}

///|
fn change_month_serial(
  serial : Double,
  num_months : Double,
  return_last_month : Bool,
) -> Double {
  let (year, month, day) = match date_parts_from_serial(serial) {
    Some(parts) => parts
    None => return serial
  }
  let mut offset_day = 0
  if return_last_month && day == days_in_month(year, month) {
    offset_day = -1
  }
  let (new_year, new_month, new_day) = normalize_date_parts(
    year,
    month + Double::to_int(trunc_double(num_months)),
    day + offset_day,
  )
  if return_last_month {
    let last_day = days_in_month(new_year, new_month)
    return match excel_serial_from_date(new_year, new_month, last_day) {
      Some(serial_value) => serial_value
      None => serial
    }
  }
  match excel_serial_from_date(new_year, new_month, new_day) {
    Some(serial_value) => serial_value
    None => serial
  }
}

///|
fn dates_aggregate(
  start_date : Double,
  end_date : Double,
  num_months : Double,
  f : (Double, Double) -> Double,
  acc : Double,
  return_last_month : Bool,
) -> (Double, Double, Double) {
  let mut front_date = start_date
  let mut trailing_date = end_date
  let mut stop = if num_months > 0.0 {
    front_date >= end_date
  } else {
    end_date >= front_date
  }
  let mut result = acc
  while !stop {
    trailing_date = front_date
    front_date = change_month_serial(front_date, num_months, return_last_month)
    result = result + f(front_date, trailing_date)
    stop = if num_months > 0.0 {
      front_date >= end_date
    } else {
      end_date >= front_date
    }
  }
  (front_date, trailing_date, result)
}

///|
fn coup_number(
  maturity : Double,
  settlement : Double,
  num_months : Double,
) -> Double {
  let (mat_year, mat_month, mat_day) = match date_parts_from_serial(maturity) {
    Some(parts) => parts
    None => return 0.0
  }
  let (settle_year, settle_month, settle_day) = match
    date_parts_from_serial(settlement) {
    Some(parts) => parts
    None => return 0.0
  }
  let end_of_month_temp = days_in_month(mat_year, mat_month) == mat_day
  let mut end_of_month = end_of_month_temp
  if !end_of_month_temp &&
    mat_month != 2 &&
    mat_day > 28 &&
    mat_day < days_in_month(mat_year, mat_month) {
    end_of_month = days_in_month(settle_year, settle_month) == settle_day
  }
  let start_date = change_month_serial(settlement, 0.0, end_of_month)
  let mut coupons = 0.0
  if start_date > settlement {
    coupons = coupons + 1.0
  }
  let date = change_month_serial(start_date, num_months, end_of_month)
  let f = fn(_pcd : Double, _ncd : Double) -> Double { 1.0 }
  let (_, _, result) = dates_aggregate(
    date, maturity, num_months, f, coupons, end_of_month,
  )
  result
}

///|
fn prepare_odd_yld_or_pr_arg(
  name : String,
  value : FormulaValue,
) -> Result[Double, FormulaValue] {
  let yld_or_pr = match value_as_number(value) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if (name == "ODDFPRICE" || name == "ODDLPRICE") && yld_or_pr < 0.0 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  if (name == "ODDFYIELD" || name == "ODDLYIELD") && yld_or_pr <= 0.0 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  Ok(yld_or_pr)
}

///|
fn prepare_oddf_args(
  name : String,
  values : ArrayView[FormulaValue],
) -> Result[
  (Double, Double, Double, Double, Double, Double, Double, Double, Int),
  FormulaValue,
] {
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let issue = match value_as_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let first_coupon = match value_as_date_serial(values[3]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if issue >= settlement {
    return Err(FormulaValue::Error(formula_error_num))
  }
  if settlement >= first_coupon {
    return Err(FormulaValue::Error(formula_error_num))
  }
  if first_coupon >= maturity {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let rate = match value_as_number(values[4]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if rate < 0.0 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let yld_or_pr = match prepare_odd_yld_or_pr_arg(name, values[5]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let redemption = match value_as_number(values[6]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if redemption <= 0.0 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let frequency = match value_as_number(values[7]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if !validate_frequency(frequency) {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let basis = if values.length() == 9 {
    match value_as_number(values[8]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return Err(err)
    }
  } else {
    0
  }
  Ok(
    (
      settlement, maturity, issue, first_coupon, rate, yld_or_pr, redemption, frequency,
      basis,
    ),
  )
}

///|
fn oddfprice_calc(
  settlement : Double,
  maturity : Double,
  issue : Double,
  first_coupon : Double,
  rate : Double,
  yld : Double,
  redemption : Double,
  frequency : Double,
  basis : Int,
) -> Result[Double, FormulaValue] {
  if basis < 0 || basis > 4 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let (mat_year, mat_month, mat_day) = match date_parts_from_serial(maturity) {
    Some(parts) => parts
    None => return Err(FormulaValue::Error(formula_error_value))
  }
  let return_last_month = days_in_month(mat_year, mat_month) == mat_day
  let num_months = 12.0 / frequency
  let num_months_neg = -num_months
  let mat = change_month_serial(maturity, num_months_neg, return_last_month)
  let f = fn(_d1 : Double, _d2 : Double) -> Double { 0.0 }
  let (pcd, _, _) = dates_aggregate(
    mat, first_coupon, num_months_neg, f, 0.0, return_last_month,
  )
  if pcd != first_coupon {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let e = match coupdays_value(settlement, maturity, frequency, basis) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let n = match coupnum_value(settlement, maturity, frequency) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let dfc = coupdays_between(issue, first_coupon, basis)
  if dfc < e {
    let dsc = coupdays_between(settlement, first_coupon, basis)
    let a = coupdays_between(issue, settlement, basis)
    let x = yld / frequency + 1.0
    let y = dsc / e
    let p3 = @math.pow(x, n - 1.0 + y)
    let term1 = redemption / p3
    let term2 = 100.0 * rate / frequency * dfc / e / @math.pow(x, y)
    let term3 = aggr_between(2.0, Double::floor(n), [0.0], fn(
      acc : Array[Double],
      index : Double,
    ) -> Array[Double] {
      [acc[0] + 100.0 * rate / frequency / @math.pow(x, index - 1.0 + y)]
    })
    let term4 = a / e * (rate / frequency) * 100.0
    return Ok(term1 + term2 + term3[0] - term4)
  }
  let nc = match coupnum_value(issue, first_coupon, frequency) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let mut last_coupon = first_coupon
  let ag = aggr_between(Double::floor(nc), 1.0, [0.0, 0.0], fn(
    acc : Array[Double],
    index : Double,
  ) -> Array[Double] {
    let (last_year, last_month, last_day) = match
      date_parts_from_serial(last_coupon) {
      Some(parts) => parts
      None => return acc
    }
    let (early_year, early_month, early_day) = normalize_date_parts(
      last_year,
      last_month + Double::to_int(trunc_double(num_months_neg)),
      last_day,
    )
    let early_coupon = match
      excel_serial_from_date(early_year, early_month, early_day) {
      Some(serial) => serial
      None => return acc
    }
    let mut nl = e
    if basis == 1 {
      nl = coupdays_between(early_coupon, last_coupon, basis)
    }
    let mut dci = coupdays_between(issue, last_coupon, basis)
    if index > 1.0 {
      dci = nl
    }
    let start_date = if issue > early_coupon { issue } else { early_coupon }
    let end_date = if settlement < last_coupon {
      settlement
    } else {
      last_coupon
    }
    let a = coupdays_between(start_date, end_date, basis)
    last_coupon = early_coupon
    let dcnl = acc[0] + dci / nl
    let anl = acc[1] + a / nl
    [dcnl, anl]
  })
  let dcnl = ag[0]
  let anl = ag[1]
  let dsc = if basis == 2 || basis == 3 {
    let ncd = match
      coupon_date_serial("COUPNCD", settlement, first_coupon, frequency) {
      Ok(serial) => serial
      Err(err) => return Err(err)
    }
    coupdays_between(settlement, ncd, basis)
  } else {
    let pcd = match
      coupon_date_serial("COUPPCD", settlement, first_coupon, frequency) {
      Ok(serial) => serial
      Err(err) => return Err(err)
    }
    let a = coupdays_between(pcd, settlement, basis)
    e - a
  }
  let nq = coup_number(first_coupon, settlement, num_months)
  let n_final = match coupnum_value(first_coupon, maturity, frequency) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let x = yld / frequency + 1.0
  let y = dsc / e
  let p3 = @math.pow(x, y + nq + n_final)
  let term1 = redemption / p3
  let term2 = 100.0 * rate / frequency * dcnl / @math.pow(x, nq + y)
  let term3 = aggr_between(1.0, Double::floor(n_final), [0.0], fn(
    acc : Array[Double],
    index : Double,
  ) -> Array[Double] {
    [acc[0] + 100.0 * rate / frequency / @math.pow(x, index + nq + y)]
  })
  let term4 = 100.0 * rate / frequency * anl
  Ok(term1 + term2 + term3[0] - term4)
}

///|
fn oddfprice_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 8 && values.length() != 9 {
    return FormulaValue::Error(formula_error_value)
  }
  let (
    settlement,
    maturity,
    issue,
    first_coupon,
    rate,
    yld,
    redemption,
    frequency,
    basis,
  ) = match prepare_oddf_args("ODDFPRICE", values) {
    Ok(args) => args
    Err(err) => return err
  }
  let result = match
    oddfprice_calc(
      settlement, maturity, issue, first_coupon, rate, yld, redemption, frequency,
      basis,
    ) {
    Ok(num) => num
    Err(err) => return err
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn get_oddfprice(
  f : (Double) -> Double,
  x : Double,
  cnt : Double,
  prec : Double,
) -> Double {
  let max_cnt = 20.0
  let d = (f(x + prec) - f(x - prec)) / (2.0 * prec)
  let new_x = x - f(x) / d
  if Double::abs(new_x - x) < prec {
    new_x
  } else if cnt > max_cnt {
    new_x
  } else {
    get_oddfprice(f, new_x, cnt + 1.0, prec)
  }
}

///|
fn oddfyield_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 8 && values.length() != 9 {
    return FormulaValue::Error(formula_error_value)
  }
  let (
    settlement,
    maturity,
    issue,
    first_coupon,
    rate,
    pr,
    redemption,
    frequency,
    basis,
  ) = match prepare_oddf_args("ODDFYIELD", values) {
    Ok(args) => args
    Err(err) => return err
  }
  if basis < 0 || basis > 4 {
    return FormulaValue::Error(formula_error_num)
  }
  let years = coupdays_between(settlement, maturity, basis)
  let px = pr - 100.0
  let num = rate * years * 100.0 - px
  let denum = px / 4.0 + years * px / 2.0 + years * 100.0
  let guess = num / denum
  let f = fn(yld : Double) -> Double {
    match
      oddfprice_calc(
        settlement, maturity, issue, first_coupon, rate, yld, redemption, frequency,
        basis,
      ) {
      Ok(price) => pr - price
      Err(_) => 0.0 / 0.0
    }
  }
  let result = get_oddfprice(f, guess, 0.0, 1.0e-7)
  if Double::is_nan(result) || Double::is_inf(result) {
    FormulaValue::Error(formula_error_num)
  } else {
    number_or_num_error(round_significant_digits(result, 15))
  }
}

///|
fn prepare_oddl_args(
  name : String,
  values : ArrayView[FormulaValue],
) -> Result[
  (Double, Double, Double, Double, Double, Double, Double, Int),
  FormulaValue,
] {
  let settlement = match value_as_date_serial(values[0]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let maturity = match value_as_date_serial(values[1]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let last_interest = match value_as_date_serial(values[2]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if last_interest >= settlement {
    return Err(FormulaValue::Error(formula_error_num))
  }
  if settlement >= maturity {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let rate = match value_as_number(values[3]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if rate < 0.0 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let yld_or_pr = match prepare_odd_yld_or_pr_arg(name, values[4]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  let redemption = match value_as_number(values[5]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if redemption <= 0.0 {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let frequency = match value_as_number(values[6]) {
    Ok(num) => num
    Err(err) => return Err(err)
  }
  if !validate_frequency(frequency) {
    return Err(FormulaValue::Error(formula_error_num))
  }
  let basis = if values.length() == 8 {
    match value_as_number(values[7]) {
      Ok(num) => Double::to_int(trunc_double(num))
      Err(err) => return Err(err)
    }
  } else {
    0
  }
  Ok(
    (
      settlement, maturity, last_interest, rate, yld_or_pr, redemption, frequency,
      basis,
    ),
  )
}

///|
fn oddl_values(name : String, values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 7 && values.length() != 8 {
    return FormulaValue::Error(formula_error_value)
  }
  let (
    settlement,
    maturity,
    last_interest,
    rate,
    pr_or_yld,
    redemption,
    frequency,
    basis,
  ) = match prepare_oddl_args(name, values) {
    Ok(args) => args
    Err(err) => return err
  }
  if basis < 0 || basis > 4 {
    return FormulaValue::Error(formula_error_num)
  }
  let num_months = 12.0 / frequency
  let nc = match coupnum_value(last_interest, maturity, frequency) {
    Ok(num) => num
    Err(err) => return err
  }
  let mut early_coupon = last_interest
  let ag = aggr_between(1.0, Double::floor(nc), [0.0, 0.0, 0.0], fn(
    acc : Array[Double],
    index : Double,
  ) -> Array[Double] {
    let late_coupon = change_month_serial(early_coupon, num_months, false)
    let nl = coupdays_between(early_coupon, late_coupon, basis)
    let mut dci = coupdays_between(early_coupon, maturity, basis)
    if index < nc {
      dci = nl
    }
    let mut a = 0.0
    if late_coupon < settlement {
      a = dci
    } else if early_coupon < settlement {
      a = coupdays_between(early_coupon, settlement, basis)
    }
    let start_date = if settlement > early_coupon {
      settlement
    } else {
      early_coupon
    }
    let end_date = if maturity < late_coupon { maturity } else { late_coupon }
    let dsc = coupdays_between(start_date, end_date, basis)
    early_coupon = late_coupon
    let dcnl = acc[0] + dci / nl
    let anl = acc[1] + a / nl
    let dscnl = acc[2] + dsc / nl
    [dcnl, anl, dscnl]
  })
  let dcnl = ag[0]
  let anl = ag[1]
  let dscnl = ag[2]
  let x = 100.0 * rate / frequency
  let term1 = dcnl * x + redemption
  if name == "ODDLPRICE" {
    let term2 = dscnl * pr_or_yld / frequency + 1.0
    let term3 = anl * x
    let result = term1 / term2 - term3
    return number_or_num_error(round_significant_digits(result, 15))
  }
  let term2 = anl * x + pr_or_yld
  let term3 = frequency / dscnl
  let result = (term1 - term2) / term2 * term3
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn median_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Number(num) => numbers.push(num)
      FormulaValue::Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
      FormulaValue::String(text) =>
        match parse_double_opt(text) {
          Some(num) => numbers.push(num)
          None => return FormulaValue::Error(formula_error_value)
        }
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  if numbers.length() == 0 {
    return FormulaValue::Error(formula_error_num)
  }
  numbers.sort()
  let count = numbers.length()
  if count % 2 == 0 {
    let left = numbers[count / 2 - 1]
    let right = numbers[count / 2]
    FormulaValue::Number((left + right) / 2.0)
  } else {
    FormulaValue::Number(numbers[count / 2])
  }
}

///|
fn list_from_value(value : FormulaValue) -> Array[FormulaValue] {
  match value {
    FormulaValue::List(list) => list
    _ => [value]
  }
}

///|
fn index_of_double(values : ArrayView[Double], target : Double) -> Int {
  for i in 0..<values.length() {
    if values[i] == target {
      return i
    }
  }
  -1
}

///|
fn avedev_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let avg_value = average_values(values)
  let avg = match avg_value {
    FormulaValue::Number(num) => num
    _ => return FormulaValue::Error(formula_error_value)
  }
  let mut sum = 0.0
  let mut count = 0
  for value in values {
    match value {
      FormulaValue::List(list) =>
        for cell in list {
          match value_as_number(cell) {
            Ok(num) => {
              sum = sum + Double::abs(num - avg)
              count = count + 1
            }
            Err(_) => return FormulaValue::Error(formula_error_value)
          }
        }
      _ =>
        match value_as_number(value) {
          Ok(num) => {
            sum = sum + Double::abs(num - avg)
            count = count + 1
          }
          Err(_) => return FormulaValue::Error(formula_error_value)
        }
    }
  }
  if count == 0 {
    FormulaValue::Error(formula_error_value)
  } else {
    FormulaValue::Number(
      round_significant_digits(sum / Double::from_int(count), 15),
    )
  }
}

///|
fn devsq_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match value {
      FormulaValue::List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            FormulaValue::Number(num) => numbers.push(num)
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          FormulaValue::Number(num) => numbers.push(num)
          _ => ()
        }
    }
  }
  if numbers.length() == 0 {
    return FormulaValue::Error(formula_error_na)
  }
  let mut sum = 0.0
  for num in numbers {
    sum = sum + num
  }
  let mean = sum / Double::from_int(numbers.length())
  let mut total = 0.0
  for num in numbers {
    let delta = num - mean
    total = total + delta * delta
  }
  FormulaValue::Number(round_significant_digits(total, 15))
}

///|
fn geomean_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut product = 1.0
  let mut count = 0
  for value in values {
    match value {
      FormulaValue::List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            FormulaValue::Number(num) => {
              if num <= 0.0 {
                return FormulaValue::Error(formula_error_num)
              }
              product = product * num
              count = count + 1
            }
            FormulaValue::Error(err) => return FormulaValue::Error(err)
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          FormulaValue::Number(num) => {
            if num <= 0.0 {
              return FormulaValue::Error(formula_error_num)
            }
            product = product * num
            count = count + 1
          }
          FormulaValue::Bool(flag) => {
            let num = if flag { 1.0 } else { 0.0 }
            if num <= 0.0 {
              return FormulaValue::Error(formula_error_num)
            }
            product = product * num
            count = count + 1
          }
          FormulaValue::String(text) =>
            match parse_double_opt(text) {
              Some(num) => {
                if num <= 0.0 {
                  return FormulaValue::Error(formula_error_num)
                }
                product = product * num
                count = count + 1
              }
              None => return FormulaValue::Error(formula_error_value)
            }
          FormulaValue::Error(err) => return FormulaValue::Error(err)
          FormulaValue::Empty => ()
          FormulaValue::List(_) => ()
        }
    }
  }
  if count == 0 {
    return FormulaValue::Error(formula_error_num)
  }
  let result = @math.pow(product, 1.0 / Double::from_int(count))
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn harmean_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut total = 0.0
  let mut count = 0
  for value in values {
    match value {
      FormulaValue::List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            FormulaValue::Number(num) => {
              if num <= 0.0 {
                return FormulaValue::Error(formula_error_na)
              }
              total = total + 1.0 / num
              count = count + 1
            }
            FormulaValue::Error(err) => return FormulaValue::Error(err)
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          FormulaValue::Number(num) => {
            if num <= 0.0 {
              return FormulaValue::Error(formula_error_na)
            }
            total = total + 1.0 / num
            count = count + 1
          }
          FormulaValue::Bool(flag) => {
            let num = if flag { 1.0 } else { 0.0 }
            if num <= 0.0 {
              return FormulaValue::Error(formula_error_na)
            }
            total = total + 1.0 / num
            count = count + 1
          }
          FormulaValue::String(text) =>
            match parse_double_opt(text) {
              Some(num) => {
                if num <= 0.0 {
                  return FormulaValue::Error(formula_error_na)
                }
                total = total + 1.0 / num
                count = count + 1
              }
              None => ()
            }
          FormulaValue::Error(err) => return FormulaValue::Error(err)
          FormulaValue::Empty => ()
          FormulaValue::List(_) => ()
        }
    }
  }
  if count == 0 {
    return FormulaValue::Error(formula_error_na)
  }
  let result = 1.0 / (total / Double::from_int(count))
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn kurt_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match value {
      FormulaValue::List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            FormulaValue::Number(num) => numbers.push(num)
            FormulaValue::String(text) =>
              match parse_double_opt(text) {
                Some(num) => numbers.push(num)
                None => ()
              }
            FormulaValue::Bool(flag) =>
              numbers.push(if flag { 1.0 } else { 0.0 })
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          FormulaValue::Number(num) => numbers.push(num)
          FormulaValue::String(text) =>
            match parse_double_opt(text) {
              Some(num) => numbers.push(num)
              None => ()
            }
          FormulaValue::Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
          _ => ()
        }
    }
  }
  if numbers.length() < 4 {
    return FormulaValue::Error(formula_error_div)
  }
  let mut sum_numbers = 0.0
  for num in numbers {
    sum_numbers = sum_numbers + num
  }
  let count = Double::from_int(numbers.length())
  let mean = sum_numbers / count
  let stdev = match sample_stdev(numbers) {
    Some(num) => num
    None => return FormulaValue::Error(formula_error_div)
  }
  if stdev <= 0.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let mut sum = 0.0
  for num in numbers {
    let scaled = (num - mean) / stdev
    sum = sum + scaled * scaled * scaled * scaled
  }
  let term1 = sum *
    (count * (count + 1.0) / ((count - 1.0) * (count - 2.0) * (count - 3.0)))
  let term2 = 3.0 *
    @math.pow(count - 1.0, 2.0) /
    ((count - 2.0) * (count - 3.0))
  number_or_num_error(round_significant_digits(term1 - term2, 15))
}

///|
fn skew_values(name : String, values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match value {
      FormulaValue::List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            FormulaValue::Error(err) => return FormulaValue::Error(err)
            FormulaValue::Number(num) => numbers.push(num)
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          FormulaValue::Number(num) => numbers.push(num)
          FormulaValue::String(text) =>
            match parse_double_opt(text) {
              Some(num) => numbers.push(num)
              None => return FormulaValue::Error(formula_error_value)
            }
          FormulaValue::Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
          FormulaValue::Error(err) => return FormulaValue::Error(err)
          FormulaValue::Empty => ()
          FormulaValue::List(_) => ()
        }
    }
  }
  if numbers.length() <= 2 {
    return FormulaValue::Error(formula_error_div)
  }
  let mut sum = 0.0
  for num in numbers {
    sum = sum + num
  }
  let count = Double::from_int(numbers.length())
  let mean = sum / count
  let stdev = if name == "SKEW" {
    match sample_stdev(numbers) {
      Some(num) => num
      None => return FormulaValue::Error(formula_error_div)
    }
  } else {
    let mut sum_sq = 0.0
    for num in numbers {
      let delta = num - mean
      sum_sq = sum_sq + delta * delta
    }
    @math.pow(sum_sq / count, 0.5)
  }
  if stdev <= 0.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let mut sum_scaled = 0.0
  for num in numbers {
    let scaled = (num - mean) / stdev
    sum_scaled = sum_scaled + scaled * scaled * scaled
  }
  let result = if name == "SKEW" {
    sum_scaled * (count / ((count - 1.0) * (count - 2.0)))
  } else {
    sum_scaled / count
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn standardize_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let x = match value_as_number(values[0]) {
    Ok(num) => num
    Err(err) => return err
  }
  let mean = match value_as_number(values[1]) {
    Ok(num) => num
    Err(err) => return err
  }
  let stddev = match value_as_number(values[2]) {
    Ok(num) => num
    Err(err) => return err
  }
  if stddev <= 0.0 {
    return FormulaValue::Error(formula_error_na)
  }
  let result = (x - mean) / stddev
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn kth_values(
  name : String,
  array_value : FormulaValue,
  k_value : FormulaValue,
) -> FormulaValue {
  let k_raw = match value_as_number(k_value) {
    Ok(num) => num
    Err(err) => return err
  }
  let k = k_raw.to_int()
  if k < 1 {
    return FormulaValue::Error(formula_error_num)
  }
  let values = list_from_value(array_value)
  let numbers : Array[Double] = []
  for value in values {
    match normalize_scalar(value) {
      FormulaValue::Number(num) => numbers.push(num)
      _ => ()
    }
  }
  if numbers.length() < k {
    return FormulaValue::Error(formula_error_num)
  }
  numbers.sort()
  let result = if name == "LARGE" {
    numbers[numbers.length() - k]
  } else {
    numbers[k - 1]
  }
  FormulaValue::Number(result)
}

///|
fn mode_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match value {
      FormulaValue::List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            FormulaValue::Number(num) => numbers.push(num)
            FormulaValue::Bool(flag) =>
              numbers.push(if flag { 1.0 } else { 0.0 })
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          FormulaValue::Number(num) => numbers.push(num)
          FormulaValue::Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
          FormulaValue::Error(err) => return FormulaValue::Error(err)
          _ => return FormulaValue::Error(formula_error_value)
        }
    }
  }
  if numbers.length() == 0 {
    return FormulaValue::Error(formula_error_na)
  }
  numbers.sort()
  let mut mode_count = 0
  let mut mode = 0.0
  for i in 0..<numbers.length() {
    let mut count = 0
    for j in 0..<numbers.length() {
      if i != j && numbers[j] == numbers[i] {
        count = count + 1
      }
    }
    if count > mode_count {
      mode_count = count
      mode = numbers[i]
    }
  }
  if mode_count == 0 {
    FormulaValue::Error(formula_error_na)
  } else {
    FormulaValue::Number(mode)
  }
}

///|
fn mode_mult_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let numbers : Array[Double] = []
  for value in values {
    match value {
      FormulaValue::List(list) =>
        for cell in list {
          match normalize_scalar(cell) {
            FormulaValue::Number(num) => numbers.push(num)
            FormulaValue::Bool(flag) =>
              numbers.push(if flag { 1.0 } else { 0.0 })
            _ => ()
          }
        }
      _ =>
        match normalize_scalar(value) {
          FormulaValue::Number(num) => numbers.push(num)
          FormulaValue::Bool(flag) => numbers.push(if flag { 1.0 } else { 0.0 })
          FormulaValue::Error(err) => return FormulaValue::Error(err)
          _ => return FormulaValue::Error(formula_error_value)
        }
    }
  }
  if numbers.length() == 0 {
    return FormulaValue::Error(formula_error_na)
  }
  numbers.sort()
  let mut mode_count = 0
  let mut modes : Array[FormulaValue] = []
  for i in 0..<numbers.length() {
    let mut count = 0
    for j in (i + 1)..<numbers.length() {
      if numbers[i] == numbers[j] {
        count = count + 1
      }
    }
    if count > mode_count {
      mode_count = count
      modes = [FormulaValue::Number(numbers[i])]
    } else if count == mode_count {
      modes.push(FormulaValue::Number(numbers[i]))
    }
  }
  if mode_count == 0 {
    FormulaValue::Error(formula_error_na)
  } else {
    FormulaValue::List(modes)
  }
}

///|
fn percentile_values(
  array_value : FormulaValue,
  k : Double,
  exclusive : Bool,
  error_on_error : Bool,
) -> FormulaValue {
  let values = list_from_value(array_value)
  let numbers : Array[Double] = []
  for value in values {
    match normalize_scalar(value) {
      FormulaValue::Error(err) =>
        return if error_on_error {
          FormulaValue::Error(formula_error_num)
        } else {
          FormulaValue::Error(err)
        }
      FormulaValue::Number(num) => numbers.push(num)
      _ => ()
    }
  }
  if numbers.length() == 0 {
    return FormulaValue::Error(formula_error_num)
  }
  numbers.sort()
  let count = numbers.length()
  if exclusive {
    let idx = k * Double::from_int(count + 1)
    let base = @math.floor(idx)
    let base_index = base.to_int()
    let next_index = base_index - 1
    if next_index < 0 || base_index >= count {
      return FormulaValue::Error(formula_error_num)
    }
    let proportion = idx - base
    let result = numbers[next_index] +
      (numbers[base_index] - numbers[next_index]) * proportion
    return FormulaValue::Number(round_significant_digits(result, 15))
  }
  let idx = k * Double::from_int(count - 1)
  let base = @math.floor(idx)
  if idx == base {
    return FormulaValue::Number(numbers[base.to_int()])
  }
  let base_index = base.to_int()
  let next_index = base_index + 1
  let proportion = idx - base
  let result = numbers[base_index] +
    (numbers[next_index] - numbers[base_index]) * proportion
  FormulaValue::Number(round_significant_digits(result, 15))
}

///|
fn percentrank_values(
  name : String,
  array_value : FormulaValue,
  x : Double,
  significance : Double,
) -> FormulaValue {
  if significance < 1.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let values = list_from_value(array_value)
  let numbers : Array[Double] = []
  for value in values {
    match normalize_scalar(value) {
      FormulaValue::Error(_) => return FormulaValue::Error(formula_error_na)
      FormulaValue::Number(num) => numbers.push(num)
      _ => ()
    }
  }
  if numbers.length() == 0 {
    return FormulaValue::Error(formula_error_na)
  }
  numbers.sort()
  let count = numbers.length()
  if x < numbers[0] || x > numbers[count - 1] {
    return FormulaValue::Error(formula_error_na)
  }
  let mut pos = Double::from_int(index_of_double(numbers, x))
  if pos < 0.0 {
    let mut idx = 0.0
    let mut cmp = numbers[0]
    while cmp < x {
      idx = idx + 1.0
      cmp = numbers[idx.to_int()]
    }
    idx = idx - 1.0
    pos = idx + (x - numbers[idx.to_int()]) / (cmp - numbers[idx.to_int()])
  }
  let pow = @math.pow(10.0, significance)
  let digit = if name == "PERCENTRANK.EXC" {
    pow * (pos + 1.0) / (Double::from_int(count) + 1.0)
  } else {
    pow * pos / (Double::from_int(count) - 1.0)
  }
  let result = @math.floor(digit) / pow
  FormulaValue::Number(round_significant_digits(result, 15))
}

///|
fn quartile_values(
  name : String,
  array_value : FormulaValue,
  quart : Double,
  exclusive : Bool,
) -> FormulaValue {
  if exclusive {
    if quart <= 0.0 || quart >= 4.0 {
      return FormulaValue::Error(formula_error_num)
    }
  } else if quart < 0.0 || quart > 4.0 {
    return FormulaValue::Error(formula_error_num)
  }
  let k = quart / 4.0
  let error_on_error = name == "QUARTILE.EXC"
  percentile_values(array_value, k, exclusive, error_on_error)
}

///|
fn rank_values(
  num_value : FormulaValue,
  array_value : FormulaValue,
  order : Double?,
) -> FormulaValue {
  let num = match value_as_number(num_value) {
    Ok(num) => num
    Err(err) => return err
  }
  let values = list_from_value(array_value)
  let numbers : Array[Double] = []
  for value in values {
    match normalize_scalar(value) {
      FormulaValue::Number(num) => numbers.push(num)
      _ => ()
    }
  }
  if numbers.length() == 0 {
    return FormulaValue::Error(formula_error_na)
  }
  numbers.sort()
  let order_value = match order {
    Some(num) => num
    None => 0.0
  }
  if order_value == 0.0 {
    numbers.rev_in_place()
  }
  let idx = index_of_double(numbers, num)
  if idx < 0 {
    FormulaValue::Error(formula_error_na)
  } else {
    FormulaValue::Number(Double::from_int(idx + 1))
  }
}

///|
fn sample_stdev(numbers : ArrayView[Double]) -> Double? {
  if numbers.length() < 2 {
    return None
  }
  let mut sum = 0.0
  for num in numbers {
    sum = sum + num
  }
  let mean = sum / Double::from_int(numbers.length())
  let mut sum_sq = 0.0
  for num in numbers {
    let delta = num - mean
    sum_sq = sum_sq + delta * delta
  }
  let denom = Double::from_int(numbers.length() - 1)
  Some(@math.pow(sum_sq / denom, 0.5))
}

///|
fn correl_values(
  left_value : FormulaValue,
  right_value : FormulaValue,
) -> FormulaValue {
  let left = list_from_value(left_value)
  let right = list_from_value(right_value)
  if left.length() != right.length() {
    return FormulaValue::Error(formula_error_na)
  }
  let xs : Array[Double] = []
  let ys : Array[Double] = []
  for i in 0..<left.length() {
    let x = sumx_number(left[i])
    let y = sumx_number(right[i])
    if x != 0.0 && y != 0.0 {
      xs.push(x)
      ys.push(y)
    }
  }
  if xs.length() < 2 {
    return FormulaValue::Error(formula_error_div)
  }
  let stdev_x = match sample_stdev(xs) {
    Some(num) => num
    None => return FormulaValue::Error(formula_error_div)
  }
  let stdev_y = match sample_stdev(ys) {
    Some(num) => num
    None => return FormulaValue::Error(formula_error_div)
  }
  if stdev_x == 0.0 || stdev_y == 0.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  for num in xs {
    sum_x = sum_x + num
  }
  for num in ys {
    sum_y = sum_y + num
  }
  let mean_x = sum_x / Double::from_int(xs.length())
  let mean_y = sum_y / Double::from_int(ys.length())
  let mut sum = 0.0
  for i in 0..<xs.length() {
    sum = sum + (xs[i] - mean_x) * (ys[i] - mean_y)
  }
  let denom = Double::from_int(xs.length() - 1)
  let result = sum / denom / stdev_x / stdev_y
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn covar_values(
  name : String,
  left_value : FormulaValue,
  right_value : FormulaValue,
) -> FormulaValue {
  let left = list_from_value(left_value)
  let right = list_from_value(right_value)
  if left.length() != right.length() {
    return FormulaValue::Error(formula_error_na)
  }
  let mut sum_left = 0.0
  let mut count_left = 0
  for value in left {
    match value_as_number_opt(value) {
      Some(num) => {
        sum_left = sum_left + num
        count_left = count_left + 1
      }
      None => ()
    }
  }
  let mut sum_right = 0.0
  let mut count_right = 0
  for value in right {
    match value_as_number_opt(value) {
      Some(num) => {
        sum_right = sum_right + num
        count_right = count_right + 1
      }
      None => ()
    }
  }
  if count_left == 0 || count_right == 0 {
    return FormulaValue::Error(formula_error_div)
  }
  let mean_left = sum_left / Double::from_int(count_left)
  let mean_right = sum_right / Double::from_int(count_right)
  let mut sum = 0.0
  let mut count = 0
  for i in 0..<left.length() {
    match (value_as_number_opt(left[i]), value_as_number_opt(right[i])) {
      (Some(lhs), Some(rhs)) => {
        sum = sum + (lhs - mean_left) * (rhs - mean_right)
        count = count + 1
      }
      _ => ()
    }
  }
  let denom = if name == "COVARIANCE.S" { count - 1 } else { count }
  if denom <= 0 {
    return FormulaValue::Error(formula_error_div)
  }
  let result = sum / Double::from_int(denom)
  FormulaValue::Number(round_significant_digits(result, 15))
}

///|
fn pearson_product_values(
  name : String,
  values : ArrayView[FormulaValue],
) -> FormulaValue {
  if values.length() != 2 && values.length() != 3 {
    return FormulaValue::Error(formula_error_value)
  }
  let mut array1 = list_from_value(values[values.length() - 1])
  let mut array2 = list_from_value(values[0])
  let mut fx = 0.0
  if values.length() == 3 {
    fx = match value_as_number(values[0]) {
      Ok(num) => num
      Err(err) => return err
    }
    array2 = list_from_value(values[1])
    array1 = list_from_value(values[2])
  }
  if name == "PEARSON" || name == "RSQ" {
    let tmp = array1
    array1 = array2
    array2 = tmp
  }
  if array1.length() != array2.length() {
    return FormulaValue::Error(formula_error_na)
  }
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  let mut count = 0
  for i in 0..<array1.length() {
    match (normalize_scalar(array1[i]), normalize_scalar(array2[i])) {
      (FormulaValue::Number(x), FormulaValue::Number(y)) => {
        sum_x = sum_x + x
        sum_y = sum_y + y
        count = count + 1
      }
      _ => ()
    }
  }
  if count == 0 {
    return FormulaValue::Error(formula_error_div)
  }
  let mean_x = sum_x / Double::from_int(count)
  let mean_y = sum_y / Double::from_int(count)
  let mut sum = 0.0
  let mut delta_x = 0.0
  let mut delta_y = 0.0
  for i in 0..<array1.length() {
    match (normalize_scalar(array1[i]), normalize_scalar(array2[i])) {
      (FormulaValue::Number(x), FormulaValue::Number(y)) => {
        let dx = x - mean_x
        let dy = y - mean_y
        sum = sum + dx * dy
        delta_x = delta_x + dx * dx
        delta_y = delta_y + dy * dy
      }
      _ => ()
    }
  }
  if sum * delta_x * delta_y == 0.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let result = match name {
    "FORECAST" | "FORECAST.LINEAR" => mean_y + sum / delta_x * (fx - mean_x)
    "INTERCEPT" => mean_y - sum / delta_x * mean_x
    "PEARSON" => sum / @math.pow(delta_x * delta_y, 0.5)
    "RSQ" => @math.pow(sum / @math.pow(delta_x * delta_y, 0.5), 2.0)
    _ => sum / delta_x
  }
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn steyx_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() != 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let array_x = list_from_value(values[1])
  let array_y = list_from_value(values[0])
  if array_x.length() != array_y.length() {
    return FormulaValue::Error(formula_error_na)
  }
  let mut count = 0.0
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  let mut square_x = 0.0
  let mut square_y = 0.0
  let mut sigma_xy = 0.0
  for i in 0..<array_x.length() {
    match (normalize_scalar(array_x[i]), normalize_scalar(array_y[i])) {
      (FormulaValue::Number(x), FormulaValue::Number(y)) => {
        sum_x = sum_x + x
        sum_y = sum_y + y
        square_x = square_x + x * x
        square_y = square_y + y * y
        sigma_xy = sigma_xy + x * y
        count = count + 1.0
      }
      _ => ()
    }
  }
  if count < 3.0 {
    return FormulaValue::Error(formula_error_div)
  }
  let dx = sum_x / count
  let dy = sum_y / count
  let sigma1 = square_y - 2.0 * dy * sum_y + count * dy * dy
  let sigma2 = sigma_xy - dy * sum_x - sum_y * dx + count * dy * dx
  let sigma3 = square_x - 2.0 * dx * sum_x + count * dx * dx
  let result = @math.pow(
    (sigma1 - sigma2 * sigma2 / sigma3) / (count - 2.0),
    0.5,
  )
  number_or_num_error(round_significant_digits(result, 15))
}

///|
fn trend_growth_values(
  workbook : Workbook,
  sheet_name : String,
  name : String,
  args : ArrayView[Expr],
  values : ArrayView[FormulaValue],
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  if values.length() < 1 {
    return FormulaValue::Error(formula_error_value)
  }
  if values.length() > 4 {
    return FormulaValue::Error(formula_error_value)
  }
  let know_y_range = range_from_expr_or_value(
    workbook,
    sheet_name,
    args[0],
    values[0],
    ctx,
  )
  let know_y = match number_matrix_from_range(know_y_range, false) {
    Ok(matrix) => matrix
    Err(err) => return err
  }
  let mut know_x : Array[Array[Double]] = []
  if values.length() >= 2 {
    let know_x_range = range_from_expr_or_value(
      workbook,
      sheet_name,
      args[1],
      values[1],
      ctx,
    )
    know_x = match number_matrix_from_range(know_x_range, false) {
      Ok(matrix) => matrix
      Err(err) => return err
    }
  }
  let mut new_x : Array[Array[Double]] = []
  if values.length() >= 3 {
    let new_x_range = range_from_expr_or_value(
      workbook,
      sheet_name,
      args[2],
      values[2],
      ctx,
    )
    let base = match number_matrix_from_range(new_x_range, false) {
      Ok(matrix) => matrix
      Err(err) => return err
    }
    new_x = transpose_number_matrix(base)
  }
  let mut constant = true
  if values.length() == 4 {
    constant = match value_as_bool(values[3]) {
      Ok(flag) => flag
      Err(err) => return err
    }
  }
  let is_growth = name == "GROWTH"
  let result = match
    calc_trend_growth(know_y, know_x, new_x, constant, is_growth) {
    Ok(matrix) => matrix
    Err(err) => return err
  }
  for col in 0..<result.length() {
    for row in 0..<result[col].length() {
      result[col][row] = round_significant_digits(result[col][row], 15)
    }
  }
  FormulaValue::List(matrix_values(result))
}

///|
fn min_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut min = None
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Number(num) =>
        min = Some(
          match min {
            Some(current) => if num < current { num } else { current }
            None => num
          },
        )
      FormulaValue::Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        min = Some(
          match min {
            Some(current) => if num < current { num } else { current }
            None => num
          },
        )
      }
      FormulaValue::String(text) =>
        if text == "TRUE" || text == "FALSE" {
          ()
        } else {
          match parse_double_opt(text) {
            Some(num) =>
              min = Some(
                match min {
                  Some(current) => if num < current { num } else { current }
                  None => num
                },
              )
            None => ()
          }
        }
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  match min {
    Some(value) => FormulaValue::Number(value)
    None => FormulaValue::Number(0.0)
  }
}

///|
fn mina_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut min : Double? = None
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Number(num) =>
        min = Some(
          match min {
            Some(current) => if num < current { num } else { current }
            None => num
          },
        )
      FormulaValue::Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        min = Some(
          match min {
            Some(current) => if num < current { num } else { current }
            None => num
          },
        )
      }
      FormulaValue::String(text) =>
        if text == "" {
          ()
        } else if text == "TRUE" || text == "FALSE" {
          let num = if text == "TRUE" { 1.0 } else { 0.0 }
          min = Some(
            match min {
              Some(current) => if num < current { num } else { current }
              None => num
            },
          )
        } else {
          match parse_double_opt(text) {
            Some(num) =>
              min = Some(
                match min {
                  Some(current) => if num < current { num } else { current }
                  None => num
                },
              )
            None => ()
          }
        }
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  match min {
    Some(value) => FormulaValue::Number(value)
    None => FormulaValue::Number(0.0)
  }
}

///|
fn max_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut max = None
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Number(num) =>
        max = Some(
          match max {
            Some(current) => if num > current { num } else { current }
            None => num
          },
        )
      FormulaValue::Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        max = Some(
          match max {
            Some(current) => if num > current { num } else { current }
            None => num
          },
        )
      }
      FormulaValue::String(text) =>
        if text == "TRUE" || text == "FALSE" {
          ()
        } else {
          match parse_double_opt(text) {
            Some(num) =>
              max = Some(
                match max {
                  Some(current) => if num > current { num } else { current }
                  None => num
                },
              )
            None => ()
          }
        }
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  match max {
    Some(value) => FormulaValue::Number(value)
    None => FormulaValue::Number(0.0)
  }
}

///|
fn maxa_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut max : Double? = None
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Number(num) =>
        max = Some(
          match max {
            Some(current) => if num > current { num } else { current }
            None => num
          },
        )
      FormulaValue::Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        max = Some(
          match max {
            Some(current) => if num > current { num } else { current }
            None => num
          },
        )
      }
      FormulaValue::String(text) =>
        if text == "" {
          ()
        } else if text == "TRUE" || text == "FALSE" {
          let num = if text == "TRUE" { 1.0 } else { 0.0 }
          max = Some(
            match max {
              Some(current) => if num > current { num } else { current }
              None => num
            },
          )
        } else {
          match parse_double_opt(text) {
            Some(num) =>
              max = Some(
                match max {
                  Some(current) => if num > current { num } else { current }
                  None => num
                },
              )
            None => ()
          }
        }
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  match max {
    Some(value) => FormulaValue::Number(value)
    None => FormulaValue::Number(0.0)
  }
}

///|
fn count_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut count = 0
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Number(_) => count = count + 1
      FormulaValue::Bool(_) => count = count + 1
      FormulaValue::String(text) =>
        match parse_double_opt(text) {
          Some(_) => count = count + 1
          None => ()
        }
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  FormulaValue::Number(Double::from_int(count))
}

///|
fn counta_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut count = 0
  for value in flatten_values(values) {
    match normalize_scalar(value) {
      FormulaValue::Number(_) => count = count + 1
      FormulaValue::Bool(_) => count = count + 1
      FormulaValue::String(text) => if text != "" { count = count + 1 }
      FormulaValue::Error(_) => ()
      FormulaValue::Empty => ()
      FormulaValue::List(_) => ()
    }
  }
  FormulaValue::Number(Double::from_int(count))
}

///|
fn subtotal_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  if values.length() < 2 {
    return FormulaValue::Error(formula_error_value)
  }
  let function_num = match value_as_number(values[0]) {
    Ok(num) => Double::to_int(trunc_double(num))
    Err(err) => return err
  }
  let sub_values : Array[FormulaValue] = []
  for i in 1..<values.length() {
    sub_values.push(values[i])
  }
  match function_num {
    1 | 101 => average_values(sub_values)
    2 | 102 => count_values(sub_values)
    3 | 103 => counta_values(sub_values)
    4 | 104 => max_values(sub_values)
    5 | 105 => min_values(sub_values)
    6 | 106 => product_values(sub_values)
    7 | 107 => stdev_values(false, sub_values)
    8 | 108 =>
      match variance_values(sub_values, false, false) {
        FormulaValue::Number(variance) => {
          let result = @math.pow(variance, 0.5)
          FormulaValue::Number(round_significant_digits(result, 15))
        }
        FormulaValue::Error(err) => FormulaValue::Error(err)
        _ => FormulaValue::Error(formula_error_value)
      }
    9 | 109 => sum_values(sub_values)
    10 | 110 => variance_values(sub_values, true, false)
    11 | 111 => variance_values(sub_values, false, false)
    _ => FormulaValue::Error(formula_error_value)
  }
}

///|
fn sumproduct_scalars(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut product = 1.0
  for value in values {
    match normalize_scalar(value) {
      FormulaValue::Error(err) => return FormulaValue::Error(err)
      FormulaValue::Number(num) => product = product * num
      FormulaValue::Bool(flag) => {
        let num = if flag { 1.0 } else { 0.0 }
        product = product * num
      }
      FormulaValue::String(text) =>
        match parse_double_opt(text) {
          Some(num) => product = product * num
          None => return FormulaValue::Error(formula_error_value)
        }
      FormulaValue::Empty => ()
      FormulaValue::List(_) => return FormulaValue::Error(formula_error_value)
    }
  }
  FormulaValue::Number(product)
}

///|
fn sumproduct_number(value : FormulaValue) -> Result[Double, FormulaValue] {
  match normalize_scalar(value) {
    FormulaValue::Error(err) => Err(FormulaValue::Error(err))
    FormulaValue::Number(num) => Ok(num)
    FormulaValue::Bool(flag) => Ok(if flag { 1.0 } else { 0.0 })
    FormulaValue::String(text) =>
      if text == "" {
        Ok(0.0)
      } else {
        match parse_double_opt(text) {
          Some(num) => Ok(num)
          None => Err(FormulaValue::Error(formula_error_value))
        }
      }
    FormulaValue::Empty => Ok(0.0)
    FormulaValue::List(_) => Err(FormulaValue::Error(formula_error_value))
  }
}

///|
fn sumproduct_values(ranges : Array[RangeValues]) -> FormulaValue {
  if ranges.length() == 0 {
    return FormulaValue::Error(formula_error_value)
  }
  let base = ranges[0]
  for range in ranges {
    if range.rows != base.rows || range.cols != base.cols {
      return FormulaValue::Error(formula_error_value)
    }
  }
  let mut sum = 0.0
  let count = base.rows * base.cols
  for idx in 0..<count {
    let mut product = 1.0
    for range in ranges {
      match sumproduct_number(range.values[idx]) {
        Ok(num) => product = product * num
        Err(err) => return err
      }
    }
    sum = sum + product
  }
  FormulaValue::Number(sum)
}

///|
fn sumx_number(value : FormulaValue) -> Double {
  match normalize_scalar(value) {
    FormulaValue::Number(num) => num
    FormulaValue::Bool(flag) => if flag { 1.0 } else { 0.0 }
    FormulaValue::String(text) =>
      match parse_double_opt(text) {
        Some(num) => num
        None => 0.0
      }
    FormulaValue::Empty => 0.0
    FormulaValue::Error(_) => 0.0
    FormulaValue::List(_) => 0.0
  }
}

///|
fn sumx_values(
  name : String,
  left : RangeValues,
  right : RangeValues,
) -> FormulaValue {
  if left.rows != right.rows || left.cols != right.cols {
    return FormulaValue::Error(formula_error_na)
  }
  let mut sum = 0.0
  let count = left.rows * left.cols
  for idx in 0..<count {
    let lhs = sumx_number(left.values[idx])
    let rhs = sumx_number(right.values[idx])
    if lhs != 0.0 && rhs != 0.0 {
      let term = match name {
        "SUMX2MY2" => lhs * lhs - rhs * rhs
        "SUMX2PY2" => lhs * lhs + rhs * rhs
        _ => (lhs - rhs) * (lhs - rhs)
      }
      sum = sum + term
    }
  }
  FormulaValue::Number(sum)
}

///|
fn error_type_value(value : FormulaValue) -> FormulaValue {
  match normalize_scalar(value) {
    FormulaValue::Error(err) =>
      if err == formula_error_null {
        FormulaValue::Number(1.0)
      } else if err == formula_error_div {
        FormulaValue::Number(2.0)
      } else if err == formula_error_value {
        FormulaValue::Number(3.0)
      } else if err == formula_error_ref {
        FormulaValue::Number(4.0)
      } else if err == formula_error_name {
        FormulaValue::Number(5.0)
      } else if err == formula_error_num {
        FormulaValue::Number(6.0)
      } else if err == formula_error_na {
        FormulaValue::Number(7.0)
      } else {
        FormulaValue::Error(formula_error_na)
      }
    _ => FormulaValue::Error(formula_error_na)
  }
}

///|
fn type_value(value : FormulaValue) -> FormulaValue {
  match value {
    FormulaValue::Error(_) => FormulaValue::Number(16.0)
    FormulaValue::List(_) => FormulaValue::Number(64.0)
    FormulaValue::Number(_) => FormulaValue::Number(1.0)
    FormulaValue::Bool(_) => FormulaValue::Number(4.0)
    FormulaValue::Empty => FormulaValue::Number(1.0)
    FormulaValue::String(_) => FormulaValue::Number(2.0)
  }
}

///|
fn sheet_index_opt(workbook : Workbook, name : String) -> Int? {
  try workbook.sheet_index(name) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn is_known_error_code(err : String) -> Bool {
  err == formula_error_null ||
  err == formula_error_div ||
  err == formula_error_value ||
  err == formula_error_ref ||
  err == formula_error_name ||
  err == formula_error_num ||
  err == formula_error_na ||
  err == formula_error_spill ||
  err == formula_error_calc ||
  err == formula_error_getting_data
}

///|
fn is_ref_expr(expr : Expr) -> Bool {
  match expr {
    Expr::Cell(_, _) => true
    Expr::Range(_, _, _) => true
    _ => false
  }
}

///|
fn cell_has_formula(
  workbook : Workbook,
  sheet_name : String,
  reference : String,
) -> Bool {
  match workbook.sheet(sheet_name) {
    Some(sheet) => {
      let (row, col) = try cell_ref_to_rc(reference) catch {
        _ => return false
      } noraise {
        value => value
      }
      for cell in sheet.cells() {
        if cell.row == row && cell.col == col {
          match cell.formula {
            Some(formula) => return formula != ""
            None => return false
          }
        }
      }
      false
    }
    None => false
  }
}

///|
fn countblank_values(range_values : RangeValues) -> FormulaValue {
  let mut count = 0
  for value in range_values.values {
    match normalize_scalar(value) {
      FormulaValue::Empty => count = count + 1
      _ => ()
    }
  }
  FormulaValue::Number(Double::from_int(count))
}

///|
fn countif_values(
  range_values : RangeValues,
  criteria_value : FormulaValue,
) -> FormulaValue {
  let criteria = parse_formula_criteria(criteria_value)
  let mut count = 0
  for value in range_values.values {
    let normalized = normalize_scalar(value)
    if normalized is FormulaValue::String(_) &&
      !formula_criteria_condition_is_string(criteria) {
      continue
    }
    if formula_criteria_eval(normalized, criteria) {
      count = count + 1
    }
  }
  FormulaValue::Number(Double::from_int(count))
}

///|
fn sumif_values(
  range_values : RangeValues,
  criteria_value : FormulaValue,
  sum_range : RangeValues?,
) -> FormulaValue {
  let criteria = parse_formula_criteria(criteria_value)
  let mut sum = 0.0
  for row in 0..<range_values.rows {
    for col in 0..<range_values.cols {
      let idx = row * range_values.cols + col
      let cell = range_values.values[idx]
      let normalized = normalize_scalar(cell)
      if normalized is FormulaValue::Empty {
        continue
      }
      if formula_criteria_eval(normalized, criteria) {
        let target = match sum_range {
          Some(range) =>
            match range.get(row, col) {
              Some(value) => value
              None => cell
            }
          None => cell
        }
        match normalize_scalar(target) {
          FormulaValue::Number(num) => sum = sum + num
          FormulaValue::Bool(flag) => {
            let num = if flag { 1.0 } else { 0.0 }
            sum = sum + num
          }
          _ => ()
        }
      }
    }
  }
  FormulaValue::Number(sum)
}

///|
fn averageif_values(
  range_values : RangeValues,
  criteria_value : FormulaValue,
  average_range : RangeValues?,
) -> FormulaValue {
  let criteria = parse_formula_criteria(criteria_value)
  let mut sum = 0.0
  let mut count = 0
  for row in 0..<range_values.rows {
    for col in 0..<range_values.cols {
      let idx = row * range_values.cols + col
      let cell = normalize_scalar(range_values.values[idx])
      if formula_value_string(cell) == "" {
        continue
      }
      if cell is FormulaValue::String(_) &&
        !formula_criteria_condition_is_string(criteria) {
        continue
      }
      if formula_criteria_eval(cell, criteria) {
        let target = match average_range {
          Some(range) =>
            match range.get(row, col) {
              Some(value) => value
              None => cell
            }
          None => cell
        }
        match parse_double_opt(formula_value_string(target)) {
          Some(num) => {
            sum = sum + num
            count = count + 1
          }
          None => ()
        }
      }
    }
  }
  if count == 0 {
    FormulaValue::Error(formula_error_div)
  } else {
    FormulaValue::Number(sum / Double::from_int(count))
  }
}

///|
fn maxifs_values(
  max_range : RangeValues,
  matches : Array[CellIndex],
) -> FormulaValue {
  let mut best : Double? = None
  for cell in matches {
    match max_range.get(cell.row, cell.col) {
      Some(value) =>
        match value_as_number_opt(value) {
          Some(num) =>
            match best {
              Some(current) => if num > current { best = Some(num) }
              None => best = Some(num)
            }
          None => ()
        }
      None => return FormulaValue::Error(formula_error_value)
    }
  }
  match best {
    Some(value) => FormulaValue::Number(value)
    None => FormulaValue::Number(0.0)
  }
}

///|
fn minifs_values(
  min_range : RangeValues,
  matches : Array[CellIndex],
) -> FormulaValue {
  let mut best : Double? = None
  for cell in matches {
    match min_range.get(cell.row, cell.col) {
      Some(value) =>
        match value_as_number_opt(value) {
          Some(num) =>
            match best {
              Some(current) => if num < current { best = Some(num) }
              None => best = Some(num)
            }
          None => ()
        }
      None => return FormulaValue::Error(formula_error_value)
    }
  }
  match best {
    Some(value) => FormulaValue::Number(value)
    None => FormulaValue::Number(0.0)
  }
}

///|
fn ifs_match(
  ranges : Array[RangeValues],
  criteria : Array[FormulaCriteria],
) -> Array[CellIndex] {
  let matches : Array[CellIndex] = []
  if ranges.length() == 0 {
    return matches
  }
  let base = ranges[0]
  let base_criteria = criteria[0]
  for row in 0..<base.rows {
    for col in 0..<base.cols {
      let value = base.values[row * base.cols + col]
      if formula_criteria_eval(value, base_criteria) {
        matches.push({ row, col })
      }
    }
  }
  let mut current = matches
  for i in 1..<ranges.length() {
    let range = ranges[i]
    let criteria = criteria[i]
    let next : Array[CellIndex] = []
    for cell in current {
      match range.get(cell.row, cell.col) {
        Some(value) =>
          if formula_criteria_eval(value, criteria) {
            next.push(cell)
          }
        None => ()
      }
    }
    current = next
  }
  current
}

///|
fn flatten_values(values : ArrayView[FormulaValue]) -> Array[FormulaValue] {
  let out : Array[FormulaValue] = []
  for value in values {
    match value {
      FormulaValue::List(list) => out.append(list)
      _ => out.push(value)
    }
  }
  out
}

///|

///|
fn resolve_cell_value(
  workbook : Workbook,
  sheet_name : String,
  reference : String,
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  let key = sheet_name + "!" + reference
  match ctx.visiting.get(key) {
    Some(_) => return FormulaValue::Error(formula_error_calc)
    None => ()
  }
  if ctx.depth >= ctx.max_depth {
    return FormulaValue::Error(formula_error_calc)
  }
  ctx.visiting[key] = true
  ctx.depth = ctx.depth + 1
  let value = calc_cell_value_internal(workbook, sheet_name, reference, ctx)
  ignore(ctx.visiting.remove(key))
  ctx.depth = ctx.depth - 1
  value
}

///|
fn calc_cell_value_internal(
  workbook : Workbook,
  sheet_name : String,
  reference : String,
  ctx : CalcContext,
) -> FormulaValue raise XlsxError {
  let sheet = match workbook.sheet(sheet_name) {
    Some(value) => value
    None => return FormulaValue::Error(formula_error_ref)
  }
  let (row, col) = cell_ref_to_rc(reference)
  for cell in sheet.cells() {
    if cell.row == row && cell.col == col {
      match cell.formula {
        Some(formula) => {
          let expr = parse_formula_expr(formula)
          let prev_sheet = ctx.current_sheet
          let prev_ref = ctx.current_ref
          ctx.current_sheet = sheet_name
          ctx.current_ref = reference
          let result = eval_expr(workbook, sheet_name, expr, ctx)
          ctx.current_sheet = prev_sheet
          ctx.current_ref = prev_ref
          return result
        }
        None => {
          let value = cell_value_from_raw(cell.value_type, cell.value)
          return formula_value_from_cell_value(value)
        }
      }
    }
  }
  FormulaValue::Empty
}

///|
fn collect_range_values(
  workbook : Workbook,
  sheet_name : String,
  start_ref : String,
  end_ref : String,
  ctx : CalcContext,
) -> Array[FormulaValue] raise XlsxError {
  collect_range_values_with_shape(workbook, sheet_name, start_ref, end_ref, ctx).values
}

///|
fn collect_range_values_with_shape(
  workbook : Workbook,
  sheet_name : String,
  start_ref : String,
  end_ref : String,
  ctx : CalcContext,
) -> RangeValues raise XlsxError {
  let (row1, col1) = cell_ref_to_rc(start_ref)
  let (row2, col2) = cell_ref_to_rc(end_ref)
  let min_row = if row1 < row2 { row1 } else { row2 }
  let max_row = if row1 > row2 { row1 } else { row2 }
  let min_col = if col1 < col2 { col1 } else { col2 }
  let max_col = if col1 > col2 { col1 } else { col2 }
  let out : Array[FormulaValue] = []
  for row in min_row..<=max_row {
    for col in min_col..<=max_col {
      let cell_ref = cell_ref_from(row, col)
      out.push(resolve_cell_value(workbook, sheet_name, cell_ref, ctx))
    }
  }
  { values: out, rows: max_row - min_row + 1, cols: max_col - min_col + 1 }
}

///|
fn eval_range_expr(
  workbook : Workbook,
  sheet_name : String,
  expr : Expr,
  ctx : CalcContext,
) -> RangeValues raise XlsxError {
  match expr {
    Expr::Range(sheet, start_ref, end_ref) => {
      let target_sheet = if sheet == "" { sheet_name } else { sheet }
      collect_range_values_with_shape(
        workbook, target_sheet, start_ref, end_ref, ctx,
      )
    }
    Expr::Cell(sheet, reference) => {
      let target_sheet = if sheet == "" { sheet_name } else { sheet }
      let value = resolve_cell_value(workbook, target_sheet, reference, ctx)
      { values: [value], rows: 1, cols: 1 }
    }
    Expr::FuncCall(name, args) =>
      if is_munit_func(name) {
        munit_range_values_from_expr(workbook, sheet_name, args, ctx)
      } else if name == "TRANSPOSE" {
        transpose_range_values_from_expr(workbook, sheet_name, args, ctx)
      } else {
        let value = eval_expr(workbook, sheet_name, expr, ctx)
        { values: [value], rows: 1, cols: 1 }
      }
    _ => {
      let value = eval_expr(workbook, sheet_name, expr, ctx)
      { values: [value], rows: 1, cols: 1 }
    }
  }
}
