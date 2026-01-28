///|
test "shape write" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let shape = Shape::new("A1", "rect", text="Hello")
  sheet.add_shape(shape)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  inspect(drawing_xml.contains("<xdr:sp>"), content="true")
  inspect(drawing_xml.contains("prst=\"rect\""), content="true")
  inspect(drawing_xml.contains("Hello"), content="true")
  inspect(drawing_xml.contains("cx=\"1524000\""), content="true")
  inspect(drawing_xml.contains("cy=\"1524000\""), content="true")
}

///|
test "shape size and rich text paragraphs" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let runs : Array[RichTextRun] = [
    {
      text: "Rectangle",
      font: Some({
        bold: false,
        italic: false,
        underline: None,
        size: None,
        color: Some("CD5C5C"),
        family: None,
      }),
    },
    {
      text: "Shape",
      font: Some({
        bold: true,
        italic: true,
        underline: Some("sng"),
        size: Some(18.0),
        color: Some("2980B9"),
        family: Some("Times New Roman"),
      }),
    },
  ]
  let shape = Shape::new("B2", "rect", paragraph=runs, width=180, height=40)
  sheet.add_shape(shape)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  inspect(drawing_xml.contains("cx=\"1714500\""), content="true")
  inspect(drawing_xml.contains("cy=\"381000\""), content="true")
  inspect(drawing_xml.contains("b=\"1\""), content="true")
  inspect(drawing_xml.contains("i=\"1\""), content="true")
  inspect(drawing_xml.contains("u=\"sng\""), content="true")
  inspect(drawing_xml.contains("sz=\"1800\""), content="true")
  inspect(drawing_xml.contains("typeface=\"Times New Roman\""), content="true")
  inspect(drawing_xml.contains("val=\"2980B9\""), content="true")
}

///|
test "form control add/get/delete and vml" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_form_control(
    "Sheet1",
    FormControl::new("B2", "Button", text="Click"),
  )
  workbook.add_form_control("Sheet1", FormControl::new("C3", "CheckBox"))
  inspect(workbook.get_form_controls("Sheet1").length(), content="2")
  workbook.delete_form_control("Sheet1", "C3")
  inspect(workbook.get_form_controls("Sheet1").length(), content="1")
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let vml_xml = match archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("vmlDrawing1.vml utf8 decode failed")
      }
    None => fail("missing vmlDrawing1.vml")
  }
  inspect(vml_xml.contains("ObjectType=\"Button\""), content="true")
  inspect(vml_xml.contains("Click"), content="true")
}

///|
test "slicer add/get/delete and xml" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_slicer("Sheet1", Slicer::new("Slicer1"))
  inspect(workbook.get_slicers("Sheet1").length(), content="1")
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let slicer_xml = match archive.get("xl/slicers/slicer1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("slicer1.xml utf8 decode failed")
      }
    None => fail("missing slicer1.xml")
  }
  inspect(slicer_xml.contains("name=\"Slicer1\""), content="true")
  let cache_xml = match archive.get("xl/slicerCaches/slicerCache1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("slicerCache1.xml utf8 decode failed")
      }
    None => fail("missing slicerCache1.xml")
  }
  inspect(cache_xml.contains("name=\"Slicer1\""), content="true")
  let rels_xml = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml.rels utf8 decode failed")
      }
    None => fail("missing sheet1.xml.rels")
  }
  inspect(rels_xml.contains("relationships/slicer"), content="true")
  workbook.delete_slicer("Slicer1")
  inspect(workbook.get_slicers("Sheet1").length(), content="0")
}
