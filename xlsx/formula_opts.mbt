///|
pub(all) enum FormulaType {
  Normal
  Array
  Shared
  DataTable
} derive(Debug)

///|
fn formula_type_to_ooxml(kind : FormulaType) -> String {
  match kind {
    Normal => "normal"
    Array => "array"
    Shared => "shared"
    DataTable => "dataTable"
  }
}

///|
fn formula_type_from_ooxml(value : StringView) -> FormulaType? {
  match value.to_owned() {
    "normal" => Some(Normal)
    "array" => Some(Array)
    "shared" => Some(Shared)
    "dataTable" => Some(DataTable)
    _ => None
  }
}

///|
pub struct FormulaOpts {
  mut formula_type : FormulaType?
  mut range_ref : String?
} derive(Debug)

///|
fn FormulaOpts::new() -> FormulaOpts {
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
  FormulaOpts::with_values(formula_type=Array, range_ref~)
}

///|
pub fn FormulaOpts::shared(range_ref : String) -> FormulaOpts {
  FormulaOpts::with_values(formula_type=Shared, range_ref~)
}

///|
test "formula opts wb: ooxml mapping covers normal and dataTable" {
  inspect(formula_type_to_ooxml(Normal), content="normal")
  inspect(formula_type_to_ooxml(DataTable), content="dataTable")
  debug_inspect(formula_type_from_ooxml("dataTable"), content="Some(DataTable)")
  debug_inspect(formula_type_from_ooxml("unknown"), content="None")
}

///|
test "formula opts wb: with_values none formula_type branch" {
  let opts = FormulaOpts::with_values()
  debug_inspect(opts.formula_type, content="None")
  debug_inspect(opts.range_ref, content="None")
}
