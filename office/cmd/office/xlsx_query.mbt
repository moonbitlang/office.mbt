///|
let xlsx_cli_max_query_selector_chars : Int = 4096

///|
let xlsx_cli_max_query_predicates : Int = 16

///|
let xlsx_cli_max_query_value_chars : Int = 1024

///|
enum XlsxCellKind {
  Formula
  Number
  StringValue
  Boolean
  ErrorValue
}

///|
enum XlsxNumberOperator {
  Greater
  GreaterOrEqual
  Less
  LessOrEqual
  Equal
  NotEqual
}

///|
enum XlsxCellPredicate {
  HasType(XlsxCellKind)
  ValueCompare(XlsxNumberOperator, Double)
  HasFormula
  FormulaContains(String)
  TextEquals(String)
  TextContains(String)
}

///|
enum PreparedXlsxCellPredicate {
  PreparedHasType(XlsxCellKind)
  PreparedValueCompare(XlsxNumberOperator, Double)
  PreparedHasFormula
  PreparedFormulaContains(OfficeLinearPattern)
  PreparedTextEquals(String)
  PreparedTextContains(OfficeLinearPattern)
}

///|
struct XlsxQuerySpec {
  selector : String
  predicates : Array[XlsxCellPredicate]
  offset : Int
  limit : Int
}

///|
fn xlsx_query_failure(message : String, selector : String) -> CliFailure {
  xlsx_cli_failure(
    "office.xlsx.invalid_query",
    message,
    details=Json::object({
      "selector": Json::string(bounded_text(selector, 240)),
    }),
  )
}

///|
fn require_xlsx_query_number_value(
  label : String,
  value : String,
  selector : String,
) -> String raise CliFailure {
  let trimmed = value.trim().to_owned()
  if trimmed == "" {
    raise xlsx_query_failure("\{label} needs a non-empty value", selector)
  }
  if !has_at_most_chars(trimmed, xlsx_cli_max_query_value_chars) {
    raise xlsx_query_failure(
      "\{label} value exceeds \{xlsx_cli_max_query_value_chars} characters",
      selector,
    )
  }
  trimmed
}

///|
fn xlsx_query_quoted_literal_end(value : String) -> Int? {
  let mut escaped = false
  let mut index = 1
  while index < value.length() {
    let character = value[index]
    if escaped {
      escaped = false
    } else if character == ('\\' : UInt16) {
      escaped = true
    } else if character == ('"' : UInt16) {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn xlsx_query_literal_has_valid_unicode(value : String) -> Bool {
  let mut offset = 0
  while offset < value.length() {
    let unit = value[offset]
    if unit.is_leading_surrogate() {
      if offset + 1 >= value.length() ||
        !value[offset + 1].is_trailing_surrogate() {
        return false
      }
      offset += 2
    } else if unit.is_trailing_surrogate() {
      return false
    } else {
      offset += 1
    }
  }
  true
}

///|
fn require_xlsx_query_literal(
  label : String,
  value : String,
  selector : String,
) -> String raise CliFailure {
  let decoded = if value.has_prefix("\"") {
    guard xlsx_query_quoted_literal_end(value) is Some(close) &&
      close == value.length() - 1 else {
      raise xlsx_query_failure(
        "\{label} quoted value must be one complete JSON string",
        selector,
      )
    }
    let parsed = @json.parse(value) catch {
      _ =>
        raise xlsx_query_failure(
          "\{label} quoted value contains an invalid JSON string escape",
          selector,
        )
    }
    guard parsed is String(text) else {
      raise xlsx_query_failure(
        "\{label} quoted value must be a JSON string",
        selector,
      )
    }
    text
  } else {
    value
  }
  if decoded == "" {
    raise xlsx_query_failure("\{label} needs a non-empty value", selector)
  }
  if !xlsx_query_literal_has_valid_unicode(decoded) {
    raise xlsx_query_failure(
      "\{label} value contains an isolated UTF-16 surrogate",
      selector,
    )
  }
  if !has_at_most_chars(decoded, xlsx_cli_max_query_value_chars) {
    raise xlsx_query_failure(
      "\{label} value exceeds \{xlsx_cli_max_query_value_chars} characters",
      selector,
    )
  }
  decoded
}

///|
fn parse_xlsx_number_predicate(
  rest : String,
  selector : String,
) -> XlsxCellPredicate raise CliFailure {
  let (operator, number_text) = if rest.has_prefix(">=") {
    (GreaterOrEqual, rest[2:].to_owned())
  } else if rest.has_prefix("<=") {
    (LessOrEqual, rest[2:].to_owned())
  } else if rest.has_prefix("!=") {
    (NotEqual, rest[2:].to_owned())
  } else if rest.has_prefix(">") {
    (Greater, rest[1:].to_owned())
  } else if rest.has_prefix("<") {
    (Less, rest[1:].to_owned())
  } else if rest.has_prefix("=") {
    (Equal, rest[1:].to_owned())
  } else {
    raise xlsx_query_failure(
      "a value predicate requires one of >, >=, <, <=, =, or !=", selector,
    )
  }
  let bounded = require_xlsx_query_number_value(
    "value comparison", number_text, selector,
  )
  let number = @string.parse_double(bounded) catch {
    _ =>
      raise xlsx_query_failure(
        "value predicate expects a finite number", selector,
      )
  }
  if number != number || number.is_inf() {
    raise xlsx_query_failure(
      "value predicate expects a finite number", selector,
    )
  }
  ValueCompare(operator, number)
}

///|
fn parse_xlsx_predicate(
  body : String,
  selector : String,
) -> XlsxCellPredicate raise CliFailure {
  let predicate = body
  if predicate.has_prefix("type=") {
    match predicate[5:].to_owned() {
      "formula" => HasType(Formula)
      "number" => HasType(Number)
      "string" => HasType(StringValue)
      "bool" => HasType(Boolean)
      "error" => HasType(ErrorValue)
      _ =>
        raise xlsx_query_failure(
          "type predicate expects formula, number, string, bool, or error", selector,
        )
    }
  } else if predicate.has_prefix("value") {
    parse_xlsx_number_predicate(predicate[5:].to_owned(), selector)
  } else if predicate.has_prefix("formula~=") {
    FormulaContains(
      require_xlsx_query_literal(
        "formula~=",
        predicate[9:].to_owned(),
        selector,
      ),
    )
  } else if predicate == "formula" {
    HasFormula
  } else if predicate.has_prefix("text~=") {
    TextContains(
      require_xlsx_query_literal("text~=", predicate[6:].to_owned(), selector),
    )
  } else if predicate.has_prefix("text=") {
    TextEquals(
      require_xlsx_query_literal("text=", predicate[5:].to_owned(), selector),
    )
  } else {
    raise xlsx_query_failure("unknown XLSX cell predicate", selector)
  }
}

///|
/// Finds the terminator for one outer predicate group while permitting
/// balanced brackets in unquoted values and arbitrary brackets in JSON-string
/// values. The former supports normal Excel structured references such as
/// `Table1[[#Headers],[Amount]]`; the latter makes every exact string
/// representable without confusing it with selector structure.
fn xlsx_query_predicate_close(
  rest : String,
  selector : String,
) -> Int raise CliFailure {
  let mut depth = 0
  let mut index = 0
  let mut in_string = false
  let mut escaped = false
  while index < rest.length() {
    let character = rest[index]
    if in_string {
      if escaped {
        escaped = false
      } else if character == ('\\' : UInt16) {
        escaped = true
      } else if character == ('"' : UInt16) {
        in_string = false
      }
    } else if character == ('"' : UInt16) {
      in_string = true
    } else if character == ('[' : UInt16) {
      depth += 1
    } else if character == (']' : UInt16) {
      depth -= 1
      if depth == 0 {
        return index
      }
      if depth < 0 {
        break
      }
    }
    index += 1
  }
  raise xlsx_query_failure("query selector is missing a closing ']'", selector)
}

///|
fn parse_xlsx_query_selector(
  source : String,
) -> Array[XlsxCellPredicate] raise CliFailure {
  if !has_at_most_chars(source, xlsx_cli_max_query_selector_chars) {
    raise xlsx_query_failure(
      "query selector exceeds \{xlsx_cli_max_query_selector_chars} characters",
      source,
    )
  }
  let selector = source.trim().to_owned()
  if selector != "cell" && !selector.has_prefix("cell[") {
    raise xlsx_query_failure(
      "selector must be 'cell' followed by optional [predicate] groups", selector,
    )
  }
  let predicates : Array[XlsxCellPredicate] = []
  let mut rest = selector[4:].to_owned()
  while rest != "" {
    if predicates.length() >= xlsx_cli_max_query_predicates {
      raise xlsx_cli_failure(
        "office.xlsx.query_predicate_limit",
        "at most \{xlsx_cli_max_query_predicates} XLSX query predicates are allowed",
        details=Json::object({
          "limit": Json::number(xlsx_cli_max_query_predicates.to_double()),
        }),
      )
    }
    if !rest.has_prefix("[") {
      raise xlsx_query_failure("expected '[' in query selector", selector)
    }
    let close = xlsx_query_predicate_close(rest, selector)
    predicates.push(parse_xlsx_predicate(rest[1:close].to_owned(), selector))
    rest = rest[close + 1:].to_owned()
  }
  predicates
}

///|
fn XlsxNumberOperator::matches(
  self : XlsxNumberOperator,
  value : Double,
  bound : Double,
) -> Bool {
  match self {
    Greater => value > bound
    GreaterOrEqual => value >= bound
    Less => value < bound
    LessOrEqual => value <= bound
    Equal => value == bound
    NotEqual => value != bound
  }
}

///|
fn XlsxCellPredicate::prepare(
  self : XlsxCellPredicate,
  work : OfficeQueryWorkBudget,
) -> PreparedXlsxCellPredicate raise CliFailure {
  match self {
    HasType(kind) => PreparedHasType(kind)
    ValueCompare(operator, bound) => PreparedValueCompare(operator, bound)
    HasFormula => PreparedHasFormula
    FormulaContains(needle) =>
      PreparedFormulaContains(OfficeLinearPattern::compile(needle, false, work))
    TextEquals(expected) => PreparedTextEquals(expected)
    TextContains(needle) =>
      PreparedTextContains(OfficeLinearPattern::compile(needle, false, work))
  }
}

///|
fn prepare_xlsx_query_predicates(
  predicates : Array[XlsxCellPredicate],
  work : OfficeQueryWorkBudget,
) -> Array[PreparedXlsxCellPredicate] raise CliFailure {
  predicates.map(predicate => predicate.prepare(work))
}

///|
async fn PreparedXlsxCellPredicate::matches(
  self : PreparedXlsxCellPredicate,
  cell : XlsxCellSnapshot,
  work : OfficeQueryWorkBudget,
) -> Bool {
  match self {
    PreparedHasType(kind) => {
      work.charge(1)
      match kind {
        Formula => cell.formula is Some(_)
        Number => cell.raw is Some(Numeric(_))
        StringValue => cell.raw is Some(String(_))
        Boolean => cell.raw is Some(Bool(_))
        ErrorValue => cell.raw is Some(Error(_))
      }
    }
    PreparedValueCompare(operator, bound) => {
      work.charge(1)
      match cell.raw {
        Some(Numeric(value)) => operator.matches(value, bound)
        _ => false
      }
    }
    PreparedHasFormula => {
      work.charge(1)
      cell.formula is Some(_)
    }
    PreparedFormulaContains(pattern) =>
      match cell.formula {
        Some(formula) => pattern.is_in_cooperative(formula, work)
        None => {
          work.charge(1)
          false
        }
      }
    PreparedTextEquals(expected) =>
      match cell.raw {
        Some(String(value)) =>
          query_strings_equal_cooperative(value, expected, work)
        _ => {
          work.charge(1)
          false
        }
      }
    PreparedTextContains(pattern) =>
      match cell.raw {
        Some(String(value)) => pattern.is_in_cooperative(value, work)
        _ => {
          work.charge(1)
          false
        }
      }
  }
}

///|
async fn xlsx_cell_matches(
  cell : XlsxCellSnapshot,
  predicates : Array[PreparedXlsxCellPredicate],
  work : OfficeQueryWorkBudget,
) -> Bool {
  work.charge(1)
  if !cell.is_present() {
    return false
  }
  for predicate in predicates {
    if !predicate.matches(cell, work) {
      return false
    }
  }
  true
}
