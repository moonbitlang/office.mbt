///|
/// A Kingsoft WPS Office embedded cell image, extracted from
/// `xl/cellimages.xml` and its relationships. The `name` is the image
/// identifier a `DISPIMG` formula references; `data` is the raw media,
/// `extension` its file extension (with the leading dot, e.g. ".png"),
/// and `alt_text` the descriptive text from `cNvPr@descr`.
struct CellImage {
  name : String
  data : Bytes
  extension : String
  content_type : String
  alt_text : String
}

///|
/// Parses `xl/cellimages.xml` plus its relationships into the list of
/// embedded cell images, loading each referenced media part from the
/// archive. Mirrors Excelize's `cellImagesReader` / `getDispImages`.
/// Images whose media part is absent are skipped, like Go.
fn parse_cell_images(
  cell_images_xml : StringView,
  rels_xml : StringView,
  archive : @zip.Archive,
) -> Array[CellImage] raise XlsxError {
  let images : Array[CellImage] = []
  let targets = if rels_xml.to_string() == "" {
    {}
  } else {
    // cellimages relationships are always image relationships
    parse_relationship_targets(rels_xml, rel_image)
  }
  let xml_str = cell_images_xml.to_string()
  // Each embedded image is one <...pic> element; cellimages.xml contains
  // only cell images, so every pic here is one. The WPS namespace prefix
  // (xdr:) is matched, falling back to an unprefixed <pic>.
  let (open_tag, close_tag) = if xml_str.contains("<xdr:pic") {
    ("<xdr:pic", "</xdr:pic>")
  } else {
    ("<pic", "</pic>")
  }
  let mut first = true
  for chunk in xml_str.split(open_tag) {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(close_tag) {
      Some(pos) => pos
      None => continue
    }
    let pic_body = text[:end]
    let cnv_attrs = match tag_attributes_in(pic_body, "xdr:cNvPr") {
      Some(value) => value
      None =>
        match tag_attributes_in(pic_body, "cNvPr") {
          Some(value) => value
          None => continue
        }
    }
    let name = match attr_value(cnv_attrs, "name") {
      Some(value) => value
      None => continue
    }
    let alt_text = match attr_value(cnv_attrs, "descr") {
      Some(value) => value
      None => ""
    }
    // Narrow to the blipFill body first: an unprefixed `<blip` needle
    // would otherwise match `<blipFill>`, which carries no r:embed.
    let blip_fill_body = match extract_tag_body_from(pic_body, "xdr:blipFill") {
      Some(value) => value
      None =>
        match extract_tag_body_from(pic_body, "blipFill") {
          Some(value) => value
          None => continue
        }
    }
    let blip_attrs = match tag_attributes_in(blip_fill_body, "a:blip") {
      Some(value) => value
      None =>
        match tag_attributes_in(blip_fill_body, "blip") {
          Some(value) => value
          None => continue
        }
    }
    let embed = match attr_value(blip_attrs, "r:embed") {
      Some(value) => value
      None =>
        match attr_value(blip_attrs, "embed") {
          Some(value) => value
          None => continue
        }
    }
    let target = match targets.get(embed) {
      Some(value) => value
      None => continue
    }
    let media_path = normalize_cell_image_target(target)
    match archive.get(media_path) {
      Some(data) => {
        let extension = cell_image_extension(media_path)
        let content_type = match image_content_type(extension[1:]) {
          Some(value) => value
          None => ""
        }
        images.push({
          name: unescape_xml_text(name),
          data,
          extension,
          content_type,
          alt_text: unescape_xml_text(alt_text),
        })
      }
      None => continue
    }
  }
  images
}

///|
/// Resolves a cellimages relationship target to an archive path. WPS
/// targets are workbook-relative (e.g. "media/image1.png"); a leading
/// "/" is absolute and a "../" prefix is rewritten to "xl", matching
/// Excelize's `"xl/" + r.Target` / package path handling.
fn normalize_cell_image_target(target : String) -> String {
  if target.has_prefix("/") {
    target[1:].to_string()
  } else if target.has_prefix("../") {
    "xl/" + target[3:].to_string()
  } else {
    "xl/" + target
  }
}

///|
/// Returns the file extension (with leading dot) of a media path, or the
/// empty string when there is none.
fn cell_image_extension(path : String) -> String {
  match path.rev_find(".") {
    Some(pos) => path[pos:].to_string()
    None => ""
  }
}

///|
/// Builds an `Image` positioned in `reference` from an embedded cell
/// image. Cell images have no anchor geometry, so offsets/size are zero
/// and positioning is one-cell, matching how Excelize surfaces a
/// place-in-cell `Picture`.
fn CellImage::to_image(self : CellImage, reference : String) -> Image {
  {
    reference,
    data: self.data,
    extension: self.extension,
    content_type: self.content_type,
    offset_x: 0,
    offset_y: 0,
    scale_x: 1.0,
    scale_y: 1.0,
    width_emu: 0,
    height_emu: 0,
    print_object: true,
    locked: false,
    hyperlink: "",
    hyperlink_type: Unset,
    name: self.name,
    alt_text: self.alt_text,
    lock_aspect_ratio: false,
    positioning: OneCell,
  }
}

///|
/// Resolves the Kingsoft WPS Office embedded images (`DISPIMG`) shown in
/// `reference`, mirroring Excelize's `getDispImages`: a cell whose
/// formula is a `DISPIMG` call evaluates to the image identifier, which
/// selects the matching `cellimages.xml` entry.
fn Workbook::disp_images_for_cell(
  self : Workbook,
  sheet : Worksheet,
  reference : StringView,
) -> Array[Image] raise XlsxError {
  let result : Array[Image] = []
  if self.cell_images.length() == 0 {
    return result
  }
  let formula = match sheet.get_cell_formula(reference) {
    Some(value) => value
    None => return result
  }
  if !is_disp_img_formula(formula) {
    return result
  }
  let img_id = self.calc_cell_value(sheet.name(), reference)
  let canonical = {
    let (row, col) = cell_ref_to_rc(reference)
    cell_ref_from(row, col)
  }
  for image in self.cell_images {
    if image.name == img_id {
      result.push(image.to_image(canonical))
    }
  }
  result
}

///|
/// Reports whether a formula is a `DISPIMG` call, tolerating a leading
/// `=` and the `_xlfn.` future-function prefix, like Excelize.
fn is_disp_img_formula(formula : String) -> Bool {
  let mut text = formula
  if text.has_prefix("=") {
    text = text[1:].to_string()
  }
  if text.has_prefix("_xlfn.") {
    text = text[6:].to_string()
  }
  text.has_prefix("DISPIMG")
}
