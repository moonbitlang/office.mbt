///|
fn body(text : String) -> @paragraph.ParagraphInput {
  {
    runs: [
      {
        text,
        field: NotAField,
        style: {
          family: "Calibri",
          size_pt: 12,
          bold: false,
          italic: false,
          color: @pagelayout.black,
        },
      },
    ],
    style: @paragraph.ParagraphStyle::default(),
  }
}

///|
/// A section shaped to hold exactly `lines` 12pt Carlito lines
/// (line height 14.6484375) in its content box, 200pt wide.
fn tiny_section(lines : Int) -> @paginate.SectionProps {
  let line_h = 14.6484375
  {
    page_width_pt: 272,
    page_height_pt: 72.0 * 2.0 + line_h * lines.to_double(),
    margin_top_pt: 72,
    margin_right_pt: 36,
    margin_bottom_pt: 72,
    margin_left_pt: 36,
    header_pt: 18,
    footer_pt: 18,
  }
}

///|
fn long_text(words : Int) -> String {
  let sb = StringBuilder()
  for i in 0..<words {
    if i > 0 {
      sb.write_string(" ")
    }
    sb.write_string("word\{i % 10}")
  }
  sb.to_string()
}

///|
test "short document fills a single page" {
  let model = @paginate.paginate([@paginate.Block::paragraph(body("Hello"))])
  assert_eq(model.pages.length(), 1)
  debug_inspect(model.validate(), content="[]")
  // first baseline sits one ascent below the top margin
  guard! model.pages[0].items[0] is Text(run)
  inspect(run.baseline_pt, content="83.42578125")
  inspect(run.x_pt, content="72")
}

///|
test "overflowing text flows onto following pages" {
  let model = @paginate.paginate(
    [@paginate.Block::paragraph(body(long_text(120)))],
    section=tiny_section(6),
  )
  assert_true(model.pages.length() > 1)
  debug_inspect(model.validate(), content="[]")
  // every page keeps its content inside the bottom margin
  for page in model.pages {
    for item in page.items {
      guard! item is Text(run)
      assert_true(run.baseline_pt < page.height_pt - 72.0 + 0.0001)
      assert_true(run.baseline_pt > 72.0)
    }
  }
}

///|
test "explicit page break starts a new page" {
  let model = @paginate.paginate([
    @paginate.Block::paragraph(body("one")),
    PageBreak,
    @paginate.Block::paragraph(body("two")),
  ])
  assert_eq(model.pages.length(), 2)
  assert_eq(model.pages[0].items.length(), 1)
  assert_eq(model.pages[1].items.length(), 1)
}

///|
test "widow control keeps two lines on each side" {
  // 5-line paragraph into 6-line pages: fits entirely on page 1
  // 8-line paragraph: splits, and no page may hold a single line of it
  let text = long_text(90) // ~8 lines at 200pt
  let model = @paginate.paginate(
    [
      @paginate.Block::paragraph(body(long_text(30))),
      @paginate.Block::paragraph(body(text)),
    ],
    section=tiny_section(6),
  )
  debug_inspect(model.validate(), content="[]")
  assert_true(model.pages.length() >= 2)
  // count text baselines per page: with widow control no page carries
  // exactly one line of the split paragraph — approximate by requiring
  // at least two items on every page that has any
  for page in model.pages {
    let baselines : Array[Double] = []
    for item in page.items {
      guard! item is Text(run)
      if !baselines.contains(run.baseline_pt) {
        baselines.push(run.baseline_pt)
      }
    }
    assert_true(baselines.length() != 1 || model.pages.length() == 1)
  }
}

///|
test "keep_lines moves an unsplittable paragraph whole" {
  // page holds 6 lines; first paragraph takes 3, second needs 4 with
  // keep_lines: it must move to page 2 unsplit
  let model = @paginate.paginate(
    [
      @paginate.Block::paragraph(body("a1\na2\na3")), // exactly 3 lines
      @paginate.Block::paragraph(body("b1\nb2\nb3\nb4"), keep_lines=true), // 4
    ],
    section=tiny_section(6),
  )
  assert_eq(model.pages.length(), 2)
  // page 1 has only the first paragraph's lines
  let page1_baselines : Array[Double] = []
  for item in model.pages[0].items {
    guard! item is Text(run)
    if !page1_baselines.contains(run.baseline_pt) {
      page1_baselines.push(run.baseline_pt)
    }
  }
  assert_true(page1_baselines.length() <= 3)
}

///|
test "keep_next glues a heading to its body" {
  // page holds 6 lines: 5 lines of body, then a 1-line heading with
  // keep_next — the heading must move to page 2 with its paragraph
  let model = @paginate.paginate(
    [
      @paginate.Block::paragraph(body("a1\na2\na3\na4\na5")), // exactly 5 lines
      @paginate.Block::paragraph(body("Heading"), keep_next=true),
      @paginate.Block::paragraph(body("b1\nb2\nb3")),
    ],
    section=tiny_section(6),
  )
  assert_eq(model.pages.length(), 2)
  // the heading is page 2's first baseline
  guard! model.pages[1].items[0] is Text(first)
  inspect(first.text, content="Heading")
}

///|
test "space before is suppressed at page top" {
  let style = @paragraph.ParagraphStyle::default()
  let spaced = @paragraph.ParagraphInput::{
    runs: body("after break").runs,
    style: { ..style, space_before_pt: 100 },
  }
  let model = @paginate.paginate([
    @paginate.Block::paragraph(body("page one")),
    PageBreak,
    @paginate.Block::paragraph(spaced),
  ])
  guard! model.pages[1].items[0] is Text(run)
  // baseline equals the unspaced first-line baseline
  inspect(run.baseline_pt, content="83.42578125")
}

///|
test "empty document still yields one empty page" {
  let model = @paginate.paginate([])
  assert_eq(model.pages.length(), 1)
  assert_eq(model.pages[0].items.length(), 0)
}

///|
test "fonts are interned once across pages" {
  let model = @paginate.paginate(
    [
      @paginate.Block::paragraph(body(long_text(40))),
      @paginate.Block::paragraph(body(long_text(40))),
    ],
    section=tiny_section(4),
  )
  assert_eq(model.fonts.length(), 1)
  inspect(model.fonts[0].family, content="Carlito")
}
