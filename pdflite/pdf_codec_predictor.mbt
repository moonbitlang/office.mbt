///|
fn pdf_predictor_scanline_width(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
) -> Int raise PdfError {
  if colors <= 0 || bits_per_component <= 0 || columns <= 0 {
    raise PredictorExpected
  }
  (colors * bits_per_component * columns + 7) / 8
}

///|
fn pdf_predictor_bytes_per_pixel(
  colors : Int,
  bits_per_component : Int,
) -> Int raise PdfError {
  if colors <= 0 || bits_per_component <= 0 {
    raise PredictorExpected
  }
  (colors * bits_per_component + 7) / 8
}

///|
fn pdf_predictor_get0(values : ArrayView[Int], index : Int) -> Int {
  if index < 0 {
    0
  } else {
    values[index]
  }
}

///|
fn pdf_predictor_wrapping_byte(value : Int) -> Byte {
  let remainder = value % 256
  if remainder < 0 {
    (remainder + 256).to_byte()
  } else {
    remainder.to_byte()
  }
}

///|
fn pdf_paeth_predictor(a : Int, b : Int, c : Int) -> Int {
  let p = a + b - c
  let pa = (p - a).abs()
  let pb = (p - b).abs()
  let pc = (p - c).abs()
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}

///|
fn pdf_decode_tiff_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  if bits_per_component != 8 {
    raise PredictorNotSupported(2)
  }
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let output : Array[Byte] = [ for byte in data => byte ]
  for line in 0..<(data.length() / scanline_width) {
    let line_start = line * scanline_width
    let mut position = colors
    while position < scanline_width {
      let index = line_start + position
      output[index] = ((
        output[index - colors].to_int() + output[index].to_int()
      ) %
      256).to_byte()
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_encode_tiff_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  if bits_per_component != 8 {
    raise PredictorNotSupported(2)
  }
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let output : Array[Byte] = [ for byte in data => byte ]
  for line in 0..<(data.length() / scanline_width) {
    let line_start = line * scanline_width
    let mut position = colors
    while position < scanline_width {
      let index = line_start + position
      output[index] = pdf_predictor_wrapping_byte(
        data[index].to_int() - data[index - colors].to_int(),
      )
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_decode_png_current(
  data : BytesView,
  row_start : Int,
  available : Int,
  index : Int,
) -> Int {
  if index < available {
    data[row_start + index].to_int()
  } else {
    0
  }
}

///|
fn pdf_decode_png_decoded_length(data : BytesView, scanline_width : Int) -> Int {
  let mut rows = 0
  let mut index = 0
  while index < data.length() {
    rows += 1
    index += 1
    let available = if index + scanline_width > data.length() {
      data.length() - index
    } else {
      scanline_width
    }
    index += available
  }
  rows * scanline_width
}

///|
fn pdf_decode_png_push_scanline(
  output : Array[Byte],
  position : Int,
  predictor : Int,
  prior_decoded : ArrayView[Int],
  decoded : Array[Int],
  data : BytesView,
  row_start : Int,
  available : Int,
  bytes_per_pixel : Int,
) -> Int raise PdfError {
  let scanline_width = decoded.length()
  let mut output_position = position
  match predictor {
    0 =>
      for i in 0..<scanline_width {
        decoded[i] = pdf_decode_png_current(data, row_start, available, i)
        output[output_position] = decoded[i].to_byte()
        output_position += 1
      }
    1 =>
      for i in 0..<scanline_width {
        let current = pdf_decode_png_current(data, row_start, available, i)
        decoded[i] = (
            current + pdf_predictor_get0(decoded, i - bytes_per_pixel)
          ) %
          256
        output[output_position] = decoded[i].to_byte()
        output_position += 1
      }
    2 =>
      for i in 0..<scanline_width {
        let current = pdf_decode_png_current(data, row_start, available, i)
        decoded[i] = (current + pdf_predictor_get0(prior_decoded, i)) % 256
        output[output_position] = decoded[i].to_byte()
        output_position += 1
      }
    3 =>
      for i in 0..<scanline_width {
        let current = pdf_decode_png_current(data, row_start, available, i)
        decoded[i] = (
            current +
            (
              pdf_predictor_get0(decoded, i - bytes_per_pixel) +
              pdf_predictor_get0(prior_decoded, i)
            ) /
            2
          ) %
          256
        output[output_position] = decoded[i].to_byte()
        output_position += 1
      }
    4 =>
      for i in 0..<scanline_width {
        let current = pdf_decode_png_current(data, row_start, available, i)
        let left = pdf_predictor_get0(decoded, i - bytes_per_pixel)
        let up = pdf_predictor_get0(prior_decoded, i)
        let up_left = pdf_predictor_get0(prior_decoded, i - bytes_per_pixel)
        decoded[i] = (current + pdf_paeth_predictor(left, up, up_left)) % 256
        output[output_position] = decoded[i].to_byte()
        output_position += 1
      }
    _ => raise PredictorNotSupported(predictor)
  }
  output_position
}

///|
fn pdf_decode_png_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let bytes_per_pixel = pdf_predictor_bytes_per_pixel(
    colors, bits_per_component,
  )
  let output = Array::make(
    pdf_decode_png_decoded_length(data, scanline_width),
    b'\x00',
  )
  let mut position = 0
  let mut prior_decoded : Array[Int] = [ for _ in 0..<scanline_width => 0 ]
  let mut decoded : Array[Int] = [ for _ in 0..<scanline_width => 0 ]
  let mut index = 0
  while index < data.length() {
    let predictor = data[index].to_int()
    index += 1
    let available = if index + scanline_width > data.length() {
      data.length() - index
    } else {
      scanline_width
    }
    let row_start = index
    index += available
    position = pdf_decode_png_push_scanline(
      output, position, predictor, prior_decoded, decoded, data, row_start, available,
      bytes_per_pixel,
    )
    let previous = prior_decoded
    prior_decoded = decoded
    decoded = previous
  }
  Bytes::from_array(output[:position])
}

///|
/// Decode data after applying a PDF predictor.
///
/// Predictor `1` is identity, `2` is TIFF horizontal differencing, and
/// `10..15` are PNG predictors. Invalid image geometry or unsupported
/// predictors raise `PdfError`.
pub fn pdf_decode_predictor_view(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  match predictor {
    1 => data.to_owned()
    2 => pdf_decode_tiff_predictor(colors, bits_per_component, columns, data)
    value if value >= 10 && value <= 15 =>
      pdf_decode_png_predictor(colors, bits_per_component, columns, data)
    _ => raise PredictorNotSupported(predictor)
  }
}

///|
/// Owned-byte wrapper for `pdf_decode_predictor_view`.
///
/// Predictor `1` returns the original owned bytes unchanged.
pub fn pdf_decode_predictor(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if predictor == 1 {
    data
  } else {
    pdf_decode_predictor_view(
      predictor, colors, bits_per_component, columns, data,
    )
  }
}

///|
fn pdf_encode_png_encoded_length(data : BytesView, scanline_width : Int) -> Int {
  data.length() / scanline_width * (scanline_width + 1)
}

///|
fn pdf_encode_png_sub_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let bytes_per_pixel = pdf_predictor_bytes_per_pixel(
    colors, bits_per_component,
  )
  let output = Array::make(
    pdf_encode_png_encoded_length(data, scanline_width),
    b'\x00',
  )
  let mut position = 0
  for row in 0..<(data.length() / scanline_width) {
    position = pdf_encode_png_push_scanline(
      output,
      position,
      1,
      data,
      row * scanline_width,
      scanline_width,
      bytes_per_pixel,
    )
  }
  Bytes::from_array(output[:position])
}

///|
fn pdf_encode_png_up_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let bytes_per_pixel = pdf_predictor_bytes_per_pixel(
    colors, bits_per_component,
  )
  let output = Array::make(
    pdf_encode_png_encoded_length(data, scanline_width),
    b'\x00',
  )
  let mut position = 0
  for row in 0..<(data.length() / scanline_width) {
    position = pdf_encode_png_push_scanline(
      output,
      position,
      2,
      data,
      row * scanline_width,
      scanline_width,
      bytes_per_pixel,
    )
  }
  Bytes::from_array(output[:position])
}

///|
fn pdf_encode_png_predictor_value(
  predictor : Int,
  data : BytesView,
  row_start : Int,
  index : Int,
  scanline_width : Int,
  bytes_per_pixel : Int,
) -> Int raise PdfError {
  let left = if index < bytes_per_pixel {
    0
  } else {
    data[row_start + index - bytes_per_pixel].to_int()
  }
  let up = if row_start < scanline_width {
    0
  } else {
    data[row_start - scanline_width + index].to_int()
  }
  let up_left = if row_start < scanline_width || index < bytes_per_pixel {
    0
  } else {
    data[row_start - scanline_width + index - bytes_per_pixel].to_int()
  }
  match predictor {
    0 => 0
    1 => left
    2 => up
    3 => (left + up) / 2
    4 => pdf_paeth_predictor(left, up, up_left)
    _ => raise PredictorNotSupported(predictor)
  }
}

///|
fn pdf_encode_png_push_scanline(
  output : Array[Byte],
  position : Int,
  predictor : Int,
  data : BytesView,
  row_start : Int,
  scanline_width : Int,
  bytes_per_pixel : Int,
) -> Int raise PdfError {
  let mut current = position
  output[current] = predictor.to_byte()
  current += 1
  for i in 0..<scanline_width {
    let predicted = pdf_encode_png_predictor_value(
      predictor, data, row_start, i, scanline_width, bytes_per_pixel,
    )
    output[current] = pdf_predictor_wrapping_byte(
      data[row_start + i].to_int() - predicted,
    )
    current += 1
  }
  current
}

///|
fn pdf_encode_png_predictor_score(
  predictor : Int,
  data : BytesView,
  row_start : Int,
  scanline_width : Int,
  bytes_per_pixel : Int,
) -> Int raise PdfError {
  let mut score = 0
  for i in 0..<scanline_width {
    let predicted = pdf_encode_png_predictor_value(
      predictor, data, row_start, i, scanline_width, bytes_per_pixel,
    )
    let value = pdf_predictor_wrapping_byte(
      data[row_start + i].to_int() - predicted,
    ).to_int()
    score += if value > 127 { 256 - value } else { value }
  }
  score
}

///|
fn pdf_encode_png_tagged_predictor(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let bytes_per_pixel = pdf_predictor_bytes_per_pixel(
    colors, bits_per_component,
  )
  let output = Array::make(
    pdf_encode_png_encoded_length(data, scanline_width),
    b'\x00',
  )
  let mut position = 0
  for row in 0..<(data.length() / scanline_width) {
    position = pdf_encode_png_push_scanline(
      output,
      position,
      predictor,
      data,
      row * scanline_width,
      scanline_width,
      bytes_per_pixel,
    )
  }
  Bytes::from_array(output[:position])
}

///|
fn pdf_encode_png_optimum_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let bytes_per_pixel = pdf_predictor_bytes_per_pixel(
    colors, bits_per_component,
  )
  let output = Array::make(
    pdf_encode_png_encoded_length(data, scanline_width),
    b'\x00',
  )
  let mut position = 0
  for row in 0..<(data.length() / scanline_width) {
    let row_start = row * scanline_width
    let mut best_predictor = 0
    let mut best_score = pdf_encode_png_predictor_score(
      0, data, row_start, scanline_width, bytes_per_pixel,
    )
    for predictor in 1..<=4 {
      let score = pdf_encode_png_predictor_score(
        predictor, data, row_start, scanline_width, bytes_per_pixel,
      )
      if score < best_score {
        best_predictor = predictor
        best_score = score
      }
    }
    position = pdf_encode_png_push_scanline(
      output, position, best_predictor, data, row_start, scanline_width, bytes_per_pixel,
    )
  }
  Bytes::from_array(output[:position])
}

///|
/// Encode data with a PDF predictor.
///
/// Predictor `1` is identity, `2` is TIFF horizontal differencing, `10..14`
/// use fixed PNG row filters, and `15` chooses the lowest-scoring PNG filter
/// per row.
pub fn pdf_encode_predictor_view(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  match predictor {
    1 => data.to_owned()
    2 => pdf_encode_tiff_predictor(colors, bits_per_component, columns, data)
    10 =>
      pdf_encode_png_tagged_predictor(
        0, colors, bits_per_component, columns, data,
      )
    11 =>
      pdf_encode_png_sub_predictor(colors, bits_per_component, columns, data)
    12 => pdf_encode_png_up_predictor(colors, bits_per_component, columns, data)
    13 =>
      pdf_encode_png_tagged_predictor(
        3, colors, bits_per_component, columns, data,
      )
    14 =>
      pdf_encode_png_tagged_predictor(
        4, colors, bits_per_component, columns, data,
      )
    15 =>
      pdf_encode_png_optimum_predictor(
        colors, bits_per_component, columns, data,
      )
    _ => raise PredictorNotSupported(predictor)
  }
}

///|
/// Owned-byte wrapper for `pdf_encode_predictor_view`.
///
/// Predictor `1` returns the original owned bytes unchanged.
pub fn pdf_encode_predictor(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if predictor == 1 {
    data
  } else {
    pdf_encode_predictor_view(
      predictor, colors, bits_per_component, columns, data,
    )
  }
}
