///|
/// Asserts a freshly built workbook is a structurally valid OOXML
/// package, failing with the problem list otherwise.
fn assert_valid_package(name : String, workbook : @xlsx.Workbook) -> Unit raise {
  let problems = @xlsx.validate_ooxml_package(@xlsx.write(workbook)[:])
  if problems.length() != 0 {
    fail("\{name} is not a valid package: \{problems}")
  }
}

///|
test "package validity: core cell value types" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", String("text"))
  sheet.set_cell_value("A2", Numeric(3.14))
  sheet.set_cell_value("A3", Bool(true))
  sheet.set_cell_value("A4", Error("#DIV/0!"))
  sheet.set_cell_formula("A5", "SUM(A2:A2)")
  assert_valid_package("core values", workbook)
}

///|
test "package validity: styles, number formats, merges" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", String("styled"))
  let style = workbook.new_style(
    @xlsx.Style::builtin_number_format(2)
    .with_font(@xlsx.Font::with_values(bold=true, color="#FF0000"))
    .with_fill(@xlsx.Fill::pattern(pattern=1, color="#FFFF00")),
  )
  workbook.set_cell_style("Sheet1", "A1", style)
  sheet.merge_cells("B1:D1")
  assert_valid_package("styles", workbook)
}

///|
test "package validity: multiple sheets and defined names" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("First"))
  ignore(workbook.add_sheet("Second"))
  ignore(workbook.add_sheet("Third"))
  workbook.set_cell("First", "A1", "a")
  workbook.set_cell("Second", "A1", "b")
  workbook.set_defined_name(@xlsx.DefinedName::new("MyRange", "First!$A$1"))
  assert_valid_package("multi-sheet", workbook)
}

///|
test "package validity: hyperlinks" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://example.com",
    @xlsx.HyperlinkType::External,
  )
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A2",
    "Sheet1!B2",
    @xlsx.HyperlinkType::Location,
  )
  assert_valid_package("hyperlinks", workbook)
}

///|
test "package validity: comments and rich text" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  workbook.add_comment("Sheet1", {
    cell: "A1",
    author: "Tester",
    author_id: None,
    text: "a note",
    paragraph: [],
    width: None,
    height: None,
  })
  sheet.set_cell_rich_text("B2", [
    { text: "bold ", font: None },
    { text: "plain", font: None },
  ])
  assert_valid_package("comments+richtext", workbook)
}

///|
test "package validity: table" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", String("Name"))
  sheet.set_cell_value("B1", String("Qty"))
  sheet.set_cell_value("A2", String("x"))
  sheet.set_cell_value("B2", Numeric(1.0))
  ignore(
    workbook.add_table_with_columns("Sheet1", "A1:B2", "T1", ["Name", "Qty"]),
  )
  assert_valid_package("table", workbook)
}

///|
test "package validity: chart" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  for i in 1..<=4 {
    sheet.set_cell_value("A\{i}", Numeric(i.to_double()))
    sheet.set_cell_value("B\{i}", Numeric((i * i).to_double()))
  }
  let opts = @xlsx.ChartOptions::new(Col)
  opts.series.push(
    @xlsx.ChartSeries::new("Sheet1!$A$1:$A$4", "Sheet1!$B$1:$B$4", name="S1"),
  )
  workbook.add_chart_with_options("Sheet1", "D1", opts)
  assert_valid_package("chart", workbook)
}

///|
test "package validity: sheet protection and workbook props" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.protect_sheet(
    "Sheet1",
    @xlsx.SheetProtectionOptions::with_values(
      password="secret",
      select_locked_cells=true,
    ),
  )
  workbook.set_workbook_props(
    Some(@xlsx.WorkbookPropsOptions::with_values(date_1904=true)),
  )
  assert_valid_package("protection", workbook)
}

///|
test "package validity: freeze panes and dimensions" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", String("header"))
  workbook.set_panes(
    "Sheet1",
    @xlsx.Panes::with_values(
      freeze=true,
      x_split=1,
      y_split=1,
      top_left_cell="B2",
    ),
  )
  workbook.set_row_height("Sheet1", 1, 30.0)
  workbook.set_col_width("Sheet1", 1, 18.0)
  assert_valid_package("panes+dims", workbook)
}

///|
test "package validity: streaming writer" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let stream = workbook.new_stream_writer("Sheet1")
  for r in 1..<=50 {
    stream.set_row_cells("A\{r}", [
      @xlsx.StreamCell::new("row\{r}"),
      @xlsx.StreamCell::new_value(Numeric(r.to_double())),
    ])
  }
  stream.flush()
  assert_valid_package("stream", workbook)
}
