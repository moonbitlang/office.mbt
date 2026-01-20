///|
test "data validation and conditional formatting" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_data_validation_list("A1:A2", ["Yes", "No"], allow_blank=false)
  sheet.add_conditional_format_xml(
    "<conditionalFormatting sqref=\"A1\"><cfRule type=\"expression\" priority=\"1\"><formula>A1>0</formula></cfRule></conditionalFormatting>",
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet")
  }
  inspect(sheet_xml.contains("<dataValidations count=\"1\">"), content="true")
  inspect(sheet_xml.contains("type=\"list\""), content="true")
  inspect(sheet_xml.contains("<formula1>\"Yes,No\"</formula1>"), content="true")
  inspect(sheet_xml.contains("conditionalFormatting"), content="true")
}
