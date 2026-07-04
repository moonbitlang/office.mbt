///|
test "sparkline APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let add_sparkline_result : Result[Unit, Error] = Ok(
    workbook.add_sparkline("Sheet:1", SparklineOptions::new(["B2"], ["A1:A3"])),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_sparkline_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let add_group_result : Result[Unit, Error] = Ok(
    workbook.add_sparkline_group("Sheet:1", ["B2"][:], ["A1:A3"][:]),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_group_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let add_opts_result : Result[Unit, Error] = Ok(
    workbook.add_sparkline_options(
      "Sheet:1",
      SparklineOptions::new(["C2"], ["A1:A3"]),
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_opts_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let add_basic_result : Result[Unit, Error] = Ok(
    workbook.add_sparkline_basic("Sheet:1", "B2", "A1:A3"),
  ) catch {
    e => Err(e)
  }
  inspect(
    add_basic_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
