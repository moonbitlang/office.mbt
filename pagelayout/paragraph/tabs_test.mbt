///|
test "the default interval steps at multiples" {
  let ruler = @paragraph.TabRuler::default()
  inspect(ruler.next_stop(0), content="36")
  inspect(ruler.next_stop(10), content="36")
  inspect(ruler.next_stop(36), content="72")
  inspect(ruler.next_stop(80), content="108")
}

///|
test "explicit stops win, then the default takes over" {
  let ruler = @paragraph.TabRuler::{
    stops: [
      { position_pt: 50, align: TabLeft },
      { position_pt: 120, align: TabCenter },
    ],
    default_interval_pt: 36,
  }
  inspect(ruler.next_stop(0), content="50")
  inspect(ruler.next_stop(50), content="120")
  // past the last explicit stop the default interval resumes
  inspect(ruler.next_stop(120), content="144")
}

///|
test "a bar stop draws a rule and does not stop text" {
  let ruler = @paragraph.TabRuler::{
    stops: [
      { position_pt: 40, align: TabBar },
      { position_pt: 90, align: TabLeft },
    ],
    default_interval_pt: 36,
  }
  inspect(ruler.next_stop(0), content="90")
}

///|
test "a tab always advances, even past every stop" {
  let ruler = @paragraph.TabRuler::{
    stops: [{ position_pt: 10, align: TabLeft }],
    default_interval_pt: 0,
  }
  // a degenerate interval must not stall the pen
  assert_true(ruler.next_stop(500) > 500)
}

///|
test "a tab advances the pen to its stop, not by a glyph width" {
  let style = @paragraph.ParagraphStyle::default()
  let run = @paragraph.RunStyle::{
    family: "Calibri",
    size_pt: 12,
    bold: false,
    italic: false,
    color: @pagelayout.black,
  }
  let input = @paragraph.ParagraphInput::{
    runs: [{ text: "ab\tcd", style: run, field: NotAField }],
    style: {
      ..style,
      tabs: {
        stops: [{ position_pt: 100, align: TabLeft }],
        default_interval_pt: 36,
      },
    },
  }
  let laid = @paragraph.layout_paragraph(input, 400)
  let line = laid.lines[0]
  // the text after the tab starts exactly at the stop
  let mut x = line.runs[0].x_pt
  let mut i = 0
  for advance in line.runs[0].advances_pt {
    if i == 3 {
      break
    }
    x += advance
    i += 1
  }
  inspect(x, content="100")
}

///|
test "a right stop ends the following text at the stop" {
  let style = @paragraph.ParagraphStyle::default()
  let run = @paragraph.RunStyle::{
    family: "Calibri",
    size_pt: 12,
    bold: false,
    italic: false,
    color: @pagelayout.black,
  }
  let input = @paragraph.ParagraphInput::{
    runs: [{ text: "Chapter\t9", style: run, field: NotAField }],
    style: {
      ..style,
      tabs: {
        stops: [{ position_pt: 200, align: TabRight }],
        default_interval_pt: 36,
      },
    },
  }
  let laid = @paragraph.layout_paragraph(input, 400)
  let placed = laid.lines[0].runs[0]
  // the "9" after the tab ends exactly on the 200pt stop
  let mut right = placed.x_pt
  for advance in placed.advances_pt {
    right += advance
  }
  inspect(right, content="200")
}

///|
test "a centre stop centres the following text on the stop" {
  let style = @paragraph.ParagraphStyle::default()
  let run = @paragraph.RunStyle::{
    family: "Calibri",
    size_pt: 12,
    bold: false,
    italic: false,
    color: @pagelayout.black,
  }
  let input = @paragraph.ParagraphInput::{
    runs: [{ text: "a\tXY", style: run, field: NotAField }],
    style: {
      ..style,
      tabs: {
        stops: [{ position_pt: 100, align: TabCenter }],
        default_interval_pt: 36,
      },
    },
  }
  let laid = @paragraph.layout_paragraph(input, 400)
  let placed = laid.lines[0].runs[0]
  // measure where "XY" starts and ends; its midpoint is the stop
  let mut x = placed.x_pt
  for i in 0..<2 {
    x += placed.advances_pt[i]
  }
  let start = x
  let mut end = start
  for i in 2..<placed.advances_pt.length() {
    end += placed.advances_pt[i]
  }
  let midpoint = (start + end) / 2.0
  assert_true((midpoint - 100.0).abs() < 0.001)
}

///|
test "a right stop never pulls text backwards" {
  let style = @paragraph.ParagraphStyle::default()
  let run = @paragraph.RunStyle::{
    family: "Calibri",
    size_pt: 12,
    bold: false,
    italic: false,
    color: @pagelayout.black,
  }
  // the text before the tab already passes the stop
  let input = @paragraph.ParagraphInput::{
    runs: [
      {
        text: "a very long leading label indeed\tX",
        style: run,
        field: NotAField,
      },
    ],
    style: {
      ..style,
      tabs: {
        stops: [{ position_pt: 20, align: TabRight }],
        default_interval_pt: 36,
      },
    },
  }
  let laid = @paragraph.layout_paragraph(input, 400)
  let placed = laid.lines[0].runs[0]
  // every advance stays non-negative, so nothing overlaps backwards
  for advance in placed.advances_pt {
    assert_true(advance >= 0.0)
  }
}

///|
test "a tab on a wrapped line measures from that line's origin" {
  let run = @paragraph.RunStyle::{
    family: "Calibri",
    size_pt: 12,
    bold: false,
    italic: false,
    color: @pagelayout.black,
  }
  // the first line fills the measure, so the tab lands on line two
  let input = @paragraph.ParagraphInput::{
    runs: [
      {
        text: "aaaa bbbb cccc dddd eeee ffff gggg hhhh\tX",
        style: run,
        field: NotAField,
      },
    ],
    style: {
      ..@paragraph.ParagraphStyle::default(),
      tabs: {
        stops: [{ position_pt: 60, align: TabLeft }],
        default_interval_pt: 36,
      },
    },
  }
  let laid = @paragraph.layout_paragraph(input, 150)
  assert_true(laid.lines.length() > 1)
  // find the line holding the tab and check the text after it starts at
  // the 60pt stop, measured from that line rather than the paragraph
  let last = laid.lines[laid.lines.length() - 1]
  let placed = last.runs[last.runs.length() - 1]
  let mut x = placed.x_pt
  let mut i = 0
  while i < placed.text.length() {
    if placed.text[i].to_int() == 0x09 {
      x += placed.advances_pt[i]
      break
    }
    x += placed.advances_pt[i]
    i += 1
  }
  inspect(x, content="60")
}
