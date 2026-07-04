///|
test "validate_ooxml_package accepts a well-formed workbook" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", String("hello"))
  sheet.set_cell_value("B2", Numeric(42.0))
  let problems = @xlsx.validate_ooxml_package(@xlsx.write(workbook)[:])
  debug_inspect(
    problems,
    content=(
      #|[]
    ),
  )
}

///|
test "validate_ooxml_package flags a missing relationship target" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  // drop xl/workbook.xml so the root rels target dangles
  let archive = @zip.read(@xlsx.write(workbook))
  let broken = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() != "xl/workbook.xml" {
      broken.add(entry.name(), entry.data())
    }
  }
  let problems = @xlsx.validate_ooxml_package(@zip.write(broken)[:])
  inspect(
    problems.iter().any(fn(p) { p.contains("missing required part") }),
    content="true",
  )
  inspect(
    problems.iter().any(fn(p) { p.contains("points to a missing part") }),
    content="true",
  )
}

///|
test "validate_ooxml_package flags an undeclared content type" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let archive = @zip.read(@xlsx.write(workbook))
  let broken = @zip.Archive::new()
  for entry in archive.entries() {
    broken.add(entry.name(), entry.data())
  }
  // add a part with an extension no Default/Override covers
  broken.add("xl/mystery.dat", b"\x00\x01\x02")
  let problems = @xlsx.validate_ooxml_package(@zip.write(broken)[:])
  inspect(
    problems
    .iter()
    .any(fn(p) {
      p.contains("no declared content type") && p.contains("mystery.dat")
    }),
    content="true",
  )
}

///|
test "validate_ooxml_package flags a corrupt archive" {
  let problems = @xlsx.validate_ooxml_package(b"not a zip at all"[:])
  inspect(
    problems.iter().any(fn(p) { p.contains("not a readable zip") }),
    content="true",
  )
}
