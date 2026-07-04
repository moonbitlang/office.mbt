///|
test "shape workbook sheet name validation" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_shape("Sheet1", Shape::new("A1", "rect"))
  let bad_name : Result[Unit, Error] = try? workbook.add_shape(
    "Sheet:1",
    Shape::new("A1", "rect"),
  )
  inspect(bad_name is Err(XlsxError::InvalidSheetName(_)), content="true")
  let missing : Result[Unit, Error] = try? workbook.add_shape(
    "SheetN",
    Shape::new("A1", "rect"),
  )
  inspect(missing is Err(XlsxError::SheetNotFound(_)), content="true")
}

///|
test "shape new validates basic fields" {
  inspect(
    (try? Shape::new("", "rect")) is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (try? Shape::new("A1", "")) is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (try? Shape::new("A1", "rect", width=0)) is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (try? Shape::new("A1", "rect", height=-1)) is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (try? Shape::new("A1", "rect", scale_x=0.0))
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (try? Shape::new("A1", "rect", scale_y=-1.0))
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (try? Shape::new("A1", "rect", fill_transparency=-1))
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (try? Shape::new("A1", "rect", fill_transparency=101))
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (try? Shape::new("A1", "rect", line_width=0.0))
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (try? Shape::new("??", "rect")) is Err(InvalidCellRef(_)),
    content="true",
  )
  inspect(
    (try? ShapeFill::with_values(transparency=-1))
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (try? ShapeFill::with_values(transparency=101))
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
}

///|
test "shape new happy path with options" {
  let line = ShapeLine::with_values(color="FF0000", width=2.0)
  debug_inspect(line.color, content="Some(\"FF0000\")")
  debug_inspect(line.width, content="Some(2)")
  let line2 = ShapeLine::with_values()
  debug_inspect(line2.color, content="None")
  debug_inspect(line2.width, content="None")
  let fill = ShapeFill::with_values(color="00FF00", transparency=25)
  debug_inspect(fill.color, content="Some(\"00FF00\")")
  debug_inspect(fill.transparency, content="Some(25)")
  let fill2 = ShapeFill::with_values()
  debug_inspect(fill2.color, content="None")
  debug_inspect(fill2.transparency, content="None")
  let shape = Shape::new(
    "B2",
    "rect",
    macro_name="Macro1",
    text="Hello",
    width=120,
    height=80,
    scale_x=1.5,
    scale_y=2.0,
    fill_color="00FF00",
    fill_transparency=25,
    line_color="0000FF",
    line_width=1.25,
    name="S1",
    alt_text="Alt",
    print_object=false,
    locked=false,
    positioning=TwoCell,
  )
  inspect(shape.reference, content="B2")
  inspect(shape.cell, content="B2")
  inspect(shape.shape_type, content="rect")
  inspect(shape.macro_alias, content="Macro1")
  inspect(shape.macro_name, content="Macro1")
  inspect(shape.text, content="Hello")
  inspect(shape.width, content="120")
  inspect(shape.height, content="80")
  inspect(shape.scale_x, content="1.5")
  inspect(shape.scale_y, content="2")
  debug_inspect(shape.format.scale_x, content="Some(1.5)")
  debug_inspect(shape.format.scale_y, content="Some(2)")
  debug_inspect(shape.format.name, content="Some(\"S1\")")
  debug_inspect(shape.format.alt_text, content="Some(\"Alt\")")
  debug_inspect(shape.format.print_object, content="Some(false)")
  debug_inspect(shape.format.locked, content="Some(false)")
  debug_inspect(shape.format.positioning, content="Some(TwoCell)")
  debug_inspect(shape.fill.color, content="Some(\"00FF00\")")
  debug_inspect(shape.fill.transparency, content="Some(25)")
  inspect(shape.fill_color, content="00FF00")
  inspect(shape.fill_transparency, content="25")
  debug_inspect(shape.line.color, content="Some(\"0000FF\")")
  debug_inspect(shape.line.width, content="Some(1.25)")
  inspect(shape.line_color, content="0000FF")
  inspect(shape.line_width, content="1.25")
  inspect(shape.name, content="S1")
  inspect(shape.alt_text, content="Alt")
  inspect(shape.print_object, content="false")
  inspect(shape.locked, content="false")
  debug_inspect(shape.positioning, content="TwoCell")
}
