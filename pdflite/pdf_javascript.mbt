///|
fn pdf_javascript_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_javascript_js_key_name : PdfName = pdf_javascript_name("/JS")

///|
fn pdf_javascript_js_key() -> PdfName {
  pdf_javascript_js_key_name
}

///|
let pdf_javascript_uri_key_name : PdfName = pdf_javascript_name("/URI")

///|
fn pdf_javascript_uri_key() -> PdfName {
  pdf_javascript_uri_key_name
}

///|
let pdf_javascript_s_key_name : PdfName = pdf_javascript_name("/S")

///|
fn pdf_javascript_s_key() -> PdfName {
  pdf_javascript_s_key_name
}

///|
let pdf_javascript_root_key_name : PdfName = pdf_javascript_name("/Root")

///|
fn pdf_javascript_root_key() -> PdfName {
  pdf_javascript_root_key_name
}

///|
let pdf_javascript_names_key_name : PdfName = pdf_javascript_name("/Names")

///|
fn pdf_javascript_names_key() -> PdfName {
  pdf_javascript_names_key_name
}

///|
let pdf_javascript_javascript_key_name : PdfName = pdf_javascript_name(
  "/JavaScript",
)

///|
fn pdf_javascript_javascript_key() -> PdfName {
  pdf_javascript_javascript_key_name
}

///|
let pdf_javascript_empty_bytes : PdfBytes = @ascii.encode("")

///|
fn pdf_javascript_empty_string() -> PdfObject {
  PdfString(pdf_javascript_empty_bytes)
}

///|
let pdf_javascript_action_bytes : PdfBytes = @ascii.encode("/JavaScript")

///|
let pdf_javascript_uri_prefix_bytes : PdfBytes = @ascii.encode("javascript:")

///|
fn pdf_javascript_bytes_equal(left : BytesView, right : BytesView) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    for index in 0..<left.length() {
      if left[index] != right[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_javascript_bytes_has_prefix(
  bytes : BytesView,
  prefix : BytesView,
) -> Bool {
  if bytes.length() < prefix.length() {
    false
  } else {
    for index in 0..<prefix.length() {
      if bytes[index] != prefix[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn PdfDocument::pdf_javascript_object_has_uri(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_javascript_uri_key(), object) {
    Some(PdfString(bytes)) =>
      pdf_javascript_bytes_has_prefix(bytes, pdf_javascript_uri_prefix_bytes)
    _ => false
  }
}

///|
fn PdfDocument::pdf_javascript_object_has_action(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_javascript_s_key(), object) {
    Some(PdfString(bytes)) =>
      pdf_javascript_bytes_equal(bytes, pdf_javascript_action_bytes)
    _ => false
  }
}

///|
fn PdfDocument::pdf_javascript_object_has_javascript(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  self.pdf_javascript_object_has_action(object) ||
  self.pdf_javascript_object_has_uri(object)
}

///|
fn PdfDocument::pdf_javascript_remove_from_dictionary(
  self : PdfDocument,
  object : PdfObject,
) -> PdfObject {
  let mut output = object
  match self.lookup_direct(pdf_javascript_js_key(), output) {
    Some(_) =>
      output = try! output.add_dict_entry(
        pdf_javascript_js_key(),
        pdf_javascript_empty_string(),
      )
    None => ()
  }
  match self.lookup_direct(pdf_javascript_uri_key(), output) {
    Some(PdfString(bytes)) if pdf_javascript_bytes_has_prefix(
        bytes, pdf_javascript_uri_prefix_bytes,
      ) =>
      output = try! output.add_dict_entry(
        pdf_javascript_uri_key(),
        pdf_javascript_empty_string(),
      )
    _ => ()
  }
  output
}

///|
fn PdfDocument::pdf_javascript_remove_from_object(
  self : PdfDocument,
  object : PdfObject,
) -> PdfObject {
  match object {
    PdfDictionary(entries) => {
      let rewritten = pdf_recurse_dict(
        fn(child) { self.pdf_javascript_remove_from_object(child) },
        entries,
      )
      self.pdf_javascript_remove_from_dictionary(rewritten)
    }
    PdfStreamObject(stream) =>
      match stream.dictionary {
        PdfDictionary(entries) => {
          stream.dictionary = pdf_recurse_dict(
            fn(child) { self.pdf_javascript_remove_from_object(child) },
            entries,
          )
          self.pdf_javascript_remove_from_dictionary(PdfStreamObject(stream))
        }
        _ => object
      }
    PdfArray(values) =>
      pdf_recurse_array(
        fn(child) { self.pdf_javascript_remove_from_object(child) },
        values,
      )
    _ => object
  }
}

///|
fn PdfDocument::pdf_javascript_object_contains(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  if self.pdf_javascript_object_has_javascript(object) {
    true
  } else {
    match object {
      PdfDictionary(entries) =>
        for entry in entries {
          if self.pdf_javascript_object_contains(entry.1) {
            break true
          }
        } nobreak {
          false
        }
      PdfStreamObject(stream) =>
        self.pdf_javascript_object_contains(stream.dictionary)
      PdfArray(values) =>
        for value in values {
          if self.pdf_javascript_object_contains(value) {
            break true
          }
        } nobreak {
          false
        }
      _ => false
    }
  }
}

///|
fn PdfDocument::pdf_javascript_has_name_tree(self : PdfDocument) -> Bool {
  self.lookup_chain(self.trailer_dict(), [
    pdf_javascript_root_key(),
    pdf_javascript_names_key(),
    pdf_javascript_javascript_key(),
  ]) !=
  None
}

///|
/// Return whether parsed document objects or the root names tree contain
/// cpdf-style JavaScript markers.
///
/// This follows cpdf's historical checks: `/URI` strings are detected only when
/// they begin with lowercase `javascript:`, and `/S` is detected only when its
/// resolved value is the PDF string `/JavaScript`.
pub fn PdfDocument::contains_javascript(self : PdfDocument) -> Bool {
  for entry in self.parsed_object_entries() {
    if self.pdf_javascript_object_contains(entry.2) {
      break true
    }
  } nobreak {
    self.pdf_javascript_has_name_tree()
  }
}

///|
/// Empty `/JS` strings, empty lowercase `javascript:` URI strings, and remove
/// the `/Root /Names /JavaScript` chain.
pub fn PdfDocument::remove_javascript(
  self : PdfDocument,
) -> Unit raise PdfError {
  self.map_objects_in_place(fn(object) {
    self.pdf_javascript_remove_from_object(object)
  })
  ignore(
    self.remove_chain([
      pdf_javascript_root_key(),
      pdf_javascript_names_key(),
      pdf_javascript_javascript_key(),
    ]),
  )
}

///|
/// Compatibility wrapper for `PdfDocument::contains_javascript`.
pub fn pdf_contains_javascript(document : PdfDocument) -> Bool {
  document.contains_javascript()
}

///|
/// Compatibility wrapper for `PdfDocument::remove_javascript`.
pub fn pdf_remove_javascript(document : PdfDocument) -> Unit raise PdfError {
  document.remove_javascript()
}
