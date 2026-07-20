///|
fn probe_workbook() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  ignore(workbook.add_sheet("Notes"))
  workbook.set_cell("Data", "A1", "Region")
  workbook.set_cell_int("Data", "B1", 42)
  workbook.set_cell_bool("Data", "C1", true)
  workbook.set_cell("Data", "A2", "")
  workbook.set_cell_formula("Data", "B2", "SUM(B1:B1)")
  workbook.merge_cells("Data", "A3:B3")
  workbook.merge_cells("Data", "A1:A1")
  workbook.set_panes(
    "Data",
    @xlsx.Panes::with_values(freeze=true, y_split=1, top_left_cell="A2"),
  )
  workbook.auto_filter("Data", "A1:C1", [])
  workbook.set_cell("Notes", "A1", "aside")
  workbook.set_sheet_visible("Notes", false)
  workbook
}

///|
test "the dump document is canonical, ordered, and replay-shaped" {
  let envelope = @dump.dump_xlsx_workbook(
    probe_workbook(),
    source_file="probe.xlsx",
    source_bytes=1234,
  )
  inspect(
    envelope.to_json_document().stringify(indent=2),
    content=(
      #|{
      #|  "schema": "office.dump/1",
      #|  "format": "xlsx",
      #|  "source": {
      #|    "file": "probe.xlsx",
      #|    "bytes": 1234
      #|  },
      #|  "replay": {
      #|    "batch_schema": "xlsx.batch/1",
      #|    "create": {
      #|      "sheet": "Data"
      #|    },
      #|    "limits": {
      #|      "max_ops": 10000,
      #|      "max_new_styles": 4096,
      #|      "max_script_bytes": 8388608
      #|    }
      #|  },
      #|  "ops": [
      #|    {
      #|      "op": "add-sheet",
      #|      "params": {
      #|        "name": "Notes"
      #|      }
      #|    },
      #|    {
      #|      "op": "set",
      #|      "params": {
      #|        "sheet": "Data",
      #|        "cell": "A1",
      #|        "value": "Region"
      #|      }
      #|    },
      #|    {
      #|      "op": "set",
      #|      "params": {
      #|        "sheet": "Data",
      #|        "cell": "B1",
      #|        "value": 42
      #|      }
      #|    },
      #|    {
      #|      "op": "set",
      #|      "params": {
      #|        "sheet": "Data",
      #|        "cell": "C1",
      #|        "value": true
      #|      }
      #|    },
      #|    {
      #|      "op": "set",
      #|      "params": {
      #|        "sheet": "Data",
      #|        "cell": "A2",
      #|        "value": ""
      #|      }
      #|    },
      #|    {
      #|      "op": "formula",
      #|      "params": {
      #|        "sheet": "Data",
      #|        "cell": "B2",
      #|        "formula": "SUM(B1:B1)"
      #|      }
      #|    },
      #|    {
      #|      "op": "merge",
      #|      "params": {
      #|        "sheet": "Data",
      #|        "range": "A1:A1"
      #|      }
      #|    },
      #|    {
      #|      "op": "merge",
      #|      "params": {
      #|        "sheet": "Data",
      #|        "range": "A3:B3"
      #|      }
      #|    },
      #|    {
      #|      "op": "freeze",
      #|      "params": {
      #|        "sheet": "Data",
      #|        "cell": "A2"
      #|      }
      #|    },
      #|    {
      #|      "op": "filter",
      #|      "params": {
      #|        "sheet": "Data",
      #|        "range": "A1:C1"
      #|      }
      #|    },
      #|    {
      #|      "op": "set",
      #|      "params": {
      #|        "sheet": "Notes",
      #|        "cell": "A1",
      #|        "value": "aside"
      #|      }
      #|    },
      #|    {
      #|      "op": "sheet",
      #|      "params": {
      #|        "action": "hide",
      #|        "name": "Notes"
      #|      }
      #|    }
      #|  ],
      #|  "residual": [],
      #|  "warnings": [],
      #|  "stats": {
      #|    "ops": 12,
      #|    "residual": 0,
      #|    "warnings": 0
      #|  }
      #|}
    ),
  )
}

///|
test "jsonl lines carry header first, ops indexed, end last" {
  let envelope = @dump.dump_xlsx_workbook(
    probe_workbook(),
    source_file="probe.xlsx",
    source_bytes=1234,
  )
  let lines = envelope.to_jsonl_lines()
  assert_true(lines.length() > 3)
  assert_true(lines[0].contains("\"record\":\"header\""))
  assert_true(lines[0].contains("\"schema\":\"office.dump/1\""))
  assert_true(lines[1].contains("\"record\":\"op\""))
  assert_true(lines[1].contains("\"index\":0"))
  assert_true(lines[lines.length() - 1].contains("\"record\":\"end\""))
  let mut op_lines = 0
  for line in lines {
    if line.contains("\"record\":\"op\"") {
      op_lines += 1
    }
  }
  assert_eq(op_lines, envelope.ops.length())
}

///|
test "error cells become residual records, never lossy ops" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_value("A1", Error("#DIV/0!"))
  workbook.set_cell("Data", "B1", "ok")
  let envelope = @dump.dump_xlsx_workbook(
    workbook,
    source_file="err.xlsx",
    source_bytes=1,
  )
  let document = envelope.to_json_document().stringify()
  assert_true(document.contains("xlsx.error_cell_unsupported"))
  assert_true(document.contains("#DIV/0!"))
  // the error cell produced no set op
  let mut set_ops = 0
  for op in envelope.ops {
    if op.stringify().contains("\"op\":\"set\"") {
      set_ops += 1
    }
  }
  assert_eq(set_ops, 1)
}

///|
test "dimensions become width/row/col ops before cell ops" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Grid"))
  workbook.set_col_width("Grid", 1, 18.5)
  workbook.set_row_height("Grid", 2, 30.0)
  workbook.set_row_visible("Grid", 3, false)
  workbook.set_col_visible("Grid", 4, false)
  workbook.set_cell("Grid", "A1", "corner")
  let envelope = @dump.dump_xlsx_workbook(
    workbook,
    source_file="grid.xlsx",
    source_bytes=1,
  )
  let ops = envelope.ops.map(op => op.stringify())
  // width/row/col ops precede the first set op
  let mut first_set = ops.length()
  let mut last_dim = -1
  for index, op in ops {
    if op.contains("\"op\":\"set\"") && index < first_set {
      first_set = index
    }
    if op.contains("\"op\":\"width\"") ||
      op.contains("\"op\":\"row\"") ||
      op.contains("\"op\":\"col\"") {
      last_dim = index
    }
  }
  assert_true(last_dim >= 0 && last_dim < first_set)
  let document = envelope.to_json_document().stringify()
  assert_true(document.contains("\"width\":18.5"))
  assert_true(document.contains("\"action\":\"height\""))
  assert_true(document.contains("\"action\":\"hide\""))
  // the JSONL end record carries an ops integrity digest
  let lines = envelope.to_jsonl_lines()
  assert_true(lines[lines.length() - 1].contains("\"ops_sha256\":\""))
}

///|
test "an all-hidden workbook keeps one worksheet visible on replay" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("A"))
  workbook.set_cell("A", "A1", "a")
  // a visible chart sheet lets the engine hide the only worksheet; the
  // chart sheet is dropped on dump, so replay would have no visible sheet
  // unless the worksheet's hide is withheld
  let chart = @xlsx.ChartOptions::new(Col)
  chart.series.push(@xlsx.ChartSeries::new("A!$A$1:$A$1", "A!$A$1:$A$1"))
  ignore(workbook.add_chart_sheet_with_options("Chart", chart))
  workbook.set_sheet_visible("A", false)
  let envelope = @dump.dump_xlsx_workbook(
    workbook,
    source_file="hidden.xlsx",
    source_bytes=1,
  )
  // the sole worksheet's hide is withheld so replay keeps it visible
  let mut hides = 0
  for op in envelope.ops {
    if op.stringify().contains("\"op\":\"sheet\"") {
      hides += 1
    }
  }
  assert_eq(hides, 0)
  let document = envelope.to_json_document().stringify()
  assert_true(document.contains("xlsx.sheet_visibility_forced_visible"))
}

///|
test "oversized merge and filter ranges degrade to residual, not self-check failure" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "x")
  // A1:A200000 covers 200000 cells, past the 100000 batch range ceiling
  workbook.merge_cells("Data", "A1:A200000")
  // this must succeed (not raise DumpSelfCheckFailed) and record residual
  let envelope = @dump.dump_xlsx_workbook(
    workbook,
    source_file="big.xlsx",
    source_bytes=1,
  )
  let document = envelope.to_json_document().stringify()
  assert_true(document.contains("xlsx.merge_range_too_large"))
  // no merge op was emitted for the oversized range
  let mut merge_ops = 0
  for op in envelope.ops {
    if op.stringify().contains("\"op\":\"merge\"") {
      merge_ops += 1
    }
  }
  assert_eq(merge_ops, 0)
}

///|
test "workbook-level content produces explicit residuals" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "x")
  workbook.set_defined_name(@xlsx.DefinedName::new("Choice", "Data!$A$1"))
  let envelope = @dump.dump_xlsx_workbook(
    workbook,
    source_file="named.xlsx",
    source_bytes=1,
  )
  assert_true(
    envelope
    .to_json_document()
    .stringify()
    .contains("xlsx.defined_names_dropped"),
  )
}

///|
test "a source digest travels in the envelope source record" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "x")
  let envelope = @dump.dump_xlsx_workbook(
    workbook,
    source_file="d.xlsx",
    source_bytes=3,
    source_sha256=Some("abc123"),
  )
  let document = envelope.to_json_document().stringify()
  assert_true(document.contains("\"sha256\":\"abc123\""))
  // the header line of the JSONL form carries it too
  assert_true(envelope.to_jsonl_lines()[0].contains("\"sha256\":\"abc123\""))
}

///|
test "non-default page and view state produce residuals" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "x")
  workbook.set_page_margins(
    "Data",
    Some(@xlsx.PageLayoutMarginsOptions::with_values(top=1.5, bottom=1.5)),
  )
  workbook.set_sheet_view(
    "Data",
    0,
    @xlsx.SheetViewOptions::with_values(show_grid_lines=false, zoom_scale=125.0),
  )
  let document = @dump.dump_xlsx_workbook(
      workbook,
      source_file="layout.xlsx",
      source_bytes=1,
    )
    .to_json_document()
    .stringify()
  assert_true(document.contains("xlsx.page_margins_dropped"))
  assert_true(document.contains("xlsx.sheet_view_state_dropped"))
}

///|
test "a frozen pane with a persisted scroll position is disclosed" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "x")
  workbook.set_panes(
    "Data",
    @xlsx.Panes::with_values(
      freeze=true,
      x_split=1,
      y_split=1,
      top_left_cell="C5",
    ),
  )
  let document = @dump.dump_xlsx_workbook(
      workbook,
      source_file="scroll.xlsx",
      source_bytes=1,
    )
    .to_json_document()
    .stringify()
  // freeze op present AND the scroll position disclosed as approximated
  assert_true(document.contains("\"op\":\"freeze\""))
  assert_true(document.contains("xlsx.freeze_pane_state_approximated"))
}

///|
test "filter-database name is excluded only with a matching auto-filter" {
  // a _xlnm._FilterDatabase name whose sheet has NO auto-filter is a real
  // drop, not a reconstructed one
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "x")
  workbook.set_defined_name(
    @xlsx.DefinedName::new("_xlnm._FilterDatabase", "Data!$A$1", scope="Data"),
  )
  assert_true(
    @dump.dump_xlsx_workbook(workbook, source_file="d.xlsx", source_bytes=1)
    .to_json_document()
    .stringify()
    .contains("xlsx.defined_names_dropped"),
  )
}

///|
test "additional non-default view fields and plain scroll are disclosed" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "x")
  workbook.set_sheet_view(
    "Data",
    0,
    @xlsx.SheetViewOptions::with_values(show_zeros=false, top_left_cell="C5"),
  )
  let document = @dump.dump_xlsx_workbook(
      workbook,
      source_file="v.xlsx",
      source_bytes=1,
    )
    .to_json_document()
    .stringify()
  // show_zeros=false is a genuine non-default view state
  assert_true(document.contains("xlsx.sheet_view_state_dropped"))
  // a scroll anchor with no frozen/split panes is disclosed too
  assert_true(document.contains("xlsx.sheet_scroll_position_dropped"))
}

///|
test "filter-database scope matches the sheet case-insensitively" {
  // sheet lookup is case-insensitive; a filter created with a differently
  // cased sheet name must still suppress the reconstructed builtin name
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "x")
  workbook.set_cell("Data", "B1", "y")
  workbook.auto_filter("data", "A1:B1", [])
  let document = @dump.dump_xlsx_workbook(
      workbook,
      source_file="ci.xlsx",
      source_bytes=1,
    )
    .to_json_document()
    .stringify()
  assert_true(document.contains("\"op\":\"filter\""))
  // no spurious defined-names residual for the auto-created builtin
  assert_false(document.contains("xlsx.defined_names_dropped"))
}

///|
test "cancellation raises before work completes" {
  try
    ignore(
      @dump.dump_xlsx_workbook(
        probe_workbook(),
        source_file="c.xlsx",
        source_bytes=1,
        cancelled=() => true,
      ),
    )
  catch {
    @dump.DumpCancelled => ()
    error => fail("expected DumpCancelled, got \{error}")
  } noraise {
    _ => fail("expected cancellation to raise")
  }
}

///|
test "a workbook with only chart sheets is refused with a typed error" {
  let workbook = @xlsx.Workbook::new()
  // Workbook::new starts with zero sheets; nothing to dump
  try
    ignore(
      @dump.dump_xlsx_workbook(workbook, source_file="x.xlsx", source_bytes=1),
    )
  catch {
    @dump.DumpUnsupported(_) => ()
    error => fail("expected DumpUnsupported, got \{error}")
  } noraise {
    _ => fail("expected an empty workbook to be refused")
  }
}
