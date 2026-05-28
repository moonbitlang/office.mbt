///|
fn pdf_bookmark_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_bookmark_outlines_key_name : PdfName = pdf_bookmark_name("/Outlines")

///|
fn pdf_bookmark_outlines_key() -> PdfName {
  pdf_bookmark_outlines_key_name
}

///|
let pdf_bookmark_root_key_name : PdfName = pdf_bookmark_name("/Root")

///|
fn pdf_bookmark_root_key() -> PdfName {
  pdf_bookmark_root_key_name
}

///|
let pdf_bookmark_first_key_name : PdfName = pdf_bookmark_name("/First")

///|
fn pdf_bookmark_first_key() -> PdfName {
  pdf_bookmark_first_key_name
}

///|
let pdf_bookmark_next_key_name : PdfName = pdf_bookmark_name("/Next")

///|
fn pdf_bookmark_next_key() -> PdfName {
  pdf_bookmark_next_key_name
}

///|
let pdf_bookmark_prev_key_name : PdfName = pdf_bookmark_name("/Prev")

///|
fn pdf_bookmark_prev_key() -> PdfName {
  pdf_bookmark_prev_key_name
}

///|
let pdf_bookmark_parent_key_name : PdfName = pdf_bookmark_name("/Parent")

///|
fn pdf_bookmark_parent_key() -> PdfName {
  pdf_bookmark_parent_key_name
}

///|
let pdf_bookmark_title_key_name : PdfName = pdf_bookmark_name("/Title")

///|
fn pdf_bookmark_title_key() -> PdfName {
  pdf_bookmark_title_key_name
}

///|
let pdf_bookmark_last_key_name : PdfName = pdf_bookmark_name("/Last")

///|
fn pdf_bookmark_last_key() -> PdfName {
  pdf_bookmark_last_key_name
}

///|
let pdf_bookmark_dest_key_name : PdfName = pdf_bookmark_name("/Dest")

///|
fn pdf_bookmark_dest_key() -> PdfName {
  pdf_bookmark_dest_key_name
}

///|
let pdf_bookmark_action_key_name : PdfName = pdf_bookmark_name("/A")

///|
fn pdf_bookmark_action_key() -> PdfName {
  pdf_bookmark_action_key_name
}

///|
let pdf_bookmark_d_key_name : PdfName = pdf_bookmark_name("/D")

///|
fn pdf_bookmark_d_key() -> PdfName {
  pdf_bookmark_d_key_name
}

///|
let pdf_bookmark_count_key_name : PdfName = pdf_bookmark_name("/Count")

///|
fn pdf_bookmark_count_key() -> PdfName {
  pdf_bookmark_count_key_name
}

///|
let pdf_bookmark_colour_key_name : PdfName = pdf_bookmark_name("/C")

///|
fn pdf_bookmark_colour_key() -> PdfName {
  pdf_bookmark_colour_key_name
}

///|
let pdf_bookmark_flags_key_name : PdfName = pdf_bookmark_name("/F")

///|
fn pdf_bookmark_flags_key() -> PdfName {
  pdf_bookmark_flags_key_name
}

///|
fn PdfDocument::pdf_bookmark_catalog(
  self : PdfDocument,
) -> PdfObject raise PdfError {
  self.catalog()
}

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
  text : PdfBytes
  target : PdfDestination
  is_open : Bool
  colour : PdfBookmarkColour
  flags : Int
} derive(Debug, Eq, ToJson)

///|
struct PdfBookmarkNode {
  number : Int
  object : PdfObject
  children : Array[PdfBookmarkNode]
  is_open : Bool
} derive(Debug, Eq, ToJson)

///|
/// Default black bookmark colour.
pub let pdf_bookmark_black : PdfBookmarkColour = {
  red: 0.0,
  green: 0.0,
  blue: 0.0,
}
