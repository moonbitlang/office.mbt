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
