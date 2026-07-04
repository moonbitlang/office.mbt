///|
/// Bookmark display colour from the PDF outline `/C` entry.
///
/// PDF stores these as RGB real numbers, normally in the range 0.0 to 1.0.
pub(all) struct PdfBookmarkColour {
  red : Double
  green : Double
  blue : Double
} derive(Debug, Eq, ToJson)

///|
/// One bookmark in the flattened outline representation.
///
/// Bookmarks are ordered in preorder. `level` is zero-based nesting depth,
/// `text` is the raw PDF title string bytes, and `target` is the parsed
/// destination or preserved action.
pub(all) struct PdfBookmark {
  level : Int
  text : @core.PdfBytes
  target : @destination.PdfDestination
  is_open : Bool
  colour : PdfBookmarkColour
  flags : Int
} derive(Debug, Eq, ToJson)

///|
/// Default black bookmark colour.
pub let pdf_bookmark_black : PdfBookmarkColour = {
  red: 0.0,
  green: 0.0,
  blue: 0.0,
}
