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
