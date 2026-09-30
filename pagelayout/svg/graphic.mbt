///|
// Vector graphics (`GraphicItem`) to SVG. A graphic becomes a group
// translated to its origin; `Save`/`Restore` bracket nested groups, and a
// transformation or a clip opens one more group that the matching
// `Restore` (or the graphic's end) closes. Alphas become fill and stroke
// opacities on what follows them, gradients `<linearGradient>` and
// `<radialGradient>` definitions in user space. Clip, gradient ids count up
// in `Defs` so they stay unique on the page.
//
// Numbers in a graphic are written exactly (`num`), not rounded to three
// decimals as page items are: a graphic's own transformations can scale
// what follows them by any factor, so no fixed precision is enough.

///|
/// The shortest decimal that reads back as `v` (with an exponent for very
/// large and small magnitudes, which SVG's number syntax allows). `v` is
/// finite (see `PageModel::validate`).
fn num(v : Double) -> String {
  v.to_string()
}

///|
fn path_data(segments : Array[@pagelayout.PathSegment]) -> String {
  let parts : Array[String] = []
  for segment in segments {
    match segment {
      MoveTo(x, y) => parts.push("M\{num(x)} \{num(y)}")
      LineTo(x, y) => parts.push("L\{num(x)} \{num(y)}")
      CurveTo(x1, y1, x2, y2, x, y) =>
        parts.push(
          "C\{num(x1)} \{num(y1)} \{num(x2)} \{num(y2)} \{num(x)} \{num(y)}",
        )
      // the winding of PDF's `re` (see `PathSegment::Rectangle`)
      Rectangle(x, y, w, h) =>
        parts.push("M\{num(x)} \{num(y + h)}h\{num(w)}v\{num(-h)}h\{num(-w)}Z")
      Close => parts.push("Z")
    }
  }
  parts.join("")
}

///|
/// A straight or curved piece of a subpath, from its first point.
priv enum Piece {
  Line(Double, Double, Double, Double)
  Curve(Double, Double, Double, Double, Double, Double, Double, Double)
}

///|
/// How finely a curve is divided to measure its length.
const CURVE_STEPS : Int = 64

///|
fn bezier(
  p0 : Double,
  p1 : Double,
  p2 : Double,
  p3 : Double,
  t : Double,
) -> Double {
  let u = 1.0 - t
  u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
}

///|
/// The first (`left`) or second part of the cubic `q` split at `t` (de
/// Casteljau), its four control values.
fn bezier_split(q : Array[Double], t : Double, left~ : Bool) -> Array[Double] {
  let a = q[0] + (q[1] - q[0]) * t
  let b = q[1] + (q[2] - q[1]) * t
  let c = q[2] + (q[3] - q[2]) * t
  let d = a + (b - a) * t
  let e = b + (c - b) * t
  let mid = d + (e - d) * t
  if left {
    [q[0], a, d, mid]
  } else {
    [mid, e, c, q[3]]
  }
}

///|
/// The part of the cubic `q` from `t0` to `t1`.
fn bezier_part(q : Array[Double], t0 : Double, t1 : Double) -> Array[Double] {
  let head = if t1 < 1.0 { bezier_split(q, t1, left=true) } else { q }
  if t0 <= 0.0 || t1 <= 0.0 {
    head
  } else {
    bezier_split(head, t0 / t1, left=false)
  }
}

///|
/// A piece measured: its length, and for a curve the length up to each of
/// `CURVE_STEPS` equal steps of its parameter, to find where a length
/// along it falls.
priv struct Measured {
  piece : Piece
  length : Double
  lengths : Array[Double]
}

///|
fn measure(piece : Piece) -> Measured {
  match piece {
    Line(x0, y0, x1, y1) => {
      let length = ((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)).sqrt()
      { piece, length, lengths: [], }
    }
    Curve(x0, y0, x1, y1, x2, y2, x3, y3) => {
      let lengths = [0.0]
      let mut px = x0
      let mut py = y0
      let mut total = 0.0
      for i in 1..<=CURVE_STEPS {
        let t = i.to_double() / CURVE_STEPS.to_double()
        let x = bezier(x0, x1, x2, x3, t)
        let y = bezier(y0, y1, y2, y3, t)
        total += ((x - px) * (x - px) + (y - py) * (y - py)).sqrt()
        lengths.push(total)
        px = x
        py = y
      }
      { piece, length: total, lengths, }
    }
  }
}

///|
/// The parameter of a curve at length `s` along it.
fn Measured::parameter(self : Measured, s : Double) -> Double {
  if s <= 0.0 || self.length <= 0.0 {
    return 0.0
  }
  if s >= self.length {
    return 1.0
  }
  let lengths = self.lengths
  let mut i = 1
  while i < CURVE_STEPS && lengths[i] < s {
    i += 1
  }
  let span = lengths[i] - lengths[i - 1]
  let within = if span > 0.0 { (s - lengths[i - 1]) / span } else { 0.0 }
  (i.to_double() - 1.0 + within) / CURVE_STEPS.to_double()
}

///|
/// The point at length `s` along the piece.
fn Measured::point(self : Measured, s : Double) -> (Double, Double) {
  match self.piece {
    Line(x0, y0, x1, y1) => {
      let f = if self.length > 0.0 { s / self.length } else { 0.0 }
      (x0 + (x1 - x0) * f, y0 + (y1 - y0) * f)
    }
    Curve(x0, y0, x1, y1, x2, y2, x3, y3) => {
      let t = self.parameter(s)
      (bezier(x0, x1, x2, x3, t), bezier(y0, y1, y2, y3, t))
    }
  }
}

///|
/// The segment drawing the piece from length `s0` to `s1` along it, from
/// the point at `s0`.
fn Measured::part(
  self : Measured,
  s0 : Double,
  s1 : Double,
) -> @pagelayout.PathSegment {
  match self.piece {
    Line(_, _, _, _) => {
      let (x, y) = self.point(s1)
      LineTo(x, y)
    }
    Curve(x0, y0, x1, y1, x2, y2, x3, y3) => {
      let t0 = self.parameter(s0)
      let t1 = self.parameter(s1)
      let xs = bezier_part([x0, x1, x2, x3], t0, t1)
      let ys = bezier_part([y0, y1, y2, y3], t0, t1)
      CurveTo(xs[1], ys[1], xs[2], ys[2], xs[3], ys[3])
    }
  }
}

///|
/// A path's subpaths as pieces, a `Close` (or a `Rectangle`'s end)
/// closing its own with a line back to its start.
fn subpaths(segments : Array[@pagelayout.PathSegment]) -> Array[Array[Piece]] {
  let result : Array[Array[Piece]] = []
  let mut pieces : Array[Piece] = []
  let mut x = 0.0
  let mut y = 0.0
  let mut start_x = 0.0
  let mut start_y = 0.0
  for segment in segments {
    match segment {
      MoveTo(mx, my) => {
        if !pieces.is_empty() {
          result.push(pieces)
        }
        pieces = []
        x = mx
        y = my
        start_x = mx
        start_y = my
      }
      LineTo(lx, ly) => {
        pieces.push(Line(x, y, lx, ly))
        x = lx
        y = ly
      }
      CurveTo(x1, y1, x2, y2, cx, cy) => {
        pieces.push(Curve(x, y, x1, y1, x2, y2, cx, cy))
        x = cx
        y = cy
      }
      Close => {
        pieces.push(Line(x, y, start_x, start_y))
        result.push(pieces)
        pieces = []
        x = start_x
        y = start_y
      }
      Rectangle(rx, ry, w, h) => {
        if !pieces.is_empty() {
          result.push(pieces)
        }
        // the winding of `PathSegment::Rectangle`
        result.push([
          Line(rx, ry + h, rx + w, ry + h),
          Line(rx + w, ry + h, rx + w, ry),
          Line(rx + w, ry, rx, ry),
          Line(rx, ry, rx, ry + h),
        ])
        pieces = []
        x = rx
        y = ry + h
        start_x = x
        start_y = y
      }
    }
  }
  if !pieces.is_empty() {
    result.push(pieces)
  }
  result
}

///|
/// The dashes of a path dashed by `dash` from `phase` (see
/// `@pagelayout.StrokeStyle`), as PDF dashes it: the pattern (twice over
/// when its length is odd) runs along each subpath in the path's own
/// space, restarting from the phase at each; a dash turning a corner is
/// one subpath, joined there; a dash of length 0 is a subpath of length 0
/// (a dot, with round or square caps).
fn dashed(
  segments : Array[@pagelayout.PathSegment],
  dash : Array[Double],
  phase : Double,
) -> Array[@pagelayout.PathSegment] {
  let pattern = if dash.length() % 2 == 1 { dash + dash } else { dash }
  let period = pattern.fold(init=0.0, (sum, d) => sum + d)
  // at least one length is positive (see `PageModel::validate`)
  guard period > 0.0 else { return segments }
  let out : Array[@pagelayout.PathSegment] = []
  for pieces in subpaths(segments) {
    // where in the pattern the subpath starts, and how much of that
    // length is left
    let mut index = 0
    let mut left = pattern[0]
    let mut into = phase - (phase / period).floor() * period
    while into >= left {
      into -= left
      index = (index + 1) % pattern.length()
      left = pattern[index]
    }
    left -= into
    // whether a dash is being drawn, and whether it has a segment yet
    let mut open = false
    let mut drawn = false
    for piece in pieces {
      let m = measure(piece)
      let mut s = 0.0
      while true {
        let on = index % 2 == 0
        if on && !open {
          let (x, y) = m.point(s)
          out.push(MoveTo(x, y))
          open = true
          drawn = false
        }
        let step = if left < m.length - s { left } else { m.length - s }
        if on && step > 0.0 {
          out.push(m.part(s, s + step))
          drawn = true
        }
        s += step
        left -= step
        guard left <= 0.0 else { break }
        // this length of the pattern ends here
        if on {
          if !drawn {
            let (x, y) = m.point(s)
            out.push(LineTo(x, y))
          }
          open = false
        }
        index = (index + 1) % pattern.length()
        left = pattern[index]
      }
    }
    // a dash that would start where the subpath ends is not drawn
    if open && !drawn {
      let _ = out.pop()
    }
  }
  out
}

///|
fn matrix_attr(m : @pagelayout.Matrix) -> String {
  "matrix(\{num(m.a)} \{num(m.b)} \{num(m.c)} \{num(m.d)} \{num(m.e)} \{num(m.f)})"
}

///|
/// The ids of a page's definitions: clip paths and gradients count up
/// from 1, and a gradient already defined on the page (its definition
/// the same but for the id) is referred to again rather than repeated.
priv struct Defs {
  mut last : Int
  gradients : Map[String, String]
}

///|
fn Defs::new() -> Defs {
  { last: 0, gradients: Map([]), }
}

///|
fn Defs::next(self : Defs, prefix : String) -> String {
  self.last += 1
  "\{prefix}\{self.last}"
}

///|
/// The shortest a gradient is drawn on the page, in points: a linear one's
/// length, a radial one's end radius. As the PDF backend draws it (see its
/// `drawable`): Cairo, and so librsvg, paints nothing for a gradient much
/// below 1e-4 points on the page.
const SHORTEST_GRADIENT : Double = 1.0e-3

///|
/// `g` as drawn where the transformation from its user space to the page
/// is `ctm`: when it is smaller there than `SHORTEST_GRADIENT`, grown to
/// that size about the middle of a linear one's line or a radial one's end
/// centre (its focal circle with it), which moves its colours by less than
/// a thousandth of a point.
fn drawable(
  g : @pagelayout.Gradient,
  ctm : @pagelayout.Matrix,
) -> @pagelayout.Gradient {
  let m = ctm.after(g.transform)
  // the length on the page of a vector in gradient space
  let length = fn(x : Double, y : Double) {
    let (px, py) = (m.a * x + m.c * y, m.b * x + m.d * y)
    (px * px + py * py).sqrt()
  }
  let size = match g.shape {
    Linear(x1~, y1~, x2~, y2~) => length(x2 - x1, y2 - y1)
    Radial(r2~, ..) => {
      let first = length(r2, 0)
      let second = length(0, r2)
      if first >= second {
        first
      } else {
        second
      }
    }
  }
  guard size > 0.0 && size < SHORTEST_GRADIENT else { return g }
  let k = SHORTEST_GRADIENT / size
  let shape : @pagelayout.GradientShape = match g.shape {
    Linear(x1~, y1~, x2~, y2~) => {
      let (mx, my) = ((x1 + x2) / 2, (y1 + y2) / 2)
      Linear(
        x1=mx + (x1 - mx) * k,
        y1=my + (y1 - my) * k,
        x2=mx + (x2 - mx) * k,
        y2=my + (y2 - my) * k,
      )
    }
    Radial(x1~, y1~, r1~, x2~, y2~, r2~) =>
      Radial(
        x1=x2 + (x1 - x2) * k,
        y1=y2 + (y1 - y2) * k,
        r1=r1 * k,
        x2~,
        y2~,
        r2=r2 * k,
      )
  }
  { ..g, shape, }
}

///|
/// The value of a `fill` or `stroke` attribute for `paint`, writing a
/// gradient's definition first unless the page has it already. A
/// gradient's coordinates are in the user space of what it paints
/// (`userSpaceOnUse`), so one definition serves wherever it is used. A
/// gradient without extent is its colour (see
/// `@pagelayout.Gradient::degenerate_color`); one too small on the page to
/// draw is grown (see `drawable`), where `ctm` is the transformation from
/// the user space to the page.
fn paint_attr(
  sb : StringBuilder,
  paint : @pagelayout.Paint,
  defs : Defs,
  ctm : @pagelayout.Matrix,
) -> String {
  match paint {
    Solid(color) => color.to_hex()
    GradientPaint(g) if g.degenerate_color() is Some(color) => color.to_hex()
    GradientPaint(g) => {
      let g = drawable(g, ctm)
      // the definition after its id
      let def = StringBuilder()
      let transform = matrix_attr(g.transform)
      let element = match g.shape {
        Linear(x1~, y1~, x2~, y2~) => {
          def.write_string(
            " gradientUnits=\"userSpaceOnUse\" gradientTransform=\"\{transform}\" x1=\"\{num(x1)}\" y1=\"\{num(y1)}\" x2=\"\{num(x2)}\" y2=\"\{num(y2)}\">\n",
          )
          "linearGradient"
        }
        Radial(x1~, y1~, r1~, x2~, y2~, r2~) => {
          def.write_string(
            " gradientUnits=\"userSpaceOnUse\" gradientTransform=\"\{transform}\" fx=\"\{num(x1)}\" fy=\"\{num(y1)}\" fr=\"\{num(r1)}\" cx=\"\{num(x2)}\" cy=\"\{num(y2)}\" r=\"\{num(r2)}\">\n",
          )
          "radialGradient"
        }
      }
      // at offset 0 only the last stop there counts, at offset 1 only the
      // first (see `@pagelayout.Gradient`), where SVG would pad with the
      // outermost
      let stops = g.stops
      for i, stop in stops {
        if stop.offset <= 0.0 &&
          i + 1 < stops.length() &&
          stops[i + 1].offset <= 0.0 {
          continue
        }
        if stop.offset >= 1.0 && i > 0 && stops[i - 1].offset >= 1.0 {
          continue
        }
        def.write_string(
          "    <stop offset=\"\{num(stop.offset)}\" stop-color=\"\{stop.color.to_hex()}\"/>\n",
        )
      }
      def.write_string("  </\{element}>\n")
      let def = def.to_string()
      let key = element + def
      let id = match defs.gradients.get(key) {
        Some(id) => id
        None => {
          let id = defs.next("g")
          defs.gradients[key] = id
          sb.write_string("  <\{element} id=\"\{id}\"")
          sb.write_string(def)
          id
        }
      }
      "url(#\{id})"
    }
  }
}

///|
/// The attributes of a stroke in `style` (after its `stroke`), `alpha`
/// opaque. A hairline is a non-scaling stroke one CSS pixel wide, the
/// nearest SVG has to PDF's thinnest line.
fn write_stroke_style(
  sb : StringBuilder,
  style : @pagelayout.StrokeStyle,
  alpha : Double,
) -> Unit {
  match style.width {
    Width(width) => sb.write_string(" stroke-width=\"\{num(width)}\"")
    Hairline =>
      sb.write_string(
        " stroke-width=\"1\" vector-effect=\"non-scaling-stroke\"",
      )
  }
  match style.cap {
    ButtCap => ()
    RoundCap => sb.write_string(" stroke-linecap=\"round\"")
    SquareCap => sb.write_string(" stroke-linecap=\"square\"")
  }
  match style.join {
    MiterJoin => ()
    RoundJoin => sb.write_string(" stroke-linejoin=\"round\"")
    BevelJoin => sb.write_string(" stroke-linejoin=\"bevel\"")
  }
  if style.miter_limit != 4.0 {
    sb.write_string(" stroke-miterlimit=\"\{num(style.miter_limit)}\"")
  }
  if !style.dash.is_empty() {
    sb.write_string(" stroke-dasharray=\"\{style.dash.map(num).join(" ")}\"")
    if style.dash_phase != 0.0 {
      sb.write_string(" stroke-dashoffset=\"\{num(style.dash_phase)}\"")
    }
  }
  if alpha != 1.0 {
    sb.write_string(" stroke-opacity=\"\{num(alpha)}\"")
  }
}

///|
/// A path as `<path>`, its fill and stroke `fill_alpha` and `stroke_alpha`
/// opaque.
fn emit_path(
  sb : StringBuilder,
  path : @pagelayout.PathItem,
  defs : Defs,
  fill_alpha : Double,
  stroke_alpha : Double,
  ctm : @pagelayout.Matrix,
) -> Unit {
  let fill = match path.fill {
    Some(paint) => paint_attr(sb, paint, defs, ctm)
    None => "none"
  }
  let stroke = path.stroke.map(paint => paint_attr(sb, paint, defs, ctm))
  sb.write_string("  <path d=\"\{path_data(path.segments)}\" fill=\"\{fill}\"")
  if path.fill is Some(_) && path.fill_rule is EvenOdd {
    sb.write_string(" fill-rule=\"evenodd\"")
  }
  if fill_alpha != 1.0 {
    sb.write_string(" fill-opacity=\"\{num(fill_alpha)}\"")
  }
  match stroke {
    Some(stroke) => {
      sb.write_string(" stroke=\"\{stroke}\"")
      write_stroke_style(sb, path.stroke_style, stroke_alpha)
    }
    None => ()
  }
  sb.write_string("/>\n")
}

///|
fn emit_graphic(
  sb : StringBuilder,
  model : @pagelayout.PageModel,
  graphic : @pagelayout.GraphicItem,
  defs : Defs,
) -> Unit {
  sb.write_string(
    "  <g transform=\"translate(\{num(graphic.x_pt)} \{num(graphic.y_pt)})\">\n",
  )
  // per Save level: the groups opened at that level, the alphas, and the
  // transformation from the graphic's space (scaled as the page)
  let mut open = 0
  let mut fill_alpha = 1.0
  let mut stroke_alpha = 1.0
  let mut ctm = @pagelayout.identity
  let stack : Array[(Int, Double, Double, @pagelayout.Matrix)] = []
  for op in graphic.ops {
    match op {
      Save => {
        stack.push((open, fill_alpha, stroke_alpha, ctm))
        open = 0
      }
      Restore =>
        match stack.pop() {
          Some((outer, fill, stroke, saved)) => {
            for _ in 0..<open {
              sb.write_string("  </g>\n")
            }
            open = outer
            fill_alpha = fill
            stroke_alpha = stroke
            ctm = saved
          }
          None => ()
        }
      Transform(m) => {
        sb.write_string("  <g transform=\"\{matrix_attr(m)}\">\n")
        open += 1
        ctm = ctm.after(m)
      }
      Clip(segments, rule) => {
        let id = defs.next("c")
        let clip_rule = match rule {
          NonZero => "nonzero"
          EvenOdd => "evenodd"
        }
        sb.write_string(
          "  <clipPath id=\"\{id}\"><path d=\"\{path_data(segments)}\" clip-rule=\"\{clip_rule}\"/></clipPath>\n",
        )
        sb.write_string("  <g clip-path=\"url(#\{id})\">\n")
        open += 1
      }
      Alpha(fill, stroke) => {
        fill_alpha = fill
        stroke_alpha = stroke
      }
      // a non-scaling stroke's dashes are measured in the host's space, not
      // the graphic's (in device pixels by some renderers, CSS pixels by
      // others), so a dashed hairline is drawn dashed already: a fill of
      // its own, then its dashes as a solid hairline
      Path(path) if path.stroke is Some(_) &&
        path.stroke_style.width is Hairline &&
        !path.stroke_style.dash.is_empty() => {
        let style = path.stroke_style
        if path.fill is Some(_) {
          emit_path(
            sb,
            { ..path, stroke: None, },
            defs,
            fill_alpha,
            stroke_alpha,
            ctm,
          )
        }
        emit_path(
          sb,
          {
            ..path,
            segments: dashed(path.segments, style.dash, style.dash_phase),
            fill: None,
            stroke_style: { ..style, dash: [], dash_phase: 0, },
          },
          defs,
          fill_alpha,
          stroke_alpha,
          ctm,
        )
      }
      Path(path) => emit_path(sb, path, defs, fill_alpha, stroke_alpha, ctm)
      Text(run) | PaintedText(run, _) => {
        // the paint goes on the text itself: its fill in the run's colour
        // (or none), its outline, each with its own opacity
        let paint = StringBuilder()
        let (filled, outline) = match op {
          PaintedText(_, paint) =>
            (paint.fill, paint.stroke.map(c => (c, paint.stroke_style)))
          _ => (true, None)
        }
        if filled {
          paint.write_string(" fill=\"\{run.color.to_hex()}\"")
          if fill_alpha != 1.0 {
            paint.write_string(" fill-opacity=\"\{num(fill_alpha)}\"")
          }
        } else {
          paint.write_string(" fill=\"none\"")
        }
        match outline {
          Some((color, style)) => {
            paint.write_string(" stroke=\"\{color.to_hex()}\"")
            write_stroke_style(paint, style, stroke_alpha)
          }
          None => ()
        }
        emit_text(sb, model, run, paint=paint.to_string(), num~)
      }
      Image(image) => {
        if fill_alpha != 1.0 {
          sb.write_string("  <g opacity=\"\{num(fill_alpha)}\">\n")
        }
        emit_image(sb, image, num~, fill=true)
        if fill_alpha != 1.0 {
          sb.write_string("  </g>\n")
        }
      }
    }
  }
  // close whatever an unbalanced graphic left open
  while stack.pop() is Some((outer, _, _, _)) {
    for _ in 0..<open {
      sb.write_string("  </g>\n")
    }
    open = outer
  }
  for _ in 0..<open {
    sb.write_string("  </g>\n")
  }
  sb.write_string("  </g>\n")
}
