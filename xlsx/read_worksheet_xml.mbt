///|
fn worksheet_sheet_data_body(xml : StringView) -> String raise XlsxError {
  match extract_tag_body(xml, "sheetData") {
    Some(value) => value
    None => ""
  }
}

///|
/// Accounts for one lexical worksheet pass before it begins. The worksheet
/// reader intentionally composes several focused parsers; charging every pass
/// keeps that convenience inside the same cumulative work policy.
fn worksheet_parse_pass(
  source : StringView,
  budget : ReadBudget?,
) -> Unit raise XlsxError {
  match budget {
    Some(value) => {
      value.checkpoint()
      value.charge_work(source.length())
    }
    None => ()
  }
}

///|
fn parse_worksheet(
  xml : StringView,
  shared_strings : Array[SharedStringEntry],
  style_count : Int,
  budget? : ReadBudget,
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
  worksheet_parse_pass(xml, budget)
  let sheet_data = worksheet_sheet_data_body(xml)
  worksheet_parse_pass(sheet_data, budget)
  let mut first = true
  for chunk in sheet_data.split("<c") {
    match budget {
      Some(value) => value.checkpoint()
      None => ()
    }
    if first {
      first = false
      continue
    }
    if chunk.length() == 0 || !is_xml_open_tag_boundary(chunk[0]) {
      continue
    }
    let text = chunk.to_owned()
    let end = match xml_open_tag_end_from(text, 0) {
      Some(pos) => pos
      None => raise InvalidXml(msg="cell tag not closed")
    }
    let tag = text[:end]
    let ref_value = match attr_value(tag, "r") {
      Some(value) => unescape_xml_text(value)
      None => raise InvalidXml(msg="cell reference missing")
    }
    let style_id = match attr_value(tag, "s") {
      Some(value) =>
        @string.parse_int(value, base=10) catch {
          _ => raise InvalidXml(msg="style id invalid")
        }
      None => 0
    }
    if style_id < 0 || style_id >= style_count {
      raise InvalidStyleId(index=style_id)
    }
    let cell_type = attr_value(tag, "t")
    let mut tag_last = tag.length() - 1
    while tag_last >= 0 && is_xml_attr_space_unit(tag[tag_last]) {
      tag_last = tag_last - 1
    }
    let self_closing = tag_last >= 0 && tag[tag_last] == '/'
    let after_open = text[end + 1:]
    let cell_body = if self_closing {
      after_open[:0]
    } else {
      match find_xml_close_tag_from(after_open, "c", 0) {
        Some((pos, _)) => after_open[:pos]
        None => raise InvalidXml(msg="cell not closed")
      }
    }
    let formula_start = find_xml_open_tag_start(cell_body, "f")
    let (formula, formula_type, formula_ref, formula_shared_index) = match
      formula_start {
      Some(pos) => {
        let f_rest = cell_body[pos:]
        let open_end = match xml_open_tag_end_from(f_rest, 0) {
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
          Some(value) =>
            Some(
              validate_cell_or_range_ref_for_read(
                unescape_xml_text(value),
                "formula",
              ),
            )
          None => None
        }
        let si_value = match attr_value(open_tag, "si") {
          Some(value) =>
            Some(
              @string.parse_uint(value, base=10) catch {
                _ => raise InvalidXml(msg="formula si invalid")
              },
            )
          None => None
        }
        if is_self_closing {
          (Some(""), kind, ref_value, si_value)
        } else {
          let after_open = f_rest[open_end + 1:]
          let close_end = match find_xml_close_tag_from(after_open, "f", 0) {
            Some((value, _)) => value
            None => raise InvalidXml(msg="formula not closed")
          }
          let content = unescape_xml_text(after_open[:close_end])
          (Some(content), kind, ref_value, si_value)
        }
      }
      None => (None, None, None, None)
    }
    // ECMA-376 defines the expression on non-master shared formulas as
    // ignored. Canonicalize followers immediately so downstream consumers do
    // not accidentally evaluate producer-specific garbage from that node.
    let formula = match (formula_type, formula_ref, formula) {
      (Some(Shared), None, Some(_)) => Some("")
      _ => formula
    }
    let raw_value_opt = match find_xml_open_tag_start(cell_body, "v") {
      Some(pos) => {
        let v_rest = cell_body[pos:]
        let open_end = match xml_open_tag_end_from(v_rest, 0) {
          Some(end) => end
          None => raise InvalidXml(msg="cell value tag not closed")
        }
        let open_tag = v_rest[:open_end].to_owned()
        if open_tag.trim().has_suffix("/") {
          Some("")
        } else {
          let value_rest = v_rest[open_end + 1:]
          let v_end = match find_xml_close_tag_from(value_rest, "v", 0) {
            Some((end, _)) => end
            None => raise InvalidXml(msg="cell value not closed")
          }
          Some(value_rest[:v_end].to_owned())
        }
      }
      None => None
    }
    let raw_value = raw_value_opt.unwrap_or("")
    let inline_entry = match cell_type {
      Some("inlineStr") => Some(parse_inline_string(cell_body))
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
          let index = @string.parse_int(raw_value, base=10) catch {
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
        // A missing `t` attribute defaults to a numeric cell, same as t="n".
        Some("n") | None =>
          if raw_value == "" {
            value = ""
            value_type = String
          } else {
            let number = @string.parse_double(raw_value) catch {
              _ => raise InvalidXml(msg="cell number invalid")
            }
            if number.is_nan() || number.is_inf() {
              raise InvalidXml(msg="cell number must be finite")
            }
            value = raw_value
            value_type = Number
          }
        Some(_) => {
          value = unescape_xml_text(raw_value)
          value_type = String
        }
      }
    }
    let valid_ref = validate_cell_ref_for_read(ref_value, "cell")
    let (row, col) = cell_ref_to_rc(valid_ref)
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
      formula_value_present: formula is Some(_) && raw_value_opt is Some(_),
      style_id,
    })
  }
  // Shared formulas are a worksheet-wide construct: followers carry only an
  // index, so validate the complete group before exposing a partial model.
  match budget {
    Some(value) => {
      value.checkpoint()
      value.charge_work(cells.length())
    }
    None => ()
  }
  ignore(validated_shared_formula_masters(cells))
  worksheet_parse_pass(xml, budget)
  let merged_cells = parse_merge_cells(xml)
  worksheet_parse_pass(xml, budget)
  let auto_filter = parse_auto_filter(xml)
  worksheet_parse_pass(sheet_data, budget)
  let row_dimensions = parse_row_dimensions(sheet_data, style_count)
  worksheet_parse_pass(xml, budget)
  let col_dimensions = parse_col_dimensions(xml, style_count)
  worksheet_parse_pass(xml, budget)
  let page_margins = parse_page_margins(xml)
  worksheet_parse_pass(xml, budget)
  let page_layout = parse_page_layout(xml)
  worksheet_parse_pass(xml, budget)
  let header_footer = parse_header_footer(xml)
  worksheet_parse_pass(xml, budget)
  let sheet_protection = parse_sheet_protection(xml)
  worksheet_parse_pass(xml, budget)
  let row_breaks = parse_page_breaks(xml, "rowBreaks")
  worksheet_parse_pass(xml, budget)
  let col_breaks = parse_page_breaks(xml, "colBreaks")
  worksheet_parse_pass(xml, budget)
  let sheet_views = parse_sheet_views(xml, budget?)
  worksheet_parse_pass(xml, budget)
  let sheet_props = parse_sheet_props(xml)
  worksheet_parse_pass(xml, budget)
  let dimension_ref = parse_sheet_dimension(xml)
  worksheet_parse_pass(xml, budget)
  let picture_rel_id = parse_picture_rel_id(xml)
  (
    cells, merged_cells, auto_filter, row_dimensions, col_dimensions, page_margins,
    page_layout, header_footer, sheet_protection, row_breaks, col_breaks, sheet_views,
    sheet_props, dimension_ref, picture_rel_id,
  )
}
