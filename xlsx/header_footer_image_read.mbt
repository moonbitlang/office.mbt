///|
fn parse_header_footer_shape_id(
  id : StringView,
) -> (HeaderFooterImagePosition, Bool, Bool)? {
  let id_norm = id.to_owned().to_upper()
  if id_norm.length() < 2 {
    return None
  }
  let pos_char = id_norm.get_char(0)
  let hf_char = id_norm.get_char(1)
  let position = match pos_char {
    Some('L') => HeaderFooterImagePosition::Left
    Some('C') => Center
    Some('R') => Right
    _ => return None
  }
  let is_footer = match hf_char {
    Some('H') => false
    Some('F') => true
    _ => return None
  }
  let suffix = if id_norm.length() > 2 {
    let view = id_norm[2:]
    view.to_owned()
  } else {
    ""
  }
  let first_page = match suffix {
    "" => false
    "FIRST" => true
    _ => return None
  }
  Some((position, is_footer, first_page))
}

///|
fn parse_style_value(style : StringView, key : StringView) -> String? {
  let style_str = style.to_owned()
  let needle = "\{key.to_owned()}:"
  let start = match style_str.find(needle) {
    Some(pos) => pos + needle.length()
    None => return None
  }
  let rest = style_str[start:]
  let end = match rest.find(";") {
    Some(pos) => pos
    None => rest.length()
  }
  let slice = rest[:end]
  let trimmed = slice.to_owned().trim()
  let value = trimmed.to_owned()
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
fn extension_from_path(path : StringView) -> String? {
  let path_str = path.to_owned()
  let dot = match path_str.rev_find(".") {
    Some(pos) => pos
    None => return None
  }
  let start = dot + 1
  if start >= path_str.length() {
    return None
  }
  let slice = path_str[start:]
  let value = slice.to_owned().to_lower()
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
fn parse_header_footer_images_from_vml(
  vml_xml : StringView,
  vml_rels_xml : String?,
  vml_part : StringView,
  part_names : Map[String, String],
  archive : @zip.Archive,
) -> Array[HeaderFooterImage] raise XlsxError {
  let shapes = extract_vml_shapes(vml_xml)
  let rel_targets = match vml_rels_xml {
    Some(xml) => parse_relationship_targets(xml, rel_image)
    None => Map([])
  }
  let images : Array[HeaderFooterImage] = []
  let index_by_id : Map[String, Int] = Map([])
  for shape in shapes {
    let shape_attrs = match tag_attributes_in(shape, "v:shape") {
      Some(value) => value
      None => continue
    }
    let shape_id = match attr_value(shape_attrs, "id") {
      Some(value) => value
      None => continue
    }
    let info = match parse_header_footer_shape_id(shape_id) {
      Some(value) => value
      None => continue
    }
    let (position, is_footer, first_page) = info
    let style = match attr_value(shape_attrs, "style") {
      Some(value) => value
      None => ""
    }
    let width = match parse_style_value(style, "width") {
      Some(value) => value
      None => continue
    }
    let height = match parse_style_value(style, "height") {
      Some(value) => value
      None => continue
    }
    let imagedata_attrs = match tag_attributes_in(shape, "v:imagedata") {
      Some(value) => value
      None => continue
    }
    let rel_id = match attr_value(imagedata_attrs, "o:relid") {
      Some(value) => value
      None =>
        match attr_value(imagedata_attrs, "r:id") {
          Some(value) => value
          None => continue
        }
    }
    let target = match rel_targets.get(rel_id) {
      Some(value) => value
      None => raise InvalidXml(msg="header/footer image relationship missing")
    }
    let image_path = actual_relationship_target_path(
      vml_part, target, part_names,
    )
    let image_bytes = match archive.get(image_path) {
      Some(value) => value
      None => raise MissingPart(path=image_path)
    }
    let extension = match extension_from_path(image_path) {
      Some(value) => value
      None => continue
    }
    let content_type = match image_content_type(extension) {
      Some(value) => value
      None => continue
    }
    let image : HeaderFooterImage = {
      position,
      data: image_bytes.to_owned(),
      extension,
      content_type,
      is_footer,
      first_page,
      width,
      height,
    }
    let key = header_footer_image_shape_id(position, is_footer, first_page)
    match index_by_id.get(key) {
      Some(idx) => images[idx] = image
      None => {
        index_by_id[key] = images.length()
        images.push(image)
      }
    }
  }
  images
}

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
    "xl/drawings/vmlDrawing1.vml",
    Map([]),
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
    parse_header_footer_images_from_vml(
      vml_xml,
      Some(rels_xml),
      "xl/drawings/vmlDrawing1.vml",
      Map([]),
      archive,
    ),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(XlsxError::MissingPart(path~)) =>
      inspect(path, content="xl/media/missing.png")
    _ => fail("expected MissingPart for missing header/footer image target")
  }
}
