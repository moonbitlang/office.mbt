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
fn merge_sqref_row_intervals(entries : Array[(Int, Int)]) -> Array[(Int, Int)] {
  entries.sort_by((left, right) => {
    let (left_start, left_end) = left
    let (right_start, right_end) = right
    if left_start < right_start {
      -1
    } else if left_start > right_start {
      1
    } else if left_end < right_end {
      -1
    } else if left_end > right_end {
      1
    } else {
      0
    }
  })
  let merged : Array[(Int, Int)] = []
  for entry in entries {
    let (start_row, end_row) = entry
    if merged.length() == 0 {
      merged.push(entry)
      continue
    }
    let last_index = merged.length() - 1
    let (last_start, last_end) = merged[last_index]
    if start_row <= last_end + 1 {
      if end_row > last_end {
        merged[last_index] = (last_start, end_row)
      }
    } else {
      merged.push(entry)
    }
  }
  merged
}

///|
/// Parse an sqref into row intervals keyed by column. Expanding across columns
/// is bounded by Excel's 16,384-column grid; rows are never materialized one by
/// one, so full-column and full-grid references stay bounded.
fn flat_sqref(
  sqref : StringView,
) -> Map[Int, Array[(Int, Int)]] raise XlsxError {
  let intervals : Map[Int, Array[(Int, Int)]] = Map([])
  for text in xml_whitespace_tokens(sqref) {
    let (min_row, min_col, max_row, max_col) = if text.contains(":") {
      let (min_row, min_col, max_row, max_col) = parse_range_ref(text)
      (min_row, min_col, max_row, max_col)
    } else {
      let (row, col) = cell_ref_to_rc(text)
      (row, col, row, col)
    }
    for col in min_col..<=max_col {
      let entries = match intervals.get(col) {
        Some(value) => value
        None => []
      }
      entries.push((min_row, max_row))
      intervals[col] = entries
    }
  }
  for col, entries in intervals {
    intervals[col] = merge_sqref_row_intervals(entries)
  }
  intervals
}

///|
fn subtract_sqref_row_intervals(
  existing : Array[(Int, Int)],
  deletions : Array[(Int, Int)],
) -> Array[(Int, Int)] {
  let updated : Array[(Int, Int)] = []
  for source in existing {
    let (source_start, source_end) = source
    let mut cursor = source_start
    let mut exhausted = false
    for deletion in deletions {
      let (delete_start, delete_end) = deletion
      if delete_end < cursor {
        continue
      }
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
    }
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
