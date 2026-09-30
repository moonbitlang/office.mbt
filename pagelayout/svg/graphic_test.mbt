///|
test "a graphic renders as nested groups, clips, paths and gradients" {
  let model = @pagelayout.PageModel::new()
  let page = @pagelayout.Page::{ width_pt: 100, height_pt: 50, items: [], }
  let gradient = @pagelayout.Gradient::{
    shape: Linear(x1=0, y1=0, x2=10, y2=0),
    stops: [
      { offset: 0, color: @pagelayout.Color::rgb(255, 255, 255), },
      { offset: 1, color: @pagelayout.Color::rgb(0, 0, 0), },
    ],
    transform: @pagelayout.identity,
  }
  page.items.push(
    Graphic({
      x_pt: 10,
      y_pt: 5,
      ops: [
        Save,
        Transform({ a: 2, b: 0, c: 0, d: 2, e: 0, f: 0, }),
        Clip([Rectangle(0, 0, 20, 10)], NonZero),
        Alpha(0.5, 1),
        Path({
          segments: [MoveTo(0, 0), LineTo(10, 0), LineTo(10, 10), Close],
          fill: Some(GradientPaint(gradient)),
          fill_rule: EvenOdd,
          stroke: Some(Solid(@pagelayout.Color::rgb(255, 0, 0))),
          stroke_style: { ..@pagelayout.StrokeStyle::default(), dash: [2, 1], },
        }),
        Restore,
      ],
    }),
  )
  model.pages.push(page)
  inspect(
    @svg.render_page(model, 0),
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" width="100pt" height="50pt" viewBox="0 0 100 50">
      #|  <rect x="0" y="0" width="100" height="50" fill="#ffffff"/>
      #|  <g transform="translate(10 5)">
      #|  <g transform="matrix(2 0 0 2 0 0)">
      #|  <clipPath id="c1"><path d="M0 10h20v-10h-20Z" clip-rule="nonzero"/></clipPath>
      #|  <g clip-path="url(#c1)">
      #|  <linearGradient id="g2" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1 0 0 1 0 0)" x1="0" y1="0" x2="10" y2="0">
      #|    <stop offset="0" stop-color="#ffffff"/>
      #|    <stop offset="1" stop-color="#000000"/>
      #|  </linearGradient>
      #|  <path d="M0 0L10 0L10 10Z" fill="url(#g2)" fill-rule="evenodd" fill-opacity="0.5" stroke="#ff0000" stroke-width="1" stroke-miterlimit="10" stroke-dasharray="2 1"/>
      #|  </g>
      #|  </g>
      #|  </g>
      #|</svg>
      #|
    ),
  )
}

///|
/// A page with one graphic whose ops are made from a one-letter run.
fn text_graphic(
  ops : (@pagelayout.GlyphRun) -> Array[@pagelayout.GraphicOp],
) -> @pagelayout.PageModel {
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({ family: "Sans", bold: false, italic: false, })
  let run = @pagelayout.GlyphRun::{
    font,
    size_pt: 10,
    x_pt: 0,
    baseline_pt: 10,
    text: "A",
    advances_pt: [6],
    color: @pagelayout.black,
  }
  let page = @pagelayout.Page::{ width_pt: 100, height_pt: 50, items: [], }
  page.items.push(Graphic({ x_pt: 0, y_pt: 0, ops: ops(run), }))
  model.pages.push(page)
  model
}

///|
test "painted text takes its fill and stroke opacities separately" {
  let red = @pagelayout.Color::rgb(255, 0, 0)
  let style = @pagelayout.StrokeStyle::default()
  let model = text_graphic(run => {
    [
      Alpha(0, 1),
      PaintedText(run, { fill: false, stroke: Some(red), stroke_style: style, }),
      Alpha(1, 0),
      PaintedText(run, { fill: true, stroke: Some(red), stroke_style: style, }),
      Alpha(0.5, 0.25),
      Text(run),
    ]
  })
  inspect(
    @svg.render_page(model, 0),
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" width="100pt" height="50pt" viewBox="0 0 100 50">
      #|  <rect x="0" y="0" width="100" height="50" fill="#ffffff"/>
      #|  <g transform="translate(0 0)">
      #|  <text x="0" y="10" font-family="Sans" font-size="10" fill="none" stroke="#ff0000" stroke-width="1" stroke-miterlimit="10">A</text>
      #|  <text x="0" y="10" font-family="Sans" font-size="10" fill="#000000" stroke="#ff0000" stroke-width="1" stroke-miterlimit="10" stroke-opacity="0">A</text>
      #|  <text x="0" y="10" font-family="Sans" font-size="10" fill="#000000" fill-opacity="0.5">A</text>
      #|  </g>
      #|</svg>
      #|
    ),
  )
}

///|
test "text outlines are stroked in their own whole style" {
  let red = @pagelayout.Color::rgb(255, 0, 0)
  let model = text_graphic(run => {
    [
      Path({
        segments: [MoveTo(0, 0), LineTo(10, 0)],
        fill: None,
        fill_rule: NonZero,
        stroke: Some(Solid(red)),
        stroke_style: {
          ..@pagelayout.StrokeStyle::default(),
          cap: RoundCap,
          dash: [1, 4],
        },
      }),
      PaintedText(run, {
        fill: false,
        stroke: Some(red),
        stroke_style: {
          ..@pagelayout.StrokeStyle::default(),
          width: Width(0.5),
          join: RoundJoin,
          dash: [2, 1],
          dash_phase: 1,
        },
      }),
    ]
  })
  let svg = @svg.render_page(model, 0)
  assert_true(
    svg.contains(
      "fill=\"none\" stroke=\"#ff0000\" stroke-width=\"0.5\" stroke-linejoin=\"round\" stroke-miterlimit=\"10\" stroke-dasharray=\"2 1\" stroke-dashoffset=\"1\">A</text>",
    ),
  )
}

///|
test "a hairline is a non-scaling stroke one pixel wide" {
  let hairline = { ..@pagelayout.StrokeStyle::default(), width: Hairline, }
  let model = text_graphic(run => {
    [
      Transform({ a: 10, b: 0, c: 0, d: 10, e: 0, f: 0, }),
      Path({
        segments: [MoveTo(0, 0), LineTo(10, 0)],
        fill: None,
        fill_rule: NonZero,
        stroke: Some(Solid(@pagelayout.black)),
        stroke_style: hairline,
      }),
      PaintedText(run, {
        fill: false,
        stroke: Some(@pagelayout.black),
        stroke_style: hairline,
      }),
    ]
  })
  let svg = @svg.render_page(model, 0)
  assert_true(
    svg.contains(
      "<path d=\"M0 0L10 0\" fill=\"none\" stroke=\"#000000\" stroke-width=\"1\" vector-effect=\"non-scaling-stroke\" stroke-miterlimit=\"10\"/>",
    ),
  )
  assert_true(
    svg.contains(
      "fill=\"none\" stroke=\"#000000\" stroke-width=\"1\" vector-effect=\"non-scaling-stroke\" stroke-miterlimit=\"10\">A</text>",
    ),
  )
}

///|
/// A stroke-only path in `style`, black.
fn stroked(
  segments : Array[@pagelayout.PathSegment],
  style : @pagelayout.StrokeStyle,
) -> @pagelayout.GraphicOp {
  Path({
    segments,
    fill: None,
    fill_rule: NonZero,
    stroke: Some(Solid(@pagelayout.black)),
    stroke_style: style,
  })
}

///|
test "a dashed hairline keeps its dashes in the graphic's space" {
  // ten units scaled by ten, dashed one on, one off: five dashes ten
  // points long, as PDF draws `[1 1] 0 d` with `0 w` there
  let hairline = {
    ..@pagelayout.StrokeStyle::default(),
    width: Hairline,
    dash: [1, 1],
  }
  let model = text_graphic(_ => {
    [
      Transform({ a: 10, b: 0, c: 0, d: 10, e: 0, f: 0, }),
      stroked([MoveTo(0, 0), LineTo(10, 0)], hairline),
    ]
  })
  let svg = @svg.render_page(model, 0)
  // the dashes are drawn as subpaths of a solid non-scaling stroke, since
  // a non-scaling stroke's dash lengths would not be in the graphic's space
  assert_true(
    svg.contains(
      "<path d=\"M0 0L1 0M2 0L3 0M4 0L5 0M6 0L7 0M8 0L9 0\" fill=\"none\" stroke=\"#000000\" stroke-width=\"1\" vector-effect=\"non-scaling-stroke\" stroke-miterlimit=\"10\"/>",
    ),
  )
  assert_false(svg.contains("stroke-dasharray"))
}

///|
test "dashed hairlines restart at each subpath, from the phase, and follow curves" {
  let hairline = {
    ..@pagelayout.StrokeStyle::default(),
    width: Hairline,
    dash: [2],
    dash_phase: 1,
  }
  let model = text_graphic(_ => {
    [
      // a filled square keeps its fill, whole
      Path({
        segments: [Rectangle(0, 0, 4, 4)],
        fill: Some(Solid(@pagelayout.black)),
        fill_rule: NonZero,
        stroke: Some(Solid(@pagelayout.black)),
        stroke_style: hairline,
      }),
      // a quarter of the way into the pattern [2 2] at 1: one unit on,
      // then two off, two on; again for the second subpath
      stroked(
        [
          MoveTo(0, 10),
          LineTo(6, 10),
          MoveTo(0, 20),
          CurveTo(2, 20, 4, 20, 6, 20),
        ],
        hairline,
      ),
    ]
  })
  let svg = @svg.render_page(model, 0)
  assert_true(svg.contains("<path d=\"M0 4h4v-4h-4Z\" fill=\"#000000\"/>"))
  // around the square from its bottom-left corner, 16 long: on 0-1, 3-5,
  // 7-9, 11-13, 15-16, the dashes turning its corners
  assert_true(
    svg.contains(
      "<path d=\"M0 4L1 4M3 4L4 4L4 3M4 1L4 0L3 0M1 0L0 0L0 1M0 3L0 4\" fill=\"none\"",
    ),
  )
  // the curve (straight, its parameter in step with its length) split
  // where the lines are
  let start = svg.find("<path d=\"M0 10").unwrap() + "<path d=\"".length()
  let d = svg[start:]
  let d = d[:d.find("\"").unwrap()]
  let (letters, numbers) = path_parts(d)
  assert_eq(letters, "MLMLMCMC")
  let expected : ReadOnlyArray[Double] = [
    0.0,
    10,
    1,
    10,
    3,
    10,
    5,
    10,
    0,
    20,
    1.0 / 3,
    20,
    2.0 / 3,
    20,
    1,
    20,
    3,
    20,
    11.0 / 3,
    20,
    13.0 / 3,
    20,
    5,
    20,
  ]
  assert_eq(numbers.length(), expected.length())
  for i, n in numbers {
    assert_true((n - expected[i]).abs() < 1.0e-9)
  }
}

///|
/// Path data's command letters, and its numbers.
fn path_parts(d : StringView) -> (String, Array[Double]) raise {
  let letters = StringBuilder()
  let numbers = []
  let word = StringBuilder()
  let flush = fn() raise {
    if word.to_string() != "" {
      numbers.push(@string.parse_double(word.to_string()))
      word.reset()
    }
  }
  for c in d {
    if c is ('A'..='Z' | 'a'..='z') && c != 'e' {
      flush()
      letters.write_char(c)
    } else if c == ' ' {
      flush()
    } else {
      word.write_char(c)
    }
  }
  flush()
  (letters.to_string(), numbers)
}

///|
test "gradient stops at the ends: only the one nearer the middle is written" {
  let colours : ReadOnlyArray[@pagelayout.Color] = [
    @pagelayout.Color::rgb(255, 255, 255),
    @pagelayout.Color::rgb(255, 0, 0),
    @pagelayout.Color::rgb(0, 0, 255),
    @pagelayout.Color::rgb(0, 255, 0),
    @pagelayout.Color::rgb(0, 0, 0),
  ]
  let offsets : Array[Double] = [0, 0, 0.5, 1, 1]
  let model = text_graphic(_ => {
    [
      Path({
        segments: [Rectangle(0, 0, 10, 10)],
        fill: Some(
          GradientPaint({
            shape: Radial(x1=5, y1=5, r1=0, x2=5, y2=5, r2=5),
            stops: offsets.mapi((i, offset) => { offset, color: colours[i], }),
            transform: @pagelayout.identity,
          }),
        ),
        fill_rule: NonZero,
        stroke: None,
        stroke_style: @pagelayout.StrokeStyle::default(),
      }),
    ]
  })
  let svg = @svg.render_page(model, 0)
  let start = svg.find("<radialGradient").unwrap()
  let end = svg.find("</radialGradient>").unwrap()
  inspect(
    svg[start:end + "</radialGradient>".length()],
    content=(
      #|<radialGradient id="g1" gradientUnits="userSpaceOnUse" gradientTransform="matrix(1 0 0 1 0 0)" fx="5" fy="5" fr="0" cx="5" cy="5" r="5">
      #|    <stop offset="0" stop-color="#ff0000"/>
      #|    <stop offset="0.5" stop-color="#0000ff"/>
      #|    <stop offset="1" stop-color="#00ff00"/>
      #|  </radialGradient>
    ),
  )
}

///|
test "small transformations and fine coordinates survive in SVG" {
  let model = text_graphic(run => {
    [
      Transform({ a: 0.0001, b: 0, c: 0, d: 0.0001, e: 0, f: 0, }),
      Path({
        segments: [Rectangle(0, 0, 1000000, 600000.25)],
        fill: Some(Solid(@pagelayout.black)),
        fill_rule: NonZero,
        stroke: None,
        stroke_style: @pagelayout.StrokeStyle::default(),
      }),
      Transform({ a: 1.0e-7, b: 0, c: 0, d: 1.0e-7, e: 0.00025, f: 0, }),
      Text({ ..run, x_pt: 1234.0005, size_pt: 1.0e8, }),
    ]
  })
  inspect(
    @svg.render_page(model, 0),
    content=(
      #|<svg xmlns="http://www.w3.org/2000/svg" width="100pt" height="50pt" viewBox="0 0 100 50">
      #|  <rect x="0" y="0" width="100" height="50" fill="#ffffff"/>
      #|  <g transform="translate(0 0)">
      #|  <g transform="matrix(0.0001 0 0 0.0001 0 0)">
      #|  <path d="M0 600000.25h1000000v-600000.25h-1000000Z" fill="#000000"/>
      #|  <g transform="matrix(1e-7 0 0 1e-7 0.00025 0)">
      #|  <text x="1234.0005" y="10" font-family="Sans" font-size="100000000" fill="#000000">A</text>
      #|  </g>
      #|  </g>
      #|  </g>
      #|</svg>
      #|
    ),
  )
}

///|
test "a gradient used again on the page is defined once" {
  let gradient = @pagelayout.Gradient::{
    shape: Linear(x1=0, y1=0, x2=10, y2=0),
    stops: [
      { offset: 0, color: @pagelayout.Color::rgb(255, 255, 255), },
      { offset: 1, color: @pagelayout.black, },
    ],
    transform: @pagelayout.identity,
  }
  let fill = @pagelayout.GraphicOp::Path({
    segments: [Rectangle(0, 0, 10, 10)],
    fill: Some(GradientPaint(gradient)),
    fill_rule: NonZero,
    stroke: Some(GradientPaint(gradient)),
    stroke_style: @pagelayout.StrokeStyle::default(),
  })
  let other = @pagelayout.GraphicOp::Path({
    segments: [Rectangle(0, 0, 10, 10)],
    fill: Some(
      GradientPaint({
        ..gradient,
        transform: { ..@pagelayout.identity, e: 1, },
      }),
    ),
    fill_rule: NonZero,
    stroke: None,
    stroke_style: @pagelayout.StrokeStyle::default(),
  })
  let model = text_graphic(_ => {
    [
      fill,
      Transform({ ..@pagelayout.identity, a: 2, }),
      Clip([Rectangle(0, 0, 5, 5)], NonZero),
      fill,
      other,
    ]
  })
  let svg = @svg.render_page(model, 0)
  assert_eq(svg.split("<linearGradient").count() - 1, 2)
  assert_eq(svg.split("url(#g1)").count() - 1, 4)
  assert_true(svg.contains("<clipPath id=\"c2\">"))
  assert_true(svg.contains("fill=\"url(#g3)\""))
}

///|
/// Gradients without extent, white to red to blue: a linear one whose ends
/// coincide, a radial one whose end circle has radius 0, and one whose
/// circles coincide.
let degenerate_gradients : Array[@pagelayout.Gradient] = [
  @pagelayout.GradientShape::Linear(x1=5, y1=5, x2=5, y2=5),
  Radial(x1=1, y1=1, r1=2, x2=5, y2=5, r2=0),
  Radial(x1=5, y1=5, r1=3, x2=5, y2=5, r2=3),
].map(shape => {
  shape,
  stops: [
    { offset: 0, color: @pagelayout.Color::rgb(255, 255, 255), },
    { offset: 0.5, color: @pagelayout.Color::rgb(255, 0, 0), },
    { offset: 1, color: @pagelayout.Color::rgb(0, 0, 255), },
  ],
  transform: @pagelayout.identity,
})

///|
test "a gradient without extent paints its last stop's colour" {
  let model = text_graphic(_ => {
    degenerate_gradients.map(gradient => {
      @pagelayout.GraphicOp::Path({
        segments: [Rectangle(0, 0, 10, 10)],
        fill: Some(GradientPaint(gradient)),
        fill_rule: NonZero,
        stroke: Some(GradientPaint(gradient)),
        stroke_style: @pagelayout.StrokeStyle::default(),
      })
    })
  })
  assert_true(model.validate().is_empty())
  let svg = @svg.render_page(model, 0)
  assert_false(svg.contains("Gradient"))
  assert_eq(svg.split("fill=\"#0000ff\" stroke=\"#0000ff\"").count() - 1, 3)
}

///|
test "an image in a graphic is stretched to its rectangle" {
  let model = text_graphic(_ => {
    [
      Alpha(0.5, 1),
      Image({
        x_pt: 1,
        y_pt: 2,
        w_pt: 30,
        h_pt: 4,
        data: b"\x89PNG",
        mime: "image/png",
      }),
    ]
  })
  let svg = @svg.render_page(model, 0)
  assert_true(
    svg.contains(
      "  <g opacity=\"0.5\">\n  <image x=\"1\" y=\"2\" width=\"30\" height=\"4\" preserveAspectRatio=\"none\" href=\"data:image/png;base64,iVBORw==\"/>\n  </g>\n",
    ),
  )
}
