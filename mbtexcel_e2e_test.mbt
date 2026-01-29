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
  let spark_opts = @xlsx.SparklineOptions::new(["C2"], ["B2:B2"])
  workbook.add_sparkline("Sheet1", spark_opts)
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
  inspect(
    parsed.get_cell_formula("Sheet1", "A2"),
    content="Some(\"SUM(A1,B1)\")",
  )
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

///|
test "mbtexcel e2e comments" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let comment : @xlsx.Comment = {
    cell: "A1",
    author: "tester",
    text: "note",
    paragraph: [],
    width: None,
    height: None,
  }
  workbook.add_comment("Sheet1", comment)
  let parsed = read(write(workbook))
  let comments = parsed.get_comments("Sheet1")
  inspect(comments.length(), content="1")
  inspect(
    (comments[0].cell, comments[0].author, comments[0].text),
    content="(\"A1\", \"tester\", \"note\")",
  )
}

///|
test "mbtexcel e2e conditional format roundtrip" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let opt = @xlsx.ConditionalFormatOptions::new("cell")
  opt.criteria = ">"
  opt.value = "6"
  workbook.set_conditional_format("Sheet1", "A1:A2", [opt])
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet xml")
  }
  inspect(sheet_xml.contains("conditionalFormatting"), content="true")
  inspect(sheet_xml.contains("type=\"cellIs\""), content="true")
  inspect(sheet_xml.contains("<formula>6</formula>"), content="true")
}

///|
test "mbtexcel e2e sheet props roundtrip" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let props = @xlsx.SheetPropsOptions::with_values(
    code_name="SheetCode",
    fit_to_page=true,
    tab_color_rgb="FF0000",
  )
  workbook.set_sheet_props("Sheet1", Some(props))
  let parsed = read(write(workbook))
  let parsed_props = parsed.get_sheet_props("Sheet1")
  inspect(parsed_props.code_name, content="Some(\"SheetCode\")")
  inspect(parsed_props.fit_to_page, content="Some(true)")
  inspect(parsed_props.tab_color_rgb, content="Some(\"FF0000\")")
}

///|
test "mbtexcel e2e workbook props roundtrip" {
  let workbook = new_workbook()
  let props = @xlsx.WorkbookPropsOptions::with_values(
    date_1904=true,
    filter_privacy=true,
    code_name="BookCode",
  )
  workbook.set_workbook_props(Some(props))
  let parsed = read(write(workbook))
  let parsed_props = parsed.get_workbook_props()
  inspect(parsed_props.date_1904, content="Some(true)")
  inspect(parsed_props.filter_privacy, content="Some(true)")
  inspect(parsed_props.code_name, content="Some(\"BookCode\")")
}

///|
test "mbtexcel e2e workbook protection xml" {
  let workbook = new_workbook()
  let opts = @xlsx.WorkbookProtectionOptions::with_values(
    password="secret",
    lock_structure=true,
  )
  workbook.protect_workbook(options=opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook xml")
  }
  inspect(workbook_xml.contains("workbookProtection"), content="true")
  inspect(workbook_xml.contains("lockStructure=\"1\""), content="true")
}

///|
test "mbtexcel e2e page breaks" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.insert_page_break("Sheet1", "B2")
  let parsed = read(write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(sheet.row_breaks().length(), content="1")
  inspect(sheet.col_breaks().length(), content="1")
}

///|
test "mbtexcel e2e custom properties" {
  let workbook = new_workbook()
  workbook.set_custom_props(
    @xlsx.CustomProperty::new(
      "Text",
      Some(@xlsx.CustomPropertyValue::Text("hello")),
    ),
  )
  workbook.set_custom_props(
    @xlsx.CustomProperty::new(
      "Count",
      Some(@xlsx.CustomPropertyValue::Integer(3)),
    ),
  )
  let parsed = read(write(workbook))
  let props = parsed.get_custom_props()
  inspect(props.length(), content="2")
  inspect((props[0].name, props[1].name), content="(\"Text\", \"Count\")")
}

///|
test "mbtexcel e2e core and app properties" {
  let workbook = new_workbook()
  let core = @xlsx.CoreProperties::with_values(title="Title", creator="Author")
  let app = @xlsx.AppProperties::with_values(
    application="mbtexcel",
    company="MoonBit",
  )
  workbook.set_core_properties(core)
  workbook.set_app_properties(app)
  let parsed = read(write(workbook))
  let parsed_core = parsed.core_properties()
  let parsed_app = parsed.app_properties()
  inspect(parsed_core.title, content="Title")
  inspect(parsed_core.creator, content="Author")
  inspect(parsed_app.application, content="mbtexcel")
  inspect(parsed_app.company, content="MoonBit")
}

///|
test "mbtexcel e2e page layout and margins" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let margins = @xlsx.PageLayoutMarginsOptions::with_values(
    top=0.5,
    bottom=0.6,
    left=0.7,
    right=0.8,
    header=0.9,
    footer=1.0,
    horizontally=true,
    vertically=true,
  )
  let layout = @xlsx.PageLayoutOptions::with_values(
    orientation="landscape",
    fit_to_width=2,
    fit_to_height=1,
    black_and_white=true,
  )
  workbook.set_page_margins("Sheet1", Some(margins))
  workbook.set_page_layout("Sheet1", Some(layout))
  let parsed = read(write(workbook))
  let parsed_margins = parsed.get_page_margins("Sheet1")
  let parsed_layout = parsed.get_page_layout("Sheet1")
  inspect(parsed_margins.top, content="Some(0.5)")
  inspect(parsed_margins.footer, content="Some(1)")
  inspect(parsed_margins.horizontally, content="Some(true)")
  inspect(parsed_layout.orientation, content="Some(\"landscape\")")
  inspect(parsed_layout.fit_to_width, content="Some(2)")
  inspect(parsed_layout.black_and_white, content="Some(true)")
}

///|
test "mbtexcel e2e sheet view panes and dimension" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let view = @xlsx.SheetViewOptions::with_values(
    show_grid_lines=false,
    show_row_col_headers=false,
    top_left_cell="B2",
    zoom_scale=120.0,
  )
  workbook.set_sheet_view("Sheet1", 0, view)
  let selection = @xlsx.Selection::with_values(
    sqref="B3",
    active_cell="B3",
    pane="bottomRight",
  )
  let panes = @xlsx.Panes::with_values(
    freeze=true,
    x_split=1,
    y_split=2,
    top_left_cell="B3",
    active_pane="bottomRight",
    selection=[selection],
  )
  workbook.set_panes("Sheet1", panes)
  workbook.set_sheet_dimension("Sheet1", "A1:C3")
  let parsed = read(write(workbook))
  let parsed_view = parsed.get_sheet_view("Sheet1", 0)
  inspect(parsed_view.show_grid_lines == Some(false), content="true")
  inspect(parsed_view.top_left_cell == Some("B2"), content="true")
  inspect(parsed_view.zoom_scale == Some(120.0), content="true")
  let parsed_panes = parsed.get_panes("Sheet1")
  inspect(parsed_panes.freeze, content="true")
  inspect(parsed_panes.x_split, content="1")
  inspect(parsed_panes.y_split, content="2")
  inspect(parsed_panes.top_left_cell, content="B3")
  inspect(parsed.get_sheet_dimension("Sheet1"), content="A1:C3")
}

///|
test "mbtexcel e2e calc props and default font" {
  let workbook = new_workbook()
  let calc = @xlsx.CalcPropsOptions::with_values(
    calc_id=123,
    calc_mode="manual",
    full_calc_on_load=true,
    iterate=true,
    iterate_count=10,
    iterate_delta=0.001,
    calc_on_save=true,
    force_full_calc=true,
  )
  workbook.set_calc_props(Some(calc))
  workbook.set_default_font("Courier New")
  let parsed = read(write(workbook))
  let parsed_calc = parsed.get_calc_props()
  inspect(parsed_calc.calc_id == Some(123), content="true")
  inspect(parsed_calc.calc_mode == Some("manual"), content="true")
  inspect(parsed_calc.full_calc_on_load == Some(true), content="true")
  inspect(parsed_calc.iterate == Some(true), content="true")
  inspect(parsed_calc.iterate_count == Some(10), content="true")
  inspect(parsed_calc.iterate_delta == Some(0.001), content="true")
  inspect(parsed_calc.calc_on_save == Some(true), content="true")
  inspect(parsed_calc.force_full_calc == Some(true), content="true")
  inspect(parsed.get_default_font(), content="Courier New")
}

///|
test "mbtexcel e2e sheet visibility" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Hidden"))
  workbook.set_sheet_visible("Hidden", false)
  let parsed = read(write(workbook))
  inspect(parsed.sheet_visible("Hidden"), content="false")
}

///|
test "mbtexcel e2e active sheet index" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  workbook.set_active_sheet(1)
  let parsed = read(write(workbook))
  inspect(parsed.active_sheet_index(), content="1")
  parsed.set_active_sheet(99)
  inspect(parsed.active_sheet_index(), content="0")
}

///|
test "mbtexcel e2e vba project roundtrip" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let vba_header : Array[Byte] = [
    0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1,
  ]
  let vba_bytes : Bytes = Bytes::from_array(vba_header)
  workbook.add_vba_project(vba_bytes)
  let bytes = write(workbook)
  let parsed = read(bytes)
  let bytes2 = write(parsed)
  let archive = @zip.read(bytes2)
  let vba_part = match archive.get("xl/vbaProject.bin") {
    Some(value) => value
    None => fail("missing vba project")
  }
  inspect(vba_part == vba_bytes, content="true")
  let types_xml = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(
    types_xml.contains("application/vnd.ms-office.vbaProject"),
    content="true",
  )
}

///|
test "mbtexcel e2e ignored errors roundtrip" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_ignored_errors("Sheet1", "A1", @xlsx.IgnoredErrorType::EvalError)
  workbook.add_ignored_errors(
    "Sheet1",
    "B2:C3",
    @xlsx.IgnoredErrorType::NumberStoredAsText,
  )
  let parsed = read(write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  let ignored = sheet.ignored_errors()
  inspect(ignored.length(), content="2")
  inspect(ignored[0].sqref, content="A1")
  inspect(ignored[0].eval_error, content="true")
  inspect(ignored[1].sqref, content="B2:C3")
  inspect(ignored[1].number_stored_as_text, content="true")
}

///|
test "mbtexcel e2e pivot table roundtrip" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(
    workbook.add_pivot_table_xml(
      "Sheet1",
      "<pivotTableDefinition name=\"PivotE2E\"/>",
      "<pivotCacheDefinition cacheId=\"1\"/>",
      cache_records_xml="<pivotCacheRecords count=\"0\"/>",
    ),
  )
  let parsed = read(write(workbook))
  let pivots = parsed.get_pivot_tables("Sheet1")
  inspect(pivots.length(), content="1")
  inspect(pivots[0].name, content="PivotE2E")
  inspect(
    pivots[0].table_xml,
    content="<pivotTableDefinition name=\"PivotE2E\"/>",
  )
  inspect(
    pivots[0].cache_definition_xml,
    content="<pivotCacheDefinition cacheId=\"1\"/>",
  )
  inspect(
    pivots[0].cache_records_xml,
    content="Some(\"<pivotCacheRecords count=\\\"0\\\"/>\")",
  )
}

///|
test "mbtexcel e2e vml drawing roundtrip" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_vml_drawing_xml("Sheet1", "<xml>vml</xml>")
  workbook.add_vml_drawing_hf_xml("Sheet1", "<xml>hf</xml>")
  let parsed = read(write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(sheet.vml_drawing_xml(), content="Some(\"<xml>vml</xml>\")")
  inspect(sheet.vml_drawing_hf_xml(), content="Some(\"<xml>hf</xml>\")")
}

///|
test "mbtexcel e2e form control and slicer" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_table("Sheet1", "A1:B2", "Table1", ["SlicerE2E", "B"]))
  let control = @xlsx.FormControl::new("B2", "Button", text="Click")
  workbook.add_form_control("Sheet1", control)
  let slicer_opts = @xlsx.SlicerOptions::new(
    "SlicerE2E", "E1", "Sheet1", "Table1",
  )
  slicer_opts.set_caption("SlicerE2E")
  workbook.add_slicer("Sheet1", slicer_opts)
  inspect(workbook.get_form_controls("Sheet1").length(), content="1")
  inspect(workbook.get_slicers("Sheet1").length(), content="1")
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let vml_xml = match archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing vml drawing")
  }
  inspect(vml_xml.contains("ObjectType=\"Button\""), content="true")
  let slicer_xml = match archive.get("xl/slicers/slicer1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing slicer xml")
  }
  inspect(slicer_xml.contains("name=\"SlicerE2E\""), content="true")
}

///|
test "mbtexcel e2e delete table and slicer/form control" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let table = workbook.add_table("Sheet1", "A1:B2", "TableE2E", [
    "SlicerDel", "B",
  ])
  let control = @xlsx.FormControl::new("C3", "Button", text="Go")
  workbook.add_form_control("Sheet1", control)
  let slicer_opts = @xlsx.SlicerOptions::new(
    "SlicerDel", "E1", "Sheet1", "TableE2E",
  )
  workbook.add_slicer("Sheet1", slicer_opts)
  inspect(workbook.get_tables("Sheet1").length(), content="1")
  inspect(workbook.get_form_controls("Sheet1").length(), content="1")
  inspect(workbook.get_slicers("Sheet1").length(), content="1")
  workbook.delete_table(table.name)
  workbook.delete_form_control("Sheet1", "C3")
  workbook.delete_slicer("SlicerDel")
  inspect(workbook.get_tables("Sheet1").length(), content="0")
  inspect(workbook.get_form_controls("Sheet1").length(), content="0")
  inspect(workbook.get_slicers("Sheet1").length(), content="0")
  let missing_table : Result[Unit, Error] = try? workbook.delete_table("Nope")
  inspect(missing_table is Err(_), content="true")
  let missing_slicer : Result[Unit, Error] = try? workbook.delete_slicer("Nope")
  inspect(missing_slicer is Err(_), content="true")
}

///|
test "mbtexcel e2e group and ungroup sheets" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  ignore(workbook.add_sheet("Sheet3"))
  workbook.set_active_sheet(1)
  let bad_group : Result[Unit, Error] = try? workbook.group_sheets([
    "Sheet1", "Sheet3",
  ])
  inspect(
    bad_group is Err(@xlsx.XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  workbook.group_sheets(["Sheet2", "Sheet3"])
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let sheet2_xml = match archive.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet2 xml")
  }
  inspect(sheet2_xml.contains("tabSelected=\"1\""), content="true")
  workbook.ungroup_sheets()
  let bytes2 = write(workbook)
  let archive2 = @zip.read(bytes2)
  let sheet3_xml = match archive2.get("xl/worksheets/sheet3.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet3 xml")
  }
  inspect(sheet3_xml.contains("tabSelected=\"1\""), content="false")
}

///|
test "mbtexcel e2e row and col helpers" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_row("Sheet1", 1, ["A", "B", "C"])
  workbook.set_col("Sheet1", 2, ["X", "Y"])
  let parsed = read(write(workbook))
  inspect(parsed.get_row("Sheet1", 1), content="[\"A\", \"X\", \"C\"]")
  inspect(parsed.get_col("Sheet1", 2), content="[\"X\", \"Y\"]")
}

///|
test "mbtexcel e2e merge cells info and calc" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "10")
  workbook.set_cell("Sheet1", "A2", "5")
  workbook.set_cell_formula("Sheet1", "B1", "A1+A2")
  workbook.merge_cells("Sheet1", "A1:B1")
  let merges = workbook.get_merge_cells_info("Sheet1")
  inspect(merges.length(), content="1")
  inspect((merges[0].range_ref, merges[0].value), content="(\"A1:B1\", \"10\")")
  let merges_wo = workbook.get_merge_cells_info("Sheet1", without_values=true)
  inspect(merges_wo[0].value, content="")
  inspect(workbook.calc_cell_value("Sheet1", "B1"), content="15")
  let parsed = read(write(workbook))
  inspect(parsed.calc_cell_value("Sheet1", "B1"), content="15")
}

///|
test "mbtexcel e2e chart and shape via workbook api" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let chart_xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart">
    #|  <c:chart/>
    #|</c:chartSpace>
  workbook.add_chart("Sheet1", "C3", chart_xml)
  let shape = @xlsx.Shape::new("A1", "rect", text="Hello")
  workbook.add_shape("Sheet1", shape)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let chart = match archive.get("xl/charts/chart1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing chart")
  }
  inspect(chart.contains("<c:chartSpace"), content="true")
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("graphicFrame"), content="true")
  inspect(drawing_xml.contains("prst=\"rect\""), content="true")
}

///|
test "mbtexcel e2e chart sheet roundtrip" {
  let workbook = new_workbook()
  let chart_xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart">
    #|  <c:chart/>
    #|</c:chartSpace>
  ignore(workbook.add_chart_sheet("Chart1", chart_xml))
  let parsed = read(write(workbook))
  let chart = match parsed.chart_sheet("Chart1") {
    Some(value) => value
    None => fail("missing chart sheet")
  }
  inspect(chart.name(), content="Chart1")
  inspect(chart.chart_xml().contains("<c:chartSpace"), content="true")
}

///|
test "mbtexcel e2e picture via workbook api" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  let img : Bytes = [1, 2, 3, 4]
  workbook.add_picture_from_bytes("Sheet1", "B2", img, ".png")
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let stored = match archive.get("xl/media/image1.png") {
    Some(value) => value
    None => fail("missing image1.png")
  }
  inspect(stored == img, content="true")
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("<xdr:pic"), content="true")
  let types_xml = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(types_xml.contains("Extension=\"png\""), content="true")
}
