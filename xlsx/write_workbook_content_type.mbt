///|
fn workbook_content_type_for_extension(extension : StringView) -> String? {
  match extension.to_owned().to_lower() {
    "xlsx" => Some(ct_workbook)
    "xlsm" => Some(ct_workbook_macro)
    "xlam" => Some(ct_workbook_addin_macro)
    "xltx" => Some(ct_workbook_template)
    "xltm" => Some(ct_workbook_template_macro)
    _ => None
  }
}
