///|
test "slicer APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let slicer = Slicer::new("Slicer1") catch {
    err => fail("slicer init failed: \{err}")
  }
  let add_raw_result : Result[Unit, Error] = try? workbook.add_slicer_raw(
    "Sheet:1", slicer,
  )
  inspect(add_raw_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let get_result : Result[Array[Slicer], Error] = try? workbook.get_slicers(
    "Sheet:1",
  )
  inspect(get_result is Err(XlsxError::InvalidSheetName(_)), content="true")
}
