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

///|
test "mbtexcel excel_date_to_time wrapper" {
  let t0 = excel_date_to_time(1.0)
  inspect((t0.year(), t0.month(), t0.day()), content="(1900, 1, 1)")
}

///|
test "mbtexcel column name conversions" {
  inspect(column_name_to_number("AK"), content="37")
  inspect(column_number_to_name(37), content="AK")
  let invalid_name : Result[Int, Error] = try? column_name_to_number("A1")
  inspect(invalid_name is Err(_), content="true")
  let invalid_num : Result[String, Error] = try? column_number_to_name(0)
  inspect(invalid_num is Err(_), content="true")
}

///|
test "mbtexcel acronym color helpers" {
  let (r, g, b) = hslto_rgb(0.0, 1.0, 0.4)
  assert_eq(r, (204).to_byte())
  assert_eq(g, (0).to_byte())
  assert_eq(b, (0).to_byte())
  let (h, s, l) = rgbto_hsl((255).to_byte(), (255).to_byte(), (0).to_byte())
  inspect((h, s, l), content="(0.16666666666666666, 1, 0.5)")
}

///|
test "mbtexcel sheet management helpers" {
  let workbook = new_file()
  ignore(workbook.add_sheet("Data"))
  workbook.set_sheet_name("Sheet1", "Main")
  inspect(workbook.sheet_name(0), content="Some(\"Main\")")
  inspect(workbook.sheet_index("Data"), content="1")
  let list = workbook.get_sheet_list()
  inspect(list.contains("Main"), content="true")
  inspect(list.contains("Data"), content="true")
  let map = workbook.get_sheet_map()
  guard map is { 1: "Main", 2: "Data", .. } else {
    fail("unexpected sheet map")
  }
  workbook.delete_sheet("Data")
  let missing : Result[Int, Error] = try? workbook.sheet_index("Data")
  inspect(missing is Err(_), content="true")
}

///|
test "mbtexcel excel_date_to_time 1904 and invalid" {
  let t0 = excel_date_to_time(0.0, use_1904_format=true)
  inspect((t0.year(), t0.month(), t0.day()), content="(1904, 1, 1)")
  let invalid : Result[@time.ZonedDateTime, Error] = try? excel_date_to_time(
    -1.0,
  )
  inspect(invalid is Err(_), content="true")
}

///|
test "mbtexcel theme_color wrapper" {
  inspect(theme_color("000000", 0.0), content="FF000000")
  inspect(theme_color("00FF00", 0.2), content="FF33FF33")
  inspect(theme_color("!!!!!!", 1.0), content="FFFFFFFF")
}

///|
test "mbtexcel row/col visibility and style ranges" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let style_id = workbook.add_style(@xlsx.Style::new())
  workbook.set_row_style_range("Sheet1", 2, 3, style_id)
  workbook.set_col_style_range("Sheet1", "B:C", style_id)
  workbook.set_row_visible("Sheet1", 2, false)
  workbook.set_col_visible("Sheet1", 3, false)
  inspect(workbook.get_row_style("Sheet1", 2), content="Some(1)")
  inspect(workbook.get_col_style("Sheet1", 3), content="Some(1)")
  inspect(workbook.row_visible("Sheet1", 2), content="false")
  inspect(workbook.col_visible("Sheet1", 3), content="false")
}

///|
test "mbtexcel read options unzip limits" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = write(workbook)
  let opts = @xlsx.Options::with_values(unzip_size_limit=1)
  let result : Result[@xlsx.Workbook, Error] = try? read(bytes, options=opts)
  guard result is Err(@xlsx.XlsxError::InvalidOptions(_)) else {
    fail("expected unzip size limit error")
  }
}

///|
test "mbtexcel calc props validation" {
  let workbook = new_workbook()
  let bad_mode = @xlsx.CalcPropsOptions::with_values(calc_mode="bad")
  let result1 : Result[Unit, Error] = try? workbook.set_calc_props(
    Some(bad_mode),
  )
  inspect(
    result1,
    content="Err(InvalidWorkbookProperty(msg=\"invalid calc mode\"))",
  )
  let bad_ref = @xlsx.CalcPropsOptions::with_values(ref_mode="R2C2")
  let result2 : Result[Unit, Error] = try? workbook.set_calc_props(
    Some(bad_ref),
  )
  inspect(
    result2,
    content="Err(InvalidWorkbookProperty(msg=\"invalid reference mode\"))",
  )
}

///|
test "mbtexcel workbook protection invalid password" {
  let workbook = new_workbook()
  let opts = @xlsx.WorkbookProtectionOptions::with_values(
    password="secret",
    lock_structure=true,
  )
  workbook.protect_workbook(options=opts)
  let result : Result[Unit, Error] = try? workbook.unprotect_workbook(
    password="wrong",
  )
  guard result is Err(@xlsx.XlsxError::InvalidWorkbookProtection(_)) else {
    fail("expected workbook protection mismatch")
  }
}

///|
test "mbtexcel sheet protection invalid password" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = @xlsx.SheetProtectionOptions::with_values(password="secret")
  workbook.protect_sheet("Sheet1", opts)
  let result : Result[Unit, Error] = try? workbook.unprotect_sheet(
    "Sheet1",
    password="wrong",
  )
  guard result is Err(@xlsx.XlsxError::InvalidSheetProtection(_)) else {
    fail("expected sheet protection mismatch")
  }
}
