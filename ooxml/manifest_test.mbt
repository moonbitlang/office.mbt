///|
test "workbook manifest basics" {
  let manifest = WorkbookManifest::new(2)
  let content_types = manifest.content_types_xml()
  inspect(content_types.contains("/xl/worksheets/sheet1.xml"), content="true")
  inspect(content_types.contains("/xl/worksheets/sheet2.xml"), content="true")
  inspect(content_types.contains("/xl/sharedStrings.xml"), content="true")
  inspect(
    manifest.root_rels_xml(),
    content=(
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      #|  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
      #|  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
      #|  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
      #|</Relationships>
    ),
  )
  let workbook_rels = manifest.workbook_rels_xml()
  inspect(workbook_rels.contains("worksheets/sheet1.xml"), content="true")
  inspect(workbook_rels.contains("styles.xml"), content="true")
}
