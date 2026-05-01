///|
fn pdf_image_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_image_image_mask_key() -> PdfName {
  pdf_image_name("/ImageMask")
}

///|
fn pdf_image_im_key() -> PdfName {
  pdf_image_name("/IM")
}

///|
fn pdf_image_colorspace_key() -> PdfName {
  pdf_image_name("/ColorSpace")
}

///|
fn pdf_image_cs_key() -> PdfName {
  pdf_image_name("/CS")
}

///|
fn pdf_image_bits_per_component_key() -> PdfName {
  pdf_image_name("/BitsPerComponent")
}

///|
fn pdf_image_bpc_key() -> PdfName {
  pdf_image_name("/BPC")
}

///|
fn pdf_image_width_key() -> PdfName {
  pdf_image_name("/Width")
}

///|
fn pdf_image_w_key() -> PdfName {
  pdf_image_name("/W")
}

///|
fn pdf_image_height_key() -> PdfName {
  pdf_image_name("/Height")
}

///|
fn pdf_image_h_key() -> PdfName {
  pdf_image_name("/H")
}

///|
fn pdf_image_filter_key() -> PdfName {
  pdf_image_name("/Filter")
}

///|
fn pdf_image_f_key() -> PdfName {
  pdf_image_name("/F")
}

///|
fn pdf_image_decode_key() -> PdfName {
  pdf_image_name("/Decode")
}

///|
fn pdf_image_d_key() -> PdfName {
  pdf_image_name("/D")
}

///|
fn pdf_image_decodeparms_key() -> PdfName {
  pdf_image_name("/DecodeParms")
}

///|
fn pdf_image_dp_key() -> PdfName {
  pdf_image_name("/DP")
}

///|
fn pdf_image_jbig2_globals_key() -> PdfName {
  pdf_image_name("/JBIG2Globals")
}

///|
fn pdf_image_dctdecode_name() -> PdfName {
  pdf_image_name("/DCTDecode")
}

///|
fn pdf_image_dct_name() -> PdfName {
  pdf_image_name("/DCT")
}

///|
fn pdf_image_jbig2decode_name() -> PdfName {
  pdf_image_name("/JBIG2Decode")
}

///|
fn pdf_image_jpxdecode_name() -> PdfName {
  pdf_image_name("/JPXDecode")
}

///|
pub(all) enum PdfPixelLayout {
  PdfBPP1
  PdfBPP8
  PdfBPP24
  PdfBPP48
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfImage {
  PdfJPEG(PdfBytes, Array[Double]?)
  PdfJPEG2000(PdfBytes, Array[Double]?)
  PdfJBIG2(PdfBytes, Array[Double]?, Int?)
  PdfRawImage(Int, Int, PdfPixelLayout, PdfBytes)
} derive(Debug, Eq, ToJson)

///|
fn PdfDocument::pdf_image_is_mask(
  self : PdfDocument,
  image : PdfObject,
) -> Bool {
  match
    self.lookup_direct_or_else(
      pdf_image_image_mask_key(),
      pdf_image_im_key(),
      image,
    ) {
    Some(PdfBoolean(true)) => true
    _ => false
  }
}

///|
pub fn PdfDocument::image_colour_space(
  self : PdfDocument,
  image : PdfObject,
  resources : PdfObject,
) -> PdfColourSpace raise PdfError {
  if self.pdf_image_is_mask(image) {
    PdfDeviceGray
  } else {
    match
      self.lookup_direct_or_else(
        pdf_image_colorspace_key(),
        pdf_image_cs_key(),
        image,
      ) {
      Some(colour_space) =>
        match self.read_colour_space(resources, colour_space) {
          Some(space) => space
          None => raise DictionaryKeyNotFound(pdf_image_colorspace_key())
        }
      None => raise DictionaryKeyNotFound(pdf_image_colorspace_key())
    }
  }
}

///|
pub fn PdfDocument::image_bits_per_component(
  self : PdfDocument,
  image : PdfObject,
) -> PdfObject? {
  match
    self.lookup_direct_or_else(
      pdf_image_bits_per_component_key(),
      pdf_image_bpc_key(),
      image,
    ) {
    Some(bits_per_component) => Some(bits_per_component)
    None =>
      if self.pdf_image_is_mask(image) {
        Some(PdfInteger(1))
      } else {
        None
      }
  }
}

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
      let output : Array[Double] = []
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
  let values : Array[Double] = []
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
fn PdfDocument::pdf_image_filter_value(
  self : PdfDocument,
  image : PdfObject,
) -> PdfObject? {
  self.lookup_direct_or_else(pdf_image_filter_key(), pdf_image_f_key(), image)
}

///|
fn PdfDocument::pdf_image_first_filter(
  self : PdfDocument,
  image : PdfObject,
) -> PdfName? raise PdfError {
  match self.pdf_image_filter_value(image) {
    None => None
    Some(PdfArray([])) => None
    Some(PdfNameObject(name)) => Some(name)
    Some(PdfArray([PdfNameObject(name), ..])) => Some(name)
    Some(_) => raise FilterExpected
  }
}

///|
fn pdf_image_is_encoded_stop_filter(name : PdfName) -> Bool {
  name == pdf_image_dctdecode_name() ||
  name == pdf_image_dct_name() ||
  name == pdf_image_jbig2decode_name() ||
  name == pdf_image_jpxdecode_name()
}

///|
fn PdfDocument::pdf_image_decode_to_image(
  self : PdfDocument,
  image : PdfObject,
) -> PdfObject raise PdfError {
  let mut current = self.direct(image)
  let mut stages = 0
  let mut done = false
  while !done {
    match self.pdf_image_first_filter(current) {
      Some(filter) if !pdf_image_is_encoded_stop_filter(filter) => {
        if stages >= 1024 {
          raise FilterExpected
        }
        current = pdf_decode_stream_onestage(current)
        stages += 1
      }
      _ => done = true
    }
  }
  current
}

///|
fn PdfDocument::pdf_image_jbig2_globals(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Int? {
  match
    self.lookup_direct_or_else(
      pdf_image_decodeparms_key(),
      pdf_image_dp_key(),
      dictionary,
    ) {
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
fn pdf_image_apply_1bpp_decode(data : PdfBytes) -> PdfBytes {
  let output : Array[Byte] = []
  for value in data {
    output.push((value.to_int() ^ 0xFF).to_byte())
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_apply_8bpp_decode(
  data : PdfBytes,
  values : ArrayView[Double],
) -> PdfBytes raise PdfError {
  let components = values.length() / 2
  let output : Array[Byte] = []
  for index in 0..<data.length() {
    let component = index % components
    output.push(
      pdf_byte_of_int(
        pdf_image_decode_interpolate(
          values[component * 2],
          values[component * 2 + 1],
          data[index].to_int(),
          8,
        ),
      ),
    )
  }
  Bytes::from_array(output)
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
          Some(1) => pdf_image_apply_1bpp_decode(data)
          Some(2) | Some(4) | Some(16) => data
          Some(8) => pdf_image_apply_8bpp_decode(data, values)
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
  let output : Array[Byte] = []
  for index in 0..<pixels {
    let value = data[index]
    output.push(value)
    output.push(value)
    output.push(value)
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
  let output : Array[Byte] = []
  for index in 0..<pixels {
    let offset = index * 4
    let (red, green, blue) = pdf_image_rgb_of_cmyk(
      data[offset].to_int(),
      data[offset + 1].to_int(),
      data[offset + 2].to_int(),
      data[offset + 3].to_int(),
    )
    output.push(pdf_byte_of_int(red))
    output.push(pdf_byte_of_int(green))
    output.push(pdf_byte_of_int(blue))
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
  let output : Array[Byte] = []
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let byte = data[row_offset + column / 8].to_int()
      let bit = (byte >> (7 - column % 8)) & 1
      let value : Byte = if bit == 1 { 255 } else { 0 }
      output.push(value)
      output.push(value)
      output.push(value)
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_gray_4bpp_as_rgb24(
  width : Int,
  height : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let bytes_per_row = (width + 1) / 2
  pdf_image_require_size(data, bytes_per_row * height)
  let output : Array[Byte] = []
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let byte = data[row_offset + column / 2].to_int()
      let nibble = if column % 2 == 0 { byte >> 4 } else { byte & 0x0F }
      let value = (nibble * 17).to_byte()
      output.push(value)
      output.push(value)
      output.push(value)
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_indexed_lookup(
  table : ArrayView[(Int, Array[Int])],
  index : Int,
  components : Int,
) -> ArrayView[Int] raise PdfError {
  for entry in table {
    if entry.0 == index && entry.1.length() == components {
      break entry.1[:]
    }
  } nobreak {
    raise EndOfInput
  }
}

///|
fn pdf_image_rgb_indexed_value(
  output : Array[Byte],
  table : ArrayView[(Int, Array[Int])],
  index : Int,
) -> Unit raise PdfError {
  let values = pdf_image_indexed_lookup(table, index, 3)
  output.push(pdf_byte_of_int(values[0]))
  output.push(pdf_byte_of_int(values[1]))
  output.push(pdf_byte_of_int(values[2]))
}

///|
fn pdf_image_cmyk_indexed_value(
  output : Array[Byte],
  table : ArrayView[(Int, Array[Int])],
  index : Int,
) -> Unit raise PdfError {
  let values = pdf_image_indexed_lookup(table, index, 4)
  let (red, green, blue) = pdf_image_rgb_of_cmyk(
    values[0],
    values[1],
    values[2],
    values[3],
  )
  output.push(pdf_byte_of_int(red))
  output.push(pdf_byte_of_int(green))
  output.push(pdf_byte_of_int(blue))
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
  table : ArrayView[(Int, Array[Int])],
  index : Int,
  white : PdfTristimulusPoint,
) -> Unit raise PdfError {
  let values = pdf_image_indexed_lookup(table, index, 3)
  let lightness = (values[0] - 127).to_double() / 255.0
  let a = (values[1] - 127).to_double() / 255.0
  let b = (values[2] - 127).to_double() / 255.0
  let (x, y, z) = pdf_image_xyz_of_lab(lightness, a, b, white)
  let (red, green, blue) = pdf_image_rgb_of_xyz(x, y, z)
  output.push(pdf_byte_of_int((red * 255.0).to_int()))
  output.push(pdf_byte_of_int((green * 255.0).to_int()))
  output.push(pdf_byte_of_int((blue * 255.0).to_int()))
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
  let output : Array[Byte] = []
  for index in 0..<pixels {
    pdf_image_rgb_indexed_value(output, table, data[index].to_int())
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
  let output : Array[Byte] = []
  for index in 0..<pixels {
    pdf_image_lab_indexed_value(output, table, data[index].to_int(), white)
  }
  Bytes::from_array(output)
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
  let output : Array[Byte] = []
  for index in 0..<pixels {
    pdf_image_cmyk_indexed_value(output, table, data[index].to_int())
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
  let bytes_per_row = (width + 1) / 2
  pdf_image_require_size(data, bytes_per_row * height)
  let output : Array[Byte] = []
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let byte = data[row_offset + column / 2].to_int()
      let index = if column % 2 == 0 { byte >> 4 } else { byte & 0x0F }
      pdf_image_rgb_indexed_value(output, table, index)
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
  let bytes_per_row = (width + 1) / 2
  pdf_image_require_size(data, bytes_per_row * height)
  let output : Array[Byte] = []
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let byte = data[row_offset + column / 2].to_int()
      let index = if column % 2 == 0 { byte >> 4 } else { byte & 0x0F }
      pdf_image_cmyk_indexed_value(output, table, index)
    }
  }
  Bytes::from_array(output)
}

///|
fn PdfDocument::pdf_image_raw_8bpp_as_rgb24(
  self : PdfDocument,
  resources : PdfObject,
  width : Int,
  height : Int,
  dictionary : PdfObject,
  data : BytesView,
) -> PdfImage raise PdfError {
  let colour_space = self.image_colour_space(dictionary, resources)
  let bpc = self.pdf_image_bits_per_component_int(dictionary)
  match (colour_space, bpc) {
    (PdfDeviceRGB | PdfCalRGB(_, _, _, _), Some(8)) => {
      let required = width * height * 3
      pdf_image_require_size(data, required)
      PdfRawImage(width, height, PdfBPP24, data[:required].to_owned())
    }
    (PdfDeviceGray | PdfCalGray(_, _, _), Some(8)) =>
      PdfRawImage(
        width,
        height,
        PdfBPP24,
        pdf_image_gray_8bpp_as_rgb24(width, height, data),
      )
    (PdfDeviceCMYK, Some(8)) =>
      PdfRawImage(
        width,
        height,
        PdfBPP24,
        pdf_image_cmyk_8bpp_as_rgb24(width, height, data),
      )
    (_, Some(1)) =>
      PdfRawImage(
        width,
        height,
        PdfBPP24,
        pdf_image_1bpp_as_rgb24(width, height, data),
      )
    (PdfDeviceGray, Some(4)) =>
      PdfRawImage(
        width,
        height,
        PdfBPP24,
        pdf_image_gray_4bpp_as_rgb24(width, height, data),
      )
    (PdfIndexed(base, table), Some(8)) =>
      match pdf_space_basic_table_colour_space(base) {
        PdfDeviceRGB | PdfCalRGB(_, _, _, _) =>
          PdfRawImage(
            width,
            height,
            PdfBPP24,
            pdf_image_indexed_8bpp_as_rgb24(width, height, table, data),
          )
        PdfDeviceCMYK =>
          PdfRawImage(
            width,
            height,
            PdfBPP24,
            pdf_image_cmyk_indexed_8bpp_as_rgb24(width, height, table, data),
          )
        PdfLab(white, _, _) =>
          PdfRawImage(
            width,
            height,
            PdfBPP24,
            pdf_image_lab_indexed_8bpp_as_rgb24(
              width, height, table, white, data,
            ),
          )
        _ => raise FilterExpected
      }
    (PdfIndexed(base, table), Some(4)) =>
      match pdf_space_basic_table_colour_space(base) {
        PdfDeviceRGB | PdfCalRGB(_, _, _, _) =>
          PdfRawImage(
            width,
            height,
            PdfBPP24,
            pdf_image_indexed_4bpp_as_rgb24(width, height, table, data),
          )
        PdfDeviceCMYK =>
          PdfRawImage(
            width,
            height,
            PdfBPP24,
            pdf_image_cmyk_indexed_4bpp_as_rgb24(width, height, table, data),
          )
        _ => raise FilterExpected
      }
    _ => raise FilterExpected
  }
}

///|
pub fn PdfDocument::get_image_24bpp(
  self : PdfDocument,
  resources : PdfObject,
  image : PdfObject,
) -> PdfImage raise PdfError {
  let decoded = self.pdf_image_decode_to_image(image)
  match decoded {
    PdfStreamObject(stream) => {
      let width = self.pdf_image_lookup_int_or_else(
        pdf_image_width_key(),
        pdf_image_w_key(),
        stream.dictionary,
      )
      let height = self.pdf_image_lookup_int_or_else(
        pdf_image_height_key(),
        pdf_image_h_key(),
        stream.dictionary,
      )
      match stream.data {
        StreamGot(data) =>
          match self.pdf_image_first_filter(decoded) {
            Some(filter) if filter == pdf_image_dctdecode_name() ||
              filter == pdf_image_dct_name() =>
              PdfJPEG(
                data,
                self.pdf_image_decode_values_with_defaults(
                  resources,
                  stream.dictionary,
                ),
              )
            Some(filter) if filter == pdf_image_jpxdecode_name() =>
              PdfJPEG2000(
                data,
                self.pdf_image_decode_values_with_defaults(
                  resources,
                  stream.dictionary,
                ),
              )
            Some(filter) if filter == pdf_image_jbig2decode_name() =>
              PdfJBIG2(
                data,
                self.pdf_image_decode_values_with_defaults(
                  resources,
                  stream.dictionary,
                ),
                self.pdf_image_jbig2_globals(stream.dictionary),
              )
            None =>
              match
                self.pdf_image_raw_8bpp_as_rgb24(
                  resources,
                  width,
                  height,
                  stream.dictionary,
                  data[:],
                ) {
                PdfRawImage(width, height, layout, data) =>
                  PdfRawImage(
                    width,
                    height,
                    layout,
                    pdf_image_apply_decode(
                      data,
                      self.pdf_image_bits_per_component_int(stream.dictionary),
                      self.pdf_image_decode_values_with_defaults(
                        resources,
                        stream.dictionary,
                      ),
                    ),
                  )
                encoded => encoded
              }
            Some(filter) => raise FilterNotSupported(filter)
          }
        _ => raise StreamDataExpected
      }
    }
    _ => raise ParseStreamExpected
  }
}
