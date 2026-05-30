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
  encoding? : @metadata.PdfMetadataEncoding = PdfMetadataUTF8,
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
  encoding : @metadata.PdfMetadataEncoding,
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
