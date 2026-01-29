///|
test "row/col + rc ops validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let set_style_rc_result : Result[Unit, Error] = try? workbook.set_cell_style_rc(
    "Sheet:1", 1, 1, 0,
  )
  inspect(
    set_style_rc_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_style_rc_result : Result[Int?, Error] = try? workbook.get_cell_style_rc(
    "Sheet:1", 1, 1,
  )
  inspect(
    get_style_rc_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_formula_rc_result : Result[Unit, Error] = try? workbook.set_cell_formula_rc(
    "Sheet:1", 1, 1, "1+1",
  )
  inspect(
    set_formula_rc_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_row_result : Result[Unit, Error] = try? workbook.set_row(
    "Sheet:1",
    1,
    ["A"][:],
  )
  inspect(set_row_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let get_row_result : Result[Array[String], Error] = try? workbook.get_row(
    "Sheet:1", 1,
  )
  inspect(get_row_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let set_col_result : Result[Unit, Error] = try? workbook.set_col(
    "Sheet:1",
    1,
    ["A"][:],
  )
  inspect(set_col_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let get_col_result : Result[Array[String], Error] = try? workbook.get_col(
    "Sheet:1", 1,
  )
  inspect(get_col_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let set_row_height_result : Result[Unit, Error] = try? workbook.set_row_height(
    "Sheet:1", 1, 10.0,
  )
  inspect(
    set_row_height_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_row_height_result : Result[Double?, Error] = try? workbook.get_row_height(
    "Sheet:1", 1,
  )
  inspect(
    get_row_height_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let set_col_width_result : Result[Unit, Error] = try? workbook.set_col_width(
    "Sheet:1", 1, 8.0,
  )
  inspect(
    set_col_width_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let get_col_width_result : Result[Double?, Error] = try? workbook.get_col_width(
    "Sheet:1", 1,
  )
  inspect(
    get_col_width_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let insert_rows_result : Result[Unit, Error] = try? workbook.insert_rows(
    "Sheet:1", 1, 1,
  )
  inspect(
    insert_rows_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let remove_rows_result : Result[Unit, Error] = try? workbook.remove_rows(
    "Sheet:1", 1, 1,
  )
  inspect(
    remove_rows_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let insert_cols_result : Result[Unit, Error] = try? workbook.insert_cols(
    "Sheet:1", 1, 1,
  )
  inspect(
    insert_cols_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let remove_cols_result : Result[Unit, Error] = try? workbook.remove_cols(
    "Sheet:1", 1, 1,
  )
  inspect(
    remove_cols_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
  let duplicate_row_to_result : Result[Unit, Error] = try? workbook.duplicate_row_to(
    "Sheet:1", 1, 2,
  )
  inspect(
    duplicate_row_to_result is Err(XlsxError::InvalidSheetName(_)),
    content="true",
  )
}
