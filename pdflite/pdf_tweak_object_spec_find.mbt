///|
fn PdfDocument::pdf_tweak_find_chained_object(
  self : PdfDocument,
  start : PdfObject,
  chain : ArrayView[PdfName],
  source : String,
) -> PdfObject raise PdfError {
  match self.lookup_chain(start, chain) {
    Some(object) => object
    None => raise BadPageSpecification(source)
  }
}

///|
fn PdfDocument::pdf_tweak_find_numbered_object(
  self : PdfDocument,
  number : Int,
  chain : ArrayView[PdfName],
  source : String,
) -> PdfObject raise PdfError {
  let object = if number == 0 {
    self.trailer_dict()
  } else {
    self.lookup_object_or_null(number)
  }
  self.pdf_tweak_find_chained_object(object, chain, source)
}
