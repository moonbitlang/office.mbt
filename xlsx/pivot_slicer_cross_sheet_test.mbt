///|
fn count_substr(text : StringView, needle : StringView) -> Int {
  let mut count = 0
  let mut rest = text.to_owned()
  while true {
    match rest.find(needle) {
      Some(idx) => {
        count = count + 1
        rest = rest[idx + needle.length():].to_owned()
      }
      None => break
    }
  }
  count
}

///|
test "pivot+slicer cross-sheet multi-cache corpus" {
  let workbook = Workbook::new()
  let sheet_a = workbook.add_sheet("DataA")
  let sheet_b = workbook.add_sheet("DataB")
  ignore(workbook.add_sheet("Dash"))

  for row in 1..<=4 {
    sheet_a.set_cell_value("A\{row}", String("Region\{row}"))
    sheet_a.set_cell_value("B\{row}", Numeric(Double::from_int(row)))
    sheet_b.set_cell_value("A\{row}", String("Zone\{row}"))
    sheet_b.set_cell_value("B\{row}", Numeric(Double::from_int(row * 10)))
  }

  ignore(
    workbook.add_table_with_columns("DataA", "A1:B4", "TableA", [
      "Region", "Value",
    ]),
  )
  ignore(
    workbook.add_table_with_columns("DataB", "A1:B4", "TableB", [
      "Region", "Value",
    ]),
  )

  ignore(
    workbook.add_pivot_table_xml(
      "DataA",
      "<pivotTableDefinition name=\"PivotA\"/>",
      "<pivotCacheDefinition><cacheFields count=\"1\"><cacheField name=\"Region\"/></cacheFields></pivotCacheDefinition>",
      name="PivotA",
    ),
  )
  ignore(
    workbook.add_pivot_table_xml(
      "DataB",
      "<pivotTableDefinition name=\"PivotB\"/>",
      "<pivotCacheDefinition><cacheFields count=\"1\"><cacheField name=\"Region\"/></cacheFields></pivotCacheDefinition>",
      name="PivotB",
    ),
  )

  let table_a = SlicerOptions::new("Region", "A1", "DataA", "TableA")
  let table_b = SlicerOptions::new("Region", "A20", "DataB", "TableB")
  let pivot_a = SlicerOptions::new("Region", "H1", "DataA", "PivotA")
  let pivot_b = SlicerOptions::new("Region", "H20", "DataB", "PivotB")

  workbook.add_slicer("Dash", table_a)
  workbook.add_slicer("Dash", table_b)
  workbook.add_slicer("Dash", pivot_a)
  workbook.add_slicer("Dash", pivot_b)

  let bytes = write(workbook)
  let archive = @zip.read(bytes)

  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook.xml")
  }
  inspect(workbook_xml.contains("<x14:slicerCaches"), content="true")
  inspect(workbook_xml.contains("<x15:slicerCaches"), content="true")

  let mut cache_files = 0
  for i in 1..<=6 {
    match archive.get("xl/slicerCaches/slicerCache\{i}.xml") {
      Some(value) => {
        cache_files = cache_files + 1
        ignore(@encoding/utf8.decode(value))
      }
      None => ()
    }
  }
  inspect(cache_files, content="4")

  let rels_xml = match archive.get("xl/worksheets/_rels/sheet3.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing dash sheet rels")
  }
  inspect(count_substr(rels_xml, "relationships/slicer"), content="2")

  let mut slicer_parts = 0
  let mut slicer_entry_count = 0
  for i in 1..<=4 {
    match archive.get("xl/slicers/slicer\{i}.xml") {
      Some(value) => {
        slicer_parts = slicer_parts + 1
        let xml = @encoding/utf8.decode(value)
        slicer_entry_count = slicer_entry_count +
          count_substr(xml, "<slicer name=")
      }
      None => ()
    }
  }
  inspect(slicer_parts, content="2")
  inspect(slicer_entry_count, content="4")

  let parsed = read(bytes)
  let slicers = parsed.get_slicers("Dash")
  inspect(slicers.length(), content="4")

  let mut found_table_a = false
  let mut found_table_b = false
  let mut found_pivot_a = false
  let mut found_pivot_b = false
  for slicer in slicers {
    if slicer.table_sheet == "DataA" && slicer.table_name == "TableA" {
      found_table_a = true
    }
    if slicer.table_sheet == "DataB" && slicer.table_name == "TableB" {
      found_table_b = true
    }
    if slicer.table_sheet == "DataA" && slicer.table_name == "PivotA" {
      found_pivot_a = true
    }
    if slicer.table_sheet == "DataB" && slicer.table_name == "PivotB" {
      found_pivot_b = true
    }
  }
  inspect(found_table_a, content="true")
  inspect(found_table_b, content="true")
  inspect(found_pivot_a, content="true")
  inspect(found_pivot_b, content="true")
}
