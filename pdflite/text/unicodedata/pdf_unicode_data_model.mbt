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
