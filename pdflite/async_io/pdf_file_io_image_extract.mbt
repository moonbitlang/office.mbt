///|
fn pdf_async_io_extracted_image_has_smask(
  stem : String,
  files : ArrayView[@pdflite.PdfExtractedImageFile],
) -> Bool {
  let mask_prefix = stem + "-smask."
  for file in files {
    if file.path.has_prefix(mask_prefix) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_async_io_extracted_image_has_any_smask(
  files : ArrayView[@pdflite.PdfExtractedImageFile],
) -> Bool {
  for file in files {
    if file.path.contains("-smask") {
      break true
    }
  } nobreak {
    false
  }
}

///|
/// Extract one image object and write cpdf-style image files to disk.
///
/// This is the native filesystem counterpart of cpdfimage's
/// `extract_single_image`. The core extraction path emits raw PNM for decoded
/// image data; external PNM-to-PNG conversion remains outside this wrapper.
pub async fn pdf_extract_single_image_to_files(
  document : @pdflite.PdfDocument,
  object_number : Int,
  stem : StringView,
  raw? : Bool = false,
  path_to_p2p? : String = "",
  path_to_im? : String = "",
  merge_masks? : Bool = false,
  permission? : Int = 0o644,
) -> Array[String] {
  ignore(raw)
  ignore(path_to_p2p)
  ignore(path_to_im)
  let stem_text = stem.to_owned()
  let files = document.extract_single_image_files(object_number, stem_text)
  let paths : Array[String] = []
  for file in files {
    @fs.write_file(file.path, file.data, create=permission)
    paths.push(file.path)
  }
  if merge_masks && pdf_async_io_extracted_image_has_smask(stem_text, files) {
    @pdflite.pdf_error("combine_image_and_mask: imagemagick not found")
  }
  paths
}

///|
/// Compatibility wrapper matching cpdfimage's `extract_single_image`.
pub async fn pdf_extract_single_image(
  merge_masks : Bool,
  encoding : @metadata.PdfMetadataEncoding,
  document : @pdflite.PdfDocument,
  object_number : Int,
  stem : StringView,
  raw? : Bool = false,
  path_to_p2p? : String = "",
  path_to_im? : String = "",
  permission? : Int = 0o644,
) -> Unit {
  ignore(encoding)
  ignore(
    pdf_extract_single_image_to_files(
      document,
      object_number,
      stem,
      raw~,
      path_to_p2p~,
      path_to_im~,
      merge_masks~,
      permission~,
    ),
  )
}

///|
/// Extract page images and write cpdf-style image files to disk.
///
/// This is the native filesystem counterpart of cpdfimage's `extract_images`.
/// The core extraction path emits raw PNM for decoded image data; external
/// PNM-to-PNG conversion remains outside this wrapper.
pub async fn pdf_extract_images_to_files(
  document : @pdflite.PdfDocument,
  page_numbers : ArrayView[Int],
  stem : StringView,
  encoding? : @metadata.PdfMetadataEncoding = PdfMetadataUTF8,
  inline? : Bool = false,
  dedup? : Bool = false,
  dedup_per_page? : Bool = false,
  raw? : Bool = false,
  path_to_p2p? : String = "",
  path_to_im? : String = "",
  merge_masks? : Bool = false,
  permission? : Int = 0o644,
) -> Array[String] {
  ignore(raw)
  ignore(path_to_p2p)
  ignore(path_to_im)
  let files = document.extract_images_files(
    page_numbers,
    stem.to_owned(),
    encoding~,
    inline~,
    dedup~,
    dedup_per_page~,
  )
  let paths : Array[String] = []
  for file in files {
    @fs.write_file(file.path, file.data, create=permission)
    paths.push(file.path)
  }
  if merge_masks && pdf_async_io_extracted_image_has_any_smask(files) {
    @pdflite.pdf_error("combine_image_and_mask: imagemagick not found")
  }
  paths
}

///|
/// Compatibility wrapper matching cpdfimage's `extract_images`.
pub async fn pdf_extract_images(
  merge_masks : Bool,
  inline : Bool,
  encoding : @metadata.PdfMetadataEncoding,
  dedup : Bool,
  dedup_per_page : Bool,
  document : @pdflite.PdfDocument,
  page_numbers : ArrayView[Int],
  stem : StringView,
  raw? : Bool = false,
  path_to_p2p? : String = "",
  path_to_im? : String = "",
  permission? : Int = 0o644,
) -> Unit {
  ignore(
    pdf_extract_images_to_files(
      document,
      page_numbers,
      stem,
      encoding~,
      inline~,
      dedup~,
      dedup_per_page~,
      raw~,
      path_to_p2p~,
      path_to_im~,
      merge_masks~,
      permission~,
    ),
  )
}
