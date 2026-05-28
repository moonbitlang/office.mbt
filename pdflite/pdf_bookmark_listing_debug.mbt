///|
/// Format a bookmark as a diagnostic byte string.
///
/// The output includes level, title bytes, destination object, and open state;
/// it is intended for debugging rather than PDF serialization.
pub fn pdf_string_of_bookmark(
  bookmark : PdfBookmark,
) -> PdfBytes raise PdfError {
  let space = @ascii.encode(" ")
  pdf_bytes_concat_views([
    @ascii.encode(bookmark.level.to_string()),
    space,
    bookmark.text,
    space,
    pdf_write_object(pdf_object_of_destination(bookmark.target)),
    space,
    @ascii.encode(if bookmark.is_open { "true" } else { "false" }),
    @ascii.encode("\n"),
  ])
}
