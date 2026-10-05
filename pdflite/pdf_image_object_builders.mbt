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
  PdfJPEG(@core.PdfBytes, Array[Double]?)
  PdfJPEG2000(@core.PdfBytes, Array[Double]?)
  PdfJBIG2(@core.PdfBytes, Array[Double]?, Int?)
  PdfRawImage(Int, Int, PdfPixelLayout, @core.PdfBytes)
} derive(Debug, Eq, ToJson)

///|
/// One file that cpdf-style image extraction would write.
pub(all) struct PdfExtractedImageFile {
  path : String
  data : @core.PdfBytes
} derive(Debug, Eq, ToJson)

///|
/// Build a PDF image XObject for JPEG data.
pub fn pdf_image_object_of_jpeg_data(
  data : BytesView,
) -> @syntax.PdfObject raise @core.PdfError {
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
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise @core.PdfError {
  ignore(path_to_im)
  (pdf_image_object_of_jpeg_data(data), [])
}

///|
/// Source-spelled cpdfimage `obj_of_jpeg_data` wrapper.
pub fn pdf_obj_of_jpeg_data(
  data : BytesView,
  path_to_im? : String = "",
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise @core.PdfError {
  pdf_image_obj_of_jpeg_data(data, path_to_im~)
}

///|
/// Build a PDF image XObject for JPEG2000 data.
pub fn pdf_image_object_of_jpeg2000_data(
  data : BytesView,
) -> @syntax.PdfObject raise @core.PdfError {
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
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise @core.PdfError {
  (pdf_image_object_of_jpeg2000_data(data), [])
}

///|
/// Source-spelled cpdfimage `obj_of_jpeg2000_data` wrapper.
pub fn pdf_obj_of_jpeg2000_data(
  data : BytesView,
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise @core.PdfError {
  pdf_image_obj_of_jpeg2000_data(data)
}

///|
/// Components per pixel as far as the PDF predictor is concerned. Palette
/// indices count as one component, like greyscale: the predictor runs
/// over the index stream, not the colours it names.
fn PdfPNG::pdf_image_png_components(self : PdfPNG) -> Int raise @core.PdfError {
  match self.color_type {
    0 | 3 | 4 => 1
    2 | 6 => 3
    _ => raise BadPNG("obj_of_png_data unknown colortype")
  }
}

///|
fn PdfPNG::pdf_image_png_color_space(
  self : PdfPNG,
) -> @syntax.PdfObject raise @core.PdfError {
  match self.color_type {
    0 | 4 => PdfNameObject(pdf_image_device_gray_name())
    2 | 6 => PdfNameObject(pdf_image_device_rgb_name())
    3 =>
      match self.palette {
        // PDF has indexed colour natively, so the palette maps straight
        // onto `[/Indexed /DeviceRGB hival lookup]` and the IDAT keeps
        // the compressed passthrough untouched — no inflate, no
        // re-encode.
        Some(plte) =>
          PdfArray([
            PdfNameObject(pdf_image_indexed_name()),
            PdfNameObject(pdf_image_device_rgb_name()),
            PdfInteger(plte.length() / 3 - 1),
            PdfString(plte),
          ])
        // Unreachable off pdf_read_png, which rejects type 3 without a
        // PLTE; guarded for a hand-built PdfPNG.
        None => raise BadPNG("obj_of_png_data palette image without palette")
      }
    _ => raise BadPNG("obj_of_png_data unknown colortype")
  }
}

///|
fn pdf_image_png_dictionary(
  png : PdfPNG,
  data : @core.PdfBytes,
  color_space : @syntax.PdfObject,
  colors : Int,
  predictor : Bool,
) -> Array[(@core.PdfName, @syntax.PdfObject)] {
  let entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
    (pdf_image_length_key(), PdfInteger(data.length())),
    (pdf_image_subtype_key(), PdfNameObject(pdf_image_image_name())),
    (pdf_image_bits_per_component_key(), PdfInteger(png.bit_depth)),
    (pdf_image_colorspace_key(), color_space),
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
) -> (@core.PdfBytes, @core.PdfBytes) raise @core.PdfError {
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
/// A palette image's soft mask: each pixel's alpha, its palette entry's in
/// `alpha` (opaque past its end, and so for an index past the palette, as
/// PNG has decoders recover), 8 bits a pixel, flate-compressed. Raises
/// BadPNG for image data short of the raster (or a raster too large).
fn PdfPNG::pdf_image_palette_mask(
  self : PdfPNG,
  alpha : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  let depth = self.bit_depth
  if depth != 1 && depth != 2 && depth != 4 && depth != 8 {
    raise BadPNG("obj_of_png_data: bad palette bit depth")
  }
  // the raster's size, checked wide: each row a filter byte and its indices
  let row_bytes64 = (self.width.to_int64() * depth.to_int64() + 7L) / 8L
  let size64 = self.height.to_int64() * (row_bytes64 + 1L)
  let pixels64 = self.width.to_int64() * self.height.to_int64()
  if size64 > 0x7FFFFFFFL || pixels64 > 0x7FFFFFFFL {
    raise BadPNG("obj_of_png_data: palette image too large")
  }
  let row_bytes = row_bytes64.to_int()
  let size = size64.to_int()
  // all of it, or the mask would be made up where the data is missing
  let raster = @flate.pdf_flate_decode(self.idat)
  if raster.length() < size {
    raise BadPNG("obj_of_png_data: palette image data truncated")
  }
  let indices = pdf_decode_predictor_view(
    15,
    1,
    depth,
    self.width,
    raster[:size],
  )
  if indices.length() < self.height * row_bytes {
    raise BadPNG("obj_of_png_data: palette image data truncated")
  }
  let per_byte = 8 / depth
  let max = (1 << depth) - 1
  let mask = Array::make(self.width * self.height, b'\xFF')
  for y in 0..<self.height {
    for x in 0..<self.width {
      let at = y * row_bytes + x / per_byte
      let shift = 8 - depth * (x % per_byte + 1)
      let index = (indices[at].to_int() >> shift) & max
      // (opaque past the alpha there is, and so past the palette, where PNG
      // has decoders make an index an opaque pixel)
      if index < alpha.length() {
        mask[y * self.width + x] = alpha[index]
      }
    }
  }
  @flate.pdf_flate_encode(Bytes::from_array(mask))
}

///|
/// Build a PDF image XObject for PNG data, adding an `/SMask` object to
/// `self` when the PNG carries an alpha channel.
pub fn PdfDocument::pdf_image_object_of_png_data(
  self : PdfDocument,
  data : BytesView,
) -> @syntax.PdfObject raise @core.PdfError {
  let png = pdf_read_png_view(data)
  let (image_data, mask_data, predictor) = match png.color_type {
    4 | 6 => {
      let (colors, mask) = png.pdf_image_split_alpha()
      (colors, Some(mask), false)
    }
    // a palette's alpha: the indices stay as they are, the mask is made
    3 if png.transparency is Some(PdfPNGPaletteAlpha(alpha)) =>
      (png.idat, Some(png.pdf_image_palette_mask(alpha)), true)
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
  // a colour key: the pixels of that colour are transparent, a /Mask of
  // each sample's range
  match png.transparency {
    Some(PdfPNGColourKey(key)) => {
      // colour-key masks are PDF 1.3
      self.pdf_image_raise_version(1, 3)
      entries.push(
        (
          pdf_image_mask_key(),
          PdfArray(
            key
            .map(v => {
              let n : @syntax.PdfObject = PdfInteger(v)
              [n, n]
            })
            .flatten(),
          ),
        ),
      )
    }
    // (a palette's alpha is the soft mask made above)
    Some(PdfPNGPaletteAlpha(_)) | None => ()
  }
  match mask_data {
    Some(mask) => {
      // (an alpha channel's depth is the image's; a palette's, 8 bits)
      let mask_entries = pdf_image_png_dictionary(
        if png.color_type == 3 {
          { ..png, bit_depth: 8, }
        } else {
          png
        },
        mask,
        PdfNameObject(pdf_image_device_gray_name()),
        1,
        false,
      )
      let smask = @syntax.pdf_stream(
        PdfDictionary(mask_entries),
        StreamGot(mask),
      )
      // soft masks are PDF 1.4
      self.pdf_image_raise_version(1, 4)
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
) -> @syntax.PdfObject raise @core.PdfError {
  document.pdf_image_object_of_png_data(data)
}

///|
/// Compatibility wrapper matching cpdfimage's `obj_of_png_data` result shape.
pub fn pdf_image_obj_of_png_data(
  document : PdfDocument,
  data : BytesView,
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise @core.PdfError {
  (document.pdf_image_object_of_png_data(data), [])
}

///|
/// Source-spelled cpdfimage `obj_of_png_data` wrapper.
pub fn pdf_obj_of_png_data(
  document : PdfDocument,
  data : BytesView,
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise @core.PdfError {
  pdf_image_obj_of_png_data(document, data)
}

///|
fn pdf_image_jbig2_u32_at(
  data : BytesView,
  offset : Int,
) -> Int raise @core.PdfError {
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
) -> (Int, Int) raise @core.PdfError {
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
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise @core.PdfError {
  let payload = data.to_owned()
  let (width, height) = pdf_image_jbig2_dimensions_view(data)
  let entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
    (pdf_image_length_key(), PdfInteger(payload.length())),
    (pdf_image_filter_key(), PdfNameObject(pdf_image_jbig2decode_name())),
    (pdf_image_subtype_key(), PdfNameObject(pdf_image_image_name())),
    (pdf_image_bits_per_component_key(), PdfInteger(1)),
    (pdf_image_colorspace_key(), PdfNameObject(pdf_image_device_gray_name())),
    (pdf_image_width_key(), PdfInteger(width)),
    (pdf_image_height_key(), PdfInteger(height)),
  ]
  let extra : Array[(Int, @syntax.PdfObject)] = Array(
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
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise @core.PdfError {
  pdf_image_object_of_jbig2_data(data, global~)
}

///|
/// Source-spelled cpdfimage `obj_of_jbig2_data` wrapper.
pub fn pdf_obj_of_jbig2_data(
  data : BytesView,
  global? : BytesView? = None,
) -> (@syntax.PdfObject, Array[(Int, @syntax.PdfObject)]) raise @core.PdfError {
  pdf_image_obj_of_jbig2_data(data, global~)
}

///|
/// Raise the document's PDF version to `major.minor` when it is below it,
/// as an image feature of that version needs.
fn PdfDocument::pdf_image_raise_version(
  self : PdfDocument,
  major : Int,
  minor : Int,
) -> Unit {
  let (m, n) = self.version()
  if m < major || (m == major && n < minor) {
    self.set_version(major, minor)
  }
}
