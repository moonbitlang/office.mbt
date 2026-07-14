///|
const MINIMAL_DOCUMENT_XML : String =
  #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>hi</w:t></w:r></w:p></w:body></w:document>

///|
const MINIMAL_CONTENT_TYPES_XML : String =
  #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>

///|
const MINIMAL_ROOT_RELS_XML : String =
  #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>

///|
fn utf8_bytes(text : String) -> Bytes {
  @utf8.encode(text)
}

///|
/// A minimal structurally valid docx, with per-part replacement hooks.
fn minimal_docx(
  content_types? : String? = None,
  root_rels? : String? = None,
  document? : String? = None,
  extra? : Array[(String, Bytes)] = [],
  skip? : Array[String] = [],
) -> Bytes {
  let archive = @mbtzip.Archive::new()
  let parts : Array[(String, Bytes)] = [
    (
      "[Content_Types].xml",
      utf8_bytes(content_types.unwrap_or(MINIMAL_CONTENT_TYPES_XML)),
    ),
    ("_rels/.rels", utf8_bytes(root_rels.unwrap_or(MINIMAL_ROOT_RELS_XML))),
    ("word/document.xml", utf8_bytes(document.unwrap_or(MINIMAL_DOCUMENT_XML))),
  ]
  for part in parts {
    let (name, data) = part
    if skip.search(name) is None {
      archive.add(name, data)
    }
  }
  for part in extra {
    let (name, data) = part
    archive.add(name, data)
  }
  try! @mbtzip.write(archive)
}

///|
test "a minimal well-formed package is valid" {
  debug_inspect(@opc.validate_docx_package(minimal_docx()), content="[]")
}

///|
test "relationship targets share fallible package-root normalization" {
  assert_eq(
    @opc.resolve_target("word", "media/./image.png"),
    Some("word/media/image.png"),
  )
  assert_eq(
    @opc.resolve_target("word/", "../custom/main.xml"),
    Some("custom/main.xml"),
  )
  assert_eq(
    @opc.resolve_target("ignored/base", "/word/./document.xml"),
    Some("word/document.xml"),
  )
  assert_eq(@opc.resolve_target("word", "../../escape.xml"), None)
  assert_eq(@opc.resolve_target("", "/../escape.xml"), None)
  assert_eq(@opc.resolve_target("", "word//document.xml"), None)
  assert_eq(@opc.resolve_target("", "https://example.test/x.xml"), None)
}

///|
test "package-rooted relationship dot segments validate consistently" {
  let rooted = MINIMAL_ROOT_RELS_XML.replace(
    old="Target=\"word/document.xml\"",
    new="Target=\"/word/./document.xml\"",
  )
  debug_inspect(
    @opc.validate_docx_package(minimal_docx(root_rels=Some(rooted))),
    content="[]",
  )
  let escaping = MINIMAL_ROOT_RELS_XML.replace(
    old="Target=\"word/document.xml\"",
    new="Target=\"/../word/document.xml\"",
  )
  let findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(escaping)),
  )
  assert_true(
    findings.search_by(finding => {
      finding.contains(
        "_rels/.rels: officeDocument relationship has an invalid target: /../word/document.xml",
      )
    })
    is Some(_),
  )
}

///|
test "archive-backed validation matches byte validation" {
  let valid = minimal_docx()
  let invalid = minimal_docx(extra=[("word/media/image1.png", b"not-png")])
  for data in [valid, invalid] {
    let archive = try! @mbtzip.read(data)
    assert_eq(
      @opc.validate_docx_archive(archive),
      @opc.validate_docx_package(data),
    )
  }
}

///|
test "limited validation bounds findings and messages during production" {
  let archive = @mbtzip.Archive::new()
  for index in 0..<12 {
    archive.add(
      "very-long-malformed-entry-name-\{index}-\\bad.xml",
      utf8_bytes("<x/>"),
    )
  }
  let (findings, truncated) = @opc.validate_docx_archive_limited(
    archive,
    max_findings=3,
    max_message_chars=24,
  )
  assert_eq(findings.length(), 3)
  assert_true(truncated)
  for finding in findings {
    assert_true(finding.length() <= 24)
  }
  let (valid_findings, valid_truncated) = @opc.validate_docx_archive_limited(
    try! @mbtzip.read(minimal_docx()),
    max_findings=3,
    max_message_chars=24,
  )
  assert_eq(valid_findings.length(), 0)
  assert_false(valid_truncated)
}

///|
test "limited validation bounds aggregate XML work before DOM construction" {
  let archive = try! @mbtzip.read(minimal_docx())
  let (source_findings, _) = @opc.validate_docx_archive_limited(
    archive,
    max_findings=4,
    max_message_chars=256,
    max_xml_source_units=1,
    max_xml_tokens=1024,
    max_xml_materialized_chars=4096,
    max_xml_token_chars=1024,
  )
  assert_true(
    source_findings.search_by(finding => {
      finding.contains("XML source budget exceeded")
    })
    is Some(_),
  )
  let (token_findings, _) = @opc.validate_docx_archive_limited(
    archive,
    max_findings=4,
    max_message_chars=256,
    max_xml_source_units=4096,
    max_xml_tokens=1,
    max_xml_materialized_chars=4096,
    max_xml_token_chars=1024,
  )
  assert_true(
    token_findings.search_by(finding => {
      finding.contains("XML token budget exceeded")
    })
    is Some(_),
  )
}

///|
test "limited validation bounds parser diagnostics before collector truncation" {
  let entity = "attacker".repeat(512)
  let document = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>&\{entity};</w:body></w:document>"
  let archive = try! @mbtzip.read(minimal_docx(document=Some(document)))
  let (findings, _) = @opc.validate_docx_archive_limited(
    archive,
    max_findings=8,
    max_message_chars=512,
    max_xml_source_units=32 * 1024,
    max_xml_tokens=4096,
    max_xml_materialized_chars=32 * 1024,
    max_xml_token_chars=8 * 1024,
  )
  guard findings.search_by(finding => finding.contains("undeclared XML entity"))
    is Some(index) else {
    fail("expected bounded XML parser diagnostic")
  }
  let finding = findings[index]
  assert_true(finding.length() < 256)
  assert_true(finding.contains("…"))
}

///|
test "OPC validation uses strict XML for every structural part" {
  let duplicate_types = MINIMAL_CONTENT_TYPES_XML.replace(
    old="<Default Extension=\"rels\"",
    new="<Default Extension=\"bad\" Extension=\"rels\"",
  )
  let duplicate_rels = MINIMAL_ROOT_RELS_XML.replace(
    old="<Relationship Id=\"rId1\"",
    new="<Relationship Id=\"bad\" Id=\"rId1\"",
  )
  let duplicate_document = MINIMAL_DOCUMENT_XML.replace(
    old="<w:document ",
    new="<w:document duplicate=\"bad\" duplicate=\"value\" ",
  )
  for
    data in [
      minimal_docx(content_types=Some(duplicate_types)),
      minimal_docx(root_rels=Some(duplicate_rels)),
      minimal_docx(document=Some(duplicate_document)),
    ] {
    let findings = @opc.validate_docx_package(data)
    assert_true(
      findings.search_by(finding => finding.contains("duplicate XML attribute"))
      is Some(_),
    )
  }
}

///|
test "garbage bytes and missing required parts are findings" {
  debug_inspect(
    @opc.validate_docx_package(b"not a zip at all"),
    content=(
      #|["invalid ZIP archive: MissingEndOfCentral"]
    ),
  )
  debug_inspect(
    @opc.validate_docx_package(minimal_docx(skip=["[Content_Types].xml"])),
    content=(
      #|["missing required part: [Content_Types].xml"]
    ),
  )
  debug_inspect(
    @opc.validate_docx_package(minimal_docx(skip=["_rels/.rels"])),
    content=(
      #|["missing required part: _rels/.rels"]
    ),
  )
}

///|
test "the main part is found by following the officeDocument relationship" {
  // Nonstandard main-part path: valid as long as the relationship, the
  // part, and its content-type override line up (never a hardcoded
  // word/document.xml check).
  let rels =
    #|<?xml version="1.0"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="custom/main.xml"/></Relationships>
  let types =
    #|<?xml version="1.0"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/custom/main.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
  let archive = @mbtzip.Archive::new()
  archive.add("[Content_Types].xml", utf8_bytes(types))
  archive.add("_rels/.rels", utf8_bytes(rels))
  archive.add("custom/main.xml", utf8_bytes(MINIMAL_DOCUMENT_XML))
  debug_inspect(
    @opc.validate_docx_package(try! @mbtzip.write(archive)),
    content="[]",
  )
  // A dangling officeDocument relationship is a finding.
  debug_inspect(
    @opc.validate_docx_package(minimal_docx(skip=["word/document.xml"])),
    content=(
      #|[
      #|  "[Content_Types].xml: Override names a missing part: /word/document.xml",
      #|  "officeDocument relationship targets a missing part: word/document.xml",
      #|]
    ),
  )
}

///|
test "Strict main relationships are authoritative and multiple declarations fail" {
  let strict_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument" Target="word/document.xml"/></Relationships>
  assert_eq(
    @opc.validate_docx_package(minimal_docx(root_rels=Some(strict_rels))),
    [],
  )
  let multiple = strict_rels.replace(
    old="</Relationships>",
    new=(
      #|<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
    ),
  )
  let findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(multiple)),
  )
  assert_true(
    findings.search_by(finding => {
      finding == "_rels/.rels: multiple officeDocument relationships"
    })
    is Some(_),
  )
}

///|
test "a wrong main-part root and a missing officeDocument rel are findings" {
  debug_inspect(
    @opc.validate_docx_package(
      minimal_docx(
        document=Some(
          (
            #|<w:wrong xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>
          ),
        ),
      ),
    ),
    content=(
      #|["main part word/document.xml root element is 'wrong', expected a 'document' root"]
    ),
  )
  let no_office_rel =
    #|<?xml version="1.0"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="word/styles.xml"/></Relationships>
  let findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(no_office_rel)),
  )
  // The styles rel target is also missing; the first finding is the one
  // under test.
  debug_inspect(
    findings.search_by(f => f.has_prefix("_rels/.rels: no officeDocument"))
    is Some(_),
    content="true",
  )
}

///|
test "part relationships with dangling internal targets are findings" {
  let doc_rels =
    #|<?xml version="1.0"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/missing.png"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com" TargetMode="External"/></Relationships>
  debug_inspect(
    @opc.validate_docx_package(
      minimal_docx(extra=[
        ("word/_rels/document.xml.rels", utf8_bytes(doc_rels)),
      ]),
    ),
    content=(
      #|["relationship target missing: word/_rels/document.xml.rels -> media/missing.png (resolved word/media/missing.png)"]
    ),
  )
}

///|
test "content-type coverage requires a default or an override" {
  debug_inspect(
    @opc.validate_docx_package(
      minimal_docx(extra=[("word/media/image1.png", b"\x89PNG")]),
    ),
    content=(
      #|["no content type for part: word/media/image1.png"]
    ),
  )
  // An override naming a missing part is a finding too.
  let types =
    #|<?xml version="1.0"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/ghost.xml" ContentType="application/xml"/></Types>
  debug_inspect(
    @opc.validate_docx_package(minimal_docx(content_types=Some(types))),
    content=(
      #|["[Content_Types].xml: Override names a missing part: /word/ghost.xml"]
    ),
  )
}

///|
test "content types reject duplicate normalized declaration keys" {
  let types =
    #|<?xml version="1.0"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    #|<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
    #|<Default Extension="xml" ContentType="application/xml"/>
    #|<Default Extension="XML" ContentType="application/duplicate+xml"/>
    #|<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    #|<Override PartName="/word/./document.xml" ContentType="application/duplicate+xml"/>
    #|</Types>
  let findings = @opc.validate_docx_package(
    minimal_docx(content_types=Some(types)),
  )
  assert_true(
    findings.search_by(finding => {
      finding.contains(
        "duplicate Default Extension after case normalization: xml",
      )
    })
    is Some(_),
  )
  assert_true(
    findings.search_by(finding => {
      finding.contains(
        "duplicate Override PartName after path normalization: /word/document.xml",
      )
    })
    is Some(_),
  )
  assert_true(
    findings.search_by(finding => {
      finding.contains(
        "Override PartName is not canonical: /word/./document.xml",
      )
    })
    is Some(_),
  )
}

///|
test "each relationships part requires unique non-empty ids" {
  let root_rels =
    #|<?xml version="1.0"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|<Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    #|<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    #|<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com" TargetMode="External"/>
    #|</Relationships>
  let document_rels =
    #|<?xml version="1.0"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://one.example" TargetMode="External"/>
    #|<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://two.example" TargetMode="External"/>
    #|</Relationships>
  let findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(root_rels), extra=[
      ("word/_rels/document.xml.rels", utf8_bytes(document_rels)),
    ]),
  )
  assert_true(
    findings.search_by(finding => {
      finding == "_rels/.rels: Relationship missing a non-empty Id"
    })
    is Some(_),
  )
  assert_true(
    findings.search_by(finding => {
      finding == "_rels/.rels: duplicate Relationship Id: rId1"
    })
    is Some(_),
  )
  assert_true(
    findings.search_by(finding => {
      finding == "word/_rels/document.xml.rels: duplicate Relationship Id: rId1"
    })
    is Some(_),
  )
}

///|
test "malformed entry names are findings" {
  debug_inspect(
    @opc.validate_docx_package(
      minimal_docx(extra=[
        ("word/../secret.xml", utf8_bytes("<x/>")),
        ("word\\windows.xml", utf8_bytes("<x/>")),
      ]),
    ),
    content=(
      #|[
      #|  "entry name contains a '..' segment: word/../secret.xml",
      #|  "entry name contains a backslash: word\\windows.xml",
      #|]
    ),
  )
}

///|
test "duplicate names and CRC corruption are findings" {
  let archive = @mbtzip.Archive::new()
  archive.add("[Content_Types].xml", utf8_bytes(MINIMAL_CONTENT_TYPES_XML))
  archive.add("_rels/.rels", utf8_bytes(MINIMAL_ROOT_RELS_XML))
  archive.add("word/document.xml", utf8_bytes(MINIMAL_DOCUMENT_XML))
  archive.add("word/document.xml", utf8_bytes(MINIMAL_DOCUMENT_XML))
  debug_inspect(
    @opc.validate_docx_package(try! @mbtzip.write(archive)),
    content=(
      #|["duplicate entry name: word/document.xml"]
    ),
  )
  // Flip one byte of the stored (uncompressed) document payload: inflation
  // tolerates it, the stored CRC exposes it. This is the exact corruption
  // class that slipped through review fixtures before (issue #76).
  let bytes = minimal_docx().to_array()
  let marker = utf8_bytes("<w:t>hi</w:t>")
  let mut at = -1
  let haystack = Bytes::from_array(bytes)
  for i in 0..<(haystack.length() - marker.length()) {
    if haystack[i:i + marker.length()] == marker {
      at = i
      break
    }
  }
  assert_true(at >= 0)
  bytes[at + 5] = b'X'
  debug_inspect(
    @opc.validate_docx_package(Bytes::from_array(bytes)),
    content=(
      #|["entry data does not match its stored CRC-32: word/document.xml"]
    ),
  )
}

///|
test "an empty or slash-less Override PartName is a finding, not a crash" {
  let types =
    #|<?xml version="1.0"?>
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="" ContentType="application/xml"/><Override PartName="w" ContentType="application/xml"/></Types>
  debug_inspect(
    @opc.validate_docx_package(minimal_docx(content_types=Some(types))),
    content=(
      #|[
      #|  "[Content_Types].xml: Override PartName must start with '/': ",
      #|  "[Content_Types].xml: Override PartName must start with '/': w",
      #|]
    ),
  )
}
