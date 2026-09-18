///|
test "integration stream writer ooxml consistency under row volume" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let summary = workbook.add_sheet("Summary")

  let writer = workbook.new_stream_writer("Data")
  writer.set_col_width(1, 3, 14.0)
  writer.set_row("A1", ["A", "B", "Total"])
  for row in 2..<=301 {
    let a = row - 1
    let b = (row - 1) * 2
    let total = a + b
    writer.set_row_cells("A\{row}", [
      @xlsx.StreamCell::new("\{a}"),
      @xlsx.StreamCell::new("\{b}"),
      @xlsx.StreamCell::new("\{total}", formula="SUM(A\{row},B\{row})"),
    ])
  }
  ignore(writer.add_table("A1:C301", "StreamTable", ["A", "B", "Total"]))
  writer.flush()

  summary.set_cell("A1", "Rows")
  summary.set_cell("B1", "300")

  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let data_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing data worksheet xml")
  }
  let data_rels = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing data worksheet rels")
  }
  let table_xml = match archive.get("xl/tables/table1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing table xml")
  }

  inspect(data_xml.contains("<sheetData>"), content="true")
  inspect(data_xml.contains("<tableParts count=\"1\">"), content="true")
  inspect(data_xml.contains("SUM(A2,B2)"), content="true")
  inspect(data_xml.contains("SUM(A301,B301)"), content="true")
  inspect(data_rels.contains("../tables/table1.xml"), content="true")
  inspect(table_xml.contains("name=\"StreamTable\""), content="true")
  inspect(table_xml.contains("ref=\"A1:C301\""), content="true")

  let parsed = @xlsx.read(bytes)
  let data = match parsed.sheet("Data") {
    Some(value) => value
    None => fail("missing parsed data sheet")
  }
  debug_inspect(data.get_row(1), content="[\"A\", \"B\", \"Total\"]")
  debug_inspect(
    data.get_cell_formula("C301"),
    content="Some(\"SUM(A301,B301)\")",
  )
  debug_inspect(data.get_cell("C301"), content="Some(\"900\")")
  let tables = parsed.get_tables("Data")
  inspect(tables.length(), content="1")
  inspect(tables[0].name, content="StreamTable")
}
