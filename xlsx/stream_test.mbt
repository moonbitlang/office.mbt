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
  debug_inspect(sheet.merged_cells().to_owned(), content="[\"A1:B1\"]")
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

///|
test "stream writer typed time and duration cells" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let stream = workbook.new_stream_writer("Sheet1")
  let time_cell = stream.new_time_cell(@time.date_time(2024, 7, 3, hour=9))
  let styled_time_cell = stream.new_time_cell(
    @time.date_time(2024, 7, 4),
    style_id=0,
  )
  let duration_cell = stream.new_duration_cell(
    @time.Duration::of(hours=1, minutes=30),
  )
  let pre_epoch_cell = stream.new_time_cell(@time.date_time(1899, 6, 1))
  stream.set_row_cells("A1", [
    time_cell, styled_time_cell, duration_cell, pre_epoch_cell,
  ])
  stream.flush()
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }
  // 2024-07-03 09:00 -> serial 45476.375
  inspect(sheet_xml.contains("45476.375"), content="true")
  // 1h30m -> 0.0625
  inspect(sheet_xml.contains("0.0625"), content="true")
  let styles_xml = match archive.get("xl/styles.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing styles.xml")
  }
  // unstyled time cells share one registered numFmt-22 style
  inspect(styles_xml.contains("numFmtId=\"22\""), content="true")
  // pre-epoch fallback is stored as text
  let parsed = @xlsx.read(bytes)
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  debug_inspect(
    sheet.get_cell("D1"),
    content=(
      #|Some("1899-06-01T00:00:00Z")
    ),
  )
}

///|
test "stream writer time cells honor workbook date-1904" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_workbook_props(
    Some(@xlsx.WorkbookPropsOptions::with_values(date_1904=true)),
  )
  let stream = workbook.new_stream_writer("Sheet1")
  stream.set_row_cells("A1", [stream.new_time_cell(@time.date_time(1904, 1, 2))])
  stream.flush()
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  debug_inspect(
    sheet.get_cell("A1"),
    content=(
      #|Some("1")
    ),
  )
}

///|
test "stream time cells respect row and column style inheritance" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bold_idx = workbook.new_style(
    @xlsx.Style::font(@xlsx.Font::with_values(bold=true)),
  )
  let stream = workbook.new_stream_writer("Sheet1")
  // column B carries a style: the time cell there keeps style 0 and no
  // default time format is registered for it
  stream.set_col_style(2, 2, bold_idx)
  stream.set_row_cells("A1", [
    stream.new_time_cell(@time.date_time(2024, 7, 3, hour=9)),
    stream.new_time_cell(@time.date_time(2024, 7, 3, hour=9)),
  ])
  // a row with an explicit style suppresses the default too
  stream.set_row_cells(
    "A2",
    [stream.new_time_cell(@time.date_time(2024, 7, 4))],
    row_opts=@xlsx.RowOpts::with_values(style_id=bold_idx),
  )
  stream.flush()
  let style_of = (reference : String) => {
    match workbook.get_cell_style("Sheet1", reference) {
      Some(value) => value
      None => 0
    }
  }
  // A1 got the registered numFmt-22 style; B1 (styled column) and A2
  // (styled row) stayed at 0 to inherit
  let time_style = style_of("A1")
  inspect(time_style > 0, content="true")
  inspect(style_of("B1"), content="0")
  inspect(style_of("A2"), content="0")
  // and the workbook-level style it registered is numFmt 22
  inspect(
    workbook.get_style(time_style).number_format
    is Some(@xlsx.NumberFormat::Builtin(22)),
    content="true",
  )
}

///|
test "stream time cells read date-1904 live" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let stream = workbook.new_stream_writer("Sheet1")
  // switching workbook props after stream creation must still be honored
  workbook.set_workbook_props(
    Some(@xlsx.WorkbookPropsOptions::with_values(date_1904=true)),
  )
  stream.set_row_cells("A1", [stream.new_time_cell(@time.date_time(1904, 1, 2))])
  stream.flush()
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  debug_inspect(
    sheet.get_cell("A1"),
    content=(
      #|Some("1")
    ),
  )
}

///|
test "stream row rejects style ids minted by lazy time-style registration" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let stream = workbook.new_stream_writer("Sheet1")
  // the id the lazy numFmt-22 registration would mint
  let future_id = 1
  let result : Result[Unit, Error] = Ok(
    stream.set_row_cells("A1", [
      stream.new_time_cell(@time.date_time(2024, 7, 3, hour=9)),
      @xlsx.StreamCell::new("x", style_id=future_id),
    ]),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "stream blank cells advance the column without writing" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let stream = workbook.new_stream_writer("Sheet1")
  stream.set_row_cells("A1", [
    @xlsx.StreamCell::new("left"),
    @xlsx.StreamCell::new_blank(),
    @xlsx.StreamCell::new("right"),
  ])
  stream.flush()
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }
  // no cell element is produced for the blank slot
  inspect(sheet_xml.contains("r=\"B1\""), content="false")
  let parsed = @xlsx.read(bytes)
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  debug_inspect(
    sheet.get_cell("A1"),
    content=(
      #|Some("left")
    ),
  )
  debug_inspect(sheet.get_cell("B1"), content="None")
  debug_inspect(
    sheet.get_cell("C1"),
    content=(
      #|Some("right")
    ),
  )
}
