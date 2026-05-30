///|
/// Parse cpdf's plain text bookmark-file format.
///
/// The input is byte-oriented. Bookmark titles are double-quoted UTF-8 text
/// with cpdf's `\\`, `\"`, and `\n` escapes; optional destinations are
/// double-quoted PDF object snippets such as `[1 /Fit]`.
pub fn PdfDocument::parse_bookmark_text(
  self : PdfDocument,
  data : BytesView,
  verify? : Bool = true,
) -> Array[@bookmark.PdfBookmark] raise PdfError {
  let bookmarks : Array[@bookmark.PdfBookmark] = []
  let cursor = byte_cursor_of_view(data)
  for line_number, line in cursor.read_line_views() {
    match self.pdf_bookmark_import_parse_line(line, line_number + 1) {
      Some(bookmark) => bookmarks.push(bookmark)
      None => ()
    }
  }
  if verify && !self.pdf_bookmark_import_verify(bookmarks) {
    raise SoftError(
      "Bad bookmark file (References non-existant pages or is malformed)",
    )
  }
  bookmarks
}

///|
/// Return a copy of the document with bookmarks imported from cpdf text bytes.
pub fn PdfDocument::add_bookmarks_from_text(
  self : PdfDocument,
  data : BytesView,
  verify? : Bool = true,
) -> PdfDocument raise PdfError {
  self.add_bookmarks(self.parse_bookmark_text(data, verify~))
}

///|
/// Compatibility wrapper for `PdfDocument::parse_bookmark_text`.
pub fn pdf_parse_bookmark_text(
  verify : Bool,
  data : BytesView,
  document : PdfDocument,
) -> Array[@bookmark.PdfBookmark] raise PdfError {
  document.parse_bookmark_text(data, verify~)
}

///|
/// Compatibility wrapper matching cpdfbookmarks' plain `parse_bookmark_file`.
pub fn pdf_parse_bookmark_file(
  verify : Bool,
  document : PdfDocument,
  data : BytesView,
) -> Array[@bookmark.PdfBookmark] raise PdfError {
  document.parse_bookmark_text(data, verify~)
}

///|
/// Compatibility wrapper for `PdfDocument::add_bookmarks_from_text`.
pub fn pdf_add_bookmarks_from_text(
  verify : Bool,
  data : BytesView,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.add_bookmarks_from_text(data, verify~)
}
