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
fn insert_sqref_row_interval(
  entries : Array[(Int, Int)],
  start_row : Int,
  end_row : Int,
) -> Unit {
  let mut index = 0
  while index < entries.length() {
    let (_, existing_end) = entries[index]
    if existing_end + 1 < start_row {
      index = index + 1
    } else {
      break
    }
  }
  if index < entries.length() {
    let (existing_start, existing_end) = entries[index]
    if existing_start <= start_row && existing_end >= end_row {
      return
    }
  }
  let mut merged_start = start_row
  let mut merged_end = end_row
  while index < entries.length() {
    let (existing_start, existing_end) = entries[index]
    if existing_start > merged_end + 1 {
      break
    }
    if existing_start < merged_start {
      merged_start = existing_start
    }
    if existing_end > merged_end {
      merged_end = existing_end
    }
    ignore(entries.remove(index))
  }
  entries.insert(index, (merged_start, merged_end))
}

///|
/// Parse an sqref into row intervals keyed by column. Expanding across columns
/// is bounded by Excel's 16,384-column grid; rows are never materialized one by
/// one, so full-column and full-grid references stay bounded.
fn flat_sqref(
  sqref : StringView,
) -> Map[Int, Array[(Int, Int)]] raise XlsxError {
  let intervals : Map[Int, Array[(Int, Int)]] = Map([])
  let seen_rectangles : Map[String, Bool] = Map([])
  for text in xml_whitespace_tokens(sqref) {
    let (min_row, min_col, max_row, max_col) = if text.contains(":") {
      let (min_row, min_col, max_row, max_col) = parse_range_ref(text)
      (min_row, min_col, max_row, max_col)
    } else {
      let (row, col) = cell_ref_to_rc(text)
      (row, col, row, col)
    }
    let rectangle_key = "\{min_row}:\{min_col}:\{max_row}:\{max_col}"
    if seen_rectangles.contains(rectangle_key) {
      continue
    }
    seen_rectangles[rectangle_key] = true
    for col in min_col..<=max_col {
      let entries = match intervals.get(col) {
        Some(value) => value
        None => []
      }
      insert_sqref_row_interval(entries, min_row, max_row)
      intervals[col] = entries
    }
  }
  intervals
}

///|
fn subtract_sqref_row_intervals(
  existing : Array[(Int, Int)],
  deletions : Array[(Int, Int)],
) -> Array[(Int, Int)] {
  let updated : Array[(Int, Int)] = []
  let mut delete_index = 0
  for source in existing {
    let (source_start, source_end) = source
    while delete_index < deletions.length() {
      let (_, delete_end) = deletions[delete_index]
      if delete_end < source_start {
        delete_index = delete_index + 1
      } else {
        break
      }
    }
    let mut cursor = source_start
    let mut exhausted = false
    let mut scan = delete_index
    while scan < deletions.length() {
      let (delete_start, delete_end) = deletions[scan]
      if delete_start > source_end {
        break
      }
      if delete_start > cursor {
        updated.push((cursor, delete_start - 1))
      }
      if delete_end >= source_end {
        exhausted = true
        break
      }
      cursor = delete_end + 1
      scan = scan + 1
    }
    delete_index = scan
    if !exhausted && cursor <= source_end {
      updated.push((cursor, source_end))
    }
  }
  updated
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
fn delete_cells_from_sqref(
  sqref : StringView,
  del_intervals : Map[Int, Array[(Int, Int)]],
) -> String raise XlsxError {
  let col_intervals = flat_sqref(sqref)
  for col, deletions in del_intervals {
    match col_intervals.get(col) {
      Some(existing) =>
        col_intervals[col] = subtract_sqref_row_intervals(existing, deletions)
      None => ()
    }
  }
  let refs : Array[String] = []
  let cols : Array[Int] = []
  for col, _ in col_intervals {
    cols.push(col)
  }
  cols.sort_by((a, b) => a - b)
  for col in cols {
    match col_intervals.get(col) {
      Some(entries) =>
        for entry in entries {
          let (start_row, end_row) = entry
          refs.push(range_ref_from_coords((col, start_row), (col, end_row)))
        }
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

///|
test "sqref wb: full-column subtraction does not expand rows" {
  let deletions = flat_sqref("A1")
  let updated = delete_cells_from_sqref("A1:A1048576", deletions)
  inspect(updated, content="A2:A1048576")
}

///|
test "sqref wb: full-grid subtraction stays bounded" {
  let deletions = flat_sqref("A1:XFD1048576")
  let updated = delete_cells_from_sqref("A1:XFD1048576", deletions)
  inspect(updated, content="")
}

///|
test "sqref wb: repeated full-grid rectangles are coalesced incrementally" {
  let refs : Array[String] = []
  for _ in 0..<1000 {
    refs.push("A1:XFD1048576")
  }
  let intervals = flat_sqref(refs.join(" "))
  inspect(intervals.length(), content="16384")
  match intervals.get(1) {
    Some(entries) => debug_inspect(entries, content="[(1, 1048576)]")
    None => fail("missing first column interval")
  }
  match intervals.get(16384) {
    Some(entries) => debug_inspect(entries, content="[(1, 1048576)]")
    None => fail("missing last column interval")
  }
}
