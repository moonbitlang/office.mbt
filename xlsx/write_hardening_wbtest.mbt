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
        rest = (rest[next:] catch { _ => "" }).to_string()
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
    positioning=positioning,
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
  inspect(xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"), content="true")
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
  let xml = write_drawing_xml(
    None,
    [],
    [],
    [shape_two, shape_abs],
    [],
  )
  inspect(xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"), content="true")
  inspect(xml.contains("<a:ln w=\"25400\"/>"), content="true")
  inspect(xml.contains("strike=\"sngStrike\""), content="true")
  inspect(wb_count_substr(xml, "<xdr:sp>"), content="2")
}

///|
test "write hardening wb: two_cell_axis_to skips zero-size cells" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_col_visible(2, false)
  sheet.set_row_visible(3, false)
  let xml = write_drawing_xml(Some(sheet), [wb_drawing_image(TwoCell)], [], [], [])
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
  inspect(xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"), content="true")
  inspect(wb_count_substr(xml, "<xdr:to>"), content="1")
}

///|
test "write hardening wb: write_drawing_xml covers slicer positioning and defaults" {
  let two = wb_drawing_slicer("SlicerTwo", None, Some(0.0), Some(-1.0), true)
  let abs = wb_drawing_slicer(
    "SlicerAbs",
    Some(Absolute),
    None,
    None,
    false,
  )
  let one = wb_drawing_slicer(
    "SlicerOne",
    Some(OneCell),
    None,
    None,
    false,
  )
  let xml = write_drawing_xml(None, [], [], [], [two, abs, one])
  inspect(xml.contains("Requires=\"sle15\""), content="true")
  inspect(xml.contains("Requires=\"a14\""), content="true")
  inspect(xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"), content="true")
  inspect(xml.contains("<xdr:oneCellAnchor>"), content="true")
  inspect(xml.contains("fLocksWithSheet=\"1\" fPrintsWithSheet=\"1\""), content="true")
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
  inspect(format_xml.contains("<sheetFormatPr baseColWidth=\"8\""), content="true")
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
