///|
pub(all) struct AutoFilterOption {
  column : String
  expression : String
} derive(Debug)

///|
/// A checkbox-list criterion. Values are literal cell text, not expressions:
/// spaces, quotes, wildcards, and words such as "blanks" are preserved.
/// `column` is an absolute worksheet column name (for example "C").
pub(all) struct AutoFilterValuesOption {
  column : String
  values : Array[String]
} derive(Debug)

///|
#deprecated("implicit trait-method promotion is being removed; call via the trait")
pub extend AutoFilterValuesOption with @debug.Debug::{to_repr}

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
fn tokenize_filter_expression(
  expression : StringView,
) -> Array[String] raise XlsxError {
  let tokens : Array[String] = []
  let chars = expression.to_array()
  let mut current = StringBuilder()
  let mut has_content = false
  let mut in_quotes = false
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if in_quotes {
      if ch == '"' {
        if i + 1 < chars.length() && chars[i + 1] == '"' {
          current.write_char('"')
          i = i + 1
        } else {
          in_quotes = false
        }
      } else {
        current.write_char(ch)
        has_content = true
      }
      i = i + 1
      continue
    }
    if is_whitespace(ch) {
      if has_content {
        tokens.push(current.to_string())
        current = StringBuilder()
        has_content = false
      }
      i = i + 1
      continue
    }
    if ch == '"' {
      in_quotes = true
      has_content = true
      i = i + 1
      continue
    }
    current.write_char(ch)
    has_content = true
    i = i + 1
  }
  if in_quotes {
    raise InvalidAutoFilter(msg="auto filter expression unclosed quote")
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
  if tokens.length() < 3 || (tokens.length() + 1) % 4 != 0 {
    raise InvalidAutoFilter(msg="auto filter expression invalid")
  }
  let ops : Array[Int] = []
  let values : Array[String] = []
  for i = 0; i < tokens.length(); i = i + 4 {
    if i > 0 {
      let conditional = match tokens[i - 1].to_lower() {
        "or" | "||" => 1
        "and" | "&&" => 0
        _ => raise InvalidAutoFilter(msg="auto filter conjunction invalid")
      }
      ops.push(conditional)
    }
    let (op, value) = parse_filter_tokens(tokens[i:i + 3])
    ops.push(op)
    values.push(value)
  }
  (ops, values)
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
  let mut is_value_list = true
  for i, op in ops {
    if op != (if i % 2 == 0 { 2 } else { 1 }) {
      is_value_list = false
    }
  }
  if is_value_list {
    return { col, filters: Some(values), custom_filters: None, }
  }
  // SpreadsheetML customFilters can contain at most two comparisons.
  if values.length() > 2 {
    raise InvalidAutoFilter(
      msg="only equality OR chains support more than two values",
    )
  }
  let custom_filters : Array[AutoFilterCustomFilter] = []
  if ops.length() == 1 {
    let operator = custom_filter_operator(ops[0])
    custom_filters.push({ operator, value: values[0], })
  } else {
    let operator1 = custom_filter_operator(ops[0])
    let operator2 = custom_filter_operator(ops[2])
    custom_filters.push({ operator: operator1, value: values[0], })
    custom_filters.push({ operator: operator2, value: values[1], })
  }
  let and_value = ops.length() == 3 && ops[1] == 0
  {
    col,
    filters: None,
    custom_filters: Some({ and_filter: and_value, filters: custom_filters, }),
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
  { range_ref: normalized, columns, }
}

///|
fn auto_filter_from_values(
  range_ref : String,
  options : ArrayView[AutoFilterValuesOption],
) -> AutoFilter raise XlsxError {
  let normalized = normalize_range_ref(range_ref)
  let (_, min_col, _, max_col) = parse_range_ref(normalized)
  let columns : Array[AutoFilterColumn] = []
  for opt in options {
    let col = column_name_to_number(opt.column) catch {
      _ => raise InvalidAutoFilter(msg="auto filter column invalid")
    }
    if col < min_col || col > max_col {
      raise InvalidAutoFilter(msg="auto filter column out of range")
    }
    if opt.values.is_empty() {
      raise InvalidAutoFilter(msg="auto filter values must not be empty")
    }
    let column : AutoFilterColumn = {
      col,
      filters: Some(opt.values.copy()),
      custom_filters: None,
    }
    let mut replaced = false
    for i, existing in columns {
      if existing.col == col {
        columns[i] = column
        replaced = true
        break
      }
    }
    if !replaced {
      columns.push(column)
    }
  }
  { range_ref: normalized, columns, }
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
          copied_filters.push({ operator: entry.operator, value: entry.value, })
        }
        Some({ and_filter: custom.and_filter, filters: copied_filters, })
      }
      None => None
    }
    columns.push({ col: column.col, filters, custom_filters, })
  }
  { range_ref: filter.range_ref, columns, }
}

///|
test "auto filter wb: parse_filter_tokens rejects non-3 token input" {
  let bad_tokens : Result[(Int, String), Error] = Ok(
    parse_filter_tokens(["x", "=="]),
  ) catch {
    e => Err(e)
  }
  inspect(bad_tokens is Err(XlsxError::InvalidAutoFilter(_)), content="true")
}

///|
test "auto filter wb: custom_filter_operator equal and invalid branches" {
  inspect(custom_filter_operator(2), content="equal")
  let bad_op : Result[String, Error] = Ok(custom_filter_operator(99)) catch {
    e => Err(e)
  }
  inspect(bad_op is Err(XlsxError::InvalidAutoFilter(_)), content="true")
}
