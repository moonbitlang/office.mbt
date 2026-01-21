///|
fn decode_utf8(bytes : Bytes) -> String raise XlsxError {
  @encoding/utf8.decode(bytes) catch {
    _ => raise XlsxError::InvalidXml(msg="invalid utf8")
  }
}

///|
fn parse_workbook_sheets(
  xml : StringView,
) -> Array[(String, SheetState)] raise XlsxError {
  let sheets : Array[(String, SheetState)] = []
  let mut first = true
  for chunk in xml.to_string().split("<sheet ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="sheet tag not closed")
    }
    let tag = try! text[:end]
    let name = match attr_value(tag, "name") {
      Some(value) => unescape_xml_text(value)
      None => raise XlsxError::InvalidXml(msg="sheet name missing")
    }
    let state = match attr_value(tag, "state") {
      Some(value) =>
        match value.to_lower() {
          "hidden" => SheetState::Hidden
          "veryhidden" => SheetState::VeryHidden
          _ => SheetState::Visible
        }
      None => SheetState::Visible
    }
    sheets.push((name, state))
  }
  sheets
}

///|
fn parse_active_sheet_index(xml : StringView) -> Int? raise XlsxError {
  let xml_str = xml.to_string()
  let marker = "<workbookView"
  match xml_str.find(marker) {
    None => None
    Some(start) => {
      let rest = xml_str[start + marker.length():] catch {
          _ => raise XlsxError::InvalidXml(msg="workbookView slice invalid")
        }
      let end = match rest.find(">") {
        Some(pos) => pos
        None => raise XlsxError::InvalidXml(msg="workbookView tag not closed")
      }
      let tag = rest[:end] catch {
          _ => raise XlsxError::InvalidXml(msg="workbookView tag invalid")
        }
      match attr_value(tag, "activeTab") {
        Some(value) =>
          Some(
            @strconv.parse_int(value, base=10) catch {
              _ => raise XlsxError::InvalidXml(msg="activeTab invalid")
            },
          )
        None => None
      }
    }
  }
}

///|
fn parse_shared_strings(xml : StringView) -> Array[String] {
  let values : Array[String] = []
  let mut first = true
  for chunk in xml.to_string().split("<t") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let start = match text.find(">") {
      Some(pos) => pos + 1
      None => continue
    }
    let rest = try! text[start:]
    match rest.find("</t>") {
      Some(end) => values.push(unescape_xml_text(try! rest[:end]))
      None => ()
    }
  }
  values
}

///|
fn extract_tag_body(
  xml : StringView,
  tag_name : StringView,
) -> String? raise XlsxError {
  let xml_str = xml.to_string()
  let open_tag = "<\{tag_name.to_string()}"
  let close_tag = "</\{tag_name.to_string()}>"
  let start = match xml_str.find(open_tag) {
    Some(pos) => pos
    None => return None
  }
  let after_start = xml_str[start:] catch {
      _ => raise XlsxError::InvalidXml(msg="tag slice invalid")
    }
  let open_end_rel = match after_start.find(">") {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="tag open not closed")
  }
  let body_start = start + open_end_rel + 1
  let end = match xml_str.find(close_tag) {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="tag close missing")
  }
  let body = xml_str[body_start:end] catch {
      _ => raise XlsxError::InvalidXml(msg="tag body invalid")
    }
  Some(body.to_string())
}

///|
fn parse_num_fmts(xml : StringView) -> Map[Int, String] raise XlsxError {
  let num_fmts : Map[Int, String] = {}
  let body = match extract_tag_body(xml, "numFmts") {
    Some(value) => value
    None => return num_fmts
  }
  let mut first = true
  for chunk in body.split("<numFmt ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="numFmt tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="numFmt tag invalid")
      }
    let id_text = match attr_value(tag, "numFmtId") {
      Some(value) => value
      None => continue
    }
    let fmt_text = match attr_value(tag, "formatCode") {
      Some(value) => value
      None => continue
    }
    let id = @strconv.parse_int(id_text, base=10) catch {
      _ => raise XlsxError::InvalidXml(msg="numFmtId invalid")
    }
    num_fmts[id] = unescape_xml_text(fmt_text)
  }
  num_fmts
}

///|
fn parse_cell_xfs(
  xml : StringView,
  num_fmts : Map[Int, String],
) -> Array[Style] raise XlsxError {
  let styles : Array[Style] = []
  let body = match extract_tag_body(xml, "cellXfs") {
    Some(value) => value
    None => {
      styles.push(Style::new())
      return styles
    }
  }
  let mut first = true
  for chunk in body.split("<xf ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="xf tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="xf tag invalid")
      }
    let num_fmt_id = match attr_value(tag, "numFmtId") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="numFmtId invalid")
        }
      None => 0
    }
    let style = match num_fmts.get(num_fmt_id) {
      Some(code) => Style::number_format(code)
      None =>
        if num_fmt_id == 0 {
          Style::new()
        } else {
          Style::builtin_number_format(num_fmt_id)
        }
    }
    styles.push(style)
  }
  if styles.length() == 0 {
    styles.push(Style::new())
  }
  styles
}

///|
fn parse_styles(xml : StringView) -> Array[Style] raise XlsxError {
  let num_fmts = parse_num_fmts(xml)
  parse_cell_xfs(xml, num_fmts)
}

///|
fn parse_merge_cells(xml : StringView) -> Array[String] raise XlsxError {
  let merged : Array[String] = []
  let body = match extract_tag_body(xml, "mergeCells") {
    Some(value) => value
    None => return merged
  }
  let mut first = true
  for chunk in body.split("<mergeCell ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="mergeCell tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="mergeCell tag invalid")
      }
    let ref_value = match attr_value(tag, "ref") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="mergeCell ref missing")
    }
    let normalized = normalize_range_ref(ref_value)
    merged.push(normalized)
  }
  merged
}

///|
fn parse_table_part_ids(xml : StringView) -> Array[String] raise XlsxError {
  let ids : Array[String] = []
  let body = match extract_tag_body(xml, "tableParts") {
    Some(value) => value
    None => return ids
  }
  let mut first = true
  for chunk in body.split("<tablePart ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="tablePart tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="tablePart tag invalid")
      }
    let id = match attr_value(tag, "r:id") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="tablePart id missing")
    }
    ids.push(id)
  }
  ids
}

///|
fn parse_pivot_table_part_ids(
  xml : StringView,
) -> Array[String] raise XlsxError {
  let ids : Array[String] = []
  let body = match extract_tag_body(xml, "pivotTableParts") {
    Some(value) => value
    None => return ids
  }
  let mut first = true
  for chunk in body.split("<pivotTablePart ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None =>
            raise XlsxError::InvalidXml(msg="pivotTablePart tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="pivotTablePart tag invalid")
      }
    let id = match attr_value(tag, "r:id") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="pivotTablePart id missing")
    }
    ids.push(id)
  }
  ids
}

///|
fn parse_legacy_drawing_rel_id(
  xml : StringView,
  tag_name : StringView,
) -> String? raise XlsxError {
  let marker = "<\{tag_name.to_string()}"
  let mut first = true
  for chunk in xml.to_string().split(marker) {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None =>
            raise XlsxError::InvalidXml(
              msg="\{tag_name.to_string()} tag not closed",
            )
        }
    }
    let tag = text[:end] catch {
        _ =>
          raise XlsxError::InvalidXml(msg="\{tag_name.to_string()} tag invalid")
      }
    let id = match attr_value(tag, "r:id") {
      Some(value) => value
      None =>
        raise XlsxError::InvalidXml(msg="\{tag_name.to_string()} id missing")
    }
    return Some(id)
  }
  None
}

///|
fn parse_relationship_targets(
  xml : StringView,
  rel_type : StringView,
) -> Map[String, String] raise XlsxError {
  let targets : Map[String, String] = {}
  let mut first = true
  for chunk in xml.to_string().split("<Relationship ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find("/>") {
      Some(pos) => pos
      None =>
        match text.find(">") {
          Some(pos) => pos
          None => raise XlsxError::InvalidXml(msg="relationship tag not closed")
        }
    }
    let tag = text[:end] catch {
        _ => raise XlsxError::InvalidXml(msg="relationship tag invalid")
      }
    let rel = match attr_value(tag, "Type") {
      Some(value) => value
      None => continue
    }
    if rel != rel_type.to_string() {
      continue
    }
    let id = match attr_value(tag, "Id") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="relationship id missing")
    }
    let target = match attr_value(tag, "Target") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="relationship target missing")
    }
    targets[id] = target
  }
  targets
}

///|
fn first_relationship_target(targets : Map[String, String]) -> String? {
  for _, target in targets {
    return Some(target)
  }
  None
}

///|
fn rels_path_for(path : StringView, folder : StringView) -> String {
  let path_str = path.to_string()
  let prefix = "xl/\{folder.to_string()}/"
  if path_str.has_prefix(prefix) {
    path_str.replace_all(old=prefix, new="xl/\{folder.to_string()}/_rels/") +
    ".rels"
  } else {
    "xl/\{folder.to_string()}/_rels/" + path_str + ".rels"
  }
}

///|
fn parse_id_from_path(path : StringView, prefix : StringView) -> Int {
  let path_str = path.to_string()
  let prefix_str = prefix.to_string()
  if !path_str.has_prefix(prefix_str) || !path_str.has_suffix(".xml") {
    return 0
  }
  let start = prefix_str.length()
  let end = path_str.length() - 4
  let slice = path_str[start:end] catch { _ => return 0 }
  @strconv.parse_int(slice.to_string(), base=10) catch {
    _ => 0
  }
}

///|
fn resolve_rel_target(
  target : StringView,
  base_folder : StringView,
) -> String raise XlsxError {
  let target_str = target.to_string()
  if target_str.has_prefix("../") {
    let rest = target_str[3:] catch {
        _ => raise XlsxError::InvalidXml(msg="relationship target invalid")
      }
    "xl/" + rest.to_string()
  } else if target_str.has_prefix("xl/") {
    target_str
  } else {
    let base = base_folder.to_string()
    if base.has_suffix("/") {
      "xl/" + base + target_str
    } else {
      "xl/" + base + "/" + target_str
    }
  }
}

///|
fn parse_bool_attr(value : StringView) -> Bool {
  match value.to_string() {
    "1" => true
    "true" => true
    "TRUE" => true
    _ => false
  }
}

///|
fn parse_inline_string(rest : StringView) -> String raise XlsxError {
  let text = rest.to_string()
  let start = match text.find("<is") {
    Some(pos) => pos
    None => return ""
  }
  let after_start = text[start:] catch {
      _ => raise XlsxError::InvalidXml(msg="inline string tag invalid")
    }
  let open_end = match after_start.find(">") {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="inline string not closed")
  }
  let body_start = start + open_end + 1
  let end = match text.find("</is>") {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="inline string end missing")
  }
  let body = text[body_start:end] catch {
      _ => raise XlsxError::InvalidXml(msg="inline string body invalid")
    }
  let t_start = match body.find("<t>") {
    Some(pos) => pos
    None => return ""
  }
  let t_rest = body[t_start + 3:] catch {
      _ => raise XlsxError::InvalidXml(msg="inline string text invalid")
    }
  let t_end = match t_rest.find("</t>") {
    Some(pos) => pos
    None => raise XlsxError::InvalidXml(msg="inline string text end missing")
  }
  unescape_xml_text(try! t_rest[:t_end])
}

///|
fn parse_row_dimensions(
  xml : StringView,
  style_count : Int,
) -> Map[Int, RowDimension] raise XlsxError {
  let dims : Map[Int, RowDimension] = {}
  let mut first = true
  for chunk in xml.to_string().split("<row ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="row tag not closed")
    }
    let tag = try! text[:end]
    let row_text = match attr_value(tag, "r") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="row index missing")
    }
    let row = @strconv.parse_int(row_text, base=10) catch {
      _ => raise XlsxError::InvalidXml(msg="row index invalid")
    }
    if row <= 0 {
      raise XlsxError::InvalidXml(msg="row index invalid")
    }
    let height = match attr_value(tag, "ht") {
      Some(value) =>
        Some(
          @strconv.parse_double(value) catch {
            _ => raise XlsxError::InvalidXml(msg="row height invalid")
          },
        )
      None => None
    }
    let hidden = match attr_value(tag, "hidden") {
      Some(value) => parse_bool_attr(value)
      None => false
    }
    let outline_level = match attr_value(tag, "outlineLevel") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="row outline level invalid")
        }
      None => 0
    }
    let style_id = match attr_value(tag, "s") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="row style id invalid")
        }
      None => 0
    }
    if style_id < 0 || style_id >= style_count {
      raise XlsxError::InvalidStyleId(index=style_id)
    }
    let style = if style_id > 0 { Some(style_id) } else { None }
    if height is None && !hidden && outline_level == 0 && style is None {
      continue
    }
    dims[row] = { height, hidden, outline_level, style_id: style }
  }
  dims
}

///|
fn parse_col_dimensions(
  xml : StringView,
  style_count : Int,
) -> Map[Int, ColDimension] raise XlsxError {
  let dims : Map[Int, ColDimension] = {}
  let mut first = true
  for chunk in xml.to_string().split("<col ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="col tag not closed")
    }
    let tag = try! text[:end]
    let min_text = match attr_value(tag, "min") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="col min missing")
    }
    let max_text = match attr_value(tag, "max") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="col max missing")
    }
    let min_col = @strconv.parse_int(min_text, base=10) catch {
      _ => raise XlsxError::InvalidXml(msg="col min invalid")
    }
    let max_col = @strconv.parse_int(max_text, base=10) catch {
      _ => raise XlsxError::InvalidXml(msg="col max invalid")
    }
    if min_col <= 0 || max_col <= 0 || max_col < min_col {
      raise XlsxError::InvalidXml(msg="col range invalid")
    }
    let width = match attr_value(tag, "width") {
      Some(value) =>
        Some(
          @strconv.parse_double(value) catch {
            _ => raise XlsxError::InvalidXml(msg="col width invalid")
          },
        )
      None => None
    }
    let hidden = match attr_value(tag, "hidden") {
      Some(value) => parse_bool_attr(value)
      None => false
    }
    let outline_level = match attr_value(tag, "outlineLevel") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="col outline level invalid")
        }
      None => 0
    }
    let style_id = match attr_value(tag, "style") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="col style id invalid")
        }
      None => 0
    }
    if style_id < 0 || style_id >= style_count {
      raise XlsxError::InvalidStyleId(index=style_id)
    }
    let style = if style_id > 0 { Some(style_id) } else { None }
    if width is None && !hidden && outline_level == 0 && style is None {
      continue
    }
    let dim = { width, hidden, outline_level, style_id: style }
    let mut col = min_col
    while col <= max_col {
      dims[col] = dim
      col = col + 1
    }
  }
  dims
}

///|
fn parse_worksheet(
  xml : StringView,
  shared_strings : Array[String],
  style_count : Int,
) -> (
  Array[Cell],
  Array[String],
  Map[Int, RowDimension],
  Map[Int, ColDimension],
) raise XlsxError {
  let cells : Array[Cell] = []
  let mut first = true
  for chunk in xml.to_string().split("<c ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_string()
    let end = match text.find(">") {
      Some(pos) => pos
      None => raise XlsxError::InvalidXml(msg="cell tag not closed")
    }
    let tag = try! text[:end]
    let ref_value = match attr_value(tag, "r") {
      Some(value) => value
      None => raise XlsxError::InvalidXml(msg="cell reference missing")
    }
    let style_id = match attr_value(tag, "s") {
      Some(value) =>
        @strconv.parse_int(value, base=10) catch {
          _ => raise XlsxError::InvalidXml(msg="style id invalid")
        }
      None => 0
    }
    if style_id < 0 || style_id >= style_count {
      raise XlsxError::InvalidStyleId(index=style_id)
    }
    let cell_type = attr_value(tag, "t")
    let rest = try! text[end + 1:]
    let formula = match rest.find("<f>") {
      Some(pos) => {
        let f_rest = try! rest[pos + 3:]
        let f_end = match f_rest.find("</f>") {
          Some(end) => end
          None => raise XlsxError::InvalidXml(msg="formula not closed")
        }
        Some(unescape_xml_text(try! f_rest[:f_end]))
      }
      None => None
    }
    let raw_value_opt = match rest.find("<v>") {
      Some(pos) => {
        let v_rest = try! rest[pos + 3:]
        let v_end = match v_rest.find("</v>") {
          Some(end) => end
          None => raise XlsxError::InvalidXml(msg="cell value not closed")
        }
        Some(try! v_rest[:v_end].to_string())
      }
      None => None
    }
    let raw_value = match raw_value_opt {
      Some(value) => value
      None => ""
    }
    let inline_value = match cell_type {
      Some(kind) if kind == "inlineStr" => parse_inline_string(rest)
      _ => ""
    }
    if raw_value_opt is None &&
      formula is None &&
      !(cell_type is Some("inlineStr")) {
      raise XlsxError::InvalidXml(msg="cell value missing")
    }
    let force_string = raw_value_opt is None &&
      formula is Some(_) &&
      !(cell_type is Some("inlineStr"))
    let (value, value_type) = if force_string {
      ("", CellValueType::String)
    } else {
      match cell_type {
        Some(kind) if kind == "s" => {
          let index = @strconv.parse_int(raw_value, base=10) catch {
            _ => raise XlsxError::InvalidXml(msg="shared string index invalid")
          }
          if index < 0 || index >= shared_strings.length() {
            raise XlsxError::InvalidSharedString(index~)
          }
          (shared_strings[index], CellValueType::String)
        }
        Some(kind) if kind == "b" => {
          if raw_value != "0" && raw_value != "1" {
            raise XlsxError::InvalidXml(msg="cell boolean invalid")
          }
          (raw_value, CellValueType::Bool)
        }
        Some(kind) if kind == "e" =>
          (unescape_xml_text(raw_value), CellValueType::Error)
        Some(kind) if kind == "str" =>
          (unescape_xml_text(raw_value), CellValueType::String)
        Some(kind) if kind == "inlineStr" =>
          (inline_value, CellValueType::String)
        Some(kind) if kind == "d" =>
          (unescape_xml_text(raw_value), CellValueType::String)
        Some(kind) if kind == "n" => {
          ignore(
            @strconv.parse_double(raw_value) catch {
              _ => raise XlsxError::InvalidXml(msg="cell number invalid")
            },
          )
          (raw_value, CellValueType::Number)
        }
        Some(_) => (unescape_xml_text(raw_value), CellValueType::String)
        None => {
          ignore(
            @strconv.parse_double(raw_value) catch {
              _ => raise XlsxError::InvalidXml(msg="cell number invalid")
            },
          )
          (raw_value, CellValueType::Number)
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
      formula,
      style_id,
    })
  }
  let merged_cells = parse_merge_cells(xml)
  let row_dimensions = parse_row_dimensions(xml, style_count)
  let col_dimensions = parse_col_dimensions(xml, style_count)
  (cells, merged_cells, row_dimensions, col_dimensions)
}

///|
fn read_zip_bytes(bytes : BytesView) -> Workbook raise XlsxError {
  let archive = @zip.read(bytes) catch {
    err => raise XlsxError::UnsupportedFeature(msg=err.to_string())
  }
  let workbook_bytes = match archive.get("xl/workbook.xml") {
    Some(value) => value
    None => raise XlsxError::MissingPart(path="xl/workbook.xml")
  }
  let workbook_xml = decode_utf8(workbook_bytes)
  let sheets = parse_workbook_sheets(workbook_xml)
  let active_index = match parse_active_sheet_index(workbook_xml) {
    Some(value) => value
    None => 0
  }
  let safe_active_index = if active_index < 0 || active_index >= sheets.length() {
    0
  } else {
    active_index
  }
  let shared_strings = match archive.get("xl/sharedStrings.xml") {
    Some(value) => parse_shared_strings(decode_utf8(value))
    None => []
  }
  let styles = match archive.get("xl/styles.xml") {
    Some(value) => parse_styles(decode_utf8(value))
    None => [Style::new()]
  }
  let core_properties = match archive.get("docProps/core.xml") {
    Some(value) => parse_core_properties(decode_utf8(value))
    None => CoreProperties::new()
  }
  let app_properties = match archive.get("docProps/app.xml") {
    Some(value) => parse_app_properties(decode_utf8(value))
    None => AppProperties::new()
  }
  let style_count = styles.length()
  let workbook : Workbook = {
    sheets: [],
    styles,
    core_properties,
    app_properties,
    active_sheet_index: safe_active_index,
  }
  for i, entry in sheets {
    let (name, state) = entry
    let sheet_path = "xl/worksheets/sheet\{i + 1}.xml"
    let sheet_bytes = match archive.get(sheet_path) {
      Some(value) => value
      None => raise XlsxError::MissingPart(path=sheet_path)
    }
    let sheet_xml = decode_utf8(sheet_bytes)
    let (cells, merged_cells, row_dimensions, col_dimensions) = parse_worksheet(
      sheet_xml, shared_strings, style_count,
    )
    let table_part_ids = parse_table_part_ids(sheet_xml)
    let pivot_part_ids = parse_pivot_table_part_ids(sheet_xml)
    let legacy_drawing_rel_id = parse_legacy_drawing_rel_id(
      sheet_xml, "legacyDrawing",
    )
    let legacy_drawing_hf_rel_id = parse_legacy_drawing_rel_id(
      sheet_xml, "legacyDrawingHF",
    )
    let sparkline_groups = parse_sparkline_groups(sheet_xml)
    let needs_rels = table_part_ids.length() > 0 ||
      pivot_part_ids.length() > 0 ||
      legacy_drawing_rel_id is Some(_) ||
      legacy_drawing_hf_rel_id is Some(_)
    let rels_xml = if needs_rels {
      let rels_path = "xl/worksheets/_rels/sheet\{i + 1}.xml.rels"
      let rels_bytes = match archive.get(rels_path) {
        Some(value) => value
        None => raise XlsxError::MissingPart(path=rels_path)
      }
      decode_utf8(rels_bytes)
    } else {
      ""
    }
    let tables = if table_part_ids.length() == 0 {
      []
    } else {
      let rel_targets = parse_relationship_targets(rels_xml, rel_table)
      let parsed_tables : Array[Table] = []
      for rel_id in table_part_ids {
        let target = match rel_targets.get(rel_id) {
          Some(value) => value
          None => raise XlsxError::InvalidXml(msg="table relationship missing")
        }
        let table_path = resolve_rel_target(target, "worksheets")
        let table_bytes = match archive.get(table_path) {
          Some(value) => value
          None => raise XlsxError::MissingPart(path=table_path)
        }
        let table_xml = decode_utf8(table_bytes)
        parsed_tables.push(parse_table_xml(table_xml))
      }
      parsed_tables
    }
    let pivot_tables = if pivot_part_ids.length() == 0 {
      []
    } else {
      let rel_targets = parse_relationship_targets(rels_xml, rel_pivot_table)
      let parsed_pivots : Array[PivotTable] = []
      for rel_id in pivot_part_ids {
        let target = match rel_targets.get(rel_id) {
          Some(value) => value
          None =>
            raise XlsxError::InvalidXml(msg="pivot table relationship missing")
        }
        let pivot_path = resolve_rel_target(target, "worksheets")
        let pivot_bytes = match archive.get(pivot_path) {
          Some(value) => value
          None => raise XlsxError::MissingPart(path=pivot_path)
        }
        let pivot_xml = decode_utf8(pivot_bytes)
        let pivot_rels_path = rels_path_for(pivot_path, "pivotTables")
        let pivot_rels_bytes = match archive.get(pivot_rels_path) {
          Some(value) => value
          None => raise XlsxError::MissingPart(path=pivot_rels_path)
        }
        let pivot_rels_xml = decode_utf8(pivot_rels_bytes)
        let cache_targets = parse_relationship_targets(
          pivot_rels_xml, rel_pivot_cache,
        )
        let cache_target = match first_relationship_target(cache_targets) {
          Some(value) => value
          None =>
            raise XlsxError::InvalidXml(msg="pivot cache relationship missing")
        }
        let cache_path = resolve_rel_target(cache_target, "pivotTables")
        let cache_bytes = match archive.get(cache_path) {
          Some(value) => value
          None => raise XlsxError::MissingPart(path=cache_path)
        }
        let cache_xml = decode_utf8(cache_bytes)
        let cache_id = parse_id_from_path(
          cache_path, "xl/pivotCache/pivotCacheDefinition",
        )
        let pivot_id = parse_id_from_path(
          pivot_path, "xl/pivotTables/pivotTable",
        )
        let cache_records_xml = match
          archive.get(rels_path_for(cache_path, "pivotCache")) {
          Some(value) => {
            let cache_rels_xml = decode_utf8(value)
            let record_targets = parse_relationship_targets(
              cache_rels_xml, rel_pivot_cache_records,
            )
            match first_relationship_target(record_targets) {
              Some(record_target) => {
                let record_path = resolve_rel_target(
                  record_target, "pivotCache",
                )
                let record_bytes = match archive.get(record_path) {
                  Some(value) => value
                  None => raise XlsxError::MissingPart(path=record_path)
                }
                Some(decode_utf8(record_bytes))
              }
              None => None
            }
          }
          None => None
        }
        parsed_pivots.push({
          table_id: pivot_id,
          cache_id,
          table_xml: pivot_xml,
          cache_definition_xml: cache_xml,
          cache_records_xml,
        })
      }
      parsed_pivots
    }
    let vml_targets = if legacy_drawing_rel_id is Some(_) ||
      legacy_drawing_hf_rel_id is Some(_) {
      parse_relationship_targets(rels_xml, rel_vml)
    } else {
      {}
    }
    let vml_drawing_xml = match legacy_drawing_rel_id {
      Some(rel_id) => {
        let target = match vml_targets.get(rel_id) {
          Some(value) => value
          None =>
            raise XlsxError::InvalidXml(msg="vml drawing relationship missing")
        }
        let vml_path = resolve_rel_target(target, "worksheets")
        let vml_bytes = match archive.get(vml_path) {
          Some(value) => value
          None => raise XlsxError::MissingPart(path=vml_path)
        }
        Some(decode_utf8(vml_bytes))
      }
      None => None
    }
    let vml_drawing_hf_xml = match legacy_drawing_hf_rel_id {
      Some(rel_id) => {
        let target = match vml_targets.get(rel_id) {
          Some(value) => value
          None =>
            raise XlsxError::InvalidXml(
              msg="vml drawing hf relationship missing",
            )
        }
        let vml_path = resolve_rel_target(target, "worksheets")
        let vml_bytes = match archive.get(vml_path) {
          Some(value) => value
          None => raise XlsxError::MissingPart(path=vml_path)
        }
        Some(decode_utf8(vml_bytes))
      }
      None => None
    }
    workbook.sheets.push({
      name,
      cells,
      merged_cells,
      tables,
      sparkline_groups,
      pivot_tables,
      vml_drawing_xml,
      vml_drawing_hf_xml,
      images: [],
      charts: [],
      data_validations: [],
      conditional_formats: [],
      row_dimensions,
      col_dimensions,
      state,
      stream_state: StreamState::Idle,
    })
  }
  workbook
}

///|
pub fn read(bytes : BytesView) -> Workbook raise XlsxError {
  if is_encrypted_package(bytes) {
    raise XlsxError::EncryptedPackage
  }
  read_zip_bytes(bytes)
}

///|
pub fn read_with_password(
  bytes : BytesView,
  password : String,
) -> Workbook raise XlsxError {
  if is_encrypted_package(bytes) {
    let decrypted = decrypt_encrypted_package(bytes, password)
    let result : Result[Workbook, Error] = try? read_zip_bytes(decrypted)
    match result {
      Ok(workbook) => workbook
      Err(_) => raise XlsxError::InvalidPassword
    }
  } else {
    read_zip_bytes(bytes)
  }
}
