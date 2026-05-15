///|
fn PdfDocument::pdf_page_prefix_content_streams(
  self : PdfDocument,
  prefix : String,
  page_object : PdfObject,
  fixed_streams : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  let resources = match
    self.lookup_direct(pdf_page_resources_key(), page_object) {
    Some(resources) => resources
    None => PdfDictionary([])
  }
  let contents = self.pdf_page_content_list(
    self.pdf_page_content_object(page_object),
  )
  for content in contents {
    match content {
      PdfIndirect(number) if !fixed_streams.contains(number) => {
        let ops = self.pdf_page_parse_content_ops(resources, [content])
        self.add_object_given_number(
          number,
          pdf_content_stream_of_ops(
            self.pdf_page_prefix_content_ops(prefix, ops),
          ),
        )
        fixed_streams[number] = true
      }
      _ => ()
    }
  }
}

///|
fn PdfDocument::pdf_page_prefix_object(
  self : PdfDocument,
  prefix : String,
  object : PdfObject,
) -> PdfObject raise PdfError {
  match self.lookup_direct(pdf_page_resources_key(), object) {
    Some(resources) =>
      object.add_dict_entry(
        pdf_page_resources_key(),
        self.pdf_page_prefix_resource_dictionary(prefix, resources),
      )
    None => object
  }
}

///|
fn PdfDocument::pdf_page_merged_content_stream(
  self : PdfDocument,
  contents : ArrayView[PdfObject],
) -> PdfObject raise PdfError {
  let decoded_streams : Array[PdfBytes] = []
  for content in contents {
    match self.direct(content) {
      PdfStreamObject(stream) =>
        decoded_streams.push(
          pdf_stream_data_bytes(
            self.pdf_decode_stream_value_direct(stream).data,
          ),
        )
      _ => raise PdfError::ParseStreamExpected
    }
  }
  let data = pdf_content_concat_streams(decoded_streams)
  pdf_stream(
    PdfDictionary([(pdf_page_length_key_name, PdfInteger(data.length()))]),
    StreamGot(data),
  )
}

///|
fn PdfDocument::pdf_page_merge_content_object(
  self : PdfDocument,
  object : PdfObject,
) -> PdfObject raise PdfError {
  match object.lookup_immediate(pdf_page_contents_key()) {
    Some(PdfArray(contents)) if contents.length() != 1 => {
      let stream_number = self.add_object(
        self.pdf_page_merged_content_stream(contents),
      )
      object.add_dict_entry(pdf_page_contents_key(), PdfIndirect(stream_number))
    }
    _ => object
  }
}

///|
/// Merge multi-stream page contents into single decoded streams.
///
/// Only page-like objects with `/Resources` are considered. The document is
/// mutated in place and stream filters are decoded before concatenation.
pub fn PdfDocument::merge_content_streams(
  self : PdfDocument,
) -> Unit raise PdfError {
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    if self.pdf_page_object_uses_page_resources(object) {
      let updated = self.pdf_page_merge_content_object(object)
      if updated != object {
        self.add_object_given_number(number, updated)
      }
    }
  }
}

///|
fn PdfDocument::pdf_page_split_contents_need_merge(
  self : PdfDocument,
  resources : PdfObject,
  contents : ArrayView[PdfObject],
) -> Bool {
  if contents.length() <= 1 {
    false
  } else {
    for content in contents {
      try self.pdf_page_parse_content_ops(resources, [content]) catch {
        _ => break true
      } noraise {
        _ => ()
      }
    } nobreak {
      false
    }
  }
}

///|
fn PdfDocument::pdf_page_object_needs_content_merge(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  if !self.pdf_page_object_uses_page_resources(object) {
    false
  } else {
    let resources = match self.lookup_direct(pdf_page_resources_key(), object) {
      Some(resources) => resources
      None => PdfDictionary([])
    }
    match object.lookup_immediate(pdf_page_contents_key()) {
      Some(PdfArray(contents)) =>
        self.pdf_page_split_contents_need_merge(resources, contents)
      _ => false
    }
  }
}

///|
fn PdfDocument::pdf_page_needs_content_merge(self : PdfDocument) -> Bool {
  for number in self.object_numbers() {
    if self.pdf_page_object_needs_content_merge(
        self.lookup_object_or_null(number),
      ) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn PdfDocument::pdf_page_add_prefix(
  self : PdfDocument,
  prefix : String,
) -> Unit raise PdfError {
  let fixed_streams : @hashmap.HashMap[Int, Bool] = HashMap([])
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    if self.pdf_page_object_uses_page_resources(object) {
      self.pdf_page_prefix_content_streams(prefix, object, fixed_streams)
      self.add_object_given_number(
        number,
        self.pdf_page_prefix_object(prefix, object),
      )
    }
  }
}

///|
/// Prefix all page resource names and corresponding content references.
///
/// If split content streams cannot be parsed independently, content streams are
/// merged first. This mutates the document in place and is useful before
/// combining pages from multiple documents.
pub fn PdfDocument::add_prefix(
  self : PdfDocument,
  prefix : String,
) -> Unit raise PdfError {
  if self.pdf_page_needs_content_merge() {
    self.merge_content_streams()
  }
  self.pdf_page_add_prefix(prefix)
}

///|
/// Compatibility wrapper for `PdfDocument::add_prefix`.
pub fn pdf_add_prefix(
  document : PdfDocument,
  prefix : String,
) -> Unit raise PdfError {
  document.add_prefix(prefix)
}
