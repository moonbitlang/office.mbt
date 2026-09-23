// Modified for office.mbt: follow the workspace warning conventions.
// Conversions are tested against the OOXML reference table:
//   1 inch = 914_400 EMU = 72 pt = 2.54 cm
// Round-trip cases use exact powers of the conversion factors so Double
// imprecision does not show up.

///|
test "constants match OOXML reference table" {
  debug_inspect(@units.emu_per_inch, content="914400")
  debug_inspect(@units.emu_per_pt, content="12700")
  debug_inspect(@units.emu_per_cm, content="360000")
  // 1 inch = 72 pt
  debug_inspect(@units.emu_per_inch == @units.emu_per_pt * 72L, content="true")
}

///|
test "Inch -> Emu" {
  debug_inspect(@units.Inch(1.0).to_emu(), content="Emu(914400)")
  debug_inspect(@units.Inch(0.5).to_emu(), content="Emu(457200)")
  debug_inspect(@units.Inch(10.0).to_emu(), content="Emu(9144000)")
}

///|
test "Pt -> Emu" {
  debug_inspect(@units.Pt(72.0).to_emu(), content="Emu(914400)")
  debug_inspect(@units.Pt(1.0).to_emu(), content="Emu(12700)")
  debug_inspect(@units.Pt(36.0).to_emu(), content="Emu(457200)")
}

///|
test "Cm -> Emu" {
  debug_inspect(@units.Cm(2.54).to_emu(), content="Emu(914400)")
  debug_inspect(@units.Cm(1.0).to_emu(), content="Emu(360000)")
  debug_inspect(@units.Cm(10.0).to_emu(), content="Emu(3600000)")
}

///|
test "Emu -> Inch round trip" {
  let original = @units.Inch(1.5)
  let round = original.to_emu().to_inch()
  debug_inspect(
    (round.value() - original.value()).abs() < 1.0e-9,
    content="true",
  )
}

///|
test "Emu -> Pt round trip" {
  let original = @units.Pt(36.0)
  let round = original.to_emu().to_pt()
  debug_inspect(
    (round.value() - original.value()).abs() < 1.0e-9,
    content="true",
  )
}

///|
test "Emu -> Cm round trip" {
  let original = @units.Cm(2.54)
  let round = original.to_emu().to_cm()
  debug_inspect(
    (round.value() - original.value()).abs() < 1.0e-9,
    content="true",
  )
}

///|
test "Emu compare and equal" {
  let a = @units.Emu(100L)
  let b = @units.Emu(200L)
  debug_inspect(a < b, content="true")
  debug_inspect(a, content="Emu(100)")
  debug_inspect(a != b, content="true")
}

///|
test "Emu arithmetic" {
  let slide_w = @units.Inch(10.0).to_emu() // 9_144_000
  let slide_h = @units.Inch(7.5).to_emu() // 6_858_000
  let total = slide_w.add(slide_h)
  debug_inspect(total, content="Emu(16002000)")
  let diff = slide_w.sub(slide_h)
  debug_inspect(diff, content="Emu(2286000)")
  debug_inspect(slide_w.neg(), content="Emu(-9144000)")
}

///|
test "Emu does not overflow on slide-scale products" {
  // A 1920x1080 widescreen slide is ~12_192_000 x 6_858_000 EMU.
  // Their product (~8.36e13) overflows Int32 but fits in Int64.
  let w = @units.Emu(12_192_000L)
  let h = @units.Emu(6_858_000L)
  let area = w.value() * h.value()
  debug_inspect(area > 0L, content="true")
  debug_inspect(area, content="83612736000000")
}
