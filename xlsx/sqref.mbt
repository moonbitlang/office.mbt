///|
fn xml_whitespace_tokens(value : StringView) -> Array[String] {
  let tokens : Array[String] = []
  let mut current = StringBuilder::new()
  let mut has_chars = false
  for ch in value {
    if is_attr_space(ch) {
      if has_chars {
        tokens.push(current.to_string())
        current = StringBuilder::new()
        has_chars = false
      }
    } else {
      current.write_char(ch)
      has_chars = true
    }
  }
  if has_chars {
    tokens.push(current.to_string())
  }
  tokens
}

///|
fn invalid_coordinate_xml(field : StringView) -> Unit raise XlsxError {
  raise InvalidXml(msg="\{field.to_owned()} reference invalid")
}

///|
fn validate_cell_ref_for_read(
  value : StringView,
  field : StringView,
) -> String raise XlsxError {
  if try_parse_cell_ref_parts(value) is None {
    invalid_coordinate_xml(field)
  }
  value.to_owned()
}

///|
fn validate_cell_or_range_ref_for_read(
  value : StringView,
  field : StringView,
) -> String raise XlsxError {
  let mut part_count = 0
  for part in value.split(":") {
    part_count = part_count + 1
    if part_count > 2 {
      invalid_coordinate_xml(field)
    }
    ignore(validate_cell_ref_for_read(part, field))
  }
  if part_count == 0 {
    invalid_coordinate_xml(field)
  }
  value.to_owned()
}

///|
fn normalize_sqref_for_read(
  value : StringView,
  field : StringView,
) -> String raise XlsxError {
  let tokens = xml_whitespace_tokens(value)
  if tokens.length() == 0 {
    invalid_coordinate_xml(field)
  }
  for token in tokens {
    ignore(validate_cell_or_range_ref_for_read(token, field))
  }
  tokens.join(" ")
}

///|
fn normalize_xml_sqref_attr_for_read(
  xml : StringView,
  tag_name : StringView,
  field : StringView,
) -> String raise XlsxError {
  let tag = match tag_attributes_in(xml, tag_name) {
    Some(value) => value
    None => raise InvalidXml(msg="\{field.to_owned()} tag missing")
  }
  let raw = match attr_value(tag, "sqref") {
    Some(value) => unescape_xml_text(value)
    None => raise InvalidXml(msg="\{field.to_owned()} sqref missing")
  }
  let normalized = normalize_sqref_for_read(raw, field)
  if normalized == raw {
    return xml.to_owned()
  }
  match replace_attr_value_in_open_tag(xml, "sqref", normalized) {
    Some(value) => value
    None => raise InvalidXml(msg="\{field.to_owned()} sqref invalid")
  }
}

///|
fn flat_sqref(
  sqref : StringView,
) -> Map[Int, Array[(Int, Int)]] raise XlsxError {
  let cells : Map[Int, Array[(Int, Int)]] = Map([])
  for text in xml_whitespace_tokens(sqref) {
    if text.contains(":") {
      let (min_row, min_col, max_row, max_col) = parse_range_ref(text)
      for col in min_col..<=max_col {
        for row in min_row..<=max_row {
          let entries = match cells.get(col) {
            Some(value) => value
            None => []
          }
          entries.push((col, row))
          cells[col] = entries
        }
      }
    } else {
      let (row, col) = cell_ref_to_rc(text)
      let entries = match cells.get(col) {
        Some(value) => value
        None => []
      }
      entries.push((col, row))
      cells[col] = entries
    }
  }
  for col, entries in cells {
    entries.sort_by((left, right) => {
      let (_, row_left) = left
      let (_, row_right) = right
      row_left - row_right
    })
    cells[col] = entries
  }
  cells
}

///|
fn in_coordinates(cells : Array[(Int, Int)], target : (Int, Int)) -> Int {
  for i, cell in cells {
    if cell == target {
      return i
    }
  }
  -1
}

///|
fn range_ref_from_coords(
  start_cell : (Int, Int),
  end_cell : (Int, Int),
) -> String raise XlsxError {
  let (start_col, start_row) = start_cell
  let (end_col, end_row) = end_cell
  let start_ref = cell_ref_from(start_row, start_col)
  if start_col == end_col && start_row == end_row {
    return start_ref
  }
  let end_ref = cell_ref_from(end_row, end_col)
  "\{start_ref}:\{end_ref}"
}

///|
fn squash_sqref(cells : Array[(Int, Int)]) -> Array[String] raise XlsxError {
  if cells.length() == 0 {
    return []
  }
  if cells.length() == 1 {
    return [range_ref_from_coords(cells[0], cells[0])]
  }
  let refs : Array[String] = []
  let mut start = 0
  let mut end = 0
  for i in 1..<cells.length() {
    let (_, prev_row) = cells[end]
    let (_, row) = cells[i]
    if row - prev_row > 1 {
      refs.push(range_ref_from_coords(cells[start], cells[end]))
      start = i
      end = i
    } else {
      end = i
    }
  }
  refs.push(range_ref_from_coords(cells[start], cells[end]))
  refs
}

///|
fn delete_cells_from_sqref(
  sqref : StringView,
  del_cells : Map[Int, Array[(Int, Int)]],
) -> String raise XlsxError {
  let col_cells = flat_sqref(sqref)
  for col, cells in del_cells {
    match col_cells.get(col) {
      Some(existing) => {
        let updated : Array[(Int, Int)] = []
        for cell in existing {
          if in_coordinates(cells, cell) == -1 {
            updated.push(cell)
          }
        }
        col_cells[col] = updated
      }
      None => ()
    }
  }
  let refs : Array[String] = []
  let cols : Array[Int] = []
  for col, _ in col_cells {
    cols.push(col)
  }
  cols.sort_by((a, b) => a - b)
  for col in cols {
    match col_cells.get(col) {
      Some(entries) => refs.append(squash_sqref(entries))
      None => ()
    }
  }
  refs.join(" ")
}

///|
test "sqref wb: flat_sqref trims empty tokens and merges repeated single-column refs" {
  let normalized = delete_cells_from_sqref("A1\t\r\n A2", Map([]))
  inspect(normalized, content="A1:A2")
}
