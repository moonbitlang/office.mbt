///|
#cfg(target="native")
async test "excelize fixture encryptSHA1.xlsx opens with password" {
  let workbook = open_file(
    "fixtures/excelize/test/encryptSHA1.xlsx",
    password="password",
  )
  debug_inspect(
    workbook.get_cell_value("Sheet1", "A1"),
    content="Some(\"SECRET\")",
  )
}

///|
#cfg(target="native")
async test "excelize fixture encryptSHA1.xlsx wrong password errors" {
  let result : Result[Workbook, Error] = Ok(
    open_file("fixtures/excelize/test/encryptSHA1.xlsx", password="passwd"),
  ) catch {
    e => Err(e)
  }
  inspect(result is Err(XlsxError::InvalidPassword), content="true")
}
