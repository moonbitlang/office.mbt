// Witnesses for the DOM <-> physical join (#434 PR 3). Success cases pin
// the cooked-children rule and the name canonicalization; refusal cases pin
// each disagreement class; the invariants function is applied to every
// hostile generated document.

///|
fn join_text_story(source : String) -> ReaderInputJoinResult {
  join_reader_input_story(@utf8.encode(source)[:])
}

///|
fn joined_preorder_ids(node : JoinedReaderNode, out : Array[Int]) -> Unit {
  let SourceElementId(index) = node.source_element_id
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
  fn check(node : JoinedReaderNode) -> Unit raise {
    let SourceElementId(index) = node.source_element_id
    let source = story.scan.elements()[index]
    assert_eq(
      node.element.name,
      reader_join_dom_name(source.uri, source.local_name),
    )
    for child in node.children {
      let SourceElementId(child_index) = child.source_element_id
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
      #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><!-- note --><w:p>stray<w:r><w:t>a&amp;b</w:t></w:r></w:p></w:body></w:document>
    ),
  )
  let ids : Array[Int] = []
  joined_preorder_ids(story.root, ids)
  debug_inspect(ids, content="[0, 1, 2, 3, 4]")
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
        // hostile documents are tolerant-first by construction; a stage
        // refusal (strict gate or scanner) is a legitimate outcome, but a
        // JOIN mismatch on scanner-accepted input is exactly the bug class
        // this property exists to catch
        Refused(StageRefused(..)) => ()
        Refused(refusal) => fail("join mismatch: " + refusal.describe())
      }
      true
    },
    count=64,
    max_size=60,
    seed=0x646F_6378_70UL,
  )
}
