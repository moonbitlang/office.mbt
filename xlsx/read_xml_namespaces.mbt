///|
/// Converts namespace-qualified OOXML element names into the lexical form used
/// by the existing bounded feature parsers. The source is fully namespace- and
/// structure-validated before rewriting; only names change, never values.
fn canonicalize_xlsx_xml(xml : StringView) -> String raise XlsxError {
  @ooxml.canonicalize_xml_expanded_names(
    xml,
    [transitional_spreadsheet_namespace, strict_spreadsheet_namespace],
    [
      (transitional_relationship_attribute_namespace, "r"),
      (strict_relationship_attribute_namespace, "r"),
    ],
  ) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
  }
}

///|
test "XLSX XML canonicalization handles Strict elements and relationship attributes" {
  let source =
    #|<s:worksheet xmlns:s="http://purl.oclc.org/ooxml/spreadsheetml/main" xmlns:q="http://purl.oclc.org/ooxml/officeDocument/relationships"><s:drawing q:id="d1"/><s:sheetData><s:row r="1"><s:c r="A1" t="str"><s:v>ok</s:v></s:c></s:row></s:sheetData></s:worksheet>
  inspect(
    canonicalize_xlsx_xml(source),
    content=(
      #|<worksheet xmlns:s="http://purl.oclc.org/ooxml/spreadsheetml/main" xmlns:q="http://purl.oclc.org/ooxml/officeDocument/relationships"><drawing r:id="d1"/><sheetData><row r="1"><c r="A1" t="str"><v>ok</v></c></row></sheetData></worksheet>
    ),
  )
}
