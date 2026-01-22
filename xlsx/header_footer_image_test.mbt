///|
test "header footer image vml and rels" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_header_footer(
    Some(HeaderFooterOptions::with_values(odd_header="&L&G")),
  )
  let img : Bytes = [1, 2, 3, 4]
  sheet.add_header_footer_image(
    HeaderFooterImageOptions::new(
      HeaderFooterImagePosition::Left,
      img,
      ".png",
      width="50pt",
      height="32pt",
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
  inspect(
    sheet_xml.contains("<legacyDrawingHF r:id=\"rId1\"/>"),
    content="true",
  )
  let rels_xml = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml.rels utf8 decode failed")
      }
    None => fail("missing sheet1.xml.rels")
  }
  inspect(rels_xml.contains("vmlDrawing1.vml"), content="true")
  let vml_xml = match archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("vmlDrawing1.vml utf8 decode failed")
      }
    None => fail("missing vmlDrawing1.vml")
  }
  inspect(vml_xml.contains("id=\"LH\""), content="true")
  inspect(vml_xml.contains("o:relid=\"rId1\""), content="true")
  let vml_rels = match archive.get("xl/drawings/_rels/vmlDrawing1.vml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("vmlDrawing1.vml.rels utf8 decode failed")
      }
    None => fail("missing vmlDrawing1.vml.rels")
  }
  inspect(vml_rels.contains("../media/image1.png"), content="true")
}

///|
test "header footer image read roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let img : Bytes = [10, 20, 30]
  sheet.add_header_footer_image(
    HeaderFooterImageOptions::new(
      HeaderFooterImagePosition::Left,
      img,
      ".png",
      width="50pt",
      height="32pt",
    ),
  )
  let parsed = read(write(workbook))
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  match parsed_sheet.vml_drawing_hf_xml() {
    Some(xml) => {
      inspect(xml.contains("v:imagedata"), content="true")
      inspect(xml.contains("id=\"LH\""), content="true")
      inspect(xml.contains("width:50pt"), content="true")
    }
    None => fail("missing vml drawing hf")
  }
  let images = parsed_sheet.get_header_footer_images()
  inspect(images.length(), content="1")
  let first = images[0]
  inspect(
    (
      first.position,
      first.is_footer,
      first.first_page,
      first.extension,
      first.width,
      first.height,
    ),
    content="(Left, false, false, \"png\", \"50pt\", \"32pt\")",
  )
  inspect(first.data == img, content="true")
  inspect(parsed.get_header_footer_images("Sheet1").length(), content="1")
}

///|
test "header footer image invalid extension" {
  let sheet = Worksheet::new("Sheet1")
  let result = try
    sheet.add_header_footer_image(
      HeaderFooterImageOptions::new(
        HeaderFooterImagePosition::Left,
        [1, 2],
        ".bad",
        width="10pt",
        height="10pt",
      ),
    )
  catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    result,
    content="Err(UnsupportedFeature(msg=\"unsupported header/footer image extension\"))",
  )
}
