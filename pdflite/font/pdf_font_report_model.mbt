///|
/// One font resource entry reported by cpdf-style font listing.
///
/// `page` is one-based. `name`, `subtype`, `basefont`, and `encoding` are PDF
/// names rendered with their leading slash; missing non-name fields are empty
/// strings to match cpdf's text listing and JSON-null conversion.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfFontListEntry {
  page : Int32
  name : String
  subtype : String
  basefont : String
  encoding : String
  font : @syntax.PdfObject
}

///|
/// One cpdf-style missing-font report entry.
///
/// `encoding == "Built-in"` records cpdf's fallback when a missing font does
/// not have a named `/Encoding`.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfMissingFontEntry {
  page : Int32
  name : String
  subtype : String
  basefont : String
  encoding : String
}

///|
/// One row from cpdf's font encoding table.
///
/// `unicode_name` is empty when this port has no Unicode character-name table
/// entry for the codepoint. `utf8` is `<nonprintable>` for C0/C1 controls.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfFontTableEntry {
  code : Int32
  unicode : String
  utf8 : String
  unicode_name : String
  glyphnames : String
}
