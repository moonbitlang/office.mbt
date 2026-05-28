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
) -> PdfObject raise PdfError {
  let (width, height) = pdf_jpeg_dimensions_view(data)
  let payload = data.to_owned()
  pdf_stream(
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
) -> (PdfObject, Array[(Int, PdfObject)]) raise PdfError {
  ignore(path_to_im)
  (pdf_image_object_of_jpeg_data(data), [])
}

///|
/// Source-spelled cpdfimage `obj_of_jpeg_data` wrapper.
pub fn pdf_obj_of_jpeg_data(
  data : BytesView,
  path_to_im? : String = "",
) -> (PdfObject, Array[(Int, PdfObject)]) raise PdfError {
  pdf_image_obj_of_jpeg_data(data, path_to_im~)
}

///|
/// Build a PDF image XObject for JPEG2000 data.
pub fn pdf_image_object_of_jpeg2000_data(
  data : BytesView,
) -> PdfObject raise PdfError {
  let (width, height) = pdf_jpeg2000_dimensions_view(data)
  let payload = data.to_owned()
  pdf_stream(
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
) -> (PdfObject, Array[(Int, PdfObject)]) raise PdfError {
  (pdf_image_object_of_jpeg2000_data(data), [])
}

///|
/// Source-spelled cpdfimage `obj_of_jpeg2000_data` wrapper.
pub fn pdf_obj_of_jpeg2000_data(
  data : BytesView,
) -> (PdfObject, Array[(Int, PdfObject)]) raise PdfError {
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
) -> Array[(PdfName, PdfObject)] {
  let entries : Array[(PdfName, PdfObject)] = [
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
    pdf_flate_decode(self.idat),
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
    pdf_flate_encode(Bytes::from_array(colors)),
    pdf_flate_encode(Bytes::from_array(mask)),
  )
}

///|
/// Build a PDF image XObject for PNG data, adding an `/SMask` object to
/// `self` when the PNG carries an alpha channel.
pub fn PdfDocument::pdf_image_object_of_png_data(
  self : PdfDocument,
  data : BytesView,
) -> PdfObject raise PdfError {
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
      let smask = pdf_stream(PdfDictionary(mask_entries), StreamGot(mask))
      let smask_number = self.add_object(smask)
      entries.push((pdf_image_smask_key(), PdfIndirect(smask_number)))
    }
    None => ()
  }
  pdf_stream(PdfDictionary(entries), StreamGot(image_data))
}

///|
/// Build a PDF image XObject for PNG data using `document` for any alpha mask
/// object that must be added.
pub fn pdf_image_object_of_png_data(
  document : PdfDocument,
  data : BytesView,
) -> PdfObject raise PdfError {
  document.pdf_image_object_of_png_data(data)
}

///|
/// Compatibility wrapper matching cpdfimage's `obj_of_png_data` result shape.
pub fn pdf_image_obj_of_png_data(
  document : PdfDocument,
  data : BytesView,
) -> (PdfObject, Array[(Int, PdfObject)]) raise PdfError {
  (document.pdf_image_object_of_png_data(data), [])
}

///|
/// Source-spelled cpdfimage `obj_of_png_data` wrapper.
pub fn pdf_obj_of_png_data(
  document : PdfDocument,
  data : BytesView,
) -> (PdfObject, Array[(Int, PdfObject)]) raise PdfError {
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
) -> (PdfObject, Array[(Int, PdfObject)]) raise PdfError {
  let payload = data.to_owned()
  let (width, height) = pdf_image_jbig2_dimensions_view(data)
  let entries : Array[(PdfName, PdfObject)] = [
    (pdf_image_length_key(), PdfInteger(payload.length())),
    (pdf_image_filter_key(), PdfNameObject(pdf_image_jbig2decode_name())),
    (pdf_image_subtype_key(), PdfNameObject(pdf_image_image_name())),
    (pdf_image_bits_per_component_key(), PdfInteger(1)),
    (pdf_image_colorspace_key(), PdfNameObject(pdf_image_device_gray_name())),
    (pdf_image_width_key(), PdfInteger(width)),
    (pdf_image_height_key(), PdfInteger(height)),
  ]
  let extra : Array[(Int, PdfObject)] = Array::new(
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
          pdf_stream(
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
  (pdf_stream(PdfDictionary(entries), StreamGot(payload)), extra)
}

///|
/// Compatibility wrapper matching cpdfimage's `obj_of_jbig2_data`.
pub fn pdf_image_obj_of_jbig2_data(
  data : BytesView,
  global? : BytesView? = None,
) -> (PdfObject, Array[(Int, PdfObject)]) raise PdfError {
  pdf_image_object_of_jbig2_data(data, global~)
}

///|
/// Source-spelled cpdfimage `obj_of_jbig2_data` wrapper.
pub fn pdf_obj_of_jbig2_data(
  data : BytesView,
  global? : BytesView? = None,
) -> (PdfObject, Array[(Int, PdfObject)]) raise PdfError {
  pdf_image_obj_of_jbig2_data(data, global~)
}

///|
fn PdfDocument::pdf_image_add_structure_tree(
  self : PdfDocument,
  subformat : PdfUASubformat?,
  title : String,
) -> Unit raise PdfError {
  let structure_root_number = self.add_object(PdfNull)
  let figure_number = self.add_object(PdfNull)
  let parent_tree_number = self.add_object(PdfNull)
  let figure_reference = PdfIndirect(figure_number)
  let parent_tree = PdfDictionary([
    (
      pdf_image_nums_key(),
      PdfArray([PdfInteger(1), PdfArray([figure_reference])]),
    ),
  ])
  self.add_object_given_number(parent_tree_number, parent_tree)
  match subformat {
    Some(PdfUA2) => {
      let ns_object = PdfIndirect(
        self.add_object(
          PdfDictionary([
            (pdf_image_ns_key(), PdfString(pdf_image_pdfua2_namespace)),
          ]),
        ),
      )
      let document_number = self.add_object(PdfNull)
      self.add_object_given_number(
        document_number,
        PdfDictionary([
          (pdf_structure_k_key(), PdfArray([figure_reference])),
          (pdf_image_p_key(), PdfIndirect(structure_root_number)),
          (pdf_image_s_key(), PdfNameObject(pdf_image_document_name())),
          (pdf_image_ns_key(), ns_object),
        ]),
      )
      self.add_object_given_number(
        figure_number,
        PdfDictionary([
          (pdf_structure_k_key(), PdfArray([PdfInteger(0)])),
          (pdf_image_p_key(), PdfIndirect(document_number)),
          (pdf_image_s_key(), PdfNameObject(pdf_image_figure_name())),
          (pdf_image_alt_key(), PdfString(@utf8.encode(title))),
        ]),
      )
      self.add_object_given_number(
        structure_root_number,
        PdfDictionary([
          (pdf_image_namespaces_key(), PdfArray([ns_object])),
          (pdf_ua_type_key(), PdfNameObject(pdf_ua_struct_tree_root())),
          (pdf_structure_k_key(), PdfArray([PdfIndirect(document_number)])),
          (pdf_structure_parent_tree_key(), PdfIndirect(parent_tree_number)),
        ]),
      )
    }
    _ => {
      self.add_object_given_number(
        figure_number,
        PdfDictionary([
          (pdf_structure_k_key(), PdfArray([PdfInteger(0)])),
          (pdf_image_p_key(), PdfIndirect(structure_root_number)),
          (pdf_image_s_key(), PdfNameObject(pdf_image_figure_name())),
          (pdf_image_alt_key(), PdfString(@utf8.encode(title))),
        ]),
      )
      self.add_object_given_number(
        structure_root_number,
        PdfDictionary([
          (pdf_ua_type_key(), PdfNameObject(pdf_ua_struct_tree_root())),
          (pdf_structure_k_key(), PdfArray([figure_reference])),
          (pdf_structure_parent_tree_key(), PdfIndirect(parent_tree_number)),
        ]),
      )
    }
  }
  self.replace_chain(
    [pdf_structure_root_key(), pdf_structure_struct_tree_root_key()],
    PdfIndirect(structure_root_number),
  )
}

///|
fn pdf_image_title_for_subformat(
  subformat : PdfUASubformat?,
  title : String?,
) -> String raise PdfError {
  match (subformat, title) {
    (Some(_), Some(title)) => title
    (Some(_), None) => raise TitleExpected
    (None, Some(title)) => title
    (None, None) => ""
  }
}

///|
fn pdf_image_content_ops(
  structinfo : Bool,
  width : Int,
  height : Int,
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = Array::new(
    capacity=if structinfo { 4 } else { 2 },
  )
  if structinfo {
    output.push(
      Op_BDC(
        pdf_image_figure_name(),
        PdfDictionary([(pdf_image_mcid_key(), PdfInteger(0))]),
      ),
    )
  }
  output.push(
    Op_cm({
      ..transform_identity_matrix,
      a: width.to_double(),
      d: height.to_double(),
    }),
  )
  output.push(Op_Do(pdf_image_i0_name()))
  if structinfo {
    output.push(Op_EMC)
  }
  output
}

///|
fn PdfDocument::pdf_image_add_image_page(
  self : PdfDocument,
  image : PdfObject,
  process_struct_tree : Bool,
  subformat : PdfUASubformat?,
  title : String?,
) -> Unit raise PdfError {
  let title = pdf_image_title_for_subformat(subformat, title)
  let structinfo = process_struct_tree || subformat != None
  let width = self.pdf_image_lookup_int_or_else(
    pdf_image_width_key(),
    pdf_image_w_key(),
    image,
  )
  let height = self.pdf_image_lookup_int_or_else(
    pdf_image_height_key(),
    pdf_image_h_key(),
    image,
  )
  let image_number = self.add_object(image)
  let page : PdfPage = {
    content: [
      pdf_content_stream_of_ops(
        pdf_image_content_ops(structinfo, width, height),
      ),
    ],
    mediabox: PdfArray([
      PdfReal(0.0),
      PdfReal(0.0),
      PdfReal(width.to_double()),
      PdfReal(height.to_double()),
    ]),
    resources: PdfDictionary([
      (
        pdf_image_xobject_key(),
        PdfDictionary([(pdf_image_i0_name(), PdfIndirect(image_number))]),
      ),
    ]),
    rotate: Rotate0,
    rest: if structinfo {
      PdfDictionary([(pdf_image_struct_parents_key(), PdfInteger(1))])
    } else {
      PdfDictionary([])
    },
  }
  let page_root = self.add_pagetree([page])
  ignore(self.add_root(page_root, []))
  if structinfo {
    self.pdf_image_add_structure_tree(subformat, title)
  }
  match subformat {
    Some(subformat) => self.pdf_ua_apply_subformat_metadata(subformat, title)
    None => ()
  }
}

///|
/// Build a single-page PDF document that draws `image` at its natural size.
pub fn pdf_image_document_of_object(
  image : PdfObject,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  document.pdf_image_add_image_page(
    image, process_struct_tree, subformat, title,
  )
  document
}

///|
/// Compatibility wrapper matching cpdfimage's `image_of_input`.
///
/// The input side is represented by a byte view instead of `Pdfio.input`;
/// `object_of_data` receives the document so PNG masks and similar side objects
/// can be added through the same document before the page is built.
pub fn pdf_image_of_input(
  data : BytesView,
  object_of_data : (PdfDocument, BytesView) -> (
    PdfObject,
    Array[(Int, PdfObject)],
  ) raise PdfError,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  let (image, extra_objects) = object_of_data(document, data)
  for extra in extra_objects {
    document.add_object_given_number(extra.0, extra.1)
  }
  document.pdf_image_add_image_page(
    image, process_struct_tree, subformat, title,
  )
  document
}

///|
/// Build a single-page PDF document from JPEG data.
pub fn pdf_image_document_of_jpeg_data(
  data : BytesView,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  pdf_image_document_of_object(
    pdf_image_object_of_jpeg_data(data),
    process_struct_tree~,
    subformat~,
    title~,
  )
}

///|
/// Build a single-page PDF document from JPEG2000 data.
pub fn pdf_image_document_of_jpeg2000_data(
  data : BytesView,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  pdf_image_document_of_object(
    pdf_image_object_of_jpeg2000_data(data),
    process_struct_tree~,
    subformat~,
    title~,
  )
}

///|
/// Build a single-page PDF document from PNG data.
pub fn pdf_image_document_of_png_data(
  data : BytesView,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  let image = document.pdf_image_object_of_png_data(data)
  document.pdf_image_add_image_page(
    image, process_struct_tree, subformat, title,
  )
  document
}

///|
/// Build a single-page PDF document from JBIG2 data.
pub fn pdf_image_document_of_jbig2_data(
  data : BytesView,
  global? : BytesView? = None,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  let (image, extra_objects) = pdf_image_object_of_jbig2_data(data, global~)
  for extra in extra_objects {
    document.add_object_given_number(extra.0, extra.1)
  }
  document.pdf_image_add_image_page(
    image, process_struct_tree, subformat, title,
  )
  document
}

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
          None => raise DictionaryKeyNotFound(pdf_image_colorspace_key())
        }
      None => raise DictionaryKeyNotFound(pdf_image_colorspace_key())
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
priv struct PdfImageListEntry {
  object_number : Int
  pages : Array[Int]
  name : String
  width : Int
  height : Int
  byte_count : Int
  bits_per_component : Int?
  colourspace : String?
  filter : String?
  mask : String
  mask_object_number : Int?
}

///|
fn pdf_image_json_int(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn pdf_image_json_int_or_null(value : Int?) -> Json {
  match value {
    Some(value) => pdf_image_json_int(value)
    None => Json::null()
  }
}

///|
fn pdf_image_json_string_or_null(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn pdf_image_name_to_string(name : PdfName) -> String raise PdfError {
  @ascii.decode(name.bytes()) catch {
    _ =>
      @ascii.decode(pdf_write_object(PdfNameObject(name))) catch {
        _ => raise InvalidUTF8
      }
  }
}

///|
fn pdf_image_add_unique_page(pages : Array[Int], page_number : Int) -> Unit {
  if !pages.contains(page_number) {
    pages.push(page_number)
  }
}

///|
fn pdf_image_list_find_entry(
  entries : ArrayView[PdfImageListEntry],
  object_number : Int,
) -> Int {
  if object_number <= 0 {
    -1
  } else {
    for index in 0..<entries.length() {
      if entries[index].object_number == object_number {
        break index
      }
    } nobreak {
      -1
    }
  }
}

///|
fn PdfDocument::pdf_image_lookup_int_or_default(
  self : PdfDocument,
  first_key : PdfName,
  second_key : PdfName,
  image : PdfObject,
  default : Int,
) -> Int raise PdfError {
  match self.lookup_direct_or_else(first_key, second_key, image) {
    Some(value) => self.get_number(value).to_int()
    None => default
  }
}

///|
fn PdfDocument::pdf_image_stream_length(
  self : PdfDocument,
  image : PdfObject,
  fallback : Int,
) -> Int {
  match self.lookup_direct(pdf_image_length_key(), image) {
    Some(PdfInteger(value)) => value
    _ => fallback
  }
}

///|
fn PdfDocument::pdf_image_bits_per_component_number(
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
fn PdfDocument::pdf_image_colourspace_name(
  self : PdfDocument,
  image : PdfObject,
  resources : PdfObject,
) -> String? {
  Some(self.image_colour_space(image, resources).debug_name()) catch {
    _ => None
  }
}

///|
fn pdf_image_single_filter_object(filter : PdfObject) -> PdfObject {
  match filter {
    PdfArray([single]) => single
    _ => filter
  }
}

///|
fn pdf_image_filter_is_name(filter : PdfObject, name : PdfName) -> Bool {
  match filter {
    PdfNameObject(filter_name) => filter_name == name
    PdfArray([PdfNameObject(filter_name)]) => filter_name == name
    _ => false
  }
}

///|
fn PdfDocument::pdf_image_first_decodeparms(
  self : PdfDocument,
  image : PdfObject,
) -> PdfObject? {
  match
    self.lookup_direct_or_else(
      pdf_image_decodeparms_key(),
      pdf_image_dp_key(),
      image,
    ) {
    Some(PdfArray([first, ..])) =>
      match self.direct(first) {
        PdfDictionary(_) as dictionary => Some(dictionary)
        _ => None
      }
    Some(PdfDictionary(_) as dictionary) => Some(dictionary)
    _ => None
  }
}

///|
fn PdfDocument::pdf_image_decodeparms_k(
  self : PdfDocument,
  image : PdfObject,
) -> Int? {
  match self.pdf_image_first_decodeparms(image) {
    Some(decodeparms) =>
      match self.lookup_direct(pdf_image_k_key(), decodeparms) {
        Some(PdfInteger(value)) => Some(value)
        _ => None
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_image_decodeparms_has_jbig2_globals(
  self : PdfDocument,
  image : PdfObject,
) -> Bool {
  match self.pdf_image_first_decodeparms(image) {
    Some(decodeparms) =>
      match self.lookup_direct(pdf_image_jbig2_globals_key(), decodeparms) {
        Some(_) => true
        None => false
      }
    None => false
  }
}

///|
fn PdfDocument::pdf_image_filter_name(
  self : PdfDocument,
  image : PdfObject,
) -> String? raise PdfError {
  match
    self.lookup_direct_or_else(pdf_image_filter_key(), pdf_image_f_key(), image) {
    Some(filter) if pdf_image_filter_is_name(
        filter,
        pdf_image_ccittfaxdecode_name(),
      ) =>
      match self.pdf_image_decodeparms_k(image) {
        Some(value) if value < 0 => Some("/CCITTFaxDecodeG4")
        Some(value) if value > 0 => Some("/CCITTFaxDecodeG32D")
        Some(0) => Some("/CCITTFaxDecodeG31D")
        _ => Some("/CCITTFaxDecode")
      }
    Some(filter) if pdf_image_filter_is_name(
        filter,
        pdf_image_jbig2decode_name(),
      ) =>
      if self.pdf_image_decodeparms_has_jbig2_globals(image) {
        Some("/JBIG2DecodeLossy")
      } else {
        Some("/JBIG2DecodeLossless")
      }
    Some(filter) =>
      Some(
        @ascii.decode(pdf_write_object(pdf_image_single_filter_object(filter))) catch {
          _ => raise InvalidUTF8
        },
      )
    None => None
  }
}

///|
fn PdfDocument::pdf_image_indirect_mask_number(
  self : PdfDocument,
  image : PdfObject,
  key : PdfName,
) -> Int? {
  match self.direct(image) {
    PdfDictionary(entries)
    | PdfStreamObject({ dictionary: PdfDictionary(entries), .. }) =>
      for entry in entries {
        if entry.0 == key {
          break match entry.1 {
            PdfIndirect(number) => Some(number)
            _ => None
          }
        }
      } nobreak {
        None
      }
    _ => None
  }
}

///|
fn PdfDocument::pdf_image_list_mask(
  self : PdfDocument,
  resources : PdfObject,
  page_number : Int,
  image : PdfObject,
  inline : Bool,
  entries : Array[PdfImageListEntry],
  form_numbers : @hashmap.HashMap[Int, Bool],
) -> (String, Int?) raise PdfError {
  match
    self.lookup_direct_or_else(
      pdf_image_image_mask_key(),
      pdf_image_im_key(),
      image,
    ) {
    Some(PdfBoolean(true)) => ("ImageMask", None)
    _ =>
      match self.lookup_direct(pdf_image_mask_key(), image) {
        Some(PdfStreamObject(_)) => {
          let number = self.pdf_image_indirect_mask_number(
            image,
            pdf_image_mask_key(),
          )
          match number {
            Some(number) =>
              self.pdf_image_collect_xobject(
                resources,
                page_number,
                pdf_image_name("/Mask"),
                PdfIndirect(number),
                inline,
                entries,
                form_numbers,
              )
            None => ()
          }
          ("ExplicitMask", number)
        }
        Some(_) => ("ColourKeyMask", None)
        None =>
          match self.lookup_direct(pdf_image_smask_key(), image) {
            Some(_) => {
              let number = self.pdf_image_indirect_mask_number(
                image,
                pdf_image_smask_key(),
              )
              match number {
                Some(number) =>
                  self.pdf_image_collect_xobject(
                    resources,
                    page_number,
                    pdf_image_name("/SMask"),
                    PdfIndirect(number),
                    inline,
                    entries,
                    form_numbers,
                  )
                None => ()
              }
              ("SMask", number)
            }
            None =>
              match self.lookup_direct(pdf_image_smask_in_data_key(), image) {
                Some(_) => ("SMaskInData", None)
                None => ("NoMask", None)
              }
          }
      }
  }
}

///|
fn PdfDocument::pdf_image_list_add_image(
  self : PdfDocument,
  resources : PdfObject,
  page_number : Int,
  name : PdfName,
  image : PdfObject,
  object_number : Int,
  data_length : Int,
  inline : Bool,
  entries : Array[PdfImageListEntry],
  form_numbers : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  let existing = pdf_image_list_find_entry(entries, object_number)
  if existing >= 0 {
    pdf_image_add_unique_page(entries[existing].pages, page_number)
  } else {
    let (mask, mask_object_number) = self.pdf_image_list_mask(
      resources, page_number, image, inline, entries, form_numbers,
    )
    entries.push({
      object_number,
      pages: [page_number],
      name: pdf_image_name_to_string(name),
      width: self.pdf_image_lookup_int_or_default(
        pdf_image_width_key(),
        pdf_image_w_key(),
        image,
        1,
      ),
      height: self.pdf_image_lookup_int_or_default(
        pdf_image_height_key(),
        pdf_image_h_key(),
        image,
        1,
      ),
      byte_count: self.pdf_image_stream_length(image, data_length),
      bits_per_component: self.pdf_image_bits_per_component_number(image),
      colourspace: self.pdf_image_colourspace_name(image, resources),
      filter: self.pdf_image_filter_name(image),
      mask,
      mask_object_number,
    })
  }
}

///|
fn PdfDocument::pdf_image_collect_inline_images(
  self : PdfDocument,
  resources : PdfObject,
  page_number : Int,
  content : ArrayView[PdfObject],
  entries : Array[PdfImageListEntry],
  form_numbers : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  let ops = self.parse_content_ops_with_resources(resources, content)
  for op in ops {
    match op {
      Op_InlineImage(dictionary, _, data) => {
        let image = dictionary
          .add_dict_entry(
            pdf_image_subtype_key(),
            PdfNameObject(pdf_image_image_name()),
          )
          .add_dict_entry(pdf_image_length_key(), PdfInteger(data.length()))
        self.pdf_image_list_add_image(
          PdfDictionary([]),
          page_number,
          pdf_image_name("/InlineImage"),
          image,
          0,
          data.length(),
          true,
          entries,
          form_numbers,
        )
      }
      _ => ()
    }
  }
}

///|
fn PdfDocument::pdf_image_collect_xobject(
  self : PdfDocument,
  resources : PdfObject,
  page_number : Int,
  name : PdfName,
  xobject : PdfObject,
  inline : Bool,
  entries : Array[PdfImageListEntry],
  form_numbers : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_image_subtype_key(), xobject) {
    Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() => {
      let object_number = match xobject {
        PdfIndirect(number) => number
        _ => 0
      }
      self.pdf_image_list_add_image(
        resources, page_number, name, xobject, object_number, 0, inline, entries,
        form_numbers,
      )
    }
    Some(PdfNameObject(subtype)) if subtype == pdf_image_form_name() =>
      match xobject {
        PdfIndirect(number) =>
          if !form_numbers.contains(number) {
            form_numbers[number] = true
            let form = self.direct(xobject)
            let form_resources = match
              self.lookup_direct(pdf_xobject_resources_key(), form) {
              Some(resources) => resources
              None => PdfDictionary([])
            }
            if inline {
              self.pdf_image_collect_inline_images(
                form_resources,
                page_number,
                [form],
                entries,
                form_numbers,
              )
            }
            match self.lookup_direct(pdf_image_xobject_key(), form_resources) {
              Some(PdfDictionary(xobjects)) =>
                for entry in xobjects {
                  self.pdf_image_collect_xobject(
                    form_resources,
                    page_number,
                    entry.0,
                    entry.1,
                    inline,
                    entries,
                    form_numbers,
                  )
                }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_image_collect_page_images(
  self : PdfDocument,
  page : PdfPage,
  page_number : Int,
  inline : Bool,
  entries : Array[PdfImageListEntry],
  form_numbers : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  if inline {
    self.pdf_image_collect_inline_images(
      page.resources,
      page_number,
      page.content,
      entries,
      form_numbers,
    )
  }
  match self.lookup_direct(pdf_image_xobject_key(), page.resources) {
    Some(PdfDictionary(xobjects)) =>
      for entry in xobjects {
        self.pdf_image_collect_xobject(
          page.resources,
          page_number,
          entry.0,
          entry.1,
          inline,
          entries,
          form_numbers,
        )
      }
    _ => ()
  }
}

///|
fn pdf_image_list_entry_json(entry : PdfImageListEntry) -> Json {
  entry.pages.sort()
  Json::object(
    Map([
      ("Object", pdf_image_json_int(entry.object_number)),
      (
        "Pages",
        Json::array(
          [
            for page_number in entry.pages => pdf_image_json_int(page_number)
          ],
        ),
      ),
      ("Name", Json::string(entry.name)),
      ("Width", pdf_image_json_int(entry.width)),
      ("Height", pdf_image_json_int(entry.height)),
      ("Bytes", pdf_image_json_int(entry.byte_count)),
      ("BitsPerComponent", pdf_image_json_int_or_null(entry.bits_per_component)),
      ("Colourspace", pdf_image_json_string_or_null(entry.colourspace)),
      ("Filter", pdf_image_json_string_or_null(entry.filter)),
      ("Mask", Json::string(entry.mask)),
      ("MaskObjNum", pdf_image_json_int_or_null(entry.mask_object_number)),
    ]),
  )
}

///|
/// List image XObjects referenced by selected pages as cpdf-style JSON rows.
pub fn PdfDocument::images_json(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  inline? : Bool = false,
) -> Json raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "images")
  let entries : Array[PdfImageListEntry] = Array::new(
    capacity=page_numbers.length(),
  )
  let form_numbers : @hashmap.HashMap[Int, Bool] = HashMap([])
  for page_number in page_numbers {
    self.pdf_image_collect_page_images(
      pages[page_number - 1],
      page_number,
      inline,
      entries,
      form_numbers,
    )
  }
  Json::array([ for entry in entries => pdf_image_list_entry_json(entry) ])
}

///|
/// List image XObjects referenced by selected pages as UTF-8 JSON bytes.
pub fn PdfDocument::images_json_blob(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  inline? : Bool = false,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.images_json(page_numbers, inline~).stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::images_json`.
pub fn pdf_image_images(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Json raise PdfError {
  document.images_json(page_numbers, inline~)
}

///|
/// Source-spelled compatibility wrapper for cpdfimage's `images`.
pub fn pdf_images(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Json raise PdfError {
  document.images_json(page_numbers, inline~)
}

///|
/// Compatibility wrapper for `PdfDocument::images_json_blob`.
pub fn pdf_image_images_json_blob(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  document.images_json_blob(page_numbers, inline~)
}

///|
priv enum PdfImageResolutionObject {
  PdfImageResolutionImage(Int, Int)
  PdfImageResolutionForm(TransformMatrix, PdfObject, PdfObject)
}

///|
priv struct PdfImageResolutionCandidate {
  name : PdfName
  object : PdfImageResolutionObject
  object_number : Int
}

///|
priv struct PdfImageResolutionEntry {
  page_number : Int
  xobject : String
  width : Int
  height : Int
  xdpi : Double
  ydpi : Double
  object_number : Int
}

///|
fn pdf_image_resolution_compare_double(left : Double, right : Double) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn pdf_image_resolution_entry_compare(
  left : PdfImageResolutionEntry,
  right : PdfImageResolutionEntry,
) -> Int {
  let page = left.page_number.compare(right.page_number)
  if page != 0 {
    page
  } else {
    let xobject = left.xobject.compare(right.xobject)
    if xobject != 0 {
      xobject
    } else {
      let width = left.width.compare(right.width)
      if width != 0 {
        width
      } else {
        let height = left.height.compare(right.height)
        if height != 0 {
          height
        } else {
          let xdpi = pdf_image_resolution_compare_double(left.xdpi, right.xdpi)
          if xdpi != 0 {
            xdpi
          } else {
            let ydpi = pdf_image_resolution_compare_double(
              left.ydpi,
              right.ydpi,
            )
            if ydpi != 0 {
              ydpi
            } else {
              left.object_number.compare(right.object_number)
            }
          }
        }
      }
    }
  }
}

///|
fn pdf_image_resolution_distance(left : Point2, right : Point2) -> Double {
  let dx = right.x - left.x
  let dy = right.y - left.y
  (dx * dx + dy * dy).sqrt()
}

///|
fn pdf_image_resolution_inches(matrix : TransformMatrix) -> (Double, Double) {
  let origin = matrix.apply(point2(0.0, 0.0))
  let x_axis = matrix.apply(point2(1.0, 0.0))
  let y_axis = matrix.apply(point2(0.0, 1.0))
  (
    unit_inches(pdf_image_resolution_distance(origin, x_axis), PdfPoint),
    unit_inches(pdf_image_resolution_distance(origin, y_axis), PdfPoint),
  )
}

///|
fn pdf_image_resolution_push_entry(
  entries : Array[PdfImageResolutionEntry],
  page_number : Int,
  name : PdfName,
  width : Int,
  height : Int,
  object_number : Int,
  matrix : TransformMatrix,
) -> Unit raise PdfError {
  let (x_inches, y_inches) = pdf_image_resolution_inches(matrix)
  entries.push({
    page_number,
    xobject: pdf_image_name_to_string(name),
    width,
    height,
    xdpi: width.to_double() / x_inches,
    ydpi: height.to_double() / y_inches,
    object_number,
  })
}

///|
fn PdfDocument::pdf_image_resolution_lookup_inline_int(
  self : PdfDocument,
  first_key : PdfName,
  second_key : PdfName,
  image : PdfObject,
) -> Int? {
  match self.lookup_direct_or_else(first_key, second_key, image) {
    Some(PdfInteger(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_image_resolution_find_candidate(
  candidates : ArrayView[PdfImageResolutionCandidate],
  name : PdfName,
) -> PdfImageResolutionCandidate? {
  for candidate in candidates {
    if candidate.name == name {
      break Some(candidate)
    }
  } nobreak {
    None
  }
}

///|
fn PdfDocument::pdf_image_resolution_candidates(
  self : PdfDocument,
  resources : PdfObject,
) -> Array[PdfImageResolutionCandidate] raise PdfError {
  match self.lookup_direct(pdf_image_xobject_key(), resources) {
    Some(PdfDictionary(xobjects)) => {
      let candidates : Array[PdfImageResolutionCandidate] = Array::new(
        capacity=xobjects.length(),
      )
      for entry in xobjects {
        let object_number = match entry.1 {
          PdfIndirect(number) => number
          _ => 0
        }
        match self.lookup_direct(pdf_image_subtype_key(), entry.1) {
          Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() =>
            candidates.push({
              name: entry.0,
              object: PdfImageResolutionImage(
                self.pdf_image_lookup_int_or_default(
                  pdf_image_width_key(),
                  pdf_image_width_key(),
                  entry.1,
                  1,
                ),
                self.pdf_image_lookup_int_or_default(
                  pdf_image_height_key(),
                  pdf_image_height_key(),
                  entry.1,
                  1,
                ),
              ),
              object_number,
            })
          Some(PdfNameObject(subtype)) if subtype == pdf_image_form_name() => {
            let form = self.direct(entry.1)
            let form_resources = match
              self.lookup_direct(pdf_xobject_resources_key(), form) {
              Some(resources) => resources
              None => resources
            }
            candidates.push({
              name: entry.0,
              object: PdfImageResolutionForm(
                self.parse_matrix(pdf_image_matrix_key(), form),
                form,
                form_resources,
              ),
              object_number,
            })
          }
          _ => ()
        }
      }
      candidates
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_image_resolution_process_content(
  self : PdfDocument,
  resources : PdfObject,
  content : ArrayView[PdfObject],
  candidates : ArrayView[PdfImageResolutionCandidate],
  page_number : Int,
  inline : Bool,
  initial_matrix : TransformMatrix,
  depth : Int,
  results : Array[PdfImageResolutionEntry],
) -> Unit raise PdfError {
  if depth > 64 {
    return
  }
  let ops = self.parse_content_ops_with_resources(resources, content)
  let transforms : Array[TransformMatrix] = [initial_matrix]
  for op in ops {
    match op {
      Op_cm(matrix) =>
        if transforms.length() > 0 {
          let index = transforms.length() - 1
          transforms[index] = transform_matrix_compose(
            transforms[index],
            matrix,
          )
        }
      Op_q =>
        if transforms.length() > 0 {
          transforms.push(transforms[transforms.length() - 1])
        }
      Op_Q => if transforms.length() > 0 { ignore(transforms.pop()) }
      Op_InlineImage(dictionary, _, _) =>
        if inline && transforms.length() > 0 {
          match
            (
              self.pdf_image_resolution_lookup_inline_int(
                pdf_image_width_key(),
                pdf_image_w_key(),
                dictionary,
              ),
              self.pdf_image_resolution_lookup_inline_int(
                pdf_image_height_key(),
                pdf_image_h_key(),
                dictionary,
              ),
            ) {
            (Some(width), Some(height)) =>
              pdf_image_resolution_push_entry(
                results,
                page_number,
                pdf_image_name("/InlineImage"),
                width,
                height,
                0,
                transforms[transforms.length() - 1],
              )
            _ => ()
          }
        }
      Op_Do(name) =>
        if transforms.length() > 0 {
          match pdf_image_resolution_find_candidate(candidates, name) {
            Some(
              {
                object: PdfImageResolutionImage(width, height),
                object_number,
                ..,
              }
            ) =>
              pdf_image_resolution_push_entry(
                results,
                page_number,
                name,
                width,
                height,
                object_number,
                transforms[transforms.length() - 1],
              )
            Some(
              {
                object: PdfImageResolutionForm(matrix, form, form_resources),
                ..,
              }
            ) => {
              let form_candidates = self.pdf_image_resolution_candidates(
                form_resources,
              )
              self.pdf_image_resolution_process_content(
                form_resources,
                [form],
                form_candidates,
                page_number,
                inline,
                transform_matrix_compose(
                  matrix,
                  transforms[transforms.length() - 1],
                ),
                depth + 1,
                results,
              )
            }
            None => ()
          }
        }
      _ => ()
    }
  }
}

///|
/// Report image resolutions for selected pages.
///
/// Results match cpdf's tuple order: page number, XObject name, image width,
/// image height, horizontal DPI, vertical DPI, and object number. Entries are
/// kept when either axis is below `dpi`.
pub fn PdfDocument::image_resolution(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
  inline? : Bool = false,
) -> Array[(Int, String, Int, Int, Double, Double, Int)] raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "images")
  let results : Array[PdfImageResolutionEntry] = Array::new(
    capacity=page_numbers.length(),
  )
  for page_number in page_numbers {
    let page = pages[page_number - 1]
    let candidates = self.pdf_image_resolution_candidates(page.resources)
    if inline || candidates.length() > 0 {
      self.pdf_image_resolution_process_content(
        page.resources,
        page.content,
        candidates,
        page_number,
        inline,
        transform_identity_matrix,
        0,
        results,
      )
    }
  }
  let filtered : Array[PdfImageResolutionEntry] = Array::new(
    capacity=results.length(),
  )
  for entry in results {
    if entry.xdpi < dpi || entry.ydpi < dpi {
      filtered.push(entry)
    }
  }
  filtered.sort_by(pdf_image_resolution_entry_compare)
  [
    for entry in filtered => {
      (
        entry.page_number,
        entry.xobject,
        entry.width,
        entry.height,
        entry.xdpi,
        entry.ydpi,
        entry.object_number,
      )
    }
  ]
}

///|
fn pdf_image_resolution_entry_json(
  entry : (Int, String, Int, Int, Double, Double, Int),
) -> Json {
  Json::object(
    Map([
      ("Object", pdf_image_json_int(entry.6)),
      ("Page", pdf_image_json_int(entry.0)),
      ("XObject", Json::string(entry.1)),
      ("W", pdf_image_json_int(entry.2)),
      ("H", pdf_image_json_int(entry.3)),
      ("Xdpi", Json::number(entry.4)),
      ("Ydpi", Json::number(entry.5)),
    ]),
  )
}

///|
/// Report image resolution data as cpdf-style JSON rows.
pub fn PdfDocument::image_resolution_json(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
  inline? : Bool = false,
) -> Json raise PdfError {
  Json::array(
    [
      for entry in self.image_resolution(page_numbers, dpi, inline~) => {
        pdf_image_resolution_entry_json(entry)
      }
    ],
  )
}

///|
/// Report image resolution data as UTF-8 JSON bytes.
pub fn PdfDocument::image_resolution_json_blob(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
  inline? : Bool = false,
) -> PdfBytes raise PdfError {
  @utf8.encode(
    self.image_resolution_json(page_numbers, dpi, inline~).stringify(),
  )
}

///|
/// Compatibility wrapper for `PdfDocument::image_resolution`.
pub fn pdf_image_resolution(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
) -> Array[(Int, String, Int, Int, Double, Double, Int)] raise PdfError {
  document.image_resolution(page_numbers, dpi, inline~)
}

///|
/// Compatibility wrapper for `PdfDocument::image_resolution_json`.
pub fn pdf_image_resolution_json(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
) -> Json raise PdfError {
  document.image_resolution_json(page_numbers, dpi, inline~)
}

///|
/// Compatibility wrapper for `PdfDocument::image_resolution_json_blob`.
pub fn pdf_image_resolution_json_blob(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
) -> PdfBytes raise PdfError {
  document.image_resolution_json_blob(page_numbers, dpi, inline~)
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
