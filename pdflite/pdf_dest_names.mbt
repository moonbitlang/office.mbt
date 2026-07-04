///|
fn pdf_dest_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_dest_d_key_name : @core.PdfName = pdf_dest_name("/D")

///|
fn pdf_dest_d_key() -> @core.PdfName {
  pdf_dest_d_key_name
}

///|
let pdf_dest_s_key_name : @core.PdfName = pdf_dest_name("/S")

///|
fn pdf_dest_s_key() -> @core.PdfName {
  pdf_dest_s_key_name
}

///|
let pdf_dest_goto_name_value : @core.PdfName = pdf_dest_name("/GoTo")

///|
fn pdf_dest_goto_name() -> @core.PdfName {
  pdf_dest_goto_name_value
}

///|
let pdf_dest_dests_key_name : @core.PdfName = pdf_dest_name("/Dests")

///|
fn pdf_dest_dests_key() -> @core.PdfName {
  pdf_dest_dests_key_name
}

///|
let pdf_dest_names_key_name : @core.PdfName = pdf_dest_name("/Names")

///|
fn pdf_dest_names_key() -> @core.PdfName {
  pdf_dest_names_key_name
}

///|
let pdf_dest_type_xyz_name : @core.PdfName = pdf_dest_name("/XYZ")

///|
fn pdf_dest_type_xyz() -> @core.PdfName {
  pdf_dest_type_xyz_name
}

///|
let pdf_dest_type_fit_name : @core.PdfName = pdf_dest_name("/Fit")

///|
fn pdf_dest_type_fit() -> @core.PdfName {
  pdf_dest_type_fit_name
}

///|
let pdf_dest_type_fith_name : @core.PdfName = pdf_dest_name("/FitH")

///|
fn pdf_dest_type_fith() -> @core.PdfName {
  pdf_dest_type_fith_name
}

///|
let pdf_dest_type_fitv_name : @core.PdfName = pdf_dest_name("/FitV")

///|
fn pdf_dest_type_fitv() -> @core.PdfName {
  pdf_dest_type_fitv_name
}

///|
let pdf_dest_type_fitr_name : @core.PdfName = pdf_dest_name("/FitR")

///|
fn pdf_dest_type_fitr() -> @core.PdfName {
  pdf_dest_type_fitr_name
}

///|
let pdf_dest_type_fitb_name : @core.PdfName = pdf_dest_name("/FitB")

///|
fn pdf_dest_type_fitb() -> @core.PdfName {
  pdf_dest_type_fitb_name
}

///|
let pdf_dest_type_fitbh_name : @core.PdfName = pdf_dest_name("/FitBH")

///|
fn pdf_dest_type_fitbh() -> @core.PdfName {
  pdf_dest_type_fitbh_name
}

///|
let pdf_dest_type_fitbv_name : @core.PdfName = pdf_dest_name("/FitBV")

///|
fn pdf_dest_type_fitbv() -> @core.PdfName {
  pdf_dest_type_fitbv_name
}
