///|
test "pivot table write and relationships" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  ignore(
    sheet.add_pivot_table_xml(
      "<pivotTableDefinition name=\"Pivot1\"/>",
      "<pivotCacheDefinition/>",
      cache_records_xml="<pivotCacheRecords/>",
    ),
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("<pivotTableParts count=\"1\">"), content="true")
  inspect(sheet_xml.contains("r:id=\"rId1\""), content="true")
  let rels_xml = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml.rels utf8 decode failed")
      }
    None => fail("missing sheet1.xml.rels")
  }
  inspect(rels_xml.contains("relationships/pivotTable"), content="true")
  inspect(rels_xml.contains("../pivotTables/pivotTable1.xml"), content="true")
  let pivot_xml = match archive.get("xl/pivotTables/pivotTable1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("pivotTable1.xml utf8 decode failed")
      }
    None => fail("missing pivotTable1.xml")
  }
  inspect(pivot_xml.contains("pivotTableDefinition"), content="true")
  let pivot_rels = match
    archive.get("xl/pivotTables/_rels/pivotTable1.xml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("pivotTable1.xml.rels utf8 decode failed")
      }
    None => fail("missing pivotTable1.xml.rels")
  }
  inspect(pivot_rels.contains("pivotCacheDefinition1.xml"), content="true")
  let cache_xml = match archive.get("xl/pivotCache/pivotCacheDefinition1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("pivotCacheDefinition1.xml utf8 decode failed")
      }
    None => fail("missing pivotCacheDefinition1.xml")
  }
  inspect(cache_xml.contains("pivotCacheDefinition"), content="true")
  let cache_rels = match
    archive.get("xl/pivotCache/_rels/pivotCacheDefinition1.xml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("pivot cache rels utf8 decode failed")
      }
    None => fail("missing pivot cache rels")
  }
  inspect(cache_rels.contains("pivotCacheRecords1.xml"), content="true")
  let records_xml = match archive.get("xl/pivotCache/pivotCacheRecords1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("pivotCacheRecords1.xml utf8 decode failed")
      }
    None => fail("missing pivotCacheRecords1.xml")
  }
  inspect(records_xml.contains("pivotCacheRecords"), content="true")
  let workbook_rels = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("workbook.xml.rels utf8 decode failed")
      }
    None => fail("missing workbook.xml.rels")
  }
  inspect(workbook_rels.contains("pivotCacheDefinition1.xml"), content="true")
}

///|
test "pivot table roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  ignore(
    sheet.add_pivot_table_xml(
      "<pivotTableDefinition name=\"Pivot2\"/>",
      "<pivotCacheDefinition cacheId=\"2\"/>",
      cache_records_xml="<pivotCacheRecords count=\"0\"/>",
    ),
  )
  let parsed = read(write(workbook))
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(parsed_sheet.pivot_tables().length(), content="1")
  let pivot = parsed_sheet.pivot_tables()[0]
  inspect(pivot.name, content="Pivot2")
  inspect(pivot.table_id, content="1")
  inspect(pivot.cache_id, content="1")
  inspect(pivot.table_xml, content="<pivotTableDefinition name=\"Pivot2\"/>")
  inspect(
    pivot.cache_definition_xml,
    content="<pivotCacheDefinition cacheId=\"2\"/>",
  )
  inspect(
    pivot.cache_records_xml,
    content="Some(\"<pivotCacheRecords count=\\\"0\\\"/>\")",
  )
}

///|
test "pivot table validation" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let result = try
    sheet.add_pivot_table_xml("", "<pivotCacheDefinition/>")
  catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    result,
    content="Err(InvalidPivotTable(msg=\"pivot table xml empty\"))",
  )
}

///|
test "pivot table add/get/delete" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(
    workbook.add_pivot_table(
      "Sheet1",
      "<pivotTableDefinition name=\"PivotA\"/>",
      "<pivotCacheDefinition/>",
      name="PivotA",
    ),
  )
  let pivots = workbook.get_pivot_tables("Sheet1")
  inspect(pivots.length(), content="1")
  inspect(pivots[0].name, content="PivotA")
  workbook.delete_pivot_table("Sheet1", "PivotA")
  inspect(workbook.get_pivot_tables("Sheet1").length(), content="0")
}
