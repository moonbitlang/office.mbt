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
