// Modified for office.mbt: follow the workspace warning conventions.
// Tests for `Presentation::set_slide_size_mut`.

///|
test "SlideSizeKind: dimensions of common presets" {
  let (cx, cy) = @presentation.SlideSizeKind::ScreenFourByThree.dimensions()
  debug_inspect(cx, content="Emu(9144000)")
  debug_inspect(cy, content="Emu(6858000)")
  let (cx, cy) = @presentation.SlideSizeKind::Widescreen.dimensions()
  debug_inspect(cx, content="Emu(12192000)")
  debug_inspect(cy, content="Emu(6858000)")
  let (cx, cy) = @presentation.SlideSizeKind::A4.dimensions()
  debug_inspect(cx, content="Emu(10692000)")
  debug_inspect(cy, content="Emu(7560000)")
}

///|
test "SlideSizeKind: size_type strings match ST_SlideSizeType" {
  debug_inspect(
    @presentation.SlideSizeKind::ScreenFourByThree.size_type(),
    content="\"screen4x3\"",
  )
  debug_inspect(
    @presentation.SlideSizeKind::ScreenSixteenByNine.size_type(),
    content="\"screen16x9\"",
  )
  // Widescreen omits the `type` attribute entirely — see size_type's doc.
  debug_inspect(
    @presentation.SlideSizeKind::Widescreen.size_type(),
    content="\"\"",
  )
  debug_inspect(
    @presentation.SlideSizeKind::Letter.size_type(),
    content="\"letter\"",
  )
  debug_inspect(@presentation.SlideSizeKind::A4.size_type(), content="\"A4\"")
}

///|
test "SlideSizeKind::Custom honours user-supplied EMU dimensions" {
  let kind = @presentation.SlideSizeKind::Custom(
    Emu(11_111_111L),
    Emu(2_222_222L),
  )
  let (cx, cy) = kind.dimensions()
  debug_inspect(cx, content="Emu(11111111)")
  debug_inspect(cy, content="Emu(2222222)")
  // Custom dimensions omit the type attribute.
  debug_inspect(kind.size_type(), content="\"\"")
}

///|
test "set_slide_size_mut: switches a fresh deck to 16:9 widescreen" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Widescreen)
  let pres = prs.presentation_part().unwrap()
  let sz = pres.sld_sz.unwrap()
  debug_inspect(sz.cx, content="Emu(12192000)")
  debug_inspect(sz.cy, content="Emu(6858000)")
  // Widescreen → no `type` attribute (PowerPoint convention).
  debug_inspect(sz.size_type, content="\"\"")
}

///|
test "set_slide_size_mut: survives save → reopen" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(A4)
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  let sz = prs2.presentation_part().unwrap().sld_sz.unwrap()
  debug_inspect(sz.cx, content="Emu(10692000)")
  debug_inspect(sz.cy, content="Emu(7560000)")
  debug_inspect(sz.size_type, content="\"A4\"")
}

///|
test "set_slide_size_mut: Custom EMU pair survives save → reopen" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Custom(Emu(8_000_000L), Emu(4_500_000L)))
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  let sz = prs2.presentation_part().unwrap().sld_sz.unwrap()
  debug_inspect(sz.cx, content="Emu(8000000)")
  debug_inspect(sz.cy, content="Emu(4500000)")
  // Custom dimensions omit the `type` attribute (PowerPoint convention).
  debug_inspect(sz.size_type, content="\"\"")
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
    debug_inspect(size.cx == cx, content="true")
    debug_inspect(size.cy == cy, content="true")
    debug_inspect(size.size_type == kind.size_type(), content="true")
  }
}
