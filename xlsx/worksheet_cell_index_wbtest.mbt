// White-box tests for the lazy worksheet cell index.

///|
fn raw_cell(reference : String, row : Int, col : Int, value : String) -> Cell {
  {
    reference,
    row,
    col,
    value,
    value_type: cell_value_type(CellValue::String(value)),
    rich_text: None,
    formula: None,
    formula_type: None,
    formula_ref: None,
    formula_shared_index: None,
    style_id: 0,
  }
}

///|
test "duplicate coordinates resolve to the first stored cell" {
  // A noncanonical file can carry two cells at the same coordinate. The
  // historical (pre-index) getters returned the first stored cell; the
  // index must preserve that, not silently switch to last-wins.
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("S")
  sheet.cells.push(raw_cell("A1", 1, 1, "first"))
  sheet.cells.push(raw_cell("A1", 1, 1, "second"))
  sheet.invalidate_cell_index()
  inspect(workbook.get_cell_value("S", "A1").unwrap_or(""), content="first")
  match workbook.get_cell_value_raw("S", "A1") {
    Some(String(text)) => inspect(text, content="first")
    other => fail("unexpected raw value: \{to_repr(other)}")
  }
}
