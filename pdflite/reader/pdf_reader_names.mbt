///|
fn pdf_reader_cached_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_reader_type_key_name : @core.PdfName = pdf_reader_cached_name("/Type")

///|
let pdf_reader_xref_key_name : @core.PdfName = pdf_reader_cached_name("/XRef")

///|
let pdf_reader_objstm_key_name : @core.PdfName = pdf_reader_cached_name(
  "/ObjStm",
)

///|
let pdf_reader_w_key_name : @core.PdfName = pdf_reader_cached_name("/W")

///|
let pdf_reader_index_key_name : @core.PdfName = pdf_reader_cached_name("/Index")

///|
let pdf_reader_size_key_name : @core.PdfName = pdf_reader_cached_name("/Size")

///|
let pdf_reader_n_key_name : @core.PdfName = pdf_reader_cached_name("/N")

///|
let pdf_reader_first_key_name : @core.PdfName = pdf_reader_cached_name("/First")

///|
let pdf_reader_linearized_key_name : @core.PdfName = pdf_reader_cached_name(
  "/Linearized",
)

///|
let pdf_reader_filter_key_name : @core.PdfName = pdf_reader_cached_name(
  "/Filter",
)

///|
let pdf_reader_short_filter_key_name : @core.PdfName = pdf_reader_cached_name(
  "/F",
)

///|
let pdf_reader_decodeparms_key_name : @core.PdfName = pdf_reader_cached_name(
  "/DecodeParms",
)

///|
let pdf_reader_short_decodeparms_key_name : @core.PdfName = pdf_reader_cached_name(
  "/DP",
)

///|
let pdf_reader_root_key_name : @core.PdfName = pdf_reader_cached_name("/Root")

///|
let pdf_reader_prev_key_name : @core.PdfName = pdf_reader_cached_name("/Prev")

///|
let pdf_reader_xrefstm_key_name : @core.PdfName = pdf_reader_cached_name(
  "/XRefStm",
)

///|
let pdf_length_key_name : @core.PdfName = pdf_reader_cached_name("/Length")

///|
/// Build a PDF name from an ASCII slash-prefixed spelling.
pub fn pdf_reader_name(text : String) -> @core.PdfName {
  pdf_reader_cached_name(text)
}

///|
/// Return the `/Type` name.
pub fn pdf_reader_type_name() -> @core.PdfName {
  pdf_reader_type_key_name
}

///|
/// Return the `/XRef` name.
pub fn pdf_reader_xref_name() -> @core.PdfName {
  pdf_reader_xref_key_name
}

///|
/// Return the `/ObjStm` name.
pub fn pdf_reader_objstm_name() -> @core.PdfName {
  pdf_reader_objstm_key_name
}

///|
/// Return the `/W` name.
pub fn pdf_reader_w_name() -> @core.PdfName {
  pdf_reader_w_key_name
}

///|
/// Return the `/Index` name.
pub fn pdf_reader_index_name() -> @core.PdfName {
  pdf_reader_index_key_name
}

///|
/// Return the `/Size` name.
pub fn pdf_reader_size_name() -> @core.PdfName {
  pdf_reader_size_key_name
}

///|
/// Return the `/N` name.
pub fn pdf_reader_n_name() -> @core.PdfName {
  pdf_reader_n_key_name
}

///|
/// Return the `/First` name.
pub fn pdf_reader_first_name() -> @core.PdfName {
  pdf_reader_first_key_name
}

///|
/// Return the `/Linearized` name.
pub fn pdf_reader_linearized_name() -> @core.PdfName {
  pdf_reader_linearized_key_name
}

///|
/// Return the `/Filter` name.
pub fn pdf_reader_filter_name() -> @core.PdfName {
  pdf_reader_filter_key_name
}

///|
/// Return the short `/F` filter name.
pub fn pdf_reader_short_filter_name() -> @core.PdfName {
  pdf_reader_short_filter_key_name
}

///|
/// Return the `/DecodeParms` name.
pub fn pdf_reader_decodeparms_name() -> @core.PdfName {
  pdf_reader_decodeparms_key_name
}

///|
/// Return the short `/DP` decode-parameters name.
pub fn pdf_reader_short_decodeparms_name() -> @core.PdfName {
  pdf_reader_short_decodeparms_key_name
}

///|
/// Return the `/Root` name.
pub fn pdf_reader_root_name() -> @core.PdfName {
  pdf_reader_root_key_name
}

///|
/// Return the `/Prev` name.
pub fn pdf_reader_prev_name() -> @core.PdfName {
  pdf_reader_prev_key_name
}

///|
/// Return the `/XRefStm` name.
pub fn pdf_reader_xrefstm_name() -> @core.PdfName {
  pdf_reader_xrefstm_key_name
}

///|
/// Return the `/Length` name.
pub fn pdf_length_name() -> @core.PdfName {
  pdf_length_key_name
}
