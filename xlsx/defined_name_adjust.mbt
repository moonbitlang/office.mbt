///|
fn column_name_from_number(col : Int) -> String raise XlsxError {
  column_number_to_name(col)
}

///|
fn parse_column_ref(text : StringView) -> (Int, Bool)? {
  let chars = text.to_array()
  let mut idx = 0
  let mut abs_col = false
  if idx < chars.length() && chars[idx] == '$' {
    abs_col = true
    idx = idx + 1
  }
  let mut col = 0
  let mut has_col = false
  while idx < chars.length() {
    let ch = chars[idx]
    if ch.is_ascii_alphabetic() {
      let upper = ch.to_ascii_uppercase()
      col = col * 26 + (upper.to_int() - 'A'.to_int() + 1)
      has_col = true
      idx = idx + 1
    } else {
      break
    }
  }
  if !has_col || idx != chars.length() {
    return None
  }
  Some((col, abs_col))
}

///|
fn parse_row_ref(text : StringView) -> (Int, Bool)? {
  let chars = text.to_array()
  let mut idx = 0
  let mut abs_row = false
  if idx < chars.length() && chars[idx] == '$' {
    abs_row = true
    idx = idx + 1
  }
  let row_sb = StringBuilder::new()
  while idx < chars.length() {
    let ch = chars[idx]
    if ch.is_ascii_digit() {
      row_sb.write_char(ch)
      idx = idx + 1
    } else {
      return None
    }
  }
  let text_value = row_sb.to_string()
  if text_value == "" {
    return None
  }
  let row = @strconv.parse_int(text_value, base=10) catch { _ => return None }
  if row <= 0 {
    return None
  }
  Some((row, abs_row))
}

///|
fn parse_cell_ref(text : StringView) -> (Int, Int, Bool, Bool)? {
  let chars = text.to_array()
  let mut idx = 0
  let mut abs_col = false
  if idx < chars.length() && chars[idx] == '$' {
    abs_col = true
    idx = idx + 1
  }
  let mut col = 0
  let mut has_col = false
  while idx < chars.length() {
    let ch = chars[idx]
    if ch.is_ascii_alphabetic() {
      let upper = ch.to_ascii_uppercase()
      col = col * 26 + (upper.to_int() - 'A'.to_int() + 1)
      has_col = true
      idx = idx + 1
    } else {
      break
    }
  }
  if !has_col {
    return None
  }
  let mut abs_row = false
  if idx < chars.length() && chars[idx] == '$' {
    abs_row = true
    idx = idx + 1
  }
  let row_sb = StringBuilder::new()
  while idx < chars.length() {
    let ch = chars[idx]
    if ch.is_ascii_digit() {
      row_sb.write_char(ch)
      idx = idx + 1
    } else {
      return None
    }
  }
  let row_text = row_sb.to_string()
  if row_text == "" {
    return None
  }
  let row = @strconv.parse_int(row_text, base=10) catch { _ => return None }
  if row <= 0 {
    return None
  }
  Some((row, col, abs_row, abs_col))
}

///|
fn format_column_ref(col : Int, abs_col : Bool) -> String raise XlsxError {
  let prefix = if abs_col { "$" } else { "" }
  let name = column_name_from_number(col)
  "\{prefix}\{name}"
}

///|
fn format_row_ref(row : Int, abs_row : Bool) -> String {
  let prefix = if abs_row { "$" } else { "" }
  "\{prefix}\{row}"
}

///|
fn format_cell_ref(
  row : Int,
  col : Int,
  abs_row : Bool,
  abs_col : Bool,
) -> String raise XlsxError {
  let col_prefix = if abs_col { "$" } else { "" }
  let row_prefix = if abs_row { "$" } else { "" }
  let col_name = column_name_from_number(col)
  "\{col_prefix}\{col_name}\{row_prefix}\{row}"
}

///|
fn is_ref_char(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '$' || ch == ':'
}

///|
fn adjust_range_rows_after_insert(
  min_row : Int,
  max_row : Int,
  row : Int,
  count : Int,
) -> (Int, Int) {
  adjust_bounds_for_insert(min_row, max_row, row, count)
}

///|
fn adjust_range_rows_after_remove(
  min_row : Int,
  max_row : Int,
  row : Int,
  count : Int,
) -> (Int, Int)? {
  adjust_bounds_for_remove(min_row, max_row, row, count)
}

///|
fn adjust_range_cols_after_insert(
  min_col : Int,
  max_col : Int,
  col : Int,
  count : Int,
) -> (Int, Int) {
  adjust_bounds_for_insert(min_col, max_col, col, count)
}

///|
fn adjust_range_cols_after_remove(
  min_col : Int,
  max_col : Int,
  col : Int,
  count : Int,
) -> (Int, Int)? {
  adjust_bounds_for_remove(min_col, max_col, col, count)
}

///|
fn adjust_ref_after_row_insert(
  ref_text : StringView,
  row : Int,
  count : Int,
) -> String? raise XlsxError {
  let text = ref_text.to_string()
  match text.find(":") {
    Some(pos) => {
      let left = text[:pos]
      let right = text[pos + 1:]
      match (parse_cell_ref(left), parse_cell_ref(right)) {
        (Some((r1, c1, ar1, ac1)), Some((r2, c2, ar2, ac2))) => {
          let (new_min, new_max) = adjust_range_rows_after_insert(
            r1, r2, row, count,
          )
          let start = format_cell_ref(new_min, c1, ar1, ac1)
          let end = format_cell_ref(new_max, c2, ar2, ac2)
          Some("\{start}:\{end}")
        }
        _ =>
          match (parse_row_ref(left), parse_row_ref(right)) {
            (Some((r1, ar1)), Some((r2, ar2))) => {
              let (new_min, new_max) = adjust_range_rows_after_insert(
                r1, r2, row, count,
              )
              let start = format_row_ref(new_min, ar1)
              let end = format_row_ref(new_max, ar2)
              Some("\{start}:\{end}")
            }
            _ => Some(text)
          }
      }
    }
    None =>
      match parse_cell_ref(text) {
        Some((r1, c1, ar1, ac1)) => {
          let new_row = if r1 >= row { r1 + count } else { r1 }
          Some(format_cell_ref(new_row, c1, ar1, ac1))
        }
        None =>
          match parse_row_ref(text) {
            Some((r1, ar1)) => {
              let new_row = if r1 >= row { r1 + count } else { r1 }
              Some(format_row_ref(new_row, ar1))
            }
            None => Some(text)
          }
      }
  }
}

///|
fn adjust_ref_after_row_remove(
  ref_text : StringView,
  row : Int,
  count : Int,
) -> String? raise XlsxError {
  let text = ref_text.to_string()
  match text.find(":") {
    Some(pos) => {
      let left = text[:pos]
      let right = text[pos + 1:]
      match (parse_cell_ref(left), parse_cell_ref(right)) {
        (Some((r1, c1, ar1, ac1)), Some((r2, c2, ar2, ac2))) =>
          match adjust_range_rows_after_remove(r1, r2, row, count) {
            Some((new_min, new_max)) => {
              let start = format_cell_ref(new_min, c1, ar1, ac1)
              let end = format_cell_ref(new_max, c2, ar2, ac2)
              Some("\{start}:\{end}")
            }
            None => None
          }
        _ =>
          match (parse_row_ref(left), parse_row_ref(right)) {
            (Some((r1, ar1)), Some((r2, ar2))) =>
              match adjust_range_rows_after_remove(r1, r2, row, count) {
                Some((new_min, new_max)) => {
                  let start = format_row_ref(new_min, ar1)
                  let end = format_row_ref(new_max, ar2)
                  Some("\{start}:\{end}")
                }
                None => None
              }
            _ => Some(text)
          }
      }
    }
    None =>
      match parse_cell_ref(text) {
        Some((r1, c1, ar1, ac1)) =>
          match adjust_range_rows_after_remove(r1, r1, row, count) {
            Some((new_row, _)) => Some(format_cell_ref(new_row, c1, ar1, ac1))
            None => None
          }
        None =>
          match parse_row_ref(text) {
            Some((r1, ar1)) =>
              match adjust_range_rows_after_remove(r1, r1, row, count) {
                Some((new_row, _)) => Some(format_row_ref(new_row, ar1))
                None => None
              }
            None => Some(text)
          }
      }
  }
}

///|
fn adjust_ref_after_col_insert(
  ref_text : StringView,
  col : Int,
  count : Int,
) -> String? raise XlsxError {
  let text = ref_text.to_string()
  match text.find(":") {
    Some(pos) => {
      let left = text[:pos]
      let right = text[pos + 1:]
      match (parse_cell_ref(left), parse_cell_ref(right)) {
        (Some((r1, c1, ar1, ac1)), Some((r2, c2, ar2, ac2))) => {
          let (new_min, new_max) = adjust_range_cols_after_insert(
            c1, c2, col, count,
          )
          let start = format_cell_ref(r1, new_min, ar1, ac1)
          let end = format_cell_ref(r2, new_max, ar2, ac2)
          Some("\{start}:\{end}")
        }
        _ =>
          match (parse_column_ref(left), parse_column_ref(right)) {
            (Some((c1, ac1)), Some((c2, ac2))) => {
              let (new_min, new_max) = adjust_range_cols_after_insert(
                c1, c2, col, count,
              )
              let start = format_column_ref(new_min, ac1)
              let end = format_column_ref(new_max, ac2)
              Some("\{start}:\{end}")
            }
            _ => Some(text)
          }
      }
    }
    None =>
      match parse_cell_ref(text) {
        Some((r1, c1, ar1, ac1)) => {
          let new_col = if c1 >= col { c1 + count } else { c1 }
          Some(format_cell_ref(r1, new_col, ar1, ac1))
        }
        None =>
          match parse_column_ref(text) {
            Some((c1, ac1)) => {
              let new_col = if c1 >= col { c1 + count } else { c1 }
              Some(format_column_ref(new_col, ac1))
            }
            None => Some(text)
          }
      }
  }
}

///|
fn adjust_ref_after_col_remove(
  ref_text : StringView,
  col : Int,
  count : Int,
) -> String? raise XlsxError {
  let text = ref_text.to_string()
  match text.find(":") {
    Some(pos) => {
      let left = text[:pos]
      let right = text[pos + 1:]
      match (parse_cell_ref(left), parse_cell_ref(right)) {
        (Some((r1, c1, ar1, ac1)), Some((r2, c2, ar2, ac2))) =>
          match adjust_range_cols_after_remove(c1, c2, col, count) {
            Some((new_min, new_max)) => {
              let start = format_cell_ref(r1, new_min, ar1, ac1)
              let end = format_cell_ref(r2, new_max, ar2, ac2)
              Some("\{start}:\{end}")
            }
            None => None
          }
        _ =>
          match (parse_column_ref(left), parse_column_ref(right)) {
            (Some((c1, ac1)), Some((c2, ac2))) =>
              match adjust_range_cols_after_remove(c1, c2, col, count) {
                Some((new_min, new_max)) => {
                  let start = format_column_ref(new_min, ac1)
                  let end = format_column_ref(new_max, ac2)
                  Some("\{start}:\{end}")
                }
                None => None
              }
            _ => Some(text)
          }
      }
    }
    None =>
      match parse_cell_ref(text) {
        Some((r1, c1, ar1, ac1)) =>
          match adjust_range_cols_after_remove(c1, c1, col, count) {
            Some((new_col, _)) => Some(format_cell_ref(r1, new_col, ar1, ac1))
            None => None
          }
        None =>
          match parse_column_ref(text) {
            Some((c1, ac1)) =>
              match adjust_range_cols_after_remove(c1, c1, col, count) {
                Some((new_col, _)) => Some(format_column_ref(new_col, ac1))
                None => None
              }
            None => Some(text)
          }
      }
  }
}

///|
fn adjust_defined_name_refers_to_for_sheet(
  refers_to : StringView,
  sheet_name : StringView,
  adjust_fn : (StringView) -> String? raise XlsxError,
) -> String raise XlsxError {
  let raw_chars = refers_to.to_array()
  let plain_prefix = "\{sheet_name.to_string()}!"
  let quoted_prefix = "'\{escape_sheet_name(sheet_name)}'!"
  let plain_chars = plain_prefix.to_array()
  let quoted_chars = quoted_prefix.to_array()
  let sb = StringBuilder::new()
  let mut idx = 0
  let find_prefix = fn(
    text : Array[Char],
    prefix : Array[Char],
    start : Int,
  ) -> Int? {
    if prefix.length() == 0 {
      return None
    }
    let mut pos = start
    while pos + prefix.length() <= text.length() {
      let mut matched = true
      for i in 0..<prefix.length() {
        if text[pos + i] != prefix[i] {
          matched = false
          break
        }
      }
      if matched {
        return Some(pos)
      }
      pos = pos + 1
    }
    None
  }
  while idx < raw_chars.length() {
    let plain_pos = find_prefix(raw_chars, plain_chars, idx)
    let quoted_pos = find_prefix(raw_chars, quoted_chars, idx)
    let next = match (plain_pos, quoted_pos) {
      (Some(p), Some(q)) =>
        if p < q {
          Some((p, plain_prefix, plain_chars.length()))
        } else {
          Some((q, quoted_prefix, quoted_chars.length()))
        }
      (Some(p), None) => Some((p, plain_prefix, plain_chars.length()))
      (None, Some(q)) => Some((q, quoted_prefix, quoted_chars.length()))
      (None, None) => None
    }
    match next {
      Some((pos, prefix, prefix_len)) => {
        for i in idx..<pos {
          sb.write_char(raw_chars[i])
        }
        sb.write_view(prefix)
        let start = pos + prefix_len
        let mut end = start
        while end < raw_chars.length() && is_ref_char(raw_chars[end]) {
          end = end + 1
        }
        let ref_sb = StringBuilder::new()
        for i in start..<end {
          ref_sb.write_char(raw_chars[i])
        }
        let ref_part = ref_sb.to_string()
        let updated = adjust_fn(ref_part)
        match updated {
          Some(value) => sb.write_view(value)
          None => sb.write_view("#REF!")
        }
        idx = end
      }
      None => {
        for i in idx..<raw_chars.length() {
          sb.write_char(raw_chars[i])
        }
        break
      }
    }
  }
  sb.to_string()
}
