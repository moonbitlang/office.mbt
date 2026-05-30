///|
fn PdfDocument::pdf_image_extract_named_images(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  images : ArrayView[@syntax.PdfObject],
  stem : String,
  page_number : Int,
  encoding : @metadata.PdfMetadataEncoding,
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
  resources : @syntax.PdfObject,
) -> (Array[@syntax.PdfObject], Array[@syntax.PdfObject]) {
  match self.lookup_direct(pdf_image_xobject_key(), resources) {
    Some(PdfDictionary(xobjects)) => {
      let images : Array[@syntax.PdfObject] = Array::new(
        capacity=xobjects.length(),
      )
      let forms : Array[@syntax.PdfObject] = Array::new(
        capacity=xobjects.length(),
      )
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
  form : @syntax.PdfObject,
) -> @syntax.PdfObject {
  match self.lookup_direct(pdf_xobject_resources_key(), form) {
    Some(PdfDictionary(entries)) => PdfDictionary(entries)
    _ => PdfDictionary([])
  }
}

///|
fn PdfDocument::pdf_image_extract_form_xobject_files(
  self : PdfDocument,
  form : @syntax.PdfObject,
  stem : String,
  page_number : Int,
  encoding : @metadata.PdfMetadataEncoding,
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
  resources : @syntax.PdfObject,
  content : ArrayView[@syntax.PdfObject],
  stem : String,
  page_number : Int,
  encoding : @metadata.PdfMetadataEncoding,
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
        let image = @syntax.pdf_stream(image_dictionary, StreamGot(data))
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
  form : @syntax.PdfObject,
  stem : String,
  page_number : Int,
  encoding : @metadata.PdfMetadataEncoding,
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
  image : @syntax.PdfObject,
  stem : String,
  page_number : Int,
  encoding : @metadata.PdfMetadataEncoding,
  state : PdfImageExtractionRunState,
) -> Array[PdfExtractedImageFile] raise PdfError {
  match self.direct(image) {
    PdfStreamObject(_) =>
      match self.direct(image).lookup_immediate(pdf_image_smask_key()) {
        Some(PdfIndirect(mask_number)) => {
          let mask = @syntax.PdfIndirect(mask_number)
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
