///|
/// The parsed `xl/richData/*` and `xl/metadata.xml` parts needed to
/// resolve modern Excel embedded cell images ("Place in cell"). Mirrors
/// the chain Excelize's `getImageCellRel` walks: a cell's `vm` index
/// selects a value-metadata block, whose record points at a rich value,
/// whose structure names a `_rvRel:LocalImageIdentifier` value, which
/// indexes `richValueRel.xml` to a relationship, which resolves to a
/// media part.
struct RichValueImages {
  /// value-metadata block index (0-based, i.e. vm-1) -> rich value index
  value_metadata : Array[Int]
  /// rich values: each is (structure index, ordered values)
  rich_values : Array[(Int, Array[String])]
  /// rich value structures: each is the ordered list of key names
  structures : Array[Array[String]]
  /// ordered relationship ids referenced by rich values
  rel_ids : Array[String]
  /// relationship id -> media target (from richValueRel.xml.rels)
  rel_targets : Map[String, String]
  /// ordered blip relationship ids of web images, from
  /// rdRichValueWebImage.xml (used by the IMAGE() function)
  web_blip_ids : Array[String]
  /// blip relationship id -> media target (from
  /// rdRichValueWebImage.xml.rels)
  web_rel_targets : Map[String, String]
}

///|
/// Reads the rich-value image parts from the archive, returning `None`
/// when the workbook has no rich value metadata.
fn parse_rich_value_images(
  archive : @zip.Archive,
  decode : (Bytes) -> String raise XlsxError,
) -> RichValueImages? raise XlsxError {
  let metadata_bytes = archive.get("xl/metadata.xml")
  let rich_value_bytes = archive.get("xl/richData/rdrichvalue.xml")
  guard metadata_bytes is Some(md) && rich_value_bytes is Some(rv) else {
    return None
  }
  let value_metadata = parse_value_metadata(decode(md))
  let rich_values = parse_rich_values(decode(rv))
  let structures = match archive.get("xl/richData/rdrichvaluestructure.xml") {
    Some(value) => parse_rich_value_structures(decode(value))
    None => []
  }
  let rel_ids = match archive.get("xl/richData/richValueRel.xml") {
    Some(value) => parse_rich_value_rel_ids(decode(value))
    None => []
  }
  let rel_targets = match
    archive.get("xl/richData/_rels/richValueRel.xml.rels") {
    Some(value) => parse_relationship_targets(decode(value), rel_image)
    None => {}
  }
  let web_blip_ids = match archive.get("xl/richData/rdRichValueWebImage.xml") {
    Some(value) => parse_web_image_blip_ids(decode(value))
    None => []
  }
  let web_rel_targets = match
    archive.get("xl/richData/_rels/rdRichValueWebImage.xml.rels") {
    Some(value) => parse_relationship_targets(decode(value), rel_image)
    None => {}
  }
  Some({
    value_metadata,
    rich_values,
    structures,
    rel_ids,
    rel_targets,
    web_blip_ids,
    web_rel_targets,
  })
}

///|
/// Parses the ordered blip relationship ids from `<webImageSrd>`
/// elements of `xl/richData/rdRichValueWebImage.xml`. Each web image's
/// `<blip r:id="...">` names the relationship resolving to its media.
fn parse_web_image_blip_ids(xml : String) -> Array[String] raise XlsxError {
  let result : Array[String] = []
  let mut first = true
  for chunk in xml.split("<webImageSrd") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("</webImageSrd>") {
      Some(pos) => pos
      None => text.length()
    }
    let srd_body = text[:end]
    let blip_attrs = match tag_attributes_in(srd_body, "blip") {
      Some(value) => value
      None => continue
    }
    let id = match attr_value(blip_attrs, "r:id") {
      Some(value) => Some(value)
      None => attr_value(blip_attrs, "id")
    }
    match id {
      Some(value) => result.push(value)
      None => continue
    }
  }
  result
}

///|
/// Parses the `<valueMetadata>` blocks of `xl/metadata.xml`, returning
/// the first record value of each block (the rich value index).
fn parse_value_metadata(xml : String) -> Array[Int] raise XlsxError {
  let result : Array[Int] = []
  let body = match extract_tag_body_from(xml[:], "valueMetadata") {
    Some(value) => value
    None => return result
  }
  let mut first = true
  for chunk in body.split("<bk") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("</bk>") {
      Some(pos) => pos
      None => text.length()
    }
    let bk_body = text[:end]
    match tag_attributes_in(bk_body, "rc") {
      Some(attrs) =>
        match attr_value(attrs, "v") {
          Some(v) =>
            result.push(@strconv.parse_int(v, base=10) catch { _ => -1 })
          None => result.push(-1)
        }
      None => result.push(-1)
    }
  }
  result
}

///|
/// Parses `<rv>` rich values from `xl/richData/rdrichvalue.xml`: each is
/// its structure index `s` and the ordered `<v>` values.
fn parse_rich_values(
  xml : String,
) -> Array[(Int, Array[String])] raise XlsxError {
  let result : Array[(Int, Array[String])] = []
  // Extract the rvData body first so the split does not also match the
  // "<rvData" container element (which would insert a phantom entry and
  // shift every rich value index by one).
  let body = match extract_tag_body_from(xml[:], "rvData") {
    Some(value) => value
    None => return result
  }
  let mut first = true
  for chunk in body.split("<rv") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let tag_end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let tag = text[:tag_end]
    let s = match attr_value(tag, "s") {
      Some(value) => @strconv.parse_int(value, base=10) catch { _ => 0 }
      None => 0
    }
    let end = match text.find("</rv>") {
      Some(pos) => pos
      None => text.length()
    }
    let rv_body = text[tag_end + 1:end]
    let values : Array[String] = []
    let mut first_v = true
    for v_chunk in rv_body.split("<v>") {
      if first_v {
        first_v = false
        continue
      }
      let v_text = v_chunk.to_string()
      match v_text.find("</v>") {
        Some(pos) => values.push(unescape_xml_text(v_text[:pos]))
        None => ()
      }
    }
    result.push((s, values))
  }
  result
}

///|
/// Parses `<s>` structures from `xl/richData/rdrichvaluestructure.xml`:
/// each is the ordered list of `<k n="...">` key names.
fn parse_rich_value_structures(
  xml : String,
) -> Array[Array[String]] raise XlsxError {
  let result : Array[Array[String]] = []
  let mut first = true
  for chunk in xml.split("<s ") {
    if first {
      first = false
      continue
    }
    let text = "<s \{chunk.to_string()}"
    let end = match text.find("</s>") {
      Some(pos) => pos
      None => text.length()
    }
    let s_body = text[:end]
    let keys : Array[String] = []
    let mut first_k = true
    for k_chunk in s_body.split("<k ") {
      if first_k {
        first_k = false
        continue
      }
      let k_text = "<k \{k_chunk.to_string()}"
      match tag_attributes_in(k_text, "k") {
        Some(attrs) =>
          match attr_value(attrs, "n") {
            Some(n) => keys.push(unescape_xml_text(n))
            None => keys.push("")
          }
        None => keys.push("")
      }
    }
    result.push(keys)
  }
  result
}

///|
/// Parses the ordered relationship ids from `<rel>` elements of
/// `xl/richData/richValueRel.xml`.
fn parse_rich_value_rel_ids(xml : String) -> Array[String] raise XlsxError {
  let result : Array[String] = []
  let mut first = true
  for chunk in xml.split("<rel") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let tag = text[:end]
    let id = match attr_value(tag, "r:id") {
      Some(value) => Some(value)
      None => attr_value(tag, "id")
    }
    match id {
      Some(value) => result.push(value)
      None => ()
    }
  }
  result
}

///|
/// Scans a worksheet's cells for the `vm` (value-metadata) attribute,
/// returning a canonical-reference -> vm-index map. Rich-value cell
/// images are the only cells that carry `vm`, so this is the link
/// between a cell and its rich value.
fn parse_cell_vm_map(sheet_xml : String) -> Map[String, Int] raise XlsxError {
  let result : Map[String, Int] = {}
  let mut first = true
  for chunk in sheet_xml.split("<c ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let tag = text[:end]
    let vm = match attr_value(tag, "vm") {
      Some(value) => value
      None => continue
    }
    let reference = match attr_value(tag, "r") {
      Some(value) => value
      None => continue
    }
    let vm_index = @strconv.parse_int(vm, base=10) catch { _ => continue }
    let (row, col) = cell_ref_to_rc(reference)
    result[cell_ref_from(row, col)] = vm_index
  }
  result
}

///|
/// Resolves a rich value's local ("Place in cell") image media target
/// via the `_rvRel:LocalImageIdentifier` key, or `None` when the value
/// is not a local image.
fn rich_value_local_target(
  data : RichValueImages,
  keys : Array[String],
  values : Array[String],
) -> String? {
  let local_idx = rich_value_key_index(keys, "_rvRel:LocalImageIdentifier")
  if local_idx < 0 || local_idx >= values.length() {
    return None
  }
  let rel_index = @strconv.parse_int(values[local_idx], base=10) catch {
    _ => return None
  }
  if rel_index < 0 || rel_index >= data.rel_ids.length() {
    return None
  }
  data.rel_targets.get(data.rel_ids[rel_index])
}

///|
/// Resolves a rich value's web (IMAGE function) image media target via
/// the `WebImageIdentifier` key, or `None` when the value is not a web
/// image. Mirrors Excelize's getRichDataWebImagesRel.
fn rich_value_web_target(
  data : RichValueImages,
  keys : Array[String],
  values : Array[String],
) -> String? {
  let web_idx = rich_value_key_index(keys, "WebImageIdentifier")
  if web_idx < 0 || web_idx >= values.length() {
    return None
  }
  let web_index = @strconv.parse_int(values[web_idx], base=10) catch {
    _ => return None
  }
  if web_index < 0 || web_index >= data.web_blip_ids.length() {
    return None
  }
  data.web_rel_targets.get(data.web_blip_ids[web_index])
}

///|
/// Returns the index of a key name within a rich value structure, or -1.
fn rich_value_key_index(keys : Array[String], name : String) -> Int {
  for i, key in keys {
    if key == name {
      return i
    }
  }
  -1
}

///|
/// Resolves the modern "Place in cell" embedded image shown in
/// `reference`, mirroring Excelize's `getImageCellRel`
/// (`_rvRel:LocalImageIdentifier` path). Returns `None` when the cell has
/// no rich-value image.
fn Workbook::rich_value_image_for_cell(
  self : Workbook,
  sheet : Worksheet,
  reference : StringView,
) -> Image? raise XlsxError {
  let data = match self.rich_value_images {
    Some(value) => value
    None => return None
  }
  let canonical = {
    let (row, col) = cell_ref_to_rc(reference)
    cell_ref_from(row, col)
  }
  let vm = match sheet.cell_vm.get(canonical) {
    Some(value) => value
    None => return None
  }
  // Only #VALUE! cells carry an embedded rich-value image.
  if sheet.get_cell(canonical) != Some(formula_error_value) {
    return None
  }
  if vm < 1 || vm > data.value_metadata.length() {
    return None
  }
  let rich_value_idx = data.value_metadata[vm - 1]
  if rich_value_idx < 0 || rich_value_idx >= data.rich_values.length() {
    return None
  }
  let (structure_idx, values) = data.rich_values[rich_value_idx]
  if structure_idx < 0 || structure_idx >= data.structures.length() {
    return None
  }
  let keys = data.structures[structure_idx]
  // Excelize requires the structure keys and rich value values to line
  // up before reading any of them (getImageCellRel:
  // len(rvStruct.K) != len(rv.V)); a mismatched rich value is not an
  // image.
  if keys.length() != values.length() {
    return None
  }
  let alt_text = {
    let text_idx = rich_value_key_index(keys, "Text")
    if text_idx >= 0 && text_idx < values.length() {
      values[text_idx]
    } else {
      ""
    }
  }
  // A rich value carries either a local image (Place in cell) or a web
  // image (IMAGE function). Excelize's getImageCellRel branches on which
  // key is *present*: once a LocalImageIdentifier key exists it commits
  // to the local path and never falls back to the web path, even if the
  // local relationship fails to resolve.
  let target = if rich_value_key_index(keys, "_rvRel:LocalImageIdentifier") !=
    -1 {
    rich_value_local_target(data, keys, values)
  } else {
    rich_value_web_target(data, keys, values)
  }
  let media_path = match target {
    Some(value) => normalize_cell_image_target(value)
    None => return None
  }
  match self.rich_value_media.get(media_path) {
    Some(bytes) => {
      let extension = cell_image_extension(media_path)
      let content_type = match image_content_type(extension_no_dot(extension)) {
        Some(value) => value
        None => ""
      }
      Some({
        reference: canonical,
        data: bytes,
        extension,
        content_type,
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
        name: "",
        alt_text,
        lock_aspect_ratio: false,
        positioning: OneCell,
      })
    }
    None => None
  }
}

///|
/// Returns a file extension without its leading dot.
fn extension_no_dot(extension : String) -> String {
  if extension.has_prefix(".") {
    extension[1:].to_string()
  } else {
    extension
  }
}
