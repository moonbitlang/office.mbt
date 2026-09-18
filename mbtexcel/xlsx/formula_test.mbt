///|
test "formula write and calc chain" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula("A1", "SUM(B1,B2)", value="5")
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("<f>SUM(B1,B2)</f>"), content="true")
  inspect(sheet_xml.contains("<v>5</v>"), content="true")
  let calc_xml = match archive.get("xl/calcChain.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing calcChain.xml")
  }
  inspect(calc_xml.contains("<c r=\"A1\" i=\"1\"/>"), content="true")
  let types_xml = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(types_xml.contains("calcChain"), content="true")
  let rels_xml = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook rels")
  }
  inspect(rels_xml.contains("calcChain"), content="true")
}

///|
test "formula roundtrip" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula_rc(2, 2, "A1*2", value="10")
  let bytes = @xlsx.write(workbook)
  let parsed = @xlsx.read(bytes)
  debug_inspect(parsed.get_cell("Sheet1", "B2"), content="Some(\"10\")")
  debug_inspect(
    parsed.get_cell_formula("Sheet1", "B2"),
    content="Some(\"A1*2\")",
  )
}
