///|
test "header/footer image read wb: shape id parser handles invalid cases" {
  debug_inspect(parse_header_footer_shape_id("L"), content="None")
  debug_inspect(parse_header_footer_shape_id("XH"), content="None")
  debug_inspect(parse_header_footer_shape_id("LA"), content="None")
  debug_inspect(parse_header_footer_shape_id("LHX"), content="None")
  debug_inspect(
    parse_header_footer_shape_id("LHFIRST"),
    content="Some((Left, false, true))",
  )
}

///|
test "header/footer image read wb: style and extension parsing edge cases" {
  debug_inspect(parse_style_value("height:20pt", "width"), content="None")
  debug_inspect(
    parse_style_value("width:   ;height:20pt", "width"),
    content="None",
  )
  debug_inspect(
    parse_style_value("width:10pt", "width"),
    content="Some(\"10pt\")",
  )

  debug_inspect(extension_from_path("xl/media/image."), content="None")
  debug_inspect(
    extension_from_path("xl/media/image1.png"),
    content="Some(\"png\")",
  )
}

///|
test "header/footer image read wb: parse images with r:id fallback and duplicate overwrite" {
  let archive = @zip.Archive::new()
  let image1 = @encoding/utf8.encode("img1")
  let image2 = @encoding/utf8.encode("img2")
  let image3 = @encoding/utf8.encode("img3")
  let image4 = @encoding/utf8.encode("img4")
  archive.add("xl/media/image1.png", image1)
  archive.add("xl/media/image2.png", image2)
  archive.add("xl/media/image3.bin", image3)
  archive.add("xl/media/image4", image4)

  let rels_xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image1.png"/>
    #|  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image2.png"/>
    #|  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image3.bin"/>
    #|  <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image4"/>
    #|</Relationships>
  let vml_xml =
    #|<xml xmlns:v="urn:schemas-microsoft-com:vml" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    #|  <v:shape id="LH" style="width:10pt;height:20pt">
    #|    <v:imagedata r:id="rId1"/>
    #|  </v:shape>
    #|  <v:shape id="LH" style="width:30pt;height:40pt">
    #|    <v:imagedata r:id="rId2"/>
    #|  </v:shape>
    #|  <v:shape id="CH" style="height:20pt">
    #|    <v:imagedata r:id="rId1"/>
    #|  </v:shape>
    #|  <v:shape id="RH" style="width:12pt;height:12pt">
    #|    <v:imagedata r:id="rId3"/>
    #|  </v:shape>
    #|  <v:shape id="CF" style="width:11pt;height:11pt">
    #|    <v:imagedata r:id="rId4"/>
    #|  </v:shape>
    #|</xml>

  let images = parse_header_footer_images_from_vml(
    vml_xml,
    Some(rels_xml),
    archive,
  )
  inspect(images.length(), content="1")
  debug_inspect(images[0].position, content="Left")
  inspect(images[0].is_footer, content="false")
  inspect(images[0].first_page, content="false")
  inspect(images[0].width, content="30pt")
  inspect(images[0].height, content="40pt")
  inspect(images[0].data == image2, content="true")
}

///|
test "header/footer image read wb: missing target part raises MissingPart" {
  let archive = @zip.Archive::new()
  let rels_xml =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/missing.png"/>
    #|</Relationships>
  let vml_xml =
    #|<xml xmlns:v="urn:schemas-microsoft-com:vml" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    #|  <v:shape id="LH" style="width:10pt;height:20pt">
    #|    <v:imagedata r:id="rId1"/>
    #|  </v:shape>
    #|</xml>
  let result : Result[Array[HeaderFooterImage], Error] = Ok(
    parse_header_footer_images_from_vml(vml_xml, Some(rels_xml), archive),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(XlsxError::MissingPart(path~)) =>
      inspect(path, content="xl/media/missing.png")
    _ => fail("expected MissingPart for missing header/footer image target")
  }
}
