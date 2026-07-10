///|
let pdf_addtext_cpdf_stamp_name : @core.PdfName = @core.pdf_name_of_bytes(
  b"/CPDFSTAMP",
)

///|
let pdf_addtext_extgstate_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  b"/ExtGState",
)

///|
let pdf_addtext_font_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  b"/Font",
)

///|
let pdf_addtext_annots_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  b"/Annots",
)

///|
let pdf_addtext_ca_key_name : @core.PdfName = @core.pdf_name_of_bytes(b"/ca")

///|
let pdf_addtext_ca_stroke_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  b"/CA",
)

///|
let pdf_addtext_subtype_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  b"/Subtype",
)

///|
let pdf_addtext_link_name : @core.PdfName = @core.pdf_name_of_bytes(b"/Link")

///|
let pdf_addtext_quadpoints_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  b"/QuadPoints",
)

///|
let pdf_addtext_rect_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  b"/Rect",
)

///|
let pdf_addtext_bs_key_name : @core.PdfName = @core.pdf_name_of_bytes(b"/BS")

///|
let pdf_addtext_w_key_name : @core.PdfName = @core.pdf_name_of_bytes(b"/W")

///|
let pdf_addtext_a_key_name : @core.PdfName = @core.pdf_name_of_bytes(b"/A")

///|
let pdf_addtext_uri_key_name : @core.PdfName = @core.pdf_name_of_bytes(b"/URI")

///|
let pdf_addtext_type_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  b"/Type",
)

///|
let pdf_addtext_action_name : @core.PdfName = @core.pdf_name_of_bytes(
  b"/Action",
)

///|
let pdf_addtext_s_key_name : @core.PdfName = @core.pdf_name_of_bytes(b"/S")

///|
fn pdf_addtext_cpdf_stamp() -> @core.PdfName {
  pdf_addtext_cpdf_stamp_name
}

///|
fn pdf_addtext_extgstate_key() -> @core.PdfName {
  pdf_addtext_extgstate_key_name
}

///|
fn pdf_addtext_font_key() -> @core.PdfName {
  pdf_addtext_font_key_name
}

///|
fn pdf_addtext_annots_key() -> @core.PdfName {
  pdf_addtext_annots_key_name
}

///|
fn pdf_addtext_ca_key() -> @core.PdfName {
  pdf_addtext_ca_key_name
}

///|
fn pdf_addtext_ca_stroke_key() -> @core.PdfName {
  pdf_addtext_ca_stroke_key_name
}
