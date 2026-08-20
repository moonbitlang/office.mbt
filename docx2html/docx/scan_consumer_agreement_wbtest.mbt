///|
/// #462 C2: consumer-agreement pins. With the index adopting retained
/// scans (C1c), every scan-backed span surface and the mutation resolver
/// read the same physical scan. Two kinds of pin hold that:
///
/// - VALUE pins: each surface returns exactly the adopted scan's records,
///   every exposed field compared.
/// - IDENTITY pins: value equality alone cannot catch a reintroduced
///   second scan — C1's own parity oracle proves a rescan is
///   value-identical — so sentinel records are injected into the shared
///   instance (the established corruption-probe pattern; production code
///   never mutates a frozen scan) and the surfaces must SEE them, and the
///   resolver's splice is held to the exact byte window the span surface
///   reports.
fn optional_offset(value : Int) -> Int? {
  if value < 0 {
    None
  } else {
    Some(value)
  }
}

///|
test "every span surface reads the adopted scan's records" {
  let annotated = read_docx_annotated(adoption_fixture())
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
        (
          span.byte_start(),
          span.byte_end(),
          span.content_start(),
          span.close_tag_start(),
          span.self_closing(),
        ),
        (
          node.byte_start,
          node.byte_end,
          optional_offset(node.content_start),
          optional_offset(node.close_tag_start),
          node.content_start < 0,
        ),
        msg="\{story}/\{node.path} span",
      )
      pinned += 1
    }
    guard scan.root() is Some(root) else { fail("\{story} must have a root") }
    guard annotated.story_root_span(story) is Some(root_span) else {
      fail("\{story} root must resolve")
    }
    assert_eq(
      (
        root_span.byte_start(),
        root_span.byte_end(),
        root_span.content_start(),
        root_span.close_tag_start(),
      ),
      (
        root.byte_start,
        root.byte_end,
        optional_offset(root.content_start),
        optional_offset(root.close_tag_start),
      ),
      msg="\{story} root span",
    )
  }
  assert_true(pinned > 4, msg="the fixture must exercise several nodes")
  // The body shorthands are the same lookup as the story forms, for BOTH
  // span kinds they cover.
  guard (
      annotated.body_run_span("p[1]/r[1]"),
      annotated.story_run_span("/body", "p[1]/r[1]"),
      annotated.body_paragraph_span("p[1]"),
      annotated.story_paragraph_span("/body", "p[1]"),
    )
    is (
      Some(run_short),
      Some(run_story),
      Some(paragraph_short),
      Some(paragraph_story),
    ) else {
    fail("body run and paragraph must resolve through both surfaces")
  }
  assert_eq(
    (run_short.byte_start(), run_short.byte_end()),
    (run_story.byte_start(), run_story.byte_end()),
  )
  assert_eq(
    (paragraph_short.byte_start(), paragraph_short.byte_end()),
    (paragraph_story.byte_start(), paragraph_story.byte_end()),
  )
}

///|
test "span surfaces read the SHARED scan instance, not a rescan" {
  let annotated = read_docx_annotated(adoption_fixture())
  guard annotated.reader_projections.get("word/document.xml")
    is Some(projection) else {
    fail("expected the main projection")
  }
  // A sentinel no rescan of the source could ever produce: if the span
  // surface can see it, the surface reads THIS instance.
  projection.scan
  .nodes()
  .push(ScannedNode::{
    path: "p[77]/r[77]",
    kind: "r",
    open_order: 9_999,
    open_seq: 999_990,
    close_seq: 999_991,
    byte_start: 3,
    byte_end: 9,
    content_start: -1,
    close_tag_start: -1,
  })
  guard annotated.story_run_span("/body", "p[77]/r[77]") is Some(sentinel) else {
    fail("the span surface must read the shared scan instance")
  }
  assert_eq((sentinel.byte_start(), sentinel.byte_end()), (3, 9))
  // covering_comment_ids reads the same shared nodes array: a sentinel
  // paragraph carrying the REAL first paragraph's marker-sequence window
  // must report the same covering comment.
  let mut original_open = -1
  let mut original_close = -1
  for node in projection.scan.nodes() {
    if node.kind == "p" && node.path == "p[1]" {
      original_open = node.open_seq
      original_close = node.close_seq
    }
  }
  assert_true(original_open >= 0)
  projection.scan
  .nodes()
  .push(ScannedNode::{
    path: "p[88]",
    kind: "p",
    open_order: 9_998,
    open_seq: original_open,
    close_seq: original_close,
    byte_start: 3,
    byte_end: 9,
    content_start: -1,
    close_tag_start: -1,
  })
  assert_eq(annotated.annotations().covering_comment_ids("/body/p[1]"), ["1"])
  assert_eq(annotated.annotations().covering_comment_ids("/body/p[88]"), ["1"])
}

///|
test "the resolver's splice touches exactly the span the surface reports" {
  let bytes = adoption_fixture()
  let archive = @mbtzip.read(bytes)
  let annotated = read_docx_annotated_archive(archive)
  guard annotated.story_run_span("/body", "p[1]/r[1]") is Some(span) else {
    fail("the addressed run must have a span")
  }
  let (plan, receipt) = plan_run_text_replacement(
    annotated,
    annotated.main_story_source(),
    at_relative="p[1]/r[1]",
    expect="Body",
    text="Edited",
  )
  assert_eq(receipt.replaced_text(), "Body")
  assert_eq(receipt.at_relative(), "p[1]/r[1]")
  assert_eq(receipt.story_part(), annotated.main_story_part())
  assert_eq(annotated.main_story_source().part(), annotated.main_story_part())
  // The physical proof: the spliced part differs from the retained source
  // ONLY inside the byte window the span surface reported — the resolver
  // selected the very node the surface exposes.
  guard annotated.reader_projection_sources.get("word/document.xml")
    is Some(source) else {
    fail("expected retained source bytes")
  }
  let spliced = @splice.splice_docx_archive(
    archive,
    plan,
    max_output_bytes=1 << 22,
  )
  // The re-read's retained source IS the edited part's bytes.
  let reread = read_docx_annotated(spliced)
  guard reread.reader_projection_sources.get("word/document.xml")
    is Some(edited) else {
    fail("expected the edited main part")
  }
  let delta = edited.length() - source.length()
  assert_eq(delta, "Edited".length() - "Body".length())
  for offset in 0..<span.byte_start() {
    assert_eq(source[offset], edited[offset], msg="prefix byte \{offset}")
  }
  for offset in span.byte_end()..<source.length() {
    assert_eq(
      source[offset],
      edited[offset + delta],
      msg="suffix byte \{offset}",
    )
  }
  let mut differs = false
  for offset in span.byte_start()..<span.byte_end() {
    if source[offset] != edited[offset] {
      differs = true
      break
    }
  }
  assert_true(differs, msg="the addressed window must carry the change")
  // Where the span surface reports no node, the resolver must refuse.
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
test "a nonstandard main part resolves through the relationship everywhere" {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/main-custom.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/main-custom.xml",
  )
  builder.add_part(
    "word/main-custom.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Custom</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
      ),
    ),
  )
  let annotated = read_docx_annotated(builder.build())
  assert_eq(annotated.main_story_part(), "word/main-custom.xml")
  assert_eq(annotated.main_story_source().part(), "word/main-custom.xml")
  guard annotated.reader_projections.get("word/main-custom.xml") is Some(_) else {
    fail("the nonstandard main part must carry the adopted projection")
  }
  assert_true(annotated.body_run_span("p[1]/r[1]") is Some(_))
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
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:ins w:id="1" w:author="Ada" w:date="2001-01-01T00:00:00Z"><w:r><w:t>new</w:t></w:r></w:ins><w:del w:id="2" w:author="Bob" xmlns:x="urn:extra"><w:r><w:delText>gone</w:delText><w:delInstrText>PAGE</w:delInstrText></w:r></w:del></w:p><w:sectPr/></w:body></w:document>
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
  assert_eq(spans.length(), 2)
  let mut namespace_declaring = 0
  for index in 0..<spans.length() {
    let span = spans[index]
    let site = sites[index]
    assert_eq(
      (
        span.story(),
        span.kind(),
        span.supported(),
        span.id(),
        span.author(),
        span.date(),
        span.container_path(),
      ),
      (
        "/body",
        site.local_name,
        site.supported,
        site.id,
        site.author,
        site.date,
        site.container_path,
      ),
      msg="revision span identity \{index}",
    )
    assert_eq(
      (
        span.byte_start(),
        span.byte_end(),
        span.content_start(),
        span.close_tag_start(),
      ),
      (
        site.byte_start,
        site.byte_end,
        optional_offset(site.content_start),
        optional_offset(site.close_tag_start),
      ),
      msg="revision span offsets \{index}",
    )
    assert_eq(span.declares_namespaces(), site.declares_namespaces)
    if span.declares_namespaces() {
      namespace_declaring += 1
    }
    let mut expected_edits = 0
    for record in site.name_edits {
      expected_edits += 1
      if record.close_start >= 0 {
        expected_edits += 1
      }
    }
    let edits = span.name_edits()
    assert_eq(edits.length(), expected_edits)
    let mut cursor = 0
    for record in site.name_edits {
      assert_eq(
        (
          edits[cursor].start(),
          edits[cursor].end(),
          edits[cursor].replacement(),
        ),
        (record.open_start, record.open_end, record.replacement),
        msg="name edit open \{index}/\{cursor}",
      )
      cursor += 1
      if record.close_start >= 0 {
        assert_eq(
          (
            edits[cursor].start(),
            edits[cursor].end(),
            edits[cursor].replacement(),
          ),
          (record.close_start, record.close_end, record.replacement),
          msg="name edit close \{index}/\{cursor}",
        )
        cursor += 1
      }
    }
  }
  // Both namespace-flag polarities are exercised: the ins declares nothing,
  // the del declares xmlns:x.
  assert_eq(namespace_declaring, 1)
}
