///|
test "integration stream writer stress with styles formulas and table" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Data"))

  let writer = workbook.new_stream_writer("Data")
  let style_id = workbook.new_style(Style::number_format("0.00"))
  writer.set_col_width(1, 4, 12.0)
  writer.set_col_style(4, 4, style_id)
  writer.set_row("A1", ["N", "Double", "Triple", "Total"])
  for row in 2..<=1201 {
    let n = row - 1
    let double = n * 2
    let triple = n * 3
    let total = double + triple
    writer.set_row_cells("A\{row}", [
      StreamCell::new("\{n}"),
      StreamCell::new("\{double}"),
      StreamCell::new("\{triple}"),
      StreamCell::new("\{total}", formula="SUM(B\{row}:C\{row})", style_id~),
    ])
  }
  ignore(
    writer.add_table("A1:D1201", "StreamStress", [
      "N", "Double", "Triple", "Total",
    ]),
  )
  writer.flush()

  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }
  let table_xml = match archive.get("xl/tables/table1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing table1.xml")
  }

  inspect(sheet_xml.contains("dimension ref=\"A1:D1201\""), content="true")
  inspect(sheet_xml.contains("<tableParts count=\"1\">"), content="true")
  inspect(sheet_xml.contains("SUM(B2:C2)"), content="true")
  inspect(sheet_xml.contains("SUM(B1201:C1201)"), content="true")
  inspect(sheet_xml.contains(" s=\"\{style_id}\""), content="true")
  inspect(table_xml.contains("name=\"StreamStress\""), content="true")
  inspect(table_xml.contains("ref=\"A1:D1201\""), content="true")

  let parsed = read(bytes)
  let sheet = match parsed.sheet("Data") {
    Some(value) => value
    None => fail("missing parsed Data sheet")
  }
  debug_inspect(
    sheet.get_row(1),
    content="[\"N\", \"Double\", \"Triple\", \"Total\"]",
  )
  debug_inspect(
    sheet.get_cell_formula("D1201"),
    content="Some(\"SUM(B1201:C1201)\")",
  )
  debug_inspect(sheet.get_cell("D1201"), content="Some(\"6000\")")
  debug_inspect(parsed.get_col_style("Data", 4), content="Some(\{style_id})")
  debug_inspect(parsed.get_col_width("Data", 1), content="Some(12)")
  let tables = parsed.get_tables("Data")
  inspect(tables.length(), content="1")
  inspect(tables[0].name, content="StreamStress")
}
