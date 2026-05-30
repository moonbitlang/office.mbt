///|
fn pdf_squeeze_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_squeeze_type_key_name : @core.PdfName = pdf_squeeze_name("/Type")

///|
fn pdf_squeeze_type_key() -> @core.PdfName {
  pdf_squeeze_type_key_name
}

///|
let pdf_squeeze_metadata_name_value : @core.PdfName = pdf_squeeze_name(
  "/Metadata",
)

///|
fn pdf_squeeze_metadata_name() -> @core.PdfName {
  pdf_squeeze_metadata_name_value
}

///|
let pdf_squeeze_page_name_value : @core.PdfName = pdf_squeeze_name("/Page")

///|
fn pdf_squeeze_page_name() -> @core.PdfName {
  pdf_squeeze_page_name_value
}

///|
let pdf_squeeze_subtype_key_name : @core.PdfName = pdf_squeeze_name("/Subtype")

///|
fn pdf_squeeze_subtype_key() -> @core.PdfName {
  pdf_squeeze_subtype_key_name
}

///|
fn pdf_squeeze_old_filter(name : @core.PdfName) -> Bool {
  name == pdf_filter_ascii_hex_decode_name ||
  name == pdf_filter_ascii_hex_short_name ||
  name == pdf_filter_ascii85_decode_name ||
  name == pdf_filter_ascii85_short_name ||
  name == pdf_filter_lzw_decode_name ||
  name == pdf_filter_lzw_short_name ||
  name == pdf_filter_run_length_decode_name ||
  name == pdf_filter_run_length_short_name
}

///|
fn pdf_squeeze_annotation_subtype(name : @core.PdfName) -> Bool {
  name == pdf_squeeze_name("/Text") ||
  name == pdf_squeeze_name("/Link") ||
  name == pdf_squeeze_name("/FreeText") ||
  name == pdf_squeeze_name("/Line") ||
  name == pdf_squeeze_name("/Square") ||
  name == pdf_squeeze_name("/Circle") ||
  name == pdf_squeeze_name("/Polygon") ||
  name == pdf_squeeze_name("/PolyLine") ||
  name == pdf_squeeze_name("/Highlight") ||
  name == pdf_squeeze_name("/Underline") ||
  name == pdf_squeeze_name("/Squiggly") ||
  name == pdf_squeeze_name("/StrikeOut") ||
  name == pdf_squeeze_name("/Caret") ||
  name == pdf_squeeze_name("/Stamp") ||
  name == pdf_squeeze_name("/Ink") ||
  name == pdf_squeeze_name("/Popup") ||
  name == pdf_squeeze_name("/FileAttachment") ||
  name == pdf_squeeze_name("/Sound") ||
  name == pdf_squeeze_name("/Movie") ||
  name == pdf_squeeze_name("/Screen") ||
  name == pdf_squeeze_name("/Widget") ||
  name == pdf_squeeze_name("/PrinterMark") ||
  name == pdf_squeeze_name("/TrapNet") ||
  name == pdf_squeeze_name("/3D") ||
  name == pdf_squeeze_name("/Redact") ||
  name == pdf_squeeze_name("/Projection") ||
  name == pdf_squeeze_name("/RichMedia")
}
