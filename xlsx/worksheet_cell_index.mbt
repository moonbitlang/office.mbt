///|
fn cell_index_key(row : Int, col : Int) -> String {
  "\{row}:\{col}"
}

///|
fn Worksheet::invalidate_cell_index(self : Worksheet) -> Unit {
  self.cell_index_valid = false
}

///|
fn populate_worksheet_cell_index(
  index : Map[String, Int],
  cells : Array[Cell],
) -> Unit {
  for i, cell in cells {
    let key = cell_index_key(cell.row, cell.col)
    // First occurrence wins: a noncanonical file can carry duplicate
    // coordinates, and the historical (pre-index) getters returned the
    // first stored cell.
    if !index.contains(key) {
      index[key] = i
    }
  }
}

///|
fn build_worksheet_cell_index(cells : Array[Cell]) -> Map[String, Int] {
  let index : Map[String, Int] = Map([])
  populate_worksheet_cell_index(index, cells)
  index
}

///|
fn build_bounded_worksheet_cell_index(
  cells : Array[Cell],
  budget : ReadBudget,
) -> Map[String, Int] raise XlsxError {
  // Index construction is part of workbook parsing, not deferred command
  // work. Charge it before allocating and retain cancellation checkpoints for
  // large but valid sheets.
  budget.charge_work(cells.length())
  let index : Map[String, Int] = Map([])
  for i, cell in cells {
    if i % 4096 == 0 {
      budget.checkpoint()
    }
    let key = cell_index_key(cell.row, cell.col)
    if !index.contains(key) {
      index[key] = i
    }
  }
  budget.checkpoint()
  index
}

///|
fn Worksheet::ensure_cell_index(self : Worksheet) -> Unit {
  if self.cell_index_valid {
    return
  }
  self.cell_index.clear()
  populate_worksheet_cell_index(self.cell_index, self.cells)
  self.cell_index_valid = true
}

///|
fn Worksheet::cell_index_of(self : Worksheet, row : Int, col : Int) -> Int? {
  self.ensure_cell_index()
  self.cell_index.get(cell_index_key(row, col))
}

///|
fn Worksheet::record_cell_index_if_valid(
  self : Worksheet,
  row : Int,
  col : Int,
  index : Int,
) -> Unit {
  if self.cell_index_valid {
    self.cell_index[cell_index_key(row, col)] = index
  }
}

// White-box tests for the lazy worksheet cell index.

///|
fn raw_cell(reference : String, row : Int, col : Int, value : String) -> Cell {
  {
    reference,
    row,
    col,
    value,
    value_type: cell_value_type(String(value)),
    rich_text: None,
    formula: None,
    formula_type: None,
    formula_ref: None,
    formula_shared_index: None,
    formula_value_present: false,
    style_explicit: false,
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

///|
test "resolved worksheet reads avoid repeated names and preserve style precedence" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Original")
  let cell_style = workbook.add_style(Style::builtin_number_format(2))
  let row_style = workbook.add_style(Style::new())
  let column_style = workbook.add_style(Style::new())
  sheet.set_cell_value_rc(1, 1, Numeric(1.5))
  sheet.set_cell_style_rc(1, 1, cell_style)
  workbook.set_row_style("Original", 2, row_style)
  workbook.set_col_style("Original", 1, column_style)
  workbook.set_sheet_name("Original", "Renamed")
  assert_eq(
    workbook.get_cell_value_from_worksheet_rc(sheet, 1, 1),
    Some("1.50"),
  )
  assert_eq(sheet.effective_style_id_rc(1, 1), cell_style)
  assert_eq(sheet.effective_style_id_rc(2, 2), row_style)
  assert_eq(sheet.effective_style_id_rc(3, 1), column_style)
  assert_eq(sheet.effective_style_id_rc(3, 2), 0)
}

///|
test "explicit cell style zero overrides inherited row style after roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("S")
  let row_style = workbook.add_style(Style::builtin_number_format(2))
  workbook.set_row_style("S", 1, row_style)
  sheet.set_cell_value_rc(1, 1, Numeric(1.0))
  sheet.set_cell_style_rc(1, 1, 0)
  assert_eq(sheet.effective_style_id_rc(1, 1), 0)
  assert_eq(workbook.get_cell_value("S", "A1"), Some("1"))
  let parsed = read(write(workbook))
  guard parsed.sheet("S") is Some(parsed_sheet) else {
    fail("expected parsed worksheet")
  }
  guard parsed_sheet.cell_index_of(1, 1) is Some(cell_index) else {
    fail("expected parsed cell")
  }
  assert_true(parsed_sheet.cells[cell_index].style_explicit)
  assert_eq(parsed_sheet.cells[cell_index].style_id, 0)
  assert_eq(parsed_sheet.effective_style_id_rc(1, 1), 0)
  assert_eq(parsed.get_cell_value("S", "A1"), Some("1"))
  let reparsed = read(write(parsed))
  guard reparsed.sheet("S") is Some(reparsed_sheet) else {
    fail("expected reparsed worksheet")
  }
  assert_eq(reparsed_sheet.effective_style_id_rc(1, 1), 0)
  assert_eq(reparsed.get_cell_value("S", "A1"), Some("1"))
}

///|
fn expect_unowned_worksheet_error(
  action : () -> Unit raise XlsxError,
) -> Unit raise {
  try action() catch {
    InvalidSheetOperation(msg~) =>
      inspect(msg, content="worksheet does not belong to this workbook")
    error => fail("unexpected worksheet ownership error: \{repr(error)}")
  } noraise {
    _ => fail("expected worksheet ownership error")
  }
}

///|
test "resolved worksheet reads reject foreign detached and stale handles" {
  let owner = Workbook::new()
  let owned = owner.add_sheet("Same")
  owned.set_cell_value_rc(1, 1, Numeric(1.5))
  let style = owner.add_style(Style::builtin_number_format(2))
  owned.set_cell_style_rc(1, 1, style)

  let foreign_workbook = Workbook::new()
  let foreign = foreign_workbook.add_sheet("Same")
  foreign.set_cell_value_rc(1, 1, Numeric(9.5))
  expect_unowned_worksheet_error(() => {
    ignore(owner.get_cell_value_from_worksheet_rc(foreign, 1, 1))
  })
  expect_unowned_worksheet_error(() => {
    ignore(owner.get_cell_value_styled_from_worksheet_rc(foreign, 1, 1, style))
  })

  let detached = Worksheet::new("Same")
  expect_unowned_worksheet_error(() => {
    ignore(owner.get_cell_value_from_worksheet_rc(detached, 1, 1))
  })

  ignore(owner.add_sheet("Keep"))
  let stale_deleted = owner.add_sheet("Deleted")
  owner.delete_sheet("Deleted")
  expect_unowned_worksheet_error(() => {
    ignore(owner.get_cell_value_from_worksheet_rc(stale_deleted, 1, 1))
  })

  let stale_replaced = owner.add_sheet("Destination")
  let source_index = owner.sheet_index("Same")
  let destination_index = owner.sheet_index("Destination")
  owner.copy_sheet(source_index, destination_index)
  expect_unowned_worksheet_error(() => {
    ignore(owner.get_cell_value_from_worksheet_rc(stale_replaced, 1, 1))
  })
  guard owner.sheet("Destination") is Some(replacement) else {
    fail("expected copied destination worksheet")
  }
  assert_eq(
    owner.get_cell_value_from_worksheet_rc(replacement, 1, 1),
    Some("1.50"),
  )
}

///|
test "parsed worksheets leave coordinate indexes ready for bounded reads" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Parsed")
  sheet.set_cell_value_rc(1, 1, String("first"))
  sheet.set_cell_value_rc(2, 2, Numeric(2.0))
  let parsed = read(write(workbook))
  guard parsed.sheet("Parsed") is Some(parsed_sheet) else {
    fail("expected parsed sheet")
  }
  assert_true(parsed_sheet.cell_index_valid)
  assert_eq(parsed_sheet.cell_index.length(), 2)
  assert_eq(parsed.get_cell_value("Parsed", "B2"), Some("2"))
}
