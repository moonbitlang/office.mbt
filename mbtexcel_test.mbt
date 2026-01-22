///|
test "mbtexcel roundtrip" {
  let workbook = new_workbook()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "hello")
  let bytes = write(workbook)
  let parsed = read(bytes)
  inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"hello\")")
}

///|
test "mbtexcel expose workbook" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "B2", "world")
  inspect(workbook.get_cell("Sheet1", "B2"), content="Some(\"world\")")
}

///|
test "mbtexcel new_file and helpers" {
  let workbook = new_file()
  inspect(workbook.sheet_name(0), content="Some(\"Sheet1\")")
  let (col, row) = cell_name_to_coordinates("$C$3")
  inspect((col, row), content="(3, 3)")
  inspect(coordinates_to_cell_name(3, 3, abs=true), content="$C$3")
}

///|
test "mbtexcel data_validation and stack" {
  let dv = new_data_validation(true)
  inspect(dv.allow_blank, content="true")
  let stack : Stack[Int] = new_stack()
  inspect(stack.empty(), content="true")
  stack.push(10)
  stack.push(20)
  inspect(stack.peek(), content="Some(20)")
  inspect(stack.pop(), content="Some(20)")
  inspect(stack.len(), content="1")
}

///|
test "mbtexcel encrypt decrypt roundtrip" {
  let raw : Bytes = "hello"
  let opts = @xlsx.Options::with_values(password="secret")
  let encrypted = encrypt(raw, options=opts)
  let decrypted = decrypt(encrypted, options=opts)
  assert_eq(decrypted, raw)
}
