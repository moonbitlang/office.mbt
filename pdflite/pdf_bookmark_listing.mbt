///|
/// Render cpdf's bookmark listing for selected pages.
///
/// Text output matches cpdf's line-oriented bookmark format. When `json` is
/// set, this returns UTF-8 JSON bytes for the same filtered bookmark set.
pub fn PdfDocument::list_bookmarks(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  json? : Bool = false,
  json_preserve_actions? : Bool = false,
) -> PdfBytes raise PdfError {
  let bookmarks = self.pdf_bookmark_listing_bookmarks(
    page_numbers,
    json && json_preserve_actions,
  )
  if json {
    @utf8.encode(self.pdf_bookmark_listing_json(bookmarks).stringify())
  } else {
    let lines : Array[PdfBookmarkListingTextLine] = Array::new(
      capacity=bookmarks.length(),
    )
    let mut length = 0
    for bookmark in bookmarks {
      let line = self.pdf_bookmark_listing_text_line(bookmark, encoding)
      length += line.byte_length()
      lines.push(line)
    }
    let output = Array::make(length, b'\x00')
    let mut position = 0
    for line in lines {
      position = line.write_to(output, position)
    }
    Bytes::from_array(output)
  }
}

///|
/// Return cpdf's full-document bookmark JSON listing.
pub fn PdfDocument::bookmarks_json(
  self : PdfDocument,
  json_preserve_actions? : Bool = false,
) -> Json raise PdfError {
  let end_page = self.endpage()
  let page_numbers = Array::make(end_page, 0)
  for index in 0..<end_page {
    page_numbers[index] = index + 1
  }
  let bookmarks = self.pdf_bookmark_listing_bookmarks(
    page_numbers, json_preserve_actions,
  )
  self.pdf_bookmark_listing_json(bookmarks)
}

///|
/// Return cpdf's full-document bookmark JSON listing as UTF-8 JSON bytes.
pub fn PdfDocument::bookmarks_json_blob(
  self : PdfDocument,
  json_preserve_actions? : Bool = false,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.bookmarks_json(json_preserve_actions~).stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::list_bookmarks`.
pub fn pdf_list_bookmarks(
  json : Bool,
  json_preserve_actions : Bool,
  encoding : PdfMetadataEncoding,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.list_bookmarks(
    page_numbers,
    encoding~,
    json~,
    json_preserve_actions~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::bookmarks_json_blob`.
pub fn pdf_get_bookmarks_json(
  json_preserve_actions : Bool,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.bookmarks_json_blob(json_preserve_actions~)
}
