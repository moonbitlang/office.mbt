///|
fn wb_from_xml() -> String {
  "<xdr:from><xdr:col>0</xdr:col><xdr:row>0</xdr:row><xdr:colOff>0</xdr:colOff><xdr:rowOff>0</xdr:rowOff></xdr:from>"
}

///|
fn wb_pic_xml(embed_id : String) -> String {
  "<xdr:pic><xdr:nvPicPr><xdr:cNvPr id=\"1\" name=\"Pic 1\" descr=\"Alt\"/></xdr:nvPicPr><xdr:blipFill><a:blip r:embed=\"\{embed_id}\"/></xdr:blipFill></xdr:pic>"
}

///|
fn wb_one_cell_anchor(xml_from : String, xml_ext : String) -> String {
  let pic = wb_pic_xml("rId1")
  "<xdr:wsDr><xdr:oneCellAnchor>\{xml_from}\{xml_ext}\{pic}</xdr:oneCellAnchor></xdr:wsDr>"
}

///|
fn wb_rels_image_target(target : String) -> String {
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"\{target}\"/>" +
  "</Relationships>"
}

///|
test "read_drawing_xml wb: parse_xml_int_tag missing/invalid errors" {
  let missing_tag = "<xdr:from><xdr:row>1</xdr:row></xdr:from>"
  let missing_result : Result[Int, Error] = try? parse_xml_int_tag(
    missing_tag, "xdr:col", "drawing col invalid",
  )
  match missing_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing col invalid")
    _ => fail("expected InvalidXml for missing xdr:col")
  }

  let invalid_value = "<xdr:from><xdr:col>abc</xdr:col></xdr:from>"
  let invalid_result : Result[Int, Error] = try? parse_xml_int_tag(
    invalid_value, "xdr:col", "drawing col invalid",
  )
  match invalid_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing col invalid")
    _ => fail("expected InvalidXml for invalid xdr:col numeric value")
  }
}

///|
test "read_drawing_xml wb: drawing_axis_span_emu handles reverse and same-index spans" {
  let sheet = Worksheet::new("Sheet1")
  inspect(drawing_axis_span_emu(sheet, "col", 1, 200, 1, 800), content="600")
  inspect(drawing_axis_span_emu(sheet, "col", 1, 800, 1, 200), content="600")
}

///|
test "read_drawing_xml wb: parse_drawing_anchors validation and positioning" {
  let one_missing_close = "<xdr:wsDr><xdr:oneCellAnchor><xdr:pic/></xdr:wsDr>"
  let one_result : Result[Array[(String, PicturePositioning)], Error] = try? parse_drawing_anchors(
    one_missing_close,
  )
  match one_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="oneCellAnchor close missing")
    _ => fail("expected InvalidXml for oneCellAnchor close missing")
  }

  let two_missing_close = "<xdr:wsDr><xdr:oneCellAnchor></xdr:oneCellAnchor><xdr:twoCellAnchor></xdr:wsDr>"
  let two_result : Result[Array[(String, PicturePositioning)], Error] = try? parse_drawing_anchors(
    two_missing_close,
  )
  match two_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="twoCellAnchor close missing")
    _ => fail("expected InvalidXml for twoCellAnchor close missing")
  }

  let xml =
    #|<xdr:wsDr>
    #|  <xdr:twoCellAnchor editAs="absolute"></xdr:twoCellAnchor>
    #|  <xdr:twoCellAnchor editAs="free"></xdr:twoCellAnchor>
    #|</xdr:wsDr>
  let anchors = parse_drawing_anchors(xml)
  inspect(anchors.length(), content="2")
  inspect(anchors[0].1, content="Absolute")
  inspect(anchors[1].1, content="TwoCell")
}

///|
test "read_drawing_xml wb: parse_drawing_images empty rel map branch" {
  let drawing_xml = wb_one_cell_anchor(
    wb_from_xml(),
    "<xdr:ext cx=\"9525\" cy=\"9525\"/>",
  )
  let archive = @zip.Archive::new()
  let result : Result[Array[Image], Error] = try? parse_drawing_images(
    drawing_xml,
    "",
    Worksheet::new("Sheet1"),
    archive,
  )
  match result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing image target missing")
    _ => fail("expected InvalidXml for missing drawing image target")
  }
}

///|
test "read_drawing_xml wb: parse_drawing_images anchor/ext validation errors" {
  let archive = @zip.Archive::new()
  archive.add("xl/media/image1.png", @encoding/utf8.encode("img"))
  let rels_xml = wb_rels_image_target("../media/image1.png")
  let sheet = Worksheet::new("Sheet1")

  let missing_from = wb_one_cell_anchor(
    "", "<xdr:ext cx=\"9525\" cy=\"9525\"/>",
  )
  let missing_from_result : Result[Array[Image], Error] = try? parse_drawing_images(
    missing_from, rels_xml, sheet, archive,
  )
  match missing_from_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing anchor from missing")
    _ => fail("expected InvalidXml drawing anchor from missing")
  }

  let missing_ext = wb_one_cell_anchor(wb_from_xml(), "")
  let missing_ext_result : Result[Array[Image], Error] = try? parse_drawing_images(
    missing_ext, rels_xml, sheet, archive,
  )
  match missing_ext_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing ext missing")
    _ => fail("expected InvalidXml drawing ext missing")
  }

  let cx_invalid = wb_one_cell_anchor(
    wb_from_xml(),
    "<xdr:ext cx=\"x\" cy=\"9525\"/>",
  )
  let cx_invalid_result : Result[Array[Image], Error] = try? parse_drawing_images(
    cx_invalid, rels_xml, sheet, archive,
  )
  match cx_invalid_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing cx invalid")
    _ => fail("expected InvalidXml drawing cx invalid")
  }

  let cy_missing = wb_one_cell_anchor(wb_from_xml(), "<xdr:ext cx=\"9525\"/>")
  let cy_missing_result : Result[Array[Image], Error] = try? parse_drawing_images(
    cy_missing, rels_xml, sheet, archive,
  )
  match cy_missing_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing cy missing")
    _ => fail("expected InvalidXml drawing cy missing")
  }
}
