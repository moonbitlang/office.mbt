///|
#cfg(target="native")
async test "xlsx writer generates OpenXML-valid package" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "Hello")
  workbook.set_cell_int("Sheet1", "B1", 123)
  workbook.set_cell_float("Sheet1", "C1", 3.14)
  workbook.set_cell_bool("Sheet1", "D1", true)
  workbook.set_cell_formula("Sheet1", "E1", "SUM(B1,1)", value="124")
  workbook.merge_cell("Sheet1", "A2", "B2")
  workbook.set_cell("Sheet1", "A2", "Merged")
  let style_id = workbook.add_style(@xlsx.Style::number_format("0.00"))
  workbook.set_cell_style("Sheet1", "C1", style_id)
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://example.com",
    External,
    display="Example",
  )
  let bytes = write(workbook)
  let stamp = @env.now()
    .to_string()
    .replace(old=":", new="_")
    .replace(old=" ", new="_")
  let out_dir = "_build/xlsx_validate/\{stamp}"
  @async/fs.mkdir(out_dir, permission=0o755, recursive=true) catch {
    err => fail("mkdir failed: \{err}")
  }
  let path = "\{out_dir}/openxml_valid.xlsx"
  @async/fs.write_file(path, bytes, create=0o644) catch {
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
