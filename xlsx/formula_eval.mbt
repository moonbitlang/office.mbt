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
}

///|
priv struct RangeValues {
  values : Array[FormulaValue]
  rows : Int
  cols : Int
}

///|
priv struct CellIndex {
  row : Int
  col : Int
}

///|
fn CalcContext::new() -> CalcContext {
  { visiting: {}, depth: 0, max_depth: 128 }
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
      if ch.is_ascii_digit() || ch == '.' {
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
  let cell_ref = match parse_cell_ref_token(cell_token) {
    Some(value) => value
    None => raise XlsxError::InvalidCellRef(value=cell_token)
  }
  if self.peek() == Some(':') {
    self.consume()
    let end_token = self.parse_identifier_token()
    let end_ref = match parse_cell_ref_token(end_token) {
      Some(value) => value
      None => raise XlsxError::InvalidCellRef(value=end_token)
    }
    return Expr::Range(sheet, cell_ref, end_ref)
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
    let cell_ref = match parse_cell_ref_token(cell_token) {
      Some(value) => value
      None => raise XlsxError::InvalidCellRef(value=cell_token)
    }
    if self.peek() == Some(':') {
      self.consume()
      let end_token = self.parse_identifier_token()
      let end_ref = match parse_cell_ref_token(end_token) {
        Some(value) => value
        None => raise XlsxError::InvalidCellRef(value=end_token)
      }
      return Expr::Range(ident, cell_ref, end_ref)
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
  match parse_cell_ref_token(ident) {
    Some(value) =>
      if self.peek() == Some(':') {
        self.consume()
        let end_token = self.parse_identifier_token()
        let end_ref = match parse_cell_ref_token(end_token) {
          Some(value) => value
          None => raise XlsxError::InvalidCellRef(value=end_token)
        }
        Expr::Range("", value, end_ref)
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
fn parse_double_opt(text : StringView) -> Double? {
  let parsed = @strconv.parse_double(text) catch { _ => return None }
  Some(parsed)
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
fn round_half_away_from_zero(value : Double) -> Double {
  if value < 0.0 {
    -Double::floor(-value + 0.5)
  } else {
    Double::floor(value + 0.5)
  }
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
  let values : Array[FormulaValue] = []
  for arg in args {
    values.push(eval_expr(workbook, sheet_name, arg, ctx))
  }
  match name {
    "TRUE" => FormulaValue::Bool(true)
    "FALSE" => FormulaValue::Bool(false)
    "SUM" => sum_values(values)
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
          return eval_expr(workbook, sheet_name, expr, ctx)
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
