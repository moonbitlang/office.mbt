///|
priv enum PdfTextToUnicodeSection {
  PdfTextToUnicodeNone
  PdfTextToUnicodeBFChar
  PdfTextToUnicodeBFRange
}

///|
fn pdf_text_parse_tounicode_sections(
  data : BytesView,
) -> Array[(Int, @core.PdfBytes)]? {
  let cursor = @core.byte_cursor_of_view(data)
  let entries : Array[(Int, @core.PdfBytes)] = Array::new(
    capacity=data.length() / 4,
  )
  let mut section = PdfTextToUnicodeNone
  let mut pending_bfchar_source : @core.PdfBytes? = None
  let mut pending_bfrange_array : PdfTextCMapBFRangeArray? = None
  for raw_line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(raw_line)
    for raw_segment in pdf_text_cmap_section_line_views(uncommented) {
      let mut line = raw_segment
      match pdf_text_after_ascii(raw_segment, "beginbfchar") {
        Some(rest) => {
          section = PdfTextToUnicodeBFChar
          line = rest
        }
        None =>
          match pdf_text_after_ascii(raw_segment, "beginbfrange") {
            Some(rest) => {
              section = PdfTextToUnicodeBFRange
              line = rest
            }
            None => ()
          }
      }
      let end_bfchar = pdf_text_line_contains_ascii(line, "endbfchar")
      let end_bfrange = pdf_text_line_contains_ascii(line, "endbfrange")
      match pending_bfrange_array {
        Some(pending) =>
          match pdf_text_append_pending_bfrange_array(entries, pending, line) {
            PdfTextCMapBFRangeArrayClosed(rest) =>
              pending_bfrange_array = pdf_text_append_tounicode_bfrange_line(
                entries, rest,
              )
            PdfTextCMapBFRangeArrayPending(pending) =>
              pending_bfrange_array = Some(pending)
          }
        None =>
          match section {
            PdfTextToUnicodeBFChar =>
              pending_bfchar_source = pdf_text_append_tounicode_bfchar_entries(
                entries, pending_bfchar_source, line,
              )
            PdfTextToUnicodeBFRange =>
              pending_bfrange_array = pdf_text_append_tounicode_bfrange_line(
                entries, line,
              )
            PdfTextToUnicodeNone => ()
          }
      }
      if end_bfchar && section is PdfTextToUnicodeBFChar {
        section = PdfTextToUnicodeNone
        pending_bfchar_source = None
      }
      if end_bfrange && section is PdfTextToUnicodeBFRange {
        section = PdfTextToUnicodeNone
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
fn pdf_text_parse_tounicode(data : BytesView) -> Array[(Int, @core.PdfBytes)]? {
  if pdf_text_cmap_contains_whitespace(data) {
    let parsed = pdf_text_parse_tounicode_sections(data)
    if pdf_text_cmap_has_split_marker(data) {
      let compact = pdf_text_cmap_without_whitespace(data)
      let compact_parsed = pdf_text_parse_tounicode_sections(compact)
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
    pdf_text_parse_tounicode_sections(data)
  }
}
