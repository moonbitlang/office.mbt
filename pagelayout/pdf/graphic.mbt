///|
// Vector graphics (`GraphicItem`) to content operators.
//
// A graphic's space is the page's y-down space translated to the item, so
// one `cm` that flips y maps it onto PDF's user space; after that, path
// coordinates and the graphic's own transformations are written as they
// are. Text and images, which PDF draws upright in a y-up space, are drawn
// inside a second flip of their own.
//
// Transparency becomes `/ExtGState` resources (one per distinct pair of
// alphas in the document), gradients shading patterns. A pattern's matrix
// maps pattern space to the page's default space rather than to the
// current one, so the emitter tracks the current transformation and bakes
// it into the pattern.

///|
/// The paint and stroke parameters in effect, so each is written only
/// when it changes.
priv struct PaintState {
  mut fill : String?
  mut stroke : String?
  mut width : Double?
  mut cap : @pagelayout.LineCap?
  mut join : @pagelayout.LineJoin?
  mut miter : Double?
  mut dash : (Array[Double], Double)?
  mut ctm : @pagelayout.Matrix
}

///|
fn PaintState::copy(self : PaintState) -> PaintState {
  { ..self, }
}

///|
/// What a document's graphics share: the alpha states and shadings
/// written so far, by value.
priv struct GraphicResources {
  document : @pdflite.PdfDocument
  gstates : Map[String, Int]
  shadings : Map[String, Int]
}

///|
fn GraphicResources::new(document : @pdflite.PdfDocument) -> GraphicResources {
  { document, gstates: Map([]), shadings: Map([]), }
}

///|
/// The resources one page draws with, beyond fonts and images.
priv struct PageGraphics {
  gstates : Array[Int]
  patterns : Array[Int]
}

///|
fn gstate_resource_name(number : Int) -> @core.PdfName {
  name("/GS" + number.to_string())
}

///|
fn pattern_resource_name(number : Int) -> @core.PdfName {
  name("/P" + number.to_string())
}

///|
/// The `/ExtGState` object setting these alphas, shared by value.
fn GraphicResources::gstate(
  self : GraphicResources,
  fill : Double,
  stroke : Double,
) -> Int {
  let key = "\{fill}|\{stroke}"
  match self.gstates.get(key) {
    Some(number) => number
    None => {
      let number = self.document.add_object(
        PdfDictionary([
          (name("/Type"), PdfNameObject(name("/ExtGState"))),
          (name("/ca"), PdfReal(fill)),
          (name("/CA"), PdfReal(stroke)),
        ]),
      )
      self.gstates[key] = number
      number
    }
  }
}

///|
fn colour_array(c : @pagelayout.Color) -> @syntax.PdfObject {
  let (r, g, b) = colour_of(c)
  PdfArray([PdfReal(r), PdfReal(g), PdfReal(b)])
}

///|
/// The shading of a gradient in gradient space: axial or radial, with an
/// exponential interpolation function per pair of adjacent stops (stitched
/// together when there are more than two), extended past both ends.
fn GraphicResources::shading(
  self : GraphicResources,
  gradient : @pagelayout.Gradient,
) -> Int {
  let key = ToJson::to_json(@pagelayout.Gradient::{
    ..gradient,
    transform: @pagelayout.identity,
  }).stringify()
  match self.shadings.get(key) {
    Some(number) => return number
    None => ()
  }
  let stops = gradient.stops
  let pieces : Array[@syntax.PdfObject] = []
  for i in 1..<stops.length() {
    pieces.push(
      PdfDictionary([
        (name("/FunctionType"), PdfInteger(2)),
        (name("/Domain"), PdfArray([PdfReal(0.0), PdfReal(1.0)])),
        (name("/C0"), colour_array(stops[i - 1].color)),
        (name("/C1"), colour_array(stops[i].color)),
        (name("/N"), PdfReal(1.0)),
      ]),
    )
  }
  let function : @syntax.PdfObject = if pieces.length() == 1 {
    pieces[0]
  } else {
    let bounds : Array[@syntax.PdfObject] = []
    let encode : Array[@syntax.PdfObject] = []
    for i in 1..<(stops.length() - 1) {
      bounds.push(PdfReal(stops[i].offset))
    }
    for _ in pieces {
      encode.push(PdfReal(0.0))
      encode.push(PdfReal(1.0))
    }
    PdfDictionary([
      (name("/FunctionType"), PdfInteger(3)),
      (name("/Domain"), PdfArray([PdfReal(0.0), PdfReal(1.0)])),
      (name("/Functions"), PdfArray(pieces)),
      (name("/Bounds"), PdfArray(bounds)),
      (name("/Encode"), PdfArray(encode)),
    ])
  }
  let coords : Array[@syntax.PdfObject] = if gradient.radial {
    [
      PdfReal(gradient.x1),
      PdfReal(gradient.y1),
      PdfReal(gradient.r1),
      PdfReal(gradient.x2),
      PdfReal(gradient.y2),
      PdfReal(gradient.r2),
    ]
  } else {
    [
      PdfReal(gradient.x1),
      PdfReal(gradient.y1),
      PdfReal(gradient.x2),
      PdfReal(gradient.y2),
    ]
  }
  let number = self.document.add_object(
    PdfDictionary([
      (name("/ShadingType"), PdfInteger(if gradient.radial { 3 } else { 2 })),
      (name("/ColorSpace"), PdfNameObject(name("/DeviceRGB"))),
      (name("/Coords"), PdfArray(coords)),
      (name("/Function"), function),
      (name("/Extend"), PdfArray([PdfBoolean(true), PdfBoolean(true)])),
    ]),
  )
  self.shadings[key] = number
  number
}

///|
/// A shading pattern painting `gradient` where the current transformation
/// is `ctm` (from the gradient's user space to the page's default space).
fn GraphicResources::pattern(
  self : GraphicResources,
  gradient : @pagelayout.Gradient,
  ctm : @pagelayout.Matrix,
) -> Int {
  let shading = self.shading(gradient)
  let m = ctm.after(gradient.transform)
  self.document.add_object(
    PdfDictionary([
      (name("/Type"), PdfNameObject(name("/Pattern"))),
      (name("/PatternType"), PdfInteger(2)),
      (name("/Shading"), PdfIndirect(shading)),
      (
        name("/Matrix"),
        PdfArray([
          PdfReal(m.a),
          PdfReal(m.b),
          PdfReal(m.c),
          PdfReal(m.d),
          PdfReal(m.e),
          PdfReal(m.f),
        ]),
      ),
    ]),
  )
}

///|
fn cm_op(m : @pagelayout.Matrix) -> @content.PdfContentOp {
  Op_cm({ a: m.a, b: m.b, c: m.c, d: m.d, e: m.e, f: m.f, })
}

///|
fn emit_segments(
  ops : Array[@content.PdfContentOp],
  segments : Array[@pagelayout.PathSegment],
) -> Unit {
  for segment in segments {
    match segment {
      MoveTo(x, y) => ops.push(Op_m(x, y))
      LineTo(x, y) => ops.push(Op_l(x, y))
      CurveTo(x1, y1, x2, y2, x, y) => ops.push(Op_c(x1, y1, x2, y2, x, y))
      // drawn from its bottom-left corner in the page's y-up terms, as
      // PDF's `re` with a positive height would be
      Rectangle(x, y, w, h) => ops.push(Op_re(x, y + h, w, -h))
      Close => ops.push(Op_h)
    }
  }
}

///|
/// Set the fill (or stroke) paint, when it differs from the current one.
fn set_paint(
  ops : Array[@content.PdfContentOp],
  state : PaintState,
  paint : @pagelayout.Paint,
  stroke~ : Bool,
  resources : GraphicResources,
  page : PageGraphics,
) -> Unit {
  match paint {
    Solid(colour) => {
      let key = colour.to_hex()
      let current = if stroke { state.stroke } else { state.fill }
      if current == Some(key) {
        return
      }
      let (r, g, b) = colour_of(colour)
      if stroke {
        ops.push(Op_RG(r, g, b))
        state.stroke = Some(key)
      } else {
        ops.push(Op_rg(r, g, b))
        state.fill = Some(key)
      }
    }
    GradientPaint(gradient) => {
      let number = resources.pattern(gradient, state.ctm)
      if !page.patterns.contains(number) {
        page.patterns.push(number)
      }
      if stroke {
        ops.push(Op_CS(name("/Pattern")))
        ops.push(Op_SCNName(pattern_resource_name(number), []))
        state.stroke = None
      } else {
        ops.push(Op_cs(name("/Pattern")))
        ops.push(Op_scnName(pattern_resource_name(number), []))
        state.fill = None
      }
    }
  }
}

///|
fn set_stroke_style(
  ops : Array[@content.PdfContentOp],
  state : PaintState,
  style : @pagelayout.StrokeStyle,
) -> Unit {
  if state.width != Some(style.width) {
    ops.push(Op_w(style.width))
    state.width = Some(style.width)
  }
  if state.cap != Some(style.cap) {
    ops.push(
      Op_J(
        match style.cap {
          ButtCap => 0
          RoundCap => 1
          SquareCap => 2
        },
      ),
    )
    state.cap = Some(style.cap)
  }
  if state.join != Some(style.join) {
    ops.push(
      Op_j(
        match style.join {
          MiterJoin => 0
          RoundJoin => 1
          BevelJoin => 2
        },
      ),
    )
    state.join = Some(style.join)
  }
  if state.miter != Some(style.miter_limit) {
    ops.push(Op_M(style.miter_limit))
    state.miter = Some(style.miter_limit)
  }
  let dash = (style.dash, style.dash_phase)
  if state.dash != Some(dash) {
    ops.push(Op_d(style.dash, style.dash_phase))
    state.dash = Some(dash)
  }
}

///|
/// Draw a graphic whose space's origin is at `(x_pt, y_pt)` on a page
/// `page_height` tall. Glyph runs go through `text`, which draws a run in
/// PDF's y-up terms on a page of height 0, and records the font it used;
/// images through `image`, likewise.
fn emit_graphic(
  ops : Array[@content.PdfContentOp],
  graphic : @pagelayout.GraphicItem,
  page_height : Double,
  resources : GraphicResources,
  page : PageGraphics,
  text~ : (@pagelayout.GlyphRun) -> Unit,
  image~ : (@pagelayout.ImageItem) -> Unit,
) -> Unit {
  let origin = @pagelayout.Matrix::{
    a: 1,
    b: 0,
    c: 0,
    d: -1,
    e: graphic.x_pt,
    f: page_height - graphic.y_pt,
  }
  // the flip back to y-up that text and images are drawn in
  let upright = @pagelayout.Matrix::{ a: 1, b: 0, c: 0, d: -1, e: 0, f: 0, }
  ops.push(Op_q)
  ops.push(cm_op(origin))
  let mut state = PaintState::{
    fill: None,
    stroke: None,
    width: None,
    cap: None,
    join: None,
    miter: None,
    dash: None,
    ctm: origin,
  }
  let stack : Array[PaintState] = []
  for op in graphic.ops {
    match op {
      Save => {
        ops.push(Op_q)
        stack.push(state.copy())
      }
      Restore =>
        match stack.pop() {
          Some(saved) => {
            ops.push(Op_Q)
            state = saved
          }
          // unbalanced (see `PageModel::validate`): ignored
          None => ()
        }
      Transform(m) => {
        ops.push(cm_op(m))
        state.ctm = state.ctm.after(m)
      }
      Clip(segments, rule) => {
        emit_segments(ops, segments)
        ops.push(
          match rule {
            NonZero => Op_W
            EvenOdd => Op_Wstar
          },
        )
        ops.push(Op_n)
      }
      Alpha(fill, stroke) => {
        let number = resources.gstate(fill, stroke)
        if !page.gstates.contains(number) {
          page.gstates.push(number)
        }
        ops.push(Op_gs(gstate_resource_name(number)))
      }
      Path(path) => {
        let fill = path.fill
        let stroke = path.stroke
        match fill {
          Some(paint) =>
            set_paint(ops, state, paint, stroke=false, resources, page)
          None => ()
        }
        match stroke {
          Some(paint) => {
            set_paint(ops, state, paint, stroke=true, resources, page)
            set_stroke_style(ops, state, path.stroke_style)
          }
          None => ()
        }
        emit_segments(ops, path.segments)
        let even_odd = path.fill_rule is EvenOdd
        ops.push(
          match (fill, stroke) {
            (Some(_), Some(_)) => if even_odd { Op_Bstar } else { Op_B }
            (Some(_), None) => if even_odd { Op_fstar } else { Op_f }
            (None, Some(_)) => Op_S
            (None, None) => Op_n
          },
        )
      }
      Text(run) => {
        ops.push(Op_q)
        ops.push(cm_op(upright))
        text(run)
        ops.push(Op_Q)
      }
      PaintedText(run, paint) => {
        ops.push(Op_q)
        ops.push(cm_op(upright))
        match paint.stroke {
          Some(colour) => {
            let (r, g, b) = colour_of(colour)
            ops.push(Op_RG(r, g, b))
            ops.push(Op_w(paint.stroke_width))
          }
          None => ()
        }
        // the text rendering mode (a text state parameter, valid outside a
        // text object and kept by the `Q`)
        ops.push(
          Op_Tr(
            match (paint.fill, paint.stroke) {
              (true, None) => 0
              (false, Some(_)) => 1
              (true, Some(_)) => 2
              (false, None) => 3
            },
          ),
        )
        text(run)
        ops.push(Op_Q)
      }
      Image(item) => {
        ops.push(Op_q)
        ops.push(cm_op(upright))
        image(item)
        ops.push(Op_Q)
      }
    }
  }
  // close whatever an unbalanced graphic left open
  for _ in stack {
    ops.push(Op_Q)
  }
  ops.push(Op_Q)
}
