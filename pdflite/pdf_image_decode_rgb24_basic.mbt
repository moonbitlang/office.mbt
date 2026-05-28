///|
fn pdf_image_cmyk_component(channel : Int, black : Int) -> Int {
  let channel = channel.to_double()
  let black = black.to_double()
  (255.0 - double_min(255.0, channel / 255.0 * (255.0 - black) + black)).to_int()
}

///|
fn pdf_image_rgb_of_cmyk(c : Int, m : Int, y : Int, k : Int) -> (Int, Int, Int) {
  (
    pdf_image_cmyk_component(c, k),
    pdf_image_cmyk_component(m, k),
    pdf_image_cmyk_component(y, k),
  )
}

///|
fn pdf_image_gray_8bpp_as_rgb24(
  width : Int,
  height : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let pixels = width * height
  pdf_image_require_size(data, pixels)
  let output = Array::make(pixels * 3, b'\x00')
  let mut position = 0
  for index in 0..<pixels {
    let value = data[index]
    output[position] = value
    output[position + 1] = value
    output[position + 2] = value
    position += 3
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_cmyk_8bpp_as_rgb24(
  width : Int,
  height : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let pixels = width * height
  pdf_image_require_size(data, pixels * 4)
  let output = Array::make(pixels * 3, b'\x00')
  let mut position = 0
  for index in 0..<pixels {
    let offset = index * 4
    let (red, green, blue) = pdf_image_rgb_of_cmyk(
      data[offset].to_int(),
      data[offset + 1].to_int(),
      data[offset + 2].to_int(),
      data[offset + 3].to_int(),
    )
    output[position] = pdf_byte_of_int(red)
    output[position + 1] = pdf_byte_of_int(green)
    output[position + 2] = pdf_byte_of_int(blue)
    position += 3
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_1bpp_as_rgb24(
  width : Int,
  height : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let bytes_per_row = (width + 7) / 8
  pdf_image_require_size(data, bytes_per_row * height)
  let output = Array::make(width * height * 3, b'\x00')
  let mut position = 0
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let byte = data[row_offset + column / 8].to_int()
      let bit = (byte >> (7 - column % 8)) & 1
      let value : Byte = if bit == 1 { 255 } else { 0 }
      output[position] = value
      output[position + 1] = value
      output[position + 2] = value
      position += 3
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_packed_bytes_per_row(width : Int, bits_per_component : Int) -> Int {
  let row_bits = width * bits_per_component
  if row_bits % 8 == 0 {
    row_bits / 8
  } else {
    row_bits / 8 + 1
  }
}

///|
fn pdf_image_packed_sample(
  data : BytesView,
  row_offset : Int,
  column : Int,
  bits_per_component : Int,
) -> Int {
  let bit_offset = column * bits_per_component
  let byte = data[row_offset + bit_offset / 8].to_int()
  let shift = 8 - bits_per_component - bit_offset % 8
  let mask = (1 << bits_per_component) - 1
  (byte >> shift) & mask
}

///|
fn pdf_image_gray_packed_bpp_as_rgb24(
  width : Int,
  height : Int,
  bits_per_component : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let bytes_per_row = pdf_image_packed_bytes_per_row(width, bits_per_component)
  pdf_image_require_size(data, bytes_per_row * height)
  let max_sample = (1 << bits_per_component) - 1
  let output = Array::make(width * height * 3, b'\x00')
  let mut position = 0
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let sample = pdf_image_packed_sample(
        data, row_offset, column, bits_per_component,
      )
      let value = (sample * 255 / max_sample).to_byte()
      output[position] = value
      output[position + 1] = value
      output[position + 2] = value
      position += 3
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_gray_2bpp_as_rgb24(
  width : Int,
  height : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_gray_packed_bpp_as_rgb24(width, height, 2, data)
}

///|
fn pdf_image_gray_4bpp_as_rgb24(
  width : Int,
  height : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_gray_packed_bpp_as_rgb24(width, height, 4, data)
}

///|
fn pdf_image_rgb_packed_bpp_as_rgb24(
  width : Int,
  height : Int,
  bits_per_component : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let samples_per_row = width * 3
  let bytes_per_row = pdf_image_packed_bytes_per_row(
    samples_per_row, bits_per_component,
  )
  pdf_image_require_size(data, bytes_per_row * height)
  let max_sample = (1 << bits_per_component) - 1
  let output = Array::make(width * height * 3, b'\x00')
  let mut position = 0
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      for component in 0..<3 {
        let sample = pdf_image_packed_sample(
          data,
          row_offset,
          column * 3 + component,
          bits_per_component,
        )
        output[position] = (sample * 255 / max_sample).to_byte()
        position += 1
      }
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_rgb_1bpp_as_rgb24(
  width : Int,
  height : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_rgb_packed_bpp_as_rgb24(width, height, 1, data)
}

///|
fn pdf_image_rgb_2bpp_as_rgb24(
  width : Int,
  height : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_rgb_packed_bpp_as_rgb24(width, height, 2, data)
}

///|
fn pdf_image_rgb_4bpp_as_rgb24(
  width : Int,
  height : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_rgb_packed_bpp_as_rgb24(width, height, 4, data)
}
