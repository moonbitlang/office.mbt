///|
// Engine input for one paragraph: styled runs plus paragraph properties.
// Frontends (DOCX first) translate their formats into these types; all
// lengths are already in points (converted at the frontend boundary via
// the root package's unit wrappers).

///|
/// Character formatting of one input run. `family` is the document's
/// authored family name; resolution to a bundled face happens inside the
/// paragraph layout via `@fonts.resolve_family`.
pub(all) struct RunStyle {
  family : String
  size_pt : Double
  bold : Bool
  italic : Bool
  color : @pagelayout.Color
} derive(Eq, Debug, ToJson)

///|
/// One run of paragraph text in one style.
pub(all) struct RunInput {
  text : String
  style : RunStyle
  /// What field produced this run's text, if any. A field's text is the
  /// value cached when the document was saved; `evaluate` replaces it
  /// with the real one once the layout knows the page.
  field : FieldKind
} derive(Eq, Debug, ToJson)

///|
/// A plain (non-field) run.
pub fn RunInput::plain(text : String, style : RunStyle) -> RunInput {
  { text, style, field: NotAField }
}

///|
/// Horizontal paragraph alignment.
pub(all) enum Alignment {
  AlignLeft
  AlignCenter
  AlignRight
  AlignJustify
} derive(Eq, Debug, ToJson)

///|
/// Word's line-spacing rules: `Single` uses the tallest font's natural
/// line height; `Multiple` scales it; `Exact` forces a height; `AtLeast`
/// takes the larger of the natural height and the given floor.
pub(all) enum LineSpacing {
  Single
  Multiple(Double)
  Exact(Double)
  AtLeast(Double)
} derive(Eq, Debug, ToJson)

///|
/// Paragraph formatting. `indent_first_pt` is the extra first-line indent
/// relative to `indent_left_pt` (negative for a hanging indent).
pub(all) struct ParagraphStyle {
  align : Alignment
  indent_left_pt : Double
  indent_right_pt : Double
  indent_first_pt : Double
  space_before_pt : Double
  space_after_pt : Double
  line_spacing : LineSpacing
  /// Where tabs in this paragraph advance to.
  tabs : TabRuler
} derive(Eq, Debug, ToJson)

///|
/// Word's defaults: left-aligned, no indents or extra spacing, single
/// line spacing.
pub fn ParagraphStyle::default() -> ParagraphStyle {
  {
    align: AlignLeft,
    indent_left_pt: 0,
    indent_right_pt: 0,
    indent_first_pt: 0,
    space_before_pt: 0,
    space_after_pt: 0,
    line_spacing: Single,
    tabs: TabRuler::default(),
  }
}

///|
/// One paragraph of engine input: runs plus paragraph formatting.
pub(all) struct ParagraphInput {
  runs : Array[RunInput]
  style : ParagraphStyle
} derive(Eq, Debug, ToJson)
