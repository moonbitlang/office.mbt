///|
/// One row from UnicodeData.txt as exposed by cpdf's `Cpdfunicodedata.t`.
///
/// UnicodeData.txt is an ASCII, semicolon-separated data file. The fields stay
/// as strings to match cpdf's public record and to avoid silently choosing
/// semantics for numeric-looking values such as code values and mappings.
pub(all) struct PdfUnicodeDataEntry {
  code_value : String
  character_name : String
  general_category : String
  canonical_combining_classes : String
  bidirectional_category : String
  character_decomposition_mapping : String
  decimal_digit_value : String
  digit_value : String
  numeric_value : String
  mirrored : String
  unicode_10_name : String
  iso_10646_comment_field : String
  uppercase_mapping : String
  lowercase_mapping : String
  titlecase_mapping : String
} derive(Debug, Eq, ToJson)

///|
fn pdf_unicode_data_field(
  source : BytesView,
  start : Int,
  end : Int,
) -> String raise PdfError {
  @ascii.decode(source[start:end]) catch {
    _ => raise SoftError("malformed UnicodeData.txt row")
  }
}

///|
fn pdf_unicode_data_parse_row(
  source : BytesView,
  start : Int,
  end : Int,
) -> PdfUnicodeDataEntry raise PdfError {
  let fields : Array[String] = []
  let mut field_start = start
  let mut index = start
  while index < end {
    if source[index].to_int() == 59 {
      fields.push(pdf_unicode_data_field(source, field_start, index))
      field_start = index + 1
    }
    index += 1
  }
  fields.push(pdf_unicode_data_field(source, field_start, end))
  guard fields.length() == 15 else {
    raise SoftError("malformed UnicodeData.txt row")
  }
  {
    code_value: fields[0],
    character_name: fields[1],
    general_category: fields[2],
    canonical_combining_classes: fields[3],
    bidirectional_category: fields[4],
    character_decomposition_mapping: fields[5],
    decimal_digit_value: fields[6],
    digit_value: fields[7],
    numeric_value: fields[8],
    mirrored: fields[9],
    unicode_10_name: fields[10],
    iso_10646_comment_field: fields[11],
    uppercase_mapping: fields[12],
    lowercase_mapping: fields[13],
    titlecase_mapping: fields[14],
  }
}

///|
/// Parse UnicodeData.txt bytes into cpdf-compatible rows.
pub fn pdf_parse_unicode_data(
  source : BytesView,
) -> Array[PdfUnicodeDataEntry] raise PdfError {
  let entries : Array[PdfUnicodeDataEntry] = []
  let mut index = 0
  while index < source.length() {
    let row_start = index
    while index < source.length() && source[index].to_int() != 10 {
      index += 1
    }
    let mut row_end = index
    if row_end > row_start && source[row_end - 1].to_int() == 13 {
      row_end -= 1
    }
    entries.push(pdf_unicode_data_parse_row(source, row_start, row_end))
    if index < source.length() {
      index += 1
    }
  }
  entries
}

///|
/// Decode cpdf's flate-compressed UnicodeData source bytes, then parse rows.
pub fn pdf_parse_flate_unicode_data(
  source : BytesView,
) -> Array[PdfUnicodeDataEntry] raise PdfError {
  pdf_parse_unicode_data(pdf_flate_decode_view(source))
}
