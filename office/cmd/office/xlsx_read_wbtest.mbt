///|
fn xlsx_read_test_projection() -> XlsxProjection raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Data"))
  ignore(workbook.new_sheet("财务 \"Q1\""))
  workbook.set_cell_str("Data", "A1", "alpha")
  workbook.set_cell_formula("Data", "B2", "SUM(1,2)", value="3")
  make_xlsx_projection("fixture.xlsx", workbook, 100)
}

///|
fn xlsx_cli_error(
  run : () -> Unit raise CliFailure,
) -> @lib.ProtocolError raise {
  try run() catch {
    CliFailure(error) => error
  } noraise {
    _ => fail("expected XLSX CLI failure")
  }
}

///|
test "XLSX selectors resolve to stable named canonical paths" {
  let projection = xlsx_read_test_projection()
  guard resolve_xlsx_selector(projection, "/xlsx/sheet[2]") is Sheet(second) else {
    fail("expected sheet selector")
  }
  assert_eq(second.name, "财务 \"Q1\"")
  assert_eq(second.index, 1)
  assert_eq(second.path, "/xlsx/sheet[name=\"财务 \\\"Q1\\\"\"]")
  assert_eq(@lib.parse_selector(second.path).render(), second.path)
  guard resolve_xlsx_selector(
      projection, "/xlsx/sheet[name=\"Data\"]/range[B2:A1]",
    )
    is Range(sheet, rect, path~) else {
    fail("expected range selector")
  }
  assert_eq(sheet.name, "Data")
  assert_eq(rect.cell_count(), 4L)
  assert_eq(path, "/xlsx/sheet[name=\"Data\"]/range[A1:B2]")
  assert_eq(@lib.parse_selector(path).render(), path)
}

///|
test "XLSX selector failures distinguish format, absence, and scan limits" {
  let projection = xlsx_read_test_projection()
  let mismatch = xlsx_cli_error(() => {
    ignore(resolve_xlsx_selector(projection, "/docx/body"))
  })
  assert_eq(mismatch.code, "office.xlsx.selector_format_mismatch")
  let missing = xlsx_cli_error(() => {
    ignore(resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Missing\"]"))
  })
  assert_eq(missing.code, "office.xlsx.selector_not_found")
  let oversized = xlsx_cli_error(() => {
    ignore(
      resolve_xlsx_selector(
        projection, "/xlsx/sheet[name=\"Data\"]/range[A1:K10]",
      ),
    )
  })
  assert_eq(oversized.code, "office.xlsx.resource_limit")
  guard oversized.details is Some(Object(fields)) else {
    fail("expected scan-limit details")
  }
  assert_eq(fields.get("resource"), Some(Json::string("scanned cells")))
  assert_eq(fields.get("limit"), Some(Json::number(100)))
  assert_eq(fields.get("actual"), Some(Json::number(110)))
}

///|
test "XLSX cell snapshots preserve typed values, formulas, and canonical paths" {
  let projection = xlsx_read_test_projection()
  guard resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Data\"]/cell[B2]")
    is Cell(sheet, rect, path~) else {
    fail("expected cell selector")
  }
  let budget = XlsxScanBudget::new(1)
  let snapshot = xlsx_cell_snapshot(
    projection,
    sheet,
    rect.row_lo,
    rect.col_lo,
    budget,
  )
  assert_true(snapshot.is_present())
  assert_eq(snapshot.path, path)
  assert_eq(snapshot.reference, "B2")
  assert_eq(snapshot.row, 2)
  assert_eq(snapshot.column, 2)
  assert_eq(snapshot.formula, Some("SUM(1,2)"))
  assert_eq(snapshot.formatted, Some("3"))
  assert_true(snapshot.raw is Some(String("3")))
  assert_eq(budget.scanned, 1)
}

///|
test "XLSX string and metadata accounting fail before unbounded retention" {
  let per_value = XlsxStringBudget::new(maximum=20, per_value_maximum=3)
  let too_wide = xlsx_cli_error(() => per_value.charge("cell value", "four"))
  assert_eq(too_wide.code, "office.xlsx.resource_limit")
  let aggregate = XlsxStringBudget::new(maximum=5, per_value_maximum=5)
  aggregate.charge("cell value", "abc")
  let too_many = xlsx_cli_error(() => aggregate.charge("cell formula", "def"))
  assert_eq(too_many.code, "office.xlsx.resource_limit")
  let metadata : XlsxMetadataBudget = {
    maximum_items: 1,
    maximum_string_chars: 4,
    items: 0,
    string_chars: 0,
  }
  metadata.charge_item(["name"])
  let metadata_limit = xlsx_cli_error(() => metadata.charge_item([]))
  assert_eq(metadata_limit.code, "office.xlsx.resource_limit")
}
