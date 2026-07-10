///|
test "shape parsed on read" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let shape = @xlsx.Shape::new(
    "C3",
    "rect",
    macro_name="MyMacro",
    text="Hello",
    fill_color="8EB9FF",
    fill_transparency=60,
    line_color="4286F4",
    line_width=1.2,
    name="Shape 1",
    alt_text="Alt",
    locked=false,
    print_object=false,
    positioning=TwoCell,
  )
  workbook.add_shape("Sheet1", shape)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(sheet.shapes().length(), content="1")
  let got = sheet.shapes()[0]
  inspect(got.reference, content="C3")
  inspect(got.cell, content="C3")
  inspect(got.shape_type, content="rect")
  inspect(got.macro_alias, content="MyMacro")
  inspect(got.macro_name, content="MyMacro")
  debug_inspect(got.format.name, content="Some(\"Shape 1\")")
  debug_inspect(got.format.alt_text, content="Some(\"Alt\")")
  debug_inspect(got.format.print_object, content="Some(false)")
  debug_inspect(got.format.locked, content="Some(false)")
  debug_inspect(got.format.positioning, content="Some(TwoCell)")
  debug_inspect(got.fill.color, content="Some(\"8EB9FF\")")
  debug_inspect(got.fill.transparency, content="Some(60)")
  inspect(got.fill_color, content="8EB9FF")
  inspect(got.fill_transparency, content="60")
  debug_inspect(got.line.color, content="Some(\"4286F4\")")
  inspect(got.line_color, content="4286F4")
  inspect(got.line.width is Some(_), content="true")
  inspect((got.line_width - 1.2).abs() < 0.0001, content="true")
  inspect(got.name, content="Shape 1")
  inspect(got.alt_text, content="Alt")
  inspect(got.locked, content="false")
  inspect(got.print_object, content="false")
  debug_inspect(got.positioning, content="TwoCell")
  inspect(got.paragraph.length() > 0, content="true")
  inspect(got.paragraph[0].text, content="Hello")
}
