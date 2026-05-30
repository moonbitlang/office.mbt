///|
/// Convert a TOC title to the PDFDocString stored in the generated bookmark.
///
/// Literal `\n` byte pairs are converted to line-feed bytes before PDFDocString
/// encoding, matching cpdftoc's `real_newline` helper.
pub fn pdf_toc_bookmark_text(title : BytesView) -> PdfBytes raise PdfError {
  pdf_pdfdocstring_of_utf8(pdf_toc_title_real_newlines(title))
}

///|
/// Prepend the generated table-of-contents bookmark.
///
/// Existing bookmarks are preserved at their current levels and order. The new
/// bookmark targets the first page of the current document, which should be the
/// first inserted TOC page after `toc_insert_pages`.
pub fn PdfDocument::toc_add_bookmark(
  self : PdfDocument,
  title : BytesView,
) -> PdfDocument raise PdfError {
  let page_refs = self.page_reference_numbers()
  guard page_refs.length() > 0 else {
    raise SoftError("toc_add_bookmark: no pages")
  }
  let bookmarks = self.read_bookmarks(preserve_actions=true)
  let output : Array[@bookmark.PdfBookmark] = [
    {
      level: 0,
      text: pdf_toc_bookmark_text(title),
      target: DestXYZ(TargetPageObject(page_refs[0]), None, None, None),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ]
  for bookmark in bookmarks {
    output.push(bookmark)
  }
  self.add_bookmarks(output)
}

///|
/// Compatibility wrapper for `PdfDocument::toc_add_bookmark`.
pub fn pdf_toc_add_bookmark(
  document : PdfDocument,
  title : BytesView,
) -> PdfDocument raise PdfError {
  document.toc_add_bookmark(title)
}
