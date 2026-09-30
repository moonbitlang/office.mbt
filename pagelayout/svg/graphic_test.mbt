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
test "gradient stops at the ends: only the one nearer the middle is written" {
  let colours = [
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
