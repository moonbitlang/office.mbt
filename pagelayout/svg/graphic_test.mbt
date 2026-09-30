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
test "dashed hairlines restart at each subpath, from the phase" {
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
        [MoveTo(0, 10), LineTo(6, 10), MoveTo(0, 20), LineTo(6, 20)],
        hairline,
      ),
    ]
  })
  let svg = @svg.render_page(model, 0)
  assert_true(svg.contains("<path d=\"M0 4h4v-4h-4Z\" fill=\"#000000\"/>"))
  // around the square from its bottom-left corner, 16 long: on 0-1, 3-5,
  // 7-9, 11-13, 15-16, the dashes turning its corners; the last runs on
  // through the start into the first, joined there as the closed square
  // is, not capped
  assert_true(
    svg.contains(
      "<path d=\"M3 4L4 4L4 3M4 1L4 0L3 0M1 0L0 0L0 1M0 3L0 4L1 4\" fill=\"none\"",
    ),
  )
  assert_true(
    svg.contains("<path d=\"M0 10L1 10M3 10L5 10M0 20L1 20M3 20L5 20\""),
  )
}

///|
test "dashed hairlines follow curves" {
  // an arch: x = 6t, y = 20 + 18t(1 - t)
  let curve = @pagelayout.PathSegment::CurveTo(2, 26, 4, 26, 6, 20)
  let model = text_graphic(_ => {
    [
      stroked([MoveTo(0, 20), curve], {
        ..@pagelayout.StrokeStyle::default(),
        width: Hairline,
        dash: [2],
        dash_phase: 1,
      }),
    ]
  })
  let svg = @svg.render_page(model, 0)
  let start = svg.find("<path d=\"M0 20").unwrap() + "<path d=\"".length()
  let d = svg[start:]
  let (letters, numbers) = path_parts(d[:d.find("\"").unwrap()])
  // the arch's length along it up to parameter t, finely
  let at = fn(t : Double) -> (Double, Double) {
    (6.0 * t, 20.0 + 18.0 * t * (1.0 - t))
  }
  let length = fn(t : Double) {
    let mut sum = 0.0
    let steps = 100000
    for i in 0..<steps {
      let (x0, y0) = at(t * i.to_double() / steps.to_double())
      let (x1, y1) = at(t * (i + 1).to_double() / steps.to_double())
      sum += ((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)).sqrt()
    }
    sum
  }
  let total = length(1)
  // dashes on from 0 to 1, 3 to 5, 7 to 9, 11 to 13 (the arch is about
  // 13.2 long), each a part of the curve
  let dashes = ((total + 1) / 4).ceil().to_int()
  assert_eq(letters, "MC".repeat(dashes))
  for i in 0..<dashes {
    let n = numbers[i * 8:i * 8 + 8]
    // its ends are on the arch where the dash starts and ends along it
    let t0 = n[0] / 6
    let t1 = n[6] / 6
    let (_, y0) = at(t0)
    let (_, y1) = at(t1)
    assert_true((n[1] - y0).abs() < 1.0e-9 && (n[7] - y1).abs() < 1.0e-9)
    let from = if i == 0 { 0.0 } else { 4.0 * i.to_double() - 1 }
    let to = if 4.0 * i.to_double() + 1 > total {
      total
    } else {
      4.0 * i.to_double() + 1
    }
    assert_true((length(t0) - from).abs() < 0.01)
    assert_true((length(t1) - to).abs() < 0.01)
    // and it is the arch between them: its middle is the arch's
    let mx = (n[0] + 3 * n[2] + 3 * n[4] + n[6]) / 8
    let my = (n[1] + 3 * n[3] + 3 * n[5] + n[7]) / 8
    let (ax, ay) = at((t0 + t1) / 2)
    assert_true((mx - ax).abs() < 1.0e-9 && (my - ay).abs() < 1.0e-9)
  }
}

///|
test "a dotted hairline has its dots where PDF draws them" {
  let dotted = {
    ..@pagelayout.StrokeStyle::default(),
    width: Hairline,
    cap: RoundCap,
    dash: [0, 10],
  }
  let d = fn(segments : Array[@pagelayout.PathSegment]) {
    let svg = @svg.render_page(
      text_graphic(_ => [stroked(segments, dotted)]),
      0,
    )
    let start = svg.find("<path d=\"").unwrap() + "<path d=\"".length()
    let rest = svg[start:]
    rest[:rest.find("\"").unwrap()].to_owned()
  }
  // a dot where the line starts, as PDF's dash of length 0 at phase 0
  assert_eq(d([MoveTo(20, 20), LineTo(25, 20)]), "M20 20L20 20")
  // every ten points on, but none where the line ends
  assert_eq(
    d([MoveTo(20, 20), LineTo(60, 20)]),
    "M20 20L20 20M30 20L30 20M40 20L40 20M50 20L50 20",
  )
  // at a corner
  assert_eq(
    d([MoveTo(0, 0), LineTo(10, 0), LineTo(10, 10)]),
    "M0 0L0 0M10 0L10 0",
  )
  // round a square: at its corners, once at its start
  assert_eq(
    d([Rectangle(0, 0, 10, 10)]),
    "M0 10L0 10M10 10L10 10M10 0L10 0M0 0L0 0",
  )
  // a path all at one point is a dot
  assert_eq(d([MoveTo(5, 5), LineTo(5, 5)]), "M5 5L5 5")
}

///|
test "a dash round a closed subpath is closed, and one across its start joins there" {
  let dashed = fn(
    segments : Array[@pagelayout.PathSegment],
    dash : Array[Double],
    phase : Double,
  ) {
    let style = {
      ..@pagelayout.StrokeStyle::default(),
      width: Hairline,
      dash,
      dash_phase: phase,
    }
    let svg = @svg.render_page(text_graphic(_ => [stroked(segments, style)]), 0)
    let start = svg.find("<path d=\"").unwrap() + "<path d=\"".length()
    let rest = svg[start:]
    rest[:rest.find("\"").unwrap()].to_owned()
  }
  // one dash all round: the triangle closed, its start corner joined
  assert_eq(
    dashed(
      [MoveTo(20, 60), LineTo(60, 60), LineTo(40, 20), Close],
      [1000, 1],
      0,
    ),
    "M20 60L60 60L40 20Z",
  )
  // 120 round, dashed on 0-50 and 70-130: the second dash runs through the
  // start into the first, one subpath joined at the start corner
  let triangle : Array[@pagelayout.PathSegment] = [
    MoveTo(0, 0),
    LineTo(40, 0),
    LineTo(40, 30),
    Close,
  ]
  assert_eq(dashed(triangle, [60, 20], 10), "M40 30L0 0L40 0L40 10")
  // a subpath that only ends where it starts is not closed: its dashes
  // meet there, capped
  assert_eq(
    dashed(
      [MoveTo(0, 0), LineTo(40, 0), LineTo(40, 30), LineTo(0, 0)],
      [60, 20],
      10,
    ),
    "M0 0L40 0L40 10M40 30L0 0",
  )
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
      Path({
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

///|
/// The number in attribute `name` of the first element that has it.
fn attribute(svg : String, name : String) -> Double raise {
  let key = " \{name}=\""
  let start = svg.find(key).unwrap() + key.length()
  let rest = svg[start:]
  @string.parse_double(rest[:rest.find("\"").unwrap()])
}

///|
test "a gradient is written at its size, however small a part of it" {
  // a 30-point radial gradient ending on a circle 1e-7 points across: its
  // size counts both circles (see `PageModel::validate`), and it is
  // written as it is, not grown
  let model = text_graphic(_ => {
    [
      Path({
        segments: [Rectangle(0, 0, 100, 60)],
        fill: Some(
          GradientPaint({
            shape: Radial(x1=50, y1=30, r1=30, x2=50, y2=30, r2=1.0e-7),
            stops: [
              { offset: 0, color: @pagelayout.Color::rgb(255, 0, 0), },
              { offset: 1, color: @pagelayout.Color::rgb(0, 0, 255), },
            ],
            transform: @pagelayout.identity,
          }),
        ),
        fill_rule: NonZero,
        stroke: None,
        stroke_style: @pagelayout.StrokeStyle::default(),
      }),
    ]
  })
  assert_true(model.validate().is_empty())
  let svg = @svg.render_page(model, 0)
  assert_eq(attribute(svg, "fx"), 50)
  assert_eq(attribute(svg, "fr"), 30)
  assert_eq(attribute(svg, "cx"), 50)
  assert_eq(attribute(svg, "r"), 1.0e-7)
}
