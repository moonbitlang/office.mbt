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
