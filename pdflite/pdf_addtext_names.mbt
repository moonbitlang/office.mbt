///|
let pdf_addtext_cpdf_stamp_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/CPDFSTAMP"),
)

///|
let pdf_addtext_extgstate_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/ExtGState"),
)

///|
let pdf_addtext_font_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/Font"),
)

///|
let pdf_addtext_annots_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/Annots"),
)

///|
let pdf_addtext_ca_key_name : PdfName = pdf_name_of_bytes(@ascii.encode("/ca"))

///|
let pdf_addtext_ca_stroke_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/CA"),
)

///|
let pdf_addtext_subtype_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/Subtype"),
)

///|
let pdf_addtext_link_name : PdfName = pdf_name_of_bytes(@ascii.encode("/Link"))

///|
let pdf_addtext_quadpoints_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/QuadPoints"),
)

///|
let pdf_addtext_rect_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/Rect"),
)

///|
let pdf_addtext_bs_key_name : PdfName = pdf_name_of_bytes(@ascii.encode("/BS"))

///|
let pdf_addtext_w_key_name : PdfName = pdf_name_of_bytes(@ascii.encode("/W"))

///|
let pdf_addtext_a_key_name : PdfName = pdf_name_of_bytes(@ascii.encode("/A"))

///|
let pdf_addtext_uri_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/URI"),
)

///|
let pdf_addtext_type_key_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/Type"),
)

///|
let pdf_addtext_action_name : PdfName = pdf_name_of_bytes(
  @ascii.encode("/Action"),
)

///|
let pdf_addtext_s_key_name : PdfName = pdf_name_of_bytes(@ascii.encode("/S"))

///|
fn pdf_addtext_cpdf_stamp() -> PdfName {
  pdf_addtext_cpdf_stamp_name
}

///|
fn pdf_addtext_extgstate_key() -> PdfName {
  pdf_addtext_extgstate_key_name
}

///|
fn pdf_addtext_font_key() -> PdfName {
  pdf_addtext_font_key_name
}

///|
fn pdf_addtext_annots_key() -> PdfName {
  pdf_addtext_annots_key_name
}

///|
fn pdf_addtext_ca_key() -> PdfName {
  pdf_addtext_ca_key_name
}

///|
fn pdf_addtext_ca_stroke_key() -> PdfName {
  pdf_addtext_ca_stroke_key_name
}
