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
  inspect(sheet.get_row(1), content="[\"A\", \"B\"]")
  inspect(sheet.get_cell_formula("A2"), content="Some(\"SUM(A1,B1)\")")
  inspect(sheet.get_cell("A2"), content="Some(\"3\")")
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
  inspect(result, content="Err(StreamRowOrder(last=2, next=1))")
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
  inspect(
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
  inspect(stream.next(), content="Some([\"A\", \"B\"])")
  inspect(stream.next(), content="Some([\"C\"])")
  inspect(stream.next(), content="None")
}
