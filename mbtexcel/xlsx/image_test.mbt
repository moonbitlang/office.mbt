///|
test "image drawing package" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_image("B2", b"img", "png", "image/png")
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let image = match archive.get("xl/media/image1.png") {
    Some(value) => value
    None => fail("missing image")
  }
  inspect(image == b"img", content="true")
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1")
  }
  inspect(sheet_xml.contains("<drawing r:id=\"rId1\"/>"), content="true")
  let sheet_rels = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet rels")
  }
  inspect(sheet_rels.contains("drawing1.xml"), content="true")
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("<xdr:col>1</xdr:col>"), content="true")
  inspect(drawing_xml.contains("<xdr:row>1</xdr:row>"), content="true")
  inspect(drawing_xml.contains("rId1"), content="true")
  let drawing_rels = match archive.get("xl/drawings/_rels/drawing1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing rels")
  }
  inspect(drawing_rels.contains("../media/image1.png"), content="true")
  let types_xml = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(types_xml.contains("Extension=\"png\""), content="true")
  inspect(types_xml.contains("drawing1.xml"), content="true")
}
