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
/// its exact length, and the bytes on either side of the removal made
/// adjacent (bounded to a window, so a large story costs nothing to
/// remember). Text and identity both go blind when two adjacent
/// paragraphs read alike — deleting either leaves the same projection
/// at the same path — so this is the evidence that says WHICH
/// paragraph left.
pub struct DocxDeleteCutWitness {
  priv part : String
  priv expected_length : Int
  priv offset : Int
  priv joint : Bytes
}

///|
pub fn DocxDeleteCutWitness::part(self : DocxDeleteCutWitness) -> String {
  self.part
}

///|
pub fn DocxDeleteCutWitness::expected_length(
  self : DocxDeleteCutWitness,
) -> Int {
  self.expected_length
}

///|
/// Byte offset into the published part where `joint` must appear.
pub fn DocxDeleteCutWitness::offset(self : DocxDeleteCutWitness) -> Int {
  self.offset
}

///|
pub fn DocxDeleteCutWitness::joint(self : DocxDeleteCutWitness) -> Bytes {
  self.joint
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
fn delete_blocked_construct(uri : String, local_name : String) -> String? {
  if is_revision_site_name(uri, local_name) {
    return Some("tracked-revision content")
  }
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
  // The body's flow children in document order: the target's own
  // NEIGHBOURS decide whether removing it changes structure, and a
  // subtree-only judgment cannot see that.
  let body_children : Array[Int] = []
  let mut target_position = -1
  for index, element in elements {
    if is_direct_body_child(elements, element) {
      if index == target_index {
        target_position = body_children.length()
      }
      body_children.push(index)
    }
  }
  // Two adjacent `w:tbl` elements are ONE table to a consumer. A
  // paragraph between two tables is the separator that keeps them
  // apart, and deleting it silently merges them — a structural change
  // no readback of paragraph identity would notice.
  if target_position > 0 && target_position + 1 < body_children.length() {
    let before = elements[body_children[target_position - 1]]
    let after = elements[body_children[target_position + 1]]
    if before.local_name == "tbl" &&
      is_wml_uri(before.uri) &&
      after.local_name == "tbl" &&
      is_wml_uri(after.uri) {
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
  guard field_depth == 0 else {
    raise Unsupported(
      message="delete-paragraph target '\{at}' sits inside a field region whose boundaries lie in other paragraphs; deleting it would truncate the field, so this deletion refuses",
    )
  }
  // Subtree hazards: every element inside the paragraph's byte span is
  // part of what the deletion removes.
  let mut successor_exists = false
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
      if is_wml_uri(element.uri) {
        match delete_blocked_construct(element.uri, element.local_name) {
          Some(reason) =>
            raise Unsupported(
              message="delete-paragraph target '\{at}' carries \{reason}; deleting it would dangle or destroy document state outside the paragraph, so this deletion refuses",
            )
          None => ()
        }
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
    } else if element.local_name == "p" &&
      is_wml_uri(element.uri) &&
      element.byte_start >= span.byte_end() &&
      is_direct_body_child(elements, element) {
      successor_exists = true
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
  if bookmark_starts.size() > 0 {
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
  // The joint the cut creates: the bytes on either side of the removal
  // made adjacent, in a bounded window. The transaction verifies the
  // published part reads exactly this way at exactly this offset, which
  // is the only evidence that survives when adjacent paragraphs read
  // alike.
  let window = 64
  let joint_offset = if span.byte_start() > window {
    span.byte_start() - window
  } else {
    0
  }
  let joint_after_end = if span.byte_end() + window < bytes.length() {
    span.byte_end() + window
  } else {
    bytes.length()
  }
  let joint_length = span.byte_start() -
    joint_offset +
    (joint_after_end - span.byte_end())
  let joint_buffer = FixedArray::make(joint_length, b'\x00')
  let mut joint_write = 0
  for index in joint_offset..<span.byte_start() {
    joint_buffer[joint_write] = bytes[index]
    joint_write += 1
  }
  for index in span.byte_end()..<joint_after_end {
    joint_buffer[joint_write] = bytes[index]
    joint_write += 1
  }
  let joint_bytes = Bytes::from_fixedarray(joint_buffer)
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
        expected_length: bytes.length() - (span.byte_end() - span.byte_start()),
        offset: joint_offset,
        joint: joint_bytes,
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
