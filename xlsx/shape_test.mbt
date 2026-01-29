///|
test "shape workbook sheet name validation" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_shape("Sheet1", Shape::new("A1", "rect"))
  let bad_name : Result[Unit, Error] = try? workbook.add_shape(
    "Sheet:1",
    Shape::new("A1", "rect"),
  )
  inspect(bad_name is Err(XlsxError::InvalidSheetName(_)), content="true")
  let missing : Result[Unit, Error] = try? workbook.add_shape(
    "SheetN",
    Shape::new("A1", "rect"),
  )
  inspect(missing is Err(XlsxError::SheetNotFound(_)), content="true")
}
