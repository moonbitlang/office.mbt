///|
/// The header-cell comparison must reject a replay that replaced a header
/// FORMULA with a literal of the same display text — the case where table
/// creation synthesizes a name equal to the cached value (constructible
/// from files, where a stored table can retain formula headers).
test "formula headers replaced by equal-text literals are not faithful" {
  // source: B1 is a formula (the reader keeps it for file-read tables)
  let source = @xlsx.Workbook::new()
  ignore(source.add_sheet("Data"))
  source.set_cell("Data", "A1", "Region")
  source.set_cell_formula(
    "Data",
    "B1",
    "CONCAT(\"Col\",\"umn2\")",
    value="Column2",
  )
  // replayed: B1 is a plain literal with the same text
  let replayed = @xlsx.Workbook::new()
  ignore(replayed.add_sheet("Data"))
  replayed.set_cell("Data", "A1", "Region")
  replayed.set_cell("Data", "B1", "Column2")
  // give both the same table so only the header formula differs
  fn add(workbook : @xlsx.Workbook) -> @xlsx.Table raise {
    let opts = @xlsx.TableOptions::new("A1:B2")
    opts.set_name("T")
    workbook.add_table("Data", opts)
  }
  let source_table = add(source)
  ignore(add(replayed))
  let candidate : TableCandidate = {
    op_index: 0,
    sheet: "Data",
    payload: TableObject(source_table),
  }
  // add_table normalizes the source header too; force the formula back to
  // simulate a file-read table that retained it
  source.set_cell_formula(
    "Data",
    "B1",
    "CONCAT(\"Col\",\"umn2\")",
    value="Column2",
  )
  assert_false(
    object_replayed_faithfully(source, replayed, candidate, [candidate]),
  )
  // and with matching formulas on both sides it IS faithful
  replayed.set_cell_formula(
    "Data",
    "B1",
    "CONCAT(\"Col\",\"umn2\")",
    value="Column2",
  )
  assert_true(
    object_replayed_faithfully(source, replayed, candidate, [candidate]),
  )
}
