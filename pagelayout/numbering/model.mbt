///|
// The numbering model. OOXML splits list definitions in two: an
// `w:abstractNum` holds the nine levels' formats, and each `w:num`
// instance points at one (optionally overriding levels). Paragraphs
// reference the *instance* by `w:numId`, so resolution goes
// numId → abstractNumId → level.

///|
/// `w:numFmt` — how a level's counter renders.
pub(all) enum NumberFormat {
  Decimal
  LowerLetter
  UpperLetter
  LowerRoman
  UpperRoman
  /// `w:numFmt="bullet"` — `lvl_text` is the literal glyph.
  Bullet
  /// `w:numFmt="none"` — the level shows no label at all.
  NoNumber
} derive(Eq, Debug, ToJson)

///|
/// Parse an OOXML `w:numFmt` value. Formats this engine does not render
/// (ordinal, cardinalText, the CJK and Hebrew formats, …) fall back to
/// decimal, which keeps the list numbered rather than blank.
pub fn number_format(name : String) -> NumberFormat {
  match name {
    "bullet" => Bullet
    "none" => NoNumber
    "lowerLetter" => LowerLetter
    "upperLetter" => UpperLetter
    "lowerRoman" => LowerRoman
    "upperRoman" => UpperRoman
    _ => Decimal
  }
}

///|
/// What separates a level's label from its text (`w:suff`).
pub(all) enum Suffix {
  /// The default: advance to the level's indent position.
  SuffTab
  SuffSpace
  SuffNothing
} derive(Eq, Debug, ToJson)

///|
/// One level of an abstract numbering definition.
pub(all) struct Level {
  format : NumberFormat
  /// `w:lvlText`, e.g. `"%1."` or `"%1.%2"` or a bullet glyph.
  text : String
  /// `w:start` — the first value this level counts from.
  start : Int
  /// `w:lvlRestart`: restart when a level at most this deep advances.
  /// `None` means the default (restart on any higher level).
  restart : Int?
  /// `w:isLgl` — render all levels of `text` as decimal.
  is_legal : Bool
  suffix : Suffix
  /// Indents from the level's `w:pPr/w:ind`, in twips.
  indent_left : @pagelayout.Twips?
  indent_hanging : @pagelayout.Twips?
  indent_first : @pagelayout.Twips?
  /// The family from the level's own `w:rPr/w:rFonts`. Word's bullets are
  /// private-use codepoints that only render in the face named here
  /// (Symbol, Wingdings), so a marker must not inherit the body font.
  font_family : String?
  /// The size from the level's own `w:rPr/w:sz`, in half-points. A level
  /// may size its marker independently of the paragraph text.
  size : @pagelayout.HalfPoints?
} derive(Eq, Debug, ToJson)

///|
/// A level with Word's defaults: decimal, `%N.`, starting at 1.
pub fn Level::default(depth : Int) -> Level {
  {
    format: Decimal,
    text: "%\{depth + 1}.",
    start: 1,
    restart: None,
    is_legal: false,
    suffix: SuffTab,
    indent_left: None,
    indent_hanging: None,
    indent_first: None,
    font_family: None,
    size: None,
  }
}

///|
/// An `w:abstractNum`: up to nine levels, by depth.
pub(all) struct AbstractNum {
  levels : Map[Int, Level]
} derive(Eq, Debug, ToJson)

///|
/// A `w:num` instance: which abstract definition it uses, plus any
/// per-instance level overrides (`w:lvlOverride`).
pub(all) struct NumInstance {
  abstract_id : Int
  overrides : Map[Int, Level]
  /// `w:startOverride` per level, which also forces a restart.
  start_overrides : Map[Int, Int]
} derive(Eq, Debug, ToJson)

///|
/// A parsed `word/numbering.xml`.
pub struct Numbering {
  abstracts : Map[Int, AbstractNum]
  instances : Map[Int, NumInstance]
}

///|
/// An empty definition set: every lookup falls back to Word's defaults.
pub fn Numbering::empty() -> Numbering {
  { abstracts: Map([]), instances: Map([]), }
}

///|
/// Build from parsed parts (the DOCX frontend supplies these).
pub fn Numbering::new(
  abstracts : Map[Int, AbstractNum],
  instances : Map[Int, NumInstance],
) -> Numbering {
  { abstracts, instances, }
}

///|
/// The effective level for `(num_id, depth)`: the instance's override if
/// it has one, else the abstract definition's level, else Word's default
/// for that depth. Unknown ids still produce a usable level rather than
/// dropping the list marker.
pub fn Numbering::level(self : Numbering, num_id : Int, depth : Int) -> Level {
  // OOXML defines exactly nine levels; an out-of-range w:ilvl would
  // otherwise produce a default whose %N has no counter and leak the
  // literal placeholder into the rendered text
  let depth = if depth < 0 { 0 } else if depth > 8 { 8 } else { depth }
  guard self.instances.get(num_id) is Some(instance) else {
    return Level::default(depth)
  }
  match instance.overrides.get(depth) {
    Some(level) => level
    None =>
      match self.abstracts.get(instance.abstract_id) {
        Some(abstract_num) =>
          match abstract_num.levels.get(depth) {
            Some(level) => level
            None => Level::default(depth)
          }
        None => Level::default(depth)
      }
  }
}

///|
/// A `w:startOverride` for `(num_id, depth)`, if the instance sets one.
pub fn Numbering::start_override(
  self : Numbering,
  num_id : Int,
  depth : Int,
) -> Int? {
  match self.instances.get(num_id) {
    Some(instance) => instance.start_overrides.get(depth)
    None => None
  }
}
