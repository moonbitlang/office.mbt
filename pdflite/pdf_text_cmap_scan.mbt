///|
fn pdf_text_hex_digit_value(byte : Byte) -> Int? {
  match byte {
    b'0'..=b'9' => Some(byte.to_int() - '0')
    b'A'..=b'F' => Some(byte.to_int() - 'A' + 10)
    b'a'..=b'f' => Some(byte.to_int() - 'a' + 10)
    _ => None
  }
}

///|
fn pdf_text_parse_hex_bytes(
  line : BytesView,
  start : Int,
  stop : Int,
) -> @core.PdfBytes? {
  guard stop >= start else { return None }
  // a zero-length range is valid even when the indices sit outside the
  // view (the previous index-based loops never dereferenced them)
  guard stop > start else { return Some(b"") }
  let nibbles : Array[Int] = []
  for byte in line[start:stop] {
    if @core.pdf_is_whitespace_byte(byte.to_int()) {
      continue
    }
    match pdf_text_hex_digit_value(byte) {
      Some(nibble) => nibbles.push(nibble)
      None => return None
    }
  }
  let output = Array::make((nibbles.length() + 1) / 2, b'\x00')
  for index, nibble in nibbles {
    if index % 2 == 0 {
      output[index / 2] = (nibble * 16).to_byte()
    } else {
      output[index / 2] = (output[index / 2].to_int() + nibble).to_byte()
    }
  }
  Some(Bytes::from_array(output))
}

///|
fn pdf_text_skip_cmap_whitespace(line : BytesView, start : Int) -> Int {
  for index = start; index < line.length() &&
     @core.pdf_is_whitespace_byte(line[index].to_int()); {
    continue index + 1
  } nobreak {
    index
  }
}

///|
fn pdf_text_line_contains_ascii(line : BytesView, word : String) -> Bool {
  pdf_text_index_of_ascii(line, word) != None
}

///|
fn pdf_text_index_of_ascii(line : BytesView, word : String) -> Int? {
  let needle = @ascii.encode(word)
  guard needle.length() > 0 else { return None }
  line.find(needle)
}

///|
fn pdf_text_index_of_ascii_from(
  line : BytesView,
  word : String,
  start : Int,
) -> Int? {
  guard start < line.length() else { return None }
  pdf_text_index_of_ascii(line[start:], word).map(index => start + index)
}

///|
fn pdf_text_after_ascii(line : BytesView, word : String) -> BytesView? {
  let needle = @ascii.encode(word)
  guard needle.length() > 0 else { return None }
  line.find(needle).map(index => line[index + needle.length():])
}

///|
fn pdf_text_view_equals_ascii(view : BytesView, text : String) -> Bool {
  view == @ascii.encode(text)
}

///|
fn pdf_text_cmap_end_marker(line : BytesView, start : Int) -> (Int, Int)? {
  let markers = [
    "endbfchar", "endbfrange", "endcidchar", "endcidrange", "endnotdefchar", "endnotdefrange",
    "endcodespacerange",
  ]
  let mut best : (Int, Int)? = None
  for marker in markers {
    match pdf_text_index_of_ascii_from(line, marker, start) {
      Some(index) =>
        match best {
          Some((best_index, _)) if best_index <= index => ()
          _ => best = Some((index, marker.length()))
        }
      None => ()
    }
  }
  best
}

///|
fn pdf_text_cmap_section_line_views(line : BytesView) -> Array[BytesView] {
  let views : Array[BytesView] = Array::new(capacity=line.length())
  for start = 0; start < line.length(); {
    match pdf_text_cmap_end_marker(line, start) {
      Some((index, length)) => {
        let stop = index + length
        views.push(line[start:stop])
        continue stop
      }
      None => {
        views.push(line[start:])
        break
      }
    }
  }
  views
}

///|
fn pdf_text_cmap_comment_start(line : BytesView) -> Int {
  for index = 0, in_literal = false, escaped = false, depth = 0; index <
     line.length(); {
    match (in_literal, line[index]) {
      (true, _) if escaped => continue index + 1, true, false, depth
      (true, b'\\') => continue index + 1, true, true, depth
      (true, b'(') => continue index + 1, true, false, depth + 1
      (true, b')') =>
        if depth <= 1 {
          continue index + 1, false, false, 0
        } else {
          continue index + 1, true, false, depth - 1
        }
      (true, _) => continue index + 1, true, false, depth
      (false, b'%') => break index
      (false, b'(') => continue index + 1, true, false, 1
      (false, _) => continue index + 1, false, false, depth
    }
  } nobreak {
    line.length()
  }
}

///|
fn pdf_text_cmap_line_without_comment(line : BytesView) -> @core.PdfBytes {
  line[0:pdf_text_cmap_comment_start(line)].to_owned()
}

///|
fn pdf_text_parse_cmap_hex_groups(line : BytesView) -> Array[@core.PdfBytes]? {
  let groups : Array[@core.PdfBytes] = Array::new(capacity=line.length() / 2)
  for index = 0; index < line.length(); {
    let start = pdf_text_skip_cmap_whitespace(line, index)
    guard start < line.length() && line[start] is b'<' else { break }
    match pdf_text_parse_cmap_hex_group_at(line, start) {
      Some((bytes, next)) => {
        groups.push(bytes)
        continue next
      }
      None => return None
    }
  }
  if groups.length() == 0 {
    None
  } else {
    Some(groups)
  }
}

///|
fn pdf_text_parse_cmap_hex_group_at(
  line : BytesView,
  start : Int,
) -> (@core.PdfBytes, Int)? {
  let index = pdf_text_skip_cmap_whitespace(line, start)
  guard index < line.length() && line[index] is b'<' else { return None }
  let body_start = index + 1
  guard pdf_text_index_of_byte(line, '>', body_start) is Some(stop) else {
    return None
  }
  pdf_text_parse_hex_bytes(line, body_start, stop).map(bytes => {
    (bytes, stop + 1)
  })
}

///|
fn pdf_text_bytes_to_int(bytes : BytesView) -> Int? {
  guard bytes.length() > 0 else { return None }
  let mut value = 0
  for byte in bytes {
    value = (value << 8) | byte.to_int()
  }
  Some(value)
}

///|
fn pdf_text_parse_cmap_ascii_int_at(
  line : BytesView,
  start : Int,
) -> (Int, Int)? {
  let index = pdf_text_skip_cmap_whitespace(line, start)
  guard index < line.length() else { return None }
  let digit_start = if line[index] is (b'+' | b'-') { index + 1 } else { index }
  let stop = for scan = digit_start; scan < line.length() &&
                line[scan] is (b'0'..=b'9'); {
    continue scan + 1
  } nobreak {
    scan
  }
  guard stop > digit_start else { return None }
  try @core.pdf_parse_ascii_int_view(line[index:stop]) catch {
    _ => None
  } noraise {
    value => Some((value, stop))
  }
}

///|
fn pdf_text_index_of_byte(line : BytesView, target : Int, start : Int) -> Int? {
  for index in start..<line.length() {
    if line[index].to_int() == target {
      break Some(index)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_cmap_contains_whitespace(data : BytesView) -> Bool {
  for byte in data {
    if @core.pdf_is_whitespace_byte(byte.to_int()) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_text_cmap_without_whitespace(data : BytesView) -> @core.PdfBytes {
  let output : Array[Byte] = Array::new(capacity=data.length())
  for byte in data {
    if !@core.pdf_is_whitespace_byte(byte.to_int()) {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
let pdf_text_cmap_split_begin_marker : @core.PdfBytes = b"begin"

///|
let pdf_text_cmap_split_end_marker : @core.PdfBytes = b"end"

///|
let pdf_text_cmap_split_suffixes : ReadOnlyArray[@core.PdfBytes] = [
  b"bfchar", b"bfrange", b"cidchar", b"cidrange", b"notdefchar", b"notdefrange",
  b"codespacerange",
]

///|
fn pdf_text_cmap_has_split_marker_at(
  data : BytesView,
  start : Int,
  prefix : BytesView,
) -> Bool {
  guard start >= 0 && start <= data.length() else { return false }
  guard data[start:].chop_prefix(prefix) is Some(rest) else { return false }
  let suffix_start = pdf_text_skip_cmap_whitespace(rest, 0)
  guard suffix_start > 0 else { return false }
  for suffix in pdf_text_cmap_split_suffixes {
    if rest[suffix_start:].has_prefix(suffix) {
      return true
    }
  }
  false
}

///|
fn pdf_text_cmap_has_split_marker(data : BytesView) -> Bool {
  for index in 0..<data.length() {
    if pdf_text_cmap_has_split_marker_at(
        data, index, pdf_text_cmap_split_begin_marker,
      ) ||
      pdf_text_cmap_has_split_marker_at(
        data, index, pdf_text_cmap_split_end_marker,
      ) {
      return true
    }
  }
  false
}
