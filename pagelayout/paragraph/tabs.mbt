///|
// Tab stops. A tab is not a glyph: it advances the pen to the next stop,
// so its width depends on where the text before it ended. Measuring it
// as a character (which is what happens without this) collapses every
// tab-aligned layout to one narrow gap.
//
// Centre and right stops position the text that FOLLOWS the tab, so
// they are resolved by measuring the span up to the next tab. Decimal
// stops align on the decimal separator and are treated as left stops,
// which keeps the column boundary even when the alignment within it is
// approximate.

///|
/// `w:tab w:val` — how text sits against the stop.
pub(all) enum TabAlign {
  TabLeft
  TabCenter
  TabRight
  TabDecimal
  /// `w:val="bar"` draws a vertical rule and does not stop text.
  TabBar
} derive(Eq, Debug, ToJson)

///|
/// One `w:tab` from a paragraph's `w:tabs`.
pub(all) struct TabStop {
  position_pt : Double
  align : TabAlign
} derive(Eq, Debug, ToJson)

///|
/// A paragraph's tab stops plus the document default interval
/// (`w:defaultTabStop`, 720 twips = 36pt unless the document says
/// otherwise). Word falls back to multiples of the default beyond the
/// last explicit stop.
pub(all) struct TabRuler {
  stops : Array[TabStop]
  default_interval_pt : Double
} derive(Eq, Debug, ToJson)

///|
/// Word's default ruler: no explicit stops, every 36pt.
pub fn TabRuler::default() -> TabRuler {
  { stops: [], default_interval_pt: 36.0, }
}

///|
/// The x a tab at pen position `x` advances to, measured from the
/// paragraph's left edge. Explicit stops win in order; past the last one
/// the default interval takes over. A tab that cannot advance (already
/// past everything, or a degenerate interval) moves by one interval so
/// it always makes progress.
pub fn TabRuler::next_stop(self : TabRuler, x : Double) -> Double {
  self.next_stop_of(x).position_pt
}

///|
/// The stop a tab at `x` advances to, with its alignment — which the
/// caller needs, because a centre or right stop positions the text that
/// follows rather than the tab itself.
pub fn TabRuler::next_stop_of(self : TabRuler, x : Double) -> TabStop {
  for stop in self.stops {
    // a bar stop is a rule, not a stopping point
    if stop.align is TabBar {
      continue
    }
    if stop.position_pt > x + 0.0001 {
      return stop
    }
  }
  let interval = if self.default_interval_pt > 0.0 {
    self.default_interval_pt
  } else {
    36.0
  }
  // the next multiple of the interval strictly past x; implicit stops
  // are always left-aligned
  let steps = (x / interval).floor() + 1.0
  { position_pt: steps * interval, align: TabLeft, }
}
