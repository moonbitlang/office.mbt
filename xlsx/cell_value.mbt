///|
pub(all) enum CellValueType {
  String
  Number
  Bool
  Error
} derive(Eq, Show)

///|
pub type CellType = CellValueType

///|
pub(all) enum CellValue {
  String(String)
  Numeric(Double)
  Bool(Bool)
  Error(String)
} derive(Show)

///|
fn cell_value_type(value : CellValue) -> CellValueType {
  match value {
    String(_) => String
    Numeric(_) => Number
    Bool(_) => Bool
    Error(_) => Error
  }
}

///|
fn cell_value_raw_string(value : CellValue) -> String {
  match value {
    String(text) => text
    Numeric(value) => value.to_string()
    Bool(value) => if value { "1" } else { "0" }
    Error(text) => text
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
    String => String(raw)
    Number =>
      Numeric(
        @strconv.parse_double(raw) catch {
          _ => raise InvalidXml(msg="cell number invalid")
        },
      )
    Bool => Bool(parse_cell_bool(raw))
    Error => Error(raw)
  }
}
