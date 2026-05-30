///|
fn pdf_create_blank_pages(
  paper : PaperSize,
  page_count : Int,
) -> Array[@page.PdfPage] {
  let pages : Array[@page.PdfPage] = []
  if page_count > 0 {
    for _ in 0..<page_count {
      pages.push(@page.pdf_page_blank(paper))
    }
  }
  pages
}

///|
fn pdf_create_blank_document_with_id_time(
  paper : PaperSize,
  page_count : Int,
  get_time : () -> Double,
) -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  let page_root_number = document.add_pagetree(
    pdf_create_blank_pages(paper, page_count),
  )
  ignore(document.add_root(page_root_number, []))
  document.change_id("", get_time)
  document
}

///|
fn pdf_create_now_as_double() -> Double {
  @env.now().to_double()
}

///|
/// Create a blank document from page dimensions in PDF points.
pub fn pdf_blank_document(
  width : Double,
  height : Double,
  page_count : Int,
) -> PdfDocument raise PdfError {
  pdf_create_blank_document_with_id_time(
    paper_size_make(PdfPoint, width, height),
    page_count,
    pdf_create_now_as_double,
  )
}

///|
/// Create a blank document from a named paper size.
pub fn pdf_blank_document_paper(
  paper : PaperSize,
  page_count : Int,
) -> PdfDocument raise PdfError {
  pdf_create_blank_document_with_id_time(
    paper, page_count, pdf_create_now_as_double,
  )
}
