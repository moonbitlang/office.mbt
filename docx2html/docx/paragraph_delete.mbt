// `office delete-paragraph` — the N3b planner, insertion's structural
// inverse. Exactly one DIRECT body paragraph leaves the story as a
// byte-exact splice; everything the deletion could dangle — notes,
// comments, bookmarks, split fields, revisions, media, a section
// break, the document-final paragraph — refuses instead. Nothing else
// in the package changes by a byte.

///|
/// What one planned deletion will do: the path that stops resolving,
/// the identity that leaves with it, the text it carried (the reader
/// projection, for the caller's own guard), and the successor's
/// identity — the paragraph that will answer at the deleted path after
/// publication, when one exists.
pub struct DocxDeleteReceipt {
  priv path : String
  priv para_id : String?
  priv anchor_status : String
  priv text : String
  priv successor_para_id : String?
  priv successor_text : String?
  priv cut : DocxDeleteCutWitness
}

///|
/// What the published story part must read like once the cut lands:
/// the source it is cut from, and the span removed. Text and identity
/// both go blind when two adjacent paragraphs read alike — deleting
/// either leaves the same projection at the same path — so this is the
/// evidence that says WHICH paragraph left, and it is exact: the
/// published part must equal the source with exactly this span gone,
/// byte for byte. The source is the snapshot's own bytes, held by
/// reference, so proving it costs a comparison and no copy.
pub struct DocxDeleteCutWitness {
  priv part : String
  priv source : BytesView
  priv cut_start : Int
  priv cut_end : Int
}

///|
/// The story part the cut applies to.
pub fn DocxDeleteCutWitness::part(self : DocxDeleteCutWitness) -> String {
  self.part
}

///|
/// The published part's exact byte length once the cut lands.
pub fn DocxDeleteCutWitness::expected_length(
  self : DocxDeleteCutWitness,
) -> Int {
  self.source.length() - (self.cut_end - self.cut_start)
}

///|
/// Whether `candidate` is exactly the source with the planned span
/// removed. Compared in place, so a large story costs no copy.
pub fn DocxDeleteCutWitness::matches(
  self : DocxDeleteCutWitness,
  candidate : BytesView,
) -> Bool {
  guard candidate.length() == self.expected_length() else { return false }
  for index in 0..<self.cut_start {
    guard candidate[index] == self.source[index] else { return false }
  }
  let mut write = self.cut_start
  for index in self.cut_end..<self.source.length() {
    guard candidate[write] == self.source[index] else { return false }
    write += 1
  }
  true
}

///|
/// The direct body path this deletion removes.
pub fn DocxDeleteReceipt::path(self : DocxDeleteReceipt) -> String {
  self.path
}

///|
/// The deleted paragraph's canonical w14:paraId, when it uniquely
/// carried one.
pub fn DocxDeleteReceipt::para_id(self : DocxDeleteReceipt) -> String? {
  self.para_id
}

///|
/// The target's anchor judgment in the planning snapshot.
pub fn DocxDeleteReceipt::anchor_status(self : DocxDeleteReceipt) -> String {
  self.anchor_status
}

///|
/// The deleted paragraph's reader projection — what an agent verifies
/// against before trusting an ordinal address.
pub fn DocxDeleteReceipt::text(self : DocxDeleteReceipt) -> String {
  self.text
}

///|
/// The unique identity of the paragraph that will answer at the
/// deleted path after publication, when the successor carries one.
pub fn DocxDeleteReceipt::successor_para_id(
  self : DocxDeleteReceipt,
) -> String? {
  self.successor_para_id
}

///|
/// The projection of the paragraph that will answer at the deleted
/// path after publication — the readback's text evidence, which a
/// document carrying no unique identities still has.
pub fn DocxDeleteReceipt::successor_text(self : DocxDeleteReceipt) -> String? {
  self.successor_text
}

///|
/// The exact byte span this plan removes from the main story part.
/// Text and identity both go blind when two adjacent paragraphs read
/// alike — deleting either yields the same projection — so the
/// transaction verifies the cut landed at these bytes and nowhere
/// else.
pub fn DocxDeleteReceipt::cut(self : DocxDeleteReceipt) -> DocxDeleteCutWitness {
  self.cut
}

///|
/// Whether an element is a DIRECT child of `w:body` on the physical
/// tree. The path grammar flattens wrappers (`w:sdt`, `w:ins`,
/// `mc:Fallback`…), so a path alone never proves this — every guard
/// that must not splice inside a wrapper proves it here.
fn is_direct_body_child(
  elements : Array[ScannedElement],
  element : ScannedElement,
) -> Bool {
  let parent = element.parent_index
  guard parent >= 0 && parent < elements.length() else { return false }
  let holder = elements[parent]
  holder.local_name == "body" && is_wml_uri(holder.uri)
}

///|
/// Ranges whose START lies before the target and whose END lies after
/// it: the target sits inside a range anchored by its own siblings, so
/// the subtree scan cannot see it, and removing the paragraph leaves
/// that range anchoring nothing.
///
/// Every paired range family CT_Body admits is judged, keyed by
/// (family, id) — the id spaces are INDEPENDENT, so a permission
/// numbered 1 must not close a comment range numbered 1 — and a marker
/// whose id cannot be read fails CLOSED, because outside the span is
/// exactly where bracketing lives.
fn bracketing_range_kind(
  elements : Array[ScannedElement],
  span : NodeSpan,
) -> String? {
  let opened : Map[String, String] = Map([])
  let bracketing : Array[String] = []
  for element in elements {
    guard is_wml_uri(element.uri) else { continue }
    let (family, starts) = match element.local_name {
      "commentRangeStart" => ("comment", true)
      "commentRangeEnd" => ("comment", false)
      "permStart" => ("perm", true)
      "permEnd" => ("perm", false)
      "bookmarkStart" => ("bookmark", true)
      "bookmarkEnd" => ("bookmark", false)
      "moveFromRangeStart" => ("moveFrom", true)
      "moveFromRangeEnd" => ("moveFrom", false)
      "moveToRangeStart" => ("moveTo", true)
      "moveToRangeEnd" => ("moveTo", false)
      "customXmlInsRangeStart" => ("customXmlIns", true)
      "customXmlInsRangeEnd" => ("customXmlIns", false)
      "customXmlDelRangeStart" => ("customXmlDel", true)
      "customXmlDelRangeEnd" => ("customXmlDel", false)
      "customXmlMoveFromRangeStart" => ("customXmlMoveFrom", true)
      "customXmlMoveFromRangeEnd" => ("customXmlMoveFrom", false)
      "customXmlMoveToRangeStart" => ("customXmlMoveTo", true)
      "customXmlMoveToRangeEnd" => ("customXmlMoveTo", false)
      _ => continue
    }
    let inside = element.byte_start >= span.byte_start() &&
      element.byte_end <= span.byte_end()
    if inside {
      continue
    }
    guard element.bookmark_id_raw is Some(id) else {
      // Unpairable: a marker outside the target whose id cannot be
      // read could be the half of a range that brackets it, and this
      // verb does not guess about ranges it cannot judge.
      return Some(range_family_label(family))
    }
    let key = family + "\u{1}" + id
    if element.byte_end <= span.byte_start() {
      if starts {
        opened[key] = family
      } else {
        opened.remove(key)
      }
    } else if element.byte_start >= span.byte_end() && !starts {
      match opened.get(key) {
        // A `_GoBack` cursor bookmark bracketing the target is Word's
        // caret, not an anchor anything references.
        Some(open_family) =>
          if !(open_family == "bookmark" &&
            bookmark_name_at(elements, key, "_GoBack")) {
            bracketing.push(open_family)
          }
        None => ()
      }
    }
  }
  // Deterministic: the message must not depend on hash order.
  bracketing.sort()
  match bracketing.get(0) {
    Some(family) => Some(range_family_label(family))
    None => None
  }
}

///|
/// Whether the bookmark start keyed by `key` names `expected`.
fn bookmark_name_at(
  elements : Array[ScannedElement],
  key : String,
  expected : String,
) -> Bool {
  for element in elements {
    if is_wml_uri(element.uri) &&
      element.local_name == "bookmarkStart" &&
      element.bookmark_id_raw is Some(id) &&
      "bookmark\u{1}" + id == key {
      return element.bookmark_name_raw is Some(name) && name == expected
    }
  }
  false
}

///|
fn range_family_label(family : String) -> String {
  match family {
    "comment" => "a comment range"
    "perm" => "a range permission"
    "bookmark" => "a bookmark range"
    _ => "a tracked-revision range"
  }
}

///|
/// The body's FLOW: the blocks a consumer lays out, read the way the
/// projection reads them. This is an ALLOW-LIST on purpose — exactly
/// `w:p` and `w:tbl` are flow — because the question it answers is
/// "what would touch what if this block left", and everything else in
/// a body (a content control's `w:sdtPr`, a `w:customXml` wrapper, an
/// `mc:Choice`, every range marker, anything a future WML adds)
/// occupies no layout space between two blocks that would otherwise be
/// adjacent. A deny-list here was inert on the very shape Word emits.
///
/// Content inside a transparent wrapper IS body flow — the projection
/// already gives it a body-level path — so the walk to the body climbs
/// through wrappers.
fn body_flow_kind(elements : Array[ScannedElement], index : Int) -> String? {
  let element = elements[index]
  guard is_wml_uri(element.uri) else { return None }
  let kind = match element.local_name {
    "p" => "p"
    "tbl" => "tbl"
    _ => return None
  }
  let mut parent = element.parent_index
  while parent >= 0 && parent < elements.length() {
    let holder = elements[parent]
    if is_layout_transparent(holder.uri, holder.local_name) {
      parent = holder.parent_index
      continue
    }
    guard holder.local_name == "body" && is_wml_uri(holder.uri) else {
      return None
    }
    return Some(kind)
  }
  None
}

///|
/// Wrappers that contribute no LAYOUT of their own, so the blocks
/// inside them are the blocks a consumer sees touching. This is a
/// superset of the reader's transparent containers — `w:customXml`
/// does not flatten in the path space but a table inside one is still
/// the table that would merge — because the question here is
/// adjacency, not addressing.
fn is_layout_transparent(uri : String, local_name : String) -> Bool {
  is_transparent_container(uri, local_name) ||
  (is_wml_uri(uri) && local_name is ("customXml" | "bdo" | "dir"))
}

///|
/// The subtree hazards a v1 deletion refuses. The model is three
/// MECHANICALLY CLOSED classes plus the paragraph's own structure —
/// not a hand-copied vocabulary that rots as WML grows:
///
/// 1. REVISION SITES: the reader's own `is_revision_site_name`
///    judges the whole tracked-revision family (moves, property
///    changes, the eight customXml range markers included) — deletion
///    must not silently discard history or unbalance a
///    document-order-global revision range.
/// 2. RELATIONSHIP REFERENCES: any element carrying an attribute in
///    the OPC relationships namespace (r:id, r:embed, r:link, …) is
///    judged by the scanner's resolved-URI flag — removing it
///    mechanically touches relationship reachability (drawings,
///    embedded objects, content parts, movies, anything future).
///    `w:hyperlink` alone is exempt by design: the relationship a
///    deleted hyperlink strands is an OPC-legal orphan, and
///    hyperlink-bearing paragraphs are everyday content.
/// 3. RANGE AND ANCHOR MACHINERY, enumerated closed by WML itself:
///    note references (orphan definitions), comment machinery
///    (orphan definitions, unbalanced ranges), range permissions
///    (`permStart`/`permEnd` pair across paragraphs), split field
///    boundaries (`fldChar` pairs are document-order-global;
///    `fldSimple` is self-contained and permitted), and bookmark
///    markers — judged as PAIRS by the caller, with the
///    wholly-internal `_GoBack` cursor artifact alone exempt.
///
/// `sectPr` is section layout for the whole preceding range; a nested
/// `p` means the reader tolerated a paragraph INSIDE the target, and
/// deleting the physical span would remove more logical paragraphs
/// than the receipt names. Constructs outside every class — plain
/// formatting, text, `fldSimple`, ruby, smart tags — die wholly with
/// the paragraph and dangle nothing.
fn delete_blocked_construct(uri : String, local_name : String) -> String? {
  if is_revision_site_name(uri, local_name) {
    return Some("tracked-revision content")
  }
  // Co-authoring conflict revisions are revision history in the w14
  // namespace, which the WML vocabulary above does not reach.
  if is_w14_uri(uri) &&
    local_name
    is ("conflictIns"
    | "conflictDel"
    | "conflictMoveFrom"
    | "conflictMoveTo"
    | "conflictInsDel") {
    return Some("tracked-revision content")
  }
  // Gated on WML like every neighbouring judgment: a foreign
  // `x:object` or `ns:sectPr` is not the construct this class names,
  // and refusing it would be a false refusal reported with the wrong
  // reason.
  guard is_wml_uri(uri) else { return None }
  match local_name {
    "sectPr" => Some("a section break")
    "p" => Some("a nested paragraph")
    "footnoteReference" => Some("a footnote reference")
    "endnoteReference" => Some("an endnote reference")
    "commentReference" | "commentRangeStart" | "commentRangeEnd" =>
      Some("comment machinery")
    "permStart" | "permEnd" => Some("a range-permission boundary")
    "fldChar" => Some("a field boundary")
    "drawing" | "object" | "pict" => Some("an embedded object")
    _ => None
  }
}

///|
/// Plan one paragraph deletion at a DIRECT body paragraph.
///
/// `at` is the direct body ordinal path ("p[3]") — the same anchor
/// grammar insertion uses, proven a physical child of w:body on the
/// element tree (the path grammar flattens wrappers, so the path alone
/// proves nothing). The returned plan splices ONLY the deletion; the
/// receipt names what leaves and who answers at the path afterwards.
pub fn plan_docx_paragraph_deletion(
  annotated : DocxAnnotatedResult,
  at~ : String,
) -> (@splice.SplicePlan, DocxDeleteReceipt) raise DocxError {
  guard insert_anchor_ordinal(at) is Some(ordinal) else {
    raise Unsupported(
      message="delete-paragraph targets a direct body paragraph (p[N]); '\{at}' is not one",
    )
  }
  guard annotated.body_paragraph_span(at) is Some(span) else {
    raise Unsupported(
      message="delete-paragraph target '\{at}' does not resolve in this document",
    )
  }
  let part = annotated.main_story_part()
  guard annotated.reader_projection_sources.get(part) is Some(bytes) else {
    raise Unsupported(
      message="delete-paragraph requires a mutation-safe read with retained source bytes",
    )
  }
  guard annotated.reader_projections.get(part) is Some(projection) else {
    raise Unsupported(
      message="delete-paragraph requires a mutation-safe read with a retained projection",
    )
  }
  let elements = projection.scan.elements()
  // The target must be a PHYSICAL direct child of w:body — the path
  // grammar flattens wrappers, so the path alone proves nothing — and
  // its element index is the key to its subtree.
  let mut target_index = -1
  for index, element in elements {
    if element.byte_start == span.byte_start() &&
      element.local_name == "p" &&
      is_wml_uri(element.uri) {
      if is_direct_body_child(elements, element) {
        target_index = index
      }
      break
    }
  }
  guard target_index >= 0 else {
    raise Unsupported(
      message="delete-paragraph target '\{at}' is not a DIRECT child of the body — paragraphs inside content controls, revisions, or compatibility wrappers are not deletion targets",
    )
  }
  // The body's FLOW children in document order: the target's own
  // neighbours decide whether removing it changes structure, and a
  // subtree-only judgment cannot see that. "Flow" is what a consumer
  // lays out, so this reads the story the way the projection does —
  // through transparent wrappers (`w:sdt`, `w:ins`, `mc:Fallback`…),
  // which is where the wrapped content actually lives, and past the
  // zero-width range markers CT_Body admits between blocks, which
  // occupy no space between two blocks that would otherwise touch.
  let flow_children : Array[String] = []
  let mut target_position = -1
  for index, _ in elements {
    guard body_flow_kind(elements, index) is Some(kind) else { continue }
    if index == target_index {
      target_position = flow_children.length()
    }
    flow_children.push(kind)
  }
  // Two adjacent `w:tbl` elements are ONE table to a consumer. A
  // paragraph between two tables is the separator that keeps them
  // apart, and deleting it silently merges them — a structural change
  // no readback of paragraph identity would notice.
  if target_position > 0 && target_position + 1 < flow_children.length() {
    let before = flow_children[target_position - 1]
    let after = flow_children[target_position + 1]
    if before == "tbl" && after == "tbl" {
      raise Unsupported(
        message="delete-paragraph target '\{at}' separates two tables; deleting it would merge them into one, so this deletion refuses",
      )
    }
  }
  // A paragraph strictly INSIDE an open field region carries part of a
  // field whose `fldChar` boundaries live in other paragraphs: the
  // instruction or result would be truncated with the paragraph. The
  // target's OWN boundaries refuse below; this is the region it sits
  // in, judged on the story-global begin/end depth.
  let mut field_depth = 0
  for element in elements {
    if element.byte_start >= span.byte_start() {
      break
    }
    if is_wml_uri(element.uri) && element.local_name == "fldChar" {
      match element.field_char_type {
        Some("begin") => field_depth += 1
        Some("end") => if field_depth > 0 { field_depth -= 1 }
        _ => ()
      }
    }
  }
  if field_depth > 0 {
    // A region only truncates if it CLOSES after the target. An
    // orphan `begin` — which Word tolerates — would otherwise poison
    // every later paragraph in the story with a refusal naming a
    // field that does not exist.
    // The region open AT the target must be the one that closes: an
    // unrelated well-formed field later in the story (a page number, a
    // TOC — nearly every document has one) is not this region closing,
    // and treating it as one refuses every paragraph after a stray
    // `begin` Word tolerates.
    let mut closes_after = false
    let mut depth = field_depth
    for element in elements {
      if element.byte_start < span.byte_end() {
        continue
      }
      if is_wml_uri(element.uri) && element.local_name == "fldChar" {
        match element.field_char_type {
          Some("begin") => depth += 1
          Some("end") => {
            depth -= 1
            if depth < field_depth {
              closes_after = true
              break
            }
          }
          _ => ()
        }
      }
    }
    guard !closes_after else {
      raise Unsupported(
        message="delete-paragraph target '\{at}' sits inside a field region whose boundaries lie in other paragraphs; deleting it would truncate the field, so this deletion refuses",
      )
    }
  }
  // Ranges that BRACKET the target: markers CT_Body admits as the
  // target's own siblings, whose start precedes it and whose end
  // follows. The subtree scan below cannot see them — they are not
  // inside the span — and deleting the paragraph empties the range
  // they anchor.
  match bracketing_range_kind(elements, span) {
    Some(kind) =>
      raise Unsupported(
        message="delete-paragraph target '\{at}' is bracketed by \{kind}; deleting it would empty that range, so this deletion refuses",
      )
    None => ()
  }
  // Subtree hazards: every element inside the paragraph's byte span is
  // part of what the deletion removes.
  // Bookmark markers judge as PAIRS, by MULTISET: every start inside
  // is the `_GoBack` cursor artifact with exactly one end inside, and
  // no marker outside shares an id with one inside — anything else
  // unbalances a range or dangles a reference target.
  let bookmark_starts : Map[String, Int] = Map([])
  let bookmark_ends : Map[String, Int] = Map([])
  for index, element in elements {
    if index == target_index {
      continue
    }
    if element.byte_start >= span.byte_start() &&
      element.byte_end <= span.byte_end() {
      if element.references_relationship &&
        !(is_wml_uri(element.uri) && element.local_name == "hyperlink") {
        raise Unsupported(
          message="delete-paragraph target '\{at}' carries an element that references a package relationship; deleting it would touch relationship reachability, so this deletion refuses",
        )
      }
      // The hazard judgment sees EVERY namespace: gating it on WML is
      // how `w14:conflictIns` — revision history by any measure — slid
      // through an earlier round of this same list.
      match delete_blocked_construct(element.uri, element.local_name) {
        Some(reason) =>
          raise Unsupported(
            message="delete-paragraph target '\{at}' carries \{reason}; deleting it would dangle or destroy document state outside the paragraph, so this deletion refuses",
          )
        None => ()
      }
      if is_wml_uri(element.uri) {
        if element.local_name == "bookmarkStart" {
          // Only the _GoBack cursor artifact is deletable, and only
          // with a REAL id: an absent id cannot be paired at all.
          guard element.bookmark_name_raw is Some(name) else {
            raise Unsupported(
              message="delete-paragraph target '\{at}' carries a bookmark marker whose name could not be read; the pairing cannot be judged, so this deletion refuses",
            )
          }
          guard name == "_GoBack" else {
            raise Unsupported(
              message="delete-paragraph target '\{at}' carries a named bookmark; deleting it would dangle or destroy document state outside the paragraph, so this deletion refuses",
            )
          }
          guard element.bookmark_id_raw is Some(id) && id != "" else {
            raise Unsupported(
              message="delete-paragraph target '\{at}' carries a bookmark marker without a usable id; the pairing cannot be judged, so this deletion refuses",
            )
          }
          bookmark_starts[id] = bookmark_starts.get(id).unwrap_or(0) + 1
        }
        if element.local_name == "bookmarkEnd" {
          guard element.bookmark_id_raw is Some(id) && id != "" else {
            raise Unsupported(
              message="delete-paragraph target '\{at}' carries a bookmark marker without a usable id; the pairing cannot be judged, so this deletion refuses",
            )
          }
          bookmark_ends[id] = bookmark_ends.get(id).unwrap_or(0) + 1
        }
      }
    }
  }
  // Balanced as MULTISETS: one start, one end, per id. Counting closes
  // the duplicate-end quadrant that set membership left open.
  for id, ends in bookmark_ends {
    guard bookmark_starts.get(id) is Some(starts) && starts == ends else {
      raise Unsupported(
        message="delete-paragraph target '\{at}' carries bookmark boundaries that do not pair inside it; deleting it would unbalance the range, so this deletion refuses",
      )
    }
  }
  for id, starts in bookmark_starts {
    guard bookmark_ends.get(id) is Some(ends) && ends == starts else {
      raise Unsupported(
        message="delete-paragraph target '\{at}' carries bookmark boundaries that do not pair inside it; deleting it would unbalance the range, so this deletion refuses",
      )
    }
  }
  // And no marker OUTSIDE the span may share an id with one inside:
  // the story would keep a boundary whose partner this deletion takes.
  if bookmark_starts.length() > 0 {
    for index, element in elements {
      if index == target_index ||
        (
          element.byte_start >= span.byte_start() &&
          element.byte_end <= span.byte_end()
        ) {
        continue
      }
      if is_wml_uri(element.uri) &&
        (
          element.local_name == "bookmarkStart" ||
          element.local_name == "bookmarkEnd"
        ) &&
        element.bookmark_id_raw is Some(id) &&
        bookmark_starts.get(id) is Some(_) {
        raise Unsupported(
          message="delete-paragraph target '\{at}' carries a bookmark id another marker outside it also uses; the pairing cannot be judged, so this deletion refuses",
        )
      }
    }
  }
  // A successor is a paragraph that ANSWERS at the next path — the
  // same flattened surface the receipt reports and the readback
  // re-reads, so the two cannot disagree about whether one exists.
  // Two different questions, deliberately asked on two surfaces:
  //
  // "Will the body still have a direct paragraph?" is STRUCTURAL, so it
  // is asked of the physical tree — a paragraph nested in a content
  // control does not keep the body's last direct paragraph company, and
  // a body whose last flow child is a table still needs its trailing
  // one. (The receipt's successor identity and text are the FLATTENED
  // question, asked below, because that is what re-anchors at the
  // deleted path.)
  let mut successor_exists = false
  for index, element in elements {
    if index != target_index &&
      element.local_name == "p" &&
      is_wml_uri(element.uri) &&
      element.byte_start >= span.byte_end() &&
      is_direct_body_child(elements, element) {
      successor_exists = true
      break
    }
  }
  // The document-final direct body paragraph is structural: Word keeps
  // one, and a body whose last flow child is a table still needs its
  // trailing paragraph. No successor -> refuse.
  guard successor_exists else {
    raise Unsupported(
      message="delete-paragraph target '\{at}' is the final direct body paragraph; the document keeps it",
    )
  }
  let story = annotated.main_story_source()
  let anchors = docx_paragraph_anchor_index(annotated, story)
  // A path the anchor index tombstoned (a collided head, or the tail
  // of a revision-joined paragraph) does not address exactly one
  // whole logical paragraph — refuse rather than delete more or less
  // than the receipt could name.
  guard anchors.anchor_at(at) is Some(anchor) else {
    raise Unsupported(
      message="delete-paragraph target '\{at}' does not address exactly one whole paragraph in this document, so this deletion refuses",
    )
  }
  // A `multi_physical` head is the FIRST half of a paragraph the reader
  // joined across a deleted paragraph mark: splicing its physical span
  // would delete part of one logical paragraph while the receipt named
  // the whole.
  //
  // HONEST NOTE ON REACHABILITY: today this cannot fire. Both routes to
  // `multi_physical` are already refused earlier — a join is created
  // only by a deleted paragraph mark, whose `w:del` sits in the head's
  // own subtree and trips the revision class, and the shared-head route
  // needs a nested `w:p`, which the same walk refuses. It is kept as a
  // standing guarantee for an irreversible verb: the invariant is "the
  // target is one whole logical paragraph", and that must not depend on
  // the coincidence that today's joins happen to carry revision markup
  // inside the target. A reader change that introduces a join by some
  // other mechanism finds this guard already in place rather than
  // silently publishing half a paragraph.
  guard anchor.status() != "multi_physical" else {
    raise Unsupported(
      message="delete-paragraph target '\{at}' is one physical half of a paragraph joined across a deleted paragraph mark, so this deletion refuses",
    )
  }
  let para_id = if anchor.status() == "unique" {
    anchor.para_id()
  } else {
    None
  }
  let anchor_status = anchor.status()
  let successor_para_id = match anchors.anchor_at("p[\{ordinal + 1}]") {
    Some(anchor) =>
      if anchor.status() == "unique" {
        anchor.para_id()
      } else {
        None
      }
    None => None
  }
  guard docx_paragraph_projection(annotated, story, path=at) is Some(text) else {
    raise Unsupported(
      message="delete-paragraph target '\{at}' has no readable projection in this document, so this deletion refuses",
    )
  }
  let plan = @splice.SplicePlan::new()
  plan.pin_part(part, bytes)
  plan.edit_part(
    part,
    @splice.span_edit(start=span.byte_start(), end=span.byte_end(), b""),
  )
  let successor_text = docx_paragraph_projection(
    annotated,
    story,
    path="p[\{ordinal + 1}]",
  )
  (
    plan,
    {
      path: at,
      para_id,
      anchor_status,
      text,
      successor_para_id,
      successor_text,
      cut: {
        part,
        source: bytes,
        cut_start: span.byte_start(),
        cut_end: span.byte_end(),
      },
    },
  )
}

///|
/// The number of DIRECT body paragraphs, counted on the element tree —
/// the same proof surface the deletion planner trusts. Anchor-index
/// probing undercounts when a collided or revision-joined path is
/// tombstoned; the tree does not.
pub fn docx_direct_body_paragraph_count(
  annotated : DocxAnnotatedResult,
) -> Int raise DocxError {
  let part = annotated.main_story_part()
  guard annotated.reader_projections.get(part) is Some(projection) else {
    raise Unsupported(
      message="counting direct paragraphs requires a mutation-safe read with a retained projection",
    )
  }
  let elements = projection.scan.elements()
  let mut count = 0
  for element in elements {
    if element.local_name == "p" && is_wml_uri(element.uri) {
      let parent = element.parent_index
      if parent >= 0 && parent < elements.length() {
        let holder = elements[parent]
        if holder.local_name == "body" && is_wml_uri(holder.uri) {
          count += 1
        }
      }
    }
  }
  count
}
