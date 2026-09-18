///|
test "xlsx package fixtures" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "hi")
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook.xml")
  }
  inspect(
    workbook_xml,
    content=(
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      #|  <bookViews>
      #|    <workbookView activeTab="0"/>
      #|  </bookViews>
      #|  <sheets>
      #|    <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
      #|  </sheets>
      #|</workbook>
    ),
  )
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }
  inspect(
    sheet_xml,
    content=(
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      #|  <dimension ref="A1:A1"/>
      #|  <sheetData>
      #|    <row r="1">
      #|      <c r="A1" t="s"><v>0</v></c>
      #|    </row>
      #|  </sheetData>
      #|</worksheet>
    ),
  )
  let shared_xml = match archive.get("xl/sharedStrings.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sharedStrings.xml")
  }
  inspect(
    shared_xml,
    content=(
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="1" uniqueCount="1">
      #|  <si><t>hi</t></si>
      #|</sst>
    ),
  )
  let types_xml = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(types_xml.contains("/xl/worksheets/sheet1.xml"), content="true")
  inspect(types_xml.contains("/xl/workbook.xml"), content="true")
}
