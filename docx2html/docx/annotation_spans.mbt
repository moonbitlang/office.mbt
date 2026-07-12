// L0 span queries: the byte-level insertion offsets the preservation
// (splice) layer needs, resolved from the J1 scanner's projection of
// the ORIGINAL part bytes. Offsets index into the story part named by
// `main_story_part` — never into the whole zip.

///|
/// The byte extent of one BODY-story projection node (paragraph or
/// run) in the original word-processing part, plus the two insertion
/// offsets annotation surgery uses: `content_start` (just past the
/// open tag AND past a leading pPr/rPr — the property container leads
/// its sequence, so content and markers must land after it) and
/// `close_tag_start` (the '<' of the close tag). Both are None for a
/// self-closing form, which has no interior — the splice layer must
/// first rewrite it to the open form (a byte edit of this node's own
/// span).
pub struct NodeSpan {
  priv byte_start : Int
  priv byte_end : Int
  priv content_start : Int
  priv close_tag_start : Int
}

///|
/// Offset of the '<' of the paragraph's open tag.
pub fn NodeSpan::byte_start(self : NodeSpan) -> Int {
  self.byte_start
}

///|
/// Offset just past the '>' of the paragraph's close tag (exclusive).
pub fn NodeSpan::byte_end(self : NodeSpan) -> Int {
  self.byte_end
}

///|
/// Earliest interior insertion offset (past the open tag and any
/// leading pPr), or None for a self-closing paragraph.
pub fn NodeSpan::content_start(self : NodeSpan) -> Int? {
  if self.content_start < 0 {
    None
  } else {
    Some(self.content_start)
  }
}

///|
/// Offset of the '<' of the close tag, or None for a self-closing
/// paragraph.
pub fn NodeSpan::close_tag_start(self : NodeSpan) -> Int? {
  if self.close_tag_start < 0 {
    None
  } else {
    Some(self.close_tag_start)
  }
}

///|
/// True when the paragraph is the self-closing `<w:p/>` form.
pub fn NodeSpan::self_closing(self : NodeSpan) -> Bool {
  self.content_start < 0
}

///|
/// The zip entry name of the MAIN document part the body-story spans
/// index into (resolved through the officeDocument relationship, never
/// hardcoded).
pub fn DocxAnnotatedResult::main_story_part(
  self : DocxAnnotatedResult,
) -> String {
  self.main_part
}

///|
/// The span of the body-story paragraph at `relative_path` — the
/// story-relative ORDINAL path exactly as the index emits it
/// ("p[3]", "tbl[1]/tr[2]/tc[1]/p[1]") — or None when no such
/// paragraph was projected. Offsets index into `main_story_part`'s
/// original bytes.
pub fn DocxAnnotatedResult::body_paragraph_span(
  self : DocxAnnotatedResult,
  relative_path : String,
) -> NodeSpan? {
  body_node_span_of_kind(self, relative_path, "p")
}

///|
/// The span of the body-story RUN at `relative_path` ("p[3]/r[2]", the
/// index's ordinal form), or None. Runs carry the same offsets as
/// paragraphs (content_start past a leading rPr) so L1 can rewrite a
/// self-closing `<w:r/>` by its own extent too.
pub fn DocxAnnotatedResult::body_run_span(
  self : DocxAnnotatedResult,
  relative_path : String,
) -> NodeSpan? {
  body_node_span_of_kind(self, relative_path, "r")
}

///|
/// The ROOT element's span for a scanned story ("/body", "/comments",
/// "/footnotes", "/endnotes"), or None when the story was not scanned.
/// L1 splices a new comment definition just before the comments
/// story's `close_tag_start`; a self-closing root reports no interior
/// and must be rewritten by its own extent first.
pub fn DocxAnnotatedResult::story_root_span(
  self : DocxAnnotatedResult,
  story : String,
) -> NodeSpan? {
  for entry in self.index.scans {
    let (key, scan) = entry
    if key != story {
      continue
    }
    match scan.root() {
      Some(node) =>
        return Some({
          byte_start: node.byte_start,
          byte_end: node.byte_end,
          content_start: node.content_start,
          close_tag_start: node.close_tag_start,
        })
      None => return None
    }
  }
  None
}

///|
/// The zip entry holding the comments part (resolved by RELATIONSHIP
/// TYPE from the main part, never by filename), or None when the
/// package has no comments part yet — L1 then creates it.
pub fn DocxAnnotatedResult::comments_part(
  self : DocxAnnotatedResult,
) -> String? {
  self.comments_part_name
}

///|
/// The zip entry holding the commentsExtended part (resolved by
/// RELATIONSHIP TYPE), or None when the package has none — L2 then
/// creates it.
pub fn DocxAnnotatedResult::comments_extended_part(
  self : DocxAnnotatedResult,
) -> String? {
  self.comments_extended_part_name
}

///|
/// The span of a paragraph in ANY scanned story ("/comments" included),
/// by its story-relative ordinal path ("comment[2]/p[1]") — offsets
/// index into that story's part bytes. L2's paraId retrofit edits the
/// parent comment's LAST body paragraph through this.
pub fn DocxAnnotatedResult::story_paragraph_span(
  self : DocxAnnotatedResult,
  story : String,
  relative_path : String,
) -> NodeSpan? {
  for entry in self.index.scans {
    let (key, scan) = entry
    if key != story {
      continue
    }
    for node in scan.nodes() {
      if node.kind == "p" && node.path == relative_path {
        return Some({
          byte_start: node.byte_start,
          byte_end: node.byte_end,
          content_start: node.content_start,
          close_tag_start: node.close_tag_start,
        })
      }
    }
  }
  None
}

///|
fn body_node_span_of_kind(
  annotated : DocxAnnotatedResult,
  relative_path : String,
  kind : String,
) -> NodeSpan? {
  for entry in annotated.index.scans {
    let (story, scan) = entry
    if story != "/body" {
      continue
    }
    for node in scan.nodes() {
      if node.kind == kind && node.path == relative_path {
        return Some({
          byte_start: node.byte_start,
          byte_end: node.byte_end,
          content_start: node.content_start,
          close_tag_start: node.close_tag_start,
        })
      }
    }
  }
  None
}

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

///|
test "L0 review round 1: run spans mirror paragraph spans (rPr, self-closing)" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>bold</w:t></w:r><w:r/></w:p></w:body></w:document>
  let scan = scan_story(@utf8.encode(source))
  let mut r1_content = -2
  let mut r1_close = -2
  let mut r2_content = -2
  for node in scan.nodes() {
    if node.kind == "r" && node.path == "p[1]/r[1]" {
      r1_content = node.content_start
      r1_close = node.close_tag_start
    }
    if node.kind == "r" && node.path == "p[1]/r[2]" {
      r2_content = node.content_start
    }
  }
  // Content starts past the leading rPr (CT_R: rPr first).
  assert_eq(r1_content, span_source_offset(source, "<w:t>bold"))
  assert_eq(r1_close, span_source_offset(source, "</w:r>"))
  // The self-closing <w:r/> has no interior.
  assert_eq(r2_content, -1)
}

///|
test "L1: story roots project with insertion offsets" {
  let source =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="0" w:author="A"><w:p><w:r><w:t>x</w:t></w:r></w:p></w:comment></w:comments>
  let scan = scan_story(@utf8.encode(source))
  guard scan.root() is Some(root)
  inspect(root.kind, content="comments")
  assert_eq(root.close_tag_start, span_source_offset(source, "</w:comments>"))
  assert_eq(root.content_start, span_source_offset(source, "<w:comment "))
  // A self-closing root has no interior.
  let empty = scan_story(
    @utf8.encode(
      "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
    ),
  )
  guard empty.root() is Some(empty_root)
  inspect(empty_root.content_start, content="-1")
}
