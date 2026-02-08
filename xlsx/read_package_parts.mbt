///|
fn workbook_content_type_candidates() -> Array[String] {
  [
    ct_workbook, ct_workbook_macro, ct_workbook_addin_macro, ct_workbook_template,
    ct_workbook_template_macro,
  ]
}

///|
fn resolve_workbook_xml_part_path(
  archive : @zip.Archive,
  decode : (Bytes) -> String raise XlsxError,
) -> String raise XlsxError {
  match archive.get(content_types_part_path) {
    Some(content_types_bytes) => {
      let content_types_xml = decode(content_types_bytes)
      let workbook_part_name = @ooxml.find_override_part_by_content_types(
        content_types_xml,
        workbook_content_type_candidates(),
      ) catch {
        @ooxml.ParseXmlError::InvalidXml(msg~) => raise InvalidXml(msg~)
      }
      match workbook_part_name {
        Some(part_name) => archive_path_from_part_name(part_name)
        None => workbook_part_path
      }
    }
    None => workbook_part_path
  }
}
