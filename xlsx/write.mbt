///|
fn write_workbook_protection_xml(protection : WorkbookProtection) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <workbookProtection")
  if protection.lock_structure {
    sb.write_view(" lockStructure=\"1\"")
  }
  if protection.lock_windows {
    sb.write_view(" lockWindows=\"1\"")
  }
  if protection.algorithm_name != "" {
    sb.write_view(" workbookAlgorithmName=\"")
    sb.write_view(escape_xml_attr(protection.algorithm_name))
    sb.write_view("\"")
  }
  if protection.hash_value != "" {
    sb.write_view(" workbookHashValue=\"")
    sb.write_view(escape_xml_attr(protection.hash_value))
    sb.write_view("\"")
  }
  if protection.salt_value != "" {
    sb.write_view(" workbookSaltValue=\"")
    sb.write_view(escape_xml_attr(protection.salt_value))
    sb.write_view("\"")
  }
  if protection.spin_count > 0 {
    sb.write_view(" workbookSpinCount=\"\{protection.spin_count}\"")
  }
  sb.write_view("/>\n")
  sb.to_string()
}

///|
fn write_shared_strings_xml(
  values : Array[SharedStringEntry],
  total_count : Int,
) -> String {
  fn write_rich_text_color(sb : StringBuilder, font : RichTextFont) -> Unit {
    let tint = match font.color_tint {
      Some(v) => if v == 0.0 { None } else { Some(v) }
      None => None
    }
    match font.color_theme {
      Some(value) => {
        sb.write_view("<color theme=\"\{value}\"")
        match tint {
          Some(v) => sb.write_view(" tint=\"\{v}\"")
          None => ()
        }
        sb.write_view("/>")
        return
      }
      None => ()
    }
    match font.color_indexed {
      Some(value) => {
        sb.write_view("<color indexed=\"\{value}\"")
        match tint {
          Some(v) => sb.write_view(" tint=\"\{v}\"")
          None => ()
        }
        sb.write_view("/>")
        return
      }
      None => ()
    }
    match font.color {
      Some(color) => {
        let normalized = color.replace_all(old="#", new="")
        let rgb = if normalized.length() == 6 {
          "FF" + normalized
        } else {
          normalized
        }
        sb.write_view("<color rgb=\"\{escape_xml_attr(rgb)}\"")
        match tint {
          Some(v) => sb.write_view(" tint=\"\{v}\"")
          None => ()
        }
        sb.write_view("/>")
      }
      None => ()
    }
  }

  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"\{total_count}\" uniqueCount=\"\{values.length()}\">\n",
  )
  for entry in values {
    match entry.runs {
      Some(runs) => {
        sb.write_view("  <si>\n")
        for run in runs {
          sb.write_view("    <r>")
          match run.font {
            Some(font) => {
              sb.write_view("<rPr>")
              if font.bold {
                sb.write_view("<b/>")
              }
              if font.italic {
                sb.write_view("<i/>")
              }
              if font.strike {
                sb.write_view("<strike/>")
              }
              if font.outline {
                sb.write_view("<outline/>")
              }
              if font.shadow {
                sb.write_view("<shadow/>")
              }
              if font.condense {
                sb.write_view("<condense/>")
              }
              if font.extended {
                sb.write_view("<extend/>")
              }
              match font.underline {
                Some(value) =>
                  sb.write_view("<u val=\"\{escape_xml_attr(value)}\"/>")
                None => ()
              }
              match font.size {
                Some(size) => sb.write_view("<sz val=\"\{size}\"/>")
                None => ()
              }
              match font.charset {
                Some(value) => sb.write_view("<charset val=\"\{value}\"/>")
                None => ()
              }
              match font.family_number {
                Some(value) => sb.write_view("<family val=\"\{value}\"/>")
                None => ()
              }
              match font.family {
                Some(family) =>
                  sb.write_view("<rFont val=\"\{escape_xml_attr(family)}\"/>")
                None => ()
              }
              match font.color {
                Some(_) => write_rich_text_color(sb, font)
                None =>
                  if font.color_theme is Some(_) ||
                    font.color_indexed is Some(_) ||
                    font.color_tint is Some(_) {
                    write_rich_text_color(sb, font)
                  }
              }
              match font.vert_align {
                Some(value) =>
                  sb.write_view(
                    "<vertAlign val=\"\{escape_xml_attr(value)}\"/>",
                  )
                None => ()
              }
              match font.scheme {
                Some(value) =>
                  sb.write_view("<scheme val=\"\{escape_xml_attr(value)}\"/>")
                None => ()
              }
              sb.write_view("</rPr>")
            }
            None => ()
          }
          if run.text.has_prefix(" ") ||
            run.text.has_suffix(" ") ||
            run.text.contains("\n") {
            sb.write_view("<t xml:space=\"preserve\">")
          } else {
            sb.write_view("<t>")
          }
          sb.write_view(escape_xml_text(run.text))
          sb.write_view("</t></r>\n")
        }
        sb.write_view("  </si>\n")
      }
      None => {
        sb.write_view("  <si>")
        if entry.text.has_prefix(" ") ||
          entry.text.has_suffix(" ") ||
          entry.text.contains("\n") {
          sb.write_view("<t xml:space=\"preserve\">")
        } else {
          sb.write_view("<t>")
        }
        sb.write_view(escape_xml_text(entry.text))
        sb.write_view("</t></si>\n")
      }
    }
  }
  sb.write_view("</sst>")
  sb.to_string()
}

///|
fn collect_formula_cells(workbook : Workbook) -> Array[(Int, String)] {
  let formula_cells : Array[(Int, String)] = []
  for i, sheet in workbook.sheets() {
    let sheet_id = i + 1
    for cell in sheet.cells() {
      match cell.formula {
        Some(value) =>
          if value != "" {
            formula_cells.push((sheet_id, cell.reference))
          }
        None => ()
      }
    }
  }
  formula_cells
}

///|
fn write_calc_chain_xml(cells : Array[(Int, String)]) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<calcChain xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">\n",
  )
  for cell in cells {
    let (sheet_id, reference) = cell
    sb.write_view("  <c r=\"")
    sb.write_view(escape_xml_attr(reference))
    sb.write_view("\" i=\"\{sheet_id}\"/>\n")
  }
  sb.write_view("</calcChain>")
  sb.to_string()
}

///|
priv struct DrawingImage {
  image : Image
  rel_id : Int
  hyperlink_rel_id : Int?
}

///|
priv struct DrawingChart {
  reference : String
  offset_x : Int
  offset_y : Int
  width_emu : Int
  height_emu : Int
  print_object : Bool
  locked : Bool
  positioning : PicturePositioning
  rel_id : Int
}

///|
priv struct DrawingHyperlink {
  rel_id : Int
  target : String
  link_type : HyperlinkType
}

///|
priv struct DrawingSlicer {
  slicer : Slicer
  is_table_slicer : Bool
}

///|
priv struct ResolvedSlicerCache {
  cache_id : Int
  cache_name : String
  source_name : String
  item_desc : Bool
  source : ResolvedSlicerCacheSource
}

///|
priv enum ResolvedSlicerCacheSource {
  Table(Int, Int)
  Pivot(Int, Int, String)
}

///|
let emu_per_pixel = 9525

///|
fn drawing_int64_to_int_for_write(
  value : Int64,
  field : StringView,
) -> Int raise XlsxError {
  let min_int = -0x7fff_ffffL - 1L
  if value < min_int || value > 0x7fff_ffffL {
    raise InvalidSheetOperation(msg=field.to_owned() + " out of range")
  }
  value.to_int()
}

///|
fn drawing_pixel_offset_for_write(
  value : Int,
  field : StringView,
) -> Int raise XlsxError {
  drawing_int64_to_int_for_write(
    Int64::from_int(value) * Int64::from_int(emu_per_pixel),
    field,
  )
}

///|
fn drawing_extent_for_write(
  value : Int,
  field : StringView,
) -> Int raise XlsxError {
  if value < 0 {
    raise InvalidSheetOperation(msg=field.to_owned() + " must be >= 0")
  }
  value
}

///|
fn drawing_scaled_extent_for_write(
  pixels : Double,
  scale : Double,
  field : StringView,
) -> Int raise XlsxError {
  let value = (pixels * scale * emu_per_pixel.to_double()).round()
  if Double::is_nan(value) ||
    Double::is_inf(value) ||
    value < 0.0 ||
    value > 2147483647.0 {
    raise InvalidSheetOperation(msg=field.to_owned() + " out of range")
  }
  value.to_int()
}

///|
fn drawing_axis_boundary_emu_for_write(
  metrics : DrawingAxisMetrics,
  idx0 : Int,
) -> Int64 raise XlsxError {
  let pixels = metrics.pixel_span(0, idx0)
  let factor = Int64::from_int(emu_per_pixel)
  let max_pixels = (0x7fff_ffff_ffff_ffffL - 0xffff_ffffL) / factor
  if pixels > max_pixels {
    raise InvalidSheetOperation(msg="drawing grid geometry out of range")
  }
  pixels * factor
}

///|
fn two_cell_axis_to(
  metrics : DrawingAxisMetrics,
  start_idx0 : Int,
  start_off_emu : Int,
  size_emu : Int,
) -> (Int, Int) raise XlsxError {
  if start_idx0 < 0 || start_idx0 >= metrics.limit {
    raise InvalidSheetOperation(msg="drawing " + metrics.axis + " invalid")
  }
  ignore(drawing_extent_for_write(size_emu, "drawing extent"))
  let start = drawing_axis_boundary_emu_for_write(metrics, start_idx0) +
    Int64::from_int(start_off_emu)
  let target = start + Int64::from_int(size_emu)
  let grid_end = drawing_axis_boundary_emu_for_write(metrics, metrics.limit)
  if target > grid_end {
    raise InvalidSheetOperation(msg="drawing extends beyond worksheet grid")
  }
  if target < 0L {
    return (0, drawing_int64_to_int_for_write(target, "drawing marker offset"))
  }
  if target == grid_end {
    return (metrics.limit, 0)
  }
  let mut low = 0
  let mut high = metrics.limit + 1
  while low < high {
    let mid = low + (high - low) / 2
    let boundary = drawing_axis_boundary_emu_for_write(metrics, mid)
    if boundary <= target {
      low = mid + 1
    } else {
      high = mid
    }
  }
  let idx0 = low - 1
  let boundary = drawing_axis_boundary_emu_for_write(metrics, idx0)
  (
    idx0,
    drawing_int64_to_int_for_write(target - boundary, "drawing marker offset"),
  )
}

///|
fn write_drawing_xml(
  sheet : Worksheet?,
  images : Array[DrawingImage],
  charts : Array[DrawingChart],
  shapes : Array[Shape],
  slicers : Array[DrawingSlicer],
) -> String raise XlsxError {
  let drawing_metrics = match sheet {
    Some(value) => drawing_metrics_for_sheet(value)
    None => drawing_metrics_for_sheet(Worksheet::new("Drawing"))
  }
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<xdr:wsDr xmlns:xdr=\"http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n",
  )
  let mut obj_id = 1
  for item in images {
    let image = item.image
    let (row, col) = cell_ref_to_rc(image.reference)
    let col_idx = col - 1
    let row_idx = row - 1
    let pic_id = obj_id
    obj_id = obj_id + 1
    let col_off = drawing_pixel_offset_for_write(
      image.offset_x,
      "drawing image column offset",
    )
    let row_off = drawing_pixel_offset_for_write(
      image.offset_y,
      "drawing image row offset",
    )
    let cx = drawing_extent_for_write(image.width_emu, "drawing image width")
    let cy = drawing_extent_for_write(image.height_emu, "drawing image height")
    let picture_name = if image.name == "" {
      "Image \{pic_id}"
    } else {
      image.name
    }
    match image.positioning {
      TwoCell => {
        sb.write_view("  <xdr:twoCellAnchor>\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        let (to_col_idx, to_col_off) = two_cell_axis_to(
          drawing_metrics.cols,
          col_idx,
          col_off,
          cx,
        )
        let (to_row_idx, to_row_off) = two_cell_axis_to(
          drawing_metrics.rows,
          row_idx,
          row_off,
          cy,
        )
        sb.write_view("    <xdr:to>\n")
        sb.write_view("      <xdr:col>\{to_col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{to_col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{to_row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{to_row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:to>\n")
      }
      Absolute => {
        sb.write_view("  <xdr:twoCellAnchor editAs=\"absolute\">\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        let (to_col_idx, to_col_off) = two_cell_axis_to(
          drawing_metrics.cols,
          col_idx,
          col_off,
          cx,
        )
        let (to_row_idx, to_row_off) = two_cell_axis_to(
          drawing_metrics.rows,
          row_idx,
          row_off,
          cy,
        )
        sb.write_view("    <xdr:to>\n")
        sb.write_view("      <xdr:col>\{to_col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{to_col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{to_row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{to_row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:to>\n")
      }
      OneCell => {
        sb.write_view("  <xdr:oneCellAnchor>\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        sb.write_view("    <xdr:ext cx=\"\{cx}\" cy=\"\{cy}\"/>\n")
      }
    }
    sb.write_view("    <xdr:pic>\n")
    sb.write_view("      <xdr:nvPicPr>\n")
    match item.hyperlink_rel_id {
      Some(link_id) => {
        sb.write_view("        <xdr:cNvPr id=\"\{pic_id}\" name=\"")
        sb.write_view(escape_xml_attr(picture_name))
        sb.write_view("\"")
        if image.alt_text != "" {
          sb.write_view(" descr=\"")
          sb.write_view(escape_xml_attr(image.alt_text))
          sb.write_view("\"")
        }
        sb.write_view(">\n")
        sb.write_view("          <a:hlinkClick r:id=\"rId\{link_id}\"/>\n")
        sb.write_view("        </xdr:cNvPr>\n")
      }
      None => {
        sb.write_view("        <xdr:cNvPr id=\"\{pic_id}\" name=\"")
        sb.write_view(escape_xml_attr(picture_name))
        sb.write_view("\"")
        if image.alt_text != "" {
          sb.write_view(" descr=\"")
          sb.write_view(escape_xml_attr(image.alt_text))
          sb.write_view("\"")
        }
        sb.write_view("/>\n")
      }
    }
    if image.lock_aspect_ratio {
      sb.write_view("        <xdr:cNvPicPr>\n")
      sb.write_view("          <a:picLocks noChangeAspect=\"1\"/>\n")
      sb.write_view("        </xdr:cNvPicPr>\n")
    } else {
      sb.write_view("        <xdr:cNvPicPr/>\n")
    }
    sb.write_view("      </xdr:nvPicPr>\n")
    sb.write_view("      <xdr:blipFill>\n")
    sb.write_view("        <a:blip r:embed=\"rId\{item.rel_id}\"/>\n")
    sb.write_view("        <a:stretch><a:fillRect/></a:stretch>\n")
    sb.write_view("      </xdr:blipFill>\n")
    sb.write_view("      <xdr:spPr>\n")
    sb.write_view("        <a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>\n")
    sb.write_view("      </xdr:spPr>\n")
    sb.write_view("    </xdr:pic>\n")
    sb.write_view(
      "    <xdr:clientData fLocksWithSheet=\"\{bool_attr(image.locked)}\" fPrintsWithSheet=\"\{bool_attr(image.print_object)}\"/>\n",
    )
    match image.positioning {
      TwoCell => sb.write_view("  </xdr:twoCellAnchor>\n")
      Absolute => sb.write_view("  </xdr:twoCellAnchor>\n")
      OneCell => sb.write_view("  </xdr:oneCellAnchor>\n")
    }
  }
  for chart in charts {
    let (row, col) = cell_ref_to_rc(chart.reference)
    let col_idx = col - 1
    let row_idx = row - 1
    let frame_id = obj_id
    obj_id = obj_id + 1
    let col_off = drawing_pixel_offset_for_write(
      chart.offset_x,
      "drawing chart column offset",
    )
    let row_off = drawing_pixel_offset_for_write(
      chart.offset_y,
      "drawing chart row offset",
    )
    let cx = drawing_extent_for_write(chart.width_emu, "drawing chart width")
    let cy = drawing_extent_for_write(chart.height_emu, "drawing chart height")
    match chart.positioning {
      TwoCell => {
        sb.write_view("  <xdr:twoCellAnchor>\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        let (to_col_idx, to_col_off) = two_cell_axis_to(
          drawing_metrics.cols,
          col_idx,
          col_off,
          cx,
        )
        let (to_row_idx, to_row_off) = two_cell_axis_to(
          drawing_metrics.rows,
          row_idx,
          row_off,
          cy,
        )
        sb.write_view("    <xdr:to>\n")
        sb.write_view("      <xdr:col>\{to_col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{to_col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{to_row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{to_row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:to>\n")
      }
      Absolute => {
        sb.write_view("  <xdr:twoCellAnchor editAs=\"absolute\">\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        let (to_col_idx, to_col_off) = two_cell_axis_to(
          drawing_metrics.cols,
          col_idx,
          col_off,
          cx,
        )
        let (to_row_idx, to_row_off) = two_cell_axis_to(
          drawing_metrics.rows,
          row_idx,
          row_off,
          cy,
        )
        sb.write_view("    <xdr:to>\n")
        sb.write_view("      <xdr:col>\{to_col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{to_col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{to_row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{to_row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:to>\n")
      }
      OneCell => {
        sb.write_view("  <xdr:oneCellAnchor>\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        sb.write_view("    <xdr:ext cx=\"\{cx}\" cy=\"\{cy}\"/>\n")
      }
    }
    sb.write_view("    <xdr:graphicFrame>\n")
    sb.write_view("      <xdr:nvGraphicFramePr>\n")
    sb.write_view(
      "        <xdr:cNvPr id=\"\{frame_id}\" name=\"Chart \{frame_id}\"/>\n",
    )
    sb.write_view("        <xdr:cNvGraphicFramePr/>\n")
    sb.write_view("      </xdr:nvGraphicFramePr>\n")
    sb.write_view("      <xdr:xfrm>\n")
    sb.write_view("        <a:off x=\"0\" y=\"0\"/>\n")
    sb.write_view("        <a:ext cx=\"\{cx}\" cy=\"\{cy}\"/>\n")
    sb.write_view("      </xdr:xfrm>\n")
    sb.write_view("      <a:graphic>\n")
    sb.write_view(
      "        <a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/chart\">\n",
    )
    sb.write_view(
      "          <c:chart xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" r:id=\"rId\{chart.rel_id}\"/>\n",
    )
    sb.write_view("        </a:graphicData>\n")
    sb.write_view("      </a:graphic>\n")
    sb.write_view("    </xdr:graphicFrame>\n")
    sb.write_view(
      "    <xdr:clientData fLocksWithSheet=\"\{bool_attr(chart.locked)}\" fPrintsWithSheet=\"\{bool_attr(chart.print_object)}\"/>\n",
    )
    match chart.positioning {
      TwoCell => sb.write_view("  </xdr:twoCellAnchor>\n")
      Absolute => sb.write_view("  </xdr:twoCellAnchor>\n")
      OneCell => sb.write_view("  </xdr:oneCellAnchor>\n")
    }
  }
  for shape in shapes {
    let (row, col) = cell_ref_to_rc(shape.reference)
    let col_idx = col - 1
    let row_idx = row - 1
    let shape_id = obj_id
    obj_id = obj_id + 1
    let cx = drawing_scaled_extent_for_write(
      shape.width.to_double(),
      shape.scale_x,
      "drawing shape width",
    )
    let cy = drawing_scaled_extent_for_write(
      shape.height.to_double(),
      shape.scale_y,
      "drawing shape height",
    )
    match shape.positioning {
      TwoCell => {
        sb.write_view("  <xdr:twoCellAnchor>\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>0</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>0</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        let (to_col_idx, to_col_off) = two_cell_axis_to(
          drawing_metrics.cols,
          col_idx,
          0,
          cx,
        )
        let (to_row_idx, to_row_off) = two_cell_axis_to(
          drawing_metrics.rows,
          row_idx,
          0,
          cy,
        )
        sb.write_view("    <xdr:to>\n")
        sb.write_view("      <xdr:col>\{to_col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{to_col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{to_row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{to_row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:to>\n")
      }
      Absolute => {
        sb.write_view("  <xdr:twoCellAnchor editAs=\"absolute\">\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>0</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>0</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        let (to_col_idx, to_col_off) = two_cell_axis_to(
          drawing_metrics.cols,
          col_idx,
          0,
          cx,
        )
        let (to_row_idx, to_row_off) = two_cell_axis_to(
          drawing_metrics.rows,
          row_idx,
          0,
          cy,
        )
        sb.write_view("    <xdr:to>\n")
        sb.write_view("      <xdr:col>\{to_col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{to_col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{to_row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{to_row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:to>\n")
      }
      OneCell => {
        sb.write_view("  <xdr:oneCellAnchor>\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>0</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>0</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        sb.write_view("    <xdr:ext cx=\"\{cx}\" cy=\"\{cy}\"/>\n")
      }
    }
    sb.write_view("    <xdr:sp>\n")
    sb.write_view("      <xdr:nvSpPr>\n")
    let shape_name = if shape.name == "" {
      "Shape \{shape_id}"
    } else {
      shape.name
    }
    sb.write_view("        <xdr:cNvPr id=\"\{shape_id}\" name=\"")
    sb.write_view(escape_xml_attr(shape_name))
    sb.write_view("\"")
    if shape.macro_name != "" {
      sb.write_view(" macro=\"")
      sb.write_view(escape_xml_attr(shape.macro_name))
      sb.write_view("\"")
    }
    if shape.alt_text != "" {
      sb.write_view(" descr=\"")
      sb.write_view(escape_xml_attr(shape.alt_text))
      sb.write_view("\"")
    }
    sb.write_view("/>\n")
    sb.write_view("        <xdr:cNvSpPr/>\n")
    sb.write_view("      </xdr:nvSpPr>\n")
    sb.write_view("      <xdr:spPr>\n")
    sb.write_view("        <a:xfrm>\n")
    sb.write_view("          <a:off x=\"0\" y=\"0\"/>\n")
    sb.write_view("          <a:ext cx=\"\{cx}\" cy=\"\{cy}\"/>\n")
    sb.write_view("        </a:xfrm>\n")
    sb.write_view("        <a:prstGeom prst=\"")
    sb.write_view(escape_xml_attr(shape.shape_type.to_lower()))
    sb.write_view("\"><a:avLst/></a:prstGeom>\n")
    if shape.fill_color != "" {
      let fill = shape.fill_color.replace_all(old="#", new="").to_upper()
      sb.write_view("        <a:solidFill><a:srgbClr val=\"")
      sb.write_view(escape_xml_attr(fill))
      if shape.fill_transparency > 0 {
        let alpha = (100 - shape.fill_transparency) * 1000
        sb.write_view(
          "\"><a:alpha val=\"\{alpha}\"/></a:srgbClr></a:solidFill>\n",
        )
      } else {
        sb.write_view("\"/></a:solidFill>\n")
      }
    }
    if shape.line_color != "" || shape.line_width != 1.0 {
      sb.write_view("        <a:ln")
      if shape.line_width != 1.0 {
        let w = (shape.line_width * 12700.0).round().to_int()
        sb.write_view(" w=\"\{w}\"")
      }
      if shape.line_color == "" {
        sb.write_view("/>\n")
      } else {
        let line = shape.line_color.replace_all(old="#", new="").to_upper()
        sb.write_view("><a:solidFill><a:srgbClr val=\"")
        sb.write_view(escape_xml_attr(line))
        sb.write_view("\"/></a:solidFill></a:ln>\n")
      }
    }
    sb.write_view("      </xdr:spPr>\n")
    if shape.paragraph.length() > 0 || shape.text != "" {
      sb.write_view("      <xdr:txBody>\n")
      sb.write_view("        <a:bodyPr/>\n")
      sb.write_view("        <a:lstStyle/>\n")
      let runs = if shape.paragraph.length() > 0 {
        shape.paragraph[:]
      } else {
        [{ text: shape.text, font: None }]
      }
      for run in runs {
        sb.write_view("        <a:p>\n")
        sb.write_view("          <a:r>\n")
        match run.font {
          Some(font) => {
            sb.write_view("            <a:rPr")
            sb.write_view(" lang=\"en-US\"")
            if font.bold {
              sb.write_view(" b=\"1\"")
            }
            if font.italic {
              sb.write_view(" i=\"1\"")
            }
            if font.strike {
              sb.write_view(" strike=\"sngStrike\"")
            }
            match font.underline {
              Some(value) => sb.write_view(" u=\"\{escape_xml_attr(value)}\"")
              None => ()
            }
            match font.size {
              Some(size) =>
                sb.write_view(" sz=\"\{(size * 100.0).round().to_int()}\"")
              None => ()
            }
            sb.write_view(">")
            match font.family {
              Some(family) => {
                sb.write_view("<a:latin typeface=\"")
                sb.write_view(escape_xml_attr(family))
                sb.write_view("\"/>")
                sb.write_view("<a:ea typeface=\"")
                sb.write_view(escape_xml_attr(family))
                sb.write_view("\"/>")
                sb.write_view("<a:cs typeface=\"")
                sb.write_view(escape_xml_attr(family))
                sb.write_view("\"/>")
              }
              None => ()
            }
            match font.color {
              Some(color) => {
                let normalized = color.replace_all(old="#", new="").to_upper()
                sb.write_view("<a:solidFill><a:srgbClr val=\"")
                sb.write_view(escape_xml_attr(normalized))
                sb.write_view("\"/></a:solidFill>")
              }
              None => ()
            }
            sb.write_view("</a:rPr>\n")
          }
          None => sb.write_view("            <a:rPr lang=\"en-US\"/>\n")
        }
        let text_value = if run.text == "" { " " } else { run.text }
        if text_value.has_prefix(" ") ||
          text_value.has_suffix(" ") ||
          text_value.contains("\n") {
          sb.write_view("            <a:t xml:space=\"preserve\">")
        } else {
          sb.write_view("            <a:t>")
        }
        sb.write_view(escape_xml_text(text_value))
        sb.write_view("</a:t>\n")
        sb.write_view("          </a:r>\n")
        sb.write_view("        </a:p>\n")
      }
      sb.write_view("      </xdr:txBody>\n")
    }
    sb.write_view("    </xdr:sp>\n")
    sb.write_view(
      "    <xdr:clientData fLocksWithSheet=\"\{bool_attr(shape.locked)}\" fPrintsWithSheet=\"\{bool_attr(shape.print_object)}\"/>\n",
    )
    match shape.positioning {
      TwoCell => sb.write_view("  </xdr:twoCellAnchor>\n")
      Absolute => sb.write_view("  </xdr:twoCellAnchor>\n")
      OneCell => sb.write_view("  </xdr:oneCellAnchor>\n")
    }
  }
  for item in slicers {
    let slicer = item.slicer
    let (row, col) = cell_ref_to_rc(slicer.cell)
    let col_idx = col - 1
    let row_idx = row - 1
    let frame_id = obj_id
    obj_id = obj_id + 1
    let offset_x = match slicer.format.offset_x {
      Some(v) => v
      None => 0
    }
    let offset_y = match slicer.format.offset_y {
      Some(v) => v
      None => 0
    }
    let col_off = drawing_pixel_offset_for_write(
      offset_x, "drawing slicer column offset",
    )
    let row_off = drawing_pixel_offset_for_write(
      offset_y, "drawing slicer row offset",
    )
    let scale_x = match slicer.format.scale_x {
      Some(v) => if v <= 0.0 { 1.0 } else { v }
      None => 1.0
    }
    let scale_y = match slicer.format.scale_y {
      Some(v) => if v <= 0.0 { 1.0 } else { v }
      None => 1.0
    }
    let cx = drawing_scaled_extent_for_write(
      slicer.width.to_double(),
      scale_x,
      "drawing slicer width",
    )
    let cy = drawing_scaled_extent_for_write(
      slicer.height.to_double(),
      scale_y,
      "drawing slicer height",
    )
    let positioning = match slicer.format.positioning {
      Some(v) => v
      None => TwoCell
    }
    match positioning {
      TwoCell => {
        sb.write_view("  <xdr:twoCellAnchor>\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        let (to_col_idx, to_col_off) = two_cell_axis_to(
          drawing_metrics.cols,
          col_idx,
          col_off,
          cx,
        )
        let (to_row_idx, to_row_off) = two_cell_axis_to(
          drawing_metrics.rows,
          row_idx,
          row_off,
          cy,
        )
        sb.write_view("    <xdr:to>\n")
        sb.write_view("      <xdr:col>\{to_col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{to_col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{to_row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{to_row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:to>\n")
      }
      Absolute => {
        sb.write_view("  <xdr:twoCellAnchor editAs=\"absolute\">\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        let (to_col_idx, to_col_off) = two_cell_axis_to(
          drawing_metrics.cols,
          col_idx,
          col_off,
          cx,
        )
        let (to_row_idx, to_row_off) = two_cell_axis_to(
          drawing_metrics.rows,
          row_idx,
          row_off,
          cy,
        )
        sb.write_view("    <xdr:to>\n")
        sb.write_view("      <xdr:col>\{to_col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{to_col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{to_row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{to_row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:to>\n")
      }
      OneCell => {
        sb.write_view("  <xdr:oneCellAnchor>\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        sb.write_view("    <xdr:ext cx=\"\{cx}\" cy=\"\{cy}\"/>\n")
      }
    }
    let alt_text = match slicer.format.alt_text {
      Some(v) => v
      None => ""
    }
    sb.write_view(
      "    <mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\">\n",
    )
    if item.is_table_slicer {
      sb.write_view(
        "      <mc:Choice Requires=\"sle15\" xmlns:sle15=\"http://schemas.microsoft.com/office/drawing/2012/slicer\">\n",
      )
    } else {
      sb.write_view(
        "      <mc:Choice Requires=\"a14\" xmlns:a14=\"http://schemas.microsoft.com/office/drawing/2010/main\">\n",
      )
    }
    sb.write_view("        <xdr:graphicFrame")
    if slicer.macro_name != "" {
      sb.write_view(" macro=\"")
      sb.write_view(escape_xml_attr(slicer.macro_name))
      sb.write_view("\"")
    }
    sb.write_view(">\n")
    sb.write_view("          <xdr:nvGraphicFramePr>\n")
    sb.write_view("            <xdr:cNvPr id=\"\{frame_id}\" name=\"")
    sb.write_view(escape_xml_attr(slicer.name))
    sb.write_view("\"")
    if alt_text != "" {
      sb.write_view(" descr=\"")
      sb.write_view(escape_xml_attr(alt_text))
      sb.write_view("\"")
    }
    sb.write_view("/>\n")
    sb.write_view("            <xdr:cNvGraphicFramePr/>\n")
    sb.write_view("          </xdr:nvGraphicFramePr>\n")
    sb.write_view("          <xdr:xfrm>\n")
    sb.write_view("            <a:off x=\"0\" y=\"0\"/>\n")
    sb.write_view("            <a:ext cx=\"0\" cy=\"0\"/>\n")
    sb.write_view("          </xdr:xfrm>\n")
    sb.write_view("          <a:graphic>\n")
    sb.write_view(
      "            <a:graphicData uri=\"http://schemas.microsoft.com/office/drawing/2010/slicer\">\n",
    )
    sb.write_view(
      "              <sle:slicer xmlns:sle=\"http://schemas.microsoft.com/office/drawing/2010/slicer\" name=\"",
    )
    sb.write_view(escape_xml_attr(slicer.name))
    sb.write_view("\"/>\n")
    sb.write_view("            </a:graphicData>\n")
    sb.write_view("          </a:graphic>\n")
    sb.write_view("        </xdr:graphicFrame>\n")
    sb.write_view("      </mc:Choice>\n")
    sb.write_view("      <mc:Fallback>\n")
    sb.write_view("        <xdr:sp")
    if slicer.macro_name != "" {
      sb.write_view(" macro=\"")
      sb.write_view(escape_xml_attr(slicer.macro_name))
      sb.write_view("\"")
    }
    sb.write_view(">\n")
    sb.write_view("          <xdr:nvSpPr>\n")
    sb.write_view("            <xdr:cNvPr id=\"\{frame_id}\" name=\"")
    sb.write_view(escape_xml_attr(slicer.name))
    sb.write_view("\"")
    if alt_text != "" {
      sb.write_view(" descr=\"")
      sb.write_view(escape_xml_attr(alt_text))
      sb.write_view("\"")
    }
    sb.write_view("/>\n")
    sb.write_view("            <xdr:cNvSpPr txBox=\"1\"/>\n")
    sb.write_view("          </xdr:nvSpPr>\n")
    sb.write_view("          <xdr:spPr>\n")
    sb.write_view("            <a:xfrm>\n")
    sb.write_view("              <a:off x=\"2914650\" y=\"152400\"/>\n")
    sb.write_view("              <a:ext cx=\"1828800\" cy=\"2238375\"/>\n")
    sb.write_view("            </a:xfrm>\n")
    sb.write_view(
      "            <a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>\n",
    )
    sb.write_view(
      "            <a:solidFill><a:srgbClr val=\"FFFFFF\"/></a:solidFill>\n",
    )
    sb.write_view(
      "            <a:ln w=\"1\"><a:solidFill><a:prstClr val=\"black\"/></a:solidFill></a:ln>\n",
    )
    sb.write_view("          </xdr:spPr>\n")
    sb.write_view("          <xdr:txBody>\n")
    sb.write_view(
      "            <a:bodyPr vertOverflow=\"clip\" horzOverflow=\"clip\"/>\n",
    )
    sb.write_view("            <a:p><a:r><a:t>")
    sb.write_view(
      escape_xml_text(
        "This shape represents a table slicer. Table slicers are not supported in this version of Excel.",
      ),
    )
    sb.write_view("</a:t></a:r></a:p>\n")
    sb.write_view("            <a:p><a:r><a:t>")
    sb.write_view(
      escape_xml_text(
        "If the shape was modified in an earlier version of Excel, or if the workbook was saved in Excel 2007 or earlier, the slicer can't be used.",
      ),
    )
    sb.write_view("</a:t></a:r></a:p>\n")
    sb.write_view("          </xdr:txBody>\n")
    sb.write_view("        </xdr:sp>\n")
    sb.write_view("      </mc:Fallback>\n")
    sb.write_view("    </mc:AlternateContent>\n")
    let locked = match slicer.format.locked {
      Some(v) => v
      None => true
    }
    let print_object = match slicer.format.print_object {
      Some(v) => v
      None => true
    }
    sb.write_view(
      "    <xdr:clientData fLocksWithSheet=\"\{bool_attr(locked)}\" fPrintsWithSheet=\"\{bool_attr(print_object)}\"/>\n",
    )
    match positioning {
      TwoCell => sb.write_view("  </xdr:twoCellAnchor>\n")
      Absolute => sb.write_view("  </xdr:twoCellAnchor>\n")
      OneCell => sb.write_view("  </xdr:oneCellAnchor>\n")
    }
  }
  sb.write_view("</xdr:wsDr>")
  sb.to_string()
}

///|
fn write_sheet_pr_xml(options : SheetPropsOptions) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <sheetPr")
  match options.code_name {
    Some(value) => {
      sb.write_view(" codeName=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"")
    }
    None => ()
  }
  match options.enable_format_conditions_calculation {
    Some(value) =>
      sb.write_view(
        " enableFormatConditionsCalculation=\"\{bool_attr(value)}\"",
      )
    None => ()
  }
  match options.published {
    Some(value) => sb.write_view(" published=\"\{bool_attr(value)}\"")
    None => ()
  }
  let has_tab_color = options.tab_color_indexed is Some(_) ||
    options.tab_color_rgb is Some(_) ||
    options.tab_color_theme is Some(_) ||
    options.tab_color_tint is Some(_)
  let has_outline = options.outline_summary_below is Some(_) ||
    options.outline_summary_right is Some(_)
  let has_page_setup = options.auto_page_breaks is Some(_) ||
    options.fit_to_page is Some(_)
  if !has_tab_color && !has_outline && !has_page_setup {
    sb.write_view("/>\n")
    return sb.to_string()
  }
  sb.write_view(">\n")
  if has_tab_color {
    sb.write_view("    <tabColor")
    match options.tab_color_indexed {
      Some(value) => sb.write_view(" indexed=\"\{value}\"")
      None => ()
    }
    match options.tab_color_rgb {
      Some(value) => {
        sb.write_view(" rgb=\"")
        sb.write_view(escape_xml_attr(value))
        sb.write_view("\"")
      }
      None => ()
    }
    match options.tab_color_theme {
      Some(value) => sb.write_view(" theme=\"\{value}\"")
      None => ()
    }
    match options.tab_color_tint {
      Some(value) => sb.write_view(" tint=\"\{value}\"")
      None => ()
    }
    sb.write_view("/>\n")
  }
  if has_outline {
    sb.write_view("    <outlinePr")
    match options.outline_summary_below {
      Some(value) => sb.write_view(" summaryBelow=\"\{bool_attr(value)}\"")
      None => ()
    }
    match options.outline_summary_right {
      Some(value) => sb.write_view(" summaryRight=\"\{bool_attr(value)}\"")
      None => ()
    }
    sb.write_view("/>\n")
  }
  if has_page_setup {
    sb.write_view("    <pageSetUpPr")
    match options.auto_page_breaks {
      Some(value) => sb.write_view(" autoPageBreaks=\"\{bool_attr(value)}\"")
      None => ()
    }
    match options.fit_to_page {
      Some(value) => sb.write_view(" fitToPage=\"\{bool_attr(value)}\"")
      None => ()
    }
    sb.write_view("/>\n")
  }
  sb.write_view("  </sheetPr>\n")
  sb.to_string()
}

///|
fn write_sheet_format_pr_xml(options : SheetPropsOptions) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <sheetFormatPr")
  match options.base_col_width {
    Some(value) => sb.write_view(" baseColWidth=\"\{value}\"")
    None => ()
  }
  match options.default_col_width {
    Some(value) => sb.write_view(" defaultColWidth=\"\{value}\"")
    None => ()
  }
  match options.default_row_height {
    Some(value) => sb.write_view(" defaultRowHeight=\"\{value}\"")
    None => ()
  }
  match options.custom_height {
    Some(value) => sb.write_view(" customHeight=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.zero_height {
    Some(value) => sb.write_view(" zeroHeight=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.thick_top {
    Some(value) => sb.write_view(" thickTop=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.thick_bottom {
    Some(value) => sb.write_view(" thickBottom=\"\{bool_attr(value)}\"")
    None => ()
  }
  sb.write_view("/>\n")
  sb.to_string()
}

///|
fn write_sheet_views_xml(sheet : Worksheet) -> String? raise XlsxError {
  if sheet.sheet_views.length() == 0 {
    return None
  }
  let sb = StringBuilder::new()
  sb.write_view("  <sheetViews>\n")
  for view in sheet.sheet_views {
    sb.write_view("    <sheetView")
    match view.default_grid_color {
      Some(value) => sb.write_view(" defaultGridColor=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.right_to_left {
      Some(value) => sb.write_view(" rightToLeft=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.show_formulas {
      Some(value) => sb.write_view(" showFormulas=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.show_grid_lines {
      Some(value) => sb.write_view(" showGridLines=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.show_row_col_headers {
      Some(value) => sb.write_view(" showRowColHeaders=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.show_ruler {
      Some(value) => sb.write_view(" showRuler=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.show_zeros {
      Some(value) => sb.write_view(" showZeros=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.top_left_cell {
      Some(value) => {
        sb.write_view(" topLeftCell=\"")
        sb.write_view(escape_xml_attr(normalize_cell_ref_for_write(value)))
        sb.write_view("\"")
      }
      None => ()
    }
    match view.view {
      Some(value) => {
        sb.write_view(" view=\"")
        sb.write_view(escape_xml_attr(value))
        sb.write_view("\"")
      }
      None => ()
    }
    match view.zoom_scale {
      Some(value) => sb.write_view(" zoomScale=\"\{value}\"")
      None => ()
    }
    if view.tab_selected {
      sb.write_view(" tabSelected=\"1\"")
    }
    sb.write_view(" workbookViewId=\"\{view.workbook_view_id}\"")
    if view.pane is None && view.selection.length() == 0 {
      sb.write_view("/>\n")
      continue
    }
    sb.write_view(">\n")
    match view.pane {
      Some(pane) => {
        sb.write_view("      <pane")
        if pane.active_pane != "" {
          sb.write_view(" activePane=\"")
          sb.write_view(escape_xml_attr(pane.active_pane))
          sb.write_view("\"")
        }
        if pane.state != "" {
          sb.write_view(" state=\"")
          sb.write_view(escape_xml_attr(pane.state))
          sb.write_view("\"")
        }
        if pane.top_left_cell != "" {
          sb.write_view(" topLeftCell=\"")
          sb.write_view(
            escape_xml_attr(normalize_cell_ref_for_write(pane.top_left_cell)),
          )
          sb.write_view("\"")
        }
        if pane.x_split != 0.0 {
          sb.write_view(" xSplit=\"\{pane.x_split}\"")
        }
        if pane.y_split != 0.0 {
          sb.write_view(" ySplit=\"\{pane.y_split}\"")
        }
        sb.write_view("/>\n")
      }
      None => ()
    }
    for selection in view.selection {
      sb.write_view("      <selection")
      if selection.pane != "" {
        sb.write_view(" pane=\"")
        sb.write_view(escape_xml_attr(selection.pane))
        sb.write_view("\"")
      }
      if selection.active_cell != "" {
        sb.write_view(" activeCell=\"")
        sb.write_view(
          escape_xml_attr(normalize_cell_ref_for_write(selection.active_cell)),
        )
        sb.write_view("\"")
      }
      if selection.sqref != "" {
        sb.write_view(" sqref=\"")
        sb.write_view(
          escape_xml_attr(normalize_sqref_for_write(selection.sqref)),
        )
        sb.write_view("\"")
      }
      sb.write_view("/>\n")
    }
    sb.write_view("    </sheetView>\n")
  }
  sb.write_view("  </sheetViews>\n")
  Some(sb.to_string())
}

///|
fn write_chartsheet_xml(drawing_rel_id : Int) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<chartsheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n",
  )
  sb.write_view("  <sheetViews>\n")
  sb.write_view(
    "    <sheetView zoomScale=\"100\" zoomToFit=\"1\" workbookViewId=\"0\"/>\n",
  )
  sb.write_view("  </sheetViews>\n")
  sb.write_view("  <drawing r:id=\"rId\{drawing_rel_id}\"/>\n")
  sb.write_view("</chartsheet>")
  sb.to_string()
}

///|
fn worksheet_dimension(sheet : Worksheet) -> String? raise XlsxError {
  match sheet.dimension_ref {
    Some(value) => return Some(value)
    None => ()
  }
  let mut has_any = false
  let mut min_row = 0
  let mut min_col = 0
  let mut max_row = 0
  let mut max_col = 0
  for cell in sheet.cells() {
    let row = cell.row
    let col = cell.col
    if !has_any {
      has_any = true
      min_row = row
      max_row = row
      min_col = col
      max_col = col
    } else {
      if row < min_row {
        min_row = row
      }
      if row > max_row {
        max_row = row
      }
      if col < min_col {
        min_col = col
      }
      if col > max_col {
        max_col = col
      }
    }
  }
  for range_ref in sheet.merged_cells() {
    let (row1, col1, row2, col2) = parse_range_ref(range_ref)
    if !has_any {
      has_any = true
      min_row = row1
      max_row = row2
      min_col = col1
      max_col = col2
    } else {
      if row1 < min_row {
        min_row = row1
      }
      if row2 > max_row {
        max_row = row2
      }
      if col1 < min_col {
        min_col = col1
      }
      if col2 > max_col {
        max_col = col2
      }
    }
  }
  for table in sheet.tables() {
    let (row1, col1, row2, col2) = parse_range_ref(table.range_ref)
    if !has_any {
      has_any = true
      min_row = row1
      max_row = row2
      min_col = col1
      max_col = col2
    } else {
      if row1 < min_row {
        min_row = row1
      }
      if row2 > max_row {
        max_row = row2
      }
      if col1 < min_col {
        min_col = col1
      }
      if col2 > max_col {
        max_col = col2
      }
    }
  }
  match sheet.auto_filter() {
    Some(filter) => {
      let (row1, col1, row2, col2) = parse_range_ref(filter.range_ref)
      if !has_any {
        has_any = true
        min_row = row1
        max_row = row2
        min_col = col1
        max_col = col2
      } else {
        if row1 < min_row {
          min_row = row1
        }
        if row2 > max_row {
          max_row = row2
        }
        if col1 < min_col {
          min_col = col1
        }
        if col2 > max_col {
          max_col = col2
        }
      }
    }
    None => ()
  }
  if !has_any {
    return None
  }
  let start_ref = cell_ref_from(min_row, min_col)
  let end_ref = cell_ref_from(max_row, max_col)
  Some("\{start_ref}:\{end_ref}")
}

///|
fn write_worksheet_xml(
  sheet : Worksheet,
  string_map : Map[String, Int],
  rich_text_map : Map[String, Int],
  hyperlink_rel_ids : Map[String, Int],
  hyperlinks : ArrayView[Hyperlink],
  drawing_rel_id : Int?,
  picture_rel_id : Int?,
  table_rel_ids : ArrayView[Int],
  _pivot_rel_ids : ArrayView[Int],
  slicer_rel_ids_x14 : ArrayView[Int],
  slicer_rel_ids_x15 : ArrayView[Int],
  legacy_drawing_rel_id : Int?,
  legacy_drawing_hf_rel_id : Int?,
) -> String raise XlsxError {
  fn write_worksheet_ext_lst_xml(
    slicer_rel_ids_x14 : ArrayView[Int],
    slicer_rel_ids_x15 : ArrayView[Int],
    sparkline_groups : ArrayView[SparklineGroup],
    x14_data_bars : Map[String, X14DataBarProps],
    unknown_ext_blocks : ArrayView[String],
  ) -> String? {
    fn write_x14_conditional_formattings_ext_block_xml(
      x14_data_bars : Map[String, X14DataBarProps],
    ) -> String? {
      let by_sqref : Map[String, Array[(String, X14DataBarProps)]] = Map([])
      for id, props in x14_data_bars {
        if props.bar_direction == "" &&
          !props.bar_solid &&
          props.bar_border_color == "" {
          continue
        }
        match by_sqref.get(props.sqref) {
          Some(ids) => {
            ids.push((id, props))
            by_sqref[props.sqref] = ids
          }
          None => by_sqref[props.sqref] = [(id, props)]
        }
      }
      if by_sqref.length() == 0 {
        return None
      }
      let sb = StringBuilder::new()
      sb.write_view(
        "    <ext uri=\"{78C0D931-6437-407d-A8EE-F0AAD7539E65}\">\n",
      )
      sb.write_view(
        "      <x14:conditionalFormattings xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" xmlns:xm=\"http://schemas.microsoft.com/office/excel/2006/main\">\n",
      )
      for sqref, entries in by_sqref {
        sb.write_view("        <x14:conditionalFormatting>\n")
        for entry in entries {
          let (id, props) = entry
          sb.write_view("          <x14:cfRule type=\"dataBar\" id=\"")
          sb.write_view(escape_xml_attr(id))
          sb.write_view("\">\n")
          sb.write_view("            <x14:dataBar maxLength=\"100\"")
          if props.bar_direction != "" {
            sb.write_view(" direction=\"")
            sb.write_view(escape_xml_attr(props.bar_direction))
            sb.write_view("\"")
          }
          sb.write_view(" gradient=\"")
          sb.write_view(if props.bar_solid { "0" } else { "1" })
          sb.write_view("\"")
          if props.bar_border_color != "" {
            sb.write_view(" border=\"1\"")
          }
          sb.write_view(">\n")
          sb.write_view("              <x14:cfvo type=\"autoMin\"/>\n")
          sb.write_view("              <x14:cfvo type=\"autoMax\"/>\n")
          if props.bar_border_color != "" {
            sb.write_view("              <x14:borderColor rgb=\"")
            sb.write_view(palette_color(props.bar_border_color))
            sb.write_view("\"/>\n")
          }
          sb.write_view(
            "              <x14:negativeFillColor rgb=\"FFFF0000\"/>\n",
          )
          sb.write_view("              <x14:axisColor rgb=\"FFFF0000\"/>\n")
          sb.write_view("            </x14:dataBar>\n")
          sb.write_view("          </x14:cfRule>\n")
        }
        sb.write_view("          <xm:sqref>")
        sb.write_view(escape_xml_text(sqref))
        sb.write_view("</xm:sqref>\n")
        sb.write_view("        </x14:conditionalFormatting>\n")
      }
      sb.write_view("      </x14:conditionalFormattings>\n")
      sb.write_view("    </ext>\n")
      Some(sb.to_string())
    }

    let cond_fmt_ext = write_x14_conditional_formattings_ext_block_xml(
      x14_data_bars,
    )
    let has_conditional = cond_fmt_ext is Some(_)
    let has_slicers = slicer_rel_ids_x14.length() > 0 ||
      slicer_rel_ids_x15.length() > 0
    let has_sparklines = sparkline_groups.length() > 0
    let has_unknown = unknown_ext_blocks.length() > 0
    if !has_slicers && !has_sparklines && !has_conditional && !has_unknown {
      return None
    }
    if has_sparklines && !has_slicers && !has_conditional && !has_unknown {
      return Some(write_sparkline_ext_xml(sheet.name(), sparkline_groups))
    }
    let sb = StringBuilder::new()
    sb.write_view("  <extLst>\n")
    match cond_fmt_ext {
      Some(block) => sb.write_view(block)
      None => ()
    }
    if has_sparklines {
      sb.write_view(
        write_sparkline_ext_block_xml(sheet.name(), sparkline_groups),
      )
    }
    if slicer_rel_ids_x14.length() > 0 {
      sb.write_view(
        "    <ext uri=\"{A8765BA9-456A-4dab-B4F3-ACF838C121DE}\">\n",
      )
      sb.write_view(
        "      <x14:slicerList xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\">\n",
      )
      for rel_id in slicer_rel_ids_x14 {
        sb.write_view("        <x14:slicer r:id=\"rId\{rel_id}\"/>\n")
      }
      sb.write_view("      </x14:slicerList>\n")
      sb.write_view("    </ext>\n")
    }
    if slicer_rel_ids_x15.length() > 0 {
      sb.write_view(
        "    <ext uri=\"{3A4CF648-6AED-40f4-86FF-DC5316D8AED3}\">\n",
      )
      sb.write_view(
        "      <x14:slicerList xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\">\n",
      )
      for rel_id in slicer_rel_ids_x15 {
        sb.write_view("        <x14:slicer r:id=\"rId\{rel_id}\"/>\n")
      }
      sb.write_view("      </x14:slicerList>\n")
      sb.write_view("    </ext>\n")
    }
    if unknown_ext_blocks.length() > 0 {
      for block in unknown_ext_blocks {
        let block_text = block.to_string()
        if block_text.has_prefix("<ext") {
          sb.write_view("    ")
          sb.write_view(block_text)
        } else {
          sb.write_view(block_text)
        }
        if !block_text.has_suffix("\n") {
          sb.write_view("\n")
        }
      }
    }
    sb.write_view("  </extLst>\n")
    Some(sb.to_string())
  }

  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  let needs_rels = drawing_rel_id is Some(_) ||
    table_rel_ids.length() > 0 ||
    _pivot_rel_ids.length() > 0 ||
    slicer_rel_ids_x14.length() > 0 ||
    slicer_rel_ids_x15.length() > 0 ||
    hyperlink_rel_ids.length() > 0 ||
    legacy_drawing_rel_id is Some(_) ||
    legacy_drawing_hf_rel_id is Some(_) ||
    picture_rel_id is Some(_)
  let needs_x14_ns = sheet.sparkline_groups().length() > 0 ||
    sheet.x14_data_bars.length() > 0 ||
    slicer_rel_ids_x14.length() > 0 ||
    slicer_rel_ids_x15.length() > 0
  sb.write_view(
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"",
  )
  if needs_rels {
    sb.write_view(
      " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"",
    )
  }
  if needs_x14_ns {
    sb.write_view(
      " xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\"",
    )
    sb.write_view(
      " xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"",
    )
    sb.write_view(" mc:Ignorable=\"x14\"")
  }
  sb.write_view(">\n")
  match sheet.sheet_props {
    Some(options) =>
      if sheet_props_has_sheet_pr(options) {
        sb.write_view(write_sheet_pr_xml(options))
      }
    None => ()
  }
  match worksheet_dimension(sheet) {
    Some(value) => {
      sb.write_view("  <dimension ref=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"/>\n")
    }
    None => ()
  }
  match write_sheet_views_xml(sheet) {
    Some(value) => sb.write_view(value)
    None => ()
  }
  match sheet.sheet_props {
    Some(options) =>
      if sheet_props_has_sheet_format(options) {
        sb.write_view(write_sheet_format_pr_xml(options))
      }
    None => ()
  }
  if sheet.col_dimensions.length() > 0 {
    let cols : Array[Int] = []
    for col, _ in sheet.col_dimensions {
      cols.push(col)
    }
    cols.sort_by((a, b) => a - b)
    sb.write_view("  <cols>\n")
    for col in cols {
      let dim = sheet.col_dimensions
        .get(col)
        .unwrap_or({
          width: None,
          hidden: false,
          outline_level: 0,
          style_id: None,
        })
      write_col_attributes(sb, col, dim)
    }
    sb.write_view("  </cols>\n")
  }
  sb.write_view("  <sheetData>\n")
  let cells = sheet.sorted_cells()
  let row_cells : Map[Int, Array[Cell]] = Map([])
  for cell in cells {
    let entries = match row_cells.get(cell.row) {
      Some(value) => value
      None => []
    }
    entries.push(cell)
    row_cells[cell.row] = entries
  }
  let row_keys : Array[Int] = []
  let row_present : Map[Int, Bool] = Map([])
  for row, _ in row_cells {
    row_keys.push(row)
    row_present[row] = true
  }
  for row, _ in sheet.row_dimensions {
    if !row_present.contains(row) {
      row_keys.push(row)
    }
  }
  row_keys.sort_by((a, b) => a - b)
  for row in row_keys {
    let row_entries = match row_cells.get(row) {
      Some(value) => value
      None => []
    }
    sb.write_view("    <row r=\"\{row}\"")
    match sheet.row_dimensions.get(row) {
      Some(dim) => write_row_attributes(sb, dim)
      None => ()
    }
    if row_entries.length() == 0 {
      sb.write_view("/>\n")
      continue
    }
    sb.write_view(">\n")
    for cell in row_entries {
      sb.write_view("      <c r=\"")
      sb.write_view(escape_xml_attr(cell.reference))
      sb.write_view("\"")
      if cell.style_id != 0 {
        sb.write_view(" s=\"\{cell.style_id}\"")
      }
      match cell.formula {
        Some(formula) => {
          match cell.value_type {
            String => if cell.value != "" { sb.write_view(" t=\"str\"") }
            Bool => sb.write_view(" t=\"b\"")
            Error => sb.write_view(" t=\"e\"")
            Number => ()
          }
          sb.write_view(">")
          sb.write_view("<f")
          match cell.formula_type {
            Some(kind) => {
              sb.write_view(" t=\"")
              sb.write_view(formula_type_to_ooxml(kind))
              sb.write_view("\"")
            }
            None => ()
          }
          match cell.formula_ref {
            Some(value) => {
              sb.write_view(" ref=\"")
              sb.write_view(escape_xml_attr(value))
              sb.write_view("\"")
            }
            None => ()
          }
          match cell.formula_shared_index {
            Some(si) => sb.write_view(" si=\"\{si}\"")
            None => ()
          }
          sb.write_view(">")
          sb.write_view(escape_xml_text(formula))
          sb.write_view("</f>")
          if cell.value != "" {
            sb.write_view("<v>")
            match cell.value_type {
              String => sb.write_view(escape_xml_text(cell.value))
              Error => sb.write_view(escape_xml_text(cell.value))
              _ => sb.write_view(cell.value)
            }
            sb.write_view("</v>")
          }
          sb.write_view("</c>\n")
        }
        None =>
          match cell.value_type {
            String => {
              let idx = match cell.rich_text {
                Some(_) =>
                  match rich_text_map.get(cell.reference) {
                    Some(value) => value
                    None => raise InvalidSharedString(index=cell.row)
                  }
                None =>
                  match string_map.get(cell.value) {
                    Some(value) => value
                    None => raise InvalidSharedString(index=cell.row)
                  }
              }
              sb.write_view(" t=\"s\"><v>\{idx}</v></c>\n")
            }
            Bool => {
              sb.write_view(" t=\"b\"><v>")
              sb.write_view(cell.value)
              sb.write_view("</v></c>\n")
            }
            Error => {
              sb.write_view(" t=\"e\"><v>")
              sb.write_view(escape_xml_text(cell.value))
              sb.write_view("</v></c>\n")
            }
            Number => {
              sb.write_view("><v>")
              sb.write_view(cell.value)
              sb.write_view("</v></c>\n")
            }
          }
      }
    }
    sb.write_view("    </row>\n")
  }
  sb.write_view("  </sheetData>\n")
  match sheet.sheet_protection() {
    Some(protection) => sb.write_view(write_sheet_protection_xml(protection))
    None => ()
  }
  match sheet.auto_filter() {
    Some(filter) => sb.write_view(write_auto_filter_xml(filter))
    None => ()
  }
  if sheet.merged_cells().length() > 0 {
    sb.write_view("  <mergeCells count=\"\{sheet.merged_cells().length()}\">\n")
    for range_ref in sheet.merged_cells() {
      sb.write_view("    <mergeCell ref=\"")
      sb.write_view(escape_xml_attr(range_ref))
      sb.write_view("\"/>\n")
    }
    sb.write_view("  </mergeCells>\n")
  }
  for xml in sheet.conditional_formats() {
    sb.write_view("  ")
    sb.write_view(xml)
    sb.write_view("\n")
  }
  if sheet.data_validations().length() > 0 {
    sb.write_view(
      "  <dataValidations count=\"\{sheet.data_validations().length()}\">\n",
    )
    for xml in sheet.data_validations() {
      sb.write_view("    ")
      sb.write_view(xml)
      sb.write_view("\n")
    }
    sb.write_view("  </dataValidations>\n")
  }
  if hyperlinks.length() > 0 {
    let mut wrote = false
    for link in hyperlinks {
      if link.link_type == Unset {
        continue
      }
      if !wrote {
        sb.write_view("  <hyperlinks>\n")
        wrote = true
      }
      sb.write_view("    <hyperlink ref=\"")
      sb.write_view(escape_xml_attr(link.reference))
      sb.write_view("\"")
      if link.link_type == External {
        match hyperlink_rel_ids.get(link.reference) {
          Some(rel_id) => sb.write_view(" r:id=\"rId\{rel_id}\"")
          None => raise InvalidHyperlink(msg="hyperlink relationship missing")
        }
        match link.location {
          Some(value) => {
            sb.write_view(" location=\"")
            sb.write_view(escape_xml_attr(value))
            sb.write_view("\"")
          }
          None => ()
        }
      } else {
        sb.write_view(" location=\"")
        sb.write_view(escape_xml_attr(link.target))
        sb.write_view("\"")
      }
      match link.display {
        Some(value) => {
          sb.write_view(" display=\"")
          sb.write_view(escape_xml_attr(value))
          sb.write_view("\"")
        }
        None => ()
      }
      match link.tooltip {
        Some(value) => {
          sb.write_view(" tooltip=\"")
          sb.write_view(escape_xml_attr(value))
          sb.write_view("\"")
        }
        None => ()
      }
      sb.write_view("/>\n")
    }
    if wrote {
      sb.write_view("  </hyperlinks>\n")
    }
  }
  match sheet.page_margins {
    Some(margins) => {
      match write_print_options_xml(margins) {
        Some(xml) => sb.write_view(xml)
        None => ()
      }
      let merged = page_margins_with_defaults(Some(margins))
      sb.write_view(write_page_margins_xml(merged))
    }
    None => ()
  }
  match sheet.page_layout {
    Some(layout) => sb.write_view(write_page_setup_xml(layout))
    None => ()
  }
  match sheet.header_footer() {
    Some(options) => sb.write_view(write_header_footer_xml(options))
    None => ()
  }
  match write_page_breaks_xml("rowBreaks", sheet.row_breaks()) {
    Some(xml) => sb.write_view(xml)
    None => ()
  }
  match write_page_breaks_xml("colBreaks", sheet.col_breaks()) {
    Some(xml) => sb.write_view(xml)
    None => ()
  }
  match write_ignored_errors_xml(sheet.ignored_errors()) {
    Some(value) => sb.write_view(value)
    None => ()
  }
  match drawing_rel_id {
    Some(rel_id) => sb.write_view("  <drawing r:id=\"rId\{rel_id}\"/>\n")
    None => ()
  }
  match legacy_drawing_rel_id {
    Some(rel_id) => sb.write_view("  <legacyDrawing r:id=\"rId\{rel_id}\"/>\n")
    None => ()
  }
  match legacy_drawing_hf_rel_id {
    Some(rel_id) =>
      sb.write_view("  <legacyDrawingHF r:id=\"rId\{rel_id}\"/>\n")
    None => ()
  }
  match picture_rel_id {
    Some(rel_id) => sb.write_view("  <picture r:id=\"rId\{rel_id}\"/>\n")
    None => ()
  }
  if table_rel_ids.length() > 0 {
    sb.write_view("  <tableParts count=\"\{table_rel_ids.length()}\">\n")
    for rel_id in table_rel_ids {
      sb.write_view("    <tablePart r:id=\"rId\{rel_id}\"/>\n")
    }
    sb.write_view("  </tableParts>\n")
  }
  match
    write_worksheet_ext_lst_xml(
      slicer_rel_ids_x14,
      slicer_rel_ids_x15,
      sheet.sparkline_groups(),
      sheet.x14_data_bars,
      sheet.unknown_ext_blocks,
    ) {
    Some(xml) => sb.write_view(xml)
    None => ()
  }
  sb.write_view("</worksheet>")
  sb.to_string()
}

///|
let default_theme_xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
  #|  <a:themeElements>
  #|    <a:clrScheme name="Office">
  #|      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
  #|      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
  #|      <a:dk2><a:srgbClr val="1F497D"/></a:dk2>
  #|      <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
  #|      <a:accent1><a:srgbClr val="4F81BD"/></a:accent1>
  #|      <a:accent2><a:srgbClr val="C0504D"/></a:accent2>
  #|      <a:accent3><a:srgbClr val="9BBB59"/></a:accent3>
  #|      <a:accent4><a:srgbClr val="8064A2"/></a:accent4>
  #|      <a:accent5><a:srgbClr val="4BACC6"/></a:accent5>
  #|      <a:accent6><a:srgbClr val="F79646"/></a:accent6>
  #|      <a:hlink><a:srgbClr val="0000FF"/></a:hlink>
  #|      <a:folHlink><a:srgbClr val="800080"/></a:folHlink>
  #|    </a:clrScheme>
  #|    <a:fontScheme name="Office">
  #|      <a:majorFont>
  #|        <a:latin typeface="Calibri" panose="020F0302020204030204"/>
  #|        <a:ea typeface=""/>
  #|        <a:cs typeface=""/>
  #|      </a:majorFont>
  #|      <a:minorFont>
  #|        <a:latin typeface="Calibri" panose="020F0502020204030204"/>
  #|        <a:ea typeface=""/>
  #|        <a:cs typeface=""/>
  #|      </a:minorFont>
  #|    </a:fontScheme>
  #|    <a:fmtScheme name="Office">
  #|      <a:fillStyleLst>
  #|        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
  #|        <a:gradFill rotWithShape="1">
  #|          <a:gsLst>
  #|            <a:gs pos="0"><a:schemeClr val="phClr"><a:lumMod val="110000"/><a:satMod val="105000"/><a:tint val="67000"/></a:schemeClr></a:gs>
  #|            <a:gs pos="50000"><a:schemeClr val="phClr"><a:lumMod val="105000"/><a:satMod val="103000"/><a:tint val="73000"/></a:schemeClr></a:gs>
  #|            <a:gs pos="100000"><a:schemeClr val="phClr"><a:lumMod val="105000"/><a:satMod val="109000"/><a:tint val="81000"/></a:schemeClr></a:gs>
  #|          </a:gsLst>
  #|          <a:lin ang="5400000" scaled="0"/>
  #|        </a:gradFill>
  #|        <a:gradFill rotWithShape="1">
  #|          <a:gsLst>
  #|            <a:gs pos="0"><a:schemeClr val="phClr"><a:satMod val="103000"/><a:lumMod val="102000"/><a:tint val="94000"/></a:schemeClr></a:gs>
  #|            <a:gs pos="50000"><a:schemeClr val="phClr"><a:satMod val="110000"/><a:lumMod val="100000"/><a:shade val="100000"/></a:schemeClr></a:gs>
  #|            <a:gs pos="100000"><a:schemeClr val="phClr"><a:lumMod val="99000"/><a:satMod val="120000"/><a:shade val="78000"/></a:schemeClr></a:gs>
  #|          </a:gsLst>
  #|          <a:lin ang="5400000" scaled="0"/>
  #|        </a:gradFill>
  #|      </a:fillStyleLst>
  #|      <a:lnStyleLst>
  #|        <a:ln w="6350" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln>
  #|        <a:ln w="12700" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln>
  #|        <a:ln w="19050" cap="flat" cmpd="sng" algn="ctr"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/><a:miter lim="800000"/></a:ln>
  #|      </a:lnStyleLst>
  #|      <a:effectStyleLst>
  #|        <a:effectStyle><a:effectLst/></a:effectStyle>
  #|        <a:effectStyle><a:effectLst/></a:effectStyle>
  #|        <a:effectStyle><a:effectLst><a:outerShdw blurRad="57150" dist="19050" dir="5400000" algn="ctr" rotWithShape="0"><a:srgbClr val="000000"><a:alpha val="63000"/></a:srgbClr></a:outerShdw></a:effectLst></a:effectStyle>
  #|      </a:effectStyleLst>
  #|      <a:bgFillStyleLst>
  #|        <a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
  #|        <a:solidFill><a:schemeClr val="phClr"><a:tint val="95000"/><a:satMod val="170000"/></a:schemeClr></a:solidFill>
  #|        <a:gradFill rotWithShape="1">
  #|          <a:gsLst>
  #|            <a:gs pos="0"><a:schemeClr val="phClr"><a:tint val="93000"/><a:satMod val="150000"/><a:shade val="98000"/><a:lumMod val="102000"/></a:schemeClr></a:gs>
  #|            <a:gs pos="50000"><a:schemeClr val="phClr"><a:tint val="98000"/><a:satMod val="130000"/><a:shade val="90000"/><a:lumMod val="103000"/></a:schemeClr></a:gs>
  #|            <a:gs pos="100000"><a:schemeClr val="phClr"><a:shade val="63000"/><a:satMod val="120000"/></a:schemeClr></a:gs>
  #|          </a:gsLst>
  #|          <a:lin ang="5400000" scaled="0"/>
  #|        </a:gradFill>
  #|      </a:bgFillStyleLst>
  #|    </a:fmtScheme>
  #|  </a:themeElements>
  #|  <a:objectDefaults/>
  #|  <a:extraClrSchemeLst/>
  #|</a:theme>

///|
fn write_theme_xml(theme_colors : Array[String]?) -> String {
  match theme_colors {
    Some(colors) =>
      if colors.length() >= 10 {
        // Order matches parse_theme_colors: lt1, dk1, lt2, dk2, accent1..accent6.
        let lt1 = normalize_rgb_hex(colors[0])
          .replace_all(old="#", new="")
          .to_upper()
        let dk1 = normalize_rgb_hex(colors[1])
          .replace_all(old="#", new="")
          .to_upper()
        let lt2 = normalize_rgb_hex(colors[2])
          .replace_all(old="#", new="")
          .to_upper()
        let dk2 = normalize_rgb_hex(colors[3])
          .replace_all(old="#", new="")
          .to_upper()
        let a1 = normalize_rgb_hex(colors[4])
          .replace_all(old="#", new="")
          .to_upper()
        let a2 = normalize_rgb_hex(colors[5])
          .replace_all(old="#", new="")
          .to_upper()
        let a3 = normalize_rgb_hex(colors[6])
          .replace_all(old="#", new="")
          .to_upper()
        let a4 = normalize_rgb_hex(colors[7])
          .replace_all(old="#", new="")
          .to_upper()
        let a5 = normalize_rgb_hex(colors[8])
          .replace_all(old="#", new="")
          .to_upper()
        let a6 = normalize_rgb_hex(colors[9])
          .replace_all(old="#", new="")
          .to_upper()
        let sb = StringBuilder::new()
        sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
        sb.write_view(
          "<a:theme xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" name=\"Office Theme\">\n",
        )
        sb.write_view("  <a:themeElements>\n")
        sb.write_view("    <a:clrScheme name=\"Office\">\n")
        sb.write_view("      <a:dk1><a:srgbClr val=\"")
        sb.write_view(dk1)
        sb.write_view("\"/></a:dk1>\n")
        sb.write_view("      <a:lt1><a:srgbClr val=\"")
        sb.write_view(lt1)
        sb.write_view("\"/></a:lt1>\n")
        sb.write_view("      <a:dk2><a:srgbClr val=\"")
        sb.write_view(dk2)
        sb.write_view("\"/></a:dk2>\n")
        sb.write_view("      <a:lt2><a:srgbClr val=\"")
        sb.write_view(lt2)
        sb.write_view("\"/></a:lt2>\n")
        sb.write_view("      <a:accent1><a:srgbClr val=\"")
        sb.write_view(a1)
        sb.write_view("\"/></a:accent1>\n")
        sb.write_view("      <a:accent2><a:srgbClr val=\"")
        sb.write_view(a2)
        sb.write_view("\"/></a:accent2>\n")
        sb.write_view("      <a:accent3><a:srgbClr val=\"")
        sb.write_view(a3)
        sb.write_view("\"/></a:accent3>\n")
        sb.write_view("      <a:accent4><a:srgbClr val=\"")
        sb.write_view(a4)
        sb.write_view("\"/></a:accent4>\n")
        sb.write_view("      <a:accent5><a:srgbClr val=\"")
        sb.write_view(a5)
        sb.write_view("\"/></a:accent5>\n")
        sb.write_view("      <a:accent6><a:srgbClr val=\"")
        sb.write_view(a6)
        sb.write_view("\"/></a:accent6>\n")
        sb.write_view("      <a:hlink><a:srgbClr val=\"0000FF\"/></a:hlink>\n")
        sb.write_view(
          "      <a:folHlink><a:srgbClr val=\"800080\"/></a:folHlink>\n",
        )
        sb.write_view("    </a:clrScheme>\n")
        sb.write_view("    <a:fontScheme name=\"Office\">\n")
        sb.write_view("      <a:majorFont>\n")
        sb.write_view(
          "        <a:latin typeface=\"Calibri\" panose=\"020F0302020204030204\"/>\n",
        )
        sb.write_view("        <a:ea typeface=\"\"/>\n")
        sb.write_view("        <a:cs typeface=\"\"/>\n")
        sb.write_view("      </a:majorFont>\n")
        sb.write_view("      <a:minorFont>\n")
        sb.write_view(
          "        <a:latin typeface=\"Calibri\" panose=\"020F0502020204030204\"/>\n",
        )
        sb.write_view("        <a:ea typeface=\"\"/>\n")
        sb.write_view("        <a:cs typeface=\"\"/>\n")
        sb.write_view("      </a:minorFont>\n")
        sb.write_view("    </a:fontScheme>\n")
        sb.write_view("    <a:fmtScheme name=\"Office\">\n")
        sb.write_view("      <a:fillStyleLst>\n")
        sb.write_view(
          "        <a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>\n",
        )
        sb.write_view(
          "        <a:gradFill rotWithShape=\"1\"><a:gsLst><a:gs pos=\"0\"><a:schemeClr val=\"phClr\"><a:lumMod val=\"110000\"/><a:satMod val=\"105000\"/><a:tint val=\"67000\"/></a:schemeClr></a:gs><a:gs pos=\"50000\"><a:schemeClr val=\"phClr\"><a:lumMod val=\"105000\"/><a:satMod val=\"103000\"/><a:tint val=\"73000\"/></a:schemeClr></a:gs><a:gs pos=\"100000\"><a:schemeClr val=\"phClr\"><a:lumMod val=\"105000\"/><a:satMod val=\"109000\"/><a:tint val=\"81000\"/></a:schemeClr></a:gs></a:gsLst><a:lin ang=\"5400000\" scaled=\"0\"/></a:gradFill>\n",
        )
        sb.write_view(
          "        <a:gradFill rotWithShape=\"1\"><a:gsLst><a:gs pos=\"0\"><a:schemeClr val=\"phClr\"><a:satMod val=\"103000\"/><a:lumMod val=\"102000\"/><a:tint val=\"94000\"/></a:schemeClr></a:gs><a:gs pos=\"50000\"><a:schemeClr val=\"phClr\"><a:satMod val=\"110000\"/><a:lumMod val=\"100000\"/><a:shade val=\"100000\"/></a:schemeClr></a:gs><a:gs pos=\"100000\"><a:schemeClr val=\"phClr\"><a:lumMod val=\"99000\"/><a:satMod val=\"120000\"/><a:shade val=\"78000\"/></a:schemeClr></a:gs></a:gsLst><a:lin ang=\"5400000\" scaled=\"0\"/></a:gradFill>\n",
        )
        sb.write_view("      </a:fillStyleLst>\n")
        sb.write_view("      <a:lnStyleLst>\n")
        sb.write_view(
          "        <a:ln w=\"6350\" cap=\"flat\" cmpd=\"sng\" algn=\"ctr\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill><a:prstDash val=\"solid\"/><a:miter lim=\"800000\"/></a:ln>\n",
        )
        sb.write_view(
          "        <a:ln w=\"12700\" cap=\"flat\" cmpd=\"sng\" algn=\"ctr\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill><a:prstDash val=\"solid\"/><a:miter lim=\"800000\"/></a:ln>\n",
        )
        sb.write_view(
          "        <a:ln w=\"19050\" cap=\"flat\" cmpd=\"sng\" algn=\"ctr\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill><a:prstDash val=\"solid\"/><a:miter lim=\"800000\"/></a:ln>\n",
        )
        sb.write_view("      </a:lnStyleLst>\n")
        sb.write_view("      <a:effectStyleLst>\n")
        sb.write_view("        <a:effectStyle><a:effectLst/></a:effectStyle>\n")
        sb.write_view("        <a:effectStyle><a:effectLst/></a:effectStyle>\n")
        sb.write_view(
          "        <a:effectStyle><a:effectLst><a:outerShdw blurRad=\"57150\" dist=\"19050\" dir=\"5400000\" algn=\"ctr\" rotWithShape=\"0\"><a:srgbClr val=\"000000\"><a:alpha val=\"63000\"/></a:srgbClr></a:outerShdw></a:effectLst></a:effectStyle>\n",
        )
        sb.write_view("      </a:effectStyleLst>\n")
        sb.write_view("      <a:bgFillStyleLst>\n")
        sb.write_view(
          "        <a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>\n",
        )
        sb.write_view(
          "        <a:solidFill><a:schemeClr val=\"phClr\"><a:tint val=\"95000\"/><a:satMod val=\"170000\"/></a:schemeClr></a:solidFill>\n",
        )
        sb.write_view(
          "        <a:gradFill rotWithShape=\"1\"><a:gsLst><a:gs pos=\"0\"><a:schemeClr val=\"phClr\"><a:tint val=\"93000\"/><a:satMod val=\"150000\"/><a:shade val=\"98000\"/><a:lumMod val=\"102000\"/></a:schemeClr></a:gs><a:gs pos=\"50000\"><a:schemeClr val=\"phClr\"><a:tint val=\"98000\"/><a:satMod val=\"130000\"/><a:shade val=\"90000\"/><a:lumMod val=\"103000\"/></a:schemeClr></a:gs><a:gs pos=\"100000\"><a:schemeClr val=\"phClr\"><a:shade val=\"63000\"/><a:satMod val=\"120000\"/></a:schemeClr></a:gs></a:gsLst><a:lin ang=\"5400000\" scaled=\"0\"/></a:gradFill>\n",
        )
        sb.write_view("      </a:bgFillStyleLst>\n")
        sb.write_view("    </a:fmtScheme>\n")
        sb.write_view("  </a:themeElements>\n")
        sb.write_view("  <a:objectDefaults/>\n")
        sb.write_view("  <a:extraClrSchemeLst/>\n")
        sb.write_view("</a:theme>\n")
        sb.to_string()
      } else {
        default_theme_xml
      }
    None => default_theme_xml
  }
}

///|
fn write_with_io(
  workbook : Workbook,
  io_context : WorkbookIOContext,
) -> Bytes raise XlsxError {
  let (shared_strings, string_map, rich_text_map, total_count) = collect_shared_strings(
    workbook,
  )
  let include_shared = shared_strings.length() > 0
  let sheet_count = workbook.sheets().length()
  let formula_cells = collect_formula_cells(workbook)
  let include_calc_chain = formula_cells.length() > 0
  let rel_offset = 2 +
    (if include_shared { 1 } else { 0 }) +
    (if include_calc_chain { 1 } else { 0 })
  let chartsheet_rel_start = sheet_count + rel_offset + 1
  let manifest = @ooxml.WorkbookManifest::new(
    sheet_count,
    include_shared_strings=include_shared,
    include_calc_chain~,
  )
  let mut has_path_content_type = false
  match io_context.file_path {
    Some(path) =>
      match extension_from_path(path) {
        Some(ext) =>
          match workbook_content_type_for_extension(ext) {
            Some(content_type) => {
              manifest.set_workbook_content_type(content_type)
              has_path_content_type = true
            }
            None => ()
          }
        None => ()
      }
    None => ()
  }
  if has_path_content_type {
    manifest.add_content_default("bin", ct_vba_project)
  }
  for i, _sheet in workbook.chart_sheets() {
    let sheet_id = i + 1
    manifest.add_content_override(
      content_override_path(chartsheet_part_path(sheet_id)),
      ct_chartsheet,
    )
    manifest.add_workbook_relationship(
      rel_chartsheet,
      chartsheet_workbook_rel_target(sheet_id),
    )
  }
  match workbook.vba_project {
    Some(_) => {
      if !has_path_content_type {
        manifest.set_workbook_content_type(ct_workbook_macro)
      }
      manifest.add_content_default("bin", ct_vba_project)
      manifest.add_workbook_relationship(rel_vba_project, "vbaProject.bin")
    }
    None => ()
  }
  let archive = @zip.Archive::new()
  archive.add(
    root_rels_part_path,
    @encoding/utf8.encode(manifest.root_rels_xml()),
  )
  let tables_by_sheet : Array[Array[(Int, Table)]] = []
  let mut next_table_id = 1
  for sheet in workbook.sheets() {
    for table in sheet.tables() {
      if table.id >= next_table_id {
        next_table_id = table.id + 1
      }
    }
  }
  for sheet in workbook.sheets() {
    let sheet_tables : Array[(Int, Table)] = []
    for table in sheet.tables() {
      let table_id = if table.id > 0 {
        table.id
      } else {
        let id = next_table_id
        next_table_id = next_table_id + 1
        id
      }
      sheet_tables.push((table_id, table))
    }
    tables_by_sheet.push(sheet_tables)
  }
  let pivots_by_sheet : Array[Array[(Int, Int, PivotTable)]] = []
  let mut next_pivot_table_id = 1
  let mut next_cache_id = 1
  for sheet in workbook.sheets() {
    for pivot in sheet.pivot_tables() {
      if pivot.table_id >= next_pivot_table_id {
        next_pivot_table_id = pivot.table_id + 1
      }
      if pivot.cache_id >= next_cache_id {
        next_cache_id = pivot.cache_id + 1
      }
    }
  }
  for sheet in workbook.sheets() {
    let sheet_pivots : Array[(Int, Int, PivotTable)] = []
    for pivot in sheet.pivot_tables() {
      let table_id = if pivot.table_id > 0 {
        pivot.table_id
      } else {
        let id = next_pivot_table_id
        next_pivot_table_id = next_pivot_table_id + 1
        id
      }
      let cache_id = if pivot.cache_id > 0 {
        pivot.cache_id
      } else {
        let id = next_cache_id
        next_cache_id = next_cache_id + 1
        id
      }
      sheet_pivots.push((table_id, cache_id, pivot))
    }
    pivots_by_sheet.push(sheet_pivots)
  }
  let table_lookup : Map[String, (Int, Table)] = Map([])
  for i, sheet in workbook.sheets() {
    let sheet_key = normalize_sheet_name(sheet.name())
    for entry in tables_by_sheet[i] {
      let (table_id, table) = entry
      table_lookup["\{sheet_key}|\{table.name.to_lower()}"] = (table_id, table)
    }
  }
  let pivot_lookup : Map[String, (Int, Int, PivotTable)] = Map([])
  for i, sheet in workbook.sheets() {
    let sheet_key = normalize_sheet_name(sheet.name())
    let sheet_id = i + 1
    for entry in pivots_by_sheet[i] {
      let (_pivot_id, cache_id, pivot) = entry
      if pivot.name != "" {
        pivot_lookup["\{sheet_key}|\{pivot.name.to_lower()}"] = (
          cache_id, sheet_id, pivot,
        )
      }
    }
  }
  let pivot_cache_slicer_id_by_cache_id : Map[Int, Int] = Map([])
  let mut next_pivot_cache_slicer_id = 1
  for sheet_pivots in pivots_by_sheet {
    for entry in sheet_pivots {
      let (_pivot_id, cache_id, pivot) = entry
      match parse_pivot_cache_slicer_id(pivot.cache_definition_xml) {
        Some(id) => {
          pivot_cache_slicer_id_by_cache_id[cache_id] = id
          if id >= next_pivot_cache_slicer_id {
            next_pivot_cache_slicer_id = id + 1
          }
        }
        None => ()
      }
    }
  }
  let slicer_cache_id_by_name : Map[String, Int] = Map([])
  let slicer_cache_rel_id_by_name : Map[String, String] = Map([])
  let resolved_slicer_caches : Array[ResolvedSlicerCache] = []
  let workbook_slicer_cache_rel_ids_x14 : Array[String] = []
  let workbook_slicer_cache_rel_ids_x15 : Array[String] = []
  let mut next_slicer_cache_id = 1
  for sheet in workbook.sheets() {
    for slicer in sheet.slicers() {
      let cache_name = slicer.cache
      if slicer_cache_id_by_name.contains(cache_name) {
        continue
      }
      let cache_id = next_slicer_cache_id
      next_slicer_cache_id = next_slicer_cache_id + 1
      slicer_cache_id_by_name[cache_name] = cache_id
      let source_sheet_key = normalize_sheet_name(slicer.table_sheet)
      let source_key = "\{source_sheet_key}|\{slicer.table_name.to_lower()}"
      match table_lookup.get(source_key) {
        Some((table_id, table)) => {
          let mut column : Int? = None
          for i, col_name in table.columns {
            if col_name.to_lower() == slicer.source_name.to_lower() {
              column = Some(i + 1)
              break
            }
          }
          let col = match column {
            Some(v) => v
            None =>
              raise InvalidSheetOperation(msg="slicer table field missing")
          }
          let rel_id = manifest.add_workbook_relationship_with_id(
            rel_slicer_cache,
            slicer_cache_workbook_rel_target(cache_id),
          )
          slicer_cache_rel_id_by_name[cache_name] = rel_id
          workbook_slicer_cache_rel_ids_x15.push(rel_id)
          resolved_slicer_caches.push({
            cache_id,
            cache_name,
            source_name: slicer.source_name,
            item_desc: slicer.item_desc,
            source: Table(table_id, col),
          })
        }
        None =>
          match pivot_lookup.get(source_key) {
            Some((pivot_cache_ref_id, pivot_sheet_id, pivot)) => {
              let slicer_pivot_cache_id = match
                pivot_cache_slicer_id_by_cache_id.get(pivot_cache_ref_id) {
                Some(id) => id
                None => {
                  let id = next_pivot_cache_slicer_id
                  next_pivot_cache_slicer_id = next_pivot_cache_slicer_id + 1
                  pivot_cache_slicer_id_by_cache_id[pivot_cache_ref_id] = id
                  id
                }
              }
              let rel_id = manifest.add_workbook_relationship_with_id(
                rel_slicer_cache,
                slicer_cache_workbook_rel_target(cache_id),
              )
              slicer_cache_rel_id_by_name[cache_name] = rel_id
              workbook_slicer_cache_rel_ids_x14.push(rel_id)
              resolved_slicer_caches.push({
                cache_id,
                cache_name,
                source_name: slicer.source_name,
                item_desc: slicer.item_desc,
                source: Pivot(slicer_pivot_cache_id, pivot_sheet_id, pivot.name),
              })
            }
            None => raise InvalidSheetOperation(msg="slicer source missing")
          }
      }
    }
  }
  let workbook_pivot_cache_rel_entries : Array[(Int, String)] = []
  let pivot_cache_rel_written : Map[Int, Bool] = Map([])
  for sheet_pivots in pivots_by_sheet {
    for entry in sheet_pivots {
      let (_pivot_id, cache_id, _pivot) = entry
      if pivot_cache_rel_written.contains(cache_id) {
        continue
      }
      pivot_cache_rel_written[cache_id] = true
      let rel_id = manifest.add_workbook_relationship_with_id(
        rel_pivot_cache,
        pivot_cache_workbook_rel_target(cache_id),
      )
      workbook_pivot_cache_rel_entries.push((cache_id, rel_id))
    }
  }
  archive.add(
    workbook_part_path,
    @encoding/utf8.encode(
      write_workbook_xml(
        workbook, chartsheet_rel_start, workbook_pivot_cache_rel_entries, workbook_slicer_cache_rel_ids_x14,
        workbook_slicer_cache_rel_ids_x15,
      ),
    ),
  )
  let added_extensions : Map[String, Bool] = Map([])
  let mut image_index = 1
  let mut chart_index = 1
  let mut vml_index = 1
  let mut comment_index = 1
  let mut drawing_index = sheet_count + 1
  let mut slicer_part_index = 1
  for i, sheet in workbook.sheets() {
    let sheet_id = i + 1
    let sheet_tables = tables_by_sheet[i]
    let sheet_pivots = pivots_by_sheet[i]
    let has_drawing = sheet.images().length() > 0 ||
      sheet.charts().length() > 0 ||
      sheet.shapes().length() > 0 ||
      sheet.slicers().length() > 0
    let mut rel_id = 1
    let drawing_rel_id = if has_drawing {
      let id = rel_id
      rel_id = rel_id + 1
      Some(id)
    } else {
      None
    }
    let table_rel_ids : Array[Int] = []
    let table_targets : Array[String] = []
    for entry in sheet_tables {
      let (table_id, _table) = entry
      table_rel_ids.push(rel_id)
      table_targets.push(table_rel_target(table_id))
      rel_id = rel_id + 1
    }
    let pivot_rel_ids : Array[Int] = []
    let pivot_targets : Array[String] = []
    for entry in sheet_pivots {
      let (pivot_id, _cache_id, _pivot) = entry
      pivot_rel_ids.push(rel_id)
      pivot_targets.push(pivot_table_rel_target(pivot_id))
      rel_id = rel_id + 1
    }
    let slicer_targets : Array[String] = []
    let slicer_rel_ids_x14 : Array[Int] = []
    let slicer_rel_ids_x15 : Array[Int] = []
    let pivot_slicers : Array[Slicer] = []
    let table_slicers : Array[Slicer] = []
    for slicer in sheet.slicers() {
      let source_sheet_key = normalize_sheet_name(slicer.table_sheet)
      let source_key = "\{source_sheet_key}|\{slicer.table_name.to_lower()}"
      if table_lookup.contains(source_key) {
        table_slicers.push(slicer)
      } else {
        pivot_slicers.push(slicer)
      }
    }
    let mut pivot_slicer_part_id : Int? = None
    let mut table_slicer_part_id : Int? = None
    if pivot_slicers.length() > 0 {
      let part_id = slicer_part_index
      slicer_part_index = slicer_part_index + 1
      pivot_slicer_part_id = Some(part_id)
      slicer_rel_ids_x14.push(rel_id)
      slicer_targets.push(slicer_rel_target(part_id))
      rel_id = rel_id + 1
    }
    if table_slicers.length() > 0 {
      let part_id = slicer_part_index
      slicer_part_index = slicer_part_index + 1
      table_slicer_part_id = Some(part_id)
      slicer_rel_ids_x15.push(rel_id)
      slicer_targets.push(slicer_rel_target(part_id))
      rel_id = rel_id + 1
    }
    let hyperlink_targets : Array[String] = []
    let hyperlink_rel_ids : Map[String, Int] = Map([])
    for link in sheet.hyperlinks() {
      if link.link_type == External {
        hyperlink_targets.push(link.target)
        hyperlink_rel_ids[link.reference] = rel_id
        rel_id = rel_id + 1
      }
    }
    let comment_targets : Array[String] = []
    let comment_parts : Array[(Int, String)] = []
    let comment_xml = if sheet.comments().length() > 0 {
      Some(write_comments_xml(sheet.comments()))
    } else {
      None
    }
    let comment_vml_xml = if sheet.comments().length() > 0 {
      Some(write_comments_vml(sheet_id, sheet.comments()))
    } else {
      None
    }
    let form_control_vml_xml = if sheet.form_controls().length() > 0 {
      Some(write_form_controls_vml(sheet_id, sheet, sheet.form_controls()))
    } else {
      None
    }
    match comment_xml {
      Some(xml) => {
        let comment_id = comment_index
        comment_index = comment_index + 1
        comment_targets.push(comment_rel_target(comment_id))
        comment_parts.push((comment_id, xml))
      }
      None => ()
    }
    if comment_targets.length() > 0 {
      rel_id = rel_id + comment_targets.length()
    }
    let vml_targets : Array[String] = []
    let vml_parts : Array[(Int, String)] = []
    let vml_image_rels : Array[(Int, Array[String])] = []
    let base_vml = match sheet.vml_drawing_xml() {
      Some(xml) => Some(xml)
      None => None
    }
    let merged_vml = match base_vml {
      Some(xml) =>
        match form_control_vml_xml {
          Some(control_xml) => Some(merge_vml_drawings(xml, control_xml))
          None => Some(xml)
        }
      None => form_control_vml_xml
    }
    let legacy_drawing_xml = match merged_vml {
      Some(xml) =>
        match comment_vml_xml {
          Some(comment_xml) => Some(merge_vml_drawings(xml, comment_xml))
          None => Some(xml)
        }
      None => comment_vml_xml
    }
    let legacy_drawing_rel_id = match legacy_drawing_xml {
      Some(xml) => {
        let id = rel_id
        rel_id = rel_id + 1
        let vml_id = vml_index
        vml_index = vml_index + 1
        vml_targets.push(vml_rel_target(vml_id))
        vml_parts.push((vml_id, xml))
        Some(id)
      }
      None => None
    }
    let header_footer_images = sheet.header_footer_images
    let header_footer_vml = if header_footer_images.length() > 0 {
      Some(write_header_footer_vml(sheet_id, header_footer_images))
    } else {
      None
    }
    let header_footer_shape_ids : Array[String] = []
    if header_footer_images.length() > 0 {
      for image in header_footer_images {
        header_footer_shape_ids.push(
          header_footer_image_shape_id(
            image.position,
            image.is_footer,
            image.first_page,
          ),
        )
      }
    }
    let legacy_drawing_hf_xml = match sheet.vml_drawing_hf_xml() {
      Some(xml) =>
        match header_footer_vml {
          Some(extra_xml) => {
            let filtered = filter_vml_shapes_by_id(xml, header_footer_shape_ids)
            Some(
              merge_vml_drawings_with_shapetype(
                filtered, extra_xml, "_x0000_t75",
              ),
            )
          }
          None => Some(xml)
        }
      None => header_footer_vml
    }
    let header_footer_image_targets : Array[String] = []
    if header_footer_images.length() > 0 {
      for image in header_footer_images {
        let file_name = "image\{image_index}.\{image.extension}"
        image_index = image_index + 1
        archive.add(media_part_path(file_name), image.data)
        header_footer_image_targets.push(media_rel_target(file_name))
        if !added_extensions.contains(image.extension) {
          manifest.add_content_default(image.extension, image.content_type)
          added_extensions.set(image.extension, true)
        }
      }
    }
    let legacy_drawing_hf_rel_id = match legacy_drawing_hf_xml {
      Some(xml) => {
        let id = rel_id
        rel_id = rel_id + 1
        let vml_id = vml_index
        vml_index = vml_index + 1
        vml_targets.push(vml_rel_target(vml_id))
        vml_parts.push((vml_id, xml))
        if header_footer_image_targets.length() > 0 {
          vml_image_rels.push((vml_id, header_footer_image_targets))
        }
        Some(id)
      }
      None => None
    }
    let picture_targets : Array[String] = []
    let picture_rel_id = match sheet.sheet_background() {
      Some(background) => {
        let id = rel_id
        rel_id = rel_id + 1
        let file_name = "image\{image_index}.\{background.extension}"
        image_index = image_index + 1
        archive.add(media_part_path(file_name), background.data)
        picture_targets.push(media_rel_target(file_name))
        if !added_extensions.contains(background.extension) {
          manifest.add_content_default(
            background.extension,
            background.content_type,
          )
          added_extensions.set(background.extension, true)
        }
        Some(id)
      }
      None => None
    }
    let sheet_xml = write_worksheet_xml(
      sheet,
      string_map,
      rich_text_map,
      hyperlink_rel_ids,
      sheet.hyperlinks(),
      drawing_rel_id,
      picture_rel_id,
      table_rel_ids,
      pivot_rel_ids,
      slicer_rel_ids_x14,
      slicer_rel_ids_x15,
      legacy_drawing_rel_id,
      legacy_drawing_hf_rel_id,
    )
    archive.add(worksheet_part_path(sheet_id), @encoding/utf8.encode(sheet_xml))
    if drawing_rel_id is Some(_) ||
      table_targets.length() > 0 ||
      pivot_targets.length() > 0 ||
      slicer_targets.length() > 0 ||
      hyperlink_targets.length() > 0 ||
      comment_targets.length() > 0 ||
      vml_targets.length() > 0 ||
      picture_targets.length() > 0 {
      let drawing_target = match drawing_rel_id {
        Some(_) => Some(drawing_rel_target(sheet_id))
        None => None
      }
      let sheet_rels_xml = write_sheet_rels_xml(
        drawing_target, table_targets, pivot_targets, slicer_targets, hyperlink_targets,
        comment_targets, vml_targets, picture_targets,
      )
      archive.add(
        worksheet_rels_part_path(sheet_id),
        @encoding/utf8.encode(sheet_rels_xml),
      )
    }
    for entry in sheet_tables {
      let (table_id, table) = entry
      let table_xml = write_table_xml(table_id, table)
      archive.add(table_part_path(table_id), @encoding/utf8.encode(table_xml))
      manifest.add_content_override(
        content_override_path(table_part_path(table_id)),
        ct_table,
      )
    }
    for entry in sheet_pivots {
      let (pivot_id, cache_id, pivot) = entry
      archive.add(
        pivot_table_part_path(pivot_id),
        @encoding/utf8.encode(pivot.table_xml),
      )
      manifest.add_content_override(
        content_override_path(pivot_table_part_path(pivot_id)),
        ct_pivot_table,
      )
      let pivot_rels_xml = write_pivot_table_rels_xml(cache_id)
      archive.add(
        pivot_table_rels_part_path(pivot_id),
        @encoding/utf8.encode(pivot_rels_xml),
      )
      let cache_definition_xml = match
        pivot_cache_slicer_id_by_cache_id.get(cache_id) {
        Some(slicer_pivot_cache_id) =>
          ensure_pivot_cache_slicer_id(
            pivot.cache_definition_xml,
            slicer_pivot_cache_id,
          )
        None => pivot.cache_definition_xml
      }
      archive.add(
        pivot_cache_definition_part_path(cache_id),
        @encoding/utf8.encode(cache_definition_xml),
      )
      manifest.add_content_override(
        content_override_path(pivot_cache_definition_part_path(cache_id)),
        ct_pivot_cache_def,
      )
      match pivot.cache_records_xml {
        Some(records) => {
          archive.add(
            pivot_cache_records_part_path(cache_id),
            @encoding/utf8.encode(records),
          )
          manifest.add_content_override(
            content_override_path(pivot_cache_records_part_path(cache_id)),
            ct_pivot_cache_records,
          )
          let cache_rels_xml = write_pivot_cache_rels_xml(cache_id)
          archive.add(
            pivot_cache_definition_rels_part_path(cache_id),
            @encoding/utf8.encode(cache_rels_xml),
          )
        }
        None => ()
      }
    }
    match pivot_slicer_part_id {
      Some(part_id) => {
        let slicers_xml = write_slicers_part_xml(pivot_slicers)
        archive.add(
          slicer_part_path(part_id),
          @encoding/utf8.encode(slicers_xml),
        )
        manifest.add_content_override(
          content_override_path(slicer_part_path(part_id)),
          ct_slicer,
        )
      }
      None => ()
    }
    match table_slicer_part_id {
      Some(part_id) => {
        let slicers_xml = write_slicers_part_xml(table_slicers)
        archive.add(
          slicer_part_path(part_id),
          @encoding/utf8.encode(slicers_xml),
        )
        manifest.add_content_override(
          content_override_path(slicer_part_path(part_id)),
          ct_slicer,
        )
      }
      None => ()
    }
    for part in comment_parts {
      let (comment_id, xml) = part
      archive.add(comment_part_path(comment_id), @encoding/utf8.encode(xml))
      manifest.add_content_override(
        content_override_path(comment_part_path(comment_id)),
        ct_comments,
      )
    }
    for part in vml_parts {
      let (vml_id, xml) = part
      archive.add(vml_part_path(vml_id), @encoding/utf8.encode(xml))
      manifest.add_content_override(
        content_override_path(vml_part_path(vml_id)),
        ct_vml,
      )
    }
    for part in vml_image_rels {
      let (vml_id, targets) = part
      let vml_rels_xml = write_vml_rels_xml(targets)
      archive.add(
        vml_rels_part_path(vml_id),
        @encoding/utf8.encode(vml_rels_xml),
      )
    }
    if !has_drawing {
      continue
    }
    let image_targets : Array[(Int, String)] = []
    let chart_targets : Array[(Int, String)] = []
    let drawing_images : Array[DrawingImage] = []
    let drawing_hyperlinks : Array[DrawingHyperlink] = []
    let drawing_charts : Array[DrawingChart] = []
    let drawing_shapes : Array[Shape] = []
    let drawing_slicers : Array[DrawingSlicer] = []
    let mut rel_id = 1
    for image in sheet.images() {
      let file_name = "image\{image_index}.\{image.extension}"
      image_index = image_index + 1
      archive.add(media_part_path(file_name), image.data)
      let image_rel_id = rel_id
      rel_id = rel_id + 1
      let mut hyperlink_rel_id : Int? = None
      if image.hyperlink != "" && image.hyperlink_type != Unset {
        let link_rel_id = rel_id
        rel_id = rel_id + 1
        drawing_hyperlinks.push({
          rel_id: link_rel_id,
          target: image.hyperlink,
          link_type: image.hyperlink_type,
        })
        hyperlink_rel_id = Some(link_rel_id)
      }
      image_targets.push((image_rel_id, media_rel_target(file_name)))
      drawing_images.push({ image, rel_id: image_rel_id, hyperlink_rel_id })
      if !added_extensions.contains(image.extension) {
        manifest.add_content_default(image.extension, image.content_type)
        added_extensions.set(image.extension, true)
      }
    }
    for chart in sheet.charts() {
      let file_name = "chart\{chart_index}.xml"
      chart_index = chart_index + 1
      archive.add(chart_part_path(file_name), @encoding/utf8.encode(chart.xml))
      chart_targets.push((rel_id, chart_rel_target(file_name)))
      drawing_charts.push({
        reference: chart.reference,
        offset_x: chart.offset_x,
        offset_y: chart.offset_y,
        width_emu: chart.width_emu,
        height_emu: chart.height_emu,
        print_object: chart.print_object,
        locked: chart.locked,
        positioning: chart.positioning,
        rel_id,
      })
      rel_id = rel_id + 1
      manifest.add_content_override(
        content_override_path(chart_part_path(file_name)),
        ct_chart,
      )
    }
    manifest.add_content_override(
      content_override_path(drawing_part_path(sheet_id)),
      ct_drawing,
    )
    for shape in sheet.shapes() {
      drawing_shapes.push(shape)
    }
    for slicer in sheet.slicers() {
      let source_sheet_key = normalize_sheet_name(slicer.table_sheet)
      let source_key = "\{source_sheet_key}|\{slicer.table_name.to_lower()}"
      let is_table_slicer = table_lookup.contains(source_key)
      drawing_slicers.push({ slicer, is_table_slicer })
    }
    let drawing_xml = write_drawing_xml(
      Some(sheet),
      drawing_images,
      drawing_charts,
      drawing_shapes,
      drawing_slicers,
    )
    archive.add(drawing_part_path(sheet_id), @encoding/utf8.encode(drawing_xml))
    let drawing_rels_xml = write_drawing_rels_xml(
      image_targets, chart_targets, drawing_hyperlinks,
    )
    archive.add(
      drawing_rels_part_path(sheet_id),
      @encoding/utf8.encode(drawing_rels_xml),
    )
  }
  for entry in resolved_slicer_caches {
    let cache_id = entry.cache_id
    let cache_xml = match entry.source {
      Table(table_id, column) =>
        write_slicer_cache_xml_table(
          entry.cache_name,
          entry.source_name,
          table_id,
          column,
          entry.item_desc,
        )
      Pivot(pivot_cache_id, pivot_sheet_id, pivot_name) =>
        write_slicer_cache_xml_pivot(
          entry.cache_name,
          entry.source_name,
          pivot_sheet_id,
          pivot_name,
          pivot_cache_id,
          entry.item_desc,
        )
    }
    archive.add(
      slicer_cache_part_path(cache_id),
      @encoding/utf8.encode(cache_xml),
    )
    manifest.add_content_override(
      content_override_path(slicer_cache_part_path(cache_id)),
      ct_slicer_cache,
    )
  }
  for i, sheet in workbook.chart_sheets() {
    let sheet_id = i + 1
    let chart_name = "chart\{chart_index}.xml"
    chart_index = chart_index + 1
    archive.add(
      chart_part_path(chart_name),
      @encoding/utf8.encode(sheet.chart_xml()),
    )
    manifest.add_content_override(
      content_override_path(chart_part_path(chart_name)),
      ct_chart,
    )
    let drawing_id = drawing_index
    drawing_index = drawing_index + 1
    manifest.add_content_override(
      content_override_path(drawing_part_path(drawing_id)),
      ct_drawing,
    )
    let drawing_images : Array[DrawingImage] = []
    let drawing_charts : Array[DrawingChart] = [
      {
        reference: "A1",
        offset_x: 0,
        offset_y: 0,
        width_emu: emu_per_pixel * 480,
        height_emu: emu_per_pixel * 260,
        print_object: true,
        locked: true,
        positioning: OneCell,
        rel_id: 1,
      },
    ]
    let drawing_xml = write_drawing_xml(
      None,
      drawing_images,
      drawing_charts,
      [],
      [],
    )
    archive.add(
      drawing_part_path(drawing_id),
      @encoding/utf8.encode(drawing_xml),
    )
    let chart_targets : Array[(Int, String)] = [
      (1, chart_rel_target(chart_name)),
    ]
    let drawing_rels_xml = write_drawing_rels_xml([], chart_targets, [])
    archive.add(
      drawing_rels_part_path(drawing_id),
      @encoding/utf8.encode(drawing_rels_xml),
    )
    let chartsheet_xml = write_chartsheet_xml(1)
    archive.add(
      chartsheet_part_path(sheet_id),
      @encoding/utf8.encode(chartsheet_xml),
    )
    let chartsheet_rels_xml = write_sheet_rels_xml(
      Some(drawing_rel_target(drawing_id)),
      [],
      [],
      [],
      [],
      [],
      [],
      [],
    )
    archive.add(
      chartsheet_rels_part_path(sheet_id),
      @encoding/utf8.encode(chartsheet_rels_xml),
    )
  }
  match workbook.vba_project {
    Some(value) => archive.add(vba_project_part_path, value)
    None => ()
  }
  if include_shared {
    archive.add(
      shared_strings_part_path,
      @encoding/utf8.encode(
        write_shared_strings_xml(shared_strings, total_count),
      ),
    )
  }
  if include_calc_chain {
    archive.add(
      calc_chain_part_path,
      @encoding/utf8.encode(write_calc_chain_xml(formula_cells)),
    )
  }
  archive.add(
    styles_part_path,
    @encoding/utf8.encode(
      write_styles_xml(
        workbook.styles(),
        workbook.conditional_styles(),
        workbook.default_font(),
        workbook.default_table_style,
        workbook.default_pivot_style,
        workbook.indexed_colors,
        workbook.mru_colors_xml,
        workbook.styles_ext_lst_xml,
      ),
    ),
  )
  archive.add(
    theme_part_path,
    @encoding/utf8.encode(
      match workbook.theme_xml {
        Some(xml) => xml
        None => write_theme_xml(workbook.theme_colors)
      },
    ),
  )
  archive.add(
    core_props_part_path,
    @encoding/utf8.encode(write_core_properties_xml(workbook.core_properties())),
  )
  archive.add(
    app_props_part_path,
    @encoding/utf8.encode(write_app_properties_xml(workbook.app_properties())),
  )
  let mut has_custom_props = false
  for prop in workbook.custom_properties() {
    if prop.value is Some(_) {
      has_custom_props = true
      break
    }
  }
  if has_custom_props {
    manifest.add_custom_properties()
    archive.add(
      custom_props_part_path,
      @encoding/utf8.encode(
        write_custom_properties_xml(workbook.custom_properties()),
      ),
    )
  }
  archive.add(
    workbook_rels_part_path,
    @encoding/utf8.encode(manifest.workbook_rels_xml()),
  )
  archive.add(
    content_types_part_path,
    @encoding/utf8.encode(manifest.content_types_xml()),
  )
  match io_context.zip_writer {
    Some(writer) =>
      writer(archive) catch {
        err => raise UnsupportedFeature(msg=repr(err))
      }
    None =>
      @zip.write(archive) catch {
        err => raise UnsupportedFeature(msg=repr(err))
      }
  }
}

///|
pub fn write(workbook : Workbook) -> Bytes raise XlsxError {
  write_with_io(workbook, workbook_io_context(workbook))
}

///|
pub fn write_with_password(
  workbook : Workbook,
  password : String,
) -> Bytes raise XlsxError {
  let raw = write_with_io(workbook, workbook_io_context(workbook))
  if password.length() == 0 {
    raw
  } else {
    encrypt_package(raw, password)
  }
}

///|
fn wb_count_substr(text : StringView, needle : StringView) -> Int {
  let mut count = 0
  let mut rest = text.to_owned()
  let target = needle.to_owned()
  if target == "" {
    return 0
  }
  while true {
    match rest.find(target) {
      Some(pos) => {
        count = count + 1
        let next = pos + target.length()
        rest = rest[next:].to_owned()
      }
      None => break
    }
  }
  count
}

///|
fn wb_drawing_image_with_offset(
  positioning : PicturePositioning,
  offset_x : Int,
) -> DrawingImage {
  let image : Image = {
    reference: "B3",
    data: @encoding/utf8.encode("img"),
    extension: "png",
    content_type: "image/png",
    offset_x,
    offset_y: 0,
    scale_x: 1.0,
    scale_y: 1.0,
    width_emu: 1000,
    height_emu: 2000,
    print_object: true,
    locked: true,
    hyperlink: "",
    hyperlink_type: Unset,
    name: "",
    alt_text: "",
    lock_aspect_ratio: false,
    positioning,
  }
  { image, rel_id: 1, hyperlink_rel_id: None }
}

///|
fn wb_drawing_image(positioning : PicturePositioning) -> DrawingImage {
  wb_drawing_image_with_offset(positioning, 0)
}

///|
fn wb_drawing_chart(positioning : PicturePositioning) -> DrawingChart {
  {
    reference: "C4",
    offset_x: 0,
    offset_y: 0,
    width_emu: 3000,
    height_emu: 4000,
    print_object: true,
    locked: true,
    positioning,
    rel_id: 1,
  }
}

///|
fn wb_shape_for_anchor(
  positioning : PicturePositioning,
) -> Shape raise XlsxError {
  let font : RichTextFont = {
    bold: false,
    italic: false,
    strike: true,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: Some(11.0),
    color: None,
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  Shape::new(
    "D5",
    "rect",
    paragraph=[{ text: "shape", font: Some(font) }],
    line_width=2.0,
    positioning~,
  )
}

///|
fn wb_drawing_slicer(
  name : String,
  positioning : PicturePositioning?,
  scale_x : Double?,
  scale_y : Double?,
  is_table_slicer : Bool,
) -> DrawingSlicer {
  let format = GraphicOptions::new()
  match positioning {
    Some(value) => format.positioning = Some(value)
    None => ()
  }
  match scale_x {
    Some(value) => format.scale_x = Some(value)
    None => ()
  }
  match scale_y {
    Some(value) => format.scale_y = Some(value)
    None => ()
  }
  let slicer : Slicer = {
    name,
    cache: "Slicer_" + name,
    source_name: name,
    cell: "C3",
    table_sheet: "Sheet1",
    table_name: "Table1",
    caption: "",
    macro_name: "",
    width: 200,
    height: 200,
    display_header: None,
    item_desc: false,
    format,
  }
  { slicer, is_table_slicer }
}

///|
test "write hardening wb: write_drawing_xml uses None-sheet fallback for two-cell anchors" {
  let xml = write_drawing_xml(None, [wb_drawing_image(TwoCell)], [], [], [])
  inspect(xml.contains("<xdr:twoCellAnchor>"), content="true")
  inspect(xml.contains("<xdr:col>1</xdr:col>"), content="true")
  inspect(xml.contains("<xdr:row>2</xdr:row>"), content="true")
  inspect(xml.contains("<xdr:colOff>1000</xdr:colOff>"), content="true")
  inspect(xml.contains("<xdr:rowOff>2000</xdr:rowOff>"), content="true")
}

///|
test "write hardening wb: write_drawing_xml uses None-sheet fallback for absolute anchors" {
  let xml = write_drawing_xml(None, [wb_drawing_image(Absolute)], [], [], [])
  inspect(
    xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(xml.contains("<xdr:col>1</xdr:col>"), content="true")
  inspect(xml.contains("<xdr:row>2</xdr:row>"), content="true")
  inspect(xml.contains("<xdr:colOff>1000</xdr:colOff>"), content="true")
  inspect(xml.contains("<xdr:rowOff>2000</xdr:rowOff>"), content="true")
}

///|
test "write hardening wb: write_shared_strings rich-text color and preserve-space branches" {
  let font_indexed_tint : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: None,
    color: None,
    color_theme: None,
    color_indexed: Some(64),
    color_tint: Some(0.25),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let font_rgb_tint : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: None,
    color: Some("FF00AA00"),
    color_theme: None,
    color_indexed: None,
    color_tint: Some(0.5),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let font_tint_only : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: None,
    color: None,
    color_theme: None,
    color_indexed: None,
    color_tint: Some(0.75),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let font_theme_no_tint : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: None,
    color: None,
    color_theme: Some(5),
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let entries : Array[SharedStringEntry] = [
    { text: "I", runs: Some([{ text: "I", font: Some(font_indexed_tint) }]) },
    { text: "R", runs: Some([{ text: "R", font: Some(font_rgb_tint) }]) },
    { text: "T", runs: Some([{ text: "T", font: Some(font_tint_only) }]) },
    { text: "M", runs: Some([{ text: "M", font: Some(font_theme_no_tint) }]) },
    { text: " plain", runs: None },
  ]
  let xml = write_shared_strings_xml(entries, 5)
  inspect(xml.contains("<color indexed=\"64\" tint=\"0.25\"/>"), content="true")
  inspect(
    xml.contains("<color rgb=\"FF00AA00\" tint=\"0.5\"/>"),
    content="true",
  )
  inspect(xml.contains("<color theme=\"5\"/>"), content="true")
  inspect(wb_count_substr(xml, "<color ") >= 2, content="true")
  inspect(xml.contains("<t xml:space=\"preserve\">"), content="true")
}

///|
test "write hardening wb: write_drawing_xml covers chart none-sheet anchor branches" {
  let xml = write_drawing_xml(
    None,
    [],
    [wb_drawing_chart(TwoCell), wb_drawing_chart(Absolute)],
    [],
    [],
  )
  inspect(
    xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(wb_count_substr(xml, "<xdr:graphicFrame>"), content="2")
  inspect(wb_count_substr(xml, "</xdr:twoCellAnchor>") >= 2, content="true")
}

///|
test "write hardening wb: write_drawing_xml covers shape none-sheet and run-font branches" {
  let shape_two = wb_shape_for_anchor(TwoCell) catch {
    err => fail("shape init failed: \{repr(err)}")
  }
  let shape_abs = wb_shape_for_anchor(Absolute) catch {
    err => fail("shape init failed: \{repr(err)}")
  }
  let xml = write_drawing_xml(None, [], [], [shape_two, shape_abs], [])
  inspect(
    xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(xml.contains("<a:ln w=\"25400\"/>"), content="true")
  inspect(xml.contains("strike=\"sngStrike\""), content="true")
  inspect(wb_count_substr(xml, "<xdr:sp>"), content="2")
}

///|
test "write hardening wb: two_cell_axis_to skips zero-size cells" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_col_visible(2, false)
  sheet.set_row_visible(3, false)
  let xml = write_drawing_xml(
    Some(sheet),
    [wb_drawing_image(TwoCell)],
    [],
    [],
    [],
  )
  inspect(xml.contains("<xdr:twoCellAnchor>"), content="true")
  inspect(xml.contains("<xdr:col>2</xdr:col>"), content="true")
}

///|
test "write hardening wb: two-cell anchors enforce the worksheet boundary" {
  let chart : DrawingChart = {
    reference: "XFD1",
    offset_x: 0,
    offset_y: 0,
    width_emu: emu_per_pixel * 480,
    height_emu: emu_per_pixel * 260,
    print_object: true,
    locked: true,
    positioning: TwoCell,
    rel_id: 1,
  }
  let result : Result[String, Error] = Ok(
    write_drawing_xml(Some(Worksheet::new("Sheet1")), [], [chart], [], []),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(XlsxError::InvalidSheetOperation(msg~)) =>
      inspect(msg, content="drawing extends beyond worksheet grid")
    _ => fail("expected drawing grid boundary error")
  }
}

///|
test "write hardening wb: signed offsets and exact end markers stay readable" {
  let image = wb_drawing_image_with_offset(TwoCell, -1)
  let signed_xml = write_drawing_xml(None, [image], [], [], [])
  inspect(signed_xml.contains("<xdr:colOff>-9525</xdr:colOff>"), content="true")

  let chart : DrawingChart = {
    reference: "XFD1",
    offset_x: 0,
    offset_y: 0,
    width_emu: 64 * emu_per_pixel,
    height_emu: emu_per_pixel,
    print_object: true,
    locked: true,
    positioning: TwoCell,
    rel_id: 1,
  }
  let boundary_xml = write_drawing_xml(
    Some(Worksheet::new("Sheet1")),
    [],
    [chart],
    [],
    [],
  )
  inspect(boundary_xml.contains("<xdr:col>16384</xdr:col>"), content="true")
  inspect(boundary_xml.contains("<xdr:colOff>0</xdr:colOff>"), content="true")
}

///|
test "write hardening wb: drawing arithmetic rejects overflow" {
  let image = wb_drawing_image_with_offset(OneCell, 0x7fff_ffff)
  let offset_result : Result[String, Error] = Ok(
    write_drawing_xml(None, [image], [], [], []),
  ) catch {
    error => Err(error)
  }
  match offset_result {
    Err(XlsxError::InvalidSheetOperation(msg~)) =>
      inspect(msg, content="drawing image column offset out of range")
    _ => fail("expected drawing offset overflow")
  }

  let extent_result : Result[Int, Error] = Ok(
    drawing_scaled_extent_for_write(2147483647.0, 2.0, "drawing shape width"),
  ) catch {
    error => Err(error)
  }
  match extent_result {
    Err(XlsxError::InvalidSheetOperation(msg~)) =>
      inspect(msg, content="drawing shape width out of range")
    _ => fail("expected drawing extent overflow")
  }
}

///|
test "write hardening wb: write_drawing_xml covers chart absolute with sheet anchors" {
  let sheet = Worksheet::new("Sheet1")
  let xml = write_drawing_xml(
    Some(sheet),
    [],
    [wb_drawing_chart(Absolute)],
    [],
    [],
  )
  inspect(
    xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(wb_count_substr(xml, "<xdr:to>"), content="1")
}

///|
test "write hardening wb: write_drawing_xml covers slicer positioning and defaults" {
  let two = wb_drawing_slicer("SlicerTwo", None, Some(0.0), Some(-1.0), true)
  let abs = wb_drawing_slicer("SlicerAbs", Some(Absolute), None, None, false)
  let one = wb_drawing_slicer("SlicerOne", Some(OneCell), None, None, false)
  let xml = write_drawing_xml(None, [], [], [], [two, abs, one])
  inspect(xml.contains("Requires=\"sle15\""), content="true")
  inspect(xml.contains("Requires=\"a14\""), content="true")
  inspect(
    xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(xml.contains("<xdr:oneCellAnchor>"), content="true")
  inspect(
    xml.contains("fLocksWithSheet=\"1\" fPrintsWithSheet=\"1\""),
    content="true",
  )
}

///|
test "write hardening wb: sheet property emitters cover option branches" {
  let empty_xml = write_sheet_pr_xml(SheetPropsOptions::new())
  inspect(empty_xml.contains("<sheetPr/>"), content="true")

  let tab_indexed_xml = write_sheet_pr_xml(
    SheetPropsOptions::with_values(tab_color_indexed=4),
  )
  inspect(tab_indexed_xml.contains("<tabColor indexed=\"4\"/>"), content="true")

  let outline_right_xml = write_sheet_pr_xml(
    SheetPropsOptions::with_values(outline_summary_right=true),
  )
  inspect(
    outline_right_xml.contains("<outlinePr summaryRight=\"1\"/>"),
    content="true",
  )

  let outline_below_xml = write_sheet_pr_xml(
    SheetPropsOptions::with_values(outline_summary_below=false),
  )
  inspect(
    outline_below_xml.contains("<outlinePr summaryBelow=\"0\"/>"),
    content="true",
  )

  let page_setup_xml = write_sheet_pr_xml(
    SheetPropsOptions::with_values(auto_page_breaks=true),
  )
  inspect(
    page_setup_xml.contains("<pageSetUpPr autoPageBreaks=\"1\"/>"),
    content="true",
  )

  let format_xml = write_sheet_format_pr_xml(
    SheetPropsOptions::with_values(base_col_width=8),
  )
  inspect(
    format_xml.contains("<sheetFormatPr baseColWidth=\"8\""),
    content="true",
  )
}

///|
test "write hardening wb: sheet view writer covers bool attribute branches" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_sheet_view(
    0,
    SheetViewOptions::with_values(
      right_to_left=true,
      show_formulas=true,
      show_ruler=false,
      show_zeros=false,
    ),
  )
  let xml = match write_sheet_views_xml(sheet) {
    Some(value) => value
    None => fail("missing sheet views xml")
  }
  inspect(xml.contains("rightToLeft=\"1\""), content="true")
  inspect(xml.contains("showFormulas=\"1\""), content="true")
  inspect(xml.contains("showRuler=\"0\""), content="true")
  inspect(xml.contains("showZeros=\"0\""), content="true")
}

///|
test "write hardening wb: worksheet_dimension covers cell merge and table min/max branches" {
  let sheet = Worksheet::new("Dim")
  sheet.set_cell("D3", "x")
  sheet.set_cell("C4", "y")
  sheet.merge_cells("B2:B5")
  ignore(sheet.add_table("A1:E6", "DimTable", ["A", "B", "C", "D", "E"]))
  let dimension = worksheet_dimension(sheet) catch {
    err => fail("worksheet_dimension failed: \{repr(err)}")
  }
  debug_inspect(dimension, content="Some(\"A1:E6\")")
}

///|
test "write hardening wb: worksheet_dimension covers auto-filter expansion branches" {
  let sheet = Worksheet::new("FilterDim")
  sheet.set_cell("C3", "x")
  sheet.auto_filter = Some({ range_ref: "B2:D4", columns: [] })
  let dimension = worksheet_dimension(sheet) catch {
    err => fail("worksheet_dimension failed: \{repr(err)}")
  }
  debug_inspect(dimension, content="Some(\"B2:D4\")")
}

///|
test "write hardening wb: write_worksheet_xml covers x14 map aggregation and unknown ext fallback" {
  let sheet = Worksheet::new("Exts")
  sheet.x14_data_bars["skip"] = {
    sqref: "A1",
    bar_direction: "",
    bar_solid: false,
    bar_border_color: "",
  }
  sheet.x14_data_bars["id1"] = {
    sqref: "A1",
    bar_direction: "leftToRight",
    bar_solid: false,
    bar_border_color: "",
  }
  sheet.x14_data_bars["id2"] = {
    sqref: "A1",
    bar_direction: "",
    bar_solid: true,
    bar_border_color: "",
  }
  sheet.unknown_ext_blocks.push("<foo/>")
  let xml = write_worksheet_xml(
    sheet,
    Map([]),
    Map([]),
    Map([]),
    [],
    None,
    None,
    [],
    [],
    [],
    [],
    None,
    None,
  ) catch {
    err => fail("write_worksheet_xml failed: \{repr(err)}")
  }
  inspect(xml.contains("<extLst>"), content="true")
  inspect(xml.contains("<x14:conditionalFormatting>"), content="true")
  inspect(xml.contains("<foo/>"), content="true")
}

///|
test "write hardening wb: write_theme_xml covers custom palette and fallback branches" {
  let custom = write_theme_xml(
    Some([
      "111111", "222222", "333333", "444444", "555555", "666666", "777777", "888888",
      "999999", "AAAAAA",
    ]),
  )
  inspect(custom.contains("<a:themeElements>"), content="true")
  inspect(custom.contains("val=\"111111\""), content="true")

  let fallback = write_theme_xml(Some(["FFFFFF"]))
  inspect(fallback == default_theme_xml, content="true")
}

///|
test "write hardening wb: write_worksheet_xml covers formula bool and error branches" {
  let sheet = Worksheet::new("FormulaBranches")
  sheet.cells.push({
    reference: "A1",
    row: 1,
    col: 1,
    value: "1",
    value_type: Bool,
    rich_text: None,
    formula: Some("1=1"),
    formula_type: None,
    formula_ref: None,
    formula_shared_index: None,
    style_id: 0,
  })
  sheet.cells.push({
    reference: "A2",
    row: 2,
    col: 1,
    value: "#N/A",
    value_type: Error,
    rich_text: None,
    formula: Some("NA()"),
    formula_type: None,
    formula_ref: None,
    formula_shared_index: None,
    style_id: 0,
  })
  let xml = write_worksheet_xml(
    sheet,
    Map([]),
    Map([]),
    Map([]),
    [],
    None,
    None,
    [],
    [],
    [],
    [],
    None,
    None,
  ) catch {
    err => fail("write_worksheet_xml failed: \{repr(err)}")
  }
  inspect(xml.contains("r=\"A1\" t=\"b\""), content="true")
  inspect(xml.contains("<f>1=1</f><v>1</v>"), content="true")
  inspect(xml.contains("r=\"A2\" t=\"e\""), content="true")
  inspect(xml.contains("<f>NA()</f><v>#N/A</v>"), content="true")
}

///|
test "write hardening wb: write_worksheet_xml covers shared-string and hyperlink error branches" {
  let rich_missing = Worksheet::new("RichMissing")
  rich_missing.cells.push({
    reference: "A1",
    row: 1,
    col: 1,
    value: "ignored",
    value_type: String,
    rich_text: Some([{ text: "R", font: None }]),
    formula: None,
    formula_type: None,
    formula_ref: None,
    formula_shared_index: None,
    style_id: 0,
  })
  let missing_rich : Result[String, Error] = Ok(
    write_worksheet_xml(
      rich_missing,
      Map([]),
      Map([]),
      Map([]),
      [],
      None,
      None,
      [],
      [],
      [],
      [],
      None,
      None,
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    missing_rich is Err(XlsxError::InvalidSharedString(_)),
    content="true",
  )

  let plain_missing = Worksheet::new("PlainMissing")
  plain_missing.cells.push({
    reference: "A1",
    row: 1,
    col: 1,
    value: "plain",
    value_type: String,
    rich_text: None,
    formula: None,
    formula_type: None,
    formula_ref: None,
    formula_shared_index: None,
    style_id: 0,
  })
  let missing_plain : Result[String, Error] = Ok(
    write_worksheet_xml(
      plain_missing,
      Map([]),
      Map([]),
      Map([]),
      [],
      None,
      None,
      [],
      [],
      [],
      [],
      None,
      None,
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    missing_plain is Err(XlsxError::InvalidSharedString(_)),
    content="true",
  )

  let no_hyperlinks_xml = write_worksheet_xml(
    Worksheet::new("NoLinks"),
    Map([]),
    Map([]),
    Map([]),
    [
      {
        reference: "A1",
        target: "",
        link_type: Unset,
        location: None,
        display: None,
        tooltip: None,
      },
    ],
    None,
    None,
    [],
    [],
    [],
    [],
    None,
    None,
  ) catch {
    err => fail("write_worksheet_xml failed: \{repr(err)}")
  }
  inspect(no_hyperlinks_xml.contains("<hyperlinks>"), content="false")

  let missing_rel : Result[String, Error] = Ok(
    write_worksheet_xml(
      Worksheet::new("MissingRel"),
      Map([]),
      Map([]),
      Map([]),
      [
        {
          reference: "A1",
          target: "https://example.com",
          link_type: External,
          location: None,
          display: None,
          tooltip: None,
        },
      ],
      None,
      None,
      [],
      [],
      [],
      [],
      None,
      None,
    ),
  ) catch {
    e => Err(e)
  }
  inspect(missing_rel is Err(XlsxError::InvalidHyperlink(_)), content="true")
}

///|
test "write hardening wb: write_with_io covers file-path extension fallback branches" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))

  let no_ext = write_with_io(workbook, {
    file_path: Some("demo"),
    zip_writer: None,
    charset_transcoder: None,
  }) catch {
    err => fail("write_with_io without extension failed: \{repr(err)}")
  }
  inspect(no_ext.length() > 0, content="true")

  let unsupported_ext = write_with_io(workbook, {
    file_path: Some("demo.unsupported"),
    zip_writer: None,
    charset_transcoder: None,
  }) catch {
    err => fail("write_with_io unsupported extension failed: \{repr(err)}")
  }
  inspect(unsupported_ext.length() > 0, content="true")
}

///|
test "write hardening wb: write_with_password empty password returns raw bytes" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let raw = write(workbook) catch { err => fail("write failed: \{repr(err)}") }
  let with_empty_password = write_with_password(workbook, "") catch {
    err => fail("write_with_password failed: \{repr(err)}")
  }
  inspect(raw == with_empty_password, content="true")
}

///|
test "write hardening wb: write merges base vml with form-control and comment vml" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_vml_drawing_xml("<xml>base</xml>")
  sheet.add_form_control(FormControl::new("A1", "Button"))
  sheet.add_comment({
    cell: "B2",
    author: "A",
    author_id: None,
    text: "c",
    paragraph: [],
    width: None,
    height: None,
  })
  let bytes = write(workbook) catch {
    err => fail("write failed: \{repr(err)}")
  }
  inspect(bytes.length() > 0, content="true")
}

///|
test "write hardening wb: write fails for slicer source missing" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.slicers.push({
    name: "BadSlicer",
    cache: "Slicer_BadSlicer",
    source_name: "Field",
    cell: "A1",
    table_sheet: "Sheet1",
    table_name: "MissingTable",
    caption: "",
    macro_name: "",
    width: 200,
    height: 200,
    display_header: None,
    item_desc: false,
    format: GraphicOptions::new(),
  })
  let result : Result[Bytes, Error] = Ok(write(workbook)) catch { e => Err(e) }
  inspect(result is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}

///|
test "write hardening wb: write fails for slicer table field missing" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  ignore(sheet.add_table("A1:B2", "Table1", ["A", "B"]))
  sheet.slicers.push({
    name: "BadField",
    cache: "Slicer_BadField",
    source_name: "MissingColumn",
    cell: "A1",
    table_sheet: "Sheet1",
    table_name: "Table1",
    caption: "",
    macro_name: "",
    width: 200,
    height: 200,
    display_header: None,
    item_desc: false,
    format: GraphicOptions::new(),
  })
  let result : Result[Bytes, Error] = Ok(write(workbook)) catch { e => Err(e) }
  inspect(result is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}

///|
test "write hardening wb: write handles duplicate pivot cache relationship entries" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.pivot_tables.push({
    name: "",
    table_id: 1,
    cache_id: 1,
    table_xml: "<pivotTableDefinition/>",
    cache_definition_xml: "<pivotCacheDefinition/>",
    cache_records_xml: None,
  })
  sheet.pivot_tables.push({
    name: "",
    table_id: 2,
    cache_id: 1,
    table_xml: "<pivotTableDefinition/>",
    cache_definition_xml: "<pivotCacheDefinition/>",
    cache_records_xml: None,
  })
  let bytes = write(workbook) catch {
    err => fail("write failed: \{repr(err)}")
  }
  inspect(bytes.length() > 0, content="true")
}

///|
test "write hardening wb: failing custom zip writer maps to UnsupportedFeature" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_zip_writer(_archive => {
    raise InvalidSheetOperation(msg="zip writer failed")
  })
  let result : Result[Bytes, Error] = Ok(workbook.write_to_buffer()) catch {
    e => Err(e)
  }
  inspect(result is Err(XlsxError::UnsupportedFeature(_)), content="true")
}

///|
test "write hardening wb: default zip writer failure maps to UnsupportedFeature" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.images.push({
    reference: "A1",
    data: @encoding/utf8.encode("x"),
    extension: "a".repeat(70000),
    content_type: "image/png",
    offset_x: 0,
    offset_y: 0,
    scale_x: 1.0,
    scale_y: 1.0,
    width_emu: 1,
    height_emu: 1,
    print_object: true,
    locked: true,
    hyperlink: "",
    hyperlink_type: Unset,
    name: "",
    alt_text: "",
    lock_aspect_ratio: false,
    positioning: TwoCell,
  })
  let result : Result[Bytes, Error] = Ok(write(workbook)) catch { e => Err(e) }
  inspect(result is Err(XlsxError::UnsupportedFeature(_)), content="true")
}
