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
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  guard archive.get("xl/slicerCaches/slicerCache1.xml") is Some(cache_bytes) else {
    @test.fail("missing table slicer cache")
  }
  let cache_xml = @encoding/utf8.decode(cache_bytes)
  let scanner = @ooxml.XmlStartTagScanner::new(cache_xml)
  let x = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
  let x14 = "http://schemas.microsoft.com/office/spreadsheetml/2009/9/main"
  let x15 = "http://schemas.microsoft.com/office/spreadsheetml/2010/11/main"
  // Check expanded names and nesting, independently of prefix spelling.
  let elements = [
    (x14, "slicerCacheDefinition"),
    (x14, "extLst"),
    (x, "ext"),
    (x15, "tableSlicerCache"),
  ]
  for depth, element in elements {
    @test.assert_eq(scanner.next(), true)
    @test.assert_eq(scanner.namespace_uri().to_owned(), element.0)
    @test.assert_eq(scanner.local_name().to_owned(), element.1)
    @test.assert_eq(scanner.depth(), depth + 1)
    if depth > 0 {
      @test.assert_eq(
        scanner.parent_namespace_uri(),
        Some(elements[depth - 1].0),
      )
      @test.assert_eq(
        scanner.parent_local_name().map(name => name.to_owned()),
        Some(elements[depth - 1].1),
      )
    }
    if element.1 == "ext" {
      debug_inspect(
        scanner.attribute("", "uri"),
        content="Some(\"{2F2917AC-EB37-4324-AD4E-5DD8C200BD13}\")",
      )
    }
  }
  debug_inspect(scanner.attribute("", "tableId"), content="Some(\"1\")")
  debug_inspect(scanner.attribute("", "column"), content="Some(\"1\")")
  debug_inspect(
    scanner.attribute("", "sortOrder"),
    content="Some(\"descending\")",
  )
  inspect(scanner.next(), content="false")
  let parsed = @xlsx.read(bytes)
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
