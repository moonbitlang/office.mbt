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
/// One DOM element paired with its physical identity. The join builds this
/// tree rather than a side table: `XmlElement` has no stable identity to
/// key on (synthetic `first_or_empty` nodes and fresh wrapper construction
/// make reference identity an aliasing accident).
priv struct JoinedReaderNode {
  element : XmlElement
  source_element_id : SourceElementId
  children : Array[JoinedReaderNode]
}

///|
priv struct JoinedReaderStory {
  root : JoinedReaderNode
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
fn reader_join_dom_name(uri : String, local_name : String) -> String {
  if uri == "" {
    local_name
  } else {
    match office_namespace_map().get(uri) {
      Some("") | None => "{" + uri + "}" + local_name
      Some(prefix) => prefix + ":" + local_name
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
    if index == 0 {
      if element.parent_index != -1 {
        return Some("root element has parent \{element.parent_index}")
      }
    } else if element.parent_index < 0 ||
      element.parent_index >= elements.length() {
      return Some(
        "element \{index} has out-of-range parent \{element.parent_index}",
      )
    }
    if element.first_child_index != -1 &&
      (
        element.first_child_index <= index ||
        element.first_child_index >= elements.length()
      ) {
      return Some(
        "element \{index} has out-of-range first child \{element.first_child_index}",
      )
    }
    if element.next_sibling_index != -1 &&
      (
        element.next_sibling_index <= index ||
        element.next_sibling_index >= elements.length()
      ) {
      return Some(
        "element \{index} has out-of-range sibling \{element.next_sibling_index}",
      )
    }
  }
  // every non-root element must be reached exactly once by child/sibling
  // links, and links must agree with the stored parent
  let reached : Array[Bool] = Array::make(elements.length(), false)
  reached[0] = true
  for index in 0..<elements.length() {
    let mut child = elements[index].first_child_index
    while child != -1 {
      if reached[child] {
        return Some("element \{child} is linked more than once")
      }
      if elements[child].parent_index != index {
        return Some(
          "element \{child} is linked under \{index} but records parent \{elements[child].parent_index}",
        )
      }
      reached[child] = true
      child = elements[child].next_sibling_index
    }
  }
  for index in 0..<elements.length() {
    if !reached[index] {
      return Some("element \{index} is unreachable from the root")
    }
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
      let mut candidate = element.first_child_index
      let mut fallback = -1
      while candidate != -1 {
        let candidate_element = elements[candidate]
        if candidate_element.uri == MC_URI &&
          candidate_element.local_name == "Fallback" {
          fallback = candidate
          break
        }
        candidate = candidate_element.next_sibling_index
      }
      if fallback != -1 {
        cooked.append(cooked_scanned_children(scan, fallback))
      }
    } else {
      cooked.push(child)
    }
    child = elements[child].next_sibling_index
  }
  cooked
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
  join_reader_element(root, 0, scan)
}

///|
fn join_reader_element(
  element : XmlElement,
  source_index : Int,
  scan : StoryScan,
) -> ReaderInputJoinResult {
  let source = scan.elements()[source_index]
  let expected_name = reader_join_dom_name(source.uri, source.local_name)
  if element.name != expected_name {
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
  let joined_children : Array[JoinedReaderNode] = []
  for index in 0..<dom_children.length() {
    match join_reader_element(dom_children[index], cooked[index], scan) {
      Joined(story) => joined_children.push(story.root)
      Refused(_) as refused => return refused
    }
  }
  Joined({
    root: {
      element,
      source_element_id: SourceElementId(source_index),
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
  let _ = read_identity_story_xml_strict(bytes, None) catch {
    cause => return Refused(StageRefused(stage=StrictGate, cause~))
  }
  let scan = scan_projection_source_tree(bytes) catch {
    cause => return Refused(StageRefused(stage=SourceScan, cause~))
  }
  let root = @xml.read_xml_bytes_limited(
    bytes,
    local_input_linear_xml_budget(bytes),
    namespace_map=office_namespace_map(),
  ) catch {
    cause => return Refused(StageRefused(stage=TolerantDom, cause~))
  }
  join_reader_dom(root, scan)
}
