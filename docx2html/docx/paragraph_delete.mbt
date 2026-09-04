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
/// the source it is cut from, and the span removed. The published part
/// must equal the source with exactly this span gone, byte for byte.
///
/// WHAT THIS PROVES, precisely: that the splice APPLIED as planned —
/// no second edit landed on the part, no engine bug moved the cut, no
/// zip round trip altered it. It does NOT prove the plan addressed the
/// paragraph the caller meant: the witness is built from the same span
/// the edit uses, so a mis-resolved address moves both together. The
/// check that binds an address to content is `--expect-text` against
/// the receipt's own projection. Held by reference, so proving it
/// costs a comparison and no copy.
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
  // A witness whose span does not lie inside its source describes no
  // possible cut: answer "no", never index past an end. This is public
  // API, and the only caller is a validator whose job is to fail shut.
  guard self.cut_start >= 0 &&
    self.cut_start <= self.cut_end &&
    self.cut_end <= self.source.length() else {
    return false
  }
  guard candidate.length() == self.expected_length() else { return false }
  // View equality is a memcmp intrinsic; a hand-rolled per-byte loop
  // over a multi-megabyte story is millions of guarded iterations for
  // the same answer.
  candidate[0:self.cut_start] == self.source[0:self.cut_start] &&
  candidate[self.cut_start:] == self.source[self.cut_end:]
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
/// What the published part must read like once this plan lands. The
/// transaction verifies it applied exactly — see the witness for what
/// that does and does not prove about ADDRESSING.
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
/// Whether any paired RANGE is open across the target: a range whose
/// start lies before it and whose end lies after it, in any of the
/// families CT_Body admits as a paragraph's own siblings (comments,
/// range permissions, bookmarks, tracked moves, customXml revision
/// ranges). Deleting a paragraph such a range spans takes content the
/// range anchors, and the markers are not inside the span, so the
/// subtree walk cannot see them.
///
/// This counts DEPTH per family and never reads an id or a name. The
/// pairing model it replaces read both, and every review round found
/// another way for that to be wrong: ids that repeat, ids spelled `01`
/// and `1`, ids a producer left unreadable, names resolved from the
/// wrong marker, and a name lookup that turned the walk quadratic. A
/// counter has none of those failure modes.
///
/// The depth walk mirrors the field-region one exactly, and for the
/// same two reasons. An end with nothing open is UNPAIRABLE — refuse,
/// rather than let it cancel a range that genuinely is open (clamping
/// to zero was the unsafe direction). And a range only counts as open
/// ACROSS the target when the depth after it falls BELOW the depth at
/// it — otherwise one unclosed start earlier in the story would make
/// the next end anywhere later refuse every paragraph in between.
fn open_range_across(
  elements : Array[ScannedElement],
  span : NodeSpan,
) -> String? {
  let depth : Map[String, Int] = Map([])
  let unbalanced : Array[String] = []
  let ends_inside : Array[String] = []
  // Pass zero: does each family BALANCE across the whole story? Depth
  // counting reads no ids, so it cannot tell which range an end closes
  // — an end belonging to one bookmark cancels another's start just as
  // well. That is only possible in a story whose markers do not
  // balance, so an unbalanced family means "this cannot be judged",
  // and this verb refuses what it cannot judge. (0 of 591 documents in
  // the corpus sample carry an unbalanced range marker.)
  let totals : Map[String, Int] = Map([])
  let lowest : Map[String, Int] = Map([])
  let before_target : Map[String, Bool] = Map([])
  let after_target : Map[String, Bool] = Map([])
  for element in elements {
    guard range_family_of(element) is Some((family, starts)) else { continue }
    let current = totals.get(family).unwrap_or(0)
    let next = if starts { current + 1 } else { current - 1 }
    totals[family] = next
    // The running MINIMUM catches what a total cannot: an end before
    // its start nets to zero across the story while genuinely leaving
    // a range unpairable at the point it matters.
    if next < lowest.get(family).unwrap_or(0) {
      lowest[family] = next
    }
    if element.byte_end <= span.byte_start() {
      before_target[family] = true
    } else if element.byte_start >= span.byte_end() {
      after_target[family] = true
    }
  }
  for family, total in totals {
    // Unpairable markers only matter when they could reach the target:
    // a family whose markers all sit on ONE side of it cannot have a
    // range spanning it, whatever its totals say. Refusing those too
    // would take the whole document out over a stray marker nowhere
    // near the edit.
    let straddles = before_target.get(family).unwrap_or(false) &&
      after_target.get(family).unwrap_or(false)
    let inverted = lowest.get(family).unwrap_or(0) < 0
    if (total != 0 || inverted) && straddles && !unbalanced.contains(family) {
      unbalanced.push(family)
    }
  }
  if unbalanced.length() > 0 {
    unbalanced.sort()
    // Fail CLOSED: `None` here means "no hazard, proceed with the
    // irreversible deletion", which is never the right answer from
    // inside a hazard detector that just found one.
    let family = unbalanced.get(0).unwrap_or("a range")
    return Some(
      "this story's range markers do not balance (\{family}), so which content a range covers cannot be judged",
    )
  }
  // Pass one: the depth each family stands at when the target begins.
  for element in elements {
    guard range_family_of(element) is Some((family, starts)) else { continue }
    let inside = element.byte_start >= span.byte_start() &&
      element.byte_end <= span.byte_end()
    if inside {
      // An END inside, while a range of the same family is open across
      // the target, is a boundary a consumer could pair with that
      // outside start: removing it strands the start whatever the ids
      // say. (Markers that pair wholly inside are the subtree walk's
      // business.)
      if !starts && depth.get(family).unwrap_or(0) > 0 {
        if !ends_inside.contains(family) {
          ends_inside.push(family)
        }
      }
      continue
    }
    if element.byte_end <= span.byte_start() {
      let current = depth.get(family).unwrap_or(0)
      depth[family] = if starts { current + 1 } else { current - 1 }
    }
  }
  if ends_inside.length() > 0 {
    ends_inside.sort()
    let family = ends_inside.get(0).unwrap_or("a range")
    return Some(
      "the target paragraph carries the end of \{family} opened before it",
    )
  }
  // Pass two: for each family standing open at the target, does it
  // CLOSE after it? Only then does the range span the target.
  let closes_after : Array[String] = []
  for family, entry_depth in depth {
    if entry_depth <= 0 {
      continue
    }
    let mut current = entry_depth
    for element in elements {
      if element.byte_start < span.byte_end() {
        continue
      }
      guard range_family_of(element) is Some((candidate, starts)) else {
        continue
      }
      if candidate != family {
        continue
      }
      if starts {
        current += 1
      } else {
        current -= 1
        if current < entry_depth {
          if !closes_after.contains(family) {
            closes_after.push(family)
          }
          break
        }
      }
    }
  }
  // Deterministic: the message must not depend on map order.
  closes_after.sort()
  match closes_after.get(0) {
    Some(family) =>
      Some(
        "the target paragraph sits inside \{family} opened before it and closed after it",
      )
    None => None
  }
}

///|
/// `w:id` is `ST_DecimalNumber`, so `1`, `01` and `0001` are one id.
/// Comparing raw spellings would refuse a legal document and pair two
/// ids a consumer keeps apart.
fn normalized_decimal_id(id : String) -> String {
  let negative = id.has_prefix("-")
  let digits = if negative { id[1:].to_owned() } else { id }
  // ONLY a decimal number canonicalizes as one. `0abc` is not the
  // number zero followed by letters — it is a spelling this reader
  // does not understand, and collapsing it onto `abc` would pair two
  // ids a consumer keeps apart.
  guard digits.length() > 0 else { return id }
  for ch in digits {
    guard ch is ('0'..='9') else { return id }
  }
  let mut first = 0
  while first + 1 < digits.length() && digits[first] == '0' {
    first += 1
  }
  let trimmed = digits[first:].to_owned()
  if negative {
    "-" + trimmed
  } else {
    trimmed
  }
}

///|
/// Every refusal this planner raises, as a STABLE SLUG plus prose. The
/// slug is the machine's answer and the prose is the reader's; a
/// consumer that needs to branch reads the slug and never the sentence,
/// so rewording a message cannot silently reclassify a hazard and no
/// substring can shadow another. The prefix is stripped before the
/// message reaches a caller.
fn delete_refusal(slug : String, prose : String) -> DocxError {
  Unsupported(message="delete/" + slug + ": " + prose)
}

///|
/// The prose half of a refusal this planner raised, or the message
/// unchanged when it came from somewhere else.
pub fn docx_delete_refusal_prose(message : String) -> String {
  guard message.has_prefix("delete/") else { return message }
  match message.find(": ") {
    Some(colon) => message[colon + 2:].to_owned()
    None => message
  }
}

///|
/// The slug half, when this planner raised it.
pub fn docx_delete_refusal_slug(message : String) -> String? {
  guard message.has_prefix("delete/") else { return None }
  match message.find(": ") {
    Some(colon) => Some(message[7:colon].to_owned())
    None => None
  }
}

///|
/// The range family an element belongs to, and whether it opens one.
/// Families are kept apart because their id spaces are independent and
/// their hazards are different.
fn range_family_of(element : ScannedElement) -> (String, Bool)? {
  guard is_wml_uri(element.uri) else { return None }
  match element.local_name {
    "commentRangeStart" => Some(("a comment range", true))
    "commentRangeEnd" => Some(("a comment range", false))
    "permStart" => Some(("a range permission", true))
    "permEnd" => Some(("a range permission", false))
    "bookmarkStart" => Some(("a bookmark range", true))
    "bookmarkEnd" => Some(("a bookmark range", false))
    "moveFromRangeStart" => Some(("a tracked move-from range", true))
    "moveFromRangeEnd" => Some(("a tracked move-from range", false))
    "moveToRangeStart" => Some(("a tracked move-to range", true))
    "moveToRangeEnd" => Some(("a tracked move-to range", false))
    "customXmlInsRangeStart" => Some(("a customXml insertion range", true))
    "customXmlInsRangeEnd" => Some(("a customXml insertion range", false))
    "customXmlDelRangeStart" => Some(("a customXml deletion range", true))
    "customXmlDelRangeEnd" => Some(("a customXml deletion range", false))
    "customXmlMoveFromRangeStart" => Some(("a customXml move-from range", true))
    "customXmlMoveFromRangeEnd" => Some(("a customXml move-from range", false))
    "customXmlMoveToRangeStart" => Some(("a customXml move-to range", true))
    "customXmlMoveToRangeEnd" => Some(("a customXml move-to range", false))
    _ => None
  }
}

///|
/// The body FLOW kind an element contributes, read the way a consumer
/// lays the story out rather than the way the tree nests it: this walks
/// THROUGH layout-transparent wrappers, so a table inside a content
/// control answers `Some("tbl")`. It is deliberately NOT the
/// direct-child proof — `is_direct_body_child` is that, and it is what
/// stops a splice inside a wrapper. These are the file's two surfaces,
/// and confusing them is how a guard goes blind.
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
    // BLOCK-LEVEL content inside a paragraph: the reader tolerates
    // misnesting, and the span would then hold more logical content
    // than the receipt names — a table that left with a paragraph is
    // invisible to every readback leg, since the plan removed exactly
    // the bytes it said it would.
    "p" => Some("a nested paragraph")
    "tbl" => Some("a nested table")
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
  // Canonical as the reader spells them: `p[007]` is not a path any
  // surface emits, and admitting it here would let this seam accept
  // addresses the CLI grammar refuses. (The rule is the DELETE verb's:
  // `insert_anchor_ordinal` is shared with the shipped insertion
  // planner, whose published contract this must not narrow.)
  guard !at.has_prefix("p[0") && insert_anchor_ordinal(at) is Some(ordinal) else {
    raise delete_refusal(
      "target_not_direct", "delete-paragraph targets a direct body paragraph (p[N]); this target is not one",
    )
  }
  guard annotated.body_paragraph_span(at) is Some(span) else {
    raise delete_refusal(
      "target_not_found", "the delete-paragraph target does not resolve in this document",
    )
  }
  let part = annotated.main_story_part()
  guard annotated.reader_projection_sources.get(part) is Some(bytes) else {
    raise delete_refusal(
      "engine_unavailable", "delete-paragraph requires a mutation-safe read with retained source bytes",
    )
  }
  guard annotated.reader_projections.get(part) is Some(projection) else {
    raise delete_refusal(
      "engine_unavailable", "delete-paragraph requires a mutation-safe read with a retained projection",
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
    raise delete_refusal(
      "target_not_direct", "the delete-paragraph target is not a DIRECT child of the body — paragraphs inside content controls, revisions, or compatibility wrappers are not deletion targets",
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
      raise delete_refusal(
        "table_separator", "the target paragraph separates two tables; deleting it would merge them into one, so this deletion refuses",
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
    // Counted on the PHYSICAL tree, deliberately — including boundaries
    // inside track-deleted content and unselected compatibility
    // branches. This verb performs a physical byte splice, and a
    // `fldChar` the reader suppresses is still THERE in the published
    // file: a consumer that rejects the tracked deletion, or that
    // understands the branch this reader does not, gets its field back
    // around a hole where a paragraph used to be. The projection stance
    // reads better and is wrong for a physical cut.
    if is_wml_uri(element.uri) && element.local_name == "fldChar" {
      // An ambiguous boundary is one this reader cannot judge, and a
      // field whose depth cannot be judged is one this verb will not
      // edit around.
      guard !element.field_char_type_ambiguous else {
        raise delete_refusal(
          "field_region", "this story carries a field boundary whose type cannot be read unambiguously, so field regions cannot be judged and this deletion refuses",
        )
      }
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
      raise delete_refusal(
        "field_region", "the target paragraph sits inside a field region whose boundaries lie in other paragraphs; deleting it would truncate the field, so this deletion refuses",
      )
    }
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
    if element.byte_start >= span.byte_start() &&
      element.byte_end <= span.byte_end() {
      // The target element itself is skipped only for the CLASSIFIER
      // (it would self-refuse as "a nested paragraph"); its own
      // attributes are judged like any other element's.
      if element.references_relationship &&
        !(is_wml_uri(element.uri) && element.local_name == "hyperlink") {
        raise delete_refusal(
          "relationship_reference", "the target paragraph carries an element that references a package relationship; deleting it would touch relationship reachability, so this deletion refuses",
        )
      }
      // The hazard judgment sees EVERY namespace: gating it on WML is
      // how `w14:conflictIns` — revision history by any measure — slid
      // through an earlier round of this same list.
      if index != target_index {
        match delete_blocked_construct(element.uri, element.local_name) {
          Some(reason) =>
            raise delete_refusal(
              "blocked_construct",
              "the target paragraph carries \{reason}; deleting it would dangle or destroy document state outside the paragraph, so this deletion refuses",
            )
          None => ()
        }
      }
      if index != target_index && is_wml_uri(element.uri) {
        if element.local_name == "bookmarkStart" {
          // Only the _GoBack cursor artifact is deletable, and only
          // with a REAL id: an absent id cannot be paired at all.
          guard element.bookmark_name_raw is Some(name) else {
            raise delete_refusal(
              "bookmark_unpairable", "the target paragraph carries a bookmark marker whose name could not be read; the pairing cannot be judged, so this deletion refuses",
            )
          }
          guard name == "_GoBack" else {
            raise delete_refusal(
              "blocked_construct", "the target paragraph carries a named bookmark; deleting it would dangle or destroy document state outside the paragraph, so this deletion refuses",
            )
          }
          guard element.bookmark_id_raw is Some(id) && id != "" else {
            raise delete_refusal(
              "bookmark_unpairable", "the target paragraph carries a bookmark marker without a usable id; the pairing cannot be judged, so this deletion refuses",
            )
          }
          let key = normalized_decimal_id(id)
          bookmark_starts[key] = bookmark_starts.get(key).unwrap_or(0) + 1
        }
        if element.local_name == "bookmarkEnd" {
          guard element.bookmark_id_raw is Some(id) && id != "" else {
            raise delete_refusal(
              "bookmark_unpairable", "the target paragraph carries a bookmark marker without a usable id; the pairing cannot be judged, so this deletion refuses",
            )
          }
          let key = normalized_decimal_id(id)
          bookmark_ends[key] = bookmark_ends.get(key).unwrap_or(0) + 1
        }
      }
    }
  }
  // Balanced as MULTISETS: one start, one end, per id. Counting closes
  // the duplicate-end quadrant that set membership left open.
  for id, ends in bookmark_ends {
    guard bookmark_starts.get(id) is Some(starts) && starts == ends else {
      raise delete_refusal(
        "bookmark_unpairable", "the target paragraph carries bookmark boundaries that do not pair inside it; deleting it would unbalance the range, so this deletion refuses",
      )
    }
  }
  for id, starts in bookmark_starts {
    guard bookmark_ends.get(id) is Some(ends) && ends == starts else {
      raise delete_refusal(
        "bookmark_unpairable", "the target paragraph carries bookmark boundaries that do not pair inside it; deleting it would unbalance the range, so this deletion refuses",
      )
    }
  }
  // Ranges that BRACKET the target: markers CT_Body admits as the
  // target's own siblings, whose start precedes it and whose end
  // follows. The subtree scan below cannot see them — they are not
  // inside the span — and deleting the paragraph empties the range
  // they anchor.
  match open_range_across(elements, span) {
    Some(reason) =>
      raise delete_refusal(
        "open_range",
        "\{reason}; deleting it would take or strand content a range anchors, so this deletion refuses",
      )
    None => ()
  }
  // The document-final direct body paragraph is structural: Word keeps
  // one, and a body whose last flow child is a table still needs its
  // trailing paragraph. No successor -> refuse.
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
  guard successor_exists else {
    raise delete_refusal(
      "final_paragraph", "the target is the final direct body paragraph; the document keeps it",
    )
  }
  let story = annotated.main_story_source()
  let anchors = docx_paragraph_anchor_index(annotated, story)
  // A path the anchor index tombstoned (a collided head, or the tail
  // of a revision-joined paragraph) does not address exactly one
  // whole logical paragraph — refuse rather than delete more or less
  // than the receipt could name.
  guard anchors.anchor_at(at) is Some(anchor) else {
    raise delete_refusal(
      "target_not_addressable", "the delete-paragraph target does not address exactly one whole paragraph in this document, so this deletion refuses",
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
    raise delete_refusal(
      "target_not_addressable", "the delete-paragraph target is one physical half of a paragraph joined across a deleted paragraph mark, so this deletion refuses",
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
    raise delete_refusal(
      "target_not_addressable", "the delete-paragraph target has no readable projection in this document, so this deletion refuses",
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
    raise delete_refusal(
      "engine_unavailable", "counting direct paragraphs requires a mutation-safe read with a retained projection",
    )
  }
  let elements = projection.scan.elements()
  let mut count = 0
  for element in elements {
    if element.local_name == "p" &&
      is_wml_uri(element.uri) &&
      is_direct_body_child(elements, element) {
      count += 1
    }
  }
  count
}
