///|
test "data validation full-column deletion stays bounded" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let validation = @xlsx.DataValidation::new(true)
  validation.set_sqref("A1:A1048576")
  validation.set_drop_list(["valid"])
  sheet.add_data_validation(validation)

  sheet.delete_data_validation(sqrefs=["A1"])

  let validations = sheet.get_data_validations()
  inspect(validations.length(), content="1")
  inspect(validations[0].sqref, content="A2:A1048576")
}

///|
test "conditional format full-grid deletion stays bounded" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let format = @xlsx.ConditionalFormatOptions::new("cell")
  format.set_criteria(">")
  format.set_value("0")
  sheet.set_conditional_format("A1:XFD1048576", [format])

  sheet.unset_conditional_format("A1:XFD1048576")

  inspect(sheet.conditional_formats().length(), content="0")
}
