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
    // rewrite the stored cell so the formula caches a real t="e" error
    // value, the shape Excel produces (set_cell_value would clear the
    // formula and turn this into a literal, non-actionable error cell)
    let tampered = rebuild_package_part(
      @xlsx.write(workbook),
      "xl/worksheets/sheet1.xml",
      text => {
        text
        .replace(old="<c r=\"B2\"", new="<c t=\"e\" r=\"B2\"")
        .replace(old="<f>1/0</f>", new="<f>1/0</f><v>#DIV/0!</v>")
      },
    )
    let path = write_probe_package(directory, "scan.xlsx", tampered)
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

///|
/// Rebuilds one part of a written package at the byte level so the result
/// still flows through the bounded CLI read path.
fn rebuild_package_part(
  bytes : Bytes,
  part : String,
  transform : (String) -> String,
) -> Bytes raise {
  let archive = @zip.read(bytes)
  let text = match archive.get(part) {
    Some(value) => @utf8.decode_lossy(value.data())
    None => fail("missing part: \{part}")
  }
  let rebuilt = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() != part {
      rebuilt.add(entry.name(), entry.data())
    }
  }
  rebuilt.add(part, @utf8.encode(transform(text)))
  @zip.write(rebuilt)
}

///|
async fn write_probe_package(
  directory : String,
  name : String,
  bytes : Bytes,
) -> String {
  let path = directory + "/" + name
  @afs.write_file(path, bytes, create_mode=CreateNew, permission=0o600)
  path
}

///|
/// A dangling relationship is rejected by the strict structural detector
/// before the gate runs (deterministic office.invalid_package), and the
/// non-zero validate verdict carries the complete record in its details.
async test "dangling relationships classify at the detector and the failure envelope is complete" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-validate-dangling-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("Sheet1"))
    let tampered = rebuild_package_part(
      @xlsx.write(workbook),
      "xl/_rels/workbook.xml.rels",
      text => {
        text.replace(
          old="</Relationships>",
          new="<Relationship Id=\"rIdGone\" Type=\"http://example.invalid/unknown\" Target=\"missing/part.bin\"/></Relationships>",
        )
      },
    )
    let path = write_probe_package(directory, "dangling.xlsx", tampered)
    let outcome : Result[OfficeReadPackage, Error] = Ok(
      read_office_package(path),
    ) catch {
      e => Err(e)
    }
    guard outcome is Err(CliFailure(error)) else {
      fail("expected the structural detector to reject the dangling target")
    }
    assert_true(error.code == "office.invalid_package")

    // envelope completeness: error findings ride in validation_failed details
    let clean = @xlsx.Workbook::new()
    ignore(clean.add_sheet("Sheet1"))
    let clean_path = write_probe_package(
      directory,
      "clean.xlsx",
      @xlsx.write(clean),
    )
    let source = read_office_package(clean_path)
    let findings = [
      office_finding("error", "office.xlsx.package", "probe finding"),
    ]
    let data = office_validate_data(
      @lib.SCHEMA_VALIDATE_RESULT,
      source,
      findings,
    )
    guard office_validation_failure(source, 1, data) is CliFailure(failure) else {
      fail("expected a validation failure value")
    }
    assert_true(failure.code == "office.validation_failed")
    guard failure.details is Some(Object(details)) else {
      fail("expected complete details")
    }
    assert_true(details.get("schema") is Some(String("office.validate/1")))
    assert_true(details.get("valid") is Some(False))
    assert_true(details.get("error_count") is Some(Number(_)))
    guard details.get("findings") is Some(Array(entries)) else {
      fail("expected findings array")
    }
    assert_true(entries.length() == 1)
  }
}

///|
/// Only formula-backed error cells are actionable findings; literal error
/// cells are ignored, and the report cap emits an omission marker.
async test "formula scan requires formulas and bounds its report" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-validate-formula-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let workbook = @xlsx.Workbook::new()
    let sheet = workbook.add_sheet("Data")
    sheet.set_cell_value("A1", Numeric(1.0))
    // build 70 formula cells plus one literal (formula-free) error cell,
    // then rewrite the sheet XML so every formula caches t="e" #DIV/0!
    for row in 1..<=70 {
      sheet.set_cell_formula("B\{row}", "1/0")
    }
    let tampered = rebuild_package_part(
      @xlsx.write(workbook),
      "xl/worksheets/sheet1.xml",
      text => {
        text
        .replace_all(old="<c r=\"B", new="<c t=\"e\" r=\"B")
        .replace_all(old="<f>1/0</f>", new="<f>1/0</f><v>#DIV/0!</v>")
        .replace(
          old="</sheetData>",
          new="<row r=\"80\"><c r=\"C80\" t=\"e\"><v>#NAME?</v></c></row></sheetData>",
        )
      },
    )
    let path = write_probe_package(directory, "formulas.xlsx", tampered)
    let source = read_office_package(path)
    let findings : Array[OfficeFinding] = []
    office_xlsx_formula_findings(source, findings)
    let mut reported = 0
    let mut omission_markers = 0
    for finding in findings {
      if finding.code == "office.xlsx.formula_error_value" {
        reported += 1
        assert_false(finding.location is Some("Data!C80"))
      }
      if finding.code == "office.xlsx.formula_findings_omitted" {
        omission_markers += 1
      }
    }
    assert_true(reported == office_issues_max_formula_findings)
    assert_true(omission_markers == 1)
  }
}

///|
/// Cancellation raised inside the bounded scan propagates as the protocol
/// cancellation failure instead of being swallowed.
async test "formula scan propagates cancellation" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-validate-cancel-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let workbook = @xlsx.Workbook::new()
    let sheet = workbook.add_sheet("Data")
    sheet.set_cell_value("A1", Numeric(1.0))
    sheet.set_cell_value("AZ4000", Numeric(2.0))
    let path = write_probe_package(
      directory,
      "cancel.xlsx",
      @xlsx.write(workbook),
    )
    let source = read_office_package(path)
    let findings : Array[OfficeFinding] = []
    let mut polls = 0
    let cancelled = () => {
      polls += 1
      polls > 2
    }
    let outcome : Result[Unit, Error] = Ok(
      office_xlsx_formula_findings(source, findings, cancelled~),
    ) catch {
      e => Err(e)
    }
    assert_true(outcome is Err(_))
  }
}

///|
/// An orphaned comment marker in the document body is a bounded, actionable
/// DOCX warning finding.
async test "docx issues report annotation warnings" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-validate-docx-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let tampered = rebuild_package_part(
      @word.new_blank_docx(),
      "word/document.xml",
      text => {
        text.replace(
          old="<w:body>",
          new="<w:body><w:p><w:commentRangeStart w:id=\"5\"/><w:r><w:t>marked</w:t></w:r><w:commentRangeEnd w:id=\"5\"/><w:r><w:commentReference w:id=\"5\"/></w:r></w:p>",
        )
      },
    )
    let path = write_probe_package(directory, "orphan.docx", tampered)
    let source = read_office_package(path)
    let findings : Array[OfficeFinding] = []
    office_docx_reader_findings(source, findings)
    let mut annotation_warnings = 0
    for finding in findings {
      assert_true(finding.severity == "warning")
      assert_true(finding.code.has_prefix("office.docx."))
      if finding.code == "office.docx.annotation_warning" {
        annotation_warnings += 1
      }
    }
    // the orphaned marker yields exactly one specifically coded annotation
    // warning; annotation texts are never double-counted as generic
    // reader diagnostics
    assert_true(annotation_warnings == 1)
  }
}

///|
/// Human rendering neutralizes control characters from attacker-derived
/// finding text.
test "human findings are terminal-safe" {
  let findings = [
    office_finding(
      "warning",
      "office.test.finding",
      "line\nbreak\u{1b}[31mesc",
      location="Sheet\u{7}1!A1",
    ),
  ]
  // human_text is the same sanitizer the rest of the CLI uses; assert the
  // renderer routes both message and location through it
  let message = human_text(findings[0].message, office_finding_message_chars)
  assert_false(message.contains("\n"))
  assert_false(message.contains("\u{1b}"))
  let location = human_text(findings[0].location.unwrap(), 160)
  assert_false(location.contains("\u{7}"))
  office_render_findings_human(findings)
}
