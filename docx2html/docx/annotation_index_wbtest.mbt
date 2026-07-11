///|
/// Assembles a minimal in-memory package: document.xml plus optional
/// comments/commentsExtended/footnotes parts, wired as MAIN-part
/// relationships (the plan's OPC rule). OPC-valid by construction; the
/// CONFORMANCE fixtures additionally pass the Microsoft SDK gate in
/// sdk_validity; the negatives here are deliberately schema-invalid and
/// pin tolerant-reader behavior.
fn fixture_docx(
  document_xml : String,
  comments_xml? : String? = None,
  comments_extended_xml? : String? = None,
  footnotes_xml? : String? = None,
) -> Bytes raise {
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
  builder.add_part("word/document.xml", @utf8.encode(document_xml))
  let mut next_rel = 100
  match comments_xml {
    Some(xml) => {
      builder.add_override(
        "/word/comments.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
      )
      builder.add_relationship(
        "rId\{next_rel}",
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
        "comments.xml",
        source="word/document.xml",
      )
      next_rel += 1
      builder.add_part("word/comments.xml", @utf8.encode(xml))
    }
    None => ()
  }
  match comments_extended_xml {
    Some(xml) => {
      builder.add_override(
        "/word/commentsExtended.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.commentsExtended+xml",
      )
      builder.add_relationship(
        "rId\{next_rel}",
        "http://schemas.microsoft.com/office/2011/relationships/commentsExtended",
        "commentsExtended.xml",
        source="word/document.xml",
      )
      next_rel += 1
      builder.add_part("word/commentsExtended.xml", @utf8.encode(xml))
    }
    None => ()
  }
  match footnotes_xml {
    Some(xml) => {
      builder.add_override(
        "/word/footnotes.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml",
      )
      builder.add_relationship(
        "rId\{next_rel}",
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
        "footnotes.xml",
        source="word/document.xml",
      )
      builder.add_part("word/footnotes.xml", @utf8.encode(xml))
    }
    None => ()
  }
  builder.build()
}

///|
fn comment_summary(comment : CommentInfo) -> String {
  let anchors : Array[String] = []
  for anchor in comment.anchors() {
    let refs = anchor.references().join("+")
    anchors.push(
      "[\{anchor.start().unwrap_or("-")}..\{anchor.end().unwrap_or("-")} refs=\{refs}]",
    )
  }
  let done = match comment.done() {
    Some(true) => " done"
    Some(false) => " open"
    None => ""
  }
  let parent = match comment.parent_id() {
    Some(parent) => " reply_to=\{parent}"
    None => ""
  }
  "id=\{comment.id()} defined=\{comment.defined()} author=\{comment.author().unwrap_or("-")} date=\{comment.date().unwrap_or("-")} paras=\{comment.body_paragraphs()}\{done}\{parent} anchors=\{anchors.join(" ")}"
}

///|
test "index: ranges, points, threading, and coverage on a conformance-shaped fixture" {
  // Comment 0: a multi-paragraph range (start in p2, end in p3) with its
  // reference in p3; two body paragraphs, distinct first/last paraIds
  // (the CT_CommentEx last-paragraph rule is what threading keys on).
  // Comment 1: a point comment in p4. Comment 3: an anchorless reply to
  // comment 0, resolved (done). Footnote 2: referenced twice.
  let document =
    #|<?xml version="1.0"?>
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body>
    #|<w:p><w:r><w:t>plain</w:t></w:r></w:p>
    #|<w:p><w:commentRangeStart w:id="0"/><w:r><w:t>first half</w:t></w:r></w:p>
    #|<w:p><w:r><w:t>second half</w:t></w:r><w:commentRangeEnd w:id="0"/><w:r><w:commentReference w:id="0"/></w:r></w:p>
    #|<w:p><w:r><w:commentReference w:id="1"/></w:r><w:r><w:footnoteReference w:id="2"/></w:r><w:r><w:footnoteReference w:id="2"/></w:r></w:p>
    #|</w:body>
    #|</w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml">
    #|<w:comment w:id="0" w:author="Ada" w:initials="A" w:date="2026-07-11T01:00:00Z"><w:p w14:paraId="AAAA0001"><w:r><w:t>range note</w:t></w:r></w:p><w:p w14:paraId="AAAA0002"><w:r><w:t>more</w:t></w:r></w:p></w:comment>
    #|<w:comment w:id="1" w:author="Bob"><w:p w14:paraId="BBBB0001"><w:r><w:t>point note</w:t></w:r></w:p></w:comment>
    #|<w:comment w:id="3" w:author="Cid"><w:p w14:paraId="CCCC0001"><w:r><w:t>reply</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let extended =
    #|<w15:commentsEx xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml">
    #|<w15:commentEx w15:paraId="AAAA0002" w15:done="0"/>
    #|<w15:commentEx w15:paraId="CCCC0001" w15:paraIdParent="AAAA0002" w15:done="1"/>
    #|</w15:commentsEx>
  let footnotes =
    #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:footnote w:type="separator" w:id="-1"><w:p/></w:footnote>
    #|<w:footnote w:id="2"><w:p><w:r><w:t>the note</w:t></w:r></w:p></w:footnote>
    #|</w:footnotes>
  let bytes = fixture_docx(
    document,
    comments_xml=Some(comments),
    comments_extended_xml=Some(extended),
    footnotes_xml=Some(footnotes),
  )
  let annotated = read_docx_annotated(bytes)
  let index = annotated.annotations()
  debug_inspect(index.warnings(), content="[]")
  let summaries : Array[String] = []
  for comment in index.comments() {
    summaries.push(comment_summary(comment))
  }
  debug_inspect(
    summaries,
    content=(
      #|[
      #|  "id=0 defined=true author=Ada date=2026-07-11T01:00:00Z paras=2 open anchors=[/body/p[2]../body/p[3] refs=/body/p[3]/r[2]]",
      #|  "id=1 defined=true author=Bob date=- paras=1 anchors=[-..- refs=/body/p[4]/r[1]]",
      #|  "id=3 defined=true author=Cid date=- paras=1 done reply_to=0 anchors=",
      #|]
    ),
  )
  // Coverage: the range intersects p2, p3 (and their runs); the point
  // covers its paragraph p4; p1 is untouched.
  debug_inspect(index.covering_comment_ids("/body/p[1]"), content="[]")
  debug_inspect(
    index.covering_comment_ids("/body/p[2]"),
    content=(
      #|["0"]
    ),
  )
  debug_inspect(
    index.covering_comment_ids("/body/p[3]/r[1]"),
    content=(
      #|["0"]
    ),
  )
  debug_inspect(
    index.covering_comment_ids("/body/p[4]"),
    content=(
      #|["1"]
    ),
  )
  // Notes: both references to footnote 2, in document order.
  debug_inspect(index.footnotes().length(), content="1")
  debug_inspect(
    index.footnotes()[0].references(),
    content=(
      #|["/body/p[4]/r[2]", "/body/p[4]/r[3]"]
    ),
  )
  // The anchorless reply is NOT an orphan (plan-locked: replies live via
  // their parent thread) — no warnings above proves it.
}

///|
test "index negatives: dangling markers, inverted pairs, marker-only ids, orphan definitions" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body>
    #|<w:p><w:commentRangeEnd w:id="7"/><w:r><w:t>end before start</w:t></w:r><w:commentRangeStart w:id="7"/></w:p>
    #|<w:p><w:commentRangeStart w:id="9"/><w:r><w:t>never closed</w:t></w:r></w:p>
    #|</w:body>
    #|</w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:comment w:id="7" w:author="A"><w:p><w:r><w:t>x</w:t></w:r></w:p></w:comment>
    #|<w:comment w:id="42" w:author="Orphan"><w:p><w:r><w:t>no markers</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let bytes = fixture_docx(document, comments_xml=Some(comments))
  let annotated = read_docx_annotated(bytes)
  let index = annotated.annotations()
  debug_inspect(
    index.warnings(),
    content=(
      #|[
      #|  "annotation index: markers reference comment id '9' which has no definition",
      #|  "annotation index: dangling commentRangeEnd for id '7' in /body",
      #|  "annotation index: dangling commentRangeStart for id '7' in /body",
      #|  "annotation index: comment '42' has no anchors in any story (orphan definition; content still exposed)",
      #|  "annotation index: dangling commentRangeStart for id '9' in /body",
      #|]
    ),
  )
  let summaries : Array[String] = []
  for comment in index.comments() {
    summaries.push(comment_summary(comment))
  }
  debug_inspect(
    summaries,
    content=(
      #|[
      #|  "id=7 defined=true author=A date=- paras=1 anchors=[-../body/p[1] refs=] [/body/p[1]..- refs=]",
      #|  "id=42 defined=true author=Orphan date=- paras=1 anchors=",
      #|  "id=9 defined=false author=- date=- paras=0 anchors=[/body/p[2]..- refs=]",
      #|]
    ),
  )
}

///|
test "index negatives: duplicate definitions and duplicate commentEx records" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body><w:p><w:r><w:commentReference w:id="5"/></w:r></w:p></w:body>
    #|</w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml">
    #|<w:comment w:id="5" w:author="First"><w:p w14:paraId="DDDD0001"><w:r><w:t>a</w:t></w:r></w:p></w:comment>
    #|<w:comment w:id="5" w:author="Second"><w:p w14:paraId="DDDD0002"><w:r><w:t>b</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let extended =
    #|<w15:commentsEx xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml">
    #|<w15:commentEx w15:paraId="DDDD0001" w15:done="1"/>
    #|<w15:commentEx w15:paraId="DDDD0001" w15:done="0"/>
    #|</w15:commentsEx>
  let bytes = fixture_docx(
    document,
    comments_xml=Some(comments),
    comments_extended_xml=Some(extended),
  )
  let annotated = read_docx_annotated(bytes)
  let index = annotated.annotations()
  debug_inspect(
    index.warnings(),
    content=(
      #|[
      #|  "annotation index: duplicate commentsExtended record for paraId DDDD0001 ignored (first wins)",
      #|  "annotation index: duplicate comment definition id '5' (each is exposed; id addressing will be ambiguous)",
      #|]
    ),
  )
  // Both definitions exposed ordinally; anchors attach to the first;
  // the first-wins commentEx gives done=true to the FIRST definition.
  let summaries : Array[String] = []
  for comment in index.comments() {
    summaries.push(comment_summary(comment))
  }
  debug_inspect(
    summaries,
    content=(
      #|[
      #|  "id=5 defined=true author=First date=- paras=1 done anchors=[-..- refs=/body/p[1]/r[1]]",
      #|  "id=5 defined=true author=Second date=- paras=1 anchors=",
      #|]
    ),
  )
}
