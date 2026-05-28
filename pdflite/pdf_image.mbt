///|
fn PdfDocument::pdf_image_lookup_int_or_else(
  self : PdfDocument,
  first_key : PdfName,
  second_key : PdfName,
  image : PdfObject,
) -> Int raise PdfError {
  match self.lookup_direct_or_else(first_key, second_key, image) {
    Some(PdfInteger(value)) => value
    Some(_) => raise NumberExpected
    None => raise DictionaryKeyNotFound(first_key)
  }
}

///|
fn PdfDocument::pdf_image_bits_per_component_int(
  self : PdfDocument,
  image : PdfObject,
) -> Int? raise PdfError {
  match self.image_bits_per_component(image) {
    Some(PdfInteger(value)) => Some(value)
    Some(_) => raise NumberExpected
    None => None
  }
}

///|
fn PdfDocument::pdf_image_decode_values(
  self : PdfDocument,
  image : PdfObject,
) -> Array[Double]? raise PdfError {
  match
    self.lookup_direct_or_else(pdf_image_decode_key(), pdf_image_d_key(), image) {
    Some(PdfArray(values)) => {
      let output : Array[Double] = Array::new(capacity=values.length())
      for value in values {
        output.push(self.get_number(value))
      }
      Some(output)
    }
    Some(_) => raise NumberExpected
    None => None
  }
}

///|
fn pdf_image_decode_identity_components(components : Int) -> Array[Double] {
  let values : Array[Double] = Array::new(capacity=components * 2)
  for _ in 0..<components {
    values.push(0.0)
    values.push(1.0)
  }
  values
}

///|
fn pdf_image_decode_lab_defaults(range : ArrayView[Double]) -> Array[Double] {
  let values : Array[Double] = [0.0, 1.0]
  for value in range {
    values.push(value)
  }
  values
}

///|
fn pdf_image_decode_defaults_for_space(
  colour_space : PdfColourSpace,
) -> Array[Double]? {
  match colour_space {
    PdfDeviceGray | PdfCalGray(_, _, _) | PdfSeparation(_, _, _) =>
      Some(pdf_image_decode_identity_components(1))
    PdfDeviceRGB | PdfCalRGB(_, _, _, _) =>
      Some(pdf_image_decode_identity_components(3))
    PdfDeviceCMYK => Some(pdf_image_decode_identity_components(4))
    PdfLab(_, _, range) => Some(pdf_image_decode_lab_defaults(range))
    PdfICCBased(_, _, range, _, _) => Some([ for value in range => value ])
    PdfIndexed(_, _) => Some(pdf_image_decode_identity_components(1))
    PdfDeviceN(names, _, _, _) =>
      Some(pdf_image_decode_identity_components(names.length()))
    PdfPattern | PdfPatternWithBaseColourSpace(_) => None
  }
}

///|
fn PdfDocument::pdf_image_decode_values_with_defaults(
  self : PdfDocument,
  resources : PdfObject,
  image : PdfObject,
) -> Array[Double]? raise PdfError {
  match self.pdf_image_decode_values(image) {
    Some(values) =>
      match
        self.lookup_direct_or_else(
          pdf_image_colorspace_key(),
          pdf_image_cs_key(),
          image,
        ) {
        None => Some(values)
        Some(_) =>
          match self.image_colour_space(image, resources) {
            PdfIndexed(_, _) => None
            _ => Some(values)
          }
      }
    None =>
      match
        self.lookup_direct_or_else(
          pdf_image_colorspace_key(),
          pdf_image_cs_key(),
          image,
        ) {
        None => None
        Some(_) =>
          pdf_image_decode_defaults_for_space(
            self.image_colour_space(image, resources),
          )
      }
  }
}

///|
fn PdfDocument::pdf_image_encoded_decode_values_with_defaults(
  self : PdfDocument,
  resources : PdfObject,
  image : PdfObject,
) -> Array[Double]? raise PdfError {
  match self.pdf_image_decode_values(image) {
    Some(values) => Some(values)
    None =>
      match
        self.lookup_direct_or_else(
          pdf_image_colorspace_key(),
          pdf_image_cs_key(),
          image,
        ) {
        None => None
        Some(_) =>
          pdf_image_decode_defaults_for_space(
            self.image_colour_space(image, resources),
          )
      }
  }
}

///|
priv enum PdfImageDecodedStream {
  PdfImageRawStream(PdfStream)
  PdfImageDctStream(PdfStream)
  PdfImageJpxStream(PdfStream)
  PdfImageJbig2Stream(PdfStream)
}

///|
fn PdfDocument::pdf_image_decode_stream_stages(
  self : PdfDocument,
  current : PdfStream,
  stages : Int,
) -> PdfImageDecodedStream raise PdfError {
  match self.pdf_stream_first_filter_direct(current.dictionary) {
    Some(filter) if filter == pdf_image_dctdecode_name() ||
      filter == pdf_image_dct_name() => PdfImageDctStream(current)
    Some(filter) if filter == pdf_image_jpxdecode_name() =>
      PdfImageJpxStream(current)
    Some(filter) if filter == pdf_image_jbig2decode_name() =>
      PdfImageJbig2Stream(current)
    Some(_) => {
      if stages >= 1024 {
        raise FilterExpected
      }
      self.pdf_image_decode_stream_stages(
        self.pdf_decode_stream_onestage_value_direct(current),
        stages + 1,
      )
    }
    None => PdfImageRawStream(current)
  }
}

///|
fn PdfDocument::pdf_image_decode_to_image(
  self : PdfDocument,
  image : PdfObject,
) -> PdfImageDecodedStream raise PdfError {
  let current = match self.direct(image) {
    PdfStreamObject(stream) => stream
    _ => raise ParseStreamExpected
  }
  self.pdf_image_decode_stream_stages(current, 0)
}

///|
fn PdfDocument::pdf_image_jbig2_globals(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Int? {
  let first_decodeparms = match
    self.lookup_direct_or_else(
      pdf_image_decodeparms_key(),
      pdf_image_dp_key(),
      dictionary,
    ) {
    Some(PdfDictionary(_) as decodeparms) => Some(decodeparms)
    Some(PdfArray([first, ..])) =>
      match self.direct(first) {
        PdfDictionary(_) as decodeparms => Some(decodeparms)
        _ => None
      }
    _ => None
  }
  match first_decodeparms {
    Some(decodeparms) =>
      match decodeparms.lookup_immediate(pdf_image_jbig2_globals_key()) {
        Some(PdfIndirect(number)) => Some(number)
        _ => None
      }
    None => None
  }
}

///|
fn pdf_image_require_size(
  data : BytesView,
  required : Int,
) -> Unit raise PdfError {
  if data.length() < required {
    raise EndOfInput
  }
}

///|
fn pdf_image_decode_is_identity(
  values : ArrayView[Double],
) -> Bool raise PdfError {
  if values.length() == 0 {
    true
  } else if values.length() % 2 != 0 {
    raise FilterExpected
  } else {
    let mut identity = true
    for index in 0..<(values.length() / 2) {
      if values[index * 2] != 0.0 || values[index * 2 + 1] != 1.0 {
        identity = false
      }
    }
    identity
  }
}

///|
fn pdf_image_decode_interpolate(
  dmin : Double,
  dmax : Double,
  value : Int,
  bpc : Int,
) -> Int {
  let denominator = match bpc {
    1 => 1.0
    2 => 3.0
    4 => 15.0
    8 => 255.0
    16 => 65535.0
    _ => 1.0
  }
  (dmin + value.to_double() * (dmax - dmin) / denominator).to_int()
}

///|
fn pdf_image_apply_1bpp_decode(data : BytesView) -> PdfBytes {
  let output = Array::make(data.length(), b'\x00')
  for index, value in data {
    output[index] = (value.to_int() ^ 0xFF).to_byte()
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_apply_8bpp_decode(
  data : BytesView,
  values : ArrayView[Double],
) -> PdfBytes raise PdfError {
  let components = values.length() / 2
  let output = Array::make(data.length(), b'\x00')
  for index in 0..<data.length() {
    let component = index % components
    output[index] = pdf_byte_of_int(
      pdf_image_decode_interpolate(
        values[component * 2],
        values[component * 2 + 1],
        data[index].to_int(),
        8,
      ),
    )
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_apply_decode_borrowed(
  data : BytesView,
  bpc : Int?,
  decode_values : Array[Double]?,
) -> PdfBytes raise PdfError {
  match decode_values {
    None => data.to_owned()
    Some(values) =>
      if pdf_image_decode_is_identity(values) {
        data.to_owned()
      } else {
        match bpc {
          Some(1) => pdf_image_apply_1bpp_decode(data)
          Some(2) | Some(4) | Some(16) => data.to_owned()
          Some(8) => pdf_image_apply_8bpp_decode(data, values)
          _ => raise FilterExpected
        }
      }
  }
}

///|
fn pdf_image_apply_decode(
  data : PdfBytes,
  bpc : Int?,
  decode_values : Array[Double]?,
) -> PdfBytes raise PdfError {
  match decode_values {
    None => data
    Some(values) =>
      if pdf_image_decode_is_identity(values) {
        data
      } else {
        match bpc {
          Some(1) => pdf_image_apply_decode_borrowed(data, bpc, Some(values))
          Some(2) | Some(4) | Some(16) => data
          Some(8) => pdf_image_apply_decode_borrowed(data, bpc, Some(values))
          _ => raise FilterExpected
        }
      }
  }
}

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

///|
/// Extract an image as either encoded image bytes or 24bpp RGB data.
///
/// DCT/JPEG, JPX/JPEG2000, and JBIG2 streams are returned still encoded.
/// Other supported image streams are decoded, have supported `/Decode` arrays
/// applied, and are converted to `PdfRawImage(width, height, PdfBPP24, data)`
/// where `data` is RGBRGB byte order.
pub fn PdfDocument::get_image_24bpp(
  self : PdfDocument,
  resources : PdfObject,
  image : PdfObject,
) -> PdfImage raise PdfError {
  let decoded = self.pdf_image_decode_to_image(image)
  let decoded_stream = match decoded {
    PdfImageRawStream(stream)
    | PdfImageDctStream(stream)
    | PdfImageJpxStream(stream)
    | PdfImageJbig2Stream(stream) => stream
  }
  let width = self.pdf_image_lookup_int_or_else(
    pdf_image_width_key(),
    pdf_image_w_key(),
    decoded_stream.dictionary,
  )
  let height = self.pdf_image_lookup_int_or_else(
    pdf_image_height_key(),
    pdf_image_h_key(),
    decoded_stream.dictionary,
  )
  let data = pdf_stream_data_bytes(decoded_stream.data)
  match decoded {
    PdfImageDctStream(_) =>
      PdfJPEG(
        data,
        self.pdf_image_encoded_decode_values_with_defaults(
          resources,
          decoded_stream.dictionary,
        ),
      )
    PdfImageJpxStream(_) =>
      PdfJPEG2000(
        data,
        self.pdf_image_encoded_decode_values_with_defaults(
          resources,
          decoded_stream.dictionary,
        ),
      )
    PdfImageJbig2Stream(_) =>
      PdfJBIG2(
        data,
        self.pdf_image_encoded_decode_values_with_defaults(
          resources,
          decoded_stream.dictionary,
        ),
        self.pdf_image_jbig2_globals(decoded_stream.dictionary),
      )
    PdfImageRawStream(_) => {
      let decoded_data = pdf_image_apply_decode(
        data,
        self.pdf_image_bits_per_component_int(decoded_stream.dictionary),
        self.pdf_image_decode_values_with_defaults(
          resources,
          decoded_stream.dictionary,
        ),
      )
      PdfRawImage(
        width,
        height,
        PdfBPP24,
        self.pdf_image_raw_8bpp_as_rgb24_owned(
          resources,
          width,
          height,
          decoded_stream.dictionary,
          decoded_data,
        ),
      )
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::get_image_24bpp`.
pub fn pdf_get_image_24bpp(
  document : PdfDocument,
  resources : PdfObject,
  image : PdfObject,
) -> PdfImage raise PdfError {
  document.get_image_24bpp(resources, image)
}

///|
priv struct PdfImageExtractionJbig2Global {
  object_number : Int
  serial : Int
}

///|
priv struct PdfImageExtractionState {
  next_jbig2_serial : Ref[Int]
  globals : Array[PdfImageExtractionJbig2Global]
}

///|
fn PdfImageExtractionState::jbig2_serial(
  self : PdfImageExtractionState,
  object_number : Int,
) -> Int? {
  for entry in self.globals {
    if entry.object_number == object_number {
      break Some(entry.serial)
    }
  } nobreak {
    None
  }
}

///|
fn PdfImageExtractionState::add_jbig2_global(
  self : PdfImageExtractionState,
  object_number : Int,
) -> Int {
  self.next_jbig2_serial.val += 1
  let serial = self.next_jbig2_serial.val
  self.globals.push({ object_number, serial })
  serial
}

///|
fn pdf_image_copy_view(
  output : Array[Byte],
  position : Int,
  bytes : BytesView,
) -> Int {
  let mut next = position
  for byte in bytes {
    output[next] = byte
    next += 1
  }
  next
}

///|
fn pdf_image_pnm_24bpp_bytes(
  width : Int,
  height : Int,
  data : PdfBytes,
) -> PdfBytes {
  let width_bytes = @ascii.encode(width.to_string())
  let height_bytes = @ascii.encode(height.to_string())
  let output = Array::make(
    3 + width_bytes.length() + 1 + height_bytes.length() + 5 + data.length(),
    b'\x00',
  )
  let mut position = pdf_image_copy_view(output, 0, b"P6 ")
  position = pdf_image_copy_view(output, position, width_bytes)
  position = pdf_image_copy_view(output, position, b" ")
  position = pdf_image_copy_view(output, position, height_bytes)
  position = pdf_image_copy_view(output, position, b" 255\n")
  let _ = pdf_image_copy_view(output, position, data)
  Bytes::from_array(output)
}

///|
fn pdf_image_path_separator(code_unit : UInt16) -> Bool {
  let value = code_unit.to_int()
  value == 47 || value == 92
}

///|
fn pdf_image_dirname(path : String) -> String {
  let mut separator = -1
  for index in 0..<path.length() {
    if pdf_image_path_separator(path.at(index)) {
      separator = index
    }
  }
  if separator < 0 {
    "."
  } else if separator == 0 {
    path[:1].to_owned()
  } else {
    path[:separator].to_owned()
  }
}

///|
fn pdf_image_join_directory_file(
  directory : String,
  filename : String,
) -> String {
  if directory == "." {
    "./" + filename
  } else if directory.length() == 0 {
    filename
  } else {
    let last = directory.at(directory.length() - 1).to_int()
    if last == 47 || last == 92 {
      directory + filename
    } else {
      directory + "/" + filename
    }
  }
}

///|
fn PdfDocument::pdf_image_jbig2_global_data(
  self : PdfDocument,
  object_number : Int,
) -> PdfBytes? raise PdfError {
  match self.pdf_decode_stream_until_unknown(PdfIndirect(object_number)) {
    PdfStreamObject(stream) => Some(pdf_stream_data_bytes(stream.data))
    _ => None
  }
}

///|
fn PdfDocument::pdf_image_extracted_files_of_image(
  self : PdfDocument,
  resources : PdfObject,
  name : String,
  image : PdfObject,
  state : PdfImageExtractionState,
) -> Array[PdfExtractedImageFile] raise PdfError {
  pdf_check_injectible(name)
  match self.get_image_24bpp(resources, image) {
    PdfJPEG(data, _) => [{ path: name + ".jpg", data }]
    PdfJPEG2000(data, _) => [{ path: name + ".jpx", data }]
    PdfJBIG2(data, _, None) => [{ path: name + ".jbig2", data }]
    PdfJBIG2(data, _, Some(global_number)) =>
      match state.jbig2_serial(global_number) {
        Some(serial) => [{ path: name + ".jbig2__" + serial.to_string(), data }]
        None =>
          match self.pdf_image_jbig2_global_data(global_number) {
            Some(global_data) => {
              let serial = state.add_jbig2_global(global_number)
              [
                {
                  path: pdf_image_join_directory_file(
                    pdf_image_dirname(name),
                    serial.to_string() + ".jbig2global",
                  ),
                  data: global_data,
                },
                { path: name + ".jbig2__" + serial.to_string(), data },
              ]
            }
            None => []
          }
      }
    PdfRawImage(width, height, PdfBPP24, data) =>
      [
        {
          path: name + ".pnm",
          data: pdf_image_pnm_24bpp_bytes(width, height, data),
        },
      ]
    PdfRawImage(_, _, _, _) => []
  }
}

///|
priv struct PdfImageExtractionRunState {
  serial : Ref[Int]
  written : Array[Int]
  jbig2 : PdfImageExtractionState
}

///|
fn PdfImageExtractionRunState::reset_written(
  self : PdfImageExtractionRunState,
) -> Unit {
  self.written.clear()
}

///|
fn PdfImageExtractionRunState::claim_images(
  self : PdfImageExtractionRunState,
  images : ArrayView[PdfObject],
  dedup : Bool,
  dedup_per_page : Bool,
) -> Array[PdfObject] {
  if !dedup && !dedup_per_page {
    images.to_owned()
  } else {
    let claimed : Array[PdfObject] = Array::new(capacity=images.length())
    for image in images {
      match image {
        PdfIndirect(number) if self.written.contains(number) => ()
        PdfIndirect(number) => {
          self.written.push(number)
          claimed.push(image)
        }
        _ => claimed.push(image)
      }
    }
    claimed
  }
}

///|
fn PdfImageExtractionRunState::next_serial(
  self : PdfImageExtractionRunState,
) -> Int {
  let serial = self.serial.val
  self.serial.val += 1
  serial
}

///|
fn pdf_image_replace_percent_objnum(stem : String) -> String {
  let input = @utf8.encode(stem)
  let pattern = b"%objnum"
  let mut output_length = input.length()
  let mut index = 0
  while index < input.length() {
    let mut matched = index + pattern.length() <= input.length()
    if matched {
      for pattern_index in 0..<pattern.length() {
        if input[index + pattern_index] != pattern[pattern_index] {
          matched = false
          break
        }
      }
    }
    if matched {
      output_length = output_length - pattern.length() + 2
      index += pattern.length()
    } else {
      index += 1
    }
  }
  let output = Array::make(output_length, b'\x00')
  let mut position = 0
  index = 0
  while index < input.length() {
    let mut matched = index + pattern.length() <= input.length()
    if matched {
      for pattern_index in 0..<pattern.length() {
        if input[index + pattern_index] != pattern[pattern_index] {
          matched = false
          break
        }
      }
    }
    if matched {
      output[position] = 64
      output[position + 1] = 83
      position += 2
      index += pattern.length()
    } else {
      output[position] = input[index]
      position += 1
      index += 1
    }
  }
  @utf8.decode(Bytes::from_array(output)) catch {
    _ => stem
  }
}

///|
fn PdfDocument::pdf_image_extraction_name(
  self : PdfDocument,
  encoding : PdfMetadataEncoding,
  stem : String,
  page_number : Int,
  image : PdfObject,
  state : PdfImageExtractionRunState,
) -> String raise PdfError {
  let object_number = match image {
    PdfIndirect(number) => number
    _ => 0
  }
  self.bookmark_name_of_spec(
    encoding,
    [],
    0,
    pdf_image_replace_percent_objnum(stem) + "-p" + page_number.to_string(),
    state.next_serial(),
    "",
    object_number,
    0,
  )
}

///|
fn PdfDocument::pdf_image_extract_named_images(
  self : PdfDocument,
  resources : PdfObject,
  images : ArrayView[PdfObject],
  stem : String,
  page_number : Int,
  encoding : PdfMetadataEncoding,
  state : PdfImageExtractionRunState,
) -> (Array[PdfExtractedImageFile], Array[String]) raise PdfError {
  let files : Array[PdfExtractedImageFile] = Array::new(
    capacity=images.length(),
  )
  let names : Array[String] = Array::new(capacity=images.length())
  for image in images {
    let name = self.pdf_image_extraction_name(
      encoding, stem, page_number, image, state,
    )
    names.push(name)
    for
      file in self.pdf_image_extracted_files_of_image(
        resources,
        name,
        image,
        state.jbig2,
      ) {
      files.push(file)
    }
  }
  (files, names)
}

///|
fn PdfDocument::pdf_image_partition_xobjects(
  self : PdfDocument,
  resources : PdfObject,
) -> (Array[PdfObject], Array[PdfObject]) {
  match self.lookup_direct(pdf_image_xobject_key(), resources) {
    Some(PdfDictionary(xobjects)) => {
      let images : Array[PdfObject] = Array::new(capacity=xobjects.length())
      let forms : Array[PdfObject] = Array::new(capacity=xobjects.length())
      for entry in xobjects {
        match self.lookup_direct(pdf_image_subtype_key(), entry.1) {
          Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() =>
            images.push(entry.1)
          Some(PdfNameObject(subtype)) if subtype == pdf_image_form_name() =>
            forms.push(entry.1)
          _ => ()
        }
      }
      (images, forms)
    }
    _ => ([], [])
  }
}

///|
fn PdfDocument::pdf_image_form_resources(
  self : PdfDocument,
  form : PdfObject,
) -> PdfObject {
  match self.lookup_direct(pdf_xobject_resources_key(), form) {
    Some(PdfDictionary(entries)) => PdfDictionary(entries)
    _ => PdfDictionary([])
  }
}

///|
fn PdfDocument::pdf_image_extract_form_xobject_files(
  self : PdfDocument,
  form : PdfObject,
  stem : String,
  page_number : Int,
  encoding : PdfMetadataEncoding,
  dedup : Bool,
  dedup_per_page : Bool,
  state : PdfImageExtractionRunState,
  depth : Int,
) -> Array[PdfExtractedImageFile] raise PdfError {
  if depth > 1024 {
    raise SoftError("extract_images: form XObject recursion too deep")
  }
  let resources = self.pdf_image_form_resources(form)
  let (images, forms) = self.pdf_image_partition_xobjects(resources)
  let files : Array[PdfExtractedImageFile] = Array::new(
    capacity=forms.length() + images.length(),
  )
  for child_form in forms {
    for
      file in self.pdf_image_extract_form_xobject_files(
        child_form,
        stem,
        page_number,
        encoding,
        dedup,
        dedup_per_page,
        state,
        depth + 1,
      ) {
      files.push(file)
    }
  }
  let claimed = state.claim_images(images, dedup, dedup_per_page)
  let (image_files, _) = self.pdf_image_extract_named_images(
    resources, claimed, stem, page_number, encoding, state,
  )
  for file in image_files {
    files.push(file)
  }
  files
}

///|
fn PdfDocument::pdf_image_extract_inline_image_files(
  self : PdfDocument,
  resources : PdfObject,
  content : ArrayView[PdfObject],
  stem : String,
  page_number : Int,
  encoding : PdfMetadataEncoding,
  state : PdfImageExtractionRunState,
) -> Array[PdfExtractedImageFile] raise PdfError {
  let ops = self.parse_content_ops_with_resources(resources, content)
  let files : Array[PdfExtractedImageFile] = Array::new(capacity=ops.length())
  for op in ops {
    match op {
      Op_InlineImage(dictionary, _, data) => {
        let image_dictionary = dictionary.add_dict_entry(
          pdf_image_length_key(),
          PdfInteger(data.length()),
        )
        let image = pdf_stream(image_dictionary, StreamGot(data))
        let name = self.bookmark_name_of_spec(
          encoding,
          [],
          0,
          pdf_image_replace_percent_objnum(stem) +
          "-p" +
          page_number.to_string() +
          "-inline",
          state.next_serial(),
          "",
          0,
          0,
        )
        for
          file in self.pdf_image_extracted_files_of_image(
            resources,
            name,
            image,
            state.jbig2,
          ) {
          files.push(file)
        }
      }
      _ => ()
    }
  }
  files
}

///|
fn PdfDocument::pdf_image_extract_inline_form_files(
  self : PdfDocument,
  form : PdfObject,
  stem : String,
  page_number : Int,
  encoding : PdfMetadataEncoding,
  state : PdfImageExtractionRunState,
) -> Array[PdfExtractedImageFile] raise PdfError {
  self.pdf_image_extract_inline_image_files(
    self.pdf_image_form_resources(form),
    [form],
    stem,
    page_number,
    encoding,
    state,
  )
}

///|
fn PdfDocument::pdf_image_extract_smask_files(
  self : PdfDocument,
  image : PdfObject,
  stem : String,
  page_number : Int,
  encoding : PdfMetadataEncoding,
  state : PdfImageExtractionRunState,
) -> Array[PdfExtractedImageFile] raise PdfError {
  match self.direct(image) {
    PdfStreamObject(_) =>
      match self.direct(image).lookup_immediate(pdf_image_smask_key()) {
        Some(PdfIndirect(mask_number)) => {
          let mask = PdfIndirect(mask_number)
          let (files, _) = self.pdf_image_extract_named_images(
            PdfDictionary([]),
            [mask],
            stem + "-smask",
            page_number,
            encoding,
            state,
          )
          files
        }
        _ => []
      }
    _ => []
  }
}

///|
/// Return the files cpdfimage's `extract_images` would write for page XObjects.
///
/// This ports the in-memory extraction side: page image XObjects, indirect
/// soft masks, recursive Form XObject image traversal, optional inline images,
/// cpdf filename expansion, and cpdf's indirect-image deduplication modes.
/// Decoded image data is emitted as raw PNM; external conversion and mask
/// composition are handled by native/file wrappers when available.
pub fn PdfDocument::extract_images_files(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  stem : String,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  inline? : Bool = false,
  dedup? : Bool = false,
  dedup_per_page? : Bool = false,
) -> Array[PdfExtractedImageFile] raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "images")
  let state : PdfImageExtractionRunState = {
    serial: { val: 0 },
    written: [],
    jbig2: { next_jbig2_serial: { val: 0 }, globals: [] },
  }
  let files : Array[PdfExtractedImageFile] = Array::new(
    capacity=page_numbers.length(),
  )
  let mut selected_page_number = 1
  for page_number in page_numbers {
    if dedup_per_page {
      state.reset_written()
    }
    let page = pages[page_number - 1]
    let (page_images, page_forms) = self.pdf_image_partition_xobjects(
      page.resources,
    )
    let claimed_page_images = state.claim_images(
      page_images, dedup, dedup_per_page,
    )
    let (page_image_files, _) = self.pdf_image_extract_named_images(
      page.resources,
      claimed_page_images,
      stem,
      selected_page_number,
      encoding,
      state,
    )
    for file in page_image_files {
      files.push(file)
    }
    for index in 0..<claimed_page_images.length() {
      let image = claimed_page_images[claimed_page_images.length() - index - 1]
      for
        file in self.pdf_image_extract_smask_files(
          image, stem, selected_page_number, encoding, state,
        ) {
        files.push(file)
      }
    }
    for form in page_forms {
      for
        file in self.pdf_image_extract_form_xobject_files(
          form, stem, selected_page_number, encoding, dedup, dedup_per_page, state,
          0,
        ) {
        files.push(file)
      }
    }
    if inline {
      for
        file in self.pdf_image_extract_inline_image_files(
          page.resources,
          page.content,
          stem,
          selected_page_number,
          encoding,
          state,
        ) {
        files.push(file)
      }
      for form in page_forms {
        for
          file in self.pdf_image_extract_inline_form_files(
            form, stem, selected_page_number, encoding, state,
          ) {
          files.push(file)
        }
      }
    }
    selected_page_number += 1
  }
  files
}

///|
/// Compatibility wrapper for `PdfDocument::extract_images_files`.
pub fn pdf_image_extract_images_files(
  inline : Bool,
  encoding : PdfMetadataEncoding,
  dedup : Bool,
  dedup_per_page : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  stem : String,
) -> Array[PdfExtractedImageFile] raise PdfError {
  document.extract_images_files(
    page_numbers,
    stem,
    encoding~,
    inline~,
    dedup~,
    dedup_per_page~,
  )
}

///|
/// Return the files cpdfimage's `extract_single_image` would write.
///
/// Encoded JPEG, JPEG2000, and JBIG2 images keep their encoded payloads.
/// Other supported images are decoded through `get_image_24bpp` and emitted as
/// binary PNM (`P6`) RGB files. An indirect `/SMask` is emitted with the
/// `-smask` stem, matching cpdf's single-image extraction path.
pub fn PdfDocument::extract_single_image_files(
  self : PdfDocument,
  object_number : Int,
  stem : String,
) -> Array[PdfExtractedImageFile] raise PdfError {
  let state : PdfImageExtractionState = {
    next_jbig2_serial: { val: 0 },
    globals: [],
  }
  let files = self.pdf_image_extracted_files_of_image(
    PdfDictionary([]),
    stem,
    PdfIndirect(object_number),
    state,
  )
  let image = self.direct(PdfIndirect(object_number))
  match image {
    PdfStreamObject(_) =>
      match image.lookup_immediate(pdf_image_smask_key()) {
        Some(PdfIndirect(mask_number)) =>
          for
            file in self.pdf_image_extracted_files_of_image(
              PdfDictionary([]),
              stem + "-smask",
              PdfIndirect(mask_number),
              state,
            ) {
            files.push(file)
          }
        _ => ()
      }
    _ => ()
  }
  files
}

///|
/// Compatibility wrapper for `PdfDocument::extract_single_image_files`.
pub fn pdf_image_extract_single_image_files(
  document : PdfDocument,
  object_number : Int,
  stem : String,
) -> Array[PdfExtractedImageFile] raise PdfError {
  document.extract_single_image_files(object_number, stem)
}
