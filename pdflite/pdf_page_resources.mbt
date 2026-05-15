///|
fn pdf_page_name_text_without_slash(name : PdfName) -> String {
  let bytes = name.bytes()
  let view = if bytes.length() > 0 && bytes[0].to_int() == 47 {
    bytes[1:]
  } else {
    bytes
  }
  @ascii.decode(view) catch {
    _ => ""
  }
}

///|
fn pdf_page_string_has_prefix(text : String, prefix : String) -> Bool {
  let text_bytes = @ascii.encode(text)
  let prefix_bytes = @ascii.encode(prefix)
  if prefix_bytes.length() > text_bytes.length() {
    false
  } else {
    for i in 0..<prefix_bytes.length() {
      if text_bytes[i] != prefix_bytes[i] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_page_next_prefix(prefix : String) -> String {
  if prefix == "" {
    "a"
  } else {
    let bytes = @ascii.encode(prefix)
    if bytes[0].to_int() == 122 {
      "a" + prefix
    } else {
      let output = bytes.to_array()
      output[0] = (output[0].to_int() + 1).to_byte()
      try! @ascii.decode(Bytes::from_array(output))
    }
  }
}

///|
fn pdf_page_prefix_is_unused(
  names : ArrayView[String],
  prefix : String,
) -> Bool {
  for name in names {
    if pdf_page_string_has_prefix(name, prefix) {
      break false
    }
  } nobreak {
    true
  }
}

///|
fn PdfDocument::pdf_page_resource_names(
  self : PdfDocument,
  resources : PdfObject,
) -> Array[String] {
  let names : Array[String] = []
  for resource_key in pdf_page_resource_keys() {
    match self.lookup_direct(resource_key, resources) {
      Some(PdfDictionary(entries)) =>
        for entry in entries {
          let (name, _) = entry
          names.push(pdf_page_name_text_without_slash(name))
        }
      _ => ()
    }
  }
  names
}

///|
fn pdf_page_is_resource_key(key : PdfName) -> Bool {
  for resource_key in pdf_page_resource_keys() {
    if key == resource_key {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_page_unknown_resource_entries(
  resources : PdfObject,
) -> Array[(PdfName, PdfObject)] {
  let output : Array[(PdfName, PdfObject)] = []
  match resources {
    PdfDictionary(entries) =>
      for entry in entries {
        let (key, _) = entry
        if !pdf_page_is_resource_key(key) {
          output.push(entry)
        }
      }
    _ => ()
  }
  output
}

///|
fn PdfDocument::pdf_page_resource_entries(
  self : PdfDocument,
  resources : PdfObject,
  key : PdfName,
) -> Array[(PdfName, PdfObject)] {
  match self.lookup_direct(key, resources) {
    Some(PdfDictionary(entries)) => [ for entry in entries => entry ]
    _ => []
  }
}

///|
/// Merge two page resource dictionaries.
///
/// Known resource categories such as `/Font`, `/XObject`, and `/ColorSpace`
/// are concatenated; unknown top-level entries from both dictionaries are
/// preserved. Later duplicate resource names are not renamed here.
pub fn PdfDocument::combine_pdf_resources(
  self : PdfDocument,
  first : PdfObject,
  second : PdfObject,
) -> PdfObject {
  let output : Array[(PdfName, PdfObject)] = []
  for entry in pdf_page_unknown_resource_entries(first) {
    output.push(entry)
  }
  for entry in pdf_page_unknown_resource_entries(second) {
    output.push(entry)
  }
  for key in pdf_page_resource_keys() {
    let entries = self.pdf_page_resource_entries(first, key)
    for entry in self.pdf_page_resource_entries(second, key) {
      entries.push(entry)
    }
    if entries.length() > 0 {
      output.push((key, PdfDictionary(entries)))
    }
  }
  PdfDictionary(output)
}

///|
fn PdfDocument::pdf_page_object_uses_page_resources(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_page_type_key(), object) {
    Some(PdfNameObject(name)) =>
      name == pdf_page_type_page() || name == pdf_page_type_pages()
    _ => false
  }
}

///|
fn pdf_page_merge_dictionary_objects(
  first : PdfObject,
  second : PdfObject,
) -> PdfObject raise PdfError {
  let mut output = first
  match second {
    PdfDictionary(entries) =>
      for entry in entries {
        let (key, value) = entry
        output = output.add_dict_entry(key, value)
      }
    _ => raise PdfError::DictionaryExpected
  }
  output
}

///|
fn PdfDocument::pdf_page_process_form_xobject(
  self : PdfDocument,
  resources : PdfObject,
  object_number : Int,
  process : (PdfDocument, PdfObject, ArrayView[PdfObject]) -> Array[PdfObject] raise PdfError,
) -> Unit raise PdfError {
  let xobject = self.lookup_object_or_null(object_number)
  match self.lookup_direct(pdf_page_subtype_key(), xobject) {
    Some(PdfNameObject(name)) if name == pdf_page_type_form() =>
      match xobject {
        PdfStreamObject(stream) => {
          xobject.get_stream()
          let processed = process(self, resources, [PdfStreamObject(stream)])
          if processed.length() != 1 {
            raise PdfError::ParseStreamExpected
          }
          match processed[0] {
            PdfStreamObject(processed_stream) => {
              let dictionary = pdf_page_merge_dictionary_objects(
                stream.dictionary,
                processed_stream.dictionary,
              ).remove_dict_entry(pdf_page_filter_key())
              self.add_object_given_number(
                object_number,
                PdfStreamObject({ dictionary, data: processed_stream.data }),
              )
            }
            _ => raise PdfError::ParseStreamExpected
          }
        }
        _ => raise PdfError::ParseStreamExpected
      }
    Some(_) => ()
    None => raise PdfError::DictionaryKeyNotFound(pdf_page_subtype_key())
  }
}

///|
/// Adapter for callbacks that process page-like values and return identity geometry.
///
/// This preserves the CamlPDF callback shape by returning the callback result,
/// original number, and identity transform matrix.
pub fn[A, B, C] pdf_page_process_stub(
  process : (A, B) -> C raise,
  number : A,
  page : B,
) -> (C, A, TransformMatrix) raise {
  (process(number, page), number, transform_identity_matrix)
}

///|
/// Process Form XObjects referenced by a page resource dictionary.
///
/// For each indirect `/XObject` with subtype `/Form`, `process` receives the
/// document, page resources, and the form stream. It must return exactly one
/// processed stream, which replaces the original form stream data.
pub fn PdfDocument::process_xobjects(
  self : PdfDocument,
  page : PdfPage,
  process : (PdfDocument, PdfObject, ArrayView[PdfObject]) -> Array[PdfObject] raise PdfError,
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_page_xobject_key(), page.resources) {
    Some(PdfDictionary(entries)) =>
      for entry in entries {
        let (_, value) = entry
        match value {
          PdfIndirect(number) =>
            self.pdf_page_process_form_xobject(page.resources, number, process)
          _ => raise PdfError::DictionaryExpected
        }
      }
    _ => ()
  }
}

///|
/// Return the shortest ASCII prefix unused by page resource names.
///
/// The prefix is suitable for `add_prefix` when merging pages from independent
/// documents with potentially colliding resource names.
pub fn PdfDocument::shortest_unused_prefix(self : PdfDocument) -> String {
  let names : Array[String] = []
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    if self.pdf_page_object_uses_page_resources(object) {
      match self.lookup_direct(pdf_page_resources_key(), object) {
        Some(resources) =>
          for name in self.pdf_page_resource_names(resources) {
            names.push(name)
          }
        None => ()
      }
    }
  }
  let mut prefix = "a"
  while !pdf_page_prefix_is_unused(names, prefix) {
    prefix = pdf_page_next_prefix(prefix)
  }
  prefix
}

///|
/// Compatibility wrapper for `PdfDocument::shortest_unused_prefix`.
pub fn pdf_shortest_unused_prefix(document : PdfDocument) -> String {
  document.shortest_unused_prefix()
}
