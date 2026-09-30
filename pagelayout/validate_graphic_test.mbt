///|
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
fn graphic_page(
  ops : Array[@pagelayout.GraphicOp],
  x_pt? : Double = 0,
) -> @pagelayout.PageModel {
  let model = @pagelayout.PageModel::new()
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [], }
  page.items.push(Graphic({ x_pt, y_pt: 0, ops, }))
  model.pages.push(page)
  model
}

///|
test "validate requires a current point before lines, curves and closes" {
  let style = @pagelayout.StrokeStyle::default()
  let model = graphic_page([
    stroked([LineTo(1, 1)], style),
    stroked([CurveTo(0, 0, 1, 1, 2, 2)], style),
    stroked([Close], style),
    Clip([LineTo(1, 1), MoveTo(0, 0)], NonZero),
    // fine: a rectangle and a close both leave a current point, and an
    // empty path needs none
    stroked([Rectangle(0, 0, 1, 1), LineTo(5, 5), Close, LineTo(3, 3)], style),
    Clip([MoveTo(0, 0), LineTo(1, 1), Close], EvenOdd),
    stroked([], style),
  ])
  debug_inspect(
    model.validate(),
    content=(
      #|[
      #|  "page 0 item 0 op 0: segment 0 (LineTo) without a current point",
      #|  "page 0 item 0 op 1: segment 0 (CurveTo) without a current point",
      #|  "page 0 item 0 op 2: segment 0 (Close) without a current point",
      #|  "page 0 item 0 op 3: segment 0 (LineTo) without a current point",
      #|]
    ),
  )
}

///|
test "validate rejects non-finite numbers, bad dashes and bad alphas" {
  let nan = 0.0 / 0.0
  let inf = 1.0 / 0.0
  let style = @pagelayout.StrokeStyle::default()
  let line = [@pagelayout.PathSegment::MoveTo(0, 0), LineTo(1, 1)]
  let model = graphic_page(x_pt=inf, [
    Alpha(nan, 1),
    Alpha(1, inf),
    Alpha(-0.5, 1),
    Transform({ ..@pagelayout.identity, e: nan, }),
    stroked([MoveTo(nan, 0), LineTo(1, 1)], style),
    Clip([Rectangle(0, 0, inf, 1)], NonZero),
    stroked(line, { ..style, dash: [0, 0], }),
    stroked(line, { ..style, dash: [1, nan], }),
    stroked(line, { ..style, dash: [1, -1], }),
    stroked(line, { ..style, dash_phase: inf, }),
    stroked(line, { ..style, width: Width(nan), }),
    stroked(line, { ..style, width: Width(inf), }),
    stroked(line, { ..style, miter_limit: 0.5, }),
    stroked(line, { ..style, miter_limit: nan, }),
    Image({
      x_pt: nan,
      y_pt: 0,
      w_pt: 1,
      h_pt: 1,
      data: b"\x89PNG",
      mime: "image/png",
    }),
    // fine: a solid line and a dash with one positive length
    stroked(line, { ..style, dash: [], }),
    stroked(line, { ..style, dash: [0, 2], }),
  ])
  debug_inspect(
    model.validate(),
    content=(
      #|[
      #|  "page 0 item 0: non-finite graphic origin",
      #|  "page 0 item 0 op 0: alpha outside 0..=1",
      #|  "page 0 item 0 op 1: alpha outside 0..=1",
      #|  "page 0 item 0 op 2: alpha outside 0..=1",
      #|  "page 0 item 0 op 3: non-finite transformation",
      #|  "page 0 item 0 op 4: non-finite path coordinate",
      #|  "page 0 item 0 op 5: non-finite path coordinate",
      #|  "page 0 item 0 op 6: dash without a positive length",
      #|  "page 0 item 0 op 7: dash length negative or non-finite",
      #|  "page 0 item 0 op 8: dash length negative or non-finite",
      #|  "page 0 item 0 op 9: non-finite dash phase",
      #|  "page 0 item 0 op 10: stroke width not positive and finite",
      #|  "page 0 item 0 op 11: stroke width not positive and finite",
      #|  "page 0 item 0 op 12: miter limit not a finite number from 1",
      #|  "page 0 item 0 op 13: miter limit not a finite number from 1",
      #|  "page 0 item 0 op 14: non-finite image rectangle",
      #|]
    ),
  )
}

///|
test "validate rejects non-finite text positions in graphics" {
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({ family: "Sans", bold: false, italic: false, })
  let run = @pagelayout.GlyphRun::{
    font,
    size_pt: 10,
    x_pt: 0,
    baseline_pt: 10,
    text: "AB",
    advances_pt: [6, 6],
    color: @pagelayout.black,
  }
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [], }
  page.items.push(
    Graphic({
      x_pt: 0,
      y_pt: 0,
      ops: [
        Text({ ..run, x_pt: 0.0 / 0.0, }),
        Text({ ..run, advances_pt: [6, 1.0 / 0.0], }),
        Text({ ..run, size_pt: 1.0 / 0.0, }),
        Text(run),
      ],
    }),
  )
  model.pages.push(page)
  debug_inspect(
    model.validate(),
    content=(
      #|[
      #|  "page 0 item 0 op 0: non-finite glyph run position or advance",
      #|  "page 0 item 0 op 1: non-finite glyph run position or advance",
      #|  "page 0 item 0 op 2: non-finite font size",
      #|]
    ),
  )
}

///|
test "validate rejects non-finite gradients and stops outside 0..=1" {
  let stops : Array[@pagelayout.GradientStop] = [
    { offset: 0, color: @pagelayout.black, },
    { offset: 1, color: @pagelayout.Color::rgb(255, 255, 255), },
  ]
  let gradient = @pagelayout.Gradient::{
    shape: Linear(x1=0, y1=0, x2=10, y2=0),
    stops,
    transform: @pagelayout.identity,
  }
  let filled = fn(g : @pagelayout.Gradient) -> @pagelayout.GraphicOp {
    Path({
      segments: [Rectangle(0, 0, 1, 1)],
      fill: Some(GradientPaint(g)),
      fill_rule: NonZero,
      stroke: None,
      stroke_style: @pagelayout.StrokeStyle::default(),
    })
  }
  let nan = 0.0 / 0.0
  let model = graphic_page([
    filled({ ..gradient, shape: Linear(x1=0, y1=0, x2=nan, y2=0), }),
    filled({ ..gradient, shape: Radial(x1=0, y1=0, r1=0, x2=0, y2=0, r2=nan), }),
    filled({ ..gradient, shape: Radial(x1=0, y1=0, r1=-1, x2=0, y2=0, r2=1), }),
    filled({ ..gradient, transform: { ..@pagelayout.identity, a: nan, }, }),
    filled({
      ..gradient,
      stops: [stops[0], { offset: nan, color: @pagelayout.black, }, stops[1]],
    }),
    filled({
      ..gradient,
      stops: [
        stops[0],
        { offset: 0.75, color: @pagelayout.black, },
        { offset: 0.5, color: @pagelayout.black, },
        stops[1],
      ],
    }),
    filled({ ..gradient, stops: [stops[0]], }),
    filled({ ..gradient, stops: [{ ..stops[0], offset: 0.25, }, stops[1]], }),
    // fine: coinciding stops
    filled({ ..gradient, stops: [stops[0], stops[0], stops[1], stops[1]], }),
  ])
  debug_inspect(
    model.validate(),
    content=(
      #|[
      #|  "page 0 item 0 op 0: non-finite gradient geometry",
      #|  "page 0 item 0 op 1: non-finite gradient geometry",
      #|  "page 0 item 0 op 2: negative gradient radius",
      #|  "page 0 item 0 op 3: non-finite gradient geometry",
      #|  "page 0 item 0 op 4: gradient stop offset outside 0..=1",
      #|  "page 0 item 0 op 5: gradient stops out of order",
      #|  "page 0 item 0 op 6: gradient with fewer than two stops",
      #|  "page 0 item 0 op 7: gradient stops do not span 0 to 1",
      #|]
    ),
  )
}

///|
test "validate rejects zero-width strokes, of paths and of text" {
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
  let style = @pagelayout.StrokeStyle::default()
  let zero = { ..style, width: Width(0), }
  let line = [@pagelayout.PathSegment::MoveTo(0, 0), LineTo(1, 1)]
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [], }
  page.items.push(
    Graphic({
      x_pt: 0,
      y_pt: 0,
      ops: [
        stroked(line, zero),
        stroked(line, { ..style, width: Width(-1), }),
        PaintedText(run, {
          fill: false,
          stroke: Some(@pagelayout.black),
          stroke_style: zero,
        }),
        // fine: a hairline, and a width that no stroke uses
        stroked(line, { ..style, width: Hairline, }),
        PaintedText(run, { fill: true, stroke: None, stroke_style: zero, }),
        Path({
          segments: line,
          fill: Some(Solid(@pagelayout.black)),
          fill_rule: NonZero,
          stroke: None,
          stroke_style: zero,
        }),
      ],
    }),
  )
  model.pages.push(page)
  debug_inspect(
    model.validate(),
    content=(
      #|[
      #|  "page 0 item 0 op 0: stroke width not positive and finite",
      #|  "page 0 item 0 op 1: stroke width not positive and finite",
      #|  "page 0 item 0 op 2: stroke width not positive and finite",
      #|]
    ),
  )
}
