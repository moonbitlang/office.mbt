///|
test "resolve_part_path handles real xlsx relationship shapes" {
  // worksheet rels -> drawing (../ climb)
  inspect(
    resolve_part_path("xl/worksheets/", "../drawings/drawing1.xml"),
    content="xl/drawings/drawing1.xml",
  )
  // workbook rels -> worksheet (plain descend)
  inspect(
    resolve_part_path("xl/", "worksheets/sheet1.xml"),
    content="xl/worksheets/sheet1.xml",
  )
  // root rels -> workbook
  inspect(resolve_part_path("", "xl/workbook.xml"), content="xl/workbook.xml")
  // package-absolute target
  inspect(
    resolve_part_path("xl/worksheets/", "/xl/media/image1.png"),
    content="xl/media/image1.png",
  )
  // ./ no-op segment
  inspect(
    resolve_part_path("xl/", "./theme/theme1.xml"),
    content="xl/theme/theme1.xml",
  )
  // escape-root returns "" (treated as skip, not error)
  inspect(resolve_part_path("", "../outside.xml"), content="")
}

///|
test "rels_base_dir and part_extension" {
  inspect(
    rels_base_dir("xl/worksheets/_rels/sheet1.xml.rels"),
    content="xl/worksheets/",
  )
  inspect(rels_base_dir("_rels/.rels"), content="")
  inspect(rels_base_dir("xl/_rels/workbook.xml.rels"), content="xl/")
  debug_inspect(
    part_extension("xl/worksheets/sheet1.xml"),
    content=(
      #|Some("xml")
    ),
  )
  debug_inspect(
    part_extension("xl/media/image1.PNG"),
    content=(
      #|Some("PNG")
    ),
  )
  debug_inspect(
    part_extension("_rels/.rels"),
    content=(
      #|Some("rels")
    ),
  )
  // no extension after last slash
  debug_inspect(part_extension("xl/theme"), content="None")
}
