///|
fn count_occurrences(text : StringView, needle : StringView) -> Int {
  let mut count = 0
  let mut rest = text.to_string()
  let target = needle.to_string()
  if target == "" {
    return 0
  }
  while true {
    match rest.find(target) {
      Some(pos) => {
        count = count + 1
        let next = pos + target.length()
        rest = (rest[next:] catch { _ => "" }).to_string()
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
  inspect(
    parsed.get_cell_formula("Sheet1", "A1"),
    content="Some(\"{1,2;3,4}\")",
  )
  inspect(parsed.get_cell_formula("Sheet1", "B2"), content="None")
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
  inspect(parsed.get_cell_formula("Sheet1", "C1"), content="Some(\"A1+B1\")")
  inspect(parsed.get_cell_formula("Sheet1", "C2"), content="None")
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
  inspect(parsed.get_cell_formula("Sheet1", "A1"), content="Some(\"SUM(1,2)\")")
}
