// A low-level abstraction over a single content stream (port of krilla's
// `content` module).

///|
/// A content stream writer.
priv struct Content {
  buf : @buffer.Buffer
  mut depth : Int
}

///|
fn Content::new() -> Content {
  { buf: @buffer.new(), depth: 0 }
}

///|
fn Content::raw(self : Content, s : String) -> Unit {
  for c in s {
    self.buf.write_byte(c.to_int().to_byte())
  }
}

///|
fn Content::num(self : Content, v : Double) -> Unit {
  self.raw(format_real(v))
  self.buf.write_byte(b' ')
}

///|
fn Content::op(self : Content, name : String) -> Unit {
  self.raw(name)
  self.buf.write_byte(b'\n')
}

///|
fn Content::name(self : Content, name : String) -> Unit {
  write_name(self.buf, name)
  self.buf.write_byte(b' ')
}

///|
fn Content::obj(self : Content, o : Obj) -> Unit {
  write_obj(self.buf, o)
  self.buf.write_byte(b' ')
}

///|
fn Content::save_state(self : Content) -> Unit {
  self.depth += 1
  self.op("q")
}

///|
fn Content::restore_state(self : Content) -> Unit {
  self.depth -= 1
  self.op("Q")
}

///|
fn Content::transform(self : Content, ts : Transform) -> Unit {
  self.num(ts.sx)
  self.num(ts.ky)
  self.num(ts.kx)
  self.num(ts.sy)
  self.num(ts.tx)
  self.num(ts.ty)
  self.op("cm")
}

///|
fn Content::set_parameters(self : Content, name : String) -> Unit {
  self.name(name)
  self.op("gs")
}

///|
fn Content::finish(self : Content) -> Bytes {
  self.buf.to_bytes()
}

///|
/// Stores either a device color space or the name of a color space in the
/// current resource dictionary.
priv enum ContentColorSpace {
  Device
  Named(String)
}

///|
/// A builder for a single content stream.
priv struct ContentBuilder {
  rd : ResourceDictionary
  content : Content
  validation_errors : Array[ValidationError]
  root_transform : Transform
  graphics_states : GraphicsStates
  mut bbox : Rect?
  mut uses_mask : Bool
  bbox_important : Bool
  mut active_marked_content : Bool
}

///|
fn ContentBuilder::new(
  root_transform : Transform,
  bbox_important : Bool,
) -> ContentBuilder {
  {
    rd: ResourceDictionary::new(),
    content: Content::new(),
    validation_errors: [],
    root_transform,
    graphics_states: GraphicsStates::new(),
    bbox: None,
    uses_mask: false,
    bbox_important,
    active_marked_content: false,
  }
}

///|
fn ContentBuilder::content_save_state(self : ContentBuilder) -> Unit {
  self.content.save_state()
  if self.content.depth > 28 {
    let mut seen = false
    for e in self.validation_errors {
      if e is TooHighQNestingLevel {
        seen = true
      }
    }
    if !seen {
      self.validation_errors.push(TooHighQNestingLevel)
    }
  }
}

///|
fn ContentBuilder::finish(self : ContentBuilder) -> Stream {
  {
    content: self.content.finish(),
    bbox: match self.bbox {
      Some(b) => b
      None => { left: 0.0, top: 0.0, right: 1.0, bottom: 1.0 }
    },
    validation_errors: self.validation_errors,
    resources: self.rd,
    uses_mask: self.uses_mask,
  }
}

///|
fn ContentBuilder::start_marked_content(
  self : ContentBuilder,
  name : String,
) -> Unit {
  if self.active_marked_content {
    abort("can't start marked content twice")
  }
  self.active_marked_content = true
  self.content.name(name)
  self.content.op("BMC")
}

///|
fn ContentBuilder::start_marked_content_with_properties(
  self : ContentBuilder,
  sc : SerializeContext,
  mcid : Int?,
  tag : ContentTag,
) -> Unit {
  if self.active_marked_content {
    abort("can't start marked content twice")
  }
  self.active_marked_content = true
  let props = DictBuilder::new()
  if mcid is Some(id) {
    props.set("MCID", Int(id))
  }
  // The page height is extracted from the root transform.
  tag.write_properties(sc, props, self.root_transform.ty)
  self.content.name(tag.name())
  self.content.obj(props.finish())
  self.content.op("BDC")
}

///|
fn ContentBuilder::end_marked_content(self : ContentBuilder) -> Unit {
  if !self.active_marked_content {
    abort("can't end marked content when none has been started")
  }
  self.content.op("EMC")
  self.active_marked_content = false
}

///|
fn ContentBuilder::concat_transform(self : ContentBuilder, ts : Transform) -> Unit {
  self.graphics_states.transform(ts)
}

///|
fn ContentBuilder::cur_transform(self : ContentBuilder) -> Transform {
  self.graphics_states.cur().ctm
}

///|
fn ContentBuilder::cur_transform_with_root_transform(
  self : ContentBuilder,
) -> Transform {
  self.root_transform.pre_concat(self.cur_transform())
}

///|
fn ContentBuilder::save_graphics_state(self : ContentBuilder) -> Unit {
  self.graphics_states.save_state()
}

///|
fn ContentBuilder::restore_graphics_state(self : ContentBuilder) -> Unit {
  self.graphics_states.restore_state()
}

///|
fn ContentBuilder::set_blend_mode(self : ContentBuilder, mode : String) -> Unit {
  if mode != "Normal" {
    self.graphics_states.combine({ ..ExtGState::new(), blend_mode: Some(mode) })
  }
}

///|
fn ContentBuilder::expand_bbox(self : ContentBuilder, new_bbox : Rect) -> Unit {
  let new_bbox = self.graphics_states.transform_bbox(new_bbox)
  self.bbox = Some(
    match self.bbox {
      Some(b) => b.union(new_bbox)
      None => new_bbox
    },
  )
}

///|
fn ContentBuilder::set_fill_opacity(self : ContentBuilder, alpha : Double) -> Unit {
  if alpha != 1.0 {
    self.graphics_states.combine({
      ..ExtGState::new(),
      non_stroking_alpha: Some(alpha),
    })
  }
}

///|
fn ContentBuilder::set_stroke_opacity(
  self : ContentBuilder,
  alpha : Double,
) -> Unit {
  if alpha != 1.0 {
    self.graphics_states.combine({ ..ExtGState::new(), stroking_alpha: Some(alpha) })
  }
}

///|
/// Wrap an operation in `q`/`Q`, writing the current transform and graphics
/// state first.
fn ContentBuilder::apply_isolated_op(
  self : ContentBuilder,
  sc : SerializeContext,
  prep : (ContentBuilder) -> Unit,
  op : (ContentBuilder) -> Unit,
) -> Unit {
  self.save_graphics_state()
  self.content_save_state()
  prep(self)
  let transform = self.cur_transform_with_root_transform()
  if !transform.is_identity() {
    self.content.transform(transform)
  }
  let state = self.graphics_states.cur().ext_g_state
  if !state.empty() {
    let r = sc.register_ext_g_state(state)
    let name = self.rd.register(ExtGState, r)
    self.content.set_parameters(name)
  }
  op(self)
  self.content.restore_state()
  self.restore_graphics_state()
}

///|
fn ContentBuilder::content_draw_path(self : ContentBuilder, path : Path) -> Unit {
  let mut prev = { x: 0.0, y: 0.0 }
  for seg in path.segments {
    match seg {
      MoveTo(p) => {
        self.content.num(p.x)
        self.content.num(p.y)
        self.content.op("m")
        prev = p
      }
      LineTo(p) => {
        self.content.num(p.x)
        self.content.num(p.y)
        self.content.op("l")
        prev = p
      }
      QuadTo(p1, p2) => {
        // Since PDF doesn't support quad curves, convert them into cubic.
        let calc = (n1 : Double, n2 : Double) => (n1 + n2 * 2.0) / 3.0
        self.content.num(calc(prev.x, p1.x))
        self.content.num(calc(prev.y, p1.y))
        self.content.num(calc(p2.x, p1.x))
        self.content.num(calc(p2.y, p1.y))
        self.content.num(p2.x)
        self.content.num(p2.y)
        self.content.op("c")
        prev = p2
      }
      CubicTo(p1, p2, p3) => {
        self.content.num(p1.x)
        self.content.num(p1.y)
        self.content.num(p2.x)
        self.content.num(p2.y)
        self.content.num(p3.x)
        self.content.num(p3.y)
        self.content.op("c")
        prev = p3
      }
      Close => self.content.op("h")
    }
  }
}

///|
fn ContentBuilder::draw_path(
  self : ContentBuilder,
  sc : SerializeContext,
  path : Path,
  fill : Fill?,
  stroke : Stroke?,
) -> Unit {
  if fill is None && stroke is None {
    return
  }
  guard path.bounds() is Some(bounds) else { return }
  // Zero-size geometry, don't draw.
  if bounds.width() == 0.0 && bounds.height() == 0.0 {
    return
  }
  // See krilla issue 199.
  let is_line = path.segments.length() == 2 &&
    path.segments[0] is MoveTo(_) &&
    path.segments[1] is LineTo(_)
  let dont_fill = bounds.width() == 0.0 || bounds.height() == 0.0 || is_line
  let mut fill = fill
  if dont_fill {
    match stroke {
      // Some PDF viewers have bugs where they slightly fill zero-sized
      // lines, so don't draw them in the first place.
      None => return
      Some(_) => fill = None
    }
  }
  let bbox_important = self.bbox_important
  let stroke_bbox = (stroke : Stroke) => {
    let is_solid = stroke.paint is Color(_)
    if bbox_important || !is_solid {
      calculate_stroke_bbox(stroke, path).unwrap_or(bounds)
    } else {
      bounds
    }
  }
  let fill_prep = (sb : ContentBuilder, fill : Fill) => {
    sb.expand_bbox(bounds)
    // PDF viewers don't show patterns with fill/stroke opacities
    // consistently, so the opacity is accounted for in the pattern itself.
    if !(fill.paint is Pattern(_)) {
      sb.set_fill_opacity(fill.opacity)
    }
  }
  let stroke_prep = (sb : ContentBuilder, stroke : Stroke, sbbox : Rect) => {
    sb.expand_bbox(sbbox)
    if !(stroke.paint is Pattern(_)) {
      sb.set_stroke_opacity(stroke.opacity)
    }
  }
  match (fill, stroke) {
    (Some(fill), None) =>
      self.apply_isolated_op(sc, sb => fill_prep(sb, fill), sb => {
        sb.content_set_fill_properties(sc, bounds, fill)
        sb.content_draw_path(path)
        sb.content.op(if fill.rule == EvenOdd { "f*" } else { "f" })
      })
    (None, Some(stroke)) => {
      let sbbox = stroke_bbox(stroke)
      self.apply_isolated_op(sc, sb => stroke_prep(sb, stroke, sbbox), sb => {
        sb.content_set_stroke_properties(sc, sbbox, stroke)
        sb.content_draw_path(path)
        sb.content.op("S")
      })
    }
    (Some(fill), Some(stroke)) => {
      let sbbox = stroke_bbox(stroke)
      self.apply_isolated_op(
        sc,
        sb => {
          fill_prep(sb, fill)
          stroke_prep(sb, stroke, sbbox)
        },
        sb => {
          sb.content_set_fill_properties(sc, bounds, fill)
          sb.content_set_stroke_properties(sc, sbbox, stroke)
          sb.content_draw_path(path)
          sb.content.op(if fill.rule == EvenOdd { "B*" } else { "B" })
        },
      )
    }
    (None, None) => ()
  }
}

///|
fn ContentBuilder::push_clip_path(
  self : ContentBuilder,
  path : Path,
  rule : FillRule,
) -> Unit {
  self.content_save_state()
  self.content_draw_path(path.transform(self.cur_transform_with_root_transform()))
  self.content.op(if rule == EvenOdd { "W*" } else { "W" })
  self.content.op("n")
}

///|
fn ContentBuilder::pop_clip_path(self : ContentBuilder) -> Unit {
  self.content.restore_state()
}

///|
fn ContentBuilder::draw_xobject(
  self : ContentBuilder,
  sc : SerializeContext,
  x_object : XObject,
  state : ExtGState,
) -> Unit {
  let bbox = x_object.bbox()
  self.apply_isolated_op(
    sc,
    sb => {
      sb.graphics_states.combine(state)
      sb.expand_bbox(bbox)
    },
    sb => {
      let r = sc.register_xobject(x_object)
      let name = sb.rd.register(XObject, r)
      sb.content.name(name)
      sb.content.op("Do")
    },
  )
}

///|
fn ContentBuilder::draw_xobject_by_reference(
  self : ContentBuilder,
  sc : SerializeContext,
  bbox : Rect,
  r : Int,
) -> Unit {
  self.apply_isolated_op(sc, sb => sb.expand_bbox(bbox), sb => {
    let name = sb.rd.register(XObject, r)
    sb.content.name(name)
    sb.content.op("Do")
  })
}

///|
fn ContentBuilder::draw_masked(
  self : ContentBuilder,
  sc : SerializeContext,
  mask : Mask,
  stream : Stream,
) -> Unit {
  let mask_ref = sc.register_mask(mask)
  let state = { ..ExtGState::new(), mask: Some(mask_ref) }
  self.uses_mask = true
  let x_object = XObject::new(stream, false, true, None)
  self.draw_xobject(sc, x_object, state)
}

///|
fn ContentBuilder::draw_opacified(
  self : ContentBuilder,
  sc : SerializeContext,
  opacity : Double,
  stream : Stream,
) -> Unit {
  let state = {
    ..ExtGState::new(),
    stroking_alpha: Some(opacity),
    non_stroking_alpha: Some(opacity),
  }
  let x_object = XObject::new(stream, true, false, None)
  self.draw_xobject(sc, x_object, state)
}

///|
fn ContentBuilder::draw_isolated(
  self : ContentBuilder,
  sc : SerializeContext,
  stream : Stream,
) -> Unit {
  let x_object = XObject::new(stream, true, false, None)
  self.draw_xobject(sc, x_object, ExtGState::new())
}

///|
fn ContentBuilder::draw_image(
  self : ContentBuilder,
  sc : SerializeContext,
  image : Image,
  size : Size,
) -> Unit {
  self.apply_isolated_op(
    sc,
    sb => {
      // Scale the image from 1x1 to the actual dimensions.
      let ts = Transform::from_row(
        size.width,
        0.0,
        0.0,
        -size.height,
        0.0,
        size.height,
      )
      sb.concat_transform(ts)
      sb.expand_bbox({ left: 0.0, top: 0.0, right: 1.0, bottom: 1.0 })
    },
    sb => {
      let r = sc.register_image(image)
      let name = sb.rd.register(XObject, r)
      sb.content.name(name)
      sb.content.op("Do")
    },
  )
}

///|
fn ContentBuilder::draw_shading(
  self : ContentBuilder,
  sc : SerializeContext,
  shading : ShadingFunction,
) -> Unit {
  self.apply_isolated_op(sc, _ => (), sb => {
    let r = sc.register_shading_function(shading)
    let name = sb.rd.register(Shading, r)
    sb.content.name(name)
    sb.content.op("sh")
  })
}

///|
fn ContentBuilder::cs_to_content_cs(
  self : ContentBuilder,
  sc : SerializeContext,
  color : Color,
) -> ContentColorSpace {
  match sc.register_colorspace(color) {
    Some(r) => Named(self.rd.register(ColorSpace, r))
    None => Device
  }
}

///|
fn ContentBuilder::set_solid(
  self : ContentBuilder,
  cs : ContentColorSpace,
  color : Color,
  stroke : Bool,
) -> Unit {
  match cs {
    Device =>
      match color {
        Regular(Rgb(_, _, _) as c) => {
          for v in c.to_pdf_color() {
            self.content.num(v)
          }
          self.content.op(if stroke { "RG" } else { "rg" })
        }
        Regular(Luma(_) as c) => {
          for v in c.to_pdf_color() {
            self.content.num(v)
          }
          self.content.op(if stroke { "G" } else { "g" })
        }
        Regular(Cmyk(_, _, _, _) as c) => {
          for v in c.to_pdf_color() {
            self.content.num(v)
          }
          self.content.op(if stroke { "K" } else { "k" })
        }
        Separation(_, _) =>
          abort("Device color space cannot be used with special colors")
      }
    Named(n) => {
      self.content.name(n)
      self.content.op(if stroke { "CS" } else { "cs" })
      for v in color.to_pdf_color() {
        self.content.num(v)
      }
      self.content.op(if stroke { "SCN" } else { "scn" })
    }
  }
}

///|
fn ContentBuilder::set_pattern(
  self : ContentBuilder,
  name : String,
  stroke : Bool,
) -> Unit {
  self.content.name("Pattern")
  self.content.op(if stroke { "CS" } else { "cs" })
  self.content.name(name)
  self.content.op(if stroke { "SCN" } else { "scn" })
}

///|
fn ContentBuilder::content_set_fill_stroke_properties(
  self : ContentBuilder,
  sc : SerializeContext,
  bounds : Rect,
  paint : Paint,
  opacity : Double,
  stroke : Bool,
) -> Unit {
  let write_gradient = (props : GradientProperties, transform : Transform) => {
    match props.single_stop_color() {
      Some((color, opacity)) => {
        // Write gradients with one stop as a solid color fill.
        self.set_fill_opacity(opacity)
        let cs = self.cs_to_content_cs(sc, color)
        self.set_solid(cs, color, stroke)
      }
      None => {
        let shading_mask = Mask::new_from_shading(sc, props, transform, bounds)
        let pattern = ShadingPattern::new(
          props,
          self.cur_transform_with_root_transform().pre_concat(transform),
        )
        let pr = sc.register_shading_pattern(pattern)
        let name = self.rd.register(Pattern, pr)
        if shading_mask is Some(mask) {
          let mask_ref = sc.register_mask(mask)
          let state = { ..ExtGState::new(), mask: Some(mask_ref) }
          self.uses_mask = true
          let r = sc.register_ext_g_state(state)
          let gs = self.rd.register(ExtGState, r)
          self.content.set_parameters(gs)
        }
        self.set_pattern(name, stroke)
      }
    }
  }
  match paint {
    Color(c) => {
      let cs = self.cs_to_content_cs(sc, c)
      self.set_solid(cs, c, stroke)
    }
    LinearGradient(lg) => {
      let (props, ts) = lg.gradient_properties(bounds)
      write_gradient(props, ts)
    }
    RadialGradient(rg) => {
      let (props, ts) = rg.gradient_properties(bounds)
      write_gradient(props, ts)
    }
    SweepGradient(sg) => {
      let (props, ts) = sg.gradient_properties(bounds)
      write_gradient(props, ts)
    }
    Pattern(pat) => {
      let transform = pat.transform.post_concat(
        self.cur_transform_with_root_transform(),
      )
      let tiling = TilingPattern::new(
        sc,
        pat.stream,
        transform,
        opacity,
        pat.width,
        pat.height,
      )
      let r = sc.register_tiling_pattern(tiling)
      let name = self.rd.register(Pattern, r)
      self.set_pattern(name, stroke)
    }
  }
}

///|
fn ContentBuilder::content_set_fill_properties(
  self : ContentBuilder,
  sc : SerializeContext,
  bounds : Rect,
  fill : Fill,
) -> Unit {
  self.content_set_fill_stroke_properties(
    sc,
    bounds,
    fill.paint,
    fill.opacity,
    false,
  )
}

///|
fn ContentBuilder::content_set_stroke_properties(
  self : ContentBuilder,
  sc : SerializeContext,
  bounds : Rect,
  stroke : Stroke,
) -> Unit {
  self.content_set_fill_stroke_properties(
    sc,
    bounds,
    stroke.paint,
    stroke.opacity,
    true,
  )
  // Only write if they don't correspond to the default values.
  if stroke.width != 1.0 {
    self.content.num(stroke.width)
    self.content.op("w")
  }
  if stroke.miter_limit != 10.0 {
    self.content.num(stroke.miter_limit)
    self.content.op("M")
  }
  if stroke.line_cap != Butt {
    self.content.raw(
      match stroke.line_cap {
        Butt => "0"
        Round => "1"
        Square => "2"
      },
    )
    self.content.op(" J")
  }
  if stroke.line_join != Miter {
    self.content.raw(
      match stroke.line_join {
        Miter => "0"
        Round => "1"
        Bevel => "2"
      },
    )
    self.content.op(" j")
  }
  if stroke.dash is Some(dash) {
    self.content.obj(Arr(dash.array.map(v => Real(v))))
    self.content.num(dash.offset)
    self.content.op("d")
  }
}

///|
/// The bounding box of a stroked path (approximated by expanding the path
/// bounds by half the stroke width, or by the miter length for miter
/// joins).
fn calculate_stroke_bbox(stroke : Stroke, path : Path) -> Rect? {
  guard path.bounds() is Some(b) else { return None }
  let mut w = stroke.width / 2.0
  if stroke.line_join == Miter {
    w = w * @math.maximum(stroke.miter_limit, 1.0)
  }
  if stroke.line_cap == Square {
    w = w * 1.4142135623730951
  }
  Some({
    left: b.left - w,
    top: b.top - w,
    right: b.right + w,
    bottom: b.bottom + w,
  })
}
