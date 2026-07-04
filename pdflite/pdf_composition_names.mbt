///|
fn pdf_composition_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_composition_struct_tree_root_name : @core.PdfName = pdf_composition_name(
  "/StructTreeRoot",
)

///|
fn pdf_composition_struct_tree_root() -> @core.PdfName {
  pdf_composition_struct_tree_root_name
}

///|
let pdf_composition_pg_name : @core.PdfName = pdf_composition_name("/Pg")

///|
fn pdf_composition_pg() -> @core.PdfName {
  pdf_composition_pg_name
}

///|
let pdf_composition_piece_info_name : @core.PdfName = pdf_composition_name(
  "/PieceInfo",
)

///|
fn pdf_composition_piece_info() -> @core.PdfName {
  pdf_composition_piece_info_name
}

///|
let pdf_composition_subtype_name : @core.PdfName = pdf_composition_name(
  "/Subtype",
)

///|
fn pdf_composition_subtype() -> @core.PdfName {
  pdf_composition_subtype_name
}

///|
let pdf_composition_image_name : @core.PdfName = pdf_composition_name("/Image")

///|
fn pdf_composition_image() -> @core.PdfName {
  pdf_composition_image_name
}

///|
let pdf_composition_form_name : @core.PdfName = pdf_composition_name("/Form")

///|
fn pdf_composition_form() -> @core.PdfName {
  pdf_composition_form_name
}

///|
let pdf_composition_type_name : @core.PdfName = pdf_composition_name("/Type")

///|
fn pdf_composition_type() -> @core.PdfName {
  pdf_composition_type_name
}

///|
let pdf_composition_font_name : @core.PdfName = pdf_composition_name("/Font")

///|
fn pdf_composition_font() -> @core.PdfName {
  pdf_composition_font_name
}

///|
let pdf_composition_page_name : @core.PdfName = pdf_composition_name("/Page")

///|
fn pdf_composition_page() -> @core.PdfName {
  pdf_composition_page_name
}

///|
let pdf_composition_contents_name : @core.PdfName = pdf_composition_name(
  "/Contents",
)

///|
fn pdf_composition_contents() -> @core.PdfName {
  pdf_composition_contents_name
}
