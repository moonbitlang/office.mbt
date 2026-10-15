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
fn tiny_section(lines : Int32) -> @paginate.SectionProps {
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
fn long_text(words : Int32) -> String {
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
    style: { ..style, space_before_pt: 100, },
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

///|
/// Furniture whose four variants are distinguishable by their text.
fn variant_furniture(
  title_page~ : Bool,
  even_and_odd~ : Bool,
) -> @paginate.PageFurniture {
  fn head(text : String) {
    [
      @paginate.Block::paragraph({
        runs: [
          {
            text,
            style: {
              family: "Carlito",
              size_pt: 10,
              bold: false,
              italic: false,
              color: @pagelayout.black,
            },
            field: NotAField,
          },
        ],
        style: @paragraph.ParagraphStyle::default(),
      }),
    ]
  }

  {
    header: head("DEFAULT"),
    footer: [],
    first_header: head("FIRST"),
    first_footer: [],
    even_header: head("EVEN"),
    even_footer: [],
    title_page,
    even_and_odd,
  }
}

///|
/// Three pages, forced by explicit breaks so the test does not depend on
/// how much text happens to fit.
fn three_pages() -> Array[@paginate.Block] {
  [
    @paginate.Block::paragraph(body("one")),
    PageBreak,
    @paginate.Block::paragraph(body("two")),
    PageBreak,
    @paginate.Block::paragraph(body("three")),
  ]
}

///|
/// The header text stamped on each page, in page order.
fn headers_of(model : @pagelayout.PageModel) -> Array[String] {
  let out : Array[String] = []
  for page in model.pages {
    let mut found = ""
    for item in page.items {
      guard item is Text(run) else { continue }
      if run.text == "DEFAULT" || run.text == "FIRST" || run.text == "EVEN" {
        found = run.text
      }
    }
    out.push(found)
  }
  out
}

///|
test "w:titlePg gives page one its own header" {
  // Without the flag the first-page reference is ignored, which is what
  // Word does: the variants are only consulted when the section asks.
  let pages = three_pages()
  debug_inspect(
    headers_of(
      @paginate.paginate(
        pages,
        furniture=variant_furniture(title_page=false, even_and_odd=false),
      ),
    ),
    content=(
      #|["DEFAULT", "DEFAULT", "DEFAULT"]
    ),
  )
  debug_inspect(
    headers_of(
      @paginate.paginate(
        pages,
        furniture=variant_furniture(title_page=true, even_and_odd=false),
      ),
    ),
    content=(
      #|["FIRST", "DEFAULT", "DEFAULT"]
    ),
  )
}

///|
test "w:evenAndOddHeaders alternates by page number, not index" {
  // Page numbers are 1-based, so the even variant lands on pages 2 and 4
  // — indices 1 and 3.
  let pages = three_pages()
  debug_inspect(
    headers_of(
      @paginate.paginate(
        pages,
        furniture=variant_furniture(title_page=false, even_and_odd=true),
      ),
    ),
    content=(
      #|["DEFAULT", "EVEN", "DEFAULT"]
    ),
  )
  // a title page wins over the even/odd alternation on page one
  debug_inspect(
    headers_of(
      @paginate.paginate(
        pages,
        furniture=variant_furniture(title_page=true, even_and_odd=true),
      ),
    ),
    content=(
      #|["FIRST", "EVEN", "DEFAULT"]
    ),
  )
}

///|
test "inline header pictures keep coordinates after variable length page fields" {
  let plain = body("\uFFFCafter")
  let input = {
    ..plain,
    runs: [{ ..plain.runs[0], text: "99", field: PageNumber, }, plain.runs[0]],
  }
  let image = @paragraph.InlineImage::{
    offset_utf16: 2,
    width_pt: 20,
    height_pt: 10,
    data: b"image",
    mime: "image/png",
  }
  let header = @paginate.Block::paragraph_with_images(input, [image])
  let furniture = { ..@paginate.PageFurniture::none(), header: [header], }
  let section = tiny_section(4)
  let model = @paginate.paginate(
    [
      @paginate.Block::paragraph(body("first")),
      PageBreak,
      @paginate.Block::paragraph(body("second")),
    ],
    section~,
    furniture~,
  )
  debug_inspect(model.pages.length(), content="2")
  for index, page in model.pages {
    let texts = page.items.filter_map(item => {
      match item {
        Text(run) => Some(run)
        _ => None
      }
    })
    debug_inspect(
      texts.any(run => run.text == (index + 1).to_string()),
      content="true",
    )
    debug_inspect(
      texts.any(run => run.text.contains("\uFFFC")),
      content="false",
    )
    let images = page.items.filter_map(item => {
      match item {
        Image(image) => Some(image)
        _ => None
      }
    })
    debug_inspect(images.length(), content="1")
    let image = images[0]
    debug_inspect(
      (
        image.x_pt > section.margin_left_pt,
        image.y_pt >= section.header_pt,
        image.y_pt + image.h_pt < section.margin_top_pt,
      ),
      content="(true, true, true)",
    )
    let after = texts.filter(run => run.text == "after")
    debug_inspect(after.length(), content="1")
    debug_inspect(
      (after[0].x_pt - image.x_pt - image.w_pt).abs() < 0.001,
      content="true",
    )
  }
}

///|
fn footer_test_picture() -> @paragraph.InlineImage {
  {
    offset_utf16: 0,
    width_pt: 20,
    height_pt: 40,
    data: b"image",
    mime: "image/png",
  }
}

///|
test "an image-only inline footer ends at the footer bottom instead of being clipped" {
  let section = tiny_section(4)
  let footer = @paginate.Block::paragraph_with_images(body("\uFFFC"), [
    footer_test_picture(),
  ])
  let furniture = { ..@paginate.PageFurniture::none(), footer: [footer], }
  let model = @paginate.paginate(
    [@paginate.Block::paragraph(body("Body"))],
    section~,
    furniture~,
  )
  let page = model.pages[0]
  let images = page.items.filter_map(item => {
    match item {
      Image(image) => Some(image)
      _ => None
    }
  })
  debug_inspect(
    images.map(image => {
      (
        image.w_pt,
        image.h_pt,
        (image.y_pt + image.h_pt - (page.height_pt - section.footer_pt)).abs() <
        0.001,
        image.y_pt >= 0.0 && image.y_pt + image.h_pt <= page.height_pt,
      )
    }),
    content="[(20, 40, true, true)]",
  )
}

///|
test "a footer image after dynamic page fields reserves its final line height on every page" {
  let section = tiny_section(4)
  let plain = body("\n\uFFFC")
  let input = {
    ..plain,
    runs: [{ ..plain.runs[0], text: "99", field: PageNumber, }, plain.runs[0]],
  }
  let image = { ..footer_test_picture(), offset_utf16: 3, }
  let footer = @paginate.Block::paragraph_with_images(input, [image])
  let furniture = { ..@paginate.PageFurniture::none(), footer: [footer], }
  let model = @paginate.paginate(
    [
      @paginate.Block::paragraph(body("First body")),
      PageBreak,
      @paginate.Block::paragraph(body("Second body")),
    ],
    section~,
    furniture~,
  )
  debug_inspect(model.pages.length(), content="2")
  for index, page in model.pages {
    let texts = page.items.filter_map(item => {
      match item {
        Text(run) => Some(run)
        _ => None
      }
    })
    let images = page.items.filter_map(item => {
      match item {
        Image(image) => Some(image)
        _ => None
      }
    })
    debug_inspect(
      (
        texts.any(run => run.text == (index + 1).to_string()),
        texts.any(run => run.text.contains("\uFFFC")),
        images.map(image => {
          (
            image.h_pt,
            (image.y_pt + image.h_pt - (page.height_pt - section.footer_pt)).abs() <
            0.001,
            image.y_pt >= 0.0 && image.y_pt + image.h_pt <= page.height_pt,
          )
        }),
      ),
      content="(true, false, [(40, true, true)])",
    )
  }
}

///|
test "stacked image block footers count each image's local y and height" {
  let section = tiny_section(4)
  let picture = footer_test_picture()
  let furniture = {
    ..@paginate.PageFurniture::none(),
    footer: [
      @paginate.Block::image(20, 20, picture.data, picture.mime),
      @paginate.Block::image(20, 30, picture.data, picture.mime),
    ],
  }
  let model = @paginate.paginate(
    [@paginate.Block::paragraph(body("Body"))],
    section~,
    furniture~,
  )
  let page = model.pages[0]
  let images = page.items.filter_map(item => {
    match item {
      Image(image) => Some(image)
      _ => None
    }
  })
  debug_inspect(images.length(), content="2")
  debug_inspect(
    (
      (images[0].y_pt - (page.height_pt - section.footer_pt - 50)).abs() < 0.001,
      (images[0].y_pt + images[0].h_pt - images[1].y_pt).abs() < 0.001,
      (images[1].y_pt + images[1].h_pt - (page.height_pt - section.footer_pt)).abs() <
      0.001,
    ),
    content="(true, true, true)",
  )
}

///|
test "many inline images keep their line order across page boundaries" {
  let text = [ for _ in 0..<128 => "\uFFFC" ].join("\n")
  let images : Array[@paragraph.InlineImage] = [
    for i in 0..<128 => {
      {
        offset_utf16: i * 2,
        width_pt: (i + 1).to_double(),
        height_pt: 10.0,
        data: b"image",
        mime: "image/png",
      }
    }
  ]
  let model = @paginate.paginate(
    [@paginate.Block::paragraph_with_images(body(text), images)],
    section=tiny_section(4),
  )
  let widths : Array[Double] = []
  for page in model.pages {
    for item in page.items {
      if item is Image(image) {
        widths.push(image.w_pt)
      }
    }
  }
  debug_inspect(
    (
      model.pages.length() > 1,
      widths.length(),
      widths == [ for i in 1..<=128 => i.to_double() ],
    ),
    content="(true, 128, true)",
  )
}
