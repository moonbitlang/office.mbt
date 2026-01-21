///|
pub(all) enum CellValueType {
  String
  Number
  Bool
  Error
} derive(Eq, Show)

///|
pub(all) enum CellValue {
  String(String)
  Numeric(Double)
  Bool(Bool)
  Error(String)
} derive(Eq, Show)

///|
fn cell_value_type(value : CellValue) -> CellValueType {
  match value {
    CellValue::String(_) => CellValueType::String
    CellValue::Numeric(_) => CellValueType::Number
    CellValue::Bool(_) => CellValueType::Bool
    CellValue::Error(_) => CellValueType::Error
  }
}

///|
fn cell_value_raw_string(value : CellValue) -> String {
  match value {
    CellValue::String(text) => text
    CellValue::Numeric(value) => value.to_string()
    CellValue::Bool(value) => if value { "1" } else { "0" }
    CellValue::Error(text) => text
  }
}

///|
fn parse_cell_bool(value : StringView) -> Bool {
  match value.to_string().to_lower() {
    "1" => true
    "true" => true
    "yes" => true
    _ => false
  }
}

///|
fn cell_value_from_raw(
  value_type : CellValueType,
  raw : String,
) -> CellValue raise XlsxError {
  match value_type {
    CellValueType::String => CellValue::String(raw)
    CellValueType::Number =>
      CellValue::Numeric(
        @strconv.parse_double(raw) catch {
          _ => raise XlsxError::InvalidXml(msg="cell number invalid")
        },
      )
    CellValueType::Bool => CellValue::Bool(parse_cell_bool(raw))
    CellValueType::Error => CellValue::Error(raw)
  }
}
