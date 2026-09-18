///|
/// Regression coverage for defect 2 of
/// https://github.com/moonbitlang/office.mbt/issues/264: every generated pivot
/// table carried `cacheId="1"`, so the second pivot in a workbook silently
/// summarized the first pivot's source.
/// Two pivots over two different sources must get distinct cache ids, and each
/// pivot's relationship must point at the cache part named after its own id.
test "issue 264 cache ids for two pivots over two sources" {
  let wb = @xlsx.Workbook::new()
  for sheet in ["A", "B", "Summary"] {
    wb.new_sheet(sheet) |> ignore
  }
  for sheet in ["A", "B"] {
    wb.set_cell_value(sheet, "A1", String("Key"))
    wb.set_cell_value(sheet, "B1", String("Value"))
    wb.set_cell_value(sheet, "A2", String("x"))
    wb.set_cell_value(sheet, "B2", Numeric(1.0))
  }
  let first = @xlsx.PivotTableOptions::new("A!A1:B2", "Summary!A1:C10")
  first.rows.push(@xlsx.PivotTableField::new("Key"))
  first.data.push(@xlsx.PivotTableField::new("Value"))
  let second = @xlsx.PivotTableOptions::new("B!A1:B2", "Summary!E1:G10")
  second.rows.push(@xlsx.PivotTableField::new("Key"))
  second.data.push(@xlsx.PivotTableField::new("Value"))
  let p1 = wb.add_pivot_table(first)
  let p2 = wb.add_pivot_table(second)
  // The value returned to the caller is the id that actually gets written.
  inspect(p1.cache_id, content="1")
  inspect(p2.cache_id, content="2")
  inspect(p1.table_xml.contains("cacheId=\"1\""), content="true")
  inspect(p2.table_xml.contains("cacheId=\"2\""), content="true")
  // ... and it survives the read-back accessor too.
  let summary = wb.get_pivot_tables("Summary")
  inspect(summary.length(), content="2")
  inspect(summary[0].cache_id, content="1")
  inspect(summary[1].cache_id, content="2")

  // Now check the written package: cacheId, cache part name, pivot table
  // relationship and the workbook-level <pivotCaches> entry must all agree.
  let archive = @zip.read(@xlsx.write(wb))
  fn part(path : String) -> String raise {
    match archive.get(path) {
      Some(bytes) => @encoding/utf8.decode(bytes)
      None => fail("missing part \{path}")
    }
  }

  let report = StringBuilder()
  for i in 1..<=2 {
    let table_xml = part("xl/pivotTables/pivotTable\{i}.xml")
    let rels_xml = part("xl/pivotTables/_rels/pivotTable\{i}.xml.rels")
    let cache_id = if table_xml.contains("cacheId=\"1\"") {
      1
    } else if table_xml.contains("cacheId=\"2\"") {
      2
    } else {
      0
    }
    let cache_xml = part("xl/pivotCache/pivotCacheDefinition\{cache_id}.xml")
    let source_sheet = if cache_xml.contains("sheet=\"A\"") { "A" } else { "B" }
    report.write_string("pivotTable\{i}.xml cacheId=\{cache_id}")
    report.write_string(
      " rels->pivotCacheDefinition\{cache_id}.xml=\{rels_xml.contains("pivotCacheDefinition\{cache_id}.xml")}",
    )
    report.write_string(" cache source sheet=\{source_sheet}\n")
  }
  let workbook_xml = part("xl/workbook.xml")
  let start = match workbook_xml.find("<pivotCaches>") {
    Some(pos) => pos
    None => fail("no <pivotCaches> in xl/workbook.xml")
  }
  let stop = match workbook_xml.find("</pivotCaches>") {
    Some(pos) => pos + "</pivotCaches>".length()
    None => fail("unterminated <pivotCaches>")
  }
  report.write_string(workbook_xml[start:stop].to_owned())
  inspect(
    report.to_string(),
    content=(
      #|pivotTable1.xml cacheId=1 rels->pivotCacheDefinition1.xml=true cache source sheet=A
      #|pivotTable2.xml cacheId=2 rels->pivotCacheDefinition2.xml=true cache source sheet=B
      #|<pivotCaches>
      #|    <pivotCache cacheId="1" r:id="rId7"/>
      #|    <pivotCache cacheId="2" r:id="rId8"/>
      #|  </pivotCaches>
    ),
  )
}

///|
/// A pivot added from raw XML keeps cache id 0 until write time; a generated
/// pivot added afterwards must not collide with the id the writer hands out.
test "issue 264 cache ids mix generated and raw pivots" {
  let wb = @xlsx.Workbook::new()
  wb.new_sheet("Data") |> ignore
  wb.new_sheet("Summary") |> ignore
  wb.set_cell_value("Data", "A1", String("Key"))
  wb.set_cell_value("Data", "B1", String("Value"))
  wb.set_cell_value("Data", "A2", String("x"))
  wb.set_cell_value("Data", "B2", Numeric(1.0))
  wb.add_pivot_table_xml(
    "Summary",
    "<pivotTableDefinition name=\"Raw\" cacheId=\"7\"/>",
    "<pivotCacheDefinition/>",
    name="Raw",
  )
  |> ignore
  let options = @xlsx.PivotTableOptions::new("Data!A1:B2", "Summary!E1:G10")
  options.rows.push(@xlsx.PivotTableField::new("Key"))
  options.data.push(@xlsx.PivotTableField::new("Value"))
  let generated = wb.add_pivot_table(options)
  inspect(generated.cache_id, content="1")
  let archive = @zip.read(@xlsx.write(wb))
  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(bytes) => @encoding/utf8.decode(bytes)
    None => fail("missing xl/workbook.xml")
  }
  // The raw pivot keeps cache id 0 in memory and the writer allocates it the
  // next free id (2), which does not collide with the generated pivot's 1.
  inspect(workbook_xml.contains("<pivotCache cacheId=\"1\""), content="true")
  inspect(workbook_xml.contains("<pivotCache cacheId=\"2\""), content="true")
  inspect(
    archive.get("xl/pivotCache/pivotCacheDefinition1.xml") is Some(_),
    content="true",
  )
  inspect(
    archive.get("xl/pivotCache/pivotCacheDefinition2.xml") is Some(_),
    content="true",
  )
}
