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
test "header footer vml merge preserves existing shapes" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let base_vml =
    #|<xml xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel">
    #|  <v:shapetype id="_x0000_t75"></v:shapetype>
    #|  <v:shape id="CH" type="#_x0000_t75"></v:shape>
    #|</xml>
  sheet.add_vml_drawing_hf_xml(base_vml)
  let img : Bytes = [7, 8, 9]
  sheet.add_header_footer_image(
    HeaderFooterImageOptions::new(
      HeaderFooterImagePosition::Left,
      img,
      ".png",
      width="10pt",
      height="10pt",
    ),
  )
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
  inspect(vml_xml.contains("id=\"CH\""), content="true")
  inspect(vml_xml.contains("id=\"LH\""), content="true")
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

///|
test "header footer image multiple positions and first page" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_header_footer(
    Some(
      HeaderFooterOptions::with_values(
        different_first=true,
        odd_header="&L&G&C&G&R&G",
        odd_footer="&L&G&C&G&R&G",
        first_header="&L&G&C&G&R&G",
        first_footer="&L&G&C&G&R&G",
      ),
    ),
  )
  sheet.add_header_footer_image(
    HeaderFooterImageOptions::new(
      HeaderFooterImagePosition::Left,
      [1, 2, 3],
      ".png",
      width="10pt",
      height="11pt",
    ),
  )
  sheet.add_header_footer_image(
    HeaderFooterImageOptions::new(
      HeaderFooterImagePosition::Center,
      [4, 5],
      ".gif",
      is_footer=true,
      width="12pt",
      height="13pt",
    ),
  )
  sheet.add_header_footer_image(
    HeaderFooterImageOptions::new(
      HeaderFooterImagePosition::Right,
      [6],
      ".jpg",
      first_page=true,
      width="14pt",
      height="15pt",
    ),
  )
  let bytes = write(workbook)
  let parsed = read(bytes)
  let images = parsed.get_header_footer_images("Sheet1")
  inspect(images.length(), content="3")
  let ids : Array[String] = []
  for img in images {
    let suffix = if img.first_page { "FIRST" } else { "" }
    let mid = if img.is_footer { "F" } else { "H" }
    let base = match img.position {
      HeaderFooterImagePosition::Left => "L"
      HeaderFooterImagePosition::Center => "C"
      HeaderFooterImagePosition::Right => "R"
    }
    ids.push("\{base}\{mid}\{suffix}")
  }
  inspect(ids.contains("LH"), content="true")
  inspect(ids.contains("CFF"), content="false")
  inspect(ids.contains("CFFIRST"), content="false")
  inspect(ids.contains("CF"), content="true")
  inspect(ids.contains("RHFIRST"), content="true")
}

///|
test "header footer image replaces same slot" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_header_footer_image(
    HeaderFooterImageOptions::new(
      HeaderFooterImagePosition::Left,
      [9],
      ".png",
      width="10pt",
      height="10pt",
    ),
  )
  sheet.add_header_footer_image(
    HeaderFooterImageOptions::new(
      HeaderFooterImagePosition::Left,
      [8, 7],
      ".jpg",
      width="10pt",
      height="10pt",
    ),
  )
  let parsed = read(write(workbook))
  let images = parsed.get_header_footer_images("Sheet1")
  inspect(images.length(), content="1")
  inspect(
    (
      images[0].position,
      images[0].is_footer,
      images[0].first_page,
      images[0].extension,
    ),
    content="(Left, false, false, \"jpg\")",
  )
  inspect(images[0].data == [8, 7], content="true")
}

///|
test "header footer image workbook missing sheet" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result : Result[Unit, Error] = try? workbook.add_header_footer_image(
    "SheetN",
    HeaderFooterImageOptions::new(
      HeaderFooterImagePosition::Left,
      [1],
      ".png",
      width="10pt",
      height="10pt",
    ),
  )
  inspect(result is Err(XlsxError::SheetNotFound(_)), content="true")
}
