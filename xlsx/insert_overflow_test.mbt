// The transactional insert path: an insert that would push any content past
// the grid must raise BEFORE mutating anything, so the workbook is left exactly
// as it was (never a half-shifted or invalid-reference package). Covers cells,
// row/column dimensions, defined names, and page breaks — the structures that
// shift on insert — plus the exact grid boundary.

///|
fn raises(f : () -> Unit raise) -> Bool {
  try {
    f()
    false
  } catch {
    _ => true
  }
}

///|
test "insert_rows overflow raises and leaves the workbook unchanged (cells)" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  workbook.set_cell("S", "A1", "top")
  workbook.set_cell("S", "A1048576", "bottom") // exactly the last row
  // Shifting the bottom cell down by one would land on row 1048577.
  assert_true(raises(() => workbook.insert_rows("S", 1, 1)))
  // Nothing moved: the last row still holds its value and no cell escaped the grid.
  assert_eq(workbook.get_cell("S", "A1"), Some("top"))
  assert_eq(workbook.get_cell("S", "A1048576"), Some("bottom"))
  assert_eq(workbook.get_cell("S", "A2"), None)
}

///|
test "insert_rows respects the exact grid boundary" {
  // A cell at row axis_max - count fits after the shift; one row lower does not.
  let ok = @xlsx.Workbook::new()
  ignore(ok.add_sheet("S"))
  ok.set_cell("S", "A1048575", "x")
  ok.insert_rows("S", 1, 1) // 1048575 -> 1048576 (the last row): allowed
  assert_eq(ok.get_cell("S", "A1048576"), Some("x"))
  let bad = @xlsx.Workbook::new()
  ignore(bad.add_sheet("S"))
  bad.set_cell("S", "A1048576", "x")
  assert_true(raises(() => bad.insert_rows("S", 1, 1))) // 1048576 -> 1048577: rejected
  assert_eq(bad.get_cell("S", "A1048576"), Some("x"))
}

///|
test "insert_cols overflow raises and leaves the workbook unchanged (cells)" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  workbook.set_cell("S", "A1", "left")
  workbook.set_cell("S", "XFD1", "right") // XFD = column 16384, the last column
  assert_true(raises(() => workbook.insert_cols("S", 1, 1)))
  assert_eq(workbook.get_cell("S", "A1"), Some("left"))
  assert_eq(workbook.get_cell("S", "XFD1"), Some("right"))
  assert_eq(workbook.get_cell("S", "B1"), None)
}

///|
test "insert_rows overflow is caught for a row dimension alone (no cell at the edge)" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  workbook.set_cell("S", "A1", "top")
  // A hidden row at the very bottom — a dimension key, not a cell — would shift
  // past the grid. The dimension shifts numerically (not via cell_ref_from), so
  // it needs its own bound check.
  workbook.set_row_visible("S", 1048576, false)
  assert_true(raises(() => workbook.insert_rows("S", 1, 1)))
  // Unchanged: the row is still hidden at 1048576 and the cell never moved.
  assert_eq(workbook.get_row_visible("S", 1048576), false)
  assert_eq(workbook.get_cell("S", "A1"), Some("top"))
  assert_eq(workbook.get_cell("S", "A2"), None)
}

///|
test "insert_cols overflow is caught for a column dimension alone" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  workbook.set_cell("S", "A1", "left")
  workbook.set_col_visible("S", 16384, false) // last column, hidden
  assert_true(raises(() => workbook.insert_cols("S", 1, 1)))
  assert_eq(workbook.get_col_visible("S", 16384), false)
  assert_eq(workbook.get_cell("S", "A1"), Some("left"))
}

///|
test "insert_rows overflow is caught for a defined name alone" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  workbook.set_cell("S", "A1", "top")
  // An absolute defined name pinned to the last row would rewrite to $A$1048577.
  workbook.set_defined_name(
    @xlsx.DefinedName::new("Edge", "S!$A$1048576", scope="S"),
  )
  assert_true(raises(() => workbook.insert_rows("S", 1, 1)))
  // The defined name is untouched, and so is the sheet (staged names are
  // validated before the worksheet is mutated).
  let names = workbook.defined_names()
  assert_eq(names.length(), 1)
  assert_eq(names[0].refers_to, "S!$A$1048576")
  assert_eq(workbook.get_cell("S", "A1"), Some("top"))
  assert_eq(workbook.get_cell("S", "A2"), None)
}

///|
test "insert_rows page-break bound is exact and leaves the break intact" {
  // Break ids are 0-based (id = row - 1): the last valid id is 1048575, so a
  // one-row shift of a break stored at 1048575 lands on 1048576 — out of grid.
  let bad = @xlsx.Workbook::new()
  ignore(bad.add_sheet("S"))
  bad.set_cell("S", "A1", "top")
  bad.insert_page_break("S", "A1048576") // id 1048575
  assert_true(raises(() => bad.insert_rows("S", 1, 1)))
  let badsheet = match bad.sheet("S") {
    Some(s) => s
    None => fail("S")
  }
  assert_eq(badsheet.row_breaks().length(), 1)
  assert_eq(badsheet.row_breaks()[0].id, 1048575) // untouched
  assert_eq(bad.get_cell("S", "A1"), Some("top"))
  assert_eq(bad.get_cell("S", "A2"), None)
  // A break one row higher shifts to the last valid id (1048575) and is allowed.
  let ok = @xlsx.Workbook::new()
  ignore(ok.add_sheet("S"))
  ok.insert_page_break("S", "A1048575") // id 1048574
  ok.insert_rows("S", 1, 1)
  let oksheet = match ok.sheet("S") {
    Some(s) => s
    None => fail("S")
  }
  assert_eq(oksheet.row_breaks()[0].id, 1048575)
}

///|
test "insert rejects a count larger than the grid (no Int wrap)" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  workbook.set_cell("S", "A1", "keep")
  // A pinned name near the top would wrap Int if shifted by 2147483647; the count
  // bound rejects the insert before any arithmetic can overflow.
  workbook.set_defined_name(@xlsx.DefinedName::new("N", "S!$A$1", scope="S"))
  assert_true(raises(() => workbook.insert_rows("S", 1, 2147483647)))
  assert_eq(workbook.get_cell("S", "A1"), Some("keep"))
  assert_eq(workbook.defined_names()[0].refers_to, "S!$A$1")
  assert_true(raises(() => workbook.insert_cols("S", 1, 2147483647)))
  assert_eq(workbook.get_cell("S", "A1"), Some("keep"))
}

///|
test "duplicate_row_to is atomic when a defined name would overflow" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  workbook.set_cell("S", "A1", "top")
  workbook.set_defined_name(
    @xlsx.DefinedName::new("Edge", "S!$A$1048576", scope="S"),
  )
  // Duplicating row 1 into row 2 shifts the pinned last-row name to $A$1048577;
  // staging the names before the row copy keeps the whole op all-or-nothing.
  assert_true(raises(() => workbook.duplicate_row_to("S", 1, 2)))
  let names = workbook.defined_names()
  assert_eq(names.length(), 1)
  assert_eq(names[0].refers_to, "S!$A$1048576")
  assert_eq(workbook.get_cell("S", "A1"), Some("top"))
  assert_eq(workbook.get_cell("S", "A2"), None)
}
