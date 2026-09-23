// Modified for office.mbt: follow the workspace warning conventions.

///|
test "RgbColor::new accessors" {
  let c = @units.RgbColor::new(255, 128, 0)
  debug_inspect(c.r, content="255")
  debug_inspect(c.g, content="128")
  debug_inspect(c.b, content="0")
}

///|
test "parse_hex / to_hex round trip" {
  let cases = [
    "FF0000", "00FF00", "0000FF", "808080", "000000", "FFFFFF", "1A2B3C",
  ]
  for hex in cases {
    let c = @units.RgbColor::parse_hex(hex)
    debug_inspect(c.to_hex() == hex, content="true")
  }
}

///|
test "parse_hex accepts both # prefix and lowercase" {
  let a = @units.RgbColor::parse_hex("#ff8800")
  debug_inspect(a == @units.RgbColor::new(255, 136, 0), content="true")
  debug_inspect(a.to_hex(), content="\"FF8800\"")
  let b = @units.RgbColor::parse_hex("ff8800")
  debug_inspect(a == b, content="true")
}

///|
test "parse_hex rejects malformed input" {
  // wrong length
  for bad in ["", "F", "FF", "FFFF", "FFFFF", "FFFFFFF", "##FF0000"] {
    try @units.RgbColor::parse_hex(bad) catch {
      InvalidHexColor(_) => ()
      _ => fail("expected InvalidHexColor")
    } noraise {
      _ => fail("expected InvalidHexColor")
    }
  }
  // non-hex digit
  for bad in ["GGGGGG", "FF00ZZ", "12345G"] {
    try @units.RgbColor::parse_hex(bad) catch {
      InvalidHexColor(_) => ()
      _ => fail("expected InvalidHexColor")
    } noraise {
      _ => fail("expected InvalidHexColor")
    }
  }
}

///|
test "to_hex always produces uppercase, no #" {
  debug_inspect(@units.RgbColor::new(0, 0, 0).to_hex(), content="\"000000\"")
  debug_inspect(
    @units.RgbColor::new(255, 255, 255).to_hex(),
    content="\"FFFFFF\"",
  )
  debug_inspect(@units.RgbColor::new(10, 11, 12).to_hex(), content="\"0A0B0C\"")
}
