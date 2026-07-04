///|
/// Writes `bytes` to a temp file and validates it with the Microsoft
/// DocumentFormat.OpenXml SDK (via scripts/validate_xlsx.sh), failing
/// with the validator output when the package is not schema-valid.
#cfg(target="native")
async fn validate_via_sdk(dir : String, name : String, bytes : Bytes) -> Unit {
  let path = "\{dir}/\{name}.xlsx"
  @async/fs.write_file(
    path,
    bytes,
    create_mode=@async/fs.CreateOrTruncate,
    permission=0o644,
  ) catch {
    err => fail("write \{name} failed: \{err}")
  }
  let (code, stdout, stderr) = @process.collect_output("bash", [
    "-lc",
    "scripts/validate_xlsx.sh \"\{path}\"",
  ])
  if code != 0 {
    let out = stdout.text() catch { _ => "<non-utf8 stdout>" }
    let err = stderr.text() catch { _ => "<non-utf8 stderr>" }
    fail(
      "OpenXML SDK validation failed for \{name} (exit=\{code})\nstdout:\n\{out}\nstderr:\n\{err}",
    )
  }
  @async/fs.remove(path) catch {
    _ => ()
  }
}

///|
/// Schema-validates a feature matrix through the real Microsoft OpenXML
/// SDK, complementing the fast in-MoonBit `validate_ooxml_package`
/// structural checks with authoritative schema conformance. Each case
/// exercises a distinct write path (charts of several kinds, data
/// validation, conditional formatting, auto filter, defined names,
/// styles, rich text) that the demo workbooks do not all isolate.
#cfg(target="native")
async test "feature matrix is Microsoft OpenXML schema-valid" {
  let stamp = @env.now()
    .to_string()
    .replace(old=":", new="_")
    .replace(old=" ", new="_")
  let dir = "_build/feature_sdk_validity/\{stamp}"
  @async/fs.mkdir(dir, permission=0o755, recursive=true) catch {
    err => fail("mkdir failed: \{err}")
  }

  // three chart kinds in one workbook
  let charts = @xlsx.Workbook::new()
  let cs = charts.add_sheet("Sheet1")
  for i in 1..<=5 {
    cs.set_cell_value("A\{i}", Numeric(i.to_double()))
    cs.set_cell_value("B\{i}", Numeric((i * 3 % 7).to_double()))
  }
  for entry in [("D1", @xlsx.Col), ("D20", @xlsx.Line), ("D40", @xlsx.Pie)] {
    let (anchor, kind) = entry
    let opts = @xlsx.ChartOptions::new(kind)
    opts.series.push(
      @xlsx.ChartSeries::new("Sheet1!$A$1:$A$5", "Sheet1!$B$1:$B$5", name="S"),
    )
    charts.add_chart_with_options("Sheet1", anchor, opts)
  }
  validate_via_sdk(dir, "charts", @xlsx.write(charts))

  // data validation (dropdown list) + auto filter
  let dv = @xlsx.Workbook::new()
  let dvs = dv.add_sheet("Sheet1")
  dvs.set_cell_value("A1", String("Fruit"))
  dvs.set_cell_value("A2", String("apple"))
  dvs.set_cell_value("A3", String("pear"))
  dv.add_data_validation_list("Sheet1", "B2:B10", ["apple", "pear", "plum"])
  dv.set_auto_filter("Sheet1", "A1:A3", [])
  validate_via_sdk(dir, "datavalidation_autofilter", @xlsx.write(dv))

  // conditional formatting
  let cf = @xlsx.Workbook::new()
  let cfs = cf.add_sheet("Sheet1")
  for i in 1..<=6 {
    cfs.set_cell_value("A\{i}", Numeric((i * 10).to_double()))
  }
  let cf_style = cf.new_style(
    @xlsx.Style::builtin_number_format(0).with_font(
      @xlsx.Font::with_values(bold=true),
    ),
  )
  let rule = @xlsx.ConditionalFormatOptions::new("cell")
  rule.set_criteria("greaterThan")
  rule.set_value("30")
  rule.set_format(Some(cf_style))
  cf.set_conditional_format("Sheet1", "A1:A6", [rule])
  validate_via_sdk(dir, "conditional_format", @xlsx.write(cf))

  // styles, number formats, rich text, defined names
  let styled = @xlsx.Workbook::new()
  let ss = styled.add_sheet("Sheet1")
  let style = styled.new_style(
    @xlsx.Style::builtin_number_format(44).with_font(
      @xlsx.Font::with_values(bold=true, italic=true, color="#0066CC"),
    ),
  )
  ss.set_cell_value("A1", Numeric(1234.5))
  styled.set_cell_style("Sheet1", "A1", style)
  ss.set_cell_rich_text("A2", [
    { text: "run one ", font: None },
    { text: "run two", font: None },
  ])
  styled.set_defined_name(@xlsx.DefinedName::new("Total", "Sheet1!$A$1"))
  validate_via_sdk(dir, "styles_richtext", @xlsx.write(styled))
}
