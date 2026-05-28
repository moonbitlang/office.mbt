///|
/// Read one document revision from a borrowed byte view.
///
/// Revision selection uses strict classic-xref parsing and does not use the
/// reconstruction fallback used by `pdf_read_document_from_view`.
pub fn pdf_read_document_revision_from_view(
  data : BytesView,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_revision_from_view(data, revision)
}

///|
/// Read one document revision from owned PDF bytes.
pub fn pdf_read_document_revision_from_bytes(
  data : PdfBytes,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_document_revision_from_view(data, revision)
}

///|
/// Read a PDF document from owned PDF bytes.
pub fn pdf_read_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_document_from_view(data)
}
