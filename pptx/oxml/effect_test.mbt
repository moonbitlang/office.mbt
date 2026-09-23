// Modified for office.mbt: follow the workspace warning conventions.
// @oxml.EffectList parser tests.

///|
fn parse_effect_list_inner(
  inner : String,
) -> @oxml.EffectList raise @oxml.EffectError {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\"><a:effectLst>" +
    inner +
    "</a:effectLst></wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch {
    _ => raise MalformedEffect("test wrapper open failed")
  }
  // advance to <a:effectLst> StartElement
  while true {
    let ev = r.next() catch {
      _ => raise MalformedEffect("test wrapper inner failed")
    }
    match ev {
      Some(StartElement(_, _)) => return @oxml.parse_effect_list(r)
      Some(EndElement(_)) => raise MalformedEffect("empty wrapper")
      Some(_) => ()
      None => raise MalformedEffect("unexpected end of test wrapper")
    }
  }
  raise MalformedEffect("unreachable")
}

// --- empty effectLst ---

///|
test "EffectList: empty list parses to all-None" {
  let fx = parse_effect_list_inner("")
  debug_inspect(fx.blur is None, content="true")
  debug_inspect(fx.glow is None, content="true")
  debug_inspect(fx.inner_shadow is None, content="true")
  debug_inspect(fx.outer_shadow is None, content="true")
  debug_inspect(fx.preset_shadow is None, content="true")
  debug_inspect(fx.reflection is None, content="true")
  debug_inspect(fx.soft_edge is None, content="true")
}

// --- blur ---

///|
test "EffectList: blur with rad + grow" {
  let fx = parse_effect_list_inner("<a:blur rad=\"50800\" grow=\"1\"/>")
  let b = fx.blur.unwrap()
  debug_inspect(b.rad, content="Emu(50800)")
  debug_inspect(b.grow.unwrap(), content="true")
}

///|
test "EffectList: blur missing rad defaults to 0 (ECMA-376 default)" {
  let fx = parse_effect_list_inner("<a:blur/>")
  debug_inspect(fx.blur.unwrap().rad, content="Emu(0)")
}

///|
test "EffectList: minimal outerShdw (blurRad only) parses with dist/dir = 0" {
  let fx = parse_effect_list_inner(
    "<a:outerShdw blurRad=\"40000\"><a:srgbClr val=\"000000\"/></a:outerShdw>",
  )
  let s = fx.outer_shadow.unwrap()
  debug_inspect(s.blur_rad, content="Emu(40000)")
  debug_inspect(s.dist, content="Emu(0)")
  debug_inspect(s.dir, content="Angle(0)")
}

// --- glow ---

///|
test "EffectList: glow with srgb colour" {
  let fx = parse_effect_list_inner(
    "<a:glow rad=\"63500\"><a:srgbClr val=\"FFC000\"/></a:glow>",
  )
  let g = fx.glow.unwrap()
  debug_inspect(g.rad, content="Emu(63500)")
  match g.color.base {
    Srgb(rgb) => debug_inspect(rgb.to_hex(), content="\"FFC000\"")
    _ => fail("expected Srgb base")
  }
}

///|
test "EffectList: glow without colour raises" {
  try parse_effect_list_inner("<a:glow rad=\"63500\"/>") catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
}

// --- innerShdw ---

///|
test "EffectList: innerShdw full" {
  let fx = parse_effect_list_inner(
    "<a:innerShdw blurRad=\"50800\" dist=\"38100\" dir=\"2700000\"><a:srgbClr val=\"000000\"/></a:innerShdw>",
  )
  let s = fx.inner_shadow.unwrap()
  debug_inspect(s.blur_rad, content="Emu(50800)")
  debug_inspect(s.dist, content="Emu(38100)")
  debug_inspect(s.dir == @units.Angle::from_ooxml(2700000), content="true")
  match s.color.base {
    Srgb(rgb) => debug_inspect(rgb.to_hex(), content="\"000000\"")
    _ => fail("expected Srgb base")
  }
}

///|
test "EffectList: innerShdw without colour raises" {
  try
    parse_effect_list_inner(
      "<a:innerShdw blurRad=\"50800\" dist=\"38100\" dir=\"2700000\"/>",
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
}

// --- outerShdw ---

///|
test "EffectList: outerShdw with optionals" {
  let fx = parse_effect_list_inner(
    "<a:outerShdw blurRad=\"50800\" dist=\"38100\" dir=\"5400000\" sx=\"100000\" sy=\"100000\" algn=\"b\" rotWithShape=\"0\"><a:srgbClr val=\"333333\"/></a:outerShdw>",
  )
  let s = fx.outer_shadow.unwrap()
  debug_inspect(s.blur_rad, content="Emu(50800)")
  debug_inspect(s.dist, content="Emu(38100)")
  debug_inspect(s.dir == @units.Angle::from_ooxml(5400000), content="true")
  debug_inspect(
    s.sx.unwrap() == @units.Percentage::from_ooxml(100000),
    content="true",
  )
  debug_inspect(
    s.sy.unwrap() == @units.Percentage::from_ooxml(100000),
    content="true",
  )
  debug_inspect(s.alignment.unwrap() is RectBottom, content="true")
  debug_inspect(s.rotate_with_shape.unwrap(), content="false")
}

///|
test "EffectList: outerShdw minimal (no optionals)" {
  let fx = parse_effect_list_inner(
    "<a:outerShdw blurRad=\"40000\" dist=\"20000\" dir=\"2700000\"><a:srgbClr val=\"808080\"/></a:outerShdw>",
  )
  let s = fx.outer_shadow.unwrap()
  debug_inspect(s.sx is None, content="true")
  debug_inspect(s.sy is None, content="true")
  debug_inspect(s.kx is None, content="true")
  debug_inspect(s.ky is None, content="true")
  debug_inspect(s.alignment is None, content="true")
  debug_inspect(s.rotate_with_shape is None, content="true")
}

// --- prstShdw ---

///|
test "EffectList: prstShdw" {
  let fx = parse_effect_list_inner(
    "<a:prstShdw prst=\"shdw17\" dist=\"38100\" dir=\"2700000\"><a:srgbClr val=\"AABBCC\"/></a:prstShdw>",
  )
  let s = fx.preset_shadow.unwrap()
  debug_inspect(s.preset, content="\"shdw17\"")
  debug_inspect(s.dist, content="Emu(38100)")
  match s.color.base {
    Srgb(rgb) => debug_inspect(rgb.to_hex(), content="\"AABBCC\"")
    _ => fail("expected Srgb base")
  }
}

///|
test "EffectList: prstShdw missing prst attribute raises" {
  try
    parse_effect_list_inner(
      "<a:prstShdw dist=\"38100\" dir=\"2700000\"><a:srgbClr val=\"AABBCC\"/></a:prstShdw>",
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
}

// --- softEdge ---

///|
test "EffectList: softEdge with rad" {
  let fx = parse_effect_list_inner("<a:softEdge rad=\"31750\"/>")
  let s = fx.soft_edge.unwrap()
  debug_inspect(s.rad, content="Emu(31750)")
}

// --- reflection ---

///|
test "EffectList: reflection with several attrs" {
  let fx = parse_effect_list_inner(
    "<a:reflection blurRad=\"6350\" stA=\"60000\" stPos=\"0\" endA=\"300\" endPos=\"60000\" dist=\"50800\" dir=\"5400000\" sy=\"-100000\" algn=\"bl\" rotWithShape=\"0\"/>",
  )
  let r = fx.reflection.unwrap()
  debug_inspect(r.blur_rad.unwrap(), content="Emu(6350)")
  debug_inspect(r.dist.unwrap(), content="Emu(50800)")
  debug_inspect(
    r.sy.unwrap() == @units.Percentage::from_ooxml(-100000),
    content="true",
  )
  debug_inspect(r.alignment.unwrap() is RectBottomLeft, content="true")
  debug_inspect(r.rotate_with_shape.unwrap(), content="false")
}

///|
test "EffectList: reflection bare (all attrs optional)" {
  let fx = parse_effect_list_inner("<a:reflection/>")
  let r = fx.reflection.unwrap()
  debug_inspect(r.blur_rad is None, content="true")
  debug_inspect(r.dist is None, content="true")
  debug_inspect(r.dir is None, content="true")
  debug_inspect(r.alignment is None, content="true")
}

// --- combined ---

///|
test "EffectList: glow + outerShdw together" {
  let fx = parse_effect_list_inner(
    "<a:glow rad=\"63500\"><a:srgbClr val=\"FFC000\"/></a:glow>" +
    "<a:outerShdw blurRad=\"40000\" dist=\"20000\" dir=\"2700000\"><a:srgbClr val=\"000000\"/></a:outerShdw>",
  )
  debug_inspect(!(fx.glow is None), content="true")
  debug_inspect(!(fx.outer_shadow is None), content="true")
  debug_inspect(fx.blur is None, content="true")
}

// --- unknown / skipped children ---

///|
test "EffectList: unknown child is skipped, others still parse" {
  let fx = parse_effect_list_inner(
    "<a:fillOverlay blend=\"over\"><a:srgbClr val=\"FF0000\"/></a:fillOverlay>" +
    "<a:softEdge rad=\"12700\"/>",
  )
  let s = fx.soft_edge.unwrap()
  debug_inspect(s.rad, content="Emu(12700)")
}

// --- RectAlignment::from_xml ---

///|
test "RectAlignment::from_xml round-trips known values" {
  debug_inspect(
    @oxml.RectAlignment::from_xml("tl").unwrap() is RectTopLeft,
    content="true",
  )
  debug_inspect(
    @oxml.RectAlignment::from_xml("ctr").unwrap() is RectCenter,
    content="true",
  )
  debug_inspect(
    @oxml.RectAlignment::from_xml("br").unwrap() is RectBottomRight,
    content="true",
  )
  debug_inspect(@oxml.RectAlignment::from_xml("bogus") is None, content="true")
}
