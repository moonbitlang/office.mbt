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
    paths.push("\{node.kind()} \{node.path()}")
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
  // comments.xml shape: w:comment elements each holding paragraphs. The
  // scanner has no special casing — each w:comment is a non-projection
  // frame, so its paragraphs restart at p[1] per comment? NO: counters
  // live on the PARENT FRAME (w:comment), so each comment's paragraphs
  // count independently — pinned here because the index relies on it.
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
    if node.kind() == "p" {
      paragraph_paths.push(node.path())
    }
  }
  paragraph_paths.sort()
  debug_inspect(
    paragraph_paths,
    content=(
      #|["p[1]", "p[1]", "p[2]"]
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
