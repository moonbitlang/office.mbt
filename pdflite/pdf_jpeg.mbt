///|
fn pdf_jpeg_eoi_length(data : BytesView) -> Int? {
  let mut last = 0
  for index in 0..<data.length() {
    let value = data[index].to_int()
    if value == 0xD9 && last == 0xFF {
      return Some(index + 1)
    }
    last = value
  }
  None
}

///|
/// Reads JPEG data from the current cursor position through the EOI marker.
///
/// The returned bytes include the terminal `0xFF 0xD9` marker. Raises
/// `PdfError::EndOfInput` if the marker is not found before EOF.
pub fn ByteCursor::read_jpeg_data(self : ByteCursor) -> PdfBytes raise PdfError {
  match pdf_jpeg_eoi_length(self.remaining_view()) {
    Some(length) => self.read_bytes(length)
    None => {
      let _ = self.read_view(self.remaining_length())
      raise EndOfInput
    }
  }
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

///|
fn pdf_jpeg_marker_without_segment_length(marker : Int) -> Bool {
  marker == 0x01 || (marker >= 0xD0 && marker <= 0xD9)
}

///|
fn pdf_jpeg_marker_has_dimensions(marker : Int) -> Bool {
  match marker {
    0xC0
    | 0xC1
    | 0xC2
    | 0xC3
    | 0xC5
    | 0xC6
    | 0xC7
    | 0xC9
    | 0xCA
    | 0xCB
    | 0xCD
    | 0xCE
    | 0xCF => true
    _ => false
  }
}

///|
fn pdf_jpeg_next_marker(
  data : BytesView,
  index : Int,
) -> (Int, Int) raise PdfError {
  let mut cursor = index
  while cursor < data.length() && data[cursor].to_int() != 0xFF {
    cursor += 1
  }
  if cursor >= data.length() {
    raise JPEGDimensionsExpected
  }
  while cursor < data.length() && data[cursor].to_int() == 0xFF {
    cursor += 1
  }
  if cursor >= data.length() {
    raise JPEGDimensionsExpected
  }
  (data[cursor].to_int(), cursor + 1)
}

///|
fn pdf_jpeg_backup_dimensions_inner(
  data : BytesView,
) -> (Int, Int) raise PdfError {
  if data.length() < 2 || data[0].to_int() != 0xFF || data[1].to_int() != 0xD8 {
    raise BadJPEGHeader
  }
  let mut index = 2
  while index < data.length() {
    let (marker, segment_start) = pdf_jpeg_next_marker(data, index)
    if marker == 0xD9 {
      raise JPEGDimensionsExpected
    }
    if pdf_jpeg_marker_without_segment_length(marker) {
      index = segment_start
    } else {
      let segment_length = pdf_jpeg_word_at(
        data,
        segment_start,
        JPEGDimensionsExpected,
      )
      if segment_length < 2 {
        raise InvalidJPEGBlock
      }
      if segment_start + segment_length > data.length() {
        raise JPEGDimensionsExpected
      }
      if pdf_jpeg_marker_has_dimensions(marker) {
        if segment_length < 7 {
          raise JPEGDimensionsExpected
        }
        let height = pdf_jpeg_word_at(
          data,
          segment_start + 3,
          JPEGDimensionsExpected,
        )
        let width = pdf_jpeg_word_at(
          data,
          segment_start + 5,
          JPEGDimensionsExpected,
        )
        return (width, height)
      }
      index = segment_start + segment_length
    }
  }
  raise JPEGDimensionsExpected
}

///|
/// Return JPEG dimensions by scanning any SOF marker with width and height.
///
/// This is the pure byte parser used by the cpdfjpeg `backup_jpeg_dimensions`
/// file wrapper. It accepts progressive JPEG SOF2 data that cpdf's primary
/// `jpeg_dimensions` parser rejects.
pub fn pdf_jpeg_backup_dimensions_view(
  data : BytesView,
) -> (Int, Int) raise PdfError {
  pdf_jpeg_backup_dimensions_inner(data)
}

///|
/// Return JPEG dimensions by scanning any SOF marker with width and height.
pub fn pdf_jpeg_backup_dimensions(data : PdfBytes) -> (Int, Int) raise PdfError {
  pdf_jpeg_backup_dimensions_view(data)
}
