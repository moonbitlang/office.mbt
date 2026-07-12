///|
/// N0 — the projection-to-source token map (Phase 3, docs/docx-agent-roadmap.md).
///
/// For each PHYSICAL `w:p` of a body story, maps the reader's text
/// projection (what `docx text`/`get` show) back to byte spans in the
/// original part, precisely enough to cut and splice INSIDE `w:t`
/// content. The five-class inline inventory, the story-wide field
/// stack, and the logical-paragraph enumeration all live here; the
/// reader (docx_reader.mbt) is the projection contract — where this
/// file and the reader disagree, this file is wrong.

///|
/// The lexical context of one projection slice. Splitting rules differ
/// per kind: raw text cuts anywhere on a scalar boundary; a reference
/// is atomic (cuts land at its edges); CDATA refuses mutation in v1.
pub(all) enum TokenContext {
  RawText
  EntityRef
  CharRef
  CdataText
} derive(Show, Eq)

///|
/// One slice of projection text and the source bytes that produce it.
/// `char_start`/`char_end` are UTF-16 code-unit offsets into the owning
/// paragraph's projection string; `byte_start`/`byte_end` bound the
/// producing bytes in the part.
pub(all) struct ProjToken {
  char_start : Int
  char_end : Int
  byte_start : Int
  byte_end : Int
  context : TokenContext
  atom : Int // index into the paragraph's atoms
} derive(Show)

///|
/// What kind of projecting atom produced a token run.
pub(all) enum AtomKind {
  TextAtom // a w:t element (tokens live in its content)
  TabAtom // w:tab -> "\t"
  NoBreakHyphenAtom // w:noBreakHyphen -> U+2011
  SoftHyphenAtom // w:softHyphen -> U+00AD
  SymAtom // supported w:sym -> mapped text
} derive(Show, Eq)

///|
/// A projecting atom: an element with a consuming XML span that
/// contributes projection characters. For TextAtom the content span
/// (between the open and close tags) is where tokens live; element
/// atoms (tab, hyphens, sym) project fixed text and are deleted
/// wholesale when covered by an edit.
pub(all) struct ProjAtom {
  kind : AtomKind
  byte_start : Int
  mut byte_end : Int
  mut content_start : Int? // TextAtom only; None when self-closing
  mut close_tag_start : Int? // TextAtom only; None when self-closing
  char_start : Int
  mut char_end : Int
  run_ordinal : Int // 1-based ordinal of the owning run in the paragraph
  xml_space_preserve : Bool // TextAtom: xml:space="preserve" on the element
} derive(Show)

///|
/// Why a stretch of projection text cannot be mutated (v1). The names
/// are the structured `reason` values the hit-list JSON will carry.
/// HyperlinkInterior is special: matches fully inside it stay
/// actionable; only boundary-crossing matches refuse.
pub(all) enum RestrictionReason {
  FieldRegion // complex-field content (instruction phase or cached result)
  HyperlinkInterior // inside w:hyperlink
  TrackedRegion // w:ins content, or a merged logical paragraph
  SdtContent // non-checkbox w:sdt content
  AlternateContent // mc:Fallback content (the branch that projects)
  CdataRegion // CDATA-context tokens refuse mutation
} derive(Show, Eq)

///|
/// A restricted stretch of the paragraph's projection.
pub(all) struct RestrictedSpan {
  char_start : Int
  mut char_end : Int
  reason : RestrictionReason
} derive(Show)

///|
/// What stands at a zero-width barrier position. No match may span a
/// barrier; it contributes no projection character.
pub(all) enum BarrierKind {
  BreakBarrier // w:br, w:cr
  PositionalTabBarrier // w:ptab
  ReferenceBarrier // note/comment references
  ObjectBarrier // drawings, pictures, w:object, equations
  CheckboxBarrier // checkbox-suppressed text (reader replaces it)
  UnsupportedSymBarrier // w:sym the reader cannot map
  FieldControlBarrier // w:fldChar / w:instrText / w:fldSimple
  SuppressedBarrier // w:del content, mc:Choice, move wrappers
  TextboxBarrier // txbxContent/pict content (lifted out of this paragraph)
  UnknownBarrier // any unrecognized inline element
} derive(Show, Eq)

///|
/// A zero-width position in the projection that blocks matches, with
/// the byte span of the blocking construct.
pub(all) struct BarrierPoint {
  char_pos : Int
  byte_start : Int
  mut byte_end : Int
  kind : BarrierKind
} derive(Show)

///|
/// The token map of one PHYSICAL `w:p`.
pub(all) struct ParagraphTokenMap {
  /// 1-based ordinal among the story's LOGICAL top-level paragraphs
  /// (`/body/p[n]`); 0 when this physical paragraph has no own logical
  /// slot (its mark is tracked-deleted, so it merges into a successor).
  logical_ordinal : Int
  byte_start : Int
  byte_end : Int
  /// The reader's projection of this PHYSICAL paragraph's own content.
  projection : String
  tokens : Array[ProjToken]
  atoms : Array[ProjAtom]
  restricted : Array[RestrictedSpan]
  barriers : Array[BarrierPoint]
  /// This paragraph's mark is tracked-deleted (merges forward).
  deleted_mark : Bool
  /// A preceding tracked-deleted paragraph merged content into this
  /// one: the logical projection is NOT this physical projection.
  merged_prefix : Bool
  /// The paragraph hosts textbox/pict sources whose paragraphs the
  /// reader lifts as EXTRA logical siblings after it: logical `p`
  /// ordinals AFTER this paragraph no longer align with physical
  /// order, so v1 restricts everything from here on.
  hosts_extras : Bool
  /// The paragraph carries a sectPr (delete refuses).
  has_sect_pr : Bool
} derive(Show)

///|
/// The token map of one story part.
pub(all) struct StoryTokenMap {
  paragraphs : Array[ParagraphTokenMap]
} derive(Show)

///|
/// Per-paragraph accumulation while walking.
priv struct ParagraphBuild {
  byte_start : Int
  mut byte_end : Int
  projection : StringBuilder
  mut char_len : Int
  tokens : Array[ProjToken]
  atoms : Array[ProjAtom]
  restricted : Array[RestrictedSpan]
  barriers : Array[BarrierPoint]
  mut deleted_mark : Bool
  mut merged_prefix : Bool
  mut hosts_extras : Bool
  mut has_sect_pr : Bool
}

///|
fn ParagraphBuild::start(byte_start : Int) -> ParagraphBuild {
  ParagraphBuild::{
    byte_start,
    byte_end: byte_start,
    projection: StringBuilder::new(),
    char_len: 0,
    tokens: [],
    atoms: [],
    restricted: [],
    barriers: [],
    deleted_mark: false,
    merged_prefix: false,
    hosts_extras: false,
    has_sect_pr: false,
  }
}

///|
fn ParagraphBuild::barrier(
  self : ParagraphBuild,
  kind : BarrierKind,
  byte_start : Int,
  byte_end : Int,
) -> Unit {
  self.barriers.push(BarrierPoint::{
    char_pos: self.char_len,
    byte_start,
    byte_end,
    kind,
  })
}

///|
/// One frame of the walk stack.
priv struct TmFrame {
  raw_name : String
  local_name : String
  is_wml : Bool
  declared : Array[String]
  open_end : Int // byte just past the open tag's '>'
  /// Restriction spans this element OPENED (closed when it closes).
  opened_restrictions : Array[RestrictedSpan]
  /// The atom this element opened (w:t), to finish at close.
  opened_atom : Int? // index into the current paragraph's atoms
  /// Depth-class deltas this frame applied (undone at close).
  suppress_delta : Int
  textbox_delta : Int
  checkbox_sdt : Bool
}

///|
/// One complex-field frame on the story-wide stack.
priv struct FieldFrame {
  mut separated : Bool
}

///|
/// The whole walk state. The reader is the contract for every
/// projection decision made here.
priv struct TokenWalk {
  part : Bytes
  paragraphs : Array[ParagraphBuild]
  finished : Array[ParagraphTokenMap]
  frames : Array[TmFrame]
  namespaces : Map[String, Array[String]]
  field_stack : Array[FieldFrame]
  mut paragraph : ParagraphBuild?
  mut paragraph_depth : Int
  mut run_ordinal : Int
  mut suppressed_depth : Int
  mut textbox_depth : Int
  /// Non-checkbox sdtContent / w:ins / hyperlink / mc:Fallback depths
  /// are realized as opened_restrictions on their frames; only
  /// suppression and textbox need numeric depths (they gate token
  /// production entirely).
  mut pending_deleted_prefix : Bool
}

///|
fn TokenWalk::in_paragraph(self : TokenWalk) -> ParagraphBuild? {
  if self.paragraph_depth > 0 {
    self.paragraph
  } else {
    None
  }
}

///|
fn TokenWalk::resolve(self : TokenWalk, prefix : String) -> String {
  match self.namespaces.get(prefix) {
    Some(stack) if stack.length() > 0 => stack[stack.length() - 1]
    _ => ""
  }
}

///|
/// True while inside pPr (property containers never produce tokens).
fn TokenWalk::inside(self : TokenWalk, local_name : String) -> Bool {
  for frame in self.frames {
    if frame.is_wml && frame.local_name == local_name {
      return true
    }
  }
  false
}

///|
fn TokenWalk::innermost_wt(self : TokenWalk) -> Bool {
  match self.frames.last() {
    Some(frame) => frame.is_wml && frame.local_name == "t"
    None => false
  }
}
