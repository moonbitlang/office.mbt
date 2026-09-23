// Modified for office.mbt: follow the workspace warning conventions.
// Builder-side tests for the `<a:effectLst>` records. `effect_test.mbt`
// and `effect_writer_test.mbt` cover the parse and write directions; these
// cover constructing a list from scratch, which is what
// `PictureUncropped::with_effects` needs.

///|
/// Read an effect list back out of the XML `effect_to_xml` produced, so a
/// builder-made value can be checked against what the writer and parser
/// agree on.
fn reparse_effect_list(el : @oxml.EffectList) -> @oxml.EffectList raise {
  let r = @xml.XmlReader::new(effect_to_xml(el))
  let _ = r.next() catch {
    _ => raise @oxml.EffectError::MalformedEffect("wrapper open failed")
  }
  while true {
    let ev = r.next() catch {
      _ => raise @oxml.EffectError::MalformedEffect("wrapper inner failed")
    }
    match ev {
      Some(StartElement(_, _)) => return @oxml.parse_effect_list(r)
      Some(EndElement(_)) =>
        raise @oxml.EffectError::MalformedEffect("empty wrapper")
      Some(_) => ()
      None => raise @oxml.EffectError::MalformedEffect("unexpected end")
    }
  }
  raise @oxml.EffectError::MalformedEffect("unreachable")
}

///|
test "Blur / Glow / SoftEdge constructors set their fields" {
  let blur = @oxml.Blur::new(Emu(50_800L))
  debug_inspect(blur.rad, content="Emu(50800)")
  debug_inspect(blur.grow is None, content="true")
  debug_inspect(@oxml.Blur::new(Emu(1L), grow=true).grow, content="Some(true)")
  let red = @oxml.Color::srgb(@units.RgbColor::new(0xFF, 0x00, 0x00))
  let glow = @oxml.Glow::new(Emu(63_500L), red)
  debug_inspect(glow.rad, content="Emu(63500)")
  debug_inspect(glow.color == red, content="true")
  debug_inspect(@oxml.SoftEdge::new(Emu(12_700L)).rad, content="Emu(12700)")
}

///|
test "InnerShadow / PresetShadow constructors set every required attribute" {
  let black = @oxml.Color::srgb(@units.RgbColor::new(0, 0, 0))
  let inner = @oxml.InnerShadow::new(
    blur_rad=Emu(50_800L),
    dist=Emu(25_400L),
    dir=@units.Angle::from_ooxml(2_700_000),
    color=black,
  )
  debug_inspect(inner.blur_rad, content="Emu(50800)")
  debug_inspect(inner.dist, content="Emu(25400)")
  debug_inspect(inner.dir.to_ooxml(), content="2700000")
  let preset = @oxml.PresetShadow::new(
    "shdw4",
    dist=Emu(38_100L),
    dir=@units.Angle::from_ooxml(5_400_000),
    color=black,
  )
  debug_inspect(preset.preset, content="\"shdw4\"")
  debug_inspect(preset.dist, content="Emu(38100)")
  debug_inspect(preset.dir.to_ooxml(), content="5400000")
}

///|
test "OuterShadow::new leaves the optionals unset; with_* fill them" {
  let black = @oxml.Color::srgb(@units.RgbColor::new(0, 0, 0))
  let base = @oxml.OuterShadow::new(
    blur_rad=Emu(50_800L),
    dist=Emu(25_400L),
    dir=@units.Angle::from_ooxml(2_700_000),
    color=black,
  )
  debug_inspect(base.sx is None && base.kx is None, content="true")
  debug_inspect(
    base.alignment is None && base.rotate_with_shape is None,
    content="true",
  )
  let full = base
    .with_scale(sx=Percentage(90.0), sy=Percentage(80.0))
    .with_skew(
      kx=@units.Angle::from_ooxml(60_000),
      ky=@units.Angle::from_ooxml(120_000),
    )
    .with_alignment(RectBottomLeft)
    .with_rotate_with_shape(false)
  debug_inspect(full.sx, content="Some(Percentage(90))")
  debug_inspect(full.sy, content="Some(Percentage(80))")
  debug_inspect(full.kx.unwrap().to_ooxml(), content="60000")
  debug_inspect(full.ky.unwrap().to_ooxml(), content="120000")
  debug_inspect(full.alignment is Some(RectBottomLeft), content="true")
  debug_inspect(full.rotate_with_shape, content="Some(false)")
  // The base is untouched — builders are immutable (ADR-003).
  debug_inspect(base.sx is None, content="true")
}

///|
test "Reflection::default is empty; with_* set every attribute" {
  let r = @oxml.Reflection::default()
  debug_inspect(
    r.blur_rad is None && r.st_a is None && r.dir is None,
    content="true",
  )
  let full = r
    .with_blur_rad(Emu(6_350L))
    .with_alpha(start=Percentage(60.0), end=Percentage(0.0))
    .with_positions(start=Percentage(0.0), end=Percentage(55.0))
    .with_distance(Emu(50_800L))
    .with_direction(@units.Angle::from_ooxml(5_400_000))
    .with_fade_direction(@units.Angle::from_ooxml(5_400_000))
    .with_scale(sx=Percentage(100.0), sy=Percentage(-100.0))
    .with_skew(
      kx=@units.Angle::from_ooxml(0),
      ky=@units.Angle::from_ooxml(30_000),
    )
    .with_alignment(RectBottomLeft)
    .with_rotate_with_shape(false)
  debug_inspect(full.blur_rad, content="Some(Emu(6350))")
  debug_inspect(full.st_a, content="Some(Percentage(60))")
  debug_inspect(full.end_a, content="Some(Percentage(0))")
  debug_inspect(full.st_pos, content="Some(Percentage(0))")
  debug_inspect(full.end_pos, content="Some(Percentage(55))")
  debug_inspect(full.dist, content="Some(Emu(50800))")
  debug_inspect(full.dir.unwrap().to_ooxml(), content="5400000")
  debug_inspect(full.fade_dir.unwrap().to_ooxml(), content="5400000")
  debug_inspect(full.sx, content="Some(Percentage(100))")
  debug_inspect(full.sy, content="Some(Percentage(-100))")
  debug_inspect(full.kx.unwrap().to_ooxml(), content="0")
  debug_inspect(full.ky.unwrap().to_ooxml(), content="30000")
  debug_inspect(full.alignment is Some(RectBottomLeft), content="true")
  debug_inspect(full.rotate_with_shape, content="Some(false)")
}

///|
test "EffectList::empty + with_* build a list the writer round-trips" {
  let black = @oxml.Color::srgb(@units.RgbColor::new(0, 0, 0))
  let red = @oxml.Color::srgb(@units.RgbColor::new(0xFF, 0x00, 0x00))
  let empty = @oxml.EffectList::empty()
  debug_inspect(
    empty.blur is None && empty.outer_shadow is None,
    content="true",
  )
  debug_inspect(empty.extension.length(), content="0")
  let el = empty
    .with_blur(@oxml.Blur::new(Emu(50_800L), grow=true))
    .with_glow(@oxml.Glow::new(Emu(63_500L), red))
    .with_inner_shadow(
      @oxml.InnerShadow::new(
        blur_rad=Emu(50_800L),
        dist=Emu(25_400L),
        dir=@units.Angle::from_ooxml(2_700_000),
        color=black,
      ),
    )
    .with_outer_shadow(
      @oxml.OuterShadow::new(
        blur_rad=Emu(50_800L),
        dist=Emu(25_400L),
        dir=@units.Angle::from_ooxml(2_700_000),
        color=black,
      ).with_scale(sx=Percentage(90.0), sy=Percentage(90.0)),
    )
    .with_preset_shadow(
      @oxml.PresetShadow::new(
        "shdw4",
        dist=Emu(38_100L),
        dir=@units.Angle::from_ooxml(5_400_000),
        color=black,
      ),
    )
    .with_reflection(@oxml.Reflection::default().with_blur_rad(Emu(6_350L)))
    .with_soft_edge(@oxml.SoftEdge::new(Emu(12_700L)))
  // Every slot is set, and the whole list survives write -> parse.
  debug_inspect(el.blur is Some(_) && el.glow is Some(_), content="true")
  debug_inspect(
    el.inner_shadow is Some(_) && el.outer_shadow is Some(_),
    content="true",
  )
  debug_inspect(
    el.preset_shadow is Some(_) && el.reflection is Some(_),
    content="true",
  )
  debug_inspect(el.soft_edge is Some(_), content="true")
  debug_inspect(reparse_effect_list(el) == el, content="true")
}
