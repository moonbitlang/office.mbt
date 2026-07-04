///|
test "workbook: add_sheet duplicate + stream writer conflicts" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let dup : Result[Worksheet, Error] = try? workbook.add_sheet("Sheet1")
  inspect(dup is Err(XlsxError::SheetAlreadyExists(_)), content="true")
  let missing : Result[StreamWriter, Error] = try? workbook.new_stream_writer(
    "Missing",
  )
  inspect(missing is Err(XlsxError::SheetNotFound(_)), content="true")

  // Stream writer already active.
  let w2 = Workbook::new()
  ignore(w2.add_sheet("Sheet1"))
  let first : Result[StreamWriter, Error] = try? w2.new_stream_writer("Sheet1")
  inspect(first is Ok(_), content="true")
  let second : Result[StreamWriter, Error] = try? w2.new_stream_writer("Sheet1")
  inspect(second is Err(XlsxError::StreamModeConflict(_)), content="true")

  // Worksheet already has data.
  let w3 = Workbook::new()
  let s3 = w3.add_sheet("Sheet1")
  s3.set_cell("A1", "x")
  let has_data : Result[StreamWriter, Error] = try? w3.new_stream_writer(
    "Sheet1",
  )
  inspect(has_data is Err(XlsxError::StreamModeConflict(_)), content="true")
}

///|
test "workbook: properties + custom properties replace/remove" {
  let workbook = Workbook::new()

  // Ensure these simple getters are exercised.
  inspect(workbook.defined_names().length(), content="0")
  let p = CoreProperties::with_values(title="t", creator="c")
  workbook.set_doc_properties(p)
  inspect(workbook.doc_properties().title, content="t")
  inspect(workbook.core_properties().creator, content="c")
  let app = workbook.app_properties()
  workbook.set_app_props(app)
  inspect(workbook.get_app_props().application, content=app.application)
  inspect(workbook.app_props().application, content=app.application)

  // custom prop name missing.
  let bad_name : Result[Unit, Error] = try? workbook.set_custom_props(
    CustomProperty::new("", Some(Text("x"))),
  )
  inspect(
    bad_name is Err(XlsxError::InvalidWorkbookProperty(_)),
    content="true",
  )

  // add + replace.
  workbook.set_custom_props(CustomProperty::new("k", Some(Text("v1"))))
  workbook.set_custom_props(CustomProperty::new("k", Some(Text("v2"))))
  debug_inspect(
    workbook.get_custom_props(),
    content=(
      #|[{ name: "k", value: Some(Text("v2")) }]
    ),
  )

  // remove existing + remove non-existing (no-op).
  workbook.set_custom_props(CustomProperty::new("k", None))
  workbook.set_custom_props(CustomProperty::new("missing", None))
  inspect(workbook.custom_properties().length(), content="0")

  // set_*_props default None branches.
  workbook.set_workbook_props(None)
  workbook.set_calc_props(None)
  inspect(workbook.get_calc_props() == CalcPropsOptions::new(), content="true")
}

///|
test "workbook: protect/unprotect, rename, delete, move, copy, visibility" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  ignore(workbook.add_chart_sheet("Chart1", "<chart/>"))

  // unprotect when not protected.
  let unprot : Result[Unit, Error] = try? workbook.unprotect_workbook()
  inspect(
    unprot is Err(XlsxError::InvalidWorkbookProtection(_)),
    content="true",
  )
  workbook.protect_workbook()
  workbook.unprotect_workbook()

  // rename no-op + not found + already exists.
  workbook.set_sheet_name("Sheet1", "Sheet1")
  let rename_missing : Result[Unit, Error] = try? workbook.set_sheet_name(
    "Missing", "X",
  )
  inspect(rename_missing is Err(XlsxError::SheetNotFound(_)), content="true")
  let rename_exists : Result[Unit, Error] = try? workbook.set_sheet_name(
    "Sheet1", "Sheet2",
  )
  inspect(
    rename_exists is Err(XlsxError::SheetAlreadyExists(_)),
    content="true",
  )

  // rename chart sheet branch.
  workbook.set_sheet_name("Chart1", "ChartRenamed")
  inspect(workbook.get_sheet_list().contains("ChartRenamed"), content="true")

  // defined names updated on rename, and removed on delete.
  workbook.set_defined_name(
    DefinedName::new("Dn", "Sheet1!$A$1", scope="Sheet1"),
  )
  workbook.set_sheet_name("Sheet1", "S1")
  inspect(workbook.defined_names().length(), content="1")
  inspect(workbook.defined_names()[0].scope, content="S1")
  inspect(workbook.defined_names()[0].refers_to.contains("S1!"), content="true")

  // delete no-op when only one sheet left.
  let single = Workbook::new()
  ignore(single.add_sheet("Only"))
  single.delete_sheet("Only")
  inspect(single.get_sheet_list().length(), content="1")

  // delete chart sheet branch + defined name removal.
  workbook.set_defined_name(
    DefinedName::new("Dn2", "ChartRenamed!$A$1", scope="ChartRenamed"),
  )
  workbook.delete_sheet("ChartRenamed")
  inspect(workbook.get_sheet_list().contains("ChartRenamed"), content="false")

  // defined names removed for deleted worksheet scope.
  workbook.set_defined_name(
    DefinedName::new("Dn3", "Sheet2!$A$1", scope="Sheet2"),
  )
  workbook.delete_sheet("Sheet2")
  inspect(workbook.defined_names().length(), content="2")

  // move_sheet: early return + active sheet adjustments.
  workbook.move_sheet("S1", "S1")
  let m1 = Workbook::new()
  ignore(m1.add_sheet("A"))
  ignore(m1.add_sheet("B"))
  ignore(m1.add_sheet("C"))
  ignore(m1.add_sheet("D"))
  m1.set_active_sheet(2)
  m1.move_sheet("A", "D")
  inspect(m1.active_sheet_index(), content="1")
  let m2 = Workbook::new()
  ignore(m2.add_sheet("A"))
  ignore(m2.add_sheet("B"))
  ignore(m2.add_sheet("C"))
  ignore(m2.add_sheet("D"))
  m2.set_active_sheet(1)
  m2.move_sheet("D", "A")
  inspect(m2.active_sheet_index(), content="2")

  // copy_sheet invalid indices + invalid entry kind combination.
  let bad_copy : Result[Unit, Error] = try? workbook.copy_sheet(0, 0)
  inspect(bad_copy is Err(XlsxError::InvalidSheetIndex(_)), content="true")
  let combo : Result[Unit, Error] = try? workbook.copy_sheet(2, 0)
  inspect(combo is Err(XlsxError::InvalidSheetIndex(_)), content="true")

  // visibility checks.
  let vis_missing : Result[Bool, Error] = try? workbook.sheet_visible("Missing")
  inspect(vis_missing is Err(XlsxError::SheetNotFound(_)), content="true")
  let one = Workbook::new()
  ignore(one.add_sheet("Only"))
  let hide_all : Result[Unit, Error] = try? one.set_sheet_visible("Only", false)
  inspect(hide_all is Err(XlsxError::InvalidSheetOperation(_)), content="true")
  let vis = Workbook::new()
  ignore(vis.add_sheet("A"))
  ignore(vis.add_sheet("B"))
  vis.set_sheet_visible("A", false, very_hidden=true)
  inspect(vis.sheet_visible("A"), content="false")

  // page margin/layout wrappers: missing sheet.
  let pm : Result[Unit, Error] = try? workbook.set_page_margins("Missing", None)
  inspect(pm is Err(XlsxError::SheetNotFound(_)), content="true")
  let pl : Result[Unit, Error] = try? workbook.set_page_layout("Missing", None)
  inspect(pl is Err(XlsxError::SheetNotFound(_)), content="true")
}

///|
test "workbook: delete/move edge cases (chart sheets + active fallback)" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("S1"))
  ignore(workbook.add_sheet("S2"))
  ignore(workbook.add_chart_sheet("C1", "<chart/>"))
  ignore(workbook.add_chart_sheet("C2", "<chart/>"))
  ignore(workbook.add_chart_sheet("C3", "<chart/>"))
  ignore(workbook.add_sheet("S3"))

  // Delete active sheet at the end -> fallback uses last index.
  workbook.set_active_sheet(5)
  workbook.delete_sheet("S3")
  inspect(workbook.active_sheet_index(), content="4")

  // Delete a worksheet while chart sheets exist -> hits ChartSheet pass-through branch.
  workbook.delete_sheet("S2")
  debug_inspect(
    workbook.get_sheet_list(),
    content="[\"S1\", \"C1\", \"C2\", \"C3\"]",
  )

  // Delete middle chart sheet -> hits both value>idx and value<=idx adjustment branches.
  workbook.delete_sheet("C2")
  debug_inspect(workbook.get_sheet_list(), content="[\"S1\", \"C1\", \"C3\"]")

  // move_sheet: active == source branch.
  let m = Workbook::new()
  ignore(m.add_sheet("A"))
  ignore(m.add_sheet("B"))
  ignore(m.add_sheet("C"))
  m.set_active_sheet(0)
  m.move_sheet("A", "C")
  debug_inspect(m.get_sheet_list(), content="[\"B\", \"A\", \"C\"]")
  inspect(m.active_sheet_index(), content="1")

  // set_sheet_visible: visible==true branch.
  let v = Workbook::new()
  ignore(v.add_sheet("A"))
  ignore(v.add_sheet("B"))
  v.set_sheet_visible("A", false)
  v.set_sheet_visible("A", true)
  inspect(v.sheet_visible("A"), content="true")

  // Wrapper getters: missing sheet -> SheetNotFound.
  let pm : Result[PageLayoutMarginsOptions, Error] = try? v.get_page_margins(
    "Missing",
  )
  inspect(pm is Err(XlsxError::SheetNotFound(_)), content="true")
  let pl : Result[PageLayoutOptions, Error] = try? v.get_page_layout("Missing")
  inspect(pl is Err(XlsxError::SheetNotFound(_)), content="true")
  let hf : Result[HeaderFooterOptions?, Error] = try? v.get_header_footer(
    "Missing",
  )
  inspect(hf is Err(XlsxError::SheetNotFound(_)), content="true")
  let hfi : Result[Array[HeaderFooterImageOptions], Error] = try? v.get_header_footer_images(
    "Missing",
  )
  inspect(hfi is Err(XlsxError::SheetNotFound(_)), content="true")
  let sp : Result[SheetPropsOptions, Error] = try? v.get_sheet_props("Missing")
  inspect(sp is Err(XlsxError::SheetNotFound(_)), content="true")

  // Delete active sheet in the middle -> fallback uses order_index (not last).
  let mid = Workbook::new()
  ignore(mid.add_sheet("A"))
  ignore(mid.add_sheet("B"))
  ignore(mid.add_sheet("C"))
  mid.set_active_sheet(1)
  mid.delete_sheet("B")
  debug_inspect(mid.get_sheet_list(), content="[\"A\", \"C\"]")
  inspect(mid.active_sheet_index(), content="1")

  // copy_sheet: invalid entry kind combination (worksheet -> chart sheet).
  let combo = Workbook::new()
  ignore(combo.add_sheet("A"))
  ignore(combo.add_chart_sheet("C", "<chart/>"))
  ignore(combo.add_sheet("B"))
  let copy_result : Result[Unit, Error] = try? combo.copy_sheet(0, 1)
  inspect(copy_result is Err(XlsxError::InvalidSheetIndex(_)), content="true")

  // set_sheet_visible: missing sheet.
  let set_vis : Result[Unit, Error] = try? v.set_sheet_visible("Missing", false)
  inspect(set_vis is Err(XlsxError::SheetNotFound(_)), content="true")

  // Wrapper setters: missing sheet -> SheetNotFound.
  let set_hf : Result[Unit, Error] = try? v.set_header_footer("Missing", None)
  inspect(set_hf is Err(XlsxError::SheetNotFound(_)), content="true")
  let set_sp : Result[Unit, Error] = try? v.set_sheet_props("Missing", None)
  inspect(set_sp is Err(XlsxError::SheetNotFound(_)), content="true")
  let set_sv : Result[Unit, Error] = try? v.set_sheet_view(
    "Missing",
    0,
    SheetViewOptions::new(),
  )
  inspect(set_sv is Err(XlsxError::SheetNotFound(_)), content="true")
}

///|
test "workbook: missing-sheet wrappers raise SheetNotFound" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let panes = Panes::new()
  let get_view : Result[SheetViewOptions, Error] = try? workbook.get_sheet_view(
    "Missing", 0,
  )
  inspect(get_view is Err(XlsxError::SheetNotFound(_)), content="true")
  let set_panes : Result[Unit, Error] = try? workbook.set_panes(
    "Missing", panes,
  )
  inspect(set_panes is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_panes : Result[Panes, Error] = try? workbook.get_panes("Missing")
  inspect(get_panes is Err(XlsxError::SheetNotFound(_)), content="true")
  let set_dim : Result[Unit, Error] = try? workbook.set_sheet_dimension(
    "Missing", "A1:B2",
  )
  inspect(set_dim is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_dim : Result[String, Error] = try? workbook.get_sheet_dimension(
    "Missing",
  )
  inspect(get_dim is Err(XlsxError::SheetNotFound(_)), content="true")
  let protect : Result[Unit, Error] = try? workbook.protect_sheet(
    "Missing",
    SheetProtectionOptions::new(),
  )
  inspect(protect is Err(XlsxError::SheetNotFound(_)), content="true")
  let unprotect : Result[Unit, Error] = try? workbook.unprotect_sheet("Missing")
  inspect(unprotect is Err(XlsxError::SheetNotFound(_)), content="true")
  let set_bg : Result[Unit, Error] = try? workbook.set_sheet_background(
    "Missing",
    Bytes::from_array([0]),
    "png",
  )
  inspect(set_bg is Err(XlsxError::SheetNotFound(_)), content="true")
  let clear_bg : Result[Unit, Error] = try? workbook.clear_sheet_background(
    "Missing",
  )
  inspect(clear_bg is Err(XlsxError::SheetNotFound(_)), content="true")
  let insert_break : Result[Unit, Error] = try? workbook.insert_page_break(
    "Missing", "B2",
  )
  inspect(insert_break is Err(XlsxError::SheetNotFound(_)), content="true")
  let remove_break : Result[Unit, Error] = try? workbook.remove_page_break(
    "Missing", "B2",
  )
  inspect(remove_break is Err(XlsxError::SheetNotFound(_)), content="true")
  let rs : Result[RowStream, Error] = try? workbook.row_stream("Missing")
  inspect(rs is Err(XlsxError::SheetNotFound(_)), content="true")
}

///|
test "workbook: group/ungroup edge cases" {
  // active sheet index out of range (no sheets) -> active_name == "" branch.
  let empty = Workbook::new()
  let no_active : Result[Unit, Error] = try? empty.group_sheets(["A"])
  inspect(no_active is Err(XlsxError::InvalidSheetOperation(_)), content="true")
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("A"))
  ignore(workbook.add_chart_sheet("C1", "<chart/>"))
  ignore(workbook.add_sheet("B"))
  workbook.set_active_sheet(0)

  // Contains active, but has a missing member.
  let missing : Result[Unit, Error] = try? workbook.group_sheets([
    "A", "Missing",
  ])
  inspect(missing is Err(XlsxError::SheetNotFound(_)), content="true")

  // Successful group then ungroup should ignore chart sheets.
  workbook.group_sheets(["A", "B"])
  workbook.ungroup_sheets()
}

///|
test "workbook: invalid defined name/style ids and chart sheet set_cell" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  ignore(workbook.add_chart_sheet("Chart1", "<chart/>"))
  let bad_dn : Result[Unit, Error] = try? workbook.set_defined_name(
    DefinedName::new("", "Sheet1!$A$1"),
  )
  inspect(bad_dn is Err(XlsxError::InvalidDefinedName(_)), content="true")
  let bad_cond_style : Result[Style, Error] = try? workbook.get_conditional_style(
    0,
  )
  inspect(bad_cond_style is Err(XlsxError::InvalidStyleId(_)), content="true")
  sheet.set_cell("A1", "x")
  sheet.set_cell_style("A1", 999)
  let bad_fmt : Result[String?, Error] = try? workbook.get_cell_value(
    "Sheet1", "A1",
  )
  inspect(bad_fmt is Err(XlsxError::InvalidStyleId(_)), content="true")
  let chart_set : Result[Unit, Error] = try? workbook.set_cell(
    "Chart1", "A1", "x",
  )
  inspect(chart_set is Err(XlsxError::InvalidSheetOperation(_)), content="true")
  workbook.set_cell_float("Sheet1", "B2", 1.2345, bit_size=32)
  workbook.set_cell_float("Sheet1", "C3", 1.2345, precision=2, bit_size=32)
}

///|
test "workbook: copy_sheet clones complex worksheet state" {
  let workbook = Workbook::new()
  let src = workbook.add_sheet("Src")
  ignore(workbook.add_sheet("Dst"))

  // Populate a variety of worksheet state that clone_worksheet should copy.
  src.set_cell("A1", "v")
  src.merge_cells("A1:B2")
  src.set_cell_hyperlink("B2", "https://example.com", External)
  src.add_comment({
    cell: "A1",
    author: "me",
    author_id: None,
    text: "note",
    paragraph: [
      { text: "a", font: None },
      {
        text: "b",
        font: Some({
          bold: true,
          italic: false,
          strike: false,
          outline: false,
          shadow: false,
          condense: false,
          extend: false,
          underline: None,
          size: None,
          color: None,
          color_theme: None,
          color_indexed: None,
          color_tint: None,
          charset: None,
          family_number: None,
          scheme: None,
          vert_align: None,
          family: None,
        }),
      },
    ],
    width: None,
    height: None,
  })
  ignore(workbook.add_table_with_columns("Src", "A1:B2", "Table1", ["A", "B"]))
  src.add_sparkline("C3", "A1:A2")
  src.set_auto_filter("A1:B2", [])
  src.add_data_validation_list("D1:D2", ["Yes", "No"])
  src.add_conditional_format_xml("<conditionalFormatting/>")
  src.add_ignored_errors("A1", EvalError)
  src.set_row_height(2, 18.0)
  src.set_col_width(2, 12.0)
  workbook.set_sheet_view(
    "Src",
    0,
    SheetViewOptions::with_values(zoom_scale=120.0),
  )
  src.add_header_footer_image(
    HeaderFooterImageOptions::new(
      Left,
      [1, 2, 3],
      ".png",
      width="1pt",
      height="1pt",
    ),
  )
  src.add_image("E5", b"img", "png", "image/png")
  src.add_chart("F6", "<chart/>")
  src.add_shape(try! Shape::new("G7", "rect"))
  src.add_form_control(try! FormControl::new("H8", "checkbox"))
  src.add_slicer(try! Slicer::new("S1"))
  workbook.set_panes(
    "Src",
    Panes::with_values(
      freeze=false,
      split=false,
      x_split=1,
      y_split=1,
      top_left_cell="B2",
      active_pane="bottomRight",
      selection=[
        Selection::with_values(sqref="B2", active_cell="B2", pane="bottomRight"),
      ],
    ),
  )
  workbook.set_sheet_background("Src", Bytes::from_array([0]), "png")
  workbook.insert_page_break("Src", "B2")

  // copy Src -> Dst (worksheets).
  workbook.copy_sheet(0, 1)
  let dst = match workbook.sheet("Dst") {
    Some(value) => value
    None => fail("missing Dst")
  }
  debug_inspect(dst.get_cell("A1"), content="Some(\"v\")")
  debug_inspect(dst.merged_cells().to_owned(), content="[\"A1:B2\"]")
  inspect(dst.get_cell_hyperlink("A1") is Some(_), content="true")
  inspect(workbook.get_tables("Dst").length(), content="1")
  inspect(dst.sparkline_groups().length(), content="1")
  inspect(dst.auto_filter() is Some(_), content="true")
  inspect(dst.data_validations().length() > 0, content="true")
  inspect(dst.conditional_formats().length() > 0, content="true")
  inspect(dst.comments().length(), content="1")
  workbook.clear_sheet_background("Src")
}

///|
test "workbook: missing-sheet cell/media wrapper guards" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let rich : Array[RichTextRun] = [{ text: "x", font: None }]
  let shape = Shape::new("A1", "rect") catch {
    err => fail("shape init failed: \{err}")
  }
  let control = FormControl::new("A1", "checkbox") catch {
    err => fail("form control init failed: \{err}")
  }
  let slicer_opts = SlicerOptions::new("Field", "A1", "Sheet1", "Table1") catch {
    err => fail("slicer options init failed: \{err}")
  }
  let chart_opts = ChartOptions::new(Bar)
  let image_opts = GraphicOptions::new()

  let set_rich : Result[Unit, Error] = try? workbook.set_cell_rich_text(
    "Missing",
    "A1",
    rich[:],
  )
  inspect(set_rich is Err(XlsxError::SheetNotFound(_)), content="true")
  let set_link : Result[Unit, Error] = try? workbook.set_cell_hyperlink(
    "Missing",
    "A1",
    "https://example.com",
    External,
  )
  inspect(set_link is Err(XlsxError::SheetNotFound(_)), content="true")
  let set_link_opts : Result[Unit, Error] = try? workbook.set_cell_hyperlink_opts(
    "Missing",
    "A1",
    "https://example.com",
    External,
    opts=HyperlinkOpts::new(),
  )
  inspect(set_link_opts is Err(XlsxError::SheetNotFound(_)), content="true")
  let remove_link : Result[Unit, Error] = try? workbook.remove_cell_hyperlink(
    "Missing", "A1",
  )
  inspect(remove_link is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_cell : Result[String?, Error] = try? workbook.get_cell(
    "Missing", "A1",
  )
  inspect(get_cell is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_rich : Result[Array[RichTextRun]?, Error] = try? workbook.get_cell_rich_text(
    "Missing", "A1",
  )
  inspect(get_rich is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_link : Result[Hyperlink?, Error] = try? workbook.get_cell_hyperlink(
    "Missing", "A1",
  )
  inspect(get_link is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_raw : Result[CellValue?, Error] = try? workbook.get_cell_value_raw(
    "Missing", "A1",
  )
  inspect(get_raw is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_type : Result[CellValueType?, Error] = try? workbook.get_cell_type(
    "Missing", "A1",
  )
  inspect(get_type is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_value : Result[String?, Error] = try? workbook.get_cell_value(
    "Missing", "A1",
  )
  inspect(get_value is Err(XlsxError::SheetNotFound(_)), content="true")
  let calc_value : Result[String, Error] = try? workbook.calc_cell_value(
    "Missing",
    "A1",
    options=Options::with_values(raw_cell_value=true),
  )
  inspect(calc_value is Err(XlsxError::SheetNotFound(_)), content="true")
  let calc_rc : Result[String, Error] = try? workbook.calc_cell_value_rc(
    "Missing",
    1,
    1,
    options=Options::with_values(raw_cell_value=true),
  )
  inspect(calc_rc is Err(XlsxError::SheetNotFound(_)), content="true")
  let set_formula : Result[Unit, Error] = try? workbook.set_cell_formula(
    "Missing", "A1", "1+1",
  )
  inspect(set_formula is Err(XlsxError::SheetNotFound(_)), content="true")
  let set_formula_opts : Result[Unit, Error] = try? workbook.set_cell_formula_opts(
    "Missing", "A1", "1+1",
  )
  inspect(set_formula_opts is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_formula : Result[String?, Error] = try? workbook.get_cell_formula(
    "Missing", "A1",
  )
  inspect(get_formula is Err(XlsxError::SheetNotFound(_)), content="true")
  let set_style : Result[Unit, Error] = try? workbook.set_cell_style(
    "Missing", "A1", 0,
  )
  inspect(set_style is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_style : Result[Int?, Error] = try? workbook.get_cell_style(
    "Missing", "A1",
  )
  inspect(get_style is Err(XlsxError::SheetNotFound(_)), content="true")
  let add_image : Result[Unit, Error] = try? workbook.add_image(
    "Missing",
    "A1",
    [1],
    ".png",
    "image/png",
  )
  inspect(add_image is Err(XlsxError::SheetNotFound(_)), content="true")
  let add_image_opts : Result[Unit, Error] = try? workbook.add_image_with_options(
    "Missing",
    "A1",
    [1],
    ".png",
    "image/png",
    image_opts,
  )
  inspect(add_image_opts is Err(XlsxError::SheetNotFound(_)), content="true")
  let add_picture_bytes : Result[Unit, Error] = try? workbook.add_picture_from_bytes(
    "Missing",
    "A1",
    [1],
    ".png",
  )
  inspect(add_picture_bytes is Err(XlsxError::SheetNotFound(_)), content="true")
  let add_picture_bytes_opts : Result[Unit, Error] = try? workbook.add_picture_from_bytes_with_options(
    "Missing",
    "A1",
    [1],
    ".png",
    GraphicOptions::new(),
  )
  inspect(
    add_picture_bytes_opts is Err(XlsxError::SheetNotFound(_)),
    content="true",
  )
  let add_hf_image : Result[Unit, Error] = try? workbook.add_header_footer_image(
    "Missing",
    HeaderFooterImageOptions::new(Left, [1], ".png"),
  )
  inspect(add_hf_image is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_pictures : Result[Array[Image], Error] = try? workbook.get_pictures(
    "Missing", "A1",
  )
  inspect(get_pictures is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_picture_cells : Result[Array[String], Error] = try? workbook.get_picture_cells(
    "Missing",
  )
  inspect(get_picture_cells is Err(XlsxError::SheetNotFound(_)), content="true")
  let del_picture : Result[Unit, Error] = try? workbook.delete_picture(
    "Missing", "A1",
  )
  inspect(del_picture is Err(XlsxError::SheetNotFound(_)), content="true")
  let add_chart : Result[Unit, Error] = try? workbook.add_chart(
    "Missing", "A1", "<chart/>",
  )
  inspect(add_chart is Err(XlsxError::SheetNotFound(_)), content="true")
  let add_chart_opts : Result[Unit, Error] = try? workbook.add_chart_with_options(
    "Missing", "A1", chart_opts,
  )
  inspect(add_chart_opts is Err(XlsxError::SheetNotFound(_)), content="true")
  let del_chart : Result[Unit, Error] = try? workbook.delete_chart(
    "Missing", "A1",
  )
  inspect(del_chart is Err(XlsxError::SheetNotFound(_)), content="true")
  let add_shape : Result[Unit, Error] = try? workbook.add_shape(
    "Missing", shape,
  )
  inspect(add_shape is Err(XlsxError::SheetNotFound(_)), content="true")
  let add_vml : Result[Unit, Error] = try? workbook.add_vml_drawing_xml(
    "Missing", "<xml/>",
  )
  inspect(add_vml is Err(XlsxError::SheetNotFound(_)), content="true")
  let add_vml_hf : Result[Unit, Error] = try? workbook.add_vml_drawing_hf_xml(
    "Missing", "<xml/>",
  )
  inspect(add_vml_hf is Err(XlsxError::SheetNotFound(_)), content="true")
  let add_control : Result[Unit, Error] = try? workbook.add_form_control(
    "Missing", control,
  )
  inspect(add_control is Err(XlsxError::SheetNotFound(_)), content="true")
  let get_controls : Result[Array[FormControl], Error] = try? workbook.get_form_controls(
    "Missing",
  )
  inspect(get_controls is Err(XlsxError::SheetNotFound(_)), content="true")
  let del_control : Result[Unit, Error] = try? workbook.delete_form_control(
    "Missing", "A1",
  )
  inspect(del_control is Err(XlsxError::SheetNotFound(_)), content="true")
  let add_slicer : Result[Unit, Error] = try? workbook.add_slicer(
    "Missing", slicer_opts,
  )
  inspect(add_slicer is Err(XlsxError::SheetNotFound(_)), content="true")
}

///|
test "workbook: add_image_with_options applies explicit option values" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options = GraphicOptions::with_values(
    offset_x=3,
    offset_y=4,
    scale_x=1.25,
    scale_y=1.5,
    hyperlink="https://example.com",
    hyperlink_type=External,
    name="CustomName",
    alt_text="Alt",
    lock_aspect_ratio=true,
    auto_fit=true,
    auto_fit_ignore_aspect=true,
    print_object=false,
    locked=false,
    positioning=TwoCell,
  )
  workbook.add_image_with_options(
    "Sheet1",
    "B2",
    [1, 2, 3],
    ".png",
    "image/png",
    options,
  )
  let pictures = workbook.get_pictures("Sheet1", "B2")
  inspect(pictures.length(), content="1")
  let picture = pictures[0]
  inspect(picture.offset_x, content="3")
  inspect(picture.offset_y, content="4")
  inspect(picture.scale_x == 1.25, content="true")
  inspect(picture.scale_y == 1.5, content="true")
  inspect(picture.hyperlink, content="https://example.com")
  inspect(picture.hyperlink_type, content="External")
  inspect(picture.name, content="CustomName")
  inspect(picture.alt_text, content="Alt")
  inspect(picture.lock_aspect_ratio, content="true")
  inspect(picture.positioning, content="TwoCell")
  inspect(picture.print_object, content="false")
  inspect(picture.locked, content="false")
}

///|
test "workbook: calc_cell_value raw/options/rc/style branches" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  workbook.set_cell_formula("Sheet1", "A1", "1+1")
  let opts = Options::with_values(raw_cell_value=true)
  inspect(workbook.calc_cell_value("Sheet1", "A1", options=opts), content="2")
  inspect(
    workbook.calc_cell_value_rc("Sheet1", 1, 1, options=opts),
    content="2",
  )
  sheet.set_cell_style("A1", 999)
  let bad_style : Result[String, Error] = try? workbook.calc_cell_value(
    "Sheet1", "A1",
  )
  inspect(bad_style is Err(XlsxError::InvalidStyleId(_)), content="true")
}

///|
#cfg(target="native")
async test "workbook: async missing-sheet picture/header wrappers" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let add_picture_result : Result[Unit, Error] = try? workbook.add_picture(
    "Missing", "A1", "/tmp/does-not-matter.png",
  )
  inspect(
    add_picture_result is Err(XlsxError::SheetNotFound(_)),
    content="true",
  )
  let add_picture_opts_result : Result[Unit, Error] = try? workbook.add_picture_with_options(
    "Missing",
    "A1",
    "/tmp/does-not-matter.png",
    GraphicOptions::new(),
  )
  inspect(
    add_picture_opts_result is Err(XlsxError::SheetNotFound(_)),
    content="true",
  )
  let hf_options = HeaderFooterImageOptions::from_file(
    Left,
    "/tmp/does-not-matter.png",
  ) catch {
    err => fail("header/footer file options init failed: \{err}")
  }
  let add_hf_result : Result[Unit, Error] = try? workbook.add_header_footer_image_from_file(
    "Missing", hf_options,
  )
  inspect(add_hf_result is Err(XlsxError::SheetNotFound(_)), content="true")
}

///|
test "workbook: default graphic options + formula rc wrapper branches" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_formula("Sheet1", "A1", "1+1")
  workbook.set_cell_formula_opts("Sheet1", "B1", "2+2")
  inspect(workbook.get_cell_formula("Sheet1", "B1") is Some(_), content="true")

  // Exercise calc_cell_value_rc options None forwarding.
  inspect(workbook.calc_cell_value_rc("Sheet1", 1, 1), content="2")

  // Exercise add_image_with_options default fan-in (all option fields None).
  workbook.add_image_with_options(
    "Sheet1",
    "C3",
    [1, 2],
    ".png",
    "image/png",
    GraphicOptions::new(),
  )
  let pictures = workbook.get_pictures("Sheet1", "C3")
  inspect(pictures.length(), content="1")
  let picture = pictures[0]
  inspect(picture.offset_x, content="0")
  inspect(picture.offset_y, content="0")
  inspect(picture.scale_x == 1.0, content="true")
  inspect(picture.scale_y == 1.0, content="true")
  inspect(picture.hyperlink, content="")
  inspect(picture.hyperlink_type, content="Unset")
  inspect(picture.name, content="")
  inspect(picture.alt_text, content="")
  inspect(picture.lock_aspect_ratio, content="false")
  inspect(picture.print_object, content="true")
  inspect(picture.locked, content="true")
  inspect(picture.positioning, content="OneCell")
}

///|
test "workbook: validation merge sparkline and rc/style wrapper coverage" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let empty = Workbook::new()
  ignore(empty.add_sheet("Empty"))
  empty.clear_auto_filter("Empty")
  workbook.set_defined_name(
    DefinedName::new("KeepRef", "Sheet1!$Z$1", scope="Sheet1"),
  )

  workbook.set_auto_filter("Sheet1", "A1:B2", [])
  workbook.clear_auto_filter("Sheet1")
  // Second clear hits remove-defined-name empty fast path.
  workbook.clear_auto_filter("Sheet1")

  let dv = DataValidation::new(true)
  dv.set_sqref("A1")
  dv.set_drop_list(["Yes", "No"])
  workbook.add_data_validation("Sheet1", dv)
  workbook.add_data_validation_list("Sheet1", "B1", ["A"])
  ignore(workbook.get_data_validations("Sheet1"))
  workbook.delete_data_validation("Sheet1", sqrefs=["B1"])
  workbook.add_data_validation_xml(
    "Sheet1", "<dataValidation type=\"list\" allowBlank=\"1\" sqref=\"C1\"><formula1>\"X,Y\"</formula1></dataValidation>",
  )

  workbook.add_conditional_format_xml(
    "Sheet1", "<conditionalFormatting sqref=\"A1\"><cfRule type=\"expression\" priority=\"1\"><formula>1=1</formula></cfRule></conditionalFormatting>",
  )

  workbook.merge_cells("Sheet1", "D1:E1")
  let merge_info = workbook.get_merge_cells_info(
    "Sheet1",
    options=Options::new(),
  )
  inspect(merge_info.length(), content="1")
  inspect(merge_info[0].value, content="")
  workbook.unmerge_cells("Sheet1", "D1:E1")

  workbook.set_cell("Sheet1", "A1", "10")
  workbook.add_sparkline_group("Sheet1", ["F2"][:], ["A1:A1"][:])
  workbook.add_sparkline_basic("Sheet1", "F3", "A1:A1")

  workbook.set_cell_value_rc("Sheet1", 2, 2, String("rc"))
  inspect(
    workbook.get_cell_value_raw_rc("Sheet1", 2, 2) is Some(_),
    content="true",
  )
  inspect(workbook.get_cell_value_rc("Sheet1", 2, 2) is Some(_), content="true")
  inspect(
    workbook.get_cell_value_rc("Sheet1", 2, 2, options=Options::new())
    is Some(_),
    content="true",
  )
  workbook.set_cell_style_rc("Sheet1", 2, 2, 0)
  debug_inspect(workbook.get_cell_style_rc("Sheet1", 2, 2), content="Some(0)")
  workbook.set_cell_formula_rc("Sheet1", 3, 1, "1+1")
  workbook.set_row_style_range("Sheet1", 1, 1, 0)
  workbook.set_col_style("Sheet1", 1, 0)

  let miss_row_style : Result[Unit, Error] = try? workbook.set_row_style_range(
    "Missing", 1, 1, 0,
  )
  inspect(miss_row_style is Err(XlsxError::SheetNotFound(_)), content="true")
  let miss_col_style : Result[Unit, Error] = try? workbook.set_col_style(
    "Missing", 1, 0,
  )
  inspect(miss_col_style is Err(XlsxError::SheetNotFound(_)), content="true")

  workbook.set_defined_name(
    DefinedName::new("ShiftRef", "Sheet1!$A$3", scope="Sheet1"),
  )
  workbook.duplicate_row_to("Sheet1", 1, 2)
  let mut shifted = false
  for dn in workbook.defined_names() {
    if dn.name == "ShiftRef" && dn.refers_to.contains("$A$4") {
      shifted = true
      break
    }
  }
  inspect(shifted, content="true")
}

///|
test "workbook: table naming and slicer wrapper/error branches" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))

  ignore(
    workbook.add_table_with_columns(
      "Sheet1",
      "A1:B2",
      "Table",
      ["Region", "Type"][:],
    ),
  )
  ignore(
    workbook.add_table_with_columns(
      "Sheet1",
      "D1:E2",
      "TableA",
      ["Region", "Type"][:],
    ),
  )
  ignore(
    workbook.add_table_with_columns(
      "Sheet1",
      "G1:H2",
      "Table3",
      ["Region", "Type"][:],
    ),
  )

  let auto_name_opts = TableOptions::new("J1:K2") catch {
    err => fail("table options init failed: \{err}")
  }
  let auto_name_table = workbook.add_table("Sheet1", auto_name_opts)
  inspect(auto_name_table.name, content="Table4")

  let bad_name_opts = TableOptions::new("L1:M2") catch {
    err => fail("table options init failed: \{err}")
  }
  bad_name_opts.set_name("1bad")
  let bad_name_result : Result[Table, Error] = try? workbook.add_table(
    "Sheet1", bad_name_opts,
  )
  inspect(bad_name_result is Err(XlsxError::InvalidTable(_)), content="true")

  let missing_sheet_opts = SlicerOptions::new(
    "Region", "A1", "Missing", "Table",
  ) catch {
    err => fail("slicer options init failed: \{err}")
  }
  let missing_sheet : Result[Unit, Error] = try? workbook.add_slicer(
    "Sheet1", missing_sheet_opts,
  )
  inspect(missing_sheet is Err(XlsxError::SheetNotFound(_)), content="true")

  let missing_table_opts = SlicerOptions::new(
    "Region", "A1", "Sheet1", "NoSuch",
  ) catch {
    err => fail("slicer options init failed: \{err}")
  }
  let missing_table : Result[Unit, Error] = try? workbook.add_slicer_with_options(
    "Sheet1", missing_table_opts,
  )
  inspect(missing_table is Err(XlsxError::TableNotFound(_)), content="true")

  let missing_field_opts = SlicerOptions::new(
    "MissingField", "A1", "Sheet1", "Table",
  ) catch {
    err => fail("slicer options init failed: \{err}")
  }
  let missing_field : Result[Unit, Error] = try? workbook.add_slicer(
    "Sheet1", missing_field_opts,
  )
  inspect(
    missing_field is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )

  ignore(
    workbook.add_table_with_columns(
      "Sheet1",
      "N1:O2",
      "TableDigits",
      ["1Region", "Type"][:],
    ),
  )
  let digit_field_opts = SlicerOptions::new(
    "1Region", "N3", "Sheet1", "TableDigits",
  ) catch {
    err => fail("slicer options init failed: \{err}")
  }
  workbook.add_slicer("Sheet1", digit_field_opts)

  ignore(
    workbook.add_pivot_table_xml(
      "Sheet1",
      "<pivotTableDefinition/>",
      "<cacheDefinition><cacheFields><cacheField name=\"Region</cacheFields></cacheDefinition>",
      name="PivotBad",
    ),
  )
  let pivot_field_missing_opts = SlicerOptions::new(
    "Region", "P1", "Sheet1", "PivotBad",
  ) catch {
    err => fail("slicer options init failed: \{err}")
  }
  let pivot_field_missing : Result[Unit, Error] = try? workbook.add_slicer(
    "Sheet1", pivot_field_missing_opts,
  )
  inspect(
    pivot_field_missing is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )

  let raw = Slicer::new("RawSlicer") catch {
    err => fail("raw slicer init failed: \{err}")
  }
  workbook.add_slicer_raw("Sheet1", raw)
  inspect(workbook.get_slicers("Sheet1").length() > 0, content="true")
}

///|
test "workbook: copy_sheet clones pane and x14 data bar maps" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Src"))
  ignore(workbook.add_sheet("Dst"))
  workbook.set_panes(
    "Src",
    Panes::with_values(
      freeze=true,
      split=true,
      x_split=1,
      y_split=1,
      top_left_cell="B2",
      active_pane="bottomRight",
      selection=[
        Selection::with_values(sqref="B2", active_cell="B2", pane="bottomRight"),
      ],
    ),
  )
  let data_bar = ConditionalFormatOptions::new("data_bar")
  data_bar.set_bar_solid(true)
  data_bar.set_bar_border_color("#0000FF")
  workbook.set_conditional_format("Src", "A1:A2", [data_bar])
  workbook.copy_sheet(0, 1)
  inspect(workbook.get_conditional_formats("Dst").length() > 0, content="true")
}

///|
test "workbook: pivot option residual branches" {
  let wb_name = Workbook::new()
  let name_sheet = wb_name.add_sheet("Sheet1")
  name_sheet.set_cell_value("A1", String("Region"))
  name_sheet.set_cell_value("B1", String("Sales"))
  name_sheet.set_cell_value("A2", String("East"))
  name_sheet.set_cell_value("B2", Numeric(10.0))
  ignore(
    wb_name.add_pivot_table_xml(
      "Sheet1",
      "<pivotTableDefinition/>",
      "<pivotCacheDefinition/>",
      name="Other",
    ),
  )
  ignore(
    wb_name.add_pivot_table_xml(
      "Sheet1",
      "<pivotTableDefinition/>",
      "<pivotCacheDefinition/>",
      name="PivotTable",
    ),
  )
  ignore(
    wb_name.add_pivot_table_xml(
      "Sheet1",
      "<pivotTableDefinition/>",
      "<pivotCacheDefinition/>",
      name="PivotTable3",
    ),
  )
  let next_name_opts = PivotTableOptions::new("Sheet1!A1:B2", "Sheet1!E2:H10")
  next_name_opts.rows.push(PivotTableField::new("Region"))
  next_name_opts.data.push(PivotTableField::new("Sales"))
  let next_name_pivot = wb_name.add_pivot_table(next_name_opts)
  inspect(next_name_pivot.name, content="PivotTable4")

  let wb_empty = Workbook::new()
  let empty_sheet = wb_empty.add_sheet("Sheet1")
  empty_sheet.set_cell_value("A2", String("East"))
  empty_sheet.set_cell_value("B2", Numeric(10.0))
  let empty_header_opts = PivotTableOptions::new(
    "Sheet1!A1:B2", "Sheet1!E2:H10",
  )
  let empty_header_result : Result[PivotTable, Error] = try? wb_empty.add_pivot_table(
    empty_header_opts,
  )
  inspect(
    empty_header_result is Err(XlsxError::InvalidPivotTable(_)),
    content="true",
  )

  let wb_missing = Workbook::new()
  let missing_sheet = wb_missing.add_sheet("Sheet1")
  missing_sheet.set_cell_value("A1", String("Region"))
  missing_sheet.set_cell_value("B1", String("Sales"))
  missing_sheet.set_cell_value("A2", String("East"))
  missing_sheet.set_cell_value("B2", Numeric(10.0))
  let missing_field_opts = PivotTableOptions::new(
    "Sheet1!A1:B2", "Sheet1!E2:H10",
  )
  missing_field_opts.rows.push(PivotTableField::new("Missing"))
  let missing_field_result : Result[PivotTable, Error] = try? wb_missing.add_pivot_table(
    missing_field_opts,
  )
  inspect(
    missing_field_result is Err(XlsxError::InvalidPivotTable(_)),
    content="true",
  )

  let wb_filter = Workbook::new()
  let filter_sheet = wb_filter.add_sheet("Sheet1")
  filter_sheet.set_cell_value("A1", String("Region"))
  filter_sheet.set_cell_value("B1", String("Sales"))
  filter_sheet.set_cell_value("A2", String("East"))
  filter_sheet.set_cell_value("B2", Numeric(10.0))
  let filter_opts = PivotTableOptions::new("Sheet1!A1:B2", "Sheet1!E2:H10")
  filter_opts.filter.push(PivotTableField::new("Region"))
  filter_opts.data.push(PivotTableField::new("Missing"))
  let filter_result : Result[PivotTable, Error] = try? wb_filter.add_pivot_table(
    filter_opts,
  )
  inspect(filter_result is Err(XlsxError::InvalidPivotTable(_)), content="true")
}
