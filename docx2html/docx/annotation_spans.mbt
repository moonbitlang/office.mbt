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
/// One element-name rewrite: the byte range of an element's LOCAL NAME in
/// the original part, and the name it becomes. Rejecting a deletion turns
/// every `w:delText` back into `w:t` through these ranges, which leaves the
/// namespace prefix, `xml:space`, and every other byte of the tag untouched.
pub struct RevisionNameEdit {
  priv start : Int
  priv end : Int
  priv replacement : String
}

///|
/// Offset of the first byte of the local name.
pub fn RevisionNameEdit::start(self : RevisionNameEdit) -> Int {
  self.start
}

///|
/// Offset just past the last byte of the local name (exclusive).
pub fn RevisionNameEdit::end(self : RevisionNameEdit) -> Int {
  self.end
}

///|
/// The local name that replaces the range ("t" or "instrText").
pub fn RevisionNameEdit::replacement(self : RevisionNameEdit) -> String {
  self.replacement
}

///|
/// One tracked-change ELEMENT in the original bytes: what it is, who
/// recorded it, and the byte extent a resolver needs to unwrap or remove it.
///
/// This is the MUTATION view of a revision and is deliberately wider than
/// `AnnotationIndex::revisions`, which is the READING view. Reading reports
/// the content insertions and deletions the reader's projection retains;
/// resolving must additionally see every construct it cannot act on, because
/// a construct it cannot see is a construct it would silently leave behind.
/// `supported` separates the two: it is true only for content `w:ins` and
/// `w:del`, false for property revisions, moves, and every `*PrChange`.
pub struct RevisionSpan {
  priv story : String
  priv kind : String
  priv supported : Bool
  priv id : String?
  priv author : String?
  priv date : String?
  priv container_path : String?
  priv byte_start : Int
  priv byte_end : Int
  priv content_start : Int
  priv close_tag_start : Int
  priv declares_namespaces : Bool
  priv name_edits : Array[RevisionNameEdit]
}

///|
/// The story key the span's offsets index into ("/body", "/header[1]").
pub fn RevisionSpan::story(self : RevisionSpan) -> String {
  self.story
}

///|
/// The WML local name of the element ("ins", "del", "moveFrom", "rPrChange").
pub fn RevisionSpan::kind(self : RevisionSpan) -> String {
  self.kind
}

///|
/// True only for a content `w:ins`/`w:del` a resolver can accept or reject.
pub fn RevisionSpan::supported(self : RevisionSpan) -> Bool {
  self.supported
}

///|
/// The w:id attribute, as spelled, when present.
pub fn RevisionSpan::id(self : RevisionSpan) -> String? {
  self.id
}

///|
/// The w:author attribute, as spelled, when present.
pub fn RevisionSpan::author(self : RevisionSpan) -> String? {
  self.author
}

///|
/// The w:date attribute, LEXICAL (never converted), when present.
pub fn RevisionSpan::date(self : RevisionSpan) -> String? {
  self.date
}

///|
/// The story-relative projection path of the innermost containing node
/// ("p[2]", "tbl[1]/tr[1]/tc[1]/p[1]"), or None at story level.
pub fn RevisionSpan::container_path(self : RevisionSpan) -> String? {
  self.container_path
}

///|
/// Offset of the '<' of the element's open tag.
pub fn RevisionSpan::byte_start(self : RevisionSpan) -> Int {
  self.byte_start
}

///|
/// Offset just past the '>' that ends the element (exclusive).
pub fn RevisionSpan::byte_end(self : RevisionSpan) -> Int {
  self.byte_end
}

///|
/// Offset just past the '>' of the open tag, or None for the self-closing
/// form — which has no content to keep, so all four resolutions of it
/// collapse to removing the element.
pub fn RevisionSpan::content_start(self : RevisionSpan) -> Int? {
  if self.content_start < 0 {
    None
  } else {
    Some(self.content_start)
  }
}

///|
/// Offset of the '<' of the close tag, or None for the self-closing form.
pub fn RevisionSpan::close_tag_start(self : RevisionSpan) -> Int? {
  if self.close_tag_start < 0 {
    None
  } else {
    Some(self.close_tag_start)
  }
}

///|
/// True when the element's own start tag binds a namespace prefix. Unwrapping
/// it would drop the binding while its former children still use it, so an
/// unwrap resolution must refuse; removing the whole element stays safe.
pub fn RevisionSpan::declares_namespaces(self : RevisionSpan) -> Bool {
  self.declares_namespaces
}

///|
/// The `w:delText`/`w:delInstrText` names inside this deletion, in document
/// order; empty for an insertion. Rejecting the deletion applies all of them.
pub fn RevisionSpan::name_edits(self : RevisionSpan) -> Array[RevisionNameEdit] {
  self.name_edits.copy()
}

///|
/// Every tracked-change element across every scanned story, in story order
/// then document order. Offsets index into the part that backs each story.
///
/// The list is complete BY CONSTRUCTION: the scanner records a site for every
/// tracked-change element it walks, without the suppression and projection
/// gates the reading index applies, and retraction never removes one. A
/// resolver can therefore treat an empty result as proof that the package
/// carries no tracked changes at all.
pub fn DocxAnnotatedResult::revision_spans(
  self : DocxAnnotatedResult,
) -> Array[RevisionSpan] {
  let spans : Array[RevisionSpan] = []
  for entry in self.index.scans {
    let (story, scan) = entry
    for site in scan.revision_sites() {
      let name_edits : Array[RevisionNameEdit] = []
      for record in site.name_edits {
        name_edits.push({
          start: record.open_start,
          end: record.open_end,
          replacement: record.replacement,
        })
        if record.close_start >= 0 {
          name_edits.push({
            start: record.close_start,
            end: record.close_end,
            replacement: record.replacement,
          })
        }
      }
      spans.push({
        story,
        kind: site.local_name,
        supported: site.supported,
        id: site.id,
        author: site.author,
        date: site.date,
        container_path: site.container_path,
        byte_start: site.byte_start,
        byte_end: site.byte_end,
        content_start: site.content_start,
        close_tag_start: site.close_tag_start,
        declares_namespaces: site.declares_namespaces,
        name_edits,
      })
    }
  }
  spans
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
/// The span of one text RUN in any scanned story, addressed by the
/// story key ("/body", "/header[1]", ...) and the story-relative ordinal
/// path ("p[3]/r[2]", "p[1]/hyperlink[1]/r[1]"). The scanner already
/// records run nodes with full spans in every story; this generalizes
/// the body-only lookup so template merging can rewrite header and
/// footer runs through the same byte-span contract.
pub fn DocxAnnotatedResult::story_run_span(
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
      if node.kind == "r" && node.path == relative_path {
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
/// The span of one table ROW in any scanned story, addressed by the
/// story key ("/body", "/header[1]", ...) and the story-relative ordinal
/// path ("tbl[1]/tr[2]"). The scanner already records tr nodes with full
/// spans; template repetition replaces a row's byte region with filled
/// clones through this.
pub fn DocxAnnotatedResult::story_row_span(
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
      if node.kind == "tr" && node.path == relative_path {
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
/// Site extents are checked against offsets COMPUTED from the source text, so
/// the assertions stay honest if the fixture is ever reformatted.
test "M0: revision sites carry the element's exact byte extent" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t></w:r><w:del w:id="1" w:author="R"><w:r><w:delText xml:space="preserve">gone</w:delText></w:r></w:del><w:ins w:id="2" w:author="R"><w:r><w:t>new</w:t></w:r></w:ins><w:ins w:id="3"/></w:p></w:body></w:document>
  let scan = scan_story(@utf8.encode(source))
  let sites = scan.revision_sites()
  inspect(sites.length(), content="3")
  let deletion = sites[0]
  inspect(deletion.local_name, content="del")
  inspect(deletion.supported, content="true")
  inspect(deletion.container_path.unwrap_or(""), content="p[1]")
  assert_eq(deletion.byte_start, span_source_offset(source, "<w:del "))
  assert_eq(
    deletion.content_start,
    span_source_offset(source, "<w:r><w:delText"),
  )
  assert_eq(deletion.close_tag_start, span_source_offset(source, "</w:del>"))
  assert_eq(deletion.byte_end, span_source_offset(source, "<w:ins w:id=\"2\""))
  // The name edits address the LOCAL NAME only: rewriting them renames the
  // element without touching the prefix, xml:space, or anything else.
  inspect(deletion.name_edits.length(), content="1")
  let name = deletion.name_edits[0]
  assert_eq(source[name.open_start:name.open_end].to_owned(), "delText")
  assert_eq(source[name.close_start:name.close_end].to_owned(), "delText")
  assert_eq(name.replacement, "t")
  assert_eq(name.open_start, span_source_offset(source, "delText xml:space"))
  let insertion = sites[1]
  inspect(insertion.local_name, content="ins")
  assert_eq(
    insertion.byte_start,
    span_source_offset(source, "<w:ins w:id=\"2\""),
  )
  assert_eq(
    insertion.byte_end,
    span_source_offset(source, "<w:ins w:id=\"3\"/>"),
  )
  // The self-closing form reports no interior at all.
  let empty = sites[2]
  inspect(empty.content_start, content="-1")
  inspect(empty.close_tag_start, content="-1")
  assert_eq(empty.byte_start, span_source_offset(source, "<w:ins w:id=\"3\"/>"))
  assert_eq(empty.byte_end, span_source_offset(source, "</w:p>"))
}

///|
/// Every tracked-change construct is RECORDED, including the ones no resolver
/// in this build can act on. A construct the mutation layer cannot see is a
/// construct it would silently leave behind, so `supported` — not omission —
/// is what separates the resolvable set from the rest.
test "M0: unresolvable tracked-change constructs are recorded, not skipped" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:rPr><w:ins w:id="1" w:author="R"/></w:rPr></w:pPr><w:r><w:rPr><w:b/><w:rPrChange w:id="2" w:author="R"><w:rPr/></w:rPrChange></w:rPr><w:t>a</w:t></w:r><w:moveFrom w:id="3" w:author="R"><w:r><w:t>m</w:t></w:r></w:moveFrom><w:ins w:id="4" w:author="R"><w:r><w:t>n</w:t></w:r></w:ins></w:p></w:body></w:document>
  let scan = scan_story(@utf8.encode(source))
  let shape : Array[String] = []
  for site in scan.revision_sites() {
    shape.push("\{site.local_name}:\{site.supported}")
  }
  assert_eq(shape, [
    "ins:false", "rPrChange:false", "moveFrom:false", "ins:true",
  ])
  // The READING view is unchanged by any of this: it still reports only the
  // content revisions the reader's projection retains.
  let read : Array[String] = []
  for revision in scan.revisions() {
    read.push("\{revision.kind()}:\{revision.id().unwrap_or("")}")
  }
  assert_eq(read, ["ins:4"])
}

///|
/// The two views diverge on purpose where the reader RETRACTS a subtree. A
/// vertically merged continuation cell does not exist in the projection, so
/// its revisions leave the reading index — but their bytes are still in the
/// part, so their sites must survive.
test "M0: retracting a subtree drops read revisions but keeps their sites" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>a</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:ins w:id="7" w:author="R"><w:r><w:t>hidden</w:t></w:r></w:ins></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
  let scan = scan_story(@utf8.encode(source))
  inspect(scan.revisions().length(), content="0")
  inspect(scan.revision_sites().length(), content="1")
  inspect(scan.revision_sites()[0].id.unwrap_or(""), content="7")
}

///|
/// A deleted table ROW is a property revision the reader removes wholesale.
/// The site still records it, so a resolver asked to accept everything
/// refuses instead of publishing a document that still holds a pending row
/// deletion.
test "M0: a deleted table row is recorded as an unresolvable site" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:tbl><w:tr><w:trPr><w:del w:id="5" w:author="R"/></w:trPr><w:tc><w:p><w:r><w:t>a</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>
  let scan = scan_story(@utf8.encode(source))
  inspect(scan.revisions().length(), content="0")
  let sites = scan.revision_sites()
  inspect(sites.length(), content="1")
  inspect(sites[0].local_name, content="del")
  inspect(sites[0].supported, content="false")
}

///|
/// Prefix spelling never enters the decision: a WML-bound prefix that is not
/// `w` is still a revision, and a `w`-prefixed element bound to some other
/// namespace is not.
test "M0: revision sites are matched by namespace, never by prefix" {
  let source =
    #|<x:document xmlns:x="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w="urn:not-wml"><x:body><x:p><x:ins x:id="1" x:author="R"><x:r><x:t>a</x:t></x:r></x:ins><w:ins w:id="2"/></x:p></x:body></x:document>
  let scan = scan_story(@utf8.encode(source))
  let sites = scan.revision_sites()
  inspect(sites.length(), content="1")
  inspect(sites[0].id.unwrap_or(""), content="1")
  inspect(sites[0].declares_namespaces, content="false")
}

///|
test "L1: story roots project with insertion offsets" {
  let source =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="0" w:author="A"><w:p><w:r><w:t>x</w:t></w:r></w:p></w:comment></w:comments>
  let scan = scan_story(@utf8.encode(source))
  guard scan.root() is Some(root) else { fail("expected root") }
  inspect(root.kind, content="comments")
  assert_eq(root.close_tag_start, span_source_offset(source, "</w:comments>"))
  assert_eq(root.content_start, span_source_offset(source, "<w:comment "))
  // A self-closing root has no interior.
  let empty = scan_story(
    @utf8.encode(
      "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
    ),
  )
  guard empty.root() is Some(empty_root) else { fail("expected empty_root") }
  inspect(empty_root.content_start, content="-1")
}
