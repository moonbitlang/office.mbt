///|
test "workbook manifest basics" {
  let manifest = @ooxml.WorkbookManifest::new(2)
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

///|
test "workbook manifest options and customization" {
  let manifest = @ooxml.WorkbookManifest::new(
    -1,
    include_shared_strings=false,
    include_calc_chain=true,
  )
  let content_types = manifest.content_types_xml()
  inspect(content_types.contains("/xl/sharedStrings.xml"), content="false")
  inspect(content_types.contains("/xl/calcChain.xml"), content="true")
  inspect(content_types.contains("/xl/worksheets/sheet1.xml"), content="false")
  manifest.add_custom_properties()
  inspect(
    manifest.content_types_xml().contains("/docProps/custom.xml"),
    content="true",
  )
  inspect(
    manifest.root_rels_xml().contains("custom-properties"),
    content="true",
  )
  manifest.set_workbook_content_type("application/custom-workbook+xml")
  inspect(
    manifest.content_types_xml().contains("application/custom-workbook+xml"),
    content="true",
  )
  inspect(
    manifest.workbook_rels_xml().contains("calcChain.xml"),
    content="true",
  )
  let id = manifest.add_workbook_relationship_with_id(
    "http://example.com/type", "example.xml",
  )
  inspect(id, content="rId4")
  inspect(manifest.workbook_rels_xml().contains("example.xml"), content="true")
}
