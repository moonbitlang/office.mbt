///|
fn parse_header_footer_shape_id(
  id : StringView,
) -> (HeaderFooterImagePosition, Bool, Bool)? {
  let id_norm = id.to_string().to_upper()
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
    view.to_string()
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
  let style_str = style.to_string()
  let needle = "\{key.to_string()}:"
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
  let trimmed = slice.to_string().trim()
  let value = trimmed.to_string()
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
fn extension_from_path(path : StringView) -> String? {
  let path_str = path.to_string()
  let dot = match path_str.rev_find(".") {
    Some(pos) => pos
    None => return None
  }
  let start = dot + 1
  if start >= path_str.length() {
    return None
  }
  let slice = path_str[start:]
  let value = slice.to_string().to_lower()
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
  archive : @zip.Archive,
) -> Array[HeaderFooterImage] raise XlsxError {
  let shapes = extract_vml_shapes(vml_xml)
  let rel_targets = match vml_rels_xml {
    Some(xml) => parse_relationship_targets(xml, rel_image)
    None => {}
  }
  let images : Array[HeaderFooterImage] = []
  let index_by_id : Map[String, Int] = {}
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
    let image_path = resolve_rel_target(target, "drawings")
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
      data: image_bytes,
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
