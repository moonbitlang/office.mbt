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
  // The paragraph BEFORE the target, at its own path. Deleting `p[N]`
  // leaves every path below N where it was, so this is the witness that
  // still speaks when the target is the last paragraph and the document
  // carries no unique identities — the shape where every other
  // content-binding leg goes quiet at once. Not reported to callers:
  // it is evidence for the readback, not part of the answer.
  priv predecessor_path : String?
  priv predecessor_para_id : String?
  priv predecessor_text : String?
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
  //
  // EMPTY is not a cut. With `cut_start == cut_end` the two comparisons
  // below collapse to `candidate == source`, so an UNTOUCHED part would
  // satisfy the leg documented as the strongest evidence this verb has
  // — and `queue_plan` returns early on an empty plan, so a degenerate
  // span publishes an unchanged document while the receipt still names
  // a path, an identity and text. The planner refuses to build one
  // (see `plan_docx_paragraph_deletion`); this refuses to believe one.
  guard self.cut_start >= 0 &&
    self.cut_start < self.cut_end &&
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
/// The path the paragraph before the target answers at — unchanged by
/// the deletion, because a splice at `p[N]` moves no path below N.
pub fn DocxDeleteReceipt::predecessor_path(self : DocxDeleteReceipt) -> String? {
  self.predecessor_path
}

///|
/// The unique identity of the paragraph immediately BEFORE the target,
/// when it carries one. A readback witness, not a report field.
pub fn DocxDeleteReceipt::predecessor_para_id(
  self : DocxDeleteReceipt,
) -> String? {
  self.predecessor_para_id
}

///|
/// The projection of the paragraph immediately BEFORE the target. The
/// deletion does not move it, so it must read the same at the same path
/// afterwards — the leg that binds address to content on a document
/// with no identities whose target is the last paragraph.
pub fn DocxDeleteReceipt::predecessor_text(self : DocxDeleteReceipt) -> String? {
  self.predecessor_text
}

///|
/// What the published part must read like once this plan lands. The
/// transaction verifies it applied exactly — see the witness for what
/// that does and does not prove about ADDRESSING.
pub fn DocxDeleteReceipt::cut(self : DocxDeleteReceipt) -> DocxDeleteCutWitness {
  self.cut
}

///|
/// Range markers and proofing marks that CT_Body admits between blocks.
/// They occupy no layout, so they never stand between two blocks that
/// would otherwise meet — and Word emits them at body level routinely.
fn is_zero_width_body_marker(element : ScannedElement) -> Bool {
  guard is_wml_uri(element.uri) else { return false }
  range_family_of(element) is Some(_) ||
  element.local_name is ("proofErr" | "sectPr")
}

///|
/// The index of the story's OWN `w:body`: the one the root
/// `w:document` holds. Identity by ELEMENT, never by name.
///
/// `<w:body>` is not a reserved word — nothing stops a story from
/// carrying another one somewhere inside itself, and
/// `read_identity_story_xml_strict` is a well-formedness parser, not a
/// schema validator, so it admits `<w:sectPr><w:body><w:p/></w:body>`.
/// Matching on the local name alone made every paragraph under such an
/// element a "direct body child": phantom neighbours that satisfied the
/// neighbour precondition, phantom survivors that satisfied the
/// trailing-paragraph guarantee, and — because the readback counts with
/// the SAME predicate — a count leg that agreed with the guard it was
/// meant to check. One nested `<w:body>` could publish a body with no
/// real paragraph in it.
fn document_body_index(elements : Array[ScannedElement]) -> Int? {
  for index, element in elements {
    guard element.local_name == "body" && is_wml_uri(element.uri) else {
      continue
    }
    let parent = element.parent_index
    guard parent >= 0 && parent < elements.length() else { continue }
    let holder = elements[parent]
    // The root: `w:document` with no parent of its own. A `w:body`
    // under a NESTED `w:document` is not this story's body either.
    if holder.local_name == "document" &&
      is_wml_uri(holder.uri) &&
      holder.parent_index < 0 {
      return Some(index)
    }
  }
  None
}

///|
/// Whether an element is a DIRECT child of the story's own `w:body`.
/// The path grammar flattens wrappers (`w:sdt`, `w:ins`, `mc:Fallback`…),
/// so a path alone never proves this — every guard that must not splice
/// inside a wrapper proves it here, against the ONE body index.
fn is_direct_body_child(element : ScannedElement, body : Int) -> Bool {
  element.parent_index == body
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
/// Whether any id-paired RANGE spans the target, or has exactly one of
/// its ends inside it.
///
/// WML range markers pair by `w:id` and MAY OVERLAP — Word emits
/// interleaved `_Toc`/`_Ref` bookmarks around every cross-referenced
/// heading — so they are INTERVALS, not a nesting. Earlier rounds tried
/// depth counters (an end cancelling a start it never belonged to) and
/// a nesting stack (which declared ordinary Word documents malformed).
///
/// And an interval is a PAIR, not an envelope: matching each end to the
/// most recent open start OF THE SAME ID is what keeps two disjoint
/// ranges that reuse one id — routine in merged documents, and in
/// comment ids recycled after a delete — from reading as one long range
/// that covers everything between them.
fn open_range_across(
  elements : Array[ScannedElement],
  span : NodeSpan,
) -> String? {
  // Open starts per (family, id), and the concrete intervals they close
  // into.
  let open : Map[(RangeFamily, String), Array[Int]] = Map([])
  let caret : Map[(RangeFamily, String), Bool] = Map([])
  let named : Map[(RangeFamily, String), Bool] = Map([])
  let spanning : Array[RangeFamily] = []
  let split : Array[RangeFamily] = []
  // "Unresolved" on a side means: a marker there that this walk could
  // not pair — either its id is unreadable, or it is readable but never
  // met a partner. An unresolved marker before the target and another
  // after it MAY be one range bracketing it, and a range this reader
  // cannot rule out is one it will not edit around.
  let unresolved_before : Map[RangeFamily, Bool] = Map([])
  let unresolved_after : Map[RangeFamily, Bool] = Map([])
  // A marker this walk could not place is unresolved on the side it
  // sits. One INSIDE the target is unresolved on BOTH: its partner may
  // lie on either side, and an in-span marker is exactly the shape that
  // strands a range when the span is spliced out. Every arm below is
  // written as three branches, never as `before`/`else if after`, so
  // "inside" cannot fall out of the analysis by omission.
  fn note_unresolved(family : RangeFamily, from : Int, to : Int) -> Unit {
    if to <= span.byte_start() {
      unresolved_before[family] = true
    } else if from >= span.byte_end() {
      unresolved_after[family] = true
    } else {
      unresolved_before[family] = true
      unresolved_after[family] = true
    }
  }

  fn note_interval(
    family : RangeFamily,
    key : (RangeFamily, String),
    from : Int,
    to : Int,
  ) -> Unit {
    // Word's caret marks where the cursor was; it anchors nothing.
    // Exempt only when NO named bookmark shares the id.
    if caret.get(key).unwrap_or(false) && !named.get(key).unwrap_or(false) {
      return
    }
    let starts_before = from <= span.byte_start()
    let ends_after = to >= span.byte_end()
    let start_inside = from >= span.byte_start() && from < span.byte_end()
    let end_inside = to > span.byte_start() && to <= span.byte_end()
    if starts_before && ends_after {
      if !spanning.contains(family) {
        spanning.push(family)
      }
    } else if start_inside != end_inside {
      if !split.contains(family) {
        split.push(family)
      }
    }
  }

  for element in elements {
    guard range_family_of(element) is Some((family, starts)) else { continue }
    guard element.bookmark_id_raw is Some(raw) else {
      // A marker this reader cannot place. It only matters if an
      // unplaceable pair could straddle the target, so this is judged
      // target-relative rather than story-globally: a stray marker at
      // the far end of the document does not take the deletion out.
      note_unresolved(family, element.byte_start, element.byte_end)
      continue
    }
    let key = (family, range_id_key(family, raw))
    if starts {
      if element.bookmark_name_raw is Some("_GoBack") {
        caret[key] = true
      } else if element.local_name == "bookmarkStart" {
        named[key] = true
      }
      let pending = open.get(key).unwrap_or([])
      pending.push(element.byte_start)
      open[key] = pending
    } else {
      let pending = open.get(key).unwrap_or([])
      match pending.pop() {
        Some(from) => {
          open[key] = pending
          note_interval(family, key, from, element.byte_end)
        }
        // An end with no open start of this id: unpaired here, but its
        // partner may be one of the markers whose id could not be read.
        None => note_unresolved(family, element.byte_start, element.byte_end)
      }
    }
  }
  // Starts still open at the end of the walk are unpaired too.
  for key, pending in open {
    let (family, _) = key
    for position in pending {
      note_unresolved(family, position, position)
    }
  }
  // Per FAMILY: a permission and a comment range are never one pair,
  // so an unresolved marker of each on opposite sides rules out
  // nothing.
  let unpairable : Array[RangeFamily] = []
  for family, _ in unresolved_before {
    if unresolved_after.get(family).unwrap_or(false) &&
      !unpairable.contains(family) {
      unpairable.push(family)
    }
  }
  unpairable.sort()
  spanning.sort()
  split.sort()
  // One answer per shape, most specific first. Each family list is
  // sorted, so which family a multi-family hazard names is a property
  // of the document and not of element order.
  match unpairable.get(0) {
    Some(family) =>
      Some(
        "this story carries markers of \{family.label()} on both sides of the target that this reader cannot pair, so what they cover cannot be judged",
      )
    None =>
      match spanning.get(0) {
        Some(family) =>
          Some(
            "the target paragraph sits inside \{family.label()} opened before it and closed after it",
          )
        None =>
          match split.get(0) {
            Some(family) =>
              Some(
                "the target paragraph carries part of \{family.label()} whose other markers lie outside it",
              )
            None => None
          }
      }
  }
}

///|
/// `w:id` is `ST_DecimalNumber`, so `1`, `01` and `0001` are one id.
/// ONLY a decimal number canonicalizes as one: `0abc` is not zero
/// followed by letters, and collapsing it onto `abc` would pair two
/// ids a consumer keeps apart.
fn normalized_decimal_id(id : String) -> String {
  // `ST_DecimalNumber` derives from `xs:integer`, which carries the
  // COLLAPSE whitespace facet: `" 7 "` and `"7"` are one id to any
  // schema-validating consumer. Comparing raw spellings let a start and
  // an end of the same bookmark hash to different keys — the fail-open
  // direction on an irreversible verb.
  let id = @xml.collapse_xml_schema_whitespace(id)
  let negative = id.has_prefix("-")
  let signed = negative || id.has_prefix("+")
  let digits = if signed { id[1:].to_owned() } else { id }
  guard digits.length() > 0 else { return id }
  for ch in digits {
    guard ch is ('0'..='9') else { return id }
  }
  let mut first = 0
  while first + 1 < digits.length() && digits[first] == '0' {
    first += 1
  }
  let trimmed = digits[first:].to_owned()
  // `+7` and `7` are one id; `-7` is another. Zero has no sign.
  if negative && trimmed != "0" {
    "-" + trimmed
  } else {
    trimmed
  }
}

///|
/// What a `w:fldChar` contributes to field depth. One classifier, so a
/// walk that forgets the unreadable case cannot compile — the previous
/// four hand-written copies disagreed, and the one that dropped the
/// check let a paragraph be spliced out of an open field.
priv enum FieldBoundary {
  Opens
  Closes
  /// A boundary whose type is absent (the attribute is schema-REQUIRED)
  /// or spelled more than one way. Either is a boundary this reader
  /// cannot place.
  Unreadable
  NotABoundary
}

///|
fn field_boundary_of(element : ScannedElement) -> FieldBoundary {
  guard is_wml_uri(element.uri) && element.local_name == "fldChar" else {
    return NotABoundary
  }
  guard !element.field_char_type_ambiguous else { return Unreadable }
  match element.field_char_type {
    Some("begin") => Opens
    Some("end") => Closes
    // `separate` divides instruction from result INSIDE a region and
    // changes no depth.
    Some("separate") => NotABoundary
    _ => Unreadable
  }
}

///|
/// The pairing key for one family's id. Permissions carry `ST_String`
/// ids, which are compared as written; every other family carries
/// `ST_DecimalNumber`, where `" 7 "`, `"+7"`, `"07"` and `"7"` are one
/// id to any schema-validating consumer.
///
/// Which id space a family uses is a property of the FAMILY, matched on
/// the constructor. It was once decided by string-comparing the family
/// against its own refusal prose, so rewording that sentence — an
/// edit nothing would flag — moved permission ids onto decimal
/// canonicalization, hashed `w:id="007"` and `w:id="7"` to one key, and
/// reported two distinct permissions as one balanced pair.
fn range_id_key(family : RangeFamily, raw : String) -> String {
  match family {
    RangePermission => raw
    _ => normalized_decimal_id(raw)
  }
}

///|
/// A WML range family. Kept apart because their id spaces are
/// independent and their hazards are different — and kept as a TYPE
/// rather than as the sentence each one prints, so no judgment can be
/// made by string-matching prose.
///
/// Declared in the order the families' labels sort, because the
/// reported family for a target that trips several is the first, and a
/// refusal message must not change with the order elements happened to
/// appear in.
priv enum RangeFamily {
  BookmarkRange
  CommentRange
  CustomXmlDel
  CustomXmlIns
  CustomXmlMoveFrom
  CustomXmlMoveTo
  RangePermission
  TrackedMoveFrom
  TrackedMoveTo
} derive(Eq, Hash, Compare)

///|
/// How a family reads in a refusal. Prose only — nothing branches on it.
fn RangeFamily::label(self : RangeFamily) -> String {
  match self {
    BookmarkRange => "a bookmark range"
    CommentRange => "a comment range"
    CustomXmlDel => "a customXml deletion range"
    CustomXmlIns => "a customXml insertion range"
    CustomXmlMoveFrom => "a customXml move-from range"
    CustomXmlMoveTo => "a customXml move-to range"
    RangePermission => "a range permission"
    TrackedMoveFrom => "a tracked move-from range"
    TrackedMoveTo => "a tracked move-to range"
  }
}

///|
/// Whether a WML local name is a range marker — the ONE spelling of
/// this vocabulary. The scanner asks it to decide whose `w:id` to
/// retain, and `range_family_of` answers with it, so a family cannot be
/// added to one and forgotten in the other: a marker captured but never
/// classified is invisible to the pairing walk, which is the fail-open
/// direction on an irreversible verb.
fn is_wml_range_marker_name(local_name : String) -> Bool {
  local_name
  is ("bookmarkStart"
  | "bookmarkEnd"
  | "commentRangeStart"
  | "commentRangeEnd"
  | "permStart"
  | "permEnd"
  | "moveFromRangeStart"
  | "moveFromRangeEnd"
  | "moveToRangeStart"
  | "moveToRangeEnd"
  | "customXmlInsRangeStart"
  | "customXmlInsRangeEnd"
  | "customXmlDelRangeStart"
  | "customXmlDelRangeEnd"
  | "customXmlMoveFromRangeStart"
  | "customXmlMoveFromRangeEnd"
  | "customXmlMoveToRangeStart"
  | "customXmlMoveToRangeEnd")
}

///|
/// The range family an element belongs to, and whether it opens one.
/// Every name `is_wml_range_marker_name` admits has an arm here, and
/// the escape test below proves it.
fn range_family_of(element : ScannedElement) -> (RangeFamily, Bool)? {
  guard is_wml_uri(element.uri) else { return None }
  match element.local_name {
    "commentRangeStart" => Some((CommentRange, true))
    "commentRangeEnd" => Some((CommentRange, false))
    "permStart" => Some((RangePermission, true))
    "permEnd" => Some((RangePermission, false))
    "bookmarkStart" => Some((BookmarkRange, true))
    "bookmarkEnd" => Some((BookmarkRange, false))
    "moveFromRangeStart" => Some((TrackedMoveFrom, true))
    "moveFromRangeEnd" => Some((TrackedMoveFrom, false))
    "moveToRangeStart" => Some((TrackedMoveTo, true))
    "moveToRangeEnd" => Some((TrackedMoveTo, false))
    "customXmlInsRangeStart" => Some((CustomXmlIns, true))
    "customXmlInsRangeEnd" => Some((CustomXmlIns, false))
    "customXmlDelRangeStart" => Some((CustomXmlDel, true))
    "customXmlDelRangeEnd" => Some((CustomXmlDel, false))
    "customXmlMoveFromRangeStart" => Some((CustomXmlMoveFrom, true))
    "customXmlMoveFromRangeEnd" => Some((CustomXmlMoveFrom, false))
    "customXmlMoveToRangeStart" => Some((CustomXmlMoveTo, true))
    "customXmlMoveToRangeEnd" => Some((CustomXmlMoveTo, false))
    _ => None
  }
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
    // A data-bound content control anchors a customXml island; removing
    // it strands the item and its properties, the same family of hazard
    // as a note, a comment or a relationship.
    "dataBinding" => Some("a content-control data binding")
    // NOT "fldChar": a COMPLETE field inside the target — a page
    // number, a DATE, a REF, any TOC entry — balances within the span
    // and dangles nothing. Only a SPLIT one refuses, and splitness is
    // decided by the depth walk, not by the presence of a boundary.
    // Blanket-refusing here made a large fraction of real Word
    // paragraphs undeletable while the docs promised otherwise.
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
    // GRAMMAR, not structure: the caller can reformat and retry. The
    // structural sibling below (a path that resolves but names a
    // paragraph inside a wrapper) can never succeed, and sharing one
    // slug made those indistinguishable.
    raise delete_refusal(
      "target_grammar", "delete-paragraph targets a direct body paragraph (p[N]); this target is not one",
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
  // The story's own body, resolved ONCE: every direct-child question
  // below compares against this exact element, so a `<w:body>` nested
  // anywhere else in the story is not one of them.
  let body = document_body_index(elements).unwrap_or(-1)
  // The target must be a PHYSICAL direct child of w:body — the path
  // grammar flattens wrappers, so the path alone proves nothing — and
  // its element index is the key to its subtree.
  let mut target_index = -1
  for index, element in elements {
    if element.byte_start == span.byte_start() &&
      element.local_name == "p" &&
      is_wml_uri(element.uri) {
      if is_direct_body_child(element, body) {
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
  // THE NEIGHBOUR PRECONDITION.
  //
  // What a deletion must not do is change anything except remove its
  // paragraph, and the ways it can are all about what the target sits
  // BETWEEN: two tables it keeps apart merge; a block only some
  // consumers render may or may not be there; a wrapper's contents may
  // be the real neighbour or may vanish.
  //
  // Seven rebuilds of a "flow surface" tried to decide those cases by
  // modelling which consumer sees what — transparency, suppression,
  // alternatives, accept-versus-reject — and each version closed one
  // hole and opened another, because the two questions it had to answer
  // ("would these blocks touch" and "does a paragraph remain") have
  // opposite safe answers and one model cannot hold both.
  //
  // So v1 does not model it. The target's immediate DIRECT body
  // siblings must each be a paragraph or nothing at all. That is a
  // precondition this reader can check exactly, and under it no
  // adjacency question survives: paragraphs do not merge, and a
  // paragraph neighbour is a paragraph to every consumer. A target
  // beside a table, a content control, or a compatibility alternative
  // refuses — an honest v1 boundary, stated in the message, rather
  // than a model whose corners keep being found.
  let mut previous_sibling : ScannedElement? = None
  let mut next_sibling : ScannedElement? = None
  for index, element in elements {
    guard is_direct_body_child(element, body) &&
      !is_zero_width_body_marker(element) else {
      continue
    }
    if index < target_index {
      previous_sibling = Some(element)
    } else if index > target_index && next_sibling is None {
      next_sibling = Some(element)
    }
  }
  fn sibling_is_paragraph(sibling : ScannedElement?) -> Bool {
    match sibling {
      Some(element) => is_wml_uri(element.uri) && element.local_name == "p"
      None => true
    }
  }

  guard sibling_is_paragraph(previous_sibling) &&
    sibling_is_paragraph(next_sibling) else {
    raise delete_refusal(
      "neighbour_not_paragraph", "the target paragraph sits beside a block that is not a paragraph (a table, a content control, a compatibility alternative); deleting it could change how those blocks meet, which this version does not judge, so this deletion refuses",
    )
  }
  // A paragraph strictly INSIDE an open field region carries part of a
  // field whose `fldChar` boundaries live in other paragraphs: the
  // instruction or result would be truncated with the paragraph.
  //
  // Fields DO nest (they carry no ids and cannot overlap), so depth is
  // the right model here — unlike ranges, which pair by id and may
  // overlap. Counted on the PHYSICAL tree, deliberately, including
  // boundaries inside track-deleted content and unselected
  // compatibility branches: this verb performs a physical byte splice,
  // and a boundary the reader suppresses is still THERE in the
  // published file.
  //
  // Every boundary is classified through ONE function, so a judgment
  // that forgets to handle an unreadable type cannot compile.
  let mut field_depth = 0
  for element in elements {
    if element.byte_start >= span.byte_start() {
      break
    }
    match field_boundary_of(element) {
      Opens => field_depth += 1
      Closes => if field_depth > 0 { field_depth -= 1 }
      Unreadable =>
        raise delete_refusal(
          "field_region", "this story carries a field boundary whose type cannot be read, so field regions cannot be judged and this deletion refuses",
        )
      NotABoundary => ()
    }
  }
  if field_depth > 0 {
    // A region only truncates if it CLOSES after the target. An orphan
    // `begin` — which Word tolerates — must not refuse every paragraph
    // that follows it, naming a field that does not exist. The region
    // open AT the target is the one that must close: an unrelated
    // well-formed field later in the story is not this one closing.
    let mut closes_after = false
    let mut depth = field_depth
    for element in elements {
      if element.byte_start < span.byte_end() {
        continue
      }
      match field_boundary_of(element) {
        Opens => depth += 1
        Closes => {
          depth -= 1
          if depth < field_depth {
            closes_after = true
            break
          }
        }
        Unreadable =>
          raise delete_refusal(
            "field_region", "this story carries a field boundary whose type cannot be read, so field regions cannot be judged and this deletion refuses",
          )
        NotABoundary => ()
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
  // Field boundaries INSIDE the target must pair there: a complete
  // field leaves with its paragraph and dangles nothing, while a
  // begin or end whose partner lies outside is a SPLIT field the
  // deletion would truncate.
  let mut inside_field_depth = 0
  let mut inside_field_split = false
  for index, element in elements {
    if element.byte_start >= span.byte_start() &&
      element.byte_end <= span.byte_end() {
      match field_boundary_of(element) {
        Opens => inside_field_depth += 1
        Closes => {
          inside_field_depth -= 1
          if inside_field_depth < 0 {
            inside_field_split = true
          }
        }
        Unreadable =>
          raise delete_refusal(
            "field_region", "the target paragraph carries a field boundary whose type cannot be read, so this deletion refuses",
          )
        NotABoundary => ()
      }
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
          // with a REAL id: an absent id cannot be paired at all. A name
          // this reader cannot read as `_GoBack` — absent, spelled twice,
          // or over the retention cap — is a named bookmark here, the
          // same answer every other consumer gives it.
          guard element.bookmark_name_raw is Some("_GoBack") else {
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
  if inside_field_split || inside_field_depth != 0 {
    raise delete_refusal(
      "field_region", "the target paragraph carries a split field boundary whose partner lies outside it; deleting it would truncate the field, so this deletion refuses",
    )
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
  // THE BODY KEEPS A PARAGRAPH.
  //
  // Counted on DIRECT body children, the same surface the neighbour
  // precondition uses: a paragraph inside a content control, a tracked
  // deletion, or one branch of a compatibility alternative may render
  // for nobody, so it cannot be the paragraph that keeps this promise.
  // With neighbours already required to be paragraphs, the only way a
  // deletion can end the body with a table is by removing the last
  // direct paragraph, which this catches.
  let mut direct_paragraphs = 0
  for index, element in elements {
    if element.local_name == "p" &&
      is_wml_uri(element.uri) &&
      is_direct_body_child(element, body) &&
      index != target_index {
      direct_paragraphs += 1
    }
  }
  let keeps_trailing_paragraph = direct_paragraphs > 0
  guard keeps_trailing_paragraph else {
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
  fn unique_identity_at(path : String) -> String? {
    match anchors.anchor_at(path) {
      Some(anchor) =>
        if anchor.status() == "unique" {
          anchor.para_id()
        } else {
          None
        }
      None => None
    }
  }

  let successor_para_id = unique_identity_at("p[\{ordinal + 1}]")
  // The paragraph BEFORE the target keeps its own path across the
  // splice, so it is a witness the readback can check without any
  // identity in the document. Absent when the target is `p[1]`.
  let (predecessor_path, predecessor_para_id, predecessor_text) = if ordinal > 1 {
    let path = "p[\{ordinal - 1}]"
    (
      Some(path),
      unique_identity_at(path),
      docx_paragraph_projection(annotated, story, path~),
    )
  } else {
    (None, None, None)
  }
  guard docx_paragraph_projection(annotated, story, path=at) is Some(text) else {
    raise delete_refusal(
      "target_not_addressable", "the delete-paragraph target has no readable projection in this document, so this deletion refuses",
    )
  }
  // A paragraph occupies bytes. A zero-length span would queue nothing
  // and publish an unchanged document, so it is refused HERE — where
  // the span is built — rather than left for the readback to notice.
  guard span.byte_start() < span.byte_end() else {
    raise delete_refusal(
      "target_not_addressable", "the delete-paragraph target resolves to an empty byte span, which removes nothing, so this deletion refuses",
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
  // AT LEAST ONE WITNESS BINDS THE ADDRESS TO CONTENT.
  //
  // The cut leg proves the splice applied as planned and nothing more:
  // its witness and its edit are built from ONE span, so a mis-resolved
  // address moves both together. The count leg reads `n - 1` whichever
  // paragraph left. What actually says WHICH paragraph went is an
  // identity that must disappear, or a neighbour's text that must still
  // read the same at its own path — and on a document with no unique
  // paraIds whose target is the last paragraph, all of those can be
  // absent at once. A deletion nothing can verify is not published.
  guard para_id is Some(_) ||
    successor_text is Some(_) ||
    predecessor_text is Some(_) else {
    raise delete_refusal(
      "unverifiable", "this document offers no identity and no readable neighbour text to verify the deletion against, so what was removed could not be confirmed after the fact and this deletion refuses",
    )
  }
  (
    plan,
    {
      path: at,
      para_id,
      anchor_status,
      text,
      successor_para_id,
      successor_text,
      predecessor_path,
      predecessor_para_id,
      predecessor_text,
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
  let body = document_body_index(elements).unwrap_or(-1)
  let mut count = 0
  for element in elements {
    if element.local_name == "p" &&
      is_wml_uri(element.uri) &&
      is_direct_body_child(element, body) {
      count += 1
    }
  }
  count
}
