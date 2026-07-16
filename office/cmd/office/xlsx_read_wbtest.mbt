///|
fn xlsx_read_test_projection() -> XlsxProjection raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Data"))
  ignore(workbook.new_sheet("财务 \"Q1\""))
  workbook.set_cell_str("Data", "A1", "alpha")
  workbook.set_cell_formula("Data", "B2", "SUM(1,2)", value="3")
  workbook.set_cell_formula("Data", "C3", "NOW()")
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

///|
test "XLSX query selectors are bounded, deterministic predicate conjunctions" {
  let projection = xlsx_read_test_projection()
  guard resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Data\"]/cell[B2]")
    is Cell(sheet, rect, ..) else {
    fail("expected cell selector")
  }
  let snapshot = xlsx_cell_snapshot(
    projection,
    sheet,
    rect.row_lo,
    rect.col_lo,
    XlsxScanBudget::new(1),
  )
  let predicates = parse_xlsx_query_selector(
    "cell[type=formula][formula~=SUM][text=3]",
  )
  assert_eq(predicates.length(), 3)
  let work = OfficeQueryWorkBudget::new(1024, format="xlsx")
  assert_true(
    xlsx_cell_matches(
      snapshot,
      prepare_xlsx_query_predicates(predicates, work),
      work,
    ),
  )
  let comparison_work = OfficeQueryWorkBudget::new(1024, format="xlsx")
  assert_false(
    xlsx_cell_matches(
      snapshot,
      prepare_xlsx_query_predicates(
        parse_xlsx_query_selector("cell[value>3]"),
        comparison_work,
      ),
      comparison_work,
    ),
  )
  let malformed = xlsx_cli_error(() => {
    ignore(parse_xlsx_query_selector("row[type=number]"))
  })
  assert_eq(malformed.code, "office.xlsx.invalid_query")
  let too_many = "cell" + "[formula]".repeat(17)
  let predicate_limit = xlsx_cli_error(() => {
    ignore(parse_xlsx_query_selector(too_many))
  })
  assert_eq(predicate_limit.code, "office.xlsx.query_predicate_limit")
  let work_limit = xlsx_cli_error(() => {
    let limited = OfficeQueryWorkBudget::new(24, format="xlsx")
    let prepared = prepare_xlsx_query_predicates(
      parse_xlsx_query_selector("cell[text~=alpha]"),
      limited,
    )
    ignore(xlsx_cell_matches(snapshot, prepared, limited))
  })
  assert_eq(work_limit.code, "office.xlsx.resource_limit")
  guard work_limit.details is Some(Object(fields)) else {
    fail("expected query-work details")
  }
  assert_eq(
    fields.get("resource"),
    Some(Json::string("query predicate work units")),
  )
}

///|
test "XLSX outline and get use office schemas with canonical cell records" {
  let projection = xlsx_read_test_projection()
  let outline = xlsx_outline_data(projection)
  guard outline is Object(outline_fields) else {
    fail("expected outline object")
  }
  assert_eq(
    outline_fields.get("schema"),
    Some(Json::string(@lib.SCHEMA_XLSX_OUTLINE)),
  )
  assert_eq(outline_fields.get("sheet_count"), Some(Json::number(2)))
  guard outline_fields.get("sheets") is Some(Array(sheets)) else {
    fail("expected sheets")
  }
  assert_eq(sheets.length(), 2)
  let resolved = resolve_xlsx_selector(
    projection, "/xlsx/sheet[name=\"Data\"]/range[A1:C3]",
  )
  let data = xlsx_get_data(projection, resolved)
  guard data is Object(fields) && fields.get("cells") is Some(Array(cells)) else {
    fail("expected range cells")
  }
  assert_eq(fields.get("schema"), Some(Json::string(@lib.SCHEMA_XLSX_ELEMENT)))
  assert_eq(cells.length(), 3)
  assert_true(cells[0].stringify().contains("alpha"))
  assert_true(cells[1].stringify().contains("SUM(1,2)"))
  assert_true(cells[2].stringify().contains("NOW()"))
  let missing = resolve_xlsx_selector(
    projection, "/xlsx/sheet[name=\"Data\"]/cell[D4]",
  )
  let missing_error = xlsx_cli_error(() => {
    ignore(xlsx_get_data(projection, missing))
  })
  assert_eq(missing_error.code, "office.xlsx.selector_not_found")
}

///|
test "XLSX text and query scan fully while retaining only the requested page" {
  let projection = xlsx_read_test_projection()
  let under = Some(
    resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Data\"]"),
  )
  let text = xlsx_text_data(projection, under, 1, 1)
  guard text is Object(text_fields) &&
    text_fields.get("entries") is Some(Array(entries)) else {
    fail("expected text entries")
  }
  assert_eq(text_fields.get("matched_total"), Some(Json::number(3)))
  assert_eq(text_fields.get("returned"), Some(Json::number(1)))
  assert_eq(text_fields.get("truncated"), Some(Json::boolean(true)))
  assert_eq(text_fields.get("scanned_cells"), Some(Json::number(9)))
  assert_eq(entries.length(), 1)
  assert_true(entries[0].stringify().contains("B2"))
  let formula_query : XlsxQuerySpec = {
    selector: "cell[formula]",
    predicates: parse_xlsx_query_selector("cell[formula]"),
    offset: 0,
    limit: 10,
  }
  let query = xlsx_query_data(projection, under, formula_query)
  guard query is Object(query_fields) &&
    query_fields.get("matches") is Some(Array(matches)) else {
    fail("expected query matches")
  }
  assert_eq(query_fields.get("matched_total"), Some(Json::number(2)))
  assert_eq(matches.length(), 2)
  assert_true(matches[1].stringify().contains("NOW()"))
}

///|
test "XLSX JSON and human output enforce format-specific stdout ceilings" {
  let projection = xlsx_read_test_projection()
  let payload = xlsx_outline_payload(projection, 100_000)
  let json = checked_office_json_output(payload)
  assert_true(json.contains("office.output/1"))
  assert_true(json.contains("office.xlsx.outline/1"))
  let too_small = xlsx_cli_error(() => {
    ignore(xlsx_outline_payload(projection, 8))
  })
  assert_eq(too_small.code, "office.xlsx.resource_limit")
  let under = Some(
    resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Data\"]"),
  )
  let human = xlsx_text_human(projection, under, 0, 10, 10_000)
  assert_true(human.contains("/cell[A1]\talpha"))
  assert_true(human.contains("/cell[C3]\t=NOW()"))
}

///|
test "XLSX all-sheet scans reject sparse far extents before visiting cells" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Sparse"))
  workbook.set_cell_str("Sparse", "K10", "far")
  let projection = make_xlsx_projection("sparse.xlsx", workbook, 100)
  let error = xlsx_cli_error(() => {
    ignore(xlsx_text_data(projection, None, 0, 10))
  })
  assert_eq(error.code, "office.xlsx.resource_limit")
  guard error.details is Some(Object(fields)) else {
    fail("expected sparse-scan details")
  }
  assert_eq(fields.get("actual"), Some(Json::number(110)))
}
