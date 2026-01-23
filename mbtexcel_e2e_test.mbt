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

///|
test "mbtexcel e2e tables sparklines hyperlinks" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "Name")
  workbook.set_cell("Sheet1", "B1", "Value")
  workbook.set_cell("Sheet1", "A2", "Alpha")
  workbook.set_cell_int("Sheet1", "B2", 10)
  ignore(workbook.add_table("Sheet1", "A1:B2", "Table1", ["Name", "Value"]))
  workbook.add_sparkline("Sheet1", "C2", "B2:B2")
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A2",
    "https://example.com",
    @xlsx.HyperlinkType::External,
    display="Example",
  )
  let parsed = read(write(workbook))
  inspect(parsed.get_tables("Sheet1").length(), content="1")
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(sheet.sparkline_groups().length(), content="1")
  inspect(
    parsed.get_cell_hyperlink("Sheet1", "A2"),
    content=(
      #|Some({reference: "A2", target: "https://example.com", link_type: External, display: Some("Example"), tooltip: None})
    ),
  )
}

///|
test "mbtexcel e2e stream writer" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let writer = workbook.new_stream_writer("Sheet1")
  writer.set_row("A1", ["A", "B"])
  writer.set_row_cells("A2", [
    @xlsx.StreamCell::new("3", formula="SUM(A1,B1)"),
    @xlsx.StreamCell::new("4"),
  ])
  writer.flush()
  let parsed = read(write(workbook))
  inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"A\")")
  inspect(parsed.get_cell_formula("Sheet1", "A2"), content="Some(\"SUM(A1,B1)\")")
}

///|
test "mbtexcel e2e header footer images" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_header_footer(
    "Sheet1",
    Some(@xlsx.HeaderFooterOptions::with_values(odd_header="&L&G")),
  )
  let img : Bytes = [10, 20, 30]
  workbook.add_header_footer_image(
    "Sheet1",
    @xlsx.HeaderFooterImageOptions::new(
      @xlsx.HeaderFooterImagePosition::Left,
      img,
      ".png",
      width="50pt",
      height="32pt",
    ),
  )
  let parsed = read(write(workbook))
  let images = parsed.get_header_footer_images("Sheet1")
  inspect(images.length(), content="1")
  let first = images[0]
  inspect(
    (
      first.position,
      first.is_footer,
      first.first_page,
      first.extension,
      first.width,
      first.height,
    ),
    content="(Left, false, false, \"png\", \"50pt\", \"32pt\")",
  )
  inspect(first.data == img, content="true")
}

///|
test "mbtexcel e2e sheet background" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let bg : Bytes = [1, 2, 3, 4, 5]
  workbook.set_sheet_background("Sheet1", bg, ".png")
  let parsed = read(write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  match sheet.sheet_background() {
    Some(value) => {
      inspect(value.extension, content="png")
      inspect(value.content_type, content="image/png")
      inspect(value.data == bg, content="true")
    }
    None => fail("missing background")
  }
}

///|
test "mbtexcel e2e auto filter roundtrip" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let options : Array[@xlsx.AutoFilterOption] = [
    { column: "B", expression: "x == 10" },
    { column: "C", expression: "x > 5" },
  ]
  workbook.set_auto_filter("Sheet1", "A1:C3", options)
  let parsed = read(write(workbook))
  inspect(
    parsed.get_auto_filter("Sheet1"),
    content=(
      #|Some({range_ref: "A1:C3", columns: [{col: 2, filters: Some(["10"]), custom_filters: None}, {col: 3, filters: None, custom_filters: Some({and_filter: false, filters: [{operator: "greaterThan", value: "5"}]})}]})
    ),
  )
}

///|
test "mbtexcel e2e sheet protection" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = @xlsx.SheetProtectionOptions::with_values(
    password="secret",
    auto_filter=true,
  )
  workbook.protect_sheet("Sheet1", opts)
  let parsed = read(write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(sheet.sheet_protection() is Some(_), content="true")
}

///|
test "mbtexcel e2e defined names" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let dn = @xlsx.DefinedName::new("MyName", "Sheet1!$A$1")
  workbook.set_defined_name(dn)
  let parsed = read(write(workbook))
  let names = parsed.get_defined_names()
  inspect(names.length(), content="1")
  inspect(
    (names[0].name, names[0].refers_to),
    content="(\"MyName\", \"Sheet1!$A$1\")",
  )
}

///|
test "mbtexcel e2e row/col insert remove shifts" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "alpha")
  workbook.set_cell("Sheet1", "B2", "beta")
  workbook.insert_rows("Sheet1", 1, 1)
  workbook.insert_cols("Sheet1", 1, 1)
  inspect(workbook.get_cell("Sheet1", "B2"), content="Some(\"alpha\")")
  inspect(workbook.get_cell("Sheet1", "C3"), content="Some(\"beta\")")
  workbook.remove_rows("Sheet1", 1, 1)
  workbook.remove_cols("Sheet1", 1, 1)
  inspect(workbook.get_cell("Sheet1", "A1"), content="Some(\"alpha\")")
  inspect(workbook.get_cell("Sheet1", "B2"), content="Some(\"beta\")")
}
