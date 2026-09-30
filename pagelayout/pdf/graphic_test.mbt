///|
fn graphic_model(ops : Array[@pagelayout.GraphicOp]) -> @pagelayout.PageModel {
  let model = @pagelayout.PageModel::new()
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [], }
  page.items.push(Graphic({ x_pt: 10, y_pt: 20, ops, }))
  model.pages.push(page)
  model
}

///|
fn red_path(segments : Array[@pagelayout.PathSegment]) -> @pagelayout.GraphicOp {
  Path({
    segments,
    fill: Some(Solid(@pagelayout.Color::rgb(255, 0, 0))),
    fill_rule: NonZero,
    stroke: None,
    stroke_style: @pagelayout.StrokeStyle::default(),
  })
}

///|
test "a graphic's space is flipped onto the page at its origin" {
  let model = graphic_model([
    red_path([MoveTo(0, 0), LineTo(10, 0), CurveTo(10, 5, 5, 10, 0, 10), Close]),
  ])
  let text = try! as_decoded_text(@pdf.render_pdf(model))
  // y down from (10, 20) on a page 100 tall: y' = 80 - y
  assert_true(text.contains("1 0 0 -1 10 80 cm"))
  assert_true(text.contains("1 0 0 rg"))
  assert_true(text.contains("0 0 m"))
  assert_true(text.contains("10 0 l"))
  assert_true(text.contains("10 5 5 10 0 10 c"))
  assert_true(text.contains("h f"))
}

///|
test "strokes, rules, clips, transforms and alpha reach the content stream" {
  let style = @pagelayout.StrokeStyle::{
    ..@pagelayout.StrokeStyle::default(),
    width: 2,
    cap: RoundCap,
    join: BevelJoin,
    dash: [3, 1],
  }
  let model = graphic_model([
    Save,
    Transform({ a: 2, b: 0, c: 0, d: 2, e: 5, f: 5, }),
    Clip([Rectangle(0, 0, 50, 20)], NonZero),
    Alpha(0.5, 0.25),
    Path({
      segments: [Rectangle(1, 2, 3, 4)],
      fill: Some(Solid(@pagelayout.Color::rgb(0, 0, 255))),
      fill_rule: EvenOdd,
      stroke: Some(Solid(@pagelayout.Color::rgb(0, 255, 0))),
      stroke_style: style,
    }),
    Restore,
  ])
  assert_true(model.validate().is_empty())
  let bytes = @pdf.render_pdf(model)
  let text = try! as_decoded_text(bytes)
  assert_true(text.contains("2 0 0 2 5 5 cm"))
  // a rectangle is drawn from its bottom edge up, as `re` in a y-up page
  assert_true(text.contains("0 20 50 -20 re W n"))
  assert_true(text.contains("gs"))
  assert_true(text.contains("0 1 0 RG"))
  assert_true(text.contains("2 w"))
  assert_true(text.contains("1 J"))
  assert_true(text.contains("2 j"))
  assert_true(text.contains("[3 1] 0 d"))
  assert_true(text.contains("1 6 3 -4 re B*"))
  let file = as_text(bytes)
  assert_true(file.contains("/ExtGState"))
  assert_true(file.contains("/ca 0.5"))
  assert_true(file.contains("/CA 0.25"))
}

///|
test "a gradient is a shading pattern placed by the current transformation" {
  let gradient = @pagelayout.Gradient::{
    radial: false,
    x1: 0,
    y1: 0,
    r1: 0,
    x2: 10,
    y2: 0,
    r2: 0,
    stops: [
      { offset: 0, color: @pagelayout.Color::rgb(255, 255, 255), },
      { offset: 0.5, color: @pagelayout.Color::rgb(255, 0, 0), },
      { offset: 1, color: @pagelayout.Color::rgb(0, 0, 0), },
    ],
    transform: { a: 1, b: 0, c: 0, d: 1, e: 3, f: 0, },
  }
  let model = graphic_model([
    Path({
      segments: [Rectangle(0, 0, 10, 10)],
      fill: Some(GradientPaint(gradient)),
      fill_rule: NonZero,
      stroke: None,
      stroke_style: @pagelayout.StrokeStyle::default(),
    }),
  ])
  assert_true(model.validate().is_empty())
  let bytes = @pdf.render_pdf(model)
  let text = try! as_decoded_text(bytes)
  assert_true(text.contains("/Pattern cs"))
  assert_true(text.contains("scn"))
  let file = as_text(bytes)
  assert_true(file.contains("/ShadingType 2"))
  assert_true(file.contains("/FunctionType 3"))
  assert_true(file.contains("/Bounds [0.5]"))
  // the pattern matrix: the graphic's flip, then the gradient's shift
  assert_true(file.contains("/Matrix [1 0 0 -1 13 80]"))
}

///|
test "text in a graphic is drawn upright and its font embedded" {
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({
    family: "Liberation Sans",
    bold: false,
    italic: false,
  })
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [], }
  page.items.push(
    Graphic({
      x_pt: 10,
      y_pt: 20,
      ops: [
        Text({
          font,
          size_pt: 12,
          x_pt: 1,
          baseline_pt: 15,
          text: "Hi",
          advances_pt: [8.664, 2.664],
          color: @pagelayout.black,
        }),
      ],
    }),
  )
  model.pages.push(page)
  assert_true(model.validate().is_empty())
  let bytes = @pdf.render_pdf(model)
  let text = try! as_decoded_text(bytes)
  assert_true(text.contains("1 0 0 -1 0 0 cm"))
  // the baseline at y = 15 of the graphic is at -15 once flipped back
  assert_true(text.contains("1 0 0 1 1 -15 Tm"))
  assert_true(text.contains("(Hi)"))
  assert_true(as_text(bytes).contains("/FontFile2"))
}

///|
test "painted text sets the stroke and the text rendering mode" {
  let model = @pagelayout.PageModel::new()
  let font = model.add_font({
    family: "Liberation Sans",
    bold: false,
    italic: false,
  })
  let run = @pagelayout.GlyphRun::{
    font,
    size_pt: 12,
    x_pt: 1,
    baseline_pt: 15,
    text: "Hi",
    advances_pt: [8.664, 2.664],
    color: @pagelayout.black,
  }
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [], }
  page.items.push(
    Graphic({
      x_pt: 0,
      y_pt: 0,
      ops: [
        PaintedText(run, {
          fill: true,
          stroke: Some(@pagelayout.Color::rgb(255, 0, 0)),
          stroke_width: 0.5,
        }),
        PaintedText(run, { fill: false, stroke: None, stroke_width: 0, }),
      ],
    }),
  )
  model.pages.push(page)
  assert_true(model.validate().is_empty())
  let text = try! as_decoded_text(@pdf.render_pdf(model))
  assert_true(text.contains("1 0 0 RG 0.5 w 2 Tr"))
  assert_true(text.contains("3 Tr"))
}

///|
test "validate reports unbalanced saves and bad alphas in graphics" {
  let model = graphic_model([Save, Alpha(2, 0), Restore, Restore, Save])
  debug_inspect(
    model.validate(),
    content=(
      #|[
      #|  "page 0 item 0 op 1: alpha outside 0..=1",
      #|  "page 0 item 0 op 3: restore without a save",
      #|  "page 0 item 0: 1 saves without a restore",
      #|]
    ),
  )
}
