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
fn format_number(value : Double) -> String {
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
fn number_or_num_error(value : Double) -> FormulaValue {
  if Double::is_nan(value) || Double::is_inf(value) {
    FormulaValue::Error(formula_error_num)
  } else {
    FormulaValue::Number(value)
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
  let values : Array[FormulaValue] = []
  for arg in args {
    values.push(eval_expr(workbook, sheet_name, arg, ctx))
  }
  match name {
    "TRUE" => FormulaValue::Bool(true)
    "FALSE" => FormulaValue::Bool(false)
    "SUM" => sum_values(values)
    "PRODUCT" => product_values(values)
    "AVERAGE" => average_values(values)
    "AVERAGEA" => averagea_values(values)
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
    "LEN" =>
      if values.length() == 1 {
        match value_as_string(values[0]) {
          Ok(text) => FormulaValue::Number(Double::from_int(text.length()))
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
    "VALUE" =>
      if values.length() == 1 {
        match value_as_number_text(values[0]) {
          Ok(num) => FormulaValue::Number(num)
          Err(err) => err
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
  match normalize_scalar(value) {
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
    _ => {
      let value = eval_expr(workbook, sheet_name, expr, ctx)
      { values: [value], rows: 1, cols: 1 }
    }
  }
}
