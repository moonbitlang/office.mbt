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
  match local_name {
    "sectPr" => Some("a section break (w:sectPr)")
    "p" => Some("a nested paragraph the reader tolerated")
    "footnoteReference" => Some("a footnote reference")
    "endnoteReference" => Some("an endnote reference")
    "commentReference" | "commentRangeStart" | "commentRangeEnd" =>
      Some("comment machinery")
    "permStart" | "permEnd" => Some("a range-permission boundary")
    "fldChar" => Some("a split field boundary (w:fldChar)")
    "drawing" | "object" | "pict" => Some("a drawing or embedded object")
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
  // The target must be a PHYSICAL direct child of w:body, and the
  // element index is the key to its subtree.
  let mut target_index = -1
  for index, element in elements {
    if element.byte_start == span.byte_start() &&
      element.local_name == "p" &&
      is_wml_uri(element.uri) {
      let parent = element.parent_index
      if parent >= 0 && parent < elements.length() {
        let holder = elements[parent]
        if holder.local_name == "body" && is_wml_uri(holder.uri) {
          target_index = index
        }
      }
      break
    }
  }
  guard target_index >= 0 else {
    raise Unsupported(
      message="delete-paragraph target '\{at}' is not a DIRECT child of the body — paragraphs inside content controls, revisions, or compatibility wrappers are not deletion targets",
    )
  }
  // Subtree hazards: every element inside the paragraph's byte span is
  // part of what the deletion removes. WML constructs answer by name;
  // anything the blocklist misses dies with the paragraph and dangles
  // nothing this verb owes — relationships a deleted hyperlink leaves
  // behind are OPC-legal orphans.
  let mut successor_exists = false
  // Bookmark markers judge as PAIRS: every start inside must be the
  // `_GoBack` cursor artifact with its end inside, and no end inside
  // may belong to a start outside — anything else unbalances a range
  // or dangles a reference target.
  let bookmark_starts : Map[String, String] = Map([])
  let bookmark_ends : Array[String] = []
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
          // with a REAL, unduplicated id: an absent or repeated id
          // would let this start vouch for an end that balances some
          // OTHER bookmark's range.
          guard element.bookmark_name_raw is Some("_GoBack") else {
            raise Unsupported(
              message="delete-paragraph target '\{at}' carries a named bookmark; deleting it would dangle or destroy document state outside the paragraph, so this deletion refuses",
            )
          }
          guard element.bookmark_id_raw is Some(id) && id != "" else {
            raise Unsupported(
              message="delete-paragraph target '\{at}' carries a bookmark marker without a usable id; the pairing cannot be judged, so this deletion refuses",
            )
          }
          guard bookmark_starts.get(id) is None else {
            raise Unsupported(
              message="delete-paragraph target '\{at}' carries two bookmark starts sharing one id; the pairing cannot be judged, so this deletion refuses",
            )
          }
          bookmark_starts[id] = "_GoBack"
        }
        if element.local_name == "bookmarkEnd" {
          guard element.bookmark_id_raw is Some(id) && id != "" else {
            raise Unsupported(
              message="delete-paragraph target '\{at}' carries a bookmark marker without a usable id; the pairing cannot be judged, so this deletion refuses",
            )
          }
          bookmark_ends.push(id)
        }
      }
    } else if element.local_name == "p" &&
      is_wml_uri(element.uri) &&
      element.byte_start >= span.byte_end() {
      let parent = element.parent_index
      if parent >= 0 && parent < elements.length() {
        let holder = elements[parent]
        if holder.local_name == "body" && is_wml_uri(holder.uri) {
          successor_exists = true
        }
      }
    }
  }
  for id in bookmark_ends {
    guard bookmark_starts.get(id) is Some(_) else {
      raise Unsupported(
        message="delete-paragraph target '\{at}' carries a bookmark range boundary whose start lies outside it; deleting it would unbalance the range, so this deletion refuses",
      )
    }
  }
  for id, _name in bookmark_starts {
    guard bookmark_ends.contains(id) else {
      raise Unsupported(
        message="delete-paragraph target '\{at}' carries a bookmark range boundary whose end lies outside it; deleting it would unbalance the range, so this deletion refuses",
      )
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
  (plan, { path: at, para_id, anchor_status, text, successor_para_id, })
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
