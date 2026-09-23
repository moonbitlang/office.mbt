// Modified for office.mbt: follow the workspace warning conventions.
// Tests for percentage / slide-extent positioning helpers.

///|
test "pct_w / pct_h on a fresh deck (4:3 default)" {
  let prs = @presentation.Presentation::new()
  // 4:3 defaults: 9_144_000 × 6_858_000 EMU.
  debug_inspect(prs.pct_w(0.0), content="Emu(0)")
  debug_inspect(prs.pct_w(100.0), content="Emu(9144000)")
  debug_inspect(prs.pct_w(50.0), content="Emu(4572000)")
  debug_inspect(prs.pct_h(100.0), content="Emu(6858000)")
  debug_inspect(prs.pct_h(50.0), content="Emu(3429000)")
}

///|
test "slide_w / slide_h on a fresh deck" {
  let prs = @presentation.Presentation::new()
  debug_inspect(prs.slide_w(), content="Emu(9144000)")
  debug_inspect(prs.slide_h(), content="Emu(6858000)")
}

///|
test "pct_w / pct_h follow slide-size changes" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Widescreen) // 12_192_000 × 6_858_000
  debug_inspect(prs.pct_w(100.0), content="Emu(12192000)")
  debug_inspect(prs.pct_w(25.0), content="Emu(3048000)")
  // Height unchanged for widescreen.
  debug_inspect(prs.pct_h(100.0), content="Emu(6858000)")
}

///|
test "pct_w / pct_h compose with shape builders" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // 10 % margin, full-bleed banner.
  let tb = @slide.AutoShape::textbox(
    id=2,
    name="Banner",
    x=prs.pct_w(10.0),
    y=prs.pct_h(5.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(15.0),
    "Hello",
  )
  prs.update_slide_mut(0, prs.slides()[0].with_shape(AutoShape(tb)))
  let s = prs.slides()[0]
  let auto = match s.shapes[0] {
    AutoShape(a) => a
    _ => fail("expected AutoShape")
  }
  let xfrm = auto.transform.unwrap()
  // For 4:3 defaults (9_144_000 × 6_858_000):
  //   10% × 9_144_000 = 914_400 ; 5% × 6_858_000 = 342_900
  //   80% × 9_144_000 = 7_315_200 ; 15% × 6_858_000 = 1_028_700
  debug_inspect(xfrm.offset.x, content="Emu(914400)")
  debug_inspect(xfrm.offset.y, content="Emu(342900)")
  debug_inspect(xfrm.extent.cx, content="Emu(7315200)")
  debug_inspect(xfrm.extent.cy, content="Emu(1028700)")
}
