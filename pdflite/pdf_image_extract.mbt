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
