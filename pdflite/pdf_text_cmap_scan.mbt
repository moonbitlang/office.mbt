///|
fn pdf_text_hex_digit_value(byte : Byte) -> Int? {
  let value = byte.to_int()
  if value >= 48 && value <= 57 {
    Some(value - 48)
  } else if value >= 65 && value <= 70 {
    Some(value - 55)
  } else if value >= 97 && value <= 102 {
    Some(value - 87)
  } else {
    None
  }
}

///|
fn pdf_text_parse_hex_bytes(
  line : BytesView,
  start : Int,
  stop : Int,
) -> PdfBytes? {
  guard stop >= start else { return None }
  let mut digit_count = 0
  let mut scan = start
  while scan < stop {
    let value = line[scan].to_int()
    if pdf_is_whitespace_byte(value) {
      ()
    } else {
      match pdf_text_hex_digit_value(line[scan]) {
        Some(_) => digit_count += 1
        None => return None
      }
    }
    scan += 1
  }
  let output = Array::make((digit_count + 1) / 2, b'\x00')
  let mut high : Int? = None
  let mut position = 0
  let mut index = start
  while index < stop {
    let value = line[index].to_int()
    if pdf_is_whitespace_byte(value) {
      ()
    } else {
      match pdf_text_hex_digit_value(line[index]) {
        Some(nibble) =>
          match high {
            Some(high_nibble) => {
              output[position] = (high_nibble * 16 + nibble).to_byte()
              position += 1
              high = None
            }
            None => high = Some(nibble)
          }
        None => ()
      }
    }
    index += 1
  }
  if high is Some(high_nibble) {
    output[position] = (high_nibble * 16).to_byte()
  }
  Some(Bytes::from_array(output))
}

///|
fn pdf_text_skip_cmap_whitespace(line : BytesView, start : Int) -> Int {
  let mut index = start
  while index < line.length() && pdf_is_whitespace_byte(line[index].to_int()) {
    index += 1
  }
  index
}

///|
fn pdf_text_line_contains_ascii(line : BytesView, word : String) -> Bool {
  pdf_text_index_of_ascii(line, word) != None
}

///|
fn pdf_text_index_of_ascii(line : BytesView, word : String) -> Int? {
  let needle = @ascii.encode(word)
  guard needle.length() > 0 && line.length() >= needle.length() else {
    return None
  }
  for index in 0..<=(line.length() - needle.length()) {
    let mut matched = true
    for offset in 0..<needle.length() {
      if line[index + offset] != needle[offset] {
        matched = false
      }
    }
    if matched {
      break Some(index)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_text_index_of_ascii_from(
  line : BytesView,
  word : String,
  start : Int,
) -> Int? {
  guard start < line.length() else { return None }
  match pdf_text_index_of_ascii(line[start:], word) {
    Some(index) => Some(start + index)
    None => None
  }
}

///|
fn pdf_text_after_ascii(line : BytesView, word : String) -> BytesView? {
  match pdf_text_index_of_ascii(line, word) {
    Some(index) => {
      let word_length = @ascii.encode(word).length()
      Some(line[index + word_length:])
    }
    None => None
  }
}

///|
fn pdf_text_view_equals_ascii(view : BytesView, text : String) -> Bool {
  let expected = @ascii.encode(text)
  guard view.length() == expected.length() else { return false }
  for index in 0..<view.length() {
    if view[index] != expected[index] {
      break false
    }
  } nobreak {
    true
  }
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
      Some(index) => {
        let length = @ascii.encode(marker).length()
        match best {
          Some((best_index, _)) if best_index <= index => ()
          _ => best = Some((index, length))
        }
      }
      None => ()
    }
  }
  best
}

///|
fn pdf_text_cmap_section_line_views(line : BytesView) -> Array[BytesView] {
  let views : Array[BytesView] = Array::new(capacity=line.length())
  let mut start = 0
  while start < line.length() {
    match pdf_text_cmap_end_marker(line, start) {
      Some((index, length)) => {
        let stop = index + length
        views.push(line[start:stop])
        start = stop
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
  let mut in_literal = false
  let mut escaped = false
  let mut literal_depth = 0
  for index in 0..<line.length() {
    let value = line[index].to_int()
    if in_literal {
      if escaped {
        escaped = false
      } else if value == 92 {
        escaped = true
      } else if value == 40 {
        literal_depth += 1
      } else if value == 41 {
        literal_depth -= 1
        if literal_depth <= 0 {
          in_literal = false
          literal_depth = 0
        }
      }
    } else if value == 37 {
      return index
    } else if value == 40 {
      in_literal = true
      literal_depth = 1
      escaped = false
    }
  }
  line.length()
}

///|
fn pdf_text_cmap_line_without_comment(line : BytesView) -> PdfBytes {
  let stop = pdf_text_cmap_comment_start(line)
  let output = Array::make(stop, b'\x00')
  for index in 0..<stop {
    output[index] = line[index]
  }
  Bytes::from_array(output)
}

///|
fn pdf_text_parse_cmap_hex_groups(line : BytesView) -> Array[PdfBytes]? {
  let groups : Array[PdfBytes] = Array::new(capacity=line.length() / 2)
  let mut index = 0
  while index < line.length() {
    index = pdf_text_skip_cmap_whitespace(line, index)
    if index >= line.length() {
      break
    }
    if line[index].to_int() != 60 {
      break
    }
    let start = index + 1
    let mut stop = start
    while stop < line.length() && line[stop].to_int() != 62 {
      stop += 1
    }
    guard stop < line.length() else { return None }
    match pdf_text_parse_hex_bytes(line, start, stop) {
      Some(bytes) => groups.push(bytes)
      None => return None
    }
    index = stop + 1
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
) -> (PdfBytes, Int)? {
  let index = pdf_text_skip_cmap_whitespace(line, start)
  guard index < line.length() && line[index].to_int() == 60 else { return None }
  let body_start = index + 1
  let mut stop = body_start
  while stop < line.length() && line[stop].to_int() != 62 {
    stop += 1
  }
  guard stop < line.length() else { return None }
  match pdf_text_parse_hex_bytes(line, body_start, stop) {
    Some(bytes) => Some((bytes, stop + 1))
    None => None
  }
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
  let mut stop = index
  if line[stop].to_int() == 43 || line[stop].to_int() == 45 {
    stop += 1
  }
  let digit_start = stop
  while stop < line.length() {
    let value = line[stop].to_int()
    if value >= 48 && value <= 57 {
      stop += 1
    } else {
      break
    }
  }
  guard stop > digit_start else { return None }
  try pdf_parse_ascii_int_view(line[index:stop]) catch {
    _ => None
  } noraise {
    value => Some((value, stop))
  }
}

///|
fn pdf_text_index_of_byte(line : BytesView, target : Int, start : Int) -> Int? {
  let mut index = start
  while index < line.length() {
    if line[index].to_int() == target {
      break Some(index)
    }
    index += 1
  } nobreak {
    None
  }
}

///|
fn pdf_text_cmap_contains_whitespace(data : BytesView) -> Bool {
  for byte in data {
    if pdf_is_whitespace_byte(byte.to_int()) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_text_cmap_without_whitespace(data : BytesView) -> PdfBytes {
  let mut length = 0
  for byte in data {
    if !pdf_is_whitespace_byte(byte.to_int()) {
      length += 1
    }
  }
  let output = Array::make(length, b'\x00')
  let mut position = 0
  for byte in data {
    if !pdf_is_whitespace_byte(byte.to_int()) {
      output[position] = byte
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
let pdf_text_cmap_split_begin_marker : PdfBytes = b"begin"

///|
let pdf_text_cmap_split_end_marker : PdfBytes = b"end"

///|
let pdf_text_cmap_split_suffixes : ReadOnlyArray[PdfBytes] = [
  b"bfchar", b"bfrange", b"cidchar", b"cidrange", b"notdefchar", b"notdefrange",
  b"codespacerange",
]

///|
fn pdf_text_cmap_starts_with_at(
  data : BytesView,
  start : Int,
  expected : BytesView,
) -> Bool {
  if start < 0 || start + expected.length() > data.length() {
    false
  } else {
    for offset in 0..<expected.length() {
      if data[start + offset] != expected[offset] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_text_cmap_has_split_marker_at(
  data : BytesView,
  start : Int,
  prefix : BytesView,
) -> Bool {
  guard pdf_text_cmap_starts_with_at(data, start, prefix) else { return false }
  let whitespace_start = start + prefix.length()
  let mut suffix_start = whitespace_start
  while suffix_start < data.length() &&
        pdf_is_whitespace_byte(data[suffix_start].to_int()) {
    suffix_start += 1
  }
  guard suffix_start > whitespace_start else { return false }
  for suffix in pdf_text_cmap_split_suffixes {
    if pdf_text_cmap_starts_with_at(data, suffix_start, suffix) {
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
