///|
test "mbtexcel roundtrip" {
  let workbook = new_workbook()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "hello")
  let bytes = write(workbook)
  let parsed = read(bytes)
  debug_inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"hello\")")
}

///|
test "mbtexcel read wrappers with transcoder branch" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "t")
  let bytes = write(workbook)
  let parsed = read(bytes, transcoder=fn(
    _charset : String,
    b : Bytes,
  ) -> String {
    @encoding/utf8.decode(b) catch {
      _ => ""
    }
  })
  debug_inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"t\")")
  let encrypted = write_with_password(workbook, "pass")
  let parsed2 = read_with_password(encrypted, "pass", transcoder=fn(
    _charset : String,
    b : Bytes,
  ) -> String {
    @encoding/utf8.decode(b) catch {
      _ => ""
    }
  })
  debug_inspect(parsed2.get_cell("Sheet1", "A1"), content="Some(\"t\")")
}

///|
test "mbtexcel expose workbook" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "B2", "world")
  debug_inspect(workbook.get_cell("Sheet1", "B2"), content="Some(\"world\")")
}

///|
test "mbtexcel new_file and helpers" {
  let workbook = new_file()
  debug_inspect(workbook.sheet_name(0), content="Some(\"Sheet1\")")
  let (col, row) = cell_name_to_coordinates("$C$3")
  debug_inspect((col, row), content="(3, 3)")
  inspect(coordinates_to_cell_name(3, 3, abs=true), content="$C$3")
}

///|
test "mbtexcel data_validation" {
  let dv = new_data_validation(true)
  inspect(dv.allow_blank, content="true")
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
  debug_inspect((t0.year(), t0.month(), t0.day()), content="(1900, 1, 1)")
}

///|
test "mbtexcel column name conversions" {
  inspect(column_name_to_number("AK"), content="37")
  inspect(column_number_to_name(37), content="AK")
  @test.assert_raise(() => column_name_to_number("A1"))
  @test.assert_raise(() => column_number_to_name(0))
}

///|
test "mbtexcel acronym color helpers" {
  let (r2, g2, b2) = hsl_to_rgb(0.0, 1.0, 0.4)
  assert_eq(r2, (204).to_byte())
  assert_eq(g2, (0).to_byte())
  assert_eq(b2, (0).to_byte())
  let (h2, s2, l2) = rgb_to_hsl((255).to_byte(), (255).to_byte(), (0).to_byte())
  debug_inspect((h2, s2, l2), content="(0.16666666666666666, 1, 0.5)")
}

///|
test "mbtexcel sheet management helpers" {
  let workbook = new_file()
  ignore(workbook.add_sheet("Data"))
  workbook.set_sheet_name("Sheet1", "Main")
  debug_inspect(workbook.sheet_name(0), content="Some(\"Main\")")
  inspect(workbook.sheet_index("Data"), content="1")
  let list = workbook.get_sheet_list()
  inspect(list.contains("Main"), content="true")
  inspect(list.contains("Data"), content="true")
  let map = workbook.get_sheet_map()
  guard map is { 1: "Main", 2: "Data", .. } else {
    fail("unexpected sheet map")
  }
  workbook.delete_sheet("Data")
  @test.assert_raise(() => workbook.sheet_index("Data"))
}

///|
test "mbtexcel excel_date_to_time 1904 and invalid" {
  let t0 = excel_date_to_time(0.0, use_1904_format=true)
  debug_inspect((t0.year(), t0.month(), t0.day()), content="(1904, 1, 1)")
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
  debug_inspect(workbook.get_row_style("Sheet1", 2), content="Some(1)")
  debug_inspect(workbook.get_col_style("Sheet1", 3), content="Some(1)")
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
  guard result is Err(@xlsx.InvalidOptions(_)) else {
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
  debug_inspect(
    result1,
    content="Err(InvalidWorkbookProperty(msg=\"invalid calc mode\"))",
  )
  let bad_ref = @xlsx.CalcPropsOptions::with_values(ref_mode="R2C2")
  let result2 : Result[Unit, Error] = try? workbook.set_calc_props(
    Some(bad_ref),
  )
  debug_inspect(
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
  guard result is Err(@xlsx.InvalidWorkbookProtection(_)) else {
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
  guard result is Err(@xlsx.InvalidSheetProtection(_)) else {
    fail("expected sheet protection mismatch")
  }
}
