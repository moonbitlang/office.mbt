///|
#cfg(target = "native")
async test "mbtexcel mutation-heavy workbook remains OpenXML-valid" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Data"))

  workbook.set_cell("Sheet1", "A1", "Name")
  workbook.set_cell("Sheet1", "B1", "Qty")
  workbook.set_cell("Sheet1", "C1", "Link")
  workbook.set_cell("Sheet1", "A2", "alpha")
  workbook.set_cell_int("Sheet1", "B2", 11)
  workbook.set_cell("Sheet1", "C2", "alpha link")
  workbook.set_cell("Sheet1", "A3", "beta")
  workbook.set_cell_int("Sheet1", "B3", 22)
  workbook.set_cell("Sheet1", "C3", "beta link")
  workbook.set_cell("Sheet1", "A4", "gamma")
  workbook.set_cell_int("Sheet1", "B4", 33)
  workbook.set_cell("Sheet1", "C4", "gamma link")
  ignore(
    workbook.add_table_with_columns("Sheet1", "A1:C4", "TableMut", [
      "Name", "Qty", "Link",
    ]),
  )
  workbook.set_cell_hyperlink(
    "Sheet1",
    "C2",
    "https://example.com/a",
    External,
    display="alpha",
  )
  workbook.set_cell_hyperlink(
    "Sheet1",
    "C3",
    "https://example.com/b",
    External,
    display="beta",
  )
  workbook.merge_cell("Sheet1", "A5", "B5")
  workbook.set_cell("Sheet1", "A5", "merged-total")
  let cf = @xlsx.ConditionalFormatOptions::new("cell")
  cf.criteria = ">"
  cf.value = "20"
  workbook.set_conditional_format("Sheet1", "B2:B4", [cf])

  workbook.insert_rows("Sheet1", 2, 2)
  workbook.insert_cols("Sheet1", 2, 1)
  workbook.remove_rows("Sheet1", 4, 1)
  workbook.remove_cols("Sheet1", 3, 1)
  workbook.duplicate_row_to("Sheet1", 3, 8)

  workbook.set_cell("Data", "A1", "ref")
  workbook.set_defined_name(@xlsx.DefinedName::new("MutRef", "Data!$A$1"))

  let bytes = write(workbook)
  let parsed = read(bytes)
  inspect(parsed.get_cell("Data", "A1"), content="Some(\"ref\")")

  let stamp = @env.now()
    .to_string()
    .replace(old=":", new="_")
    .replace(old=" ", new="_")
  let out_dir = "_build/xlsx_validate_mutations/\{stamp}"
  @async/fs.mkdir(out_dir, permission=0o755, recursive=true) catch {
    err => fail("mkdir failed: \{err}")
  }
  let path = "\{out_dir}/mutations_openxml_valid.xlsx"
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
