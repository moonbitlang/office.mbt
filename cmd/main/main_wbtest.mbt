///|
test "cmd/main: main_with_sheet ok" {
  let result = main_with_sheet("Sheet1")
  inspect(result is Ok(_), content="true")
}

///|
test "cmd/main: main_with_sheet error" {
  let result = main_with_sheet("Sheet/1")
  inspect(result is Err(_), content="true")
}

///|
test "cmd/main: demo_xlsx_bytes ok" {
  let result = demo_xlsx_bytes()
  inspect(result is Ok(_), content="true")
}
