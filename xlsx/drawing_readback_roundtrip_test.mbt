///|
/// Pictures with non-default positioning and hyperlinks survive write + read:
/// OneCell/Absolute anchors and both hyperlink flavors are recovered by the
/// drawing parser, not just echoed from the in-memory model.
test "picture positioning and hyperlinks round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let img : Bytes = [9, 8, 7, 6]
  workbook.add_picture_from_bytes(
    "Sheet1",
    "A1",
    img,
    ".png",
    name="pic one",
    alt_text="first picture",
    hyperlink="https://example.com/doc",
    hyperlink_type=External,
    positioning=OneCell,
    print_object=false,
    locked=true,
    lock_aspect_ratio=true,
    offset_x=3,
    offset_y=4,
    scale_x=1.5,
    scale_y=0.5,
  )
  workbook.add_picture_from_bytes(
    "Sheet1",
    "C3",
    img,
    ".png",
    hyperlink="Sheet1!B2",
    hyperlink_type=Location,
    positioning=Absolute,
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let one_cell = parsed.get_pictures("Sheet1", "A1")[0]
  inspect(
    "\{one_cell.name}|\{one_cell.alt_text}|\{one_cell.hyperlink}|\{to_repr(one_cell.hyperlink_type)}|\{to_repr(one_cell.positioning)}",
    content=(
      #|pic one|first picture|https://example.com/doc|External|OneCell
    ),
  )
  inspect(
    "print=\{one_cell.print_object} locked=\{one_cell.locked} aspect=\{one_cell.lock_aspect_ratio} off=\{one_cell.offset_x},\{one_cell.offset_y}",
    content=(
      #|print=false locked=true aspect=true off=3,4
    ),
  )
  let absolute = parsed.get_pictures("Sheet1", "C3")[0]
  inspect(
    "\{absolute.hyperlink}|\{to_repr(absolute.hyperlink_type)}|\{to_repr(absolute.positioning)}",
    content=(
      #|Sheet1!B2|Location|Absolute
    ),
  )
}

///|
/// Image dimensions are parsed from JPEG SOF markers and unit-bearing SVG
/// attributes when computing the drawing extent.
test "jpeg and svg unit image dimensions round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  // minimal JPEG: SOI, APP0 stub, SOF0 with height=20 width=10
  let jpeg : Array[Byte] = [
    0xFF, 0xD8, // SOI
     0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0 length 4
     0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x14, 0x00, 0x0A, 0x01, 0x00, 0x11, 0x00, // SOF0: precision 8, h=20, w=10
     0xFF, 0xD9, // EOI
  ]
  workbook.add_picture_from_bytes(
    "Sheet1",
    "A1",
    Bytes::from_array(jpeg),
    ".jpg",
  )
  // SVG with cm/mm units and a pt-based fallback
  workbook.add_picture_from_bytes(
    "Sheet1",
    "B2",
    @encoding/utf8.encode("<svg width=\"2cm\" height=\"10mm\"></svg>"),
    ".svg",
  )
  workbook.add_picture_from_bytes(
    "Sheet1",
    "C3",
    @encoding/utf8.encode("<svg width=\"72pt\" height=\"36pt\"></svg>"),
    ".svg",
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let jpeg_image = parsed.get_pictures("Sheet1", "A1")[0]
  inspect(
    "\{jpeg_image.width_emu}x\{jpeg_image.height_emu}",
    content=(
      #|95250x190500
    ),
  )
  let svg_cm = parsed.get_pictures("Sheet1", "B2")[0]
  inspect(
    "\{svg_cm.width_emu}x\{svg_cm.height_emu}",
    content=(
      #|723900x361950
    ),
  )
  let svg_pt = parsed.get_pictures("Sheet1", "C3")[0]
  inspect(
    "\{svg_pt.width_emu}x\{svg_pt.height_emu}",
    content=(
      #|914400x457200
    ),
  )
}

///|
/// Shapes with fills, lines, rich paragraphs, and non-default anchors are
/// preserved through a full read + rewrite cycle: the second package still
/// contains the shape geometry, text, and anchor kind.
test "shapes survive read and rewrite" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_shape(
    "Sheet1",
    @xlsx.Shape::new(
      "B2",
      "roundRect",
      text="hello shape",
      width=120,
      height=60,
      fill_color="#FFCC00",
      fill_transparency=25,
      line_color="#3366FF",
      line_width=2.5,
      name="Shape One",
      alt_text="a rounded rectangle",
      print_object=false,
      locked=true,
      positioning=OneCell,
    ),
  )
  workbook.add_shape(
    "Sheet1",
    @xlsx.Shape::new(
      "E5",
      "ellipse",
      macro_name="Shape2_Click",
      paragraph=[
        {
          text: "styled run",
          font: Some({
            bold: true,
            italic: false,
            strike: false,
            outline: false,
            shadow: false,
            condense: false,
            extended: false,
            underline: Some("double"),
            size: None,
            color: Some("FF0000"),
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
      positioning=Absolute,
    ),
  )
  let reread = @xlsx.read(@xlsx.write(workbook))
  let second = @zip.read(@xlsx.write(reread))
  let drawing_xml = @encoding/utf8.decode(
    second.get("xl/drawings/drawing1.xml").unwrap(),
  )
  // The writer lowercases the preset name, so camelCase presets like
  // roundRect are emitted as prst="roundrect" — not a valid ST_ShapeType
  // value; documented here as current behavior (potential parity fix).
  inspect(drawing_xml.contains("prst=\"roundrect\""), content="true")
  inspect(drawing_xml.contains("prst=\"ellipse\""), content="true")
  inspect(drawing_xml.contains("hello shape"), content="true")
  inspect(drawing_xml.contains("macro=\"Shape2_Click\""), content="true")
  inspect(drawing_xml.contains("oneCellAnchor"), content="true")
  // Absolute positioning maps to twoCellAnchor editAs="absolute" (excelize
  // convention), not an xdr:absoluteAnchor element.
  inspect(drawing_xml.contains("editAs=\"absolute\""), content="true")
}

///|
/// Raw chart XML attached to a sheet survives read + rewrite with its
/// drawing anchor intact.
test "chart part survives read and rewrite" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", Numeric(1.0))
  sheet.set_cell_value("A2", Numeric(2.0))
  let chart_xml =
    #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    #|<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><c:chart><c:plotArea><c:layout/><c:barChart><c:barDir val="col"/><c:grouping val="clustered"/></c:barChart></c:plotArea></c:chart></c:chartSpace>
  sheet.add_chart("C3", chart_xml)
  let reread = @xlsx.read(@xlsx.write(workbook))
  let second = @zip.read(@xlsx.write(reread))
  inspect(second.get("xl/charts/chart1.xml") is Some(_), content="true")
  let drawing_xml = @encoding/utf8.decode(
    second.get("xl/drawings/drawing1.xml").unwrap(),
  )
  inspect(drawing_xml.contains("graphicFrame"), content="true")
}

///|
/// A table slicer round-trips: get_slicers on the re-read workbook recovers
/// the slicer's source, caption, size, and options from the drawing and
/// slicer-cache parts.
test "table slicer round-trip" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  workbook.set_cell("Data", "A1", "Region")
  workbook.set_cell("Data", "A2", "East")
  workbook.set_cell("Data", "A3", "West")
  sheet.set_cell_value("B1", Numeric(0.0))
  workbook.set_cell("Data", "B1", "Sales")
  sheet.set_cell_value("B2", Numeric(10.0))
  sheet.set_cell_value("B3", Numeric(20.0))
  let table_options = @xlsx.TableOptions::new("A1:B3")
  table_options.set_name("SalesTable")
  table_options.set_style_name("TableStyleMedium9")
  ignore(workbook.add_table("Data", table_options))
  let slicer = @xlsx.SlicerOptions::new("Region", "D2", "Data", "SalesTable")
  slicer.set_caption("Pick a region")
  slicer.set_display_header(Some(false))
  slicer.set_item_desc(true)
  slicer.set_macro_name("Slicer_Change")
  slicer.set_size(240, 120)
  workbook.add_slicer("Data", slicer)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let slicers = parsed.get_slicers("Data")
  inspect(slicers.length(), content="1")
  let got = slicers[0]
  inspect(
    "\{got.name}|\{got.source_name}|\{got.cell}|\{got.table_name}|\{got.caption}",
    content=(
      #|Region|Region|D2|SalesTable|Pick a region
    ),
  )
  inspect(
    "header=\{to_repr(got.display_header)} desc=\{got.item_desc} macro=\{got.macro_name} \{got.width}x\{got.height}",
    content=(
      #|header=Some(false) desc=true macro=Slicer_Change 240x120
    ),
  )
}

///|
/// Every form-control family round-trips through write + read with its
/// options: unchecked boxes, scroll/spin ranges, OneCell sizing, and rich
/// paragraphs with double underline.
test "form control families round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let unchecked = @xlsx.FormControl::new("A1", "CheckBox", text="Uncheck me")
  unchecked.set_checked(false)
  unchecked.set_cell_link("D1")
  unchecked.set_format(@xlsx.GraphicOptions::with_values(positioning=OneCell))
  workbook.add_form_control("Sheet1", unchecked)
  let radio = @xlsx.FormControl::new("A3", "OptionButton", text="Choice A")
  workbook.add_form_control("Sheet1", radio)
  let scroll = @xlsx.FormControl::new("A5", "ScrollBar")
  scroll.set_cell_link("D5")
  scroll.set_current_val(30)
  scroll.set_min_val(0)
  scroll.set_max_val(100)
  scroll.set_inc_change(5)
  scroll.set_page_change(20)
  scroll.set_horizontally(true)
  scroll.set_width(200)
  scroll.set_height(24)
  workbook.add_form_control("Sheet1", scroll)
  let spin = @xlsx.FormControl::new("C1", "Spin")
  spin.set_cell_link("D7")
  spin.set_current_val(2)
  spin.set_min_val(1)
  spin.set_max_val(9)
  spin.set_inc_change(1)
  workbook.add_form_control("Sheet1", spin)
  let group = @xlsx.FormControl::new("E1", "GroupBox", text="Group")
  workbook.add_form_control("Sheet1", group)
  let label = @xlsx.FormControl::new("E4", "Label", text="A label")
  label.set_paragraph([
    {
      text: "double underlined",
      font: Some({
        bold: false,
        italic: false,
        strike: false,
        outline: false,
        shadow: false,
        condense: false,
        extended: false,
        underline: Some("double"),
        size: None,
        color: Some("112233"),
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
  ])
  workbook.add_form_control("Sheet1", label)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let controls = parsed.get_form_controls("Sheet1")
  let summary = StringBuilder()
  for control in controls {
    summary.write_string(
      "\{control.cell}|\{control.control_type}|checked=\{to_repr(control.checked)}|link=\{to_repr(control.cell_link)}|cur=\{to_repr(control.current_val)}|range=\{to_repr(control.min_val)}..\{to_repr(control.max_val)}|inc=\{to_repr(control.inc_change)}|page=\{to_repr(control.page_change)}|horiz=\{to_repr(control.horizontally)}\n",
    )
  }
  inspect(
    summary.to_string(),
    content=(
      #|A1|CheckBox|checked=Some(false)|link=Some("D1")|cur=None|range=None..None|inc=None|page=None|horiz=None
      #|A3|OptionButton|checked=None|link=None|cur=None|range=None..None|inc=None|page=None|horiz=None
      #|A5|ScrollBar|checked=None|link=Some("D5")|cur=Some(30)|range=Some(0)..Some(100)|inc=Some(5)|page=Some(20)|horiz=Some(true)
      #|C1|SpinButton|checked=None|link=Some("D7")|cur=Some(2)|range=Some(1)..Some(9)|inc=Some(1)|page=None|horiz=None
      #|E1|GroupBox|checked=None|link=None|cur=None|range=None..None|inc=None|page=None|horiz=None
      #|E4|Label|checked=None|link=None|cur=None|range=None..None|inc=None|page=None|horiz=None
      #|
    ),
  )
  // rich paragraph on the label survives with its double underline
  let label_back = controls.filter(control => control.cell == "E4")[0]
  debug_inspect(
    label_back.paragraph,
    content=(
      #|[
      #|  {
      #|    text: "double underlined",
      #|    font: Some(
      #|      {
      #|        bold: false,
      #|        italic: false,
      #|        strike: false,
      #|        outline: false,
      #|        shadow: false,
      #|        condense: false,
      #|        extended: false,
      #|        underline: Some("double"),
      #|        size: None,
      #|        color: Some("#112233"),
      #|        color_theme: None,
      #|        color_indexed: None,
      #|        color_tint: None,
      #|        charset: None,
      #|        family_number: None,
      #|        scheme: None,
      #|        vert_align: None,
      #|        family: None,
      #|      },
      #|    ),
      #|  },
      #|]
    ),
  )
}

///|
/// Form-control option validation raises with pinned messages.
test "form control invalid options raise" {
  let summary = StringBuilder()
  let record = (label : String, err : Error) => {
    summary.write_string("\{label} => \{repr(err)}\n")
  }
  record(
    "empty cell",
    @test.expect_error(() => @xlsx.FormControl::new("", "Button")),
  )
  record(
    "empty type",
    @test.expect_error(() => @xlsx.FormControl::new("A1", "")),
  )
  let control = @xlsx.FormControl::new("A1", "ScrollBar")
  record("zero width", @test.expect_error(() => control.set_width(0)))
  record("zero height", @test.expect_error(() => control.set_height(0)))
  record("negative min", @test.expect_error(() => control.set_min_val(-1)))
  record("huge max", @test.expect_error(() => control.set_max_val(2147483647)))
  record("negative inc", @test.expect_error(() => control.set_inc_change(-1)))
  record("negative page", @test.expect_error(() => control.set_page_change(-1)))
  inspect(
    summary.to_string(),
    content=(
      #|empty cell => InvalidSheetOperation(msg="form control cell empty")
      #|empty type => InvalidSheetOperation(msg="form control type empty")
      #|zero width => InvalidSheetOperation(msg="form control width invalid")
      #|zero height => InvalidSheetOperation(msg="form control height invalid")
      #|negative min => InvalidSheetOperation(msg="form control min value invalid")
      #|huge max => InvalidSheetOperation(msg="form control max value invalid")
      #|negative inc => InvalidSheetOperation(msg="form control inc change invalid")
      #|negative page => InvalidSheetOperation(msg="form control page change invalid")
      #|
    ),
  )
}

///|
/// Rich-text runs with the long-tail font attributes (theme color + tint,
/// charset, family number, scheme, vertical alignment) survive write + read
/// through the shared-strings parser.
test "rich text long-tail font round-trip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_rich_text("Sheet1", "A1", [
    { text: "plain ", font: None },
    {
      text: "themed",
      font: Some({
        bold: true,
        italic: true,
        strike: true,
        outline: false,
        shadow: false,
        condense: false,
        extended: false,
        underline: Some("singleAccounting"),
        size: Some(11.5),
        color: None,
        color_theme: Some(6),
        color_indexed: None,
        color_tint: Some(0.35),
        charset: Some(134),
        family_number: Some(3),
        scheme: Some("major"),
        vert_align: Some("subscript"),
        family: Some("SimSun"),
      }),
    },
  ])
  let parsed = @xlsx.read(@xlsx.write(workbook))
  debug_inspect(
    parsed.get_cell_rich_text("Sheet1", "A1"),
    content=(
      #|Some(
      #|  [
      #|    { text: "plain ", font: None },
      #|    {
      #|      text: "themed",
      #|      font: Some(
      #|        {
      #|          bold: true,
      #|          italic: true,
      #|          strike: true,
      #|          outline: false,
      #|          shadow: false,
      #|          condense: false,
      #|          extended: false,
      #|          underline: Some("singleAccounting"),
      #|          size: Some(11.5),
      #|          color: None,
      #|          color_theme: Some(6),
      #|          color_indexed: None,
      #|          color_tint: Some(0.35),
      #|          charset: Some(134),
      #|          family_number: Some(3),
      #|          scheme: Some("major"),
      #|          vert_align: Some("subscript"),
      #|          family: Some("SimSun"),
      #|        },
      #|      ),
      #|    },
      #|  ],
      #|)
    ),
  )
}
