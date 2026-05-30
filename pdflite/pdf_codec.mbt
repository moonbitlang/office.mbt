///|
let pdf_filter_key_name : @core.PdfName = pdf_filter_name("/Filter")

///|
let pdf_short_filter_key_name : @core.PdfName = pdf_filter_name("/F")

///|
let pdf_decodeparms_key_name : @core.PdfName = pdf_filter_name("/DecodeParms")

///|
let pdf_short_decodeparms_key_name : @core.PdfName = pdf_filter_name("/DP")

///|
let pdf_codec_length_key_name : @core.PdfName = pdf_filter_name("/Length")

///|
let pdf_predictor_key_name : @core.PdfName = pdf_filter_name("/Predictor")

///|
let pdf_early_change_key_name : @core.PdfName = pdf_filter_name("/EarlyChange")

///|
let pdf_ccitt_k_key_name : @core.PdfName = pdf_filter_name("/K")

///|
let pdf_ccitt_end_of_line_key_name : @core.PdfName = pdf_filter_name(
  "/EndOfLine",
)

///|
let pdf_ccitt_encoded_byte_align_key_name : @core.PdfName = pdf_filter_name(
  "/EncodedByteAlign",
)

///|
let pdf_ccitt_rows_key_name : @core.PdfName = pdf_filter_name("/Rows")

///|
let pdf_ccitt_end_of_block_key_name : @core.PdfName = pdf_filter_name(
  "/EndOfBlock",
)

///|
let pdf_ccitt_black_is_1_key_name : @core.PdfName = pdf_filter_name("/BlackIs1")

///|
let pdf_ccitt_damaged_rows_before_error_key_name : @core.PdfName = pdf_filter_name(
  "/DamagedRowsBeforeError",
)

///|
let pdf_colors_key_name : @core.PdfName = pdf_filter_name("/Colors")

///|
let pdf_bits_per_component_key_name : @core.PdfName = pdf_filter_name(
  "/BitsPerComponent",
)

///|
let pdf_columns_key_name : @core.PdfName = pdf_filter_name("/Columns")

///|
fn pdf_filter_key() -> @core.PdfName {
  pdf_filter_key_name
}

///|
fn pdf_short_filter_key() -> @core.PdfName {
  pdf_short_filter_key_name
}

///|
fn pdf_decodeparms_key() -> @core.PdfName {
  pdf_decodeparms_key_name
}

///|
fn pdf_short_decodeparms_key() -> @core.PdfName {
  pdf_short_decodeparms_key_name
}

///|
fn pdf_codec_length_key() -> @core.PdfName {
  pdf_codec_length_key_name
}

///|
fn pdf_predictor_key() -> @core.PdfName {
  pdf_predictor_key_name
}

///|
fn pdf_early_change_key() -> @core.PdfName {
  pdf_early_change_key_name
}

///|
fn pdf_ccitt_k_key() -> @core.PdfName {
  pdf_ccitt_k_key_name
}

///|
fn pdf_ccitt_end_of_line_key() -> @core.PdfName {
  pdf_ccitt_end_of_line_key_name
}

///|
fn pdf_ccitt_encoded_byte_align_key() -> @core.PdfName {
  pdf_ccitt_encoded_byte_align_key_name
}

///|
fn pdf_ccitt_rows_key() -> @core.PdfName {
  pdf_ccitt_rows_key_name
}

///|
fn pdf_ccitt_end_of_block_key() -> @core.PdfName {
  pdf_ccitt_end_of_block_key_name
}

///|
fn pdf_ccitt_black_is_1_key() -> @core.PdfName {
  pdf_ccitt_black_is_1_key_name
}

///|
fn pdf_ccitt_damaged_rows_before_error_key() -> @core.PdfName {
  pdf_ccitt_damaged_rows_before_error_key_name
}

///|
fn pdf_colors_key() -> @core.PdfName {
  pdf_colors_key_name
}

///|
fn pdf_bits_per_component_key() -> @core.PdfName {
  pdf_bits_per_component_key_name
}

///|
fn pdf_columns_key() -> @core.PdfName {
  pdf_columns_key_name
}
