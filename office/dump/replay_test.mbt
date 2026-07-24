///|
/// The canonical op stream of a dump, for fixpoint comparison. `source`
/// and `tool` provenance are excluded by construction (the envelope keeps
/// only ops/residual/warnings), so this compares exactly the replayable
/// content.
fn dump_ops(envelope : @dump.DumpEnvelope) -> String {
  Json::array(envelope.ops).stringify()
}

///|
fn dump_residual(envelope : @dump.DumpEnvelope) -> String {
  Json::array(envelope.residual.map(r => r.to_json())).stringify()
}

///|
fn dump_warnings(envelope : @dump.DumpEnvelope) -> String {
  Json::array(envelope.warnings.map(w => w.to_json())).stringify()
}

///|
/// Builds a workbook exercising the op families the in-memory dump emits:
/// add-sheet, width/row-height/row-hide/col-hide dimensions, typed
/// set (string, empty-string, integer, non-integral number, bool),
/// formula, merge, freeze, filter, style, and hidden + very-hidden
/// visibility. Shared-formula translation is NOT exercised here — shared
/// formulas exist only after a file round-trip through the reader, which
/// an in-memory workbook never performs; it is covered by the file-corpus
/// fixpoint in a later slice.
fn fixpoint_workbook() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  ignore(workbook.add_sheet("Extra"))
  ignore(workbook.add_sheet("Buried"))
  workbook.set_cell("Data", "A1", "Region")
  workbook.set_cell("Data", "B1", "Sales")
  workbook.set_cell("Data", "A2", "East")
  workbook.set_cell("Data", "D2", "")
  workbook.set_cell_int("Data", "B2", 30)
  workbook.set_cell_float("Data", "C2", 3.5)
  workbook.set_cell_bool("Data", "E2", true)
  workbook.set_cell_formula("Data", "B3", "SUM(B2:B2)")
  workbook.merge_cells("Data", "A5:B5")
  workbook.set_col_width("Data", 1, 18.0)
  workbook.set_col_visible("Data", 6, false)
  workbook.set_row_height("Data", 1, 24.0)
  workbook.set_row_visible("Data", 4, false)
  workbook.set_panes(
    "Data",
    @xlsx.Panes::with_values(freeze=true, y_split=1, top_left_cell="A2"),
  )
  workbook.auto_filter("Data", "A1:C1", [])
  let header = workbook.new_style(
    @xlsx.Style::new()
    .with_font(@xlsx.Font::with_values(bold=true, color="FFFFFF"))
    .with_fill(@xlsx.Fill::solid("4472C4")),
  )
  workbook.set_cell_style("Data", "A1", header)
  workbook.set_cell_style("Data", "B1", header)
  workbook.set_cell("Extra", "A1", "note")
  workbook.set_sheet_visible("Extra", false)
  workbook.set_cell("Buried", "A1", "deep")
  workbook.set_sheet_visible("Buried", false, very_hidden=true)
  workbook
}

///|
test "v2 dump then replay then dump is a fixpoint on the op stream" {
  let source = fixpoint_workbook()
  let d1 = @dump.dump_xlsx_workbook(
    source,
    source_file="fixpoint.xlsx",
    source_bytes=1,
  )
  assert_eq(d1.batch_schema, "xlsx.batch/2")
  // replay the dump into a fresh workbook using the same engine, then dump
  // that — the ops, residuals, create sheet, and warnings must be stable
  let replayed = @dump.replay_xlsx_dump(d1)
  let d2 = @dump.dump_xlsx_workbook(
    replayed,
    source_file="fixpoint.xlsx",
    source_bytes=1,
  )
  assert_eq(dump_ops(d1), dump_ops(d2))
  assert_eq(dump_residual(d1), dump_residual(d2))
  assert_eq(d1.create_sheet, d2.create_sheet)
  assert_eq(dump_warnings(d1), dump_warnings(d2))
  // the replayed workbook carries the source semantics, not just a match
  // of op text: sheet set/order/state, typed values, formula, dimensions,
  // merge, and pane all survive
  assert_eq(source.get_sheet_list(), replayed.get_sheet_list())
  assert_true(replayed.get_sheet_visible("Data"))
  assert_false(replayed.get_sheet_visible("Extra"))
  assert_true(replayed.sheet("Buried").unwrap().state() is VeryHidden)
  assert_true(replayed.get_cell_value_raw("Data", "C2") is Some(Numeric(3.5)))
  assert_true(replayed.get_cell_value_raw("Data", "E2") is Some(Bool(true)))
  // the empty-string cell survives as a string, not an absent cell
  assert_true(replayed.get_cell_value_raw("Data", "D2") is Some(String("")))
  assert_true(replayed.get_cell_formula("Data", "B3") is Some("SUM(B2:B2)"))
  assert_eq(replayed.get_col_width("Data", 1), Some(18.0))
  assert_false(replayed.get_row_visible("Data", 4))
  assert_false(replayed.get_col_visible("Data", 6))
  assert_eq(replayed.get_merge_cells("Data"), ["A5:B5"])
  assert_true(replayed.get_auto_filter("Data") is Some(_))
  assert_true(replayed.get_panes("Data").freeze)
}

///|
test "a batch-authored chart survives the file-backed dump replay fixpoint" {
  let source = @xlsx.Workbook::new()
  ignore(source.add_sheet("Data"))
  source.set_cell("Data", "A1", "Quarter")
  source.set_cell("Data", "B1", "Revenue")
  source.set_cell("Data", "A2", "Q1")
  source.set_cell_int("Data", "B2", 10)
  source.set_cell("Data", "A3", "Q2")
  source.set_cell_int("Data", "B3", 15)
  let script = Json::object({
    "schema": Json::string("xlsx.batch/2"),
    "ops": Json::array([
      Json::object({
        "op": Json::string("chart"),
        "params": Json::object({
          "sheet": Json::string("Data"),
          "anchor": Json::string("E2"),
          "type": Json::string("line"),
          "categories": Json::string("A2:A3"),
          "values": Json::string("B2:B3"),
          "name": Json::string("Revenue"),
          "title": Json::string("By quarter"),
        }),
      }),
    ]),
  })
  for op in @batch.parse_script(script) {
    @batch.apply_op(source, op)
  }
  let file_backed = @xlsx.read(@xlsx.write(source))
  guard file_backed.sheet("Data") is Some(source_sheet) else {
    fail("missing file-backed Data")
  }
  assert_eq(source_sheet.charts().length(), 1)
  let source_chart = source_sheet.charts()[0]
  assert_eq(@inspect.chart_title(source_chart.xml), Some("By quarter"))
  let source_series = @inspect.chart_series(source_chart.xml)
  assert_eq(source_series.length(), 1)
  assert_eq(source_series[0].name, Some("Revenue"))
  assert_eq(source_series[0].categories, Some("'Data'!A2:A3"))
  assert_eq(source_series[0].values, Some("'Data'!B2:B3"))
  let candidate_book = @xlsx.Workbook::new()
  let candidate_sheet = candidate_book.add_sheet("Data")
  let candidate_options = @xlsx.ChartOptions::new(Line)
  candidate_options.title = "By quarter"
  candidate_options.series.push(
    @xlsx.ChartSeries::new("'Data'!A2:A3", "'Data'!B2:B3", name="Revenue"),
  )
  candidate_book.add_chart_with_options("Data", "E2", candidate_options)
  let candidate_chart = candidate_sheet.charts()[0]
  assert_true(candidate_chart.xml.has_suffix(source_chart.xml))
  assert_eq(candidate_chart.offset_x, source_chart.offset_x)
  assert_eq(candidate_chart.offset_y, source_chart.offset_y)
  assert_eq(candidate_chart.width_emu, source_chart.width_emu)
  assert_eq(candidate_chart.height_emu, source_chart.height_emu)
  assert_eq(candidate_chart.print_object, source_chart.print_object)
  assert_eq(candidate_chart.locked, source_chart.locked)
  let d1 = @dump.dump_xlsx_workbook(
    file_backed,
    source_file="charted.xlsx",
    source_bytes=1,
  )
  let document = d1.to_json_document().stringify()
  assert_true(document.contains("\"op\":\"chart\""))
  assert_true(document.contains("\"anchor\":\"E2\""))
  assert_true(document.contains("\"type\":\"line\""))
  assert_true(document.contains("\"categories\":\"A2:A3\""))
  assert_true(document.contains("\"values\":\"B2:B3\""))
  assert_true(document.contains("\"name\":\"Revenue\""))
  assert_true(document.contains("\"title\":\"By quarter\""))
  assert_false(document.contains("xlsx.charts_not_dumped"))
  let replayed = @xlsx.read(@xlsx.write(@dump.replay_xlsx_dump(d1)))
  guard replayed.sheet("Data") is Some(sheet) else { fail("missing Data") }
  assert_eq(sheet.charts().length(), 1)
  let replayed_chart = sheet.charts()[0]
  assert_eq(replayed_chart.reference, "E2")
  assert_eq(@inspect.chart_kinds(replayed_chart.xml), ["lineChart"])
  assert_eq(@inspect.chart_title(replayed_chart.xml), Some("By quarter"))
  let series = @inspect.chart_series(replayed_chart.xml)
  assert_eq(series.length(), 1)
  assert_eq(series[0].name, Some("Revenue"))
  assert_eq(series[0].categories, Some("'Data'!A2:A3"))
  assert_eq(series[0].values, Some("'Data'!B2:B3"))
  let d2 = @dump.dump_xlsx_workbook(
    replayed,
    source_file="charted.xlsx",
    source_bytes=1,
  )
  assert_eq(dump_ops(d1), dump_ops(d2))
  assert_eq(dump_residual(d1), dump_residual(d2))
}

///|
test "a batch chart on a bang-named sheet remains replayable" {
  let source = @xlsx.Workbook::new()
  ignore(source.add_sheet("Bang!"))
  let script = Json::object({
    "schema": Json::string("xlsx.batch/2"),
    "ops": Json::array([
      Json::object({
        "op": Json::string("chart"),
        "params": Json::object({
          "sheet": Json::string("Bang!"),
          "anchor": Json::string("E2"),
          "type": Json::string("line"),
          "categories": Json::string("A1:A2"),
          "values": Json::string("B1:B2"),
        }),
      }),
    ]),
  })
  for op in @batch.parse_script(script) {
    @batch.apply_op(source, op)
  }
  let d1 = @dump.dump_xlsx_workbook(
    @xlsx.read(@xlsx.write(source)),
    source_file="bang.xlsx",
    source_bytes=1,
  )
  assert_true(dump_ops(d1).contains("\"categories\":\"A1:A2\""))
  assert_true(dump_ops(d1).contains("\"values\":\"B1:B2\""))
  assert_false(dump_residual(d1).contains("xlsx.charts_not_dumped"))
  let d2 = @dump.dump_xlsx_workbook(
    @xlsx.read(@xlsx.write(@dump.replay_xlsx_dump(d1))),
    source_file="bang.xlsx",
    source_bytes=1,
  )
  assert_eq(dump_ops(d1), dump_ops(d2))
  assert_eq(dump_residual(d1), dump_residual(d2))
}

///|
test "non-batch chart formulas become a residual instead of aborting dump" {
  let source = @xlsx.Workbook::new()
  ignore(source.add_sheet("Data"))
  let options = @xlsx.ChartOptions::new(Line)
  options.series.push(@xlsx.ChartSeries::new("CategoryName", "ValueName"))
  source.add_chart_with_options("Data", "E2", options)
  let envelope = @dump.dump_xlsx_workbook(
    @xlsx.read(@xlsx.write(source)),
    source_file="named-formulas.xlsx",
    source_bytes=1,
  )
  assert_false(dump_ops(envelope).contains("\"op\":\"chart\""))
  assert_true(dump_residual(envelope).contains("xlsx.charts_not_dumped"))
}

///|
test "unqualified SDK chart ranges are not misclassified as batch-authored" {
  let source = @xlsx.Workbook::new()
  ignore(source.add_sheet("Data"))
  let options = @xlsx.ChartOptions::new(Line)
  options.series.push(@xlsx.ChartSeries::new("A1:A2", "B1:B2"))
  source.add_chart_with_options("Data", "E2", options)
  let envelope = @dump.dump_xlsx_workbook(
    @xlsx.read(@xlsx.write(source)),
    source_file="unqualified.xlsx",
    source_bytes=1,
  )
  assert_false(dump_ops(envelope).contains("\"op\":\"chart\""))
  assert_true(dump_residual(envelope).contains("xlsx.charts_not_dumped"))
}

///|
test "custom chart frame metadata prevents lossy chart op emission" {
  let source = @xlsx.Workbook::new()
  ignore(source.add_sheet("Data"))
  let options = @xlsx.ChartOptions::new(Line)
  options.series.push(@xlsx.ChartSeries::new("'Data'!A1:A2", "'Data'!B1:B2"))
  source.add_chart_with_options("Data", "E2", options)
  let archive = @zip.read(@xlsx.write(source))
  let drawing_path = "xl/drawings/drawing1.xml"
  guard archive.get(drawing_path) is Some(drawing_bytes) else {
    fail("missing chart drawing")
  }
  let drawing = @utf8.decode(drawing_bytes)
  let customized = drawing.replace(
    old="name=\"Chart 1\"/>",
    new="name=\"Custom chart\" descr=\"Accessible chart\"/>",
  )
  assert_false(customized == drawing)
  assert_true(archive.replace(drawing_path, @utf8.encode(customized)))
  let file_backed = @xlsx.read(@zip.write(archive))
  guard file_backed.sheet("Data") is Some(sheet) else { fail("missing Data") }
  assert_false(sheet.charts()[0].drawing_frame_is_canonical())
  let envelope = @dump.dump_xlsx_workbook(
    file_backed,
    source_file="custom-frame.xlsx",
    source_bytes=1,
  )
  assert_false(dump_ops(envelope).contains("\"op\":\"chart\""))
  assert_true(dump_residual(envelope).contains("xlsx.charts_not_dumped"))
}

///|
test "every advertised batch chart type dumps and aliases canonicalize" {
  let source = @xlsx.Workbook::new()
  ignore(source.add_sheet("Data"))
  let cases : Array[(String, String, String)] = [
    ("col", "col", "E2"),
    ("column", "col", "E20"),
    ("bar", "bar", "K2"),
    ("line", "line", "K20"),
    ("pie", "pie", "Q2"),
    ("area", "area", "Q20"),
    ("scatter", "scatter", "W2"),
    ("doughnut", "doughnut", "W20"),
    ("donut", "doughnut", "AC2"),
    ("radar", "radar", "AC20"),
  ]
  for chart_case in cases {
    let (input_type, _, anchor) = chart_case
    let script = Json::object({
      "schema": Json::string("xlsx.batch/2"),
      "ops": Json::array([
        Json::object({
          "op": Json::string("chart"),
          "params": Json::object({
            "sheet": Json::string("Data"),
            "anchor": Json::string(anchor),
            "type": Json::string(input_type),
            "categories": Json::string("A1:A3"),
            "values": Json::string("B1:B3"),
          }),
        }),
      ]),
    })
    for op in @batch.parse_script(script) {
      @batch.apply_op(source, op)
    }
  }
  let file_backed = @xlsx.read(@xlsx.write(source))
  guard file_backed.sheet("Data") is Some(source_sheet) else {
    fail("missing file-backed Data")
  }
  assert_eq(source_sheet.charts().length(), cases.length())
  let d1 = @dump.dump_xlsx_workbook(
    file_backed,
    source_file="chart-types.xlsx",
    source_bytes=1,
  )
  let ops = dump_ops(d1)
  let mut chart_ops = 0
  for op in d1.ops {
    if op.stringify().contains("\"op\":\"chart\"") {
      chart_ops += 1
    }
  }
  assert_eq(chart_ops, cases.length())
  for chart_case in cases {
    let (_, canonical_type, anchor) = chart_case
    assert_true(
      ops.contains("\"anchor\":\"\{anchor}\",\"type\":\"\{canonical_type}\""),
    )
  }
  assert_false(dump_residual(d1).contains("xlsx.charts_not_dumped"))
  let replayed = @xlsx.read(@xlsx.write(@dump.replay_xlsx_dump(d1)))
  guard replayed.sheet("Data") is Some(replayed_sheet) else {
    fail("missing replayed Data")
  }
  assert_eq(replayed_sheet.charts().length(), cases.length())
  let d2 = @dump.dump_xlsx_workbook(
    replayed,
    source_file="chart-types.xlsx",
    source_bytes=1,
  )
  assert_eq(dump_ops(d1), dump_ops(d2))
  assert_eq(dump_residual(d1), dump_residual(d2))
}

///|
test "charts outside the batch-authored subset retain a bounded residual" {
  let source = @xlsx.Workbook::new()
  ignore(source.add_sheet("Data"))
  let options = @xlsx.ChartOptions::new(Col)
  options.series.push(
    @xlsx.ChartSeries::new("Data!A1:A2", "Data!B1:B2", name="one"),
  )
  options.series.push(
    @xlsx.ChartSeries::new("Data!A1:A2", "Data!C1:C2", name="two"),
  )
  source.add_chart_with_options("Data", "E2", options)
  let envelope = @dump.dump_xlsx_workbook(
    @xlsx.read(@xlsx.write(source)),
    source_file="unsupported-chart.xlsx",
    source_bytes=1,
  )
  let document = envelope.to_json_document().stringify()
  assert_false(document.contains("\"op\":\"chart\""))
  assert_true(document.contains("xlsx.charts_not_dumped"))
  assert_true(document.contains("1 not yet covered by the dump"))
}

///|
test "historical v1 XLSX dumps remain replayable" {
  let source = @xlsx.Workbook::new()
  ignore(source.add_sheet("Data"))
  source.set_cell("Data", "A1", "legacy")
  source.set_cell_int("Data", "B1", 7)
  let current = @dump.dump_xlsx_workbook(
    source,
    source_file="legacy.xlsx",
    source_bytes=1,
  )
  let historical = { ..current, batch_schema: "xlsx.batch/1" }
  let replayed = @dump.replay_xlsx_dump(historical)
  assert_eq(replayed.get_cell_value("Data", "A1"), Some("legacy"))
  assert_eq(replayed.get_cell_value("Data", "B1"), Some("7"))
}

///|
test "the canonical probe replays to an identical dump" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "x")
  workbook.set_cell_int("Data", "B1", 7)
  workbook.set_cell_formula("Data", "C1", "B1*2")
  let d1 = @dump.dump_xlsx_workbook(
    workbook,
    source_file="p.xlsx",
    source_bytes=1,
  )
  let d2 = @dump.dump_xlsx_workbook(
    @dump.replay_xlsx_dump(d1),
    source_file="p.xlsx",
    source_bytes=1,
  )
  assert_eq(dump_ops(d1), dump_ops(d2))
}

///|
test "the shared chunking policy splits on both op and style ceilings" {
  // op-count ceiling: 10001 plain ops -> 10000 + 1
  let plain : Array[Json] = []
  for _ in 0..<10001 {
    plain.push(Json::object({ "op": Json::string("set") }))
  }
  let by_ops = @dump.xlsx_dump_op_chunks(plain)
  assert_eq(by_ops.length(), 2)
  assert_eq(by_ops[0].length(), 10000)
  assert_eq(by_ops[1].length(), 1)
  // new-style ceiling: 4097 style ops -> 4096 + 1, even though well under
  // the op ceiling
  let styles : Array[Json] = []
  for _ in 0..<4097 {
    styles.push(Json::object({ "op": Json::string("style") }))
  }
  let by_styles = @dump.xlsx_dump_op_chunks(styles)
  assert_eq(by_styles.length(), 2)
  assert_eq(by_styles[0].length(), 4096)
  assert_eq(by_styles[1].length(), 1)
  // a highlighted cf op mints a dxf at parse time, so it counts against
  // the style budget exactly like a style op; an unhighlighted one (a
  // color scale) does not
  let highlighted : Array[Json] = []
  for _ in 0..<4097 {
    highlighted.push(
      Json::object({
        "op": Json::string("cf"),
        "params": Json::object({
          "sheet": Json::string("Data"),
          "range": Json::string("A1:A5"),
          "type": Json::string("cell"),
          "criteria": Json::string(">"),
          "value": Json::string("5"),
          "fill": Json::string("FFCC00"),
        }),
      }),
    )
  }
  let by_cf = @dump.xlsx_dump_op_chunks(highlighted)
  assert_eq(by_cf.length(), 2)
  assert_eq(by_cf[0].length(), 4096)
  assert_eq(by_cf[1].length(), 1)
  // and the first chunk must actually satisfy the batch parser's budget
  ignore(
    @batch.parse_script(
      Json::object({
        "schema": Json::string("xlsx.batch/1"),
        "ops": Json::array(by_cf[0]),
      }),
    ),
  )
  let plain_cf : Array[Json] = []
  for _ in 0..<4097 {
    plain_cf.push(
      Json::object({
        "op": Json::string("cf"),
        "params": Json::object({
          "sheet": Json::string("Data"),
          "range": Json::string("A1:A5"),
          "type": Json::string("2_color_scale"),
          "min_color": Json::string("FF0000"),
          "max_color": Json::string("00FF00"),
        }),
      }),
    )
  }
  assert_eq(@dump.xlsx_dump_op_chunks(plain_cf).length(), 1)
}

///|
test "a dump spanning a chunk boundary still replays" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  // enough cells to force the dump op stream across the 10000-op ceiling,
  // so replay must apply it in the same chunks the self-check validated
  for row in 1..<=10_050 {
    workbook.set_cell("Data", "A\{row}", "v\{row}")
  }
  let d1 = @dump.dump_xlsx_workbook(
    workbook,
    source_file="big.xlsx",
    source_bytes=1,
  )
  assert_true(d1.ops.length() > 10_000)
  let replayed = @dump.replay_xlsx_dump(d1)
  assert_true(replayed.get_cell_value("Data", "A10050") is Some("v10050"))
  let d2 = @dump.dump_xlsx_workbook(
    replayed,
    source_file="big.xlsx",
    source_bytes=1,
  )
  assert_eq(dump_ops(d1), dump_ops(d2))
}

///|
test "replay rejects an unexpected batch schema even with no ops" {
  let envelope : @dump.DumpEnvelope = {
    format: "xlsx",
    source_file: "s.xlsx",
    source_bytes: 1,
    source_sha256: None,
    batch_schema: "xlsx.batch/3",
    create_sheet: Some("Start"),
    ops: [],
    assets: {},
    residual: [],
    warnings: [],
  }
  try ignore(@dump.replay_xlsx_dump(envelope)) catch {
    @dump.ReplayInvalidFormat(message) =>
      assert_eq(
        message, "unsupported XLSX batch schema 'xlsx.batch/3' (accepted: xlsx.batch/1, xlsx.batch/2)",
      )
    error => fail("expected ReplayInvalidFormat")
  } noraise {
    _ => fail("expected replay to reject an unexpected batch schema")
  }
}

///|
test "replay rejects a non-xlsx envelope" {
  let envelope : @dump.DumpEnvelope = {
    format: "docx",
    source_file: "d.docx",
    source_bytes: 1,
    source_sha256: None,
    batch_schema: "docx.batch/2",
    create_sheet: None,
    ops: [],
    assets: {},
    residual: [],
    warnings: [],
  }
  try ignore(@dump.replay_xlsx_dump(envelope)) catch {
    @dump.ReplayInvalidFormat(_) => ()
    error => fail("expected ReplayInvalidFormat")
  } noraise {
    _ => fail("expected replay to reject a docx envelope")
  }
}
