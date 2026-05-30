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
/// One file that cpdf-style image extraction would write.
pub(all) struct PdfExtractedImageFile {
  path : String
  data : PdfBytes
} derive(Debug, Eq, ToJson)

///|
/// Build a PDF image XObject for JPEG data.
pub fn pdf_image_object_of_jpeg_data(
  data : BytesView,
) -> @syntax.PdfObject raise PdfError {
  let (width, height) = @codec.pdf_jpeg_dimensions_view(data)
  let payload = data.to_owned()
  @syntax.pdf_stream(
    PdfDictionary([
      (pdf_image_length_key(), PdfInteger(payload.length())),
      (pdf_image_filter_key(), PdfNameObject(pdf_image_dctdecode_name())),
      (pdf_image_bits_per_component_key(), PdfInteger(8)),
      (pdf_image_colorspace_key(), PdfNameObject(pdf_image_device_rgb_name())),
      (pdf_image_subtype_key(), PdfNameObject(pdf_image_image_name())),
      (pdf_image_width_key(), PdfInteger(width)),
      (pdf_image_height_key(), PdfInteger(height)),
    ]),
    StreamGot(payload),
  )
}

///|
/// Compatibility wrapper matching cpdfimage's `obj_of_jpeg_data` result shape.
pub fn pdf_image_obj_of_jpeg_data(
  data : BytesView,
  path_to_im? : String = "",
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise PdfError {
  ignore(path_to_im)
  (pdf_image_object_of_jpeg_data(data), [])
}

///|
/// Source-spelled cpdfimage `obj_of_jpeg_data` wrapper.
pub fn pdf_obj_of_jpeg_data(
  data : BytesView,
  path_to_im? : String = "",
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise PdfError {
  pdf_image_obj_of_jpeg_data(data, path_to_im~)
}

///|
/// Build a PDF image XObject for JPEG2000 data.
pub fn pdf_image_object_of_jpeg2000_data(
  data : BytesView,
) -> @syntax.PdfObject raise PdfError {
  let (width, height) = pdf_jpeg2000_dimensions_view(data)
  let payload = data.to_owned()
  @syntax.pdf_stream(
    PdfDictionary([
      (pdf_image_length_key(), PdfInteger(payload.length())),
      (pdf_image_filter_key(), PdfNameObject(pdf_image_jpxdecode_name())),
      (pdf_image_subtype_key(), PdfNameObject(pdf_image_image_name())),
      (pdf_image_width_key(), PdfInteger(width)),
      (pdf_image_height_key(), PdfInteger(height)),
    ]),
    StreamGot(payload),
  )
}

///|
/// Compatibility wrapper matching cpdfimage's `obj_of_jpeg2000_data` result shape.
pub fn pdf_image_obj_of_jpeg2000_data(
  data : BytesView,
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise PdfError {
  (pdf_image_object_of_jpeg2000_data(data), [])
}

///|
/// Source-spelled cpdfimage `obj_of_jpeg2000_data` wrapper.
pub fn pdf_obj_of_jpeg2000_data(
  data : BytesView,
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise PdfError {
  pdf_image_obj_of_jpeg2000_data(data)
}

///|
fn PdfPNG::pdf_image_png_components(self : PdfPNG) -> Int raise PdfError {
  match self.color_type {
    0 | 4 => 1
    2 | 6 => 3
    _ => raise BadPNG("obj_of_png_data unknown colortype")
  }
}

///|
fn PdfPNG::pdf_image_png_color_space(self : PdfPNG) -> PdfName raise PdfError {
  match self.color_type {
    0 | 4 => pdf_image_device_gray_name()
    2 | 6 => pdf_image_device_rgb_name()
    _ => raise BadPNG("obj_of_png_data unknown colortype")
  }
}

///|
fn pdf_image_png_dictionary(
  png : PdfPNG,
  data : PdfBytes,
  color_space : PdfName,
  colors : Int,
  predictor : Bool,
) -> Array[(PdfName, @syntax.PdfObject)] {
  let entries : Array[(PdfName, @syntax.PdfObject)] = [
    (pdf_image_length_key(), PdfInteger(data.length())),
    (pdf_image_subtype_key(), PdfNameObject(pdf_image_image_name())),
    (pdf_image_bits_per_component_key(), PdfInteger(png.bit_depth)),
    (pdf_image_colorspace_key(), PdfNameObject(color_space)),
    (pdf_image_width_key(), PdfInteger(png.width)),
    (pdf_image_height_key(), PdfInteger(png.height)),
    (pdf_image_filter_key(), PdfNameObject(PdfStreamFlate.filter_name())),
  ]
  if predictor {
    entries.push(
      (
        pdf_decodeparms_key(),
        pdf_predictor_decodeparms(15, colors, png.bit_depth, png.width),
      ),
    )
  }
  entries
}

///|
fn PdfPNG::pdf_image_split_alpha(
  self : PdfPNG,
) -> (PdfBytes, PdfBytes) raise PdfError {
  if self.bit_depth > 8 {
    raise BadPNG("Cannot use alpha PNGs with >8bpp")
  }
  let components = match self.color_type {
    4 => 1
    6 => 3
    _ => raise BadPNG("obj_of_png_data/split_mask: bad colortype")
  }
  let decoded = pdf_decode_predictor(
    15,
    components + 1,
    self.bit_depth,
    self.width,
    @flate.pdf_flate_decode(self.idat),
  )
  let stride = components + 1
  if decoded.length() % stride != 0 {
    raise BadPNG("obj_of_png_data/split_mask: malformed alpha data")
  }
  let pixels = decoded.length() / stride
  let colors = Array::make(pixels * components, b'\x00')
  let mask = Array::make(pixels, b'\x00')
  let mut color_position = 0
  let mut mask_position = 0
  for pixel in 0..<pixels {
    let offset = pixel * stride
    for component in 0..<components {
      colors[color_position] = decoded[offset + component]
      color_position += 1
    }
    mask[mask_position] = decoded[offset + components]
    mask_position += 1
  }
  (
    @flate.pdf_flate_encode(Bytes::from_array(colors)),
    @flate.pdf_flate_encode(Bytes::from_array(mask)),
  )
}

///|
/// Build a PDF image XObject for PNG data, adding an `/SMask` object to
/// `self` when the PNG carries an alpha channel.
pub fn PdfDocument::pdf_image_object_of_png_data(
  self : PdfDocument,
  data : BytesView,
) -> @syntax.PdfObject raise PdfError {
  let png = pdf_read_png_view(data)
  let (image_data, mask_data, predictor) = match png.color_type {
    4 | 6 => {
      let (colors, mask) = png.pdf_image_split_alpha()
      (colors, Some(mask), false)
    }
    _ => (png.idat, None, true)
  }
  let components = png.pdf_image_png_components()
  let entries = pdf_image_png_dictionary(
    png,
    image_data,
    png.pdf_image_png_color_space(),
    components,
    predictor,
  )
  match mask_data {
    Some(mask) => {
      let mask_entries = pdf_image_png_dictionary(
        png,
        mask,
        pdf_image_device_gray_name(),
        1,
        predictor,
      )
      let smask = @syntax.pdf_stream(
        PdfDictionary(mask_entries),
        StreamGot(mask),
      )
      let smask_number = self.add_object(smask)
      entries.push((pdf_image_smask_key(), PdfIndirect(smask_number)))
    }
    None => ()
  }
  @syntax.pdf_stream(PdfDictionary(entries), StreamGot(image_data))
}

///|
/// Build a PDF image XObject for PNG data using `document` for any alpha mask
/// object that must be added.
pub fn pdf_image_object_of_png_data(
  document : PdfDocument,
  data : BytesView,
) -> @syntax.PdfObject raise PdfError {
  document.pdf_image_object_of_png_data(data)
}

///|
/// Compatibility wrapper matching cpdfimage's `obj_of_png_data` result shape.
pub fn pdf_image_obj_of_png_data(
  document : PdfDocument,
  data : BytesView,
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise PdfError {
  (document.pdf_image_object_of_png_data(data), [])
}

///|
/// Source-spelled cpdfimage `obj_of_png_data` wrapper.
pub fn pdf_obj_of_png_data(
  document : PdfDocument,
  data : BytesView,
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise PdfError {
  pdf_image_obj_of_png_data(document, data)
}

///|
fn pdf_image_jbig2_u32_at(data : BytesView, offset : Int) -> Int raise PdfError {
  if offset < 0 || offset + 4 > data.length() {
    raise EndOfInput
  }
  let value = (data[offset].to_uint() << 24) |
    (data[offset + 1].to_uint() << 16) |
    (data[offset + 2].to_uint() << 8) |
    data[offset + 3].to_uint()
  value.to_int64().to_int()
}

///|
fn pdf_image_jbig2_dimensions_view(
  data : BytesView,
) -> (Int, Int) raise PdfError {
  (pdf_image_jbig2_u32_at(data, 11), pdf_image_jbig2_u32_at(data, 15))
}

///|
/// Build a PDF image XObject for JBIG2 data.
///
/// When `global` is supplied, the returned extra object list contains the
/// `/JBIG2Globals` stream at object number `10000`, matching cpdf's standalone
/// `obj_of_jbig2_data` contract.
pub fn pdf_image_object_of_jbig2_data(
  data : BytesView,
  global? : BytesView? = None,
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise PdfError {
  let payload = data.to_owned()
  let (width, height) = pdf_image_jbig2_dimensions_view(data)
  let entries : Array[(PdfName, @syntax.PdfObject)] = [
    (pdf_image_length_key(), PdfInteger(payload.length())),
    (pdf_image_filter_key(), PdfNameObject(pdf_image_jbig2decode_name())),
    (pdf_image_subtype_key(), PdfNameObject(pdf_image_image_name())),
    (pdf_image_bits_per_component_key(), PdfInteger(1)),
    (pdf_image_colorspace_key(), PdfNameObject(pdf_image_device_gray_name())),
    (pdf_image_width_key(), PdfInteger(width)),
    (pdf_image_height_key(), PdfInteger(height)),
  ]
  let extra : Array[(Int, @syntax.PdfObject)] = Array::new(
    capacity=match global {
      Some(_) => 1
      None => 0
    },
  )
  match global {
    Some(global) => {
      let global_payload = global.to_owned()
      entries.push(
        (
          pdf_decodeparms_key(),
          PdfDictionary([
            (
              pdf_image_jbig2_globals_key(),
              PdfIndirect(pdf_image_jbig2_globals_object_number),
            ),
          ]),
        ),
      )
      extra.push(
        (
          pdf_image_jbig2_globals_object_number,
          @syntax.pdf_stream(
            PdfDictionary([
              (pdf_image_length_key(), PdfInteger(global_payload.length())),
            ]),
            StreamGot(global_payload),
          ),
        ),
      )
    }
    None => ()
  }
  (@syntax.pdf_stream(PdfDictionary(entries), StreamGot(payload)), extra)
}

///|
/// Compatibility wrapper matching cpdfimage's `obj_of_jbig2_data`.
pub fn pdf_image_obj_of_jbig2_data(
  data : BytesView,
  global? : BytesView? = None,
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise PdfError {
  pdf_image_object_of_jbig2_data(data, global~)
}

///|
/// Source-spelled cpdfimage `obj_of_jbig2_data` wrapper.
pub fn pdf_obj_of_jbig2_data(
  data : BytesView,
  global? : BytesView? = None,
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise PdfError {
  pdf_image_obj_of_jbig2_data(data, global~)
}
