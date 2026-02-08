///|
test "workbook and calc props roundtrip" {
  let workbook = Workbook::new()
  let wb_opts = WorkbookPropsOptions::with_values(
    date_1904=true,
    filter_privacy=true,
    code_name="CodeName",
  )
  workbook.set_workbook_props(Some(wb_opts))
  let calc_opts = CalcPropsOptions::with_values(
    calc_id=1,
    calc_mode="manual",
    full_calc_on_load=true,
    ref_mode="A1",
    iterate=true,
    iterate_count=2,
    iterate_delta=0.01,
    full_precision=true,
    calc_completed=true,
    calc_on_save=true,
    concurrent_calc=true,
    concurrent_manual_count=3,
    force_full_calc=true,
  )
  workbook.set_calc_props(Some(calc_opts))
  let bytes = write(workbook)
  let parsed = read(bytes)
  let parsed_wb = parsed.get_workbook_props()
  inspect(parsed_wb.date_1904, content="Some(true)")
  inspect(parsed_wb.filter_privacy, content="Some(true)")
  inspect(parsed_wb.code_name, content="Some(\"CodeName\")")
  let parsed_calc = parsed.get_calc_props()
  inspect(parsed_calc.calc_id, content="Some(1)")
  inspect(parsed_calc.calc_mode, content="Some(\"manual\")")
  inspect(parsed_calc.ref_mode, content="Some(\"A1\")")
  inspect(parsed_calc.iterate, content="Some(true)")
  inspect(parsed_calc.iterate_count, content="Some(2)")
  inspect(parsed_calc.iterate_delta, content="Some(0.01)")
  inspect(parsed_calc.force_full_calc, content="Some(true)")
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("workbook.xml utf8 decode failed")
      }
    None => fail("missing workbook.xml")
  }
  inspect(workbook_xml.contains("<workbookPr"), content="true")
  inspect(workbook_xml.contains("date1904=\"1\""), content="true")
  inspect(workbook_xml.contains("calcMode=\"manual\""), content="true")
}

///|
test "invalid calc props" {
  let workbook = Workbook::new()
  let bad = CalcPropsOptions::with_values(calc_mode="bad")
  let result = try? workbook.set_calc_props(Some(bad))
  inspect(
    result,
    content="Err(InvalidWorkbookProperty(msg=\"invalid calc mode\"))",
  )
}

///|
test "calc props normalize auto + r1c1 variants" {
  let workbook = Workbook::new()
  let calc_opts = CalcPropsOptions::with_values(
    calc_mode="AUTO",
    ref_mode="r1c1",
  )
  workbook.set_calc_props(Some(calc_opts))
  let bytes = write(workbook)
  let parsed = read(bytes)
  let props = parsed.get_calc_props()
  inspect(props.calc_mode, content="Some(\"auto\")")
  inspect(props.ref_mode, content="Some(\"R1C1\")")
}
