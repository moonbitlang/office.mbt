///|
fn PdfDocument::sanitize_reader_trailer(
  self : PdfDocument,
) -> Unit raise PdfError {
  self.set_trailer_dict(
    @reader.pdf_reader_sanitize_trailer(
      self.trailer_dict(),
      self.objects.max_object_number() + 1,
    ),
  )
}
