///|
test "slicer roundtrip read" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(
    workbook.add_table_with_columns("Sheet1", "A1:C4", "Table1", [
      "Region", "Type", "Sales",
    ]),
  )
  let opts = @xlsx.SlicerOptions::new("Region", "E1", "Sheet1", "Table1")
  opts.set_caption("Region caption")
  opts.set_display_header(Some(false))
  opts.set_item_desc(true)
  opts.set_macro_name("Macro1")
  opts.set_size(300, 160)
  opts.set_format(
    @xlsx.GraphicOptions::with_values(
      offset_x=5,
      offset_y=7,
      alt_text="Slicer alt",
      print_object=false,
      locked=false,
      positioning=Absolute,
    ),
  )
  workbook.add_slicer("Sheet1", opts)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let slicers = parsed.get_slicers("Sheet1")
  inspect(slicers.length(), content="1")
  let slicer = slicers[0]
  inspect(slicer.name, content="Region")
  inspect(slicer.source_name, content="Region")
  inspect(slicer.cell, content="E1")
  inspect(slicer.table_sheet, content="Sheet1")
  inspect(slicer.table_name, content="Table1")
  inspect(slicer.caption, content="Region caption")
  inspect(slicer.macro_name, content="Macro1")
  inspect(slicer.width, content="300")
  inspect(slicer.height, content="160")
  debug_inspect(slicer.display_header, content="Some(false)")
  inspect(slicer.item_desc, content="true")
  debug_inspect(slicer.format.offset_x, content="Some(5)")
  debug_inspect(slicer.format.offset_y, content="Some(7)")
  debug_inspect(slicer.format.alt_text, content="Some(\"Slicer alt\")")
  debug_inspect(slicer.format.print_object, content="Some(false)")
  debug_inspect(slicer.format.locked, content="Some(false)")
  debug_inspect(slicer.format.positioning, content="Some(Absolute)")
}
