///|
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
