///|
test "rc cell APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let set_cell_rc_result : Result[Unit, Error] = Ok(
    workbook.set_cell_rc("Sheet:1", 1, 1, "alpha"),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_cell_rc_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_cell_value_rc_result : Result[Unit, Error] = Ok(
    workbook.set_cell_value_rc("Sheet:1", 1, 1, String("beta")),
  ) catch {
    e => Err(e)
  }
  inspect(
    set_cell_value_rc_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_cell_rc_result : Result[String?, Error] = Ok(
    workbook.get_cell_rc("Sheet:1", 1, 1),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_cell_rc_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_cell_value_raw_rc_result : Result[CellValue?, Error] = Ok(
    workbook.get_cell_value_raw_rc("Sheet:1", 1, 1),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_cell_value_raw_rc_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_cell_value_rc_result : Result[String?, Error] = Ok(
    workbook.get_cell_value_rc("Sheet:1", 1, 1),
  ) catch {
    e => Err(e)
  }
  inspect(
    get_cell_value_rc_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
