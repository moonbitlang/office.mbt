///|
test "validate and issues generated help expose bounded flags" {
  let validate_help = validate_command().render_help()
  assert_true(validate_help.contains("<file>"))
  assert_true(validate_help.contains("--json"))
  assert_true(validate_help.contains("--jsonl"))
  assert_false(validate_help.to_lower().contains("ppt"))
  let issues_help = issues_command().render_help()
  assert_true(issues_help.contains("<file>"))
  assert_true(issues_help.contains("--jsonl"))
}

///|
async test "issues scan reports cached formula error values with locations" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-validate-scan-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let workbook = @xlsx.Workbook::new()
    let sheet = workbook.add_sheet("Data")
    sheet.set_cell_value("A1", Numeric(1.0))
    sheet.set_cell_formula("B2", "1/0")
    sheet.set_cell_value("B2", Error("#DIV/0!"))
    let path = directory + "/scan.xlsx"
    @afs.write_file(
      path,
      @xlsx.write(workbook),
      create_mode=CreateNew,
      permission=0o600,
    )
    let source = read_office_package(path)
    let findings : Array[OfficeFinding] = []
    office_xlsx_formula_findings(source, findings)
    assert_true(findings.length() == 1)
    assert_true(findings[0].severity == "warning")
    assert_true(findings[0].code == "office.xlsx.formula_error_value")
    assert_true(findings[0].location is Some("Data!B2"))
    assert_true(findings[0].message.contains("#DIV/0!"))
  }
}

///|
async test "validate gate findings are empty for a freshly written workbook" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-validate-gate-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("Sheet1"))
    let path = directory + "/clean.xlsx"
    @afs.write_file(
      path,
      @xlsx.write(workbook),
      create_mode=CreateNew,
      permission=0o600,
    )
    let source = read_office_package(path)
    let findings = office_package_gate_findings(source)
    assert_true(findings is [])
  }
}
