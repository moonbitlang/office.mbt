// Modified for office.mbt: follow the workspace warning conventions.
// Tests for the typed picture builder state machine.
//
// The compile-time guarantees (no second `with_crop`; no `with_effects`
// after `build`) are enforced by the type system and so cannot be
// exercised at runtime — these tests cover the *values* each stage
// produces and that a fully-built picture round-trips.

///|
fn thin_stroke() -> @oxml.Stroke {
  {
    width: Some(Emu(12700L)),
    cap: None,
    compound: None,
    alignment: None,
    fill: None,
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
}

///|
fn pic_builder() -> @slide.PictureUncropped {
  @slide.Picture::builder(
    id=5,
    name="Pic",
    "rId2",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
}

// --- build at each stage ---

///|
test "Picture::builder: build with no crop/effects equals of_image" {
  let built = pic_builder().build()
  let flat = @slide.Picture::of_image(
    id=5,
    name="Pic",
    "rId2",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  debug_inspect(built == flat, content="true")
}

///|
test "Picture::builder: with_crop sets the source rectangle" {
  let pic = pic_builder()
    .with_crop(left=Percentage(10.0), right=Percentage(5.0))
    .build()
  match pic.blip_fill.src_rect {
    Some(rect) => {
      debug_inspect(rect.left, content="Percentage(10)")
      debug_inspect(rect.right, content="Percentage(5)")
    }
    None => fail("expected a crop rectangle")
  }
}

///|
test "Picture::builder: with_effects sets outline + effect list" {
  let stroke = thin_stroke()
  let effects = @oxml.EffectList::empty()
  let pic = pic_builder().with_effects(outline=stroke, effects~).build()
  debug_inspect(pic.stroke == Some(stroke), content="true")
  debug_inspect(pic.effects == Some(effects), content="true")
}

///|
test "Picture::builder: with_effects leaves omitted fields unset" {
  let pic = pic_builder().with_effects(outline=thin_stroke()).build()
  debug_inspect(pic.stroke is Some(_), content="true")
  debug_inspect(pic.effects is None, content="true")
}

///|
test "Picture::builder: crop then effects keeps both" {
  let pic = pic_builder()
    .with_crop(top=Percentage(8.0))
    .with_effects(outline=thin_stroke())
    .build()
  debug_inspect(pic.blip_fill.src_rect is Some(_), content="true")
  debug_inspect(pic.stroke is Some(_), content="true")
}

///|
test "Picture::builder: build straight after crop (no effects)" {
  let pic = pic_builder().with_crop(bottom=Percentage(3.0)).build()
  debug_inspect(pic.blip_fill.src_rect is Some(_), content="true")
  debug_inspect(pic.stroke is None, content="true")
  debug_inspect(pic.effects is None, content="true")
}

// --- round-trip ---

///|
test "Picture::builder: built picture round-trips through a slide" {
  let pic = pic_builder()
    .with_crop(left=Percentage(5.0), top=Percentage(5.0))
    .with_effects(outline=thin_stroke())
    .build()
  let reparsed = @slide.Slide::parse(slide_of_picture(pic).serialize())
  match reparsed.shapes[0] {
    Picture(p) => {
      debug_inspect(p.blip_fill.src_rect is Some(_), content="true")
      debug_inspect(p.stroke is Some(_), content="true")
    }
    _ => fail("expected a picture shape")
  }
}
