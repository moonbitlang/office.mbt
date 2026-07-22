///|
/// End-to-end nets for XLSX bounded row repetition (#207 R2): the happy
/// invoice path, final coordinates under multiple regions, the strict
/// refusal matrix, allow-missing semantics, and the ownership split
/// between the scalar pass and the region pass.

///|
async fn with_region_dir(run : async (String) -> Unit) -> Unit {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-xlsx-regions-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    run(directory)
  }
}

///|
/// header (title with a scalar placeholder), one template row, a footer
/// label below — the smallest realistic repetition shape.
fn region_fixture() -> Bytes raise {
  let workbook = @engine.Workbook::new()
  let sheet = workbook.add_sheet("Items")
  sheet.set_cell_value("A1", @engine.CellValue::String("Invoice {{company}}"))
  sheet.set_cell_value("A2", @engine.CellValue::String("{{item}}"))
  sheet.set_cell_value("B2", @engine.CellValue::String("{{qty}}"))
  sheet.set_cell_value("C2", @engine.CellValue::String("unit"))
  sheet.set_cell_value("A3", @engine.CellValue::String("footer"))
  @engine.write(workbook)
}

///|
fn region_data(records : String) -> @template.TemplateData raise {
  @template.parse_template_document(
    "{\"schema\": \"office.template.data/1\", " +
    "\"values\": {\"company\": \"ACME\"}, " +
    "\"regions\": {\"items\": {\"sheet\": \"Items\", \"row\": 2, \"records\": [" +
    records +
    "]}}}",
  )
}

///|
async test "region merge clones, fills, and shifts the footer" {
  with_region_dir() <| directory => {
    let input = directory + "/tpl.xlsx"
    @afs.write_file(
      input,
      region_fixture(),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/filled.xlsx"
    let result = @xlsx.transact_template_document(
      @transaction.transaction_options(input, output_path=output),
      region_data(
        "{\"item\": \"Widget\", \"qty\": 2}, " +
        "{\"item\": \"Gadget\", \"qty\": 3}, " +
        "{\"item\": \"Gizmo\", \"qty\": 5}",
      ),
      allow_missing=false,
    )
    assert_eq(result.regions.length(), 1)
    let outcome = result.regions[0]
    assert_eq(outcome.output_rows_start, 2)
    assert_eq(outcome.output_rows_count, 3)
    assert_eq(outcome.records, 3)
    // 2 placeholders per record row
    assert_eq(outcome.replaced, 6)
    // the scalar pass replaced the title and skipped the claimed row
    assert_eq(result.report.replaced, 7)
    assert_true(result.scalar_cells_skipped >= 2)
    assert_true(result.report.changed)
    // read the published workbook back
    let published = @engine.read(@afs.read_file(output).binary()[:])
    guard published.sheet("Items") is Some(sheet) else {
      fail("published sheet missing")
    }
    fn text_at(
      workbook : @engine.Workbook,
      reference : String,
    ) -> String raise {
      match workbook.get_cell_value_raw("Items", reference) {
        Some(String(value)) => value
        Some(Numeric(value)) => "num:\{value}"
        other => "other:\{to_repr(other)}"
      }
    }

    assert_eq(text_at(published, "A1"), "Invoice ACME")
    assert_eq(text_at(published, "A2"), "Widget")
    // whole-cell numeric placeholders keep their native type
    assert_eq(text_at(published, "B2"), "num:2")
    assert_eq(text_at(published, "A3"), "Gadget")
    assert_eq(text_at(published, "B3"), "num:3")
    assert_eq(text_at(published, "A4"), "Gizmo")
    // static cells clone with the row; the footer shifted below
    assert_eq(text_at(published, "C2"), "unit")
    assert_eq(text_at(published, "C4"), "unit")
    assert_eq(text_at(published, "A5"), "footer")
    ignore(sheet)
  }
}

///|
async test "two regions report final coordinates after upper insertions" {
  with_region_dir() <| directory => {
    let workbook = @engine.Workbook::new()
    let sheet = workbook.add_sheet("Data")
    sheet.set_cell_value("A2", @engine.CellValue::String("{{a}}"))
    sheet.set_cell_value("A6", @engine.CellValue::String("{{b}}"))
    let input = directory + "/two.xlsx"
    @afs.write_file(
      input,
      @engine.write(workbook),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/two-out.xlsx"
    let data = @template.parse_template_document(
      "{\"schema\": \"office.template.data/1\", \"values\": {}, \"regions\": {" +
      "\"upper\": {\"sheet\": \"Data\", \"row\": 2, \"records\": [{\"a\": 1}, {\"a\": 2}, {\"a\": 3}]}, " +
      "\"lower\": {\"sheet\": \"Data\", \"row\": 6, \"records\": [{\"b\": 10}, {\"b\": 20}]}}}",
    )
    let result = @xlsx.transact_template_document(
      @transaction.transaction_options(input, output_path=output),
      data,
      allow_missing=false,
    )
    assert_eq(result.regions.length(), 2)
    // document order preserved; upper stays, lower shifts by 2 inserted
    assert_eq(result.regions[0].name, "upper")
    assert_eq(result.regions[0].output_rows_start, 2)
    assert_eq(result.regions[0].output_rows_count, 3)
    assert_eq(result.regions[1].name, "lower")
    assert_eq(result.regions[1].output_rows_start, 8)
    assert_eq(result.regions[1].output_rows_count, 2)
    let published = @engine.read(@afs.read_file(output).binary()[:])
    match published.get_cell_value_raw("Data", "A8") {
      Some(Numeric(value)) => assert_eq(value, 10)
      other =>
        fail(
          "expected the lower region at its shifted row, got \{to_repr(other)}",
        )
    }
  }
}

///|
async fn expect_region_refusal(
  directory : String,
  fixture : Bytes,
  data_text : String,
  expected_detail_fragment : String,
) -> Unit {
  let input = directory + "/refuse.xlsx"
  @afs.write_file(input, fixture, create_mode=CreateNew, permission=0o600)
  let output = directory + "/refuse-out.xlsx"
  let data = @template.parse_template_document(data_text)
  try
    @xlsx.transact_template_document(
      @transaction.transaction_options(input, output_path=output),
      data,
      allow_missing=false,
    )
    |> ignore
  catch {
    @xlsx.XlsxTemplateRefused(report) => {
      assert_true(report.unsupported_total > 0 || report.missing_total > 0)
      let mut seen = false
      for finding in report.unsupported {
        if finding.detail.contains(expected_detail_fragment) {
          seen = true
        }
      }
      for finding in report.missing {
        if finding.detail.contains(expected_detail_fragment) {
          seen = true
        }
      }
      assert_true(seen)
    }
    error => fail("expected XlsxTemplateRefused, got \{error}")
  } noraise {
    _ => fail("expected refusal: " + expected_detail_fragment)
  }
  // nothing was published
  assert_false(@afs.exists(output))
}

///|
async test "region refusal matrix" {
  with_region_dir() <| directory => {
    let plain_data = "{\"schema\": \"office.template.data/1\", \"values\": {}, " +
      "\"regions\": {\"items\": {\"sheet\": \"Items\", \"row\": 2, \"records\": [{\"item\": \"x\", \"qty\": 1}]}}}"
    // a stored formula ANYWHERE refuses (v1 formula-free workbook)
    let with_formula = {
      let workbook = @engine.Workbook::new()
      let sheet = workbook.add_sheet("Items")
      sheet.set_cell_value("A2", @engine.CellValue::String("{{item}} {{qty}}"))
      ignore(workbook.add_sheet("Other"))
      workbook.set_cell_formula("Other", "B1", "1+1")
      @engine.write(workbook)
    }
    @afs.mkdir(directory + "/f") catch {
      _ => ()
    }
    expect_region_refusal(
      directory + "/f",
      with_formula,
      plain_data,
      "stored formula cell",
    )
    |> ignore
    // sequential subdirectories keep CreateNew happy
    for
      label, fixture_and_detail in {
        "name": (
          {
            let workbook = @engine.Workbook::new()
            let sheet = workbook.add_sheet("Items")
            sheet.set_cell_value(
              "A2",
              @engine.CellValue::String("{{item}} {{qty}}"),
            )
            workbook.set_defined_name(
              @engine.DefinedName::new("total_band", "Items!$A$2:$B$2"),
            )
            @engine.write(workbook)
          },
          "defined name",
        ),
        "comment": (
          {
            let workbook = @engine.Workbook::new()
            let sheet = workbook.add_sheet("Items")
            sheet.set_cell_value(
              "A2",
              @engine.CellValue::String("{{item}} {{qty}}"),
            )
            workbook.add_comment("Items", {
              cell: "D9",
              author: "a",
              author_id: None,
              text: "note",
              paragraph: [],
              width: None,
              height: None,
            })
            @engine.write(workbook)
          },
          "a comment on a sheet receiving inserted rows",
        ),
        "merge": (
          {
            let workbook = @engine.Workbook::new()
            let sheet = workbook.add_sheet("Items")
            sheet.set_cell_value(
              "A2",
              @engine.CellValue::String("{{item}} {{qty}}"),
            )
            workbook.merge_cells("Items", "A1:A3")
            @engine.write(workbook)
          },
          "multi-row merged range intersects",
        ),
        "table_row": (
          {
            let workbook = @engine.Workbook::new()
            let sheet = workbook.add_sheet("Items")
            sheet.set_cell_value(
              "A2",
              @engine.CellValue::String("{{item}} {{qty}}"),
            )
            @engine.write(workbook)
          },
          "table-row addressing applies to DOCX merges",
        ),
      } {
      let subdir = directory + "/" + label
      @afs.mkdir(subdir) catch {
        _ => ()
      }
      let data_text = if label == "table_row" {
        "{\"schema\": \"office.template.data/1\", \"values\": {}, " +
        "\"regions\": {\"items\": {\"path\": \"/docx/body/tbl[1]/tr[1]\", \"records\": [{\"item\": \"x\"}]}}}"
      } else {
        plain_data
      }
      let (fixture, detail) = fixture_and_detail
      expect_region_refusal(subdir, fixture, data_text, detail) |> ignore
    }
  }
}

///|
async test "missing record keys refuse strictly and publish under allow-missing" {
  with_region_dir() <| directory => {
    let input = directory + "/missing.xlsx"
    @afs.write_file(
      input,
      region_fixture(),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/missing-out.xlsx"
    // record 1 lacks qty
    let data = region_data(
      "{\"item\": \"Widget\", \"qty\": 2}, {\"item\": \"Gadget\"}",
    )
    try
      @xlsx.transact_template_document(
        @transaction.transaction_options(input, output_path=output),
        data,
        allow_missing=false,
      )
      |> ignore
    catch {
      @xlsx.XlsxTemplateRefused(report) => {
        assert_eq(report.missing_total, 1)
        let mut seen = false
        for finding in report.missing {
          if finding.detail == "record 1: qty" {
            seen = true
          }
        }
        assert_true(seen)
      }
      error => fail("expected XlsxTemplateRefused, got \{error}")
    } noraise {
      _ => fail("expected the missing record key to refuse")
    }
    assert_false(@afs.exists(output))
    // allow-missing publishes with the literal placeholder in that clone
    let relaxed = @xlsx.transact_template_document(
      @transaction.transaction_options(input, output_path=output),
      data,
      allow_missing=true,
    )
    assert_eq(relaxed.report.missing_total, 1)
    assert_true(relaxed.report.changed)
    let published = @engine.read(@afs.read_file(output).binary()[:])
    match published.get_cell_value_raw("Items", "B3") {
      Some(String(text)) => assert_eq(text, "{{qty}}")
      other => fail("expected the literal placeholder, got \{to_repr(other)}")
    }
  }
}

///|
async test "single-record regions fill in place without inserting" {
  with_region_dir() <| directory => {
    let input = directory + "/one.xlsx"
    @afs.write_file(
      input,
      region_fixture(),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/one-out.xlsx"
    let result = @xlsx.transact_template_document(
      @transaction.transaction_options(input, output_path=output),
      region_data("{\"item\": \"Solo\", \"qty\": 9}"),
      allow_missing=false,
    )
    assert_eq(result.regions[0].output_rows_count, 1)
    let published = @engine.read(@afs.read_file(output).binary()[:])
    match published.get_cell_value_raw("Items", "A3") {
      Some(String(text)) => assert_eq(text, "footer")
      other =>
        fail(
          "the footer must not shift for a single record, got \{to_repr(other)}",
        )
    }
  }
}

///|
async test "scalar-only documents behave exactly like transact_template" {
  with_region_dir() <| directory => {
    let workbook = @engine.Workbook::new()
    let sheet = workbook.add_sheet("Data")
    sheet.set_cell_value("A1", @engine.CellValue::String("Hello {{who}}"))
    let input = directory + "/scalar.xlsx"
    @afs.write_file(
      input,
      @engine.write(workbook),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/scalar-out.xlsx"
    let data = @template.parse_template_document(
      "{\"schema\": \"office.template.data/1\", \"values\": {\"who\": \"world\"}}",
    )
    let result = @xlsx.transact_template_document(
      @transaction.transaction_options(input, output_path=output),
      data,
      allow_missing=false,
    )
    assert_eq(result.regions.length(), 0)
    assert_eq(result.scalar_cells_skipped, 0)
    assert_eq(result.report.replaced, 1)
    let published = @engine.read(@afs.read_file(output).binary()[:])
    match published.get_cell_value_raw("Data", "A1") {
      Some(String(text)) => assert_eq(text, "Hello world")
      other => fail("expected the scalar substitution, got \{to_repr(other)}")
    }
  }
}

///|
async test "values keys used only inside regions are not reported unused" {
  with_region_dir() <| directory => {
    let workbook = @engine.Workbook::new()
    let sheet = workbook.add_sheet("Data")
    // "unit_label" resolves from values inside every clone; no scalar
    // cell references it
    sheet.set_cell_value(
      "A2",
      @engine.CellValue::String("{{item}} ({{unit_label}})"),
    )
    let input = directory + "/regiononly.xlsx"
    @afs.write_file(
      input,
      @engine.write(workbook),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/regiononly-out.xlsx"
    let data = @template.parse_template_document(
      "{\"schema\": \"office.template.data/1\", " +
      "\"values\": {\"unit_label\": \"pcs\"}, " +
      "\"regions\": {\"items\": {\"sheet\": \"Data\", \"row\": 2, \"records\": [" +
      "{\"item\": \"Widget\"}, {\"item\": \"Gadget\"}]}}}",
    )
    let result = @xlsx.transact_template_document(
      @transaction.transaction_options(input, output_path=output),
      data,
      allow_missing=false,
    )
    assert_eq(result.report.unused_total, 0)
    assert_eq(result.report.unused.length(), 0)
    let published = @engine.read(@afs.read_file(output).binary()[:])
    match published.get_cell_value_raw("Data", "A3") {
      Some(String(text)) => assert_eq(text, "Gadget (pcs)")
      other =>
        fail("expected the values fallback in the clone, got \{to_repr(other)}")
    }
  }
}
