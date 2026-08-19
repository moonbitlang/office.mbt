// Witnesses for the DOM <-> physical join (#434 PR 3). Success cases pin
// the cooked-children rule and the name canonicalization; refusal cases pin
// each disagreement class; the invariants function is applied to every
// hostile generated document.

///|
fn join_text_story(source : String) -> ReaderInputJoinResult {
  join_reader_input_story(@utf8.encode(source)[:])
}

///|
fn joined_preorder_ids(node : ReaderNode, out : Array[Int]) -> Unit raise {
  guard node.source_element_id is Some(SourceElementId(index)) else {
    fail("a joined node carries no physical identity")
  }
  out.push(index)
  for child in node.children {
    joined_preorder_ids(child, out)
  }
}

///|
fn count_dom_elements(element : XmlElement) -> Int {
  let mut count = 1
  for child in element.children {
    if child is XmlElement(child_element) {
      count = count + count_dom_elements(child_element)
    }
  }
  count
}

///|
/// Every invariant a successful join guarantees: one node per DOM element,
/// identities unique and strictly increasing in DOM preorder, names agreeing
/// under the canonical rule, and every child's physical span inside its DOM
/// parent's span (MC splicing keeps fallback content physically inside the
/// construct, which is inside the DOM parent).
fn assert_join_invariants(story : JoinedReaderStory) -> Unit raise {
  let ids : Array[Int] = []
  joined_preorder_ids(story.root, ids)
  assert_eq(ids.length(), count_dom_elements(story.root.element))
  for index in 1..<ids.length() {
    assert_true(ids[index] > ids[index - 1])
  }
  fn check(node : ReaderNode) -> Unit raise {
    guard node.source_element_id is Some(SourceElementId(index)) else {
      fail("a joined node carries no physical identity")
    }
    let source = story.scan.elements()[index]
    assert_true(
      reader_join_dom_name_matches(
        office_namespace_map(),
        source.uri,
        source.local_name,
        node.element.name,
      ),
    )
    for child in node.children {
      guard child.source_element_id is Some(SourceElementId(child_index)) else {
        fail("a joined node carries no physical identity")
      }
      let child_source = story.scan.elements()[child_index]
      assert_true(child_source.byte_start >= source.byte_start)
      assert_true(child_source.byte_end <= source.byte_end)
      check(child)
    }
  }

  check(story.root)
}

///|
fn assert_joined(source : String) -> JoinedReaderStory raise {
  match join_text_story(source) {
    Joined(story) => {
      assert_join_invariants(story)
      story
    }
    Refused(refusal) => fail("unexpected refusal: " + refusal.describe())
  }
}

///|
test "join pairs plain stories across namespace spellings" {
  // Transitional URI, canonical prefixes
  let transitional = assert_joined(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t></w:r></w:p><w:p/></w:body></w:document>
    ),
  )
  let ids : Array[Int] = []
  joined_preorder_ids(transitional.root, ids)
  debug_inspect(ids, content="[0, 1, 2, 3, 4, 5]")
  // Strict OOXML URI canonicalizes to the same prefix on both sides
  let strict_uri = assert_joined(
    (
      #|<x:document xmlns:x="http://purl.oclc.org/ooxml/wordprocessingml/main"><x:body><x:p/></x:body></x:document>
    ),
  )
  inspect(strict_uri.root.element.name, content="w:document")
  // an arbitrary prefix bound to the Transitional URI
  let renamed = assert_joined(
    (
      #|<zz:document xmlns:zz="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><zz:body><zz:p/></zz:body></zz:document>
    ),
  )
  inspect(renamed.root.element.name, content="w:document")
  // unknown namespace joins through the braced form; no-namespace joins bare
  let foreign = assert_joined(
    (
      #|<q:root xmlns:q="urn:example:unknown"><q:leaf/></q:root>
    ),
  )
  inspect(foreign.root.element.name, content="{urn:example:unknown}root")
  let bare = assert_joined("<root><leaf/></root>")
  inspect(bare.root.element.name, content="root")
}

///|
test "join ignores comments, PIs, text, CDATA, and entities between elements" {
  let story = assert_joined(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><!-- note --><?pi data?><w:p>stray<w:r><w:t><![CDATA[a]]></w:t><w:t>a&amp;b</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  let ids : Array[Int] = []
  joined_preorder_ids(story.root, ids)
  debug_inspect(ids, content="[0, 1, 2, 3, 4, 5]")
}

///|
test "join cooks alternate content like the parser, whatever the prefix" {
  // literal mc:, canonical shape: wrapper, choice, and fallback wrapper all
  // vanish from the cooked view; the fallback's content pairs with its
  // ORIGINAL physical identities
  let literal =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><w:body><w:p/><mc:AlternateContent><mc:Choice Requires="wps"><w:p><w:r><w:t>choice</w:t></w:r></w:p></mc:Choice><mc:Fallback><w:p><w:r><w:t>fallback</w:t></w:r></w:p></mc:Fallback></mc:AlternateContent><w:p/></w:body></w:document>
  let story = assert_joined(literal)
  let ids : Array[Int] = []
  joined_preorder_ids(story.root, ids)
  // document=0 body=1 p=2 | AC=3 Choice=4 p=5 r=6 t=7 | Fallback=8 p=9
  // r=10 t=11 | p=12 -- the cooked view keeps 0,1,2 then the fallback
  // subtree 9,10,11 then 12
  debug_inspect(ids, content="[0, 1, 2, 9, 10, 11, 12]")
  // an alternate prefix bound to the MC URI splices identically
  let renamed =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:zz="http://schemas.openxmlformats.org/markup-compatibility/2006"><w:body><w:p/><zz:AlternateContent><zz:Choice Requires="wps"><w:p><w:r><w:t>choice</w:t></w:r></w:p></zz:Choice><zz:Fallback><w:p><w:r><w:t>fallback</w:t></w:r></w:p></zz:Fallback></zz:AlternateContent><w:p/></w:body></w:document>
  let renamed_story = assert_joined(renamed)
  let renamed_ids : Array[Int] = []
  joined_preorder_ids(renamed_story.root, renamed_ids)
  debug_inspect(renamed_ids, content="[0, 1, 2, 9, 10, 11, 12]")
}

///|
test "join alternate content edge shapes" {
  // no fallback: the construct contributes nothing
  let no_fallback = assert_joined(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><w:body><mc:AlternateContent><mc:Choice Requires="wps"><w:p/></mc:Choice></mc:AlternateContent><w:p/></w:body></w:document>
    ),
  )
  let no_fallback_ids : Array[Int] = []
  joined_preorder_ids(no_fallback.root, no_fallback_ids)
  // document=0 body=1 AC=2 Choice=3 p=4 p=5
  debug_inspect(no_fallback_ids, content="[0, 1, 5]")
  // nested alternate content inside the selected fallback cooks recursively
  let nested = assert_joined(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><w:body><mc:AlternateContent><mc:Fallback><mc:AlternateContent><mc:Fallback><w:p/></mc:Fallback></mc:AlternateContent></mc:Fallback></mc:AlternateContent></w:body></w:document>
    ),
  )
  let nested_ids : Array[Int] = []
  joined_preorder_ids(nested.root, nested_ids)
  // document=0 body=1 AC=2 Fallback=3 AC=4 Fallback=5 p=6
  debug_inspect(nested_ids, content="[0, 1, 6]")
  // a root AlternateContent is never spliced and pairs normally
  let root_mc = assert_joined(
    (
      #|<mc:AlternateContent xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><mc:Choice Requires="wps"><w:p/></mc:Choice><mc:Fallback><w:p/></mc:Fallback></mc:AlternateContent>
    ),
  )
  inspect(root_mc.root.element.name, content="mc:AlternateContent")
  let root_ids : Array[Int] = []
  joined_preorder_ids(root_mc.root, root_ids)
  debug_inspect(root_ids, content="[0, 1, 2, 3, 4]")
  // AlternateContent OUTSIDE the MC namespace is an ordinary element
  let ordinary = assert_joined(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:AlternateContent><w:p/></w:AlternateContent></w:body></w:document>
    ),
  )
  let ordinary_ids : Array[Int] = []
  joined_preorder_ids(ordinary.root, ordinary_ids)
  debug_inspect(ordinary_ids, content="[0, 1, 2, 3]")
}

///|
test "join refuses at the strict gate what tolerant parsing recovers" {
  // unclosed tag: tolerant recovers, strict refuses
  guard join_text_story(
      "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p></w:body></w:document>",
    )
    is Refused(StageRefused(stage=StrictGate, ..) as refusal) else {
    fail("expected a strict-gate refusal")
  }
  assert_true(refusal.describe().has_prefix("refused at strict-gate: "))
  // unbound prefix: tolerant keeps the raw name, strict refuses -- this is
  // what keeps the unbound-literal-mc splice out of the join's domain
  guard join_text_story(
      "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><zz:p/></w:body></w:document>",
    )
    is Refused(StageRefused(stage=StrictGate, ..)) else {
    fail("expected a strict-gate refusal for the unbound prefix")
  }
}

///|
test "join surfaces scanner refusals" {
  // mixed CDATA/text w:t content: the DOM parses it, the scanner refuses
  let refusal = join_text_story(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a<![CDATA[b]]></w:t></w:r></w:p></w:body></w:document>
    ),
  )
  guard refusal is Refused(StageRefused(stage=SourceScan, ..) as inner) else {
    fail("expected a source-scan refusal")
  }
  inspect(
    inner.describe(),
    content="refused at source-scan: Unsupported: projection source scanner: mixed CDATA/text w:t content has no simple-text reader projection",
  )
}

///|
test "join refuses structural disagreement instead of guessing" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:p/></w:body></w:document>
  let scan = scan_projection_source_tree(@utf8.encode(source)[:])
  // a DOM with one child MISSING under body
  let fewer = read_xml_string(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/></w:body></w:document>
    ),
    namespace_map=office_namespace_map(),
  )
  guard join_reader_dom(fewer, scan)
    is Refused(
      ChildCountMismatch(
        parent=SourceElementId(1),
        dom_count=1,
        cooked_source_count=2
      )
    ) else {
    fail("expected a child count mismatch under body")
  }
  // a DOM with one name CHANGED without changing structure
  let renamed = read_xml_string(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:tbl/></w:body></w:document>
    ),
    namespace_map=office_namespace_map(),
  )
  guard join_reader_dom(renamed, scan)
    is Refused(NameMismatch(source=SourceElementId(3), dom_name="w:tbl", ..)) else {
    fail("expected a name mismatch at the second paragraph")
  }
}

///|
test "join generated documents and hold every invariant" {
  @quickcheck.check(
    (seeds : Array[Int]) => {
      let source = hostile_document(seeds)
      match join_text_story(source) {
        Joined(story) => assert_join_invariants(story)
        // the generator emits strict-valid, scanner-supported documents:
        // every one must join, so a stage regression cannot quietly turn
        // this property vacuous
        Refused(refusal) => fail("refused: " + refusal.describe())
      }
      true
    },
    count=64,
    max_size=60,
    seed=0x646F_6378_70UL,
  )
}

///|
/// The parser cooks an AlternateContent's children BEFORE searching them
/// for the fallback, so a fallback PROMOTED out of a nested construct wins
/// over a physically-direct one that appears later. Pairing against the
/// direct child alone would silently bind the DOM element to the wrong
/// physical identity (both are named x here).
test "join selects the promoted fallback like the parser" {
  let story = assert_joined(
    (
      #|<r xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"><mc:AlternateContent><mc:AlternateContent><mc:Fallback><mc:Fallback><x id="inner"/></mc:Fallback></mc:Fallback></mc:AlternateContent><mc:Fallback><x id="outer"/></mc:Fallback></mc:AlternateContent></r>
    ),
  )
  // r=0, outer AC=1, inner AC=2, Fallback=3, Fallback=4, inner x=5,
  // outer Fallback=6, outer x=7. The inner AC cooks to [Fallback@4], which
  // becomes the outer construct's FIRST fallback; its child x@5 is the one
  // the DOM contains.
  let ids : Array[Int] = []
  joined_preorder_ids(story.root, ids)
  debug_inspect(ids, content="[0, 5]")
  guard story.root.children[0].element.attributes.get("id") is Some("inner") else {
    fail("expected the inner x to be the selected one")
  }
}

///|
/// Two name shapes the strict gate accepts whose tolerant spelling differs
/// from the mapped canonical form: the implicit `xml:` binding (tolerant
/// keeps the raw name) and an explicit empty default namespace (tolerant
/// cooks the braced-empty form).
test "join accepts implicit xml prefixes and explicit empty namespaces" {
  // inside a normal-sized story: the join's input-linear strict budget is
  // deliberately tight, and implicit-namespace expansion of a bare
  // three-element document exceeds it before the name rule is ever reached
  let implicit_xml = assert_joined(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><xml:r><xml:c/></xml:r></w:p></w:body></w:document>
    ),
  )
  inspect(
    implicit_xml.root.children[0].children[0].children[0].element.name,
    content="xml:r",
  )
  let empty_default = assert_joined(
    (
      #|<r xmlns=""><c/></r>
    ),
  )
  let ids : Array[Int] = []
  joined_preorder_ids(empty_default.root, ids)
  debug_inspect(ids, content="[0, 1]")
}

///|
/// A corrupted physical table refuses instead of joining: fail-closed on
/// shapes no real scan emits. Links are mutable, so a real scan's table is
/// corrupted in place.
test "join refuses corrupted physical tables" {
  let source =
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:tbl/></w:body></w:document>
  let dom = read_xml_string(source, namespace_map=office_namespace_map())
  fn corrupted(mutate : (Array[ScannedElement]) -> Unit) -> String raise {
    let scan = scan_projection_source_tree(@utf8.encode(source))
    mutate(scan.elements())
    guard join_reader_dom(dom, scan)
      is Refused(StructureMismatch(..) as refusal) else {
      fail("expected a structure refusal")
    }
    refusal.describe()
  }

  // document=0 body=1 p=2 tbl=3
  inspect(
    corrupted(elements => elements[1].first_child_index = -1),
    content="structure mismatch: only 2 of 4 elements are reachable from the root",
  )
  inspect(
    corrupted(elements => elements[0].next_sibling_index = 1),
    content="structure mismatch: root element has a sibling 1",
  )
  // swap the sibling order under body: parents still agree, but the table
  // is no longer in opening-tag preorder
  inspect(
    corrupted(elements => {
      elements[1].first_child_index = 3
      elements[3].next_sibling_index = 2
      elements[2].next_sibling_index = -1
    }),
    content="structure mismatch: element 3 sits at preorder position 2; the table is not in opening-tag order",
  )
}

///|
/// The accessors navigate the cached tree, so identities survive every
/// access path; a synthetic `first_or_empty` miss carries none.
test "joined identities survive the reader accessors" {
  let story = assert_joined(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:t>a</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 pPr=3 jc=4 r=5 t=6
  guard story.root.first("w:body") is Some(body) else {
    fail("expected a body")
  }
  debug_inspect(body.source_element_id, content="Some(SourceElementId(1))")
  let paragraph = body.element_children()[0]
  debug_inspect(paragraph.source_element_id, content="Some(SourceElementId(2))")
  debug_inspect(
    paragraph.first_or_empty("w:pPr").source_element_id,
    content="Some(SourceElementId(3))",
  )
  debug_inspect(
    paragraph.elements_by_tag_name("w:r")[0].source_element_id,
    content="Some(SourceElementId(5))",
  )
  // a metadata miss synthesizes a node with no identity
  debug_inspect(
    paragraph.first_or_empty("w:sectPr").source_element_id,
    content="None",
  )
}

///|
/// The payoff: a joined story read by the ACTUAL BodyReader produces an
/// effect stream whose source nodes carry physical identities -- the
/// provenance the projection re-derived from bytes now falls out of the
/// read itself.
test "reading a joined story yields effects with physical identities" {
  let story = assert_joined(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>a</w:t><w:tab/></w:r></w:p><w:p><w:r><w:t>b</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 r=3 t=4 tab=5 p=6 r=7 t=8
  guard story.root.first("w:body") is Some(body) else {
    fail("expected a body")
  }
  let items = empty_body_reader({ relationships: [] }).read_children(
    body.element_children(),
  )
  let labelled : Array[String] = []
  for effect in collect_reader_effects(items) {
    let (kind, source) = match effect {
      ProjectsText(source~, kind=_, value~) => ("text=" + value, source)
      ProjectsVisibleNonText(source~) => ("nontext", source)
      TransparentBoundary(source~) => ("boundary", source)
      Suppressed(source~) => ("suppressed", source)
    }
    let id = match source.source_element_id {
      Some(SourceElementId(index)) => "\{index}"
      None => "-"
    }
    labelled.push("\{kind}@\{id}")
  }
  inspect(labelled.join(" ; "), content="text=a@4 ; text=\t@5 ; text=b@8")
  // and the produced trees' own sources carry identities too
  guard items[0]
    is New({ source: paragraph_source, local_effects: _, shape: _ }) else {
    fail("expected a paragraph tree")
  }
  debug_inspect(
    paragraph_source.source_element_id,
    content="Some(SourceElementId(2))",
  )
}

///|
/// The rebuilding transforms (vMerge, checkbox replacement) construct new
/// trees from their inputs' sources -- physical identities must survive
/// the rebuild, and a suppression records the identity of what it removed.
test "joined identities survive the rebuilding transforms" {
  let story = assert_joined(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr><w:p><w:r><w:t>top</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>under</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:p><w:r><w:sdt><w:sdtPr><w14:checkbox><w14:checked w14:val="1"/></w14:checkbox></w:sdtPr><w:sdtContent><w:t>replaced</w:t></w:sdtContent></w:sdt></w:r></w:p></w:body></w:document>
    ),
  )
  guard story.root.first("w:body") is Some(body) else {
    fail("expected a body")
  }
  let items = empty_body_reader({ relationships: [] }).read_children(
    body.element_children(),
  )
  // document=0 body=1 tbl=2 tr=3 tc=4 tcPr=5 vMerge=6 p=7 r=8 t=9
  // tr=10 tc=11 tcPr=12 vMerge=13 p=14 r=15 t=16
  // p=17 r=18 sdt=19 sdtPr=20 checkbox=21 checked=22 sdtContent=23 t=24
  let labelled : Array[String] = []
  for effect in collect_reader_effects(items) {
    let (kind, source) = match effect {
      ProjectsText(source~, kind=_, value~) => ("text=" + value, source)
      ProjectsVisibleNonText(source~) => ("nontext", source)
      TransparentBoundary(source~) => ("boundary", source)
      Suppressed(source~) => ("suppressed", source)
    }
    let id = match source.source_element_id {
      Some(SourceElementId(index)) => "\{index}"
      None => "-"
    }
    labelled.push("\{kind}@\{id}")
  }
  // the vMerge suppression carries the REMOVED cell's identity (11); the
  // checkbox replacement suppresses the replaced text (24) and stands
  // visible at the same node
  inspect(
    labelled.join(" ; "),
    content="boundary@5 ; text=top@9 ; suppressed@11 ; boundary@19 ; boundary@20 ; suppressed@24 ; nontext@24",
  )
}

///|
/// A deleted-paragraph join records every physical source paragraph WITH
/// its own ordered carriers -- the structure per-paragraph field
/// classification observes -- while the children stream still reads the
/// concatenation.
test "joined paragraph inputs record the deleted prefix paragraphs" {
  let story = assert_joined(
    (
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:pPr><w:rPr><w:del/></w:rPr></w:pPr><w:r><w:t>joined </w:t></w:r></w:p><w:p><w:r><w:t>tail</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  // document=0 body=1 p=2 pPr=3 rPr=4 del=5 r=6 t=7 p=8 r=9 t=10
  guard story.root.first("w:body") is Some(body) else {
    fail("expected a body")
  }
  let items = empty_body_reader({ relationships: [] }).read_children(
    body.element_children(),
  )
  guard items[0]
    is New(
      {
        source: _,
        local_effects: _,
        shape: ReaderParagraph(inputs~, children~, extras=_, properties=_),
      }
    ) else {
    fail("expected the joined paragraph")
  }
  let described : Array[String] = []
  for input in inputs {
    let paragraph_id = match input.paragraph.source_element_id {
      Some(SourceElementId(index)) => "\{index}"
      None => "-"
    }
    let carrier_ids : Array[String] = []
    for carrier in input.carriers {
      carrier_ids.push(
        match carrier.source_element_id {
          Some(SourceElementId(index)) => "\{index}"
          None => "-"
        },
      )
    }
    described.push("p@\{paragraph_id}[\{carrier_ids.join(",")}]")
  }
  // the deleted paragraph (2) owns pPr(3) and r(6); the terminal (8) owns
  // r(9)
  inspect(described.join(" ; "), content="p@2[3,6] ; p@8[9]")
  // and the joined children stream still erases to the concatenated text
  inspect(
    convert_document_to_html(document(reader_items_to_elements(items))).value,
    content="<p>joined tail</p>",
  )
}
