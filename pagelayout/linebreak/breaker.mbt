///|
// Greedy first-fit line breaking (what Word does — no paragraph-level
// optimization): walk the text accumulating advances, and at overflow
// break at the last legal opportunity, or force-break mid-word when a
// single fragment exceeds the line. Trailing spaces hang: they never
// trigger overflow and never count toward a line's reported width.

///|
/// One line of broken text: code units `[start, end)`. Line ranges
/// partition the text exactly, except that a `'\n'` separator belongs to
/// no line; spaces hanging at a soft break stay in their line's range but
/// are excluded from `width_pt` (they hang past the margin, per Word).
pub(all) struct LineRange {
  start : Int32
  end : Int32
  width_pt : Double
} derive(Eq, Debug, ToJson)

///|
fn is_trail_surrogate(unit : Int32) -> Bool {
  unit >= 0xDC00 && unit <= 0xDFFF
}

///|
/// Break `text` (measured as `advances_pt`, one advance per UTF-16 code
/// unit) into lines of at most `first_width_pt` (line one) and
/// `rest_width_pt` (all others). `'\n'` forces a break and is consumed.
/// Every line keeps at least one character, so pathological widths
/// terminate with one-character lines rather than looping; surrogate
/// pairs are never split.
/// `break_opportunity` can supply the document's own language or punctuation
/// policy; omitted, the standard Latin/CJK policy is used.
/// `line_end_adjustment(end)` excludes tracking or pair spacing after the last
/// visible codepoint (exclusive UTF-16 index `end`) from wrapping and alignment.
/// The advances still include that spacing between characters inside a line.
pub fn break_lines(
  text : String,
  advances_pt : Array[Double],
  first_width_pt : Double,
  rest_width_pt : Double,
  break_opportunity? : (String, Int32) -> Bool,
  line_end_adjustment? : (Int32) -> Double,
) -> Array[LineRange] {
  let lines : Array[LineRange] = []
  let n = text.length()
  fn adjusted_width(width : Double, start : Int32, end : Int32) -> Double {
    let mut visible_end = end
    while visible_end > start && is_space(text[visible_end - 1].to_int()) {
      visible_end -= 1
    }
    if visible_end <= start {
      return 0.0
    }
    width -
    line_end_adjustment.map(adjust => adjust(visible_end)).unwrap_or(0.0)
  }

  let mut line_start = 0
  // committed content width: interior spaces included, trailing run not
  let mut content_width = 0.0
  // width of the space run since the last non-space character
  let mut pending_spaces = 0.0
  let mut last_break = -1
  let mut i = 0
  while i < n {
    let unit = text[i].to_int()
    if unit == '\n'.to_int() {
      lines.push({
        start: line_start,
        end: i,
        width_pt: adjusted_width(content_width, line_start, i),
      })
      line_start = i + 1
      content_width = 0.0
      pending_spaces = 0.0
      last_break = -1
      i += 1
      continue
    }
    if is_space(unit) {
      pending_spaces += advances_pt[i]
      i += 1
      continue
    }
    let allowed = match break_opportunity {
      Some(opportunity) => opportunity(text, i)
      None => can_break_at(text, i)
    }
    if allowed {
      last_break = i
    }
    let limit = if lines.length() == 0 { first_width_pt } else { rest_width_pt }
    let codepoint_end = if unit >= 0xD800 &&
      unit <= 0xDBFF &&
      i + 1 < n &&
      is_trail_surrogate(text[i + 1].to_int()) {
      i + 2
    } else {
      i + 1
    }
    let candidate = content_width + pending_spaces + advances_pt[i]
    let overflows = adjusted_width(candidate, line_start, codepoint_end) > limit
    if overflows && content_width > 0.0 && !is_trail_surrogate(unit) {
      let break_at = if last_break > line_start { last_break } else { i }
      // the break point is the first code unit of the next line, so this
      // line's range runs to it; its width stops before the hanging spaces
      let mut visible_end = break_at
      let mut width = 0.0
      while visible_end > line_start && is_space(text[visible_end - 1].to_int()) {
        visible_end -= 1
      }
      for j in line_start..<visible_end {
        width += advances_pt[j]
      }
      lines.push({
        start: line_start,
        end: break_at,
        width_pt: adjusted_width(width, line_start, visible_end),
      })
      line_start = break_at
      content_width = 0.0
      pending_spaces = 0.0
      last_break = -1
      i = break_at
      continue
    }
    content_width += pending_spaces + advances_pt[i]
    pending_spaces = 0.0
    i += 1
  }
  if line_start < n || lines.length() == 0 {
    lines.push({
      start: line_start,
      end: n,
      width_pt: adjusted_width(content_width, line_start, n),
    })
  }
  lines
}
