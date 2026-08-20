// PR 3 of the reader unification (#434): the DOM <-> physical join.
//
// One story part is read three ways: the strict parser gates mutation
// safety, the byte scanner extracts physical identities and spans, and the
// tolerant parser builds the DOM the reader walks. The join pairs every DOM
// element with its physical `ScannedElement` identity by walking both trees
// in lockstep; any disagreement is a refusal, never a guess. PR 4 threads
// the paired identity into `ReaderNode`; until then the join is new
// machinery with no production caller.
//
// The one structural transform the join must model: the tolerant parser
// splices a CHILD `mc:AlternateContent` into its first `mc:Fallback`'s
// children at parse time, and it does so on the CANONICALIZED name -- any
// prefix bound to the MC namespace URI splices, not only the literal `mc:`
// spelling. The scanner keeps the full physical construct. The join
// therefore computes each physical parent's "cooked" child sequence with
// the same URI-based rule before comparing. A root `AlternateContent` is
// never spliced (it was not parsed as somebody's child) and pairs
// normally. An UNBOUND literal `mc:` prefix would also splice tolerantly
// while the scanner sees no MC namespace -- but the strict gate refuses
// unbound prefixes before the join ever runs.

///|
/// A physical element identity: the index into the story scan's element
/// table, assigned in opening-tag order.
priv struct SourceElementId(Int) derive(Debug, Eq)

///|
/// A joined story: the reader-input tree whose every node carries its
/// physical identity, plus the scan those identities index. The join
/// builds the `ReaderNode` tree directly rather than a side table:
/// `XmlElement` has no stable identity to key on (synthetic
/// `first_or_empty` nodes and fresh wrapper construction make reference
/// identity an aliasing accident).
priv struct JoinedReaderStory {
  root : ReaderNode
  scan : StoryScan
}

///|
/// Which stage of the end-to-end preparation refused.
priv enum ReaderInputJoinStage {
  StrictGate
  SourceScan
  TolerantDom
} derive(Debug, Eq)

///|
/// Why a story could not be joined. Stage refusals preserve the original
/// error; the three mismatch classes are the join's own findings and carry
/// bounded diagnostics (identities, names, counts -- never raw XML).
priv enum ReaderInputJoinRefusal {
  StageRefused(stage~ : ReaderInputJoinStage, cause~ : DocxError)
  ChildCountMismatch(
    parent~ : SourceElementId,
    dom_count~ : Int,
    cooked_source_count~ : Int
  )
  NameMismatch(
    source~ : SourceElementId,
    dom_name~ : String,
    source_uri~ : String,
    source_local_name~ : String
  )
  StructureMismatch(detail~ : String)
}

///|
priv enum ReaderInputJoinResult {
  Joined(JoinedReaderStory)
  Refused(ReaderInputJoinRefusal)
}

///|
/// A bounded human-readable form for tests and diagnostics.
fn ReaderInputJoinRefusal::describe(self : ReaderInputJoinRefusal) -> String {
  fn error_message(cause : DocxError) -> String {
    match cause {
      InvalidZip(message~) => "InvalidZip: " + message
      InvalidXml(message~) => "InvalidXml: " + message
      MissingPart(message~) => "MissingPart: " + message
      Unsupported(message~) => "Unsupported: " + message
      ResourceLimit(limit=_, message~) => "ResourceLimit: " + message
      WriteResourceLimit(kind=_, limit=_, actual=_, message~) =>
        "WriteResourceLimit: " + message
    }
  }

  match self {
    StageRefused(stage~, cause~) => {
      let stage_label = match stage {
        StrictGate => "strict-gate"
        SourceScan => "source-scan"
        TolerantDom => "tolerant-dom"
      }
      "refused at \{stage_label}: \{error_message(cause)}"
    }
    ChildCountMismatch(parent~, dom_count~, cooked_source_count~) => {
      let SourceElementId(parent_index) = parent
      "child count mismatch under source element \{parent_index}: dom has \{dom_count}, cooked source has \{cooked_source_count}"
    }
    NameMismatch(source~, dom_name~, source_uri~, source_local_name~) => {
      let SourceElementId(index) = source
      "name mismatch at source element \{index}: dom \{dom_name}, source {\{source_uri}}\{source_local_name}"
    }
    StructureMismatch(detail~) => "structure mismatch: " + detail
  }
}

///|
/// The DOM name the tolerant parser would produce for a physical element,
/// mirroring `XmlParser::map_uri_name` for elements: an empty URI keeps the
/// bare local name, a mapped URI becomes `prefix:local` (an empty canonical
/// prefix falls back to the braced form), and an unmapped URI becomes
/// `{uri}local`.
fn reader_join_dom_name_matches(
  namespace_map : Map[String, String],
  uri : String,
  local_name : String,
  dom_name : String,
) -> Bool {
  if uri == "" {
    // no namespace: an undeclared default keeps the bare name, while an
    // EXPLICIT xmlns="" routes through the tolerant mapper and comes out
    // braced-empty; the scanner records "" for both and the strict gate
    // accepts both
    dom_name == local_name || dom_name == "{}" + local_name
  } else if uri == XML_NAMESPACE_URI {
    // the strict gate and the scanner install the implicit `xml` binding;
    // tolerant parsing keeps the raw `xml:` name unless the source declares
    // it, in which case the unmapped URI comes out braced
    dom_name == "xml:" + local_name || dom_name == "{" + uri + "}" + local_name
  } else {
    match namespace_map.get(uri) {
      Some("") | None => dom_name == "{" + uri + "}" + local_name
      Some(prefix) => dom_name == prefix + ":" + local_name
    }
  }
}

///|
/// Validates the physical table's structural invariants so a later
/// mismatch means what it says. These hold for every scanner-built table;
/// checking keeps hand-built or corrupted inputs fail-closed.
fn validate_scanned_element_table(scan : StoryScan) -> String? {
  let elements = scan.elements()
  if elements.length() == 0 {
    return Some("empty physical element table")
  }
  for index in 0..<elements.length() {
    let element = elements[index]
    if element.identity != index {
      return Some("element \{index} carries identity \{element.identity}")
    }
    if element.first_child_index != -1 &&
      (
        element.first_child_index < 0 ||
        element.first_child_index >= elements.length()
      ) {
      return Some(
        "element \{index} has out-of-range first child \{element.first_child_index}",
      )
    }
    if element.next_sibling_index != -1 &&
      (
        element.next_sibling_index < 0 ||
        element.next_sibling_index >= elements.length()
      ) {
      return Some(
        "element \{index} has out-of-range sibling \{element.next_sibling_index}",
      )
    }
  }
  if elements[0].parent_index != -1 {
    return Some("root element has parent \{elements[0].parent_index}")
  }
  if elements[0].next_sibling_index != -1 {
    return Some("root element has a sibling \{elements[0].next_sibling_index}")
  }
  // opening-tag preorder is the identity contract: an explicit DFS over the
  // links must visit element k as the k-th node, with parents agreeing.
  // (An iterative stack: synthetic tables are not bounded by the scanner's
  // depth cap.)
  let mut visited = 0
  let stack : Array[Int] = [0]
  while stack.length() > 0 {
    let index = stack.unsafe_pop()
    if index != visited {
      return Some(
        "element \{index} sits at preorder position \{visited}; the table is not in opening-tag order",
      )
    }
    visited = visited + 1
    if elements[index].next_sibling_index != -1 {
      if index == 0 {
        return Some("root element has a sibling")
      }
      if elements[elements[index].next_sibling_index].parent_index !=
        elements[index].parent_index {
        return Some(
          "siblings \{index} and \{elements[index].next_sibling_index} record different parents",
        )
      }
      stack.push(elements[index].next_sibling_index)
    }
    if elements[index].first_child_index != -1 {
      if elements[elements[index].first_child_index].parent_index != index {
        return Some(
          "element \{elements[index].first_child_index} is linked under \{index} but records parent \{elements[elements[index].first_child_index].parent_index}",
        )
      }
      stack.push(elements[index].first_child_index)
    }
  }
  if visited != elements.length() {
    return Some(
      "only \{visited} of \{elements.length()} elements are reachable from the root",
    )
  }
  None
}

///|
/// The child sequence the tolerant parser would cook from one physical
/// parent's direct children: an MC `AlternateContent` child is replaced by
/// its first MC `Fallback`'s cooked children (nothing when it has no
/// fallback); everything else contributes itself. The rule matches on the
/// namespace URI, exactly like the parser's canonicalize-then-splice.
fn cooked_scanned_children(scan : StoryScan, parent_index : Int) -> Array[Int] {
  let elements = scan.elements()
  let cooked : Array[Int] = []
  let mut child = elements[parent_index].first_child_index
  while child != -1 {
    let element = elements[child]
    if element.uri == MC_URI && element.local_name == "AlternateContent" {
      cooked.append(cooked_alternate_content_selection(scan, child))
    } else {
      cooked.push(child)
    }
    child = elements[child].next_sibling_index
  }
  cooked
}

///|
/// What one MC `AlternateContent` contributes: the parser parses (and
/// thereby cooks) the construct's children FIRST and only then searches
/// them for the first `mc:Fallback` -- so a fallback PROMOTED out of a
/// nested `AlternateContent` can be the one selected. The selection is the
/// chosen fallback's own cooked children, or nothing.
fn cooked_alternate_content_selection(
  scan : StoryScan,
  alternate_index : Int,
) -> Array[Int] {
  let elements = scan.elements()
  for candidate in cooked_scanned_children(scan, alternate_index) {
    let element = elements[candidate]
    if element.uri == MC_URI && element.local_name == "Fallback" {
      return cooked_scanned_children(scan, candidate)
    }
  }
  []
}

///|
/// Pairs a tolerant DOM with the physical element table. The root pairs
/// with identity 0 (a root `AlternateContent` is never spliced); below it,
/// each DOM element's children are zipped against the physical parent's
/// cooked child sequence, name-checked position by position, and recursed.
fn join_reader_dom(
  root : XmlElement,
  scan : StoryScan,
) -> ReaderInputJoinResult {
  match validate_scanned_element_table(scan) {
    Some(detail) => return Refused(StructureMismatch(detail~))
    None => ()
  }
  join_reader_element(root, 0, scan, office_namespace_map())
}

///|
fn join_reader_element(
  element : XmlElement,
  source_index : Int,
  scan : StoryScan,
  namespace_map : Map[String, String],
) -> ReaderInputJoinResult {
  let source = scan.elements()[source_index]
  if !reader_join_dom_name_matches(
      namespace_map,
      source.uri,
      source.local_name,
      element.name,
    ) {
    return Refused(
      NameMismatch(
        source=SourceElementId(source_index),
        dom_name=element.name,
        source_uri=source.uri,
        source_local_name=source.local_name,
      ),
    )
  }
  let dom_children : Array[XmlElement] = []
  for child in element.children {
    match child {
      XmlElement(child_element) => dom_children.push(child_element)
      XmlText(_) => ()
    }
  }
  let cooked = cooked_scanned_children(scan, source_index)
  if dom_children.length() != cooked.length() {
    return Refused(
      ChildCountMismatch(
        parent=SourceElementId(source_index),
        dom_count=dom_children.length(),
        cooked_source_count=cooked.length(),
      ),
    )
  }
  let joined_children : Array[ReaderNode] = []
  for index in 0..<dom_children.length() {
    match
      join_reader_element(
        dom_children[index],
        cooked[index],
        scan,
        namespace_map,
      ) {
      Joined(story) => joined_children.push(story.root)
      Refused(_) as refused => return refused
    }
  }
  Joined({
    root: {
      element,
      source_element_id: Some(SourceElementId(source_index)),
      children: joined_children,
    },
    scan,
  })
}

///|
/// The end-to-end preparation for one story part: strict gate, physical
/// scan, tolerant parse, join. Each stage's refusal is preserved; there is
/// deliberately NO fallback to an unjoined read -- a caller that wants the
/// plain tolerant DOM simply does not call this.
fn join_reader_input_story(bytes : BytesView) -> ReaderInputJoinResult {
  join_reader_input_story_limited(bytes)
}

///|
/// The budget-threaded form for production callers: the strict gate and
/// the tolerant DOM keep SEPARATE budgets because their callers account
/// differently -- main-document strict validation runs against a local
/// transient budget while its tolerant DOM charges the caller's
/// cumulative one. Omitted budgets fall back to the part-local linear
/// allowance, exactly as the unbudgeted wrapper always has.
fn join_reader_input_story_limited(
  bytes : BytesView,
  strict_budget? : @xml.XmlReadBudget,
  tolerant_budget? : @xml.XmlReadBudget,
  path_budget? : AnnotationPathBudget,
) -> ReaderInputJoinResult {
  let _ = read_identity_story_xml_strict(bytes, strict_budget) catch {
    cause => return Refused(StageRefused(stage=StrictGate, cause~))
  }
  let scan = scan_projection_source_tree(bytes, path_budget?) catch {
    cause => return Refused(StageRefused(stage=SourceScan, cause~))
  }
  let tolerant = match tolerant_budget {
    Some(value) => value
    None => local_input_linear_xml_budget(bytes)
  }
  let root = @xml.read_xml_bytes_limited(
    bytes,
    tolerant,
    namespace_map=office_namespace_map(),
  ) catch {
    cause => return Refused(StageRefused(stage=TolerantDom, cause~))
  }
  join_reader_dom(root, scan)
}
