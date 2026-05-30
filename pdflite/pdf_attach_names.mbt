///|
fn pdf_attach_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_attach_root_key_name : @core.PdfName = pdf_attach_name("/Root")

///|
fn pdf_attach_root_key() -> @core.PdfName {
  pdf_attach_root_key_name
}

///|
let pdf_attach_names_key_name : @core.PdfName = pdf_attach_name("/Names")

///|
fn pdf_attach_names_key() -> @core.PdfName {
  pdf_attach_names_key_name
}

///|
let pdf_attach_embedded_files_key_name : @core.PdfName = pdf_attach_name(
  "/EmbeddedFiles",
)

///|
fn pdf_attach_embedded_files_key() -> @core.PdfName {
  pdf_attach_embedded_files_key_name
}

///|
let pdf_attach_type_key_name : @core.PdfName = pdf_attach_name("/Type")

///|
fn pdf_attach_type_key() -> @core.PdfName {
  pdf_attach_type_key_name
}

///|
let pdf_attach_length_key_name : @core.PdfName = pdf_attach_name("/Length")

///|
fn pdf_attach_length_key() -> @core.PdfName {
  pdf_attach_length_key_name
}

///|
let pdf_attach_params_key_name : @core.PdfName = pdf_attach_name("/Params")

///|
fn pdf_attach_params_key() -> @core.PdfName {
  pdf_attach_params_key_name
}

///|
let pdf_attach_size_key_name : @core.PdfName = pdf_attach_name("/Size")

///|
fn pdf_attach_size_key() -> @core.PdfName {
  pdf_attach_size_key_name
}

///|
let pdf_attach_checksum_key_name : @core.PdfName = pdf_attach_name("/CheckSum")

///|
fn pdf_attach_checksum_key() -> @core.PdfName {
  pdf_attach_checksum_key_name
}

///|
let pdf_attach_embedded_file_name : @core.PdfName = pdf_attach_name(
  "/EmbeddedFile",
)

///|
fn pdf_attach_embedded_file() -> @core.PdfName {
  pdf_attach_embedded_file_name
}

///|
let pdf_attach_filespec_name : @core.PdfName = pdf_attach_name("/Filespec")

///|
fn pdf_attach_filespec() -> @core.PdfName {
  pdf_attach_filespec_name
}

///|
let pdf_attach_ef_key_name : @core.PdfName = pdf_attach_name("/EF")

///|
fn pdf_attach_ef_key() -> @core.PdfName {
  pdf_attach_ef_key_name
}

///|
let pdf_attach_f_key_name : @core.PdfName = pdf_attach_name("/F")

///|
fn pdf_attach_f_key() -> @core.PdfName {
  pdf_attach_f_key_name
}

///|
let pdf_attach_uf_key_name : @core.PdfName = pdf_attach_name("/UF")

///|
fn pdf_attach_uf_key() -> @core.PdfName {
  pdf_attach_uf_key_name
}

///|
let pdf_attach_desc_key_name : @core.PdfName = pdf_attach_name("/Desc")

///|
fn pdf_attach_desc_key() -> @core.PdfName {
  pdf_attach_desc_key_name
}

///|
let pdf_attach_af_relationship_key_name : @core.PdfName = pdf_attach_name(
  "/AFRelationship",
)

///|
fn pdf_attach_af_relationship_key() -> @core.PdfName {
  pdf_attach_af_relationship_key_name
}

///|
let pdf_attach_annots_key_name : @core.PdfName = pdf_attach_name("/Annots")

///|
fn pdf_attach_annots_key() -> @core.PdfName {
  pdf_attach_annots_key_name
}

///|
let pdf_attach_subtype_key_name : @core.PdfName = pdf_attach_name("/Subtype")

///|
fn pdf_attach_subtype_key() -> @core.PdfName {
  pdf_attach_subtype_key_name
}

///|
let pdf_attach_file_attachment_name : @core.PdfName = pdf_attach_name(
  "/FileAttachment",
)

///|
fn pdf_attach_file_attachment() -> @core.PdfName {
  pdf_attach_file_attachment_name
}

///|
let pdf_attach_contents_key_name : @core.PdfName = pdf_attach_name("/Contents")

///|
fn pdf_attach_contents_key() -> @core.PdfName {
  pdf_attach_contents_key_name
}

///|
let pdf_attach_fs_key_name : @core.PdfName = pdf_attach_name("/FS")

///|
fn pdf_attach_fs_key() -> @core.PdfName {
  pdf_attach_fs_key_name
}

///|
let pdf_attach_rect_key_name : @core.PdfName = pdf_attach_name("/Rect")

///|
fn pdf_attach_rect_key() -> @core.PdfName {
  pdf_attach_rect_key_name
}
