///|
// Paragraph layout: concatenate the runs, measure with per-character CJK
// fallback, break greedily, then rebuild each line as placed segments
// split wherever the style or the rendering face changes. Output is
// paragraph-relative (x from the paragraph's left edge, baselines from
// its top including space-before); pagination stacks these boxes.

///|
/// One positioned run fragment on a line. `font` is the resolved,
/// renderable face (post family-mapping and CJK fallback).
pub(all) struct PlacedRun {
  font : @pagelayout.FontSpec
  size_pt : Double
  x_pt : Double
  text : String
  advances_pt : Array[Double]
  color : @pagelayout.Color
} derive(Eq, Debug, ToJson)

///|
/// One laid-out line: `baseline_pt` and `height_pt` are relative to the
/// paragraph's top edge (which includes `space_before_pt`).
pub(all) struct LineBox {
  baseline_pt : Double
  height_pt : Double
  runs : Array[PlacedRun]
} derive(Eq, Debug, ToJson)

///|
/// A fully laid-out paragraph. `height_pt` includes space before/after.
pub(all) struct ParagraphLayout {
  height_pt : Double
  lines : Array[LineBox]
} derive(Eq, Debug, ToJson)

///|
priv struct FlatRun {
  style : RunStyle
  face : @fonts.FaceMetrics
  end : Int // global code-unit offset one past this run's text
}

///|
/// Lay out one paragraph into `width_pt` of available horizontal space.
pub fn layout_paragraph(
  input : ParagraphInput,
  width_pt : Double,
) -> ParagraphLayout {
  // 1. concatenate runs; measure each with its resolved face
  let sb = StringBuilder()
  let advances : Array[Double] = []
  let fallback : Array[Bool] = []
  let flat_runs : Array[FlatRun] = []
  let mut offset = 0
  for run in input.runs {
    let face = @fonts.face(
      @fonts.resolve_family(run.style.family),
      bold=run.style.bold,
      italic=run.style.italic,
    )
    let measured = @linebreak.measure(run.text, face, run.style.size_pt)
    sb.write_string(run.text)
    advances.append(measured.advances_pt)
    fallback.append(measured.fallback)
    flat_runs.push({ style: run.style, face, end: offset + run.text.length(), })
    offset += run.text.length()
  }
  let text = sb.to_string()

  // A tab is not a glyph: it advances the pen to the next stop, so its
  // width depends on the text before it — which depends on where the
  // line began. Resolve once against the first line's indent to get a
  // usable break, then again per line below.
  resolve_tabs(
    text,
    advances,
    input.style.tabs,
    input.style.indent_left_pt + input.style.indent_first_pt,
    0,
    text.length(),
  )

  // 2. break into lines
  let style = input.style
  let content_width = width_pt - style.indent_left_pt - style.indent_right_pt
  let first_width = content_width - style.indent_first_pt
  let mut lines = @linebreak.break_lines(
    text, advances, first_width, content_width,
  )

  // Re-resolve each line's tabs from that line's own origin, then break
  // again. The first pass measured every tab from the paragraph start,
  // which is wrong for any tab on a wrapped line. One extra pass settles
  // the common cases and always terminates.
  if has_tab(text, 0, text.length()) {
    for index, line in lines {
      let origin = if index == 0 {
        style.indent_left_pt + style.indent_first_pt
      } else {
        style.indent_left_pt
      }
      resolve_tabs(text, advances, style.tabs, origin, line.start, line.end)
    }
    lines = @linebreak.break_lines(text, advances, first_width, content_width)
  }

  // 3. place each line: vertical metrics, alignment, justification
  let line_boxes : Array[LineBox] = []
  let mut y = style.space_before_pt
  for line_index, line in lines {
    let segments = split_segments(text, flat_runs, fallback, line)
    let mut ascent = 0.0
    let mut natural = 0.0
    for seg in segments {
      let face = segment_face(seg)
      let a = face.ascent_pt(seg.style.size_pt)
      if a > ascent {
        ascent = a
      }
      let h = face.line_height_pt(seg.style.size_pt)
      if h > natural {
        natural = h
      }
    }
    if segments.length() == 0 {
      // empty line (empty paragraph or blank between hard breaks): use
      // the first run's style, or a bare default when there are no runs
      let (face, size) = match flat_runs.get(0) {
        Some(r) => (r.face, r.style.size_pt)
        None => (@fonts.face("Carlito"), 12.0)
      }
      ascent = face.ascent_pt(size)
      natural = face.line_height_pt(size)
    }
    let line_height = match style.line_spacing {
      Single => natural
      Multiple(m) => natural * m
      Exact(h) => h
      AtLeast(h) => if natural > h { natural } else { h }
    }
    let is_first = line_index == 0
    let line_indent = style.indent_left_pt +
      (if is_first { style.indent_first_pt } else { 0.0 })
    let avail = if is_first { first_width } else { content_width }
    let slack = avail - line.width_pt
    let is_last = line_index == lines.length() - 1
    let mut x = line_indent
    let mut extra_per_space = 0.0
    match style.align {
      AlignLeft => ()
      AlignCenter => x += slack / 2
      AlignRight => x += slack
      AlignJustify =>
        if !is_last && slack > 0 {
          let spaces = count_spaces(
            text,
            line.start,
            line.start + visible_length(text, line),
          )
          if spaces > 0 {
            extra_per_space = slack / spaces.to_double()
          }
        }
    }
    let placed : Array[PlacedRun] = []
    let mut pen = x
    for seg in segments {
      let seg_text = text[seg.start:seg.end].to_owned()
      let seg_advances : Array[Double] = Array::new(
        capacity=seg.end - seg.start,
      )
      let mut seg_width = 0.0
      for j in seg.start..<seg.end {
        let mut a = advances[j]
        if extra_per_space > 0 && text[j].to_int() == 0x20 {
          a += extra_per_space
        }
        seg_advances.push(a)
        seg_width += a
      }
      placed.push({
        font: {
          family: segment_family(seg),
          bold: seg.style.bold,
          italic: seg.style.italic,
        },
        size_pt: seg.style.size_pt,
        x_pt: pen,
        text: seg_text,
        advances_pt: seg_advances,
        color: seg.style.color,
      })
      pen += seg_width
    }
    line_boxes.push({
      baseline_pt: y + ascent,
      height_pt: line_height,
      runs: placed,
    })
    y += line_height
  }
  { height_pt: y + style.space_after_pt, lines: line_boxes, }
}

///|
/// Rewrite the advances of every tab in `[from, to)` so each lands on
/// its stop, walking a pen that starts at `origin`.
///
/// A centre or right stop positions the text that FOLLOWS the tab, so it
/// needs that text's width — measured to the next tab or to `to`, which
/// is the span the stop governs. Neither ever pulls text backwards past
/// the pen.
fn resolve_tabs(
  text : String,
  advances : Array[Double],
  ruler : TabRuler,
  origin : Double,
  from : Int,
  to : Int,
) -> Unit {
  let mut pen = origin
  for i in from..<to {
    if text[i].to_int() != 0x09 {
      pen += advances[i]
      continue
    }
    let stop = ruler.next_stop_of(pen)
    let target = match stop.align {
      TabLeft | TabBar => stop.position_pt
      TabCenter | TabRight | TabDecimal => {
        // How far past the tab the text runs, and how far to its decimal
        // separator. A decimal stop aligns the separator; centre and right
        // use the whole span.
        let mut span = 0.0
        let mut to_separator = -1.0
        for j in (i + 1)..<to {
          if text[j].to_int() == 0x09 {
            break
          }
          if to_separator < 0.0 && text[j].to_int() == 0x2E {
            to_separator = span
          }
          span += advances[j]
        }
        let placed = match stop.align {
          TabRight => stop.position_pt - span
          TabCenter => stop.position_pt - span / 2.0
          // A decimal stop with nothing to align on right-aligns instead,
          // which is what Word does with an integer in a decimal column.
          TabDecimal =>
            if to_separator < 0.0 {
              stop.position_pt - span
            } else {
              stop.position_pt - to_separator
            }
          TabLeft | TabBar => stop.position_pt
        }
        if placed < pen {
          pen
        } else {
          placed
        }
      }
    }
    advances[i] = target - pen
    pen = target
  }
}

///|
/// Whether `[from, to)` holds a tab, so lines without one skip the
/// re-resolve entirely.
fn has_tab(text : String, from : Int, to : Int) -> Bool {
  for i in from..<to {
    if text[i].to_int() == 0x09 {
      return true
    }
  }
  false
}

///|
priv struct Segment {
  style : RunStyle
  face : @fonts.FaceMetrics
  used_fallback : Bool
  start : Int
  end : Int
}

///|
fn segment_face(seg : Segment) -> @fonts.FaceMetrics {
  if seg.used_fallback {
    @fonts.cjk_fallback()
  } else {
    seg.face
  }
}

///|
fn segment_family(seg : Segment) -> String {
  if seg.used_fallback {
    @fonts.cjk_fallback().family
  } else {
    seg.face.family
  }
}

///|
/// Slice one broken line back into maximal segments of identical
/// (input run, rendering face) so each becomes one placed run.
fn split_segments(
  text : String,
  flat_runs : Array[FlatRun],
  fallback : Array[Bool],
  line : @linebreak.LineRange,
) -> Array[Segment] {
  let segments : Array[Segment] = []
  let end = line.start + visible_length(text, line)
  let mut run_index = 0
  let mut i = line.start
  while i < end {
    while run_index < flat_runs.length() && flat_runs[run_index].end <= i {
      run_index += 1
    }
    guard run_index < flat_runs.length() else { break }
    let run = flat_runs[run_index]
    let seg_fallback = fallback[i]
    let mut j = i + 1
    while j < end && j < run.end && fallback[j] == seg_fallback {
      j += 1
    }
    segments.push({
      style: run.style,
      face: run.face,
      used_fallback: seg_fallback,
      start: i,
      end: j,
    })
    i = j
  }
  segments
}

///|
/// Code units of `line` that are actually rendered: its range minus the
/// trailing hanging-space run.
fn visible_length(text : String, line : @linebreak.LineRange) -> Int {
  let mut end = line.end
  while end > line.start && text[end - 1].to_int() == 0x20 {
    end -= 1
  }
  end - line.start
}

///|
fn count_spaces(text : String, start : Int, end : Int) -> Int {
  let mut n = 0
  for i in start..<end {
    if text[i].to_int() == 0x20 {
      n += 1
    }
  }
  n
}
