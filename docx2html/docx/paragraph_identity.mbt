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
  /// For `multi_physical` only: the valid canonical ids of the joined
  /// physical paragraphs, in document order, bounded — a diagnostic
  /// inventory, never a singular anchor.
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
/// Per-story anchor index, keyed by the scanner's paragraph path — the
/// same body-relative grammar `find` and `replace` emit.
pub struct DocxParagraphAnchorIndex {
  by_path : Map[String, DocxParagraphAnchor]
}

///|
pub fn DocxParagraphAnchorIndex::anchor_at(
  self : DocxParagraphAnchorIndex,
  path : String,
) -> DocxParagraphAnchor? {
  self.by_path.get(path)
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
  // Pass 2: one judgment per projected logical paragraph, addressed by
  // its head source's path (the name every read surface already uses;
  // a joined logical paragraph is LISTED under its first physical
  // source but never receives a singular anchor through it).
  let paragraph_paths = find_path_map(projection.scan, "p")
  let by_path : Map[String, DocxParagraphAnchor] = Map([])
  for paragraph in projection.paragraphs {
    guard paragraph.sources.length() > 0 else { continue }
    let SourceElementId(head) = paragraph.sources[0].source
    guard paragraph_paths.get(elements[head].byte_start) is Some(path) else {
      continue
    }
    let anchor = if paragraph.sources.length() > 1 {
      let physical : Array[String] = []
      let mut listed = 0
      for source in paragraph.sources {
        let SourceElementId(index) = source.source
        if listed < max_reported_physical_para_ids {
          match elements[index].para_id_raw {
            Some(raw) =>
              match validated_para_id(raw) {
                Some(canonical) => {
                  physical.push(canonical)
                  listed += 1
                }
                None => ()
              }
            None => ()
          }
        }
      }
      { status: "multi_physical", para_id: None, physical_para_ids: physical }
    } else {
      match elements[head].para_id_raw {
        None => { status: "missing", para_id: None, physical_para_ids: [] }
        Some(raw) =>
          match validated_para_id(raw) {
            None => { status: "invalid", para_id: None, physical_para_ids: [] }
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
    by_path[path] = anchor
  }
  { by_path, }
}
