///|
/// End-to-end J2 pins through the PUBLIC projection: cross-story
/// coverage (a range anchored INSIDE a comment body) surfaces as
/// comment_ids on both id-form and ordinal annotation-body paths.
fn commented_fixture() -> Bytes raise {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body><w:p><w:r><w:t>plain body</w:t></w:r></w:p></w:body>
    #|</w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:comment w:id="0" w:author="A"><w:p><w:commentRangeStart w:id="1"/><w:r><w:t>annotated inside a comment</w:t></w:r><w:commentRangeEnd w:id="1"/><w:r><w:commentReference w:id="1"/></w:r></w:p></w:comment>
    #|<w:comment w:id="1" w:author="B"><w:p><w:r><w:t>meta comment</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/comments.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rId2",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    "comments.xml",
    source="word/document.xml",
  )
  builder.add_part("word/document.xml", @utf8.encode(document))
  builder.add_part("word/comments.xml", @utf8.encode(comments))
  builder.build()
}

///|
test "J2: cross-story comment_ids on annotation-body paths, id-form and ordinal" {
  let annotated = @docx_impl.read_docx_annotated(commented_fixture())
  for path in ["/comments/comment[@id=0]/p[1]", "/comments/comment[1]/p[1]"] {
    let payload = @inspect.annotated_element(annotated, file="f.docx", path~)
    guard payload is Object(map)
    guard map.get("comment_ids") is Some(Array(ids))
    debug_inspect(ids.length(), content="1")
    debug_inspect(
      ids[0],
      content=(
        #|String("1")
      ),
    )
    // Both spellings normalize to the id-form echo.
    debug_inspect(
      map.get("path"),
      content=(
        #|Some(String("/comments/comment[@id=0]/p[1]"))
      ),
    )
  }
}
