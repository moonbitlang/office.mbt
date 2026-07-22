///|
/// End-to-end net for read-time package feature flags (#207 R2a): the
/// flags must come from the RAW part list of a real read, not from any
/// modeled state, and API-built workbooks must carry none.

///|
test "package features: API-built workbooks carry none" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  assert_eq(workbook.package_features(), @xlsx.XlsxPackageFeatures::none())
}

///|
test "package features: injected external-link part raises the flag through read" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Data")
  sheet.set_cell_value("A1", @xlsx.CellValue::String("x"))
  let base = @xlsx.write(workbook)
  let clean = @xlsx.read(base)
  assert_eq(clean.package_features(), @xlsx.XlsxPackageFeatures::none())
  let archive = @zip.read(base)
  // cover the injected part in the manifest so the strict reader treats
  // it as a declared (if unmodeled) part rather than an alien entry
  let manifest = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  let patched = manifest.replace(
    old="</Types>",
    new="<Override PartName=\"/xl/externalLinks/externalLink1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.externalLink+xml\"/></Types>",
  )
  assert_true(
    archive.replace("[Content_Types].xml", @encoding/utf8.encode(patched)),
  )
  archive.add(
    "xl/externalLinks/externalLink1.xml",
    @encoding/utf8.encode(
      "<externalLink xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"/>",
    ),
  )
  let tampered = @zip.write(archive)
  let parsed = @xlsx.read(tampered)
  let features = parsed.package_features()
  assert_true(features.external_links)
  assert_eq(
    features.first_external_link,
    Some("xl/externalLinks/externalLink1.xml"),
  )
  assert_false(features.unknown_parts)
}
