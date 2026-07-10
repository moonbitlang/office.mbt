///|
pub(all) struct AutoFilterOption {
  column : String
  expression : String
} derive(Debug)

///|
pub type AutoFilterOptions = AutoFilterOption

///|
pub struct AutoFilterCustomFilter {
  operator : String
  value : String
} derive(Debug)

///|
pub struct AutoFilterCustomFilters {
  and_filter : Bool
  filters : Array[AutoFilterCustomFilter]
} derive(Debug)

///|
pub struct AutoFilterColumn {
  col : Int
  filters : Array[String]?
  custom_filters : AutoFilterCustomFilters?
} derive(Debug)

///|
pub struct AutoFilter {
  range_ref : String
  columns : Array[AutoFilterColumn]
} derive(Debug)

///|
fn is_whitespace(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' => true
    _ => false
  }
}

///|
fn tokenize_filter_expression(expression : StringView) -> Array[String] {
  let tokens : Array[String] = []
  let chars = expression.to_array()
  let mut current = StringBuilder::new()
  let mut has_content = false
  let mut in_quotes = false
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if in_quotes {
      current.write_char(ch)
      has_content = true
      if ch == '"' {
        if i + 1 < chars.length() && chars[i + 1] == '"' {
          current.write_char('"')
          i = i + 1
        } else {
          in_quotes = false
        }
      }
      i = i + 1
      continue
    }
    if is_whitespace(ch) {
      if has_content {
        tokens.push(current.to_string())
        current = StringBuilder::new()
        has_content = false
      }
      i = i + 1
      continue
    }
    if ch == '"' {
      in_quotes = true
      current.write_char(ch)
      has_content = true
      i = i + 1
      continue
    }
    current.write_char(ch)
    has_content = true
    i = i + 1
  }
  if has_content {
    tokens.push(current.to_string())
  }
  tokens
}

///|
fn parse_filter_tokens(
  tokens : ArrayView[String],
) -> (Int, String) raise XlsxError {
  if tokens.length() != 3 {
    raise InvalidAutoFilter(msg="auto filter expression invalid")
  }
  let op_text = tokens[1].to_lower()
  let operator = match op_text {
    "==" | "=" | "=~" | "eq" => 2
    "!=" | "!~" | "ne" | "<>" => 5
    "<" => 1
    "<=" => 3
    ">" => 4
    ">=" => 6
    _ => raise InvalidAutoFilter(msg="auto filter operator invalid")
  }
  let mut op_value = operator
  let mut token = tokens[2]
  let lower_token = token.to_lower()
  if lower_token == "blanks" || lower_token == "nonblanks" {
    if op_value != 2 && op_value != 5 {
      raise InvalidAutoFilter(msg="auto filter operator invalid")
    }
    token = lower_token
    if token == "blanks" {
      if op_value == 5 {
        token = " "
      }
    } else if op_value == 5 {
      op_value = 2
      token = "blanks"
    } else {
      op_value = 5
      token = " "
    }
  }
  if op_value == 2 && (token.contains("*") || token.contains("?")) {
    op_value = 22
  }
  (op_value, token)
}

///|
fn parse_filter_expression(
  tokens : ArrayView[String],
) -> (Array[Int], Array[String]) raise XlsxError {
  if tokens.length() == 7 {
    let cond = tokens[3].to_lower()
    let conditional = if cond == "or" || tokens[3] == "||" { 1 } else { 0 }
    let (op1, token1) = parse_filter_tokens(tokens[:3])
    let (op2, token2) = parse_filter_tokens(tokens[4:7])
    ([op1, conditional, op2], [token1, token2])
  } else if tokens.length() == 3 {
    let (op, token) = parse_filter_tokens(tokens)
    ([op], [token])
  } else {
    raise InvalidAutoFilter(msg="auto filter expression invalid")
  }
}

///|
fn custom_filter_operator(op : Int) -> String raise XlsxError {
  match op {
    1 => "lessThan"
    2 => "equal"
    3 => "lessThanOrEqual"
    4 => "greaterThan"
    5 => "notEqual"
    6 => "greaterThanOrEqual"
    22 => "equal"
    _ => raise InvalidAutoFilter(msg="auto filter operator invalid")
  }
}

///|
fn auto_filter_column_from_expression(
  col : Int,
  expression : StringView,
) -> AutoFilterColumn raise XlsxError {
  let tokens = tokenize_filter_expression(expression)
  let (ops, values) = parse_filter_expression(tokens)
  if ops.length() == 1 && ops[0] == 2 {
    return { col, filters: Some(values), custom_filters: None }
  }
  if ops.length() == 3 && ops[0] == 2 && ops[1] == 1 && ops[2] == 2 {
    return { col, filters: Some(values), custom_filters: None }
  }
  let custom_filters : Array[AutoFilterCustomFilter] = []
  if ops.length() == 1 {
    let operator = custom_filter_operator(ops[0])
    custom_filters.push({ operator, value: values[0] })
  } else {
    let operator1 = custom_filter_operator(ops[0])
    let operator2 = custom_filter_operator(ops[2])
    custom_filters.push({ operator: operator1, value: values[0] })
    custom_filters.push({ operator: operator2, value: values[1] })
  }
  let and_value = ops.length() == 3 && ops[1] == 0
  {
    col,
    filters: None,
    custom_filters: Some({ and_filter: and_value, filters: custom_filters }),
  }
}

///|

///|
fn auto_filter_from_options(
  range_ref : String,
  options : ArrayView[AutoFilterOption],
) -> AutoFilter raise XlsxError {
  let normalized = normalize_range_ref(range_ref)
  let (_min_row, min_col, _max_row, max_col) = parse_range_ref(normalized)
  let columns : Array[AutoFilterColumn] = []
  for opt in options {
    if opt.column == "" || opt.expression == "" {
      continue
    }
    let col = column_name_to_number(opt.column) catch {
      _ => raise InvalidAutoFilter(msg="auto filter column invalid")
    }
    if col < min_col || col > max_col {
      raise InvalidAutoFilter(msg="auto filter column out of range")
    }
    let column = auto_filter_column_from_expression(col, opt.expression)
    let mut replaced = false
    for i, existing in columns {
      if existing.col == column.col {
        columns[i] = column
        replaced = true
        break
      }
    }
    if !replaced {
      columns.push(column)
    }
  }
  { range_ref: normalized, columns }
}

///|
fn clone_auto_filter(filter : AutoFilter) -> AutoFilter {
  let columns : Array[AutoFilterColumn] = []
  for column in filter.columns {
    let filters = match column.filters {
      Some(values) => {
        let copied : Array[String] = []
        for value in values {
          copied.push(value)
        }
        Some(copied)
      }
      None => None
    }
    let custom_filters = match column.custom_filters {
      Some(custom) => {
        let copied_filters : Array[AutoFilterCustomFilter] = []
        for entry in custom.filters {
          copied_filters.push({ operator: entry.operator, value: entry.value })
        }
        Some({ and_filter: custom.and_filter, filters: copied_filters })
      }
      None => None
    }
    columns.push({ col: column.col, filters, custom_filters })
  }
  { range_ref: filter.range_ref, columns }
}
