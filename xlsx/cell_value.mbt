///|
enum CellValueType {
  String
  Number
  Bool
  Error
} derive(Eq, Show, Debug)

///|
pub type CellType = CellValueType

///|
pub(all) enum CellValue {
  String(String)
  Numeric(Double)
  Bool(Bool)
  Error(String)
} derive(Show, Debug)

///|
fn cell_value_type(value : CellValue) -> CellValueType {
  match value {
    String(_) => String
    // NaN and infinities cannot be stored in a numeric <v> cell; Excelize
    // writes them as string cells instead.
    Numeric(value) =>
      if value.is_nan() || value.is_inf() {
        String
      } else {
        Number
      }
    Bool(_) => Bool
    Error(_) => Error
  }
}

///|
/// Renders a non-finite double the way Go's fmt.Sprint does, which is the
/// text Excelize stores for NaN/Inf cell values.
fn non_finite_to_string(value : Double) -> String {
  if value.is_nan() {
    "NaN"
  } else if value.is_pos_inf() {
    "+Inf"
  } else {
    "-Inf"
  }
}

///|
fn cell_value_raw_string(value : CellValue) -> String {
  match value {
    String(text) => text
    Numeric(value) =>
      if value.is_nan() || value.is_inf() {
        non_finite_to_string(value)
      } else {
        value.to_string()
      }
    Bool(value) => if value { "1" } else { "0" }
    Error(text) => text
  }
}

///|
fn parse_cell_bool(value : StringView) -> Bool {
  match value.to_owned().to_lower() {
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
        @string.parse_double(raw) catch {
          _ => raise InvalidXml(msg="cell number invalid")
        },
      )
    Bool => Bool(parse_cell_bool(raw))
    Error => Error(raw)
  }
}
