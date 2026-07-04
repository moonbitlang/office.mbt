///|
fn count_occurrences(text : StringView, needle : StringView) -> Int {
  let mut count = 0
  let mut rest = text.to_owned()
  let target = needle.to_owned()
  if target == "" {
    return 0
  }
  while true {
    match rest.find(target) {
      Some(pos) => {
        count = count + 1
        let next = pos + target.length()
        rest = rest[next:].to_owned()
      }
      None => break
    }
  }
  count
}

///|
test "formula opts array writes typed formula" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula_opts(
    "A1",
    "{1,2;3,4}",
    opts=FormulaOpts::array("A1:B2"),
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("t=\"array\""), content="true")
  inspect(sheet_xml.contains("ref=\"A1:B2\""), content="true")
  inspect(count_occurrences(sheet_xml, "t=\"array\""), content="4")
  let calc_xml = match archive.get("xl/calcChain.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("calcChain.xml utf8 decode failed")
      }
    None => fail("missing calcChain.xml")
  }
  inspect(calc_xml.contains("<c r=\"A1\" i=\"1\"/>"), content="true")
  inspect(calc_xml.contains("r=\"B2\""), content="false")
  let parsed = read(bytes)
  debug_inspect(
    parsed.get_cell_formula("Sheet1", "A1"),
    content="Some(\"{1,2;3,4}\")",
  )
  debug_inspect(parsed.get_cell_formula("Sheet1", "B2"), content="None")
}

///|
test "formula opts shared writes typed formula" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula_opts("C1", "A1+B1", opts=FormulaOpts::shared("C1:C3"))
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("t=\"shared\""), content="true")
  inspect(sheet_xml.contains("ref=\"C1:C3\""), content="true")
  inspect(sheet_xml.contains("si=\"0\""), content="true")
  inspect(count_occurrences(sheet_xml, "t=\"shared\""), content="3")
  let calc_xml = match archive.get("xl/calcChain.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("calcChain.xml utf8 decode failed")
      }
    None => fail("missing calcChain.xml")
  }
  inspect(calc_xml.contains("<c r=\"C1\" i=\"1\"/>"), content="true")
  inspect(calc_xml.contains("r=\"C2\""), content="false")
  let parsed = read(bytes)
  debug_inspect(
    parsed.get_cell_formula("Sheet1", "C1"),
    content="Some(\"A1+B1\")",
  )
  debug_inspect(parsed.get_cell_formula("Sheet1", "C2"), content="None")
}

///|
test "formula opts dataTable behaves like normal formula" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula_opts(
    "A1",
    "SUM(1,2)",
    opts=FormulaOpts::with_values(formula_type=DataTable),
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("t=\"dataTable\""), content="false")
  let parsed = read(bytes)
  debug_inspect(
    parsed.get_cell_formula("Sheet1", "A1"),
    content="Some(\"SUM(1,2)\")",
  )
}

///|
test "formula opts: worksheet edge cases" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")

  // formula_type = None (default).
  sheet.set_cell_formula_opts("A1", "1+1")

  // formula_type = Normal.
  sheet.set_cell_formula_opts(
    "A2",
    "1+2",
    opts=FormulaOpts::with_values(formula_type=Normal),
  )

  // Array: missing range_ref.
  let missing_array_ref : Result[Unit, Error] = try? sheet.set_cell_formula_opts(
    "B1",
    "{1}",
    opts=FormulaOpts::with_values(formula_type=Array),
  )
  debug_inspect(
    missing_array_ref,
    content=(
      #|Err(InvalidSheetOperation(msg="array formula ref missing"))
    ),
  )

  // Array: master must be top-left.
  let bad_array_master : Result[Unit, Error] = try? sheet.set_cell_formula_opts(
    "A1",
    "{1,2}",
    opts=FormulaOpts::array("B1:C1"),
  )
  debug_inspect(
    bad_array_master,
    content=(
      #|Err(InvalidSheetOperation(msg="array formula master must be top-left of ref"))
    ),
  )

  // Array: update existing cells.
  sheet.set_cell("C1", "x")
  sheet.set_cell_formula_opts("C1", "{1,2}", opts=FormulaOpts::array("C1:D1"))
  debug_inspect(sheet.get_cell_formula("C1"), content="Some(\"{1,2}\")")

  // Shared: missing range_ref.
  let missing_shared_ref : Result[Unit, Error] = try? sheet.set_cell_formula_opts(
    "E1",
    "A1",
    opts=FormulaOpts::with_values(formula_type=Shared),
  )
  debug_inspect(
    missing_shared_ref,
    content=(
      #|Err(InvalidSheetOperation(msg="shared formula ref missing"))
    ),
  )

  // Shared: master must be top-left.
  let bad_shared_master : Result[Unit, Error] = try? sheet.set_cell_formula_opts(
    "F1",
    "A1+B1",
    opts=FormulaOpts::shared("F2:F3"),
  )
  debug_inspect(
    bad_shared_master,
    content=(
      #|Err(InvalidSheetOperation(msg="shared formula master must be top-left of ref"))
    ),
  )

  // Shared: update existing cells + max shared index scan.
  sheet.set_cell("G1", "x")
  sheet.set_cell_formula_opts("G1", "A1+B1", opts=FormulaOpts::shared("G1:G2"))
  sheet.set_cell_formula_opts("H1", "A1+B1", opts=FormulaOpts::shared("H1:H2"))
  debug_inspect(sheet.get_cell_formula("G2"), content="None")
  debug_inspect(sheet.get_cell_formula("H2"), content="None")
}
