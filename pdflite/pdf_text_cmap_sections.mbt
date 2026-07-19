///|
fn pdf_text_push_cmap_cidchar_entries(
  entries : Array[(Int, Int)],
  line : BytesView,
) -> Unit {
  for index = 0; index < line.length(); {
    guard pdf_text_parse_cmap_hex_group_at(line, index)
      is Some((source, after_source)) &&
      pdf_text_parse_cmap_ascii_int_at(line, after_source)
      is Some((cid, after_cid)) else {
      break
    }
    if pdf_text_bytes_to_int(source) is Some(code) {
      entries.push((code, cid))
    }
    continue after_cid
  }
}

///|
fn pdf_text_push_cmap_cidrange_entries(
  entries : Array[(Int, Int)],
  line : BytesView,
) -> Unit {
  for index = 0; index < line.length(); {
    guard pdf_text_parse_cmap_hex_group_at(line, index)
      is Some((source, after_source)) &&
      pdf_text_parse_cmap_hex_group_at(line, after_source)
      is Some((stop, after_stop)) &&
      pdf_text_parse_cmap_ascii_int_at(line, after_stop)
      is Some((cid, after_cid)) else {
      break
    }
    match (pdf_text_bytes_to_int(source), pdf_text_bytes_to_int(stop)) {
      (Some(first), Some(last)) if first <= last =>
        for code in first..<=last {
          entries.push((code, cid + code - first))
        }
      _ => ()
    }
    continue after_cid
  }
}

///|
fn pdf_text_push_cmap_codespace_entries(
  entries : Array[PdfCMapCodeSpace],
  line : BytesView,
) -> Unit {
  for index = 0; index < line.length(); {
    guard pdf_text_parse_cmap_hex_group_at(line, index)
      is Some((source, after_source)) &&
      pdf_text_parse_cmap_hex_group_at(line, after_source)
      is Some((stop, after_stop)) else {
      break
    }
    match (pdf_text_bytes_to_int(source), pdf_text_bytes_to_int(stop)) {
      (Some(first), Some(last)) if first <= last &&
        source.length() == stop.length() =>
        entries.push({ length: source.length(), first, last })
      _ => ()
    }
    continue after_stop
  }
}

///|
/// Shared section walker: each entry pairs a `begin<word>`/`end<word>`
/// marker with the pusher that consumes lines inside that section. Markers
/// are tried in order, matching the original per-kind walkers.
fn[E] pdf_text_parse_cmap_sections_with(
  data : BytesView,
  sections : Array[(String, String, (Array[E], BytesView) -> Unit)],
) -> Array[E]? {
  let cursor = @core.byte_cursor_of_view(data)
  let entries : Array[E] = Array::new(capacity=data.length() / 4)
  let mut active = -1
  for raw_line in cursor.read_line_views() {
    let uncommented = pdf_text_cmap_line_without_comment(raw_line)
    for raw_segment in pdf_text_cmap_section_line_views(uncommented) {
      let mut line = raw_segment
      for index, section in sections {
        let (begin_word, _, _) = section
        if pdf_text_after_ascii(raw_segment, begin_word) is Some(rest) {
          active = index
          line = rest
          break
        }
      }
      if active >= 0 {
        let (_, _, push) = sections[active]
        push(entries, line)
      }
      for index, section in sections {
        let (_, end_word, _) = section
        if active == index && pdf_text_line_contains_ascii(line, end_word) {
          active = -1
        }
      }
    }
  }
  if entries is [] {
    None
  } else {
    Some(entries)
  }
}

///|
fn pdf_text_parse_cmap_cid_sections(data : BytesView) -> Array[(Int, Int)]? {
  pdf_text_parse_cmap_sections_with(data, [
    ("begincidchar", "endcidchar", pdf_text_push_cmap_cidchar_entries),
    ("begincidrange", "endcidrange", pdf_text_push_cmap_cidrange_entries),
  ])
}

///|
fn pdf_text_parse_cmap_notdef_sections(data : BytesView) -> Array[(Int, Int)]? {
  pdf_text_parse_cmap_sections_with(data, [
    ("beginnotdefchar", "endnotdefchar", pdf_text_push_cmap_cidchar_entries),
    ("beginnotdefrange", "endnotdefrange", pdf_text_push_cmap_cidrange_entries),
  ])
}

///|
fn pdf_text_parse_cmap_codespace_sections(
  data : BytesView,
) -> Array[PdfCMapCodeSpace]? {
  pdf_text_parse_cmap_sections_with(data, [
    (
      "begincodespacerange", "endcodespacerange", pdf_text_push_cmap_codespace_entries,
    ),
  ])
}

///|
/// Whitespace-split CMaps are parsed twice — as written and with all
/// whitespace stripped — keeping whichever run yields more entries.
fn[E] pdf_text_parse_cmap_with_compact_fallback(
  data : BytesView,
  parse : (BytesView) -> Array[E]?,
) -> Array[E]? {
  guard pdf_text_cmap_contains_whitespace(data) else { return parse(data) }
  let parsed = parse(data)
  guard pdf_text_cmap_has_split_marker(data) else { return parsed }
  let compact = pdf_text_cmap_without_whitespace(data)
  match (parsed, parse(compact)) {
    (Some(original_entries), Some(compact_entries)) if compact_entries.length() >
      original_entries.length() => Some(compact_entries)
    (None, Some(compact_entries)) => Some(compact_entries)
    _ => parsed
  }
}

///|
fn pdf_text_parse_cmap_cids(data : BytesView) -> Array[(Int, Int)]? {
  pdf_text_parse_cmap_with_compact_fallback(
    data, pdf_text_parse_cmap_cid_sections,
  )
}

///|
fn pdf_text_parse_cmap_notdefs(data : BytesView) -> Array[(Int, Int)]? {
  pdf_text_parse_cmap_with_compact_fallback(
    data, pdf_text_parse_cmap_notdef_sections,
  )
}

///|
fn pdf_text_parse_cmap_codespaces(data : BytesView) -> Array[PdfCMapCodeSpace]? {
  pdf_text_parse_cmap_with_compact_fallback(
    data, pdf_text_parse_cmap_codespace_sections,
  )
}
