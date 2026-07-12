// Blackbox tests for the xlsx.batch/1 script engine: every op kind
// applies through the same library calls as its CLI twin, JSON value
// types are honored, and validation is strict with 0-based op indexes.

///|
fn parse_ops(script : String) -> Array[@batch.BatchOp] raise {
  @batch.parse_script(@json.parse(script))
}

///|
fn apply_script(workbook : @xlsx.Workbook, script : String) -> Int raise {
  let ops = parse_ops(script)
  for op in ops {
    @batch.apply_op(workbook, op)
  }
  ops.length()
}

///|
test "a script covering every op kind applies like its CLI twins" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{
    #|  "schema": "xlsx.batch/1",
    #|  "ops": [
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "A1", "value": "Region"}},
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "B1", "value": 42}},
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "B2", "value": 4.5}},
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "C1", "value": true}},
    #|    {"op": "formula", "params": {"sheet": "Data", "cell": "B3", "formula": "=SUM(B1:B2)"}},
    #|    {"op": "style", "params": {"sheet": "Data", "range": "A1:B1", "bold": true, "fill": "4472C4", "font_color": "FFFFFF", "number_format": "#,##0.00", "align": "center"}},
    #|    {"op": "merge", "params": {"sheet": "Data", "range": "A5:B5"}},
    #|    {"op": "width", "params": {"sheet": "Data", "column": "A:B", "width": 16}},
    #|    {"op": "freeze", "params": {"sheet": "Data", "cell": "A2"}},
    #|    {"op": "filter", "params": {"sheet": "Data", "range": "A1:C3"}},
    #|    {"op": "add-sheet", "params": {"name": "Summary"}},
    #|    {"op": "chart", "params": {"sheet": "Data", "anchor": "E2", "type": "line", "categories": "A1:A3", "values": "B1:B3", "name": "Sales", "title": "Trend"}}
    #|  ]
    #|}
  inspect(apply_script(workbook, script), content="12")
  // Values honored JSON types: text, integer cell, float cell, bool cell.
  inspect(workbook.get_cell("Data", "A1").unwrap_or(""), content="Region")
  match workbook.get_cell_value_raw("Data", "B1") {
    Some(Numeric(n)) => inspect(n, content="42")
    other => fail("B1 should be numeric, got \{to_repr(other)}")
  }
  match workbook.get_cell_value_raw("Data", "B2") {
    Some(Numeric(n)) => inspect(n, content="4.5")
    other => fail("B2 should be numeric, got \{to_repr(other)}")
  }
  match workbook.get_cell_value_raw("Data", "C1") {
    Some(Bool(b)) => inspect(b, content="true")
    other => fail("C1 should be bool, got \{to_repr(other)}")
  }
  inspect(
    workbook.get_cell_formula("Data", "B3").unwrap_or(""),
    content="SUM(B1:B2)",
  )
  // Style applied to both cells of the range, with the CLI's structure.
  let style_id = workbook.get_cell_style("Data", "A1").unwrap_or(0)
  assert_true(style_id != 0)
  assert_eq(workbook.get_cell_style("Data", "B1").unwrap_or(0), style_id)
  let style = workbook.get_style(style_id)
  match style.font {
    Some(font) => {
      assert_true(font.bold.unwrap_or(false))
      inspect(font.color.unwrap_or(""), content="FFFFFF")
    }
    None => fail("style should carry a font")
  }
  debug_inspect(
    workbook.get_merge_cells("Data"),
    content=(
      #|["A5:B5"]
    ),
  )
  inspect(workbook.get_col_width("Data", 1).unwrap_or(0), content="16")
  inspect(workbook.get_col_width("Data", 2).unwrap_or(0), content="16")
  match style.number_format {
    Some(Custom(code)) => inspect(code, content="#,##0.00")
    other => fail("expected the custom number format, got \{to_repr(other)}")
  }
  match style.fill {
    Some(fill) =>
      debug_inspect(
        fill.colors,
        content=(
          #|Some(["4472C4"])
        ),
      )
    None => fail("style should carry a fill")
  }
  match style.alignment {
    Some(alignment) =>
      inspect(alignment.horizontal.unwrap_or(""), content="center")
    None => fail("style should carry an alignment")
  }
  let panes = workbook.get_panes("Data")
  assert_true(panes.freeze)
  inspect(panes.y_split, content="1")
  inspect(panes.x_split, content="0")
  inspect(panes.top_left_cell, content="A2")
  match workbook.get_auto_filter("Data") {
    Some(auto_filter) => inspect(auto_filter.range_ref, content="A1:C3")
    None => fail("auto-filter should be set")
  }
  debug_inspect(
    workbook.get_sheet_list(),
    content=(
      #|["Data", "Summary"]
    ),
  )
  let mut chart_count = 0
  let mut chart_xml = ""
  for sheet in workbook.sheets() {
    for chart in sheet.charts() {
      chart_count += 1
      chart_xml = chart.xml
    }
  }
  inspect(chart_count, content="1")
  // Line type, sheet-qualified series ranges, series name, and title all
  // survive into the chart part.
  assert_true(chart_xml.contains("<c:lineChart>"))
  assert_true(chart_xml.contains("'Data'!A1:A3"))
  assert_true(chart_xml.contains("'Data'!B1:B3"))
  assert_true(chart_xml.contains("Sales"))
  assert_true(chart_xml.contains("Trend"))
}

///|
test "a style op applies borders, per-side overriding the all-sides default" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"style","params":{"sheet":"Data","range":"B2:C3","border":"thin","border_bottom":"medium","border_color":"4472C4"}}
    #|]}
  inspect(apply_script(workbook, script), content="1")
  let style_id = workbook.get_cell_style("Data", "B2").unwrap_or(0)
  assert_true(style_id != 0)
  let style = workbook.get_style(style_id)
  let sides : Map[String, Int] = Map([])
  let colors : Map[String, String] = Map([])
  match style.border {
    Some(borders) =>
      for border in borders {
        sides[border.typ] = border.style.unwrap_or(0)
        colors[border.typ] = border.color.unwrap_or("")
      }
    None => fail("style should carry borders")
  }
  // top/left/right take the all-sides thin (1); bottom is overridden to
  // medium (2); every side is colored.
  inspect(sides.get("top").unwrap_or(-1), content="1")
  inspect(sides.get("left").unwrap_or(-1), content="1")
  inspect(sides.get("right").unwrap_or(-1), content="1")
  inspect(sides.get("bottom").unwrap_or(-1), content="2")
  inspect(colors.get("top").unwrap_or(""), content="4472C4")
  inspect(colors.get("bottom").unwrap_or(""), content="4472C4")
}

///|
test "a style op can border a single side (a header underline)" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  ignore(
    apply_script(
      workbook,
      (
        #|{"schema":"xlsx.batch/1", "ops": [{"op":"style", "params": {"sheet":"Data", "range":"A1", "border_bottom":"double"}}]}
      ),
    ),
  )
  let style = workbook.get_style(
    workbook.get_cell_style("Data", "A1").unwrap_or(0),
  )
  match style.border {
    Some(borders) => {
      inspect(borders.length(), content="1")
      inspect(borders[0].typ, content="bottom")
      inspect(borders[0].style.unwrap_or(0), content="6") // double
    }
    None => fail("style should carry a single-side border")
  }
}

///|
test "a style op rejects an unknown border style or a bad border color" {
  let cases = [
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"style","params":{"sheet":"S","range":"A1","border":"wiggly"}}]}
      ),
      "style: unknown border style 'wiggly' (expected one of: thin, medium, thick, dashed, dotted, double, hair)",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"style","params":{"sheet":"S","range":"A1","border":"thin","border_color":"blue"}}]}
      ),
      "style: 'border_color' 'blue' is not a 6-digit hex RGB color (e.g. FF0000)",
    ),
  ]
  for case in cases {
    let (script, want) = case
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("S"))
    try {
      ignore(apply_script(workbook, script))
      fail("expected apply to reject: \{want}")
    } catch {
      @batch.BatchError(message) => assert_eq(message, want)
      err => fail("expected a BatchError, got \{err}")
    }
  }
}

///|
fn first_table(workbook : @xlsx.Workbook) -> @xlsx.Table raise {
  for sheet in workbook.sheets() {
    for table in sheet.tables() {
      return table
    }
  }
  fail("no table on any sheet")
}

///|
test "a table op derives columns from the header row and honors options" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{
    #|  "schema": "xlsx.batch/1",
    #|  "ops": [
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "A1", "value": "Item"}},
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "B1", "value": "Qty"}},
    #|    {"op": "table", "params": {"sheet": "Data", "range": "A1:B4", "name": "Inventory", "style": "TableStyleMedium2", "first_column": true, "row_stripes": false}}
    #|  ]
    #|}
  inspect(apply_script(workbook, script), content="3")
  let table = first_table(workbook)
  inspect(table.name, content="Inventory")
  inspect(table.display_name, content="Inventory")
  inspect(table.range_ref, content="A1:B4")
  // Column names are read from the header row, in order.
  debug_inspect(
    table.columns,
    content=(
      #|["Item", "Qty"]
    ),
  )
  inspect(table.style_name, content="TableStyleMedium2")
  assert_true(table.show_first_column)
  assert_false(table.show_row_stripes) // explicitly overridden off
  assert_true(table.show_header_row) // omitted -> engine default (shown)
}

///|
test "a table op auto-names and keeps engine defaults when options are omitted" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  // No headers, no name, no flags: columns auto-name, the engine assigns
  // Table1, and the tri-state defaults (shown header, striped rows) hold.
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"table","params":{"sheet":"S","range":"A1:C3"}}
    #|]}
  inspect(apply_script(workbook, script), content="1")
  let table = first_table(workbook)
  inspect(table.name, content="Table1")
  debug_inspect(
    table.columns,
    content=(
      #|["Column1", "Column2", "Column3"]
    ),
  )
  assert_true(table.show_header_row) // Bool? None -> true
  assert_true(table.show_row_stripes) // Bool? None -> true
  assert_false(table.show_first_column) // Bool default -> false
}

///|
test "a table op accepts a large range — no expansion cap applies" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("S"))
  // 100,002 cells — past the 100k cap that `style`/`merge` ranges hit, but a
  // table never enumerates its cells, so it must be accepted.
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"table","params":{"sheet":"S","range":"A1:B50001"}}
    #|]}
  inspect(apply_script(workbook, script), content="1")
  inspect(first_table(workbook).range_ref, content="A1:B50001")
}

///|
test "a table op rejects a single-row range on the last grid row" {
  try
    ignore(
      parse_ops(
        (
          #|{"schema":"xlsx.batch/1", "ops": [{"op":"table", "params": {"sheet":"S", "range":"A1048576:B1048576"}}]}
        ),
      ),
    )
  catch {
    @batch.BatchError(message) =>
      inspect(
        message,
        content="op 0 (table): 'range' is a single-row range on the last grid row, leaving no room for a data row: 'A1048576:B1048576'",
      )
    err => fail("expected a BatchError, got \{err}")
  } noraise {
    _ => fail("expected the last-row table range to be rejected")
  }
}

///|
test "a table op requires an A1:B2-style range, not a bare cell" {
  try
    ignore(
      parse_ops(
        (
          #|{"schema":"xlsx.batch/1", "ops": [{"op":"table", "params": {"sheet":"S", "range":"A1"}}]}
        ),
      ),
    )
  catch {
    @batch.BatchError(message) =>
      inspect(
        message,
        content="op 0 (table): 'range' must be an A1:B2-style range: 'A1'",
      )
    err => fail("expected a BatchError, got \{err}")
  } noraise {
    _ => fail("expected the table op to be rejected")
  }
}

///|
fn only_validation(
  workbook : @xlsx.Workbook,
  sheet : String,
) -> @xlsx.DataValidation raise {
  let dvs = workbook.get_data_validations(sheet)
  assert_eq(dvs.length(), 1)
  dvs[0]
}

///|
test "a validate op builds an inline dropdown list" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"validate","params":{"sheet":"Data","range":"A1:A10","type":"list","values":["Yes","No","Maybe"]}}
    #|]}
  inspect(apply_script(workbook, script), content="1")
  let dv = only_validation(workbook, "Data")
  inspect(dv.validation_type, content="list")
  // The engine quotes the CSV of the values into formula1.
  inspect(dv.formula1, content="\"Yes,No,Maybe\"")
  inspect(dv.sqref, content="A1:A10")
  // allow_blank defaults to true (Excel's friendlier default).
  inspect(dv.allow_blank, content="true")
}

///|
test "a validate op backs a dropdown with a source range" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"validate","params":{"sheet":"Data","range":"B2","type":"list","source":"Lists!$A$1:$A$5","allow_blank":false}}
    #|]}
  inspect(apply_script(workbook, script), content="1")
  let dv = only_validation(workbook, "Data")
  inspect(dv.validation_type, content="list")
  inspect(dv.formula1, content="Lists!$A$1:$A$5")
  inspect(dv.allow_blank, content="false")
}

///|
test "a validate op builds a two-bound whole-number rule with messages" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"validate","params":{"sheet":"Data","range":"C1:C3","type":"whole","operator":"between","formula1":"1","formula2":"100","error_style":"warning","error_title":"Out of range","error_message":"Enter 1-100","input_title":"Score","input_message":"1 to 100"}}
    #|]}
  inspect(apply_script(workbook, script), content="1")
  let dv = only_validation(workbook, "Data")
  inspect(dv.validation_type, content="whole")
  inspect(dv.operator, content="between")
  inspect(dv.formula1, content="1")
  inspect(dv.formula2, content="100")
  inspect(dv.error_style.unwrap_or(""), content="warning")
  inspect(dv.error_title.unwrap_or(""), content="Out of range")
  inspect(dv.error.unwrap_or(""), content="Enter 1-100")
  inspect(dv.prompt_title.unwrap_or(""), content="Score")
  inspect(dv.prompt.unwrap_or(""), content="1 to 100")
}

///|
test "a validate op builds a one-bound rule and a custom formula" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  // greaterThan needs only formula1; custom carries a boolean formula.
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"validate","params":{"sheet":"Data","range":"D1","type":"decimal","operator":"greaterThan","formula1":"0"}},
    #|  {"op":"validate","params":{"sheet":"Data","range":"E1","type":"custom","formula1":"=ISNUMBER(E1)"}}
    #|]}
  inspect(apply_script(workbook, script), content="2")
  let dvs = workbook.get_data_validations("Data")
  assert_eq(dvs.length(), 2)
  let decimal = dvs[0]
  inspect(decimal.validation_type, content="decimal")
  inspect(decimal.operator, content="greaterThan")
  inspect(decimal.formula1, content="0")
  inspect(decimal.formula2, content="")
  let custom = dvs[1]
  inspect(custom.validation_type, content="custom")
  inspect(custom.formula1, content="=ISNUMBER(E1)")
}

///|
test "a validate op reports the workbook stays valid OOXML" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  ignore(
    apply_script(
      workbook,
      (
        #|{"schema":"xlsx.batch/1","ops":[
        #|  {"op":"validate","params":{"sheet":"Data","range":"A1:A10","type":"list","values":["Yes","No"]}}
        #|]}
      ),
    ),
  )
  // A round-trip through the writer/reader keeps the validation.
  let bytes = @xlsx.write(workbook)
  let reopened = @xlsx.read(bytes)
  inspect(only_validation(reopened, "Data").validation_type, content="list")
}

///|
test "validate op apply-time errors are typed and specific" {
  let cases = [
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"list"}}]}
      ),
      "validate: type 'list' requires 'values' or 'source'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"whole","operator":"between","formula1":"1"}}]}
      ),
      "validate: operator 'between' requires 'formula2'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"whole","operator":"greaterThan","formula1":"1","formula2":"2"}}]}
      ),
      "validate: operator 'greaterThan' does not take 'formula2'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"whole","formula1":"1"}}]}
      ),
      "validate: type 'whole' requires 'operator'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"nonsense"}}]}
      ),
      "validate: unknown type 'nonsense' (expected one of: list, whole, decimal, date, time, textLength, custom)",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"whole","operator":"gt","formula1":"1"}}]}
      ),
      "validate: unknown operator 'gt' (expected one of: between, notBetween, equal, notEqual, greaterThan, greaterThanOrEqual, lessThan, lessThanOrEqual)",
    ),
    // A type that does not use a param must reject it, not silently drop it.
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"custom","formula1":"=A1>0","formula2":"=A1<9"}}]}
      ),
      "validate: type 'custom' does not take 'formula2'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"custom","operator":"equal","formula1":"=A1>0"}}]}
      ),
      "validate: type 'custom' does not take 'operator'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"list","values":["A"],"operator":"equal"}}]}
      ),
      "validate: type 'list' does not take 'operator'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"whole","operator":"equal","formula1":"1","values":["A"]}}]}
      ),
      "validate: type 'whole' does not take 'values'",
    ),
    // An unknown enum value is rejected even with no other trigger.
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"list","values":["A"],"error_style":"loud"}}]}
      ),
      "validate: unknown error_style 'loud' (expected one of: stop, warning, information)",
    ),
    // Inline values the engine's comma-join + quote cannot represent.
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"list","values":["Last, First","Other"]}}]}
      ),
      "validate: inline list value 'Last, First' contains a comma; use 'source' with a cell range instead",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"validate","params":{"sheet":"S","range":"A1","type":"list","values":["=SUM(1)"]}}]}
      ),
      "validate: an inline list value must not start with '='; use 'source' with a cell range instead",
    ),
  ]
  for case in cases {
    let (script, want) = case
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("S"))
    try {
      ignore(apply_script(workbook, script))
      fail("expected apply to reject: \{want}")
    } catch {
      @batch.BatchError(message) => assert_eq(message, want)
      err => fail("expected a BatchError, got \{err}")
    }
    // The rejected op left no validation behind.
    assert_eq(workbook.get_data_validations("S").length(), 0)
  }
}

///|
fn only_cf_xml(workbook : @xlsx.Workbook, sheet : String) -> String raise {
  for ws in workbook.sheets() {
    if ws.name() == sheet {
      let xmls = ws.conditional_formats()
      assert_eq(xmls.length(), 1)
      return xmls[0]
    }
  }
  fail("sheet '\{sheet}' not found")
}

///|
test "a cf cell rule paints a dxf highlight above a threshold" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"cf","params":{"sheet":"Data","range":"B2:B20","type":"cell","criteria":">","value":"100","fill":"FF0000","bold":true}}
    #|]}
  inspect(apply_script(workbook, script), content="1")
  let xml = only_cf_xml(workbook, "Data")
  assert_true(xml.contains("type=\"cellIs\""))
  assert_true(xml.contains("operator=\"greaterThan\""))
  assert_true(xml.contains("<formula>100</formula>"))
  // A dxf style id was allocated and referenced.
  assert_true(xml.contains("dxfId=\""))
  assert_true(xml.contains("sqref=\"B2:B20\""))
}

///|
test "a cf between rule uses min/max and an expression rule uses a formula" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"cf","params":{"sheet":"Data","range":"A1:A5","type":"cell","criteria":"between","min_value":"1","max_value":"9","fill":"FFFF00"}},
    #|  {"op":"cf","params":{"sheet":"Data","range":"C1:C5","type":"formula","formula":"=$A1>0","font_color":"FF0000"}}
    #|]}
  inspect(apply_script(workbook, script), content="2")
  // Two separate conditionalFormatting blocks, one per range.
  let ws = workbook.sheets()[0]
  let xmls = ws.conditional_formats()
  assert_eq(xmls.length(), 2)
  assert_true(xmls[0].contains("operator=\"between\""))
  assert_true(xmls[0].contains("<formula>1</formula>"))
  assert_true(xmls[0].contains("<formula>9</formula>"))
  assert_true(xmls[1].contains("type=\"expression\""))
  assert_true(xmls[1].contains("<formula>=$A1&gt;0</formula>"))
}

///|
test "a cf op renders color scales, a data bar, and an icon set" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"cf","params":{"sheet":"Data","range":"A1:A9","type":"3_color_scale","min_color":"FF0000","mid_color":"FFFF00","max_color":"00FF00"}},
    #|  {"op":"cf","params":{"sheet":"Data","range":"B1:B9","type":"data_bar","bar_color":"638EC6"}},
    #|  {"op":"cf","params":{"sheet":"Data","range":"C1:C9","type":"icon_set","icon_style":"3TrafficLights1","reverse_icons":true}}
    #|]}
  inspect(apply_script(workbook, script), content="3")
  let xmls = workbook.sheets()[0].conditional_formats()
  assert_eq(xmls.length(), 3)
  assert_true(xmls[0].contains("colorScale"))
  assert_true(xmls[0].contains("rgb=\"FFFF0000\""))
  assert_true(xmls[0].contains("rgb=\"FF00FF00\""))
  assert_true(xmls[1].contains("dataBar"))
  assert_true(xmls[1].contains("rgb=\"FF638EC6\""))
  // A basic data bar stays out of the x14 extension.
  assert_false(xmls[1].contains("x14"))
  assert_true(xmls[2].contains("iconSet=\"3TrafficLights1\""))
  assert_true(xmls[2].contains("reverse=\"1\""))
}

///|
test "a cf data_bar with x14 options emits the extended data bar" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"cf","params":{"sheet":"Data","range":"A1:A9","type":"data_bar","bar_color":"638EC6","bar_solid":true,"bar_direction":"rightToLeft","bar_border_color":"4472C4"}}
    #|]}
  inspect(apply_script(workbook, script), content="1")
  let xml = only_cf_xml(workbook, "Data")
  // Any x14 option makes the rule carry the x14 id extension (vs the basic
  // bar, which has no x14 marker).
  assert_true(xml.contains("dataBar"))
  assert_true(xml.contains("x14:id"))
  // The workbook round-trips as valid OOXML with the extended bar preserved.
  let reopened = @xlsx.read(@xlsx.write(workbook))
  let formats = reopened.sheets()[0].get_conditional_formats()
  match formats.get("A1:A9") {
    Some(opts) => {
      assert_eq(opts.length(), 1)
      assert_true(opts[0].bar_solid)
      inspect(opts[0].bar_direction, content="rightToLeft")
    }
    None => fail("expected the x14 data bar to survive a round-trip")
  }
}

///|
test "stacked cf ops on one range get increasing priorities and stay valid" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"cf","params":{"sheet":"Data","range":"A1:A5","type":"cell","criteria":">","value":"10","fill":"00FF00"}},
    #|  {"op":"cf","params":{"sheet":"Data","range":"A1:A5","type":"cell","criteria":"<","value":"0","fill":"FF0000"}}
    #|]}
  inspect(apply_script(workbook, script), content="2")
  let xmls = workbook.sheets()[0].conditional_formats()
  assert_eq(xmls.length(), 2)
  assert_true(xmls[0].contains("priority=\"1\""))
  assert_true(xmls[1].contains("priority=\"2\""))
  // The package round-trips.
  let reopened = @xlsx.read(@xlsx.write(workbook))
  let formats = reopened.sheets()[0].get_conditional_formats()
  match formats.get("A1:A5") {
    Some(opts) => assert_eq(opts.length(), 2)
    None => fail("expected the stacked rules to survive a round-trip")
  }
}

///|
test "cf op apply-time errors are typed and specific" {
  let cases = [
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"nope"}}]}
      ),
      "cf: unknown type 'nope' (expected one of: cell, formula, 2_color_scale, 3_color_scale, data_bar, icon_set)",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"cell","value":"1"}}]}
      ),
      "cf: type 'cell' requires 'criteria'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"cell","criteria":">","value":"1"}}]}
      ),
      "cf: type 'cell' requires a highlight (fill, font_color, bold, or italic)",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"cell","criteria":">","fill":"FF0000"}}]}
      ),
      "cf: type 'cell' requires 'value'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"cell","criteria":"between","min_value":"1","fill":"FF0000"}}]}
      ),
      "cf: a 'between' rule requires 'min_value' and 'max_value'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"formula","fill":"FF0000"}}]}
      ),
      "cf: type 'formula' requires 'formula'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"2_color_scale","min_color":"FF0000"}}]}
      ),
      "cf: type '2_color_scale' requires 'min_color' and 'max_color'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"icon_set"}}]}
      ),
      "cf: type 'icon_set' requires 'icon_style'",
    ),
    // A param the type does not use is rejected, not silently dropped.
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"data_bar","bar_color":"638EC6","fill":"FF0000"}}]}
      ),
      "cf: type 'data_bar' does not take 'fill'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"cell","criteria":">","value":"1","fill":"FF0000","bar_color":"638EC6"}}]}
      ),
      "cf: type 'cell' does not take 'bar_color'",
    ),
    // An x14-only icon set cannot go through the classic <iconSet>.
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"icon_set","icon_style":"3Stars"}}]}
      ),
      "cf: icon_style '3Stars' is not a classic icon set (expected one of: 3Arrows, 3ArrowsGray, 3Flags, 3Signs, 3Symbols, 3Symbols2, 3TrafficLights1, 3TrafficLights2, 4Arrows, 4ArrowsGray, 4Rating, 4RedToBlack, 4TrafficLights, 5Arrows, 5ArrowsGray, 5Quarters, 5Rating); 3Stars, 3Triangles, and 5Boxes are x14-only",
    ),
    // A cfvo stop type outside the classic enum would be invalid OOXML.
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"data_bar","min_type":"bogus"}}]}
      ),
      "cf: 'min_type' 'bogus' is not a valid stop type (expected one of: num, min, max, percent, percentile, formula)",
    ),
    // x14 data-bar option guards.
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"data_bar","bar_direction":"sideways"}}]}
      ),
      "cf: bar_direction 'sideways' is not valid (expected leftToRight or rightToLeft)",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"data_bar","bar_border_color":"navy"}}]}
      ),
      "cf: 'bar_border_color' 'navy' is not a 6-digit hex RGB color (e.g. FF0000)",
    ),
    // An x14 bar option on a type that is not a data bar is rejected.
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"cell","criteria":">","value":"1","fill":"FF0000","bar_solid":true}}]}
      ),
      "cf: type 'cell' does not take 'bar_solid'",
    ),
    // A color that is not a 6-digit hex RGB would be written as invalid rgb.
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"2_color_scale","min_color":"red","max_color":"00FF00"}}]}
      ),
      "cf: 'min_color' 'red' is not a 6-digit hex RGB color (e.g. FF0000)",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"data_bar","bar_color":"FF638EC6"}}]}
      ),
      "cf: 'bar_color' 'FF638EC6' is not a 6-digit hex RGB color (e.g. FF0000)",
    ),
    // A cell criteria that is a text/time-period word, not a comparison
    // operator, would become an invalid cellIs operator.
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"cell","criteria":"today","value":"1","fill":"FF0000"}}]}
      ),
      "cf: cell criteria 'today' is not a comparison operator (expected one of: >, >=, <, <=, =, !=, between, not between)",
    ),
    // An explicit `false` flag the type does not use is still rejected.
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"cf","params":{"sheet":"S","range":"A1","type":"data_bar","bar_color":"638EC6","stop_if_true":false}}]}
      ),
      "cf: type 'data_bar' does not take 'stop_if_true'",
    ),
  ]
  for case in cases {
    let (script, want) = case
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("S"))
    try {
      ignore(apply_script(workbook, script))
      fail("expected apply to reject: \{want}")
    } catch {
      @batch.BatchError(message) => assert_eq(message, want)
      err => fail("expected a BatchError, got \{err}")
    }
    assert_eq(workbook.sheets()[0].conditional_formats().length(), 0)
  }
}

///|
test "a sheet op renames, deletes, hides, very-hides, and shows sheets" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Scratch"))
  ignore(workbook.add_sheet("Helper"))
  ignore(workbook.add_sheet("Deep"))
  ignore(workbook.add_sheet("Was_Hidden"))
  let script =
    #|{"schema":"xlsx.batch/1","ops":[
    #|  {"op":"sheet","params":{"action":"rename","name":"Sheet1","to":"Data"}},
    #|  {"op":"sheet","params":{"action":"delete","name":"Scratch"}},
    #|  {"op":"sheet","params":{"action":"hide","name":"Helper"}},
    #|  {"op":"sheet","params":{"action":"very-hide","name":"Deep"}},
    #|  {"op":"sheet","params":{"action":"hide","name":"Was_Hidden"}},
    #|  {"op":"sheet","params":{"action":"show","name":"Was_Hidden"}}
    #|]}
  inspect(apply_script(workbook, script), content="6")
  // Renamed and deleted, in tab order.
  debug_inspect(
    workbook.get_sheet_list(),
    content=(
      #|["Data", "Helper", "Deep", "Was_Hidden"]
    ),
  )
  assert_eq(workbook.get_sheet_visible("Data"), true)
  assert_eq(workbook.get_sheet_visible("Helper"), false)
  assert_eq(workbook.get_sheet_visible("Deep"), false)
  // show restored visibility after hide.
  assert_eq(workbook.get_sheet_visible("Was_Hidden"), true)
  // very-hide is the stronger hidden state, distinct from a plain hide.
  match (workbook.sheet("Helper"), workbook.sheet("Deep")) {
    (Some(helper), Some(deep)) => {
      debug_inspect(helper.state(), content="Hidden")
      debug_inspect(deep.state(), content="VeryHidden")
    }
    _ => fail("Helper and Deep should still exist")
  }
}

///|
test "sheet op validation errors are typed and specific" {
  let cases = [
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"sheet","params":{"action":"flip","name":"S"}}]}
      ),
      "sheet: unknown action 'flip' (expected one of: rename, delete, hide, show, very-hide)",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"sheet","params":{"action":"rename","name":"S"}}]}
      ),
      "sheet: action 'rename' requires 'to'",
    ),
    (
      (
        #|{"schema":"xlsx.batch/1","ops":[{"op":"sheet","params":{"action":"delete","name":"S","to":"X"}}]}
      ),
      "sheet: action 'delete' does not take 'to'",
    ),
  ]
  for case in cases {
    let (script, want) = case
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("S"))
    ignore(workbook.add_sheet("Other"))
    try {
      ignore(apply_script(workbook, script))
      fail("expected apply to reject: \{want}")
    } catch {
      @batch.BatchError(message) => assert_eq(message, want)
      err => fail("expected a BatchError, got \{err}")
    }
    // The two sheets are untouched by a rejected op.
    assert_eq(workbook.get_sheet_list().length(), 2)
  }
}

///|
test "a sheet op rejects an unknown target instead of silently no-op-ing" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Only"))
  // `delete_sheet` silently returns on an unknown name, so the op must gate
  // on existence itself.
  try
    ignore(
      apply_script(
        workbook,
        (
          #|{"schema":"xlsx.batch/1", "ops": [{"op":"sheet", "params": {"action":"delete", "name":"Missing"}}]}
        ),
      ),
    )
  catch {
    @batch.BatchError(message) =>
      assert_eq(message, "sheet: no sheet named 'Missing'")
    err => fail("expected a BatchError, got \{err}")
  } noraise {
    _ => fail("expected the unknown target to be rejected")
  }
  assert_eq(workbook.get_sheet_list().length(), 1)
}

///|
test "a sheet op refuses to delete the last visible sheet" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Visible"))
  ignore(workbook.add_sheet("Helper"))
  // Hide Helper, then try to delete the only remaining visible sheet: that
  // would leave an all-hidden, invalid workbook (delete_sheet checks only the
  // total count).
  ignore(
    apply_script(
      workbook,
      (
        #|{"schema":"xlsx.batch/1", "ops": [{"op":"sheet", "params": {"action":"hide", "name":"Helper"}}]}
      ),
    ),
  )
  try
    ignore(
      apply_script(
        workbook,
        (
          #|{"schema":"xlsx.batch/1", "ops": [{"op":"sheet", "params": {"action":"delete", "name":"Visible"}}]}
        ),
      ),
    )
  catch {
    @batch.BatchError(message) =>
      assert_true(message.contains("at least one visible sheet"))
    err => fail("expected a BatchError, got \{err}")
  } noraise {
    _ => fail("expected the last-visible-sheet delete to be rejected")
  }
  // Nothing was deleted; deleting the HIDDEN sheet is fine (a visible remains).
  assert_eq(workbook.get_sheet_list().length(), 2)
  ignore(
    apply_script(
      workbook,
      (
        #|{"schema":"xlsx.batch/1", "ops": [{"op":"sheet", "params": {"action":"delete", "name":"Helper"}}]}
      ),
    ),
  )
  debug_inspect(
    workbook.get_sheet_list(),
    content=(
      #|["Visible"]
    ),
  )
}

///|
test "a sheet op targets chart sheets and counts them for the visible guard" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  ignore(workbook.add_chart_sheet("Chart1", "<chart/>"))
  // `workbook.sheet` sees only worksheets; the op resolves across the full tab
  // order, so a chart sheet is a valid target — hide it by its canonical name
  // spelled in a different case.
  ignore(
    apply_script(
      workbook,
      (
        #|{"schema":"xlsx.batch/1", "ops": [{"op":"sheet", "params": {"action":"hide", "name":"chart1"}}]}
      ),
    ),
  )
  assert_false(workbook.get_sheet_visible("Chart1"))
  // Re-show and rename it — chart sheets rename like worksheets.
  ignore(
    apply_script(
      workbook,
      (
        #|{"schema":"xlsx.batch/1", "ops": [{"op":"sheet", "params": {"action":"show", "name":"Chart1"}}, {"op":"sheet", "params": {"action":"rename", "name":"Chart1", "to":"Dashboard"}}]}
      ),
    ),
  )
  debug_inspect(
    workbook.get_sheet_list(),
    content=(
      #|["Data", "Dashboard"]
    ),
  )
  // The visible-sheet guard must count the chart sheet: with the chart sheet
  // (Dashboard) still visible, deleting the worksheet Data is allowed — the
  // workbook keeps a visible sheet. (Counting only worksheets would reject it.)
  ignore(
    apply_script(
      workbook,
      (
        #|{"schema":"xlsx.batch/1", "ops": [{"op":"sheet", "params": {"action":"delete", "name":"Data"}}]}
      ),
    ),
  )
  debug_inspect(
    workbook.get_sheet_list(),
    content=(
      #|["Dashboard"]
    ),
  )
}

///|
test "a chart op requires valid categories and values at parse time" {
  try
    ignore(
      parse_ops(
        (
          #|{"schema": "xlsx.batch/1",
          #| "ops": [{"op": "chart", "params": {"sheet": "Data", "anchor": "E2", "categories": "", "values": "B1:B3"}}]}
        ),
      ),
    )
  catch {
    @batch.BatchError(message) =>
      inspect(
        message,
        content="op 0 (chart): 'categories' is not a valid series range: ''",
      )
    err => fail("expected a BatchError, got \{err}")
  } noraise {
    _ => fail("expected the chart op to be rejected")
  }
}

///|
test "references are validated strictly at parse time" {
  for
    case in [
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "set", "params": {"sheet": "S", "cell": "XFE1", "value": 1}}]}
        ),
        "op 0 (set): 'cell' is not a valid cell reference: 'XFE1'",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "set", "params": {"sheet": "S", "cell": "A1:B2", "value": 1}}]}
        ),
        "op 0 (set): 'cell' must be a single cell, not a range: 'A1:B2'",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "freeze", "params": {"sheet": "S", "cell": "A$B1"}}]}
        ),
        "op 0 (freeze): 'cell' is not a valid cell reference: 'A$B1'",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "merge", "params": {"sheet": "S", "range": "A1:XFE1"}}]}
        ),
        "op 0 (merge): 'range' is not a valid cell or range reference: 'A1:XFE1'",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "width", "params": {"sheet": "S", "column": "XFE", "width": 9}}]}
        ),
        "op 0 (width): 'column' is not a valid column or column range: 'XFE'",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "chart", "params": {"sheet": "S", "anchor": "E2", "categories": "Data!$A$1:$A$3", "values": "nope"}}]}
        ),
        "op 0 (chart): 'values' is not a valid series range: 'nope'",
      ),
    ] {
    let (script, expected) = case
    try ignore(parse_ops(script)) catch {
      @batch.BatchError(message) => assert_eq(message, expected)
      err => fail("expected BatchError, got \{err}")
    } noraise {
      _ => fail("expected rejection: \{script}")
    }
  }
  // Round-4 apply-equivalence pins: range spelling for cell params,
  // colon requirement for merge/filter, strict column grammar, and
  // series anchors validated exactly as emitted.
  for
    case in [
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "set", "params": {"sheet": "S", "cell": "A1:A1", "value": 1}}]}
        ),
        "op 0 (set): 'cell' must be a single cell, not a range: 'A1:A1'",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "merge", "params": {"sheet": "S", "range": "A1"}}]}
        ),
        "op 0 (merge): 'range' must be an A1:B2-style range: 'A1'",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "filter", "params": {"sheet": "S", "range": "B2"}}]}
        ),
        "op 0 (filter): 'range' must be an A1:B2-style range: 'B2'",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "width", "params": {"sheet": "S", "column": "$A", "width": 9}}]}
        ),
        "op 0 (width): 'column' is not a valid column or column range: '$A'",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "width", "params": {"sheet": "S", "column": "D:B", "width": 9}}]}
        ),
        "op 0 (width): 'column' is not a valid column or column range: 'D:B'",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "chart", "params": {"sheet": "S", "anchor": "E2", "categories": "Data!A$B1:A$B2", "values": "B1:B3"}}]}
        ),
        "op 0 (chart): 'categories' is not a valid series range: 'Data!A$B1:A$B2'",
      ),
    ] {
    let (script, expected) = case
    try ignore(parse_ops(script)) catch {
      @batch.BatchError(message) => assert_eq(message, expected)
      err => fail("expected BatchError, got \{err}")
    } noraise {
      _ => fail("expected rejection: \{script}")
    }
  }
  for
    case in [
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "chart", "params": {"sheet": "S", "anchor": "E2", "categories": "!A1:A2", "values": "B1:B3"}}]}
        ),
        "op 0 (chart): 'categories' is not a valid series range: '!A1:A2'",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "chart", "params": {"sheet": "S", "anchor": "E2", "categories": "Data!A1!B1:B2", "values": "B1:B3"}}]}
        ),
        "op 0 (chart): 'categories' is not a valid series range: 'Data!A1!B1:B2'",
      ),
    ] {
    let (script, expected) = case
    try ignore(parse_ops(script)) catch {
      @batch.BatchError(message) => assert_eq(message, expected)
      err => fail("expected BatchError, got \{err}")
    } noraise {
      _ => fail("expected rejection: \{script}")
    }
  }
  // Qualified series ranges with anchors stay valid.
  let ok =
    #|{"schema": "xlsx.batch/1",
    #| "ops": [{"op": "chart", "params": {"sheet": "S", "anchor": "E2", "categories": "'My Data'!$A$1:$A$3", "values": "B1:B3"}}]}
  inspect(parse_ops(ok).length(), content="1")
}

///|
test "the aggregate style-cell budget rejects a runaway script" {
  // 11 ops x 100,000 cells (A1:J10000 is exactly the per-range cap)
  // crosses the 1,000,000-cell aggregate budget on the 11th op.
  let ops = StringBuilder()
  for i in 0..<11 {
    if i > 0 {
      ops.write_string(",")
    }
    ops.write_string(
      "{\"op\": \"style\", \"params\": {\"sheet\": \"S\", \"range\": \"A1:J10000\", \"bold\": true}}",
    )
  }
  let script = "{\"schema\": \"xlsx.batch/1\", \"ops\": [" +
    ops.to_string() +
    "]}"
  try ignore(parse_ops(script)) catch {
    @batch.BatchError(message) =>
      inspect(
        message,
        content="op 10 (style): style ranges expand past 1000000 total cells",
      )
    err => fail("expected BatchError, got \{err}")
  } noraise {
    _ => fail("expected the budget to reject the script")
  }
}

///|
test "non-finite numbers are rejected, finite ones follow IEEE semantics" {
  // Standard JSON number semantics: literals round to the nearest double
  // (spelling-independent); only values that are not finite are rejected.
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let rounding =
    #|{"schema": "xlsx.batch/1",
    #| "ops": [{"op": "set", "params": {"sheet": "Data", "cell": "A1", "value": 9007199254740993}}]}
  ignore(apply_script(workbook, rounding))
  match workbook.get_cell_value_raw("Data", "A1") {
    Some(Numeric(n)) => inspect(n, content="9007199254740992")
    other => fail("expected the rounded double, got \{to_repr(other)}")
  }
  for
    case in [
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "set", "params": {"sheet": "S", "cell": "A1", "value": 1e309}}]}
        ),
        "op 0 (set): 'value' must be a finite JSON number",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "set", "params": {"sheet": "S", "cell": "A1", "value": -1e309}}]}
        ),
        "op 0 (set): 'value' must be a finite JSON number",
      ),
      (
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": "width", "params": {"sheet": "S", "column": "A", "width": 1e309}}]}
        ),
        "op 0 (width): 'width' must be a finite JSON number",
      ),
    ] {
    let (script, expected) = case
    try ignore(parse_ops(script)) catch {
      @batch.BatchError(message) => assert_eq(message, expected)
      err => fail("expected BatchError, got \{err}")
    } noraise {
      _ => fail("expected rejection: \{script}")
    }
  }
}

///|
test "a non-string op name has its own diagnostic" {
  try
    ignore(
      parse_ops(
        (
          #|{"schema": "xlsx.batch/1", "ops": [{"op": 5, "params": {}}]}
        ),
      ),
    )
  catch {
    @batch.BatchError(message) =>
      inspect(message, content="op 0: \"op\" must be a string")
    err => fail("expected BatchError, got \{err}")
  } noraise {
    _ => fail("expected rejection")
  }
}

///|
test "set with null clears the cell's contents" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "old")
  let script =
    #|{"schema": "xlsx.batch/1",
    #| "ops": [{"op": "set", "params": {"sheet": "Data", "cell": "A1", "value": null}}]}
  inspect(apply_script(workbook, script), content="1")
  inspect(workbook.get_cell("Data", "A1").unwrap_or("?"), content="")
}

///|
test "zero ops is a valid no-op" {
  let ops = parse_ops(
    (
      #|{"schema": "xlsx.batch/1", "ops": []}
    ),
  )
  inspect(ops.length(), content="0")
}

///|
test "strict validation names the 0-based op index" {
  let cases : Array[(String, String)] = [
    (
      (
        #|{"ops": []}
      ),
      "missing \"schema\" (expected xlsx.batch/1)",
    ),
    (
      (
        #|{"schema": "xlsx.batch/2", "ops": []}
      ),
      "unsupported schema 'xlsx.batch/2' (expected xlsx.batch/1)",
    ),
    (
      (
        #|{"schema": "xlsx.batch/1", "ops": [], "extra": 1}
      ),
      "unknown top-level key 'extra'",
    ),
    (
      (
        #|{"schema": "xlsx.batch/1", "ops": [{"op": "nop", "params": {}}]}
      ),
      "op 0 (nop): unknown op (expected one of: set, formula, style, merge, width, freeze, filter, add-sheet, chart, table, validate, sheet, cf)",
    ),
    (
      (
        #|{"schema": "xlsx.batch/1", "ops": [
        #|  {"op": "set", "params": {"sheet": "Data", "cell": "A1", "value": 1}},
        #|  {"op": "style", "params": {"sheet": "Data", "range": "A1", "colour": "FF0000"}}
        #|]}
      ),
      "op 1 (style): unknown param 'colour'",
    ),
    (
      (
        #|{"schema": "xlsx.batch/1", "ops": [{"op": "width", "params": {"sheet": "Data", "column": "A", "width": "wide"}}]}
      ),
      "op 0 (width): 'width' must be a number",
    ),
    (
      (
        #|{"schema": "xlsx.batch/1", "ops": [{"op": "merge", "params": {"sheet": "Data"}}]}
      ),
      "op 0 (merge): missing param 'range'",
    ),
    (
      (
        #|{"schema": "xlsx.batch/1", "ops": [{"op": "set", "params": {"sheet": "Data", "cell": "A1", "value": [1]}}]}
      ),
      "op 0 (set): 'value' must be a string, number, bool, or null",
    ),
  ]
  for case in cases {
    let (script, expected) = case
    try ignore(parse_ops(script)) catch {
      @batch.BatchError(message) => assert_eq(message, expected)
      err => fail("expected BatchError, got \{err}")
    } noraise {
      _ => fail("expected script to be rejected: \{script}")
    }
  }
}

///|
test "the op-count cap rejects a runaway script" {
  let ops = StringBuilder()
  for i in 0..<10_001 {
    if i > 0 {
      ops.write_string(",")
    }
    ops.write_string(
      "{\"op\": \"set\", \"params\": {\"sheet\": \"S\", \"cell\": \"A1\", \"value\": 1}}",
    )
  }
  let script = "{\"schema\": \"xlsx.batch/1\", \"ops\": [" +
    ops.to_string() +
    "]}"
  try ignore(parse_ops(script)) catch {
    @batch.BatchError(message) =>
      inspect(message, content="script has 10001 ops; max is 10000")
    err => fail("expected BatchError, got \{err}")
  } noraise {
    _ => fail("expected the cap to reject the script")
  }
}

///|
test "apply failures carry the underlying library error" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let ops = parse_ops(
    (
      #|{"schema": "xlsx.batch/1",
      #| "ops": [{"op": "merge", "params": {"sheet": "Nope", "range": "A1:B2"}}]}
    ),
  )
  let mut failed = false
  for op in ops {
    @batch.apply_op(workbook, op) catch {
      _ => {
        failed = true
        break
      }
    }
  }
  assert_true(failed)
}
