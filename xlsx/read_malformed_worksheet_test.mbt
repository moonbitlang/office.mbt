///|
/// Rebuild a written package with one worksheet-XML substring replaced, so
/// each case below can corrupt exactly one construct. Fails the test if the
/// target substring is absent (the corruption must actually apply).
fn corrupt_sheet1(bytes : Bytes, old : String, new : String) -> Bytes raise {
  let archive = @zip.read(bytes)
  let part = "xl/worksheets/sheet1.xml"
  let sheet_xml = match archive.get(part) {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing \{part}")
  }
  if !sheet_xml.contains(old) {
    fail("corruption target not found in sheet1.xml: \{old}")
  }
  let updated = sheet_xml.replace_all(old~, new~)
  let rebuilt = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() != part {
      rebuilt.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  rebuilt.add(part, @encoding/utf8.encode(updated))
  @zip.write(rebuilt)
}

///|
/// Assert that reading the corrupted package raises InvalidXml.
fn expect_invalid_xml(bytes : Bytes) -> Unit raise {
  let result : Result[@xlsx.Workbook, Error] = Ok(@xlsx.read(bytes)) catch {
    e => Err(e)
  }
  match result {
    Ok(_) => fail("expected InvalidXml for corrupted package")
    Err(@xlsx.XlsxError::InvalidXml(_)) => ()
    Err(err) => fail("unexpected error: \{repr(err)}")
  }
}

///|
/// Malformed structural tags in the worksheet are rejected, not silently
/// tolerated: unclosed mergeCell, invalid page-break and pageSetup numbers,
/// missing filter/hyperlink attributes, and broken tab colors.
test "malformed worksheet constructs are rejected" {
  // merged cell whose element never closes
  let merged = @xlsx.Workbook::new()
  ignore(merged.add_sheet("Sheet1"))
  merged.merge_cells("Sheet1", "A1:B2")
  let merged_bytes = @xlsx.write(merged)
  expect_invalid_xml(
    corrupt_sheet1(merged_bytes, "<mergeCell ref=\"A1:B2\"/>", "<mergeCell "),
  )

  // page margins / page setup with non-numeric attribute values
  let layout = @xlsx.Workbook::new()
  ignore(layout.add_sheet("Sheet1"))
  layout.set_page_margins(
    "Sheet1",
    Some(@xlsx.PageLayoutMarginsOptions::with_values(left=0.25, right=0.3)),
  )
  layout.set_page_layout(
    "Sheet1",
    Some(
      @xlsx.PageLayoutOptions::with_values(
        size=9,
        first_page_number=7,
        adjust_to=85,
        fit_to_height=2,
        fit_to_width=3,
      ),
    ),
  )
  let layout_bytes = @xlsx.write(layout)
  expect_invalid_xml(
    corrupt_sheet1(layout_bytes, "left=\"0.25\"", "left=\"wide\""),
  )
  expect_invalid_xml(
    corrupt_sheet1(layout_bytes, "paperSize=\"9\"", "paperSize=\"A4\""),
  )
  expect_invalid_xml(
    corrupt_sheet1(
      layout_bytes, "firstPageNumber=\"7\"", "firstPageNumber=\"x\"",
    ),
  )
  expect_invalid_xml(
    corrupt_sheet1(layout_bytes, "fitToHeight=\"2\"", "fitToHeight=\"tall\""),
  )

  // page breaks with a mangled id / max
  let breaks = @xlsx.Workbook::new()
  ignore(breaks.add_sheet("Sheet1"))
  breaks.insert_page_break("Sheet1", "A25")
  let break_bytes = @xlsx.write(breaks)
  expect_invalid_xml(corrupt_sheet1(break_bytes, "id=\"24\"", "id=\"row\""))

  // auto filter: missing ref, then missing colId
  let filtered = @xlsx.Workbook::new()
  ignore(filtered.add_sheet("Sheet1"))
  filtered.set_cell("Sheet1", "A1", "Name")
  filtered.set_auto_filter("Sheet1", "A1:C3", [
    { column: "B", expression: "x > 5" },
  ])
  let filter_bytes = @xlsx.write(filtered)
  expect_invalid_xml(
    corrupt_sheet1(filter_bytes, "<autoFilter ref=\"A1:C3\"", "<autoFilter "),
  )
  expect_invalid_xml(corrupt_sheet1(filter_bytes, "colId=\"1\"", "col=\"1\""))

  // hyperlink without its cell reference
  let linked = @xlsx.Workbook::new()
  ignore(linked.add_sheet("Sheet1"))
  linked.set_cell("Sheet1", "A1", "link")
  linked.set_cell_hyperlink("Sheet1", "A1", "https://example.com", External)
  let linked_bytes = @xlsx.write(linked)
  expect_invalid_xml(
    corrupt_sheet1(linked_bytes, "<hyperlink ref=\"A1\"", "<hyperlink "),
  )

  // tab color with a non-numeric theme, then invalid sheetFormatPr width
  let props = @xlsx.Workbook::new()
  ignore(props.add_sheet("Sheet1"))
  props.set_sheet_props(
    "Sheet1",
    Some(
      @xlsx.SheetPropsOptions::with_values(
        tab_color_theme=5,
        tab_color_tint=-0.3,
        base_col_width=12,
      ),
    ),
  )
  let props_bytes = @xlsx.write(props)
  expect_invalid_xml(
    corrupt_sheet1(props_bytes, "theme=\"5\"", "theme=\"accent\""),
  )
  expect_invalid_xml(
    corrupt_sheet1(props_bytes, "tint=\"-0.3\"", "tint=\"dark\""),
  )
  expect_invalid_xml(
    corrupt_sheet1(props_bytes, "baseColWidth=\"12\"", "baseColWidth=\"wide\""),
  )
}

///|
/// A cfRule with no type attribute is dropped by the tolerant reader — the
/// range entry survives but holds no parsed rules — while a sheetProtection
/// spinCount that is not a number fails at read time.
test "cfRule without type is tolerated and malformed protection is rejected" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opt = @xlsx.ConditionalFormatOptions::new("cell")
  opt.set_criteria(">")
  opt.set_value("6")
  workbook.set_conditional_format("Sheet1", "A1:A5", [opt])
  workbook.protect_sheet(
    "Sheet1",
    @xlsx.SheetProtectionOptions::with_values(
      algorithm_name="SHA-512",
      password="pw",
      sort=true,
    ),
  )
  let bytes = @xlsx.write(workbook)
  let no_type = @xlsx.read(
    corrupt_sheet1(bytes, "type=\"cellIs\"", "kind=\"cellIs\""),
  )
  let no_type_formats = no_type.get_conditional_formats("Sheet1")
  let rule_count = match no_type_formats.get("A1:A5") {
    Some(rules) => rules.length()
    None => -1
  }
  inspect(
    "ranges=\{no_type_formats.size()} rules=\{rule_count}",
    content=(
      #|ranges=1 rules=0
    ),
  )
  expect_invalid_xml(
    corrupt_sheet1(bytes, "spinCount=\"100000\"", "spinCount=\"lots\""),
  )
}

///|
/// A definedName element that never closes is rejected (workbook.xml).
test "malformed defined name is rejected" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(@xlsx.DefinedName::new("block", "Sheet1!$A$1"))
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let part = "xl/workbook.xml"
  let workbook_xml = @encoding/utf8.decode(archive.get(part).unwrap())
  inspect(workbook_xml.contains("</definedName>"), content="true")
  let updated = workbook_xml.replace_all(old="</definedName>", new="")
  let rebuilt = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() != part {
      rebuilt.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  rebuilt.add(part, @encoding/utf8.encode(updated))
  expect_invalid_xml(@zip.write(rebuilt))
}
