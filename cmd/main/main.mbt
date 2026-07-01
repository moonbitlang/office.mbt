///|
fn demo_xlsx_bytes(sheet_name? : String = "Sheet1") -> Result[Bytes, Error] {
  try {
    let workbook = @lib.new_workbook()
    let sheet = workbook.add_sheet(sheet_name)
    sheet.set_cell("A1", "hello")
    sheet.set_cell("B1", "42")
    sheet.set_cell_formula("C1", "B1", value="42")
    Ok(@lib.write(workbook))
  } catch {
    e => Err(e)
  }
}

///|
fn main_with_sheet(sheet_name : String) -> Result[Bytes, Error] {
  let result = demo_xlsx_bytes(sheet_name~)
  match result {
    Ok(bytes) => println("xlsx bytes: \{bytes.length()}")
    Err(err) => println("write failed: \{err}")
  }
  result
}

///|
fn main {
  ignore(main_with_sheet("Sheet1"))
}
