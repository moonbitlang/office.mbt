///|
fn pdf_page_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_page_static_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_page_type_key_name : @core.PdfName = pdf_page_static_name("/Type")

///|
let pdf_page_pages_name : @core.PdfName = pdf_page_static_name("/Pages")

///|
let pdf_page_root_key_name : @core.PdfName = pdf_page_static_name("/Root")

///|
let pdf_page_kids_key_name : @core.PdfName = pdf_page_static_name("/Kids")

///|
let pdf_page_parent_key_name : @core.PdfName = pdf_page_static_name("/Parent")

///|
let pdf_page_count_key_name : @core.PdfName = pdf_page_static_name("/Count")

///|
let pdf_page_resources_key_name : @core.PdfName = pdf_page_static_name(
  "/Resources",
)

///|
let pdf_page_mediabox_key_name : @core.PdfName = pdf_page_static_name(
  "/MediaBox",
)

///|
let pdf_page_cropbox_key_name : @core.PdfName = pdf_page_static_name("/CropBox")

///|
let pdf_page_rotate_key_name : @core.PdfName = pdf_page_static_name("/Rotate")

///|
let pdf_page_contents_key_name : @core.PdfName = pdf_page_static_name(
  "/Contents",
)

///|
let pdf_page_names_key_name : @core.PdfName = pdf_page_static_name("/Names")

///|
let pdf_page_dests_key_name : @core.PdfName = pdf_page_static_name("/Dests")

///|
let pdf_page_annots_key_name : @core.PdfName = pdf_page_static_name("/Annots")

///|
let pdf_page_open_action_key_name : @core.PdfName = pdf_page_static_name(
  "/OpenAction",
)

///|
let pdf_page_dest_key_name : @core.PdfName = pdf_page_static_name("/Dest")

///|
let pdf_page_action_key_name : @core.PdfName = pdf_page_static_name("/A")

///|
let pdf_page_subtype_key_name : @core.PdfName = pdf_page_static_name("/Subtype")

///|
let pdf_page_xobject_key_name : @core.PdfName = pdf_page_static_name("/XObject")

///|
let pdf_page_filter_key_name : @core.PdfName = pdf_page_static_name("/Filter")

///|
let pdf_page_popup_key_name : @core.PdfName = pdf_page_static_name("/Popup")

///|
let pdf_page_catalog_name : @core.PdfName = pdf_page_static_name("/Catalog")

///|
let pdf_page_page_name : @core.PdfName = pdf_page_static_name("/Page")

///|
let pdf_page_link_name : @core.PdfName = pdf_page_static_name("/Link")

///|
let pdf_page_form_name : @core.PdfName = pdf_page_static_name("/Form")

///|
let pdf_page_font_resource_name : @core.PdfName = pdf_page_static_name("/Font")

///|
let pdf_page_extgstate_resource_name : @core.PdfName = pdf_page_static_name(
  "/ExtGState",
)

///|
let pdf_page_colorspace_resource_name : @core.PdfName = pdf_page_static_name(
  "/ColorSpace",
)

///|
let pdf_page_pattern_resource_name : @core.PdfName = pdf_page_static_name(
  "/Pattern",
)

///|
let pdf_page_shading_resource_name : @core.PdfName = pdf_page_static_name(
  "/Shading",
)

///|
let pdf_page_properties_resource_name : @core.PdfName = pdf_page_static_name(
  "/Properties",
)

///|
let pdf_page_device_gray_name : @core.PdfName = pdf_page_static_name(
  "/DeviceGray",
)

///|
let pdf_page_device_rgb_name : @core.PdfName = pdf_page_static_name(
  "/DeviceRGB",
)

///|
let pdf_page_device_cmyk_name : @core.PdfName = pdf_page_static_name(
  "/DeviceCMYK",
)

///|
let pdf_page_g_name : @core.PdfName = pdf_page_static_name("/G")

///|
let pdf_page_rgb_name : @core.PdfName = pdf_page_static_name("/RGB")

///|
let pdf_page_cmyk_name : @core.PdfName = pdf_page_static_name("/CMYK")

///|
let pdf_page_cs_key_name : @core.PdfName = pdf_page_static_name("/CS")

///|
let pdf_page_length_key_name : @core.PdfName = pdf_page_static_name("/Length")

///|
fn pdf_page_type_key() -> @core.PdfName {
  pdf_page_type_key_name
}

///|
fn pdf_page_pages_key() -> @core.PdfName {
  pdf_page_pages_name
}

///|
fn pdf_page_root_key() -> @core.PdfName {
  pdf_page_root_key_name
}

///|
fn pdf_page_kids_key() -> @core.PdfName {
  pdf_page_kids_key_name
}

///|
fn pdf_page_parent_key() -> @core.PdfName {
  pdf_page_parent_key_name
}

///|
fn pdf_page_count_key() -> @core.PdfName {
  pdf_page_count_key_name
}

///|
fn pdf_page_resources_key() -> @core.PdfName {
  pdf_page_resources_key_name
}

///|
fn pdf_page_mediabox_key() -> @core.PdfName {
  pdf_page_mediabox_key_name
}

///|
fn pdf_page_cropbox_key() -> @core.PdfName {
  pdf_page_cropbox_key_name
}

///|
fn pdf_page_rotate_key() -> @core.PdfName {
  pdf_page_rotate_key_name
}

///|
fn pdf_page_contents_key() -> @core.PdfName {
  pdf_page_contents_key_name
}

///|
fn pdf_page_names_key() -> @core.PdfName {
  pdf_page_names_key_name
}

///|
fn pdf_page_dests_key() -> @core.PdfName {
  pdf_page_dests_key_name
}

///|
fn pdf_page_annots_key() -> @core.PdfName {
  pdf_page_annots_key_name
}

///|
fn pdf_page_open_action_key() -> @core.PdfName {
  pdf_page_open_action_key_name
}

///|
fn pdf_page_dest_key() -> @core.PdfName {
  pdf_page_dest_key_name
}

///|
fn pdf_page_action_key() -> @core.PdfName {
  pdf_page_action_key_name
}

///|
fn pdf_page_subtype_key() -> @core.PdfName {
  pdf_page_subtype_key_name
}

///|
fn pdf_page_xobject_key() -> @core.PdfName {
  pdf_page_xobject_key_name
}

///|
fn pdf_page_filter_key() -> @core.PdfName {
  pdf_page_filter_key_name
}

///|
fn pdf_page_popup_key() -> @core.PdfName {
  pdf_page_popup_key_name
}

///|
fn pdf_page_type_catalog() -> @core.PdfName {
  pdf_page_catalog_name
}

///|
fn pdf_page_type_pages() -> @core.PdfName {
  pdf_page_pages_name
}

///|
fn pdf_page_type_page() -> @core.PdfName {
  pdf_page_page_name
}

///|
fn pdf_page_type_link() -> @core.PdfName {
  pdf_page_link_name
}

///|
fn pdf_page_type_form() -> @core.PdfName {
  pdf_page_form_name
}

///|
fn pdf_page_resource_keys() -> Array[@core.PdfName] {
  [
    pdf_page_font_resource_name, pdf_page_extgstate_resource_name, pdf_page_colorspace_resource_name,
    pdf_page_pattern_resource_name, pdf_page_shading_resource_name, pdf_page_xobject_key_name,
    pdf_page_properties_resource_name,
  ]
}
