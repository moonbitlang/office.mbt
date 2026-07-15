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
fn maximum_deep_zip_name() -> String {
  // 32,768 one-character segments: 32,767 slashes plus 32,768 letters.
  "a/".repeat(32_767) + "a"
}

///|
test "a built package satisfies the structural validator" {
  let bytes = minimal_builder().build()
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
}

///|
test "the builder maps logical Unicode part names to ASCII ZIP items" {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/é.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/é.xml",
  )
  builder.add_part(
    "word/é.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:sectPr/></w:body></w:document>
      ),
    ),
  )
  let bytes = builder.build()
  let archive = @mbtzip.read(bytes)
  assert_true(archive.get("word/%C3%A9.xml") is Some(_))
  assert_eq(archive.get("word/é.xml"), None)
  assert_eq(@opc.validate_docx_package(bytes), [])
}

///|
test "the builder preserves legal opaque percent escapes" {
  let builder = minimal_builder()
  builder.add_default("bin", "application/octet-stream")
  builder.add_part("word/%FF.bin", b"opaque")
  let bytes = builder.build()
  let archive = @mbtzip.read(bytes)
  assert_true(archive.get("word/%FF.bin") is Some(_))
  assert_eq(@opc.validate_docx_package(bytes), [])
}

///|
test "the builder handles the maximum deeply segmented ZIP entry name linearly" {
  let name = maximum_deep_zip_name()
  assert_eq(name.length(), 65_535)
  let registry = @opc.PartNameRegistry::new()
  assert_true(registry.register(name, name) is None)
  match registry.register(name, name) {
    Some(Equivalent(existing)) => assert_eq(existing.length(), 65_535)
    _ => fail("expected exact PartName equivalence")
  }
  let builder = minimal_builder()
  builder.add_part(name, b"")
}

///|
test "the builder rejects a ZIP entry name beyond the format limit" {
  let oversized = "a".repeat(65_536)
  expect_build_error(
    builder => builder.add_part(oversized, b""),
    "part name exceeds the 65535-character ZIP entry-name limit",
  )
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
    builder => builder.add_part("word/./extra.xml", b"x"),
    "invalid part name 'word/./extra.xml'",
  )
  expect_build_error(
    builder => builder.add_part("word//extra.xml", b"x"),
    "invalid part name 'word//extra.xml'",
  )
  expect_build_error(
    builder => builder.add_part("word/document.xml", b"x"),
    "duplicate part name: word/document.xml",
  )
  expect_build_error(
    builder => builder.add_part("WORD/DOCUMENT.XML", b"x"),
    "duplicate part name after case normalization: word/document.xml and WORD/DOCUMENT.XML",
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
  expect_build_error(
    builder => {
      builder.add_relationship(
        "rEscape",
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
        "../../outside.xml",
        source="word/document.xml",
      )
    },
    "relationship rEscape of 'word/document.xml' has an invalid internal target",
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

///|
test "ordinary parts inside _rels directories receive doubled relationship paths" {
  let builder = minimal_builder()
  builder.add_default("bin", "application/octet-stream")
  builder.add_part("word/_rels/data.bin", b"payload")
  builder.add_relationship(
    "rNested",
    "urn:test:related",
    "../document.xml",
    source="word/_rels/data.bin",
  )
  let bytes = builder.build()
  let archive = @mbtzip.read(bytes)
  assert_true(archive.get("word/_rels/data.bin") is Some(_))
  assert_true(archive.get("word/_rels/_rels/data.bin.rels") is Some(_))
  assert_eq(@opc.validate_docx_package(bytes), [])
}

///|
test "builder round 1 hardening: reserved names, orphan sources, metadata, determinism" {
  // Reserved / builder-owned names.
  expect_build_error(
    builder => builder.add_part("[Content_Types].xml", b"x"),
    "reserved part name '[Content_Types].xml'",
  )
  expect_build_error(
    builder => builder.add_part("[CONTENT_TYPES].XML", b"x"),
    "reserved part name '[CONTENT_TYPES].XML'",
  )
  expect_build_error(
    builder => builder.add_part("_rels/.rels", b"x"),
    "reserved part name '_rels/.rels'",
  )
  expect_build_error(
    builder => builder.add_part("word/_rels/.rels", b"x"),
    "reserved part name 'word/_rels/.rels'",
  )
  expect_build_error(
    builder => builder.add_part("word/_rels/document.xml.rels", b"x"),
    "reserved part name 'word/_rels/document.xml.rels'",
  )
  expect_build_error(
    builder => builder.add_part("WORD/_RELS/DOCUMENT.XML.RELS", b"x"),
    "reserved part name 'WORD/_RELS/DOCUMENT.XML.RELS'",
  )
  expect_build_error(
    builder => {
      builder.add_override(
        "/WORD/DOCUMENT.XML", "application/case-equivalent+xml",
      )
    },
    "duplicate Override PartName after case normalization: /word/document.xml and /WORD/DOCUMENT.XML",
  )
  // Trailing slash is a directory, not a part.
  expect_build_error(
    builder => builder.add_part("word/media/", b"x"),
    "invalid part name 'word/media/'",
  )
  // Orphan relationship source.
  expect_build_error(
    builder => {
      builder.add_relationship(
        "rId1",
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
        "/word/document.xml",
        source="ghost.xml",
      )
    },
    "relationships declared for source 'ghost.xml'",
  )
  // Duplicate relationship id per source.
  expect_build_error(
    builder => {
      builder.add_relationship(
        "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
        "word/document.xml",
      )
    },
    "duplicate relationship Id 'rId1' for source ''",
  )
  // XML-illegal control character in metadata.
  expect_build_error(
    builder => {
      builder.add_relationship(
        "rId7", "http://example.com/rel", "word/docu\u{01}ment.xml",
      )
    },
    "relationship Target contains an XML-illegal control character",
  )
  expect_build_error(
    builder => builder.add_default("", "application/xml"),
    "Default extension must not be empty",
  )
  // Determinism: two identical call sequences produce identical bytes.
  let first = minimal_builder().build()
  let second = minimal_builder().build()
  assert_eq(first, second)
}

///|
test "external relationships skip resolution and emit TargetMode" {
  let builder = minimal_builder()
  builder.add_relationship(
    "rId9",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
    "https://example.com/page",
    source="word/document.xml",
    external=true,
  )
  let bytes = builder.build()
  debug_inspect(@opc.validate_docx_package(bytes), content="[]")
  // The rels part carries TargetMode="External" for the hyperlink.
  let archive = @mbtzip.read(bytes)
  guard archive.get("word/_rels/document.xml.rels") is Some(rels)
  let text = @utf8.decode(rels, ignore_bom=true)
  inspect(text.find("TargetMode=\"External\"") is Some(_), content="true")
}

///|
test "builder enforces package-wide names and metadata grammars" {
  expect_build_error(
    builder => builder.add_part("word", b"ancestor"),
    "part names must not be derivable from one another",
  )
  expect_build_error(
    builder => builder.add_part("_rels", b"generated ancestor"),
    "part names must not be derivable from one another",
  )
  expect_build_error(
    builder => builder.add_default("bin", "not a media type"),
    "Default content type is not a valid media type",
  )
  expect_build_error(
    builder => builder.add_default(".bin", "application/octet-stream"),
    "Default extension is not a valid OPC ST_Extension",
  )
  expect_build_error(
    builder => builder.add_default("bad%GG", "application/octet-stream"),
    "Default extension is not a valid OPC ST_Extension",
  )
  expect_build_error(
    builder => {
      builder.add_default("bin", "application/octet-stream; charset =utf-8")
    },
    "Default content type is not a valid media type",
  )
  expect_build_error(
    builder => {
      builder.add_default("bin", "application/octet-stream; note=\"Ā\"")
    },
    "Default content type is not a valid media type",
  )
  expect_build_error(
    builder => builder.add_override("/word/document.xml", "application"),
    "Override content type is not a valid media type",
  )
  expect_build_error(
    builder => {
      builder.add_relationship("bad id", "urn:test", "word/document.xml")
    },
    "relationship Id is not an XML NCName",
  )
  expect_build_error(
    builder => {
      builder.add_relationship("rRelative", "types/test", "word/document.xml")
    },
    "relationship Type must be an absolute IRI without a fragment",
  )
  expect_build_error(
    builder => {
      builder.add_relationship(
        "rFragment", "urn:test#kind", "word/document.xml",
      )
    },
    "relationship Type must be an absolute IRI without a fragment",
  )
  expect_build_error(
    builder => {
      builder.add_relationship(
        "rPercent", "https://example.test/%GG", "word/document.xml",
      )
    },
    "relationship Type must be an absolute IRI without a fragment",
  )
  expect_build_error(
    builder => {
      builder.add_relationship(
        "rSpace",
        "urn:test",
        "https://example.test/bad path",
        external=true,
      )
    },
    "external relationship Target is not a valid IRI reference",
  )
  expect_build_error(
    builder => {
      builder.add_relationship(
        "rIpv6",
        "urn:test",
        "https://[2001:db8:::1]/",
        external=true,
      )
    },
    "external relationship Target is not a valid IRI reference",
  )
  expect_build_error(
    builder => {
      builder.add_relationship(
        "rBadPercent",
        "urn:test",
        "../outside/%GG",
        external=true,
      )
    },
    "external relationship Target is not a valid IRI reference",
  )
  expect_build_error(
    builder => {
      builder.add_relationship(
        "rNoncharacter",
        "urn:test",
        "https://example.test/\u{fdd0}",
        external=true,
      )
    },
    "external relationship Target is not a valid IRI reference",
  )
  expect_build_error(
    builder => builder.add_relationship("rBadTarget", "urn:test", "_rels/.rels"),
    "relationship rBadTarget of '' must not target a Relationships part",
  )
  let parameterized = minimal_builder()
  parameterized.add_default(
    "bin", "application/octet-stream; charset=\"utf-8\"",
  )
  parameterized.add_default(
    "a!$&'()*+,:=@-_~%2Fz", "application/x-test; note=\"é\"",
  )
  parameterized.add_part("word/data.bin", b"data")
  parameterized.add_relationship(
    "rUnicodeIri",
    "https://例え.テスト/型",
    "https://例え.テスト/文書?q=値",
    source="word/document.xml",
    external=true,
  )
  parameterized.add_relationship(
    " rWhitespace ",
    " urn:test:whitespace ",
    " data.bin ",
    source="word/document.xml",
  )
  parameterized.add_relationship(
    "rRelativeIri",
    "urn:test:relative",
    "../outside/文書",
    source="word/document.xml",
    external=true,
  )
  parameterized.add_relationship(
    "rOfficeFile",
    "urn:test:file",
    "file:///C:\\docs\\文書.docx",
    source="word/document.xml",
    external=true,
  )
  assert_eq(@opc.validate_docx_package(parameterized.build()), [])
}
