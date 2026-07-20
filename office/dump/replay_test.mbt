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
/// Builds a workbook exercising every op family the dump emits.
fn fixpoint_workbook() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  ignore(workbook.add_sheet("Extra"))
  workbook.set_cell("Data", "A1", "Region")
  workbook.set_cell("Data", "B1", "Sales")
  workbook.set_cell("Data", "A2", "East")
  workbook.set_cell_int("Data", "B2", 30)
  workbook.set_cell_bool("Data", "C2", true)
  workbook.set_cell_formula("Data", "B3", "SUM(B2:B2)")
  workbook.merge_cells("Data", "A5:B5")
  workbook.set_col_width("Data", 1, 18.0)
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
  workbook
}

///|
test "dump then replay then dump is a fixpoint on the op stream" {
  let source = fixpoint_workbook()
  let d1 = @dump.dump_xlsx_workbook(
    source,
    source_file="fixpoint.xlsx",
    source_bytes=1,
  )
  // replay the dump into a fresh workbook using the same engine, then dump
  // that — the op stream and residuals must be stable
  let replayed = @dump.replay_xlsx_dump(d1)
  let d2 = @dump.dump_xlsx_workbook(
    replayed,
    source_file="fixpoint.xlsx",
    source_bytes=1,
  )
  assert_eq(dump_ops(d1), dump_ops(d2))
  assert_eq(dump_residual(d1), dump_residual(d2))
  // and the replayed workbook actually carries the content
  assert_true(replayed.get_cell_value("Data", "A1") is Some("Region"))
  assert_true(replayed.get_sheet_list().length() == 2)
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
test "replay rejects a non-xlsx envelope" {
  let envelope : @dump.DumpEnvelope = {
    format: "docx",
    source_file: "d.docx",
    source_bytes: 1,
    source_sha256: None,
    batch_schema: "docx.batch/2",
    create_sheet: None,
    ops: [],
    residual: [],
    warnings: [],
  }
  try ignore(@dump.replay_xlsx_dump(envelope)) catch {
    @dump.ReplayInvalidFormat(_) => ()
    error => fail("expected ReplayInvalidFormat, got \{error}")
  } noraise {
    _ => fail("expected replay to reject a docx envelope")
  }
}
