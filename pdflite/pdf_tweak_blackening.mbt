///|
/// Paint text on selected one-based pages and Form XObjects with `colour`.
pub fn PdfDocument::black_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : @colour.PdfContentColour,
) -> PdfDocument raise @core.PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, fn(
        doc,
        resources,
        streams,
      ) raise @core.PdfError {
        pdf_tweak_black_text_xobject(colour, doc, resources, streams)
      })
      rewritten.push(document.pdf_tweak_black_text_page(page, colour))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::black_text`.
pub fn pdf_black_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : @colour.PdfContentColour,
) -> PdfDocument raise @core.PdfError {
  document.black_text(page_numbers, colour)
}

///|
/// Compatibility wrapper matching cpdftweak's `blacktext` name and order.
pub fn pdf_blacktext(
  colour : @colour.PdfContentColour,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  document.black_text(page_numbers, colour)
}

///|
/// Paint line strokes on selected one-based pages and Form XObjects with `colour`.
pub fn PdfDocument::black_lines(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : @colour.PdfContentColour,
) -> PdfDocument raise @core.PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, fn(
        doc,
        resources,
        streams,
      ) raise @core.PdfError {
        pdf_tweak_black_lines_xobject(colour, doc, resources, streams)
      })
      rewritten.push(document.pdf_tweak_black_lines_page(page, colour))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::black_lines`.
pub fn pdf_black_lines(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : @colour.PdfContentColour,
) -> PdfDocument raise @core.PdfError {
  document.black_lines(page_numbers, colour)
}

///|
/// Compatibility wrapper matching cpdftweak's `blacklines` name and order.
pub fn pdf_blacklines(
  colour : @colour.PdfContentColour,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  document.black_lines(page_numbers, colour)
}

///|
/// Paint fills on selected one-based pages and Form XObjects with `colour`.
pub fn PdfDocument::black_fills(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : @colour.PdfContentColour,
) -> PdfDocument raise @core.PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, fn(
        doc,
        resources,
        streams,
      ) raise @core.PdfError {
        pdf_tweak_black_fills_xobject(colour, doc, resources, streams)
      })
      rewritten.push(document.pdf_tweak_black_fills_page(page, colour))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::black_fills`.
pub fn pdf_black_fills(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : @colour.PdfContentColour,
) -> PdfDocument raise @core.PdfError {
  document.black_fills(page_numbers, colour)
}

///|
/// Compatibility wrapper matching cpdftweak's `blackfills` name and order.
pub fn pdf_blackfills(
  colour : @colour.PdfContentColour,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  document.black_fills(page_numbers, colour)
}
