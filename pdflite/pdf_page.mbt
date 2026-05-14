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
      _ => raise ParseStreamExpected
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

///|
fn pdf_page_reference_numbers_inner(
  pdf : PdfDocument,
  pages_node : PdfObject,
  node_number : Int,
  depth : Int,
) -> Array[Int] raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match pdf.lookup_direct(pdf_page_type_key(), pages_node) {
    Some(PdfNameObject(name)) if name == pdf_page_type_page() => [node_number]
    _ =>
      match pdf.lookup_direct(pdf_page_kids_key(), pages_node) {
        Some(PdfArray(kids)) => {
          let output : Array[Int] = []
          for kid in kids {
            match kid {
              PdfIndirect(number) => {
                let child = pdf.direct(kid)
                if child != PdfNull {
                  for
                    page_number in pdf_page_reference_numbers_inner(
                      pdf,
                      child,
                      number,
                      depth + 1,
                    ) {
                    output.push(page_number)
                  }
                }
              }
              _ => ()
            }
          }
          output
        }
        _ => [node_number]
      }
  }
}

///|
fn PdfDocument::pdf_pages_of_pagetree_quick_node(
  self : PdfDocument,
  node : PdfObject,
  depth : Int,
) -> Int raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  if node == PdfNull {
    0
  } else {
    match self.lookup_direct(pdf_page_type_key(), node) {
      Some(PdfNameObject(name)) if name != pdf_page_type_pages() => 1
      _ =>
        match self.lookup_direct(pdf_page_kids_key(), node) {
          Some(PdfArray(kids)) => {
            let mut count = 0
            for kid in kids {
              match kid {
                PdfIndirect(number) => {
                  let child = self.lookup_object_or_null(number)
                  if child == PdfNull {
                    raise PageTreeExpected
                  }
                  count += self.pdf_pages_of_pagetree_quick_node(
                    child,
                    depth + 1,
                  )
                }
                PdfDictionary(_) =>
                  count += self.pdf_pages_of_pagetree_quick_node(kid, depth + 1)
                _ => raise PageTreeExpected
              }
            }
            count
          }
          _ => raise PageTreeExpected
        }
    }
  }
}

///|
fn pdf_page_root_pages_node(pdf : PdfDocument) -> PdfObject raise PdfError {
  let root = match pdf.pdf_page_active_catalog() {
    Some((catalog, _)) => catalog
    None => raise RootExpected
  }
  match pdf.lookup_direct(pdf_page_pages_key(), root) {
    Some(pages) => pages
    None => raise PageTreeExpected
  }
}

///|
/// Return page object numbers in page-tree order.
pub fn PdfDocument::page_reference_numbers(
  self : PdfDocument,
) -> Array[Int] raise PdfError {
  pdf_page_reference_numbers_inner(self, pdf_page_root_pages_node(self), -1, 0)
}

///|
/// Compatibility wrapper for `PdfDocument::page_reference_numbers`.
pub fn pdf_page_reference_numbers(
  document : PdfDocument,
) -> Array[Int] raise PdfError {
  document.page_reference_numbers()
}

///|
/// Count pages by walking the page tree without materializing `PdfPage` records.
pub fn PdfDocument::pages_of_pagetree_quick(
  self : PdfDocument,
) -> Int raise PdfError {
  self.pdf_pages_of_pagetree_quick_node(pdf_page_root_pages_node(self), 0)
}

///|
/// Return the object number for a 1-based page number.
///
/// Out-of-range page numbers return `None`.
pub fn PdfDocument::page_object_number(
  self : PdfDocument,
  page_number : Int,
) -> Int? raise PdfError {
  let references = self.page_reference_numbers()
  if page_number < 1 || page_number > references.length() {
    None
  } else {
    Some(references[page_number - 1])
  }
}

///|
/// Compatibility wrapper for `PdfDocument::page_object_number`.
pub fn pdf_page_object_number(
  document : PdfDocument,
  page_number : Int,
) -> Int? raise PdfError {
  document.page_object_number(page_number)
}

///|
/// Resolve a destination target to a 1-based page number.
pub fn PdfDocument::page_number_of_target(
  self : PdfDocument,
  destination : PdfDestination,
) -> Int raise PdfError {
  self.pdf_destination_page_number(destination, self.page_reference_numbers())
}

///|
/// Compatibility wrapper for `PdfDocument::page_number_of_target`.
pub fn pdf_pagenumber_of_target(
  document : PdfDocument,
  destination : PdfDestination,
) -> Int raise PdfError {
  document.page_number_of_target(destination)
}

///|
/// Build a fit destination for a 1-based page number.
///
/// Out-of-range page numbers return `DestNull`.
pub fn PdfDocument::target_of_page_number(
  self : PdfDocument,
  page_number : Int,
) -> PdfDestination raise PdfError {
  match self.page_object_number(page_number) {
    Some(object_number) => DestFit(TargetPageObject(object_number))
    None => DestNull
  }
}

///|
/// Compatibility wrapper for `PdfDocument::target_of_page_number`.
pub fn pdf_target_of_pagenumber(
  document : PdfDocument,
  page_number : Int,
) -> PdfDestination raise PdfError {
  document.target_of_page_number(page_number)
}

///|
/// Return the number of pages by walking the page tree.
pub fn PdfDocument::endpage(self : PdfDocument) -> Int raise PdfError {
  self.pages_of_pagetree_quick()
}

///|
/// Compatibility wrapper for `PdfDocument::endpage`.
pub fn pdf_endpage(document : PdfDocument) -> Int raise PdfError {
  document.endpage()
}

///|
/// Return the root page-tree `/Count` value without validating child pages.
///
/// Missing or malformed counts return `0`.
pub fn PdfDocument::endpage_fast(self : PdfDocument) -> Int raise PdfError {
  match
    self.lookup_direct(pdf_page_count_key(), pdf_page_root_pages_node(self)) {
    Some(PdfInteger(count)) => count
    _ => 0
  }
}

///|
/// Compatibility wrapper for `PdfDocument::endpage_fast`.
pub fn pdf_endpage_fast(document : PdfDocument) -> Int raise PdfError {
  document.endpage_fast()
}
