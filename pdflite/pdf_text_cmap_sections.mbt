///|
priv enum PdfTextCMapSection {
  PdfTextCMapNone
  PdfTextCMapCIDChar
  PdfTextCMapCIDRange
  PdfTextCMapNotDefChar
  PdfTextCMapNotDefRange
  PdfTextCMapCodeSpace
}

///|
fn pdf_text_push_cmap_cidchar_entries(
  entries : Array[(Int, Int)],
  line : BytesView,
) -> Unit {
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_ascii_int_at(line, after_source) {
          Some((cid, after_cid)) => {
            match pdf_text_bytes_to_int(source) {
              Some(code) => entries.push((code, cid))
              None => ()
            }
            index = after_cid
          }
          None => break
        }
      None => break
    }
  }
}

///|
fn pdf_text_push_cmap_cidrange_entries(
  entries : Array[(Int, Int)],
  line : BytesView,
) -> Unit {
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_hex_group_at(line, after_source) {
          Some((stop, after_stop)) =>
            match pdf_text_parse_cmap_ascii_int_at(line, after_stop) {
              Some((cid, after_cid)) => {
                match
                  (pdf_text_bytes_to_int(source), pdf_text_bytes_to_int(stop)) {
                  (Some(first), Some(last)) if first <= last =>
                    for code in first..<=last {
                      entries.push((code, cid + code - first))
                    }
                  _ => ()
                }
                index = after_cid
              }
              None => break
            }
          None => break
        }
      None => break
    }
  }
}

///|
fn pdf_text_push_cmap_codespace_entries(
  entries : Array[PdfCMapCodeSpace],
  line : BytesView,
) -> Unit {
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_hex_group_at(line, after_source) {
          Some((stop, after_stop)) => {
            match (pdf_text_bytes_to_int(source), pdf_text_bytes_to_int(stop)) {
              (Some(first), Some(last)) if first <= last &&
                source.length() == stop.length() =>
                entries.push({ length: source.length(), first, last })
              _ => ()
            }
            index = after_stop
          }
          None => break
        }
      None => break
    }
  }
}

///|
fn pdf_text_parse_cmap_cid_sections(data : BytesView) -> Array[(Int, Int)]? {
  let cursor = @core.byte_cursor_of_view(data)
  let entries : Array[(Int, Int)] = Array::new(capacity=data.length() / 4)
  let mut section = PdfTextCMapNone
  for raw_line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(raw_line)
    for raw_segment in pdf_text_cmap_section_line_views(uncommented) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "begincidchar") {
        Some(rest) => {
          section = PdfTextCMapCIDChar
          line = rest
        }
        None =>
          match pdf_text_after_ascii(raw_segment, "begincidrange") {
            Some(rest) => {
              section = PdfTextCMapCIDRange
              line = rest
            }
            None => ()
          }
      }
      match section {
        PdfTextCMapCIDChar => pdf_text_push_cmap_cidchar_entries(entries, line)
        PdfTextCMapCIDRange =>
          pdf_text_push_cmap_cidrange_entries(entries, line)
        _ => ()
      }
      if pdf_text_line_contains_ascii(line, "endcidchar") &&
        section is PdfTextCMapCIDChar {
        section = PdfTextCMapNone
      }
      if pdf_text_line_contains_ascii(line, "endcidrange") &&
        section is PdfTextCMapCIDRange {
        section = PdfTextCMapNone
      }
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries)
  }
}

///|
fn pdf_text_parse_cmap_notdef_sections(data : BytesView) -> Array[(Int, Int)]? {
  let cursor = @core.byte_cursor_of_view(data)
  let entries : Array[(Int, Int)] = Array::new(capacity=data.length() / 4)
  let mut section = PdfTextCMapNone
  for raw_line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(raw_line)
    for raw_segment in pdf_text_cmap_section_line_views(uncommented) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "beginnotdefchar") {
        Some(rest) => {
          section = PdfTextCMapNotDefChar
          line = rest
        }
        None =>
          match pdf_text_after_ascii(raw_segment, "beginnotdefrange") {
            Some(rest) => {
              section = PdfTextCMapNotDefRange
              line = rest
            }
            None => ()
          }
      }
      match section {
        PdfTextCMapNotDefChar =>
          pdf_text_push_cmap_cidchar_entries(entries, line)
        PdfTextCMapNotDefRange =>
          pdf_text_push_cmap_cidrange_entries(entries, line)
        _ => ()
      }
      if pdf_text_line_contains_ascii(line, "endnotdefchar") &&
        section is PdfTextCMapNotDefChar {
        section = PdfTextCMapNone
      }
      if pdf_text_line_contains_ascii(line, "endnotdefrange") &&
        section is PdfTextCMapNotDefRange {
        section = PdfTextCMapNone
      }
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries)
  }
}

///|
fn pdf_text_parse_cmap_codespace_sections(
  data : BytesView,
) -> Array[PdfCMapCodeSpace]? {
  let cursor = @core.byte_cursor_of_view(data)
  let entries : Array[PdfCMapCodeSpace] = Array::new(capacity=data.length() / 4)
  let mut section = PdfTextCMapNone
  for raw_line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(raw_line)
    for raw_segment in pdf_text_cmap_section_line_views(uncommented) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "begincodespacerange") {
        Some(rest) => {
          section = PdfTextCMapCodeSpace
          line = rest
        }
        None => ()
      }
      match section {
        PdfTextCMapCodeSpace =>
          pdf_text_push_cmap_codespace_entries(entries, line)
        _ => ()
      }
      if pdf_text_line_contains_ascii(line, "endcodespacerange") &&
        section is PdfTextCMapCodeSpace {
        section = PdfTextCMapNone
      }
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries)
  }
}

///|
fn pdf_text_parse_cmap_cids(data : BytesView) -> Array[(Int, Int)]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_cmap_cid_sections(data)
    if pdf_text_cmap_has_split_marker(data) {
      let compact = pdf_text_cmap_without_whitespace(data)
      let compact_parsed = pdf_text_parse_cmap_cid_sections(compact)
      match (parsed, compact_parsed) {
        (Some(original_entries), Some(compact_entries)) =>
          if compact_entries.length() > original_entries.length() {
            Some(compact_entries)
          } else {
            Some(original_entries)
          }
        (None, Some(compact_entries)) => Some(compact_entries)
        _ => parsed
      }
    } else {
      parsed
    }
  } else {
    pdf_text_parse_cmap_cid_sections(data)
  }
}

///|
fn pdf_text_parse_cmap_notdefs(data : BytesView) -> Array[(Int, Int)]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_cmap_notdef_sections(data)
    if pdf_text_cmap_has_split_marker(data) {
      let compact = pdf_text_cmap_without_whitespace(data)
      let compact_parsed = pdf_text_parse_cmap_notdef_sections(compact)
      match (parsed, compact_parsed) {
        (Some(original_entries), Some(compact_entries)) =>
          if compact_entries.length() > original_entries.length() {
            Some(compact_entries)
          } else {
            Some(original_entries)
          }
        (None, Some(compact_entries)) => Some(compact_entries)
        _ => parsed
      }
    } else {
      parsed
    }
  } else {
    pdf_text_parse_cmap_notdef_sections(data)
  }
}

///|
fn pdf_text_parse_cmap_codespaces(data : BytesView) -> Array[PdfCMapCodeSpace]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_cmap_codespace_sections(data)
    if pdf_text_cmap_has_split_marker(data) {
      let compact = pdf_text_cmap_without_whitespace(data)
      let compact_parsed = pdf_text_parse_cmap_codespace_sections(compact)
      match (parsed, compact_parsed) {
        (Some(original_entries), Some(compact_entries)) =>
          if compact_entries.length() > original_entries.length() {
            Some(compact_entries)
          } else {
            Some(original_entries)
          }
        (None, Some(compact_entries)) => Some(compact_entries)
        _ => parsed
      }
    } else {
      parsed
    }
  } else {
    pdf_text_parse_cmap_codespace_sections(data)
  }
}
