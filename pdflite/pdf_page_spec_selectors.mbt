///|
fn PdfDocumentPageSpecContext::select_dimensions(
  self : PdfDocumentPageSpecContext,
  candidates : ArrayView[Int],
  portrait : Bool,
) -> Array[Int] raise PdfError {
  let pages = self.document.pages_of_pagetree()
  let output : Array[Int] = Array::new(capacity=candidates.length())
  for page_number in candidates {
    if page_number >= 1 && page_number <= pages.length() {
      let page = pages[page_number - 1]
      let rectangle = self.document.parse_rectangle(page.mediabox)
      let width = rectangle.max_x - rectangle.min_x
      let height = rectangle.max_y - rectangle.min_y
      if (portrait && width < height) || (!portrait && width > height) {
        output.push(page_number)
      }
    }
  }
  output
}

///|
fn PdfDocumentPageSpecContext::select_annotated(
  self : PdfDocumentPageSpecContext,
  candidates : ArrayView[Int],
) -> Array[Int] raise PdfError {
  let pages = self.document.pages_of_pagetree()
  let output : Array[Int] = Array::new(capacity=candidates.length())
  for page_number in candidates {
    if page_number >= 1 && page_number <= pages.length() {
      let page = pages[page_number - 1]
      match self.document.lookup_direct(pdf_page_annots_key(), page.rest) {
        Some(PdfArray(annotations)) if annotations.length() > 0 =>
          output.push(page_number)
        _ => ()
      }
    }
  }
  output
}
