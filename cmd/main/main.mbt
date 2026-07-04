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
  match (try? demo_xlsx_bytes()) {
    Ok(bytes) => println("xlsx bytes: \{bytes.length()}")
    Err(err) => println("write failed: \{err}")
  }
}
