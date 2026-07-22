///|
/// White-box nets for the row-addressed state inventory and the read-time
/// package feature flags (#207 R2a): classes that only file reads or
/// internal state can produce are staged directly on the structs.

///|
fn wb_inventory_entry(
  entries : Array[RowStateEntry],
  class : RowStateClass,
) -> RowStateEntry? {
  for entry in entries {
    if entry.class == class {
      return Some(entry)
    }
  }
  None
}

///|
test "inventory: API-built classes report parsed extents and insert handling" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_value("A1", String("head"))
  sheet.set_cell_value("B7", Numeric(3.5))
  workbook.merge_cells("Data", "A2:C2")
  workbook.set_row_height("Data", 9, 24.0)
  let entries = workbook.sheet_row_state_inventory("Data")
  assert_eq(
    wb_inventory_entry(entries, Cells),
    Some({ class: Cells, extent: RowsUpTo(7), handling: ShiftedByInsert }),
  )
  assert_eq(
    wb_inventory_entry(entries, MergedRanges),
    Some({ class: MergedRanges, extent: RowsUpTo(2), handling: ShiftedByInsert }),
  )
  assert_eq(
    wb_inventory_entry(entries, RowDimensions),
    Some({
      class: RowDimensions,
      extent: RowsUpTo(9),
      handling: ShiftedByInsert,
    }),
  )
  // absent classes are omitted
  assert_eq(wb_inventory_entry(entries, TableRanges), None)
  assert_eq(wb_inventory_entry(entries, DefinedNameReferences), None)
}

///|
test "inventory: defined names classify by the adjuster, not scope" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Data"))
  ignore(workbook.add_sheet("Other"))
  // workbook-scoped but QUALIFIED to Data: the staging rewrites it, so
  // Data's inventory must carry it with the parsed row bound
  workbook.set_defined_name(DefinedName::new("wb_ref", "Data!$A$1048576"))
  // scoped to Data but UNQUALIFIED: the adjuster never touches its text
  workbook.set_defined_name(DefinedName::new("bare", "$A$9", scope="Data"))
  let data = workbook.sheet_row_state_inventory("Data")
  assert_eq(
    wb_inventory_entry(data, DefinedNameReferences),
    Some({
      class: DefinedNameReferences,
      extent: RowsUpTo(1048576),
      handling: ShiftedByInsert,
    }),
  )
  assert_eq(
    wb_inventory_entry(data, SheetScopedNamesUnadjusted),
    Some({
      class: SheetScopedNamesUnadjusted,
      extent: WholeSheet,
      handling: StaticOnWrite,
    }),
  )
  // Other has no qualified refs and no scoped names: nothing appears
  let other = workbook.sheet_row_state_inventory("Other")
  assert_eq(wb_inventory_entry(other, DefinedNameReferences), None)
  assert_eq(wb_inventory_entry(other, SheetScopedNamesUnadjusted), None)
}

///|
test "inventory: sparkline extent folds the source range" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.sparkline_groups.push({
    sparkline_type: Line,
    sparklines: [{ range_ref: "A100:A200", location: "F2" }],
    options: SparklineGroupOptions::new(),
  })
  let entries = sheet.row_state_inventory()
  assert_eq(
    wb_inventory_entry(entries, SparklineAnchors),
    Some({
      class: SparklineAnchors,
      extent: RowsUpTo(200),
      handling: ShiftedByInsert,
    }),
  )
}

///|
test "inventory: opaque and internal-state classes degrade to whole-sheet" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.unknown_ext_blocks.push("<ext uri=\"{x}\"/>")
  sheet.vml_drawing_xml = Some("<xml/>")
  sheet.cell_vm["B3"] = 1
  sheet.hyperlinks.push({
    reference: "C4",
    target: "https://example.com/page",
    link_type: External,
    location: Some("Sheet1!A1"),
    display: None,
    tooltip: None,
  })
  // an unparsable merge reference degrades that class, not the sheet
  sheet.merged_cells.push("NOT A RANGE")
  let entries = sheet.row_state_inventory()
  assert_eq(
    wb_inventory_entry(entries, UnknownExtensions),
    Some({
      class: UnknownExtensions,
      extent: WholeSheet,
      handling: StaticOnWrite,
    }),
  )
  assert_eq(
    wb_inventory_entry(entries, VmlContent),
    Some({ class: VmlContent, extent: WholeSheet, handling: StaticOnWrite }),
  )
  assert_eq(
    wb_inventory_entry(entries, CellValueMetadata),
    Some({
      class: CellValueMetadata,
      extent: RowsUpTo(3),
      handling: DroppedByWriter,
    }),
  )
  assert_eq(
    wb_inventory_entry(entries, HyperlinkAnchors),
    Some({
      class: HyperlinkAnchors,
      extent: RowsUpTo(4),
      handling: ShiftedByInsert,
    }),
  )
  assert_eq(
    wb_inventory_entry(entries, InternalLinkTargets),
    Some({
      class: InternalLinkTargets,
      extent: WholeSheet,
      handling: StaticOnWrite,
    }),
  )
  assert_eq(
    wb_inventory_entry(entries, MergedRanges),
    Some({ class: MergedRanges, extent: WholeSheet, handling: ShiftedByInsert }),
  )
}

///|
test "inventory: row breaks use one-based rows from zero-based ids" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.row_breaks.push({ id: 41, min: 0, max: 16383, manual: true })
  let entries = sheet.row_state_inventory()
  assert_eq(
    wb_inventory_entry(entries, RowPageBreaks),
    Some({
      class: RowPageBreaks,
      extent: RowsUpTo(42),
      handling: ShiftedByInsert,
    }),
  )
}

///|
test "stored formula presence counts empty formula text" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_value("A1", String("plain"))
  assert_eq(sheet.first_stored_formula_cell(), None)
  // shared-formula followers store Some("") — the presence test must see
  // them even though formula_refs() excludes empty text
  sheet.cells.push({
    reference: "B2",
    row: 2,
    col: 2,
    value: "0",
    value_type: Number,
    rich_text: None,
    formula: Some(""),
    formula_type: None,
    formula_ref: None,
    formula_shared_index: None,
    formula_value_present: true,
    style_explicit: false,
    style_id: 0,
  })
  sheet.cell_index_valid = false
  assert_eq(sheet.first_stored_formula_cell(), Some("B2"))
}

///|
test "package feature detection classifies the raw part list" {
  let names : Map[String, String] = {}
  for
    physical in [
      "[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels",
      "xl/worksheets/sheet1.xml", "xl/styles.xml", "xl/theme/theme1.xml", "docProps/core.xml",
      "docProps/app.xml", "xl/externalLinks/externalLink1.xml", "xl/queryTables/queryTable1.xml",
      "xl/connections.xml", "xl/pivotCache/pivotCacheDefinition1.xml", "xl/drawings/vmlDrawing1.vml",
      "xl/unexpected/blob.bin",
    ] {
    names[physical.to_lower()] = physical
  }
  let features = detect_package_features(names, _ => None)
  assert_true(features.external_links)
  assert_eq(
    features.first_external_link,
    Some("xl/externalLinks/externalLink1.xml"),
  )
  assert_true(features.query_tables)
  assert_true(features.connections)
  assert_true(features.pivot_parts)
  assert_eq(
    features.first_pivot_part,
    Some("xl/pivotCache/pivotCacheDefinition1.xml"),
  )
  assert_true(features.vml_present)
  assert_eq(features.first_vml_part, Some("xl/drawings/vmlDrawing1.vml"))
  assert_true(features.unknown_parts)
  assert_eq(features.first_unknown_part, Some("xl/unexpected/blob.bin"))
}

///|
test "package feature detection stays quiet for a conventional package" {
  let names : Map[String, String] = {}
  for
    physical in [
      "[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels",
      "xl/worksheets/sheet1.xml", "xl/worksheets/_rels/sheet1.xml.rels", "xl/styles.xml",
      "xl/sharedStrings.xml", "xl/theme/theme1.xml", "xl/calcChain.xml", "xl/tables/table1.xml",
      "xl/media/image1.png", "xl/drawings/drawing1.xml", "xl/charts/chart1.xml",
      "xl/printerSettings/printerSettings1.bin", "customXml/item1.xml", "docProps/core.xml",
      "docProps/app.xml", "docProps/custom.xml",
    ] {
    names[physical.to_lower()] = physical
  }
  assert_eq(
    detect_package_features(names, _ => None),
    XlsxPackageFeatures::none(),
  )
}

///|
test "table source formulas flag threads through parse and workbook scan" {
  let clean = parse_table_xml(
    (
      #|<table xmlns="x" id="1" name="T1" displayName="T1" ref="A1:B3" headerRowCount="1"><tableColumns count="2"><tableColumn id="1" name="Alpha"/><tableColumn id="2" name="Beta"/></tableColumns></table>
    ),
  )
  assert_false(clean.carries_source_formulas)
  let carrying = parse_table_xml(
    (
      #|<table xmlns="x" id="2" name="T2" displayName="T2" ref="A1:B3" headerRowCount="1"><tableColumns count="2"><tableColumn id="1" name="Alpha"/><tableColumn id="2" name="Total"><calculatedColumnFormula>Alpha*2</calculatedColumnFormula></tableColumn></tableColumns></table>
    ),
  )
  assert_true(carrying.carries_source_formulas)
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Data")
  assert_eq(workbook.first_table_with_source_formulas(), None)
  sheet.tables.push(carrying)
  assert_eq(workbook.first_table_with_source_formulas(), Some(("Data", "T2")))
}

///|
test "clear_dimension_ref makes the writer recompute" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_value("A1", String("x"))
  // simulate the read path: a stale stored dimension is echoed verbatim
  sheet.dimension_ref = Some("A1:Z99")
  let stale = write(workbook)
  let stale_xml = zip_entry_text(stale, "xl/worksheets/sheet1.xml")
  assert_true(stale_xml.find("<dimension ref=\"A1:Z99\"/>") is Some(_))
  sheet.clear_dimension_ref()
  let fresh = write(workbook)
  let fresh_xml = zip_entry_text(fresh, "xl/worksheets/sheet1.xml")
  assert_true(fresh_xml.find("<dimension ref=\"A1:A1\"/>") is Some(_))
}

///|
fn zip_entry_text(bytes : Bytes, entry : String) -> String raise {
  let archive = @zip.read(bytes)
  match archive.get(entry) {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("entry not found: " + entry)
  }
}

///|
test "inventory handling labels match actual insert behavior" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_value("A10", String("below"))
  workbook.merge_cells("Data", "A8:B8")
  sheet.add_comment({
    cell: "A9",
    author: "a",
    author_id: None,
    text: "note",
    paragraph: [],
    width: None,
    height: None,
  })
  sheet.ignored_errors.push({
    sqref: "A9",
    eval_error: false,
    two_digit_text_year: false,
    number_stored_as_text: true,
    formula: false,
    formula_range: false,
    unlocked_formula: false,
    empty_cell_reference: false,
    list_data_validation: false,
    calculated_column: false,
  })
  workbook.insert_rows("Data", 5, 2)
  // ShiftedByInsert classes moved with the content
  assert_eq(workbook.get_merge_cells("Data"), ["A10:B10"])
  assert_true(sheet.first_stored_formula_cell() is None)
  let mut shifted_cell = false
  for cell in sheet.cells {
    if cell.reference == "A12" {
      shifted_cell = true
    }
  }
  assert_true(shifted_cell)
  // StaticOnWrite classes kept their original coordinates (the honest,
  // uncomfortable fact the inventory reports)
  assert_eq(sheet.comments.length(), 1)
  assert_eq(sheet.comments[0].cell, "A9")
  assert_eq(sheet.ignored_errors[0].sqref, "A9")
}

///|
test "package feature detection: declared content types beat inert paths" {
  let names : Map[String, String] = {}
  for
    physical in [
      "xl/media/link.xml", "xl/media/macro.xml", "xl/preservedDrawingParts/part1.bin",
    ] {
    names[physical.to_lower()] = physical
  }
  let types : Map[String, String] = {
    "xl/media/link.xml": "application/vnd.openxmlformats-officedocument.spreadsheetml.externalLink+xml",
    "xl/media/macro.xml": "application/vnd.ms-excel.macrosheet+xml",
  }
  let features = detect_package_features(names, name => types.get(name))
  // the round-1 fail-open shape: an external-link part hidden under an
  // inert-looking path is classified by its manifest type
  assert_true(features.external_links)
  assert_eq(features.first_external_link, Some("xl/media/link.xml"))
  // formula-capable macrosheets fold into unknown_parts
  assert_true(features.unknown_parts)
  assert_eq(features.first_unknown_part, Some("xl/media/macro.xml"))
  // the writer's own preserved-drawing payloads are known-inert
  assert_false(features.vml_present)
}

///|
test "library output with rich features stays classified" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_value("A1", String("x"))
  sheet.add_comment({
    cell: "B2",
    author: "a",
    author_id: None,
    text: "note",
    paragraph: [],
    width: None,
    height: None,
  })
  let chart_xml =
    #|<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart">
    #|  <c:chart/>
    #|</c:chartSpace>
  sheet.add_chart("C3", chart_xml)
  let parsed = read(write(workbook))
  let features = parsed.package_features()
  // the library's own conventional output never counts as unknown
  assert_false(features.unknown_parts)
  assert_false(features.external_links)
  assert_false(features.query_tables)
  assert_false(features.connections)
  assert_false(features.pivot_parts)
  // comments legitimately raise the VML flag: the writer emits legacy
  // VML comment boxes, and VML is opaque static content on read
  assert_true(features.vml_present)
  assert_eq(features.first_vml_part, Some("xl/drawings/vmlDrawing1.vml"))
}
