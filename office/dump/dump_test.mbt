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
