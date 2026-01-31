///|
pub(all) enum IgnoredErrorType {
  EvalError
  TwoDigitTextYear
  NumberStoredAsText
  Formula
  FormulaRange
  UnlockedFormula
  EmptyCellReference
  ListDataValidation
  CalculatedColumn
} derive(Eq, Show)

///|
pub struct IgnoredError {
  sqref : String
  eval_error : Bool
  two_digit_text_year : Bool
  number_stored_as_text : Bool
  formula : Bool
  formula_range : Bool
  unlocked_formula : Bool
  empty_cell_reference : Bool
  list_data_validation : Bool
  calculated_column : Bool
} derive(Eq, Show)

///|
fn ignored_error_from_type(
  sqref : String,
  error_type : IgnoredErrorType,
) -> IgnoredError {
  let eval_error = error_type == EvalError
  let two_digit_text_year = error_type == TwoDigitTextYear
  let number_stored_as_text = error_type == NumberStoredAsText
  let formula = error_type == Formula
  let formula_range = error_type == FormulaRange
  let unlocked_formula = error_type == UnlockedFormula
  let empty_cell_reference = error_type == EmptyCellReference
  let list_data_validation = error_type == ListDataValidation
  let calculated_column = error_type == CalculatedColumn
  {
    sqref,
    eval_error,
    two_digit_text_year,
    number_stored_as_text,
    formula,
    formula_range,
    unlocked_formula,
    empty_cell_reference,
    list_data_validation,
    calculated_column,
  }
}

///|
fn ignored_error_xml(error : IgnoredError) -> String raise XlsxError {
  if error.sqref == "" {
    raise InvalidSheetOperation(msg="ignored errors sqref empty")
  }
  let sb = StringBuilder::new()
  sb.write_view("<ignoredError sqref=\"")
  sb.write_view(escape_xml_attr(error.sqref))
  sb.write_view("\"")
  if error.eval_error {
    sb.write_view(" evalError=\"\{bool_attr(true)}\"")
  }
  if error.two_digit_text_year {
    sb.write_view(" twoDigitTextYear=\"\{bool_attr(true)}\"")
  }
  if error.number_stored_as_text {
    sb.write_view(" numberStoredAsText=\"\{bool_attr(true)}\"")
  }
  if error.formula {
    sb.write_view(" formula=\"\{bool_attr(true)}\"")
  }
  if error.formula_range {
    sb.write_view(" formulaRange=\"\{bool_attr(true)}\"")
  }
  if error.unlocked_formula {
    sb.write_view(" unlockedFormula=\"\{bool_attr(true)}\"")
  }
  if error.empty_cell_reference {
    sb.write_view(" emptyCellReference=\"\{bool_attr(true)}\"")
  }
  if error.list_data_validation {
    sb.write_view(" listDataValidation=\"\{bool_attr(true)}\"")
  }
  if error.calculated_column {
    sb.write_view(" calculatedColumn=\"\{bool_attr(true)}\"")
  }
  sb.write_view("/>")
  sb.to_string()
}

///|
fn write_ignored_errors_xml(
  errors : ArrayView[IgnoredError],
) -> String? raise XlsxError {
  if errors.length() == 0 {
    return None
  }
  let sb = StringBuilder::new()
  sb.write_view("  <ignoredErrors>\n")
  for error in errors {
    sb.write_view("    ")
    sb.write_view(ignored_error_xml(error))
    sb.write_view("\n")
  }
  sb.write_view("  </ignoredErrors>\n")
  Some(sb.to_string())
}

///|
fn parse_ignored_errors(
  xml : StringView,
) -> Array[IgnoredError] raise XlsxError {
  let body = match extract_tag_body(xml, "ignoredErrors") {
    Some(value) => value
    None => return []
  }
  let out : Array[IgnoredError] = []
  let mut first = true
  for chunk in body.split("<ignoredError ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise InvalidXml(msg="ignoredError tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise InvalidXml(msg="ignoredError tag invalid")
      }
    let sqref = match attr_value(tag, "sqref") {
      Some(value) => unescape_xml_text(value)
      None => raise InvalidXml(msg="ignoredError sqref missing")
    }
    let error : IgnoredError = {
      sqref,
      eval_error: match attr_value(tag, "evalError") {
        Some(value) => parse_bool_attr(value)
        None => false
      },
      two_digit_text_year: match attr_value(tag, "twoDigitTextYear") {
        Some(value) => parse_bool_attr(value)
        None => false
      },
      number_stored_as_text: match attr_value(tag, "numberStoredAsText") {
        Some(value) => parse_bool_attr(value)
        None => false
      },
      formula: match attr_value(tag, "formula") {
        Some(value) => parse_bool_attr(value)
        None => false
      },
      formula_range: match attr_value(tag, "formulaRange") {
        Some(value) => parse_bool_attr(value)
        None => false
      },
      unlocked_formula: match attr_value(tag, "unlockedFormula") {
        Some(value) => parse_bool_attr(value)
        None => false
      },
      empty_cell_reference: match attr_value(tag, "emptyCellReference") {
        Some(value) => parse_bool_attr(value)
        None => false
      },
      list_data_validation: match attr_value(tag, "listDataValidation") {
        Some(value) => parse_bool_attr(value)
        None => false
      },
      calculated_column: match attr_value(tag, "calculatedColumn") {
        Some(value) => parse_bool_attr(value)
        None => false
      },
    }
    out.push(error)
  }
  out
}
