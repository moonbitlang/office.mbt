///|
fn check_paint(
  violations : Array[String],
  where_ : String,
  paint : Paint,
) -> Unit {
  match paint {
    Solid(color) => check_color(violations, where_, color)
    GradientPaint(gradient) => {
      let stops = gradient.stops
      if stops.length() < 2 {
        violations.push("\{where_}: gradient with fewer than two stops")
        return
      }
      if stops[0].offset != 0.0 || stops[stops.length() - 1].offset != 1.0 {
        violations.push("\{where_}: gradient stops do not span 0 to 1")
      }
      for i, stop in stops {
        check_color(violations, where_, stop.color)
        if i > 0 && stop.offset < stops[i - 1].offset {
          violations.push("\{where_}: gradient stops out of order")
        }
      }
      if gradient.shape is Radial(r1~, r2~, ..) && (r1 < 0.0 || r2 < 0.0) {
        violations.push("\{where_}: negative gradient radius")
      }
    }
  }
}

///|
/// A stroke style's invariants: a `Width` is positive (a hairline is
/// `Hairline`, not width 0, on which PDF and SVG disagree) and dash lengths
/// are non-negative.
fn check_stroke_style(
  violations : Array[String],
  where_ : String,
  style : StrokeStyle,
) -> Unit {
  if style.width is Width(width) && !(width > 0.0) {
    violations.push("\{where_}: stroke width not positive and finite")
  }
  if style.dash.iter().any(d => d < 0.0) {
    violations.push("\{where_}: negative dash length")
  }
}

///|
/// The invariants of a graphic's ops: `Save` and `Restore` balance (never
/// more restores than saves so far, as many in all), glyph runs and images
/// are well-formed as page items are, alphas are within 0..=1, the
/// strokes painted are valid (see `check_stroke_style`) and so is every
/// paint.
fn PageModel::check_graphic(
  self : PageModel,
  violations : Array[String],
  where_ : String,
  graphic : GraphicItem,
) -> Unit {
  let mut depth = 0
  for i, op in graphic.ops {
    let at = "\{where_} op \{i}"
    match op {
      Save => depth += 1
      Restore => {
        depth -= 1
        if depth < 0 {
          violations.push("\{at}: restore without a save")
          depth = 0
        }
      }
      Transform(_) | Clip(_, _) => ()
      Alpha(fill, stroke) =>
        if fill < 0.0 || fill > 1.0 || stroke < 0.0 || stroke > 1.0 {
          violations.push("\{at}: alpha outside 0..=1")
        }
      Path(path) => {
        match path.fill {
          Some(paint) => check_paint(violations, at, paint)
          None => ()
        }
        match path.stroke {
          Some(paint) => {
            check_paint(violations, at, paint)
            check_stroke_style(violations, at, path.stroke_style)
          }
          None => ()
        }
      }
      Text(run) | PaintedText(run, _) => {
        match op {
          PaintedText(_, paint) =>
            match paint.stroke {
              Some(color) => {
                check_color(violations, at, color)
                check_stroke_style(violations, at, paint.stroke_style)
              }
              None => ()
            }
          _ => ()
        }
        if run.advances_pt.length() != run.text.length() {
          violations.push(
            "\{at}: \{run.advances_pt.length()} advances for \{run.text.length()} UTF-16 code units",
          )
        }
        if run.font < 0 || run.font >= self.fonts.length() {
          violations.push(
            "\{at}: font index \{run.font} outside fonts[0..\{self.fonts.length()}]",
          )
        }
        if run.size_pt <= 0 {
          violations.push("\{at}: non-positive font size")
        }
        check_color(violations, at, run.color)
      }
      Image(image) => {
        if image.w_pt <= 0 || image.h_pt <= 0 {
          violations.push("\{at}: non-positive image extent")
        }
        if image.data.length() == 0 {
          violations.push("\{at}: empty image data")
        }
      }
    }
  }
  if depth != 0 {
    violations.push("\{where_}: \{depth} saves without a restore")
  }
}
