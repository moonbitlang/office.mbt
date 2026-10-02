// XObjects, masks, tiling patterns, shading patterns and shading functions
// (port of krilla's `graphics::{xobject, mask, tiling_pattern,
// shading_pattern, shading_function}`).

///|
/// A form XObject.
priv struct XObject {
  stream : Stream
  isolated : Bool
  transparency_group_color_space : Bool
  custom_bbox : Rect?
}

///|
fn XObject::new(
  stream : Stream,
  isolated : Bool,
  transparency_group_color_space : Bool,
  custom_bbox : Rect?,
) -> XObject {
  // In case a mask was invoked in the content stream, always create a new
  // transparency group (see typst/typst#5509).
  {
    stream,
    isolated,
    transparency_group_color_space: transparency_group_color_space ||
    stream.uses_mask,
    custom_bbox,
  }
}

///|
fn XObject::bbox(self : XObject) -> Rect {
  match self.custom_bbox {
    Some(b) => b
    None => self.stream.bbox
  }
}

///|
fn SerializeContext::register_xobject(
  self : SerializeContext,
  x : XObject,
) -> Int {
  let r = self.new_ref()
  for e in x.stream.validation_errors {
    self.register_validation_error(e)
  }
  let use_group = x.isolated || x.transparency_group_color_space
  if use_group {
    self.register_validation_error(Transparency(self.location))
  }
  let d = DictBuilder::new()
  d.set("Type", Name("XObject"))
  d.set("Subtype", Name("Form"))
  d.set("Resources", x.stream.resources.to_pdf())
  d.set("BBox", x.bbox().to_pdf())
  // A layer with tagged content is a struct parent.
  if x.stream.struct_info is Some((stream_id, num_mcids)) &&
    num_mcids > 0 &&
    self.settings.enable_tagging {
    let sp = self.struct_parents.length()
    self.struct_parents.push(Stream(stream_id, num_mcids))
    self.tag_stream_refs[stream_id] = r
    d.set("StructParents", Int(sp))
  }
  if use_group {
    let g = DictBuilder::new()
    g.set("Type", Name("Group"))
    g.set("S", Name("Transparency"))
    if x.isolated {
      g.set("I", Bool(true))
    }
    g.set("CS", self.regular_color_space_obj(Rgb(0, 0, 0)))
    d.set("Group", g.finish())
  }
  self.put_content_stream(r, d.entries(), x.stream.content)
  r
}

///|
/// A soft mask.
priv struct Mask {
  stream : Stream
  luminosity : Bool
  custom_bbox : Rect?
}

///|
/// A luminosity mask from the opacities of a gradient, if it has
/// translucent stops.
fn Mask::new_from_shading(
  sc : SerializeContext,
  props : GradientProperties,
  shading_transform : Transform,
  bbox : Rect,
) -> Mask? {
  if props.stops().iter().all(s => s.opacity == 1.0) {
    return None
  }
  let shading = ShadingFunction::new(props, true)
  let builder = ContentBuilder::new(Transform::identity(), true)
  builder.save_graphics_state()
  builder.concat_transform(shading_transform)
  builder.draw_shading(sc, shading)
  builder.restore_graphics_state()
  Some({ stream: builder.finish(), luminosity: true, custom_bbox: Some(bbox), })
}

///|
fn SerializeContext::register_mask(self : SerializeContext, mask : Mask) -> Int {
  let x = self.register_xobject(
    XObject::new(mask.stream, false, true, mask.custom_bbox),
  )
  let r = self.new_ref()
  self.put(
    r,
    Dict([
      ("Type", Name("Mask")),
      ("S", Name(if mask.luminosity { "Luminosity" } else { "Alpha" })),
      ("G", Ref(x)),
    ]),
  )
  r
}

///|
/// A tiling pattern.
priv struct TilingPattern {
  stream : Stream
  transform : Transform
  width : Double
  height : Double
}

///|
fn TilingPattern::new(
  sc : SerializeContext,
  stream : Stream,
  transform : Transform,
  base_opacity : Double,
  width : Double,
  height : Double,
) -> TilingPattern {
  // Stroke/fill opacity doesn't work consistently across viewers for
  // patterns, so it is simulated with an opacity group.
  let stream = if base_opacity == 1.0 {
    stream
  } else {
    let builder = ContentBuilder::new(Transform::identity(), true)
    builder.draw_opacified(sc, base_opacity, stream)
    builder.finish()
  }
  { stream, transform, width, height, }
}

///|
fn SerializeContext::register_tiling_pattern(
  self : SerializeContext,
  p : TilingPattern,
) -> Int {
  let r = self.new_ref()
  for e in p.stream.validation_errors {
    self.register_validation_error(e)
  }
  self.put_content_stream(
    r,
    [
      ("Type", Name("Pattern")),
      ("PatternType", Int(1)),
      ("PaintType", Int(1)),
      ("TilingType", Int(1)),
      ("BBox", pdf_rect(0.0, 0.0, p.width, p.height)),
      ("XStep", Real(p.width)),
      ("YStep", Real(p.height)),
      ("Matrix", p.transform.to_pdf()),
      ("Resources", p.stream.resources.to_pdf()),
    ],
    p.stream.content,
  )
  r
}

///|
/// The kind of a PostScript gradient.
priv enum GradientType {
  Sweep
  Linear
} derive(Eq)

///|
/// The properties of a gradient after resolving its spread method.
priv enum GradientProperties {
  RadialAxial(Array[Double], Bool, Array[Stop], Bool) // coords, radial, stops, anti-alias
  PostScript(PostScriptGradient)
}

///|
priv struct PostScriptGradient {
  min : Double
  max : Double
  cx : Double
  cy : Double
  stops : Array[Stop]
  domain : Rect
  spread_method : SpreadMethod
  gradient_type : GradientType
  anti_alias : Bool
}

///|
fn GradientProperties::stops(self : GradientProperties) -> Array[Stop] {
  match self {
    RadialAxial(_, _, stops, _) => stops
    PostScript(p) => p.stops
  }
}

///|
fn GradientProperties::single_stop_color(
  self : GradientProperties,
) -> (Color, Double)? {
  let stops = self.stops()
  if stops.length() == 1 {
    Some((stops[0].color, stops[0].opacity))
  } else {
    None
  }
}

///|
fn get_expanded_bbox(bbox : Rect, shading_transform : Transform) -> Rect {
  match shading_transform.invert() {
    Some(inv) => bbox.union(bbox.transform(inv))
    None => bbox
  }
}

///|
fn LinearGradient::gradient_properties(
  self : LinearGradient,
  bbox : Rect,
) -> (GradientProperties, Transform) {
  if self.spread_method == Pad {
    (
      RadialAxial(
        [self.x1, self.y1, self.x2, self.y2],
        false,
        normalize_stops(self.stops),
        self.anti_alias,
      ),
      self.transform,
    )
  } else {
    let dx = self.x2 - self.x1
    let dy = self.y2 - self.y1
    let dist = (dx * dx + dy * dy).sqrt()
    let angle = @math.atan2(dy, dx)
    let (s, c) = (@math.sin(angle), @math.cos(angle))
    // Rotate around (x1, y1).
    let ts = Transform::from_translate(self.x1, self.y1)
      .pre_concat(Transform::from_row(c, s, -s, c, 0.0, 0.0))
      .pre_concat(Transform::from_translate(-self.x1, -self.y1))
    let full = self.transform.pre_concat(ts)
    (
      PostScript({
        min: self.x1,
        max: self.x1 + dist,
        cx: 0.0,
        cy: 0.0,
        stops: normalize_stops(self.stops),
        domain: get_expanded_bbox(bbox, full),
        spread_method: self.spread_method,
        gradient_type: Linear,
        anti_alias: self.anti_alias,
      }),
      full,
    )
  }
}

///|
fn RadialGradient::gradient_properties(
  self : RadialGradient,
  _bbox : Rect,
) -> (GradientProperties, Transform) {
  (
    RadialAxial(
      [self.fx, self.fy, self.fr, self.cx, self.cy, self.cr],
      true,
      normalize_stops(self.stops),
      self.anti_alias,
    ),
    self.transform,
  )
}

///|
fn SweepGradient::gradient_properties(
  self : SweepGradient,
  bbox : Rect,
) -> (GradientProperties, Transform) {
  (
    PostScript({
      min: self.start_angle,
      max: self.end_angle,
      cx: self.cx,
      cy: self.cy,
      stops: normalize_stops(self.stops),
      domain: get_expanded_bbox(bbox, self.transform),
      spread_method: self.spread_method,
      gradient_type: Sweep,
      anti_alias: self.anti_alias,
    }),
    self.transform,
  )
}

///|
/// A shading function.
priv struct ShadingFunction {
  properties : GradientProperties
  use_opacities : Bool
}

///|
fn ShadingFunction::new(
  properties : GradientProperties,
  use_opacities : Bool,
) -> ShadingFunction {
  { properties, use_opacities, }
}

///|
/// A shading pattern.
priv struct ShadingPattern {
  function : ShadingFunction
  transform : Transform
}

///|
fn ShadingPattern::new(
  props : GradientProperties,
  transform : Transform,
) -> ShadingPattern {
  { function: ShadingFunction::new(props, false), transform, }
}

///|
fn SerializeContext::register_shading_pattern(
  self : SerializeContext,
  p : ShadingPattern,
) -> Int {
  let shading = self.register_shading_function(p.function)
  let r = self.new_ref()
  self.put(
    r,
    Dict([
      ("Type", Name("Pattern")),
      ("PatternType", Int(2)),
      ("Shading", Ref(shading)),
      ("Matrix", p.transform.to_pdf()),
    ]),
  )
  r
}

///|
fn shading_color_space(
  sc : SerializeContext,
  color : Color,
  use_opacities : Bool,
) -> Obj {
  if use_opacities {
    return sc.regular_color_space_obj(Luma(0))
  }
  match color {
    Regular(c) => sc.regular_color_space_obj(c)
    Separation(_, _) =>
      match sc.register_colorspace(color) {
        Some(r) => Ref(r)
        None => Name("DeviceRGB")
      }
  }
}

///|
fn stop_components(stop : Stop, use_opacities : Bool) -> Array[Double] {
  if use_opacities {
    [stop.opacity]
  } else {
    stop.color.to_pdf_color()
  }
}

///|
fn range_obj(n : Int) -> Obj {
  let r = []
  for _ in 0..<n {
    r.push(Real(0.0))
    r.push(Real(1.0))
  }
  Arr(r)
}

///|
fn SerializeContext::serialize_exponential(
  self : SerializeContext,
  c0 : Array[Double],
  c1 : Array[Double],
) -> Int {
  let r = self.new_ref()
  self.put(
    r,
    Dict([
      ("FunctionType", Int(2)),
      ("Range", range_obj(c0.length())),
      ("C0", Arr(c0.map(v => Real(v)))),
      ("C1", Arr(c1.map(v => Real(v)))),
      ("Domain", Arr([Real(0.0), Real(1.0)])),
      ("N", Real(1.0)),
    ]),
  )
  r
}

///|
fn SerializeContext::serialize_stitching(
  self : SerializeContext,
  stops : Array[Stop],
  use_opacities : Bool,
) -> Int {
  let r = self.new_ref()
  let functions = []
  let bounds = []
  let encode = []
  let mut count = 0
  for i in 0..<(stops.length() - 1) {
    let first = stops[i]
    let second = stops[i + 1]
    bounds.push(Real(second.offset))
    let c0 = stop_components(first, use_opacities)
    let c1 = stop_components(second, use_opacities)
    count = c0.length()
    functions.push(Ref(self.serialize_exponential(c0, c1)))
    encode.push(Real(0.0))
    encode.push(Real(1.0))
  }
  bounds.pop() |> ignore
  self.put(
    r,
    Dict([
      ("FunctionType", Int(3)),
      ("Domain", Arr([Real(0.0), Real(1.0)])),
      ("Range", range_obj(count)),
      ("Functions", Arr(functions)),
      ("Bounds", Arr(bounds)),
      ("Encode", Arr(encode)),
    ]),
  )
  r
}

///|
fn SerializeContext::register_shading_function(
  self : SerializeContext,
  f : ShadingFunction,
) -> Int {
  let r = self.new_ref()
  match f.properties {
    RadialAxial(coords, radial, stops, anti_alias) => {
      let stops = stops.copy()
      if stops.length() > 0 && stops[0].offset != 0.0 {
        stops.insert(0, { ..stops[0], offset: 0.0, })
      }
      if stops.length() > 0 && stops[stops.length() - 1].offset != 1.0 {
        stops.push({ ..stops[stops.length() - 1], offset: 1.0, })
      }
      let function = if stops.length() == 2 {
        self.serialize_exponential(
          stop_components(stops[0], f.use_opacities),
          stop_components(stops[1], f.use_opacities),
        )
      } else {
        self.serialize_stitching(stops, f.use_opacities)
      }
      self.put(
        r,
        Dict([
          ("ShadingType", Int(if radial { 3 } else { 2 })),
          (
            "ColorSpace",
            shading_color_space(self, stops[0].color, f.use_opacities),
          ),
          ("AntiAlias", Bool(anti_alias)),
          ("Function", Ref(function)),
          ("Coords", Arr(coords.map(v => Real(v)))),
          ("Extend", Arr([Bool(true), Bool(true)])),
        ]),
      )
    }
    PostScript(psg) => {
      self.register_validation_error(ContainsPostScript(self.location))
      let function = self.serialize_postscript_function(psg, f.use_opacities)
      let d = psg.domain
      self.put(
        r,
        Dict([
          ("ShadingType", Int(1)),
          (
            "ColorSpace",
            shading_color_space(self, psg.stops[0].color, f.use_opacities),
          ),
          ("Matrix", Transform::identity().to_pdf()),
          ("AntiAlias", Bool(psg.anti_alias)),
          ("Function", Ref(function)),
          (
            "Domain",
            Arr([Real(d.left), Real(d.right), Real(d.top), Real(d.bottom)]),
          ),
        ]),
      )
    }
  }
  r
}

///|
/// PostScript calculator function code.
priv enum PsOp {
  PsReal(Double)
  PsInt(Int)
  PsOp(String)
  PsIf(Array[PsOp])
  PsIfElse(Array[PsOp], Array[PsOp])
}

///|
fn encode_ps(code : Array[PsOp], sb : StringBuilder) -> Unit {
  sb.write_string("{ ")
  for op in code {
    match op {
      PsReal(v) => sb.write_string(format_real(v))
      PsInt(i) => sb.write_string(i.to_string())
      PsOp(name) => sb.write_string(name)
      PsIf(body) => {
        encode_ps(body, sb)
        sb.write_string(" if")
      }
      PsIfElse(a, b) => {
        encode_ps(a, sb)
        sb.write_char(' ')
        encode_ps(b, sb)
        sb.write_string(" ifelse")
      }
    }
    sb.write_char(' ')
  }
  sb.write_string("}")
}

///|
fn encode_spread_method(
  min : Double,
  max : Double,
  code : Array[PsOp],
  spread : SpreadMethod,
) -> Unit {
  if spread == Pad {
    return
  }
  let length = max - min
  for
    op in [
      PsReal(length),
      PsReal(min),
      PsInt(2),
      PsOp("index"),
      PsInt(1),
      PsOp("index"),
      PsOp("sub"),
      PsOp("dup"),
      PsInt(3),
      PsOp("index"),
      PsOp("div"),
      PsOp("floor"),
      PsOp("exch"),
      PsInt(1),
      PsOp("index"),
      PsInt(4),
      PsOp("index"),
      PsOp("mul"),
      PsOp("sub"),
      PsOp("exch"),
      PsOp("cvi"),
      PsOp("abs"),
      PsInt(2),
      PsOp("mod"),
      PsInt(0),
      PsOp("gt"),
      if spread == Reflect {
        PsIf([PsInt(2), PsOp("index"), PsOp("exch"), PsOp("sub")])
      } else {
        PsOp("pop")
      },
      PsOp("add"),
      PsInt(3),
      PsInt(1),
      PsOp("roll"),
      PsOp("pop"),
      PsOp("pop"),
    ] {
    code.push(op)
  }
}

///|
fn encode_stops_impl(
  stops : ArrayView[Stop],
  min : Double,
  max : Double,
  code : Array[PsOp],
  use_opacities : Bool,
) -> Unit {
  if stops.length() == 1 {
    // Replace the input value with the stop's color. (krilla doesn't pop the
    // input value here, leaving one value too many on the stack.)
    code.push(PsOp("pop"))
    for c in stop_components(stops[0], use_opacities) {
      code.push(PsReal(c))
    }
    return
  }
  let length = max - min
  let stops_min = min + length * stops[0].offset
  let stops_max = min + length * stops[1].offset
  let if_stops = []
  let c0 = stop_components(stops[0], use_opacities)
  let c1 = stop_components(stops[1], use_opacities)
  if stops_min == stops_max {
    if_stops.push(PsOp("pop"))
    for c in c0 {
      if_stops.push(PsReal(c))
    }
  } else {
    for
      op in [
        PsReal(stops_min),
        PsOp("sub"),
        PsReal(stops_max),
        PsReal(stops_min),
        PsOp("sub"),
        PsOp("div"),
      ] {
      if_stops.push(op)
    }
    for i in 0..<c0.length() {
      for
        op in [
          PsInt(i),
          PsOp("index"),
          PsReal(c0[i]),
          PsOp("exch"),
          PsReal(c1[i]),
          PsReal(c0[i]),
          PsOp("sub"),
          PsOp("mul"),
          PsOp("add"),
        ] {
        if_stops.push(op)
      }
    }
    if_stops.push(PsInt(c0.length() + 1))
    if_stops.push(PsInt(-1))
    if_stops.push(PsOp("roll"))
    if_stops.push(PsOp("pop"))
  }
  let else_stops = []
  encode_stops_impl(stops[1:], min, max, else_stops, use_opacities)
  code.push(PsOp("dup"))
  code.push(PsReal(stops_max))
  code.push(PsOp("le"))
  code.push(PsIfElse(if_stops, else_stops))
}

///|
fn SerializeContext::serialize_postscript_function(
  self : SerializeContext,
  p : PostScriptGradient,
  use_opacities : Bool,
) -> Int {
  let r = self.new_ref()
  let code = []
  match p.gradient_type {
    Sweep =>
      for
        op in [
          PsReal(p.cy),
          PsOp("sub"),
          PsOp("exch"),
          PsReal(p.cx),
          PsOp("sub"),
          PsOp("dup"),
          PsOp("dup"),
          PsReal(0.0001),
          PsOp("lt"),
          PsOp("exch"),
          PsReal(-0.0001),
          PsOp("gt"),
          PsOp("and"),
          PsIf([PsOp("pop"), PsReal(0.0001)]),
          PsOp("atan"),
        ] {
        code.push(op)
      }
    Linear => code.push(PsOp("pop"))
  }
  encode_spread_method(p.min, p.max, code, p.spread_method)
  // Trim to at most 97 stops, then pad the ends.
  let mut stops = p.stops
  if stops.length() > 97 {
    let factor = stops.length().to_double() / 97.0
    let trimmed = []
    let mut cur = 0.0
    while cur.round().to_int() < stops.length() {
      trimmed.push(stops[cur.round().to_int()])
      cur += factor
    }
    stops = trimmed
  }
  let padded = stops.copy()
  if stops.length() > 0 {
    padded.insert(0, { ..stops[0], offset: 0.0, })
    padded.push({ ..stops[stops.length() - 1], offset: 1.0, })
  }
  encode_stops_impl(padded, p.min, p.max, code, use_opacities)
  let sb = StringBuilder()
  encode_ps(code, sb)
  let d = p.domain
  self.put_content_stream(
    r,
    [
      ("FunctionType", Int(4)),
      (
        "Domain",
        Arr([Real(d.left), Real(d.right), Real(d.top), Real(d.bottom)]),
      ),
      // The number of components of the stops' color space (krilla always
      // declares three).
      (
        "Range",
        range_obj(
          if use_opacities || p.stops.is_empty() {
            1
          } else {
            p.stops[0].color.to_pdf_color().length()
          },
        ),
      ),
    ],
    utf8_bytes(sb.to_string()),
  )
  r
}
