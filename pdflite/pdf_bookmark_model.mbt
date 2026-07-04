///|
fn pdf_bookmark_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_bookmark_outlines_key_name : @core.PdfName = pdf_bookmark_name(
  "/Outlines",
)

///|
fn pdf_bookmark_outlines_key() -> @core.PdfName {
  pdf_bookmark_outlines_key_name
}

///|
let pdf_bookmark_root_key_name : @core.PdfName = pdf_bookmark_name("/Root")

///|
fn pdf_bookmark_root_key() -> @core.PdfName {
  pdf_bookmark_root_key_name
}

///|
let pdf_bookmark_first_key_name : @core.PdfName = pdf_bookmark_name("/First")

///|
fn pdf_bookmark_first_key() -> @core.PdfName {
  pdf_bookmark_first_key_name
}

///|
let pdf_bookmark_next_key_name : @core.PdfName = pdf_bookmark_name("/Next")

///|
fn pdf_bookmark_next_key() -> @core.PdfName {
  pdf_bookmark_next_key_name
}

///|
let pdf_bookmark_prev_key_name : @core.PdfName = pdf_bookmark_name("/Prev")

///|
fn pdf_bookmark_prev_key() -> @core.PdfName {
  pdf_bookmark_prev_key_name
}

///|
let pdf_bookmark_parent_key_name : @core.PdfName = pdf_bookmark_name("/Parent")

///|
fn pdf_bookmark_parent_key() -> @core.PdfName {
  pdf_bookmark_parent_key_name
}

///|
let pdf_bookmark_title_key_name : @core.PdfName = pdf_bookmark_name("/Title")

///|
fn pdf_bookmark_title_key() -> @core.PdfName {
  pdf_bookmark_title_key_name
}

///|
let pdf_bookmark_last_key_name : @core.PdfName = pdf_bookmark_name("/Last")

///|
fn pdf_bookmark_last_key() -> @core.PdfName {
  pdf_bookmark_last_key_name
}

///|
let pdf_bookmark_dest_key_name : @core.PdfName = pdf_bookmark_name("/Dest")

///|
fn pdf_bookmark_dest_key() -> @core.PdfName {
  pdf_bookmark_dest_key_name
}

///|
let pdf_bookmark_action_key_name : @core.PdfName = pdf_bookmark_name("/A")

///|
fn pdf_bookmark_action_key() -> @core.PdfName {
  pdf_bookmark_action_key_name
}

///|
let pdf_bookmark_d_key_name : @core.PdfName = pdf_bookmark_name("/D")

///|
fn pdf_bookmark_d_key() -> @core.PdfName {
  pdf_bookmark_d_key_name
}

///|
let pdf_bookmark_count_key_name : @core.PdfName = pdf_bookmark_name("/Count")

///|
fn pdf_bookmark_count_key() -> @core.PdfName {
  pdf_bookmark_count_key_name
}

///|
let pdf_bookmark_colour_key_name : @core.PdfName = pdf_bookmark_name("/C")

///|
fn pdf_bookmark_colour_key() -> @core.PdfName {
  pdf_bookmark_colour_key_name
}

///|
let pdf_bookmark_flags_key_name : @core.PdfName = pdf_bookmark_name("/F")

///|
fn pdf_bookmark_flags_key() -> @core.PdfName {
  pdf_bookmark_flags_key_name
}

///|
fn PdfDocument::pdf_bookmark_catalog(
  self : PdfDocument,
) -> @syntax.PdfObject raise @core.PdfError {
  self.catalog()
}

///|
struct PdfBookmarkNode {
  number : Int
  object : @syntax.PdfObject
  children : Array[PdfBookmarkNode]
  is_open : Bool
} derive(Debug, Eq, ToJson)
