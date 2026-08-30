// Paragraph identity provenance (paraId R1).
//
// `w14:paraId` is IMPORTED, IMMUTABLE provenance: reads never stamp or
// repair it, duplicated ids never resolve first-wins, and invalid
// spellings are reported, never normalized in place. This layer turns
// the scanner's as-spelled capture into per-paragraph anchor judgments;
// it is built from the retained projection and its scan — never from
// the annotation index, which stays presentation data, not identity
// authority.

///|
/// One logical paragraph's stable-anchor judgment.
///
/// `path` is where the paragraph is in THIS snapshot; the anchor is what
/// the paragraph IS across structural edits. The two are deliberately
/// separate dimensions — and both are separate from planner
/// editability (`actionable`), which this layer never touches.
pub struct DocxParagraphAnchor {
  /// `unique`, `missing`, `invalid`, `duplicate`, or `multi_physical`.
  priv status : String
  /// The canonical (uppercase) value when the spelling is a valid
  /// paraId — present for `unique` AND `duplicate` (both carriers
  /// report the value; neither duplicate is an addressable anchor).
  /// Absent for `missing`, `invalid`, and `multi_physical`.
  priv para_id : String?
  /// For `multi_physical` only: the valid canonical ids of the
  /// PARTICIPATING physical paragraphs, in document order, bounded — a
  /// diagnostic inventory, never a singular anchor. One element when a
  /// single physical paragraph is shared by several logical ones.
  priv physical_para_ids : Array[String]
}

///|
/// The anchor status: `unique`, `missing`, `invalid`, `duplicate`, or
/// `multi_physical`.
pub fn DocxParagraphAnchor::status(self : DocxParagraphAnchor) -> String {
  self.status
}

///|
/// The canonical (uppercase) paraId when the spelling is valid and the
/// anchor is a carrier (`unique` or `duplicate`); `None` otherwise.
pub fn DocxParagraphAnchor::para_id(self : DocxParagraphAnchor) -> String? {
  self.para_id
}

///|
/// For `multi_physical` anchors only: the valid canonical ids of the
/// participating physical paragraphs, in document order, bounded.
pub fn DocxParagraphAnchor::physical_para_ids(
  self : DocxParagraphAnchor,
) -> Array[String] {
  // A COPY: arrays are reference-backed, and a caller's mutation must
  // not rewrite the anchor's judgment.
  self.physical_para_ids.copy()
}

///|
/// How many joined physical ids a `multi_physical` anchor reports
/// before truncating: the inventory is diagnostic, and a revision-heavy
/// join must not turn an anchor record into a payload.
let max_reported_physical_para_ids : Int = 8

///|
/// Validate one as-spelled paraId and return its canonical uppercase
/// form: exactly eight ASCII hex digits (either case), nonzero, and
/// below 0x80000000 (MS-DOCX: greater than zero, high bit clear).
/// Anything else is not an identity.
///
/// Distinct from the comments layer's `canonical_para_id`, which only
/// case-normalizes conforming spellings for comparison and passes
/// everything else through verbatim — this is the ADDRESSING judgment,
/// and it rejects what it cannot vouch for.
pub fn validated_para_id(raw : String) -> String? {
  guard raw.length() == 8 else { return None }
  let builder = StringBuilder(size_hint=8)
  let mut all_zero = true
  for index, character in raw {
    let code = character.to_int()
    let upper = if code >= 'a'.to_int() && code <= 'f'.to_int() {
      code - 32
    } else {
      code
    }
    let is_hex = (upper >= '0'.to_int() && upper <= '9'.to_int()) ||
      (upper >= 'A'.to_int() && upper <= 'F'.to_int())
    guard is_hex else { return None }
    if upper != '0'.to_int() {
      all_zero = false
    }
    // The high bit lives in the FIRST digit: 8-F there means a value
    // at or above 0x80000000, which the format reserves.
    if index == 0 && upper >= '8'.to_int() && upper <= '9'.to_int() {
      return None
    }
    if index == 0 && upper >= 'A'.to_int() && upper <= 'F'.to_int() {
      return None
    }
    builder.write_char(upper.unsafe_to_char())
  }
  guard !all_zero else { return None }
  Some(builder.to_string())
}

///|
/// Per-story anchor index. The AUTHORITATIVE key is the logical
/// paragraph's projection index — paths are NOT unique (a tolerated
/// nested paragraph makes two logical paragraphs share one physical
/// head, hence one path), so a path-keyed lookup refuses collided
/// paths rather than answering for either claimant.
pub struct DocxParagraphAnchorIndex {
  priv anchors : Array[DocxParagraphAnchor?]
  priv by_path : Map[String, DocxParagraphAnchor?]
  // The scanner paragraph path per projection paragraph — the address a
  // resolved identity CURRENTLY answers to.
  priv paths : Array[String?]
  // canonical id -> projection indices of ADDRESSABLE carriers (single
  // physical, not shared; status unique or duplicate). A carrier buried
  // inside a multi-physical join is deliberately NOT here — it counts
  // in `buried_para_ids` so resolution can refuse with the truth.
  priv by_para_id : Map[String, Array[Int]]
  priv buried_para_ids : Map[String, Int]
}

///|
/// The judgment for one projected logical paragraph, by its index in
/// the projection — the join `find` and the planners already hold.
pub fn DocxParagraphAnchorIndex::anchor_of_paragraph(
  self : DocxParagraphAnchorIndex,
  paragraph_index : Int,
) -> DocxParagraphAnchor? {
  match self.anchors.get(paragraph_index) {
    Some(anchor) => anchor
    None => None
  }
}

///|
/// The scanner paragraph path a projection paragraph answers to in
/// THIS snapshot.
pub fn DocxParagraphAnchorIndex::scan_path_of_paragraph(
  self : DocxParagraphAnchorIndex,
  paragraph_index : Int,
) -> String? {
  match self.paths.get(paragraph_index) {
    Some(path) => path
    None => None
  }
}

///|
/// Projection indices of the ADDRESSABLE carriers of a canonical id.
pub fn DocxParagraphAnchorIndex::paragraphs_with_para_id(
  self : DocxParagraphAnchorIndex,
  canonical : String,
) -> Array[Int] {
  // A COPY: the internal carrier list is the resolver's authority, and
  // a caller's mutation must not change later resolution answers.
  match self.by_para_id.get(canonical) {
    Some(list) => list.copy()
    None => []
  }
}

///|
/// Path-keyed lookup for callers that only hold a path. A path claimed
/// by MORE than one logical paragraph returns None: an ambiguous name
/// must not resolve to either claimant's judgment.
pub fn DocxParagraphAnchorIndex::anchor_at(
  self : DocxParagraphAnchorIndex,
  path : String,
) -> DocxParagraphAnchor? {
  match self.by_path.get(path) {
    Some(entry) => entry
    None => None
  }
}

///|
/// Build the anchor index for one story.
///
/// Duplicate detection is PART-SCOPED over every WML `w:p` the scan
/// retained (the reader-selected view of the part) — not merely the
/// projected logical paragraphs — because Word's uniqueness rule is
/// per part, and a collision hiding in suppressed content still makes
/// the id unaddressable. Only VALID spellings can collide: an invalid
/// value is not an identity, so it neither claims nor contests one.
pub fn docx_paragraph_anchor_index(
  annotated : DocxAnnotatedResult,
  story : DocxStoryPartSource,
) -> DocxParagraphAnchorIndex raise DocxError {
  let part = story.part()
  guard annotated.reader_projections.get(part) is Some(projection) else {
    raise Unsupported(
      message="paragraph identity requires a mutation-safe read with a retained projection for '\{part}'",
    )
  }
  let elements = projection.scan.elements()
  // Pass 1: the part-scoped multiset of valid canonical ids.
  let occupancy : Map[String, Int] = Map([])
  for element in elements {
    if is_wml_uri(element.uri) && element.local_name == "p" {
      match element.para_id_raw {
        Some(raw) =>
          match validated_para_id(raw) {
            Some(canonical) =>
              occupancy[canonical] = occupancy.get(canonical).unwrap_or(0) + 1
            None => ()
          }
        None => ()
      }
    }
  }
  // Pass 2: how many logical paragraphs each physical source
  // participates in. A stable anchor requires a one-physical-to-
  // one-logical mapping, so participation above one — a tolerated
  // nested paragraph splitting its host — voids singular anchoring
  // for EVERY logical paragraph that shares the physical.
  let participation : Map[Int, Int] = Map([])
  for paragraph in projection.paragraphs {
    for source in paragraph.sources {
      let SourceElementId(index) = source.source
      participation[index] = participation.get(index).unwrap_or(0) + 1
    }
  }
  // Pass 3: one judgment per projected logical paragraph, keyed by
  // projection index; the path map is a secondary name that refuses
  // collisions.
  let paragraph_paths = find_path_map(projection.scan, "p")
  let anchors : Array[DocxParagraphAnchor?] = []
  let by_path : Map[String, DocxParagraphAnchor?] = Map([])
  let paths : Array[String?] = []
  let by_para_id : Map[String, Array[Int]] = Map([])
  let buried_para_ids : Map[String, Int] = Map([])
  for paragraph_index, paragraph in projection.paragraphs {
    guard paragraph.sources.length() > 0 else {
      anchors.push(None)
      paths.push(None)
      continue
    }
    let SourceElementId(head) = paragraph.sources[0].source
    let mut shared = false
    for source in paragraph.sources {
      let SourceElementId(index) = source.source
      if participation.get(index).unwrap_or(0) > 1 {
        shared = true
      }
    }
    let anchor : DocxParagraphAnchor = if paragraph.sources.length() > 1 ||
      shared {
      // No one-to-one mapping — joined from several physicals, or
      // sharing a physical with another logical paragraph. Either way
      // a singular id would be a promise resolution cannot keep.
      let physical : Array[String] = []
      for source in paragraph.sources {
        let SourceElementId(index) = source.source
        match elements[index].para_id_raw {
          Some(raw) =>
            match validated_para_id(raw) {
              Some(canonical) => {
                // The buried INVENTORY is complete — resolution's
                // judgment must not depend on the diagnostic cap,
                // which bounds only the reported array below.
                buried_para_ids[canonical] = buried_para_ids
                  .get(canonical)
                  .unwrap_or(0) +
                  1
                if physical.length() < max_reported_physical_para_ids {
                  physical.push(canonical)
                }
              }
              None => ()
            }
          None => ()
        }
      }
      { status: "multi_physical", para_id: None, physical_para_ids: physical, }
    } else {
      match elements[head].para_id_raw {
        None => { status: "missing", para_id: None, physical_para_ids: [], }
        Some(raw) =>
          match validated_para_id(raw) {
            None => { status: "invalid", para_id: None, physical_para_ids: [], }
            Some(canonical) =>
              if occupancy.get(canonical).unwrap_or(0) > 1 {
                {
                  status: "duplicate",
                  para_id: Some(canonical),
                  physical_para_ids: [],
                }
              } else {
                {
                  status: "unique",
                  para_id: Some(canonical),
                  physical_para_ids: [],
                }
              }
          }
      }
    }
    anchors.push(Some(anchor))
    match anchor.para_id {
      Some(canonical) =>
        match by_para_id.get(canonical) {
          Some(list) => list.push(paragraph_index)
          None => by_para_id[canonical] = [paragraph_index]
        }
      None => ()
    }
    match paragraph_paths.get(elements[head].byte_start) {
      Some(path) => {
        paths.push(Some(path))
        if by_path.contains(path) {
          // Second claimant: the path no longer names one paragraph.
          by_path[path] = None
        } else {
          by_path[path] = Some(anchor)
        }
      }
      None => paths.push(None)
    }
  }
  { anchors, by_path, paths, by_para_id, buried_para_ids, }
}

///|
/// The identity DELTA judgment for a mutation's candidate against its
/// source, part-scoped per Word's uniqueness rule. Existing dirt may
/// SURVIVE — real documents carry duplicate and invalid ids, and a text
/// edit must not be hostage to them — and removals are always fine
/// (consumed content takes its ids with it). What a write may never do:
///
/// - introduce an invalid spelling the part did not already carry
///   (per raw spelling, count-bounded by the source), or
/// - increase a valid id's per-part occupancy beyond one — creating a
///   NEW collision or deepening an existing one. Case-insensitive:
///   `1a…` and `1A…` are the same identity.
///
/// Returns the first violation's description, or None when the delta is
/// acceptable. Cross-part equality is NOT a violation — identity scope
/// is the part.
pub fn para_id_state_delta_violation(
  source : Map[String, Array[String]],
  candidate : Map[String, Array[String]],
) -> String? {
  for part, candidate_values in candidate {
    let source_values = source.get(part).unwrap_or([])
    let source_invalid : Map[String, Int] = Map([])
    let source_valid : Map[String, Int] = Map([])
    for value in source_values {
      match validated_para_id(value) {
        Some(canonical) =>
          source_valid[canonical] = source_valid.get(canonical).unwrap_or(0) + 1
        None =>
          source_invalid[value] = source_invalid.get(value).unwrap_or(0) + 1
      }
    }
    let candidate_invalid : Map[String, Int] = Map([])
    let candidate_valid : Map[String, Int] = Map([])
    for value in candidate_values {
      match validated_para_id(value) {
        Some(canonical) =>
          candidate_valid[canonical] = candidate_valid
            .get(canonical)
            .unwrap_or(0) +
            1
        None =>
          candidate_invalid[value] = candidate_invalid.get(value).unwrap_or(0) +
            1
      }
    }
    for value, count in candidate_invalid {
      if count > source_invalid.get(value).unwrap_or(0) {
        return Some(
          "the operation introduces an invalid w14:paraId spelling in '\{part}'",
        )
      }
    }
    for canonical, count in candidate_valid {
      if count > 1 && count > source_valid.get(canonical).unwrap_or(0) {
        return Some(
          "the operation makes w14:paraId '\{canonical}' collide in '\{part}'",
        )
      }
    }
  }
  None
}

///|
/// One tree paragraph occurrence's relationship to the projection: the
/// judgment travels ONLY across a proven bijection. `Unjoined` is a
/// JOIN outcome, not a sixth anchor status — the engine vocabulary is
/// unchanged, and a tree surface reporting it says "no sound
/// correspondence", never a borrowed judgment.
pub enum DocxParagraphJoin {
  Joined(Int, DocxParagraphAnchor)
  Unjoined(String)
}

///|
/// The tree/projection join for one story (paraId R1b): tree paragraph
/// occurrences in erase order, each mapped to at most one projection
/// paragraph by source-vector bijection.
pub struct DocxParagraphAnchorJoinIndex {
  priv joins : Array[DocxParagraphJoin]
  priv reverse : Map[Int, Int]
  priv anchor_index : DocxParagraphAnchorIndex
}

///|
/// The join for the Nth tree Paragraph occurrence, in the depth-first
/// order the erased tree presents them. None when the occurrence is out
/// of range — a caller whose own enumeration disagrees with the
/// provenance channel must treat EVERY paragraph as unjoined.
pub fn DocxParagraphAnchorJoinIndex::join_of_occurrence(
  self : DocxParagraphAnchorJoinIndex,
  occurrence : Int,
) -> DocxParagraphJoin? {
  self.joins.get(occurrence)
}

///|
/// Number of paragraph occurrences represented by this story join.
pub fn DocxParagraphAnchorJoinIndex::occurrence_count(
  self : DocxParagraphAnchorJoinIndex,
) -> Int {
  self.joins.length()
}

///|
/// The R2a seam: the unique tree occurrence a projection paragraph
/// joined to, if the bijection held in both directions.
pub fn DocxParagraphAnchorJoinIndex::occurrence_of_paragraph(
  self : DocxParagraphAnchorJoinIndex,
  paragraph_index : Int,
) -> Int? {
  self.reverse.get(paragraph_index)
}

///|
/// Build the story's tree/projection join.
///
/// A tree occurrence joins a projection paragraph only when ALL hold:
/// the source vectors are exactly equal; exactly one occurrence and one
/// projection paragraph claim that vector; and every physical source in
/// the vector participates in exactly one projection paragraph. The
/// last condition kills the false match the nested-paragraph shape
/// offers (the outer tree paragraph's [host] superficially equals the
/// post-half projection paragraph's [host], but the host also
/// participates in the joined head) — refusing beats first-wins.
pub fn docx_paragraph_anchor_join_index(
  annotated : DocxAnnotatedResult,
  story : DocxStoryPartSource,
) -> DocxParagraphAnchorJoinIndex raise DocxError {
  let part = story.part()
  guard annotated.reader_paragraph_provenance.get(part) is Some(tree_vectors) else {
    raise Unsupported(
      message="paragraph identity join requires a mutation-safe read with retained provenance for '\{part}'",
    )
  }
  guard annotated.reader_projections.get(part) is Some(projection) else {
    raise Unsupported(
      message="paragraph identity join requires a retained projection for '\{part}'",
    )
  }
  let anchors = docx_paragraph_anchor_index(annotated, story)
  // Projection-side claims and participation.
  let projection_claims : Map[String, Array[Int]] = Map([])
  let participation : Map[Int, Int] = Map([])
  for paragraph_index, paragraph in projection.paragraphs {
    let key = StringBuilder()
    for source in paragraph.sources {
      let SourceElementId(index) = source.source
      participation[index] = participation.get(index).unwrap_or(0) + 1
      key.write_string("\{index},")
    }
    let rendered = key.to_string()
    match projection_claims.get(rendered) {
      Some(list) => list.push(paragraph_index)
      None => projection_claims[rendered] = [paragraph_index]
    }
  }
  // Tree-side claims.
  let tree_claims : Map[String, Int] = Map([])
  let tree_keys : Array[String?] = []
  for vector in tree_vectors {
    let mut incomplete = false
    let key = StringBuilder()
    for entry in vector {
      match entry {
        Some(SourceElementId(index)) => key.write_string("\{index},")
        None => incomplete = true
      }
    }
    if incomplete || vector.length() == 0 {
      tree_keys.push(None)
    } else {
      let rendered = key.to_string()
      tree_claims[rendered] = tree_claims.get(rendered).unwrap_or(0) + 1
      tree_keys.push(Some(rendered))
    }
  }
  let joins : Array[DocxParagraphJoin] = []
  let reverse : Map[Int, Int] = Map([])
  for occurrence, entry in tree_keys {
    match entry {
      None => joins.push(Unjoined("missing-source-identity"))
      Some(key) =>
        match projection_claims.get(key) {
          None => joins.push(Unjoined("no-projection-counterpart"))
          Some(claimants) =>
            if claimants.length() != 1 {
              joins.push(Unjoined("ambiguous-projection-claim"))
            } else if tree_claims.get(key).unwrap_or(0) != 1 {
              joins.push(Unjoined("ambiguous-tree-claim"))
            } else {
              let paragraph_index = claimants[0]
              let mut shared = false
              for source in projection.paragraphs[paragraph_index].sources {
                let SourceElementId(index) = source.source
                if participation.get(index).unwrap_or(0) > 1 {
                  shared = true
                }
              }
              if shared {
                joins.push(Unjoined("shared-physical-source"))
              } else {
                match anchors.anchor_of_paragraph(paragraph_index) {
                  Some(anchor) => {
                    joins.push(Joined(paragraph_index, anchor))
                    reverse[paragraph_index] = occurrence
                  }
                  None => joins.push(Unjoined("unjudged-paragraph"))
                }
              }
            }
        }
    }
  }
  { joins, reverse, anchor_index: anchors, }
}

///|
/// One stable-selector resolution outcome. `p[id="…"]` resolves to a
/// TREE OCCURRENCE only through the whole chain — validated id, exactly
/// one addressable carrier, sound tree join — and every other state is
/// its own typed refusal. There is no first-wins and no ordinal
/// fallback anywhere in this enum.
pub enum DocxParaIdResolution {
  /// The unique carrier's tree occurrence (erase order) and its
  /// projection index.
  ResolvedOccurrence(Int, Int)
  /// Not eight case-insensitive hex digits in 1..0x7FFFFFFF.
  ParaIdInvalid
  /// No paragraph in the story carries the id.
  ParaIdNotFound
  /// More than one carrier claims the id (part-scoped, case-insensitive)
  /// — the ADDRESSABLE carriers' projection indices, for diagnostics.
  ParaIdAmbiguous(Array[Int])
  /// The id's only carriers are buried inside multi-physical joins —
  /// the identity exists but names no addressable paragraph.
  ParaIdInMultiPhysical
  /// A single addressable carrier exists but its tree join does not —
  /// the paragraph cannot be named in the tree without guessing.
  ParaIdUnjoined(Int)
}

///|
/// The identity judgment WITHOUT the tree step: resolve an as-spelled
/// paraId to its single addressable carrier's projection index, or the
/// typed reason it never resolves. Scan-path consumers (find scopes,
/// the write verbs) build on this; tree surfaces add the join step.
pub fn DocxParagraphAnchorIndex::resolve_para_id_carrier(
  self : DocxParagraphAnchorIndex,
  raw : String,
) -> DocxParaIdResolution {
  guard validated_para_id(raw) is Some(canonical) else { return ParaIdInvalid }
  let carriers = self.paragraphs_with_para_id(canonical)
  if carriers.length() > 1 {
    return ParaIdAmbiguous(carriers)
  }
  guard carriers is [paragraph_index] else {
    if self.buried_para_ids.get(canonical).unwrap_or(0) > 0 {
      return ParaIdInMultiPhysical
    }
    return ParaIdNotFound
  }
  // A single addressable carrier whose PART-SCOPED occupancy is still
  // plural means the other claimants are buried or suppressed — the
  // identity is contested and never resolves. The carrier's own anchor
  // status carries that occupancy judgment.
  match self.anchor_of_paragraph(paragraph_index) {
    Some(anchor) =>
      if anchor.status() != "unique" {
        return ParaIdAmbiguous(carriers)
      }
    None => return ParaIdAmbiguous(carriers)
  }
  // The carrier resolution reuses ResolvedOccurrence with the OCCURRENCE
  // slot unset (-1): only the join step can name a tree occurrence.
  ResolvedOccurrence(-1, paragraph_index)
}

///|
/// Resolve one as-spelled paraId to a tree occurrence.
pub fn DocxParagraphAnchorJoinIndex::resolve_para_id(
  self : DocxParagraphAnchorJoinIndex,
  raw : String,
) -> DocxParaIdResolution {
  match self.anchor_index.resolve_para_id_carrier(raw) {
    ResolvedOccurrence(_, paragraph_index) =>
      match self.reverse.get(paragraph_index) {
        Some(occurrence) => ResolvedOccurrence(occurrence, paragraph_index)
        None => ParaIdUnjoined(paragraph_index)
      }
    other => other
  }
}

///|
/// The anchor index this join was judged against, for callers that
/// need scan paths or per-paragraph anchors beside the resolution.
pub fn DocxParagraphAnchorJoinIndex::anchor_index(
  self : DocxParagraphAnchorJoinIndex,
) -> DocxParagraphAnchorIndex {
  self.anchor_index
}
