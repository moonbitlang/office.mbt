///|
fn pdf_image_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_image_image_mask_key_name : PdfName = pdf_image_name("/ImageMask")

///|
let pdf_image_im_key_name : PdfName = pdf_image_name("/IM")

///|
let pdf_image_colorspace_key_name : PdfName = pdf_image_name("/ColorSpace")

///|
let pdf_image_cs_key_name : PdfName = pdf_image_name("/CS")

///|
let pdf_image_bits_per_component_key_name : PdfName = pdf_image_name(
  "/BitsPerComponent",
)

///|
let pdf_image_bpc_key_name : PdfName = pdf_image_name("/BPC")

///|
let pdf_image_width_key_name : PdfName = pdf_image_name("/Width")

///|
let pdf_image_w_key_name : PdfName = pdf_image_name("/W")

///|
let pdf_image_height_key_name : PdfName = pdf_image_name("/Height")

///|
let pdf_image_h_key_name : PdfName = pdf_image_name("/H")

///|
let pdf_image_decode_key_name : PdfName = pdf_image_name("/Decode")

///|
let pdf_image_d_key_name : PdfName = pdf_image_name("/D")

///|
let pdf_image_decodeparms_key_name : PdfName = pdf_image_name("/DecodeParms")

///|
let pdf_image_dp_key_name : PdfName = pdf_image_name("/DP")

///|
let pdf_image_jbig2_globals_key_name : PdfName = pdf_image_name("/JBIG2Globals")

///|
let pdf_image_dctdecode_name_value : PdfName = pdf_image_name("/DCTDecode")

///|
let pdf_image_dct_name_value : PdfName = pdf_image_name("/DCT")

///|
let pdf_image_jbig2decode_name_value : PdfName = pdf_image_name("/JBIG2Decode")

///|
let pdf_image_jpxdecode_name_value : PdfName = pdf_image_name("/JPXDecode")

///|
let pdf_image_length_key_name : PdfName = pdf_image_name("/Length")

///|
let pdf_image_filter_key_name : PdfName = pdf_image_name("/Filter")

///|
let pdf_image_f_key_name : PdfName = pdf_image_name("/F")

///|
let pdf_image_subtype_key_name : PdfName = pdf_image_name("/Subtype")

///|
let pdf_image_image_name_value : PdfName = pdf_image_name("/Image")

///|
let pdf_image_device_rgb_name_value : PdfName = pdf_image_name("/DeviceRGB")

///|
let pdf_image_device_gray_name_value : PdfName = pdf_image_name("/DeviceGray")

///|
let pdf_image_xobject_key_name : PdfName = pdf_image_name("/XObject")

///|
let pdf_image_smask_key_name : PdfName = pdf_image_name("/SMask")

///|
let pdf_image_mask_key_name : PdfName = pdf_image_name("/Mask")

///|
let pdf_image_smask_in_data_key_name : PdfName = pdf_image_name("/SMaskInData")

///|
let pdf_image_i0_name_value : PdfName = pdf_image_name("/I0")

///|
let pdf_image_struct_parents_key_name : PdfName = pdf_image_name(
  "/StructParents",
)

///|
let pdf_image_figure_name_value : PdfName = pdf_image_name("/Figure")

///|
let pdf_image_mcid_key_name : PdfName = pdf_image_name("/MCID")

///|
let pdf_image_alt_key_name : PdfName = pdf_image_name("/Alt")

///|
let pdf_image_p_key_name : PdfName = pdf_image_name("/P")

///|
let pdf_image_s_key_name : PdfName = pdf_image_name("/S")

///|
let pdf_image_nums_key_name : PdfName = pdf_image_name("/Nums")

///|
let pdf_image_namespaces_key_name : PdfName = pdf_image_name("/Namespaces")

///|
let pdf_image_ns_key_name : PdfName = pdf_image_name("/NS")

///|
let pdf_image_document_name_value : PdfName = pdf_image_name("/Document")

///|
let pdf_image_form_name_value : PdfName = pdf_image_name("/Form")

///|
let pdf_image_matrix_key_name : PdfName = pdf_image_name("/Matrix")

///|
let pdf_image_ccittfaxdecode_name_value : PdfName = pdf_image_name(
  "/CCITTFaxDecode",
)

///|
let pdf_image_k_key_name : PdfName = pdf_image_name("/K")

///|
let pdf_image_pdfua2_namespace : PdfBytes = @ascii.encode(
  "http://iso.org/pdf2/ssn",
)

///|
let pdf_image_jbig2_globals_object_number : Int = 10000

///|
let pdf_image_debug_image_processing_enabled : Ref[Bool] = { val: false }

///|
/// Return cpdfimage's `debug_image_processing` flag.
pub fn pdf_image_debug_image_processing() -> Bool {
  pdf_image_debug_image_processing_enabled.val
}

///|
/// Set cpdfimage's `debug_image_processing` flag.
pub fn pdf_image_set_debug_image_processing(enabled : Bool) -> Unit {
  pdf_image_debug_image_processing_enabled.val = enabled
}

///|
/// Source-spelled cpdfimage `debug_image_processing` flag reader.
pub fn pdf_debug_image_processing() -> Bool {
  pdf_image_debug_image_processing()
}

///|
/// Set cpdfimage's `debug_image_processing` flag through the source-spelled
/// compatibility surface.
pub fn pdf_set_debug_image_processing(enabled : Bool) -> Unit {
  pdf_image_set_debug_image_processing(enabled)
}

///|
fn pdf_image_image_mask_key() -> PdfName {
  pdf_image_image_mask_key_name
}

///|
fn pdf_image_im_key() -> PdfName {
  pdf_image_im_key_name
}

///|
fn pdf_image_colorspace_key() -> PdfName {
  pdf_image_colorspace_key_name
}

///|
fn pdf_image_cs_key() -> PdfName {
  pdf_image_cs_key_name
}

///|
fn pdf_image_bits_per_component_key() -> PdfName {
  pdf_image_bits_per_component_key_name
}

///|
fn pdf_image_bpc_key() -> PdfName {
  pdf_image_bpc_key_name
}

///|
fn pdf_image_width_key() -> PdfName {
  pdf_image_width_key_name
}

///|
fn pdf_image_w_key() -> PdfName {
  pdf_image_w_key_name
}

///|
fn pdf_image_height_key() -> PdfName {
  pdf_image_height_key_name
}

///|
fn pdf_image_h_key() -> PdfName {
  pdf_image_h_key_name
}

///|
fn pdf_image_decode_key() -> PdfName {
  pdf_image_decode_key_name
}

///|
fn pdf_image_d_key() -> PdfName {
  pdf_image_d_key_name
}

///|
fn pdf_image_decodeparms_key() -> PdfName {
  pdf_image_decodeparms_key_name
}

///|
fn pdf_image_dp_key() -> PdfName {
  pdf_image_dp_key_name
}

///|
fn pdf_image_jbig2_globals_key() -> PdfName {
  pdf_image_jbig2_globals_key_name
}

///|
fn pdf_image_dctdecode_name() -> PdfName {
  pdf_image_dctdecode_name_value
}

///|
fn pdf_image_dct_name() -> PdfName {
  pdf_image_dct_name_value
}

///|
fn pdf_image_jbig2decode_name() -> PdfName {
  pdf_image_jbig2decode_name_value
}

///|
fn pdf_image_jpxdecode_name() -> PdfName {
  pdf_image_jpxdecode_name_value
}

///|
fn pdf_image_length_key() -> PdfName {
  pdf_image_length_key_name
}

///|
fn pdf_image_filter_key() -> PdfName {
  pdf_image_filter_key_name
}

///|
fn pdf_image_f_key() -> PdfName {
  pdf_image_f_key_name
}

///|
fn pdf_image_subtype_key() -> PdfName {
  pdf_image_subtype_key_name
}

///|
fn pdf_image_image_name() -> PdfName {
  pdf_image_image_name_value
}

///|
fn pdf_image_device_rgb_name() -> PdfName {
  pdf_image_device_rgb_name_value
}

///|
fn pdf_image_device_gray_name() -> PdfName {
  pdf_image_device_gray_name_value
}

///|
fn pdf_image_xobject_key() -> PdfName {
  pdf_image_xobject_key_name
}

///|
fn pdf_image_smask_key() -> PdfName {
  pdf_image_smask_key_name
}

///|
fn pdf_image_mask_key() -> PdfName {
  pdf_image_mask_key_name
}

///|
fn pdf_image_smask_in_data_key() -> PdfName {
  pdf_image_smask_in_data_key_name
}

///|
fn pdf_image_i0_name() -> PdfName {
  pdf_image_i0_name_value
}

///|
fn pdf_image_struct_parents_key() -> PdfName {
  pdf_image_struct_parents_key_name
}

///|
fn pdf_image_figure_name() -> PdfName {
  pdf_image_figure_name_value
}

///|
fn pdf_image_mcid_key() -> PdfName {
  pdf_image_mcid_key_name
}

///|
fn pdf_image_alt_key() -> PdfName {
  pdf_image_alt_key_name
}

///|
fn pdf_image_p_key() -> PdfName {
  pdf_image_p_key_name
}

///|
fn pdf_image_s_key() -> PdfName {
  pdf_image_s_key_name
}

///|
fn pdf_image_nums_key() -> PdfName {
  pdf_image_nums_key_name
}

///|
fn pdf_image_namespaces_key() -> PdfName {
  pdf_image_namespaces_key_name
}

///|
fn pdf_image_ns_key() -> PdfName {
  pdf_image_ns_key_name
}

///|
fn pdf_image_document_name() -> PdfName {
  pdf_image_document_name_value
}

///|
fn pdf_image_form_name() -> PdfName {
  pdf_image_form_name_value
}

///|
fn pdf_image_matrix_key() -> PdfName {
  pdf_image_matrix_key_name
}

///|
fn pdf_image_ccittfaxdecode_name() -> PdfName {
  pdf_image_ccittfaxdecode_name_value
}

///|
fn pdf_image_k_key() -> PdfName {
  pdf_image_k_key_name
}
