///|
fn PdfDocument::pdf_bookmark_name_for_page(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  split_level : Int,
  page_number : Int,
) -> String raise PdfError {
  for bookmark in bookmarks {
    if bookmark.level <= split_level &&
      self.page_number_of_target(bookmark.target) == page_number {
      let text = @utf8.decode(pdf_utf8_of_pdfdocstring(bookmark.text)) catch {
        _ => raise InvalidUTF8
      }
      return pdf_attachment_remove_unsafe_characters(text)
    }
  }
  ""
}
