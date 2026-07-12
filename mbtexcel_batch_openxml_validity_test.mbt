///|
/// Ground-truth gate for the batch engine: a workbook produced through
/// the real `xlsx.batch/1` parse + apply path (not the individual library
/// calls) must satisfy the .NET DocumentFormat.OpenXml validator, the
/// same oracle the other root validity tests use. Exercises the full op
/// vocabulary — the original nine plus the authoring ops `cf` (all four
/// visual families, including an x14 extended data bar), `table`, and
/// `validate` — so the validator proves each
/// produces schema-valid OOXML, not just structurally-sound XML.
#cfg(target="native")
async test "mbtexcel batch-built workbook is OpenXML-valid" {
  let workbook = @mbtexcel.new_workbook()
  ignore(workbook.add_sheet("Data"))
  let script =
    #|{
    #|  "schema": "xlsx.batch/1",
    #|  "ops": [
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "A1", "value": "Region"}},
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "B1", "value": "Sales"}},
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "A2", "value": "East"}},
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "B2", "value": 120}},
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "A3", "value": "West"}},
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "B3", "value": 87.5}},
    #|    {"op": "set", "params": {"sheet": "Data", "cell": "C2", "value": true}},
    #|    {"op": "formula", "params": {"sheet": "Data", "cell": "B4", "formula": "=SUM(B2:B3)"}},
    #|    {"op": "style", "params": {"sheet": "Data", "range": "A1:B1", "bold": true, "fill": "4472C4", "font_color": "FFFFFF", "align": "center", "border": "thin", "border_bottom": "medium", "border_color": "1F3864"}},
    #|    {"op": "style", "params": {"sheet": "Data", "range": "B2:B4", "number_format": "#,##0.00"}},
    #|    {"op": "merge", "params": {"sheet": "Data", "range": "A6:B6"}},
    #|    {"op": "width", "params": {"sheet": "Data", "column": "A:B", "width": 14}},
    #|    {"op": "freeze", "params": {"sheet": "Data", "cell": "A2"}},
    #|    {"op": "filter", "params": {"sheet": "Data", "range": "A1:B3"}},
    #|    {"op": "add-sheet", "params": {"name": "Summary"}},
    #|    {"op": "chart", "params": {"sheet": "Data", "anchor": "E2", "type": "col", "categories": "A2:A3", "values": "B2:B3", "name": "Sales", "title": "By region"}},
    #|    {"op": "cf", "params": {"sheet": "Data", "range": "B2:B4", "type": "3_color_scale", "min_color": "F8696B", "mid_color": "FFEB84", "max_color": "63BE7B"}},
    #|    {"op": "cf", "params": {"sheet": "Data", "range": "B2:B4", "type": "cell", "criteria": ">=", "value": "100", "fill": "C6EFCE", "font_color": "006100"}},
    #|    {"op": "cf", "params": {"sheet": "Data", "range": "B2:B4", "type": "data_bar", "bar_color": "638EC6"}},
    #|    {"op": "cf", "params": {"sheet": "Data", "range": "A2:A3", "type": "data_bar", "bar_color": "638EC6", "bar_solid": true, "bar_direction": "rightToLeft", "bar_border_color": "4472C4"}},
    #|    {"op": "cf", "params": {"sheet": "Data", "range": "B2:B4", "type": "icon_set", "icon_style": "3TrafficLights1"}},
    #|    {"op": "set", "params": {"sheet": "Summary", "cell": "A1", "value": "Item"}},
    #|    {"op": "set", "params": {"sheet": "Summary", "cell": "B1", "value": "Count"}},
    #|    {"op": "table", "params": {"sheet": "Summary", "range": "A1:B4", "name": "Items", "style": "TableStyleMedium2"}},
    #|    {"op": "validate", "params": {"sheet": "Summary", "range": "D2:D20", "type": "list", "values": ["Low", "High"]}}
    #|  ]
    #|}
  let ops = @batch.parse_script(@json.parse(script))
  for op in ops {
    @batch.apply_op(workbook, op)
  }
  let bytes = @mbtexcel.write(workbook)

  // Structural sanity before the heavyweight oracle.
  let problems = @xlsx.validate_ooxml_package(bytes)
  if problems.length() != 0 {
    fail("structural validation failed: \{to_repr(problems)}")
  }
  let stamp = @env.now()
    .to_string()
    .replace(old=":", new="_")
    .replace(old=" ", new="_")
  let out_dir = "_build/xlsx_validate_batch/\{stamp}"
  @async/fs.mkdir(out_dir, permission=0o755, recursive=true) catch {
    err => fail("mkdir failed: \{err}")
  }
  let path = "\{out_dir}/batch_openxml_valid.xlsx"
  @async/fs.write_file(
    path,
    bytes,
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
    err => fail("write xlsx failed: \{err}")
  }
  let (code, stdout, stderr) = @process.collect_output("bash", [
    "-lc",
    "scripts/validate_xlsx.sh \"\{path}\"",
  ])
  if code != 0 {
    let out = stdout.text() catch { _ => "<non-utf8 stdout>" }
    let err = stderr.text() catch { _ => "<non-utf8 stderr>" }
    fail(
      "OpenXML validation failed (exit=\{code}) for \{path}\nstdout:\n\{out}\nstderr:\n\{err}",
    )
  }
  @async/fs.remove(path) catch {
    _ => ()
  }
}
