// Modified for office.mbt: follow the workspace warning conventions.
// Tests for the animation DSL — typed `<p:timing>`.

///|
/// Serialise a slide to an XML string for structural assertions.
fn anim_xml(slide : @slide.Slide) -> String raise {
  @oxml.bytes_to_string(slide.serialize())
}

///|
/// Count non-overlapping occurrences of `needle` in `haystack`.
fn count(haystack : String, needle : String) -> Int {
  for rest = haystack[:], total = 0 {
    match rest.find(needle) {
      Some(at) => continue rest[at + needle.length():], total + 1
      None => break total
    }
  }
}

///|
/// A real parsed slide (the title-slide fixture already carries a `<p:timing>`
/// in `extension`, which `with_animations` must strip when a typed timeline is set).
fn anim_base_slide() -> @slide.Slide raise {
  @slide.Slide::parse(typical_title_slide())
}

// --- Direction / orientation filter words ---

///|
test "AnimDirection / AnimOrientation map to their filter words" {
  debug_inspect(@slide.AnimDirection::Up.to_filter(), content="\"up\"")
  debug_inspect(@slide.AnimDirection::Down.to_filter(), content="\"down\"")
  debug_inspect(@slide.AnimDirection::Left.to_filter(), content="\"left\"")
  debug_inspect(@slide.AnimDirection::Right.to_filter(), content="\"right\"")
  debug_inspect(
    @slide.AnimOrientation::Horizontal.to_filter(),
    content="\"horizontal\"",
  )
  debug_inspect(
    @slide.AnimOrientation::Vertical.to_filter(),
    content="\"vertical\"",
  )
}

// --- VisualEffect metadata ---

///|
test "VisualEffect::filter maps each effect to its DrawingML filter" {
  debug_inspect(@slide.VisualEffect::Fade.filter().unwrap(), content="\"fade\"")
  debug_inspect(
    @slide.VisualEffect::Wipe(Up).filter().unwrap(),
    content="\"wipe(up)\"",
  )
  debug_inspect(
    @slide.VisualEffect::Wipe(Right).filter().unwrap(),
    content="\"wipe(right)\"",
  )
  debug_inspect(
    @slide.VisualEffect::Blinds(Vertical).filter().unwrap(),
    content="\"blinds(vertical)\"",
  )
  debug_inspect(
    @slide.VisualEffect::RandomBars(Horizontal).filter().unwrap(),
    content="\"randombar(horizontal)\"",
  )
  debug_inspect(
    @slide.VisualEffect::Dissolve.filter().unwrap(),
    content="\"dissolve\"",
  )
  debug_inspect(
    @slide.VisualEffect::Wedge.filter().unwrap(),
    content="\"wedge\"",
  )
  debug_inspect(
    @slide.VisualEffect::Wheel(8).filter().unwrap(),
    content="\"wheel(8)\"",
  )
  // Appear is a bare <p:set> — no animEffect filter.
  debug_inspect(@slide.VisualEffect::Appear.filter() is None, content="true")
}

///|
test "VisualEffect::preset_id matches the entrance preset numbering" {
  debug_inspect(@slide.VisualEffect::Appear.preset_id(), content="1")
  debug_inspect(@slide.VisualEffect::Fade.preset_id(), content="10")
  debug_inspect(@slide.VisualEffect::Wipe(Up).preset_id(), content="22")
  debug_inspect(@slide.VisualEffect::Wheel(4).preset_id(), content="21")
}

// --- Slide builders ---

///|
test "Slide::with_animations sets the typed field and strips extension timing" {
  let base = anim_base_slide()
  // The fixture parsed its <p:timing> into extension; the typed field is None.
  debug_inspect(base.timing is None, content="true")
  debug_inspect(
    base.extension.map(e => e.name.local_name).contains("timing"),
    content="true",
  )
  let animated = base.with_animations(
    @slide.Timeline::new().on_click(Entrance(Fade), 2),
  )
  debug_inspect(animated.timing is Some(_), content="true")
  // The captured <p:timing> is gone — the typed timeline is the single source.
  debug_inspect(
    animated.extension.map(e => e.name.local_name).contains("timing"),
    content="false",
  )
}

///|
test "Slide::without_animations clears the typed field and extension timing" {
  let base = anim_base_slide()
  let cleared = base
    .with_animations(@slide.Timeline::new().on_click(Entrance(Fade), 2))
    .without_animations()
  debug_inspect(cleared.timing is None, content="true")
  debug_inspect(
    cleared.extension.map(e => e.name.local_name).contains("timing"),
    content="false",
  )
}

///|
test "Slide::with_animations emits exactly one <p:timing> (no double-emit)" {
  let base = anim_base_slide()
  let animated = base.with_animations(
    @slide.Timeline::new().on_click(Entrance(Fade), 2),
  )
  let xml = anim_xml(animated)
  debug_inspect(count(xml, "<p:timing>"), content="1")
}

// --- Generated structure ---

///|
test "timing: entrance emits the canonical main-sequence scaffold" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(@slide.Timeline::new().on_click(Entrance(Fade), 7)),
  )
  debug_inspect(xml.contains("nodeType=\"tmRoot\""), content="true")
  debug_inspect(xml.contains("nodeType=\"mainSeq\""), content="true")
  debug_inspect(xml.contains("nodeType=\"clickEffect\""), content="true")
  debug_inspect(xml.contains("presetClass=\"entr\""), content="true")
  debug_inspect(xml.contains("presetID=\"10\""), content="true")
  debug_inspect(xml.contains("filter=\"fade\""), content="true")
  debug_inspect(xml.contains("transition=\"in\""), content="true")
  // Entrance reveals the shape.
  debug_inspect(xml.contains("<p:strVal val=\"visible\"/>"), content="true")
  // Targets the requested shape id.
  debug_inspect(xml.contains("<p:spTgt spid=\"7\"/>"), content="true")
  // The sequence navigation conditions are present.
  debug_inspect(xml.contains("<p:prevCondLst>"), content="true")
  debug_inspect(xml.contains("<p:nextCondLst>"), content="true")
}

///|
test "timing: exit plays out and hides the shape" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(@slide.Timeline::new().on_click(Exit(Wipe(Down)), 3)),
  )
  debug_inspect(xml.contains("presetClass=\"exit\""), content="true")
  debug_inspect(xml.contains("transition=\"out\""), content="true")
  debug_inspect(xml.contains("filter=\"wipe(down)\""), content="true")
  // Exit hides the shape at the end.
  debug_inspect(xml.contains("<p:strVal val=\"hidden\"/>"), content="true")
}

///|
test "timing: Appear is a bare <p:set> with no <p:animEffect>" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(@slide.Timeline::new().on_click(Entrance(Appear), 2)),
  )
  debug_inspect(xml.contains("<p:strVal val=\"visible\"/>"), content="true")
  debug_inspect(xml.contains("<p:animEffect"), content="false")
}

///|
test "timing: start modes map to clickEffect / afterEffect / withEffect" {
  let base = anim_base_slide()
  let tl = @slide.Timeline::new()
    .on_click(Entrance(Fade), 2)
    .after_previous(Entrance(Fade), 3)
    .with_previous(Entrance(Fade), 4)
  let xml = anim_xml(base.with_animations(tl))
  debug_inspect(xml.contains("nodeType=\"clickEffect\""), content="true")
  debug_inspect(xml.contains("nodeType=\"afterEffect\""), content="true")
  debug_inspect(xml.contains("nodeType=\"withEffect\""), content="true")
  // The click group waits for a click (delay indefinite); the after-previous
  // group auto-starts (delay 0).
  debug_inspect(xml.contains("<p:cond delay=\"indefinite\"/>"), content="true")
}

///|
test "timing: a leading with_previous step behaves like on_click" {
  let base = anim_base_slide()
  // No prior step to attach to → opens a click group.
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().with_previous(Entrance(Fade), 2),
    ),
  )
  debug_inspect(xml.contains("nodeType=\"clickEffect\""), content="true")
  debug_inspect(xml.contains("nodeType=\"withEffect\""), content="false")
}

// --- Emphasis effects ---

///|
test "EmphasisEffect::preset_id classifies each emphasis" {
  debug_inspect(@slide.EmphasisEffect::Spin(360).preset_id(), content="8")
  debug_inspect(@slide.EmphasisEffect::GrowShrink(150).preset_id(), content="6")
  debug_inspect(
    @slide.EmphasisEffect::ChangeFillColor(@units.RgbColor::new(0, 0, 0)).preset_id(),
    content="4",
  )
}

///|
test "timing: Spin emphasis emits <p:animRot> on the rotation attribute" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(Emphasis(Spin(360)), 2, duration_ms=2000),
    ),
  )
  debug_inspect(xml.contains("presetClass=\"emph\""), content="true")
  // 360° in 60000ths of a degree.
  debug_inspect(xml.contains("<p:animRot by=\"21600000\">"), content="true")
  debug_inspect(xml.contains("<p:attrName>r</p:attrName>"), content="true")
  debug_inspect(xml.contains("dur=\"2000\""), content="true")
  // Emphasis does not toggle visibility.
  debug_inspect(xml.contains("style.visibility"), content="false")
}

///|
test "timing: GrowShrink emphasis emits <p:animScale> with a <p:by>" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(Emphasis(GrowShrink(150)), 5),
    ),
  )
  debug_inspect(xml.contains("<p:animScale>"), content="true")
  // 150% in 1000ths of a percent.
  debug_inspect(
    xml.contains("<p:by x=\"150000\" y=\"150000\"/>"),
    content="true",
  )
  debug_inspect(xml.contains("<p:spTgt spid=\"5\"/>"), content="true")
}

///|
test "timing: ChangeFillColor emphasis emits <p:animClr> to an <a:srgbClr>" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(
        Emphasis(ChangeFillColor(@units.RgbColor::new(255, 0, 0))),
        2,
      ),
    ),
  )
  debug_inspect(xml.contains("<p:animClr clrSpc=\"rgb\">"), content="true")
  debug_inspect(xml.contains("<a:srgbClr val=\"FF0000\"/>"), content="true")
  debug_inspect(
    xml.contains("<p:attrName>fillColor</p:attrName>"),
    content="true",
  )
}

///|
test "timing: emphasis composes with entrance in one timeline" {
  let base = anim_base_slide()
  let tl = @slide.Timeline::new()
    .on_click(Entrance(Fade), 2)
    .after_previous(Emphasis(Spin(720)), 2, duration_ms=1500)
  let xml = anim_xml(base.with_animations(tl))
  debug_inspect(xml.contains("presetClass=\"entr\""), content="true")
  debug_inspect(xml.contains("presetClass=\"emph\""), content="true")
  // 720° = two turns.
  debug_inspect(xml.contains("<p:animRot by=\"43200000\">"), content="true")
}

// --- Fly In / Fly Out ---

///|
test "VisualEffect: FlyIn classifies as a fly, not a filter" {
  debug_inspect(
    @slide.VisualEffect::FlyIn(Left).fly_direction() is Some(Left),
    content="true",
  )
  debug_inspect(
    @slide.VisualEffect::FlyIn(Left).filter() is None,
    content="true",
  )
  debug_inspect(@slide.VisualEffect::FlyIn(Up).preset_id(), content="2")
  // A filter effect has no fly direction.
  debug_inspect(
    @slide.VisualEffect::Fade.fly_direction() is None,
    content="true",
  )
}

///|
test "timing: FlyIn entrance moves ppt_x from off-slide to home" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(Entrance(FlyIn(Left)), 5),
    ),
  )
  debug_inspect(xml.contains("presetClass=\"entr\""), content="true")
  // Reveal + a positional <p:anim> on ppt_x (no <p:animEffect> filter).
  debug_inspect(xml.contains("<p:strVal val=\"visible\"/>"), content="true")
  debug_inspect(
    xml.contains("<p:anim calcmode=\"lin\" valueType=\"num\">"),
    content="true",
  )
  debug_inspect(xml.contains("<p:attrName>ppt_x</p:attrName>"), content="true")
  debug_inspect(xml.contains("<p:strVal val=\"0-#ppt_w/2\"/>"), content="true")
  debug_inspect(xml.contains("<p:strVal val=\"#ppt_x\"/>"), content="true")
  debug_inspect(xml.contains("<p:animEffect"), content="false")
}

///|
test "timing: FlyOut exit moves home to off-slide then hides" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(@slide.Timeline::new().on_click(Exit(FlyIn(Down)), 5)),
  )
  debug_inspect(xml.contains("presetClass=\"exit\""), content="true")
  debug_inspect(xml.contains("<p:attrName>ppt_y</p:attrName>"), content="true")
  // Off-slide value at the END (tm=100000) for a fly-out below the slide.
  debug_inspect(xml.contains("<p:strVal val=\"1+#ppt_h/2\"/>"), content="true")
  // Exit hides the shape afterwards.
  debug_inspect(xml.contains("<p:strVal val=\"hidden\"/>"), content="true")
}

///|
test "timing: each fly direction targets the right axis + off-slide value" {
  let base = anim_base_slide()
  fn fly_xml(dir : @slide.AnimDirection) -> String raise {
    anim_xml(
      base.with_animations(
        @slide.Timeline::new().on_click(Entrance(FlyIn(dir)), 2),
      ),
    )
  }

  debug_inspect(
    fly_xml(Right).contains("<p:strVal val=\"1+#ppt_w/2\"/>"),
    content="true",
  )
  debug_inspect(
    fly_xml(Right).contains("<p:attrName>ppt_x</p:attrName>"),
    content="true",
  )
  debug_inspect(
    fly_xml(Up).contains("<p:strVal val=\"0-#ppt_h/2\"/>"),
    content="true",
  )
  debug_inspect(
    fly_xml(Up).contains("<p:attrName>ppt_y</p:attrName>"),
    content="true",
  )
}

// --- Motion paths ---

///|
test "MotionPath::to_path_string formats the animMotion mini-language" {
  // Move, line, cubic curve, close — terminated by the E end marker.
  let p = @slide.MotionPath::new()
    .move_to(0.0, 0.0)
    .line_to(0.3, 0.1)
    .curve_to(0.4, 0.2, 0.5, 0.0, 0.6, 0.1)
    .close()
  debug_inspect(
    p.to_path_string(),
    content="\"M 0 0 L 0.3 0.1 C 0.4 0.2 0.5 0 0.6 0.1 Z E\"",
  )
}

///|
test "MotionPath::line is a one-segment relative move" {
  debug_inspect(
    @slide.MotionPath::line(0.25, -0.1).to_path_string(),
    content="\"M 0 0 L 0.25 -0.1 E\"",
  )
}

///|
test "timing: motion emits <p:animMotion> with the path + ppt_x/ppt_y" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(
      @slide.Timeline::new().on_click(
        Motion(@slide.MotionPath::line(0.3, 0.1)),
        5,
        duration_ms=2000,
      ),
    ),
  )
  debug_inspect(xml.contains("presetClass=\"path\""), content="true")
  debug_inspect(
    xml.contains(
      "<p:animMotion origin=\"layout\" path=\"M 0 0 L 0.3 0.1 E\" pathEditMode=\"relative\">",
    ),
    content="true",
  )
  debug_inspect(xml.contains("<p:attrName>ppt_x</p:attrName>"), content="true")
  debug_inspect(xml.contains("<p:attrName>ppt_y</p:attrName>"), content="true")
  debug_inspect(xml.contains("<p:spTgt spid=\"5\"/>"), content="true")
  // Motion does not toggle visibility.
  debug_inspect(xml.contains("style.visibility"), content="false")
}

///|
test "timing: motion composes after an entrance in one timeline" {
  let base = anim_base_slide()
  let tl = @slide.Timeline::new()
    .on_click(Entrance(Fade), 2)
    .after_previous(
      Motion(
        @slide.MotionPath::new()
        .move_to(0.0, 0.0)
        .curve_to(0.1, 0.1, 0.2, -0.1, 0.3, 0.0),
      ),
      2,
    )
  let xml = anim_xml(base.with_animations(tl))
  debug_inspect(xml.contains("presetClass=\"entr\""), content="true")
  debug_inspect(xml.contains("presetClass=\"path\""), content="true")
  debug_inspect(xml.contains("C 0.1 0.1 0.2 -0.1 0.3 0"), content="true")
}

// --- By-paragraph text builds ---

///|
test "timing: a paragraph-targeted effect emits a <p:pRg> + a <p:bldP>" {
  let base = anim_base_slide()
  let tl = @slide.Timeline::new()
    .on_click(Entrance(Fade), 3, paragraph=0)
    .on_click(Entrance(Fade), 3, paragraph=1)
  let xml = anim_xml(base.with_animations(tl))
  // Each effect targets a paragraph range, not the whole shape.
  debug_inspect(
    xml.contains("<p:txEl><p:pRg st=\"0\" end=\"0\"/></p:txEl>"),
    content="true",
  )
  debug_inspect(
    xml.contains("<p:txEl><p:pRg st=\"1\" end=\"1\"/></p:txEl>"),
    content="true",
  )
  // The shape is declared as a by-paragraph build.
  debug_inspect(xml.contains("<p:bldLst>"), content="true")
  debug_inspect(
    xml.contains("<p:bldP spid=\"3\" grpId=\"1\" build=\"p\"/>"),
    content="true",
  )
}

///|
test "timing: a whole-shape effect has no <p:pRg> and no <p:bldLst>" {
  let base = anim_base_slide()
  let xml = anim_xml(
    base.with_animations(@slide.Timeline::new().on_click(Entrance(Fade), 2)),
  )
  debug_inspect(xml.contains("<p:pRg"), content="false")
  debug_inspect(xml.contains("<p:bldLst>"), content="false")
}

///|
test "timing: build-group ids match between paragraph effects and their <p:bldP>" {
  let base = anim_base_slide()
  // Two shapes built by paragraph → distinct grpIds 1 and 2; a whole-shape
  // effect stays in group 0.
  let tl = @slide.Timeline::new()
    .on_click(Entrance(Fade), 3, paragraph=0)
    .on_click(Entrance(Wipe(Up)), 4, paragraph=0)
    .with_previous(Emphasis(Spin(360)), 2)
  let xml = anim_xml(base.with_animations(tl))
  debug_inspect(
    xml.contains("<p:bldP spid=\"3\" grpId=\"1\" build=\"p\"/>"),
    content="true",
  )
  debug_inspect(
    xml.contains("<p:bldP spid=\"4\" grpId=\"2\" build=\"p\"/>"),
    content="true",
  )
  // The paragraph effects carry their shape's build grpId on the cTn.
  debug_inspect(xml.contains("grpId=\"1\""), content="true")
  debug_inspect(xml.contains("grpId=\"2\""), content="true")
  // The whole-shape emphasis stays in the default group 0.
  debug_inspect(xml.contains("grpId=\"0\""), content="true")
}

// --- Build-only round-trip ---

///|
test "timing: built timeline re-serialises stably (build-only round-trip)" {
  let base = anim_base_slide()
  let animated = base.with_animations(
    @slide.Timeline::new()
    .on_click(Entrance(FlyIn(Left)), 2)
    .with_previous(Emphasis(Spin(360)), 2)
    .after_previous(Motion(@slide.MotionPath::line(0.2, 0.0)), 2)
    .on_click(Entrance(Fade), 3, paragraph=0)
    .after_previous(Exit(Wipe(Up)), 3),
  )
  let xml1 = anim_xml(animated)
  // Parsing re-captures <p:timing> into extension; the typed field is None.
  let reparsed = @slide.Slide::parse(animated.serialize())
  debug_inspect(reparsed.timing is None, content="true")
  debug_inspect(
    reparsed.extension.map(e => e.name.local_name).contains("timing"),
    content="true",
  )
  // …but the bytes are stable across the round trip.
  let xml2 = anim_xml(reparsed)
  debug_inspect(xml1 == xml2, content="true")
}

///|
test "timing: a slide with no animations emits no <p:timing> from the field" {
  // Fresh built slide (no fixture timing); ensure we don't emit an empty tree.
  let base = anim_base_slide().without_animations()
  debug_inspect(base.timing is None, content="true")
  // (Fixture timing was stripped by without_animations.)
  let xml = anim_xml(base)
  debug_inspect(xml.contains("<p:timing>"), content="false")
}
