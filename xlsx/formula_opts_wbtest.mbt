///|
test "formula opts wb: ooxml mapping covers normal and dataTable" {
  inspect(formula_type_to_ooxml(Normal), content="normal")
  inspect(formula_type_to_ooxml(DataTable), content="dataTable")
  inspect(formula_type_from_ooxml("dataTable"), content="Some(DataTable)")
  inspect(formula_type_from_ooxml("unknown"), content="None")
}

///|
test "formula opts wb: with_values none formula_type branch" {
  let opts = FormulaOpts::with_values()
  inspect(opts.formula_type, content="None")
  inspect(opts.range_ref, content="None")
}
