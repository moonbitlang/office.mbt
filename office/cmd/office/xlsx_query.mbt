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
fn require_xlsx_query_value(
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
  let bounded = require_xlsx_query_value(
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
  let predicate = body.trim().to_owned()
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
      require_xlsx_query_value("formula~=", predicate[9:].to_owned(), selector),
    )
  } else if predicate == "formula" {
    HasFormula
  } else if predicate.has_prefix("text~=") {
    TextContains(
      require_xlsx_query_value("text~=", predicate[6:].to_owned(), selector),
    )
  } else if predicate.has_prefix("text=") {
    TextEquals(
      require_xlsx_query_value("text=", predicate[5:].to_owned(), selector),
    )
  } else {
    raise xlsx_query_failure("unknown XLSX cell predicate", selector)
  }
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
    let close = match rest.find("]") {
      Some(index) => index
      None =>
        raise xlsx_query_failure(
          "query selector is missing a closing ']'", selector,
        )
    }
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
fn PreparedXlsxCellPredicate::matches(
  self : PreparedXlsxCellPredicate,
  cell : XlsxCellSnapshot,
  work : OfficeQueryWorkBudget,
) -> Bool raise CliFailure {
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
        Some(formula) => pattern.is_in(formula, work)
        None => {
          work.charge(1)
          false
        }
      }
    PreparedTextEquals(expected) =>
      match cell.raw {
        Some(String(value)) => {
          work.charge(value.length().min(expected.length()) + 1)
          value == expected
        }
        _ => {
          work.charge(1)
          false
        }
      }
    PreparedTextContains(pattern) =>
      match cell.raw {
        Some(String(value)) => pattern.is_in(value, work)
        _ => {
          work.charge(1)
          false
        }
      }
  }
}

///|
fn xlsx_cell_matches(
  cell : XlsxCellSnapshot,
  predicates : Array[PreparedXlsxCellPredicate],
  work : OfficeQueryWorkBudget,
) -> Bool raise CliFailure {
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
