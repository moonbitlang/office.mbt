///|
fn pdf_spot_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_spot_separation_name : @core.PdfName = pdf_spot_name("/Separation")

///|
fn pdf_spot_separation() -> @core.PdfName {
  pdf_spot_separation_name
}

///|
fn pdf_spot_colour_of_object(
  document : PdfDocument,
  object : @syntax.PdfObject,
) -> @core.PdfName? {
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
pub fn PdfDocument::list_spot_colours(
  self : PdfDocument,
) -> Array[@core.PdfName] {
  let colours : Array[@core.PdfName] = []
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
pub fn PdfDocument::list_spot_colours_blob(
  self : PdfDocument,
) -> @core.PdfBytes {
  let names = self.list_spot_colours()
  let mut output_length = 0
  for name in names {
    output_length += name.bytes().length() + 1
  }
  let output = Array::make(output_length, b'\n')
  let mut position = 0
  for name in names {
    for byte in name.bytes() {
      output[position] = byte
      position += 1
    }
    position += 1
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::list_spot_colours`.
pub fn pdf_list_spot_colours(document : PdfDocument) -> Array[@core.PdfName] {
  document.list_spot_colours()
}

///|
/// Compatibility wrapper for `PdfDocument::list_spot_colours_blob`.
pub fn pdf_list_spot_colours_blob(document : PdfDocument) -> @core.PdfBytes {
  document.list_spot_colours_blob()
}
