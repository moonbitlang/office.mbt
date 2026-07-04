///|
fn PdfDocument::pdf_bookmark_import_parse_line(
  self : PdfDocument,
  line : BytesView,
  line_number : Int,
) -> @bookmark.PdfBookmark? raise @core.PdfError {
  let line = pdf_bookmark_import_trim_line_end(line)
  let index : Ref[Int] = { val: 0 }
  pdf_bookmark_import_skip_whitespace(line, index)
  if index.val == line.length() {
    None
  } else {
    let level = match pdf_bookmark_import_parse_int(line, index) {
      Some(value) => value
      None =>
        raise SoftError("Bad bookmark file, line " + line_number.to_string())
    }
    let title = match pdf_bookmark_import_parse_quoted(line, index) {
      Some(value) => value
      None =>
        raise SoftError("Bad bookmark file, line " + line_number.to_string())
    }
    let page_number = match pdf_bookmark_import_parse_int(line, index) {
      Some(value) => value
      None =>
        raise SoftError("Bad bookmark file, line " + line_number.to_string())
    }
    let is_open = pdf_bookmark_import_take_open(line, index)
    let destination = pdf_bookmark_import_optional_destination(line, index)
    Some(
      self.pdf_bookmark_import_bookmark(
        level, title, page_number, is_open, destination,
      ),
    )
  }
}

///|
fn PdfDocument::pdf_bookmark_import_verify(
  self : PdfDocument,
  bookmarks : ArrayView[@bookmark.PdfBookmark],
) -> Bool raise @core.PdfError {
  if bookmarks.length() == 0 {
    true
  } else if bookmarks[0].level != 0 {
    false
  } else {
    let page_reference_numbers = self.page_reference_numbers()
    let page_number_lookup = pdf_page_number_lookup(page_reference_numbers)
    let end_page = self.endpage()
    let mut last_level = 0
    for index in 1..<bookmarks.length() {
      let bookmark = bookmarks[index]
      let page_number = self.pdf_destination_page_number_with_lookup(
        bookmark.target,
        page_number_lookup,
      )
      if bookmark.level >= last_level + 2 ||
        bookmark.level < 0 ||
        page_number > end_page ||
        page_number < 0 {
        break false
      }
      last_level = bookmark.level
    } nobreak {
      true
    }
  }
}
