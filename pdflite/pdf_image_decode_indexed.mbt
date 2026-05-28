///|
fn pdf_image_indexed_lookup(
  table : ArrayView[(Int, Array[Int])],
  index : Int,
  components : Int,
) -> ArrayView[Int] raise PdfError {
  for entry in table {
    if entry.0 == index && entry.1.length() == components {
      break entry.1
    }
  } nobreak {
    raise EndOfInput
  }
}

///|
fn pdf_image_rgb_indexed_value(
  output : Array[Byte],
  position : Int,
  table : ArrayView[(Int, Array[Int])],
  index : Int,
) -> Int raise PdfError {
  let values = pdf_image_indexed_lookup(table, index, 3)
  output[position] = pdf_byte_of_int(values[0])
  output[position + 1] = pdf_byte_of_int(values[1])
  output[position + 2] = pdf_byte_of_int(values[2])
  position + 3
}

///|
fn pdf_image_cmyk_indexed_value(
  output : Array[Byte],
  position : Int,
  table : ArrayView[(Int, Array[Int])],
  index : Int,
) -> Int raise PdfError {
  let values = pdf_image_indexed_lookup(table, index, 4)
  let (red, green, blue) = pdf_image_rgb_of_cmyk(
    values[0],
    values[1],
    values[2],
    values[3],
  )
  output[position] = pdf_byte_of_int(red)
  output[position + 1] = pdf_byte_of_int(green)
  output[position + 2] = pdf_byte_of_int(blue)
  position + 3
}

///|
fn pdf_image_clamp_unit(value : Double) -> Double {
  if value > 1.0 {
    1.0
  } else if value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
fn pdf_image_lab_g(value : Double) -> Double {
  if value >= 6.0 / 29.0 {
    value * value * value
  } else {
    108.0 / 841.0 * (value - 4.0 / 29.0)
  }
}

///|
fn pdf_image_xyz_of_lab(
  lightness : Double,
  a : Double,
  b : Double,
  white : PdfTristimulusPoint,
) -> (Double, Double, Double) {
  let l = (lightness + 16.0) / 116.0 + a / 500.0
  let m = (lightness + 16.0) / 116.0
  let n = (lightness + 16.0) / 116.0 - b / 200.0
  (
    pdf_image_clamp_unit(white.x * pdf_image_lab_g(l)),
    pdf_image_clamp_unit(white.y * pdf_image_lab_g(m)),
    pdf_image_clamp_unit(white.z * pdf_image_lab_g(n)),
  )
}

///|
fn pdf_image_rgb_of_xyz(
  x : Double,
  y : Double,
  z : Double,
) -> (Double, Double, Double) {
  (
    pdf_image_clamp_unit(2.5623 * x + -1.1661 * y + -0.3962 * z),
    pdf_image_clamp_unit(-1.0215 * x + 1.9778 * y + 0.0437 * z),
    pdf_image_clamp_unit(0.0752 * x + -0.2562 * y + 1.1810 * z),
  )
}

///|
fn pdf_image_lab_indexed_value(
  output : Array[Byte],
  position : Int,
  table : ArrayView[(Int, Array[Int])],
  index : Int,
  white : PdfTristimulusPoint,
) -> Int raise PdfError {
  let values = pdf_image_indexed_lookup(table, index, 3)
  let lightness = (values[0] - 127).to_double() / 255.0
  let a = (values[1] - 127).to_double() / 255.0
  let b = (values[2] - 127).to_double() / 255.0
  let (x, y, z) = pdf_image_xyz_of_lab(lightness, a, b, white)
  let (red, green, blue) = pdf_image_rgb_of_xyz(x, y, z)
  output[position] = pdf_byte_of_int((red * 255.0).to_int())
  output[position + 1] = pdf_byte_of_int((green * 255.0).to_int())
  output[position + 2] = pdf_byte_of_int((blue * 255.0).to_int())
  position + 3
}

///|
fn pdf_image_indexed_8bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  data : BytesView,
) -> PdfBytes raise PdfError {
  let pixels = width * height
  pdf_image_require_size(data, pixels)
  let output = Array::make(pixels * 3, b'\x00')
  let mut position = 0
  for index in 0..<pixels {
    position = pdf_image_rgb_indexed_value(
      output,
      position,
      table,
      data[index].to_int(),
    )
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_lab_indexed_8bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  white : PdfTristimulusPoint,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let pixels = width * height
  pdf_image_require_size(data, pixels)
  let output = Array::make(pixels * 3, b'\x00')
  let mut position = 0
  for index in 0..<pixels {
    position = pdf_image_lab_indexed_value(
      output,
      position,
      table,
      data[index].to_int(),
      white,
    )
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_lab_indexed_packed_bpp_as_rgb24(
  width : Int,
  height : Int,
  bits_per_component : Int,
  table : ArrayView[(Int, Array[Int])],
  white : PdfTristimulusPoint,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let bytes_per_row = pdf_image_packed_bytes_per_row(width, bits_per_component)
  pdf_image_require_size(data, bytes_per_row * height)
  let output = Array::make(width * height * 3, b'\x00')
  let mut position = 0
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let index = pdf_image_packed_sample(
        data, row_offset, column, bits_per_component,
      )
      position = pdf_image_lab_indexed_value(
        output, position, table, index, white,
      )
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_lab_indexed_4bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  white : PdfTristimulusPoint,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_lab_indexed_packed_bpp_as_rgb24(
    width, height, 4, table, white, data,
  )
}

///|
fn pdf_image_lab_indexed_2bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  white : PdfTristimulusPoint,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_lab_indexed_packed_bpp_as_rgb24(
    width, height, 2, table, white, data,
  )
}

///|
fn pdf_image_lab_indexed_1bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  white : PdfTristimulusPoint,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_lab_indexed_packed_bpp_as_rgb24(
    width, height, 1, table, white, data,
  )
}

///|
fn pdf_image_cmyk_indexed_8bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  data : BytesView,
) -> PdfBytes raise PdfError {
  let pixels = width * height
  pdf_image_require_size(data, pixels)
  let output = Array::make(pixels * 3, b'\x00')
  let mut position = 0
  for index in 0..<pixels {
    position = pdf_image_cmyk_indexed_value(
      output,
      position,
      table,
      data[index].to_int(),
    )
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_indexed_packed_bpp_as_rgb24(
  width : Int,
  height : Int,
  bits_per_component : Int,
  table : ArrayView[(Int, Array[Int])],
  data : BytesView,
) -> PdfBytes raise PdfError {
  let bytes_per_row = pdf_image_packed_bytes_per_row(width, bits_per_component)
  pdf_image_require_size(data, bytes_per_row * height)
  let output = Array::make(width * height * 3, b'\x00')
  let mut position = 0
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let index = pdf_image_packed_sample(
        data, row_offset, column, bits_per_component,
      )
      position = pdf_image_rgb_indexed_value(output, position, table, index)
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_indexed_4bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_indexed_packed_bpp_as_rgb24(width, height, 4, table, data)
}

///|
fn pdf_image_indexed_2bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_indexed_packed_bpp_as_rgb24(width, height, 2, table, data)
}

///|
fn pdf_image_indexed_1bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_indexed_packed_bpp_as_rgb24(width, height, 1, table, data)
}

///|
fn pdf_image_cmyk_indexed_packed_bpp_as_rgb24(
  width : Int,
  height : Int,
  bits_per_component : Int,
  table : ArrayView[(Int, Array[Int])],
  data : BytesView,
) -> PdfBytes raise PdfError {
  let bytes_per_row = pdf_image_packed_bytes_per_row(width, bits_per_component)
  pdf_image_require_size(data, bytes_per_row * height)
  let output = Array::make(width * height * 3, b'\x00')
  let mut position = 0
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let index = pdf_image_packed_sample(
        data, row_offset, column, bits_per_component,
      )
      position = pdf_image_cmyk_indexed_value(output, position, table, index)
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_cmyk_indexed_4bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_cmyk_indexed_packed_bpp_as_rgb24(width, height, 4, table, data)
}

///|
fn pdf_image_cmyk_indexed_2bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_cmyk_indexed_packed_bpp_as_rgb24(width, height, 2, table, data)
}

///|
fn pdf_image_cmyk_indexed_1bpp_as_rgb24(
  width : Int,
  height : Int,
  table : ArrayView[(Int, Array[Int])],
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_image_cmyk_indexed_packed_bpp_as_rgb24(width, height, 1, table, data)
}
