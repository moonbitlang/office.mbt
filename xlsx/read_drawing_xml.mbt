///|
fn parse_xml_int_tag(
  xml : StringView,
  tag_name : StringView,
  msg : String,
) -> Int raise XlsxError {
  let body = match extract_tag_body_from(xml, tag_name) {
    Some(value) => value
    None => raise InvalidXml(msg~)
  }
  @string.parse_int(body, base=10) catch {
    _ => raise InvalidXml(msg~)
  }
}

///|
fn validate_drawing_axis_marker_for_read(
  axis : StringView,
  idx0 : Int,
  off_emu : Int,
  allow_end_boundary : Bool,
) -> Unit raise XlsxError {
  let limit = if axis == "col" {
    cell_ref_max_cols
  } else if axis == "row" {
    cell_ref_max_rows
  } else {
    raise InvalidXml(msg="drawing axis invalid")
  }
  let at_end_boundary = idx0 == limit && off_emu <= 0
  if idx0 < 0 ||
    idx0 > limit ||
    (idx0 == limit && (!allow_end_boundary || !at_end_boundary)) {
    raise InvalidXml(msg="drawing " + axis.to_owned() + " invalid")
  }
}

///|
fn drawing_reference_for_read(
  row_idx0 : Int,
  col_idx0 : Int,
  row_off_emu : Int,
  col_off_emu : Int,
) -> String raise XlsxError {
  validate_drawing_axis_marker_for_read("row", row_idx0, row_off_emu, false)
  validate_drawing_axis_marker_for_read("col", col_idx0, col_off_emu, false)
  cell_ref_from(row_idx0 + 1, col_idx0 + 1)
}

///|
fn validate_drawing_extent_for_read(
  value : Int,
  field : StringView,
) -> Int raise XlsxError {
  if value < 0 {
    raise InvalidXml(msg=field.to_owned() + " invalid")
  }
  value
}

///|
fn drawing_axis_position_emu_for_read(
  metrics : DrawingAxisMetrics,
  idx0 : Int,
  off_emu : Int,
) -> Int64 raise XlsxError {
  let pixels = metrics.pixel_span(0, idx0)
  let emu_per_pixel = Int64::from_int(picture_emu_per_pixel)
  let max_base = 0x7fff_ffff_ffff_ffffL - 0xffff_ffffL
  if pixels > max_base / emu_per_pixel {
    raise InvalidXml(msg="drawing span out of range")
  }
  pixels * emu_per_pixel + Int64::from_int(off_emu)
}

///|
fn drawing_axis_span_emu(
  metrics : DrawingAxisMetrics,
  from_idx0 : Int,
  from_off_emu : Int,
  to_idx0 : Int,
  to_off_emu : Int,
) -> Int raise XlsxError {
  validate_drawing_axis_marker_for_read(
    metrics.axis,
    from_idx0,
    from_off_emu,
    false,
  )
  validate_drawing_axis_marker_for_read(metrics.axis, to_idx0, to_off_emu, true)
  let from_position = drawing_axis_position_emu_for_read(
    metrics, from_idx0, from_off_emu,
  )
  let to_position = drawing_axis_position_emu_for_read(
    metrics, to_idx0, to_off_emu,
  )
  let span = if to_position >= from_position {
    to_position - from_position
  } else {
    from_position - to_position
  }
  if span > 0x7fff_ffffL {
    raise InvalidXml(msg="drawing span out of range")
  }
  span.to_int()
}

///|
fn drawing_anchor_has_unsupported_reader_object(xml : StringView) -> Bool {
  // Namespace-aware structure validation has already proved that these
  // canonical names can only designate the direct unsupported object (or a
  // descendant of its group subtree), so lexical filtering is safe here.
  xml.contains("<xdr:grpSp") ||
  xml.contains("<xdr:cxnSp") ||
  xml.contains("<xdr:contentPart") ||
  // The semantic shape reader can faithfully reconstruct preset geometry.
  // Treat every other shape geometry as opaque; otherwise a valid custom
  // geometry is skipped by `parse_drawing_shapes` and silently disappears on
  // the next workbook write.
  (
    find_xml_open_tag_start(xml, "xdr:sp") is Some(_) &&
    find_xml_open_tag_start(xml, "a:prstGeom") is None
  )
}

///|
priv enum DrawingAnchorForm {
  OneCellAnchor
  TwoCellAnchor
  AbsoluteAnchor
} derive(Eq, Debug)

///|
priv struct DrawingAnchor {
  xml : String
  positioning : PicturePositioning
  form : DrawingAnchorForm
  order : Int
  unsupported : Bool
}

///|
priv struct DrawingAnchorOrigin {
  reference : String
  col_idx0 : Int
  row_idx0 : Int
  col_off_emu : Int
  row_off_emu : Int
}

///|
fn parse_drawing_int_attr(
  tag : StringView,
  name : StringView,
  invalid_message : String,
  missing_message : String,
) -> Int raise XlsxError {
  match attr_value(tag, name) {
    Some(value) =>
      @string.parse_int(value, base=10) catch {
        _ => raise InvalidXml(msg=invalid_message)
      }
    None => raise InvalidXml(msg=missing_message)
  }
}

///|
fn DrawingAnchor::origin_for_read(
  self : DrawingAnchor,
) -> DrawingAnchorOrigin raise XlsxError {
  if self.form == AbsoluteAnchor {
    let pos_tag = match tag_attributes_in(self.xml, "xdr:pos") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing absolute position missing")
    }
    let x = parse_drawing_int_attr(
      pos_tag, "x", "drawing absolute x invalid", "drawing absolute x missing",
    )
    let y = parse_drawing_int_attr(
      pos_tag, "y", "drawing absolute y invalid", "drawing absolute y missing",
    )
    {
      reference: drawing_reference_for_read(0, 0, y, x),
      col_idx0: 0,
      row_idx0: 0,
      col_off_emu: x,
      row_off_emu: y,
    }
  } else {
    let from_body = match extract_tag_body_from(self.xml, "xdr:from") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing anchor from missing")
    }
    let col_idx0 = parse_xml_int_tag(
      from_body, "xdr:col", "drawing col invalid",
    )
    let row_idx0 = parse_xml_int_tag(
      from_body, "xdr:row", "drawing row invalid",
    )
    let col_off_emu = parse_xml_int_tag(
      from_body, "xdr:colOff", "drawing colOff invalid",
    )
    let row_off_emu = parse_xml_int_tag(
      from_body, "xdr:rowOff", "drawing rowOff invalid",
    )
    {
      reference: drawing_reference_for_read(
        row_idx0, col_idx0, row_off_emu, col_off_emu,
      ),
      col_idx0,
      row_idx0,
      col_off_emu,
      row_off_emu,
    }
  }
}

///|
fn DrawingAnchor::uses_direct_extent(self : DrawingAnchor) -> Bool {
  match self.form {
    OneCellAnchor | AbsoluteAnchor => true
    TwoCellAnchor => false
  }
}

///|
fn DrawingAnchor::extent_for_read(
  self : DrawingAnchor,
  metrics : DrawingMetrics,
  origin : DrawingAnchorOrigin,
  object_name? : String = "",
) -> (Int, Int) raise XlsxError {
  let prefix = if object_name == "" {
    "drawing"
  } else {
    "drawing " + object_name
  }
  if self.uses_direct_extent() {
    let ext_tag = match tag_attributes_in(self.xml, "xdr:ext") {
      Some(value) => value
      None => raise InvalidXml(msg=prefix + " ext missing")
    }
    let cx = parse_drawing_int_attr(
      ext_tag,
      "cx",
      prefix + " cx invalid",
      prefix + " cx missing",
    )
    let cy = parse_drawing_int_attr(
      ext_tag,
      "cy",
      prefix + " cy invalid",
      prefix + " cy missing",
    )
    ignore(validate_drawing_extent_for_read(cx, prefix + " cx"))
    ignore(validate_drawing_extent_for_read(cy, prefix + " cy"))
    (cx, cy)
  } else {
    let to_body = match extract_tag_body_from(self.xml, "xdr:to") {
      Some(value) => value
      None => {
        let target = if object_name == "" { "drawing anchor" } else { prefix }
        raise InvalidXml(msg=target + " to missing")
      }
    }
    let to_col_idx0 = parse_xml_int_tag(
      to_body,
      "xdr:col",
      prefix + " to col invalid",
    )
    let to_row_idx0 = parse_xml_int_tag(
      to_body,
      "xdr:row",
      prefix + " to row invalid",
    )
    let to_col_off = parse_xml_int_tag(
      to_body,
      "xdr:colOff",
      prefix + " to colOff invalid",
    )
    let to_row_off = parse_xml_int_tag(
      to_body,
      "xdr:rowOff",
      prefix + " to rowOff invalid",
    )
    (
      drawing_axis_span_emu(
        metrics.cols,
        origin.col_idx0,
        origin.col_off_emu,
        to_col_idx0,
        to_col_off,
      ),
      drawing_axis_span_emu(
        metrics.rows,
        origin.row_idx0,
        origin.row_off_emu,
        to_row_idx0,
        to_row_off,
      ),
    )
  }
}

///|
fn parse_drawing_anchors(
  drawing_xml : StringView,
  budget? : ReadBudget,
) -> Array[DrawingAnchor] raise XlsxError {
  match budget {
    Some(value) => {
      value.checkpoint()
      value.charge_work(drawing_xml.length())
    }
    None => ()
  }
  let xml_str = drawing_xml.to_owned()
  let anchors : Array[DrawingAnchor] = []
  let anchor_names : ReadOnlyArray[String] = [
    "xdr:oneCellAnchor", "xdr:twoCellAnchor", "xdr:absoluteAnchor",
  ]
  let mut cursor = 0
  let mut scanned = 0
  for ;; {
    let mut next_start : Int? = None
    let mut next_name = ""
    for candidate in anchor_names {
      match find_xml_open_tag_start_from(xml_str, candidate, cursor) {
        Some(start) =>
          match next_start {
            Some(current) if current <= start => ()
            _ => {
              next_start = Some(start)
              next_name = candidate
            }
          }
        None => ()
      }
    }
    let start = match next_start {
      Some(value) => value
      None => break
    }
    if (scanned & 255) == 0 {
      match budget {
        Some(value) => value.checkpoint()
        None => ()
      }
    }
    let close_end = match find_xml_close_tag_from(xml_str, next_name, start) {
      Some((_, value)) => value
      None => {
        let local_name = next_name[4:].to_owned()
        raise InvalidXml(msg=local_name + " close missing")
      }
    }
    let full = xml_str[start:close_end + 1].to_owned()
    let form = if next_name == "xdr:absoluteAnchor" {
      AbsoluteAnchor
    } else if next_name == "xdr:oneCellAnchor" {
      OneCellAnchor
    } else {
      TwoCellAnchor
    }
    let positioning = match form {
      AbsoluteAnchor => Absolute
      OneCellAnchor => OneCell
      TwoCellAnchor =>
        match tag_attributes_in(full, "xdr:twoCellAnchor") {
          Some(tag) =>
            match attr_value(tag, "editAs") {
              Some("absolute") => Absolute
              Some("oneCell") => OneCell
              Some("twoCell") | None => TwoCell
              Some(_) => raise InvalidXml(msg="drawing editAs value is invalid")
            }
          None => TwoCell
        }
    }
    anchors.push({
      xml: full,
      positioning,
      form,
      order: scanned,
      unsupported: drawing_anchor_has_unsupported_reader_object(full),
    })
    scanned += 1
    cursor = close_end + 1
  }
  match budget {
    Some(value) => value.checkpoint()
    None => ()
  }
  anchors
}

///|
fn charge_drawing_work(
  budget : ReadBudget?,
  units : Int,
) -> Unit raise XlsxError {
  match budget {
    Some(value) => {
      value.checkpoint()
      value.charge_work(units)
    }
    None => ()
  }
}

///|
fn charge_drawing_anchor_pass(
  budget : ReadBudget?,
  anchor_xml : StringView,
) -> Unit raise XlsxError {
  charge_drawing_work(budget, anchor_xml.length())
}

///|
/// Returns the sole chart relationship selected by a chart-sheet drawing.
/// Drawing structure validation has already proved the canonical `c:chart`
/// path and relationship-attribute dialect; this pass enforces chart-sheet
/// cardinality and keeps relationship lookup tied to that exact payload.
fn single_drawing_chart_rel_id(
  anchors : ArrayView[DrawingAnchor],
  budget? : ReadBudget,
) -> String raise XlsxError {
  let mut selected : String? = None
  for anchor in anchors {
    if anchor.unsupported {
      continue
    }
    let anchor_xml = anchor.xml
    charge_drawing_anchor_pass(budget, anchor_xml)
    match tag_attributes_in(anchor_xml, "c:chart") {
      Some(tag) => {
        if selected is Some(_) {
          raise InvalidXml(msg="chartsheet drawing has multiple charts")
        }
        selected = match attr_value(tag, "r:id") {
          Some(value) if value.length() > 0 => Some(value.to_string())
          _ => raise InvalidXml(msg="chartsheet chart rel id missing")
        }
      }
      None => ()
    }
  }
  match selected {
    Some(value) => value
    None => raise InvalidXml(msg="chartsheet chart payload missing")
  }
}

///|
/// Returns the shape-level solid fill, never a line-level fill nested later in
/// `a:ln`. Drawing structure validation has already rejected every other
/// `a:solidFill` path before the canonical reader reaches this helper.
fn drawing_shape_solid_fill_body(sppr_body : StringView) -> String? {
  let fill_start = match find_xml_open_tag_start(sppr_body, "a:solidFill") {
    Some(value) => value
    None => return None
  }
  match find_xml_open_tag_start(sppr_body, "a:ln") {
    Some(line_start) if line_start < fill_start => return None
    _ => ()
  }
  extract_tag_body_from(sppr_body, "a:solidFill")
}

///|
fn drawing_text_bool_attribute(
  tag : StringView,
  name : StringView,
) -> Bool raise XlsxError {
  match attr_value(tag, name) {
    Some(value) => parse_bool_attr(value)
    None => false
  }
}

///|
fn parse_drawing_text_font(
  container_body : StringView,
) -> RichTextFont? raise XlsxError {
  let rpr_tag = match tag_attributes_in(container_body, "a:rPr") {
    Some(value) => value
    None => return None
  }
  let bold = drawing_text_bool_attribute(rpr_tag, "b")
  let italic = drawing_text_bool_attribute(rpr_tag, "i")
  let strike = match attr_value(rpr_tag, "strike") {
    Some("sngStrike") | Some("dblStrike") => true
    Some("noStrike") | None => false
    Some(_) => raise InvalidXml(msg="drawing text strike is invalid")
  }
  let underline = match attr_value(rpr_tag, "u") {
    Some("none") | None => None
    Some(value) => Some(unescape_xml_text(value))
  }
  let size = match attr_value(rpr_tag, "sz") {
    Some(value) => {
      let parsed = @string.parse_int(value, base=10) catch {
        _ => raise InvalidXml(msg="drawing text size is invalid")
      }
      if parsed < 0 {
        raise InvalidXml(msg="drawing text size is invalid")
      }
      Some(parsed.to_double() / 100.0)
    }
    None => None
  }
  let rpr_body = extract_tag_body_from(container_body, "a:rPr").unwrap_or("")
  let source = "<root xmlns:a=\"" +
    transitional_drawing_main_namespace +
    "\">" +
    rpr_body +
    "</root>"
  let scanner = @ooxml.XmlStartTagScanner::new(source)
  let mut family : String? = None
  let mut color : String? = None
  let mut direct_solid_fill = false
  while workbook_scanner_next(scanner) {
    let depth = scanner.depth()
    if depth <= 2 {
      direct_solid_fill = false
    }
    if depth == 2 &&
      scanner.namespace_uri() == transitional_drawing_main_namespace &&
      scanner.parent_local_name() == Some("root") {
      if scanner.local_name() == "latin" && family is None {
        family = workbook_scanner_attribute(scanner, "", "typeface")
      } else if scanner.local_name() == "solidFill" {
        direct_solid_fill = true
      }
    } else if direct_solid_fill &&
      depth == 3 &&
      scanner.namespace_uri() == transitional_drawing_main_namespace &&
      scanner.local_name() == "srgbClr" &&
      scanner.parent_local_name() == Some("solidFill") &&
      scanner.parent_namespace_uri() ==
      Some(transitional_drawing_main_namespace) &&
      color is None {
      color = match workbook_scanner_attribute(scanner, "", "val") {
        Some(value) if value != "" => Some(value)
        _ => raise InvalidXml(msg="drawing text color is invalid")
      }
    }
  }
  if bold ||
    italic ||
    strike ||
    underline is Some(_) ||
    size is Some(_) ||
    family is Some(_) ||
    color is Some(_) {
    Some({
      bold,
      italic,
      strike,
      outline: false,
      shadow: false,
      condense: false,
      extended: false,
      underline,
      size,
      color,
      color_theme: None,
      color_indexed: None,
      color_tint: None,
      charset: None,
      family_number: None,
      scheme: None,
      vert_align: None,
      family,
    })
  } else {
    None
  }
}

///|
fn parse_drawing_shape_text_runs(
  tx_body : StringView,
) -> Array[RichTextRun] raise XlsxError {
  let runs : Array[RichTextRun] = []
  let source = tx_body.to_owned()
  let container_names : ReadOnlyArray[String] = ["a:r", "a:fld", "a:br"]
  let mut cursor = 0
  for ;; {
    let mut next_start : Int? = None
    let mut next_name = ""
    for candidate in container_names {
      match find_xml_open_tag_start_from(source, candidate, cursor) {
        Some(start) =>
          match next_start {
            Some(current) if current <= start => ()
            _ => {
              next_start = Some(start)
              next_name = candidate
            }
          }
        None => ()
      }
    }
    let start = match next_start {
      Some(value) => value
      None => break
    }
    let open_end = match xml_open_tag_end_from(source, start + 1) {
      Some(value) => value
      None => raise InvalidXml(msg="drawing text tag is not closed")
    }
    let self_closing = source[start + 1:open_end].trim().has_suffix("/")
    let (container_body, close_end) = if self_closing {
      ("", open_end)
    } else {
      let (close_start, end) = match
        find_xml_close_tag_from(source, next_name, open_end + 1) {
        Some(value) => value
        None => raise InvalidXml(msg="drawing text close is missing")
      }
      (source[open_end + 1:close_start].to_owned(), end)
    }
    if next_name == "a:br" {
      runs.push({ text: "\n", font: parse_drawing_text_font(container_body) })
    } else {
      let text = match extract_tag_body_from(container_body, "a:t") {
        Some(value) => unescape_xml_text(value)
        None =>
          if tag_attributes_in(container_body, "a:t") is Some(_) {
            ""
          } else {
            raise InvalidXml(msg="drawing text value is missing")
          }
      }
      runs.push({ text, font: parse_drawing_text_font(container_body) })
    }
    cursor = close_end + 1
  }
  runs
}

///|
fn parse_drawing_images(
  anchors : ArrayView[DrawingAnchor],
  drawing_rels_xml : StringView,
  drawing_part : StringView,
  part_names : Map[String, String],
  content_types : @ooxml.PackageContentTypes,
  metrics : DrawingMetrics,
  archive : @zip.Archive,
  media_cache? : Map[String, Bytes],
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> Array[Image] raise XlsxError {
  let images : Array[Image] = []
  let retained_media = media_cache.unwrap_or(Map([]))
  let image_targets = if drawing_rels_xml is "" {
    Map([])
  } else {
    parse_internal_relationship_targets(
      drawing_rels_xml,
      rel_image,
      budget?,
      cancelled~,
    )
  }
  let hyperlink_targets = if drawing_rels_xml is "" {
    Map([])
  } else {
    parse_external_relationship_targets(
      drawing_rels_xml,
      rel_hyperlink,
      budget?,
      cancelled~,
    )
  }
  // location links (e.g. "Sheet1!B2") are written as internal-mode
  // relationships by this library's own writer; reading only external-mode
  // records would drop them on round-trip
  let location_hyperlink_targets = if drawing_rels_xml is "" {
    Map([])
  } else {
    parse_internal_relationship_targets(
      drawing_rels_xml,
      rel_hyperlink,
      budget?,
      cancelled~,
    )
  }
  for anchor in anchors {
    if anchor.unsupported {
      continue
    }
    let anchor_xml = anchor.xml
    let positioning = anchor.positioning
    charge_drawing_anchor_pass(budget, anchor_xml)
    let pic_body = match extract_tag_body_from(anchor_xml, "xdr:pic") {
      Some(value) => value
      None => continue
    }
    let origin = anchor.origin_for_read()
    let reference = origin.reference
    let offset_x = origin.col_off_emu / picture_emu_per_pixel
    let offset_y = origin.row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = anchor.extent_for_read(metrics, origin)
    let c_nv_pr_tag = match tag_attributes_in(pic_body, "xdr:cNvPr") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing cNvPr missing")
    }
    let name = match attr_value(c_nv_pr_tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let alt_text = match attr_value(c_nv_pr_tag, "descr") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let lock_aspect_ratio = match tag_attributes_in(pic_body, "a:picLocks") {
      Some(tag) =>
        match attr_value(tag, "noChangeAspect") {
          Some(value) => parse_bool_attr(value)
          None => false
        }
      None => false
    }
    let client_tag = match tag_attributes_in(anchor_xml, "xdr:clientData") {
      Some(value) => value
      None => ""
    }
    let locked = match attr_value(client_tag, "fLocksWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let print_object = match attr_value(client_tag, "fPrintsWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let blip_tag = match tag_attributes_in(pic_body, "a:blip") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing blip missing")
    }
    let embed_id = match attr_value(blip_tag, "r:embed") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing embed missing")
    }
    let target = match image_targets.get(embed_id.to_string()) {
      Some(value) => value
      None => raise InvalidXml(msg="drawing image target missing")
    }
    let media_path = actual_relationship_target_path(
      drawing_part,
      target,
      part_names,
      cancelled~,
    )
    let (source_data, identity) = load_image_part(
      archive,
      content_types,
      media_path,
      "drawing image",
      cancelled~,
    )
    let data = match retained_media.get(media_path) {
      Some(value) => value
      None => {
        let value = source_data.to_owned()
        retained_media[media_path] = value
        value
      }
    }
    let mut hyperlink = ""
    let mut hyperlink_type = HyperlinkType::Unset
    match tag_attributes_in(pic_body, "a:hlinkClick") {
      Some(tag) =>
        match attr_value(tag, "r:id") {
          Some(rel_id) =>
            match hyperlink_targets.get(rel_id.to_string()) {
              Some(value) => {
                hyperlink = value
                hyperlink_type = External
              }
              None =>
                match location_hyperlink_targets.get(rel_id.to_string()) {
                  Some(value) => {
                    hyperlink = value
                    hyperlink_type = Location
                  }
                  None => ()
                }
            }
          None => ()
        }
      None => ()
    }
    images.push({
      reference,
      data,
      extension: identity.extension,
      content_type: identity.content_type,
      offset_x,
      offset_y,
      scale_x: 1.0,
      scale_y: 1.0,
      width_emu,
      height_emu,
      print_object,
      locked,
      hyperlink,
      hyperlink_type,
      name,
      alt_text,
      lock_aspect_ratio,
      positioning,
      drawing_offset_x_emu: Some(origin.col_off_emu),
      drawing_offset_y_emu: Some(origin.row_off_emu),
      drawing_width_emu: Some(width_emu),
      drawing_height_emu: Some(height_emu),
      drawing_order: Some(anchor.order),
    })
  }
  images
}

///|
fn parse_drawing_charts(
  anchors : ArrayView[DrawingAnchor],
  drawing_rels_xml : StringView,
  drawing_part : StringView,
  part_names : Map[String, String],
  content_types : @ooxml.PackageContentTypes,
  metrics : DrawingMetrics,
  archive : @zip.Archive,
  decode : (BytesView) -> String raise XlsxError,
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> Array[Chart] raise XlsxError {
  let charts : Array[Chart] = []
  let chart_targets = if drawing_rels_xml is "" {
    Map([])
  } else {
    parse_internal_relationship_targets(
      drawing_rels_xml,
      rel_chart,
      budget?,
      cancelled~,
    )
  }
  for anchor in anchors {
    if anchor.unsupported {
      continue
    }
    let anchor_xml = anchor.xml
    let positioning = anchor.positioning
    charge_drawing_anchor_pass(budget, anchor_xml)
    let chart_tag = match tag_attributes_in(anchor_xml, "c:chart") {
      Some(value) => value
      None => continue
    }
    let rel_id = match attr_value(chart_tag, "r:id") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing chart rel id missing")
    }
    let target = match chart_targets.get(rel_id.to_string()) {
      Some(value) => value
      None => raise InvalidXml(msg="drawing chart target missing")
    }
    let chart_path = actual_relationship_target_path(
      drawing_part,
      target,
      part_names,
      cancelled~,
    )
    require_part_content_type(
      content_types,
      logical_archive_part_path(chart_path),
      [ct_chart],
      "chart",
      cancelled~,
    )
    let chart_bytes = match archive.get(chart_path) {
      Some(value) => value
      None => raise MissingPart(path=chart_path)
    }
    let xml = decode(chart_bytes)
    let origin = anchor.origin_for_read()
    let reference = origin.reference
    let offset_x = origin.col_off_emu / picture_emu_per_pixel
    let offset_y = origin.row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = anchor.extent_for_read(metrics, origin)
    let client_tag = match tag_attributes_in(anchor_xml, "xdr:clientData") {
      Some(value) => value
      None => ""
    }
    let locked = match attr_value(client_tag, "fLocksWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let print_object = match attr_value(client_tag, "fPrintsWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let drawing_frame_canonical = drawing_chart_frame_is_canonical(
      anchor_xml,
      width_emu,
      height_emu,
      locked,
      print_object,
      budget?,
      cancelled~,
    )
    charts.push({
      reference,
      xml,
      offset_x,
      offset_y,
      width_emu,
      height_emu,
      print_object,
      locked,
      positioning,
      drawing_offset_x_emu: Some(origin.col_off_emu),
      drawing_offset_y_emu: Some(origin.row_off_emu),
      drawing_width_emu: Some(width_emu),
      drawing_height_emu: Some(height_emu),
      drawing_order: Some(anchor.order),
      drawing_frame_canonical,
    })
  }
  charts
}

///|
/// Checks the complete graphic-frame subtree against the exact structural
/// subset the writer can regenerate from `Chart`. A single namespace-aware
/// scan rejects additional attributes, children, locks, names, alternative
/// text, or transforms instead of accepting the first familiar descendant.
fn drawing_chart_frame_is_canonical(
  anchor_xml : StringView,
  width_emu : Int,
  height_emu : Int,
  locked : Bool,
  print_object : Bool,
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> Bool raise XlsxError {
  if cancelled() {
    raise ReadCancelled
  }
  let wrapper_prefix = "<frame-root xmlns:xdr=\"" +
    transitional_spreadsheet_drawing_namespace +
    "\" xmlns:a=\"" +
    transitional_drawing_main_namespace +
    "\" xmlns:c=\"" +
    transitional_drawing_chart_namespace +
    "\" xmlns:r=\"" +
    transitional_relationship_attribute_namespace +
    "\">"
  let wrapper_suffix = "</frame-root>"
  let wrapped_length = wrapper_prefix.length() +
    anchor_xml.length() +
    wrapper_suffix.length()
  // Preflight the retained-fragment materialization. The two wrapped charges
  // cover the scanner's complete pass (including character-data
  // classification) and the exact-attribute pass. Attribute values are
  // extracted during that exact pass, so there are no hidden rescans.
  charge_drawing_work(budget, wrapped_length)
  let wrapper = StringBuilder::new(size_hint=wrapped_length)
  wrapper.write_string(wrapper_prefix)
  wrapper.write_view(anchor_xml)
  wrapper.write_string(wrapper_suffix)
  let wrapped = wrapper.to_string()
  charge_drawing_anchor_pass(budget, wrapped)
  charge_drawing_anchor_pass(budget, wrapped)
  try {
    let scanner = @ooxml.XmlStartTagScanner::new(wrapped, cancelled~)
    let drawing_namespace = transitional_spreadsheet_drawing_namespace
    let main_namespace = transitional_drawing_main_namespace
    let chart_namespace = transitional_drawing_chart_namespace
    let relationship_namespace = transitional_relationship_attribute_namespace
    let mut step = 0
    let mut frame_id = ""
    while workbook_scanner_next(scanner) {
      let depth = scanner.depth()
      let local_name = scanner.local_name()
      let namespace_uri = scanner.namespace_uri()
      if step == 0 {
        let direct_frame = depth == 3 &&
          namespace_uri == drawing_namespace &&
          local_name == "graphicFrame" &&
          scanner.parent_namespace_uri() == Some(drawing_namespace) &&
          scanner
          .parent_local_name()
          .map(name => xlsx_drawing_anchor_name(name))
          .unwrap_or(false)
        if direct_frame {
          guard workbook_scanner_has_exact_attributes(scanner, []) else {
            return false
          }
          step = 1
        }
        continue
      }
      if !scanner.intervening_character_data_is_whitespace() {
        return false
      }
      let matched = match step {
        1 =>
          depth == 4 &&
          namespace_uri == drawing_namespace &&
          local_name == "nvGraphicFramePr" &&
          scanner.parent_namespace_uri() == Some(drawing_namespace) &&
          scanner.parent_local_name() == Some("graphicFrame") &&
          workbook_scanner_has_exact_attributes(scanner, [])
        2 => {
          guard depth == 5 &&
            namespace_uri == drawing_namespace &&
            local_name == "cNvPr" &&
            scanner.parent_namespace_uri() == Some(drawing_namespace) &&
            scanner.parent_local_name() == Some("nvGraphicFramePr") else {
            return false
          }
          guard workbook_scanner_exact_attribute_values(scanner, [
              ("", "id"),
              ("", "name"),
            ])
            is Some(attributes) else {
            return false
          }
          frame_id = attributes[0]
          guard frame_id != "" else { return false }
          let parsed_id = @string.parse_int(frame_id, base=10) catch {
            _ => return false
          }
          parsed_id > 0 &&
          frame_id == "\{parsed_id}" &&
          attributes[1] == "Chart " + frame_id
        }
        3 =>
          depth == 5 &&
          namespace_uri == drawing_namespace &&
          local_name == "cNvGraphicFramePr" &&
          scanner.parent_namespace_uri() == Some(drawing_namespace) &&
          scanner.parent_local_name() == Some("nvGraphicFramePr") &&
          workbook_scanner_has_exact_attributes(scanner, [])
        4 =>
          depth == 4 &&
          namespace_uri == drawing_namespace &&
          local_name == "xfrm" &&
          scanner.parent_namespace_uri() == Some(drawing_namespace) &&
          scanner.parent_local_name() == Some("graphicFrame") &&
          workbook_scanner_has_exact_attributes(scanner, [])
        5 =>
          depth == 5 &&
          namespace_uri == main_namespace &&
          local_name == "off" &&
          scanner.parent_namespace_uri() == Some(drawing_namespace) &&
          scanner.parent_local_name() == Some("xfrm") &&
          workbook_scanner_has_exact_attributes(scanner, [
            ("", "x", "0"),
            ("", "y", "0"),
          ])
        6 =>
          depth == 5 &&
          namespace_uri == main_namespace &&
          local_name == "ext" &&
          scanner.parent_namespace_uri() == Some(drawing_namespace) &&
          scanner.parent_local_name() == Some("xfrm") &&
          workbook_scanner_has_exact_attributes(scanner, [
            ("", "cx", "\{width_emu}"),
            ("", "cy", "\{height_emu}"),
          ])
        7 =>
          depth == 4 &&
          namespace_uri == main_namespace &&
          local_name == "graphic" &&
          scanner.parent_namespace_uri() == Some(drawing_namespace) &&
          scanner.parent_local_name() == Some("graphicFrame") &&
          workbook_scanner_has_exact_attributes(scanner, [])
        8 =>
          depth == 5 &&
          namespace_uri == main_namespace &&
          local_name == "graphicData" &&
          scanner.parent_namespace_uri() == Some(main_namespace) &&
          scanner.parent_local_name() == Some("graphic") &&
          workbook_scanner_has_exact_attributes(scanner, [
            ("", "uri", chart_namespace),
          ])
        9 => {
          guard depth == 6 &&
            namespace_uri == chart_namespace &&
            local_name == "chart" &&
            scanner.parent_namespace_uri() == Some(main_namespace) &&
            scanner.parent_local_name() == Some("graphicData") else {
            return false
          }
          guard workbook_scanner_exact_attribute_values(scanner, [
              (relationship_namespace, "id"),
            ])
            is Some(attributes) else {
            return false
          }
          attributes[0] != ""
        }
        10 =>
          depth == 3 &&
          namespace_uri == drawing_namespace &&
          local_name == "clientData" &&
          scanner.parent_namespace_uri() == Some(drawing_namespace) &&
          scanner
          .parent_local_name()
          .map(name => xlsx_drawing_anchor_name(name))
          .unwrap_or(false) &&
          workbook_scanner_has_exact_attributes(scanner, [
            ("", "fLocksWithSheet", if locked { "1" } else { "0" }),
            ("", "fPrintsWithSheet", if print_object { "1" } else { "0" }),
          ])
        _ => false
      }
      if !matched {
        return false
      }
      step += 1
    }
    step == 11 &&
    frame_id != "" &&
    scanner.intervening_character_data_is_whitespace()
  } catch {
    InvalidXml(_) => false
    ReadCancelled => raise ReadCancelled
    error => raise error
  }
}

///|
fn parse_drawing_shapes(
  anchors : ArrayView[DrawingAnchor],
  metrics : DrawingMetrics,
  budget? : ReadBudget,
) -> Array[Shape] raise XlsxError {
  let shapes : Array[Shape] = []
  for anchor in anchors {
    if anchor.unsupported {
      continue
    }
    let anchor_xml = anchor.xml
    let positioning = anchor.positioning
    charge_drawing_anchor_pass(budget, anchor_xml)
    let sp_body = match extract_tag_body_from(anchor_xml, "xdr:sp") {
      Some(value) => value
      None => continue
    }
    if !sp_body.contains("<a:prstGeom") {
      continue
    }
    let origin = anchor.origin_for_read()
    let reference = origin.reference
    let (cx, cy) = anchor.extent_for_read(metrics, origin, object_name="shape")
    let c_nv_pr_tag = match tag_attributes_in(sp_body, "xdr:cNvPr") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing shape cNvPr missing")
    }
    let name = match attr_value(c_nv_pr_tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let alt_text = match attr_value(c_nv_pr_tag, "descr") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let macro_name = match attr_value(c_nv_pr_tag, "macro") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let client_tag = match tag_attributes_in(anchor_xml, "xdr:clientData") {
      Some(value) => value
      None => ""
    }
    let locked = match attr_value(client_tag, "fLocksWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let print_object = match attr_value(client_tag, "fPrintsWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let sppr_body = match extract_tag_body_from(sp_body, "xdr:spPr") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing shape spPr missing")
    }
    let width = (cx.to_double() / picture_emu_per_pixel.to_double())
      .round()
      .to_int()
    let height = (cy.to_double() / picture_emu_per_pixel.to_double())
      .round()
      .to_int()
    let geom_tag = match tag_attributes_in(sppr_body, "a:prstGeom") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing shape prstGeom missing")
    }
    let shape_type = match attr_value(geom_tag, "prst") {
      Some(value) => unescape_xml_text(value)
      None => raise InvalidXml(msg="drawing shape prst missing")
    }
    let mut fill_color = ""
    let mut fill_transparency = 0
    match drawing_shape_solid_fill_body(sppr_body) {
      Some(fill_body) =>
        match tag_attributes_in(fill_body, "a:srgbClr") {
          Some(tag) =>
            match attr_value(tag, "val") {
              Some(value) => {
                fill_color = unescape_xml_text(value)
                match tag_attributes_in(fill_body, "a:alpha") {
                  Some(alpha_tag) =>
                    match attr_value(alpha_tag, "val") {
                      Some(alpha) =>
                        try @string.parse_int(alpha, base=10) catch {
                          _ => ()
                        } noraise {
                          value => {
                            let visible = value / 1000
                            let transparency = 100 - visible
                            if transparency >= 0 && transparency <= 100 {
                              fill_transparency = transparency
                            }
                          }
                        }
                      None => ()
                    }
                  None => ()
                }
              }
              None => ()
            }
          None => ()
        }
      None => ()
    }
    let mut line_color = ""
    let mut line_width = 1.0
    match tag_attributes_in(sppr_body, "a:ln") {
      Some(tag) => {
        match attr_value(tag, "w") {
          Some(value) =>
            try @string.parse_int(value, base=10) catch {
              _ => ()
            } noraise {
              value => line_width = value.to_double() / 12700.0
            }
          None => ()
        }
        match extract_tag_body_from(sppr_body, "a:ln") {
          Some(ln_body) =>
            match tag_attributes_in(ln_body, "a:srgbClr") {
              Some(color_tag) =>
                match attr_value(color_tag, "val") {
                  Some(value) => line_color = unescape_xml_text(value)
                  None => ()
                }
              None => ()
            }
          None => ()
        }
      }
      None => ()
    }
    let paragraph = match extract_tag_body_from(sp_body, "xdr:txBody") {
      Some(tx_body) => parse_drawing_shape_text_runs(tx_body)
      None => []
    }
    let text = ""
    let format = shape_graphic_options(
      1.0, 1.0, name, alt_text, print_object, locked, positioning,
    )
    let offset_x = origin.col_off_emu / picture_emu_per_pixel
    let offset_y = origin.row_off_emu / picture_emu_per_pixel
    if offset_x != 0 {
      format.offset_x = Some(offset_x)
    }
    if offset_y != 0 {
      format.offset_y = Some(offset_y)
    }
    let fill = shape_fill_from_values(fill_color, fill_transparency)
    let line = shape_line_from_values(line_color, line_width)
    shapes.push({
      reference,
      cell: reference,
      shape_type,
      macro_alias: macro_name,
      macro_name,
      format,
      text,
      paragraph,
      width,
      height,
      scale_x: 1.0,
      scale_y: 1.0,
      fill,
      fill_color,
      fill_transparency,
      line,
      line_color,
      line_width,
      name,
      alt_text,
      print_object,
      locked,
      positioning,
      drawing_offset_x_emu: Some(origin.col_off_emu),
      drawing_offset_y_emu: Some(origin.row_off_emu),
      drawing_width_emu: Some(cx),
      drawing_height_emu: Some(cy),
      drawing_order: Some(anchor.order),
    })
  }
  shapes
}

///|
priv struct SlicerAnchorInfo {
  cell : String
  offset_x : Int
  offset_y : Int
  width : Int
  height : Int
  positioning : PicturePositioning
  macro_name : String
  alt_text : String
  locked : Bool
  print_object : Bool
  offset_x_emu : Int
  offset_y_emu : Int
  width_emu : Int
  height_emu : Int
  order : Int
}

///|
fn parse_drawing_slicer_anchors(
  anchors : ArrayView[DrawingAnchor],
  metrics : DrawingMetrics,
  budget? : ReadBudget,
) -> Map[String, SlicerAnchorInfo] raise XlsxError {
  let out : Map[String, SlicerAnchorInfo] = Map([])
  for anchor in anchors {
    if anchor.unsupported {
      continue
    }
    let anchor_xml = anchor.xml
    let positioning = anchor.positioning
    charge_drawing_anchor_pass(budget, anchor_xml)
    let slicer_tag = match tag_attributes_in(anchor_xml, "sle:slicer") {
      Some(value) => value
      None => continue
    }
    let slicer_name = match attr_value(slicer_tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => continue
    }
    let origin = anchor.origin_for_read()
    let cell = origin.reference
    let offset_x = origin.col_off_emu / picture_emu_per_pixel
    let offset_y = origin.row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = anchor.extent_for_read(
      metrics,
      origin,
      object_name="slicer",
    )
    let width = (width_emu.to_double() / picture_emu_per_pixel.to_double())
      .round()
      .to_int()
    let height = (height_emu.to_double() / picture_emu_per_pixel.to_double())
      .round()
      .to_int()
    let graphic_frame_tag = match
      tag_attributes_in(anchor_xml, "xdr:graphicFrame") {
      Some(value) => value
      None => ""
    }
    let macro_name = match attr_value(graphic_frame_tag, "macro") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let c_nv_pr_tag = match tag_attributes_in(anchor_xml, "xdr:cNvPr") {
      Some(value) => value
      None => ""
    }
    let alt_text = match attr_value(c_nv_pr_tag, "descr") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let client_tag = match tag_attributes_in(anchor_xml, "xdr:clientData") {
      Some(value) => value
      None => ""
    }
    let locked = match attr_value(client_tag, "fLocksWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    let print_object = match attr_value(client_tag, "fPrintsWithSheet") {
      Some(value) => parse_bool_attr(value)
      None => true
    }
    out[slicer_name] = {
      cell,
      offset_x,
      offset_y,
      width,
      height,
      positioning,
      macro_name,
      alt_text,
      locked,
      print_object,
      offset_x_emu: origin.col_off_emu,
      offset_y_emu: origin.row_off_emu,
      width_emu,
      height_emu,
      order: anchor.order,
    }
  }
  out
}

///|
fn wb_from_xml() -> String {
  "<xdr:from><xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>0</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>"
}

///|
fn wb_pic_xml(embed_id : String) -> String {
  "<xdr:pic><xdr:nvPicPr><xdr:cNvPr id=\"1\" name=\"Pic 1\" descr=\"Alt\"/></xdr:nvPicPr><xdr:blipFill><a:blip r:embed=\"\{embed_id}\"/></xdr:blipFill></xdr:pic>"
}

///|
fn wb_one_cell_anchor(xml_from : String, xml_ext : String) -> String {
  let pic = wb_pic_xml("rId1")
  "<xdr:wsDr><xdr:oneCellAnchor>\{xml_from}\{xml_ext}\{pic}<xdr:clientData/></xdr:oneCellAnchor></xdr:wsDr>"
}

///|
fn wb_two_cell_anchor(xml_from : String, xml_to : String) -> String {
  let pic = wb_pic_xml("rId1")
  "<xdr:wsDr><xdr:twoCellAnchor>\{xml_from}\{xml_to}\{pic}<xdr:clientData/></xdr:twoCellAnchor></xdr:wsDr>"
}

///|
fn wb_rels_image_target(target : String) -> String {
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"\{target}\"/>" +
  "</Relationships>"
}

///|
fn wb_canonical_chart_anchor() -> String {
  let anchor =
    #|<xdr:oneCellAnchor>
    #|  <xdr:from><xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>0</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>
    #|  <xdr:ext cx="9525" cy="9525"/>
    #|  <xdr:graphicFrame>
    #|    <xdr:nvGraphicFramePr>
    #|      <xdr:cNvPr id="1" name="Chart 1"/>
    #|      <xdr:cNvGraphicFramePr/>
    #|    </xdr:nvGraphicFramePr>
    #|    <xdr:xfrm>
    #|      <a:off x="0" y="0"/>
    #|      <a:ext cx="9525" cy="9525"/>
    #|    </xdr:xfrm>
    #|    <a:graphic>
    #|      <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">
    #|        <c:chart r:id="rId1"/>
    #|      </a:graphicData>
    #|    </a:graphic>
    #|  </xdr:graphicFrame>
    #|  <xdr:clientData fLocksWithSheet="1" fPrintsWithSheet="1"/>
    #|</xdr:oneCellAnchor>
  anchor
}

///|
test "DrawingML MCE fallback feeds image chart shape and slicer readers" {
  let source =
    #|<wsDr xmlns="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:d="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:q="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:rel="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:compat="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:sl="http://schemas.microsoft.com/office/drawing/2010/slicer" xmlns:future="urn:future-drawing">
    #|  <oneCellAnchor><from><col>0</col><colOff>0</colOff><row>0</row><rowOff>0</rowOff></from><ext cx="9525" cy="9525"/><compat:AlternateContent><compat:Choice Requires="future"><pic><nvPicPr><cNvPr id="1" name="bad-image"/></nvPicPr><blipFill><d:blip rel:embed="image-bad"/></blipFill></pic></compat:Choice><compat:Fallback><pic><nvPicPr><cNvPr id="2" name="good-image"/></nvPicPr><blipFill><d:blip rel:embed="image-good"/></blipFill></pic></compat:Fallback></compat:AlternateContent><clientData/></oneCellAnchor>
    #|  <oneCellAnchor><from><col>1</col><colOff>0</colOff><row>0</row><rowOff>0</rowOff></from><ext cx="9525" cy="9525"/><compat:AlternateContent><compat:Choice Requires="future"><graphicFrame><d:graphic><d:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"><q:chart rel:id="chart-bad"/></d:graphicData></d:graphic></graphicFrame></compat:Choice><compat:Fallback><graphicFrame><d:graphic><d:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"><q:chart rel:id="chart-good"/></d:graphicData></d:graphic></graphicFrame></compat:Fallback></compat:AlternateContent><clientData/></oneCellAnchor>
    #|  <oneCellAnchor><from><col>2</col><colOff>0</colOff><row>0</row><rowOff>0</rowOff></from><ext cx="9525" cy="9525"/><compat:AlternateContent><compat:Choice Requires="future"><sp><nvSpPr><cNvPr id="3" name="bad-shape"/></nvSpPr><spPr><d:xfrm><d:ext cx="9525" cy="9525"/></d:xfrm><d:prstGeom prst="bad"/></spPr></sp></compat:Choice><compat:Fallback><sp><nvSpPr><cNvPr id="4" name="good-shape"/></nvSpPr><spPr><d:xfrm><d:ext cx="9525" cy="9525"/></d:xfrm><d:prstGeom prst="rect"/></spPr></sp></compat:Fallback></compat:AlternateContent><clientData/></oneCellAnchor>
    #|  <oneCellAnchor><from><col>3</col><colOff>0</colOff><row>0</row><rowOff>0</rowOff></from><ext cx="9525" cy="9525"/><compat:AlternateContent><compat:Choice Requires="future"><graphicFrame macro="bad-macro"><nvGraphicFramePr><cNvPr id="5" descr="bad-slicer"/></nvGraphicFramePr><d:graphic><d:graphicData uri="http://schemas.microsoft.com/office/drawing/2010/slicer"><sl:slicer name="slicer-bad"/></d:graphicData></d:graphic></graphicFrame></compat:Choice><compat:Fallback><graphicFrame macro="good-macro"><nvGraphicFramePr><cNvPr id="6" descr="good-slicer"/></nvGraphicFramePr><d:graphic><d:graphicData uri="http://schemas.microsoft.com/office/drawing/2010/slicer"><sl:slicer name="slicer-good"/></d:graphicData></d:graphic></graphicFrame></compat:Fallback></compat:AlternateContent><clientData/></oneCellAnchor>
    #|</wsDr>
  let drawing = canonicalize_xlsx_drawing_xml(
    source, default_max_xml_part_bytes,
  )
  assert_false(drawing.contains("bad-image"))
  assert_false(drawing.contains("chart-bad"))
  assert_false(drawing.contains("bad-shape"))
  assert_false(drawing.contains("slicer-bad"))
  assert_false(drawing.contains("<mc:AlternateContent"))
  let anchors = parse_drawing_anchors(drawing)
  inspect(anchors.length(), content="4")
  let rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|  <Relationship Id="image-good" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/good.png"/>
    #|  <Relationship Id="chart-good" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart" Target="../charts/good.xml"/>
    #|</Relationships>
  let content_types = try! @ooxml.parse_package_content_types(
    (
      #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      #|  <Default Extension="png" ContentType="image/png"/>
      #|  <Override PartName="/xl/charts/good.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>
      #|</Types>
    ),
  )
  let archive = @zip.Archive::new()
  archive.add("xl/media/good.png", @encoding/utf8.encode("good-image"))
  archive.add("xl/charts/good.xml", @encoding/utf8.encode("good-chart"))
  let metrics = drawing_metrics_for_sheet(Worksheet::new("Sheet1"))
  let images = parse_drawing_images(
    anchors,
    rels,
    "xl/drawings/drawing1.xml",
    Map([]),
    content_types,
    metrics,
    archive,
  )
  inspect(images.length(), content="1")
  inspect(images[0].name, content="good-image")
  let charts = parse_drawing_charts(
    anchors,
    rels,
    "xl/drawings/drawing1.xml",
    Map([]),
    content_types,
    metrics,
    archive,
    decode_utf8_or_invalid_xml,
  )
  inspect(charts.length(), content="1")
  inspect(charts[0].xml, content="good-chart")
  let shapes = parse_drawing_shapes(anchors, metrics)
  inspect(shapes.length(), content="1")
  inspect(shapes[0].name, content="good-shape")
  inspect(shapes[0].shape_type, content="rect")
  let slicers = parse_drawing_slicer_anchors(anchors, metrics)
  guard slicers.get("slicer-good") is Some(slicer) else {
    fail("expected projected slicer fallback")
  }
  inspect(slicers.length(), content="1")
  inspect(slicer.macro_name, content="good-macro")
  inspect(slicer.alt_text, content="good-slicer")
}

///|
test "DrawingML extension payload cannot spoof anchors or drawing features" {
  let source =
    #|<wsDr xmlns="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:d="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:q="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:rel="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:sl="http://schemas.microsoft.com/office/drawing/2010/slicer">
    #|  <d:extLst><d:ext uri="urn:decoy-anchor"><oneCellAnchor><from><col>99</col><row>99</row><colOff>0</colOff><rowOff>0</rowOff></from><ext cx="1" cy="1"/><pic><nvPicPr><cNvPr id="99" name="bad-anchor"/></nvPicPr><blipFill><d:blip rel:embed="image-bad-anchor"/></blipFill></pic></oneCellAnchor></d:ext></d:extLst>
    #|  <oneCellAnchor><from><col>0</col><colOff>0</colOff><row>0</row><rowOff>0</rowOff></from><ext cx="9525" cy="9525"/><d:extLst><d:ext uri="urn:decoy-image"><pic><nvPicPr><cNvPr id="91" name="bad-image"/></nvPicPr><blipFill><d:blip rel:embed="image-bad"/></blipFill></pic></d:ext></d:extLst><pic><nvPicPr><cNvPr id="1" name="good-image"/></nvPicPr><blipFill><d:blip rel:embed="image-good"/></blipFill></pic><clientData/></oneCellAnchor>
    #|  <oneCellAnchor><from><col>1</col><colOff>0</colOff><row>0</row><rowOff>0</rowOff></from><ext cx="9525" cy="9525"/><q:extLst><q:ext uri="urn:decoy-chart"><q:chart rel:id="chart-bad"/></q:ext></q:extLst><graphicFrame><d:graphic><d:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"><q:chart rel:id="chart-good"/></d:graphicData></d:graphic></graphicFrame><clientData/></oneCellAnchor>
    #|  <oneCellAnchor><from><col>2</col><colOff>0</colOff><row>0</row><rowOff>0</rowOff></from><ext cx="9525" cy="9525"/><d:extLst><d:ext uri="urn:decoy-shape"><sp><nvSpPr><cNvPr id="92" name="bad-shape"/></nvSpPr><spPr><d:xfrm><d:ext cx="1" cy="1"/></d:xfrm><d:prstGeom prst="bad"/></spPr></sp></d:ext></d:extLst><sp><nvSpPr><cNvPr id="2" name="good-shape"/></nvSpPr><spPr><d:xfrm><d:ext cx="9525" cy="9525"/></d:xfrm><d:prstGeom prst="rect"/></spPr></sp><clientData/></oneCellAnchor>
    #|  <oneCellAnchor><from><col>3</col><colOff>0</colOff><row>0</row><rowOff>0</rowOff></from><ext cx="9525" cy="9525"/><sl:extLst><sl:ext uri="urn:decoy-slicer"><sl:slicer name="slicer-bad"/></sl:ext></sl:extLst><graphicFrame macro="good-macro"><nvGraphicFramePr><cNvPr id="3" descr="good-slicer"/></nvGraphicFramePr><d:graphic><d:graphicData uri="http://schemas.microsoft.com/office/drawing/2010/slicer"><sl:slicer name="slicer-good"/></d:graphicData></d:graphic></graphicFrame><clientData/></oneCellAnchor>
    #|</wsDr>
  let drawing = canonicalize_xlsx_drawing_xml(
    source, default_max_xml_part_bytes,
  )
  assert_false(drawing.contains("bad-anchor"))
  assert_false(drawing.contains("bad-image"))
  assert_false(drawing.contains("chart-bad"))
  assert_false(drawing.contains("bad-shape"))
  assert_false(drawing.contains("slicer-bad"))
  assert_false(drawing.contains("extLst"))
  let anchors = parse_drawing_anchors(drawing)
  inspect(anchors.length(), content="4")
  let image_anchor = anchors[0].xml
  let chart_anchor = anchors[1].xml
  let shape_anchor = anchors[2].xml
  let slicer_anchor = anchors[3].xml
  assert_true(image_anchor.contains("image-good"))
  assert_true(chart_anchor.contains("chart-good"))
  assert_true(shape_anchor.contains("good-shape"))
  assert_true(slicer_anchor.contains("slicer-good"))
}

///|
test "DrawingML retains valid unsupported anchors without reading nested objects" {
  let source =
    #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
    #|  <xdr:oneCellAnchor><xdr:from><xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>0</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:ext cx="9525" cy="9525"/><xdr:grpSp><xdr:nvGrpSpPr/><xdr:grpSpPr/><xdr:sp><xdr:nvSpPr><xdr:cNvPr id="1" name="nested"/></xdr:nvSpPr><xdr:spPr><a:prstGeom prst="rect"/></xdr:spPr></xdr:sp></xdr:grpSp><xdr:clientData/></xdr:oneCellAnchor>
    #|  <xdr:oneCellAnchor><xdr:from><xdr:col>1</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>0</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:ext cx="9525" cy="9525"/><xdr:sp><xdr:nvSpPr><xdr:cNvPr id="2" name="direct"/></xdr:nvSpPr><xdr:spPr><a:xfrm><a:ext cx="9525" cy="9525"/></a:xfrm><a:prstGeom prst="rect"/></xdr:spPr></xdr:sp><xdr:clientData/></xdr:oneCellAnchor>
    #|</xdr:wsDr>
  let drawing = canonicalize_xlsx_drawing_xml(
    source, default_max_xml_part_bytes,
  )
  assert_true(drawing.contains("<xdr:grpSp>"))
  let anchors = parse_drawing_anchors(drawing)
  inspect(anchors.length(), content="2")
  assert_true(anchors[0].unsupported)
  assert_true(anchors[0].xml.contains("name=\"nested\""))
  assert_false(anchors[1].unsupported)
  let anchor_xml = anchors[1].xml
  assert_true(anchor_xml.contains("name=\"direct\""))
  assert_false(anchor_xml.contains("name=\"nested\""))
  let shapes = parse_drawing_shapes(
    anchors,
    drawing_metrics_for_sheet(Worksheet::new("Sheet1")),
  )
  assert_eq(shapes.length(), 1)
  assert_eq(shapes[0].name, "direct")
}

///|
test "DrawingML rejects extension entries outside extension lists" {
  let source =
    #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:ext uri="urn:misplaced"><xdr:oneCellAnchor/></a:ext></xdr:wsDr>
  try canonicalize_xlsx_drawing_xml(source, default_max_xml_part_bytes) catch {
    InvalidXml(msg~) =>
      inspect(msg, content="drawing extension payload is misplaced")
    _ => fail("unexpected misplaced extension error")
  } noraise {
    _ => fail("expected a misplaced extension payload error")
  }
}

///|
test "DrawingML rejects supported-namespace reader decoys" {
  let cases : Array[(String, String)] = [
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing"><xdr:clientData><xdr:oneCellAnchor/></xdr:clientData></xdr:wsDr>
      ),
      "drawing anchor reader target is misplaced",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><xdr:oneCellAnchor><xdr:graphicFrame><a:graphic><a:graphicData uri="urn:vendor"><xdr:pic/></a:graphicData></a:graphic></xdr:graphicFrame></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing reader object is misplaced",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing"><xdr:oneCellAnchor><xdr:clientData><xdr:sp/></xdr:clientData></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing reader object is misplaced",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart"><xdr:oneCellAnchor><xdr:graphicFrame><a:graphic><a:graphicData uri="urn:vendor"><c:chart/></a:graphicData></a:graphic></xdr:graphicFrame></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing chart graphicData URI is invalid",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:sle="http://schemas.microsoft.com/office/drawing/2010/slicer"><xdr:oneCellAnchor><xdr:graphicFrame><a:graphic><a:graphicData uri="urn:vendor"><sle:slicer/></a:graphicData></a:graphic></xdr:graphicFrame></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing slicer graphicData URI is invalid",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing"><xdr:oneCellAnchor><xdr:pic/><xdr:sp/></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing anchor has multiple reader objects",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:s="http://purl.oclc.org/ooxml/drawingml/spreadsheetDrawing"><xdr:oneCellAnchor><s:pic/></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing reader target dialect is mixed",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><xdr:oneCellAnchor><xdr:pic><a:blip r:embed="decoy"/><xdr:blipFill><a:blip r:embed="real"/></xdr:blipFill></xdr:pic></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing blip target is misplaced",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><xdr:oneCellAnchor><xdr:pic><xdr:blipFill><a:blip r:embed="first"/><a:blip r:embed="second"/></xdr:blipFill></xdr:pic></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing blip target is duplicated",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://purl.oclc.org/ooxml/drawingml/main"><xdr:oneCellAnchor><xdr:graphicFrame><a:graphic/></xdr:graphicFrame></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing reader target dialect is mixed",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:r="http://purl.oclc.org/ooxml/officeDocument/relationships"><xdr:oneCellAnchor><xdr:graphicFrame><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"><c:chart r:id="wrong-dialect"/></a:graphicData></a:graphic></xdr:graphicFrame></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing relationship attribute dialect is invalid",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><xdr:oneCellAnchor><xdr:sp><xdr:spPr><a:t>decoy</a:t></xdr:spPr><xdr:txBody><a:p><a:r><a:t>real</a:t></a:r></a:p></xdr:txBody></xdr:sp></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing text target is misplaced",
    ),
    (
      (
        #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><xdr:oneCellAnchor><xdr:sp><xdr:txBody><a:p><a:r><a:rPr><a:t>decoy</a:t></a:rPr><a:t>real</a:t></a:r></a:p></xdr:txBody></xdr:sp></xdr:oneCellAnchor></xdr:wsDr>
      ),
      "drawing text target is misplaced",
    ),
  ]
  for case in cases {
    let (source, expected) = case
    try
      canonicalize_xlsx_drawing_xml(source, default_max_xml_part_bytes)
    catch {
      InvalidXml(msg~) => assert_eq(msg, expected)
      _ => fail("unexpected drawing structure error")
    } noraise {
      _ => fail("expected supported-namespace drawing decoy rejection")
    }
  }
}

///|
test "DrawingML rich text ignores unmodeled paragraph defaults" {
  let source =
    #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
    #|  <xdr:oneCellAnchor>
    #|    <xdr:from><xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>0</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>
    #|    <xdr:ext cx="9525" cy="9525"/>
    #|    <xdr:sp>
    #|      <xdr:nvSpPr><xdr:cNvPr id="1" name="text"/></xdr:nvSpPr>
    #|      <xdr:spPr><a:prstGeom prst="rect"/></xdr:spPr>
    #|      <xdr:txBody><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr><a:solidFill><a:srgbClr val="DECOY"/></a:solidFill></a:defRPr></a:pPr><a:r><a:rPr><a:solidFill><a:srgbClr val="A1B2C3"/></a:solidFill></a:rPr><a:t xml:space="preserve"> real </a:t></a:r><a:endParaRPr><a:latin typeface="Ignored Default"/></a:endParaRPr></a:p></xdr:txBody>
    #|    </xdr:sp>
    #|    <xdr:clientData/>
    #|  </xdr:oneCellAnchor>
    #|</xdr:wsDr>
  let canonical = canonicalize_xlsx_drawing_xml(
    source, default_max_xml_part_bytes,
  )
  let tx_body = extract_tag_body_from(canonical, "xdr:txBody").unwrap_or("")
  let runs = parse_drawing_shape_text_runs(tx_body)
  inspect(runs.length(), content="1")
  inspect(runs[0].text, content=" real ")
  let font = runs[0].font.unwrap()
  inspect(font.color.unwrap_or(""), content="A1B2C3")
  inspect(font.family.unwrap_or(""), content="")
}

///|
test "DrawingML shape fill selection excludes line-only fills" {
  let line_only =
    #|<a:xfrm><a:ext cx="9525" cy="9525"/></a:xfrm><a:prstGeom prst="rect"/><a:ln><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></a:ln>
  assert_true(drawing_shape_solid_fill_body(line_only) is None)
  let shape_and_line =
    #|<a:xfrm><a:ext cx="9525" cy="9525"/></a:xfrm><a:prstGeom prst="rect"/><a:solidFill><a:srgbClr val="00FF00"/></a:solidFill><a:ln><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></a:ln>
  assert_eq(
    drawing_shape_solid_fill_body(shape_and_line).unwrap_or(""),
    "<a:srgbClr val=\"00FF00\"/>",
  )
}

///|
test "chartsheet drawing selector requires exactly one chart payload" {
  let anchor =
    #|<xdr:oneCellAnchor><xdr:graphicFrame><a:graphic><a:graphicData><c:chart r:id="selected"/></a:graphicData></a:graphic></xdr:graphicFrame></xdr:oneCellAnchor>
  let one : ReadOnlyArray[DrawingAnchor] = [
    {
      xml: anchor,
      positioning: OneCell,
      form: OneCellAnchor,
      order: 0,
      unsupported: false,
    },
  ]
  assert_eq(single_drawing_chart_rel_id(one), "selected")
  let empty : ReadOnlyArray[DrawingAnchor] = []
  try single_drawing_chart_rel_id(empty) catch {
    InvalidXml(msg~) => assert_eq(msg, "chartsheet chart payload missing")
    _ => fail("unexpected empty chartsheet drawing error")
  } noraise {
    _ => fail("expected empty chartsheet drawing rejection")
  }
  let two : ReadOnlyArray[DrawingAnchor] = [
    {
      xml: anchor,
      positioning: OneCell,
      form: OneCellAnchor,
      order: 0,
      unsupported: false,
    },
    {
      xml: anchor,
      positioning: OneCell,
      form: OneCellAnchor,
      order: 1,
      unsupported: false,
    },
  ]
  try single_drawing_chart_rel_id(two) catch {
    InvalidXml(msg~) => assert_eq(msg, "chartsheet drawing has multiple charts")
    _ => fail("unexpected duplicate chartsheet chart error")
  } noraise {
    _ => fail("expected duplicate chartsheet chart rejection")
  }
}

///|
test "DrawingML validates Strict chart dialect and payload URI together" {
  let source =
    #|<xdr:wsDr xmlns:xdr="http://purl.oclc.org/ooxml/drawingml/spreadsheetDrawing" xmlns:a="http://purl.oclc.org/ooxml/drawingml/main" xmlns:c="http://purl.oclc.org/ooxml/drawingml/chart" xmlns:r="http://purl.oclc.org/ooxml/officeDocument/relationships"><xdr:oneCellAnchor><xdr:from><xdr:col>0</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>0</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:ext cx="9525" cy="9525"/><xdr:graphicFrame><a:graphic><a:graphicData uri="http://purl.oclc.org/ooxml/drawingml/chart"><c:chart r:id="chart"/></a:graphicData></a:graphic></xdr:graphicFrame><xdr:clientData/></xdr:oneCellAnchor></xdr:wsDr>
  let canonical = canonicalize_xlsx_drawing_xml(
    source, default_max_xml_part_bytes,
  )
  assert_true(canonical.contains("<c:chart r:id=\"chart\"/>"))
}

///|
test "DrawingML preprocessing charges every bounded pass" {
  let source =
    #|<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing"/>
  // Charging only the source and final output would fit this ceiling. The
  // independent root-validation, extension-removal, and MCE passes must not.
  let limit = source.length() * 2
  let budget = ReadBudget::new(
    ReadLimits::with_values(max_parser_work_units=limit),
  )
  try
    canonicalize_xlsx_drawing_xml(source, default_max_xml_part_bytes, budget~)
  catch {
    ResourceLimitExceeded(kind~, limit=actual_limit, actual~) => {
      assert_eq(kind, "parser_work_units")
      assert_eq(actual_limit, limit)
      assert_true(actual > actual_limit)
    }
    _ => fail("unexpected DrawingML preprocessing limit error")
  } noraise {
    _ => fail("expected DrawingML preprocessing work rejection")
  }
}

///|
test "chart frame fidelity scan rejects extra content and charges its work" {
  let anchor = wb_canonical_chart_anchor()
  let budget = ReadBudget::new(
    ReadLimits::with_values(max_parser_work_units=1024 * 1024),
  )
  assert_true(
    drawing_chart_frame_is_canonical(anchor, 9525, 9525, true, true, budget~),
  )
  let charged_work = budget.parser_work_units
  assert_true(charged_work > anchor.length() * 3)
  let exact_budget = ReadBudget::new(
    ReadLimits::with_values(max_parser_work_units=charged_work),
  )
  assert_true(
    drawing_chart_frame_is_canonical(
      anchor,
      9525,
      9525,
      true,
      true,
      budget=exact_budget,
    ),
  )
  let limited_budget = ReadBudget::new(
    ReadLimits::with_values(max_parser_work_units=charged_work - 1),
  )
  try
    drawing_chart_frame_is_canonical(
      anchor,
      9525,
      9525,
      true,
      true,
      budget=limited_budget,
    )
    |> ignore
  catch {
    ResourceLimitExceeded(kind~, ..) => assert_eq(kind, "parser_work_units")
    _ => fail("unexpected chart frame work-limit error")
  } noraise {
    _ => fail("expected chart frame work-limit rejection")
  }
  let extra_transform = anchor.replace(
    old="    <a:graphic>\n",
    new="    <xdr:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"9525\" cy=\"9525\"/></xdr:xfrm>\n    <a:graphic>\n",
  )
  assert_false(
    drawing_chart_frame_is_canonical(extra_transform, 9525, 9525, true, true),
  )
  let extra_attribute = anchor.replace(
    old="<a:graphicData uri=",
    new="<a:graphicData custom=\"x\" uri=",
  )
  assert_false(
    drawing_chart_frame_is_canonical(extra_attribute, 9525, 9525, true, true),
  )
  let extra_text = anchor.replace(
    old="<xdr:cNvPr id=\"1\" name=\"Chart 1\"/>\n",
    new="<xdr:cNvPr id=\"1\" name=\"Chart 1\"/>custom\n",
  )
  assert_false(
    drawing_chart_frame_is_canonical(extra_text, 9525, 9525, true, true),
  )
  let mut cancellation_checks = 0
  try
    drawing_chart_frame_is_canonical(anchor, 9525, 9525, true, true, cancelled=() => {
      cancellation_checks += 1
      cancellation_checks >= 2
    })
    |> ignore
  catch {
    ReadCancelled => assert_true(cancellation_checks >= 2)
    _ => fail("unexpected chart frame cancellation error")
  } noraise {
    _ => fail("expected chart frame cancellation")
  }
}

///|
test "read_drawing_xml wb: parse_xml_int_tag missing/invalid errors" {
  let missing_tag = "<xdr:from><xdr:row>1</xdr:row></xdr:from>"
  let missing_result : Result[Int, Error] = Ok(
    parse_xml_int_tag(missing_tag, "xdr:col", "drawing col invalid"),
  ) catch {
    e => Err(e)
  }
  match missing_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing col invalid")
    _ => fail("expected InvalidXml for missing xdr:col")
  }

  let invalid_value = "<xdr:from><xdr:col>abc</xdr:col></xdr:from>"
  let invalid_result : Result[Int, Error] = Ok(
    parse_xml_int_tag(invalid_value, "xdr:col", "drawing col invalid"),
  ) catch {
    e => Err(e)
  }
  match invalid_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing col invalid")
    _ => fail("expected InvalidXml for invalid xdr:col numeric value")
  }
}

///|
test "read_drawing_xml wb: drawing_axis_span_emu handles reverse and same-index spans" {
  let sheet = Worksheet::new("Sheet1")
  let metrics = drawing_metrics_for_sheet(sheet)
  inspect(drawing_axis_span_emu(metrics.cols, 1, 200, 1, 800), content="600")
  inspect(drawing_axis_span_emu(metrics.cols, 1, 800, 1, 200), content="600")
  inspect(
    drawing_axis_span_emu(metrics.cols, 0, -9525, 1, -9525),
    content="609600",
  )
}

///|
test "read_drawing_xml wb: drawing spans use sparse dimensions and grid boundary" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_col_width(501, 10.0)
  let metrics = drawing_metrics_for_sheet(sheet)
  inspect(
    drawing_axis_span_emu(metrics.cols, 0, 0, 1000, 0),
    content="609752400",
  )
  inspect(
    drawing_axis_span_emu(metrics.cols, 16383, 0, 16384, 0),
    content="609600",
  )
}

///|
test "read_drawing_xml wb: drawing spans reject invalid markers and overflow" {
  let sheet = Worksheet::new("Sheet1")
  let metrics = drawing_metrics_for_sheet(sheet)
  let invalid_marker : Result[Int, Error] = Ok(
    drawing_axis_span_emu(metrics.cols, 0, 0, 0x7fff_ffff, 0),
  ) catch {
    error => Err(error)
  }
  match invalid_marker {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing col invalid")
    _ => fail("expected invalid drawing column")
  }
  let overflow : Result[Int, Error] = Ok(
    drawing_axis_span_emu(metrics.rows, 0, 0, cell_ref_max_rows, 0),
  ) catch {
    error => Err(error)
  }
  match overflow {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing span out of range")
    _ => fail("expected drawing span overflow")
  }
}

///|
test "read_drawing_xml wb: parse_drawing_anchors validation and positioning" {
  let one_missing_close = "<xdr:wsDr><xdr:oneCellAnchor><xdr:pic/></xdr:wsDr>"
  let one_result : Result[Array[DrawingAnchor], Error] = Ok(
    parse_drawing_anchors(one_missing_close),
  ) catch {
    e => Err(e)
  }
  match one_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="oneCellAnchor close missing")
    _ => fail("expected InvalidXml for oneCellAnchor close missing")
  }

  let two_missing_close = "<xdr:wsDr><xdr:oneCellAnchor></xdr:oneCellAnchor><xdr:twoCellAnchor></xdr:wsDr>"
  let two_result : Result[Array[DrawingAnchor], Error] = Ok(
    parse_drawing_anchors(two_missing_close),
  ) catch {
    e => Err(e)
  }
  match two_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="twoCellAnchor close missing")
    _ => fail("expected InvalidXml for twoCellAnchor close missing")
  }

  let absolute_missing_close = "<xdr:wsDr><xdr:absoluteAnchor><xdr:graphicFrame/></xdr:wsDr>"
  let absolute_result : Result[Array[DrawingAnchor], Error] = Ok(
    parse_drawing_anchors(absolute_missing_close),
  ) catch {
    e => Err(e)
  }
  match absolute_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="absoluteAnchor close missing")
    _ => fail("expected InvalidXml for absoluteAnchor close missing")
  }

  let xml =
    #|<xdr:wsDr>
    #|  <xdr:absoluteAnchor></xdr:absoluteAnchor >
    #|  <xdr:oneCellAnchor></xdr:oneCellAnchor>
    #|  <xdr:twoCellAnchor editAs="absolute"></xdr:twoCellAnchor >
    #|  <xdr:twoCellAnchor editAs="oneCell"></xdr:twoCellAnchor>
    #|  <xdr:twoCellAnchor editAs="twoCell"></xdr:twoCellAnchor>
    #|</xdr:wsDr>
  let anchors = parse_drawing_anchors(xml)
  inspect(anchors.length(), content="5")
  debug_inspect(anchors[0].positioning, content="Absolute")
  debug_inspect(anchors[1].positioning, content="OneCell")
  debug_inspect(anchors[2].positioning, content="Absolute")
  debug_inspect(anchors[3].positioning, content="OneCell")
  debug_inspect(anchors[4].positioning, content="TwoCell")
  debug_inspect(anchors[0].form, content="AbsoluteAnchor")
  debug_inspect(anchors[2].form, content="TwoCellAnchor")
  try
    parse_drawing_anchors(
      "<xdr:wsDr><xdr:twoCellAnchor editAs=\"free\"></xdr:twoCellAnchor></xdr:wsDr>",
    )
  catch {
    InvalidXml(msg~) => inspect(msg, content="drawing editAs value is invalid")
    _ => fail("unexpected drawing editAs error")
  } noraise {
    _ => fail("expected invalid drawing editAs rejection")
  }
}

///|
test "read_drawing_xml wb: anchor parsing checks limits before copying source" {
  let drawing_xml = "<xdr:wsDr><xdr:oneCellAnchor></xdr:oneCellAnchor></xdr:wsDr>"
  let limited = ReadBudget::new(
    ReadLimits::with_values(max_parser_work_units=1),
  )
  let limit_result : Result[Array[DrawingAnchor], Error] = Ok(
    parse_drawing_anchors(drawing_xml, budget=limited),
  ) catch {
    error => Err(error)
  }
  match limit_result {
    Err(ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="parser_work_units")
      inspect(limit, content="1")
      inspect(actual, content="2")
    }
    _ => fail("expected drawing work limit")
  }

  let mut checks = 0
  let cancelled = ReadBudget::new(ReadLimits::new(), cancelled=() => {
    checks += 1
    true
  })
  let cancel_result : Result[Array[DrawingAnchor], Error] = Ok(
    parse_drawing_anchors(drawing_xml, budget=cancelled),
  ) catch {
    error => Err(error)
  }
  assert_true(cancel_result is Err(ReadCancelled))
  inspect(checks, content="1")
}

///|
test "read_drawing_xml wb: parse_drawing_images empty rel map branch" {
  let drawing_xml = wb_one_cell_anchor(
    wb_from_xml(),
    "<xdr:ext cx=\"9525\" cy=\"9525\"/>",
  )
  let archive = @zip.Archive::new()
  let metrics = drawing_metrics_for_sheet(Worksheet::new("Sheet1"))
  let result : Result[Array[Image], Error] = Ok(
    parse_drawing_images(
      parse_drawing_anchors(drawing_xml),
      "",
      "xl/drawings/drawing1.xml",
      Map([]),
      image_reader_test_content_types(),
      metrics,
      archive,
    ),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing image target missing")
    _ => fail("expected InvalidXml for missing drawing image target")
  }
}

///|
test "read_drawing_xml wb: signed marker offsets are retained" {
  let archive = @zip.Archive::new()
  archive.add("xl/media/image1.png", @encoding/utf8.encode("img"))
  let rels_xml = wb_rels_image_target("../media/image1.png")
  let drawing_xml = wb_one_cell_anchor(
    "<xdr:from><xdr:col>0</xdr:col><xdr:row>0</xdr:row><xdr:colOff>-19050</xdr:colOff><xdr:rowOff>-9525</xdr:rowOff></xdr:from>",
    "<xdr:ext cx=\"9525\" cy=\"9525\"/>",
  )
  let metrics = drawing_metrics_for_sheet(Worksheet::new("Sheet1"))
  let images = parse_drawing_images(
    parse_drawing_anchors(drawing_xml),
    rels_xml,
    "xl/drawings/drawing1.xml",
    Map([]),
    image_reader_test_content_types(),
    metrics,
    archive,
  )
  inspect(images.length(), content="1")
  inspect(images[0].reference, content="A1")
  inspect(images[0].offset_x, content="-2")
  inspect(images[0].offset_y, content="-1")
}

///|
test "read_drawing_xml wb: repeated anchors share one retained media payload" {
  let archive = @zip.Archive::new()
  archive.add("xl/media/image1.png", @encoding/utf8.encode("shared-image"))
  let rels_xml = wb_rels_image_target("../media/image1.png")
  let anchor = "<xdr:oneCellAnchor>\{wb_from_xml()}<xdr:ext cx=\"9525\" cy=\"9525\"/>\{wb_pic_xml("rId1")}</xdr:oneCellAnchor>"
  let drawing_xml = "<xdr:wsDr>\{anchor}\{anchor}</xdr:wsDr>"
  let retained : Map[String, Bytes] = Map([])
  let images = parse_drawing_images(
    parse_drawing_anchors(drawing_xml),
    rels_xml,
    "xl/drawings/drawing1.xml",
    Map([]),
    image_reader_test_content_types(),
    drawing_metrics_for_sheet(Worksheet::new("Sheet1")),
    archive,
    media_cache=retained,
  )
  assert_eq(images.length(), 2)
  assert_eq(retained.length(), 1)
  assert_eq(images[0].data, images[1].data)
}

///|
test "read_drawing_xml wb: parse_drawing_images anchor/ext validation errors" {
  let archive = @zip.Archive::new()
  archive.add("xl/media/image1.png", @encoding/utf8.encode("img"))
  let rels_xml = wb_rels_image_target("../media/image1.png")
  let sheet = Worksheet::new("Sheet1")
  let metrics = drawing_metrics_for_sheet(sheet)

  let missing_from = wb_one_cell_anchor(
    "", "<xdr:ext cx=\"9525\" cy=\"9525\"/>",
  )
  let missing_from_result : Result[Array[Image], Error] = Ok(
    parse_drawing_images(
      parse_drawing_anchors(missing_from),
      rels_xml,
      "xl/drawings/drawing1.xml",
      Map([]),
      image_reader_test_content_types(),
      metrics,
      archive,
    ),
  ) catch {
    e => Err(e)
  }
  match missing_from_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing anchor from missing")
    _ => fail("expected InvalidXml drawing anchor from missing")
  }

  let missing_ext = wb_one_cell_anchor(wb_from_xml(), "")
  let missing_ext_result : Result[Array[Image], Error] = Ok(
    parse_drawing_images(
      parse_drawing_anchors(missing_ext),
      rels_xml,
      "xl/drawings/drawing1.xml",
      Map([]),
      image_reader_test_content_types(),
      metrics,
      archive,
    ),
  ) catch {
    e => Err(e)
  }
  match missing_ext_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing ext missing")
    _ => fail("expected InvalidXml drawing ext missing")
  }

  let cx_invalid = wb_one_cell_anchor(
    wb_from_xml(),
    "<xdr:ext cx=\"x\" cy=\"9525\"/>",
  )
  let cx_invalid_result : Result[Array[Image], Error] = Ok(
    parse_drawing_images(
      parse_drawing_anchors(cx_invalid),
      rels_xml,
      "xl/drawings/drawing1.xml",
      Map([]),
      image_reader_test_content_types(),
      metrics,
      archive,
    ),
  ) catch {
    e => Err(e)
  }
  match cx_invalid_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing cx invalid")
    _ => fail("expected InvalidXml drawing cx invalid")
  }

  let cy_missing = wb_one_cell_anchor(wb_from_xml(), "<xdr:ext cx=\"9525\"/>")
  let cy_missing_result : Result[Array[Image], Error] = Ok(
    parse_drawing_images(
      parse_drawing_anchors(cy_missing),
      rels_xml,
      "xl/drawings/drawing1.xml",
      Map([]),
      image_reader_test_content_types(),
      metrics,
      archive,
    ),
  ) catch {
    e => Err(e)
  }
  match cy_missing_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing cy missing")
    _ => fail("expected InvalidXml drawing cy missing")
  }

  let invalid_to = wb_two_cell_anchor(
    wb_from_xml(),
    "<xdr:to><xdr:col>2147483647</xdr:col><xdr:row>0</xdr:row><xdr:colOff>0</xdr:colOff><xdr:rowOff>0</xdr:rowOff></xdr:to>",
  )
  let invalid_to_result : Result[Array[Image], Error] = Ok(
    parse_drawing_images(
      parse_drawing_anchors(invalid_to),
      rels_xml,
      "xl/drawings/drawing1.xml",
      Map([]),
      image_reader_test_content_types(),
      metrics,
      archive,
    ),
  ) catch {
    error => Err(error)
  }
  match invalid_to_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing col invalid")
    _ => fail("expected InvalidXml drawing to column invalid")
  }
}
