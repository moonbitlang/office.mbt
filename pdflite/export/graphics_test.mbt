///|
fn fill_of(paint : @export.Paint) -> @export.Fill {
  { ..@export.Fill::default(), paint, }
}

///|
fn stops2(
  a : @export.Color,
  b : @export.Color,
  opacity_b? : Double = 1.0,
) -> Array[@export.Stop] {
  [
    { offset: 0.0, color: a, opacity: 1.0, },
    { offset: 1.0, color: b, opacity: opacity_b, },
  ]
}

///|
/// The page resources with their entries resolved one level deep.
fn Parsed::resources(self : Parsed) -> String raise {
  self.show_deep(self.get(self.page(0), "Resources"))
}

///|
/// Resolve the resource `key`/`name` of the first page.
fn Parsed::resource(
  self : Parsed,
  key : String,
  name : String,
) -> @syntax.PdfObject raise {
  self.path(self.page(0), ["Resources", key, name])
}

///|
test "fill with device colors" {
  let p = parse(
    one_page(s => {
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      s.set_fill(Some(fill_of(Color(Regular(Luma(128))))))
      s.draw_path(rect_path(10.0, 0.0, 10.0, 10.0))
      s.set_fill(Some(fill_of(Color(Regular(Cmyk(0, 255, 51, 0))))))
      s.draw_path(rect_path(20.0, 0.0, 10.0, 10.0))
      s.set_fill(Some({ ..fill_of(solid(255, 0, 0)), rule: EvenOdd, }))
      s.draw_path(rect_path(30.0, 0.0, 10.0, 10.0))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|0.50196 g
      #|10 0 m
      #|20 0 l
      #|20 10 l
      #|10 10 l
      #|h
      #|f
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 1 0.2 0 k
      #|20 0 m
      #|30 0 l
      #|30 10 l
      #|20 10 l
      #|h
      #|f
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|1 0 0 rg
      #|30 0 m
      #|40 0 l
      #|40 10 l
      #|30 10 l
      #|h
      #|f*
      #|Q
      #|
    ),
  )
  inspect(
    p.resources(),
    content=(
      #|<<>>
    ),
  )
}

///|
test "stroke properties" {
  let p = parse(
    one_page(s => {
      s.set_stroke(
        Some({
          ..stroke_of(solid(0, 0, 255), 2.0),
          miter_limit: 4.0,
          line_cap: Round,
          line_join: Bevel,
          dash: Some({ array: [3.0, 1.5], offset: 0.5, }),
        }),
      )
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      // Default stroke properties are not written.
      s.set_stroke(
        Some({ ..stroke_of(solid(0, 0, 0), 1.0), line_cap: Square, }),
      )
      s.draw_path(rect_path(20.0, 0.0, 10.0, 10.0))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 1 RG
      #|2 w
      #|4 M
      #|1 J
      #|2 j
      #|[3 1.5] 0.5 d
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|S
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 RG
      #|2 J
      #|20 0 m
      #|30 0 l
      #|30 10 l
      #|20 10 l
      #|h
      #|S
      #|Q
      #|
    ),
  )
}

///|
test "fill and stroke together" {
  let p = parse(
    one_page(s => {
      s.set_fill(Some(fill_of(solid(255, 0, 0))))
      s.set_stroke(Some(stroke_of(solid(0, 255, 0), 3.0)))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      s.set_fill(Some({ ..fill_of(solid(255, 0, 0)), rule: EvenOdd, }))
      s.draw_path(rect_path(20.0, 0.0, 10.0, 10.0))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|1 0 0 rg
      #|0 1 0 RG
      #|3 w
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|B
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|1 0 0 rg
      #|0 1 0 RG
      #|3 w
      #|20 0 m
      #|30 0 l
      #|30 10 l
      #|20 10 l
      #|h
      #|B*
      #|Q
      #|
    ),
  )
}

///|
test "lines are never filled and empty paths are skipped" {
  let line = {
    let pb = @export.PathBuilder::new()
    pb.move_to(0.0, 0.0)
    pb.line_to(50.0, 50.0)
    pb.finish().unwrap()
  }
  let flat = {
    let pb = @export.PathBuilder::new()
    pb.move_to(0.0, 5.0)
    pb.line_to(10.0, 5.0)
    pb.line_to(20.0, 5.0)
    pb.finish().unwrap()
  }
  let point = {
    let pb = @export.PathBuilder::new()
    pb.move_to(3.0, 3.0)
    pb.line_to(3.0, 3.0)
    pb.finish().unwrap()
  }
  let p = parse(
    one_page(s => {
      // Filled only: nothing is drawn.
      s.set_fill(Some(fill_of(solid(1, 2, 3))))
      s.draw_path(line)
      s.draw_path(flat)
      s.draw_path(point)
      // Filled and stroked: only the stroke is drawn.
      s.set_stroke(Some(stroke_of(solid(0, 0, 0), 1.0)))
      s.draw_path(line)
      s.draw_path(point)
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 RG
      #|0 0 m
      #|50 50 l
      #|S
      #|Q
      #|
    ),
  )
}

///|
test "quadratic curves are converted to cubic curves" {
  let pb = @export.PathBuilder::new()
  pb.move_to(0.0, 0.0)
  pb.quad_to(30.0, 30.0, 60.0, 0.0)
  pb.close()
  let path = pb.finish().unwrap()
  let p = parse(one_page(s => s.draw_path(path)))
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|0 0 m
      #|20 20 40 20 60 0 c
      #|h
      #|f
      #|Q
      #|
    ),
  )
}

///|
test "transforms are written per drawing operation" {
  let p = parse(
    one_page(s => {
      s.push_transform(@export.Transform::from_translate(10.0, 20.0))
      s.push_transform(@export.Transform::from_scale(2.0, 2.0))
      debug_inspect(
        s.ctm(),
        content=(
          #|{ sx: 2, ky: 0, kx: 0, sy: 2, tx: 10, ty: 20 }
        ),
      )
      s.draw_path(rect_path(0.0, 0.0, 5.0, 5.0))
      s.pop()
      s.pop()
      debug_inspect(s.ctm().is_identity(), content="true")
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|2 0 0 -2 10 80 cm
      #|0 0 0 rg
      #|0 0 m
      #|5 0 l
      #|5 5 l
      #|0 5 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
}

///|
test "clip paths" {
  let p = parse(
    one_page(s => {
      s.push_transform(@export.Transform::from_translate(5.0, 5.0))
      s.push_clip_path(rect_path(0.0, 0.0, 20.0, 20.0), NonZero)
      s.push_clip_path(rect_path(5.0, 5.0, 5.0, 5.0), EvenOdd)
      s.draw_path(rect_path(0.0, 0.0, 50.0, 50.0))
      s.pop()
      s.pop()
      s.pop()
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|5 95 m
      #|25 95 l
      #|25 75 l
      #|5 75 l
      #|h
      #|W
      #|n
      #|q
      #|10 90 m
      #|15 90 l
      #|15 85 l
      #|10 85 l
      #|h
      #|W*
      #|n
      #|q
      #|1 0 0 -1 5 95 cm
      #|0 0 0 rg
      #|0 0 m
      #|50 0 l
      #|50 50 l
      #|0 50 l
      #|h
      #|f
      #|Q
      #|Q
      #|Q
      #|
    ),
  )
}

///|
test "fill and stroke opacity use ExtGStates" {
  let p = parse(
    one_page(s => {
      s.set_fill(Some({ ..fill_of(solid(255, 0, 0)), opacity: 0.25, }))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      // A translucent stroke is drawn separately from the fill.
      s.set_stroke(Some({ ..stroke_of(solid(0, 0, 255), 1.0), opacity: 0.5, }))
      s.draw_path(rect_path(20.0, 0.0, 10.0, 10.0))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|/g0 gs
      #|1 0 0 rg
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/g0 gs
      #|1 0 0 rg
      #|20 0 m
      #|30 0 l
      #|30 10 l
      #|20 10 l
      #|h
      #|f
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/g1 gs
      #|0 0 1 RG
      #|20 0 m
      #|30 0 l
      #|30 10 l
      #|20 10 l
      #|h
      #|S
      #|Q
      #|
    ),
  )
  inspect(
    p.resources(),
    content=(
      #|<</ExtGState <</g0 <</Type /ExtGState /ca 0.25>> /g1 <</Type /ExtGState /CA 0.5>>>>>>
    ),
  )
}

///|
test "group opacity draws a transparency group" {
  let p = parse(
    one_page(s => {
      // An opacity of 1 doesn't create a group.
      s.push_opacity(1.0)
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      s.pop()
      s.push_opacity(0.5)
      s.draw_path(rect_path(20.0, 0.0, 10.0, 10.0))
      s.pop()
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/g0 gs
      #|/x0 Do
      #|Q
      #|
    ),
  )
  inspect(
    p.resources(),
    content=(
      #|<</ExtGState <</g0 <</Type /ExtGState /ca 0.5 /CA 0.5>>>> /XObject <</x0 stream<</Type /XObject /Subtype /Form /Resources <<>> /BBox [20 0 30 10] /Group <</Type /Group /S /Transparency /I true /CS /DeviceRGB>> /Length 47>>>>>>
    ),
  )
  let form = p.resource("XObject", "x0")
  inspect(
    p.show(form),
    content=(
      #|stream<</Type /XObject /Subtype /Form /Resources <<>> /BBox [20 0 30 10] /Group <</Type /Group /S /Transparency /I true /CS /DeviceRGB>> /Length 47>>
    ),
  )
  inspect(
    p.content(form),
    content=(
      #|q
      #|0 0 0 rg
      #|20 0 m
      #|30 0 l
      #|30 10 l
      #|20 10 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
}

///|
test "blend modes" {
  let p = parse(
    one_page(s => {
      s.push_blend_mode("Normal")
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      s.pop()
      s.push_blend_mode("Multiply")
      s.draw_path(rect_path(20.0, 0.0, 10.0, 10.0))
      s.pop()
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 rg
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/g0 gs
      #|0 0 0 rg
      #|20 0 m
      #|30 0 l
      #|30 10 l
      #|20 10 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
  inspect(
    p.resources(),
    content=(
      #|<</ExtGState <</g0 <</Type /ExtGState /BM /Multiply>>>>>>
    ),
  )
}

///|
test "masks and isolated groups" {
  let p = parse(
    one_page(s => {
      let ms = s.stream_surface()
      ms.set_fill(Some(fill_of(Color(Regular(Luma(255))))))
      ms.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      let mask = ms.finish_stream()
      s.push_mask(mask, true)
      s.draw_path(rect_path(0.0, 0.0, 20.0, 20.0))
      s.pop()
      s.push_isolated()
      s.draw_path(rect_path(30.0, 0.0, 5.0, 5.0))
      s.pop()
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|/g0 gs
      #|/x0 Do
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/x1 Do
      #|Q
      #|
    ),
  )
  let gs = p.resource("ExtGState", "g0")
  let smask = p.get(gs, "SMask")
  inspect(
    p.show_deep(smask),
    content=(
      #|<</Type /Mask /S /Luminosity /G stream<</Type /XObject /Subtype /Form /Resources <<>> /BBox [0 0 10 10] /Group <</Type /Group /S /Transparency /CS /DeviceRGB>> /Length 40>>>>
    ),
  )
  let g = p.get(smask, "G")
  inspect(
    p.show(p.resolve(g)),
    content=(
      #|stream<</Type /XObject /Subtype /Form /Resources <<>> /BBox [0 0 10 10] /Group <</Type /Group /S /Transparency /CS /DeviceRGB>> /Length 40>>
    ),
  )
  inspect(
    p.content(g),
    content=(
      #|q
      #|1 g
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
  inspect(
    p.show(p.resource("XObject", "x0")),
    content=(
      #|stream<</Type /XObject /Subtype /Form /Resources <<>> /BBox [0 0 20 20] /Group <</Type /Group /S /Transparency /CS /DeviceRGB>> /Length 45>>
    ),
  )
  inspect(
    p.show(p.resource("XObject", "x1")),
    content=(
      #|stream<</Type /XObject /Subtype /Form /Resources <<>> /BBox [30 0 35 5] /Group <</Type /Group /S /Transparency /I true /CS /DeviceRGB>> /Length 45>>
    ),
  )
}

///|
test "linear and radial gradients are shading patterns" {
  let linear = @export.LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 10.0,
    y2: 0.0,
    transform: @export.Transform::identity(),
    spread_method: Pad,
    stops: stops2(@export.Color::rgb(255, 0, 0), @export.Color::rgb(0, 0, 255)),
    anti_alias: false,
  }
  let radial = @export.RadialGradient::{
    fx: 5.0,
    fy: 5.0,
    fr: 0.0,
    cx: 5.0,
    cy: 5.0,
    cr: 5.0,
    transform: @export.Transform::identity(),
    spread_method: Pad,
    stops: [
      { offset: 0.0, color: Regular(Luma(0)), opacity: 1.0, },
      { offset: 0.5, color: Regular(Luma(128)), opacity: 1.0, },
      { offset: 0.8, color: Regular(Luma(255)), opacity: 1.0, },
    ],
    anti_alias: true,
  }
  let p = parse(
    one_page(s => {
      s.set_fill(Some(fill_of(LinearGradient(linear))))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      s.set_fill(Some(fill_of(RadialGradient(radial))))
      s.draw_path(rect_path(20.0, 0.0, 10.0, 10.0))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|/Pattern cs
      #|/p0 scn
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/Pattern cs
      #|/p1 scn
      #|20 0 m
      #|30 0 l
      #|30 10 l
      #|20 10 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
  let p0 = p.resource("Pattern", "p0")
  inspect(
    p.show(p0),
    content=(
      #|<</Type /Pattern /PatternType 2 /Shading R /Matrix [1 0 0 -1 0 100]>>
    ),
  )
  inspect(
    p.show_deep(p.get(p0, "Shading")),
    content=(
      #|<</ShadingType 2 /ColorSpace /DeviceRGB /AntiAlias false /Function <</FunctionType 2 /Range [0 1 0 1 0 1] /C0 [1 0 0] /C1 [0 0 1] /Domain [0 1] /N 1>> /Coords [0 0 10 0] /Extend [true true]>>
    ),
  )
  inspect(
    p.show(p.path(p0, ["Shading", "Function"])),
    content=(
      #|<</FunctionType 2 /Range [0 1 0 1 0 1] /C0 [1 0 0] /C1 [0 0 1] /Domain [0 1] /N 1>>
    ),
  )
  let p1 = p.resource("Pattern", "p1")
  // Stops are padded to the full domain and joined by a stitching function.
  let shading = p.get(p1, "Shading")
  inspect(
    p.show(p.resolve(shading)),
    content=(
      #|<</ShadingType 3 /ColorSpace /DeviceGray /AntiAlias true /Function R /Coords [5 5 0 5 5 5] /Extend [true true]>>
    ),
  )
  let f = p.get(shading, "Function")
  inspect(
    p.show(p.resolve(f)),
    content=(
      #|<</FunctionType 3 /Domain [0 1] /Range [0 1] /Functions [R R R] /Bounds [0.5 0.8] /Encode [0 1 0 1 0 1]>>
    ),
  )
  inspect(
    p.items(p.get(f, "Functions")).map(g => p.show(g)).join("\n"),
    content=(
      #|<</FunctionType 2 /Range [0 1] /C0 [0] /C1 [0.50196] /Domain [0 1] /N 1>>
      #|<</FunctionType 2 /Range [0 1] /C0 [0.50196] /C1 [1] /Domain [0 1] /N 1>>
      #|<</FunctionType 2 /Range [0 1] /C0 [1] /C1 [1] /Domain [0 1] /N 1>>
    ),
  )
}

///|
test "gradients with a single stop are drawn as a solid color" {
  let linear = @export.LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 10.0,
    y2: 0.0,
    transform: @export.Transform::identity(),
    spread_method: Pad,
    stops: [
      { offset: 0.3, color: @export.Color::rgb(0, 255, 0), opacity: 1.0, },
    ],
    anti_alias: false,
  }
  let p = parse(
    one_page(s => {
      s.set_fill(Some(fill_of(LinearGradient(linear))))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 1 0 rg
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
}

///|
test "gradients with translucent stops get a luminosity mask" {
  let linear = @export.LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 10.0,
    y2: 0.0,
    transform: @export.Transform::identity(),
    spread_method: Pad,
    stops: stops2(
      @export.Color::rgb(255, 0, 0),
      @export.Color::rgb(0, 0, 255),
      opacity_b=0.2,
    ),
    anti_alias: false,
  }
  let p = parse(
    one_page(s => {
      s.set_fill(Some(fill_of(LinearGradient(linear))))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|/g0 gs
      #|/Pattern cs
      #|/p0 scn
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
  let smask = p.path(p.page(0), ["Resources", "ExtGState", "g0", "SMask"])
  inspect(
    p.show(smask),
    content=(
      #|<</Type /Mask /S /Luminosity /G R>>
    ),
  )
  let g = p.get(smask, "G")
  inspect(
    p.content(g),
    content=(
      #|q
      #|/s0 sh
      #|Q
      #|
    ),
  )
  // The mask shading draws the opacities in DeviceGray.
  let shading = p.path(g, ["Resources", "Shading", "s0"])
  inspect(
    p.show(shading),
    content=(
      #|<</ShadingType 2 /ColorSpace /DeviceGray /AntiAlias false /Function R /Coords [0 0 10 0] /Extend [true true]>>
    ),
  )
  inspect(
    p.show(p.get(shading, "Function")),
    content=(
      #|<</FunctionType 2 /Range [0 1] /C0 [1] /C1 [0.2] /Domain [0 1] /N 1>>
    ),
  )
}

///|
test "sweep and repeating gradients use PostScript functions" {
  let sweep = @export.SweepGradient::{
    cx: 5.0,
    cy: 5.0,
    start_angle: 0.0,
    end_angle: 360.0,
    transform: @export.Transform::identity(),
    spread_method: Pad,
    stops: stops2(@export.Color::rgb(255, 0, 0), @export.Color::rgb(0, 0, 255)),
    anti_alias: false,
  }
  let linear = @export.LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 4.0,
    y2: 0.0,
    transform: @export.Transform::identity(),
    spread_method: Reflect,
    stops: stops2(@export.Color::rgb(255, 0, 0), @export.Color::rgb(0, 0, 255)),
    anti_alias: false,
  }
  let p = parse(
    one_page(s => {
      s.set_fill(Some(fill_of(SweepGradient(sweep))))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      s.set_fill(Some(fill_of(LinearGradient(linear))))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
    }),
  )
  let shading = p.path(p.page(0), ["Resources", "Pattern", "p0", "Shading"])
  inspect(
    p.show(shading),
    content=(
      #|<</ShadingType 1 /ColorSpace /DeviceRGB /Matrix [1 0 0 1 0 0] /AntiAlias false /Function R /Domain [0 10 0 10]>>
    ),
  )
  let f = p.get(shading, "Function")
  inspect(
    p.show(p.resolve(f)),
    content=(
      #|stream<</FunctionType 4 /Domain [0 10 0 10] /Range [0 1 0 1 0 1] /Length 314>>
    ),
  )
  inspect(
    latin1(p.stream_data(f)),
    content=(
      #|{ 5 sub exch 5 sub dup dup 0.0001 lt exch -0.0001 gt and { pop 0.0001 } if atan dup 0 le { pop 1 0 0 } { dup 360 le { 0 sub 360 0 sub div 0 index 1 exch 0 1 sub mul add 1 index 0 exch 0 0 sub mul add 2 index 0 exch 1 0 sub mul add 4 -1 roll pop } { dup 360 le { pop 0 0 1 } { pop 0 0 1 } ifelse } ifelse } ifelse }
    ),
  )
  let shading = p.path(p.page(0), ["Resources", "Pattern", "p1", "Shading"])
  inspect(
    p.show(shading),
    content=(
      #|<</ShadingType 1 /ColorSpace /DeviceRGB /Matrix [1 0 0 1 0 0] /AntiAlias false /Function R /Domain [0 10 0 10]>>
    ),
  )
  inspect(
    latin1(p.stream_data(p.get(shading, "Function"))),
    content=(
      #|{ pop 4 0 2 index 1 index sub dup 3 index div floor exch 1 index 4 index mul sub exch cvi abs 2 mod 0 gt { 2 index exch sub } if add 3 1 roll pop pop dup 0 le { pop 1 0 0 } { dup 4 le { 0 sub 4 0 sub div 0 index 1 exch 0 1 sub mul add 1 index 0 exch 0 0 sub mul add 2 index 0 exch 1 0 sub mul add 4 -1 roll pop } { dup 4 le { pop 0 0 1 } { pop 0 0 1 } ifelse } ifelse } ifelse }
    ),
  )
}

///|
test "tiling patterns" {
  let p = parse(
    one_page(s => {
      let tile = s.stream_surface()
      tile.draw_path(rect_path(0.0, 0.0, 2.0, 2.0))
      let stream = tile.finish_stream()
      let pattern = @export.Pattern::{
        stream,
        transform: @export.Transform::from_scale(2.0, 2.0),
        width: 4.0,
        height: 4.0,
      }
      s.set_fill(Some(fill_of(Pattern(pattern))))
      s.draw_path(rect_path(0.0, 0.0, 20.0, 20.0))
      // A translucent pattern fill is wrapped into a transparency group.
      s.set_fill(Some({ ..fill_of(Pattern(pattern)), opacity: 0.5, }))
      s.draw_path(rect_path(0.0, 0.0, 20.0, 20.0))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|/Pattern cs
      #|/p0 scn
      #|0 0 m
      #|20 0 l
      #|20 20 l
      #|0 20 l
      #|h
      #|f
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/Pattern cs
      #|/p1 scn
      #|0 0 m
      #|20 0 l
      #|20 20 l
      #|0 20 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
  let p0 = p.resource("Pattern", "p0")
  inspect(
    p.show(p.resolve(p0)),
    content=(
      #|stream<</Type /Pattern /PatternType 1 /PaintType 1 /TilingType 1 /BBox [0 0 4 4] /XStep 4 /YStep 4 /Matrix [2 0 0 -2 0 100] /Resources <<>> /Length 41>>
    ),
  )
  inspect(
    p.content(p0),
    content=(
      #|q
      #|0 0 0 rg
      #|0 0 m
      #|2 0 l
      #|2 2 l
      #|0 2 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
  let p1 = p.resource("Pattern", "p1")
  inspect(
    p.content(p1),
    content=(
      #|q
      #|/g0 gs
      #|/x0 Do
      #|Q
      #|
    ),
  )
  inspect(
    p.show_deep(p.get(p1, "Resources")),
    content=(
      #|<</ExtGState <</g0 <</Type /ExtGState /ca 0.5 /CA 0.5>>>> /XObject <</x0 stream<</Type /XObject /Subtype /Form /Resources <<>> /BBox [0 0 2 2] /Group <</Type /Group /S /Transparency /I true /CS /DeviceRGB>> /Length 41>>>>>>
    ),
  )
}

///|
test "draw_stream draws a form XObject" {
  let p = parse(
    one_page(s => {
      let sub = s.stream_surface()
      sub.draw_path(rect_path(1.0, 2.0, 3.0, 4.0))
      let stream = sub.finish_stream()
      inspect(stream.is_empty(), content="false")
      inspect(@export.Stream::empty().is_empty(), content="true")
      s.draw_stream(stream)
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|/x0 Do
      #|Q
      #|
    ),
  )
  let x0 = p.resource("XObject", "x0")
  inspect(
    p.show(x0),
    content=(
      #|stream<</Type /XObject /Subtype /Form /Resources <<>> /BBox [1 2 4 6] /Length 41>>
    ),
  )
  inspect(
    p.content(x0),
    content=(
      #|q
      #|0 0 0 rg
      #|1 2 m
      #|4 2 l
      #|4 6 l
      #|1 6 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
}

///|
test "separation colors register a color space" {
  let spot = @export.SeparationSpace::{
    colorant: Custom("Spot Red"),
    fallback: Cmyk(0, 255, 255, 0),
  }
  let p = parse(
    one_page(s => {
      s.set_fill(Some(fill_of(Color(Separation(128, spot)))))
      s.set_stroke(Some(stroke_of(Color(Separation(255, spot)), 1.0)))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|/c0 cs
      #|0.50196 scn
      #|/c0 CS
      #|1 SCN
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|B
      #|Q
      #|
    ),
  )
  inspect(
    p.show(p.resource("ColorSpace", "c0")),
    content=(
      #|[/Separation /Spot Red /DeviceCMYK <</FunctionType 2 /Domain [0 1] /Range [0 1 0 1 0 1 0 1] /C0 [0 0 0 0] /C1 [0 1 1 0] /N 1>>]
    ),
  )
}

///|
test "validation errors from graphics" {
  let opacity = (s : @export.Surface) => {
    s.set_location(42UL)
    s.push_opacity(0.5)
    s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
    s.pop()
    s.reset_location()
  }
  inspect(
    export_result(() => {
      one_page(s => opacity(s), settings=settings_with(a=Some(A1_B)))
    }),
    content=(
      #|Validation: Transparency by PDF/A-1b
    ),
  )
  // PDF/A-2 allows transparency.
  inspect(
    export_result(() => {
      one_page(s => opacity(s), settings=settings_with(a=Some(A2_B)))
    }),
    content="ok",
  )
  let nested = (s : @export.Surface) => {
    for _ in 0..<30 {
      s.push_clip_path(rect_path(0.0, 0.0, 10.0, 10.0), NonZero)
    }
    s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
    for _ in 0..<30 {
      s.pop()
    }
  }
  inspect(
    export_result(() => {
      one_page(s => nested(s), settings=settings_with(a=Some(A2_B)))
    }),
    content=(
      #|Validation: TooHighQNestingLevel by PDF/A-2b
    ),
  )
  inspect(export_result(() => one_page(s => nested(s))), content="ok")
  let sweep = @export.SweepGradient::{
    cx: 5.0,
    cy: 5.0,
    start_angle: 0.0,
    end_angle: 360.0,
    transform: @export.Transform::identity(),
    spread_method: Pad,
    stops: stops2(@export.Color::rgb(255, 0, 0), @export.Color::rgb(0, 0, 255)),
    anti_alias: false,
  }
  inspect(
    export_result(() => {
      one_page(
        s => {
          s.set_fill(Some(fill_of(SweepGradient(sweep))))
          s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
        },
        settings=settings_with(a=Some(A2_B)),
      )
    }),
    content=(
      #|Validation: ContainsPostScript by PDF/A-2b
    ),
  )
  let separations = (s : @export.Surface) => {
    s.set_fill(
      Some(
        fill_of(
          Color(
            Separation(255, { colorant: Custom("S"), fallback: Rgb(255, 0, 0), }),
          ),
        ),
      ),
    )
    s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
    s.set_fill(
      Some(
        fill_of(
          Color(
            Separation(255, { colorant: Custom("S"), fallback: Rgb(0, 255, 0), }),
          ),
        ),
      ),
    )
    s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
  }
  inspect(
    export_result(() => {
      one_page(s => separations(s), settings=settings_with(a=Some(A2_B)))
    }),
    content=(
      #|Validation: InconsistentSeparationFallback by PDF/A-2b
    ),
  )
}

///|
test "validators" {
  let v = @export.Validators::{ a: Some(A2_A), ua: Some(UA1), }
  inspect(
    v.to_array().map(x => x.as_str()).join(", "),
    content=(
      #|PDF/A-2a, PDF/UA-1
    ),
  )
  debug_inspect(
    v.to_array().map(x => x.max()),
    content=(
      #|[Pdf17, Pdf17]
    ),
  )
  inspect(@export.Validators::empty().is_empty(), content="true")
  let all : Array[@export.Archival] = [
    A1_A,
    A1_B,
    A2_A,
    A2_B,
    A2_U,
    A3_A,
    A3_B,
    A3_U,
    A4,
    A4F,
    A4E,
  ]
  inspect(
    all.map(a => a.as_str()).join(" "),
    content=(
      #|PDF/A-1a PDF/A-1b PDF/A-2a PDF/A-2b PDF/A-2u PDF/A-3a PDF/A-3b PDF/A-3u PDF/A-4 PDF/A-4f PDF/A-4e
    ),
  )
  debug_inspect(
    [
      @export.StructureOrderTabbing,
      HeaderFooterArtifactSubtypes,
      TableHeaderScope,
    ].map(f => f.minimum_pdf_version()),
    content=(
      #|[Pdf15, Pdf17, Pdf15]
    ),
  )
}

///|
test "panic pop without push" {
  let doc = @export.Document::new_with(plain_settings())
  let page = doc.start_page_with(
    @export.PageSettings::from_wh(10.0, 10.0).unwrap(),
  )
  page.surface().pop()
}

///|
test "panic unbalanced push on finish" {
  let doc = @export.Document::new_with(plain_settings())
  let page = doc.start_page_with(
    @export.PageSettings::from_wh(10.0, 10.0).unwrap(),
  )
  let s = page.surface()
  s.push_opacity(0.5)
  s.finish()
}

///|
test "no_device_cs uses ICC-based sRGB and sGrey color spaces" {
  let settings = { ..plain_settings(), no_device_cs: true, }
  let linear = @export.LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 10.0,
    y2: 0.0,
    transform: @export.Transform::identity(),
    spread_method: Pad,
    stops: stops2(@export.Color::rgb(255, 0, 0), @export.Color::rgb(0, 0, 255)),
    anti_alias: false,
  }
  let p = parse(
    one_page(
      s => {
        s.set_fill(Some(fill_of(solid(255, 0, 0))))
        s.set_stroke(Some(stroke_of(Color(Regular(Luma(51))), 1.0)))
        s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
        s.push_opacity(0.5)
        s.set_stroke(None)
        s.set_fill(Some(fill_of(LinearGradient(linear))))
        s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
        s.pop()
        s.set_fill(
          Some(
            fill_of(
              Color(
                Separation(255, {
                  colorant: Custom("S"),
                  fallback: Rgb(0, 0, 0),
                }),
              ),
            ),
          ),
        )
        s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
        s.draw_image(
          {
            key: "i",
            width: 1,
            height: 1,
            colorspace: Luma,
            data: Samples(b"\x00", None),
            icc: None,
            interpolate: false,
            inverted_cmyk: false,
          },
          @export.Size::from_wh(1.0, 1.0).unwrap(),
        )
      },
      settings~,
    ),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|/c0 cs
      #|1 0 0 scn
      #|/c1 CS
      #|0.2 SCN
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|B
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/g0 gs
      #|/x0 Do
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/c2 cs
      #|1 scn
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|q
      #|1 0 0 1 0 99 cm
      #|/x1 Do
      #|Q
      #|
    ),
  )
  let res = p.get(p.page(0), "Resources")
  inspect(
    p.show_deep(p.get(res, "ColorSpace")),
    content=(
      #|<</c0 [/ICCBased R] /c1 [/ICCBased R] /c2 [/Separation /S R <</FunctionType 2 /Domain [0 1] /Range [0 1 0 1 0 1] /C0 [1 1 1] /C1 [0 0 0] /N 1>>]>>
    ),
  )
  let srgb = p.path(res, ["ColorSpace", "c0"])
  let profile = p.items(srgb)[1]
  inspect(
    p.show(profile),
    content=(
      #|stream<</N 3 /Range [0 1 0 1 0 1] /Filter /FlateDecode /Length 316>>
    ),
  )
  // The v4 sRGB profile for PDF 1.7.
  inspect(p.stream_data(profile)[8], content="b'\\x04'")
  // Transparency groups, shadings and separations use the ICC-based spaces.
  let x0 = p.path(res, ["XObject", "x0"])
  inspect(p.show(p.path(x0, ["Group", "CS"])) == p.show(srgb), content="true")
  let shading = p.path(x0, ["Resources", "Pattern", "p0", "Shading"])
  inspect(p.show(p.get(shading, "ColorSpace")) == p.show(srgb), content="true")
  let sep = p.path(res, ["ColorSpace", "c2"])
  inspect(p.show(p.items(sep)[2]) == p.show(srgb), content="true")
  let image = p.path(res, ["XObject", "x1"])
  inspect(
    p.show(p.get(image, "ColorSpace")) ==
    p.show(p.path(res, ["ColorSpace", "c1"])),
    content="true",
  )
}

///|
test "PDF/A uses ICC-based colors and an sRGB output intent" {
  let draw = (s : @export.Surface) => {
    s.set_fill(Some(fill_of(solid(255, 0, 0))))
    s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
  }
  let p = parse(
    one_page(s => draw(s), settings=settings_with(a=Some(A2_B), version=Pdf16)),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|/c0 cs
      #|1 0 0 scn
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
  let oi = p.items(p.get(p.catalog(), "OutputIntents"))
  inspect(
    p.show(oi[0]),
    content=(
      #|<</Type /OutputIntent /DestOutputProfile R /S /GTS_PDFA1 /OutputConditionIdentifier (Custom) /OutputCondition (sRGB) /RegistryName () /Info (sRGB v2.1)>>
    ),
  )
  // PDF 1.4 to 1.6 use the v2 profile.
  let profile = p.get(oi[0], "DestOutputProfile")
  inspect(p.stream_data(profile)[8], content="b'\\x02'")
  // The page's color space uses the same profile.
  let cs = p.path(p.page(0), ["Resources", "ColorSpace", "c0"])
  inspect(p.show(p.items(cs)[1]) == p.show(p.resolve(profile)), content="true")
  // There is no CMYK profile.
  inspect(
    export_result(() => {
      one_page(
        s => {
          s.set_fill(Some(fill_of(Color(Regular(Cmyk(0, 0, 0, 255))))))
          s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
        },
        settings=settings_with(a=Some(A2_B)),
      )
    }),
    content=(
      #|Validation: MissingCMYKProfile by PDF/A-2b
    ),
  )
}

///|
test "PostScript functions declare the components of the stops' color space" {
  let sweep = @export.SweepGradient::{
    cx: 5.0,
    cy: 5.0,
    start_angle: 0.0,
    end_angle: 360.0,
    transform: @export.Transform::identity(),
    spread_method: Pad,
    stops: stops2(Regular(Luma(0)), Regular(Luma(255))),
    anti_alias: false,
  }
  let p = parse(
    one_page(s => {
      s.set_fill(Some(fill_of(SweepGradient(sweep))))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      s.set_fill(
        Some(
          fill_of(
            SweepGradient({
              ..sweep,
              stops: stops2(
                Regular(Cmyk(255, 0, 0, 0)),
                Regular(Cmyk(0, 0, 0, 255)),
              ),
            }),
          ),
        ),
      )
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
    }),
  )
  let range = (name : String) => {
    let shading = p.path(p.page(0), ["Resources", "Pattern", name, "Shading"])
    p.show(p.get(shading, "ColorSpace")) +
    " " +
    p.show(p.path(shading, ["Function", "Range"]))
  }
  inspect(
    range("p0"),
    content=(
      #|/DeviceGray [0 1]
    ),
  )
  inspect(
    range("p1"),
    content=(
      #|/DeviceCMYK [0 1 0 1 0 1 0 1]
    ),
  )
}

///|
test "single-stop gradients apply the stop opacity" {
  let one_stop = (opacity : Double) => @export.LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 10.0,
    y2: 0.0,
    transform: @export.Transform::identity(),
    spread_method: Pad,
    stops: [{ offset: 0.5, color: @export.Color::rgb(0, 0, 255), opacity, }],
    anti_alias: false,
  }
  let p = parse(
    one_page(s => {
      s.set_fill(
        Some({ ..fill_of(LinearGradient(one_stop(0.5))), opacity: 0.5, }),
      )
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      s.set_fill(None)
      s.set_stroke(Some(stroke_of(LinearGradient(one_stop(0.4)), 1.0)))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
    }),
  )
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|/g0 gs
      #|0 0 1 rg
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/g1 gs
      #|0 0 1 RG
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|S
      #|Q
      #|
    ),
  )
  inspect(
    p.show_deep(p.path(p.page(0), ["Resources", "ExtGState"])),
    content=(
      #|<</g0 <</Type /ExtGState /ca 0.25>> /g1 <</Type /ExtGState /CA 0.4>>>>
    ),
  )
}

///|
test "gradients without stops paint nothing and mixed stops are converted" {
  let empty = @export.LinearGradient::{
    x1: 0.0,
    y1: 0.0,
    x2: 10.0,
    y2: 0.0,
    transform: @export.Transform::identity(),
    spread_method: Pad,
    stops: [],
    anti_alias: false,
  }
  let p = parse(
    one_page(s => {
      s.set_fill(Some(fill_of(LinearGradient(empty))))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      s.set_fill(
        Some(
          fill_of(
            SweepGradient({
              cx: 0.0,
              cy: 0.0,
              start_angle: 0.0,
              end_angle: 90.0,
              transform: @export.Transform::identity(),
              spread_method: Pad,
              stops: [],
              anti_alias: false,
            }),
          ),
        ),
      )
      s.set_stroke(Some(stroke_of(solid(0, 0, 0), 1.0)))
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
      s.set_stroke(None)
      s.set_fill(
        Some(
          fill_of(
            LinearGradient({
              ..empty,
              stops: [
                { offset: 0.0, color: Regular(Luma(0)), opacity: 1.0, },
                {
                  offset: 0.5,
                  color: Regular(Cmyk(0, 255, 255, 0)),
                  opacity: 1.0,
                },
                {
                  offset: 1.0,
                  color: Separation(128, {
                    colorant: Custom("S"),
                    fallback: Rgb(0, 0, 255),
                  }),
                  opacity: 1.0,
                },
              ],
            }),
          ),
        ),
      )
      s.draw_path(rect_path(0.0, 0.0, 10.0, 10.0))
    }),
  )
  // Only the stroke of the second path and the third path are drawn.
  inspect(
    p.content(p.page(0)),
    content=(
      #|q
      #|1 0 0 -1 0 100 cm
      #|0 0 0 RG
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|S
      #|Q
      #|q
      #|1 0 0 -1 0 100 cm
      #|/Pattern cs
      #|/p0 scn
      #|0 0 m
      #|10 0 l
      #|10 10 l
      #|0 10 l
      #|h
      #|f
      #|Q
      #|
    ),
  )
  let shading = p.path(p.page(0), ["Resources", "Pattern", "p0", "Shading"])
  inspect(
    p.show(p.get(shading, "ColorSpace")),
    content=(
      #|/DeviceRGB
    ),
  )
  let f = p.get(shading, "Function")
  inspect(
    p.items(p.get(f, "Functions")).map(g => p.show(g)).join("\n"),
    content=(
      #|<</FunctionType 2 /Range [0 1 0 1 0 1] /C0 [0 0 0] /C1 [1 0 0] /Domain [0 1] /N 1>>
      #|<</FunctionType 2 /Range [0 1 0 1 0 1] /C0 [1 0 0] /C1 [0.49804 0.49804 1] /Domain [0 1] /N 1>>
    ),
  )
}
