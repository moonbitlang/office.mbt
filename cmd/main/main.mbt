///|
fn main {
  let workbook = @lib.new_workbook()
  let result = try {
    let sheet = workbook.add_sheet("Sheet1")
    sheet.set_cell("A1", "hello")
    sheet.set_cell("B1", "42")
    sheet.set_cell_formula("C1", "B1", value="42")
    @lib.write(workbook)
  } catch {
    err => Err(err)
  } noraise {
    bytes => Ok(bytes)
  }
  match result {
    Ok(bytes) => println("xlsx bytes: \{bytes.length()}")
    Err(err) => println("write failed: \{err}")
  }
}
