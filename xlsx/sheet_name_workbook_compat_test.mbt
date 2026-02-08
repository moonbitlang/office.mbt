///|
test "workbook_compat APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let set_row_result : Result[Unit, Error] = try? workbook.set_sheet_row(
    "Sheet:1",
    "A1",
    ["a", "b"][:],
  )
  inspect(set_row_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let set_col_result : Result[Unit, Error] = try? workbook.set_sheet_col(
    "Sheet:1",
    "A1",
    ["a", "b"][:],
  )
  inspect(set_col_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let width_result : Result[Unit, Error] = try? workbook.set_col_width_range(
    "Sheet:1", "A:C", 10.0,
  )
  inspect(width_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let visible_result : Result[Unit, Error] = try? workbook.set_col_visible_range(
    "Sheet:1", "A:C", false,
  )
  inspect(visible_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let outline_result : Result[Unit, Error] = try? workbook.set_col_outline_level_range(
    "Sheet:1", "A:C", 1,
  )
  inspect(outline_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let style_result : Result[Unit, Error] = try? workbook.set_col_style_range(
    "Sheet:1", "A:C", 0,
  )
  inspect(style_result is Err(XlsxError::InvalidSheetName(_)), content="true")

  let missing_row : Result[Unit, Error] = try? workbook.set_sheet_row(
    "Missing",
    "A1",
    ["a", "b"][:],
  )
  inspect(missing_row is Err(XlsxError::SheetNotFound(_)), content="true")
  let missing_col : Result[Unit, Error] = try? workbook.set_sheet_col(
    "Missing",
    "A1",
    ["a", "b"][:],
  )
  inspect(missing_col is Err(XlsxError::SheetNotFound(_)), content="true")
  let missing_width : Result[Unit, Error] = try? workbook.set_col_width_range(
    "Missing", "A:C", 10.0,
  )
  inspect(missing_width is Err(XlsxError::SheetNotFound(_)), content="true")
  let missing_visible : Result[Unit, Error] = try? workbook.set_col_visible_range(
    "Missing", "A:C", false,
  )
  inspect(missing_visible is Err(XlsxError::SheetNotFound(_)), content="true")
  let missing_outline : Result[Unit, Error] = try? workbook.set_col_outline_level_range(
    "Missing", "A:C", 1,
  )
  inspect(missing_outline is Err(XlsxError::SheetNotFound(_)), content="true")
  let missing_style : Result[Unit, Error] = try? workbook.set_col_style_range(
    "Missing", "A:C", 0,
  )
  inspect(missing_style is Err(XlsxError::SheetNotFound(_)), content="true")
}
