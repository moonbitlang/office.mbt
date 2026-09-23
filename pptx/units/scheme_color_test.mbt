// Modified for office.mbt: follow the workspace warning conventions.

///|
test "ThemeColor xml round trip for every variant" {
  let names = [
    "bg1", "bg2", "tx1", "tx2", "dk1", "dk2", "lt1", "lt2", "accent1", "accent2",
    "accent3", "accent4", "accent5", "accent6", "hlink", "folHlink", "phClr",
  ]
  for n in names {
    let parsed = @units.ThemeColor::from_xml(n)
    debug_inspect(parsed.to_xml() == n, content="true")
  }
}

///|
test "ThemeColor::from_xml rejects unknown names" {
  for bad in ["", "BG1", "accent7", "accent10", "bgX", "purple"] {
    try @units.ThemeColor::from_xml(bad) catch {
      UnknownSchemeColor(_) => ()
      _ => fail("expected UnknownSchemeColor")
    } noraise {
      _ => fail("expected UnknownSchemeColor")
    }
  }
}

///|
test "ThemeColor variants are distinct" {
  // A handful of equality checks confirm the enum tags are not collapsed.
  debug_inspect(@units.ThemeColor::Accent1 != Accent2, content="true")
  debug_inspect(@units.ThemeColor::Bg1 != Tx1, content="true")
  debug_inspect(@units.ThemeColor::Dk1 != Lt1, content="true")
  debug_inspect(@units.ThemeColor::Hlink != FolHlink, content="true")
}

///|
test "SchemeColor builder is immutable" {
  let base = @units.SchemeColor::new(Accent1)
  debug_inspect(base.transforms.length(), content="0")
  let lighter = base.with_transform(Tint(Percentage(40.0)))
  // original unchanged
  debug_inspect(base.transforms.length(), content="0")
  debug_inspect(lighter.transforms.length(), content="1")
  // chained build
  let chained = lighter.with_transform(LumMod(Percentage(75.0)))
  debug_inspect(chained.transforms.length(), content="2")
  debug_inspect(lighter.transforms.length(), content="1")
}

///|
test "SchemeColor preserves transform order" {
  let c = @units.SchemeColor::new(Accent3)
    .with_transform(Tint(Percentage(20.0)))
    .with_transform(Alpha(Percentage(80.0)))
    .with_transform(SatMod(Percentage(150.0)))
  debug_inspect(c.transforms.length(), content="3")
  debug_inspect(c.transforms[0] is Tint(_), content="true")
  debug_inspect(c.transforms[1] is Alpha(_), content="true")
  debug_inspect(c.transforms[2] is SatMod(_), content="true")
}
