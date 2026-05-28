///|
fn PdfDocument::pdf_image_separation_cmyk_8bpp_as_rgb24(
  self : PdfDocument,
  width : Int,
  height : Int,
  tint : PdfObject,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let pixels = width * height
  pdf_image_require_size(data, pixels)
  let tint_function = self.parse_function(tint)
  let output = Array::make(pixels * 3, b'\x00')
  let mut position = 0
  for index in 0..<pixels {
    let values = tint_function.eval([data[index].to_double() / 255.0])
    if values.length() != 4 {
      raise FilterExpected
    }
    let c = (values[0] * 255.0).to_int()
    let m = (values[2] * 255.0).to_int()
    let y = (values[1] * 255.0).to_int()
    let k = (values[3] * 255.0).to_int()
    let (red, green, blue) = pdf_image_rgb_of_cmyk(c, m, y, k)
    output[position] = pdf_byte_of_int(red)
    output[position + 1] = pdf_byte_of_int(green)
    output[position + 2] = pdf_byte_of_int(blue)
    position += 3
  }
  Bytes::from_array(output)
}

///|
fn PdfDocument::pdf_image_raw_colour_space_as_rgb24(
  self : PdfDocument,
  width : Int,
  height : Int,
  colour_space : PdfColourSpace,
  bpc : Int?,
  data : BytesView,
) -> PdfBytes raise PdfError {
  match (colour_space, bpc) {
    (PdfDeviceRGB | PdfCalRGB(_, _, _, _), Some(8)) => {
      let required = width * height * 3
      pdf_image_require_size(data, required)
      data[:required].to_owned()
    }
    (PdfDeviceRGB | PdfCalRGB(_, _, _, _), Some(1)) =>
      pdf_image_rgb_1bpp_as_rgb24(width, height, data)
    (PdfDeviceRGB | PdfCalRGB(_, _, _, _), Some(2)) =>
      pdf_image_rgb_2bpp_as_rgb24(width, height, data)
    (PdfDeviceRGB | PdfCalRGB(_, _, _, _), Some(4)) =>
      pdf_image_rgb_4bpp_as_rgb24(width, height, data)
    (PdfDeviceGray | PdfCalGray(_, _, _), Some(8)) =>
      pdf_image_gray_8bpp_as_rgb24(width, height, data)
    (PdfDeviceCMYK, Some(8)) =>
      pdf_image_cmyk_8bpp_as_rgb24(width, height, data)
    (PdfDeviceGray | PdfCalGray(_, _, _), Some(2)) =>
      pdf_image_gray_2bpp_as_rgb24(width, height, data)
    (PdfDeviceGray | PdfCalGray(_, _, _), Some(4)) =>
      pdf_image_gray_4bpp_as_rgb24(width, height, data)
    (PdfIndexed(base, table), Some(1)) =>
      match pdf_space_basic_table_colour_space(base) {
        PdfDeviceRGB | PdfCalRGB(_, _, _, _) =>
          pdf_image_indexed_1bpp_as_rgb24(width, height, table, data)
        PdfDeviceCMYK =>
          pdf_image_cmyk_indexed_1bpp_as_rgb24(width, height, table, data)
        PdfLab(white, _, _) =>
          pdf_image_lab_indexed_1bpp_as_rgb24(width, height, table, white, data)
        _ => raise FilterExpected
      }
    (PdfIndexed(base, table), Some(8)) =>
      match pdf_space_basic_table_colour_space(base) {
        PdfDeviceRGB | PdfCalRGB(_, _, _, _) =>
          pdf_image_indexed_8bpp_as_rgb24(width, height, table, data)
        PdfDeviceCMYK =>
          pdf_image_cmyk_indexed_8bpp_as_rgb24(width, height, table, data)
        PdfLab(white, _, _) =>
          pdf_image_lab_indexed_8bpp_as_rgb24(width, height, table, white, data)
        _ => raise FilterExpected
      }
    (PdfIndexed(base, table), Some(2)) =>
      match pdf_space_basic_table_colour_space(base) {
        PdfDeviceRGB | PdfCalRGB(_, _, _, _) =>
          pdf_image_indexed_2bpp_as_rgb24(width, height, table, data)
        PdfDeviceCMYK =>
          pdf_image_cmyk_indexed_2bpp_as_rgb24(width, height, table, data)
        PdfLab(white, _, _) =>
          pdf_image_lab_indexed_2bpp_as_rgb24(width, height, table, white, data)
        _ => raise FilterExpected
      }
    (PdfIndexed(base, table), Some(4)) =>
      match pdf_space_basic_table_colour_space(base) {
        PdfDeviceRGB | PdfCalRGB(_, _, _, _) =>
          pdf_image_indexed_4bpp_as_rgb24(width, height, table, data)
        PdfDeviceCMYK =>
          pdf_image_cmyk_indexed_4bpp_as_rgb24(width, height, table, data)
        PdfLab(white, _, _) =>
          pdf_image_lab_indexed_4bpp_as_rgb24(width, height, table, white, data)
        _ => raise FilterExpected
      }
    (_, Some(1)) => pdf_image_1bpp_as_rgb24(width, height, data)
    (PdfSeparation(_, PdfDeviceCMYK, tint), Some(8)) =>
      self.pdf_image_separation_cmyk_8bpp_as_rgb24(width, height, tint, data)
    (PdfICCBased(_, alternate, _, _, _), _) =>
      self.pdf_image_raw_colour_space_as_rgb24(
        width, height, alternate, bpc, data,
      )
    _ => raise FilterExpected
  }
}

///|
fn PdfDocument::pdf_image_raw_colour_space_as_rgb24_owned(
  self : PdfDocument,
  width : Int,
  height : Int,
  colour_space : PdfColourSpace,
  bpc : Int?,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  match (colour_space, bpc) {
    (PdfDeviceRGB | PdfCalRGB(_, _, _, _), Some(8)) => {
      let required = width * height * 3
      pdf_image_require_size(data, required)
      if data.length() == required {
        data
      } else {
        data[:required].to_owned()
      }
    }
    _ =>
      self.pdf_image_raw_colour_space_as_rgb24(
        width, height, colour_space, bpc, data,
      )
  }
}

///|
fn PdfDocument::pdf_image_raw_8bpp_as_rgb24_owned(
  self : PdfDocument,
  resources : PdfObject,
  width : Int,
  height : Int,
  dictionary : PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  self.pdf_image_raw_colour_space_as_rgb24_owned(
    width,
    height,
    self.image_colour_space(dictionary, resources),
    self.pdf_image_bits_per_component_int(dictionary),
    data,
  )
}
