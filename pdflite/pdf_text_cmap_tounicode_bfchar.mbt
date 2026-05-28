///|
fn pdf_text_push_tounicode_bfchar_entry(
  entries : Array[(Int, PdfBytes)],
  source : PdfBytes,
  unicode : PdfBytes,
) -> Unit {
  match pdf_text_bytes_to_int(source) {
    Some(code) => entries.push((code, unicode))
    None => ()
  }
}

///|
fn pdf_text_append_tounicode_bfchar_entries(
  entries : Array[(Int, PdfBytes)],
  pending_source : PdfBytes?,
  line : BytesView,
) -> PdfBytes? {
  let mut pending = pending_source
  match pdf_text_parse_cmap_hex_groups(line) {
    Some(groups) => {
      let mut index = 0
      match pending {
        Some(source) =>
          if groups.length() > 0 {
            pdf_text_push_tounicode_bfchar_entry(entries, source, groups[0])
            pending = None
            index = 1
          }
        None => ()
      }
      while index + 1 < groups.length() {
        pdf_text_push_tounicode_bfchar_entry(
          entries,
          groups[index],
          groups[index + 1],
        )
        index += 2
      }
      if index < groups.length() {
        pending = Some(groups[index])
      }
      pending
    }
    None => pending
  }
}
