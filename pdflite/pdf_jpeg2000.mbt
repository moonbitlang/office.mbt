///|
let pdf_jpeg2000_signature_length : UInt = 0x0000000CU

///|
let pdf_jpeg2000_signature_type : UInt = 0x6A502020U

///|
let pdf_jpeg2000_signature_magic : UInt = 0x0D0A870AU

///|
let pdf_jpeg2000_image_header_box : UInt = 0x69686472U

///|
fn ByteCursor::read_u32_be(self : ByteCursor) -> UInt raise PdfError {
  let a = match self.read_byte() {
    Some(byte) => byte.to_uint()
    None => raise EndOfInput
  }
  let b = match self.read_byte() {
    Some(byte) => byte.to_uint()
    None => raise EndOfInput
  }
  let c = match self.read_byte() {
    Some(byte) => byte.to_uint()
    None => raise EndOfInput
  }
  let d = match self.read_byte() {
    Some(byte) => byte.to_uint()
    None => raise EndOfInput
  }
  (a << 24) | (b << 16) | (c << 8) | d
}

///|
fn pdf_jpeg2000_dimension_word_to_int(value : UInt) -> Int {
  value.to_int64().to_int()
}

///|
fn ByteCursor::jpeg2000_dimensions_inner(
  self : ByteCursor,
) -> (Int, Int) raise PdfError {
  let signature_length = self.read_u32_be() catch {
    EndOfInput => raise BadJPEG2000Header
    error => raise error
  }
  let signature_type = self.read_u32_be() catch {
    EndOfInput => raise BadJPEG2000Header
    error => raise error
  }
  let signature_magic = self.read_u32_be() catch {
    EndOfInput => raise BadJPEG2000Header
    error => raise error
  }
  if signature_length != pdf_jpeg2000_signature_length ||
    signature_type != pdf_jpeg2000_signature_type ||
    signature_magic != pdf_jpeg2000_signature_magic {
    raise BadJPEG2000Header
  }
  while true {
    let box = self.read_u32_be() catch {
      EndOfInput => raise JPEG2000DimensionsExpected
      error => raise error
    }
    if box == pdf_jpeg2000_image_header_box {
      let height : UInt = self.read_u32_be() catch {
        EndOfInput => raise JPEG2000DimensionsExpected
        error => raise error
      }
      let width : UInt = self.read_u32_be() catch {
        EndOfInput => raise JPEG2000DimensionsExpected
        error => raise error
      }
      return (
        pdf_jpeg2000_dimension_word_to_int(width),
        pdf_jpeg2000_dimension_word_to_int(height),
      )
    }
    self.seek(self.position() - 3) catch {
      _ => raise JPEG2000DimensionsExpected
    }
  }
  raise JPEG2000DimensionsExpected
}

///|
/// Return the width and height of a JPEG2000 JP2/JPX byte stream.
///
/// The scan follows cpdf's byte-by-byte search for the `ihdr` image header box.
pub fn pdf_jpeg2000_dimensions_view(
  data : BytesView,
) -> (Int, Int) raise PdfError {
  byte_cursor_of_view(data, source="jpeg2000").jpeg2000_dimensions_inner()
}

///|
/// Return the width and height of a JPEG2000 JP2/JPX byte stream.
pub fn pdf_jpeg2000_dimensions(data : PdfBytes) -> (Int, Int) raise PdfError {
  pdf_jpeg2000_dimensions_view(data)
}
