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
    if haystack[i:i + marker.length()] == marker[:] {
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
