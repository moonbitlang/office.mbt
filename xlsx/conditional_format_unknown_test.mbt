///|
test "get_conditional_formats ignores unsupported cfRule types" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let sheet = workbook.sheet("Sheet1").unwrap()
  sheet.add_conditional_format_xml(
    "<conditionalFormatting sqref=\"A1\"><cfRule type=\"unsupported\" priority=\"1\"/></conditionalFormatting>",
  )
  let formats = workbook.get_conditional_formats("Sheet1")
  inspect(formats.get("A1").unwrap().length(), content="0")
}
