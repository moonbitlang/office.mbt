///|
fn plain_style(size_pt : Double) -> @paragraph.RunStyle {
  {
    family: "Calibri",
    size_pt,
    bold: false,
    italic: false,
    color: @pagelayout.black,
  }
}

///|
fn para(
  text : String,
  align? : @paragraph.Alignment = AlignLeft,
  first? : Double = 0,
) -> @paragraph.ParagraphInput {
  let style = @paragraph.ParagraphStyle::default()
  {
    runs: [{ text, style: plain_style(12), field: NotAField, }],
    style: { ..style, align, indent_first_pt: first, },
  }
}

///|
test "single short line lays out on one baseline" {
  let layout = @paragraph.layout_paragraph(para("Hello world"), 400)
  assert_eq(layout.lines.length(), 1)
  let line = layout.lines[0]
  assert_eq(line.runs.length(), 1)
  inspect(line.runs[0].x_pt, content="0")
  // baseline = Carlito ascent at 12pt
  inspect(line.baseline_pt, content="11.42578125")
  inspect(layout.height_pt, content="14.6484375")
}

///|
test "wrapping stacks baselines one line height apart" {
  let text = "the quick brown fox jumps over the lazy dog"
  let layout = @paragraph.layout_paragraph(para(text), 90)
  assert_eq(layout.lines.length(), 3)
  let h = layout.lines[1].baseline_pt - layout.lines[0].baseline_pt
  inspect(h, content="14.6484375")
  let h2 = layout.lines[2].baseline_pt - layout.lines[1].baseline_pt
  assert_eq(h, h2)
}

///|
test "first-line indent shifts only the first line" {
  let text = "aaa bbb ccc ddd eee fff ggg hhh"
  let layout = @paragraph.layout_paragraph(para(text, first=18), 100)
  assert_true(layout.lines.length() >= 2)
  inspect(layout.lines[0].runs[0].x_pt, content="18")
  inspect(layout.lines[1].runs[0].x_pt, content="0")
}

///|
test "center and right alignment position by slack" {
  let centered = @paragraph.layout_paragraph(para("Hi", align=AlignCenter), 100)
  let righted = @paragraph.layout_paragraph(para("Hi", align=AlignRight), 100)
  let width = centered.lines[0].runs[0].advances_pt[0] +
    centered.lines[0].runs[0].advances_pt[1]
  assert_eq(centered.lines[0].runs[0].x_pt, (100 - width) / 2)
  assert_eq(righted.lines[0].runs[0].x_pt, 100 - width)
}

///|
test "justify stretches spaces on all but the last line" {
  let text = "aa bb cc dd ee ff gg hh ii jj"
  let layout = @paragraph.layout_paragraph(para(text, align=AlignJustify), 60)
  assert_true(layout.lines.length() >= 2)
  // every non-final line fills the full measure
  for i in 0..<(layout.lines.length() - 1) {
    let line = layout.lines[i]
    let last = line.runs[line.runs.length() - 1]
    let mut right_edge = last.x_pt
    for a in last.advances_pt {
      right_edge += a
    }
    // trailing hanging space stretches past the measure; the visible
    // right edge before it must land on the measure
    let spaces_at_end = if last.text.length() > 0 &&
      last.text[last.text.length() - 1].to_int() == 0x20 {
      last.advances_pt[last.advances_pt.length() - 1]
    } else {
      0.0
    }
    let visible_edge = right_edge - spaces_at_end
    assert_true((visible_edge - 60.0).abs() < 0.0001)
  }
  // the last line stays ragged
  let final_line = layout.lines[layout.lines.length() - 1]
  let mut w = 0.0
  for run in final_line.runs {
    for a in run.advances_pt {
      w += a
    }
  }
  assert_true(w < 60.0)
}

///|
test "mixed cjk splits into separately-faced placed runs" {
  let layout = @paragraph.layout_paragraph(para("engine引擎end"), 400)
  let line = layout.lines[0]
  assert_eq(line.runs.length(), 3)
  inspect(line.runs[0].font.family, content="Carlito")
  inspect(line.runs[1].font.family, content="Noto Sans SC")
  inspect(line.runs[2].font.family, content="Carlito")
  // runs abut: each starts where the previous ended
  let mut edge = line.runs[0].x_pt
  for run in line.runs {
    assert_true((run.x_pt - edge).abs() < 0.0001)
    for a in run.advances_pt {
      edge += a
    }
  }
  // the CJK line raises the line height to Noto's metrics
  let noto = @fonts.cjk_fallback()
  assert_eq(line.height_pt, noto.line_height_pt(12))
}

///|
test "multi-style runs keep their boundaries" {
  let bold = @paragraph.RunStyle::{
    family: "Calibri",
    size_pt: 12,
    bold: true,
    italic: false,
    color: @pagelayout.black,
  }
  let input = @paragraph.ParagraphInput::{
    runs: [
      { text: "normal ", style: plain_style(12), field: NotAField, },
      { text: "bold", style: bold, field: NotAField, },
    ],
    style: @paragraph.ParagraphStyle::default(),
  }
  let layout = @paragraph.layout_paragraph(input, 400)
  let line = layout.lines[0]
  assert_eq(line.runs.length(), 2)
  assert_false(line.runs[0].font.bold)
  assert_true(line.runs[1].font.bold)
  inspect(line.runs[1].text, content="bold")
}

///|
test "line spacing rules scale heights" {
  let base = @paragraph.layout_paragraph(para("Hello"), 400)
  let natural = base.lines[0].height_pt
  let style = @paragraph.ParagraphStyle::default()
  let double_spaced = @paragraph.layout_paragraph(
    {
      runs: para("Hello").runs,
      style: { ..style, line_spacing: Multiple(2), },
    },
    400,
  )
  assert_eq(double_spaced.lines[0].height_pt, natural * 2)
  let exact = @paragraph.layout_paragraph(
    { runs: para("Hello").runs, style: { ..style, line_spacing: Exact(20), }, },
    400,
  )
  assert_eq(exact.lines[0].height_pt, 20)
  let at_least_small = @paragraph.layout_paragraph(
    { runs: para("Hello").runs, style: { ..style, line_spacing: AtLeast(6), }, },
    400,
  )
  assert_eq(at_least_small.lines[0].height_pt, natural)
}

///|
test "space before and after pad the paragraph height" {
  let style = @paragraph.ParagraphStyle::default()
  let padded = @paragraph.layout_paragraph(
    {
      runs: para("Hello").runs,
      style: { ..style, space_before_pt: 6, space_after_pt: 10, },
    },
    400,
  )
  let bare = @paragraph.layout_paragraph(para("Hello"), 400)
  assert_eq(padded.height_pt, bare.height_pt + 16)
  assert_eq(padded.lines[0].baseline_pt, bare.lines[0].baseline_pt + 6)
}

///|
test "empty paragraph still occupies one line" {
  let layout = @paragraph.layout_paragraph(para(""), 400)
  assert_eq(layout.lines.length(), 1)
  assert_eq(layout.lines[0].runs.length(), 0)
  inspect(layout.height_pt, content="14.6484375")
}
