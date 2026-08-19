// Witnesses for the reader-native projection adapter (#434 PR 5.2):
// grouping, provenance, run addressing, UTF-16 coordinates, and the
// provenance refusals -- plus the partition property over the hostile
// generator.

///|
fn project_text_story(source : String) -> ReaderProjectionBuildResult raise {
  guard join_text_story(source) is Joined(story) else {
    fail("expected the story to join")
  }
  guard story.root.first("w:body") is Some(body) else {
    fail("expected a body")
  }
  let items = empty_body_reader({ relationships: [] }).read_children(
    body.element_children(),
  )
  project_reader_items("word/document.xml", story.scan, items)
}

///|
fn projection_of(source : String) -> ReaderProjection raise {
  guard project_text_story(source) is Projected(projection) else {
    fail("expected a projection")
  }
  projection
}

///|
fn describe_projection(projection : ReaderProjection) -> String {
  let parts : Array[String] = []
  for paragraph in projection.paragraphs {
    let sources : Array[String] = []
    for source in paragraph.sources {
      let SourceElementId(index) = source.source
      sources.push("\{index}")
    }
    let runs : Array[String] = []
    for run in paragraph.runs {
      let SourceElementId(index) = run.source
      runs.push("\{index}")
    }
    let contributions : Array[String] = []
    for contribution in paragraph.contributions {
      let SourceElementId(index) = contribution.source
      let kind = match contribution.kind {
        ProjectedText(_) => "t:" + contribution.value
        VisibleNonText => "v"
        Transparent => "b"
        SuppressedContent => "s"
      }
      contributions.push(
        "\{kind}@\{index}r\{contribution.logical_run_index}[\{contribution.projection_start},\{contribution.projection_end})",
      )
    }
    parts.push(
      "p\{paragraph.logical_index}(src=\{sources.join(",")};runs=\{runs.join(",")};[\{paragraph.projection_start},\{paragraph.projection_end}))" +
      contributions.join(" "),
    )
  }
  parts.join("\n")
}

///|
test "projection groups paragraphs, runs, and coordinates" {
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>ab</w:t><w:tab/></w:r><w:r/></w:p><w:p><w:r><w:t>c</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 r=3 t=4 tab=5 r=6 p=7 r=8 t=9
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=2;runs=3,6;[0,3))t:ab@4r0[0,2) t:	@5r0[2,3)
      #|p1(src=7;runs=8;[5,6))t:c@9r0[5,6)
    ),
  )
}

///|
test "projection joins flow-level text into the following paragraph" {
  // a body-level run before any paragraph: its text belongs to the next
  // paragraph, exactly as the erased partition behaves
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:r><w:t>flow</w:t></w:r><w:p><w:r><w:t>owned</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 r=2 t=3 p=4 r=5 t=6
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=4;runs=2,5;[0,9))t:flow@3r0[0,4) t:owned@6r1[4,9)
    ),
  )
}

///|
test "projection refuses trailing visible content and unjoined reads" {
  // trailing flow text after the final paragraph is owned by nothing
  guard project_text_story(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:r><w:t>tail</w:t></w:r></w:body></w:document>
      ),
    )
    is ProjectionRefused(UnownedVisibleContribution(..) as refusal) else {
    fail("expected an unowned-content refusal")
  }
  inspect(
    refusal.describe(),
    content="visible content at source element 4 is owned by no paragraph",
  )
  // an UNJOINED read carries no identities and refuses outright
  let xml =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t></w:r></w:p></w:body></w:document>
  let root = ReaderNode::of(
    read_xml_string(xml, namespace_map=office_namespace_map()),
  )
  guard root.first("w:body") is Some(body) else { fail("expected a body") }
  let items = empty_body_reader({ relationships: [] }).read_children(
    body.element_children(),
  )
  let scan = scan_projection_source_tree(@utf8.encode(xml))
  guard project_reader_items("word/document.xml", scan, items)
    is ProjectionRefused(MissingSourceIdentity(..)) else {
    fail("expected a missing-identity refusal")
  }
}

///|
test "projection keeps a run addressable across a nested paragraph" {
  // a tolerated nested paragraph inside a run: the run participates in
  // both logical paragraphs, keeping one identity
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>pre</w:t><w:p><w:r><w:t>inner</w:t></w:r></w:p><w:t>post</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 r=3 t=4 p=5 r=6 t=7 t=8
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=2,5;runs=3,6;[0,8))t:pre@4r0[0,3) t:inner@7r1[3,8)
      #|p1(src=2;runs=3;[10,14))t:post@8r0[10,14)
    ),
  )
}

///|
test "projection separates textbox extras and registers empty runs" {
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>boxed</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 r=3 pict=4 shape=5 textbox=6 txbx=7 p=8 r=9 t=10
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=2;runs=3;[0,0))s@4r0[0,0)
      #|p1(src=8;runs=9;[2,7))t:boxed@10r0[2,7)
    ),
  )
}

///|
test "projection measures astral characters in UTF-16 units" {
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>𝔘x</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // the astral character occupies two UTF-16 units
  inspect(projection.paragraphs[0].contributions[0].projection_end, content="3")
}

///|
/// Does the erased tree contain visible content no paragraph ever owns?
/// Visible content OUTSIDE a paragraph is absorbed by the next paragraph
/// close in flatten order (flow-level content joins the following
/// paragraph); only visible content with NO later paragraph close is
/// unowned -- the independent oracle for `UnownedVisibleContribution`.
fn erased_walk_unowned(
  elements : Array[DocumentElement],
  inside_paragraph : Bool,
  state : ErasedUnownedState,
) -> Unit {
  for element in elements {
    match element {
      Paragraph(children~, ..) => {
        erased_walk_unowned(children, true, state)
        // this close absorbs every pending outside-visible before it
        state.pending_outside = false
      }
      Run(children~, ..)
      | Hyperlink(children~, ..)
      | Table(children~, ..)
      | TableRow(children~, ..)
      | TableCell(children~, ..) =>
        erased_walk_unowned(children, inside_paragraph, state)
      Text(value) =>
        if !inside_paragraph && value.length() > 0 {
          state.pending_outside = true
        }
      Checkbox(_)
      | Image(_)
      | NoteReference(..)
      | CommentReference(_)
      | Break(_)
      | Tab => if !inside_paragraph { state.pending_outside = true }
      _ => ()
    }
  }
}

///|
priv struct ErasedUnownedState {
  mut pending_outside : Bool
}

///|
fn erased_has_unowned_visible(
  elements : Array[DocumentElement],
  inside_paragraph : Bool,
) -> Bool {
  let state : ErasedUnownedState = { pending_outside: false }
  erased_walk_unowned(elements, inside_paragraph, state)
  state.pending_outside
}

///|
/// A paragraph whose own text contains the separator must not be split.
///
/// `"a\n\nb"` in a single `w:t` serialises exactly like two paragraphs
/// holding `"a"` and `"b"`, so flat story equality cannot tell them
/// apart. A projection that split the first would invent a `p[1]` that
/// surgery could address and the reader has never heard of. The expected
/// counts come from the source, not from either side's output.
test "a separator inside one paragraph does not split it" {
  let document = fn(body : String) -> String {
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>\{body}</w:body></w:document>"
  }
  let joined = document("<w:p><w:r><w:t>a&#10;&#10;b</w:t></w:r></w:p>")
  let split = document(
    "<w:p><w:r><w:t>a</w:t></w:r></w:p><w:p><w:r><w:t>b</w:t></w:r></w:p>",
  )
  // identical stories
  assert_eq(current_reader_story_text(joined), "a\n\nb\n\n")
  assert_eq(current_reader_story_text(split), "a\n\nb\n\n")
  // and distinguishable structures
  assert_eq(projection_of(joined).paragraphs.length(), 1)
  assert_eq(projection_of(split).paragraphs.length(), 2)
}

///|
/// The adapter's text partition equals the erased reader's own paragraph
/// partition on every joinable generated document -- the same oracle the
/// effect stream satisfies, now through grouping, coordinates, and
/// provenance.
test "projection partitions generated documents like the reader" {
  @quickcheck.check(
    (seeds : Array[Int]) => {
      let source = hostile_document(seeds)
      guard join_text_story(source) is Joined(story) else {
        fail("expected the story to join")
      }
      let node = story.root
      let children = match node.first("w:body") {
        Some(body) => body.element_children()
        None => node.element_children()
      }
      let items = empty_body_reader({ relationships: [] }).read_children(
        children,
      )
      let projection = match
        project_reader_items("word/document.xml", story.scan, items) {
        Projected(projection) => projection
        // visible content no paragraph owns is a TYPED refusal by design
        // (the fourth pinned divergence class); require the independent
        // erased-tree oracle to agree the content really is unowned
        ProjectionRefused(UnownedVisibleContribution(..)) => {
          assert_true(
            erased_has_unowned_visible(reader_items_to_elements(items), false),
          )
          return true
        }
        ProjectionRefused(refusal) => fail("refused: " + refusal.describe())
      }
      let texts : Array[String] = []
      for paragraph in projection.paragraphs {
        let text = StringBuilder()
        for contribution in paragraph.contributions {
          text.write_string(contribution.value)
        }
        texts.push(text.to_string())
      }
      assert_eq(texts, reader_paragraph_texts(source))
      // successful projections must have NO unowned visible content: the
      // refusal oracle is two-sided
      assert_false(
        erased_has_unowned_visible(reader_items_to_elements(items), false),
      )
      // every contribution's run index agrees with its run's record, and
      // run records number 0..n in first-appearance order
      for paragraph in projection.paragraphs {
        for index, run in paragraph.runs {
          assert_eq(run.logical_index, index)
        }
        for contribution in paragraph.contributions {
          match contribution.run_source {
            Some(run_source) => {
              let mut matched = false
              for run in paragraph.runs {
                if run.source == run_source {
                  assert_eq(contribution.logical_run_index, run.logical_index)
                  matched = true
                  break
                }
              }
              assert_true(matched)
            }
            None => assert_eq(contribution.logical_run_index, -1)
          }
        }
      }
      // and the intervals tile the story: each paragraph's interval is
      // exactly its text length, separated by two units
      let mut offset = 0
      for paragraph in projection.paragraphs {
        assert_eq(paragraph.projection_start, offset)
        offset = paragraph.projection_end + reader_projection_separator_units
      }
      true
    },
    count=64,
    max_size=60,
    seed=0x646F_6378_70UL,
  )
}

///|
/// An atomless run occupies its first-appearance position: the legacy
/// walker's zero-width run-open seams made empty runs addressable, and
/// the run records reproduce that numbering.
test "projection numbers atomless runs into the addressing order" {
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r/><w:r><w:t>x</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 r=3 r=4 t=5: the empty run is r0, the text run
  // r1, and the text contribution addresses r1
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=2;runs=3,4;[0,1))t:x@5r1[0,1)
    ),
  )
  inspect(projection.paragraphs[0].runs[0].logical_index, content="0")
  inspect(projection.paragraphs[0].runs[1].logical_index, content="1")
}

///|
/// A synthesized field-checkbox run whose carrier is not physically a
/// `w:r` has no run-shaped address: typed refusal, never a fake run.
test "projection refuses a non-run synthesized checkbox carrier" {
  guard project_text_story(
      (
        #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="a"><w:r><w:fldChar w:fldCharType="begin"/></w:r></w:hyperlink><w:r><w:instrText> FORMCHECKBOX </w:instrText></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
      ),
    )
    is ProjectionRefused(SourceShapeMismatch(..) as refusal) else {
    fail("expected a shape refusal")
  }
  inspect(
    refusal.describe(),
    content="source element 3 is a hyperlink, not the w:r its role requires",
  )
}

///|
/// The adapter carries its own cumulative caps.
test "projection budgets bound the build" {
  let xml =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t></w:r></w:p></w:body></w:document>
  guard join_text_story(xml) is Joined(story) else {
    fail("expected the story to join")
  }
  guard story.root.first("w:body") is Some(body) else {
    fail("expected a body")
  }
  let items = empty_body_reader({ relationships: [] }).read_children(
    body.element_children(),
  )
  let starved : ReaderProjectionBudget = {
    visits_left: 2,
    contributions_left: 1024,
    retained_left: 1024,
  }
  let outcome = try {
    ignore(
      project_reader_items(
        "word/document.xml",
        story.scan,
        items,
        budget=starved,
      ),
    )
    "completed"
  } catch {
    // budget exhaustion is a TYPED resource ceiling (#434 PR 6c), so
    // the machine class survives into public error taxonomies
    ResourceLimit(limit=DocxXmlTokens, ..) => "resource limit: DocxXmlTokens"
    _ => "other error"
  }
  inspect(outcome, content="resource limit: DocxXmlTokens")
}

///|
/// Two nested paragraphs inside ONE inline container: each is its own
/// block element, so the enclosing physical paragraph participates in the
/// first flush of EACH -- the legacy walker re-ensures the outer source
/// after every consumed block.
test "projection rearms the outer paragraph for every nested block" {
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:hyperlink w:anchor="a"><w:p><w:r><w:t>A</w:t></w:r></w:p><w:p><w:r><w:t>B</w:t></w:r></w:p></w:hyperlink></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 hyperlink=3 pA=4 rA=5 tA=6 pB=7 rB=8 tB=9
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=2,4;runs=5;[0,1))b@3r-1[0,0) t:A@6r0[0,1)
      #|p1(src=2,7;runs=8;[3,4))t:B@9r0[3,4)
      #|p2(src=2;runs=;[6,6))
    ),
  )
}

///|
/// A table inside an open run: the outer run reaches the MERGED first
/// paragraph (its content preceded the block) and the suffix paragraph,
/// but never leaks into the table's later standalone paragraphs.
test "projection scopes open runs at block boundaries" {
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>pre</w:t><w:tbl><w:tr><w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:t>post</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 r=3 t=4 tbl=5 tr=6 tc=7 pA=8 rA=9 tA=10
  // pB=11 rB=12 tB=13 t(post)=14
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=2,8;runs=3,9;[0,4))t:pre@4r0[0,3) t:A@10r1[3,4)
      #|p1(src=11;runs=12;[6,7))t:B@13r0[6,7)
      #|p2(src=2;runs=3;[9,13))t:post@14r0[9,13)
    ),
  )
}

///|
/// A textbox extra of a paragraph nested inside an open run gets ONLY its
/// own run: the outer run reopens after the paragraph's whole output --
/// extras included -- has been consumed. (The textbox appears twice: the
/// nested paragraph's extras pass re-homes it, and the OUTER paragraph's
/// own extras pass re-homes it once more -- the reader's verified erased
/// behaviour.)
test "projection extras do not inherit the enclosing run" {
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r><w:t>pre</w:t><w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>boxed</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p><w:t>post</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 r=3 t(pre)=4 nested-p=5 r=6 pict=7 shape=8
  // textbox=9 txbx=10 boxed-p=11 r=12 t=13 t(post)=14
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=2,5;runs=3,6;[0,3))t:pre@4r0[0,3) s@7r1[3,3)
      #|p1(src=11;runs=12;[5,10))t:boxed@13r0[5,10)
      #|p2(src=2;runs=3;[12,16))t:post@14r0[12,16)
      #|p3(src=11;runs=12;[18,23))t:boxed@13r0[18,23)
    ),
  )
}

///|
/// Two tolerated direct rows inside one paragraph: each is its own block
/// element, so the outer paragraph participates in both first flushes.
test "projection rearms for direct inline rows" {
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:tr><w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:p><w:r><w:t>B</w:t></w:r></w:p></w:tc></w:tr></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 tr=3 tc=4 pA=5 rA=6 tA=7 tr=8 tc=9 pB=10 rB=11 tB=12
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=2,5;runs=6;[0,1))t:A@7r0[0,1)
      #|p1(src=2,10;runs=11;[3,4))t:B@12r0[3,4)
      #|p2(src=2;runs=;[6,6))
    ),
  )
}

///|
/// READER-NATIVE DIVERGENCE, pinned deliberately: an open HYPERLINK field
/// hoists a nested paragraph's extras into independent sibling hyperlink
/// items (the erase-grouping the reader itself performs), so the adapter
/// treats each as its own block element and the outer paragraph
/// participates in the hoisted extra's flush. The legacy walker, which
/// models the PHYSICAL shape, keeps that extra standalone. The reader-
/// native projection records what the reader did; the shadow comparator
/// carries this shape on its allowlist.
test "projection field-hoisted extras are reader-native block items" {
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:v="urn:schemas-microsoft-com:vml"><w:body><w:p><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> HYPERLINK "https://e" </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent><w:p><w:r><w:t>X</w:t></w:r></w:p></w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p></w:body></w:document>
    ),
  )
  let described : Array[String] = []
  for paragraph in projection.paragraphs {
    let sources : Array[String] = []
    for source in paragraph.sources {
      let SourceElementId(index) = source.source
      sources.push("\{index}")
    }
    described.push(sources.join(","))
  }
  // document=0 body=1 p=2 r(begin)=3..; nested p=9; boxed p=15
  // the hoisted textbox extra (physical paragraph 15) carries the outer
  // source 2 here, where the legacy walker keeps it standalone
  inspect(
    described.join(" ; "),
    content=(
      #|2,9 ; 2,15 ; 2 ; 15
    ),
  )
}

///|
/// A tolerated direct cell inside a paragraph arms it like any block.
test "projection rearms for a direct inline cell" {
  let projection = projection_of(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 tc=3 pA=4 rA=5 tA=6
  inspect(
    describe_projection(projection),
    content=(
      #|p0(src=2,4;runs=5;[0,1))t:A@6r0[0,1)
      #|p1(src=2;runs=;[3,3))
    ),
  )
}
