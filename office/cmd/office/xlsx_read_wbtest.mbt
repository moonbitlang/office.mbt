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
fn xlsx_bounded_test_source(
  file : String,
  bytes : BytesView,
) -> OfficeReadPackage raise {
  let archive = @zip.read_limited(
    bytes,
    max_package_bytes=office_read_max_package_bytes,
    max_entries=office_read_max_zip_entries,
    max_entry_uncompressed_bytes=office_read_max_zip_entry_bytes,
    max_total_uncompressed_bytes=office_read_max_zip_total_bytes,
    max_total_preserved_source_bytes=office_read_max_preserved_source_bytes,
  )
  { file, format: Xlsx, archive }
}

///|
fn xlsx_strict_test_bytes() -> Bytes raise {
  let archive = @zip.Archive::new()
  let content_types =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>
  let root_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="main" Type="http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
  let workbook =
    #|<workbook xmlns="http://purl.oclc.org/ooxml/spreadsheetml/main" xmlns:r="http://purl.oclc.org/ooxml/officeDocument/relationships"><sheets><sheet name="Strict" sheetId="1" r:id="sheet"/></sheets></workbook>
  let workbook_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="sheet" Type="http://purl.oclc.org/ooxml/officeDocument/relationships/worksheet" Target="worksheets/sheet.xml"/></Relationships>
  let worksheet =
    #|<worksheet xmlns="http://purl.oclc.org/ooxml/spreadsheetml/main"><sheetData><row r="1"><c r="A1" t="str"><v>strict-value</v></c></row></sheetData></worksheet>
  archive.add("[Content_Types].xml", @utf8.encode(content_types))
  archive.add("_rels/.rels", @utf8.encode(root_relationships))
  archive.add("xl/workbook.xml", @utf8.encode(workbook))
  archive.add(
    "xl/_rels/workbook.xml.rels",
    @utf8.encode(workbook_relationships),
  )
  archive.add("xl/worksheets/sheet.xml", @utf8.encode(worksheet))
  @zip.write(archive)
}

///|
fn xlsx_relocated_test_bytes() -> Bytes raise {
  let archive = @zip.Archive::new()
  let content_types =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="/custom/book.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/data/first.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/data/Strings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/></Types>
  let root_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="custom/book.xml"/></Relationships>
  let workbook =
    #|<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Moved" sheetId="1" r:id="sheet"/></sheets></workbook>
  let workbook_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="sheet" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="../data/first.xml"/><Relationship Id="strings" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="../data/strings.xml"/></Relationships>
  let worksheet =
    #|<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c></row></sheetData></worksheet>
  let shared_strings =
    #|<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="1" uniqueCount="1"><si><t>relocated-value</t></si></sst>
  archive.add("[Content_Types].xml", @utf8.encode(content_types))
  archive.add("_rels/.rels", @utf8.encode(root_relationships))
  archive.add("custom/book.xml", @utf8.encode(workbook))
  archive.add(
    "custom/_rels/book.xml.rels",
    @utf8.encode(workbook_relationships),
  )
  archive.add("data/first.xml", @utf8.encode(worksheet))
  // OPC part lookup is case-insensitive. Keep the relationship spelling lower
  // case and the actual ZIP entry mixed case to cover canonical resolution.
  archive.add("data/Strings.xml", @utf8.encode(shared_strings))
  @zip.write(archive)
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
  guard resolve_xlsx_selector(
      projection, "/xlsx/sheet[name=\"Data\"]/range[B2:B2]",
    )
    is Range(_, singleton, path~) else {
    fail("expected singleton range selector")
  }
  assert_eq(singleton.range_reference(projection.file), "B2:B2")
  assert_eq(path, "/xlsx/sheet[name=\"Data\"]/range[B2:B2]")
  assert_eq(@lib.parse_selector(path).render(), path)
  guard resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"data\"]/cell[A1]")
    is Cell(case_insensitive_sheet, _, path~) else {
    fail("expected case-insensitive sheet selector")
  }
  assert_eq(case_insensitive_sheet.name, "Data")
  assert_eq(path, "/xlsx/sheet[name=\"Data\"]/cell[A1]")
}

///|
test "XLSX structured reads accept detector-valid Strict OOXML relationships" {
  let source = xlsx_bounded_test_source("strict.xlsx", xlsx_strict_test_bytes())
  assert_true(@lib.detect_archive_format(source.file, source.archive) is Xlsx)
  let projection = open_xlsx_projection(source, 10)
  guard xlsx_get_data(
      projection,
      resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Strict\"]/cell[A1]"),
    )
    is Object(get) &&
    get.get("cell") is Some(Object(cell)) else {
    fail("expected Strict XLSX cell")
  }
  assert_eq(cell.get("value"), Some(Json::string("strict-value")))
}

///|
test "XLSX structured reads resolve relationships from relocated workbooks" {
  let source = xlsx_bounded_test_source(
    "relocated.xlsx",
    xlsx_relocated_test_bytes(),
  )
  assert_true(@lib.detect_archive_format(source.file, source.archive) is Xlsx)
  let projection = open_xlsx_projection(source, 10)
  guard xlsx_get_data(
      projection,
      resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"moved\"]/cell[A1]"),
    )
    is Object(get) &&
    get.get("cell") is Some(Object(cell)) else {
    fail("expected relocated XLSX cell")
  }
  assert_eq(
    get.get("path"),
    Some(Json::string("/xlsx/sheet[name=\"Moved\"]/cell[A1]")),
  )
  assert_eq(cell.get("value"), Some(Json::string("relocated-value")))
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
  assert_eq(snapshot.formatted, None)
  snapshot.ensure_formatted(projection, budget)
  assert_eq(snapshot.formatted, Some("3"))
  assert_true(snapshot.raw is Some(String("3")))
  assert_eq(budget.scanned, 1)
}

///|
test "XLSX cell scans keep the resolved worksheet handle" {
  let projection = xlsx_read_test_projection()
  guard resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Data\"]/cell[A1]")
    is Cell(sheet, rect, ..) else {
    fail("expected cell selector")
  }
  projection.workbook.set_sheet_name("Data", "Renamed")
  let snapshot = xlsx_cell_snapshot(
    projection,
    sheet,
    rect.row_lo,
    rect.col_lo,
    XlsxScanBudget::new(1),
  )
  guard snapshot.raw is Some(String(raw)) else {
    fail("expected resolved raw string")
  }
  assert_eq(raw, "alpha")
  snapshot.ensure_formatted(projection, XlsxScanBudget::new(1))
  assert_eq(snapshot.formatted, Some("alpha"))
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
  let structured = parse_xlsx_query_selector(
    "cell[formula~=SUM(Table1[[#Headers],[Amount]])][text~=total]",
  )
  assert_eq(structured.length(), 2)
  guard structured[0] is FormulaContains(literal) else {
    fail("expected structured-reference formula predicate")
  }
  assert_eq(literal, "SUM(Table1[[#Headers],[Amount]])")
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
test "XLSX snapshots preserve and resolve shared-formula followers" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Data"))
  workbook.set_cell_formula_opts(
    "Data",
    "A1",
    "D1+1",
    opts=@xlsx.FormulaOpts::shared("A1:C1"),
  )
  let projection = make_xlsx_projection("shared.xlsx", workbook, 10)
  assert_false(projection.sheets[0].shared_formulas_indexed)
  let under = Some(
    resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Data\"]"),
  )
  let spec : XlsxQuerySpec = {
    selector: "cell[type=formula][formula~=D1]",
    predicates: parse_xlsx_query_selector("cell[type=formula][formula~=D1]"),
    offset: 0,
    limit: 10,
  }
  guard xlsx_query_data(projection, under, spec) is Object(fields) &&
    fields.get("matches") is Some(Array(matches)) else {
    fail("expected shared-formula matches")
  }
  assert_eq(fields.get("matched_total"), Some(Json::number(3)))
  assert_eq(matches.length(), 3)
  assert_true(projection.sheets[0].shared_formulas_indexed)
  for match_record in matches {
    assert_true(match_record.stringify().contains("\"formula\":\"D1+1\""))
  }
}

///|
test "XLSX formatting is deferred and custom-format work is charged" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Data"))
  let style_id = workbook.new_style(@xlsx.Style::number_format("[Red]0.00"))
  for column in 1..<=2 {
    workbook.set_cell_int(
      "Data",
      @xlsx.coordinates_to_cell_name(column, 1),
      column,
    )
    workbook.set_cell_style(
      "Data",
      @xlsx.coordinates_to_cell_name(column, 1),
      style_id,
    )
  }
  let projection = make_xlsx_projection("format-work.xlsx", workbook, 10)
  let regions = xlsx_scan_regions(
    projection,
    Some(resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Data\"]")),
  )
  // A raw predicate with an empty page never formats matching cells.
  let page = collect_xlsx_cell_page(
    projection,
    regions,
    xlsx_query_filter(parse_xlsx_query_selector("cell[type=number]")),
    0,
    0,
    format_work_maximum=1,
  )
  assert_eq(page.matched_total, 2)
  assert_eq(page.cells.length(), 0)
  assert_false(projection.sheets[0].shared_formulas_indexed)
  let limited = xlsx_cli_error(() => {
    ignore(
      collect_xlsx_cell_page(
        projection,
        regions,
        TextCells,
        0,
        10,
        format_work_maximum=1,
      ),
    )
  })
  assert_eq(limited.code, "office.xlsx.resource_limit")
  guard limited.details is Some(Object(details)) else {
    fail("expected format-work limit details")
  }
  assert_eq(
    details.get("resource"),
    Some(Json::string("cell formatting work units")),
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
test "XLSX singleton used ranges remain canonical two-endpoint ranges" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Only"))
  workbook.set_cell_str("Only", "A1", "one")
  let projection = make_xlsx_projection("one.xlsx", workbook, 10)
  let outline = xlsx_outline_data(projection)
  guard outline is Object(fields) &&
    fields.get("sheets") is Some(Array([Object(sheet), ..])) &&
    sheet.get("used_range") is Some(Object(used)) else {
    fail("expected singleton used range")
  }
  assert_eq(used.get("reference"), Some(Json::string("A1:A1")))
  assert_eq(
    used.get("path"),
    Some(Json::string("/xlsx/sheet[name=\"Only\"]/range[A1:A1]")),
  )
  let resolved = resolve_xlsx_selector(
    projection, "/xlsx/sheet[name=\"Only\"]/range[A1:A1]",
  )
  guard xlsx_get_data(projection, resolved) is Object(get) else {
    fail("expected singleton range get")
  }
  assert_eq(get.get("reference"), Some(Json::string("A1:A1")))
}

///|
test "XLSX structured reads reject non-finite package numbers" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Data"))
  workbook.set_cell_int("Data", "A1", 1)
  let archive = try! @zip.read(@xlsx.write(workbook))
  guard archive.get("xl/worksheets/sheet1.xml") is Some(sheet_bytes) else {
    fail("missing worksheet part")
  }
  let sheet_xml = try! @utf8.decode(sheet_bytes, ignore_bom=true)
  assert_true(sheet_xml.contains("<v>1</v>"))
  assert_true(
    archive.replace(
      "xl/worksheets/sheet1.xml",
      @utf8.encode(sheet_xml.replace(old="<v>1</v>", new="<v>NaN</v>")),
    ),
  )
  let bytes = @zip.write(archive)
  let bounded = try! @zip.read_limited(
    bytes,
    max_package_bytes=office_read_max_package_bytes,
    max_entries=office_read_max_zip_entries,
    max_entry_uncompressed_bytes=office_read_max_zip_entry_bytes,
    max_total_uncompressed_bytes=office_read_max_zip_total_bytes,
    max_total_preserved_source_bytes=office_read_max_preserved_source_bytes,
  )
  let source : OfficeReadPackage = {
    file: "non-finite.xlsx",
    format: Xlsx,
    archive: bounded,
  }
  let error = xlsx_cli_error(() => ignore(open_xlsx_projection(source, 10)))
  assert_eq(error.code, "office.invalid_package")
}

///|
test "XLSX parse-time index corruption is classified as an invalid package" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Data"))
  workbook.set_cell_str("Data", "A1", "alpha")
  let shared_archive = @zip.read(@xlsx.write(workbook))
  guard shared_archive.get("xl/worksheets/sheet1.xml") is Some(shared_bytes) else {
    fail("missing shared-string worksheet")
  }
  let shared_xml = @utf8.decode(shared_bytes, ignore_bom=true)
  assert_true(shared_xml.contains("<v>0</v>"))
  assert_true(
    shared_archive.replace(
      "xl/worksheets/sheet1.xml",
      @utf8.encode(shared_xml.replace(old="<v>0</v>", new="<v>7</v>")),
    ),
  )
  let shared_source = xlsx_bounded_test_source(
    "broken-shared.xlsx",
    @zip.write(shared_archive),
  )
  let shared = xlsx_cli_error(() => {
    ignore(open_xlsx_projection(shared_source, 10))
  })
  assert_eq(shared.code, "office.invalid_package")

  let styled_workbook = @xlsx.Workbook::new()
  ignore(styled_workbook.new_sheet("Data"))
  styled_workbook.set_cell_int("Data", "A1", 1)
  let style_archive = @zip.read(@xlsx.write(styled_workbook))
  guard style_archive.get("xl/worksheets/sheet1.xml") is Some(style_bytes) else {
    fail("missing styled worksheet")
  }
  let style_xml = @utf8.decode(style_bytes, ignore_bom=true)
  assert_true(style_xml.contains("<c r=\"A1\""))
  assert_true(
    style_archive.replace(
      "xl/worksheets/sheet1.xml",
      @utf8.encode(
        style_xml.replace(old="<c r=\"A1\"", new="<c r=\"A1\" s=\"9\""),
      ),
    ),
  )
  let style_source = xlsx_bounded_test_source(
    "broken-style.xlsx",
    @zip.write(style_archive),
  )
  let style = xlsx_cli_error(() => {
    ignore(open_xlsx_projection(style_source, 10))
  })
  assert_eq(style.code, "office.invalid_package")
}

///|
test "XLSX style parsing rejects non-finite JSON-facing numbers" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Data"))
  workbook.set_cell_int("Data", "A1", 1)
  let style_id = workbook.new_style(
    @xlsx.Style::font(@xlsx.Font::with_values(size=12.0)),
  )
  workbook.set_cell_style("Data", "A1", style_id)
  let archive = try! @zip.read(@xlsx.write(workbook))
  guard archive.get("xl/styles.xml") is Some(style_bytes) else {
    fail("missing styles part")
  }
  let styles_xml = try! @utf8.decode(style_bytes, ignore_bom=true)
  assert_true(styles_xml.contains("<sz val=\"12\"/>"))
  assert_true(
    archive.replace(
      "xl/styles.xml",
      @utf8.encode(
        styles_xml.replace(old="<sz val=\"12\"/>", new="<sz val=\"NaN\"/>"),
      ),
    ),
  )
  let result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(@zip.write(archive)),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(@xlsx.XlsxError::InvalidXml(_)))
}

///|
test "XLSX displayed text preserves formula results formatted to blank" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Data"))
  let style_id = workbook.new_style(@xlsx.Style::number_format(";;;"))
  workbook.set_cell_formula("Data", "A1", "1+0", value="1")
  workbook.set_cell_style("Data", "A1", style_id)
  let archive = try! @zip.read(@xlsx.write(workbook))
  guard archive.get("xl/worksheets/sheet1.xml") is Some(sheet_bytes) else {
    fail("missing worksheet part")
  }
  let sheet_xml = try! @utf8.decode(sheet_bytes, ignore_bom=true)
  assert_true(sheet_xml.contains(" t=\"str\""))
  // Formula setters retain string compatibility. Remove t="str" to model a
  // normal OOXML cached numeric formula result.
  assert_true(
    archive.replace(
      "xl/worksheets/sheet1.xml",
      @utf8.encode(sheet_xml.replace(old=" t=\"str\"", new="")),
    ),
  )
  let projection = make_xlsx_projection(
    "blank-display.xlsx",
    try! @xlsx.read(@zip.write(archive)),
    10,
  )
  let under = Some(
    resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Data\"]"),
  )
  guard xlsx_text_data(projection, under, 0, 10) is Object(text) else {
    fail("expected text result")
  }
  assert_eq(text.get("matched_total"), Some(Json::number(0)))
  guard xlsx_get_data(
      projection,
      resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Data\"]/cell[A1]"),
    )
    is Object(get) &&
    get.get("cell") is Some(Object(cell)) else {
    fail("expected formula cell")
  }
  assert_eq(cell.get("value"), Some(Json::string("")))
  assert_eq(cell.get("formula"), Some(Json::string("1+0")))
}

///|
test "XLSX cached empty formula results remain distinct from a missing cache" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.new_sheet("Data"))
  workbook.set_cell_formula("Data", "A1", "1+0")
  let archive = @zip.read(@xlsx.write(workbook))
  guard archive.get("xl/worksheets/sheet1.xml") is Some(sheet_bytes) else {
    fail("missing formula worksheet")
  }
  let sheet_xml = @utf8.decode(sheet_bytes, ignore_bom=true)
  assert_true(sheet_xml.contains("<f>1+0</f></c>"))
  let cached_xml = sheet_xml
    .replace(old="<c r=\"A1\"", new="<c r=\"A1\" t=\"str\"")
    .replace(old="<f>1+0</f></c>", new="<f>1+0</f><v /></c>")
  assert_true(
    archive.replace("xl/worksheets/sheet1.xml", @utf8.encode(cached_xml)),
  )
  let parsed = @xlsx.read(@zip.write(archive))
  guard parsed.sheet("Data") is Some(parsed_sheet) &&
    parsed_sheet.get_cell_formula_info_rc(1, 1) is Some(info) else {
    fail("expected cached formula metadata")
  }
  assert_true(info.cached_value_present)
  guard parsed_sheet.get_cell_value_raw("A1") is Some(String(raw)) else {
    fail("expected cached empty raw string")
  }
  assert_eq(raw, "")

  // Cached-presence is part of the reader model, so a write/read cycle must
  // retain the explicit empty cache rather than collapsing it to no `<v>`.
  let roundtrip = @zip.read(@xlsx.write(parsed))
  guard roundtrip.get("xl/worksheets/sheet1.xml") is Some(roundtrip_bytes) else {
    fail("missing round-trip formula worksheet")
  }
  let roundtrip_xml = @utf8.decode(roundtrip_bytes, ignore_bom=true)
  assert_true(roundtrip_xml.contains("<f>1+0</f><v></v>"))

  let compact_archive = @zip.read(@xlsx.write(workbook))
  assert_true(
    compact_archive.replace(
      "xl/worksheets/sheet1.xml",
      @utf8.encode(
        sheet_xml
        .replace(old="<c r=\"A1\"", new="<c r=\"A1\" t=\"str\"")
        .replace(old="<f>1+0</f></c>", new="<f>1+0</f><v/></c>"),
      ),
    ),
  )
  let compact = @xlsx.read(@zip.write(compact_archive))
  guard compact.sheet("Data") is Some(compact_sheet) &&
    compact_sheet.get_cell_formula_info_rc(1, 1) is Some(compact_info) else {
    fail("expected compact cached formula metadata")
  }
  assert_true(compact_info.cached_value_present)

  let projection = make_xlsx_projection("cached-empty.xlsx", parsed, 10)
  guard xlsx_get_data(
      projection,
      resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Data\"]/cell[A1]"),
    )
    is Object(get) &&
    get.get("cell") is Some(Object(cell)) else {
    fail("expected cached-empty formula cell")
  }
  assert_eq(cell.get("value"), Some(Json::string("")))
  assert_eq(
    cell.get("raw"),
    Some(
      Json::object({ "type": Json::string("string"), "value": Json::string("") }),
    ),
  )
  guard xlsx_text_data(
      projection,
      Some(resolve_xlsx_selector(projection, "/xlsx/sheet[name=\"Data\"]")),
      0,
      10,
    )
    is Object(text) else {
    fail("expected cached-empty text result")
  }
  assert_eq(text.get("matched_total"), Some(Json::number(0)))
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
