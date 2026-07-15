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
const DOCX_MAIN_CONTENT_TYPE_FOR_TEST : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"

///|
fn utf8_bytes(text : String) -> Bytes {
  @utf8.encode(text)
}

///|
fn opc_hash_clustered_names(
  count : Int,
  bucket_mask : Int,
  suffix : String,
) -> Array[String] {
  let names : Array[String] = []
  let mut candidate = 0
  while names.length() < count {
    let name = "n\{candidate}\{suffix}"
    if (name.hash() & bucket_mask) == 0 {
      names.push(name)
    }
    candidate += 1
  }
  names
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
  let report = @opc.validate_docx_archive_report_limited(
    try! @mbtzip.read(minimal_docx()),
    max_findings=8,
    max_message_chars=256,
  )
  assert_eq(report.main_document_part(), Some("word/document.xml"))
}

///|
test "explicit ZIP directory records are valid package metadata" {
  let with_directories = minimal_docx(extra=[
    ("word/", b""),
    ("word/media/", b""),
    ("WORD/", b""),
  ])
  debug_inspect(@opc.validate_docx_package(with_directories), content="[]")
}

///|
test "byte-backed OPC validation bounds ZIP inflation before XML parsing" {
  let data = minimal_docx()
  let entry_report = @opc.validate_docx_package_report_limited(
    data,
    max_findings=8,
    max_message_chars=1,
    max_zip_entries=2,
  )
  assert_true(entry_report.resource_limit() is Some(ZipEntries))
  assert_eq(entry_report.main_document_part(), None)
  let expanded_entry_report = @opc.validate_docx_package_report_limited(
    data,
    max_findings=8,
    max_message_chars=1,
    max_zip_entry_uncompressed_bytes=1,
  )
  assert_true(
    expanded_entry_report.resource_limit() is Some(ZipEntryUncompressedBytes),
  )
  let aggregate_report = @opc.validate_docx_package_report_limited(
    data,
    max_findings=8,
    max_message_chars=1,
    max_zip_entry_uncompressed_bytes=1024 * 1024,
    max_zip_total_uncompressed_bytes=1,
  )
  assert_true(
    aggregate_report.resource_limit() is Some(ZipTotalUncompressedBytes),
  )
}

///|
test "archive-backed OPC validation reports typed ZIP-name resource limits" {
  let data = try! @mbtzip.read(minimal_docx())
  let entry_report = @opc.validate_docx_archive_report_limited(
    data,
    max_findings=8,
    max_message_chars=64,
    max_zip_entry_name_chars=4,
  )
  assert_true(entry_report.resource_limit() is Some(ZipEntryNameCharacters))
  let aggregate_report = @opc.validate_docx_archive_report_limited(
    data,
    max_findings=8,
    max_message_chars=64,
    max_zip_entry_name_chars=65_535,
    max_zip_total_entry_name_chars=20,
  )
  assert_true(
    aggregate_report.resource_limit() is Some(ZipTotalEntryNameCharacters),
  )
}

///|
test "archive-backed OPC validation handles a maximum deep PartName" {
  let deep = "a/".repeat(32_746) + "a"
  assert_eq(deep.length(), 65_493)
  let archive = try! @mbtzip.read(minimal_docx())
  archive.add(deep, b"payload")
  let report = @opc.validate_docx_archive_report_limited(
    archive,
    max_findings=8,
    max_message_chars=64,
  )
  assert_true(report.resource_limit() is None)
  assert_false(
    report
    .findings()
    .any(finding => finding.contains("central-directory file header exceeds")),
  )
}

///|
test "OPC validation enforces the complete central-directory header limit" {
  let oversized = "a/".repeat(32_746) + "aa"
  assert_eq(oversized.length(), 65_494)
  let archive = try! @mbtzip.read(minimal_docx())
  archive.add(oversized, b"payload")
  let report = @opc.validate_docx_archive_report_limited(
    archive,
    max_findings=8,
    max_message_chars=128,
  )
  assert_true(
    report
    .findings()
    .any(finding => {
      finding.contains(
        "central-directory file header exceeds the OPC 65535-byte limit",
      )
    }),
  )
}

///|
test "relationship validation requires the OPC package namespace" {
  let foreign_child =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships" xmlns:foreign="urn:foreign"><foreign:Relationship Id="main" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
  let report = @opc.validate_docx_archive_report_limited(
    try! @mbtzip.read(minimal_docx(root_rels=Some(foreign_child))),
    max_findings=8,
    max_message_chars=256,
  )
  assert_true(
    report
    .findings()
    .search_by(finding => {
      finding.contains(
        "Relationship element is outside the OPC package relationships namespace",
      )
    })
    is Some(_),
  )
  assert_eq(report.main_document_part(), None)
}

///|
test "Relationships apply OPC Markup Compatibility processing" {
  let ignorable =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| xmlns:v="urn:vendor" mc:Ignorable="v" v:metadata="drop">
    #| <v:Extension/>
    #| <Relationship v:annotation="drop" Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    #|</Relationships>
  let process_content =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| xmlns:v="urn:vendor" mc:Ignorable="v" mc:ProcessContent="v:Wrapper">
    #| <v:Wrapper><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></v:Wrapper>
    #|</Relationships>
  let understood_choice =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
    #| xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships"
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| xmlns:v="urn:vendor">
    #| <mc:AlternateContent>
    #|  <mc:Choice Requires="v"><v:Unsupported/></mc:Choice>
    #|  <mc:Choice Requires="r"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></mc:Choice>
    #|  <mc:Fallback><v:Fallback/></mc:Fallback>
    #| </mc:AlternateContent>
    #|</Relationships>
  let fallback =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| xmlns:v="urn:vendor">
    #| <mc:AlternateContent>
    #|  <mc:Choice Requires="v"><v:Unsupported/></mc:Choice>
    #|  <mc:Fallback><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></mc:Fallback>
    #| </mc:AlternateContent>
    #|</Relationships>
  for relationships in [ignorable, process_content, understood_choice, fallback] {
    assert_eq(
      @opc.validate_docx_package(minimal_docx(root_rels=Some(relationships))),
      [],
    )
  }
}

///|
test "Relationships retain unknown MCE attributes for schema validation" {
  let root_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| mc:Bogus="value">
    #| <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    #|</Relationships>
  let findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(root_rels)),
  )
  assert_true(
    findings.any(finding => {
      finding.contains("Relationships has undeclared attribute") &&
      finding.contains("Bogus")
    }),
  )
}

///|
test "Relationships reject invalid Markup Compatibility contracts" {
  let unbound_ignorable =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| mc:Ignorable="missing">
    #| <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    #|</Relationships>
  let unsupported_must_understand =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| xmlns:v="urn:vendor" mc:MustUnderstand="v">
    #| <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    #|</Relationships>
  let malformed_alternate_content =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
    #| xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    #| xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships">
    #| <mc:AlternateContent><mc:Choice><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></mc:Choice></mc:AlternateContent>
    #|</Relationships>
  for
    relationships in [
      unbound_ignorable, unsupported_must_understand, malformed_alternate_content,
    ] {
    let findings = @opc.validate_docx_package(
      minimal_docx(root_rels=Some(relationships)),
    )
    assert_true(
      findings.any(finding => finding.contains("markup compatibility mismatch")),
    )
  }
}

///|
test "Relationships close their post-MCE XML schema" {
  let root_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"
    #| xmlns:v="urn:vendor" xml:base="https://example.test/" bad="value">
    #| unexpected text
    #| <Other/>
    #| <v:Foreign/>
    #| <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml" extra="value"><Nested/></Relationship>
    #|</Relationships>
  let findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(root_rels)),
  )
  assert_true(
    findings.any(finding => {
      finding.contains("Relationships has undeclared attribute")
    }),
  )
  assert_true(
    findings.contains("_rels/.rels: Relationships contains unexpected text"),
  )
  assert_true(
    findings.any(finding => {
      finding.contains("Relationships contains unexpected element")
    }),
  )
  assert_true(
    findings.contains(
      "_rels/.rels: Relationship has undeclared attribute: extra",
    ),
  )
  assert_true(
    findings.contains("_rels/.rels: Relationship contains a child element"),
  )
  assert_true(findings.contains("_rels/.rels: no officeDocument relationship"))
}

///|
test "Relationship elements reject non-whitespace text in root and part relationships" {
  let root_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml">schema string content</Relationship></Relationships>
  let root_findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(root_rels)),
  )
  assert_true(
    root_findings.contains("_rels/.rels: Relationship contains unexpected text"),
  )
  assert_true(
    root_findings.contains("_rels/.rels: no officeDocument relationship"),
  )

  let whitespace_root_rels = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\">\n \t</Relationship></Relationships>"
  assert_eq(
    @opc.validate_docx_package(
      minimal_docx(root_rels=Some(whitespace_root_rels)),
    ),
    [],
  )

  let part_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rImage" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/missing.png">schema string content</Relationship></Relationships>
  let part_findings = @opc.validate_docx_package(
    minimal_docx(extra=[("word/_rels/document.xml.rels", utf8_bytes(part_rels))]),
  )
  assert_true(
    part_findings.contains(
      "word/_rels/document.xml.rels: Relationship contains unexpected text",
    ),
  )
  assert_true(
    part_findings.all(finding => {
      !finding.contains("relationship target missing")
    }),
  )
}

///|
test "OPC validation is independent of deterministic string-hash clustering" {
  let part_names = opc_hash_clustered_names(256, 0x3FF, ".bin")
  let relationship_ids = opc_hash_clustered_names(256, 0x3FF, "")
  let relationships = StringBuilder()
  relationships.write_string(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
  )
  for index, id in relationship_ids {
    assert_eq(id.hash() & 0x3FF, 0)
    if index == 0 {
      relationships.write_string(
        "<Relationship Id=\"\{id}\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>",
      )
    } else {
      relationships.write_string(
        "<Relationship Id=\"\{id}\" Type=\"urn:mbt:test\" Target=\"https://example.invalid/\{index}\" TargetMode=\"External\"/>",
      )
    }
  }
  relationships.write_string("</Relationships>")
  let extras : Array[(String, Bytes)] = []
  for name in part_names {
    assert_eq(name.hash() & 0x3FF, 0)
    extras.push((name, b""))
  }
  let content_types =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="bin" ContentType="application/octet-stream"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
  debug_inspect(
    @opc.validate_docx_package(
      minimal_docx(
        content_types=Some(content_types),
        root_rels=Some(relationships.to_string()),
        extra=extras,
      ),
    ),
    content="[]",
  )
}

///|
test "OPC part lookup preserves spelling while comparing case-insensitively" {
  let archive = @mbtzip.Archive::new()
  archive.add(
    "[Content_Types].xml",
    utf8_bytes(
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/CUSTOM/MAIN.XML\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>",
    ),
  )
  archive.add(
    "_rels/.rels",
    utf8_bytes(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"custom/main.xml\"/></Relationships>",
    ),
  )
  archive.add("CUSTOM/MAIN.XML", utf8_bytes(MINIMAL_DOCUMENT_XML))
  archive.add(
    "custom/_RELS/main.xml.RELS",
    utf8_bytes(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"metadata\" Type=\"urn:example:metadata\" Target=\"comments.xml\"/></Relationships>",
    ),
  )
  archive.add("CUSTOM/comments.xml", utf8_bytes("<comments/>"))
  debug_inspect(
    @opc.validate_docx_package(try! @mbtzip.write(archive)),
    content="[]",
  )

  let aliases = @mbtzip.Archive::new()
  aliases.add("word/document.xml", utf8_bytes("<w:document/>"))
  aliases.add("WORD/DOCUMENT.XML", utf8_bytes("<w:document/>"))
  let (findings, _) = @opc.validate_docx_archive_limited(
    aliases,
    max_findings=8,
    max_message_chars=256,
  )
  assert_true(
    findings.search_by(finding => {
      finding.has_prefix("duplicate entry name: WORD/DOCUMENT.XML")
    })
    is Some(_),
  )
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
  assert_eq(@opc.resolve_target("", "1:document.xml"), None)
  assert_eq(@opc.resolve_target("", "./1:document.xml"), Some("1:document.xml"))
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
  let source_report = @opc.validate_docx_archive_report_limited(
    archive,
    max_findings=4,
    max_message_chars=1,
    max_xml_source_units=1,
    max_xml_tokens=1024,
    max_xml_materialized_chars=4096,
    max_xml_token_chars=1024,
  )
  assert_true(source_report.resource_limit() is Some(XmlSourceUnits))
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
  let token_report = @opc.validate_docx_archive_report_limited(
    archive,
    max_findings=4,
    max_message_chars=1,
    max_xml_source_units=4096,
    max_xml_tokens=1,
    max_xml_materialized_chars=4096,
    max_xml_token_chars=1024,
  )
  assert_true(token_report.resource_limit() is Some(XmlTokens))
}

///|
test "typed OPC resource status cannot be forged by a part name" {
  let data = minimal_docx(extra=[
    ("word/XML source budget exceeded.bin", b"ordinary"),
  ])
  let report = @opc.validate_docx_archive_report_limited(
    try! @mbtzip.read(data),
    max_findings=8,
    max_message_chars=256,
  )
  assert_true(report.resource_limit() is None)
  assert_true(
    report
    .findings()
    .any(finding => finding.contains("XML source budget exceeded")),
  )
}

///|
test "typed OPC resource status includes the XML nesting guard" {
  let document = StringBuilder::new()
  document.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>",
  )
  for _ in 0..<300 {
    document.write_string("<x>")
  }
  for _ in 0..<300 {
    document.write_string("</x>")
  }
  document.write_string("</w:body></w:document>")
  let report = @opc.validate_docx_archive_report_limited(
    try! @mbtzip.read(minimal_docx(document=Some(document.to_string()))),
    max_findings=8,
    max_message_chars=8,
    max_xml_source_units=1024 * 1024,
    max_xml_tokens=4096,
    max_xml_materialized_chars=1024 * 1024,
    max_xml_token_chars=4096,
  )
  assert_true(report.resource_limit() is Some(XmlNestingDepth))
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
      #|  "relationship target missing: _rels/.rels -> word/document.xml (resolved word/document.xml)",
      #|  "officeDocument relationship targets a missing part: word/document.xml",
      #|]
    ),
  )
}

///|
test "OPC Pack-URI aliases cannot select a trusted main part" {
  for
    segment in [
      "%77ord", "doc%2Fument.xml", "doc%5Cument.xml", "malformed%", "trailing.",
    ] {
    assert_false(@opc.is_valid_part_segment(segment))
  }
  for
    target in [
      "%77ord/document.xml", "word/doc%2Fument.xml", "word/doc%5Cument.xml", "word/malformed%.xml",
      "word/trailing./document.xml",
    ] {
    assert_eq(@opc.resolve_part_target("", target), None)
  }
  let aliased_path = "%77ord/document.xml"
  let alias_rels = MINIMAL_ROOT_RELS_XML.replace(
    old="Target=\"word/document.xml\"",
    new="Target=\"\{aliased_path}\"",
  )
  let alias_types = MINIMAL_CONTENT_TYPES_XML.replace(
    old="</Types>",
    new="<Override PartName=\"/\{aliased_path}\" ContentType=\"\{DOCX_MAIN_CONTENT_TYPE_FOR_TEST}\"/></Types>",
  )
  let report = @opc.validate_docx_archive_report_limited(
    try! @mbtzip.read(
      minimal_docx(
        content_types=Some(alias_types),
        root_rels=Some(alias_rels),
        extra=[(aliased_path, utf8_bytes(MINIMAL_DOCUMENT_XML))],
      ),
    ),
    max_findings=16,
    max_message_chars=256,
  )
  assert_eq(report.main_document_part(), None)
  assert_true(
    report
    .findings()
    .any(finding => finding.contains("entry name is not a valid OPC URI path")),
  )
  assert_true(
    report
    .findings()
    .any(finding => {
      finding.contains("officeDocument relationship has an invalid target")
    }),
  )
}

///|
test "OPC logical part names are distinct from physical ZIP item names" {
  assert_true(@opc.is_valid_part_segment("é.xml"))
  assert_true(@opc.is_valid_part_segment("𐐀.xml"))
  assert_false(@opc.is_valid_part_segment("%C3%A9.xml"))
  assert_false(@opc.is_valid_part_segment("%F0%90%90%80.xml"))
  assert_eq(
    @opc.logical_part_name_from_zip_item_name("word/%C3%A9.xml"),
    Some("word/é.xml"),
  )
  assert_eq(
    @opc.logical_part_name_from_zip_item_name("word/%f0%90%90%80.xml"),
    Some("word/𐐀.xml"),
  )
  assert_eq(
    @opc.logical_part_name_from_zip_item_name("word/%FF.xml"),
    Some("word/%FF.xml"),
  )
  assert_eq(
    @opc.logical_part_name_from_zip_item_name("word/%C2%80.xml"),
    Some("word/%C2%80.xml"),
  )
  assert_eq(@opc.logical_part_name_from_zip_item_name("word/é.xml"), None)
  assert_eq(@opc.logical_part_name_from_zip_item_name("word/%77ork.xml"), None)
  assert_eq(@opc.part_name_key("WORD/É.XML"), "word/É.xml")
  assert_false(@opc.part_name_key("É.xml") == @opc.part_name_key("é.xml"))
}

///|
test "relationship TargetMode is validated before identity selection" {
  let explicit_internal = MINIMAL_ROOT_RELS_XML.replace(
    old="Target=\"word/document.xml\"",
    new="Target=\"word/document.xml\" TargetMode=\"Internal\"",
  )
  let internal_report = @opc.validate_docx_archive_report_limited(
    try! @mbtzip.read(minimal_docx(root_rels=Some(explicit_internal))),
    max_findings=8,
    max_message_chars=256,
  )
  assert_eq(internal_report.findings(), [])
  assert_eq(internal_report.main_document_part(), Some("word/document.xml"))
  let invalid_mode = MINIMAL_ROOT_RELS_XML.replace(
    old="Target=\"word/document.xml\"",
    new="Target=\"word/document.xml\" TargetMode=\"Bogus\"",
  )
  let invalid_report = @opc.validate_docx_archive_report_limited(
    try! @mbtzip.read(minimal_docx(root_rels=Some(invalid_mode))),
    max_findings=8,
    max_message_chars=256,
  )
  assert_eq(invalid_report.main_document_part(), None)
  assert_true(
    invalid_report
    .findings()
    .any(finding => {
      finding.contains("Relationship has invalid TargetMode: Bogus")
    }),
  )
}

///|
test "root targets and relationship-part content types are all validated" {
  let wrong_types = MINIMAL_CONTENT_TYPES_XML.replace(
    old="application/vnd.openxmlformats-package.relationships+xml",
    new="application/xml",
  )
  let dangling_root = MINIMAL_ROOT_RELS_XML.replace(
    old="</Relationships>",
    new="<Relationship Id=\"dangling\" Type=\"urn:example:metadata\" Target=\"missing.xml\"/></Relationships>",
  )
  let findings = @opc.validate_docx_package(
    minimal_docx(content_types=Some(wrong_types), root_rels=Some(dangling_root)),
  )
  assert_true(
    findings.any(finding => {
      finding.contains(
        "relationship part _rels/.rels has content type 'application/xml'",
      )
    }),
  )
  assert_true(
    findings.any(finding => {
      finding.contains(
        "relationship target missing: _rels/.rels -> missing.xml",
      )
    }),
  )
}

///|
test "Strict main relationships require matching WordprocessingML" {
  let strict_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument" Target="word/document.xml"/></Relationships>
  let strict_document =
    #|<w:document xmlns:w="http://purl.oclc.org/ooxml/wordprocessingml/main"><w:body><w:p><w:r><w:t>hi</w:t></w:r></w:p></w:body></w:document>
  assert_eq(
    @opc.validate_docx_package(
      minimal_docx(root_rels=Some(strict_rels), document=Some(strict_document)),
    ),
    [],
  )
  let mixed_findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(strict_rels)),
  )
  assert_true(
    mixed_findings.any(finding => {
      finding.contains("does not match the officeDocument relationship dialect")
    }),
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
test "content-types and main document identity require exact namespaces and MIME" {
  let foreign_root = MINIMAL_CONTENT_TYPES_XML.replace(
    old="http://schemas.openxmlformats.org/package/2006/content-types",
    new="urn:foreign-content-types",
  )
  let foreign_root_report = @opc.validate_docx_archive_report_limited(
    try! @mbtzip.read(minimal_docx(content_types=Some(foreign_root))),
    max_findings=8,
    max_message_chars=256,
  )
  assert_true(
    foreign_root_report
    .findings()
    .any(finding => {
      finding.contains("root element is not in the OPC content-types namespace")
    }),
  )
  assert_eq(foreign_root_report.main_document_part(), None)

  let foreign_child = MINIMAL_CONTENT_TYPES_XML.replace(
    old="<Override PartName=",
    new="<foreign:Override xmlns:foreign=\"urn:foreign\" PartName=",
  )
  let foreign_child_report = @opc.validate_docx_archive_report_limited(
    try! @mbtzip.read(minimal_docx(content_types=Some(foreign_child))),
    max_findings=8,
    max_message_chars=256,
  )
  assert_true(
    foreign_child_report
    .findings()
    .any(finding => {
      finding.contains(
        "Override element is outside the OPC content-types namespace",
      )
    }),
  )
  assert_eq(foreign_child_report.main_document_part(), None)

  let wrong_mime = MINIMAL_CONTENT_TYPES_XML.replace(
    old=DOCX_MAIN_CONTENT_TYPE_FOR_TEST,
    new="application/xml",
  )
  let wrong_mime_report = @opc.validate_docx_archive_report_limited(
    try! @mbtzip.read(minimal_docx(content_types=Some(wrong_mime))),
    max_findings=8,
    max_message_chars=256,
  )
  assert_true(
    wrong_mime_report
    .findings()
    .any(finding => {
      finding.contains("expected '" + DOCX_MAIN_CONTENT_TYPE_FOR_TEST + "'")
    }),
  )
  assert_eq(wrong_mime_report.main_document_part(), None)
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
      #|["main part word/document.xml root element does not match the officeDocument relationship dialect"]
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
        ("word/./dot.xml", utf8_bytes("<x/>")),
        ("word//empty.xml", utf8_bytes("<x/>")),
        ("word\\windows.xml", utf8_bytes("<x/>")),
      ]),
    ),
    content=(
      #|[
      #|  "entry name contains a '..' segment: word/../secret.xml",
      #|  "entry name contains a '.' segment: word/./dot.xml",
      #|  "entry name contains an empty segment: word//empty.xml",
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

///|
test "OPC part names are not derivable from one another" {
  let descendant_first = @opc.validate_docx_package(
    minimal_docx(extra=[("word", b"ancestor")]),
  )
  assert_true(
    descendant_first.any(finding => {
      finding.contains("part name is derivable from another part name") &&
      finding.contains("word/document.xml") &&
      finding.contains("word")
    }),
  )
  let ancestor_first = @opc.validate_docx_package(
    minimal_docx(extra=[("a", b"ancestor"), ("a/b.xml", b"descendant")]),
  )
  assert_true(
    ancestor_first.any(finding => {
      finding.contains("part name is derivable from another part name") &&
      finding.contains("a/b.xml")
    }),
  )
}

///|
test "Relationships parts require a source while ordinary _rels paths remain legal" {
  let empty_relationships =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
  let findings = @opc.validate_docx_package(
    minimal_docx(extra=[
      ("word/_rels/ghost.xml.rels", utf8_bytes(empty_relationships)),
      ("word/_rels/.rels", utf8_bytes(empty_relationships)),
      ("word/_rels/nested/ghost.rels", utf8_bytes(empty_relationships)),
    ]),
  )
  assert_true(
    findings.contains(
      "relationship part word/_rels/ghost.xml.rels describes missing source part: word/ghost.xml",
    ),
  )
  assert_true(
    findings.contains("invalid Relationships part name: word/_rels/.rels"),
  )
  assert_true(
    findings.all(finding => !finding.contains("word/_rels/nested/ghost.rels")),
  )
}

///|
test "Relationships require NCName ids and non-empty required attributes" {
  let root_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    #|<Relationship Id="bad id" Type="urn:test" Target="word/document.xml"/>
    #|<Relationship Id="missingType" Target="word/document.xml"/>
    #|<Relationship Id="missingTarget" Type="urn:test"/>
    #|</Relationships>
  let findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(root_rels)),
  )
  assert_true(
    findings.contains(
      "_rels/.rels: Relationship Id is not an XML NCName: bad id",
    ),
  )
  assert_true(
    findings.contains("_rels/.rels: Relationship missing a non-empty Type"),
  )
  assert_true(
    findings.contains("_rels/.rels: Relationship missing a non-empty Target"),
  )
}

///|
test "Relationships collapse schema whitespace and accept Unicode Type IRIs" {
  let root_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|<Relationship Id=" rId1 " Type=" http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument " Target=" word/document.xml "/>
    #|<Relationship Id=" unicode " Type=" https://例え.テスト/型 " Target=" https://例え.テスト/文書 " TargetMode="External"/>
    #|</Relationships>
  assert_eq(
    @opc.validate_docx_package(minimal_docx(root_rels=Some(root_rels))),
    [],
  )
}

///|
test "Relationships compare collapsed IDs for uniqueness" {
  let root_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    #|<Relationship Id=" rId1 " Type="urn:test" Target="word/document.xml"/>
    #|</Relationships>
  let findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(root_rels)),
  )
  assert_true(findings.contains("_rels/.rels: duplicate Relationship Id: rId1"))
}

///|
test "Relationships enforce Type IRI and External Target IRI grammar" {
  let root_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    #|<Relationship Id="relativeType" Type="types/test" Target="https://example.test" TargetMode="External"/>
    #|<Relationship Id="fragmentType" Type="urn:test#kind" Target="https://example.test" TargetMode="External"/>
    #|<Relationship Id="badPercentType" Type="https://example.test/%GG" Target="https://example.test" TargetMode="External"/>
    #|<Relationship Id="spaceTarget" Type="urn:test" Target="https://example.test/bad path" TargetMode="External"/>
    #|<Relationship Id="badIpv6Target" Type="urn:test" Target="https://[2001:db8:::1]/" TargetMode="External"/>
    #|<Relationship Id="badPercentTarget" Type="urn:test" Target="../outside/%GG" TargetMode="External"/>
    #|<Relationship Id="unicodeTarget" Type="urn:test" Target="https://例え.テスト/文書?q=值" TargetMode="External"/>
    #|<Relationship Id="relativeTarget" Type="urn:test" Target="../outside/文書" TargetMode="External"/>
    #|<Relationship Id="officeFile" Type="urn:test" Target="file:///C:\docs\文書.docx" TargetMode="External"/>
    #|</Relationships>
  let findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(root_rels)),
  )
  assert_true(
    findings.contains(
      "_rels/.rels: Relationship Type is not an absolute IRI without a fragment: types/test",
    ),
  )
  assert_true(
    findings.contains(
      "_rels/.rels: Relationship Type is not an absolute IRI without a fragment: urn:test#kind",
    ),
  )
  assert_true(
    findings.contains(
      "_rels/.rels: Relationship Type is not an absolute IRI without a fragment: https://example.test/%GG",
    ),
  )
  assert_true(
    findings.contains(
      "_rels/.rels: external Relationship Target is not a valid IRI reference: https://example.test/bad path",
    ),
  )
  assert_true(
    findings.contains(
      "_rels/.rels: external Relationship Target is not a valid IRI reference: https://[2001:db8:::1]/",
    ),
  )
  assert_true(
    findings.contains(
      "_rels/.rels: external Relationship Target is not a valid IRI reference: ../outside/%GG",
    ),
  )
  assert_true(findings.contains("_rels/.rels: no officeDocument relationship"))
  assert_eq(findings.length(), 7)
}

///|
test "internal relationships cannot target Relationships parts" {
  let root_rels =
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rMetadata" Type="urn:test" Target="_rels/.rels"/></Relationships>
  let findings = @opc.validate_docx_package(
    minimal_docx(root_rels=Some(root_rels)),
  )
  assert_true(
    findings.contains(
      "relationship target must not be a Relationships part: _rels/.rels -> _rels/.rels",
    ),
  )
}

///|
test "content types require exact metadata spelling and media-type syntax" {
  let wrong_reserved = @opc.validate_docx_package(
    minimal_docx(skip=["[Content_Types].xml"], extra=[
      ("[CONTENT_TYPES].XML", utf8_bytes(MINIMAL_CONTENT_TYPES_XML)),
    ]),
  )
  assert_true(
    wrong_reserved.contains(
      "reserved content-types entry must use exact spelling '[Content_Types].xml': [CONTENT_TYPES].XML",
    ),
  )
  let invalid_types =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType=""/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="not a media type"/></Types>
  let findings = @opc.validate_docx_package(
    minimal_docx(content_types=Some(invalid_types)),
  )
  assert_true(
    findings.contains("[Content_Types].xml: Default has invalid ContentType: "),
  )
  assert_true(
    findings.contains(
      "[Content_Types].xml: Override has invalid ContentType: not a media type",
    ),
  )
}

///|
test "content types enforce the closed OPC XML schema" {
  let schema_invalid =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types" extra="root">unexpected text<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" extra="child"> </Default><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml" extra="child"><Bogus/></Override><Bogus/></Types>
  let findings = @opc.validate_docx_package(
    minimal_docx(content_types=Some(schema_invalid)),
  )
  for
    expected in [
      "Types has undeclared attribute", "Types contains unexpected text", "Default has undeclared attribute",
      "Default element is not empty", "Override has undeclared attribute", "Override element is not empty",
      "Types contains unexpected element",
    ] {
    if !findings.any(finding => finding.contains(expected)) {
      fail("missing schema finding: \{expected}")
    }
  }
}

///|
test "content types reject foreign MCE instead of projecting fallbacks" {
  let with_mce =
    #|<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:v="urn:vendor" mc:Ignorable="v"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><mc:AlternateContent><mc:Fallback><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></mc:Fallback></mc:AlternateContent></Types>
  let report = @opc.validate_docx_archive_report_limited(
    try! @mbtzip.read(minimal_docx(content_types=Some(with_mce))),
    max_findings=16,
    max_message_chars=512,
  )
  assert_true(
    report
    .findings()
    .any(finding => {
      finding.contains("Types has undeclared attribute") &&
      finding.contains("markup-compatibility")
    }),
  )
  assert_true(
    report
    .findings()
    .any(finding => finding.contains("Types contains unexpected element")),
  )
  assert_eq(report.main_document_part(), None)
}

///|
test "content types enforce ST_Extension and quoted media characters" {
  for invalid in [".xml", "bad%GG", "two words", "é", "x/y"] {
    let types = MINIMAL_CONTENT_TYPES_XML.replace(
      old="Extension=\"xml\"",
      new="Extension=\"\{invalid}\"",
    )
    let findings = @opc.validate_docx_package(
      minimal_docx(content_types=Some(types)),
    )
    if !findings.any(finding => {
        finding.contains("Default has invalid Extension")
      }) {
      fail("accepted invalid ST_Extension: \{invalid}")
    }
  }
  let invalid_media = MINIMAL_CONTENT_TYPES_XML
    .replace(
      old="ContentType=\"application/xml\"",
      new="ContentType=\"application/xml; charset =utf-8\"",
    )
    .replace(
      old="ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"",
      new="ContentType=\"application/x-test; note=&quot;Ā&quot;\"",
    )
  let media_findings = @opc.validate_docx_package(
    minimal_docx(content_types=Some(invalid_media)),
  )
  assert_true(
    media_findings.any(finding => {
      finding.contains("Default has invalid ContentType")
    }),
  )
  assert_true(
    media_findings.any(finding => {
      finding.contains("Override has invalid ContentType")
    }),
  )
}
