///|
fn pdf_image_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_image_image_mask_key_name : PdfName = pdf_image_name("/ImageMask")

///|
let pdf_image_im_key_name : PdfName = pdf_image_name("/IM")

///|
let pdf_image_colorspace_key_name : PdfName = pdf_image_name("/ColorSpace")

///|
let pdf_image_cs_key_name : PdfName = pdf_image_name("/CS")

///|
let pdf_image_bits_per_component_key_name : PdfName = pdf_image_name(
  "/BitsPerComponent",
)

///|
let pdf_image_bpc_key_name : PdfName = pdf_image_name("/BPC")

///|
let pdf_image_width_key_name : PdfName = pdf_image_name("/Width")

///|
let pdf_image_w_key_name : PdfName = pdf_image_name("/W")

///|
let pdf_image_height_key_name : PdfName = pdf_image_name("/Height")

///|
let pdf_image_h_key_name : PdfName = pdf_image_name("/H")

///|
let pdf_image_decode_key_name : PdfName = pdf_image_name("/Decode")

///|
let pdf_image_d_key_name : PdfName = pdf_image_name("/D")

///|
let pdf_image_decodeparms_key_name : PdfName = pdf_image_name("/DecodeParms")

///|
let pdf_image_dp_key_name : PdfName = pdf_image_name("/DP")

///|
let pdf_image_jbig2_globals_key_name : PdfName = pdf_image_name("/JBIG2Globals")

///|
let pdf_image_dctdecode_name_value : PdfName = pdf_image_name("/DCTDecode")

///|
let pdf_image_dct_name_value : PdfName = pdf_image_name("/DCT")

///|
let pdf_image_jbig2decode_name_value : PdfName = pdf_image_name("/JBIG2Decode")

///|
let pdf_image_jpxdecode_name_value : PdfName = pdf_image_name("/JPXDecode")

///|
fn pdf_image_image_mask_key() -> PdfName {
  pdf_image_image_mask_key_name
}

///|
fn pdf_image_im_key() -> PdfName {
  pdf_image_im_key_name
}

///|
fn pdf_image_colorspace_key() -> PdfName {
  pdf_image_colorspace_key_name
}

///|
fn pdf_image_cs_key() -> PdfName {
  pdf_image_cs_key_name
}

///|
fn pdf_image_bits_per_component_key() -> PdfName {
  pdf_image_bits_per_component_key_name
}

///|
fn pdf_image_bpc_key() -> PdfName {
  pdf_image_bpc_key_name
}

///|
fn pdf_image_width_key() -> PdfName {
  pdf_image_width_key_name
}

///|
fn pdf_image_w_key() -> PdfName {
  pdf_image_w_key_name
}

///|
fn pdf_image_height_key() -> PdfName {
  pdf_image_height_key_name
}

///|
fn pdf_image_h_key() -> PdfName {
  pdf_image_h_key_name
}

///|
fn pdf_image_decode_key() -> PdfName {
  pdf_image_decode_key_name
}

///|
fn pdf_image_d_key() -> PdfName {
  pdf_image_d_key_name
}

///|
fn pdf_image_decodeparms_key() -> PdfName {
  pdf_image_decodeparms_key_name
}

///|
fn pdf_image_dp_key() -> PdfName {
  pdf_image_dp_key_name
}

///|
fn pdf_image_jbig2_globals_key() -> PdfName {
  pdf_image_jbig2_globals_key_name
}

///|
fn pdf_image_dctdecode_name() -> PdfName {
  pdf_image_dctdecode_name_value
}

///|
fn pdf_image_dct_name() -> PdfName {
  pdf_image_dct_name_value
}

///|
fn pdf_image_jbig2decode_name() -> PdfName {
  pdf_image_jbig2decode_name_value
}

///|
fn pdf_image_jpxdecode_name() -> PdfName {
  pdf_image_jpxdecode_name_value
}

///|
/// Pixel layout for extracted raw image data.
pub(all) enum PdfPixelLayout {
  PdfBPP1
  PdfBPP8
  PdfBPP24
  PdfBPP48
} derive(Debug, Eq, ToJson)

///|
/// Extracted PDF image data.
///
/// JPEG, JPEG2000, and JBIG2 variants keep their encoded bytes and optional
/// decode array. `PdfJBIG2` also carries the optional `/JBIG2Globals` object
/// number. `PdfRawImage` stores width, height, layout, and decoded pixel bytes.
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
/// Read an image XObject colour space.
///
/// `/ImageMask true` images are treated as `PdfDeviceGray`. Otherwise this
/// reads `/ColorSpace` or `/CS`, resolving named spaces through `resources`.
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
          None =>
            raise PdfError::DictionaryKeyNotFound(pdf_image_colorspace_key())
        }
      None => raise PdfError::DictionaryKeyNotFound(pdf_image_colorspace_key())
    }
  }
}

///|
/// Compatibility alias for `PdfDocument::image_colour_space`.
pub fn PdfDocument::colspace(
  self : PdfDocument,
  image : PdfObject,
  resources : PdfObject,
) -> PdfColourSpace raise PdfError {
  self.image_colour_space(image, resources)
}

///|
/// Compatibility wrapper for `PdfDocument::colspace`.
pub fn pdf_image_colspace(
  document : PdfDocument,
  image : PdfObject,
  resources : PdfObject,
) -> PdfColourSpace raise PdfError {
  document.colspace(image, resources)
}

///|
/// Return an image's `/BitsPerComponent` or abbreviated `/BPC` entry.
///
/// Image masks default to `1` when no explicit value is present. The raw object
/// is returned to preserve the PDF representation.
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
/// Compatibility alias for `PdfDocument::image_bits_per_component`.
pub fn PdfDocument::bpc(self : PdfDocument, image : PdfObject) -> PdfObject? {
  self.image_bits_per_component(image)
}

///|
/// Compatibility wrapper for `PdfDocument::bpc`.
pub fn pdf_image_bpc(document : PdfDocument, image : PdfObject) -> PdfObject? {
  document.bpc(image)
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
    Some(_) => raise PdfError::NumberExpected
    None => raise PdfError::DictionaryKeyNotFound(first_key)
  }
}

///|
fn PdfDocument::pdf_image_bits_per_component_int(
  self : PdfDocument,
  image : PdfObject,
) -> Int? raise PdfError {
  match self.image_bits_per_component(image) {
    Some(PdfInteger(value)) => Some(value)
    Some(_) => raise PdfError::NumberExpected
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
    Some(_) => raise PdfError::NumberExpected
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
        raise PdfError::FilterExpected
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
    _ => raise PdfError::ParseStreamExpected
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
    raise PdfError::EndOfInput
  }
}

///|
fn pdf_image_decode_is_identity(
  values : ArrayView[Double],
) -> Bool raise PdfError {
  if values.length() == 0 {
    true
  } else if values.length() % 2 != 0 {
    raise PdfError::FilterExpected
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
  let output : Array[Byte] = []
  for value in data {
    output.push((value.to_int() ^ 0xFF).to_byte())
  }
  Bytes::from_array(output)
}

///|
fn pdf_image_apply_8bpp_decode(
  data : BytesView,
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
          _ => raise PdfError::FilterExpected
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
          _ => raise PdfError::FilterExpected
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
  let output : Array[Byte] = []
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let sample = pdf_image_packed_sample(
        data, row_offset, column, bits_per_component,
      )
      let value = (sample * 255 / max_sample).to_byte()
      output.push(value)
      output.push(value)
      output.push(value)
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
  let output : Array[Byte] = []
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
        output.push((sample * 255 / max_sample).to_byte())
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
    raise PdfError::EndOfInput
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
  let output : Array[Byte] = []
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let index = pdf_image_packed_sample(
        data, row_offset, column, bits_per_component,
      )
      pdf_image_lab_indexed_value(output, table, index, white)
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
  let output : Array[Byte] = []
  for index in 0..<pixels {
    pdf_image_cmyk_indexed_value(output, table, data[index].to_int())
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
  let output : Array[Byte] = []
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let index = pdf_image_packed_sample(
        data, row_offset, column, bits_per_component,
      )
      pdf_image_rgb_indexed_value(output, table, index)
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
  let output : Array[Byte] = []
  for row in 0..<height {
    let row_offset = row * bytes_per_row
    for column in 0..<width {
      let index = pdf_image_packed_sample(
        data, row_offset, column, bits_per_component,
      )
      pdf_image_cmyk_indexed_value(output, table, index)
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
  let output : Array[Byte] = []
  for index in 0..<pixels {
    let values = tint_function.eval([data[index].to_double() / 255.0])
    if values.length() != 4 {
      raise PdfError::FilterExpected
    }
    let c = (values[0] * 255.0).to_int()
    let m = (values[2] * 255.0).to_int()
    let y = (values[1] * 255.0).to_int()
    let k = (values[3] * 255.0).to_int()
    let (red, green, blue) = pdf_image_rgb_of_cmyk(c, m, y, k)
    output.push(pdf_byte_of_int(red))
    output.push(pdf_byte_of_int(green))
    output.push(pdf_byte_of_int(blue))
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
        _ => raise PdfError::FilterExpected
      }
    (PdfIndexed(base, table), Some(8)) =>
      match pdf_space_basic_table_colour_space(base) {
        PdfDeviceRGB | PdfCalRGB(_, _, _, _) =>
          pdf_image_indexed_8bpp_as_rgb24(width, height, table, data)
        PdfDeviceCMYK =>
          pdf_image_cmyk_indexed_8bpp_as_rgb24(width, height, table, data)
        PdfLab(white, _, _) =>
          pdf_image_lab_indexed_8bpp_as_rgb24(width, height, table, white, data)
        _ => raise PdfError::FilterExpected
      }
    (PdfIndexed(base, table), Some(2)) =>
      match pdf_space_basic_table_colour_space(base) {
        PdfDeviceRGB | PdfCalRGB(_, _, _, _) =>
          pdf_image_indexed_2bpp_as_rgb24(width, height, table, data)
        PdfDeviceCMYK =>
          pdf_image_cmyk_indexed_2bpp_as_rgb24(width, height, table, data)
        PdfLab(white, _, _) =>
          pdf_image_lab_indexed_2bpp_as_rgb24(width, height, table, white, data)
        _ => raise PdfError::FilterExpected
      }
    (PdfIndexed(base, table), Some(4)) =>
      match pdf_space_basic_table_colour_space(base) {
        PdfDeviceRGB | PdfCalRGB(_, _, _, _) =>
          pdf_image_indexed_4bpp_as_rgb24(width, height, table, data)
        PdfDeviceCMYK =>
          pdf_image_cmyk_indexed_4bpp_as_rgb24(width, height, table, data)
        PdfLab(white, _, _) =>
          pdf_image_lab_indexed_4bpp_as_rgb24(width, height, table, white, data)
        _ => raise PdfError::FilterExpected
      }
    (_, Some(1)) => pdf_image_1bpp_as_rgb24(width, height, data)
    (PdfSeparation(_, PdfDeviceCMYK, tint), Some(8)) =>
      self.pdf_image_separation_cmyk_8bpp_as_rgb24(width, height, tint, data)
    (PdfICCBased(_, alternate, _, _, _), _) =>
      self.pdf_image_raw_colour_space_as_rgb24(
        width, height, alternate, bpc, data,
      )
    _ => raise PdfError::FilterExpected
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
