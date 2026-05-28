///|
fn pdf_bookmark_import_fixup_escape(value : Int) -> Byte? {
  match value {
    92 => Some((92).to_byte())
    34 => Some((34).to_byte())
    110 => Some((10).to_byte())
    _ => None
  }
}

///|
fn pdf_bookmark_import_fixup_text_length(text : BytesView) -> Int {
  let mut length = 0
  let mut index = 0
  while index < text.length() {
    if text[index].to_int() == 92 && index + 1 < text.length() {
      match pdf_bookmark_import_fixup_escape(text[index + 1].to_int()) {
        Some(_) => index += 2
        None => index += 1
      }
    } else {
      index += 1
    }
    length += 1
  }
  length
}

///|
fn pdf_bookmark_import_fixup_text(text : BytesView) -> PdfBytes {
  let output = Array::make(pdf_bookmark_import_fixup_text_length(text), b'\x00')
  let mut position = 0
  let mut index = 0
  while index < text.length() {
    if text[index].to_int() == 92 && index + 1 < text.length() {
      match pdf_bookmark_import_fixup_escape(text[index + 1].to_int()) {
        Some(byte) => {
          output[position] = byte
          index += 2
        }
        None => {
          output[position] = text[index]
          index += 1
        }
      }
    } else {
      output[position] = text[index]
      index += 1
    }
    position += 1
  }
  Bytes::from_array(output)
}
