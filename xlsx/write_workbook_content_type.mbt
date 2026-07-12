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

///|
test "write workbook content type: known extensions map to workbook content types" {
  debug_inspect(
    workbook_content_type_for_extension("xlsx"),
    content="Some(\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\")",
  )
  debug_inspect(
    workbook_content_type_for_extension("xlsm"),
    content="Some(\"application/vnd.ms-excel.sheet.macroEnabled.main+xml\")",
  )
  debug_inspect(
    workbook_content_type_for_extension("xlam"),
    content="Some(\"application/vnd.ms-excel.addin.macroEnabled.main+xml\")",
  )
  debug_inspect(
    workbook_content_type_for_extension("xltx"),
    content="Some(\"application/vnd.openxmlformats-officedocument.spreadsheetml.template.main+xml\")",
  )
  debug_inspect(
    workbook_content_type_for_extension("xltm"),
    content="Some(\"application/vnd.ms-excel.template.macroEnabled.main+xml\")",
  )
}

///|
test "write workbook content type: extension matching is case-insensitive and unknown returns None" {
  debug_inspect(
    workbook_content_type_for_extension("XLSX"),
    content="Some(\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\")",
  )
  debug_inspect(workbook_content_type_for_extension("xls"), content="None")
  debug_inspect(workbook_content_type_for_extension(""), content="None")
}
