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
