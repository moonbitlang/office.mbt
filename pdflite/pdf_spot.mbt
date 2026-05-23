///|
fn pdf_spot_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_spot_separation_name : PdfName = pdf_spot_name("/Separation")

///|
fn pdf_spot_separation() -> PdfName {
  pdf_spot_separation_name
}

///|
fn pdf_spot_colour_of_object(
  document : PdfDocument,
  object : PdfObject,
) -> PdfName? {
  match object {
    PdfArray([PdfNameObject(kind), colourant, ..]) if kind ==
      pdf_spot_separation() =>
      match document.direct(colourant) {
        PdfNameObject(name) => Some(name)
        _ => None
      }
    _ => None
  }
}

///|
/// Return spot colourant names from top-level `/Separation` colour-space objects.
///
/// This follows cpdf's `list_spot_colours` scan: it iterates document objects
/// and reports arrays whose first entry is `/Separation`; nested arrays inside
/// dictionaries are not recursively scanned by this helper.
pub fn PdfDocument::list_spot_colours(self : PdfDocument) -> Array[PdfName] {
  let colours : Array[PdfName] = []
  for entry in self.parsed_object_entries() {
    match pdf_spot_colour_of_object(self, entry.2) {
      Some(name) => colours.push(name)
      None => ()
    }
  }
  colours
}

///|
/// Return the bytes cpdf's `list_spot_colours` would print to stdout.
pub fn PdfDocument::list_spot_colours_blob(self : PdfDocument) -> PdfBytes {
  let output : Array[Byte] = []
  for name in self.list_spot_colours() {
    pdf_writer_push_view(output, name.bytes())
    output.push(10)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::list_spot_colours`.
pub fn pdf_list_spot_colours(document : PdfDocument) -> Array[PdfName] {
  document.list_spot_colours()
}

///|
/// Compatibility wrapper for `PdfDocument::list_spot_colours_blob`.
pub fn pdf_list_spot_colours_blob(document : PdfDocument) -> PdfBytes {
  document.list_spot_colours_blob()
}
