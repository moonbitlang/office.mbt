///|
/// Reads JPEG data from the current cursor position through the EOI marker.
///
/// The returned bytes include the terminal `0xFF 0xD9` marker. Raises
/// `PdfError::EndOfInput` if the marker is not found before EOF.
pub fn ByteCursor::read_jpeg_data(self : ByteCursor) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  let mut last = 0
  let mut done = false
  while !done {
    match self.read_byte() {
      Some(byte) => {
        let value = byte.to_int()
        output.push(byte)
        if value == 0xD9 && last == 0xFF {
          done = true
        } else {
          last = value
        }
      }
      None => raise EndOfInput
    }
  }
  Bytes::from_array(output)
}

///|
/// Reads JPEG data from a cursor through the EOI marker.
///
/// This is the standalone form of `ByteCursor::read_jpeg_data`.
pub fn pdf_get_jpeg_data(input : ByteCursor) -> PdfBytes raise PdfError {
  input.read_jpeg_data()
}
