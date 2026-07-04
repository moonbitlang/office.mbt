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
) -> Int raise @core.PdfError {
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
) -> @core.PdfBytes raise @core.PdfError {
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
