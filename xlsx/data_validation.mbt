///|
pub(all) enum DataValidationType {
  NoneType
  Custom
  Date
  Decimal
  List
  TextLength
  Time
  Whole
} derive(Show)

///|
pub(all) enum DataValidationErrorStyle {
  Stop
  Warning
  Information
} derive(Show)

///|
pub(all) enum DataValidationOperator {
  Between
  Equal
  GreaterThan
  GreaterThanOrEqual
  LessThan
  LessThanOrEqual
  NotBetween
  NotEqual
} derive(Show)

///|
pub(all) enum DataValidationFormula {
  IntValue(Int)
  DoubleValue(Double)
  TextValue(String)
} derive(Show)

///|
pub struct DataValidation {
  allow_blank : Bool
  mut error : String?
  mut error_style : String?
  mut error_title : String?
  mut operator : String
  mut prompt : String?
  mut prompt_title : String?
  mut show_drop_down : Bool
  mut show_error_message : Bool
  mut show_input_message : Bool
  mut sqref : String
  mut validation_type : String
  mut formula1 : String
  mut formula2 : String
} derive(Show)

///|
fn data_validation_type_text(value : DataValidationType) -> String {
  match value {
    NoneType => "none"
    Custom => "custom"
    Date => "date"
    Decimal => "decimal"
    List => "list"
    TextLength => "textLength"
    Time => "time"
    Whole => "whole"
  }
}

///|
fn data_validation_error_style_text(value : DataValidationErrorStyle) -> String {
  match value {
    Stop => "stop"
    Warning => "warning"
    Information => "information"
  }
}

///|
fn data_validation_operator_text(value : DataValidationOperator) -> String {
  match value {
    Between => "between"
    Equal => "equal"
    GreaterThan => "greaterThan"
    GreaterThanOrEqual => "greaterThanOrEqual"
    LessThan => "lessThan"
    LessThanOrEqual => "lessThanOrEqual"
    NotBetween => "notBetween"
    NotEqual => "notEqual"
  }
}

///|
fn data_validation_abs_double(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn data_validation_formula_text(
  value : DataValidationFormula,
) -> String raise XlsxError {
  let max_float32 = 3.4028234663852886e38
  match value {
    IntValue(v) => v.to_string()
    DoubleValue(v) =>
      if data_validation_abs_double(v) > max_float32 {
        raise InvalidDataValidation(msg="data validation range exceeds limit")
      } else {
        v.to_string()
      }
    TextValue(v) => v
  }
}

///|
fn escape_data_validation_formula(value : StringView) -> String {
  escape_xml_text(value)
}

///|
fn unescape_data_validation_formula(value : StringView) -> String {
  let text = unescape_xml_text(value)
  if text.has_prefix("\"") {
    text.replace_all(old="\"\"", new="\"")
  } else {
    text
  }
}

///|
pub fn DataValidation::new(allow_blank : Bool) -> DataValidation {
  {
    allow_blank,
    error: None,
    error_style: None,
    error_title: None,
    operator: "",
    prompt: None,
    prompt_title: None,
    show_drop_down: false,
    show_error_message: false,
    show_input_message: false,
    sqref: "",
    validation_type: "",
    formula1: "",
    formula2: "",
  }
}

///|
pub fn DataValidation::set_error(
  self : DataValidation,
  style : DataValidationErrorStyle,
  title : String,
  msg : String,
) -> Unit {
  self.error = Some(msg)
  self.error_title = Some(title)
  self.error_style = Some(data_validation_error_style_text(style))
  self.show_error_message = true
}

///|
pub fn DataValidation::set_input(
  self : DataValidation,
  title : String,
  msg : String,
) -> Unit {
  self.show_input_message = true
  self.prompt_title = Some(title)
  self.prompt = Some(msg)
}

///|
pub fn DataValidation::set_drop_list(
  self : DataValidation,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  let sb = StringBuilder::new()
  for i, value in values {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_view(value)
  }
  let formula = sb.to_string()
  if count_utf16_units(formula) > max_field_length {
    raise InvalidDataValidation(msg="data validation must be 0-255 characters")
  }
  self.validation_type = data_validation_type_text(List)
  if formula.has_prefix("=") {
    self.formula1 = escape_data_validation_formula(formula)
    return
  }
  let escaped = escape_data_validation_formula(formula).replace_all(
    old="\"",
    new="\"\"",
  )
  self.formula1 = "\"\{escaped}\""
}

///|
pub fn DataValidation::set_range(
  self : DataValidation,
  formula1 : DataValidationFormula,
  formula2 : DataValidationFormula,
  validation_type : DataValidationType,
  op : DataValidationOperator,
) -> Unit raise XlsxError {
  self.formula1 = data_validation_formula_text(formula1)
  self.formula2 = data_validation_formula_text(formula2)
  self.validation_type = data_validation_type_text(validation_type)
  self.operator = data_validation_operator_text(op)
}

///|
pub fn DataValidation::set_sqref_drop_list(
  self : DataValidation,
  sqref : String,
) -> Unit {
  self.formula1 = sqref
  self.validation_type = data_validation_type_text(List)
}

///|
pub fn DataValidation::set_sqref(self : DataValidation, sqref : String) -> Unit {
  if self.sqref == "" {
    self.sqref = sqref
  } else {
    self.sqref = "\{self.sqref} \{sqref}"
  }
}

///|
fn data_validation_bool_attr(value : Bool) -> String {
  if value {
    "1"
  } else {
    "0"
  }
}

///|
fn data_validation_xml(dv : DataValidation) -> String raise XlsxError {
  if dv.sqref == "" {
    raise InvalidDataValidation(msg="data validation sqref empty")
  }
  let sb = StringBuilder::new()
  sb.write_view("<dataValidation")
  sb.write_view(" allowBlank=\"\{data_validation_bool_attr(dv.allow_blank)}\"")
  match dv.error {
    Some(value) => {
      sb.write_view(" error=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"")
    }
    None => ()
  }
  match dv.error_style {
    Some(value) => {
      sb.write_view(" errorStyle=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"")
    }
    None => ()
  }
  match dv.error_title {
    Some(value) => {
      sb.write_view(" errorTitle=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"")
    }
    None => ()
  }
  if dv.operator != "" {
    sb.write_view(" operator=\"")
    sb.write_view(escape_xml_attr(dv.operator))
    sb.write_view("\"")
  }
  match dv.prompt {
    Some(value) => {
      sb.write_view(" prompt=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"")
    }
    None => ()
  }
  match dv.prompt_title {
    Some(value) => {
      sb.write_view(" promptTitle=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"")
    }
    None => ()
  }
  if dv.show_drop_down {
    sb.write_view(" showDropDown=\"1\"")
  }
  if dv.show_error_message {
    sb.write_view(" showErrorMessage=\"1\"")
  }
  if dv.show_input_message {
    sb.write_view(" showInputMessage=\"1\"")
  }
  sb.write_view(" sqref=\"")
  sb.write_view(escape_xml_attr(dv.sqref))
  sb.write_view("\"")
  if dv.validation_type != "" {
    sb.write_view(" type=\"")
    sb.write_view(escape_xml_attr(dv.validation_type))
    sb.write_view("\"")
  }
  sb.write_view(">")
  if dv.formula1 != "" {
    sb.write_view("<formula1>")
    sb.write_view(escape_data_validation_formula(dv.formula1))
    sb.write_view("</formula1>")
  }
  if dv.formula2 != "" {
    sb.write_view("<formula2>")
    sb.write_view(escape_data_validation_formula(dv.formula2))
    sb.write_view("</formula2>")
  }
  sb.write_view("</dataValidation>")
  sb.to_string()
}

///|
fn parse_xml_bool(text : StringView) -> Bool {
  match text.to_owned().to_lower() {
    "1" | "true" => true
    _ => false
  }
}

///|
fn data_validation_from_xml(xml : StringView) -> DataValidation raise XlsxError {
  let tag = match tag_attributes_in(xml, "dataValidation") {
    Some(value) => value
    None => raise InvalidXml(msg="data validation tag missing")
  }
  let allow_blank = match attr_value(tag, "allowBlank") {
    Some(value) => parse_xml_bool(value)
    None => false
  }
  let dv = DataValidation::new(allow_blank)
  match attr_value(tag, "error") {
    Some(value) => dv.error = Some(unescape_xml_text(value))
    None => ()
  }
  match attr_value(tag, "errorStyle") {
    Some(value) => dv.error_style = Some(unescape_xml_text(value))
    None => ()
  }
  match attr_value(tag, "errorTitle") {
    Some(value) => dv.error_title = Some(unescape_xml_text(value))
    None => ()
  }
  match attr_value(tag, "operator") {
    Some(value) => dv.operator = unescape_xml_text(value)
    None => ()
  }
  match attr_value(tag, "prompt") {
    Some(value) => dv.prompt = Some(unescape_xml_text(value))
    None => ()
  }
  match attr_value(tag, "promptTitle") {
    Some(value) => dv.prompt_title = Some(unescape_xml_text(value))
    None => ()
  }
  match attr_value(tag, "showDropDown") {
    Some(value) => dv.show_drop_down = parse_xml_bool(value)
    None => ()
  }
  match attr_value(tag, "showErrorMessage") {
    Some(value) => dv.show_error_message = parse_xml_bool(value)
    None => ()
  }
  match attr_value(tag, "showInputMessage") {
    Some(value) => dv.show_input_message = parse_xml_bool(value)
    None => ()
  }
  dv.sqref = match attr_value(tag, "sqref") {
    Some(value) => unescape_xml_text(value)
    None => raise InvalidXml(msg="data validation sqref missing")
  }
  match attr_value(tag, "type") {
    Some(value) => dv.validation_type = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body_from(xml, "formula1") {
    Some(value) => dv.formula1 = unescape_data_validation_formula(value)
    None => ()
  }
  match extract_tag_body_from(xml, "formula2") {
    Some(value) => dv.formula2 = unescape_data_validation_formula(value)
    None => ()
  }
  dv
}
