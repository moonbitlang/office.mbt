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
//
// Numbers in a graphic's content are written exactly (`exact_real`), not
// rounded as pdflite writes reals (to six decimals below 0.0001, else to
// twelve significant digits): a graphic's own transformations can scale
// them by any factor. Dictionaries are written by pdflite, so what goes
// into them is kept within its precision instead: a shading's geometry is
// canonical (a linear one runs from (0, 0) to (1, 0)), the pattern matrix
// carrying it to the gradient's place on the page, and stitching bounds
// that would be written equal are merged.

///|
/// The paint and stroke parameters in effect, so each is written only
/// when it changes.
priv struct PaintState {
  mut fill : String?
  mut stroke : String?
  mut width : @pagelayout.StrokeWidth?
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
/// What a document's graphics share: the alpha states, shadings and
/// patterns written so far, by value (a pattern by its shading and matrix),
/// so that a gradient painted many times is written once.
priv struct GraphicResources {
  document : @pdflite.PdfDocument
  gstates : Map[String, Int]
  shadings : Map[String, Int]
  patterns : Map[String, Int]
}

///|
fn GraphicResources::new(document : @pdflite.PdfDocument) -> GraphicResources {
  { document, gstates: Map([]), shadings: Map([]), patterns: Map([]), }
}

///|
/// The resources one page draws with, beyond fonts and images, in the
/// order of first use.
priv struct PageGraphics {
  gstates : Map[Int, Unit]
  patterns : Map[Int, Unit]
}

///|
fn PageGraphics::new() -> PageGraphics {
  { gstates: Map([]), patterns: Map([]), }
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
/// The interpolations of a gradient's colours: from `.1` to `.2` over the
/// offsets from `.0` to the next one's `.0` (or 1). Stops at the same
/// offset make no interpolation of their own, only a sharp change from
/// the one before them to the one after; at offset 0 that leaves the last
/// of them to start from, and at offset 1 the first to end at (see
/// `@pagelayout.Gradient`). PDF's stitching function needs exactly this:
/// its bounds, the starts after the first, must strictly increase (PDF
/// 32000-1, 7.10.4).
///
/// Strictly increasing offsets are not enough: the bounds must increase as
/// written, where offsets nearer than a written real resolves come out
/// equal (0.5 and 0.50000000000001 both as 0.5, 1e-8 and 2e-8 both as
/// 0.000000). So an interval that would be written without width is
/// dropped as a zero-width one is, the next taking over at its start, and
/// one that would be written to start at 1 is dropped with all after it.
fn gradient_pieces(
  stops : Array[@pagelayout.GradientStop],
) -> Array[(Double, @pagelayout.Color, @pagelayout.Color)] {
  let pieces : Array[(Double, @pagelayout.Color, @pagelayout.Color)] = []
  // where the last piece starts, as written
  let mut last = 0.0
  for i in 1..<stops.length() {
    guard stops[i].offset > stops[i - 1].offset else { continue }
    let start = stops[i - 1].offset
    let at = written_real(start)
    if pieces.is_empty() {
      pieces.push((start, stops[i - 1].color, stops[i].color))
    } else if at >= 1.0 {
      break
    } else if at <= last {
      let (kept, _, _) = pieces[pieces.length() - 1]
      pieces[pieces.length() - 1] = (kept, stops[i - 1].color, stops[i].color)
    } else {
      pieces.push((start, stops[i - 1].color, stops[i].color))
      last = at
    }
  }
  // stops that do not span an interval (see `PageModel::validate`): the
  // last colour throughout
  if pieces.is_empty() && !stops.is_empty() {
    let last = stops[stops.length() - 1].color
    pieces.push((0.0, last, last))
  }
  pieces
}

///|
/// The value of `v` as pdflite writes it in a dictionary.
fn written_real(v : Double) -> Double {
  let bytes = @pdflite.pdf_write_real(v) catch { _ => return v }
  let sb = StringBuilder()
  for byte in bytes {
    sb.write_char(byte.to_int().unsafe_to_char())
  }
  @string.parse_double(sb.to_string()) catch {
    _ => v
  }
}

///|
/// A gradient's shape in a space of its own where its geometry is simple,
/// and the transformation from there to gradient space: a linear gradient
/// runs from (0, 0) to (1, 0), the unit square turned and scaled onto its
/// line; a radial one ends on the unit circle. The shading type and
/// coordinates follow the transformation.
///
/// Only numbers of ordinary size are left to the shading, whose
/// coordinates pdflite writes to limited precision; the gradient's own
/// size goes into the pattern matrix, where it meets the transformations
/// that scale it back to the page. The shape has extent (a gradient
/// without is painted as its colour; see `set_paint`).
fn canonical_shape(
  shape : @pagelayout.GradientShape,
) -> (Int, Array[Double], @pagelayout.Matrix) {
  match shape {
    Linear(x1~, y1~, x2~, y2~) => {
      let dx = x2 - x1
      let dy = y2 - y1
      (2, [0, 0, 1, 0], { a: dx, b: dy, c: -dy, d: dx, e: x1, f: y1, })
    }
    Radial(x1~, y1~, r1~, x2~, y2~, r2~) =>
      (
        3,
        [(x1 - x2) / r2, (y1 - y2) / r2, r1 / r2, 0, 0, 1],
        { a: r2, b: 0, c: 0, d: r2, e: x2, f: y2, },
      )
  }
}

///|
/// The shading of a gradient in its canonical space (see
/// `canonical_shape`): axial or radial, with an exponential interpolation
/// function per interval between stops (stitched together when there is
/// more than one), extended past both ends. Shared by shape and stops.
fn GraphicResources::shading(
  self : GraphicResources,
  gradient : @pagelayout.Gradient,
  shading_type : Int,
  coords : Array[Double],
) -> Int {
  let sb = StringBuilder()
  sb.write_string("\{shading_type}")
  for x in coords {
    sb.write_string(" \{x}")
  }
  for stop in gradient.stops {
    sb.write_string(" \{stop.offset}\{stop.color.to_hex()}")
  }
  let key = sb.to_string()
  match self.shadings.get(key) {
    Some(number) => return number
    None => ()
  }
  let intervals = gradient_pieces(gradient.stops)
  let pieces : Array[@syntax.PdfObject] = []
  for piece in intervals {
    let (_, from, to) = piece
    pieces.push(
      PdfDictionary([
        (name("/FunctionType"), PdfInteger(2)),
        (name("/Domain"), PdfArray([PdfReal(0.0), PdfReal(1.0)])),
        (name("/C0"), colour_array(from)),
        (name("/C1"), colour_array(to)),
        (name("/N"), PdfReal(1.0)),
      ]),
    )
  }
  let function : @syntax.PdfObject = if pieces.length() == 1 {
    pieces[0]
  } else {
    let bounds : Array[@syntax.PdfObject] = []
    let encode : Array[@syntax.PdfObject] = []
    for i in 1..<intervals.length() {
      bounds.push(PdfReal(intervals[i].0))
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
  let number = self.document.add_object(
    PdfDictionary([
      (name("/ShadingType"), PdfInteger(shading_type)),
      (name("/ColorSpace"), PdfNameObject(name("/DeviceRGB"))),
      (name("/Coords"), PdfArray(coords.map(x => PdfReal(x)))),
      (name("/Function"), function),
      (name("/Extend"), PdfArray([PdfBoolean(true), PdfBoolean(true)])),
    ]),
  )
  self.shadings[key] = number
  number
}

///|
/// A shading pattern painting `gradient` where the current transformation
/// is `ctm` (from the gradient's user space to the page's default space),
/// one per shading and effective matrix: the matrix maps the shading's
/// canonical space through gradient space to the page.
fn GraphicResources::pattern(
  self : GraphicResources,
  gradient : @pagelayout.Gradient,
  ctm : @pagelayout.Matrix,
) -> Int {
  let (shading_type, coords, canonical) = canonical_shape(gradient.shape)
  let shading = self.shading(gradient, shading_type, coords)
  let m = ctm.after(gradient.transform).after(canonical)
  let key = "\{shading} \{m.a} \{m.b} \{m.c} \{m.d} \{m.e} \{m.f}"
  match self.patterns.get(key) {
    Some(number) => return number
    None => ()
  }
  let number = self.document.add_object(
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
  self.patterns[key] = number
  number
}

///|
/// `v` written exactly as a PDF real: the shortest decimal that reads back
/// as `v`, spelt out without an exponent, which PDF's number syntax does
/// not have (PDF 32000-1, 7.3.3). `v` is finite (see
/// `PageModel::validate`).
fn exact_real(v : Double) -> String {
  let text = v.to_string()
  guard text.find("e") is Some(e) else { return text }
  let negative = text.has_prefix("-")
  let mantissa = if negative { text[1:e] } else { text[:e] }
  let exponent = match text[e + 1:] {
    [.. "+", .. rest] => @string.parse_int(rest) catch { _ => 0 }
    [.. "-", .. rest] => -(@string.parse_int(rest) catch { _ => 0 })
    rest => @string.parse_int(rest) catch { _ => 0 }
  }
  // the significant digits, and where the point falls among them
  let (digits, point) = match mantissa.find(".") {
    Some(i) => (mantissa[:i].to_owned() + mantissa[i + 1:].to_owned(), i)
    None => (mantissa.to_owned(), mantissa.length())
  }
  let point = point + exponent
  let sb = StringBuilder()
  if negative {
    sb.write_char('-')
  }
  if point <= 0 {
    sb.write_string("0.")
    for _ in 0..<-point {
      sb.write_char('0')
    }
    sb.write_string(digits)
  } else if point >= digits.length() {
    sb.write_string(digits)
    for _ in 0..<(point - digits.length()) {
      sb.write_char('0')
    }
  } else {
    sb.write_string(digits[:point].to_owned())
    sb.write_char('.')
    sb.write_string(digits[point:].to_owned())
  }
  sb.to_string()
}

///|
/// `op` with its numbers written exactly (see `exact_real`), for the
/// operators a graphic's content uses that take numbers of any size:
/// coordinates, transformations, stroke parameters, text positions and
/// sizes. Colours and alphas, which lie in 0..=1 and come from bytes,
/// and text strings are left to pdflite.
fn exact_op(op : @content.PdfContentOp) -> @content.PdfContentOp {
  let (numbers, operator) : (Array[Double], String) = match op {
    Op_cm(m) => ([m.a, m.b, m.c, m.d, m.e, m.f], "cm")
    Op_Tm(m) => ([m.a, m.b, m.c, m.d, m.e, m.f], "Tm")
    Op_m(x, y) => ([x, y], "m")
    Op_l(x, y) => ([x, y], "l")
    Op_c(x1, y1, x2, y2, x, y) => ([x1, y1, x2, y2, x, y], "c")
    Op_re(x, y, w, h) => ([x, y, w, h], "re")
    Op_w(width) => ([width], "w")
    Op_M(limit) => ([limit], "M")
    Op_Td(x, y) => ([x, y], "Td")
    Op_d(dash, phase) => {
      let text = "[\{dash.map(exact_real).join(" ")}] \{exact_real(phase)} d"
      return Op_Unknown(@utf8.encode(text))
    }
    Op_Tf(font, size) => {
      let sb = StringBuilder()
      for byte in @pdflite.pdf_write_name(font) {
        sb.write_char(byte.to_int().unsafe_to_char())
      }
      sb.write_string(" \{exact_real(size)} Tf")
      return Op_Unknown(@utf8.encode(sb.to_string()))
    }
    _ => return op
  }
  Op_Unknown(@utf8.encode("\{numbers.map(exact_real).join(" ")} \{operator}"))
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
/// A gradient without extent is its colour (see
/// `@pagelayout.Gradient::degenerate_color`).
fn set_paint(
  ops : Array[@content.PdfContentOp],
  state : PaintState,
  paint : @pagelayout.Paint,
  stroke~ : Bool,
  resources : GraphicResources,
  page : PageGraphics,
) -> Unit {
  let paint : @pagelayout.Paint = match paint {
    GradientPaint(g) if g.degenerate_color() is Some(colour) => Solid(colour)
    paint => paint
  }
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
      page.patterns[number] = ()
      // a pattern's key cannot be a colour's, which starts with `#`
      let key = "/P\{number}"
      let current = if stroke { state.stroke } else { state.fill }
      if current == Some(key) {
        return
      }
      if stroke {
        ops.push(Op_CS(name("/Pattern")))
        ops.push(Op_SCNName(pattern_resource_name(number), []))
        state.stroke = Some(key)
      } else {
        ops.push(Op_cs(name("/Pattern")))
        ops.push(Op_scnName(pattern_resource_name(number), []))
        state.fill = Some(key)
      }
    }
  }
}

///|
/// The stroke parameters of `style`, those `state` does not already have
/// (all of them for a state that knows nothing). A hairline is PDF's line
/// width 0.
fn set_stroke_style(
  ops : Array[@content.PdfContentOp],
  state : PaintState,
  style : @pagelayout.StrokeStyle,
) -> Unit {
  if state.width != Some(style.width) {
    ops.push(
      Op_w(
        match style.width {
          Width(width) => width
          Hairline => 0.0
        },
      ),
    )
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
/// A state that knows nothing of the paint and stroke parameters in effect,
/// where the transformation is `ctm`.
fn PaintState::unknown(ctm : @pagelayout.Matrix) -> PaintState {
  {
    fill: None,
    stroke: None,
    width: None,
    cap: None,
    join: None,
    miter: None,
    dash: None,
    ctm,
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
  let start = ops.length()
  ops.push(Op_q)
  ops.push(cm_op(origin))
  let mut state = PaintState::unknown(origin)
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
        page.gstates[number] = ()
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
            // the whole stroke style, inside the text's own `q`: whatever
            // the paths before it left in effect does not carry over, and
            // what is set here does not carry out
            set_stroke_style(
              ops,
              PaintState::unknown(state.ctm),
              paint.stroke_style,
            )
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
  // everything the graphic drew, its text and images too, is in a space
  // its transformations may have scaled by any factor
  for i in start..<ops.length() {
    ops[i] = exact_op(ops[i])
  }
}
