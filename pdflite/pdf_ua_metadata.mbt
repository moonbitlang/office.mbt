///|
fn pdf_ua_create_pdfua(
  subformat : PdfUASubformat,
  title : String,
  paper : PaperSize,
  page_count : Int,
) -> PdfDocument raise PdfError {
  let document = pdf_create_blank_document_with_id_time(
    paper, page_count, pdf_create_now_as_double,
  )
  document.pdf_ua_apply_subformat_metadata(subformat, title)
  document
}

///|
/// Create a blank PDF/UA-1 document with the given title and page size.
pub fn pdf_ua_create_pdfua1(
  title : String,
  paper : PaperSize,
  page_count : Int,
) -> PdfDocument raise PdfError {
  pdf_ua_create_pdfua(PdfUA1, title, paper, page_count)
}

///|
/// Create a blank PDF/UA-2 document with the given title and page size.
pub fn pdf_ua_create_pdfua2(
  title : String,
  paper : PaperSize,
  page_count : Int,
) -> PdfDocument raise PdfError {
  pdf_ua_create_pdfua(PdfUA2, title, paper, page_count)
}

///|
/// Return a copy of the document marked as PDF/UA-1 in its XMP metadata.
pub fn PdfDocument::mark_pdfua1(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  self.pdf_ua_mark_inner("1", None)
}

///|
/// Return a copy of the document marked as PDF/UA-2 for the given revision year.
pub fn PdfDocument::mark_pdfua2(
  self : PdfDocument,
  year : Int,
) -> PdfDocument raise PdfError {
  self.pdf_ua_mark_inner("2", Some(year))
}

///|
/// Return a copy of the document with PDF/UA XMP marker fields removed.
pub fn PdfDocument::remove_pdfua_mark(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  match self.metadata() {
    None => self
    Some(metadata) => {
      let without_marker = pdf_ua_remove_marker_elements(metadata)
      self.set_metadata_from_bytes(without_marker, keep_version=true)
    }
  }
}
