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
  inspect(
    workbook.get_custom_props(),
    content=(
      #|[{name: "k", value: Some(Text("v2"))}]
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
  inspect(workbook.get_sheet_list(), content="[\"S1\", \"C1\", \"C2\", \"C3\"]")

  // Delete middle chart sheet -> hits both value>idx and value<=idx adjustment branches.
  workbook.delete_sheet("C2")
  inspect(workbook.get_sheet_list(), content="[\"S1\", \"C1\", \"C3\"]")

  // move_sheet: active == source branch.
  let m = Workbook::new()
  ignore(m.add_sheet("A"))
  ignore(m.add_sheet("B"))
  ignore(m.add_sheet("C"))
  m.set_active_sheet(0)
  m.move_sheet("A", "C")
  inspect(m.get_sheet_list(), content="[\"B\", \"A\", \"C\"]")
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
  inspect(mid.get_sheet_list(), content="[\"A\", \"C\"]")
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
  inspect(dst.get_cell("A1"), content="Some(\"v\")")
  inspect(dst.merged_cells(), content="[\"A1:B2\"]")
  inspect(dst.get_cell_hyperlink("A1") is Some(_), content="true")
  inspect(workbook.get_tables("Dst").length(), content="1")
  inspect(dst.sparkline_groups().length(), content="1")
  inspect(dst.auto_filter() is Some(_), content="true")
  inspect(dst.data_validations().length() > 0, content="true")
  inspect(dst.conditional_formats().length() > 0, content="true")
  inspect(dst.comments().length(), content="1")
  workbook.clear_sheet_background("Src")
}
