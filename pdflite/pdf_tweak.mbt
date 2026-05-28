///|
fn pdf_tweak_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_tweak_extgstate_key_name : PdfName = pdf_tweak_name("/ExtGState")

///|
fn pdf_tweak_extgstate_key() -> PdfName {
  pdf_tweak_extgstate_key_name
}

///|
let pdf_tweak_line_width_key_name : PdfName = pdf_tweak_name("/LW")

///|
fn pdf_tweak_line_width_key() -> PdfName {
  pdf_tweak_line_width_key_name
}

///|
let pdf_tweak_length_key_name : PdfName = pdf_tweak_name("/Length")

///|
fn pdf_tweak_length_key() -> PdfName {
  pdf_tweak_length_key_name
}

///|
let pdf_tweak_device_rgb_key_name : PdfName = pdf_tweak_name("/DeviceRGB")

///|
fn pdf_tweak_device_rgb_key() -> PdfName {
  pdf_tweak_device_rgb_key_name
}
