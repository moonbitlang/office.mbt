///|
fn minimal_builder() -> @opc.PackageBuilder raise {
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
  builder.add_part(
    "word/document.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:sectPr/></w:body></w:document>
      ),
    ),
  )
  builder
}

///|
test "a built package satisfies the structural validator" {
  let bytes = minimal_builder().build()
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
}

///|
fn expect_build_error(
  configure : (@opc.PackageBuilder) -> Unit raise,
  expected_prefix : String,
) -> Unit raise {
  let builder = minimal_builder()
  try {
    configure(builder)
    let _ = builder.build()
  } catch {
    @opc.PackageBuildError(message) =>
      if !message.has_prefix(expected_prefix) {
        fail("unexpected message: \{message}")
      }
    _ => fail("expected PackageBuildError")
  } noraise {
    _ => fail("expected the build to fail")
  }
}

///|
test "the builder fails closed" {
  expect_build_error(
    builder => builder.add_part("word/../evil.xml", b"x"),
    "invalid part name 'word/../evil.xml'",
  )
  expect_build_error(
    builder => builder.add_part("word/document.xml", b"x"),
    "duplicate part name: word/document.xml",
  )
  expect_build_error(
    builder => builder.add_part("word/media/logo.png", b"\x89PNG"),
    "no content type for part 'word/media/logo.png'",
  )
  expect_build_error(
    builder => builder.add_override("word/ghost.xml", "application/xml"),
    "override PartName must start with '/'",
  )
  expect_build_error(
    builder => builder.add_override("/word/ghost.xml", "application/xml"),
    "override names a part that was not added: /word/ghost.xml",
  )
  expect_build_error(
    builder => {
      builder.add_relationship(
        "rId9",
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
        "styles.xml",
        source="word/document.xml",
      )
    },
    "relationship rId9 of 'word/document.xml' targets a part that was not added",
  )
}

///|
test "relationship targets resolve against their source part's directory" {
  let builder = minimal_builder()
  builder.add_override("/word/styles.xml", "application/xml")
  builder.add_part("word/styles.xml", @utf8.encode("<s/>"))
  builder.add_relationship(
    "rId2",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
    "styles.xml",
    source="word/document.xml",
  )
  let bytes = builder.build()
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
}
