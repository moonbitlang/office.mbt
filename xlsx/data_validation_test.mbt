///|
test "data validation drop list roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let dv = DataValidation::new(false)
  dv.set_sqref("A1:B2")
  dv.set_drop_list(["Yes", "No"])
  sheet.add_data_validation(dv)
  let validations = sheet.get_data_validations()
  inspect(validations.length(), content="1")
  let first = validations[0]
  inspect(first.validation_type, content="list")
  inspect(first.formula1, content="\"Yes,No\"")
  inspect(first.sqref, content="A1:B2")
  inspect(first.allow_blank, content="false")
}

///|
test "data validation drop list length limit" {
  let dv = DataValidation::new(true)
  let long = "a".repeat(260)
  let result : Result[Unit, Error] = try? dv.set_drop_list([long])
  guard result is Err(XlsxError::InvalidDataValidation(_)) else {
    fail("expected length error")
  }
}

///|
test "data validation range value bounds" {
  let dv = DataValidation::new(true)
  let result : Result[Unit, Error] = try? dv.set_range(
    DataValidationFormula::DoubleValue(1.0e39),
    DataValidationFormula::IntValue(10),
    DataValidationType::Whole,
    DataValidationOperator::Between,
  )
  guard result is Err(XlsxError::InvalidDataValidation(_)) else {
    fail("expected range error")
  }
}

///|
test "data validation delete by sqref" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let dv1 = DataValidation::new(true)
  dv1.set_sqref("A1:A3")
  dv1.set_drop_list(["Yes"])
  sheet.add_data_validation(dv1)
  let dv2 = DataValidation::new(true)
  dv2.set_sqref("B1")
  dv2.set_drop_list(["No"])
  sheet.add_data_validation(dv2)
  sheet.delete_data_validation(sqrefs=["A2"])
  let validations = sheet.get_data_validations()
  let sqrefs : Array[String] = []
  for dv in validations {
    sqrefs.push(dv.sqref)
  }
  inspect(sqrefs.contains("A1 A3"), content="true")
  inspect(sqrefs.contains("B1"), content="true")
}
