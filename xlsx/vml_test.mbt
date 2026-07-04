///|
test "vml drawing write and relationships" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_vml_drawing_xml("<xml>vml</xml>")
  let bytes = write(workbook)
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
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_vml_drawing_xml("<xml>vml</xml>")
  let parsed = read(write(workbook))
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
test "vml drawing hf roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_vml_drawing_hf_xml("<xml>hf</xml>")
  let parsed = read(write(workbook))
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
  let workbook = Workbook::new()
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
