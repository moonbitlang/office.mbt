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
    workbook.add_pivot_table_xml(
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

///|
test "pivot table options builder write" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("Region"))
  sheet.set_cell_value("B1", CellValue::String("Type"))
  sheet.set_cell_value("C1", CellValue::String("Sales"))
  sheet.set_cell_value("A2", CellValue::String("East"))
  sheet.set_cell_value("B2", CellValue::String("A"))
  sheet.set_cell_value("C2", CellValue::Numeric(10.0))
  sheet.set_cell_value("A3", CellValue::String("West"))
  sheet.set_cell_value("B3", CellValue::String("B"))
  sheet.set_cell_value("C3", CellValue::Numeric(20.0))
  sheet.set_cell_value("A4", CellValue::String("East"))
  sheet.set_cell_value("B4", CellValue::String("B"))
  sheet.set_cell_value("C4", CellValue::Numeric(30.0))
  let opts = PivotTableOptions::new("Sheet1!A1:C4", "Sheet1!E2:H10")
  opts.rows.push(PivotTableField::new("Region"))
  opts.columns.push(PivotTableField::new("Type"))
  opts.data.push(PivotTableField::new("Sales"))
  let pivot = workbook.add_pivot_table(opts)
  inspect(pivot.name, content="PivotTable1")
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let pivot_xml = match archive.get("xl/pivotTables/pivotTable1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing pivotTable1.xml")
  }
  inspect(pivot_xml.contains("pivotTableDefinition"), content="true")
  inspect(pivot_xml.contains("name=\"PivotTable1\""), content="true")
  inspect(pivot_xml.contains("rowGrandTotals=\"1\""), content="true")
  inspect(pivot_xml.contains("colGrandTotals=\"1\""), content="true")
  inspect(pivot_xml.contains("showDrill=\"1\""), content="true")
  inspect(pivot_xml.contains("useAutoFormatting=\"0\""), content="true")
  inspect(pivot_xml.contains("pageOverThenDown=\"0\""), content="true")
  inspect(pivot_xml.contains("mergeItem=\"0\""), content="true")
  inspect(pivot_xml.contains("compactData=\"0\""), content="true")
  inspect(pivot_xml.contains("gridDropZones=\"0\""), content="true")
  inspect(pivot_xml.contains("showError=\"0\""), content="true")
  inspect(pivot_xml.contains("fieldPrintTitles=\"0\""), content="true")
  inspect(pivot_xml.contains("itemPrintTitles=\"0\""), content="true")
  inspect(pivot_xml.contains("<rowItems count=\"1\">"), content="true")
  inspect(pivot_xml.contains("<colItems count=\"1\">"), content="true")
  inspect(pivot_xml.contains("axis=\"axisRow\""), content="true")
  inspect(pivot_xml.contains("axis=\"axisCol\""), content="true")
  inspect(pivot_xml.contains("dataField=\"1\""), content="true")
  inspect(pivot_xml.contains("<items count=\"1\">"), content="true")
  let cache_xml = match archive.get("xl/pivotCache/pivotCacheDefinition1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing pivotCacheDefinition1.xml")
  }
  inspect(cache_xml.contains("worksheetSource"), content="true")
  inspect(cache_xml.contains("ref=\"A1:C4\""), content="true")
  inspect(cache_xml.contains("sheet=\"Sheet1\""), content="true")
  inspect(cache_xml.contains("cacheFields count=\"3\""), content="true")
  inspect(cache_xml.contains("cacheField name=\"Region\""), content="true")
}

///|
test "pivot table options compactData classic layout invalid" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = PivotTableOptions::new("Sheet1!A1:C4", "Sheet1!E2:H10")
  opts.compact_data = true
  opts.classic_layout = true
  let result : Result[Unit, Error] = try
    ignore(workbook.add_pivot_table(opts))
  catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    result,
    content=(
      #|Err(InvalidPivotTable(msg="pivot compactData is incompatible with classic layout"))
    ),
  )
}

///|
test "pivot table options default name increments" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("Region"))
  sheet.set_cell_value("B1", CellValue::String("Type"))
  sheet.set_cell_value("C1", CellValue::String("Sales"))
  sheet.set_cell_value("A2", CellValue::String("East"))
  sheet.set_cell_value("B2", CellValue::String("A"))
  sheet.set_cell_value("C2", CellValue::Numeric(10.0))
  let opts1 = PivotTableOptions::new("Sheet1!A1:C2", "Sheet1!E2:H10")
  opts1.rows.push(PivotTableField::new("Region"))
  opts1.data.push(PivotTableField::new("Sales"))
  let pivot1 = workbook.add_pivot_table(opts1)
  inspect(pivot1.name, content="PivotTable1")
  let opts2 = PivotTableOptions::new("Sheet1!A1:C2", "Sheet1!E20:H30")
  opts2.rows.push(PivotTableField::new("Region"))
  opts2.data.push(PivotTableField::new("Sales"))
  let pivot2 = workbook.add_pivot_table(opts2)
  inspect(pivot2.name, content="PivotTable2")
}

///|
test "pivot table options name length and data range validation" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", CellValue::String("Region"))
  sheet.set_cell_value("B1", CellValue::String("Sales"))
  sheet.set_cell_value("A2", CellValue::String("East"))
  sheet.set_cell_value("B2", CellValue::Numeric(10.0))
  let long = "c".repeat(256)
  let opts = PivotTableOptions::new("Sheet1!A1:B2", "Sheet1!E2:H10")
  opts.name = long
  opts.rows.push(PivotTableField::new("Region"))
  opts.data.push(PivotTableField::new("Sales"))
  let name_result : Result[Unit, Error] = try
    ignore(workbook.add_pivot_table(opts))
  catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(name_result is Err(XlsxError::InvalidPivotTable(_)), content="true")
  let bad_opts = PivotTableOptions::new("Sheet1!A1:A1", "Sheet1!E2:H10")
  let range_result : Result[Unit, Error] = try
    ignore(workbook.add_pivot_table(bad_opts))
  catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(range_result is Err(XlsxError::InvalidPivotTable(_)), content="true")
}
