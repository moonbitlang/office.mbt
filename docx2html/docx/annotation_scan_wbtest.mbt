///|
fn scan_text(xml : String) -> StoryScan raise DocxError {
  scan_story(@utf8.encode(xml))
}

///|
test "scanner: projection paths, marker containment, and document order" {
  let scan = scan_text(
    (
      #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:body>
      #|<w:p><w:r><w:t>plain</w:t></w:r></w:p>
      #|<w:p>
      #|<w:commentRangeStart w:id="1"/>
      #|<w:r><w:t>annotated</w:t></w:r>
      #|<w:commentRangeEnd w:id="1"/>
      #|<w:r><w:commentReference w:id="1"/></w:r>
      #|</w:p>
      #|<w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
      #|<w:p><w:hyperlink><w:r><w:t>link</w:t><w:footnoteReference w:id="2"/></w:r></w:hyperlink></w:p>
      #|</w:body>
      #|</w:document>
    ),
  )
  debug_inspect(scan.warnings().length(), content="0")
  let paths : Array[String] = []
  for node in scan.nodes() {
    paths.push("\{node.kind} \{node.path()}")
  }
  paths.sort()
  debug_inspect(
    paths,
    content=(
      #|[
      #|  "p p[1]",
      #|  "p p[2]",
      #|  "p p[3]",
      #|  "tbl tbl[1]",
      #|  "r p[1]/r[1]",
      #|  "r p[2]/r[1]",
      #|  "r p[2]/r[2]",
      #|  "tr tbl[1]/tr[1]",
      #|  "tc tbl[1]/tr[1]/tc[1]",
      #|  "r p[3]/hyperlink[1]/r[1]",
      #|  "p tbl[1]/tr[1]/tc[1]/p[1]",
      #|  "hyperlink p[3]/hyperlink[1]",
      #|  "r tbl[1]/tr[1]/tc[1]/p[1]/r[1]",
      #|]
    ),
  )
  let marks : Array[String] = []
  for marker in scan.markers() {
    marks.push(
      "\{marker.kind()} id=\{marker.id()} in=\{marker.container_path().unwrap_or("<story>")} after=\{marker.after_child().unwrap_or("-")}",
    )
  }
  debug_inspect(
    marks,
    content=(
      #|[
      #|  "commentRangeStart id=1 in=p[2] after=-",
      #|  "commentRangeEnd id=1 in=p[2] after=p[2]/r[1]",
      #|  "commentReference id=1 in=p[2]/r[2] after=-",
      #|  "footnoteReference id=2 in=p[3]/hyperlink[1]/r[1] after=-",
      #|]
    ),
  )
  // Document order and interval sanity: the range start precedes r[1]'s
  // open; the end follows r[1]'s close; the covered run's interval nests
  // inside [start.seq, end.seq].
  let markers = scan.markers()
  let mut covered_open = 0
  let mut covered_close = 0
  for node in scan.nodes() {
    if node.path() == "p[2]/r[1]" {
      covered_open = node.open_seq()
      covered_close = node.close_seq()
    }
  }
  debug_inspect(markers[0].seq() < covered_open, content="true")
  debug_inspect(covered_close < markers[1].seq(), content="true")
}

///|
test "scanner: alternate namespace prefixes and non-WML lookalikes" {
  // The WML URI bound to prefix `x`; a DIFFERENT namespace binds `w` —
  // its commentRangeStart lookalike and its `w:id` must be ignored.
  let scan = scan_text(
    (
      #|<x:document xmlns:x="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w="http://example.com/not-wml">
      #|<x:body>
      #|<x:p>
      #|<w:commentRangeStart w:id="9"/>
      #|<x:commentRangeStart x:id="3"/>
      #|<x:r><x:t>hi</x:t></x:r>
      #|<x:commentRangeEnd x:id="3"/>
      #|</x:p>
      #|</x:body>
      #|</x:document>
    ),
  )
  let marks : Array[String] = []
  for marker in scan.markers() {
    marks.push("\{marker.kind()} id=\{marker.id()}")
  }
  debug_inspect(
    marks,
    content=(
      #|["commentRangeStart id=3", "commentRangeEnd id=3"]
    ),
  )
  debug_inspect(scan.nodes().length(), content="2")
}

///|
test "scanner: comments story counts each comment body separately" {
  // w:comment is a projection CONTAINER (kind "comment") in the comments
  // story, so paragraph paths carry the container identity and each
  // comment's paragraphs count independently — review round 1 finding 3.
  let scan = scan_text(
    (
      #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:comment w:id="0"><w:p><w:r><w:t>a</w:t></w:r></w:p><w:p><w:r><w:t>b</w:t></w:r></w:p></w:comment>
      #|<w:comment w:id="1"><w:p><w:r><w:t>c</w:t></w:r></w:p></w:comment>
      #|</w:comments>
    ),
  )
  let paragraph_paths : Array[String] = []
  for node in scan.nodes() {
    if node.kind == "p" {
      paragraph_paths.push(node.path())
    }
  }
  paragraph_paths.sort()
  debug_inspect(
    paragraph_paths,
    content=(
      #|["comment[1]/p[1]", "comment[1]/p[2]", "comment[2]/p[1]"]
    ),
  )
}

///|
test "scanner: unterminated tag and UTF-16 parts fail closed" {
  try {
    let _ = scan_text(
      "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p",
    )
  } catch {
    Unsupported(message~) =>
      inspect(
        message.has_prefix("the annotation scanner found an unterminated"),
        content="true",
      )
    err => fail("unexpected error: \{repr(err)}")
  } noraise {
    _ => fail("expected the scan to fail")
  }
  let utf16 : Bytes = b"\xFF\xFE<\x00a\x00>\x00"
  try {
    let _ = scan_story(utf16)
  } catch {
    Unsupported(message~) =>
      inspect(
        message.has_prefix("the annotation scanner supports UTF-8"),
        content="true",
      )
    err => fail("unexpected error: \{repr(err)}")
  } noraise {
    _ => fail("expected the scan to fail")
  }
}

///|
test "scanner review round 1: flattening parity — sdt, ins, del, vMerge" {
  // The reader flattens sdt/sdtContent/smartTag/ins and drops w:del and
  // vMerge continuation cells; scanner ordinals must mirror that.
  let scan = scan_text(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:body>
      #|<w:p><w:r><w:t>a</w:t></w:r></w:p>
      #|<w:sdt><w:sdtPr/><w:sdtContent><w:p><w:ins><w:r><w:t>inserted</w:t></w:r></w:ins><w:del><w:r><w:t>gone</w:t></w:r></w:del></w:p></w:sdtContent></w:sdt>
      #|<w:tbl>
      #|<w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>tall</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>b</w:t></w:r></w:p></w:tc></w:tr>
      #|<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t/></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>b2</w:t></w:r></w:p></w:tc></w:tr>
      #|</w:tbl>
      #|</w:body>
      #|</w:document>
    ),
  )
  let paths : Array[String] = []
  for node in scan.nodes() {
    paths.push(node.path())
  }
  paths.sort()
  // The sdt-wrapped paragraph is p[2] (NOT a nested p[1]); the inserted
  // run is p[2]/r[1]; the deleted run has no path at all. Row 2's
  // continuation cell is stripped, so its sibling is tc[1] in the AST —
  // and the continuation cell's paragraph/run get no paths.
  debug_inspect(
    paths,
    content=(
      #|[
      #|  "p[1]",
      #|  "p[2]",
      #|  "tbl[1]",
      #|  "p[1]/r[1]",
      #|  "p[2]/r[1]",
      #|  "tbl[1]/tr[1]",
      #|  "tbl[1]/tr[2]",
      #|  "tbl[1]/tr[1]/tc[1]",
      #|  "tbl[1]/tr[1]/tc[2]",
      #|  "tbl[1]/tr[2]/tc[1]",
      #|  "tbl[1]/tr[1]/tc[1]/p[1]",
      #|  "tbl[1]/tr[1]/tc[2]/p[1]",
      #|  "tbl[1]/tr[2]/tc[1]/p[1]",
      #|  "tbl[1]/tr[1]/tc[1]/p[1]/r[1]",
      #|  "tbl[1]/tr[1]/tc[2]/p[1]/r[1]",
      #|  "tbl[1]/tr[2]/tc[1]/p[1]/r[1]",
      #|]
    ),
  )
}

///|
test "scanner review round 1: entity-decoded ids, Strict WML, CDATA immunity" {
  // &#49; IS id "1"; the Strict namespace URI is recognized; marker
  // lookalikes inside CDATA are never counted.
  let scan = scan_text(
    (
      #|<w:document xmlns:w="http://purl.oclc.org/ooxml/wordprocessingml/main">
      #|<w:body>
      #|<w:p><w:commentRangeStart w:id="&#00000049;"/><w:r><w:t><![CDATA[<w:commentRangeEnd w:id="1"/>]]></w:t></w:r><w:commentRangeEnd w:id="&#x31;"/><w:r><w:commentReference w:id="1"/></w:r></w:p>
      #|</w:body>
      #|</w:document>
    ),
  )
  let marks : Array[String] = []
  for marker in scan.markers() {
    marks.push("\{marker.kind()} id=\{marker.id()}")
  }
  debug_inspect(
    marks,
    content=(
      #|[
      #|  "commentRangeStart id=1",
      #|  "commentRangeEnd id=1",
      #|  "commentReference id=1",
      #|]
    ),
  )
}

///|
test "scanner review round 1: plumbing notes are suppressed, user notes counted" {
  let scan = scan_text(
    (
      #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      #|<w:footnote w:type="separator" w:id="-1"><w:p><w:r><w:t/></w:r></w:p></w:footnote>
      #|<w:footnote w:type="continuationSeparator" w:id="0"><w:p/></w:footnote>
      #|<w:footnote w:type="continuationNotice" w:id="1"><w:p/></w:footnote>
      #|<w:footnote w:id="2"><w:p><w:r><w:t>real</w:t></w:r></w:p></w:footnote>
      #|</w:footnotes>
    ),
  )
  let paths : Array[String] = []
  for node in scan.nodes() {
    paths.push(node.path())
  }
  paths.sort()
  debug_inspect(
    paths,
    content=(
      #|["note[1]", "note[1]/p[1]", "note[1]/p[1]/r[1]"]
    ),
  )
}
