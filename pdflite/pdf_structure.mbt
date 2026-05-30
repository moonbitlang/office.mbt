///|
fn pdf_structure_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_structure_pg_key_name : @core.PdfName = pdf_structure_name("/Pg")

///|
fn pdf_structure_pg_key() -> @core.PdfName {
  pdf_structure_pg_key_name
}

///|
let pdf_structure_obj_key_name : @core.PdfName = pdf_structure_name("/Obj")

///|
fn pdf_structure_obj_key() -> @core.PdfName {
  pdf_structure_obj_key_name
}

///|
let pdf_structure_root_key_name : @core.PdfName = pdf_structure_name("/Root")

///|
fn pdf_structure_root_key() -> @core.PdfName {
  pdf_structure_root_key_name
}

///|
let pdf_structure_struct_tree_root_key_name : @core.PdfName = pdf_structure_name(
  "/StructTreeRoot",
)

///|
fn pdf_structure_struct_tree_root_key() -> @core.PdfName {
  pdf_structure_struct_tree_root_key_name
}

///|
let pdf_structure_parent_tree_key_name : @core.PdfName = pdf_structure_name(
  "/ParentTree",
)

///|
fn pdf_structure_parent_tree_key() -> @core.PdfName {
  pdf_structure_parent_tree_key_name
}

///|
let pdf_structure_k_key_name : @core.PdfName = pdf_structure_name("/K")

///|
fn pdf_structure_k_key() -> @core.PdfName {
  pdf_structure_k_key_name
}
