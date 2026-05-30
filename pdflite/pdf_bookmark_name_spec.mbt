///|
/// Expand cpdf's bookmark-based output filename specification.
///
/// This ports the output-side `name_of_spec` helper. Bookmark-file parsing is
/// intentionally separate; callers pass the already-read bookmark list.
pub fn PdfDocument::bookmark_name_of_spec(
  self : PdfDocument,
  encoding : @metadata.PdfMetadataEncoding,
  bookmarks : ArrayView[@bookmark.PdfBookmark],
  split_level : Int,
  spec : String,
  sequence : Int,
  filename : String,
  start_page : Int,
  end_page : Int,
) -> String raise @core.PdfError {
  let _ = encoding
  self.pdf_bookmark_name_spec_process_at_fields(
    bookmarks,
    split_level,
    pdf_bookmark_name_spec_expand_percent(spec, sequence),
    sequence,
    filename,
    start_page,
    end_page,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::bookmark_name_of_spec`.
pub fn pdf_bookmark_name_of_spec(
  encoding : @metadata.PdfMetadataEncoding,
  bookmarks : ArrayView[@bookmark.PdfBookmark],
  document : PdfDocument,
  split_level : Int,
  spec : String,
  sequence : Int,
  filename : String,
  start_page : Int,
  end_page : Int,
) -> String raise @core.PdfError {
  document.bookmark_name_of_spec(
    encoding, bookmarks, split_level, spec, sequence, filename, start_page, end_page,
  )
}

///|
/// Source-spelled compatibility wrapper for cpdfbookmarks' `name_of_spec`.
pub fn pdf_name_of_spec(
  encoding : @metadata.PdfMetadataEncoding,
  bookmarks : ArrayView[@bookmark.PdfBookmark],
  document : PdfDocument,
  split_level : Int,
  spec : String,
  sequence : Int,
  filename : String,
  start_page : Int,
  end_page : Int,
) -> String raise @core.PdfError {
  document.bookmark_name_of_spec(
    encoding, bookmarks, split_level, spec, sequence, filename, start_page, end_page,
  )
}
