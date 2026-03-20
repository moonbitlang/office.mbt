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
  @strconv.parse_int(body, base=10) catch {
    _ => raise InvalidXml(msg~)
  }
}

///|
fn drawing_axis_span_emu(
  sheet : Worksheet,
  axis : StringView,
  from_idx0 : Int,
  from_off_emu : Int,
  to_idx0 : Int,
  to_off_emu : Int,
) -> Int {
  let mut start_idx0 = from_idx0
  let mut start_off = from_off_emu
  let mut end_idx0 = to_idx0
  let mut end_off = to_off_emu
  if end_idx0 < start_idx0 || (end_idx0 == start_idx0 && end_off < start_off) {
    start_idx0 = to_idx0
    start_off = to_off_emu
    end_idx0 = from_idx0
    end_off = from_off_emu
  }
  if start_idx0 == end_idx0 {
    return end_off - start_off
  }
  let mut total = 0
  let start_idx1 = start_idx0 + 1
  let start_cell_px = if axis == "col" {
    sheet.col_width_pixels(start_idx1)
  } else {
    sheet.row_height_pixels(start_idx1)
  }
  total = total + (start_cell_px * picture_emu_per_pixel - start_off)
  let mut idx0 = start_idx0 + 1
  while idx0 < end_idx0 {
    let idx1 = idx0 + 1
    let cell_px = if axis == "col" {
      sheet.col_width_pixels(idx1)
    } else {
      sheet.row_height_pixels(idx1)
    }
    total = total + cell_px * picture_emu_per_pixel
    idx0 = idx0 + 1
  }
  total + end_off
}

///|
fn parse_drawing_anchors(
  drawing_xml : StringView,
) -> Array[(String, PicturePositioning)] raise XlsxError {
  let xml_str = drawing_xml.to_string()
  let anchors : Array[(String, PicturePositioning)] = []
  let mut first_one = true
  for chunk in xml_str.split("<xdr:oneCellAnchor") {
    if first_one {
      first_one = false
      continue
    }
    let text = chunk.to_string()
    let close_tag = "</xdr:oneCellAnchor>"
    let end = match text.find(close_tag) {
      Some(pos) => pos + close_tag.length()
      None => raise InvalidXml(msg="oneCellAnchor close missing")
    }
    let slice = text[:end]
    anchors.push(("<xdr:oneCellAnchor\{slice.to_string()}", OneCell))
  }
  let mut first_two = true
  for chunk in xml_str.split("<xdr:twoCellAnchor") {
    if first_two {
      first_two = false
      continue
    }
    let text = chunk.to_string()
    let close_tag = "</xdr:twoCellAnchor>"
    let end = match text.find(close_tag) {
      Some(pos) => pos + close_tag.length()
      None => raise InvalidXml(msg="twoCellAnchor close missing")
    }
    let slice = text[:end]
    let full = "<xdr:twoCellAnchor\{slice.to_string()}"
    let positioning = match tag_attributes_in(full[:], "xdr:twoCellAnchor") {
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
  sheet : Worksheet,
  archive : @zip.Archive,
) -> Array[Image] raise XlsxError {
  let images : Array[Image] = []
  let image_targets = if drawing_rels_xml.to_string() == "" {
    {}
  } else {
    parse_relationship_targets(drawing_rels_xml, rel_image)
  }
  let hyperlink_targets = if drawing_rels_xml.to_string() == "" {
    {}
  } else {
    parse_relationship_targets(drawing_rels_xml, rel_hyperlink)
  }
  let anchors = parse_drawing_anchors(drawing_xml)
  for entry in anchors {
    let (anchor_xml, positioning) = entry
    let pic_body = match extract_tag_body_from(anchor_xml[:], "xdr:pic") {
      Some(value) => value
      None => continue
    }
    let from_body = match extract_tag_body_from(anchor_xml[:], "xdr:from") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing anchor from missing")
    }
    let col_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:col",
      "drawing col invalid",
    )
    let row_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:row",
      "drawing row invalid",
    )
    let col_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:colOff",
      "drawing colOff invalid",
    )
    let row_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:rowOff",
      "drawing rowOff invalid",
    )
    let reference = cell_ref_from(row_idx0 + 1, col_idx0 + 1)
    let offset_x = col_off_emu / picture_emu_per_pixel
    let offset_y = row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = match positioning {
      OneCell => {
        let ext_tag = match tag_attributes_in(anchor_xml[:], "xdr:ext") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing ext missing")
        }
        let cx = match attr_value(ext_tag, "cx") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing cx invalid")
            }
          None => raise InvalidXml(msg="drawing cx missing")
        }
        let cy = match attr_value(ext_tag, "cy") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing cy invalid")
            }
          None => raise InvalidXml(msg="drawing cy missing")
        }
        (cx, cy)
      }
      _ => {
        let to_body = match extract_tag_body_from(anchor_xml[:], "xdr:to") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing anchor to missing")
        }
        let to_col_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:col",
          "drawing to col invalid",
        )
        let to_row_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:row",
          "drawing to row invalid",
        )
        let to_col_off = parse_xml_int_tag(
          to_body[:],
          "xdr:colOff",
          "drawing to colOff invalid",
        )
        let to_row_off = parse_xml_int_tag(
          to_body[:],
          "xdr:rowOff",
          "drawing to rowOff invalid",
        )
        let cx = drawing_axis_span_emu(
          sheet, "col", col_idx0, col_off_emu, to_col_idx0, to_col_off,
        )
        let cy = drawing_axis_span_emu(
          sheet, "row", row_idx0, row_off_emu, to_row_idx0, to_row_off,
        )
        (cx, cy)
      }
    }
    let c_nv_pr_tag = match tag_attributes_in(pic_body[:], "xdr:cNvPr") {
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
    let client_tag = match tag_attributes_in(anchor_xml[:], "xdr:clientData") {
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
    let blip_tag = match tag_attributes_in(pic_body[:], "a:blip") {
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
    let extension = ext.to_string().to_lower()
    let content_type = match image_content_type(extension) {
      Some(value) => value
      None => "application/octet-stream"
    }
    let mut hyperlink = ""
    let mut hyperlink_type = HyperlinkType::Unset
    match tag_attributes_in(pic_body[:], "a:hlinkClick") {
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
      data,
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
  sheet : Worksheet,
  archive : @zip.Archive,
) -> Array[Chart] raise XlsxError {
  let charts : Array[Chart] = []
  let chart_targets = if drawing_rels_xml.to_string() == "" {
    {}
  } else {
    parse_relationship_targets(drawing_rels_xml, rel_chart)
  }
  let anchors = parse_drawing_anchors(drawing_xml)
  for entry in anchors {
    let (anchor_xml, positioning) = entry
    let chart_tag = match tag_attributes_in(anchor_xml[:], "c:chart") {
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
    let xml = @encoding/utf8.decode(chart_bytes) catch {
      _ => raise InvalidXml(msg="drawing chart xml decode failed")
    }
    let from_body = match extract_tag_body_from(anchor_xml[:], "xdr:from") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing anchor from missing")
    }
    let col_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:col",
      "drawing col invalid",
    )
    let row_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:row",
      "drawing row invalid",
    )
    let col_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:colOff",
      "drawing colOff invalid",
    )
    let row_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:rowOff",
      "drawing rowOff invalid",
    )
    let reference = cell_ref_from(row_idx0 + 1, col_idx0 + 1)
    let offset_x = col_off_emu / picture_emu_per_pixel
    let offset_y = row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = match positioning {
      OneCell => {
        let ext_tag = match tag_attributes_in(anchor_xml[:], "xdr:ext") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing ext missing")
        }
        let cx = match attr_value(ext_tag, "cx") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing cx invalid")
            }
          None => raise InvalidXml(msg="drawing cx missing")
        }
        let cy = match attr_value(ext_tag, "cy") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing cy invalid")
            }
          None => raise InvalidXml(msg="drawing cy missing")
        }
        (cx, cy)
      }
      _ => {
        let to_body = match extract_tag_body_from(anchor_xml[:], "xdr:to") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing anchor to missing")
        }
        let to_col_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:col",
          "drawing to col invalid",
        )
        let to_row_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:row",
          "drawing to row invalid",
        )
        let to_col_off = parse_xml_int_tag(
          to_body[:],
          "xdr:colOff",
          "drawing to colOff invalid",
        )
        let to_row_off = parse_xml_int_tag(
          to_body[:],
          "xdr:rowOff",
          "drawing to rowOff invalid",
        )
        let cx = drawing_axis_span_emu(
          sheet, "col", col_idx0, col_off_emu, to_col_idx0, to_col_off,
        )
        let cy = drawing_axis_span_emu(
          sheet, "row", row_idx0, row_off_emu, to_row_idx0, to_row_off,
        )
        (cx, cy)
      }
    }
    let client_tag = match tag_attributes_in(anchor_xml[:], "xdr:clientData") {
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
    let sp_body = match extract_tag_body_from(anchor_xml[:], "xdr:sp") {
      Some(value) => value
      None => continue
    }
    if !sp_body.contains("<a:prstGeom") {
      continue
    }
    let from_body = match extract_tag_body_from(anchor_xml[:], "xdr:from") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing anchor from missing")
    }
    let col_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:col",
      "drawing col invalid",
    )
    let row_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:row",
      "drawing row invalid",
    )
    let reference = cell_ref_from(row_idx0 + 1, col_idx0 + 1)
    let c_nv_pr_tag = match tag_attributes_in(sp_body[:], "xdr:cNvPr") {
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
    let client_tag = match tag_attributes_in(anchor_xml[:], "xdr:clientData") {
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
    let sppr_body = match extract_tag_body_from(sp_body[:], "xdr:spPr") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing shape spPr missing")
    }
    let xfrm_body = match extract_tag_body_from(sppr_body[:], "a:xfrm") {
      Some(value) => value
      None => sppr_body
    }
    let ext_tag = match tag_attributes_in(xfrm_body[:], "a:ext") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing shape ext missing")
    }
    let cx = match attr_value(ext_tag, "cx") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="drawing shape cx invalid")
        }
      None => raise InvalidXml(msg="drawing shape cx missing")
    }
    let cy = match attr_value(ext_tag, "cy") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="drawing shape cy invalid")
        }
      None => raise InvalidXml(msg="drawing shape cy missing")
    }
    let width = (cx.to_double() / picture_emu_per_pixel.to_double())
      .round()
      .to_int()
    let height = (cy.to_double() / picture_emu_per_pixel.to_double())
      .round()
      .to_int()
    let geom_tag = match tag_attributes_in(sppr_body[:], "a:prstGeom") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing shape prstGeom missing")
    }
    let shape_type = match attr_value(geom_tag, "prst") {
      Some(value) => unescape_xml_text(value)
      None => raise InvalidXml(msg="drawing shape prst missing")
    }
    let mut fill_color = ""
    let mut fill_transparency = 0
    match extract_tag_body_from(sppr_body[:], "a:solidFill") {
      Some(fill_body) =>
        match tag_attributes_in(fill_body[:], "a:srgbClr") {
          Some(tag) =>
            match attr_value(tag, "val") {
              Some(value) => {
                fill_color = unescape_xml_text(value)
                match tag_attributes_in(fill_body[:], "a:alpha") {
                  Some(alpha_tag) =>
                    match attr_value(alpha_tag, "val") {
                      Some(alpha) =>
                        try @strconv.parse_int(alpha, base=10) catch {
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
    match tag_attributes_in(sppr_body[:], "a:ln") {
      Some(tag) => {
        match attr_value(tag, "w") {
          Some(value) =>
            try @strconv.parse_int(value, base=10) catch {
              _ => ()
            } noraise {
              value => line_width = value.to_double() / 12700.0
            }
          None => ()
        }
        match extract_tag_body_from(sppr_body[:], "a:ln") {
          Some(ln_body) =>
            match tag_attributes_in(ln_body[:], "a:srgbClr") {
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
    match extract_tag_body_from(sp_body[:], "xdr:txBody") {
      Some(tx_body) => {
        let tx = tx_body.to_string()
        let mut first = true
        for chunk in tx.split("<a:t>") {
          if first {
            first = false
            continue
          }
          let part = chunk.to_string()
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
  sheet : Worksheet,
) -> Map[String, SlicerAnchorInfo] raise XlsxError {
  let out : Map[String, SlicerAnchorInfo] = {}
  let anchors = parse_drawing_anchors(drawing_xml)
  for entry in anchors {
    let (anchor_xml, positioning) = entry
    let slicer_tag = match tag_attributes_in(anchor_xml[:], "sle:slicer") {
      Some(value) => value
      None => continue
    }
    let slicer_name = match attr_value(slicer_tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => continue
    }
    let from_body = match extract_tag_body_from(anchor_xml[:], "xdr:from") {
      Some(value) => value
      None => raise InvalidXml(msg="drawing slicer from missing")
    }
    let col_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:col",
      "drawing slicer col invalid",
    )
    let row_idx0 = parse_xml_int_tag(
      from_body[:],
      "xdr:row",
      "drawing slicer row invalid",
    )
    let col_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:colOff",
      "drawing slicer colOff invalid",
    )
    let row_off_emu = parse_xml_int_tag(
      from_body[:],
      "xdr:rowOff",
      "drawing slicer rowOff invalid",
    )
    let cell = cell_ref_from(row_idx0 + 1, col_idx0 + 1)
    let offset_x = col_off_emu / picture_emu_per_pixel
    let offset_y = row_off_emu / picture_emu_per_pixel
    let (width_emu, height_emu) = match positioning {
      OneCell => {
        let ext_tag = match tag_attributes_in(anchor_xml[:], "xdr:ext") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing slicer ext missing")
        }
        let cx = match attr_value(ext_tag, "cx") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing slicer cx invalid")
            }
          None => raise InvalidXml(msg="drawing slicer cx missing")
        }
        let cy = match attr_value(ext_tag, "cy") {
          Some(value) =>
            @strconv.parse_int(value, base=10) catch {
              _ => raise InvalidXml(msg="drawing slicer cy invalid")
            }
          None => raise InvalidXml(msg="drawing slicer cy missing")
        }
        (cx, cy)
      }
      _ => {
        let to_body = match extract_tag_body_from(anchor_xml[:], "xdr:to") {
          Some(value) => value
          None => raise InvalidXml(msg="drawing slicer to missing")
        }
        let to_col_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:col",
          "drawing slicer to col invalid",
        )
        let to_row_idx0 = parse_xml_int_tag(
          to_body[:],
          "xdr:row",
          "drawing slicer to row invalid",
        )
        let to_col_off = parse_xml_int_tag(
          to_body[:],
          "xdr:colOff",
          "drawing slicer to colOff invalid",
        )
        let to_row_off = parse_xml_int_tag(
          to_body[:],
          "xdr:rowOff",
          "drawing slicer to rowOff invalid",
        )
        let cx = drawing_axis_span_emu(
          sheet, "col", col_idx0, col_off_emu, to_col_idx0, to_col_off,
        )
        let cy = drawing_axis_span_emu(
          sheet, "row", row_idx0, row_off_emu, to_row_idx0, to_row_off,
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
      tag_attributes_in(anchor_xml[:], "xdr:graphicFrame") {
      Some(value) => value
      None => ""
    }
    let macro_name = match attr_value(graphic_frame_tag, "macro") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let c_nv_pr_tag = match tag_attributes_in(anchor_xml[:], "xdr:cNvPr") {
      Some(value) => value
      None => ""
    }
    let alt_text = match attr_value(c_nv_pr_tag, "descr") {
      Some(value) => unescape_xml_text(value)
      None => ""
    }
    let client_tag = match tag_attributes_in(anchor_xml[:], "xdr:clientData") {
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
