///|
fn pdf_font_write_utf8(
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
fn pdf_font_utf8_length(text : String) -> Int {
  @utf8.encode(text).length()
}
