///|
test "sheet view set and get" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options = SheetViewOptions::with_values(
    default_grid_color=false,
    right_to_left=true,
    show_formulas=false,
    show_grid_lines=false,
    show_row_col_headers=false,
    show_ruler=false,
    show_zeros=false,
    top_left_cell="B2",
    view="pageLayout",
    zoom_scale=120.0,
  )
  workbook.set_sheet_view("Sheet1", -1, options)
  let view = workbook.get_sheet_view("Sheet1", 0)
  match view.default_grid_color {
    Some(value) => inspect(value, content="false")
    None => fail("missing default_grid_color")
  }
  match view.right_to_left {
    Some(value) => inspect(value, content="true")
    None => fail("missing right_to_left")
  }
  match view.show_formulas {
    Some(value) => inspect(value, content="false")
    None => fail("missing show_formulas")
  }
  match view.show_grid_lines {
    Some(value) => inspect(value, content="false")
    None => fail("missing show_grid_lines")
  }
  match view.show_row_col_headers {
    Some(value) => inspect(value, content="false")
    None => fail("missing show_row_col_headers")
  }
  match view.show_ruler {
    Some(value) => inspect(value, content="false")
    None => fail("missing show_ruler")
  }
  match view.show_zeros {
    Some(value) => inspect(value, content="false")
    None => fail("missing show_zeros")
  }
  match view.top_left_cell {
    Some(value) => inspect(value, content="B2")
    None => fail("missing top_left_cell")
  }
  match view.view {
    Some(value) => inspect(value, content="pageLayout")
    None => fail("missing view")
  }
  match view.zoom_scale {
    Some(value) => inspect(value, content="120")
    None => fail("missing zoom_scale")
  }
  let bad_view : Result[Unit, Error] = try? workbook.set_sheet_view(
    "Sheet1", 3, options,
  )
  inspect(bad_view is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}

///|
test "panes set and get" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let panes = Panes::with_values(
    freeze=true,
    split=false,
    x_split=1,
    y_split=0,
    top_left_cell="B1",
    active_pane="topRight",
    selection=[
      Selection::with_values(sqref="K16", active_cell="K16", pane="topRight"),
    ],
  )
  workbook.set_panes("Sheet1", panes)
  let got = workbook.get_panes("Sheet1")
  inspect(got.freeze, content="true")
  inspect(got.x_split, content="1")
  inspect(got.y_split, content="0")
  inspect(got.top_left_cell, content="B1")
  inspect(got.active_pane, content="topRight")
  inspect(got.selection.length(), content="1")
  let sel = got.selection[0]
  inspect(sel.sqref, content="K16")
  inspect(sel.active_cell, content="K16")
  inspect(sel.pane, content="topRight")
}

///|
test "panes default when worksheet has no views" {
  let sheet = Worksheet::new("Sheet1")
  let panes = sheet.get_panes()
  inspect(panes.freeze, content="false")
  inspect(panes.split, content="false")
  inspect(panes.x_split, content="0")
  inspect(panes.y_split, content="0")
  inspect(panes.selection.length(), content="0")
}

///|
test "sheet dimension override write" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_sheet_dimension("Sheet1", "B2:D4")
  inspect(workbook.get_sheet_dimension("Sheet1"), content="B2:D4")
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("<dimension ref=\"B2:D4\"/>"), content="true")
}

///|
test "sheet dimension clear" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_sheet_dimension("Sheet1", "B2:D4")
  workbook.set_sheet_dimension("Sheet1", "")
  inspect(workbook.get_sheet_dimension("Sheet1"), content="")
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("<dimension"), content="false")
}

///|
test "sheet view and panes roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let view_opts = SheetViewOptions::with_values(
    default_grid_color=false,
    top_left_cell="C3",
    view="pageBreakPreview",
  )
  workbook.set_sheet_view("Sheet1", 0, view_opts)
  let panes = Panes::with_values(
    freeze=true,
    split=false,
    x_split=0,
    y_split=2,
    top_left_cell="A3",
    active_pane="bottomLeft",
    selection=[
      Selection::with_values(sqref="A3", active_cell="A3", pane="bottomLeft"),
    ],
  )
  workbook.set_panes("Sheet1", panes)
  let parsed = read(write(workbook))
  let view = parsed.get_sheet_view("Sheet1", 0)
  match view.default_grid_color {
    Some(value) => inspect(value, content="false")
    None => fail("missing default_grid_color")
  }
  match view.top_left_cell {
    Some(value) => inspect(value, content="C3")
    None => fail("missing top_left_cell")
  }
  match view.view {
    Some(value) => inspect(value, content="pageBreakPreview")
    None => fail("missing view")
  }
  let got = parsed.get_panes("Sheet1")
  inspect(got.freeze, content="true")
  inspect(got.y_split, content="2")
  inspect(got.top_left_cell, content="A3")
  inspect(got.selection.length(), content="1")
}
