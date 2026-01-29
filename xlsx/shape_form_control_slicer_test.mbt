///|
test "shape write" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let shape = Shape::new("A1", "rect", macro_name="MyMacro", text="Hello")
  sheet.add_shape(shape)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  inspect(drawing_xml.contains("<xdr:sp>"), content="true")
  inspect(drawing_xml.contains("prst=\"rect\""), content="true")
  inspect(drawing_xml.contains("macro=\"MyMacro\""), content="true")
  inspect(drawing_xml.contains("Hello"), content="true")
  inspect(drawing_xml.contains("cx=\"1524000\""), content="true")
  inspect(drawing_xml.contains("cy=\"1524000\""), content="true")
}

///|
test "shape size and rich text paragraphs" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let runs : Array[RichTextRun] = [
    {
      text: "Rectangle",
      font: Some({
        bold: false,
        italic: false,
        strike: false,
        outline: false,
        shadow: false,
        condense: false,
        extend: false,
        underline: None,
        size: None,
        color: Some("CD5C5C"),
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
    {
      text: "Shape",
      font: Some({
        bold: true,
        italic: true,
        strike: false,
        outline: false,
        shadow: false,
        condense: false,
        extend: false,
        underline: Some("sng"),
        size: Some(18.0),
        color: Some("2980B9"),
        color_theme: None,
        color_indexed: None,
        color_tint: None,
        charset: None,
        family_number: None,
        scheme: None,
        vert_align: None,
        family: Some("Times New Roman"),
      }),
    },
  ]
  let shape = Shape::new("B2", "rect", paragraph=runs, width=180, height=40)
  sheet.add_shape(shape)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  inspect(drawing_xml.contains("cx=\"1714500\""), content="true")
  inspect(drawing_xml.contains("cy=\"381000\""), content="true")
  inspect(drawing_xml.contains("b=\"1\""), content="true")
  inspect(drawing_xml.contains("i=\"1\""), content="true")
  inspect(drawing_xml.contains("u=\"sng\""), content="true")
  inspect(drawing_xml.contains("sz=\"1800\""), content="true")
  inspect(drawing_xml.contains("typeface=\"Times New Roman\""), content="true")
  inspect(drawing_xml.contains("val=\"2980B9\""), content="true")
}

///|
test "shape fill and line" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let shape = Shape::new(
    "C3",
    "rect",
    text="Styled",
    width=160,
    height=160,
    fill_color="8EB9FF",
    fill_transparency=60,
    line_color="4286F4",
    line_width=1.2,
  )
  sheet.add_shape(shape)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  inspect(drawing_xml.contains("val=\"8EB9FF\""), content="true")
  inspect(drawing_xml.contains("alpha val=\"40000\""), content="true")
  inspect(drawing_xml.contains("w=\"15240\""), content="true")
  inspect(drawing_xml.contains("val=\"4286F4\""), content="true")
}

///|
test "shape name, alt text, and clientData flags" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let shape = Shape::new(
    "D4",
    "rect",
    text="Meta",
    name="Shape 1",
    alt_text="Shape",
    locked=false,
    print_object=false,
  )
  sheet.add_shape(shape)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  inspect(drawing_xml.contains("name=\"Shape 1\""), content="true")
  inspect(drawing_xml.contains("descr=\"Shape\""), content="true")
  inspect(drawing_xml.contains("fLocksWithSheet=\"0\""), content="true")
  inspect(drawing_xml.contains("fPrintsWithSheet=\"0\""), content="true")
}

///|
test "shape positioning twoCell" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let shape = Shape::new("E5", "rect", positioning=PicturePositioning::TwoCell)
  sheet.add_shape(shape)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  inspect(drawing_xml.contains("<xdr:twoCellAnchor>"), content="true")
  inspect(drawing_xml.contains("<xdr:oneCellAnchor>"), content="false")
}

///|
test "shape positioning absolute" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let shape = Shape::new("F6", "rect", positioning=PicturePositioning::Absolute)
  sheet.add_shape(shape)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  inspect(
    drawing_xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
}

///|
test "form control add/get/delete and vml" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_form_control(
    "Sheet1",
    FormControl::new("B2", "Button", text="Click"),
  )
  let rich_button = FormControl::new("E5", "Button", text="Button 1")
  rich_button.set_paragraph([
    {
      text: "C1=A1+B1",
      font: Some({
        bold: true,
        italic: true,
        strike: false,
        outline: false,
        shadow: false,
        condense: false,
        extend: false,
        underline: Some("single"),
        size: Some(14.0),
        color: Some("777777"),
        color_theme: None,
        color_indexed: None,
        color_tint: None,
        charset: None,
        family_number: None,
        scheme: None,
        vert_align: None,
        family: Some("Times New Roman"),
      }),
    },
  ])
  workbook.add_form_control("Sheet1", rich_button)
  let checkbox = FormControl::new("C3", "CheckBox", text="Agree")
  checkbox.set_width(140)
  checkbox.set_height(60)
  checkbox.set_macro_name("DoThing")
  checkbox.set_cell_link("A1")
  checkbox.set_checked(true)
  workbook.add_form_control("Sheet1", checkbox)
  let scrollbar = FormControl::new("D4", "Scroll")
  scrollbar.set_width(140)
  scrollbar.set_height(20)
  scrollbar.set_cell_link("A1")
  scrollbar.set_current_val(50)
  scrollbar.set_min_val(10)
  scrollbar.set_max_val(100)
  scrollbar.set_inc_change(1)
  scrollbar.set_page_change(1)
  scrollbar.set_horizontally(true)
  scrollbar.set_format(
    GraphicOptions::with_values(
      print_object=false,
      positioning=PicturePositioning::Absolute,
    ),
  )
  workbook.add_form_control("Sheet1", scrollbar)
  inspect(workbook.get_form_controls("Sheet1").length(), content="4")
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let vml_xml = match archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("vmlDrawing1.vml utf8 decode failed")
      }
    None => fail("missing vmlDrawing1.vml")
  }
  inspect(vml_xml.contains("ObjectType=\"Button\""), content="true")
  inspect(vml_xml.contains("Click"), content="true")
  inspect(vml_xml.contains("o:button=\"t\""), content="true")
  inspect(vml_xml.contains("buttonFace [67]"), content="true")
  inspect(
    vml_xml.contains("<x:Anchor>2, 0, 2, 0, 4, 12, 5, 6</x:Anchor>"),
    content="true",
  )
  inspect(
    vml_xml.contains("<x:FmlaMacro>DoThing</x:FmlaMacro>"),
    content="true",
  )
  inspect(vml_xml.contains("<x:FmlaLink>A1</x:FmlaLink>"), content="true")
  inspect(vml_xml.contains("<x:Checked>1</x:Checked>"), content="true")
  inspect(vml_xml.contains("fillcolor=\"window [65]\""), content="true")
  inspect(vml_xml.contains("strokecolor=\"windowText [64]\""), content="true")
  inspect(vml_xml.contains("ObjectType=\"Scroll\""), content="true")
  inspect(vml_xml.contains("<x:Val>50</x:Val>"), content="true")
  inspect(vml_xml.contains("<x:Min>10</x:Min>"), content="true")
  inspect(vml_xml.contains("<x:Max>100</x:Max>"), content="true")
  inspect(vml_xml.contains("<x:Inc>1</x:Inc>"), content="true")
  inspect(vml_xml.contains("<x:Page>1</x:Page>"), content="true")
  inspect(vml_xml.contains("<x:Horiz"), content="true")
  inspect(vml_xml.contains("<x:Dx>15</x:Dx>"), content="true")
  inspect(
    vml_xml.contains("face=\"Times New Roman\" size=\"280\" color=\"#777777\""),
    content="true",
  )
  inspect(vml_xml.contains("<b>"), content="true")
  inspect(vml_xml.contains("<i>"), content="true")
  inspect(vml_xml.contains("<u>"), content="true")
  inspect(
    vml_xml.contains("<x:PrintObject>False</x:PrintObject>"),
    content="true",
  )
  inspect(vml_xml.contains("<x:MoveWithCells"), content="true")
  inspect(vml_xml.contains("<x:SizeWithCells"), content="true")
  let parsed = read(bytes)
  let controls = parsed.get_form_controls("Sheet1")
  inspect(controls.length(), content="4")
  let mut parsed_checkbox : FormControl? = None
  let mut parsed_scrollbar : FormControl? = None
  let mut parsed_rich_button : FormControl? = None
  for control in controls {
    if control.control_type == "CheckBox" {
      parsed_checkbox = Some(control)
    } else if control.control_type == "ScrollBar" {
      parsed_scrollbar = Some(control)
    } else if control.cell == "E5" {
      parsed_rich_button = Some(control)
    }
  }
  match parsed_checkbox {
    Some(control) => {
      inspect(control.text, content="Agree")
      inspect(control.macro_name, content="Some(\"DoThing\")")
      inspect(control.cell_link, content="Some(\"A1\")")
      inspect(control.checked, content="Some(true)")
    }
    None => fail("missing parsed checkbox")
  }
  match parsed_scrollbar {
    Some(control) => {
      inspect(control.cell_link, content="Some(\"A1\")")
      inspect(control.current_val, content="Some(50)")
      inspect(control.min_val, content="Some(10)")
      inspect(control.max_val, content="Some(100)")
      inspect(control.inc_change, content="Some(1)")
      inspect(control.page_change, content="Some(1)")
      inspect(control.horizontally, content="Some(true)")
      inspect(control.format.print_object, content="Some(false)")
      inspect(control.format.positioning, content="Some(Absolute)")
    }
    None => fail("missing parsed scrollbar")
  }
  match parsed_rich_button {
    Some(control) => {
      inspect(control.text, content="Button 1")
      inspect(control.paragraph.length(), content="1")
      inspect(control.paragraph[0].text, content="C1=A1+B1")
      inspect(
        control.paragraph[0].font,
        content="Some({bold: true, italic: true, strike: false, outline: false, shadow: false, condense: false, extend: false, underline: Some(\"single\"), size: Some(14), color: Some(\"#777777\"), color_theme: None, color_indexed: None, color_tint: None, charset: None, family_number: None, scheme: None, vert_align: None, family: Some(\"Times New Roman\")})",
      )
    }
    None => fail("missing parsed rich button")
  }
  workbook.delete_form_control("Sheet1", "C3")
  inspect(workbook.get_form_controls("Sheet1").length(), content="3")
}

///|
test "slicer add/get/delete and xml" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(
    workbook.add_table_with_columns("Sheet1", "A1:C4", "Table1", [
      "Region", "Type", "Sales",
    ]),
  )
  let opts = SlicerOptions::new("Region", "E1", "Sheet1", "Table1")
  opts.set_caption("Region")
  workbook.add_slicer("Sheet1", opts)
  inspect(workbook.get_slicers("Sheet1").length(), content="1")
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let slicer_xml = match archive.get("xl/slicers/slicer1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("slicer1.xml utf8 decode failed")
      }
    None => fail("missing slicer1.xml")
  }
  inspect(slicer_xml.contains("<slicers"), content="true")
  inspect(slicer_xml.contains("name=\"Region\""), content="true")
  inspect(slicer_xml.contains("cache=\"Slicer_"), content="true")
  let cache_xml = match archive.get("xl/slicerCaches/slicerCache1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("slicerCache1.xml utf8 decode failed")
      }
    None => fail("missing slicerCache1.xml")
  }
  inspect(cache_xml.contains("slicerCacheDefinition"), content="true")
  inspect(cache_xml.contains("sourceName=\"Region\""), content="true")
  inspect(cache_xml.contains("tableSlicerCache"), content="true")
  let rels_xml = match archive.get("xl/worksheets/_rels/sheet1.xml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml.rels utf8 decode failed")
      }
    None => fail("missing sheet1.xml.rels")
  }
  inspect(rels_xml.contains("relationships/slicer"), content="true")
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("slicerList"), content="true")
  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("workbook.xml utf8 decode failed")
      }
    None => fail("missing workbook.xml")
  }
  inspect(workbook_xml.contains("slicerCaches"), content="true")
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  inspect(drawing_xml.contains("office/drawing/2010/slicer"), content="true")
  workbook.delete_slicer("Region")
  inspect(workbook.get_slicers("Sheet1").length(), content="0")
}

///|
test "slicer options builder write" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(
    workbook.add_table_with_columns("Sheet1", "A1:C4", "Table1", [
      "Region", "Type", "Sales",
    ]),
  )
  let opts = SlicerOptions::new("Region", "E1", "Sheet1", "Table1")
  opts.set_caption("Region")
  opts.set_display_header(Some(false))
  workbook.add_slicer("Sheet1", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let slicer_xml = match archive.get("xl/slicers/slicer1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing slicer1.xml")
  }
  inspect(slicer_xml.contains("caption=\"Region\""), content="true")
  inspect(slicer_xml.contains("showCaption=\"0\""), content="true")
}
