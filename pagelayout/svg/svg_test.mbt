///|
fn hello_model() -> @pagelayout.PageModel {
  @paginate.paginate([
    @paginate.Block::paragraph({
      runs: [
        {
          text: "Hello SVG",
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
    }),
  ])
}

///|
test "one-paragraph page renders deterministic svg" {
  let svg = @svg.render_page(hello_model(), 0)
  inspect(
    svg,
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" width="612pt" height="792pt" viewBox="0 0 612 792">
      #|  <rect x="0" y="0" width="612" height="792" fill="#ffffff"/>
      #|  <text x="72 79.477 85.447 88.201 90.955 97.283 99.996 105.51 112.318" y="83.426" font-family="Carlito" font-size="12" fill="#000000">Hello SVG</text>
      #|</svg>
      #|
    ),
  )
}

///|
test "special characters are xml-escaped" {
  let model = @paginate.paginate([
    @paginate.Block::paragraph({
      runs: [
        {
          text: "a<b & \"c\" 'd'>",
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
    }),
  ])
  let svg = @svg.render_page(model, 0)
  assert_true(svg.contains("a&lt;b &amp; &quot;c&quot; &apos;d&apos;&gt;"))
  assert_false(svg.contains("<b &"))
}

///|
test "bold and italic faces emit weight and style attributes" {
  let model = @paginate.paginate([
    @paginate.Block::paragraph({
      runs: [
        {
          text: "BI",
          style: {
            family: "Calibri",
            size_pt: 12,
            bold: true,
            italic: true,
            color: @pagelayout.black,
          },
        },
      ],
      style: @paragraph.ParagraphStyle::default(),
    }),
  ])
  let svg = @svg.render_page(model, 0)
  assert_true(svg.contains("font-weight=\"bold\""))
  assert_true(svg.contains("font-style=\"italic\""))
}

///|
test "rects and images transcribe with data uris" {
  let model = @pagelayout.PageModel::new()
  let page = @pagelayout.Page::{ width_pt: 100, height_pt: 100, items: [] }
  page.items.push(
    Rect({
      x_pt: 10,
      y_pt: 20,
      w_pt: 30,
      h_pt: 0.75,
      fill: Some(@pagelayout.Color::rgb(255, 0, 0)),
      stroke: None,
      stroke_w_pt: 0,
    }),
  )
  page.items.push(
    Image({
      x_pt: 5,
      y_pt: 6,
      w_pt: 7,
      h_pt: 8,
      data: b"\x01\x02\x03\x04",
      mime: "image/png",
    }),
  )
  model.pages.push(page)
  let svg = @svg.render_page(model, 0)
  assert_true(
    svg.contains(
      "<rect x=\"10\" y=\"20\" width=\"30\" height=\"0.75\" fill=\"#ff0000\"/>",
    ),
  )
  assert_true(svg.contains("href=\"data:image/png;base64,AQIDBA==\"/>"))
}

///|
test "per-code-unit x positions come from the advances" {
  let model = hello_model()
  let svg = @svg.render_page(model, 0)
  // "Hello SVG" = 9 code units -> 9 x positions in the list
  let marker = "<text x=\""
  guard! svg.find(marker) is Some(at)
  let after = svg[at + marker.length():].to_owned()
  guard! after.find("\"") is Some(close)
  let xs = after[0:close].to_owned()
  let mut positions = 1
  for c in xs {
    if c == ' ' {
      positions += 1
    }
  }
  assert_eq(positions, 9)
  // the first position is the run origin (left margin)
  assert_true(xs.has_prefix("72"))
}

///|
test "multi-page models render one svg per page" {
  let model = @paginate.paginate([
    @paginate.Block::paragraph({
      runs: [
        {
          text: "p1",
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
    }),
    PageBreak,
    @paginate.Block::paragraph({
      runs: [
        {
          text: "p2",
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
    }),
  ])
  let pages = @svg.render_pages(model)
  assert_eq(pages.length(), 2)
  assert_true(pages[0].contains(">p1</text>"))
  assert_true(pages[1].contains(">p2</text>"))
}
