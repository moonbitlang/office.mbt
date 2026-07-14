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
fn comment_summary(comment : @docx.CommentInfo) -> String {
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
fn expect_annotation_identity_failure(
  bytes : BytesView,
  expected : String,
) -> Unit raise {
  let annotated = @docx.read_docx_annotated(bytes)
  try @docx.validate_annotation_identity_state(annotated) catch {
    Unsupported(message~) =>
      if !message.contains(expected) {
        fail(
          "expected identity failure containing '\{expected}', received '\{message}'",
        )
      }
    _ => fail("expected an Unsupported identity failure")
  } noraise {
    _ => fail("expected structural annotation identity validation to fail")
  }
}

///|
test "archive-backed annotated reads match byte-backed reads" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body><w:p><w:r><w:t>shared archive</w:t></w:r></w:p></w:body>
    #|</w:document>
  let bytes = fixture_docx(document)
  let from_bytes = @docx.read_docx_annotated(bytes)
  let archive = try! @mbtzip.read(bytes)
  let from_archive = @docx.read_docx_annotated_archive(archive)
  assert_eq(from_archive.main_story_part(), from_bytes.main_story_part())
  assert_eq(
    from_archive.annotations().warnings(),
    from_bytes.annotations().warnings(),
  )
  assert_eq(
    from_archive.annotations().comments().length(),
    from_bytes.annotations().comments().length(),
  )
  let byte_span = from_bytes.body_paragraph_span("p[1]").unwrap()
  let archive_span = from_archive.body_paragraph_span("p[1]").unwrap()
  assert_eq(archive_span.byte_start(), byte_span.byte_start())
  assert_eq(archive_span.byte_end(), byte_span.byte_end())
  assert_eq(archive_span.content_start(), byte_span.content_start())
  assert_eq(archive_span.close_tag_start(), byte_span.close_tag_start())
}

///|
test "archive-backed annotated reads share one cumulative XML budget" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body><w:p><w:r><w:t>bounded archive</w:t></w:r></w:p></w:body>
    #|</w:document>
  let bytes = fixture_docx(document)
  let archive = try! @mbtzip.read(bytes)
  let budget = @xml.xml_read_budget(
    max_source_units=64 * 1024,
    max_tokens=4096,
    max_materialized_chars=32 * 1024,
    max_token_chars=8 * 1024,
  )
  let annotated = @docx.read_docx_annotated_archive_limited(archive, budget)
  assert_eq(annotated.main_story_part(), "word/document.xml")
  assert_true(annotated.body_paragraph_span("p[1]") is Some(_))
  let tiny = @xml.xml_read_budget(
    max_source_units=64 * 1024,
    max_tokens=1,
    max_materialized_chars=64 * 1024,
    max_token_chars=64 * 1024,
  )
  try @docx.read_docx_annotated_archive_limited(archive, tiny) catch {
    InvalidXml(message~) =>
      inspect(message, content="XML token budget exceeded")
    _ => fail("expected bounded XML read failure")
  } noraise {
    _ => fail("expected tiny XML budget to reject the archive")
  }
}

///|
test "Strict relocated main relationship outranks a conventional-path decoy" {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/custom/main.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_relationship(
    "rIdMain", "http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument",
    "custom/main.xml",
  )
  builder.add_part(
    "custom/main.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://purl.oclc.org/ooxml/wordprocessingml/main"><w:body><w:p><w:r><w:commentReference w:id="7"/></w:r></w:p></w:body></w:document>
      ),
    ),
  )
  builder.add_part(
    "word/document.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:commentReference w:id="99"/></w:r></w:p></w:body></w:document>
      ),
    ),
  )
  let annotated = @docx.read_docx_annotated(builder.build())
  assert_eq(annotated.main_story_part(), "custom/main.xml")
  let comments = annotated.annotations().comments()
  assert_eq(comments.length(), 1)
  assert_eq(comments[0].id(), "7")
}

///|
test "distinct comments relationship targets fail closed" {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/comments-a.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
  )
  builder.add_override(
    "/word/comments-b.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
  )
  builder.add_relationship(
    "rIdMain", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rIdCommentsA",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    "comments-a.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rIdCommentsB",
    "http://purl.oclc.org/ooxml/officeDocument/relationships/comments",
    "comments-b.xml",
    source="word/document.xml",
  )
  builder.add_part(
    "word/document.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
      ),
    ),
  )
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>
  builder.add_part("word/comments-a.xml", @utf8.encode(comments))
  builder.add_part("word/comments-b.xml", @utf8.encode(comments))
  let ambiguous = builder.build()
  try @docx.read_docx_annotated(ambiguous) catch {
    Unsupported(message~) =>
      inspect(
        message,
        content="the document declares multiple distinct comments relationship targets",
      )
    _ => fail("expected ambiguous comments relationship failure")
  } noraise {
    _ => fail("expected ambiguous comments relationships to fail")
  }
}

///|
test "distinct commentsExtended relationship targets fail closed" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let extended =
    #|<w15:commentsEx xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml"/>
  let archive = try! @mbtzip.read(
    fixture_docx(document, comments_extended_xml=Some(extended)),
  )
  guard archive.get("word/_rels/document.xml.rels") is Some(rels_bytes) else {
    fail("fixture is missing main relationships")
  }
  let rels = @utf8.decode(rels_bytes, ignore_bom=true).replace(
    old="</Relationships>",
    new=(
      #|<Relationship Id="rIdSecondExtended" Type="http://schemas.microsoft.com/office/2011/relationships/commentsExtended" Target="commentsExtended-2.xml"/></Relationships>
    ),
  )
  assert_true(
    archive.replace("word/_rels/document.xml.rels", @utf8.encode(rels)),
  )
  guard archive.get("[Content_Types].xml") is Some(types_bytes) else {
    fail("fixture is missing content types")
  }
  let types = @utf8.decode(types_bytes, ignore_bom=true).replace(
    old="</Types>",
    new=(
      #|<Override PartName="/word/commentsExtended-2.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.commentsExtended+xml"/></Types>
    ),
  )
  assert_true(archive.replace("[Content_Types].xml", @utf8.encode(types)))
  archive.add("word/commentsExtended-2.xml", @utf8.encode(extended))
  let ambiguous = try! @mbtzip.write(archive)
  try @docx.read_docx_annotated(ambiguous) catch {
    Unsupported(message~) =>
      inspect(
        message,
        content="the document declares multiple distinct commentsExtended relationship targets",
      )
    _ => fail("expected ambiguous commentsExtended relationship failure")
  } noraise {
    _ => fail("expected ambiguous commentsExtended relationships to fail")
  }
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
  let annotated = @docx.read_docx_annotated(bytes)
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
  let annotated = @docx.read_docx_annotated(bytes)
  let index = annotated.annotations()
  debug_inspect(
    index.warnings(),
    content=(
      #|[
      #|  "annotation index: markers reference comment id '9' which has no definition",
      #|  "annotation index: dangling commentRangeEnd for id '7' in /body",
      #|  "annotation index: dangling commentRangeStart for id '7' in /body",
      #|  "annotation index: dangling commentRangeStart for id '9' in /body",
      #|  "annotation index: comment '42' has no anchors in any story (orphan definition; content still exposed)",
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
  let annotated = @docx.read_docx_annotated(bytes)
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
  // Both definitions exposed ordinally, SHARING the id's anchors (round-1
  // review: assigning them to one ordinal arbitrarily was rejected); the
  // first-wins commentEx gives done=true to the FIRST definition.
  let summaries : Array[String] = []
  for comment in index.comments() {
    summaries.push(comment_summary(comment))
  }
  debug_inspect(
    summaries,
    content=(
      #|[
      #|  "id=5 defined=true author=First date=- paras=1 done anchors=[-..- refs=/body/p[1]/r[1]]",
      #|  "id=5 defined=true author=Second date=- paras=1 anchors=[-..- refs=/body/p[1]/r[1]]",
      #|]
    ),
  )
}

///|
test "identity validation canonicalizes comment ids and raw marker spellings" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body><w:p><w:r><w:commentReference w:id="0"/></w:r></w:p></w:body>
    #|</w:document>
  let aliased_definitions =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:comment w:id="0" w:author="First"><w:p/></w:comment>
    #|<w:comment w:id="00" w:author="Alias"><w:p/></w:comment>
    #|</w:comments>
  expect_annotation_identity_failure(
    fixture_docx(document, comments_xml=Some(aliased_definitions)),
    "multiple comment definitions for numeric id 0",
  )
  let marker_alias_document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body><w:p><w:r><w:commentReference w:id="00"/></w:r></w:p></w:body>
    #|</w:document>
  let canonical_definition =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:comment w:id="0" w:author="First"><w:p/></w:comment>
    #|</w:comments>
  expect_annotation_identity_failure(
    fixture_docx(marker_alias_document, comments_xml=Some(canonical_definition)),
    "multiple lexical spellings for numeric comment id 0",
  )
}

///|
test "identity validation structurally checks paraId and commentEx keys" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body><w:p/></w:body>
    #|</w:document>
  let duplicate_last_para =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml">
    #|<w:comment w:id="0"><w:p w14:paraId="abcd0001"/></w:comment>
    #|<w:comment w:id="1"><w:p w14:paraId="ABCD0001"/></w:comment>
    #|</w:comments>
  expect_annotation_identity_failure(
    fixture_docx(document, comments_xml=Some(duplicate_last_para)),
    "multiple comments with last-paragraph paraId ABCD0001",
  )
  let stamped_comment =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml">
    #|<w:comment w:id="0"><w:p w14:paraId="ABCD0001"/></w:comment>
    #|</w:comments>
  let missing_comment_ex_key =
    #|<w15:commentsEx xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml">
    #|<w15:commentEx w15:done="1"/>
    #|</w15:commentsEx>
  expect_annotation_identity_failure(
    fixture_docx(
      document,
      comments_xml=Some(stamped_comment),
      comments_extended_xml=Some(missing_comment_ex_key),
    ),
    "commentsExtended record without w15:paraId",
  )
  let unknown_parent =
    #|<w15:commentsEx xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml">
    #|<w15:commentEx w15:paraId="ABCD0001" w15:paraIdParent="FFFF0001"/>
    #|</w15:commentsEx>
  expect_annotation_identity_failure(
    fixture_docx(
      document,
      comments_xml=Some(stamped_comment),
      comments_extended_xml=Some(unknown_parent),
    ),
    "unknown or self-referential parent paraId",
  )
}

///|
test "annotation diagnostics are capped while distinct marker ids remain indexed" {
  let document = StringBuilder()
  document.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p>",
  )
  for id in 0..<600 {
    document.write_string("<w:commentReference w:id=\"\{id}\"/>")
  }
  document.write_string("</w:p></w:body></w:document>")
  let annotated = @docx.read_docx_annotated(fixture_docx(document.to_string()))
  assert_eq(annotated.annotations().comments().length(), 600)
  let warnings = annotated.annotations().warnings()
  assert_eq(warnings.length(), 256)
  assert_eq(
    warnings[255],
    "annotation index: additional diagnostics were omitted",
  )
  for warning in warnings {
    assert_true(warning.length() <= 512)
  }
}

///|
test "dense comment ranges and references retain FIFO attachment order" {
  let document = StringBuilder()
  document.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p>",
  )
  for _ in 0..<2_000 {
    document.write_string(
      "<w:commentRangeStart w:id=\"0\"/><w:commentRangeEnd w:id=\"0\"/><w:commentReference w:id=\"0\"/>",
    )
  }
  document.write_string("</w:p></w:body></w:document>")
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:comment w:id="0"><w:p/></w:comment>
    #|</w:comments>
  let annotated = @docx.read_docx_annotated(
    fixture_docx(document.to_string(), comments_xml=Some(comments)),
  )
  let indexed = annotated.annotations().comments()
  assert_eq(indexed.length(), 1)
  let anchors = indexed[0].anchors()
  assert_eq(anchors.length(), 2_000)
  assert_eq(anchors[0].references().length(), 1)
  assert_eq(anchors[1_999].references().length(), 1)
  assert_eq(annotated.annotations().warnings().length(), 0)
}

///|
test "distributed comment markers verify against thousands of paragraphs linearly" {
  let document = StringBuilder()
  document.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>",
  )
  for _ in 0..<3_000 {
    document.write_string(
      "<w:p><w:r><w:commentReference w:id=\"0\"/></w:r></w:p>",
    )
  }
  document.write_string("</w:body></w:document>")
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="0"><w:p/></w:comment></w:comments>
  let annotated = @docx.read_docx_annotated(
    fixture_docx(document.to_string(), comments_xml=Some(comments)),
  )
  let indexed = annotated.annotations().comments()
  assert_eq(indexed.length(), 1)
  let anchors = indexed[0].anchors()
  assert_eq(anchors.length(), 3_000)
  assert_eq(anchors[0].references(), ["/body/p[1]/r[1]"])
  assert_eq(anchors[2_999].references(), ["/body/p[3000]/r[1]"])
  assert_eq(annotated.annotations().warnings(), [])
}

///|
test "story-level marker fallbacks use a monotonic nearest-node index" {
  let document = StringBuilder()
  document.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>",
  )
  for _ in 0..<2_000 {
    document.write_string("<w:commentReference w:id=\"0\"/><w:p/>")
  }
  document.write_string("</w:body></w:document>")
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="0"><w:p/></w:comment></w:comments>
  let annotated = @docx.read_docx_annotated(
    fixture_docx(document.to_string(), comments_xml=Some(comments)),
  )
  let anchors = annotated.annotations().comments()[0].anchors()
  assert_eq(anchors.length(), 2_000)
  assert_eq(anchors[0].references(), ["/body/p[1]"])
  assert_eq(anchors[1_999].references(), ["/body/p[2000]"])
  assert_eq(annotated.annotations().warnings(), [])
}

///|
test "index review round 1: multi-range FIFO, later-range interiors, cross-story rank" {
  // One id with TWO ranges in the body plus a range in a comment body
  // (cross-story, /comments ranks last). The reference between range 1's
  // end and range 2's start attaches to range 1 (nearest preceding end);
  // the reference INSIDE range 2 attaches to range 2 by containment.
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body>
    #|<w:p><w:commentRangeStart w:id="4"/><w:r><w:t>one</w:t></w:r><w:commentRangeEnd w:id="4"/><w:r><w:commentReference w:id="4"/></w:r></w:p>
    #|<w:p><w:commentRangeStart w:id="4"/><w:r><w:commentReference w:id="4"/></w:r><w:r><w:t>two</w:t></w:r><w:commentRangeEnd w:id="4"/></w:p>
    #|</w:body>
    #|</w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:comment w:id="4" w:author="A"><w:p><w:commentRangeStart w:id="8"/><w:r><w:t>nested marker</w:t></w:r><w:commentRangeEnd w:id="8"/><w:p/></w:p></w:comment>
    #|<w:comment w:id="8" w:author="B"><w:p><w:r><w:t>anchored in a comment</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let bytes = fixture_docx(document, comments_xml=Some(comments))
  let annotated = @docx.read_docx_annotated(bytes)
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
      #|  "id=4 defined=true author=A date=- paras=2 anchors=[/body/p[1]../body/p[1] refs=/body/p[1]/r[2]] [/body/p[2]../body/p[2] refs=/body/p[2]/r[1]]",
      #|  "id=8 defined=true author=B date=- paras=1 anchors=[/comments/comment[1]/p[1]../comments/comment[1]/p[1] refs=]",
      #|]
    ),
  )
  // Boundary exposure: range 1 starts at the head of p[1] and ends after
  // its last closed child.
  let first_anchor = index.comments()[0].anchors()[0]
  debug_inspect(
    "\{first_anchor.start_boundary().unwrap()}/\{first_anchor.end_boundary().unwrap()}",
    content=(
      #|"inside_start/inside_end"
    ),
  )
  // Cross-story coverage: the comment-body range covers its paragraph.
  debug_inspect(
    index.covering_comment_ids("/comments/comment[1]/p[1]"),
    content=(
      #|["8"]
    ),
  )
}

///|
test "index review round 1: AlternateContent Fallback content maps into the parent flow" {
  // The reader splices mc:Fallback children (dropping mc:Choice); the
  // scanner mirrors that, so the marker paragraph is /body/p[2] — a
  // VERIFIED path, not a phantom nested p[1]. Round-2 review caught the
  // earlier version of this fixture resolving to the WRONG existing node.
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">
    #|<w:body>
    #|<w:p><w:r><w:t>real first</w:t></w:r></w:p>
    #|<mc:AlternateContent><mc:Choice Requires="wps"><w:p><w:r><w:commentReference w:id="9"/></w:r></w:p></mc:Choice><mc:Fallback><w:p><w:r><w:commentReference w:id="0"/></w:r></w:p></mc:Fallback></mc:AlternateContent>
    #|</w:body>
    #|</w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:comment w:id="0" w:author="A"><w:p><w:r><w:t>x</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let bytes = fixture_docx(document, comments_xml=Some(comments))
  let annotated = @docx.read_docx_annotated(bytes)
  let index = annotated.annotations()
  // No degradation, no dangling-id warning for the Choice-branch marker
  // (id 9 lives in a dropped branch and must not surface at all).
  debug_inspect(index.warnings(), content="[]")
  debug_inspect(index.comments().length(), content="1")
  debug_inspect(
    index.comments()[0].anchors()[0].references(),
    content=(
      #|["/body/p[2]/r[1]"]
    ),
  )
}

///|
test "index review round 1: genuinely unverifiable positions degrade with a diagnostic" {
  // v:textbox content is spliced by the reader (VML shapes recurse) but
  // the scanner does not model VML — a marker inside it computes a path
  // the AST does not have, and verification must degrade it rather than
  // expose a phantom.
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml">
    #|<w:body>
    #|<w:p><w:r><w:t>real first</w:t></w:r></w:p>
    #|<w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:commentReference w:id="0"/></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p>
    #|</w:body>
    #|</w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:comment w:id="0" w:author="A"><w:p><w:r><w:t>x</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let bytes = fixture_docx(document, comments_xml=Some(comments))
  let annotated = @docx.read_docx_annotated(bytes)
  let index = annotated.annotations()
  let mut saw_degradation = false
  for warning in index.warnings() {
    if warning.has_prefix("annotation index: position '") {
      saw_degradation = true
    }
  }
  debug_inspect(saw_degradation, content="true")
}

///|
test "index review round 1: orphan detection is duplicate-order independent" {
  // First definition of id 6 is an anchorless REPLY (normally silent);
  // the SECOND definition of the same id is a plain orphan. The post-
  // pass must still warn (round-2 review: the early-continue version
  // masked this ordering).
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body><w:p><w:r><w:t>plain</w:t></w:r></w:p></w:body>
    #|</w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml">
    #|<w:comment w:id="0" w:author="Root"><w:p w14:paraId="2AAA0001"><w:r><w:t>root</w:t></w:r></w:p></w:comment>
    #|<w:comment w:id="6" w:author="ReplyFirst"><w:p w14:paraId="2BBB0001"><w:r><w:t>r</w:t></w:r></w:p></w:comment>
    #|<w:comment w:id="6" w:author="OrphanSecond"><w:p w14:paraId="2CCC0001"><w:r><w:t>o</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let extended =
    #|<w15:commentsEx xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml">
    #|<w15:commentEx w15:paraId="2BBB0001" w15:paraIdParent="2AAA0001" w15:done="0"/>
    #|</w15:commentsEx>
  let bytes = fixture_docx(
    document,
    comments_xml=Some(comments),
    comments_extended_xml=Some(extended),
  )
  let annotated = @docx.read_docx_annotated(bytes)
  let index = annotated.annotations()
  let mut saw_orphan_6 = false
  for warning in index.warnings() {
    if warning ==
      "annotation index: comment '6' has no anchors in any story (orphan definition; content still exposed)" {
      saw_orphan_6 = true
    }
  }
  debug_inspect(saw_orphan_6, content="true")
}

///|
test "index review round 3: drawings are opaque — run positions verified, image coverage empty" {
  // J1 deliberately does not project image nodes (the reader's blip
  // resolution and hlinkClick wrapping need the relationship graph — L0
  // scope). A marker in a run that also holds a drawing resolves to the
  // RUN (a verified AST path); coverage queries for image paths return
  // empty rather than lying.
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
    #|<w:body>
    #|<w:p><w:commentRangeStart w:id="0"/><w:r><w:drawing><wp:inline><wp:extent cx="9525" cy="9525"/></wp:inline></w:drawing><w:commentReference w:id="0"/></w:r><w:commentRangeEnd w:id="0"/></w:p>
    #|</w:body>
    #|</w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:comment w:id="0" w:author="A"><w:p><w:r><w:t>on the picture</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let bytes = fixture_docx(document, comments_xml=Some(comments))
  let annotated = @docx.read_docx_annotated(bytes)
  let index = annotated.annotations()
  debug_inspect(index.warnings(), content="[]")
  debug_inspect(
    index.comments()[0].anchors()[0].references(),
    content=(
      #|["/body/p[1]/r[1]"]
    ),
  )
  debug_inspect(
    index.covering_comment_ids("/body/p[1]/r[1]/image[1]"),
    content="[]",
  )
  debug_inspect(
    index.covering_comment_ids("/body/p[1]"),
    content=(
      #|["0"]
    ),
  )
}

///|
test "J2 review round 1: cross-story coverage keys and unrepresentable ids warn" {
  // A range anchored INSIDE a comment body covers that body paragraph
  // (cross-story coverage), and an id spelled with '/' cannot take the
  // [@id=...] form — the ordinal-fallback diagnostic is emitted.
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body><w:p><w:r><w:commentReference w:id="a/b"/></w:r></w:p></w:body>
    #|</w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:comment w:id="a/b" w:author="Odd"><w:p><w:r><w:t>slash id</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let bytes = fixture_docx(document, comments_xml=Some(comments))
  let annotated = @docx.read_docx_annotated(bytes)
  let index = annotated.annotations()
  let mut saw_fallback = false
  for warning in index.warnings() {
    if warning ==
      "annotation index: comment id 'a/b' cannot be addressed as [@id=...]; ordinal paths are emitted for it" {
      saw_fallback = true
    }
  }
  debug_inspect(saw_fallback, content="true")
  // The point anchor still covers the body paragraph.
  debug_inspect(
    index.covering_comment_ids("/body/p[1]"),
    content=(
      #|["a/b"]
    ),
  )
}
