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
