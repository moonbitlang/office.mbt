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
      "op 0 (nop): unknown op (expected one of: set, formula, style, merge, width, freeze, filter, add-sheet, chart)",
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
