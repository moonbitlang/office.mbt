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
