///|
test "workbook_compat APIs validate sheet name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let set_row_result : Result[Unit, Error] = Ok(
    workbook.set_sheet_row("Sheet:1", "A1", ["a", "b"][:]),
  ) catch {
    e => Err(e)
  }
  inspect(set_row_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let set_col_result : Result[Unit, Error] = Ok(
    workbook.set_sheet_col("Sheet:1", "A1", ["a", "b"][:]),
  ) catch {
    e => Err(e)
  }
  inspect(set_col_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let width_result : Result[Unit, Error] = Ok(
    workbook.set_col_width_range("Sheet:1", "A:C", 10.0),
  ) catch {
    e => Err(e)
  }
  inspect(width_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let visible_result : Result[Unit, Error] = Ok(
    workbook.set_col_visible_range("Sheet:1", "A:C", false),
  ) catch {
    e => Err(e)
  }
  inspect(visible_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let outline_result : Result[Unit, Error] = Ok(
    workbook.set_col_outline_level_range("Sheet:1", "A:C", 1),
  ) catch {
    e => Err(e)
  }
  inspect(outline_result is Err(XlsxError::InvalidSheetName(_)), content="true")
  let style_result : Result[Unit, Error] = Ok(
    workbook.set_col_style_range("Sheet:1", "A:C", 0),
  ) catch {
    e => Err(e)
  }
  inspect(style_result is Err(XlsxError::InvalidSheetName(_)), content="true")

  let missing_row : Result[Unit, Error] = Ok(
    workbook.set_sheet_row("Missing", "A1", ["a", "b"][:]),
  ) catch {
    e => Err(e)
  }
  inspect(missing_row is Err(XlsxError::SheetNotFound(_)), content="true")
  let missing_col : Result[Unit, Error] = Ok(
    workbook.set_sheet_col("Missing", "A1", ["a", "b"][:]),
  ) catch {
    e => Err(e)
  }
  inspect(missing_col is Err(XlsxError::SheetNotFound(_)), content="true")
  let missing_width : Result[Unit, Error] = Ok(
    workbook.set_col_width_range("Missing", "A:C", 10.0),
  ) catch {
    e => Err(e)
  }
  inspect(missing_width is Err(XlsxError::SheetNotFound(_)), content="true")
  let missing_visible : Result[Unit, Error] = Ok(
    workbook.set_col_visible_range("Missing", "A:C", false),
  ) catch {
    e => Err(e)
  }
  inspect(missing_visible is Err(XlsxError::SheetNotFound(_)), content="true")
  let missing_outline : Result[Unit, Error] = Ok(
    workbook.set_col_outline_level_range("Missing", "A:C", 1),
  ) catch {
    e => Err(e)
  }
  inspect(missing_outline is Err(XlsxError::SheetNotFound(_)), content="true")
  let missing_style : Result[Unit, Error] = Ok(
    workbook.set_col_style_range("Missing", "A:C", 0),
  ) catch {
    e => Err(e)
  }
  inspect(missing_style is Err(XlsxError::SheetNotFound(_)), content="true")
}
