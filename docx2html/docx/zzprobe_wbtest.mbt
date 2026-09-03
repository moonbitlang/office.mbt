///|
test "probe bookmark capture" {
  let document = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:bookmarkStart w:id=\"0\" w:name=\"b\"/><w:bookmarkEnd w:id=\"0\"/><w:r><w:t>x</w:t></w:r></w:p><w:p><w:r><w:t>k</w:t></w:r></w:p><w:sectPr/></w:body></w:document>"
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_part("word/document.xml", @utf8.encode(document))
  let annotated = read_docx_annotated(builder.build())
  let part = annotated.main_story_part()
  guard annotated.reader_projections.get(part) is Some(projection) else {
    fail("no retained projection")
  }
  for element in projection.scan.elements() {
    if element.local_name == "bookmarkStart" {
      let name = element.bookmark_name_raw.unwrap_or("NONE")
      let id = element.bookmark_id_raw.unwrap_or("NONE")
      println("start name=" + name + " id=" + id)
    }
  }
}
