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
/// `@core.PdfError::EndOfInput` if the marker is not found before EOF.
pub fn pdf_cursor_read_jpeg_data(
  cursor : @core.ByteCursor,
) -> @core.PdfBytes raise @core.PdfError {
  match pdf_jpeg_eoi_length(cursor.remaining_view()) {
    Some(length) => cursor.read_bytes(length)
    None => {
      let _ = cursor.read_view(cursor.remaining_length())
      raise EndOfInput
    }
  }
}

///|
/// Reads JPEG data from a cursor through the EOI marker.
pub fn pdf_get_jpeg_data(
  input : @core.ByteCursor,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_cursor_read_jpeg_data(input)
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
  error : @core.PdfError,
) -> Int raise @core.PdfError {
  match pdf_jpeg_get(data, index) {
    Some(value) => value
    None => raise error
  }
}

///|
fn pdf_jpeg_word_at(
  data : BytesView,
  index : Int,
  error : @core.PdfError,
) -> Int raise @core.PdfError {
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
fn pdf_jpeg_has_signature(
  data : BytesView,
  index : Int,
) -> Bool raise @core.PdfError {
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
fn pdf_jpeg_dimensions_inner(
  data : BytesView,
) -> (Int, Int) raise @core.PdfError {
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
/// Progressive JPEGs and JPEGs without SOF0 raise `@core.PdfError::JPEGDimensionsExpected`.
pub fn pdf_jpeg_dimensions_view(
  data : BytesView,
) -> (Int, Int) raise @core.PdfError {
  pdf_jpeg_dimensions_inner(data)
}

///|
/// Return the width and height of a baseline JFIF/Exif JPEG byte stream.
pub fn pdf_jpeg_dimensions(
  data : @core.PdfBytes,
) -> (Int, Int) raise @core.PdfError {
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
) -> (Int, Int) raise @core.PdfError {
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
) -> (Int, Int) raise @core.PdfError {
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
) -> (Int, Int) raise @core.PdfError {
  pdf_jpeg_backup_dimensions_inner(data)
}

///|
/// Return JPEG dimensions by scanning any SOF marker with width and height.
pub fn pdf_jpeg_backup_dimensions(
  data : @core.PdfBytes,
) -> (Int, Int) raise @core.PdfError {
  pdf_jpeg_backup_dimensions_view(data)
}

///|
/// What a JPEG's frame header and markers say of its samples.
pub(all) struct PdfJpegInfo {
  width : Int
  height : Int
  /// bits a sample (the frame's precision)
  bits : Int
  /// the components of a pixel (as a rule one is greyscale, three colour
  /// and four CMYK; what they are is the markers' and the decoder's to say)
  components : Int
  /// the identifier of each component, as the frame header has them
  /// (JFIF's are 1, 2 and 3; some writers name them: `R`, `G`, `B`)
  component_ids : Array[Int]
  /// whether it has a JFIF (APP0) marker, whose three components are YCbCr
  jfif : Bool
  /// the frame header's marker, which says how the image is coded: 0xC0
  /// baseline, 0xC1 extended sequential, 0xC2 progressive (the three PDF's
  /// DCTDecode has; progressive since PDF 1.3), 0xC3 and above lossless,
  /// differential or arithmetic
  frame : Int
  /// the colour transform of its Adobe (APP14) marker — 0 none (RGB, or
  /// CMYK), 1 YCbCr, 2 YCCK — or None without the marker. Adobe writes
  /// the samples of four components inverted.
  adobe_transform : Int?
  /// whether it is of hierarchical mode (a DHP marker before its frames):
  /// frames of several sizes, the first not the image's
  hierarchical : Bool
}

///|
/// What a JPEG's first frame header (any SOF marker) says of its size and
/// samples, and its Adobe marker's colour transform when one comes before
/// its scan. Unlike `pdf_jpeg_dimensions_view` it asks for no JFIF or Exif
/// header and takes any frame. Raises `BadJPEGHeader` for data that does not
/// start a JPEG and `JPEGDimensionsExpected` without a frame header.
pub fn pdf_jpeg_info_view(data : BytesView) -> PdfJpegInfo raise @core.PdfError {
  if data.length() < 2 || data[0].to_int() != 0xFF || data[1].to_int() != 0xD8 {
    raise BadJPEGHeader
  }
  let mut frame : (Int, Int, Int, Int, Int)? = None
  let component_ids : Array[Int] = []
  let mut jfif = false
  let mut adobe_transform : Int? = None
  let mut hierarchical = false
  let mut index = 2
  while index < data.length() {
    let (marker, segment_start) = pdf_jpeg_next_marker(data, index) catch {
      // (markers run out: what was found stands)
      _ => break
    }
    // the scan, or the end of the image: the markers are done
    if marker == 0xDA || marker == 0xD9 {
      break
    }
    if pdf_jpeg_marker_without_segment_length(marker) {
      index = segment_start
      continue
    }
    let segment_length = pdf_jpeg_word_at(
      data,
      segment_start,
      JPEGDimensionsExpected,
    )
    if segment_length < 2 {
      raise InvalidJPEGBlock
    }
    if segment_length > data.length() - segment_start {
      raise JPEGDimensionsExpected
    }
    if marker == 0xDE {
      hierarchical = true
    }
    if marker == 0xE0 &&
      // (JFIF's header whole, as libjpeg asks: its name and 9 bytes more)
      segment_length >= 16 &&
      data[segment_start + 2:segment_start + 7] == b"JFIF\x00" {
      jfif = true
    }
    if frame is None && pdf_jpeg_marker_has_dimensions(marker) {
      if segment_length < 8 {
        raise JPEGDimensionsExpected
      }
      frame = Some(
        (
          marker,
          data[segment_start + 2].to_int(),
          pdf_jpeg_word_at(data, segment_start + 3, JPEGDimensionsExpected),
          pdf_jpeg_word_at(data, segment_start + 5, JPEGDimensionsExpected),
          data[segment_start + 7].to_int(),
        ),
      )
      // (the identifiers the segment has room for)
      for index in 0..<data[segment_start + 7].to_int() {
        let at = segment_start + 8 + 3 * index
        if at >= segment_start + segment_length {
          break
        }
        component_ids.push(data[at].to_int())
      }
    } else if marker == 0xEE &&
      // (Adobe's marker whole: its name, version, flags and transform)
      segment_length >= 14 &&
      data[segment_start + 2:segment_start + 7] == b"Adobe" {
      adobe_transform = Some(data[segment_start + 13].to_int())
    }
    index = segment_start + segment_length
  }
  guard frame is Some((marker, bits, height, width, components)) else {
    raise JPEGDimensionsExpected
  }
  {
    width,
    height,
    bits,
    components,
    component_ids,
    jfif,
    frame: marker,
    adobe_transform,
    hierarchical,
  }
}
