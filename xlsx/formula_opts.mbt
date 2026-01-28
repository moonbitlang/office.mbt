///|
pub(all) enum FormulaType {
  Normal
  Array
  Shared
  DataTable
} derive(Eq, Show)

///|
fn formula_type_to_ooxml(kind : FormulaType) -> String {
  match kind {
    FormulaType::Normal => "normal"
    FormulaType::Array => "array"
    FormulaType::Shared => "shared"
    FormulaType::DataTable => "dataTable"
  }
}

///|
fn formula_type_from_ooxml(value : StringView) -> FormulaType? {
  match value.to_string() {
    "normal" => Some(FormulaType::Normal)
    "array" => Some(FormulaType::Array)
    "shared" => Some(FormulaType::Shared)
    "dataTable" => Some(FormulaType::DataTable)
    _ => None
  }
}

///|
pub struct FormulaOpts {
  mut formula_type : FormulaType?
  mut range_ref : String?
} derive(Eq, Show)

///|
pub fn FormulaOpts::new() -> FormulaOpts {
  { formula_type: None, range_ref: None }
}

///|
pub fn FormulaOpts::with_values(
  formula_type? : FormulaType,
  range_ref? : String,
) -> FormulaOpts {
  let opts = FormulaOpts::new()
  match formula_type {
    Some(value) => opts.formula_type = Some(value)
    None => ()
  }
  match range_ref {
    Some(value) => opts.range_ref = Some(value)
    None => ()
  }
  opts
}

///|
pub fn FormulaOpts::array(range_ref : String) -> FormulaOpts {
  FormulaOpts::with_values(formula_type=FormulaType::Array, range_ref~)
}

///|
pub fn FormulaOpts::shared(range_ref : String) -> FormulaOpts {
  FormulaOpts::with_values(formula_type=FormulaType::Shared, range_ref~)
}
