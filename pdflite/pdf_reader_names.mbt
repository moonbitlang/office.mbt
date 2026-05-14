///|
fn pdf_reader_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_reader_type_key_name : PdfName = pdf_reader_name("/Type")

///|
let pdf_reader_xref_key_name : PdfName = pdf_reader_name("/XRef")

///|
let pdf_reader_objstm_key_name : PdfName = pdf_reader_name("/ObjStm")

///|
let pdf_reader_w_key_name : PdfName = pdf_reader_name("/W")

///|
let pdf_reader_index_key_name : PdfName = pdf_reader_name("/Index")

///|
let pdf_reader_size_key_name : PdfName = pdf_reader_name("/Size")

///|
let pdf_reader_n_key_name : PdfName = pdf_reader_name("/N")

///|
let pdf_reader_first_key_name : PdfName = pdf_reader_name("/First")

///|
let pdf_reader_linearized_key_name : PdfName = pdf_reader_name("/Linearized")

///|
let pdf_reader_filter_key_name : PdfName = pdf_reader_name("/Filter")

///|
let pdf_reader_short_filter_key_name : PdfName = pdf_reader_name("/F")

///|
let pdf_reader_decodeparms_key_name : PdfName = pdf_reader_name("/DecodeParms")

///|
let pdf_reader_short_decodeparms_key_name : PdfName = pdf_reader_name("/DP")

///|
let pdf_reader_root_key_name : PdfName = pdf_reader_name("/Root")

///|
let pdf_reader_prev_key_name : PdfName = pdf_reader_name("/Prev")

///|
let pdf_reader_xrefstm_key_name : PdfName = pdf_reader_name("/XRefStm")

///|
let pdf_length_key_name : PdfName = pdf_reader_name("/Length")

///|
fn pdf_reader_type_name() -> PdfName {
  pdf_reader_type_key_name
}

///|
fn pdf_reader_xref_name() -> PdfName {
  pdf_reader_xref_key_name
}

///|
fn pdf_reader_objstm_name() -> PdfName {
  pdf_reader_objstm_key_name
}

///|
fn pdf_reader_w_name() -> PdfName {
  pdf_reader_w_key_name
}

///|
fn pdf_reader_index_name() -> PdfName {
  pdf_reader_index_key_name
}

///|
fn pdf_reader_size_name() -> PdfName {
  pdf_reader_size_key_name
}

///|
fn pdf_reader_n_name() -> PdfName {
  pdf_reader_n_key_name
}

///|
fn pdf_reader_first_name() -> PdfName {
  pdf_reader_first_key_name
}

///|
fn pdf_reader_linearized_name() -> PdfName {
  pdf_reader_linearized_key_name
}

///|
fn pdf_reader_filter_name() -> PdfName {
  pdf_reader_filter_key_name
}

///|
fn pdf_reader_short_filter_name() -> PdfName {
  pdf_reader_short_filter_key_name
}

///|
fn pdf_reader_decodeparms_name() -> PdfName {
  pdf_reader_decodeparms_key_name
}

///|
fn pdf_reader_short_decodeparms_name() -> PdfName {
  pdf_reader_short_decodeparms_key_name
}
