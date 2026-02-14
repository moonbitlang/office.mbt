///|
test "workbook manifest set_workbook_content_type pushes when missing" {
  let manifest = WorkbookManifest::new(0)
  while manifest.content_types.overrides.length() > 0 {
    ignore(manifest.content_types.overrides.pop())
  }
  manifest.set_workbook_content_type("application/custom-workbook+xml")
  inspect(
    manifest.content_types_xml().contains("application/custom-workbook+xml"),
    content="true",
  )
}
