///|
fn pdf_ua_ascii_length(text : String) -> Int {
  @ascii.encode(text).length()
}

///|
fn pdf_ua_utf8_length(text : String) -> Int {
  @utf8.encode(text).length()
}

///|
fn pdf_ua_xml_escaped_utf8_length(text : String) -> Int {
  let mut length = 0
  for byte in @utf8.encode(text) {
    length += match byte.to_int() {
      34 => pdf_ua_ascii_length("&quot;")
      38 => pdf_ua_ascii_length("&amp;")
      39 => pdf_ua_ascii_length("&apos;")
      60 => pdf_ua_ascii_length("&lt;")
      62 => pdf_ua_ascii_length("&gt;")
      _ => 1
    }
  }
  length
}

///|
fn pdf_ua_write_ascii(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  let mut current = position
  for byte in @ascii.encode(text) {
    output[current] = byte
    current += 1
  }
  current
}

///|
fn pdf_ua_write_utf8(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  let mut current = position
  for byte in @utf8.encode(text) {
    output[current] = byte
    current += 1
  }
  current
}

///|
fn pdf_ua_write_view(
  output : Array[Byte],
  position : Int,
  bytes : BytesView,
) -> Int {
  let mut position = position
  for byte in bytes {
    output[position] = byte
    position += 1
  }
  position
}

///|
fn pdf_ua_write_xml_escaped_utf8(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  let mut current = position
  for byte in @utf8.encode(text) {
    current = match byte.to_int() {
      34 => pdf_ua_write_ascii(output, current, "&quot;")
      38 => pdf_ua_write_ascii(output, current, "&amp;")
      39 => pdf_ua_write_ascii(output, current, "&apos;")
      60 => pdf_ua_write_ascii(output, current, "&lt;")
      62 => pdf_ua_write_ascii(output, current, "&gt;")
      _ => {
        output[current] = byte
        current + 1
      }
    }
  }
  current
}
