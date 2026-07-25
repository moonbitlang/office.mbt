///|
test "vml drawing write and relationships" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_vml_drawing_xml("<xml>vml</xml>")
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("<legacyDrawing r:id=\"rId1\"/>"), content="true")
  let rels_xml = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml.rels utf8 decode failed")
      }
    None => fail("missing sheet1.xml.rels")
  }
  inspect(rels_xml.contains("relationships/vmlDrawing"), content="true")
  inspect(rels_xml.contains("../drawings/vmlDrawing1.vml"), content="true")
  let vml_xml = match archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("vmlDrawing1.vml utf8 decode failed")
      }
    None => fail("missing vmlDrawing1.vml")
  }
  inspect(vml_xml, content="<xml>vml</xml>")
}

///|
test "vml drawing roundtrip" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_vml_drawing_xml("<xml>vml</xml>")
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  debug_inspect(
    parsed_sheet.vml_drawing_xml(),
    content="Some(\"<xml>vml</xml>\")",
  )
}

///|
test "raw note VML without semantic comments is preserved byte-for-byte" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let raw_vml = "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" " +
    "xmlns:x=\"urn:schemas-microsoft-com:office:excel\">" +
    "<meta keep=\"true\"/><v:shape id=\"_x0000_s4096\" " +
    "style=\"width:86pt;height:24pt\" fillcolor=\"#123456\">" +
    "<x:ClientData ObjectType=\"Note\"><x:Row>4</x:Row>" +
    "<x:Column>2</x:Column></x:ClientData></v:shape>" +
    "<tail keep=\"true\"/></xml>"
  sheet.add_vml_drawing_xml(raw_vml)
  let first_archive = @zip.read(@xlsx.write(workbook))
  let first_vml = match first_archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing first VML drawing")
  }
  inspect(first_vml == raw_vml, content="true")

  let parsed = @xlsx.read(@xlsx.write(workbook))
  let second_archive = @zip.read(@xlsx.write(parsed))
  let second_vml = match second_archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing roundtrip VML drawing")
  }
  inspect(second_vml == raw_vml, content="true")
}

///|
test "vml drawing hf roundtrip" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_vml_drawing_hf_xml("<xml>hf</xml>")
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  debug_inspect(
    parsed_sheet.vml_drawing_hf_xml(),
    content="Some(\"<xml>hf</xml>\")",
  )
}

///|
test "vml drawing validation" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let result = try sheet.add_vml_drawing_xml("") catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  debug_inspect(
    result,
    content="Err(InvalidVmlDrawing(msg=\"vml drawing xml empty\"))",
  )
}
