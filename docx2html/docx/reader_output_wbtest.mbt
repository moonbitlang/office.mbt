// Witnesses for the joined production bundle (#434 PR 6a): production
// segmentation, the per-segment ownership boundary, and the
// budget-threaded join. The flattened forms pin exactly the leaks the
// segment boundary exists to prevent.

///|
fn project_segmented_story(
  source : String,
) -> ReaderProjectionBuildResult raise {
  guard join_text_story(source) is Joined(story) else {
    fail("expected the story to join")
  }
  guard segment_joined_reader_story(
      "word/document.xml",
      story,
      empty_body_reader({ relationships: [] }),
    )
    is SegmentedStory(output) else {
    fail("expected the story to segment")
  }
  project_joined_reader_output(output)
}

///|
fn segmentation_refusal_of(source : String) -> ReaderSegmentationRefusal raise {
  guard join_text_story(source) is Joined(story) else {
    fail("expected the story to join")
  }
  guard segment_joined_reader_story(
      "word/document.xml",
      story,
      empty_body_reader({ relationships: [] }),
    )
    is SegmentationRefused(refusal) else {
    fail("expected segmentation to refuse")
  }
  refusal
}

///|
/// The PRE-6a corpus-harness shape: every non-plumbing container's
/// children concatenated into one segmentless walk. Kept here purely as
/// the contrast oracle for the boundary tests.
fn project_flattened_notes(
  source : String,
) -> ReaderProjectionBuildResult raise {
  guard join_text_story(source) is Joined(story) else {
    fail("expected the story to join")
  }
  let collected : Array[ReaderItem] = []
  for container in story.root.element_children() {
    if !reader_note_container_is_plumbing(container) {
      collected.append(
        empty_body_reader({ relationships: [] }).read_children(
          container.element_children(),
        ),
      )
    }
  }
  project_reader_items("word/document.xml", story.scan, collected)
}

///|
test "segmented document projection matches the single-segment adapter" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>ab</w:t><w:tab/></w:r></w:p><w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:p><w:r><w:t>c</w:t></w:r></w:p></w:body></w:document>
  guard project_segmented_story(source) is Projected(segmented) else {
    fail("expected the segmented projection")
  }
  assert_eq(
    describe_projection(segmented),
    describe_projection(projection_of(source)),
  )
}

///|
test "a header root reads its own children, never a nested body" {
  let source =
    #|<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>head</w:t></w:r></w:p></w:hdr>
  guard project_segmented_story(source) is Projected(projection) else {
    fail("expected the header projection")
  }
  // hdr=0 p=1 r=2 t=3
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=1;runs=2;[0,4))t:head@3r0[0,4)
    ),
  )
  // a nested w:body is NOT selected: production passes the root's own
  // children, so the body reads as an unknown (suppressed) element and
  // the trailing paragraph is the story
  let nested =
    #|<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>X</w:t></w:r></w:p></w:body><w:p><w:r><w:t>Y</w:t></w:r></w:p></w:hdr>
  // hdr=0 body=1 p=2 r=3 t=4 p=5 r=6 t=7
  guard project_segmented_story(nested) is Projected(faithful) else {
    fail("expected the nested-body header projection")
  }
  inspect(
    describe_projection(faithful),
    content=(
      #|p0(src=5;runs=6;[0,1))s@1r-1[0,0) t:Y@7r0[0,1)
    ),
  )
}

///|
test "a footer root reads its own children" {
  let source =
    #|<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>foot</w:t></w:r></w:p></w:ftr>
  guard project_segmented_story(source) is Projected(projection) else {
    fail("expected the footer projection")
  }
  // ftr=0 p=1 r=2 t=3
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=1;runs=2;[0,4))t:foot@3r0[0,4)
    ),
  )
}

///|
test "a plumbing-typed comment still reads as content" {
  // comments carry no plumbing convention: production reads every
  // comment whatever its w:type says
  let source =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:type="separator" w:id="1"><w:p><w:r><w:t>c</w:t></w:r></w:p></w:comment></w:comments>
  // comments=0 c=1 p=2 r=3 t=4
  guard project_segmented_story(source) is Projected(projection) else {
    fail("expected the comment projection")
  }
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=2;runs=3;[0,1))t:c@4r0[0,1)
    ),
  )
}

///|
test "segmentation refuses structural surprises instead of narrowing" {
  // a foreign direct child of a notes root: production silently drops
  // it; the mutation-safe view refuses
  inspect(
    segmentation_refusal_of(
      (
        #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:x="urn:example"><x:bucket><w:p><w:r><w:t>X</w:t></w:r></w:p></x:bucket><w:footnote w:id="1"><w:p><w:r><w:t>one</w:t></w:r></w:p></w:footnote></w:footnotes>
      ),
    ).describe(),
    content="unexpected direct child {urn:example}bucket of w:footnotes",
  )
  // a document story without a body: production raises InvalidXml on
  // the same shape (only allow-listed children, so the missing body is
  // the refusal that fires)
  inspect(
    segmentation_refusal_of(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:background w:color="FF0000"/></w:document>
      ),
    ).describe(),
    content="the document story has no body",
  )
  // an unknown story root
  inspect(
    segmentation_refusal_of(
      (
        #|<w:glossaryDocument xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:glossaryDocument>
      ),
    ).describe(),
    content="unexpected story root w:glossaryDocument",
  )
  // a foreign direct child of the document: same narrowing hazard as a
  // foreign note container
  inspect(
    segmentation_refusal_of(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:x="urn:example"><x:bucket><w:p><w:r><w:t>hidden</w:t></w:r></w:p></x:bucket><w:body><w:p><w:r><w:t>visible</w:t></w:r></w:p></w:body></w:document>
      ),
    ).describe(),
    content="unexpected direct child {urn:example}bucket of w:document",
  )
  // a second body would make "the" body ambiguous
  inspect(
    segmentation_refusal_of(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body><w:body><w:p/></w:body></w:document>
      ),
    ).describe(),
    content="unexpected direct child w:body of w:document",
  )
  // the schema sequence is at most one background, before the body
  inspect(
    segmentation_refusal_of(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:background w:color="FF0000"/><w:background w:color="00FF00"/><w:body><w:p/></w:body></w:document>
      ),
    ).describe(),
    content="unexpected direct child w:background of w:document",
  )
  inspect(
    segmentation_refusal_of(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body><w:background w:color="FF0000"/></w:document>
      ),
    ).describe(),
    content="unexpected direct child w:background of w:document",
  )
}

///|
test "refusal diagnostics clip hostile names" {
  let long_uri = StringBuilder()
  long_uri.write_string("urn:")
  for _ in 0..<200 {
    long_uri.write_char('x')
  }
  let source = "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:x=\"" +
    long_uri.to_string() +
    "\"><x:bucket/><w:footnote w:id=\"1\"><w:p/></w:footnote></w:footnotes>"
  let described = segmentation_refusal_of(source).describe()
  // "unexpected direct child " + 64 clipped units + " of w:footnotes"
  assert_eq(described.length(), 24 + 64 + 15)
  guard described.has_suffix("\u{2026} of w:footnotes") else {
    fail("expected the clipped name to end in an ellipsis")
  }
  // the cap is UTF-16 units, not characters: forty non-BMP name
  // characters are eighty units and must still clip. 31 fit (62 units)
  // plus the ellipsis makes 63.
  let astral_name = StringBuilder()
  for _ in 0..<40 {
    astral_name.write_char('\u{1D54F}')
  }
  let astral_source = "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><" +
    astral_name.to_string() +
    "/><w:footnote w:id=\"1\"><w:p/></w:footnote></w:footnotes>"
  let astral_described = segmentation_refusal_of(astral_source).describe()
  assert_eq(astral_described.length(), 24 + 63 + 15)
  guard astral_described.has_suffix("\u{2026} of w:footnotes") else {
    fail("expected the clipped astral name to end in an ellipsis")
  }
}

///|
test "document segmentation reads the body and tolerates a background" {
  // a direct w:background is presentation, not story content: allowed
  // but never read, exactly as production main-document reading
  // consumes only the body
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:background w:color="FF0000"/><w:body><w:p><w:r><w:t>a</w:t></w:r></w:p></w:body></w:document>
  // document=0 background=1 body=2 p=3 r=4 t=5
  guard project_segmented_story(source) is Projected(projection) else {
    fail("expected the document projection")
  }
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=3;runs=4;[0,1))t:a@5r0[0,1)
    ),
  )
}

///|
test "note segments isolate ownership: trailing flow text refuses" {
  // footnote 1 ends with a bare flow-level run; a plumbing separator
  // note leads the part and must not become a segment
  let source =
    #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:footnote w:type="separator" w:id="0"><w:p/></w:footnote><w:footnote w:id="1"><w:p><w:r><w:t>one</w:t></w:r></w:p><w:r><w:t>tail</w:t></w:r></w:footnote><w:footnote w:id="2"><w:p><w:r><w:t>two</w:t></w:r></w:p></w:footnote></w:footnotes>
  // footnotes=0 sep=1 p=2 fn1=3 p=4 r=5 t=6 r=7 t=8 fn2=9 p=10 r=11 t=12
  guard project_segmented_story(source)
    is ProjectionRefused(UnownedVisibleContribution(..) as refusal) else {
    fail("expected the unowned-content refusal")
  }
  inspect(
    refusal.describe(),
    content="visible content at source element 8 is owned by no paragraph",
  )
  // the flattened walk absorbs the same tail into the NEXT footnote's
  // first paragraph -- the exact cross-container leak the boundary stops
  guard project_flattened_notes(source) is Projected(flattened) else {
    fail("expected the flattened projection")
  }
  inspect(
    describe_projection(flattened),
    content=(
      #|p0(src=4;runs=5;[0,3))t:one@6r0[0,3)
      #|p1(src=10;runs=7,11;[5,12))t:tail@8r0[5,9) t:two@12r1[9,12)
    ),
  )
}

///|
test "note segments do not leak pending runs across containers" {
  // endnote 1 ends with an ATOMLESS flow-level run: structurally
  // registered, contributing nothing visible. All three plumbing note
  // kinds lead the part with visible text that must NOT project.
  let source =
    #|<w:endnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:endnote w:type="separator" w:id="0"><w:p><w:r><w:t>sep</w:t></w:r></w:p></w:endnote><w:endnote w:type="continuationSeparator" w:id="10"><w:p><w:r><w:t>cont</w:t></w:r></w:p></w:endnote><w:endnote w:type="continuationNotice" w:id="11"><w:p><w:r><w:t>notice</w:t></w:r></w:p></w:endnote><w:endnote w:id="1"><w:p><w:r><w:t>one</w:t></w:r></w:p><w:r/></w:endnote><w:endnote w:id="2"><w:p><w:r><w:t>two</w:t></w:r></w:p></w:endnote></w:endnotes>
  // endnotes=0 sep=1..4 cont=5..8 notice=9..12
  // en1=13 p=14 r=15 t=16 r=17 en2=18 p=19 r=20 t=21
  guard project_segmented_story(source) is Projected(segmented) else {
    fail("expected the segmented projection")
  }
  inspect(
    describe_projection(segmented),
    content=(
      #|p0(src=14;runs=15;[0,3))t:one@16r0[0,3)
      #|p1(src=19;runs=20;[5,8))t:two@21r0[5,8)
    ),
  )
  // the flattened walk leaks endnote 1's unflushed run into endnote 2's
  // first paragraph, shifting its run numbering
  guard project_flattened_notes(source) is Projected(flattened) else {
    fail("expected the flattened projection")
  }
  inspect(
    describe_projection(flattened),
    content=(
      #|p0(src=14;runs=15;[0,3))t:one@16r0[0,3)
      #|p1(src=19;runs=17,20;[5,8))t:two@21r1[5,8)
    ),
  )
}

///|
test "comment containers segment with continuous coordinates" {
  let source =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="1"><w:p><w:r><w:t>a</w:t></w:r></w:p></w:comment><w:comment w:id="2"><w:p><w:r><w:t>b</w:t></w:r></w:p></w:comment></w:comments>
  // comments=0 c1=1 p=2 r=3 t=4 c2=5 p=6 r=7 t=8
  guard project_segmented_story(source) is Projected(projection) else {
    fail("expected the comments projection")
  }
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=2;runs=3;[0,1))t:a@4r0[0,1)
      #|p1(src=6;runs=7;[3,4))t:b@8r0[3,4)
    ),
  )
}

///|
test "the budget-threaded join refuses on each stage's own budget" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t></w:r></w:p></w:body></w:document>
  let bytes = @utf8.encode(source)
  let tiny = @xml.xml_read_budget(
    max_source_units=8,
    max_tokens=2,
    max_materialized_chars=8,
    max_token_chars=8,
  )
  guard join_reader_input_story_limited(bytes[:], strict_budget=tiny)
    is Refused(StageRefused(stage=StrictGate, ..)) else {
    fail("expected the strict gate to spend its own budget")
  }
  guard join_reader_input_story_limited(bytes[:], tolerant_budget=tiny)
    is Refused(StageRefused(stage=TolerantDom, ..)) else {
    fail("expected the tolerant stage to spend its own budget")
  }
  guard join_reader_input_story_limited(bytes[:]) is Joined(_) else {
    fail("expected the unbudgeted join to succeed")
  }
}

///|
/// The PR 6c retention contract: a mutation-safe read keeps the
/// classified projection of every joined story part, keyed by part
/// path, while the AST comes from the SAME read.
test "a mutation-safe read retains a projection for every joined story part" {
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/footnotes.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml",
  )
  builder.add_override(
    "/word/comments.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rId2",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
    "footnotes.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rId3",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    "comments.xml",
    source="word/document.xml",
  )
  builder.add_part(
    "word/document.xml",
    @utf8.encode(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Body</w:t></w:r></w:p><w:sectPr/></w:body></w:document>
      ),
    ),
  )
  builder.add_part(
    "word/footnotes.xml",
    @utf8.encode(
      (
        #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:footnote w:id="1"><w:p><w:r><w:t>note</w:t></w:r></w:p></w:footnote></w:footnotes>
      ),
    ),
  )
  builder.add_part(
    "word/comments.xml",
    @utf8.encode(
      (
        #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="1" w:author="A"><w:p><w:r><w:t>c</w:t></w:r></w:p></w:comment></w:comments>
      ),
    ),
  )
  let annotated = read_docx_annotated(builder.build())
  let retained : Array[String] = []
  for path, _ in annotated.reader_projections {
    retained.push(path)
  }
  assert_eq(retained, [
    "word/comments.xml", "word/document.xml", "word/footnotes.xml",
  ])
  guard annotated.reader_projections.get("word/document.xml") is Some(main) else {
    fail("expected the main projection")
  }
  assert_eq(main.paragraphs.length(), 1)
  guard annotated.reader_projections.get("word/footnotes.xml") is Some(notes) else {
    fail("expected the footnotes projection")
  }
  assert_eq(notes.paragraphs.length(), 1)
  // and the notes/comments ASTs came through the same joined read
  assert_eq(annotated.footnote_bodies().length(), 1)
  assert_eq(annotated.comment_bodies().length(), 1)
}
