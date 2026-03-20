///|
fn wb_count_substr(text : StringView, needle : StringView) -> Int {
  let mut count = 0
  let mut rest = text.to_string()
  let target = needle.to_string()
  if target == "" {
    return 0
  }
  while true {
    match rest.find(target) {
      Some(pos) => {
        count = count + 1
        let next = pos + target.length()
        rest = rest[next:].to_string()
      }
      None => break
    }
  }
  count
}

///|
fn wb_drawing_image(positioning : PicturePositioning) -> DrawingImage {
  let image : Image = {
    reference: "B3",
    data: @encoding/utf8.encode("img"),
    extension: "png",
    content_type: "image/png",
    offset_x: 0,
    offset_y: 0,
    scale_x: 1.0,
    scale_y: 1.0,
    width_emu: 1000,
    height_emu: 2000,
    print_object: true,
    locked: true,
    hyperlink: "",
    hyperlink_type: Unset,
    name: "",
    alt_text: "",
    lock_aspect_ratio: false,
    positioning,
  }
  { image, rel_id: 1, hyperlink_rel_id: None }
}

///|
fn wb_drawing_chart(positioning : PicturePositioning) -> DrawingChart {
  {
    reference: "C4",
    offset_x: 0,
    offset_y: 0,
    width_emu: 3000,
    height_emu: 4000,
    print_object: true,
    locked: true,
    positioning,
    rel_id: 1,
  }
}

///|
fn wb_shape_for_anchor(
  positioning : PicturePositioning,
) -> Shape raise XlsxError {
  let font : RichTextFont = {
    bold: false,
    italic: false,
    strike: true,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: None,
    size: Some(11.0),
    color: None,
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  Shape::new(
    "D5",
    "rect",
    paragraph=[{ text: "shape", font: Some(font) }],
    line_width=2.0,
    positioning~,
  )
}

///|
fn wb_drawing_slicer(
  name : String,
  positioning : PicturePositioning?,
  scale_x : Double?,
  scale_y : Double?,
  is_table_slicer : Bool,
) -> DrawingSlicer {
  let format = GraphicOptions::new()
  match positioning {
    Some(value) => format.positioning = Some(value)
    None => ()
  }
  match scale_x {
    Some(value) => format.scale_x = Some(value)
    None => ()
  }
  match scale_y {
    Some(value) => format.scale_y = Some(value)
    None => ()
  }
  let slicer : Slicer = {
    name,
    cache: "Slicer_" + name,
    source_name: name,
    cell: "C3",
    table_sheet: "Sheet1",
    table_name: "Table1",
    caption: "",
    macro_name: "",
    width: 200,
    height: 200,
    display_header: None,
    item_desc: false,
    format,
  }
  { slicer, is_table_slicer }
}

///|
test "write hardening wb: write_drawing_xml uses None-sheet fallback for two-cell anchors" {
  let xml = write_drawing_xml(None, [wb_drawing_image(TwoCell)], [], [], [])
  inspect(xml.contains("<xdr:twoCellAnchor>"), content="true")
  inspect(xml.contains("<xdr:col>1</xdr:col>"), content="true")
  inspect(xml.contains("<xdr:row>2</xdr:row>"), content="true")
  inspect(xml.contains("<xdr:colOff>1000</xdr:colOff>"), content="true")
  inspect(xml.contains("<xdr:rowOff>2000</xdr:rowOff>"), content="true")
}

///|
test "write hardening wb: write_drawing_xml uses None-sheet fallback for absolute anchors" {
  let xml = write_drawing_xml(None, [wb_drawing_image(Absolute)], [], [], [])
  inspect(
    xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(xml.contains("<xdr:col>1</xdr:col>"), content="true")
  inspect(xml.contains("<xdr:row>2</xdr:row>"), content="true")
  inspect(xml.contains("<xdr:colOff>1000</xdr:colOff>"), content="true")
  inspect(xml.contains("<xdr:rowOff>2000</xdr:rowOff>"), content="true")
}

///|
test "write hardening wb: write_shared_strings rich-text color and preserve-space branches" {
  let font_indexed_tint : RichTextFont = {
    bold: false,
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
    color_indexed: Some(64),
    color_tint: Some(0.25),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let font_rgb_tint : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: None,
    size: None,
    color: Some("FF00AA00"),
    color_theme: None,
    color_indexed: None,
    color_tint: Some(0.5),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let font_tint_only : RichTextFont = {
    bold: false,
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
    color_tint: Some(0.75),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let font_theme_no_tint : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: None,
    size: None,
    color: None,
    color_theme: Some(5),
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let entries : Array[SharedStringEntry] = [
    { text: "I", runs: Some([{ text: "I", font: Some(font_indexed_tint) }]) },
    { text: "R", runs: Some([{ text: "R", font: Some(font_rgb_tint) }]) },
    { text: "T", runs: Some([{ text: "T", font: Some(font_tint_only) }]) },
    { text: "M", runs: Some([{ text: "M", font: Some(font_theme_no_tint) }]) },
    { text: " plain", runs: None },
  ]
  let xml = write_shared_strings_xml(entries, 5)
  inspect(xml.contains("<color indexed=\"64\" tint=\"0.25\"/>"), content="true")
  inspect(
    xml.contains("<color rgb=\"FF00AA00\" tint=\"0.5\"/>"),
    content="true",
  )
  inspect(xml.contains("<color theme=\"5\"/>"), content="true")
  inspect(wb_count_substr(xml, "<color ") >= 2, content="true")
  inspect(xml.contains("<t xml:space=\"preserve\">"), content="true")
}

///|
test "write hardening wb: write_drawing_xml covers chart none-sheet anchor branches" {
  let xml = write_drawing_xml(
    None,
    [],
    [wb_drawing_chart(TwoCell), wb_drawing_chart(Absolute)],
    [],
    [],
  )
  inspect(
    xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(wb_count_substr(xml, "<xdr:graphicFrame>"), content="2")
  inspect(wb_count_substr(xml, "</xdr:twoCellAnchor>") >= 2, content="true")
}

///|
test "write hardening wb: write_drawing_xml covers shape none-sheet and run-font branches" {
  let shape_two = wb_shape_for_anchor(TwoCell) catch {
    err => fail("shape init failed: \{err}")
  }
  let shape_abs = wb_shape_for_anchor(Absolute) catch {
    err => fail("shape init failed: \{err}")
  }
  let xml = write_drawing_xml(None, [], [], [shape_two, shape_abs], [])
  inspect(
    xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(xml.contains("<a:ln w=\"25400\"/>"), content="true")
  inspect(xml.contains("strike=\"sngStrike\""), content="true")
  inspect(wb_count_substr(xml, "<xdr:sp>"), content="2")
}

///|
test "write hardening wb: two_cell_axis_to skips zero-size cells" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_col_visible(2, false)
  sheet.set_row_visible(3, false)
  let xml = write_drawing_xml(
    Some(sheet),
    [wb_drawing_image(TwoCell)],
    [],
    [],
    [],
  )
  inspect(xml.contains("<xdr:twoCellAnchor>"), content="true")
  inspect(xml.contains("<xdr:col>2</xdr:col>"), content="true")
}

///|
test "write hardening wb: write_drawing_xml covers chart absolute with sheet anchors" {
  let sheet = Worksheet::new("Sheet1")
  let xml = write_drawing_xml(
    Some(sheet),
    [],
    [wb_drawing_chart(Absolute)],
    [],
    [],
  )
  inspect(
    xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(wb_count_substr(xml, "<xdr:to>"), content="1")
}

///|
test "write hardening wb: write_drawing_xml covers slicer positioning and defaults" {
  let two = wb_drawing_slicer("SlicerTwo", None, Some(0.0), Some(-1.0), true)
  let abs = wb_drawing_slicer("SlicerAbs", Some(Absolute), None, None, false)
  let one = wb_drawing_slicer("SlicerOne", Some(OneCell), None, None, false)
  let xml = write_drawing_xml(None, [], [], [], [two, abs, one])
  inspect(xml.contains("Requires=\"sle15\""), content="true")
  inspect(xml.contains("Requires=\"a14\""), content="true")
  inspect(
    xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(xml.contains("<xdr:oneCellAnchor>"), content="true")
  inspect(
    xml.contains("fLocksWithSheet=\"1\" fPrintsWithSheet=\"1\""),
    content="true",
  )
}

///|
test "write hardening wb: sheet property emitters cover option branches" {
  let empty_xml = write_sheet_pr_xml(SheetPropsOptions::new())
  inspect(empty_xml.contains("<sheetPr/>"), content="true")

  let tab_indexed_xml = write_sheet_pr_xml(
    SheetPropsOptions::with_values(tab_color_indexed=4),
  )
  inspect(tab_indexed_xml.contains("<tabColor indexed=\"4\"/>"), content="true")

  let outline_right_xml = write_sheet_pr_xml(
    SheetPropsOptions::with_values(outline_summary_right=true),
  )
  inspect(
    outline_right_xml.contains("<outlinePr summaryRight=\"1\"/>"),
    content="true",
  )

  let outline_below_xml = write_sheet_pr_xml(
    SheetPropsOptions::with_values(outline_summary_below=false),
  )
  inspect(
    outline_below_xml.contains("<outlinePr summaryBelow=\"0\"/>"),
    content="true",
  )

  let page_setup_xml = write_sheet_pr_xml(
    SheetPropsOptions::with_values(auto_page_breaks=true),
  )
  inspect(
    page_setup_xml.contains("<pageSetUpPr autoPageBreaks=\"1\"/>"),
    content="true",
  )

  let format_xml = write_sheet_format_pr_xml(
    SheetPropsOptions::with_values(base_col_width=8),
  )
  inspect(
    format_xml.contains("<sheetFormatPr baseColWidth=\"8\""),
    content="true",
  )
}

///|
test "write hardening wb: sheet view writer covers bool attribute branches" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_sheet_view(
    0,
    SheetViewOptions::with_values(
      right_to_left=true,
      show_formulas=true,
      show_ruler=false,
      show_zeros=false,
    ),
  )
  let xml = match write_sheet_views_xml(sheet) {
    Some(value) => value
    None => fail("missing sheet views xml")
  }
  inspect(xml.contains("rightToLeft=\"1\""), content="true")
  inspect(xml.contains("showFormulas=\"1\""), content="true")
  inspect(xml.contains("showRuler=\"0\""), content="true")
  inspect(xml.contains("showZeros=\"0\""), content="true")
}

///|
test "write hardening wb: worksheet_dimension covers cell merge and table min/max branches" {
  let sheet = Worksheet::new("Dim")
  sheet.set_cell("D3", "x")
  sheet.set_cell("C4", "y")
  sheet.merge_cells("B2:B5")
  ignore(sheet.add_table("A1:E6", "DimTable", ["A", "B", "C", "D", "E"]))
  let dimension = worksheet_dimension(sheet) catch {
    err => fail("worksheet_dimension failed: \{err}")
  }
  inspect(dimension, content="Some(\"A1:E6\")")
}

///|
test "write hardening wb: worksheet_dimension covers auto-filter expansion branches" {
  let sheet = Worksheet::new("FilterDim")
  sheet.set_cell("C3", "x")
  sheet.auto_filter = Some({ range_ref: "B2:D4", columns: [] })
  let dimension = worksheet_dimension(sheet) catch {
    err => fail("worksheet_dimension failed: \{err}")
  }
  inspect(dimension, content="Some(\"B2:D4\")")
}

///|
test "write hardening wb: write_worksheet_xml covers x14 map aggregation and unknown ext fallback" {
  let sheet = Worksheet::new("Exts")
  sheet.x14_data_bars["skip"] = {
    sqref: "A1",
    bar_direction: "",
    bar_solid: false,
    bar_border_color: "",
  }
  sheet.x14_data_bars["id1"] = {
    sqref: "A1",
    bar_direction: "leftToRight",
    bar_solid: false,
    bar_border_color: "",
  }
  sheet.x14_data_bars["id2"] = {
    sqref: "A1",
    bar_direction: "",
    bar_solid: true,
    bar_border_color: "",
  }
  sheet.unknown_ext_blocks.push("<foo/>")
  let xml = write_worksheet_xml(
    sheet,
    {},
    {},
    {},
    [],
    None,
    None,
    [],
    [],
    [],
    [],
    None,
    None,
  ) catch {
    err => fail("write_worksheet_xml failed: \{err}")
  }
  inspect(xml.contains("<extLst>"), content="true")
  inspect(xml.contains("<x14:conditionalFormatting>"), content="true")
  inspect(xml.contains("<foo/>"), content="true")
}

///|
test "write hardening wb: write_theme_xml covers custom palette and fallback branches" {
  let custom = write_theme_xml(
    Some([
      "111111", "222222", "333333", "444444", "555555", "666666", "777777", "888888",
      "999999", "AAAAAA",
    ]),
  )
  inspect(custom.contains("<a:themeElements>"), content="true")
  inspect(custom.contains("val=\"111111\""), content="true")

  let fallback = write_theme_xml(Some(["FFFFFF"]))
  inspect(fallback == default_theme_xml, content="true")
}

///|
test "write hardening wb: write_worksheet_xml covers formula bool and error branches" {
  let sheet = Worksheet::new("FormulaBranches")
  sheet.cells.push({
    reference: "A1",
    row: 1,
    col: 1,
    value: "1",
    value_type: Bool,
    rich_text: None,
    formula: Some("1=1"),
    formula_type: None,
    formula_ref: None,
    formula_shared_index: None,
    style_id: 0,
  })
  sheet.cells.push({
    reference: "A2",
    row: 2,
    col: 1,
    value: "#N/A",
    value_type: Error,
    rich_text: None,
    formula: Some("NA()"),
    formula_type: None,
    formula_ref: None,
    formula_shared_index: None,
    style_id: 0,
  })
  let xml = write_worksheet_xml(
    sheet,
    {},
    {},
    {},
    [],
    None,
    None,
    [],
    [],
    [],
    [],
    None,
    None,
  ) catch {
    err => fail("write_worksheet_xml failed: \{err}")
  }
  inspect(xml.contains("r=\"A1\" t=\"b\""), content="true")
  inspect(xml.contains("<f>1=1</f><v>1</v>"), content="true")
  inspect(xml.contains("r=\"A2\" t=\"e\""), content="true")
  inspect(xml.contains("<f>NA()</f><v>#N/A</v>"), content="true")
}

///|
test "write hardening wb: write_worksheet_xml covers shared-string and hyperlink error branches" {
  let rich_missing = Worksheet::new("RichMissing")
  rich_missing.cells.push({
    reference: "A1",
    row: 1,
    col: 1,
    value: "ignored",
    value_type: String,
    rich_text: Some([{ text: "R", font: None }]),
    formula: None,
    formula_type: None,
    formula_ref: None,
    formula_shared_index: None,
    style_id: 0,
  })
  let missing_rich : Result[String, Error] = try? write_worksheet_xml(
    rich_missing,
    {},
    {},
    {},
    [],
    None,
    None,
    [],
    [],
    [],
    [],
    None,
    None,
  )
  inspect(
    missing_rich is Err(XlsxError::InvalidSharedString(_)),
    content="true",
  )

  let plain_missing = Worksheet::new("PlainMissing")
  plain_missing.cells.push({
    reference: "A1",
    row: 1,
    col: 1,
    value: "plain",
    value_type: String,
    rich_text: None,
    formula: None,
    formula_type: None,
    formula_ref: None,
    formula_shared_index: None,
    style_id: 0,
  })
  let missing_plain : Result[String, Error] = try? write_worksheet_xml(
    plain_missing,
    {},
    {},
    {},
    [],
    None,
    None,
    [],
    [],
    [],
    [],
    None,
    None,
  )
  inspect(
    missing_plain is Err(XlsxError::InvalidSharedString(_)),
    content="true",
  )

  let no_hyperlinks_xml = write_worksheet_xml(
    Worksheet::new("NoLinks"),
    {},
    {},
    {},
    [
      {
        reference: "A1",
        target: "",
        link_type: Unset,
        display: None,
        tooltip: None,
      },
    ],
    None,
    None,
    [],
    [],
    [],
    [],
    None,
    None,
  ) catch {
    err => fail("write_worksheet_xml failed: \{err}")
  }
  inspect(no_hyperlinks_xml.contains("<hyperlinks>"), content="false")

  let missing_rel : Result[String, Error] = try? write_worksheet_xml(
    Worksheet::new("MissingRel"),
    {},
    {},
    {},
    [
      {
        reference: "A1",
        target: "https://example.com",
        link_type: External,
        display: None,
        tooltip: None,
      },
    ],
    None,
    None,
    [],
    [],
    [],
    [],
    None,
    None,
  )
  inspect(missing_rel is Err(XlsxError::InvalidHyperlink(_)), content="true")
}

///|
test "write hardening wb: write_with_io covers file-path extension fallback branches" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))

  let no_ext = write_with_io(workbook, {
    file_path: Some("demo"),
    zip_writer: None,
    charset_transcoder: None,
  }) catch {
    err => fail("write_with_io without extension failed: \{err}")
  }
  inspect(no_ext.length() > 0, content="true")

  let unsupported_ext = write_with_io(workbook, {
    file_path: Some("demo.unsupported"),
    zip_writer: None,
    charset_transcoder: None,
  }) catch {
    err => fail("write_with_io unsupported extension failed: \{err}")
  }
  inspect(unsupported_ext.length() > 0, content="true")
}

///|
test "write hardening wb: write_with_password empty password returns raw bytes" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let raw = write(workbook) catch { err => fail("write failed: \{err}") }
  let with_empty_password = write_with_password(workbook, "") catch {
    err => fail("write_with_password failed: \{err}")
  }
  inspect(raw == with_empty_password, content="true")
}

///|
test "write hardening wb: write merges base vml with form-control and comment vml" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_vml_drawing_xml("<xml>base</xml>")
  sheet.add_form_control(FormControl::new("A1", "Button"))
  sheet.add_comment({
    cell: "B2",
    author: "A",
    author_id: None,
    text: "c",
    paragraph: [],
    width: None,
    height: None,
  })
  let bytes = write(workbook) catch { err => fail("write failed: \{err}") }
  inspect(bytes.length() > 0, content="true")
}

///|
test "write hardening wb: write fails for slicer source missing" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.slicers.push({
    name: "BadSlicer",
    cache: "Slicer_BadSlicer",
    source_name: "Field",
    cell: "A1",
    table_sheet: "Sheet1",
    table_name: "MissingTable",
    caption: "",
    macro_name: "",
    width: 200,
    height: 200,
    display_header: None,
    item_desc: false,
    format: GraphicOptions::new(),
  })
  let result : Result[Bytes, Error] = try? write(workbook)
  inspect(result is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}

///|
test "write hardening wb: write fails for slicer table field missing" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  ignore(sheet.add_table("A1:B2", "Table1", ["A", "B"]))
  sheet.slicers.push({
    name: "BadField",
    cache: "Slicer_BadField",
    source_name: "MissingColumn",
    cell: "A1",
    table_sheet: "Sheet1",
    table_name: "Table1",
    caption: "",
    macro_name: "",
    width: 200,
    height: 200,
    display_header: None,
    item_desc: false,
    format: GraphicOptions::new(),
  })
  let result : Result[Bytes, Error] = try? write(workbook)
  inspect(result is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}

///|
test "write hardening wb: write handles duplicate pivot cache relationship entries" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.pivot_tables.push({
    name: "",
    table_id: 1,
    cache_id: 1,
    table_xml: "<pivotTableDefinition/>",
    cache_definition_xml: "<pivotCacheDefinition/>",
    cache_records_xml: None,
  })
  sheet.pivot_tables.push({
    name: "",
    table_id: 2,
    cache_id: 1,
    table_xml: "<pivotTableDefinition/>",
    cache_definition_xml: "<pivotCacheDefinition/>",
    cache_records_xml: None,
  })
  let bytes = write(workbook) catch { err => fail("write failed: \{err}") }
  inspect(bytes.length() > 0, content="true")
}

///|
test "write hardening wb: failing custom zip writer maps to UnsupportedFeature" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_zip_writer(_archive => {
    raise InvalidSheetOperation(msg="zip writer failed")
  })
  let result : Result[Bytes, Error] = try? workbook.write_to_buffer()
  inspect(result is Err(XlsxError::UnsupportedFeature(_)), content="true")
}

///|
test "write hardening wb: default zip writer failure maps to UnsupportedFeature" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.images.push({
    reference: "A1",
    data: @encoding/utf8.encode("x"),
    extension: "a".repeat(70000),
    content_type: "image/png",
    offset_x: 0,
    offset_y: 0,
    scale_x: 1.0,
    scale_y: 1.0,
    width_emu: 1,
    height_emu: 1,
    print_object: true,
    locked: true,
    hyperlink: "",
    hyperlink_type: Unset,
    name: "",
    alt_text: "",
    lock_aspect_ratio: false,
    positioning: TwoCell,
  })
  let result : Result[Bytes, Error] = try? write(workbook)
  inspect(result is Err(XlsxError::UnsupportedFeature(_)), content="true")
}
