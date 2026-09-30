///|
// Vector graphics (`GraphicItem`) to SVG. A graphic becomes a group
// translated to its origin; `Save`/`Restore` bracket nested groups, and a
// transformation or a clip opens one more group that the matching
// `Restore` (or the graphic's end) closes. Alphas become fill and stroke
// opacities on what follows them, gradients `<linearGradient>` and
// `<radialGradient>` definitions in user space. Clip, gradient ids count up
// from `ids` so they stay unique on the page.

///|
fn path_data(segments : Array[@pagelayout.PathSegment]) -> String {
  let parts : Array[String] = []
  for segment in segments {
    match segment {
      MoveTo(x, y) => parts.push("M\{fmt_num(x)} \{fmt_num(y)}")
      LineTo(x, y) => parts.push("L\{fmt_num(x)} \{fmt_num(y)}")
      CurveTo(x1, y1, x2, y2, x, y) =>
        parts.push(
          "C\{fmt_num(x1)} \{fmt_num(y1)} \{fmt_num(x2)} \{fmt_num(y2)} \{fmt_num(x)} \{fmt_num(y)}",
        )
      // the winding of PDF's `re` (see the PDF backend)
      Rectangle(x, y, w, h) =>
        parts.push(
          "M\{fmt_num(x)} \{fmt_num(y + h)}h\{fmt_num(w)}v\{fmt_num(-h)}h\{fmt_num(-w)}Z",
        )
      Close => parts.push("Z")
    }
  }
  parts.join("")
}

///|
fn matrix_attr(m : @pagelayout.Matrix) -> String {
  "matrix(\{fmt_num(m.a)} \{fmt_num(m.b)} \{fmt_num(m.c)} \{fmt_num(m.d)} \{fmt_num(m.e)} \{fmt_num(m.f)})"
}

///|
/// The value of a `fill` or `stroke` attribute for `paint`, writing a
/// gradient's definition first.
fn paint_attr(
  sb : StringBuilder,
  paint : @pagelayout.Paint,
  ids : Ref[Int],
) -> String {
  match paint {
    Solid(color) => color.to_hex()
    GradientPaint(g) => {
      ids.val += 1
      let id = "g\{ids.val}"
      if g.radial {
        sb.write_string(
          "  <radialGradient id=\"\{id}\" gradientUnits=\"userSpaceOnUse\" gradientTransform=\"\{matrix_attr(g.transform)}\" fx=\"\{fmt_num(g.x1)}\" fy=\"\{fmt_num(g.y1)}\" fr=\"\{fmt_num(g.r1)}\" cx=\"\{fmt_num(g.x2)}\" cy=\"\{fmt_num(g.y2)}\" r=\"\{fmt_num(g.r2)}\">\n",
        )
      } else {
        sb.write_string(
          "  <linearGradient id=\"\{id}\" gradientUnits=\"userSpaceOnUse\" gradientTransform=\"\{matrix_attr(g.transform)}\" x1=\"\{fmt_num(g.x1)}\" y1=\"\{fmt_num(g.y1)}\" x2=\"\{fmt_num(g.x2)}\" y2=\"\{fmt_num(g.y2)}\">\n",
        )
      }
      for stop in g.stops {
        sb.write_string(
          "    <stop offset=\"\{fmt_num(stop.offset)}\" stop-color=\"\{stop.color.to_hex()}\"/>\n",
        )
      }
      sb.write_string(
        if g.radial {
          "  </radialGradient>\n"
        } else {
          "  </linearGradient>\n"
        },
      )
      "url(#\{id})"
    }
  }
}

///|
fn emit_graphic(
  sb : StringBuilder,
  model : @pagelayout.PageModel,
  graphic : @pagelayout.GraphicItem,
  ids : Ref[Int],
) -> Unit {
  sb.write_string(
    "  <g transform=\"translate(\{fmt_num(graphic.x_pt)} \{fmt_num(graphic.y_pt)})\">\n",
  )
  // per Save level: the groups opened at that level, and the alphas
  let mut open = 0
  let mut fill_alpha = 1.0
  let mut stroke_alpha = 1.0
  let stack : Array[(Int, Double, Double)] = []
  for op in graphic.ops {
    match op {
      Save => {
        stack.push((open, fill_alpha, stroke_alpha))
        open = 0
      }
      Restore =>
        match stack.pop() {
          Some((outer, fill, stroke)) => {
            for _ in 0..<open {
              sb.write_string("  </g>\n")
            }
            open = outer
            fill_alpha = fill
            stroke_alpha = stroke
          }
          None => ()
        }
      Transform(m) => {
        sb.write_string("  <g transform=\"\{matrix_attr(m)}\">\n")
        open += 1
      }
      Clip(segments, rule) => {
        ids.val += 1
        let id = "c\{ids.val}"
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
      Path(path) => {
        let fill = match path.fill {
          Some(paint) => paint_attr(sb, paint, ids)
          None => "none"
        }
        let stroke = path.stroke.map(paint => paint_attr(sb, paint, ids))
        sb.write_string(
          "  <path d=\"\{path_data(path.segments)}\" fill=\"\{fill}\"",
        )
        if path.fill is Some(_) && path.fill_rule is EvenOdd {
          sb.write_string(" fill-rule=\"evenodd\"")
        }
        if fill_alpha != 1.0 {
          sb.write_string(" fill-opacity=\"\{fmt_num(fill_alpha)}\"")
        }
        match stroke {
          Some(stroke) => {
            let style = path.stroke_style
            sb.write_string(
              " stroke=\"\{stroke}\" stroke-width=\"\{fmt_num(style.width)}\"",
            )
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
              sb.write_string(
                " stroke-miterlimit=\"\{fmt_num(style.miter_limit)}\"",
              )
            }
            if !style.dash.is_empty() {
              sb.write_string(
                " stroke-dasharray=\"\{style.dash.map(fmt_num).join(" ")}\"",
              )
              if style.dash_phase != 0.0 {
                sb.write_string(
                  " stroke-dashoffset=\"\{fmt_num(style.dash_phase)}\"",
                )
              }
            }
            if stroke_alpha != 1.0 {
              sb.write_string(" stroke-opacity=\"\{fmt_num(stroke_alpha)}\"")
            }
          }
          None => ()
        }
        sb.write_string("/>\n")
      }
      Text(run) => {
        if fill_alpha != 1.0 {
          sb.write_string("  <g opacity=\"\{fmt_num(fill_alpha)}\">\n")
        }
        emit_text(sb, model, run)
        if fill_alpha != 1.0 {
          sb.write_string("  </g>\n")
        }
      }
      PaintedText(run, paint) => {
        // a group carries the paint: the run's own `fill` is its colour
        let fill = if paint.fill { "" } else { " fill-opacity=\"0\"" }
        let stroke = match paint.stroke {
          Some(color) =>
            " stroke=\"\{color.to_hex()}\" stroke-width=\"\{fmt_num(paint.stroke_width)}\""
          None => ""
        }
        let opacity = if fill_alpha != 1.0 {
          " opacity=\"\{fmt_num(fill_alpha)}\""
        } else {
          ""
        }
        sb.write_string("  <g\{fill}\{stroke}\{opacity}>\n")
        emit_text(sb, model, run)
        sb.write_string("  </g>\n")
      }
      Image(image) => {
        if fill_alpha != 1.0 {
          sb.write_string("  <g opacity=\"\{fmt_num(fill_alpha)}\">\n")
        }
        emit_image(sb, image)
        if fill_alpha != 1.0 {
          sb.write_string("  </g>\n")
        }
      }
    }
  }
  // close whatever an unbalanced graphic left open
  while stack.pop() is Some((outer, _, _)) {
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
