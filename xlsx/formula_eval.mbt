///|
let formula_error_div = "#DIV/0!"

///|
let formula_error_name = "#NAME?"

///|
let formula_error_value = "#VALUE!"

///|
let formula_error_ref = "#REF!"

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
priv struct CalcContext {
  visiting : Map[String, Bool]
  mut depth : Int
  max_depth : Int
}

///|
fn CalcContext::new() -> CalcContext {
  { visiting: {}, depth: 0, max_depth: 128 }
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
    "MIN" => min_values(values)
    "MAX" => max_values(values)
    "COUNT" => count_values(values)
    "IF" =>
      if values.length() >= 2 {
        let cond = formula_value_truthy(values[0])
        if cond {
          values[1]
        } else if values.length() >= 3 {
          values[2]
        } else {
          FormulaValue::Bool(false)
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
  let mut has_error = None
  for value in flatten_values(values) {
    match value_as_number(value) {
      Ok(num) => sum = sum + num
      Err(err) => has_error = Some(err)
    }
  }
  match has_error {
    Some(err) => err
    None => FormulaValue::Number(sum)
  }
}

///|
fn average_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut sum = 0.0
  let mut count = 0
  let mut has_error = None
  for value in flatten_values(values) {
    match value_as_number(value) {
      Ok(num) => {
        sum = sum + num
        count = count + 1
      }
      Err(err) => has_error = Some(err)
    }
  }
  match has_error {
    Some(err) => err
    None =>
      if count == 0 {
        FormulaValue::Error(formula_error_div)
      } else {
        FormulaValue::Number(sum / Double::from_int(count))
      }
  }
}

///|
fn min_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut min = None
  let mut has_error = None
  for value in flatten_values(values) {
    match value_as_number(value) {
      Ok(num) =>
        match min {
          Some(current) => if num < current { min = Some(num) }
          None => min = Some(num)
        }
      Err(err) => has_error = Some(err)
    }
  }
  match has_error {
    Some(err) => err
    None =>
      match min {
        Some(value) => FormulaValue::Number(value)
        None => FormulaValue::Error(formula_error_value)
      }
  }
}

///|
fn max_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut max = None
  let mut has_error = None
  for value in flatten_values(values) {
    match value_as_number(value) {
      Ok(num) =>
        match max {
          Some(current) => if num > current { max = Some(num) }
          None => max = Some(num)
        }
      Err(err) => has_error = Some(err)
    }
  }
  match has_error {
    Some(err) => err
    None =>
      match max {
        Some(value) => FormulaValue::Number(value)
        None => FormulaValue::Error(formula_error_value)
      }
  }
}

///|
fn count_values(values : ArrayView[FormulaValue]) -> FormulaValue {
  let mut count = 0
  let mut has_error = None
  for value in flatten_values(values) {
    match value_as_number(value) {
      Ok(_) => count = count + 1
      Err(err) => has_error = Some(err)
    }
  }
  match has_error {
    Some(err) => err
    None => FormulaValue::Number(Double::from_int(count))
  }
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
fn formula_value_truthy(value : FormulaValue) -> Bool {
  match normalize_scalar(value) {
    FormulaValue::Bool(flag) => flag
    FormulaValue::Number(num) => num != 0.0
    FormulaValue::String(text) => text != ""
    FormulaValue::Empty => false
    FormulaValue::Error(_) => false
    FormulaValue::List(_) => false
  }
}

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
  out
}
