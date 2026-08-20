///|
/// #462 C2: consumer-agreement pins. With the index adopting retained
/// scans (C1c), every scan-backed span surface and the mutation resolver
/// read the same physical scan. These pins hold each public surface to the
/// adopted scan's records, so a future divergence — a second scan, a
/// filtered view, a stale copy — cannot slip in behind the shared type.
test "every span surface reads the adopted scan's records" {
  let annotated = read_docx_annotated(adoption_fixture())
  assert_eq(annotated.main_story_part(), "word/document.xml")
  let mut pinned = 0
  for entry in annotated.index.scans {
    let (story, scan) = entry
    for node in scan.nodes() {
      let span = match node.kind {
        "p" => annotated.story_paragraph_span(story, node.path)
        "r" => annotated.story_run_span(story, node.path)
        "tr" => annotated.story_row_span(story, node.path)
        _ => continue
      }
      guard span is Some(span) else {
        fail("\{story}/\{node.path} must resolve through its span surface")
      }
      assert_eq(
        (span.byte_start, span.byte_end),
        (node.byte_start, node.byte_end),
        msg="\{story}/\{node.path} span",
      )
      pinned += 1
    }
    guard scan.root() is Some(root) else { fail("\{story} must have a root") }
    guard annotated.story_root_span(story) is Some(root_span) else {
      fail("\{story} root must resolve")
    }
    assert_eq(
      (root_span.byte_start, root_span.byte_end),
      (root.byte_start, root.byte_end),
      msg="\{story} root span",
    )
  }
  assert_true(pinned > 4, msg="the fixture must exercise several nodes")
  // The body shorthands are the same lookup as the story forms.
  guard (
      annotated.body_run_span("p[1]/r[1]"),
      annotated.story_run_span("/body", "p[1]/r[1]"),
    )
    is (Some(shorthand), Some(story_form)) else {
    fail("body run must resolve through both surfaces")
  }
  assert_eq(
    (shorthand.byte_start, shorthand.byte_end),
    (story_form.byte_start, story_form.byte_end),
  )
}

///|
test "the mutation resolver and the span surface agree on the same run" {
  let annotated = read_docx_annotated(adoption_fixture())
  guard annotated.story_run_span("/body", "p[1]/r[1]") is Some(_) else {
    fail("the addressed run must have a span")
  }
  let (_, receipt) = plan_run_text_replacement(
    annotated,
    annotated.main_story_source(),
    at_relative="p[1]/r[1]",
    expect="Body",
    text="Edited",
  )
  assert_eq(receipt.replaced_text(), "Body")
  assert_eq(receipt.at_relative(), "p[1]/r[1]")
  // Where the span surface reports no node, the resolver must refuse: both
  // read the same adopted scan, so existence cannot disagree.
  assert_true(annotated.story_run_span("/body", "p[9]/r[1]") is None)
  try
    plan_run_text_replacement(
      annotated,
      annotated.main_story_source(),
      at_relative="p[9]/r[1]",
      expect="Body",
      text="Edited",
    )
    |> ignore
  catch {
    _ => ()
  } noraise {
    _ => fail("the resolver must refuse a path the span surface lacks")
  }
}

///|
test "covering comment ids read the adopted scan" {
  let annotated = read_docx_annotated(adoption_fixture())
  assert_eq(annotated.annotations().covering_comment_ids("/body/p[1]"), ["1"])
}

///|
test "revision spans read the adopted scan's sites" {
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
  builder.add_part(
    "word/document.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:ins w:id="1" w:author="Ada" w:date="2001-01-01T00:00:00Z"><w:r><w:t>new</w:t></w:r></w:ins><w:del w:id="2" w:author="Bob"><w:r><w:delText>old</w:delText></w:r></w:del></w:p><w:sectPr/></w:body></w:document>
      ),
    ),
  )
  let annotated = read_docx_annotated(builder.build())
  let spans = annotated.revision_spans()
  guard annotated.reader_projections.get("word/document.xml")
    is Some(projection) else {
    fail("expected the main projection")
  }
  let sites = projection.scan.revision_sites()
  assert_eq(spans.length(), sites.length())
  for index in 0..<spans.length() {
    let span = spans[index]
    let site = sites[index]
    assert_eq(
      (span.kind(), span.byte_start(), span.byte_end()),
      (site.local_name, site.byte_start, site.byte_end),
      msg="revision span \{index}",
    )
    assert_eq(span.declares_namespaces(), site.declares_namespaces)
  }
  assert_eq(spans.length(), 2)
}
