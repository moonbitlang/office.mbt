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
  status : String
  /// The canonical (uppercase) value when the spelling is a valid
  /// paraId — present for `unique` AND `duplicate` (both carriers
  /// report the value; neither duplicate is an addressable anchor).
  /// Absent for `missing`, `invalid`, and `multi_physical`.
  para_id : String?
  /// For `multi_physical` only: the valid canonical ids of the
  /// PARTICIPATING physical paragraphs, in document order, bounded — a
  /// diagnostic inventory, never a singular anchor. One element when a
  /// single physical paragraph is shared by several logical ones.
  physical_para_ids : Array[String]
}

///|
pub fn DocxParagraphAnchor::status(self : DocxParagraphAnchor) -> String {
  self.status
}

///|
pub fn DocxParagraphAnchor::para_id(self : DocxParagraphAnchor) -> String? {
  self.para_id
}

///|
pub fn DocxParagraphAnchor::physical_para_ids(
  self : DocxParagraphAnchor,
) -> Array[String] {
  self.physical_para_ids
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
  anchors : Array[DocxParagraphAnchor?]
  by_path : Map[String, DocxParagraphAnchor?]
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
  for paragraph in projection.paragraphs {
    guard paragraph.sources.length() > 0 else {
      anchors.push(None)
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
        if physical.length() < max_reported_physical_para_ids {
          match elements[index].para_id_raw {
            Some(raw) =>
              match validated_para_id(raw) {
                Some(canonical) => physical.push(canonical)
                None => ()
              }
            None => ()
          }
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
    match paragraph_paths.get(elements[head].byte_start) {
      Some(path) =>
        if by_path.contains(path) {
          // Second claimant: the path no longer names one paragraph.
          by_path[path] = None
        } else {
          by_path[path] = Some(anchor)
        }
      None => ()
    }
  }
  { anchors, by_path, }
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
