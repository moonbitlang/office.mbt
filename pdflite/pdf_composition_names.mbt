///|
fn pdf_composition_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_composition_struct_tree_root_name : PdfName = pdf_composition_name(
  "/StructTreeRoot",
)

///|
fn pdf_composition_struct_tree_root() -> PdfName {
  pdf_composition_struct_tree_root_name
}

///|
let pdf_composition_pg_name : PdfName = pdf_composition_name("/Pg")

///|
fn pdf_composition_pg() -> PdfName {
  pdf_composition_pg_name
}

///|
let pdf_composition_piece_info_name : PdfName = pdf_composition_name(
  "/PieceInfo",
)

///|
fn pdf_composition_piece_info() -> PdfName {
  pdf_composition_piece_info_name
}

///|
let pdf_composition_subtype_name : PdfName = pdf_composition_name("/Subtype")

///|
fn pdf_composition_subtype() -> PdfName {
  pdf_composition_subtype_name
}

///|
let pdf_composition_image_name : PdfName = pdf_composition_name("/Image")

///|
fn pdf_composition_image() -> PdfName {
  pdf_composition_image_name
}

///|
let pdf_composition_form_name : PdfName = pdf_composition_name("/Form")

///|
fn pdf_composition_form() -> PdfName {
  pdf_composition_form_name
}

///|
let pdf_composition_type_name : PdfName = pdf_composition_name("/Type")

///|
fn pdf_composition_type() -> PdfName {
  pdf_composition_type_name
}

///|
let pdf_composition_font_name : PdfName = pdf_composition_name("/Font")

///|
fn pdf_composition_font() -> PdfName {
  pdf_composition_font_name
}

///|
let pdf_composition_page_name : PdfName = pdf_composition_name("/Page")

///|
fn pdf_composition_page() -> PdfName {
  pdf_composition_page_name
}

///|
let pdf_composition_contents_name : PdfName = pdf_composition_name("/Contents")

///|
fn pdf_composition_contents() -> PdfName {
  pdf_composition_contents_name
}
