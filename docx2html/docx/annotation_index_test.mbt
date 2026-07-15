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
test "DOCX reader keeps logical Unicode identity separate from ZIP spelling" {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/é.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/é.xml",
  )
  builder.add_relationship(
    "rStyles",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
    "ßtyles.xml",
    source="word/é.xml",
  )
  builder.add_override(
    "/word/ßtyles.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml",
  )
  builder.add_part(
    "word/é.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Unicode main part</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
      ),
    ),
  )
  builder.add_part(
    "word/ßtyles.xml",
    @utf8.encode(
      (
        #|<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>
      ),
    ),
  )
  let bytes = builder.build()
  let archive = @mbtzip.read(bytes)
  assert_true(archive.get("word/%C3%A9.xml") is Some(_))
  assert_true(archive.get("word/_rels/%C3%A9.xml.rels") is Some(_))
  assert_true(archive.get("word/%C3%9Ftyles.xml") is Some(_))
  let annotated = @docx.read_docx_annotated_archive(archive)
  assert_eq(annotated.main_story_part(), "word/%C3%A9.xml")
}

///|
fn diagnostic_hash_clustered_element_names(
  count : Int,
  bucket_mask : Int,
) -> Array[String] {
  let names : Array[String] = []
  let mut candidate = 0
  while names.length() < count {
    let name = "n\{candidate}"
    if (name.hash() & bucket_mask) == 0 {
      names.push(name)
    }
    candidate += 1
  }
  names
}

///|
test "real DOCX diagnostics ignore deterministic string-hash clustering" {
  let names = diagnostic_hash_clustered_element_names(256, 0x3FF)
  let document = StringBuilder()
  document.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>",
  )
  for name in names {
    assert_eq(name.hash() & 0x3FF, 0)
    document.write_string("<")
    document.write_string(name)
    document.write_string("/>")
  }
  document.write_string("<w:p/></w:body></w:document>")
  let annotated = @docx.read_docx_annotated(fixture_docx(document.to_string()))
  let messages = annotated.result().messages
  assert_eq(messages.length(), names.length())
  for index, name in names {
    assert_eq(
      messages[index],
      @core.warning("An unrecognised element was ignored: " + name),
    )
  }
}

///|
test "bounded annotated reads cap diagnostics before retention" {
  let document = StringBuilder()
  document.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>",
  )
  for index in 0..<16 {
    document.write_string("<n\{index}\{"x".repeat(100)}/>")
  }
  document.write_string("<w:p/></w:body></w:document>")
  let archive = try! @mbtzip.read(fixture_docx(document.to_string()))
  let budget = @xml.xml_read_budget(
    max_source_units=1024 * 1024,
    max_tokens=4096,
    max_materialized_chars=1024 * 1024,
    max_token_chars=4096,
  )
  let annotated = @docx.read_docx_annotated_archive_limited(
    archive,
    budget,
    max_diagnostics=4,
    max_diagnostic_chars=64,
  )
  let messages = annotated.result().messages
  assert_eq(messages.length(), 4)
  for index in 0..<3 {
    guard messages[index] is Warning(text) else {
      fail("expected bounded warning")
    }
    assert_true(text.length() <= 66)
    assert_true(text.has_suffix("…"))
  }
  assert_eq(
    messages[3],
    @core.warning("additional DOCX diagnostics were omitted"),
  )
}

///|
test "bounded annotated reads also cap their truncation notice" {
  let document = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><unknown/><w:p/></w:body></w:document>"
  let archive = try! @mbtzip.read(fixture_docx(document))
  let budget = @xml.xml_read_budget(
    max_source_units=1024 * 1024,
    max_tokens=4096,
    max_materialized_chars=1024 * 1024,
    max_token_chars=4096,
  )
  let annotated = @docx.read_docx_annotated_archive_limited(
    archive,
    budget,
    max_diagnostics=1,
    max_diagnostic_chars=1,
  )
  assert_eq(annotated.result().messages, [@core.warning("…")])
}

///|
test "bounded annotated reads cap annotation diagnostics during production" {
  let document = StringBuilder()
  document.write_string(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p>",
  )
  for index in 0..<16 {
    document.write_string(
      "<w:r><w:commentReference w:id=\"missing-\{index}\"/></w:r>",
    )
  }
  document.write_string("</w:p></w:body></w:document>")
  let archive = try! @mbtzip.read(fixture_docx(document.to_string()))
  let budget = @xml.xml_read_budget(
    max_source_units=1024 * 1024,
    max_tokens=4096,
    max_materialized_chars=1024 * 1024,
    max_token_chars=4096,
  )
  let annotated = @docx.read_docx_annotated_archive_limited(
    archive,
    budget,
    max_diagnostics=4,
    max_diagnostic_chars=64,
  )
  assert_eq(annotated.annotations().warnings().length(), 4)
  assert_eq(
    annotated.annotations().warnings()[3],
    "annotation index: additional diagnostics were omitted",
  )
  assert_eq(annotated.result().messages.length(), 4)
  assert_eq(
    annotated.result().messages[3],
    @core.warning("additional DOCX diagnostics were omitted"),
  )
}

///|
fn unreferenced_story_fixture(
  relationship_type : String,
  target : String,
  part_path : String,
  content_type : String,
  story_xml : String,
) -> Bytes raise {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override("/" + part_path, content_type)
  builder.add_relationship(
    "rIdMain", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rIdHidden",
    relationship_type,
    target,
    source="word/document.xml",
  )
  builder.add_part(
    "word/document.xml",
    @utf8.encode(
      "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p/></w:body></w:document>",
    ),
  )
  builder.add_part(part_path, @utf8.encode(story_xml))
  builder.build()
}

///|
fn referenced_header_fixture(
  content_type : String,
  header_xml : String,
) -> Bytes raise {
  let source = unreferenced_story_fixture(
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
    "header1.xml", "word/header1.xml", content_type, header_xml,
  )
  let archive = try! @mbtzip.read(source)
  assert_true(
    archive.replace(
      "word/document.xml",
      @utf8.encode(
        (
          #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          #|<w:body><w:p/><w:sectPr><w:headerReference w:type="default" r:id="rIdHidden"/></w:sectPr></w:body>
          #|</w:document>
        ),
      ),
    ),
  )
  try! @mbtzip.write(archive)
}

///|
fn with_main_relationship(
  bytes : BytesView,
  id : String,
  relationship_type : String,
  target : String,
  external? : Bool = false,
) -> Bytes raise {
  let archive = try! @mbtzip.read(bytes)
  let rels = match archive.get("word/_rels/document.xml.rels") {
    Some(rels_bytes) => @utf8.decode(rels_bytes, ignore_bom=true)
    None =>
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"></Relationships>"
  }
  let target_mode = if external { " TargetMode=\"External\"" } else { "" }
  let relationship = "<Relationship Id=\"\{id}\" Type=\"\{relationship_type}\" Target=\"\{target}\"\{target_mode}/>"
  let updated = rels.replace(
    old="</Relationships>",
    new=relationship + "</Relationships>",
  )
  if archive.get("word/_rels/document.xml.rels") is Some(_) {
    assert_true(
      archive.replace("word/_rels/document.xml.rels", @utf8.encode(updated)),
    )
  } else {
    archive.add("word/_rels/document.xml.rels", @utf8.encode(updated))
  }
  try! @mbtzip.write(archive)
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
    ResourceLimit(limit~, message~) => {
      debug_inspect(limit, content="DocxXmlTokens")
      inspect(message, content="XML token budget exceeded")
    }
    _ => fail("expected bounded XML read failure")
  } noraise {
    _ => fail("expected tiny XML budget to reject the archive")
  }
}

///|
test "global paraId validation preserves XML resource failures" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let bytes = fixture_docx(document)
  let archive = try! @mbtzip.read(bytes)
  let annotated = @docx.read_docx_annotated(bytes)
  guard archive.get("word/document.xml") is Some(main)
  let budget = @xml.xml_read_budget(
    max_source_units=main.length() - 1,
    max_tokens=4096,
    max_materialized_chars=64 * 1024,
    max_token_chars=64 * 1024,
  )
  try
    @docx.validate_global_para_id_state_archive_limited(
      annotated, archive, budget,
    )
  catch {
    ResourceLimit(limit~, message~) => {
      debug_inspect(limit, content="DocxXmlSourceUnits")
      inspect(message, content="XML source budget exceeded")
    }
    error => fail("expected typed XML resource failure, got \{repr(error)}")
  } noraise {
    _ => fail("expected the main-story reread to exhaust its source budget")
  }
}

///|
test "limited annotated reads are pinned to the validated main part" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let archive = try! @mbtzip.read(fixture_docx(document))
  let budget = @xml.xml_read_budget(
    max_source_units=64 * 1024,
    max_tokens=4096,
    max_materialized_chars=32 * 1024,
    max_token_chars=8 * 1024,
  )
  try
    @docx.read_docx_annotated_archive_limited(
      archive,
      budget,
      expected_main_document_path="custom/unvalidated.xml",
    )
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("different main document part"))
    _ => fail("expected a validated main-part identity mismatch")
  } noraise {
    _ => fail("expected a validated main-part identity mismatch")
  }
}

///|
test "annotated story sources distinguish relationships from legacy fallback" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let bytes = fixture_docx(document)
  let related = @docx.read_docx_annotated(bytes)
  assert_eq(related.main_story_source().part(), "word/document.xml")
  assert_eq(related.main_story_source().authority().name(), "relationship")
  let archive = try! @mbtzip.read(bytes)
  assert_true(
    archive.replace(
      "_rels/.rels",
      @utf8.encode(
        (
          #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
        ),
      ),
    ),
  )
  let fallback = @docx.read_docx_annotated_archive(archive)
  assert_eq(fallback.main_story_source().part(), "word/document.xml")
  assert_eq(fallback.main_story_source().authority().name(), "legacy-fallback")
}

///|
test "unreferenced Transitional headers participate in identity validation only" {
  let bytes = unreferenced_story_fixture(
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
    "stories/../header-hidden.xml", "word/header-hidden.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml",
    "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:commentReference w:id=\"41\"/></w:r></w:p></w:hdr>",
  )
  let annotated = @docx.read_docx_annotated(bytes)
  // No section references this relationship, so it must not gain an invented
  // /header[n] path or a public marker-only comment.
  assert_eq(annotated.result().headers.length(), 0)
  assert_eq(annotated.annotations().comments().length(), 0)
  try @docx.validate_annotation_identity_state(annotated) catch {
    Unsupported(message~) =>
      assert_true(
        message.contains("marker for comment id 41 without a definition"),
      )
    _ => fail("expected the hidden header marker to fail identity validation")
  } noraise {
    _ => fail("expected the hidden header marker to fail identity validation")
  }
}

///|
test "unreferenced footers participate in identity validation only" {
  let bytes = unreferenced_story_fixture(
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer",
    "../stories/footer-hidden.xml", "stories/footer-hidden.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml",
    "<w:ftr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:commentReference w:id=\"42\"/></w:r></w:p></w:ftr>",
  )
  let annotated = @docx.read_docx_annotated(bytes)
  assert_eq(annotated.result().footers.length(), 0)
  assert_eq(annotated.annotations().comments().length(), 0)
  try @docx.validate_annotation_identity_state(annotated) catch {
    Unsupported(message~) =>
      assert_true(
        message.contains("marker for comment id 42 without a definition"),
      )
    _ => fail("expected the hidden footer marker to fail identity validation")
  } noraise {
    _ => fail("expected the hidden footer marker to fail identity validation")
  }
}

///|
test "section story references require matching typed internal relationships" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    #|<w:body><w:p/><w:sectPr><w:headerReference w:type="default" r:id="rStory"/></w:sectPr></w:body>
    #|</w:document>
  let wrong_kind = with_main_relationship(
    fixture_docx(document),
    "rStory",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer",
    "document.xml",
  )
  try @docx.read_docx_annotated(wrong_kind) catch {
    Unsupported(message~) =>
      assert_true(message.contains("is not a header relationship"))
    _ => fail("expected a wrong-kind section relationship to fail")
  } noraise {
    _ => fail("expected a wrong-kind section relationship to fail")
  }
  let external = with_main_relationship(
    fixture_docx(document),
    "rStory",
    "http://purl.oclc.org/ooxml/officeDocument/relationships/header",
    "https://example.invalid/header.xml",
    external=true,
  )
  try @docx.read_docx_annotated(external) catch {
    Unsupported(message~) => assert_true(message.contains("must be internal"))
    _ => fail("expected an external section relationship to fail")
  } noraise {
    _ => fail("expected an external section relationship to fail")
  }
  let duplicate = with_main_relationship(
    with_main_relationship(
      fixture_docx(document),
      "rStory",
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
      "document.xml",
    ),
    "rStory",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
    "document.xml",
  )
  try @docx.read_docx_annotated(duplicate) catch {
    Unsupported(message~) =>
      assert_true(message.contains("duplicate relationship id 'rStory'"))
    _ => fail("expected a duplicate section relationship id to fail")
  } noraise {
    _ => fail("expected a duplicate section relationship id to fail")
  }
}

///|
test "tolerant annotated reads warn on broken section references while mutation reads fail" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body><w:p/><w:sectPr><w:headerReference w:type="default"/></w:sectPr></w:body>
    #|</w:document>
  let archive = try! @mbtzip.read(fixture_docx(document))
  fn budget() -> @xml.XmlReadBudget {
    @xml.xml_read_budget(
      max_source_units=1024 * 1024,
      max_tokens=4096,
      max_materialized_chars=1024 * 1024,
      max_token_chars=4096,
    )
  }
  let tolerant = @docx.read_docx_annotated_archive_tolerant_limited(
    archive,
    budget(),
  )
  assert_eq(tolerant.result().headers.length(), 0)
  assert_true(
    tolerant.result().messages.any(message => {
      message ==
      @core.warning("A header/footer reference without r:id was ignored")
    }),
  )
  let read_only_spec = @docx.comment_spec(author="read-only", from=0, to=0, [
    @document.paragraph([@document.run([@document.text("blocked")])]),
  ])
  try
    @docx.plan_comment_addition_archive(
      tolerant,
      archive,
      at_relative="p[1]",
      to_relative="p[1]",
      read_only_spec,
    )
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("tolerant DOCX projection is read-only"))
    _ => fail("expected tolerant mutation provenance to be rejected")
  } noraise {
    _ => fail("expected a tolerant projection to reject mutation planning")
  }
  try @docx.read_docx_annotated_archive_limited(archive, budget()) catch {
    Unsupported(message~) => assert_true(message.contains("has no r:id"))
    _ => fail("expected mutation-safe read to reject the missing r:id")
  } noraise {
    _ => fail("expected mutation-safe read to fail closed")
  }

  let external_document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    #|<w:body><w:p/><w:sectPr><w:headerReference w:type="default" r:id="rStory"/></w:sectPr></w:body>
    #|</w:document>
  let external_bytes = with_main_relationship(
    fixture_docx(external_document),
    "rStory",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
    "https://example.invalid/header.xml",
    external=true,
  )
  let external_archive = try! @mbtzip.read(external_bytes)
  let external_tolerant = @docx.read_docx_annotated_archive_tolerant_limited(
    external_archive,
    budget(),
  )
  assert_eq(external_tolerant.result().headers.length(), 0)
  assert_true(
    external_tolerant.result().messages.any(message => {
      message ==
      @core.warning(
        "A header reference through invalid relationship rStory was ignored",
      )
    }),
  )
  try
    @docx.read_docx_annotated_archive_limited(external_archive, budget())
  catch {
    Unsupported(message~) => assert_true(message.contains("must be internal"))
    _ => fail("expected mutation-safe read to reject the external header")
  } noraise {
    _ => fail("expected mutation-safe read to fail closed")
  }

  fn assert_tolerant_header_omission(source : Bytes) -> Unit raise {
    let archive = try! @mbtzip.read(source)
    let tolerant = @docx.read_docx_annotated_archive_tolerant_limited(
      archive,
      budget(),
    )
    assert_eq(tolerant.result().headers.length(), 0)
    assert_eq(tolerant.header_story_sources().length(), 0)
    assert_eq(tolerant.result().sections[0].headers.length(), 0)
    assert_true(
      tolerant.result().messages.any(message => {
        message ==
        @core.warning(
          "A header part could not be read and was ignored: word/header1.xml",
        )
      }),
    )
  }

  let wrong_content_type = referenced_header_fixture(
    "application/xml", "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
  )
  assert_tolerant_header_omission(wrong_content_type)
  let wrong_content_archive = try! @mbtzip.read(wrong_content_type)
  try
    @docx.read_docx_annotated_archive_limited(wrong_content_archive, budget())
  catch {
    Unsupported(message~) =>
      assert_true(message.contains("has content type 'application/xml'"))
    _ => fail("expected mutation-safe read to reject the header content type")
  } noraise {
    _ => fail("expected mutation-safe read to fail on the header content type")
  }

  let wrong_root = referenced_header_fixture(
    "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml",
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
  )
  assert_tolerant_header_omission(wrong_root)
  let wrong_root_archive = try! @mbtzip.read(wrong_root)
  try
    @docx.read_docx_annotated_archive_limited(wrong_root_archive, budget())
  catch {
    InvalidXml(message~) =>
      assert_true(message.contains("must have a WordprocessingML 'hdr' root"))
    _ => fail("expected mutation-safe read to reject the header root")
  } noraise {
    _ => fail("expected mutation-safe read to fail on the header root")
  }
}

///|
test "tolerant D2 ids distinguish missing attributes from literal undefined" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment><w:p/></w:comment><w:comment w:id="undefined"><w:p/></w:comment></w:comments>
  let footnotes =
    #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:footnote><w:p/></w:footnote><w:footnote w:id="undefined"><w:p/></w:footnote></w:footnotes>
  let bytes = fixture_docx(
    document,
    comments_xml=Some(comments),
    footnotes_xml=Some(footnotes),
  )
  let legacy = @docx.read_docx_annotated(bytes)
  assert_eq(legacy.comment_bodies().map(pair => pair.0), [
    "undefined", "undefined",
  ])
  assert_eq(legacy.footnote_bodies().map(pair => pair.0), [
    "undefined", "undefined",
  ])
  let archive = try! @mbtzip.read(bytes)
  let budget = @xml.xml_read_budget(
    max_source_units=1024 * 1024,
    max_tokens=4096,
    max_materialized_chars=1024 * 1024,
    max_token_chars=4096,
  )
  let tolerant = @docx.read_docx_annotated_archive_tolerant_limited(
    archive, budget,
  )
  assert_eq(tolerant.comment_bodies().map(pair => pair.0), ["", "undefined"])
  assert_eq(tolerant.footnote_bodies().map(pair => pair.0), ["", "undefined"])
}

///|
test "tolerant D2 ids reject a present empty value instead of aliasing absence" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id=""><w:p/></w:comment></w:comments>
  let archive = try! @mbtzip.read(
    fixture_docx(document, comments_xml=Some(comments)),
  )
  let budget = @xml.xml_read_budget(
    max_source_units=1024 * 1024,
    max_tokens=4096,
    max_materialized_chars=1024 * 1024,
    max_token_chars=4096,
  )
  try
    @docx.read_docx_annotated_archive_tolerant_limited(archive, budget)
  catch {
    InvalidXml(message~) => assert_true(message.contains("present but empty"))
    _ => fail("expected a present empty annotation id to be rejected")
  } noraise {
    _ => fail("expected a present empty annotation id to be rejected")
  }
}

///|
test "tolerant range markers distinguish missing ids from present empty ids" {
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment><w:p/></w:comment></w:comments>
  let missing_document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:commentRangeStart/><w:r><w:t>text</w:t></w:r><w:commentRangeEnd/></w:p></w:body></w:document>
  let missing_archive = try! @mbtzip.read(
    fixture_docx(missing_document, comments_xml=Some(comments)),
  )
  let missing_budget = @xml.xml_read_budget(
    max_source_units=1024 * 1024,
    max_tokens=4096,
    max_materialized_chars=1024 * 1024,
    max_token_chars=4096,
  )
  let missing = @docx.read_docx_annotated_archive_tolerant_limited(
    missing_archive, missing_budget,
  )
  assert_eq(missing.annotations().comments()[0].id(), "")
  assert_eq(missing.annotations().comments()[0].anchors().length(), 1)
  let documents = [
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:commentRangeStart w:id=""/><w:r><w:t>text</w:t></w:r><w:commentRangeEnd/></w:p></w:body></w:document>
    ),
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:commentRangeStart/><w:r><w:t>text</w:t></w:r><w:commentRangeEnd w:id=""/></w:p></w:body></w:document>
    ),
  ]
  for document in documents {
    let archive = try! @mbtzip.read(
      fixture_docx(document, comments_xml=Some(comments)),
    )
    let budget = @xml.xml_read_budget(
      max_source_units=1024 * 1024,
      max_tokens=4096,
      max_materialized_chars=1024 * 1024,
      max_token_chars=4096,
    )
    try
      @docx.read_docx_annotated_archive_tolerant_limited(archive, budget)
    catch {
      InvalidXml(message~) => assert_true(message.contains("present but empty"))
      _ => fail("expected a present empty range-marker id to be rejected")
    } noraise {
      _ => fail("expected a present empty range-marker id to be rejected")
    }
  }
}

///|
test "mutation-safe reads strictly parse visible story XML before deriving spans" {
  let malformed =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p></w:tbl></w:body></w:document>
  let archive = try! @mbtzip.read(fixture_docx(malformed))
  let budget = @xml.xml_read_budget(
    max_source_units=1024 * 1024,
    max_tokens=4096,
    max_materialized_chars=1024 * 1024,
    max_token_chars=4096,
  )
  try @docx.read_docx_annotated_archive_limited(archive, budget) catch {
    InvalidXml(_) => ()
    _ => fail("expected malformed visible story XML to fail strict parsing")
  } noraise {
    _ => fail("expected malformed visible story XML to be rejected")
  }
}

///|
test "annotation story paths cannot alias body or comments under another kind" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let body_alias = with_main_relationship(
    fixture_docx(document),
    "rHiddenHeader",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
    "document.xml",
  )
  try @docx.read_docx_annotated(body_alias) catch {
    Unsupported(message~) =>
      assert_true(message.contains("targeted as both body and header"))
    _ => fail("expected body/header story aliasing to fail")
  } noraise {
    _ => fail("expected body/header story aliasing to fail")
  }
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>
  let comments_alias = with_main_relationship(
    fixture_docx(document, comments_xml=Some(comments)),
    "rHiddenFooter",
    "http://purl.oclc.org/ooxml/officeDocument/relationships/footer",
    "comments.xml",
  )
  try @docx.read_docx_annotated(comments_alias) catch {
    Unsupported(message~) =>
      assert_true(message.contains("targeted as both comments and footer"))
    _ => fail("expected comments/footer story aliasing to fail")
  } noraise {
    _ => fail("expected comments/footer story aliasing to fail")
  }
}

///|
test "typed annotation relationships require matching expanded story roots" {
  let header_type = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header"
  let header_content_type = "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"
  let wrong_kind = unreferenced_story_fixture(
    header_type, "hidden.xml", "word/hidden.xml", header_content_type, "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
  )
  try @docx.read_docx_annotated(wrong_kind) catch {
    InvalidXml(message~) =>
      inspect(
        message,
        content="the header annotation story part 'word/hidden.xml' must have a WordprocessingML 'hdr' root",
      )
    _ => fail("expected the relationship/root kind mismatch to fail")
  } noraise {
    _ => fail("expected the relationship/root kind mismatch to fail")
  }

  let wrong_namespace = unreferenced_story_fixture(
    header_type, "hidden.xml", "word/hidden.xml", header_content_type, "<x:hdr xmlns:x=\"urn:not-wordprocessingml\"/>",
  )
  try @docx.read_docx_annotated(wrong_namespace) catch {
    InvalidXml(message~) =>
      assert_true(message.contains("WordprocessingML 'hdr' root"))
    _ => fail("expected the relationship/root namespace mismatch to fail")
  } noraise {
    _ => fail("expected the relationship/root namespace mismatch to fail")
  }

  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let comments_with_wrong_root = fixture_docx(
    document,
    comments_xml=Some(
      "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
    ),
  )
  try @docx.read_docx_annotated(comments_with_wrong_root) catch {
    InvalidXml(message~) =>
      assert_true(message.contains("WordprocessingML 'comments' root"))
    _ => fail("expected a comments relationship/root mismatch to fail")
  } noraise {
    _ => fail("expected a comments relationship/root mismatch to fail")
  }
}

///|
test "annotation relationships and roots match the main OOXML dialect" {
  let transitional_relationships = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"
  let strict_relationships = "http://purl.oclc.org/ooxml/officeDocument/relationships/"
  let transitional_wml = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  let strict_wml = "http://purl.oclc.org/ooxml/wordprocessingml/main"
  let cases : Array[(String, String, String)] = [
    (
      "comments", "comments", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
    ),
    (
      "header", "hdr", "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml",
    ),
    (
      "footer", "ftr", "application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml",
    ),
    (
      "footnotes", "footnotes", "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml",
    ),
    (
      "endnotes", "endnotes", "application/vnd.openxmlformats-officedocument.wordprocessingml.endnotes+xml",
    ),
  ]
  for entry in cases {
    let (kind, root, content_type) = entry
    let target = "dialect-\{kind}.xml"
    let part_path = "word/\{target}"
    let relationship_root_mismatch = unreferenced_story_fixture(
      strict_relationships + kind,
      target,
      part_path,
      content_type,
      "<w:\{root} xmlns:w=\"\{transitional_wml}\"/>",
    )
    expect_annotation_identity_failure(
      relationship_root_mismatch,
      "the \{kind} relationship dialect does not match the target WordprocessingML namespace",
    )
    let story_main_mismatch = unreferenced_story_fixture(
      strict_relationships + kind,
      target,
      part_path,
      content_type,
      "<w:\{root} xmlns:w=\"\{strict_wml}\"/>",
    )
    expect_annotation_identity_failure(
      story_main_mismatch,
      "the \{kind} annotation story at '\{part_path}' does not match the main WordprocessingML dialect",
    )
    // A matching Transitional graph remains accepted for every role.
    let coherent = unreferenced_story_fixture(
      transitional_relationships + kind,
      target,
      part_path,
      content_type,
      "<w:\{root} xmlns:w=\"\{transitional_wml}\"/>",
    )
    @docx.validate_annotation_identity_state(
      @docx.read_docx_annotated(coherent),
    )
  }
}

///|
test "commentsExtended is strict-parsed under annotation identity rules" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:comment w:id="0"><w:p w14:paraId="ABCD0001"/></w:comment></w:comments>
  let duplicate_expanded_attribute =
    #|<w15:commentsEx xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml" xmlns:alias="http://schemas.microsoft.com/office/word/2012/wordml"><w15:commentEx w15:paraId="ABCD0001" alias:paraId="FFFF0001"/></w15:commentsEx>
  let bytes = fixture_docx(
    document,
    comments_xml=Some(comments),
    comments_extended_xml=Some(duplicate_expanded_attribute),
  )
  try @docx.read_docx_annotated(bytes) catch {
    InvalidXml(message~) =>
      inspect(
        message,
        content="duplicate expanded XML attribute: {http://schemas.microsoft.com/office/word/2012/wordml}paraId",
      )
    _ => fail("expected duplicate expanded commentsExtended attributes to fail")
  } noraise {
    _ => fail("expected duplicate expanded commentsExtended attributes to fail")
  }
}

///|
test "commentsExtended strict parsing consumes the cumulative XML budget" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let extended = StringBuilder()
  extended.write_string(
    "<w15:commentsEx xmlns:w15=\"http://schemas.microsoft.com/office/word/2012/wordml\">",
  )
  for _ in 0..<512 {
    extended.write_string("<w15:commentEx w15:paraId=\"00000000\"/>")
  }
  extended.write_string("</w15:commentsEx>")
  let archive = try! @mbtzip.read(
    fixture_docx(document, comments_extended_xml=Some(extended.to_string())),
  )
  let budget = @xml.xml_read_budget(
    max_source_units=8 * 1024,
    max_tokens=1_000_000,
    max_materialized_chars=1_000_000,
    max_token_chars=1_000_000,
  )
  try @docx.read_docx_annotated_archive_limited(archive, budget) catch {
    ResourceLimit(limit~, message~) => {
      debug_inspect(limit, content="DocxXmlSourceUnits")
      inspect(message, content="XML source budget exceeded")
    }
    _ => fail("expected commentsExtended to consume the shared XML budget")
  } noraise {
    _ => fail("expected commentsExtended to consume the shared XML budget")
  }
}

///|
test "a second comments parse preserves XML resource failure typing" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="0"><w:p/></w:comment></w:comments>
  let bytes = fixture_docx(document, comments_xml=Some(comments))
  let archive = try! @mbtzip.read(bytes)
  let mut source_limit = 0
  for
    part in [
      "_rels/.rels", "word/_rels/document.xml.rels", "[Content_Types].xml", "word/comments.xml",
      "word/document.xml",
    ] {
    guard archive.get(part) is Some(content) else {
      fail("resource fixture is missing \{part}")
    }
    source_limit += content.length()
  }
  let budget = @xml.xml_read_budget(
    max_source_units=source_limit,
    max_tokens=1_000_000,
    max_materialized_chars=1_000_000,
    max_token_chars=1_000_000,
  )
  try @docx.read_docx_annotated_archive_limited(archive, budget) catch {
    ResourceLimit(limit~, message~) => {
      debug_inspect(limit, content="DocxXmlSourceUnits")
      inspect(message, content="XML source budget exceeded")
    }
    _ => fail("expected the comments reread resource failure to stay typed")
  } noraise {
    _ => fail("expected the comments reread to exhaust its shared budget")
  }
}

///|
test "comment resolution matches decoded ids on default-namespaced entries" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:comment w:id="0"><w:p w14:paraId="ABCD0001"/></w:comment></w:comments>
  let extended =
    #|<commentsEx xmlns="http://schemas.microsoft.com/office/word/2012/wordml" xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml"><commentEx w15:paraId="ABCD000&#x31;"/></commentsEx>
  let source = fixture_docx(
    document,
    comments_xml=Some(comments),
    comments_extended_xml=Some(extended),
  )
  let annotated = @docx.read_docx_annotated(source)
  let plan = @docx.plan_comment_resolution(
    annotated,
    source,
    comment_id="0",
    done=true,
  )
  let result = @mbtzip.read(@splice.splice_docx(source, plan))
  guard result.get("word/commentsExtended.xml") is Some(bytes)
  let actual = @utf8.decode(bytes, ignore_bom=true)
  assert_true(
    actual.contains("<commentEx w15:paraId=\"ABCD000&#x31;\" w15:done=\"1\"/>"),
  )
  // Missing the lexical entry would append a second, prefixed record.
  assert_false(actual.contains("<w15:commentEx"))
  debug_inspect(
    @docx.read_docx_annotated(@splice.splice_docx(source, plan))
    .annotations()
    .comments()[0].done(),
    content="Some(true)",
  )
}

///|
test "comment reply and resolution reuse paraIds under encoded namespace URIs" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:q="http://schemas.microsoft.com/office/word/2010/wordm&#108;"><w:comment w:id="0"><w:p q:paraId="ABCD0001"/></w:comment></w:comments>
  let source = fixture_docx(document, comments_xml=Some(comments))
  let annotated = @docx.read_docx_annotated(source)
  debug_inspect(
    annotated.annotations().comments()[0].last_para_id(),
    content="Some(\"ABCD0001\")",
  )

  let resolution = @docx.plan_comment_resolution(
    annotated,
    source,
    comment_id="0",
    done=true,
  )
  let resolved = @splice.splice_docx(source, resolution)
  let resolved_archive = @mbtzip.read(resolved)
  guard resolved_archive.get("word/comments.xml") is Some(resolved_comments)
  assert_eq(@utf8.decode(resolved_comments, ignore_bom=true), comments)
  debug_inspect(
    @docx.read_docx_annotated(resolved).annotations().comments()[0].done(),
    content="Some(true)",
  )

  let reply_spec = @docx.comment_spec(author="Reply", from=0, to=0, [
    @document.paragraph([@document.run([@document.text("reply")])]),
  ])
  let (reply_plan, reply_id) = @docx.plan_comment_reply(
    annotated,
    source,
    parent_id="0",
    reply_spec,
  )
  inspect(reply_id, content="1")
  let replied = @splice.splice_docx(source, reply_plan)
  let replied_archive = @mbtzip.read(replied)
  guard replied_archive.get("word/comments.xml") is Some(replied_comments)
  let replied_text = @utf8.decode(replied_comments, ignore_bom=true)
  assert_true(replied_text.contains("<w:p q:paraId=\"ABCD0001\"/>"))
  let verified = @docx.read_docx_annotated(replied)
  assert_eq(verified.annotations().comments().length(), 2)
  debug_inspect(
    verified.annotations().comments()[1].parent_id(),
    content="Some(\"0\")",
  )
}

///|
test "comment resolution accepts arbitrarily padded numeric references" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:comment w:id="0"><w:p w14:paraId="ABCD0001"/></w:comment></w:comments>
  let extended =
    #|<commentsEx xmlns="http://schemas.microsoft.com/office/word/2012/wordml" xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml"><commentEx w15:paraId="ABCD000&#000000000000000000000000000049;"/></commentsEx>
  let source = fixture_docx(
    document,
    comments_xml=Some(comments),
    comments_extended_xml=Some(extended),
  )
  let annotated = @docx.read_docx_annotated(source)
  let plan = @docx.plan_comment_resolution(
    annotated,
    source,
    comment_id="0",
    done=true,
  )
  let result = @mbtzip.read(@splice.splice_docx(source, plan))
  guard result.get("word/commentsExtended.xml") is Some(bytes)
  let actual = @utf8.decode(bytes, ignore_bom=true)
  assert_true(
    actual.contains(
      "w15:paraId=\"ABCD000&#000000000000000000000000000049;\" w15:done=\"1\"",
    ),
  )
  assert_false(actual.contains("<w15:commentEx"))
}

///|
test "comment resolution skips greater-than signs inside prolog PIs" {
  let document =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:comment w:id="0"><w:p w14:paraId="ABCD0001"/></w:comment></w:comments>
  let extended =
    #|<?producer x > <fake ?><commentsEx xmlns="http://schemas.microsoft.com/office/word/2012/wordml" xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml"><commentEx w15:paraId="ABCD0001"/></commentsEx>
  let source = fixture_docx(
    document,
    comments_xml=Some(comments),
    comments_extended_xml=Some(extended),
  )
  let annotated = @docx.read_docx_annotated(source)
  let plan = @docx.plan_comment_resolution(
    annotated,
    source,
    comment_id="0",
    done=true,
  )
  let result = @mbtzip.read(@splice.splice_docx(source, plan))
  guard result.get("word/commentsExtended.xml") is Some(bytes)
  let actual = @utf8.decode(bytes, ignore_bom=true)
  assert_true(actual.has_prefix("<?producer x > <fake ?>"))
  assert_true(actual.contains("w15:paraId=\"ABCD0001\" w15:done=\"1\""))
}

///|
test "comment resolution chooses an unshadowed namespace and preserves prefixed OPC metadata" {
  let wml = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  let w14 = "http://schemas.microsoft.com/office/word/2010/wordml"
  let document = "<w:document xmlns:w=\"\{wml}\"><w:body><w:p/></w:body></w:document>"
  let comments = "<w:comments xmlns:w=\"\{wml}\" xmlns:w14=\"urn:vendor\" xmlns:q=\"http://schemas.microsoft.com/office/word/2010/wordm&#108;\" xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibilit&#121;/2006\" mc:Ignorable=\"q\"><w:comment w:id=\"0\"><w:p xmlns:q=\"urn:shadow\"><w:r><w:t>unstamped</w:t></w:r></w:p></w:comment></w:comments>"
  let archive = @mbtzip.read(
    fixture_docx(document, comments_xml=Some(comments)),
  )
  let relationships =
    #|<pr:Relationships xmlns:pr="http://schemas.openxmlformats.org/package/2006/relationships"><pr:Relationship Id="rId100" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="comments.xml"/></pr:Relationships>
  assert_true(
    archive.replace("word/_rels/document.xml.rels", @utf8.encode(relationships)),
  )
  let content_types =
    #|<ct:Types xmlns:ct="http://schemas.openxmlformats.org/package/2006/content-types"><ct:Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><ct:Default Extension="xml" ContentType="application/xml"/><ct:Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><ct:Override PartName="/word/comments.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"/></ct:Types>
  assert_true(
    archive.replace("[Content_Types].xml", @utf8.encode(content_types)),
  )
  let source = @mbtzip.write(archive)
  let annotated = @docx.read_docx_annotated(source)
  let plan = @docx.plan_comment_resolution(
    annotated,
    source,
    comment_id="0",
    done=true,
  )
  let result = @mbtzip.read(@splice.splice_docx(source, plan))
  guard result.get("word/comments.xml") is Some(comments_bytes)
  let comments_text = @utf8.decode(comments_bytes, ignore_bom=true)
  assert_true(comments_text.contains("xmlns:mbtw14=\"\{w14}\""))
  assert_true(comments_text.contains("mc:Ignorable=\"q mbtw14\""))
  assert_true(comments_text.contains("mbtw14:paraId="))
  assert_false(comments_text.contains(" w14:paraId="))
  guard result.get("word/_rels/document.xml.rels") is Some(rels_bytes)
  let rels_text = @utf8.decode(rels_bytes, ignore_bom=true)
  assert_true(rels_text.contains("<pr:Relationship "))
  assert_true(rels_text.contains("commentsExtended.xml"))
  guard result.get("[Content_Types].xml") is Some(types_bytes)
  let types_text = @utf8.decode(types_bytes, ignore_bom=true)
  assert_true(
    types_text.contains("<ct:Override PartName=\"/word/commentsExtended.xml\""),
  )
  let verified = @docx.read_docx_annotated(@mbtzip.write(result))
  debug_inspect(
    verified.annotations().comments()[0].done(),
    content="Some(true)",
  )
}

///|
test "comment mutation preserves Unicode namespace prefixes" {
  let wml = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  let w14 = "http://schemas.microsoft.com/office/word/2010/wordml"
  let w15 = "http://schemas.microsoft.com/office/word/2012/wordml"
  let document = "<w:document xmlns:w=\"\{wml}\"><w:body><w:p/></w:body></w:document>"
  let comments = "<w:comments xmlns:w=\"\{wml}\" xmlns:α=\"\{w14}\"><w:comment w:id=\"0\"><w:p α:paraId=\"ABCD0001\"/></w:comment></w:comments>"
  let extended = "<δ:commentsEx xmlns:δ=\"\{w15}\"><δ:commentEx δ:paraId=\"ABCD0001\"/></δ:commentsEx>"
  let source = fixture_docx(
    document,
    comments_xml=Some(comments),
    comments_extended_xml=Some(extended),
  )
  let annotated = @docx.read_docx_annotated(source) catch {
    err => fail("Unicode-prefix source read failed: \{repr(err)}")
  }
  let plan = @docx.plan_comment_resolution(
    annotated,
    source,
    comment_id="0",
    done=true,
  )
  let spliced = @splice.splice_docx(source, plan) catch {
    err => fail("Unicode-prefix splice failed: \{repr(err)}")
  }
  let result = @mbtzip.read(spliced)
  guard result.get("word/commentsExtended.xml") is Some(bytes)
  let actual = @utf8.decode(bytes, ignore_bom=true)
  assert_true(actual.contains("δ:paraId=\"ABCD0001\" δ:done=\"1\""))
  assert_false(actual.contains("Î"))
  debug_inspect(
    @docx.read_docx_annotated(@mbtzip.write(result)).annotations().comments()[0].done(),
    content="Some(true)",
  )
}

///|
test "definitions referenced only by hidden stories report no public anchors" {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/comments.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
  )
  builder.add_override(
    "/word/header-hidden.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml",
  )
  builder.add_relationship(
    "rIdMain", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rIdComments",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    "comments.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rIdHidden",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
    "header-hidden.xml",
    source="word/document.xml",
  )
  builder.add_part(
    "word/document.xml",
    @utf8.encode(
      "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p/></w:body></w:document>",
    ),
  )
  builder.add_part(
    "word/comments.xml",
    @utf8.encode(
      "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:comment w:id=\"7\"><w:p/></w:comment></w:comments>",
    ),
  )
  builder.add_part(
    "word/header-hidden.xml",
    @utf8.encode(
      "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:commentReference w:id=\"7\"/></w:r></w:p></w:hdr>",
    ),
  )
  let annotated = @docx.read_docx_annotated(builder.build())
  assert_true(
    annotated
    .annotations()
    .warnings()
    .contains(
      "annotation index: comment '7' has no public anchors (referenced only in relationship-reachable hidden stories; content still exposed)",
    ),
  )
  @docx.validate_annotation_identity_state(annotated)
}

///|
test "identity-only stories consume the cumulative XML source budget" {
  let large_header = StringBuilder()
  large_header.write_string(
    "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">",
  )
  for _ in 0..<5_000 {
    large_header.write_string("<w:p/>")
  }
  large_header.write_string("</w:hdr>")
  let bytes = unreferenced_story_fixture(
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
    "header-hidden.xml",
    "word/header-hidden.xml",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml",
    large_header.to_string(),
  )
  let archive = try! @mbtzip.read(bytes)
  let budget = @xml.xml_read_budget(
    max_source_units=16 * 1024,
    max_tokens=1_000_000,
    max_materialized_chars=1_000_000,
    max_token_chars=1_000_000,
  )
  try @docx.read_docx_annotated_archive_limited(archive, budget) catch {
    ResourceLimit(limit~, message~) => {
      debug_inspect(limit, content="DocxXmlSourceUnits")
      inspect(message, content="XML source budget exceeded")
    }
    _ => fail("expected the hidden header to consume the shared XML budget")
  } noraise {
    _ => fail("expected the hidden header to consume the shared XML budget")
  }
}

///|
test "tolerant bounded reads preserve header resource failures" {
  let large_header = "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:t>" +
    "x".repeat(1024) +
    "</w:t></w:r></w:p></w:hdr>"
  let bytes = unreferenced_story_fixture(
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
    "header.xml", "word/header.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml",
    large_header,
  )
  let archive = try! @mbtzip.read(bytes)
  assert_true(
    archive.replace(
      "word/document.xml",
      @utf8.encode(
        (
          #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body><w:p/><w:sectPr><w:headerReference w:type="default" r:id="rIdHidden"/></w:sectPr></w:body></w:document>
        ),
      ),
    ),
  )
  let budget = @xml.xml_read_budget(
    max_source_units=64 * 1024,
    max_tokens=4096,
    max_materialized_chars=64 * 1024,
    max_token_chars=256,
  )
  try
    @docx.read_docx_annotated_archive_tolerant_limited(archive, budget)
  catch {
    ResourceLimit(limit~, message~) => {
      debug_inspect(limit, content="DocxXmlTokenLength")
      inspect(message, content="XML token length budget exceeded")
    }
    error => fail("expected typed header resource failure, got \{repr(error)}")
  } noraise {
    _ => fail("expected an oversized header token to remain a hard limit")
  }
}

///|
test "relocated Strict footnotes and endnotes are parsed and publicly scanned" {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/comments.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
  )
  builder.add_override(
    "/notes/footnotes.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml",
  )
  builder.add_override(
    "/notes/endnotes.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.endnotes+xml",
  )
  builder.add_relationship(
    "rIdMain", "http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rIdComments",
    "http://purl.oclc.org/ooxml/officeDocument/relationships/comments",
    "comments.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rIdFootnotes",
    "http://purl.oclc.org/ooxml/officeDocument/relationships/footnotes",
    "../notes/footnotes.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rIdEndnotes",
    "http://purl.oclc.org/ooxml/officeDocument/relationships/endnotes",
    "../notes/endnotes.xml",
    source="word/document.xml",
  )
  builder.add_part(
    "word/document.xml",
    @utf8.encode(
      "<w:document xmlns:w=\"http://purl.oclc.org/ooxml/wordprocessingml/main\"><w:body><w:p/></w:body></w:document>",
    ),
  )
  builder.add_part(
    "word/comments.xml",
    @utf8.encode(
      "<w:comments xmlns:w=\"http://purl.oclc.org/ooxml/wordprocessingml/main\"><w:comment w:id=\"7\"><w:p/></w:comment><w:comment w:id=\"8\"><w:p/></w:comment></w:comments>",
    ),
  )
  builder.add_part(
    "notes/footnotes.xml",
    @utf8.encode(
      "<w:footnotes xmlns:w=\"http://purl.oclc.org/ooxml/wordprocessingml/main\"><w:footnote w:id=\"2\"><w:p><w:r><w:commentReference w:id=\"7\"/></w:r></w:p></w:footnote></w:footnotes>",
    ),
  )
  builder.add_part(
    "notes/endnotes.xml",
    @utf8.encode(
      "<w:endnotes xmlns:w=\"http://purl.oclc.org/ooxml/wordprocessingml/main\"><w:endnote w:id=\"3\"><w:p><w:r><w:commentReference w:id=\"8\"/></w:r></w:p></w:endnote></w:endnotes>",
    ),
  )
  let annotated = @docx.read_docx_annotated(builder.build())
  assert_eq(annotated.footnote_bodies().length(), 1)
  assert_eq(annotated.endnote_bodies().length(), 1)
  let comments = annotated.annotations().comments()
  assert_eq(comments.length(), 2)
  assert_eq(comments[0].anchors()[0].references(), [
    "/footnotes/note[1]/p[1]/r[1]",
  ])
  assert_eq(comments[1].anchors()[0].references(), [
    "/endnotes/note[1]/p[1]/r[1]",
  ])
  @docx.validate_annotation_identity_state(annotated)
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
test "singleton annotation relationships reject duplicate ids for one target" {
  let cases : Array[(String, String, String, String, String, String)] = [
    (
      "comments", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
      "comments.xml", "word/comments.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
      "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
    ),
    (
      "commentsExtended", "http://schemas.microsoft.com/office/2011/relationships/commentsExtended",
      "commentsExtended.xml", "word/commentsExtended.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.commentsExtended+xml",
      "<w15:commentsEx xmlns:w15=\"http://schemas.microsoft.com/office/word/2012/wordml\"/>",
    ),
    (
      "footnotes", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
      "footnotes.xml", "word/footnotes.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml",
      "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
    ),
    (
      "endnotes", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes",
      "endnotes.xml", "word/endnotes.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.endnotes+xml",
      "<w:endnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
    ),
  ]
  for case in cases {
    let (label, relationship_type, target, part_path, content_type, story_xml) = case
    let source = unreferenced_story_fixture(
      relationship_type, target, part_path, content_type, story_xml,
    )
    let duplicate = with_main_relationship(
      source, "rIdDuplicate", relationship_type, target,
    )
    try @docx.read_docx_annotated(duplicate) catch {
      Unsupported(message~) =>
        assert_eq(
          message,
          "the document declares multiple \{label} relationships",
        )
      _ => fail("expected duplicate \{label} relationship failure")
    } noraise {
      _ => fail("expected duplicate \{label} relationships to fail")
    }
  }
}

///|
test "annotation relationships require their role-specific content types" {
  let cases : Array[(String, String, String, String, String)] = [
    (
      "comments", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
      "comments.xml", "word/comments.xml", "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
    ),
    (
      "commentsExtended", "http://schemas.microsoft.com/office/2011/relationships/commentsExtended",
      "commentsExtended.xml", "word/commentsExtended.xml", "<w15:commentsEx xmlns:w15=\"http://schemas.microsoft.com/office/word/2012/wordml\"/>",
    ),
    (
      "footnotes", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
      "footnotes.xml", "word/footnotes.xml", "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
    ),
    (
      "endnotes", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes",
      "endnotes.xml", "word/endnotes.xml", "<w:endnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
    ),
    (
      "header", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
      "header1.xml", "word/header1.xml", "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
    ),
    (
      "footer", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer",
      "footer1.xml", "word/footer1.xml", "<w:ftr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
    ),
  ]
  for case in cases {
    let (kind, relationship_type, target, part_path, story_xml) = case
    let broken = unreferenced_story_fixture(
      relationship_type, target, part_path, "application/xml", story_xml,
    )
    try @docx.read_docx_annotated(broken) catch {
      Unsupported(message~) =>
        assert_true(
          message.has_prefix(
            "the \{kind} relationship target '\{part_path}' has content type 'application/xml', expected '",
          ),
        )
      _ => fail("expected wrong \{kind} content type to fail")
    } noraise {
      _ => fail("expected wrong \{kind} content type to be rejected")
    }
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
test "delimiter-rich annotation ids warn when paths fall back to ordinals" {
  // A range anchored INSIDE a comment body covers that body paragraph
  // (cross-story coverage). The emitted DOCX projection path still uses the
  // legacy unescaped grammar, so delimiter-rich ids require an explicit
  // stability warning even though the canonical Office selector can quote ids.
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
  let mut saw_fallback_warning = false
  for warning in index.warnings() {
    if warning.contains("cannot be addressed as [@id=...]") {
      saw_fallback_warning = true
    }
  }
  assert_true(saw_fallback_warning)
  // The point anchor still covers the body paragraph.
  debug_inspect(
    index.covering_comment_ids("/body/p[1]"),
    content=(
      #|["a/b"]
    ),
  )
}
