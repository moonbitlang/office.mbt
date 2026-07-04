///|
test "sheet rename and index lookup" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  workbook.set_sheet_name("Sheet1", "Main")
  debug_inspect(workbook.sheet_name(0), content="Some(\"Main\")")
  inspect(workbook.sheet_index("Main"), content="0")
}

///|
test "sheet name validation" {
  let workbook = Workbook::new()
  let result : Result[Worksheet, Error] = Ok(workbook.add_sheet("Sheet:1")) catch {
    e => Err(e)
  }
  inspect(result is Err(XlsxError::InvalidSheetName(_)), content="true")
}

///|
test "sheet name validation guard branches" {
  let workbook = Workbook::new()
  let blank : Result[Worksheet, Error] = Ok(workbook.add_sheet("")) catch {
    e => Err(e)
  }
  inspect(blank is Err(XlsxError::InvalidSheetName(_)), content="true")

  let too_long : Result[Worksheet, Error] = Ok(
    workbook.add_sheet("a".repeat(32)),
  ) catch {
    e => Err(e)
  }
  inspect(too_long is Err(XlsxError::InvalidSheetName(_)), content="true")

  let quoted : Result[Worksheet, Error] = Ok(workbook.add_sheet("'Quoted")) catch {
    e => Err(e)
  }
  inspect(quoted is Err(XlsxError::InvalidSheetName(_)), content="true")
}

///|
test "sheet delete updates active index" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  workbook.set_active_sheet(1)
  workbook.delete_sheet("Sheet1")
  debug_inspect(workbook.sheet_name(0), content="Some(\"Sheet2\")")
  inspect(workbook.active_sheet_index(), content="0")
}

///|
test "delete last sheet is no-op" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Only"))
  let result : Result[Unit, Error] = Ok(workbook.delete_sheet("Only")) catch {
    e => Err(e)
  }
  inspect(result is Ok(_), content="true")
  debug_inspect(workbook.sheet_name(0), content="Some(\"Only\")")
}

///|
test "sheet move reorders" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("A"))
  ignore(workbook.add_sheet("B"))
  ignore(workbook.add_sheet("C"))
  workbook.move_sheet("C", "A")
  debug_inspect(workbook.sheet_name(0), content="Some(\"C\")")
  debug_inspect(workbook.sheet_name(1), content="Some(\"A\")")
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
  debug_inspect(copied.get_cell("A1"), content="Some(\"one\")")
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
  debug_inspect(sheet2.state(), content="Hidden")
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
  debug_inspect(
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
  let result : Result[Unit, Error] = Ok(
    workbook.set_sheet_visible("Sheet1", false),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}

///|
test "chart sheet visibility via workbook API" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_chart_sheet("Chart1", "<chart/>"))
  workbook.set_sheet_visible("Chart1", false, very_hidden=true)
  inspect(workbook.sheet_visible("Chart1"), content="false")
  debug_inspect(workbook.chart_sheets()[0].state(), content="VeryHidden")
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

///|
test "group and ungroup sheets" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  ignore(workbook.add_sheet("Sheet3"))
  let bad_group : Result[Unit, Error] = Ok(
    workbook.group_sheets(["Sheet2", "Sheet3"]),
  ) catch {
    e => Err(e)
  }
  inspect(bad_group is Err(XlsxError::InvalidSheetOperation(_)), content="true")
  workbook.group_sheets(["Sheet1", "Sheet2"])
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let sheet1_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  let sheet2_xml = match archive.get("xl/worksheets/sheet2.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet2.xml utf8 decode failed")
      }
    None => fail("missing sheet2.xml")
  }
  let sheet3_xml = match archive.get("xl/worksheets/sheet3.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet3.xml utf8 decode failed")
      }
    None => fail("missing sheet3.xml")
  }
  inspect(sheet1_xml.contains("tabSelected=\"1\""), content="true")
  inspect(sheet2_xml.contains("tabSelected=\"1\""), content="true")
  inspect(sheet3_xml.contains("tabSelected=\"1\""), content="false")
  workbook.ungroup_sheets()
  let bytes2 = write(workbook)
  let archive2 = @zip.read(bytes2) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let sheet2_xml2 = match archive2.get("xl/worksheets/sheet2.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet2.xml utf8 decode failed")
      }
    None => fail("missing sheet2.xml")
  }
  inspect(sheet2_xml2.contains("tabSelected=\"1\""), content="false")
}
