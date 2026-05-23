///|
fn pdf_debug_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_debug_root_key_name : PdfName = pdf_debug_name("/Root")

///|
fn pdf_debug_root_key() -> PdfName {
  pdf_debug_root_key_name
}

///|
let pdf_debug_pages_key_name : PdfName = pdf_debug_name("/Pages")

///|
fn pdf_debug_pages_key() -> PdfName {
  pdf_debug_pages_key_name
}

///|
fn pdf_debug_push_object(
  output : Array[Byte],
  object : PdfObject,
) -> Unit raise PdfError {
  pdf_writer_push_view(output, pdf_string_of_pdf(object))
}

///|
fn pdf_debug_push_object_line(
  output : Array[Byte],
  prefix : String,
  object : PdfObject,
) -> Unit raise PdfError {
  pdf_writer_push_ascii(output, prefix)
  pdf_debug_push_object(output, object)
  pdf_writer_push_byte(output, 10)
}

///|
/// Render the CamlPDF-style object dump used by cpdf debugging tools.
///
/// The result is byte-oriented because PDF names, strings, and stream bodies are
/// byte sequences in both CamlPDF and this package. Returning bytes also keeps
/// tests exact without relying on stdout capture.
pub fn PdfDocument::debug_objects(
  self : PdfDocument,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  pdf_debug_push_object_line(output, "Trailerdict: ", self.trailer_dict())
  pdf_writer_push_ascii(output, "Root: ")
  pdf_writer_push_ascii(output, self.root().to_string())
  pdf_writer_push_byte(output, 10)
  match self.lookup_direct(pdf_debug_root_key(), self.trailer_dict()) {
    Some(catalog) => {
      pdf_debug_push_object_line(output, "Catalog: ", catalog)
      match self.lookup_direct(pdf_debug_pages_key(), catalog) {
        Some(pages) => pdf_debug_push_object_line(output, "Pages: ", pages)
        None => pdf_writer_push_ascii(output, "no catalog\n")
      }
    }
    None => pdf_writer_push_ascii(output, "No catalog!\n")
  }
  for entry in self.parsed_object_entries() {
    let (number, _, object) = entry
    pdf_writer_push_ascii(output, number.to_string())
    pdf_writer_push_ascii(output, " 0 obj:\n\n")
    pdf_debug_push_object(output, object)
    pdf_writer_push_byte(output, 10)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::debug_objects`.
pub fn pdf_debug_objects(document : PdfDocument) -> PdfBytes raise PdfError {
  document.debug_objects()
}

///|
/// Source-spelled compatibility wrapper for cpdfdebug's printed object dump.
pub fn pdf_print_pdf_objs(document : PdfDocument) -> PdfBytes raise PdfError {
  document.debug_objects()
}
