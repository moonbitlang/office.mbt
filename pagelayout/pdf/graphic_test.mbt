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
    width: Width(2),
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
    shape: Linear(x1=0, y1=0, x2=10, y2=0),
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
  // the shading runs along the unit x axis; the pattern matrix: the
  // graphic's flip, then the gradient's shift, then the gradient's line
  assert_true(file.contains("/Coords [0 0 1 0]"))
  assert_true(file.contains("/Matrix [10 0 0 -10 13 80]"))
}

///|
/// A page with a 10 by 10 square filled with a horizontal gradient
/// through `colours` at `offsets`.
fn gradient_square(
  offsets : Array[Double],
  colours : Array[@pagelayout.Color],
) -> @pagelayout.PageModel {
  let stops = offsets.mapi((i, offset) => @pagelayout.GradientStop::{
    offset,
    color: colours[i],
  })
  graphic_model([
    Path({
      segments: [Rectangle(0, 0, 10, 10)],
      fill: Some(
        GradientPaint({
          shape: Linear(x1=0, y1=0, x2=10, y2=0),
          stops,
          transform: @pagelayout.identity,
        }),
      ),
      fill_rule: NonZero,
      stroke: None,
      stroke_style: @pagelayout.StrokeStyle::default(),
    }),
  ])
}

///|
let white : @pagelayout.Color = @pagelayout.Color::rgb(255, 255, 255)

///|
let red : @pagelayout.Color = @pagelayout.Color::rgb(255, 0, 0)

///|
let blue : @pagelayout.Color = @pagelayout.Color::rgb(0, 0, 255)

///|
test "repeated gradient stops make strictly increasing stitching bounds" {
  let model = gradient_square([0, 0.5, 0.5, 1], [
    white, red, blue, @pagelayout.black,
  ])
  assert_true(model.validate().is_empty())
  let file = as_text(@pdf.render_pdf(model))
  assert_false(file.contains("/Bounds [0.5 0.5]"))
  // two interpolations, white to red below 0.5 and blue to black from it:
  // the colour jumps at 0.5
  assert_true(file.contains("/Bounds [0.5]"))
  assert_eq(occurrences(file, "/FunctionType 2"), 2)
  assert_true(file.contains("/C0 [1 1 1] /C1 [1 0 0]"))
  assert_true(file.contains("/C0 [0 0 1] /C1 [0 0 0]"))
}

///|
test "at a gradient's ends only the stop nearer the middle counts" {
  let model = gradient_square([0, 0, 0.25, 1, 1], [white, red, blue, red, white])
  assert_true(model.validate().is_empty())
  let file = as_text(@pdf.render_pdf(model))
  assert_true(file.contains("/Bounds [0.25]"))
  assert_eq(occurrences(file, "/FunctionType 2"), 2)
  assert_true(file.contains("/C0 [1 0 0] /C1 [0 0 1]"))
  assert_true(file.contains("/C0 [0 0 1] /C1 [1 0 0]"))
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
fn hi_run(model : @pagelayout.PageModel) -> @pagelayout.GlyphRun {
  let font = model.add_font({
    family: "Liberation Sans",
    bold: false,
    italic: false,
  })
  {
    font,
    size_pt: 12,
    x_pt: 1,
    baseline_pt: 15,
    text: "Hi",
    advances_pt: [8.664, 2.664],
    color: @pagelayout.black,
  }
}

///|
fn one_graphic(
  model : @pagelayout.PageModel,
  ops : Array[@pagelayout.GraphicOp],
) -> @pagelayout.PageModel {
  let page = @pagelayout.Page::{ width_pt: 200, height_pt: 100, items: [], }
  page.items.push(Graphic({ x_pt: 0, y_pt: 0, ops, }))
  model.pages.push(page)
  model
}

///|
/// How often `needle` occurs in `haystack`.
fn occurrences(haystack : String, needle : String) -> Int {
  let mut n = 0
  let mut rest = haystack[:]
  while rest.find(needle) is Some(i) {
    n += 1
    rest = rest[i + needle.length():]
  }
  n
}

///|
test "painted text sets the stroke and the text rendering mode" {
  let model = @pagelayout.PageModel::new()
  let run = hi_run(model)
  let style = @pagelayout.StrokeStyle::default()
  let model = one_graphic(model, [
    PaintedText(run, {
      fill: true,
      stroke: Some(@pagelayout.Color::rgb(255, 0, 0)),
      stroke_style: { ..style, width: Width(0.5), },
    }),
    PaintedText(run, { fill: false, stroke: None, stroke_style: style, }),
  ])
  assert_true(model.validate().is_empty())
  let text = try! as_decoded_text(@pdf.render_pdf(model))
  assert_true(text.contains("1 0 0 RG 0.5 w 0 J 0 j 10 M [] 0 d 2 Tr"))
  assert_true(text.contains("3 Tr"))
}

///|
test "outlined text does not inherit the previous path's stroke style" {
  let model = @pagelayout.PageModel::new()
  let run = hi_run(model)
  let model = one_graphic(model, [
    Path({
      segments: [MoveTo(0, 0), LineTo(10, 0)],
      fill: None,
      fill_rule: NonZero,
      stroke: Some(Solid(@pagelayout.black)),
      stroke_style: {
        width: Width(0.5),
        cap: RoundCap,
        join: BevelJoin,
        miter_limit: 3,
        dash: [1, 4],
        dash_phase: 0,
      },
    }),
    PaintedText(run, {
      fill: false,
      stroke: Some(@pagelayout.black),
      stroke_style: @pagelayout.StrokeStyle::default(),
    }),
  ])
  assert_true(model.validate().is_empty())
  let text = try! as_decoded_text(@pdf.render_pdf(model))
  // the outline is solid, one point wide, butt-capped and miter-joined
  // (limit 10), whatever the path before it used
  let start = text.find("1 0 0 -1 0 0 cm").unwrap()
  assert_true(text[start:].contains("0 0 0 RG 1 w 0 J 0 j 10 M [] 0 d 1 Tr"))
}

///|
test "a hairline is PDF's line width 0, for paths and text outlines" {
  let model = @pagelayout.PageModel::new()
  let run = hi_run(model)
  let hairline = { ..@pagelayout.StrokeStyle::default(), width: Hairline, }
  let model = one_graphic(model, [
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
  ])
  assert_true(model.validate().is_empty())
  let text = try! as_decoded_text(@pdf.render_pdf(model))
  assert_eq(occurrences(text, "0 w"), 2)
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

///|
fn gradient_fill(gradient : @pagelayout.Gradient) -> @pagelayout.GraphicOp {
  Path({
    segments: [Rectangle(0, 0, 10, 10)],
    fill: Some(GradientPaint(gradient)),
    fill_rule: NonZero,
    stroke: None,
    stroke_style: @pagelayout.StrokeStyle::default(),
  })
}

///|
let two_stops : Array[@pagelayout.GradientStop] = [
  { offset: 0, color: white, },
  { offset: 1, color: @pagelayout.black, },
]

///|
let linear : @pagelayout.Gradient = {
  shape: Linear(x1=0, y1=0, x2=10, y2=0),
  stops: two_stops,
  transform: @pagelayout.identity,
}

///|
test "identical gradient fills share one pattern and one shading" {
  let fill = gradient_fill(linear)
  let bytes = @pdf.render_pdf(graphic_model([fill, fill, fill]))
  let file = as_text(bytes)
  assert_eq(occurrences(file, "/PatternType 2"), 1)
  assert_eq(occurrences(file, "/ShadingType 2"), 1)
  // and the pattern is set once, the paint staying in effect
  let text = try! as_decoded_text(bytes)
  assert_eq(occurrences(text, "/Pattern cs"), 1)
  assert_eq(occurrences(text, " f"), 3)
}

///|
test "a gradient under another transformation shares the shading only" {
  let fill = gradient_fill(linear)
  let file = as_text(
    @pdf.render_pdf(
      graphic_model([
        fill,
        Save,
        Transform({ ..@pagelayout.identity, a: 2, }),
        fill,
        Restore,
        fill,
      ]),
    ),
  )
  assert_eq(occurrences(file, "/PatternType 2"), 2)
  assert_eq(occurrences(file, "/ShadingType 2"), 1)
  assert_true(file.contains("/Matrix [10 0 0 -10 10 80]"))
  assert_true(file.contains("/Matrix [20 0 0 -10 10 80]"))
}

///|
test "alpha states and patterns are shared across pages" {
  let model = graphic_model([Alpha(0.5, 0.5), gradient_fill(linear)])
  model.pages.push(model.pages[0])
  let file = as_text(@pdf.render_pdf(model))
  assert_eq(occurrences(file, "/Type /ExtGState"), 1)
  assert_eq(occurrences(file, "/PatternType 2"), 1)
  // each page's resources name them
  assert_eq(occurrences(file, "/ExtGState <<"), 2)
  assert_eq(occurrences(file, "/Pattern <<"), 2)
}

///|
test "a radial gradient is a radial shading from its first circle" {
  let model = graphic_model([
    gradient_fill({
      ..linear,
      shape: Radial(x1=1, y1=2, r1=0.5, x2=3, y2=4, r2=5),
    }),
  ])
  assert_true(model.validate().is_empty())
  let file = as_text(@pdf.render_pdf(model))
  assert_true(file.contains("/ShadingType 3"))
  // from the first circle to the unit one, which the pattern matrix scales
  // and moves to the second: centre (3, 4), radius 5
  assert_true(file.contains("/Coords [-0.4 -0.4 0.1 0 0 1]"))
  assert_true(file.contains("/Matrix [5 0 0 -5 13 76]"))
  assert_true(file.contains("/Extend [true true]"))
}

///|
let pixel : Bytes = b"\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90\x77\x53\xde\x00\x00\x00\x0c\x49\x44\x41\x54\x08\xd7\x63\xf8\xcf\xc0\x00\x00\x03\x01\x01\x00\x18\xdd\x8d\xb0\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82"

///|
test "an image in a graphic is drawn upright and shares its XObject" {
  let image = @pagelayout.ImageItem::{
    x_pt: 2,
    y_pt: 3,
    w_pt: 4,
    h_pt: 5,
    data: pixel,
    mime: "image/png",
  }
  let model = graphic_model([
    Save,
    Transform({ ..@pagelayout.identity, a: 2, }),
    Image(image),
    Restore,
  ])
  model.pages[0].items.push(Image(image))
  assert_true(model.validate().is_empty())
  let bytes = @pdf.render_pdf(model)
  let text = try! as_decoded_text(bytes)
  // flipped back upright, then the image's own rectangle, y up from its
  // bottom edge at y = 3 + 5
  assert_true(
    text.contains("2 0 0 1 0 0 cm q 1 0 0 -1 0 0 cm q 4 0 0 5 2 -8 cm"),
  )
  assert_eq(occurrences(text, " Do"), 2)
  assert_eq(occurrences(as_text(bytes), "/Subtype /Image"), 1)
  assert_true(@pdf.unembeddable_images(model).is_empty())
}

///|
test "a gradient without extent paints its last stop's colour" {
  let stops : Array[@pagelayout.GradientStop] = [
    { offset: 0, color: white, },
    { offset: 0.5, color: red, },
    { offset: 1, color: blue, },
  ]
  let shapes : Array[@pagelayout.GradientShape] = [
    Linear(x1=5, y1=5, x2=5, y2=5),
    Radial(x1=1, y1=1, r1=2, x2=5, y2=5, r2=0),
    Radial(x1=5, y1=5, r1=3, x2=5, y2=5, r2=3),
  ]
  for shape in shapes {
    let gradient = @pagelayout.Gradient::{
      shape,
      stops,
      transform: @pagelayout.identity,
    }
    let model = graphic_model([
      Path({
        segments: [Rectangle(0, 0, 10, 10)],
        fill: Some(GradientPaint(gradient)),
        fill_rule: NonZero,
        stroke: Some(GradientPaint(gradient)),
        stroke_style: @pagelayout.StrokeStyle::default(),
      }),
    ])
    assert_true(model.validate().is_empty())
    let bytes = @pdf.render_pdf(model)
    assert_false(as_text(bytes).contains("/Shading"))
    let text = try! as_decoded_text(bytes)
    assert_true(text.contains("0 0 1 rg 0 0 1 RG"))
    assert_false(text.contains("/Pattern"))
  }
}

///|
test "a dashed hairline is dashed in the graphic's space" {
  // PDF measures dashes in user space whatever the line width: ten units
  // scaled by ten, one on and one off, are five dashes ten points long,
  // which SVG draws dash by dash
  let model = graphic_model([
    Transform({ a: 10, b: 0, c: 0, d: 10, e: 0, f: 0, }),
    Path({
      segments: [MoveTo(0, 0), LineTo(10, 0)],
      fill: None,
      fill_rule: NonZero,
      stroke: Some(Solid(@pagelayout.black)),
      stroke_style: {
        ..@pagelayout.StrokeStyle::default(),
        width: Hairline,
        dash: [1, 1],
      },
    }),
  ])
  assert_true(model.validate().is_empty())
  let text = try! as_decoded_text(@pdf.render_pdf(model))
  assert_true(
    text.contains(
      "10 0 0 10 0 0 cm 0 0 0 RG 0 w 0 J 0 j 10 M [1 1] 0 d 0 0 m 10 0 l S",
    ),
  )
}

///|
/// The numbers of every array after `key` (`/Bounds`, say) in `file`, one
/// array each.
fn number_arrays(file : String, key : String) -> Array[Array[Double]] raise {
  let arrays = []
  let mut rest = file[:]
  let key = key + " ["
  while rest.find(key) is Some(i) {
    rest = rest[i + key.length():]
    let end = rest.find("]").unwrap()
    let numbers = []
    for word in rest[:end].split(" ") {
      if !word.is_empty() {
        numbers.push(@string.parse_double(word))
      }
    }
    arrays.push(numbers)
    rest = rest[end:]
  }
  arrays
}

///|
test "stitching bounds are written exactly, however close the stops" {
  // offsets apart by less than a rounded real resolves: each interval
  // keeps its own bound, distinct and increasing as written
  let near_half = gradient_square([0, 0.5, 0.50000000000001, 1], [
    white, red, blue, @pagelayout.black,
  ])
  assert_true(near_half.validate().is_empty())
  let file = as_text(@pdf.render_pdf(near_half))
  assert_true(file.contains("/Bounds [0.5 0.50000000000001]"))
  assert_eq(occurrences(file, "/FunctionType 2"), 3)
  assert_true(file.contains("/C0 [1 1 1] /C1 [1 0 0]"))
  assert_true(file.contains("/C0 [1 0 0] /C1 [0 0 1]"))
  assert_true(file.contains("/C0 [0 0 1] /C1 [0 0 0]"))
  // near 0 and near 1 alike
  let near_zero = gradient_square([0, 1.0e-8, 2.0e-8, 1], [
    white, red, blue, @pagelayout.black,
  ])
  let file = as_text(@pdf.render_pdf(near_zero))
  assert_true(file.contains("/Bounds [0.00000001 0.00000002]"))
  assert_eq(occurrences(file, "/FunctionType 2"), 3)
  let near_one = gradient_square([0, 0.25, 1 - 1.0e-14, 1], [
    white, red, blue, @pagelayout.black,
  ])
  let file = as_text(@pdf.render_pdf(near_one))
  assert_true(file.contains("/Bounds [0.25 0.99999999999999]"))
  assert_eq(occurrences(file, "/FunctionType 2"), 3)
}

///|
test "a gradient keeps colour regions of any width its stops give" {
  // 1e9 points long, stops at 1e-8 and 2e-8: ten points of red, then ten
  // of red turning black. Rounded, the bounds were both 0.000000 and the
  // red interval was dropped, the gradient black throughout.
  let model = graphic_model([
    Path({
      segments: [Rectangle(0, 0, 100, 60)],
      fill: Some(
        GradientPaint({
          shape: Linear(x1=0, y1=0, x2=1.0e9, y2=0),
          stops: [
            { offset: 0, color: red, },
            { offset: 1.0e-8, color: red, },
            { offset: 2.0e-8, color: @pagelayout.black, },
            { offset: 1, color: @pagelayout.black, },
          ],
          transform: @pagelayout.identity,
        }),
      ),
      fill_rule: NonZero,
      stroke: None,
      stroke_style: @pagelayout.StrokeStyle::default(),
    }),
  ])
  assert_true(model.validate().is_empty())
  let file = as_text(@pdf.render_pdf(model))
  assert_true(file.contains("/Bounds [0.00000001 0.00000002]"))
  assert_true(
    file.contains(
      "/Functions [<< /FunctionType 2 /Domain [0 1] /C0 [1 0 0] /C1 [1 0 0] /N 1 >> << /FunctionType 2 /Domain [0 1] /C0 [1 0 0] /C1 [0 0 0] /N 1 >> << /FunctionType 2 /Domain [0 1] /C0 [0 0 0] /C1 [0 0 0] /N 1 >>]",
    ),
  )
  // the whole 1e9 points in the pattern matrix: red from x = 10 to 20 on
  // the page, turning black by 30
  assert_true(file.contains("/Matrix [1000000000 0 0 -1000000000 10 80]"))
}

///|
test "graphic numbers are written exactly in the content stream" {
  // a hundred by sixty points on the page, as SVG draws it
  let model = graphic_model([
    Transform({ a: 1.0e-7, b: 0, c: 0, d: 1.0e-7, e: 0, f: 0, }),
    red_path([Rectangle(0, 0, 1.0e9, 6.0e8)]),
    red_path([
      MoveTo(0.123456789012345, 1.0e-9),
      LineTo(2.5e-5, 1.0e21),
      LineTo(-1.5e-7, -1.25e22),
    ]),
  ])
  assert_true(model.validate().is_empty())
  let text = try! as_decoded_text(@pdf.render_pdf(model))
  assert_true(text.contains("0.0000001 0 0 0.0000001 0 0 cm"))
  assert_true(text.contains("0 600000000 1000000000 -600000000 re"))
  assert_true(text.contains("0.123456789012345 0.000000001 m"))
  // integral values beyond what a PDF integer surely holds (2147483647,
  // PDF 32000-1, Annex C) with a decimal point, as reals
  assert_true(text.contains("0.000025 1000000000000000000000.0 l"))
  assert_true(text.contains("-0.00000015 -12500000000000000000000.0 l"))
}

///|
test "a gradient's pattern matrix survives a small transformation" {
  let model = graphic_model([
    Transform({ a: 1.0e-7, b: 0, c: 0, d: 1.0e-7, e: 0, f: 0, }),
    Path({
      segments: [Rectangle(0, 0, 1.0e9, 6.0e8)],
      fill: Some(
        GradientPaint({
          shape: Linear(x1=0, y1=0, x2=1.0e9, y2=0),
          stops: two_stops,
          transform: @pagelayout.identity,
        }),
      ),
      fill_rule: NonZero,
      stroke: None,
      stroke_style: @pagelayout.StrokeStyle::default(),
    }),
  ])
  assert_true(model.validate().is_empty())
  let bytes = @pdf.render_pdf(model)
  let file = as_text(bytes)
  // the shading runs along the unit x axis, which the pattern matrix maps
  // onto the gradient's hundred points on the page
  assert_true(file.contains("/Coords [0 0 1 0]"))
  assert_true(file.contains("/Matrix [100 0 0 -100 10 80]"))
  // and the path is painted where the transformation is scaled up by
  // 2^24 (Poppler refuses patterns under a determinant below 1e-6), its
  // numbers scaled down as much
  let text = try! as_decoded_text(bytes)
  assert_true(
    text.contains(
      "q 16777216 0 0 16777216 0 0 cm /Pattern cs /P2 scn 0 35.762786865234375 59.604644775390625 -35.762786865234375 re f Q",
    ),
  )
}

///|
/// A 100 by 60 rectangle filled with `gradient`, red to blue.
fn gradient_rectangle(
  shape : @pagelayout.GradientShape,
  transform? : @pagelayout.Matrix = @pagelayout.identity,
) -> @pagelayout.PageModel {
  graphic_model([
    Path({
      segments: [Rectangle(0, 0, 100, 60)],
      fill: Some(
        GradientPaint({
          shape,
          stops: [{ offset: 0, color: red, }, { offset: 1, color: blue, }],
          transform,
        }),
      ),
      fill_rule: NonZero,
      stroke: None,
      stroke_style: @pagelayout.StrokeStyle::default(),
    }),
  ])
}

///|
/// Whether `a` is within `tolerance` of `b`, relative to `b` (or absolute
/// when `b` is 0).
fn near(a : Double, b : Double, tolerance : Double) -> Bool {
  (a - b).abs() <= tolerance * (if b == 0.0 { 1.0 } else { b.abs() })
}

///|
test "pattern matrices are written exactly" {
  // a hundredth of a point long, turned by a millionth of a radian: the
  // turn is in coefficients that a rounded real would write as 0
  let model = gradient_rectangle(Linear(x1=0, y1=0, x2=0.01, y2=1.0e-8))
  assert_true(model.validate().is_empty())
  let file = as_text(@pdf.render_pdf(model))
  assert_true(file.contains("/Coords [0 0 1 0]"))
  assert_true(
    file.contains("/Matrix [0.01 -0.00000001 -0.00000001 -0.01 10 80]"),
  )
}

///|
test "a gradient too small to draw is drawn a thousandth of a point long" {
  // a ten-millionth of a point long: Poppler's Cairo renderer paints
  // nothing for it, and rounded reals made its matrix singular
  let model = gradient_rectangle(Linear(x1=0, y1=0, x2=1.0e-7, y2=0))
  assert_true(model.validate().is_empty())
  let file = as_text(@pdf.render_pdf(model))
  assert_true(file.contains("/Coords [0 0 1 0]"))
  guard number_arrays(file, "/Matrix") is [[a, b, c, d, e, f]] else {
    fail("expected one pattern matrix")
  }
  // grown about its middle, (10 + 5e-8, 80) on the page
  assert_true(near(a, 0.001, 1.0e-12) && near(d, -0.001, 1.0e-12))
  assert_eq((b, c), (0, 0))
  assert_true(near(e + a / 2, 10 + 5.0e-8, 1.0e-15) && f == 80)
  // a radial one ending on a circle as small, about its centre
  let model = gradient_rectangle(
    Radial(x1=50, y1=30, r1=0, x2=50, y2=30, r2=1.0e-7),
  )
  assert_true(model.validate().is_empty())
  let file = as_text(@pdf.render_pdf(model))
  assert_true(file.contains("/Coords [0 0 0 0 0 1]"))
  guard number_arrays(file, "/Matrix") is [[a, b, c, d, e, f]] else {
    fail("expected one pattern matrix")
  }
  assert_true(near(a, 0.001, 1.0e-12) && near(d, -0.001, 1.0e-12))
  assert_eq((b, c, e, f), (0, 0, 60, 50))
}

///|
test "a linear gradient too long to draw is shrunk about the page's centre" {
  // 1e18 points long, its middle at x = 50: Poppler paints nothing where
  // the gradient's parameter varies across the page by less than a double
  // resolves
  let model = gradient_rectangle(
    Linear(x1=50 - 5.0e17, y1=0, x2=50 + 5.0e17, y2=0),
  )
  assert_true(model.validate().is_empty())
  let file = as_text(@pdf.render_pdf(model))
  guard number_arrays(file, "/Matrix") is [[a, b, c, d, e, f]] else {
    fail("expected one pattern matrix")
  }
  // 1e12 long, and at the page's centre (100, 50) the parameter is what it
  // was, 0.5 + 4e-17 (that is, 0.5 as a double)
  assert_true(near(a, 1.0e12, 1.0e-12) && near(d, -1.0e12, 1.0e-12))
  assert_eq((b, c), (0, 0))
  assert_true(near((100 - e) / a, 0.5, 1.0e-15))
  ignore(f)
}
