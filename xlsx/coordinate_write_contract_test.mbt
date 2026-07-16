///|
test "typed coordinate writers reject references their reader would reject" {
  let validation = @xlsx.DataValidation::new(true)
  let invalid_validation : Result[Unit, Error] = Ok(
    validation.set_sqref("XFE1"),
  ) catch {
    error => Err(error)
  }
  inspect(
    invalid_validation is Err(@xlsx.XlsxError::InvalidCellRef(_)),
    content="true",
  )

  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let invalid_view : Result[Unit, Error] = Ok(
    workbook.set_sheet_view(
      "Sheet1",
      0,
      @xlsx.SheetViewOptions::with_values(top_left_cell="A1048577"),
    ),
  ) catch {
    error => Err(error)
  }
  inspect(
    invalid_view is Err(@xlsx.XlsxError::InvalidCellRef(_)),
    content="true",
  )

  let invalid_pane : Result[Unit, Error] = Ok(
    workbook.set_panes(
      "Sheet1",
      @xlsx.Panes::with_values(freeze=true, top_left_cell="XFE1", selection=[
        @xlsx.Selection::with_values(sqref="A1", active_cell="A1"),
      ]),
    ),
  ) catch {
    error => Err(error)
  }
  inspect(
    invalid_pane is Err(@xlsx.XlsxError::InvalidCellRef(_)),
    content="true",
  )

  let invalid_selection : Result[Unit, Error] = Ok(
    workbook.set_panes(
      "Sheet1",
      @xlsx.Panes::with_values(selection=[
        @xlsx.Selection::with_values(sqref="A1 XFE1", active_cell="A1048577"),
      ]),
    ),
  ) catch {
    error => Err(error)
  }
  inspect(
    invalid_selection is Err(@xlsx.XlsxError::InvalidCellRef(_)),
    content="true",
  )
}

///|
test "typed coordinate writers canonicalize and self-roundtrip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let validation = @xlsx.DataValidation::new(true)
  validation.set_sqref("$B$2:$A$1")
  validation.set_drop_list(["valid"])
  workbook.add_data_validation("Sheet1", validation)
  workbook.set_sheet_view(
    "Sheet1",
    0,
    @xlsx.SheetViewOptions::with_values(top_left_cell="$b$2"),
  )
  workbook.set_panes(
    "Sheet1",
    @xlsx.Panes::with_values(freeze=true, y_split=1, top_left_cell="$c$3", selection=[
      @xlsx.Selection::with_values(sqref="$D$4 $c$3", active_cell="$c$3"),
    ]),
  )

  let parsed = @xlsx.read(@xlsx.write(workbook))
  inspect(parsed.get_data_validations("Sheet1")[0].sqref, content="A1:B2")
  debug_inspect(
    parsed.get_sheet_view("Sheet1", 0).top_left_cell,
    content="Some(\"B2\")",
  )
  let panes = parsed.get_panes("Sheet1")
  inspect(panes.top_left_cell, content="C3")
  inspect(panes.selection[0].active_cell, content="C3")
  inspect(panes.selection[0].sqref, content="D4 C3")
}

///|
test "stream pane writer shares coordinate validation and normalization" {
  let invalid_workbook = @xlsx.Workbook::new()
  ignore(invalid_workbook.add_sheet("Sheet1"))
  let invalid_writer = invalid_workbook.new_stream_writer("Sheet1")
  let invalid : Result[Unit, Error] = Ok(
    invalid_writer.set_panes(
      @xlsx.Panes::with_values(selection=[
        @xlsx.Selection::with_values(sqref="A1 XFE1", active_cell="A1"),
      ]),
    ),
  ) catch {
    error => Err(error)
  }
  inspect(invalid is Err(@xlsx.XlsxError::InvalidCellRef(_)), content="true")

  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let writer = workbook.new_stream_writer("Sheet1")
  writer.set_panes(
    @xlsx.Panes::with_values(freeze=true, y_split=1, top_left_cell="$b$2", selection=[
      @xlsx.Selection::with_values(sqref="$b$2", active_cell="$b$2"),
    ]),
  )
  writer.flush()
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let panes = parsed.get_panes("Sheet1")
  inspect(panes.top_left_cell, content="B2")
  inspect(panes.selection[0].sqref, content="B2")
  inspect(panes.selection[0].active_cell, content="B2")
}
