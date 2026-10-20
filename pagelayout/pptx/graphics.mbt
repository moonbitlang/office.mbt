///|
fn color(
  context : SlideContext,
  source : @oxml.Color,
) -> (@pagelayout.Color, Double) raise {
  let rgb = match source.base {
    Srgb(rgb) => rgb
    Hsl(hsl) => hsl.to_rgb()
    Sys(system) => system.last_clr.unwrap_or(@units.RgbColor::new(0, 0, 0))
    Scheme(slot) => {
      guard context.theme is Some(theme) else {
        raise InvalidPresentation("theme color without a theme")
      }
      let slot = context.mapping
        .bind(mapping => mapping.resolve(slot))
        .unwrap_or(slot)
      let resolved = @slide_master.lookup_theme_slot(slot, theme.color_scheme)
      let (rgb, _) = color(context, resolved)
      @units.RgbColor::new(rgb.r, rgb.g, rgb.b)
    }
    Preset(name) =>
      match name {
        "black" => @units.RgbColor::new(0, 0, 0)
        "white" => @units.RgbColor::new(255, 255, 255)
        "red" => @units.RgbColor::new(255, 0, 0)
        _ => raise Unsupported("preset color \{name}")
      }
    Scrgb(r, g, b) =>
      @units.RgbColor::new(
        (r.value() * 2.55).to_int(),
        (g.value() * 2.55).to_int(),
        (b.value() * 2.55).to_int(),
      )
  }
  let mut r = rgb.r.to_double()
  let mut g = rgb.g.to_double()
  let mut b = rgb.b.to_double()
  let mut alpha = 1.0
  for transform in source.transforms {
    match transform {
      Alpha(percent) => alpha *= percent.value() / 100.0
      Tint(percent) => {
        let factor = percent.value() / 100.0
        r = 255.0 - (255.0 - r) * factor
        g = 255.0 - (255.0 - g) * factor
        b = 255.0 - (255.0 - b) * factor
      }
      Shade(percent) => {
        let factor = percent.value() / 100.0
        r *= factor
        g *= factor
        b *= factor
      }
      LumMod(percent) => {
        let hsl = @units.RgbColor::new(r.to_int(), g.to_int(), b.to_int()).to_hsl()
        let updated = @units.HslColor::new(
          hsl.hue,
          hsl.saturation,
          hsl.lightness * percent.value() / 100.0,
        ).to_rgb()
        r = updated.r.to_double()
        g = updated.g.to_double()
        b = updated.b.to_double()
      }
      SatMod(percent) => {
        let hsl = @units.RgbColor::new(r.to_int(), g.to_int(), b.to_int()).to_hsl()
        let updated = @units.HslColor::new(
          hsl.hue,
          hsl.saturation * percent.value() / 100.0,
          hsl.lightness,
        ).to_rgb()
        r = updated.r.to_double()
        g = updated.g.to_double()
        b = updated.b.to_double()
      }
    }
  }
  (
    @pagelayout.Color::rgb(
      (r + 0.5).to_int().clamp(min=0, max=255),
      (g + 0.5).to_int().clamp(min=0, max=255),
      (b + 0.5).to_int().clamp(min=0, max=255),
    ),
    alpha,
  )
}

///|
fn fill_color(
  context : SlideContext,
  fill : @oxml.Fill,
) -> (@pagelayout.Color, Double)? raise {
  match fill {
    NoFill => None
    SolidFill(source) => Some(color(context, source))
    _ => raise Unsupported("non-solid shape fill")
  }
}

///|
fn paint_path(
  context : SlideContext,
  ops : Array[@pagelayout.GraphicOp],
  segments : Array[@pagelayout.PathSegment],
  fill : @oxml.Fill?,
  stroke : @oxml.Stroke?,
) -> Unit raise {
  let fill = match fill {
    Some(fill) => fill_color(context, fill)
    None => None
  }
  let stroke_color = match stroke {
    Some(stroke) =>
      match stroke.fill {
        Some(fill) => fill_color(context, fill)
        None => None
      }
    None => None
  }
  if fill is None && stroke_color is None {
    return
  }
  let width = stroke.bind(stroke => stroke.width).map(emu).unwrap_or(1.0)
  if stroke.bind(stroke => stroke.compound) is Some(kind) && kind != CmpdSingle {
    raise Unsupported("compound line in \{context.part}")
  }
  if stroke.bind(stroke => stroke.head_end) is Some(end) &&
    end.arrow_type != ArrowNone {
    raise Unsupported("line arrowhead in \{context.part}")
  }
  if stroke.bind(stroke => stroke.tail_end) is Some(end) &&
    end.arrow_type != ArrowNone {
    raise Unsupported("line arrowhead in \{context.part}")
  }
  let cap = match stroke.bind(stroke => stroke.cap) {
    Some(CapRound) => @pagelayout.LineCap::RoundCap
    Some(CapSquare) => SquareCap
    _ => ButtCap
  }
  let join = match stroke.bind(stroke => stroke.join) {
    Some(JoinRound) => @pagelayout.LineJoin::RoundJoin
    Some(JoinBevel) => BevelJoin
    _ => MiterJoin
  }
  let miter_limit = match stroke.bind(stroke => stroke.join) {
    Some(JoinMiter(Some(limit))) => limit.value() / 100.0
    _ => 10.0
  }
  let dash = match stroke.bind(stroke => stroke.dash) {
    None | Some(DashSolid) => []
    Some(_) => raise Unsupported("preset line dash pattern in \{context.part}")
  }
  ops.push(
    Alpha(
      fill.map(pair => pair.1).unwrap_or(1.0),
      stroke_color.map(pair => pair.1).unwrap_or(1.0),
    ),
  )
  ops.push(
    Path({
      segments,
      fill: fill.map(pair => Solid(pair.0)),
      stroke: stroke_color.map(pair => Solid(pair.0)),
      stroke_style: {
        width: Width(width),
        cap,
        join,
        miter_limit,
        dash,
        dash_phase: 0.0,
      },
      fill_rule: NonZero,
    }),
  )
}

///|
fn paint_rectangle(
  context : SlideContext,
  ops : Array[@pagelayout.GraphicOp],
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  fill : @oxml.Fill,
  stroke : @oxml.Stroke?,
) -> Unit raise {
  paint_path(context, ops, [Rectangle(x, y, width, height)], Some(fill), stroke)
}

///|
fn begin_transform(
  ops : Array[@pagelayout.GraphicOp],
  transform : @slide.Transform,
) -> (Double, Double) {
  let x = emu(transform.offset.x)
  let y = emu(transform.offset.y)
  let width = emu(transform.extent.cx)
  let height = emu(transform.extent.cy)
  let radians = transform.rotation.map(angle => angle.degrees()).unwrap_or(0.0) *
    @math.PI /
    180.0
  let cos = @math.cos(radians)
  let sin = @math.sin(radians)
  let sx = if transform.flip_h { -1.0 } else { 1.0 }
  let sy = if transform.flip_v { -1.0 } else { 1.0 }
  ops.push(Save)
  ops.push(
    Transform({
      a: cos * sx,
      b: sin * sx,
      c: -sin * sy,
      d: cos * sy,
      e: x + width / 2.0 - cos * sx * width / 2.0 + sin * sy * height / 2.0,
      f: y + height / 2.0 - sin * sx * width / 2.0 - cos * sy * height / 2.0,
    }),
  )
  (width, height)
}

///|
fn draw_shape(
  context : SlideContext,
  shape : @slide.Shape,
  ops : Array[@pagelayout.GraphicOp],
) -> Unit raise {
  match shape {
    AutoShape(shape) => {
      if shape.effects is Some(effects) && effects != @oxml.EffectList::empty() {
        raise Unsupported(
          "shape effects in \{context.part}, object \{shape.id}",
        )
      }
      guard shape.transform is Some(transform) else {
        raise InvalidPresentation("shape \{shape.id} has no position")
      }
      let (width, height) = begin_transform(ops, transform)
      let segments : Array[@pagelayout.PathSegment] = match shape.geometry {
        None | Some(Preset(Rect, _)) => [Rectangle(0, 0, width, height)]
        Some(Preset(Line, _)) => [MoveTo(0, 0), LineTo(width, height)]
        _ =>
          raise Unsupported(
            "shape geometry in \{context.part}, object \{shape.id}",
          )
      }
      paint_path(context, ops, segments, shape.fill, shape.stroke)
      if shape.text_body is Some(body) {
        draw_text(context, body, width, height, ops)
      }
      ops.push(Restore)
    }
    Picture(picture) => {
      if picture.effects is Some(effects) &&
        effects != @oxml.EffectList::empty() {
        raise Unsupported(
          "picture effects in \{context.part}, object \{picture.id}",
        )
      }
      guard picture.transform is Some(transform) else {
        raise InvalidPresentation("picture has no position")
      }
      let (width, height) = begin_transform(ops, transform)
      match picture.geometry {
        None | Some(Preset(Rect, _)) => ()
        _ => raise Unsupported("picture clipping geometry in \{context.part}")
      }
      let fill = picture.blip_fill
      if fill.fill_mode is Tile(_) {
        raise Unsupported("tiled picture in \{context.part}")
      }
      guard relationships(context.pkg, context.part).by_id(fill.embed_id)
        is Some(rel) &&
        rel.target_mode == Internal else {
        raise InvalidPresentation(
          "picture relationship \{fill.embed_id} is missing",
        )
      }
      let image = context.pkg.require_part(
        @opc.resolve_target(context.part, rel.target, Internal),
      )
      let crop = fill.src_rect
      let left = crop.map(crop => crop.left.value() / 100.0).unwrap_or(0.0)
      let top = crop.map(crop => crop.top.value() / 100.0).unwrap_or(0.0)
      let right = crop.map(crop => crop.right.value() / 100.0).unwrap_or(0.0)
      let bottom = crop.map(crop => crop.bottom.value() / 100.0).unwrap_or(0.0)
      guard 1.0 - left - right > 0 && 1.0 - top - bottom > 0 else {
        raise InvalidPresentation("invalid picture crop")
      }
      let scaled_w = width / (1.0 - left - right)
      let scaled_h = height / (1.0 - top - bottom)
      ops.push(Save)
      ops.push(Clip([Rectangle(0, 0, width, height)], NonZero))
      ops.push(Alpha(1, 1))
      ops.push(
        Image({
          x_pt: -scaled_w * left,
          y_pt: -scaled_h * top,
          w_pt: scaled_w,
          h_pt: scaled_h,
          data: Bytes::from_array(image.bytes()),
          mime: image.content_type,
        }),
      )
      ops.push(Restore)
      paint_path(
        context,
        ops,
        [Rectangle(0, 0, width, height)],
        None,
        picture.stroke,
      )
      ops.push(Restore)
    }
    Group(group) => {
      guard group.transform is Some(transform) else {
        raise InvalidPresentation("group has no position")
      }
      let (width, height) = begin_transform(ops, transform)
      let origin = group.child_offset.unwrap_or({ x: Emu(0L), y: Emu(0L), })
      let extent = group.child_extent.unwrap_or(transform.extent)
      let sx = if emu(extent.cx) != 0 { width / emu(extent.cx) } else { 1.0 }
      let sy = if emu(extent.cy) != 0 { height / emu(extent.cy) } else { 1.0 }
      ops.push(
        Transform({
          a: sx,
          b: 0,
          c: 0,
          d: sy,
          e: -emu(origin.x) * sx,
          f: -emu(origin.y) * sy,
        }),
      )
      for shape in group.children {
        draw_shape(context, shape, ops)
      }
      ops.push(Restore)
    }
    _ => raise Unsupported("unimplemented shape in \{context.part}")
  }
}
