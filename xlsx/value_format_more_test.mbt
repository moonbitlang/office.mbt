///|
test "value format builtin ids coverage" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_float("Sheet1", "A1", 1234.5)
  workbook.set_cell_style(
    "Sheet1",
    "A1",
    workbook.add_style(Style::builtin_number_format(0)),
  )
  workbook.set_cell_float("Sheet1", "A2", 1234.5)
  workbook.set_cell_style(
    "Sheet1",
    "A2",
    workbook.add_style(Style::builtin_number_format(3)),
  )
  workbook.set_cell_float("Sheet1", "A3", 1234.5)
  workbook.set_cell_style(
    "Sheet1",
    "A3",
    workbook.add_style(Style::builtin_number_format(4)),
  )
  workbook.set_cell_float("Sheet1", "A4", 0.125)
  workbook.set_cell_style(
    "Sheet1",
    "A4",
    workbook.add_style(Style::builtin_number_format(9)),
  )
  workbook.set_cell_float("Sheet1", "A5", 0.125)
  workbook.set_cell_style(
    "Sheet1",
    "A5",
    workbook.add_style(Style::builtin_number_format(10)),
  )
  workbook.set_cell_float("Sheet1", "A6", 2.0)
  workbook.set_cell_style(
    "Sheet1",
    "A6",
    workbook.add_style(Style::builtin_number_format(16)),
  )
  workbook.set_cell_float("Sheet1", "A7", 2.0)
  workbook.set_cell_style(
    "Sheet1",
    "A7",
    workbook.add_style(Style::builtin_number_format(17)),
  )
  workbook.set_cell_float("Sheet1", "A8", 0.75)
  workbook.set_cell_style(
    "Sheet1",
    "A8",
    workbook.add_style(Style::builtin_number_format(18)),
  )
  workbook.set_cell_float("Sheet1", "A9", 0.75)
  workbook.set_cell_style(
    "Sheet1",
    "A9",
    workbook.add_style(Style::builtin_number_format(19)),
  )
  workbook.set_cell_float("Sheet1", "A10", 0.75)
  workbook.set_cell_style(
    "Sheet1",
    "A10",
    workbook.add_style(Style::builtin_number_format(20)),
  )
  workbook.set_cell_float("Sheet1", "A11", 0.75)
  workbook.set_cell_style(
    "Sheet1",
    "A11",
    workbook.add_style(Style::builtin_number_format(22)),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "A1"),
    content=(
      #|Some("1234.5")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "A2"),
    content=(
      #|Some("1,235")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "A3"),
    content=(
      #|Some("1,234.50")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "A4"),
    content=(
      #|Some("13%")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "A5"),
    content=(
      #|Some("12.50%")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "A6"),
    content=(
      #|Some("2-Jan")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "A7"),
    content=(
      #|Some("Jan-00")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "A8"),
    content=(
      #|Some("6:00 PM")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "A9"),
    content=(
      #|Some("6:00:00 PM")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "A10"),
    content=(
      #|Some("18:00")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "A11"),
    content=(
      #|Some("12/31/99 18:00")
    ),
  )
}

///|
test "value format custom sections metadata and patterns" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_float("Sheet1", "B1", -1.0)
  workbook.set_cell_style(
    "Sheet1",
    "B1",
    workbook.add_style(Style::number_format("0")),
  )
  workbook.set_cell_float("Sheet1", "B2", -1.0)
  workbook.set_cell_style(
    "Sheet1",
    "B2",
    workbook.add_style(Style::number_format("0;0;0")),
  )
  workbook.set_cell_float("Sheet1", "B3", 0.0)
  workbook.set_cell_style(
    "Sheet1",
    "B3",
    workbook.add_style(Style::number_format("0;0;\"ZERO\"")),
  )
  workbook.set_cell_value("Sheet1", "B4", String("abc"))
  workbook.set_cell_style(
    "Sheet1",
    "B4",
    workbook.add_style(Style::number_format("\"PRE\"@\"SUF\"")),
  )
  workbook.set_cell_float("Sheet1", "B5", 1.25)
  workbook.set_cell_style(
    "Sheet1",
    "B5",
    workbook.add_style(Style::number_format("# ?/?")),
  )
  workbook.set_cell_float("Sheet1", "B6", 0.5)
  workbook.set_cell_style(
    "Sheet1",
    "B6",
    workbook.add_style(Style::number_format("0%")),
  )
  workbook.set_cell_float("Sheet1", "B7", 0.0)
  workbook.set_cell_style(
    "Sheet1",
    "B7",
    workbook.add_style(Style::number_format("0.00E+00")),
  )
  workbook.set_cell_float("Sheet1", "B8", 9.99)
  workbook.set_cell_style(
    "Sheet1",
    "B8",
    workbook.add_style(Style::number_format("0.0E+00")),
  )
  workbook.set_cell_float("Sheet1", "B9", 2.0)
  workbook.set_cell_style(
    "Sheet1",
    "B9",
    workbook.add_style(Style::number_format("[$$-0409]yyyy-mm-dd")),
  )
  workbook.set_cell_float("Sheet1", "B10", 2.0)
  workbook.set_cell_style(
    "Sheet1",
    "B10",
    workbook.add_style(Style::number_format("[$$-999]yyyy-mm-dd")),
  )
  workbook.set_cell_float("Sheet1", "B11", 1.0)
  let style_b11 = workbook.add_style(Style::number_format("0_);0*_)"))
  workbook.set_cell_style("Sheet1", "B11", style_b11)
  workbook.set_cell_float("Sheet1", "B12", 0.75)
  workbook.set_cell_style(
    "Sheet1",
    "B12",
    workbook.add_style(Style::number_format("[H]:mm:ss")),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B1"),
    content=(
      #|Some("-1")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B2"),
    content=(
      #|Some("1")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B3"),
    content=(
      #|Some("ZERO")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B4"),
    content=(
      #|Some("PREabcSUF")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B5"),
    content=(
      #|Some("1 1/4")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B6"),
    content=(
      #|Some("50%")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B7"),
    content=(
      #|Some("0.00E+00")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B8"),
    content=(
      #|Some("1.0E+01")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B9"),
    content=(
      #|Some("$1900-01-02")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B10"),
    content=(
      #|Some("2")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B11"),
    content=(
      #|Some("1")
    ),
  )
  inspect(
    workbook.get_cell_value("Sheet1", "B12"),
    content=(
      #|Some("18:00:00")
    ),
  )
}
