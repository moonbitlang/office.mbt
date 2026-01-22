///|
test "sheet rename and index lookup" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  workbook.set_sheet_name("Sheet1", "Main")
  inspect(workbook.sheet_name(0), content="Some(\"Main\")")
  inspect(workbook.sheet_index("Main"), content="0")
}

///|
test "sheet name validation" {
  let workbook = Workbook::new()
  let result : Result[Worksheet, Error] = try? workbook.add_sheet("Sheet:1")
  inspect(result is Err(XlsxError::InvalidSheetName(_)), content="true")
}

///|
test "sheet delete updates active index" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  workbook.set_active_sheet(1)
  workbook.delete_sheet("Sheet1")
  inspect(workbook.sheet_name(0), content="Some(\"Sheet2\")")
  inspect(workbook.active_sheet_index(), content="0")
}

///|
test "delete last sheet rejected" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Only"))
  let result : Result[Unit, Error] = try? workbook.delete_sheet("Only")
  inspect(result is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}

///|
test "sheet move reorders" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("A"))
  ignore(workbook.add_sheet("B"))
  ignore(workbook.add_sheet("C"))
  workbook.move_sheet("C", "A")
  inspect(workbook.sheet_name(0), content="Some(\"C\")")
  inspect(workbook.sheet_name(1), content="Some(\"A\")")
}

///|
test "sheet copy replaces target contents" {
  let workbook = Workbook::new()
  let sheet1 = workbook.add_sheet("Sheet1")
  sheet1.set_cell("A1", "one")
  let sheet2 = workbook.add_sheet("Sheet2")
  sheet2.set_cell("A1", "two")
  workbook.copy_sheet(0, 1)
  let copied = match workbook.sheet("Sheet2") {
    Some(value) => value
    None => fail("missing Sheet2")
  }
  inspect(copied.get_cell("A1"), content="Some(\"one\")")
  inspect(copied.name(), content="Sheet2")
}

///|
test "sheet visibility roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  workbook.set_sheet_visible("Sheet2", false)
  let bytes = write(workbook)
  let parsed = read(bytes)
  let sheet2 = match parsed.sheet("Sheet2") {
    Some(value) => value
    None => fail("missing Sheet2")
  }
  inspect(sheet2.state(), content="Hidden")
  inspect(parsed.active_sheet_index(), content="0")
}

///|
test "sheet list and map" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let chart_xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart">
    #|  <c:chart/>
    #|</c:chartSpace>
  ignore(workbook.add_chart_sheet("Chart1", chart_xml))
  ignore(workbook.add_sheet("Sheet2"))
  inspect(
    workbook.get_sheet_list(),
    content="[\"Sheet1\", \"Chart1\", \"Sheet2\"]",
  )
  let mapping = workbook.get_sheet_map()
  inspect(mapping[1], content="Sheet1")
  inspect(mapping[2], content="Chart1")
  inspect(mapping[3], content="Sheet2")
}

///|
test "cannot hide all sheets" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result : Result[Unit, Error] = try? workbook.set_sheet_visible(
    "Sheet1", false,
  )
  inspect(result is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}

///|
test "active sheet write and read" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  workbook.set_active_sheet(1)
  let bytes = write(workbook)
  let parsed = read(bytes)
  inspect(parsed.active_sheet_index(), content="1")
}
