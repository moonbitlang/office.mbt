// L0 span pins: the scanner's insertion offsets, checked against
// positions COMPUTED from the source text (find), never hard-coded.

///|
fn span_source_offset(source : String, needle : String) -> Int raise {
  match source.find(needle) {
    Some(offset) => offset
    None => fail("needle not in source: \{needle}")
  }
}

///|
test "L0: paragraph spans carry content_start past a leading pPr" {
  let source =
    #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:pStyle w:val="H"/></w:pPr><w:r><w:t>x</w:t></w:r></w:p><w:p><w:r><w:t>y</w:t></w:r></w:p><w:p/></w:body></w:document>
  let scan = scan_story(@utf8.encode(source))
  let mut p1_content = -2
  let mut p1_close = -2
  let mut p2_content = -2
  let mut p3_content = -2
  let mut p3_close = -2
  for node in scan.nodes() {
    if node.kind == "p" && node.path == "p[1]" {
      p1_content = node.content_start
      p1_close = node.close_tag_start
    }
    if node.kind == "p" && node.path == "p[2]" {
      p2_content = node.content_start
    }
    if node.kind == "p" && node.path == "p[3]" {
      p3_content = node.content_start
      p3_close = node.close_tag_start
    }
  }
  // p[1]: content starts right past </w:pPr>, at the first run.
  assert_eq(p1_content, span_source_offset(source, "<w:r><w:t>x"))
  assert_eq(p1_close, span_source_offset(source, "</w:p><w:p><w:r><w:t>y"))
  // p[2] has no pPr: content starts right past the open tag.
  assert_eq(p2_content, span_source_offset(source, "<w:r><w:t>y"))
  // p[3] is self-closing: no interior.
  assert_eq(p3_content, -1)
  assert_eq(p3_close, -1)
}

///|
test "L0: self-closing pPr and alternate prefixes still pin content_start" {
  // A self-closing <v:pPr/> under an ALTERNATE WML prefix: URI-aware
  // matching must move content_start past it all the same.
  let source =
    #|<v:document xmlns:v="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><v:body><v:p><v:pPr/><v:r><v:t>z</v:t></v:r></v:p></v:body></v:document>
  let scan = scan_story(@utf8.encode(source))
  let mut content = -2
  let mut close = -2
  for node in scan.nodes() {
    if node.kind == "p" && node.path == "p[1]" {
      content = node.content_start
      close = node.close_tag_start
    }
  }
  assert_eq(content, span_source_offset(source, "<v:r><v:t>z"))
  assert_eq(close, span_source_offset(source, "</v:p>"))
}

///|
test "L0: a nested pPr does not move an OUTER paragraph's content_start" {
  // The pPr belongs to the INNER paragraph of a table nested mid-way;
  // the outer paragraph's content_start must stay at its own first
  // child. (Direct-parent check, not nearest-ancestor.)
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:p><w:r><w:t>after</w:t></w:r></w:p></w:body></w:document>
  let scan = scan_story(@utf8.encode(source))
  let mut cell_content = -2
  let mut after_content = -2
  for node in scan.nodes() {
    if node.kind == "p" && node.path == "tbl[1]/tr[1]/tc[1]/p[1]" {
      cell_content = node.content_start
    }
    if node.kind == "p" && node.path == "p[1]" {
      after_content = node.content_start
    }
  }
  assert_eq(cell_content, span_source_offset(source, "<w:r><w:t>cell"))
  assert_eq(after_content, span_source_offset(source, "<w:r><w:t>after"))
}
