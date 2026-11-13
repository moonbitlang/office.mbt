///|
/// Bookmark display colour from the PDF outline `/C` entry.
///
/// PDF stores these as RGB real numbers, normally in the range 0.0 to 1.0.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfBookmarkColour {
  red : Double
  green : Double
  blue : Double
}

///|
/// One bookmark in the flattened outline representation.
///
/// Bookmarks are ordered in preorder. `level` is zero-based nesting depth,
/// `text` is the raw PDF title string bytes, and `target` is the parsed
/// destination or preserved action.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfBookmark {
  level : Int32
  text : @core.PdfBytes
  target : @destination.PdfDestination
  is_open : Bool
  colour : PdfBookmarkColour
  flags : Int32
}

///|
/// Default black bookmark colour.
pub let pdf_bookmark_black : PdfBookmarkColour = {
  red: 0.0,
  green: 0.0,
  blue: 0.0,
}
