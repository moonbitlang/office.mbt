// Blackbox coverage for the materialized row/column dimension enumerators:
// ascending order, agreement with the per-index getters, dimension-only
// lines beyond the stored-cell extent, empty sheets, and survival through a
// write/read round trip.

///|
/// Probes rows 1..=limit with the per-index getters and returns every row
/// index holding a non-default dimension.
fn probed_row_indices(
  workbook : @xlsx.Workbook,
  sheet_name : String,
  limit : Int,
) -> Array[Int] raise {
  let rows : Array[Int] = []
  for row in 1..<=limit {
    let non_default = workbook.get_row_height(sheet_name, row) is Some(_) ||
      !workbook.row_visible(sheet_name, row) ||
      workbook.row_outline_level(sheet_name, row) != 0 ||
      workbook.get_row_style(sheet_name, row) is Some(_)
    if non_default {
      rows.push(row)
    }
  }
  rows
}

///|
/// Probes columns 1..=limit with the per-index getters and returns every
/// column index holding a non-default dimension.
fn probed_col_indices(
  workbook : @xlsx.Workbook,
  sheet_name : String,
  limit : Int,
) -> Array[Int] raise {
  let cols : Array[Int] = []
  for col in 1..<=limit {
    let non_default = workbook.get_col_width(sheet_name, col) is Some(_) ||
      !workbook.col_visible(sheet_name, col) ||
      workbook.col_outline_level(sheet_name, col) != 0 ||
      workbook.get_col_style(sheet_name, col) is Some(_)
    if non_default {
      cols.push(col)
    }
  }
  cols
}

///|
fn assert_row_entries_match_getters(
  workbook : @xlsx.Workbook,
  sheet_name : String,
) -> Unit raise {
  for entry in workbook.get_row_dimensions(sheet_name) {
    let (row, dim) = entry
    assert_eq(dim.height, workbook.get_row_height(sheet_name, row))
    assert_eq(dim.hidden, !workbook.row_visible(sheet_name, row))
    assert_eq(dim.outline_level, workbook.row_outline_level(sheet_name, row))
    assert_eq(dim.style_id, workbook.get_row_style(sheet_name, row))
  }
}

///|
fn assert_col_entries_match_getters(
  workbook : @xlsx.Workbook,
  sheet_name : String,
) -> Unit raise {
  for entry in workbook.get_col_dimensions(sheet_name) {
    let (col, dim) = entry
    assert_eq(dim.width, workbook.get_col_width(sheet_name, col))
    assert_eq(dim.hidden, !workbook.col_visible(sheet_name, col))
    assert_eq(dim.outline_level, workbook.col_outline_level(sheet_name, col))
    assert_eq(dim.style_id, workbook.get_col_style(sheet_name, col))
  }
}

///|
fn dimension_fixture_workbook() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  // Small stored-cell extent: A1:B3.
  workbook.set_cell("Data", "A1", "Region")
  workbook.set_cell("Data", "B1", "Total")
  workbook.set_cell_int("Data", "A2", 1)
  workbook.set_cell_int("Data", "B3", 2)
  // Row dimensions, deliberately created out of index order, several far
  // beyond the stored-cell extent (a hidden band with no cells).
  workbook.set_row_height("Data", 10000, 24.5)
  workbook.set_row_visible("Data", 5001, false)
  workbook.set_row_visible("Data", 5000, false)
  workbook.set_row_outline_level("Data", 12, 2)
  let row_style = workbook.add_style(@xlsx.Style::builtin_number_format(2))
  workbook.set_row_style("Data", 2, row_style)
  // Column dimensions: styled, hidden, sized, grouped, one beyond extent.
  let col_style = workbook.add_style(@xlsx.Style::builtin_number_format(10))
  workbook.set_col_width("Data", 3, 18.5)
  workbook.set_col_visible("Data", 2, false)
  workbook.set_col_outline_level("Data", 6, 1)
  workbook.set_col_style("Data", 8, col_style)
  workbook.set_col_width("Data", 120, 4.0)
  workbook
}

///|
test "row dimension enumerator: ascending order, beyond-extent rows, getter agreement" {
  let workbook = dimension_fixture_workbook()
  let entries = workbook.get_row_dimensions("Data")
  debug_inspect(
    entries,
    content=(
      #|[
      #|  (
      #|    2,
      #|    { height: None, hidden: false, outline_level: 0, style_id: Some(1) },
      #|  ),
      #|  (
      #|    12,
      #|    { height: None, hidden: false, outline_level: 2, style_id: None },
      #|  ),
      #|  (
      #|    5000,
      #|    { height: None, hidden: true, outline_level: 0, style_id: None },
      #|  ),
      #|  (
      #|    5001,
      #|    { height: None, hidden: true, outline_level: 0, style_id: None },
      #|  ),
      #|  (
      #|    10000,
      #|    {
      #|      height: Some(24.5),
      #|      hidden: false,
      #|      outline_level: 0,
      #|      style_id: None,
      #|    },
      #|  ),
      #|]
    ),
  )
  // Agreement with the per-index getters on every yielded index.
  assert_row_entries_match_getters(workbook, "Data")
  // ... and the enumerator reports nothing else: probing every row in a
  // range covering all fixture indices finds exactly the enumerated rows.
  let enumerated : Array[Int] = []
  for entry in entries {
    enumerated.push(entry.0)
  }
  assert_eq(enumerated, probed_row_indices(workbook, "Data", 10_050))
  // The worksheet-level enumerator returns the same records.
  assert_eq(
    entries,
    workbook.sheet("Data").unwrap().materialized_row_dimensions(),
  )
}

///|
test "col dimension enumerator: ascending order, styled/hidden columns, getter agreement" {
  let workbook = dimension_fixture_workbook()
  let entries = workbook.get_col_dimensions("Data")
  debug_inspect(
    entries,
    content=(
      #|[
      #|  (2, { width: None, hidden: true, outline_level: 0, style_id: None }),
      #|  (
      #|    3,
      #|    { width: Some(18.5), hidden: false, outline_level: 0, style_id: None },
      #|  ),
      #|  (6, { width: None, hidden: false, outline_level: 1, style_id: None }),
      #|  (
      #|    8,
      #|    { width: None, hidden: false, outline_level: 0, style_id: Some(2) },
      #|  ),
      #|  (
      #|    120,
      #|    { width: Some(4), hidden: false, outline_level: 0, style_id: None },
      #|  ),
      #|]
    ),
  )
  assert_col_entries_match_getters(workbook, "Data")
  let enumerated : Array[Int] = []
  for entry in entries {
    enumerated.push(entry.0)
  }
  assert_eq(enumerated, probed_col_indices(workbook, "Data", 200))
  assert_eq(
    entries,
    workbook.sheet("Data").unwrap().materialized_col_dimensions(),
  )
}

///|
test "dimension enumerators: empty sheet yields nothing" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Empty"))
  debug_inspect(workbook.get_row_dimensions("Empty"), content="[]")
  debug_inspect(workbook.get_col_dimensions("Empty"), content="[]")
  let sheet = workbook.sheet("Empty").unwrap()
  debug_inspect(sheet.materialized_row_dimensions(), content="[]")
  debug_inspect(sheet.materialized_col_dimensions(), content="[]")
}

///|
test "dimension enumerators: cells alone materialize no dimensions" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Cells"))
  workbook.set_cell("Cells", "A1", "x")
  workbook.set_cell_int("Cells", "C7", 42)
  debug_inspect(workbook.get_row_dimensions("Cells"), content="[]")
  debug_inspect(workbook.get_col_dimensions("Cells"), content="[]")
}

///|
test "dimension enumerators: resetting to defaults removes the record" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Reset"))
  workbook.set_row_visible("Reset", 5000, false)
  workbook.set_row_visible("Reset", 5000, true)
  debug_inspect(workbook.get_row_dimensions("Reset"), content="[]")
  workbook.set_col_visible("Reset", 9, false)
  workbook.set_col_visible("Reset", 9, true)
  debug_inspect(workbook.get_col_dimensions("Reset"), content="[]")
}

///|
test "dimension enumerators: unknown sheet raises SheetNotFound" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  try workbook.get_row_dimensions("Missing") |> ignore catch {
    e => inspect(e is SheetNotFound(_), content="true")
  } noraise {
    _ => fail("expected get_row_dimensions to raise")
  }
  try workbook.get_col_dimensions("Missing") |> ignore catch {
    e => inspect(e is SheetNotFound(_), content="true")
  } noraise {
    _ => fail("expected get_col_dimensions to raise")
  }
}

///|
test "dimension enumerators survive a write/read round trip" {
  let source = dimension_fixture_workbook()
  let bytes = source.write_to_buffer()
  let parsed = @xlsx.read(bytes)
  // Hidden rows beyond the stored-cell extent survive the round trip and
  // are enumerable without probing the grid.
  debug_inspect(
    parsed.get_row_dimensions("Data"),
    content=(
      #|[
      #|  (
      #|    2,
      #|    { height: None, hidden: false, outline_level: 0, style_id: Some(1) },
      #|  ),
      #|  (
      #|    12,
      #|    { height: None, hidden: false, outline_level: 2, style_id: None },
      #|  ),
      #|  (
      #|    5000,
      #|    { height: None, hidden: true, outline_level: 0, style_id: None },
      #|  ),
      #|  (
      #|    5001,
      #|    { height: None, hidden: true, outline_level: 0, style_id: None },
      #|  ),
      #|  (
      #|    10000,
      #|    {
      #|      height: Some(24.5),
      #|      hidden: false,
      #|      outline_level: 0,
      #|      style_id: None,
      #|    },
      #|  ),
      #|]
    ),
  )
  debug_inspect(
    parsed.get_col_dimensions("Data"),
    content=(
      #|[
      #|  (2, { width: None, hidden: true, outline_level: 0, style_id: None }),
      #|  (
      #|    3,
      #|    { width: Some(18.5), hidden: false, outline_level: 0, style_id: None },
      #|  ),
      #|  (6, { width: None, hidden: false, outline_level: 1, style_id: None }),
      #|  (
      #|    8,
      #|    { width: None, hidden: false, outline_level: 0, style_id: Some(2) },
      #|  ),
      #|  (
      #|    120,
      #|    { width: Some(4), hidden: false, outline_level: 0, style_id: None },
      #|  ),
      #|]
    ),
  )
  // The parsed workbook's enumerators still agree with its per-index
  // getters.
  assert_row_entries_match_getters(parsed, "Data")
  assert_col_entries_match_getters(parsed, "Data")
}
