///|
test "stream writer basic" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let writer = workbook.new_stream_writer("Sheet1")
  writer.set_row("A1", ["A", "B"])
  writer.set_row_cells("A2", [
    StreamCell::new("3", formula="SUM(A1,B1)"),
    StreamCell::new("4"),
  ])
  writer.flush()
  let parsed = read(write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  debug_inspect(sheet.get_row(1), content="[\"A\", \"B\"]")
  debug_inspect(sheet.get_cell_formula("A2"), content="Some(\"SUM(A1,B1)\")")
  debug_inspect(sheet.get_cell("A2"), content="Some(\"3\")")
}

///|
test "stream writer sheet id follows workbook order" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_chart_sheet("Chart1", "<chart/>"))
  ignore(workbook.add_sheet("Sheet2"))
  let writer = workbook.new_stream_writer("Sheet2")
  inspect(writer.sheet_id(), content="3")
  writer.flush()
}

///|
test "stream writer row order" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let writer = workbook.new_stream_writer("Sheet1")
  writer.set_row("A2", ["A"])
  let result = try writer.set_row("A1", ["B"]) catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  debug_inspect(result, content="Err(StreamRowOrder(last=2, next=1))")
}

///|
test "stream writer closed" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let writer = workbook.new_stream_writer("Sheet1")
  writer.set_row("A1", ["A"])
  writer.flush()
  let result = try writer.set_row("A2", ["B"]) catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  debug_inspect(result, content="Err(StreamWriterClosed)")
}

///|
test "stream writer column helpers and panes" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let writer = workbook.new_stream_writer("Sheet1")
  let style_id = workbook.new_style(Style::number_format("0%"))
  writer.set_col_width(2, 3, 20.0)
  writer.set_col_visible(2, 2, false)
  writer.set_col_style(2, 3, style_id)
  writer.set_col_outline_level(3, 2)
  let panes = Panes::with_values(
    freeze=true,
    x_split=1,
    y_split=1,
    top_left_cell="B2",
    active_pane="bottomRight",
  )
  writer.set_panes(panes)
  writer.set_row("A1", ["A"])
  writer.flush()
  let parsed = read(write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  debug_inspect(sheet.get_col_width(2), content="Some(20)")
  inspect(sheet.col_visible(2), content="false")
  debug_inspect(sheet.get_col_style(2), content="Some(1)")
  inspect(sheet.col_outline_level(3), content="2")
  let updated_panes = sheet.get_panes()
  inspect(updated_panes.freeze, content="true")
  inspect(updated_panes.x_split, content="1")
  inspect(updated_panes.y_split, content="1")
  inspect(updated_panes.top_left_cell, content="B2")
  inspect(updated_panes.active_pane, content="bottomRight")
}

///|
test "stream writer table merge and row opts" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let writer = workbook.new_stream_writer("Sheet1")
  let style_id = workbook.new_style(Style::number_format("0.0"))
  let opts = RowOpts::with_values(height=22.0, hidden=true, style_id~)
  writer.set_row("A1", ["A", "B"], row_opts=opts)
  writer.set_row("A2", ["1", "2"])
  ignore(writer.add_table("A1:B2", "Table1", ["A", "B"]))
  writer.merge_cell("A1", "B1")
  writer.flush()
  let parsed = read(write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  debug_inspect(sheet.merged_cells().to_array(), content="[\"A1:B1\"]")
  let table = match sheet.tables().get(0) {
    Some(value) => value
    None => fail("missing table")
  }
  inspect(table.name, content="Table1")
  debug_inspect(parsed.get_row_height("Sheet1", 1), content="Some(22)")
  inspect(parsed.row_visible("Sheet1", 1), content="false")
  debug_inspect(parsed.get_row_style("Sheet1", 1), content="Some(1)")
}

///|
test "stream writer column helpers require pre-row" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let writer = workbook.new_stream_writer("Sheet1")
  writer.set_row("A1", ["A"])
  let col_result = try writer.set_col_width(1, 1, 10.0) catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  debug_inspect(
    col_result,
    content="Err(StreamModeConflict(msg=\"set_col_width must be called before set_row\"))",
  )
  let panes = Panes::new()
  let pane_result = try writer.set_panes(panes) catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  debug_inspect(
    pane_result,
    content="Err(StreamModeConflict(msg=\"set_panes must be called before set_row\"))",
  )
}

///|
test "stream writer mode conflict" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let writer = workbook.new_stream_writer("Sheet1")
  let result = try sheet.set_cell("A1", "X") catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  debug_inspect(
    result,
    content="Err(StreamModeConflict(msg=\"worksheet is in stream writer mode\"))",
  )
  writer.flush()
}

///|
test "row stream iterates" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_row(1, ["A", "B"])
  sheet.set_row(3, ["C"])
  let stream = sheet.row_stream()
  debug_inspect(stream.next(), content="Some([\"A\", \"B\"])")
  debug_inspect(stream.next(), content="Some([\"C\"])")
  debug_inspect(stream.next(), content="None")
}

///|
test "workbook row stream" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_row(1, ["A"])
  let stream = workbook.row_stream("Sheet1")
  debug_inspect(stream.next(), content="Some([\"A\"])")
  debug_inspect(stream.next(), content="None")
}
