///|
fn demo_xlsx_bytes(sheet_name? : String = "Sheet1") -> Bytes raise {
  let workbook = @lib.new_workbook()
  let sheet = workbook.add_sheet(sheet_name)
  sheet.set_cell("A1", "hello")
  sheet.set_cell("B1", "42")
  sheet.set_cell_formula("C1", "B1", value="42")
  @lib.write(workbook)
}

///|
fn main {
  match (Ok(demo_xlsx_bytes()) catch { e => Err(e) }) {
    Ok(bytes) => println("xlsx bytes: \{bytes.length()}")
    Err(err) => println("write failed: \{err}")
  }
}

///|
test "cmd/main: demo_xlsx_bytes produces a workbook" {
  inspect(demo_xlsx_bytes().length() > 0, content="true")
}

///|
test "cmd/main: demo_xlsx_bytes honors the sheet name" {
  inspect(demo_xlsx_bytes(sheet_name="Data").length() > 0, content="true")
}

///|
test "cmd/main: an invalid sheet name raises" {
  inspect(
    (Ok(demo_xlsx_bytes(sheet_name="Sheet/1")) catch { e => Err(e) }) is Err(_),
    content="true",
  )
}
