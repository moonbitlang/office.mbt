///|
fn pdf_draw_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_draw_extgstate_key_name : @core.PdfName = pdf_draw_name("/ExtGState")

///|
let pdf_draw_xobject_key_name : @core.PdfName = pdf_draw_name("/XObject")

///|
let pdf_draw_font_key_name : @core.PdfName = pdf_draw_name("/Font")

///|
let pdf_draw_length_key_name : @core.PdfName = pdf_draw_name("/Length")

///|
let pdf_draw_subtype_key_name : @core.PdfName = pdf_draw_name("/Subtype")

///|
let pdf_draw_form_key_name : @core.PdfName = pdf_draw_name("/Form")

///|
let pdf_draw_resources_key_name : @core.PdfName = pdf_draw_name("/Resources")

///|
let pdf_draw_bbox_key_name : @core.PdfName = pdf_draw_name("/BBox")

///|
let pdf_draw_mcid_key_name : @core.PdfName = pdf_draw_name("/MCID")

///|
let pdf_draw_type_key_name : @core.PdfName = pdf_draw_name("/Type")

///|
let pdf_draw_struct_tree_root_key_name : @core.PdfName = pdf_draw_name(
  "/StructTreeRoot",
)

///|
let pdf_draw_parent_tree_key_name : @core.PdfName = pdf_draw_name("/ParentTree")

///|
let pdf_draw_s_key_name : @core.PdfName = pdf_draw_name("/S")

///|
let pdf_draw_p_key_name : @core.PdfName = pdf_draw_name("/P")

///|
let pdf_draw_k_key_name : @core.PdfName = pdf_draw_name("/K")

///|
let pdf_draw_pg_key_name : @core.PdfName = pdf_draw_name("/Pg")

///|
let pdf_draw_ns_key_name : @core.PdfName = pdf_draw_name("/NS")

///|
let pdf_draw_namespaces_key_name : @core.PdfName = pdf_draw_name("/Namespaces")

///|
let pdf_draw_role_map_key_name : @core.PdfName = pdf_draw_name("/RoleMap")

///|
let pdf_draw_struct_parents_key_name : @core.PdfName = pdf_draw_name(
  "/StructParents",
)

///|
let pdf_draw_begin_artifact_name : @core.PdfName = pdf_draw_name(
  "/BeginArtifact",
)

///|
let pdf_draw_end_artifact_name : @core.PdfName = pdf_draw_name("/EndArtifact")

///|
let pdf_draw_fill_alpha_key_name : @core.PdfName = pdf_draw_name("/ca")

///|
let pdf_draw_stroke_alpha_key_name : @core.PdfName = pdf_draw_name("/CA")

///|
fn pdf_draw_extgstate_key() -> @core.PdfName {
  pdf_draw_extgstate_key_name
}

///|
fn pdf_draw_xobject_key() -> @core.PdfName {
  pdf_draw_xobject_key_name
}

///|
fn pdf_draw_font_key() -> @core.PdfName {
  pdf_draw_font_key_name
}

///|
fn pdf_draw_length_key() -> @core.PdfName {
  pdf_draw_length_key_name
}

///|
fn pdf_draw_subtype_key() -> @core.PdfName {
  pdf_draw_subtype_key_name
}

///|
fn pdf_draw_form_key() -> @core.PdfName {
  pdf_draw_form_key_name
}

///|
fn pdf_draw_resources_key() -> @core.PdfName {
  pdf_draw_resources_key_name
}

///|
fn pdf_draw_bbox_key() -> @core.PdfName {
  pdf_draw_bbox_key_name
}

///|
fn pdf_draw_mcid_key() -> @core.PdfName {
  pdf_draw_mcid_key_name
}

///|
fn pdf_draw_type_key() -> @core.PdfName {
  pdf_draw_type_key_name
}

///|
fn pdf_draw_struct_tree_root_key() -> @core.PdfName {
  pdf_draw_struct_tree_root_key_name
}

///|
fn pdf_draw_parent_tree_key() -> @core.PdfName {
  pdf_draw_parent_tree_key_name
}

///|
fn pdf_draw_s_key() -> @core.PdfName {
  pdf_draw_s_key_name
}

///|
fn pdf_draw_p_key() -> @core.PdfName {
  pdf_draw_p_key_name
}

///|
fn pdf_draw_k_key() -> @core.PdfName {
  pdf_draw_k_key_name
}

///|
fn pdf_draw_pg_key() -> @core.PdfName {
  pdf_draw_pg_key_name
}

///|
fn pdf_draw_ns_key() -> @core.PdfName {
  pdf_draw_ns_key_name
}

///|
fn pdf_draw_namespaces_key() -> @core.PdfName {
  pdf_draw_namespaces_key_name
}

///|
fn pdf_draw_role_map_key() -> @core.PdfName {
  pdf_draw_role_map_key_name
}

///|
fn pdf_draw_struct_parents_key() -> @core.PdfName {
  pdf_draw_struct_parents_key_name
}

///|
fn pdf_draw_begin_artifact() -> @core.PdfName {
  pdf_draw_begin_artifact_name
}

///|
fn pdf_draw_end_artifact() -> @core.PdfName {
  pdf_draw_end_artifact_name
}

///|
fn pdf_draw_fill_alpha_key() -> @core.PdfName {
  pdf_draw_fill_alpha_key_name
}

///|
fn pdf_draw_stroke_alpha_key() -> @core.PdfName {
  pdf_draw_stroke_alpha_key_name
}
