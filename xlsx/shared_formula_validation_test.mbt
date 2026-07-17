///|
fn malformed_shared_formula_package(
  old : String,
  replacement : String,
) -> Bytes raise {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_formula_opts(
    "A1",
    "D1+1",
    opts=@xlsx.FormulaOpts::shared("A1:C1"),
  )
  let archive = @zip.read(@xlsx.write(workbook))
  let path = "xl/worksheets/sheet1.xml"
  let xml = match archive.get(path) {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("shared-formula worksheet is not UTF-8")
      }
    None => fail("missing shared-formula worksheet")
  }
  let updated = xml.replace(old~, new=replacement)
  if updated == xml {
    fail("shared-formula corruption marker was not found")
  }
  assert_true(archive.replace(path, @encoding/utf8.encode(updated)))
  @zip.write(archive)
}

///|
fn expect_shared_formula_read_error(
  label : String,
  bytes : BytesView,
  expected : String,
) -> Unit raise {
  let result : Result[@xlsx.Workbook, Error] = Ok(@xlsx.read(bytes)) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.InvalidXml(msg~)) => assert_eq(msg, expected)
    Err(error) => fail("\{label}: unexpected error \{error}")
    Ok(_) => fail("\{label}: malformed shared-formula group was accepted")
  }
}

///|
test "XLSX read rejects missing, out-of-range, and conflicting shared masters" {
  let master =
    #|<f t="shared" ref="A1:C1" si="0">D1+1</f>
  let follower =
    #|<f t="shared" si="0"></f>
  expect_shared_formula_read_error(
    "missing master",
    malformed_shared_formula_package(master, follower),
    "shared formula follower has no master",
  )
  expect_shared_formula_read_error(
    "out-of-range follower",
    malformed_shared_formula_package(
      master, "<f t=\"shared\" ref=\"A1:B1\" si=\"0\">D1+1</f>",
    ),
    "shared formula follower is outside the master range",
  )
  expect_shared_formula_read_error(
    "conflicting masters",
    malformed_shared_formula_package(
      follower, "<f t=\"shared\" ref=\"A1:C1\" si=\"0\">E1+1</f>",
    ),
    "shared formula index has conflicting masters",
  )
}

///|
test "XLSX read ignores expressions stored on shared-formula followers" {
  let bytes = malformed_shared_formula_package(
    "<f t=\"shared\" si=\"0\"></f>", "<f t=\"shared\" si=\"0\">PRODUCER_GARBAGE+1</f>",
  )
  let workbook = @xlsx.read(bytes)
  guard workbook.sheet("Data") is Some(sheet) else {
    fail("missing shared-formula worksheet")
  }
  guard sheet.get_cell_formula_info_rc(1, 2) is Some(follower) else {
    fail("missing shared-formula follower metadata")
  }
  assert_eq(follower.formula, "")
  assert_eq(follower.shared_index, Some(0))
  guard sheet.shared_formula_masters().get(0) is Some(master) else {
    fail("missing shared-formula master")
  }
  assert_eq(master.translate_to(1, 2), "E1+1")
}

///|
test "XLSX read rejects overlapping shared-formula master ranges" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_formula_opts(
    "A1",
    "B1+1",
    opts=@xlsx.FormulaOpts::shared("A1:A2"),
  )
  sheet.set_cell_formula_opts(
    "C1",
    "D1+1",
    opts=@xlsx.FormulaOpts::shared("C1:C2"),
  )
  let archive = @zip.read(@xlsx.write(workbook))
  let path = "xl/worksheets/sheet1.xml"
  let xml = match archive.get(path) {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("shared-formula worksheet is not UTF-8")
      }
    None => fail("missing shared-formula worksheet")
  }
  let updated = xml.replace(old="ref=\"A1:A2\"", new="ref=\"A1:C1\"")
  assert_true(updated != xml)
  assert_true(archive.replace(path, @encoding/utf8.encode(updated)))
  expect_shared_formula_read_error(
    "overlapping masters",
    @zip.write(archive),
    "shared formula master ranges overlap",
  )
}

///|
test "XLSX shared-formula indices cover the OOXML unsigned range" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_formula_opts(
    "A1",
    "D1+1",
    opts=@xlsx.FormulaOpts::shared("A1:C1"),
  )
  let archive = @zip.read(@xlsx.write(workbook))
  let path = "xl/worksheets/sheet1.xml"
  let xml = match archive.get(path) {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("shared-formula worksheet is not UTF-8")
      }
    None => fail("missing shared-formula worksheet")
  }
  let updated = xml.replace_all(old="si=\"0\"", new="si=\"4294967295\"")
  assert_true(updated != xml)
  assert_true(archive.replace(path, @encoding/utf8.encode(updated)))
  let parsed = @xlsx.read(@zip.write(archive))
  guard parsed.sheet("Data") is Some(parsed_sheet) else {
    fail("missing parsed shared-formula worksheet")
  }
  guard parsed_sheet.shared_formula_masters().get(0xFFFFFFFF) is Some(master) else {
    fail("missing maximum unsigned shared-formula index")
  }
  assert_eq(master.translate_to(1, 3), "F1+1")
  let roundtripped = @xlsx.read(@xlsx.write(parsed))
  guard roundtripped.sheet("Data") is Some(roundtripped_sheet) else {
    fail("missing roundtripped shared-formula worksheet")
  }
  assert_true(roundtripped_sheet.shared_formula_masters().contains(0xFFFFFFFF))
}

///|
test "XLSX read rejects negative shared-formula indices" {
  expect_shared_formula_read_error(
    "negative index",
    malformed_shared_formula_package("si=\"0\"", "si=\"-1\""),
    "formula si invalid",
  )
}
