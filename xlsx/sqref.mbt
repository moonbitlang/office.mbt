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
  budget? : ReadBudget,
) -> String raise XlsxError {
  let normalized = StringBuilder::new()
  let mut token_start = -1
  let mut token_count = 0
  for index in 0..<=value.length() {
    let at_end = index == value.length()
    let separator = at_end || is_xml_attr_space_unit(value[index])
    if !separator && token_start < 0 {
      token_start = index
    } else if separator && token_start >= 0 {
      let token = value[token_start:index]
      match budget {
        Some(value) => {
          value.checkpoint()
          value.charge_items(1)
          value.charge_work(token.length())
        }
        None => ()
      }
      ignore(validate_cell_or_range_ref_for_read(token, field))
      if token_count > 0 {
        normalized.write_char(' ')
      }
      normalized.write_view(token)
      token_count = token_count + 1
      token_start = -1
    }
  }
  if token_count == 0 {
    invalid_coordinate_xml(field)
  }
  normalized.to_string()
}

///|
/// Validate and canonicalize a writer-provided sqref. Unlike the read helper,
/// this intentionally removes absolute markers and normalizes reversed ranges;
/// writer-owned state has one stable representation before it reaches XML.
fn normalize_sqref_for_write(value : StringView) -> String raise XlsxError {
  let tokens = xml_whitespace_tokens(value)
  if tokens.length() == 0 {
    raise InvalidCellRef(value=value.to_owned())
  }
  let normalized : Array[String] = []
  for token in tokens {
    normalized.push(normalize_cell_or_range_ref(token))
  }
  normalized.join(" ")
}

///|
fn normalize_cell_ref_for_write(value : StringView) -> String raise XlsxError {
  let (row, col) = cell_ref_to_rc(value)
  cell_ref_from(row, col)
}

///|
fn normalize_xml_sqref_attr_for_read(
  xml : StringView,
  tag_name : StringView,
  field : StringView,
  budget? : ReadBudget,
) -> String raise XlsxError {
  let tag = match tag_attributes_in(xml, tag_name) {
    Some(value) => value
    None => raise InvalidXml(msg="\{field.to_owned()} tag missing")
  }
  let raw = match attr_value(tag, "sqref") {
    Some(value) => unescape_xml_text(value)
    None => raise InvalidXml(msg="\{field.to_owned()} sqref missing")
  }
  let normalized = normalize_sqref_for_read(raw, field, budget?)
  if normalized == raw {
    return xml.to_owned()
  }
  match replace_attr_value_in_open_tag(xml, "sqref", normalized) {
    Some(value) => value
    None => raise InvalidXml(msg="\{field.to_owned()} sqref invalid")
  }
}

///|
test "sqref read normalization charges tokens before materializing them" {
  let budget = ReadBudget::new(ReadLimits::with_values(max_parser_items=2))
  let result : Result[String, Error] = Ok(
    normalize_sqref_for_read("A1 B2 C3", "selection", budget~),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="parser_items")
      assert_eq(limit, 2)
      assert_eq(actual, 3)
    }
    _ => fail("expected sqref parser-item limit")
  }
}

///|
fn sort_and_merge_sqref_row_intervals(entries : Array[(Int, Int)]) -> Unit {
  if entries.length() < 2 {
    return
  }
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
  let mut current_start = entries[0].0
  let mut current_end = entries[0].1
  for index in 1..<entries.length() {
    let (start_row, end_row) = entries[index]
    if start_row <= current_end + 1 {
      if end_row > current_end {
        current_end = end_row
      }
    } else {
      merged.push((current_start, current_end))
      current_start = start_row
      current_end = end_row
    }
  }
  merged.push((current_start, current_end))
  entries.clear()
  entries.append(merged)
}

///|
/// SQREF edits expand rectangles by column, never by row. Keep the aggregate
/// expansion explicitly bounded as well: otherwise a short list of sparse
/// full-width rectangles can materialize millions of intervals.
let max_sqref_interval_entries = 65_536

///|
/// Parse an sqref into row intervals keyed by column. Raw intervals are appended
/// in O(1), then sorted and merged once per column. Rows are never materialized
/// one by one, and aggregate column expansion is capped.
fn flat_sqref(
  sqref : StringView,
) -> Map[Int, Array[(Int, Int)]] raise XlsxError {
  let intervals : Map[Int, Array[(Int, Int)]] = Map([])
  let seen_rectangles : Map[String, Bool] = Map([])
  let mut interval_entries = 0
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
    let width = max_col - min_col + 1
    if interval_entries > max_sqref_interval_entries - width {
      raise ResourceLimitExceeded(
        kind="sqref_interval_entries",
        limit=max_sqref_interval_entries,
        actual=interval_entries + width,
      )
    }
    interval_entries = interval_entries + width
    for col in min_col..<=max_col {
      let entries = match intervals.get(col) {
        Some(value) => value
        None => []
      }
      entries.push((min_row, max_row))
      intervals[col] = entries
    }
  }
  for _, entries in intervals {
    sort_and_merge_sqref_row_intervals(entries)
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
test "sqref wb: sparse reverse-ordered intervals sort and merge in bulk" {
  let refs : Array[String] = []
  for index in 0..<2000 {
    refs.push("A\{(2000 - index) * 2 - 1}")
  }
  let intervals = flat_sqref(refs.join(" "))
  let entries = match intervals.get(1) {
    Some(value) => value
    None => fail("missing column A intervals")
  }
  inspect(entries.length(), content="2000")
  debug_inspect(entries[0], content="(1, 1)")
  debug_inspect(entries[1999], content="(3999, 3999)")
}

///|
test "sqref wb: aggregate full-width expansion has an explicit work bound" {
  let refs : Array[String] = []
  // Four full-width intervals exactly reach the 65,536-entry budget; the fifth
  // must fail before allocating another 16,384 entries.
  for index in 0..<5 {
    let row = index * 2 + 1
    refs.push("A\{row}:XFD\{row}")
  }
  let result : Result[Map[Int, Array[(Int, Int)]], Error] = Ok(
    flat_sqref(refs.join(" ")),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="sqref_interval_entries")
      inspect(limit, content="65536")
      inspect(actual, content="81920")
    }
    _ => fail("expected sqref expansion limit")
  }
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
