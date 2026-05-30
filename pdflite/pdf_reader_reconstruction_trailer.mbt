///|
fn PdfDocument::select_reconstructed_trailer(
  self : PdfDocument,
  trailers : ArrayView[@syntax.PdfObject],
) -> @syntax.PdfObject raise PdfError {
  for offset in 0..<trailers.length() {
    let index = trailers.length() - 1 - offset
    let trailer = trailers[index]
    match trailer.lookup_immediate(@reader.pdf_reader_root_name()) {
      Some(PdfIndirect(root)) =>
        match self.lookup_object_or_null(root) {
          PdfDictionary(_) => break trailer
          _ => ()
        }
      _ => ()
    }
  } nobreak {
    match self.infer_reconstructed_catalog_trailer() {
      Some(trailer) => trailer
      None => raise RootExpected
    }
  }
}

///|
fn PdfDocument::infer_reconstructed_catalog_trailer(
  self : PdfDocument,
) -> @syntax.PdfObject? {
  for number in self.object_numbers() {
    let object = self.lookup_object_or_null(number)
    match object {
      PdfDictionary(_) =>
        if object.lookup_immediate(pdf_page_type_key()) ==
          Some(PdfNameObject(pdf_page_type_catalog())) &&
          object.lookup_immediate(pdf_page_pages_key()) is Some(_) {
          break Some(
            PdfDictionary([
              (@reader.pdf_reader_root_name(), PdfIndirect(number)),
            ]),
          )
        }
      _ => ()
    }
  } nobreak {
    None
  }
}

///|
fn PdfDocument::set_trailer_and_root(
  self : PdfDocument,
  trailer : @syntax.PdfObject,
) -> Unit raise PdfError {
  self.set_trailer_dict(trailer)
  match trailer.lookup_immediate(@reader.pdf_reader_root_name()) {
    Some(PdfIndirect(root)) => self.set_root(root)
    _ => raise RootExpected
  }
}
