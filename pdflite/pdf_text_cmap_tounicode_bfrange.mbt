///|
fn pdf_text_tounicode_bfrange_inline_entries(
  line : BytesView,
) -> Array[(Int, @core.PdfBytes)]? {
  let entries : Array[(Int, @core.PdfBytes)] = Array::new(
    capacity=line.length(),
  )
  let mut index = 0
  while index < line.length() {
    match pdf_text_parse_cmap_hex_group_at(line, index) {
      Some((source, after_source)) =>
        match pdf_text_parse_cmap_hex_group_at(line, after_source) {
          Some((stop, after_stop)) =>
            match (pdf_text_bytes_to_int(source), pdf_text_bytes_to_int(stop)) {
              (Some(first), Some(last)) if first <= last => {
                index = pdf_text_skip_cmap_whitespace(line, after_stop)
                if index < line.length() && line[index].to_int() == 91 {
                  match pdf_text_index_of_byte(line, 93, index + 1) {
                    Some(close) => {
                      match
                        pdf_text_parse_cmap_hex_groups(line[index + 1:close]) {
                        Some(unicodes) =>
                          match
                            pdf_text_tounicode_bfrange_array_entries(
                              first, last, unicodes,
                            ) {
                            Some(line_entries) =>
                              for entry in line_entries {
                                entries.push(entry)
                              }
                            None => return None
                          }
                        None => return None
                      }
                      index = close + 1
                    }
                    None => return None
                  }
                } else {
                  match pdf_text_parse_cmap_hex_group_at(line, index) {
                    Some((unicode, after_unicode)) => {
                      for code in first..<=last {
                        match
                          pdf_text_add_to_big_endian_bytes(
                            unicode,
                            code - first,
                          ) {
                          Some(bytes) => entries.push((code, bytes))
                          None => return None
                        }
                      }
                      index = after_unicode
                    }
                    None => return None
                  }
                }
              }
              _ => return None
            }
          None => return None
        }
      None => break
    }
  }
  if entries.length() == 0 {
    None
  } else {
    Some(entries)
  }
}

///|
fn pdf_text_add_to_big_endian_bytes(
  bytes : @core.PdfBytes,
  increment : Int,
) -> @core.PdfBytes? {
  guard increment >= 0 else { return None }
  let output = bytes.to_array()
  let mut carry = increment
  let mut index = output.length()
  while index > 0 && carry > 0 {
    index -= 1
    let sum = output[index].to_int() + carry % 256
    output[index] = (sum % 256).to_byte()
    carry = carry / 256 + sum / 256
  }
  if carry == 0 {
    Some(Bytes::from_array(output))
  } else {
    None
  }
}

///|
fn pdf_text_tounicode_bfrange_array_entries(
  first : Int,
  last : Int,
  unicodes : ArrayView[@core.PdfBytes],
) -> Array[(Int, @core.PdfBytes)]? {
  guard first <= last && unicodes.length() == last - first + 1 else {
    return None
  }
  let entries : Array[(Int, @core.PdfBytes)] = Array::new(
    capacity=unicodes.length(),
  )
  for index in 0..<unicodes.length() {
    entries.push((first + index, unicodes[index]))
  }
  Some(entries)
}

///|
fn pdf_text_tounicode_bfrange_entries_of_line(
  line : BytesView,
) -> Array[(Int, @core.PdfBytes)]? {
  pdf_text_tounicode_bfrange_inline_entries(line)
}

///|
fn pdf_text_push_tounicode_bfrange_entries(
  entries : Array[(Int, @core.PdfBytes)],
  line_entries : ArrayView[(Int, @core.PdfBytes)],
) -> Unit {
  for entry in line_entries {
    entries.push(entry)
  }
}

///|
priv struct PdfTextCMapBFRangeArray {
  first : Int
  last : Int
  unicodes : Array[@core.PdfBytes]
}

///|
fn pdf_text_extend_cmap_hex_groups(
  output : Array[@core.PdfBytes],
  line : BytesView,
) -> Unit {
  match pdf_text_parse_cmap_hex_groups(line) {
    Some(groups) =>
      for group in groups {
        output.push(group)
      }
    None => ()
  }
}

///|
fn pdf_text_cmap_bfrange_array_line(line : BytesView) -> BytesView {
  match pdf_text_index_of_byte(line, 91, 0) {
    Some(open) => line[open + 1:]
    None => line
  }
}

///|
priv enum PdfTextCMapBFRangeArrayAppend {
  PdfTextCMapBFRangeArrayPending(PdfTextCMapBFRangeArray)
  PdfTextCMapBFRangeArrayClosed(BytesView)
}

///|
fn pdf_text_append_pending_bfrange_array(
  entries : Array[(Int, @core.PdfBytes)],
  pending : PdfTextCMapBFRangeArray,
  line : BytesView,
) -> PdfTextCMapBFRangeArrayAppend {
  let content = pdf_text_cmap_bfrange_array_line(line)
  match pdf_text_index_of_byte(content, 93, 0) {
    Some(close) => {
      pdf_text_extend_cmap_hex_groups(pending.unicodes, content[0:close])
      match
        pdf_text_tounicode_bfrange_array_entries(
          pending.first,
          pending.last,
          pending.unicodes,
        ) {
        Some(line_entries) =>
          pdf_text_push_tounicode_bfrange_entries(entries, line_entries)
        None => ()
      }
      PdfTextCMapBFRangeArrayClosed(content[close + 1:])
    }
    None => {
      pdf_text_extend_cmap_hex_groups(pending.unicodes, content)
      PdfTextCMapBFRangeArrayPending(pending)
    }
  }
}

///|
priv enum PdfTextCMapBFRangeLineAppend {
  PdfTextCMapBFRangeLineDone
  PdfTextCMapBFRangeLinePending(PdfTextCMapBFRangeArray)
  PdfTextCMapBFRangeLineContinue(BytesView)
}

///|
fn pdf_text_append_tounicode_bfrange_entry(
  entries : Array[(Int, @core.PdfBytes)],
  line : BytesView,
) -> PdfTextCMapBFRangeLineAppend {
  match pdf_text_parse_cmap_hex_group_at(line, 0) {
    Some((source, after_source)) =>
      match pdf_text_parse_cmap_hex_group_at(line, after_source) {
        Some((stop, after_stop)) =>
          match (pdf_text_bytes_to_int(source), pdf_text_bytes_to_int(stop)) {
            (Some(first), Some(last)) if first <= last => {
              let value_start = pdf_text_skip_cmap_whitespace(line, after_stop)
              let pending : PdfTextCMapBFRangeArray = {
                first,
                last,
                unicodes: [],
              }
              if value_start >= line.length() {
                PdfTextCMapBFRangeLinePending(pending)
              } else if line[value_start].to_int() == 91 {
                match
                  pdf_text_append_pending_bfrange_array(
                    entries,
                    pending,
                    line[value_start + 1:],
                  ) {
                  PdfTextCMapBFRangeArrayClosed(rest) =>
                    PdfTextCMapBFRangeLineContinue(rest)
                  PdfTextCMapBFRangeArrayPending(pending) =>
                    PdfTextCMapBFRangeLinePending(pending)
                }
              } else {
                match pdf_text_parse_cmap_hex_group_at(line, value_start) {
                  Some((unicode, after_unicode)) => {
                    let line_entries : Array[(Int, @core.PdfBytes)] = Array::new(
                      capacity=last - first + 1,
                    )
                    for code in first..<=last {
                      match
                        pdf_text_add_to_big_endian_bytes(unicode, code - first) {
                        Some(bytes) => line_entries.push((code, bytes))
                        None => return PdfTextCMapBFRangeLineDone
                      }
                    }
                    pdf_text_push_tounicode_bfrange_entries(
                      entries, line_entries,
                    )
                    PdfTextCMapBFRangeLineContinue(line[after_unicode:])
                  }
                  None => PdfTextCMapBFRangeLineDone
                }
              }
            }
            _ => PdfTextCMapBFRangeLineDone
          }
        None => PdfTextCMapBFRangeLineDone
      }
    None => PdfTextCMapBFRangeLineDone
  }
}

///|
fn pdf_text_append_tounicode_bfrange_line(
  entries : Array[(Int, @core.PdfBytes)],
  line : BytesView,
) -> PdfTextCMapBFRangeArray? {
  match pdf_text_tounicode_bfrange_entries_of_line(line) {
    Some(line_entries) => {
      pdf_text_push_tounicode_bfrange_entries(entries, line_entries)
      return None
    }
    None => ()
  }
  let mut current = line
  while current.length() > 0 {
    match pdf_text_append_tounicode_bfrange_entry(entries, current) {
      PdfTextCMapBFRangeLineDone => return None
      PdfTextCMapBFRangeLinePending(pending) => return Some(pending)
      PdfTextCMapBFRangeLineContinue(rest) => current = rest
    }
  }
  None
}
