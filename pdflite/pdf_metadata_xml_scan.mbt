///|
fn pdf_metadata_is_xml_separator(byte : Byte) -> Bool {
  match byte.to_int() {
    9 | 10 | 13 | 32 | 60 => true
    _ => false
  }
}

///|
fn pdf_metadata_is_xml_space(byte : Byte) -> Bool {
  match byte.to_int() {
    9 | 10 | 13 | 32 => true
    _ => false
  }
}

///|
fn pdf_metadata_trim_xml_text(value : BytesView) -> BytesView {
  let mut start = 0
  let mut end = value.length()
  while start < end && pdf_metadata_is_xml_space(value[start]) {
    start += 1
  }
  while end > start && pdf_metadata_is_xml_space(value[end - 1]) {
    end -= 1
  }
  value[start:end]
}

///|
fn pdf_metadata_find_byte(data : BytesView, start : Int, byte : Int) -> Int {
  for position in start..<data.length() {
    if data[position].to_int() == byte {
      break position
    }
  } nobreak {
    -1
  }
}

///|
fn pdf_metadata_view_matches_at(
  data : BytesView,
  position : Int,
  pattern : BytesView,
) -> Bool {
  if position < 0 || position + pattern.length() > data.length() {
    false
  } else {
    for index in 0..<pattern.length() {
      if data[position + index] != pattern[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_metadata_find_bytes_from(
  data : BytesView,
  start : Int,
  pattern : BytesView,
) -> Int {
  if pattern.length() == 0 {
    start
  } else if data.length() < pattern.length() ||
    start > data.length() - pattern.length() {
    -1
  } else {
    for position in start..<=(data.length() - pattern.length()) {
      if pdf_metadata_view_matches_at(data, position, pattern) {
        break position
      }
    } nobreak {
      -1
    }
  }
}

///|
fn pdf_metadata_xml_tag_boundary(byte : Byte) -> Bool {
  match byte.to_int() {
    9 | 10 | 13 | 32 | 47 | 62 => true
    _ => false
  }
}
