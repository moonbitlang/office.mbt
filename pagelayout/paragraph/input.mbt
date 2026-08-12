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
/// The style with a hanging indent's implicit tab stop in its ruler.
///
/// A hanging indent carries an implicit tab stop at its text position —
/// it is what a list marker's suffix tab is designed to hit. Word
/// advances the tab after "(a)" to the indent-left position, not to the
/// next default grid line beyond it; without this stop, every first line
/// of a hanging paragraph whose indent is off the 36pt grid starts late,
/// and the paragraph's every wrap point cascades from there. Idempotent,
/// and a no-op for non-hanging styles.
pub fn ParagraphStyle::with_hanging_tab_stop(
  self : ParagraphStyle,
) -> ParagraphStyle {
  if self.indent_first_pt >= 0.0 {
    return self
  }
  if self.tabs.stops
    .iter()
    .any(s => (s.position_pt - self.indent_left_pt).abs() < 0.01) {
    return self
  }
  let merged = self.tabs.stops.copy()
  let mut at = merged.length()
  for i, stop in merged {
    if stop.position_pt > self.indent_left_pt {
      at = i
      break
    }
  }
  merged.insert(at, { position_pt: self.indent_left_pt, align: TabLeft })
  { ..self, tabs: { ..self.tabs, stops: merged } }
}

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
