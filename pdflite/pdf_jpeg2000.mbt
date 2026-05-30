///|
let pdf_jpeg2000_signature_length : UInt = 0x0000000CU

///|
let pdf_jpeg2000_signature_type : UInt = 0x6A502020U

///|
let pdf_jpeg2000_signature_magic : UInt = 0x0D0A870AU

///|
let pdf_jpeg2000_image_header_box : UInt = 0x69686472U

///|
fn byte_cursor_read_u32_be(
  cursor : @core.ByteCursor,
) -> UInt raise @core.PdfError {
  let a = match cursor.read_byte() {
    Some(byte) => byte.to_uint()
    None => raise EndOfInput
  }
  let b = match cursor.read_byte() {
    Some(byte) => byte.to_uint()
    None => raise EndOfInput
  }
  let c = match cursor.read_byte() {
    Some(byte) => byte.to_uint()
    None => raise EndOfInput
  }
  let d = match cursor.read_byte() {
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
fn pdf_jpeg2000_dimensions_inner(
  cursor : @core.ByteCursor,
) -> (Int, Int) raise @core.PdfError {
  let signature_length = byte_cursor_read_u32_be(cursor) catch {
    EndOfInput => raise BadJPEG2000Header
    error => raise error
  }
  let signature_type = byte_cursor_read_u32_be(cursor) catch {
    EndOfInput => raise BadJPEG2000Header
    error => raise error
  }
  let signature_magic = byte_cursor_read_u32_be(cursor) catch {
    EndOfInput => raise BadJPEG2000Header
    error => raise error
  }
  if signature_length != pdf_jpeg2000_signature_length ||
    signature_type != pdf_jpeg2000_signature_type ||
    signature_magic != pdf_jpeg2000_signature_magic {
    raise BadJPEG2000Header
  }
  while true {
    let box = byte_cursor_read_u32_be(cursor) catch {
      EndOfInput => raise JPEG2000DimensionsExpected
      error => raise error
    }
    if box == pdf_jpeg2000_image_header_box {
      let height : UInt = byte_cursor_read_u32_be(cursor) catch {
        EndOfInput => raise JPEG2000DimensionsExpected
        error => raise error
      }
      let width : UInt = byte_cursor_read_u32_be(cursor) catch {
        EndOfInput => raise JPEG2000DimensionsExpected
        error => raise error
      }
      return (
        pdf_jpeg2000_dimension_word_to_int(width),
        pdf_jpeg2000_dimension_word_to_int(height),
      )
    }
    cursor.seek(cursor.position() - 3) catch {
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
) -> (Int, Int) raise @core.PdfError {
  pdf_jpeg2000_dimensions_inner(
    @core.byte_cursor_of_view(data, source="jpeg2000"),
  )
}

///|
/// Return the width and height of a JPEG2000 JP2/JPX byte stream.
pub fn pdf_jpeg2000_dimensions(
  data : @core.PdfBytes,
) -> (Int, Int) raise @core.PdfError {
  pdf_jpeg2000_dimensions_view(data)
}
