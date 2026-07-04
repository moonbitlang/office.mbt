///|
test "column name conversions" {
  inspect(column_name_to_number("A"), content="1")
  inspect(column_name_to_number("Z"), content="26")
  inspect(column_name_to_number("AA"), content="27")
  inspect(column_number_to_name(1), content="A")
  inspect(column_number_to_name(27), content="AA")
  let bad : Result[Int, Error] = Ok(column_name_to_number("A1")) catch {
    e => Err(e)
  }
  guard bad is Err(_) else { fail("expected invalid column name") }
  let bad_number : Result[String, Error] = Ok(column_number_to_name(0)) catch {
    e => Err(e)
  }
  guard bad_number is Err(_) else { fail("expected invalid column number") }
}

///|
test "column range setters" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let style_id = workbook.add_style(Style::new())
  workbook.set_col_width_range("Sheet1", "B:D", 11.0)
  workbook.set_col_visible_range("Sheet1", "B:D", false)
  workbook.set_col_outline_level_range("Sheet1", "B:D", 2)
  workbook.set_col_style_range("Sheet1", "B:D", style_id)
  let bytes = write(workbook)
  let parsed = read(bytes)
  debug_inspect(
    [
      parsed.get_col_width("Sheet1", 2),
      parsed.get_col_width("Sheet1", 3),
      parsed.get_col_width("Sheet1", 4),
    ],
    content="[Some(11), Some(11), Some(11)]",
  )
  debug_inspect(
    [
      parsed.col_visible("Sheet1", 2),
      parsed.col_visible("Sheet1", 3),
      parsed.col_visible("Sheet1", 4),
    ],
    content="[false, false, false]",
  )
  debug_inspect(
    [
      parsed.col_outline_level("Sheet1", 2),
      parsed.col_outline_level("Sheet1", 3),
      parsed.col_outline_level("Sheet1", 4),
    ],
    content="[2, 2, 2]",
  )
  debug_inspect(
    [
      parsed.get_col_style("Sheet1", 2),
      parsed.get_col_style("Sheet1", 3),
      parsed.get_col_style("Sheet1", 4),
    ],
    content="[Some(1), Some(1), Some(1)]",
  )
}

///|
test "column range parser edge branches" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_col_width_range("Sheet1", "C", 9.0)
  debug_inspect(workbook.get_col_width("Sheet1", 3), content="Some(9)")

  let too_many_parts : Result[Unit, Error] = Ok(
    workbook.set_col_width_range("Sheet1", "A:B:C", 10.0),
  ) catch {
    e => Err(e)
  }
  inspect(too_many_parts is Err(XlsxError::InvalidCellRef(_)), content="true")

  let descending : Result[Unit, Error] = Ok(
    workbook.set_col_width_range("Sheet1", "D:B", 10.0),
  ) catch {
    e => Err(e)
  }
  inspect(descending is Err(XlsxError::InvalidCellRef(_)), content="true")
}
