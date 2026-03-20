///|
fn parse_worksheet(
  xml : StringView,
  shared_strings : Array[SharedStringEntry],
  style_count : Int,
) -> (
  Array[Cell],
  Array[String],
  AutoFilter?,
  Map[Int, RowDimension],
  Map[Int, ColDimension],
  PageLayoutMarginsOptions?,
  PageLayoutOptions?,
  HeaderFooterOptions?,
  SheetProtection?,
  Array[PageBreak],
  Array[PageBreak],
  Array[SheetView],
  SheetPropsOptions?,
  String?,
  String?,
) raise XlsxError {
  let cells : Array[Cell] = []
  let mut first = true
  for chunk in xml.split("<c ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise InvalidXml(msg="cell tag not closed")
    }
    let tag = text[:end]
    let ref_value = match attr_value(tag, "r") {
      Some(value) => value
      None => raise InvalidXml(msg="cell reference missing")
    }
    let style_id = match attr_value(tag, "s") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="style id invalid")
        }
      None => 0
    }
    if style_id < 0 || style_id >= style_count {
      raise InvalidStyleId(index=style_id)
    }
    let cell_type = attr_value(tag, "t")
    let rest = text[end + 1:]
    let formula_start = match rest.find("<f>") {
      Some(pos) => Some(pos)
      None =>
        match rest.find("<f ") {
          Some(pos) => Some(pos)
          None =>
            match rest.find("<f/") {
              Some(pos) => Some(pos)
              None => None
            }
        }
    }
    let (formula, formula_type, formula_ref, formula_shared_index) = match
      formula_start {
      Some(pos) => {
        let f_rest = rest[pos:]
        let open_end = match f_rest.find(">") {
          Some(value) => value
          None => raise InvalidXml(msg="formula tag not closed")
        }
        let open_tag = f_rest[:open_end]
        let open_chars = open_tag.to_array()
        let mut last = open_chars.length() - 1
        while last >= 0 && is_attr_space(open_chars[last]) {
          last = last - 1
        }
        let is_self_closing = last >= 0 && open_chars[last] == '/'
        let kind = match attr_value(open_tag, "t") {
          Some(value) =>
            match formula_type_from_ooxml(value) {
              Some(parsed) => Some(parsed)
              None => raise InvalidXml(msg="formula type invalid")
            }
          None => None
        }
        let ref_value = match attr_value(open_tag, "ref") {
          Some(value) => Some(unescape_xml_text(value))
          None => None
        }
        let si_value = match attr_value(open_tag, "si") {
          Some(value) =>
            Some(
              @strconv.parse_int(value, base=10) catch {
                _ => raise InvalidXml(msg="formula si invalid")
              },
            )
          None => None
        }
        if is_self_closing {
          (Some(""), kind, ref_value, si_value)
        } else {
          let after_open = f_rest[open_end + 1:]
          let close_end = match after_open.find("</f>") {
            Some(value) => value
            None => raise InvalidXml(msg="formula not closed")
          }
          let content = unescape_xml_text(after_open[:close_end])
          (Some(content), kind, ref_value, si_value)
        }
      }
      None => (None, None, None, None)
    }
    let raw_value_opt = match rest.find("<v>") {
      Some(pos) => {
        let v_rest = rest[pos + 3:]
        let v_end = match v_rest.find("</v>") {
          Some(end) => end
          None => raise InvalidXml(msg="cell value not closed")
        }
        Some(v_rest[:v_end].to_string())
      }
      None => None
    }
    let raw_value = raw_value_opt.unwrap_or("")
    let inline_entry = match cell_type {
      Some("inlineStr") => Some(parse_inline_string(rest))
      _ => None
    }
    let force_string = raw_value_opt is None &&
      formula is Some(_) &&
      !(cell_type is Some("inlineStr"))
    let mut value = ""
    let mut value_type : CellValueType = String
    let mut rich_text : Array[RichTextRun]? = None
    if force_string {
      value = ""
      value_type = String
    } else {
      match cell_type {
        Some("s") => {
          let index = @strconv.parse_int(raw_value, base=10) catch {
            _ => raise InvalidXml(msg="shared string index invalid")
          }
          if index < 0 || index >= shared_strings.length() {
            raise InvalidSharedString(index~)
          }
          let entry = shared_strings[index]
          value = entry.text
          rich_text = entry.runs
          value_type = String
        }
        Some("b") => {
          if raw_value != "0" && raw_value != "1" {
            raise InvalidXml(msg="cell boolean invalid")
          }
          value = raw_value
          value_type = Bool
        }
        Some("e") => {
          value = unescape_xml_text(raw_value)
          value_type = Error
        }
        Some("str") => {
          value = unescape_xml_text(raw_value)
          value_type = String
        }
        Some("inlineStr") =>
          match inline_entry {
            Some(entry) => {
              value = entry.text
              rich_text = entry.runs
              value_type = String
            }
            None => {
              value = ""
              value_type = String
            }
          }
        Some("d") => {
          value = unescape_xml_text(raw_value)
          value_type = String
        }
        Some("n") =>
          if raw_value == "" {
            value = ""
            value_type = String
          } else {
            ignore(
              @strconv.parse_double(raw_value) catch {
                _ => raise InvalidXml(msg="cell number invalid")
              },
            )
            value = raw_value
            value_type = Number
          }
        Some(_) => {
          value = unescape_xml_text(raw_value)
          value_type = String
        }
        None =>
          if raw_value == "" {
            value = ""
            value_type = String
          } else {
            ignore(
              @strconv.parse_double(raw_value) catch {
                _ => raise InvalidXml(msg="cell number invalid")
              },
            )
            value = raw_value
            value_type = Number
          }
      }
    }
    let (row, col) = cell_ref_to_rc(ref_value)
    let canonical = cell_ref_from(row, col)
    cells.push({
      reference: canonical,
      row,
      col,
      value,
      value_type,
      rich_text,
      formula,
      formula_type,
      formula_ref,
      formula_shared_index,
      style_id,
    })
  }
  let merged_cells = parse_merge_cells(xml)
  let auto_filter = parse_auto_filter(xml)
  let row_dimensions = parse_row_dimensions(xml, style_count)
  let col_dimensions = parse_col_dimensions(xml, style_count)
  let page_margins = parse_page_margins(xml)
  let page_layout = parse_page_layout(xml)
  let header_footer = parse_header_footer(xml)
  let sheet_protection = parse_sheet_protection(xml)
  let row_breaks = parse_page_breaks(xml, "rowBreaks")
  let col_breaks = parse_page_breaks(xml, "colBreaks")
  let sheet_views = parse_sheet_views(xml)
  let sheet_props = parse_sheet_props(xml)
  let dimension_ref = parse_sheet_dimension(xml)
  let picture_rel_id = parse_picture_rel_id(xml)
  (
    cells, merged_cells, auto_filter, row_dimensions, col_dimensions, page_margins,
    page_layout, header_footer, sheet_protection, row_breaks, col_breaks, sheet_views,
    sheet_props, dimension_ref, picture_rel_id,
  )
}
