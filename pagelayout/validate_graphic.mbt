///|
/// Neither NaN nor infinite.
fn finite(v : Double) -> Bool {
  v - v == 0.0
}

///|
fn finite_matrix(m : Matrix) -> Bool {
  finite(m.a) &&
  finite(m.b) &&
  finite(m.c) &&
  finite(m.d) &&
  finite(m.e) &&
  finite(m.f)
}

///|
/// A path's invariants: its coordinates are finite, and `LineTo`,
/// `CurveTo` and `Close` come after a segment that leaves a current point
/// (a `MoveTo` or `Rectangle`; after those, every segment does), as PDF's
/// path operators require and SVG's path data grammar does.
fn check_segments(
  violations : Array[String],
  where_ : String,
  segments : Array[PathSegment],
) -> Unit {
  let mut current = false
  let mut reported_coordinates = false
  for i, segment in segments {
    let (numbers, needs_current, name) : (Array[Double], Bool, String) = match
      segment {
      MoveTo(x, y) => ([x, y], false, "MoveTo")
      LineTo(x, y) => ([x, y], true, "LineTo")
      CurveTo(x1, y1, x2, y2, x, y) => ([x1, y1, x2, y2, x, y], true, "CurveTo")
      Rectangle(x, y, w, h) => ([x, y, w, h], false, "Rectangle")
      Close => ([], true, "Close")
    }
    if needs_current && !current {
      violations.push(
        "\{where_}: segment \{i} (\{name}) without a current point",
      )
    }
    current = true
    if !reported_coordinates && !numbers.iter().all(finite) {
      violations.push("\{where_}: non-finite path coordinate")
      reported_coordinates = true
    }
  }
}

///|
/// A paint's invariants: a colour's channels are in range; a gradient's
/// geometry and transformation are finite, its radii non-negative, and it
/// has at least two stops, at offsets within 0..=1 in ascending order from
/// 0 to 1.
fn check_paint(
  violations : Array[String],
  where_ : String,
  paint : Paint,
) -> Unit {
  match paint {
    Solid(color) => check_color(violations, where_, color)
    GradientPaint(gradient) => {
      let geometry = match gradient.shape {
        Linear(x1~, y1~, x2~, y2~) => [x1, y1, x2, y2]
        Radial(x1~, y1~, r1~, x2~, y2~, r2~) => {
          if r1 < 0.0 || r2 < 0.0 {
            violations.push("\{where_}: negative gradient radius")
          }
          [x1, y1, r1, x2, y2, r2]
        }
      }
      if !geometry.iter().all(finite) || !finite_matrix(gradient.transform) {
        violations.push("\{where_}: non-finite gradient geometry")
      }
      let stops = gradient.stops
      if stops.length() < 2 {
        violations.push("\{where_}: gradient with fewer than two stops")
        return
      }
      if stops.iter().any(stop => !(stop.offset >= 0.0 && stop.offset <= 1.0)) {
        violations.push("\{where_}: gradient stop offset outside 0..=1")
      } else if stops[0].offset != 0.0 ||
        stops[stops.length() - 1].offset != 1.0 {
        violations.push("\{where_}: gradient stops do not span 0 to 1")
      }
      let mut ordered = true
      for i, stop in stops {
        check_color(violations, where_, stop.color)
        if i > 0 && stop.offset < stops[i - 1].offset {
          ordered = false
        }
      }
      if !ordered {
        violations.push("\{where_}: gradient stops out of order")
      }
    }
  }
}

///|
/// A stroke style's invariants: a `Width` is positive and finite (a
/// hairline is `Hairline`, not width 0, on which PDF and SVG disagree);
/// the miter limit is a finite number from 1; the dash is either empty (a
/// solid line) or finite, non-negative lengths at least one of which is
/// positive (PDF 32000-1, 8.4.3.6), and its phase is finite.
fn check_stroke_style(
  violations : Array[String],
  where_ : String,
  style : StrokeStyle,
) -> Unit {
  if style.width is Width(width) && !(width > 0.0 && finite(width)) {
    violations.push("\{where_}: stroke width not positive and finite")
  }
  if !(style.miter_limit >= 1.0 && finite(style.miter_limit)) {
    violations.push("\{where_}: miter limit not a finite number from 1")
  }
  if style.dash.iter().any(d => !(d >= 0.0 && finite(d))) {
    violations.push("\{where_}: dash length negative or non-finite")
  } else if !style.dash.is_empty() && !style.dash.iter().any(d => d > 0.0) {
    violations.push("\{where_}: dash without a positive length")
  }
  if !finite(style.dash_phase) {
    violations.push("\{where_}: non-finite dash phase")
  }
}

///|
/// The invariants of a graphic: its origin is finite; `Save` and `Restore`
/// balance (never more restores than saves so far, as many in all);
/// transformations are finite; paths and clips are well-formed (see
/// `check_segments`); alphas are within 0..=1; the strokes painted are
/// valid (see `check_stroke_style`), and text is not outlined with a
/// dashed hairline; every paint is valid (`check_paint`); glyph runs and
/// images are well-formed as page items are, and placed at finite
/// positions.
fn PageModel::check_graphic(
  self : PageModel,
  violations : Array[String],
  where_ : String,
  graphic : GraphicItem,
) -> Unit {
  if !(finite(graphic.x_pt) && finite(graphic.y_pt)) {
    violations.push("\{where_}: non-finite graphic origin")
  }
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
      Transform(m) =>
        if !finite_matrix(m) {
          violations.push("\{at}: non-finite transformation")
        }
      Clip(segments, _) => check_segments(violations, at, segments)
      Alpha(fill, stroke) =>
        if !(fill >= 0.0 && fill <= 1.0 && stroke >= 0.0 && stroke <= 1.0) {
          violations.push("\{at}: alpha outside 0..=1")
        }
      Path(path) => {
        check_segments(violations, at, path.segments)
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
                // SVG can dash a path's hairline in the graphic's space
                // only by drawing the dashes itself, which it cannot do
                // to glyph outlines (see `StrokeWidth`)
                if paint.stroke_style.width is Hairline &&
                  !paint.stroke_style.dash.is_empty() {
                  violations.push("\{at}: dashed hairline outlining text")
                }
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
        if !finite(run.size_pt) {
          violations.push("\{at}: non-finite font size")
        } else if run.size_pt <= 0 {
          violations.push("\{at}: non-positive font size")
        }
        if !(finite(run.x_pt) &&
          finite(run.baseline_pt) &&
          run.advances_pt.iter().all(finite)) {
          violations.push("\{at}: non-finite glyph run position or advance")
        }
        check_color(violations, at, run.color)
      }
      Image(image) => {
        if !(finite(image.x_pt) &&
          finite(image.y_pt) &&
          finite(image.w_pt) &&
          finite(image.h_pt)) {
          violations.push("\{at}: non-finite image rectangle")
        } else if image.w_pt <= 0 || image.h_pt <= 0 {
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
