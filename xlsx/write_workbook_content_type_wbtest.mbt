///|
test "write workbook content type: known extensions map to workbook content types" {
  inspect(
    workbook_content_type_for_extension("xlsx"),
    content="Some(\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\")",
  )
  inspect(
    workbook_content_type_for_extension("xlsm"),
    content="Some(\"application/vnd.ms-excel.sheet.macroEnabled.main+xml\")",
  )
  inspect(
    workbook_content_type_for_extension("xlam"),
    content="Some(\"application/vnd.ms-excel.addin.macroEnabled.main+xml\")",
  )
  inspect(
    workbook_content_type_for_extension("xltx"),
    content="Some(\"application/vnd.openxmlformats-officedocument.spreadsheetml.template.main+xml\")",
  )
  inspect(
    workbook_content_type_for_extension("xltm"),
    content="Some(\"application/vnd.ms-excel.template.macroEnabled.main+xml\")",
  )
}

///|
test "write workbook content type: extension matching is case-insensitive and unknown returns None" {
  inspect(
    workbook_content_type_for_extension("XLSX"),
    content="Some(\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\")",
  )
  inspect(workbook_content_type_for_extension("xls"), content="None")
  inspect(workbook_content_type_for_extension(""), content="None")
}
