///|
fn pdf_texttopdf_font_id(font_index : Int) -> String {
  font_index.to_string()
}

///|
fn pdf_texttopdf_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_texttopdf_struct_parents_key_name : @core.PdfName = pdf_texttopdf_name(
  "/StructParents",
)

///|
fn pdf_texttopdf_struct_parents_key() -> @core.PdfName {
  pdf_texttopdf_struct_parents_key_name
}

///|
let pdf_texttopdf_type_key_name : @core.PdfName = pdf_texttopdf_name("/Type")

///|
fn pdf_texttopdf_type_key() -> @core.PdfName {
  pdf_texttopdf_type_key_name
}

///|
let pdf_texttopdf_struct_tree_root_name : @core.PdfName = pdf_texttopdf_name(
  "/StructTreeRoot",
)

///|
fn pdf_texttopdf_struct_tree_root() -> @core.PdfName {
  pdf_texttopdf_struct_tree_root_name
}

///|
let pdf_texttopdf_mcr_name : @core.PdfName = pdf_texttopdf_name("/MCR")

///|
fn pdf_texttopdf_mcr() -> @core.PdfName {
  pdf_texttopdf_mcr_name
}

///|
let pdf_texttopdf_pg_key_name : @core.PdfName = pdf_texttopdf_name("/Pg")

///|
fn pdf_texttopdf_pg_key() -> @core.PdfName {
  pdf_texttopdf_pg_key_name
}

///|
let pdf_texttopdf_mcid_key_name : @core.PdfName = pdf_texttopdf_name("/MCID")

///|
fn pdf_texttopdf_mcid_key() -> @core.PdfName {
  pdf_texttopdf_mcid_key_name
}

///|
let pdf_texttopdf_s_key_name : @core.PdfName = pdf_texttopdf_name("/S")

///|
fn pdf_texttopdf_s_key() -> @core.PdfName {
  pdf_texttopdf_s_key_name
}

///|
let pdf_texttopdf_p_name : @core.PdfName = pdf_texttopdf_name("/P")

///|
fn pdf_texttopdf_p() -> @core.PdfName {
  pdf_texttopdf_p_name
}

///|
fn pdf_texttopdf_p_key() -> @core.PdfName {
  pdf_texttopdf_p_name
}

///|
let pdf_texttopdf_document_name_value : @core.PdfName = pdf_texttopdf_name(
  "/Document",
)

///|
fn pdf_texttopdf_document_name() -> @core.PdfName {
  pdf_texttopdf_document_name_value
}

///|
let pdf_texttopdf_ns_key_name : @core.PdfName = pdf_texttopdf_name("/NS")

///|
fn pdf_texttopdf_ns_key() -> @core.PdfName {
  pdf_texttopdf_ns_key_name
}

///|
let pdf_texttopdf_namespaces_key_name : @core.PdfName = pdf_texttopdf_name(
  "/Namespaces",
)

///|
fn pdf_texttopdf_namespaces_key() -> @core.PdfName {
  pdf_texttopdf_namespaces_key_name
}

///|
let pdf_texttopdf_pdfua2_namespace : @core.PdfBytes = @ascii.encode(
  "http://iso.org/pdf2/ssn",
)
