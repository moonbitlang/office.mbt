///|
test "stream cell constructors cover rich text and values" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let writer = workbook.new_stream_writer("Sheet1")
  let cells : Array[StreamCell] = []
  cells.push(StreamCell::new_value(Numeric(3.0), formula="SUM(1,2)"))
  let runs : Array[RichTextRun] = [{ text: "hi", font: None }]
  cells.push(StreamCell::new_rich_text(runs))
  writer.set_row_cells("A1", cells)
  writer.flush()
  let parsed = read(write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(
    sheet.get_cell_formula("A1"),
    content=(
      #|Some("SUM(1,2)")
    ),
  )
  inspect(
    sheet.get_cell_value_raw("A1"),
    content=(
      #|Some(Numeric(3))
    ),
  )
  inspect(
    sheet.get_cell_rich_text("B1"),
    content=(
      #|Some([{text: "hi", font: None}])
    ),
  )
}

///|
test "stream cell rich text too long" {
  let sb = StringBuilder::new()
  for _ in 0..<32768 {
    sb.write_char('a')
  }
  let too_long = sb.to_string()
  let runs : Array[RichTextRun] = [{ text: too_long, font: None }]
  let result : Result[StreamCell, Error] = try? StreamCell::new_rich_text(runs)
  inspect(
    result is Err(_),
    content=(
      #|true
    ),
  )
}

///|
test "stream writer validation branches" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let writer = workbook.new_stream_writer("Sheet1")
  writer.set_col_width(2, 1, 10.0)
  let bad_width = try writer.set_col_width(1, 1, -1.0) catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    bad_width,
    content=(
      #|Err(InvalidSheetOperation(msg="column width is negative"))
    ),
  )
  let bad_col = try writer.set_col_width(0, 0, 10.0) catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    bad_col,
    content=(
      #|Err(InvalidCellRef(value="0:0"))
    ),
  )
  let bad_outline = try writer.set_col_outline_level(1, 8) catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    bad_outline,
    content=(
      #|Err(InvalidSheetOperation(msg="column outline level out of range"))
    ),
  )
  let panes = Panes::with_values(selection=[
    Selection::with_values(sqref="A1", active_cell="A1", pane="topLeft"),
  ])
  writer.set_panes(panes)
  writer.set_row("A1", ["B"])
  writer.flush()
  let parsed = read(write(workbook))
  inspect(
    parsed.get_col_width("Sheet1", 1),
    content=(
      #|Some(10)
    ),
  )
  inspect(
    parsed.get_col_width("Sheet1", 2),
    content=(
      #|Some(10)
    ),
  )
  let got = parsed.get_panes("Sheet1")
  inspect(
    got.freeze,
    content=(
      #|false
    ),
  )
  inspect(
    got.selection.length(),
    content=(
      #|1
    ),
  )
}

///|
test "stream writer row opts validation" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let writer = workbook.new_stream_writer("Sheet1")
  let bad_row_opts = RowOpts::with_values(height=-1.0)
  let row_opts_result = try
    writer.set_row("A1", ["A"], row_opts=bad_row_opts)
  catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    row_opts_result,
    content=(
      #|Err(InvalidSheetOperation(msg="row height is negative"))
    ),
  )
}
