///|
test "public chart API rejects extent overflow before integer narrowing" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options = @xlsx.ChartOptions::new(Col)
  // 451000 * 9525 exceeds Int32; the old Int-first calculation wrapped to a
  // small positive extent that later checks could not distinguish from valid.
  options.dimension = @xlsx.ChartDimension::with_values(451000, 1)
  let result : Result[Unit, Error] = Ok(
    workbook.add_chart_with_options("Sheet1", "A1", options),
  ) catch {
    error => Err(error)
  }
  inspect(
    result is Err(@xlsx.XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
}

///|
test "public image API rejects non-finite scaled extent before narrowing" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let result : Result[Unit, Error] = Ok(
    sheet.add_image(
      "A1",
      b"not-a-real-png",
      "png",
      "image/png",
      scale_x=1.0e308,
    ),
  ) catch {
    error => Err(error)
  }
  inspect(
    result is Err(@xlsx.XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
}
