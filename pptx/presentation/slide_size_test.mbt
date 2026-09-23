// Modified for office.mbt: follow the workspace warning conventions.
// Tests for `Presentation::set_slide_size_mut`.

///|
test "SlideSizeKind: dimensions of common presets" {
  let (cx, cy) = @presentation.SlideSizeKind::ScreenFourByThree.dimensions()
  assert_eq(cx, Emu(9_144_000L))
  assert_eq(cy, Emu(6_858_000L))
  let (cx, cy) = @presentation.SlideSizeKind::Widescreen.dimensions()
  assert_eq(cx, Emu(12_192_000L))
  assert_eq(cy, Emu(6_858_000L))
  let (cx, cy) = @presentation.SlideSizeKind::A4.dimensions()
  assert_eq(cx, Emu(10_692_000L))
  assert_eq(cy, Emu(7_560_000L))
}

///|
test "SlideSizeKind: size_type strings match ST_SlideSizeType" {
  assert_eq(
    @presentation.SlideSizeKind::ScreenFourByThree.size_type(),
    "screen4x3",
  )
  assert_eq(
    @presentation.SlideSizeKind::ScreenSixteenByNine.size_type(),
    "screen16x9",
  )
  // Widescreen omits the `type` attribute entirely — see size_type's doc.
  assert_eq(@presentation.SlideSizeKind::Widescreen.size_type(), "")
  assert_eq(@presentation.SlideSizeKind::Letter.size_type(), "letter")
  assert_eq(@presentation.SlideSizeKind::A4.size_type(), "A4")
}

///|
test "SlideSizeKind::Custom honours user-supplied EMU dimensions" {
  let kind = @presentation.SlideSizeKind::Custom(
    Emu(11_111_111L),
    Emu(2_222_222L),
  )
  let (cx, cy) = kind.dimensions()
  assert_eq(cx, Emu(11_111_111L))
  assert_eq(cy, Emu(2_222_222L))
  // Custom dimensions omit the type attribute.
  assert_eq(kind.size_type(), "")
}

///|
test "set_slide_size_mut: switches a fresh deck to 16:9 widescreen" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Widescreen)
  let pres = prs.presentation_part().unwrap()
  let sz = pres.sld_sz.unwrap()
  assert_eq(sz.cx, Emu(12_192_000L))
  assert_eq(sz.cy, Emu(6_858_000L))
  // Widescreen → no `type` attribute (PowerPoint convention).
  assert_eq(sz.size_type, "")
}

///|
test "set_slide_size_mut: survives save → reopen" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(A4)
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  let sz = prs2.presentation_part().unwrap().sld_sz.unwrap()
  assert_eq(sz.cx, Emu(10_692_000L))
  assert_eq(sz.cy, Emu(7_560_000L))
  assert_eq(sz.size_type, "A4")
}

///|
test "set_slide_size_mut: Custom EMU pair survives save → reopen" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Custom(Emu(8_000_000L), Emu(4_500_000L)))
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  let sz = prs2.presentation_part().unwrap().sld_sz.unwrap()
  assert_eq(sz.cx, Emu(8_000_000L))
  assert_eq(sz.cy, Emu(4_500_000L))
  // Custom dimensions omit the `type` attribute (PowerPoint convention).
  assert_eq(sz.size_type, "")
}

///|
test "SlideSizeKind::to_slide_size mirrors dimensions + size_type" {
  for
    kind in [
      @presentation.SlideSizeKind::ScreenFourByThree,
      Widescreen,
      Custom(Emu(123L), Emu(456L)),
    ] {
    let size = kind.to_slide_size()
    let (cx, cy) = kind.dimensions()
    assert_eq(size.cx, cx)
    assert_eq(size.cy, cy)
    assert_eq(size.size_type, kind.size_type())
  }
}
