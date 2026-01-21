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
fn has_change_of_sign(u : Double, w : Double) -> Bool {
  (u < 0.0 && w > 0.0) || (u > 0.0 && w < 0.0)
}

///|
priv struct InverseIterator {
  fp : Double
  fdf : Double
  nt : Double
}

///|
fn InverseIterator::call(self : InverseIterator, x : Double) -> Double {
  self.fp - get_t_dist(x, self.fdf, self.nt)
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
    "TdotDIST" | "T.DIST" | "_XLFN.T.DIST" => tdist_values(values)
    "TdotDISTdot2T" | "T.DIST.2T" | "_XLFN.T.DIST.2T" => tdist_2t_values(values)
    "TdotDISTdotRT" | "T.DIST.RT" | "_XLFN.T.DIST.RT" => tdist_rt_values(values)
    "TDIST" => tdist_legacy_values(values)
    "TdotINV" | "T.INV" | "_XLFN.T.INV" => tinv_values(values)
    "TdotINVdot2T" | "T.INV.2T" | "_XLFN.T.INV.2T" => tinv_2t_values(values)
    "TINV" => tinv_2t_values(values)
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
          Ok(text) => FormulaValue::String(text)
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
    InverseIterator::{ fp: 1.0 - probability, fdf: degrees, nt: 4.0 }
  } else {
    InverseIterator::{ fp: probability, fdf: degrees, nt: 4.0 }
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
  let iterator = InverseIterator::{ fp: probability, fdf: degrees, nt: 2.0 }
  let result = calc_iterate_inverse(iterator, degrees / 2.0, degrees)
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
