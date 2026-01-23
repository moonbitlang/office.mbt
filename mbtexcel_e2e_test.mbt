///|
test "mbtexcel cell reference helpers" {
  let (col, row) = split_cell_name("BC12")
  inspect((col, row), content="(\"BC\", 12)")
  inspect(join_cell_name("BC", 12), content="BC12")
  let abs = coordinates_to_cell_name(27, 12, abs=true)
  inspect(abs, content="$AA$12")
  let invalid_split : Result[(String, Int), Error] = try? split_cell_name("1A")
  inspect(invalid_split is Err(_), content="true")
  let invalid_join : Result[String, Error] = try? join_cell_name("", 0)
  inspect(invalid_join is Err(_), content="true")
}

///|
test "mbtexcel password wrappers" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "secret")
  let bytes = write_with_password(workbook, "pass")
  let parsed = read_with_password(bytes, "pass")
  inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"secret\")")
  let bad : Result[@xlsx.Workbook, Error] = try? read_with_password(
    bytes, "wrong",
  )
  guard bad is Err(@xlsx.XlsxError::InvalidPassword) else {
    fail("expected invalid password")
  }
}

///|
async test "mbtexcel open_reader wrapper" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "reader")
  let bytes = write(workbook)
  let (reader, writer) = @async/io.pipe()
  let parsed = @async.with_task_group(fn(group) {
    group.spawn_bg(() => {
      defer writer.close()
      writer.write(bytes)
    })
    open_reader(reader)
  })
  inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"reader\")")
}

///|
async test "mbtexcel read_zip_reader wrapper" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "B2", "zip")
  let bytes = write(workbook)
  let (reader, writer) = @async/io.pipe()
  let parsed = @async.with_task_group(fn(group) {
    group.spawn_bg(() => {
      defer writer.close()
      writer.write(bytes)
    })
    read_zip_reader(reader)
  })
  inspect(parsed.get_cell("Sheet1", "B2"), content="Some(\"zip\")")
}

///|
async test "mbtexcel open_file wrapper" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "C3", "file")
  let bytes = write(workbook)
  let stamp = @env.now().to_string()
  let path = "mbtexcel_open_file_\{stamp}.xlsx"
  @async/fs.write_file(path, bytes, create=0o644) catch {
    err => fail("write file failed: \{err}")
  }
  let parsed = open_file(path)
  inspect(parsed.get_cell("Sheet1", "C3"), content="Some(\"file\")")
  @async/fs.remove(path) catch {
    err => fail("remove file failed: \{err}")
  }
}

///|
test "mbtexcel e2e multi-feature roundtrip" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Summary"))
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Summary", "A1", "Item")
  workbook.set_cell("Summary", "B1", "Count")
  workbook.set_cell("Summary", "A2", "Apples")
  workbook.set_cell_int("Summary", "B2", 10)
  workbook.set_cell_int("Summary", "B3", 5)
  workbook.set_cell_formula("Summary", "C2", "SUM(B2:B3)", value="15")
  workbook.set_cell_bool("Summary", "D2", true)
  workbook.set_cell_float("Summary", "E2", 3.5)
  workbook.merge_cell("Summary", "A4", "B4")
  workbook.set_cell("Summary", "A4", "Merged")
  let style_id = workbook.add_style(@xlsx.Style::number_format("0.00"))
  workbook.set_cell_style("Summary", "E2", style_id)
  let dv = new_data_validation(false)
  dv.set_sqref("F2:F3")
  dv.set_drop_list(["Yes", "No"])
  workbook.add_data_validation("Summary", dv)
  let bytes = write(workbook)
  let parsed = read(bytes)
  inspect(parsed.sheet_name(0), content="Some(\"Summary\")")
  inspect(parsed.sheet_name(1), content="Some(\"Data\")")
  inspect(parsed.get_cell("Summary", "A2"), content="Some(\"Apples\")")
  inspect(
    parsed.get_cell_value_raw("Summary", "B2"),
    content="Some(Numeric(10))",
  )
  inspect(
    parsed.get_cell_value_raw("Summary", "D2"),
    content="Some(Bool(true))",
  )
  inspect(
    parsed.get_cell_formula("Summary", "C2"),
    content="Some(\"SUM(B2:B3)\")",
  )
  inspect(parsed.get_cell_style("Summary", "E2"), content="Some(1)")
  let merged = parsed.get_merge_cells("Summary")
  inspect(merged.contains("A4:B4"), content="true")
  let validations = parsed.get_data_validations("Summary")
  inspect(validations.length(), content="1")
  inspect(validations[0].sqref, content="F2:F3")
}
