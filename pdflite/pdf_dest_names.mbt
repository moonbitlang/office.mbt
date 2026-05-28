///|
fn pdf_dest_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_dest_d_key_name : PdfName = pdf_dest_name("/D")

///|
fn pdf_dest_d_key() -> PdfName {
  pdf_dest_d_key_name
}

///|
let pdf_dest_s_key_name : PdfName = pdf_dest_name("/S")

///|
fn pdf_dest_s_key() -> PdfName {
  pdf_dest_s_key_name
}

///|
let pdf_dest_goto_name_value : PdfName = pdf_dest_name("/GoTo")

///|
fn pdf_dest_goto_name() -> PdfName {
  pdf_dest_goto_name_value
}

///|
let pdf_dest_dests_key_name : PdfName = pdf_dest_name("/Dests")

///|
fn pdf_dest_dests_key() -> PdfName {
  pdf_dest_dests_key_name
}

///|
let pdf_dest_names_key_name : PdfName = pdf_dest_name("/Names")

///|
fn pdf_dest_names_key() -> PdfName {
  pdf_dest_names_key_name
}

///|
let pdf_dest_type_xyz_name : PdfName = pdf_dest_name("/XYZ")

///|
fn pdf_dest_type_xyz() -> PdfName {
  pdf_dest_type_xyz_name
}

///|
let pdf_dest_type_fit_name : PdfName = pdf_dest_name("/Fit")

///|
fn pdf_dest_type_fit() -> PdfName {
  pdf_dest_type_fit_name
}

///|
let pdf_dest_type_fith_name : PdfName = pdf_dest_name("/FitH")

///|
fn pdf_dest_type_fith() -> PdfName {
  pdf_dest_type_fith_name
}

///|
let pdf_dest_type_fitv_name : PdfName = pdf_dest_name("/FitV")

///|
fn pdf_dest_type_fitv() -> PdfName {
  pdf_dest_type_fitv_name
}

///|
let pdf_dest_type_fitr_name : PdfName = pdf_dest_name("/FitR")

///|
fn pdf_dest_type_fitr() -> PdfName {
  pdf_dest_type_fitr_name
}

///|
let pdf_dest_type_fitb_name : PdfName = pdf_dest_name("/FitB")

///|
fn pdf_dest_type_fitb() -> PdfName {
  pdf_dest_type_fitb_name
}

///|
let pdf_dest_type_fitbh_name : PdfName = pdf_dest_name("/FitBH")

///|
fn pdf_dest_type_fitbh() -> PdfName {
  pdf_dest_type_fitbh_name
}

///|
let pdf_dest_type_fitbv_name : PdfName = pdf_dest_name("/FitBV")

///|
fn pdf_dest_type_fitbv() -> PdfName {
  pdf_dest_type_fitbv_name
}
