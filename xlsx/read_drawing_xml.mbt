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
fn parse_drawing_anchors(
  drawing_xml : StringView,
) -> Array[(String, PicturePositioning)] raise XlsxError {
  let xml_str = drawing_xml.to_owned()
  let anchors : Array[(String, PicturePositioning)] = []
  let mut first_one = true
  for chunk in xml_str.split("<xdr:oneCellAnchor") {
    if first_one {
      first_one = false
      continue
    }
    let text = chunk.to_owned()
    let close_tag = "</xdr:oneCellAnchor>"
    let end = match text.find(close_tag) {
      Some(pos) => pos + close_tag.length()
      None => raise InvalidXml(msg="oneCellAnchor close missing")
    }
    let slice = text[:end]
    anchors.push(("<xdr:oneCellAnchor\{slice.to_owned()}", OneCell))
  }
  let mut first_two = true
  for chunk in xml_str.split("<xdr:twoCellAnchor") {
    if first_two {
      first_two = false
      continue
    }
    let text = chunk.to_owned()
    let close_tag = "</xdr:twoCellAnchor>"
    let end = match text.find(close_tag) {
      Some(pos) => pos + close_tag.length()
      None => raise InvalidXml(msg="twoCellAnchor close missing")
    }
    let slice = text[:end]
    let full = "<xdr:twoCellAnchor\{slice.to_owned()}"
    let positioning = match tag_attributes_in(full, "xdr:twoCellAnchor") {
      Some(tag) =>
        match attr_value(tag, "editAs") {
          Some(value) =>
            if value.to_string() == "absolute" {
              Absolute
            } else {
              TwoCell
            }
          None => TwoCell
        }
      None => TwoCell
    }
    anchors.push((full, positioning))
  }
  anchors
}

///|
fn parse_drawing_images(
  drawing_xml : StringView,
  drawing_rels_xml : StringView,
  metrics : DrawingMetrics,
  archive : @zip.Archive,
) -> Array[Image] raise XlsxError {
  let images : Array[Image] = []
  let image_targets = if drawing_rels_xml.to_owned() == "" {
    Map([])
  } else {
    parse_relationship_targets(drawing_rels_xml, rel_image)
  }
  let hyperlink_targets = if drawing_rels_xml.to_owned() == "" {
    Map([])
  } else {
    parse_relationship_targets(drawing_rels_xml, rel_hyperlink)
  }
  let anchors = parse_drawing_anchors(drawing_xml)
  for entry in anchors {
    let (anchor_xml, positioning) = entry
    let pic_body = match extract_tag_body_from(anchor_xml, "xdr:pic") {
      Some(value) => value
      None => continue
    }
    let from_body = match extract_tag_body_from(anchor_xml, "xdr:from") {
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
    let reference = drawing_reference_for_read(
      row_idx0, col_idx0, row_off_emu, col_off_emu,
    )
    let offset_x = col_off_emu / picture_emu_per_pixel
    let offset_y = row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = match positioning {
      OneCell => {
        let ext_tag = match tag_attributes_in(anchor_xml, "xdr:ext") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing ext missing")
        }
        let cx = match attr_value(ext_tag, "cx") {
          Some(value) =>
            @string.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing cx invalid")
            }
          None => raise InvalidXml(msg="drawing cx missing")
        }
        let cy = match attr_value(ext_tag, "cy") {
          Some(value) =>
            @string.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing cy invalid")
            }
          None => raise InvalidXml(msg="drawing cy missing")
        }
        ignore(validate_drawing_extent_for_read(cx, "drawing cx"))
        ignore(validate_drawing_extent_for_read(cy, "drawing cy"))
        (cx, cy)
      }
      _ => {
        let to_body = match extract_tag_body_from(anchor_xml, "xdr:to") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing anchor to missing")
        }
        let to_col_idx0 = parse_xml_int_tag(
          to_body, "xdr:col", "drawing to col invalid",
        )
        let to_row_idx0 = parse_xml_int_tag(
          to_body, "xdr:row", "drawing to row invalid",
        )
        let to_col_off = parse_xml_int_tag(
          to_body, "xdr:colOff", "drawing to colOff invalid",
        )
        let to_row_off = parse_xml_int_tag(
          to_body, "xdr:rowOff", "drawing to rowOff invalid",
        )
        let cx = drawing_axis_span_emu(
          metrics.cols,
          col_idx0,
          col_off_emu,
          to_col_idx0,
          to_col_off,
        )
        let cy = drawing_axis_span_emu(
          metrics.rows,
          row_idx0,
          row_off_emu,
          to_row_idx0,
          to_row_off,
        )
        (cx, cy)
      }
    }
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
    let lock_aspect_ratio = pic_body.contains("noChangeAspect=\"1\"")
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
    let media_path = resolve_rel_target(target, "drawings")
    let data = match archive.get(media_path) {
      Some(value) => value
      None => raise MissingPart(path=media_path)
    }
    let ext = match media_path.to_string().rev_find(".") {
      Some(pos) =>
        if pos + 1 < media_path.length() {
          media_path[pos + 1:]
        } else {
          ""
        }
      None => ""
    }
    let extension = ext.to_owned().to_lower()
    let content_type = match image_content_type(extension) {
      Some(value) => value
      None => "application/octet-stream"
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
                if hyperlink.contains("://") {
                  hyperlink_type = External
                } else {
                  hyperlink_type = Location
                }
              }
              None => ()
            }
          None => ()
        }
      None => ()
    }
    images.push({
      reference,
      data: data.to_owned(),
      extension,
      content_type,
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
    })
  }
  images
}

///|
fn parse_drawing_charts(
  drawing_xml : StringView,
  drawing_rels_xml : StringView,
  metrics : DrawingMetrics,
  archive : @zip.Archive,
  decode : (BytesView) -> String raise XlsxError,
) -> Array[Chart] raise XlsxError {
  let charts : Array[Chart] = []
  let chart_targets = if drawing_rels_xml.to_owned() == "" {
    Map([])
  } else {
    parse_relationship_targets(drawing_rels_xml, rel_chart)
  }
  let anchors = parse_drawing_anchors(drawing_xml)
  for entry in anchors {
    let (anchor_xml, positioning) = entry
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
    let chart_path = resolve_rel_target(target, "drawings")
    let chart_bytes = match archive.get(chart_path) {
      Some(value) => value
      None => raise MissingPart(path=chart_path)
    }
    let xml = decode(chart_bytes)
    let from_body = match extract_tag_body_from(anchor_xml, "xdr:from") {
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
    let reference = drawing_reference_for_read(
      row_idx0, col_idx0, row_off_emu, col_off_emu,
    )
    let offset_x = col_off_emu / picture_emu_per_pixel
    let offset_y = row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = match positioning {
      OneCell => {
        let ext_tag = match tag_attributes_in(anchor_xml, "xdr:ext") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing ext missing")
        }
        let cx = match attr_value(ext_tag, "cx") {
          Some(value) =>
            @string.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing cx invalid")
            }
          None => raise InvalidXml(msg="drawing cx missing")
        }
        let cy = match attr_value(ext_tag, "cy") {
          Some(value) =>
            @string.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing cy invalid")
            }
          None => raise InvalidXml(msg="drawing cy missing")
        }
        ignore(validate_drawing_extent_for_read(cx, "drawing cx"))
        ignore(validate_drawing_extent_for_read(cy, "drawing cy"))
        (cx, cy)
      }
      _ => {
        let to_body = match extract_tag_body_from(anchor_xml, "xdr:to") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing anchor to missing")
        }
        let to_col_idx0 = parse_xml_int_tag(
          to_body, "xdr:col", "drawing to col invalid",
        )
        let to_row_idx0 = parse_xml_int_tag(
          to_body, "xdr:row", "drawing to row invalid",
        )
        let to_col_off = parse_xml_int_tag(
          to_body, "xdr:colOff", "drawing to colOff invalid",
        )
        let to_row_off = parse_xml_int_tag(
          to_body, "xdr:rowOff", "drawing to rowOff invalid",
        )
        let cx = drawing_axis_span_emu(
          metrics.cols,
          col_idx0,
          col_off_emu,
          to_col_idx0,
          to_col_off,
        )
        let cy = drawing_axis_span_emu(
          metrics.rows,
          row_idx0,
          row_off_emu,
          to_row_idx0,
          to_row_off,
        )
        (cx, cy)
      }
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
    })
  }
  charts
}

///|
fn parse_drawing_shapes(
  drawing_xml : StringView,
) -> Array[Shape] raise XlsxError {
  let shapes : Array[Shape] = []
  let anchors = parse_drawing_anchors(drawing_xml)
  for entry in anchors {
    let (anchor_xml, positioning) = entry
    if anchor_xml.contains("<mc:AlternateContent") {
      continue
    }
    let sp_body = match extract_tag_body_from(anchor_xml, "xdr:sp") {
      Some(value) => value
      None => continue
    }
    if !sp_body.contains("<a:prstGeom") {
      continue
    }
    let from_body = match extract_tag_body_from(anchor_xml, "xdr:from") {
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
    let reference = drawing_reference_for_read(
      row_idx0, col_idx0, row_off_emu, col_off_emu,
    )
    match positioning {
      OneCell => ()
      _ => {
        let to_body = match extract_tag_body_from(anchor_xml, "xdr:to") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing shape to missing")
        }
        let to_col_idx0 = parse_xml_int_tag(
          to_body, "xdr:col", "drawing shape to col invalid",
        )
        let to_row_idx0 = parse_xml_int_tag(
          to_body, "xdr:row", "drawing shape to row invalid",
        )
        let to_col_off = parse_xml_int_tag(
          to_body, "xdr:colOff", "drawing shape to colOff invalid",
        )
        let to_row_off = parse_xml_int_tag(
          to_body, "xdr:rowOff", "drawing shape to rowOff invalid",
        )
        validate_drawing_axis_marker_for_read(
          "col", to_col_idx0, to_col_off, true,
        )
        validate_drawing_axis_marker_for_read(
          "row", to_row_idx0, to_row_off, true,
        )
      }
    }
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
    let xfrm_body = match extract_tag_body_from(sppr_body, "a:xfrm") {
      Some(value) => value
      None => sppr_body
    }
    let ext_tag = match tag_attributes_in(xfrm_body, "a:ext") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing shape ext missing")
    }
    let cx = match attr_value(ext_tag, "cx") {
      Some(value) =>
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="drawing shape cx invalid")
        }
      None => raise InvalidXml(msg="drawing shape cx missing")
    }
    let cy = match attr_value(ext_tag, "cy") {
      Some(value) =>
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="drawing shape cy invalid")
        }
      None => raise InvalidXml(msg="drawing shape cy missing")
    }
    ignore(validate_drawing_extent_for_read(cx, "drawing shape cx"))
    ignore(validate_drawing_extent_for_read(cy, "drawing shape cy"))
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
    match extract_tag_body_from(sppr_body, "a:solidFill") {
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
    let paragraph : Array[RichTextRun] = []
    match extract_tag_body_from(sp_body, "xdr:txBody") {
      Some(tx_body) => {
        let tx = tx_body.to_string()
        let mut first = true
        for chunk in tx.split("<a:t>") {
          if first {
            first = false
            continue
          }
          let part = chunk.to_owned()
          let end = match part.find("</a:t>") {
            Some(pos) => pos
            None => continue
          }
          let text = part[:end]
          paragraph.push({ text: unescape_xml_text(text), font: None })
        }
      }
      None => ()
    }
    let text = ""
    let format = shape_graphic_options(
      1.0, 1.0, name, alt_text, print_object, locked, positioning,
    )
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
}

///|
fn parse_drawing_slicer_anchors(
  drawing_xml : StringView,
  metrics : DrawingMetrics,
) -> Map[String, SlicerAnchorInfo] raise XlsxError {
  let out : Map[String, SlicerAnchorInfo] = Map([])
  let anchors = parse_drawing_anchors(drawing_xml)
  for entry in anchors {
    let (anchor_xml, positioning) = entry
    let slicer_tag = match tag_attributes_in(anchor_xml, "sle:slicer") {
      Some(value) => value
      None => continue
    }
    let slicer_name = match attr_value(slicer_tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => continue
    }
    let from_body = match extract_tag_body_from(anchor_xml, "xdr:from") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing slicer from missing")
    }
    let col_idx0 = parse_xml_int_tag(
      from_body, "xdr:col", "drawing slicer col invalid",
    )
    let row_idx0 = parse_xml_int_tag(
      from_body, "xdr:row", "drawing slicer row invalid",
    )
    let col_off_emu = parse_xml_int_tag(
      from_body, "xdr:colOff", "drawing slicer colOff invalid",
    )
    let row_off_emu = parse_xml_int_tag(
      from_body, "xdr:rowOff", "drawing slicer rowOff invalid",
    )
    let cell = drawing_reference_for_read(
      row_idx0, col_idx0, row_off_emu, col_off_emu,
    )
    let offset_x = col_off_emu / picture_emu_per_pixel
    let offset_y = row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = match positioning {
      OneCell => {
        let ext_tag = match tag_attributes_in(anchor_xml, "xdr:ext") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing slicer ext missing")
        }
        let cx = match attr_value(ext_tag, "cx") {
          Some(value) =>
            @string.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing slicer cx invalid")
            }
          None => raise InvalidXml(msg="drawing slicer cx missing")
        }
        let cy = match attr_value(ext_tag, "cy") {
          Some(value) =>
            @string.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing slicer cy invalid")
            }
          None => raise InvalidXml(msg="drawing slicer cy missing")
        }
        ignore(validate_drawing_extent_for_read(cx, "drawing slicer cx"))
        ignore(validate_drawing_extent_for_read(cy, "drawing slicer cy"))
        (cx, cy)
      }
      _ => {
        let to_body = match extract_tag_body_from(anchor_xml, "xdr:to") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing slicer to missing")
        }
        let to_col_idx0 = parse_xml_int_tag(
          to_body, "xdr:col", "drawing slicer to col invalid",
        )
        let to_row_idx0 = parse_xml_int_tag(
          to_body, "xdr:row", "drawing slicer to row invalid",
        )
        let to_col_off = parse_xml_int_tag(
          to_body, "xdr:colOff", "drawing slicer to colOff invalid",
        )
        let to_row_off = parse_xml_int_tag(
          to_body, "xdr:rowOff", "drawing slicer to rowOff invalid",
        )
        let cx = drawing_axis_span_emu(
          metrics.cols,
          col_idx0,
          col_off_emu,
          to_col_idx0,
          to_col_off,
        )
        let cy = drawing_axis_span_emu(
          metrics.rows,
          row_idx0,
          row_off_emu,
          to_row_idx0,
          to_row_off,
        )
        (cx, cy)
      }
    }
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
    }
  }
  out
}

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
fn wb_two_cell_anchor(xml_from : String, xml_to : String) -> String {
  let pic = wb_pic_xml("rId1")
  "<xdr:wsDr><xdr:twoCellAnchor>\{xml_from}\{xml_to}\{pic}</xdr:twoCellAnchor></xdr:wsDr>"
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
  let one_result : Result[Array[(String, PicturePositioning)], Error] = Ok(
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
  let two_result : Result[Array[(String, PicturePositioning)], Error] = Ok(
    parse_drawing_anchors(two_missing_close),
  ) catch {
    e => Err(e)
  }
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
  debug_inspect(anchors[0].1, content="Absolute")
  debug_inspect(anchors[1].1, content="TwoCell")
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
    parse_drawing_images(drawing_xml, "", metrics, archive),
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
  let images = parse_drawing_images(drawing_xml, rels_xml, metrics, archive)
  inspect(images.length(), content="1")
  inspect(images[0].reference, content="A1")
  inspect(images[0].offset_x, content="-2")
  inspect(images[0].offset_y, content="-1")
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
    parse_drawing_images(missing_from, rels_xml, metrics, archive),
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
    parse_drawing_images(missing_ext, rels_xml, metrics, archive),
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
    parse_drawing_images(cx_invalid, rels_xml, metrics, archive),
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
    parse_drawing_images(cy_missing, rels_xml, metrics, archive),
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
    parse_drawing_images(invalid_to, rels_xml, metrics, archive),
  ) catch {
    error => Err(error)
  }
  match invalid_to_result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="drawing col invalid")
    _ => fail("expected InvalidXml drawing to column invalid")
  }
}
