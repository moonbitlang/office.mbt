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

///|
fn pdf_jpeg_get(data : BytesView, index : Int) -> Int? {
  if index >= 0 && index < data.length() {
    Some(data[index].to_int())
  } else {
    None
  }
}

///|
fn pdf_jpeg_get_or(
  data : BytesView,
  index : Int,
  error : PdfError,
) -> Int raise PdfError {
  match pdf_jpeg_get(data, index) {
    Some(value) => value
    None => raise error
  }
}

///|
fn pdf_jpeg_word_at(
  data : BytesView,
  index : Int,
  error : PdfError,
) -> Int raise PdfError {
  pdf_jpeg_get_or(data, index, error) * 256 +
  pdf_jpeg_get_or(data, index + 1, error)
}

///|
fn pdf_jpeg_has_app_header(data : BytesView) -> Bool {
  data.length() >= 4 &&
  data[0].to_int() == 0xFF &&
  data[1].to_int() == 0xD8 &&
  data[2].to_int() == 0xFF &&
  (data[3].to_int() == 0xE0 || data[3].to_int() == 0xE1)
}

///|
fn pdf_jpeg_has_signature(data : BytesView, index : Int) -> Bool raise PdfError {
  let first = pdf_jpeg_get_or(data, index + 2, BadJPEGString)
  let second = pdf_jpeg_get_or(data, index + 3, BadJPEGString)
  let third = pdf_jpeg_get_or(data, index + 4, BadJPEGString)
  let fourth = pdf_jpeg_get_or(data, index + 5, BadJPEGString)
  let zero = pdf_jpeg_get_or(data, index + 6, BadJPEGString)
  (
    first == 0x4A &&
    second == 0x46 &&
    third == 0x49 &&
    fourth == 0x46 &&
    zero == 0
  ) ||
  (
    first == 0x45 &&
    second == 0x78 &&
    third == 0x69 &&
    fourth == 0x66 &&
    zero == 0
  )
}

///|
fn pdf_jpeg_dimensions_inner(data : BytesView) -> (Int, Int) raise PdfError {
  if !pdf_jpeg_has_app_header(data) {
    raise BadJPEGHeader
  }
  let mut index = 4
  if !pdf_jpeg_has_signature(data, index) {
    raise BadJPEGString
  }
  let mut block_length = pdf_jpeg_word_at(data, index, JPEGDimensionsExpected)
  while index < data.length() {
    index += block_length
    if index >= data.length() {
      raise JPEGDimensionsExpected
    }
    if pdf_jpeg_get_or(data, index, JPEGDimensionsExpected) != 0xFF {
      raise InvalidJPEGBlock
    }
    if pdf_jpeg_get_or(data, index + 1, JPEGDimensionsExpected) == 0xC0 {
      let height = pdf_jpeg_word_at(data, index + 5, JPEGDimensionsExpected)
      let width = pdf_jpeg_word_at(data, index + 7, JPEGDimensionsExpected)
      return (width, height)
    }
    index += 2
    block_length = pdf_jpeg_word_at(data, index, JPEGDimensionsExpected)
  }
  raise JPEGDimensionsExpected
}

///|
/// Return the width and height of a baseline JFIF/Exif JPEG byte stream.
///
/// This matches cpdf's parser: the image must start with SOI plus APP0/APP1
/// JFIF or Exif metadata, and dimensions are read from the first SOF0 block.
/// Progressive JPEGs and JPEGs without SOF0 raise `PdfError::JPEGDimensionsExpected`.
pub fn pdf_jpeg_dimensions_view(data : BytesView) -> (Int, Int) raise PdfError {
  pdf_jpeg_dimensions_inner(data)
}

///|
/// Return the width and height of a baseline JFIF/Exif JPEG byte stream.
pub fn pdf_jpeg_dimensions(data : PdfBytes) -> (Int, Int) raise PdfError {
  pdf_jpeg_dimensions_view(data)
}
