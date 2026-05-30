///|
fn pdf_portfolio_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_portfolio_root_key_name : @core.PdfName = pdf_portfolio_name("/Root")

///|
fn pdf_portfolio_root_key() -> @core.PdfName {
  pdf_portfolio_root_key_name
}

///|
let pdf_portfolio_names_key_name : @core.PdfName = pdf_portfolio_name("/Names")

///|
fn pdf_portfolio_names_key() -> @core.PdfName {
  pdf_portfolio_names_key_name
}

///|
let pdf_portfolio_embedded_files_key_name : @core.PdfName = pdf_portfolio_name(
  "/EmbeddedFiles",
)

///|
fn pdf_portfolio_embedded_files_key() -> @core.PdfName {
  pdf_portfolio_embedded_files_key_name
}

///|
let pdf_portfolio_collection_key_name : @core.PdfName = pdf_portfolio_name(
  "/Collection",
)

///|
fn pdf_portfolio_collection_key() -> @core.PdfName {
  pdf_portfolio_collection_key_name
}

///|
let pdf_portfolio_view_key_name : @core.PdfName = pdf_portfolio_name("/View")

///|
fn pdf_portfolio_view_key() -> @core.PdfName {
  pdf_portfolio_view_key_name
}

///|
let pdf_portfolio_table_view_name : @core.PdfName = pdf_portfolio_name("/T")

///|
fn pdf_portfolio_table_view() -> @core.PdfName {
  pdf_portfolio_table_view_name
}

///|
let pdf_portfolio_params_key_name : @core.PdfName = pdf_portfolio_name(
  "/Params",
)

///|
fn pdf_portfolio_params_key() -> @core.PdfName {
  pdf_portfolio_params_key_name
}

///|
let pdf_portfolio_mod_date_key_name : @core.PdfName = pdf_portfolio_name(
  "/ModDate",
)

///|
fn pdf_portfolio_mod_date_key() -> @core.PdfName {
  pdf_portfolio_mod_date_key_name
}

///|
let pdf_portfolio_size_key_name : @core.PdfName = pdf_portfolio_name("/Size")

///|
fn pdf_portfolio_size_key() -> @core.PdfName {
  pdf_portfolio_size_key_name
}

///|
let pdf_portfolio_length_key_name : @core.PdfName = pdf_portfolio_name(
  "/Length",
)

///|
fn pdf_portfolio_length_key() -> @core.PdfName {
  pdf_portfolio_length_key_name
}

///|
let pdf_portfolio_type_key_name : @core.PdfName = pdf_portfolio_name("/Type")

///|
fn pdf_portfolio_type_key() -> @core.PdfName {
  pdf_portfolio_type_key_name
}

///|
let pdf_portfolio_file_spec_name : @core.PdfName = pdf_portfolio_name(
  "/FileSpec",
)

///|
fn pdf_portfolio_file_spec() -> @core.PdfName {
  pdf_portfolio_file_spec_name
}

///|
let pdf_portfolio_desc_key_name : @core.PdfName = pdf_portfolio_name("/Desc")

///|
fn pdf_portfolio_desc_key() -> @core.PdfName {
  pdf_portfolio_desc_key_name
}

///|
let pdf_portfolio_f_key_name : @core.PdfName = pdf_portfolio_name("/F")

///|
fn pdf_portfolio_f_key() -> @core.PdfName {
  pdf_portfolio_f_key_name
}

///|
let pdf_portfolio_uf_key_name : @core.PdfName = pdf_portfolio_name("/UF")

///|
fn pdf_portfolio_uf_key() -> @core.PdfName {
  pdf_portfolio_uf_key_name
}

///|
let pdf_portfolio_af_relationship_key_name : @core.PdfName = pdf_portfolio_name(
  "/AFRelationship",
)

///|
fn pdf_portfolio_af_relationship_key() -> @core.PdfName {
  pdf_portfolio_af_relationship_key_name
}

///|
let pdf_portfolio_ef_key_name : @core.PdfName = pdf_portfolio_name("/EF")

///|
fn pdf_portfolio_ef_key() -> @core.PdfName {
  pdf_portfolio_ef_key_name
}

///|
let pdf_portfolio_unspecified_relationship_name : @core.PdfName = pdf_portfolio_name(
  "/Unspecified",
)

///|
fn pdf_portfolio_unspecified_relationship() -> @core.PdfName {
  pdf_portfolio_unspecified_relationship_name
}
