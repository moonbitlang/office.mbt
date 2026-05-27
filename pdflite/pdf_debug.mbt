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
fn pdf_debug_concat_chunks(chunks : ArrayView[PdfBytes]) -> PdfBytes {
  let mut output_length = 0
  for chunk in chunks {
    output_length += chunk.length()
  }
  let output = Array::make(output_length, b'\x00')
  let mut position = 0
  for chunk in chunks {
    for byte in chunk {
      output[position] = byte
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_debug_object_line(
  prefix : String,
  object : PdfObject,
) -> PdfBytes raise PdfError {
  pdf_bytes_concat_views([
    @ascii.encode(prefix),
    pdf_string_of_pdf(object),
    @ascii.encode("\n"),
  ])
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
  let object_entries = self.parsed_object_entries()
  let chunks : Array[PdfBytes] = Array::new(
    capacity=object_entries.length() * 3 + 4,
  )
  chunks.push(pdf_debug_object_line("Trailerdict: ", self.trailer_dict()))
  chunks.push(@ascii.encode("Root: " + self.root().to_string() + "\n"))
  match self.lookup_direct(pdf_debug_root_key(), self.trailer_dict()) {
    Some(catalog) => {
      chunks.push(pdf_debug_object_line("Catalog: ", catalog))
      match self.lookup_direct(pdf_debug_pages_key(), catalog) {
        Some(pages) => chunks.push(pdf_debug_object_line("Pages: ", pages))
        None => chunks.push(@ascii.encode("no catalog\n"))
      }
    }
    None => chunks.push(@ascii.encode("No catalog!\n"))
  }
  for entry in object_entries {
    let (number, _, object) = entry
    chunks.push(@ascii.encode(number.to_string() + " 0 obj:\n\n"))
    chunks.push(pdf_string_of_pdf(object))
    chunks.push(@ascii.encode("\n"))
  }
  pdf_debug_concat_chunks(chunks)
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
