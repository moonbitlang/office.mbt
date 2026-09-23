// Modified for office.mbt: follow the workspace warning conventions.
// @oxml.Fill parser tests.

///|
fn parse_inner_fill(inner : String) -> @oxml.Fill raise @oxml.FillError {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\" xmlns:r=\"" +
    @oxml.office_relationships_ns +
    "\">" +
    inner +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch {
    _ => raise MalformedFill("test wrapper open failed")
  }
  while true {
    let ev = r.next() catch {
      _ => raise MalformedFill("test wrapper inner failed")
    }
    match ev {
      Some(StartElement(name, attrs)) => return @oxml.parse_fill(r, name, attrs)
      Some(EndElement(_)) => raise MalformedFill("empty wrapper")
      Some(_) => ()
      None => raise MalformedFill("unexpected end of test wrapper")
    }
  }
  raise MalformedFill("unreachable")
}

// --- NoFill / SolidFill ---

///|
test "Fill: noFill" {
  let f = parse_inner_fill("<a:noFill/>")
  debug_inspect(f is NoFill, content="true")
}

///|
test "Fill: solidFill with srgbClr" {
  let f = parse_inner_fill(
    "<a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill>",
  )
  match f {
    SolidFill(c) =>
      match c.base {
        Srgb(rgb) => debug_inspect(rgb.to_hex(), content="\"FF0000\"")
        _ => fail("expected Srgb")
      }
    _ => fail("expected SolidFill")
  }
}

///|
test "Fill: solidFill missing colour child rejected" {
  try parse_inner_fill("<a:solidFill/>") catch {
    MalformedFill(_) => ()
    _ => fail("expected MalformedFill")
  } noraise {
    _ => fail("expected MalformedFill")
  }
}

// --- GradientFill ---

///|
test "Fill: linear gradient with two stops" {
  let inner = "<a:gradFill flip=\"none\" rotWithShape=\"1\">" +
    "<a:gsLst>" +
    "<a:gs pos=\"0\"><a:srgbClr val=\"FF0000\"/></a:gs>" +
    "<a:gs pos=\"100000\"><a:srgbClr val=\"0000FF\"/></a:gs>" +
    "</a:gsLst>" +
    "<a:lin ang=\"5400000\" scaled=\"1\"/>" +
    "</a:gradFill>"
  let f = parse_inner_fill(inner)
  match f {
    GradientFill(g) => {
      debug_inspect(g.stops.length(), content="2")
      debug_inspect(g.stops[0].position, content="Percentage(0)")
      debug_inspect(g.stops[1].position, content="Percentage(100)")
      match g.direction {
        Linear(ang, scaled) => {
          debug_inspect(ang, content="Angle(90)")
          debug_inspect(scaled, content="true")
        }
        _ => fail("expected Linear direction")
      }
      debug_inspect(g.rotate_with_shape.unwrap(), content="true")
      debug_inspect(g.flip.unwrap() is FlipNone, content="true")
    }
    _ => fail("expected GradientFill")
  }
}

///|
test "Fill: path gradient" {
  let inner = "<a:gradFill>" +
    "<a:gsLst><a:gs pos=\"0\"><a:srgbClr val=\"000000\"/></a:gs></a:gsLst>" +
    "<a:path path=\"circle\"/>" +
    "</a:gradFill>"
  let f = parse_inner_fill(inner)
  match f {
    GradientFill(g) => debug_inspect(g.direction is PathCircle, content="true")
    _ => fail("expected GradientFill")
  }
}

///|
test "Fill: gradient with no stops rejected" {
  try
    parse_inner_fill("<a:gradFill><a:gsLst/><a:lin ang=\"0\"/></a:gradFill>")
  catch {
    MalformedFill(_) => ()
    _ => fail("expected MalformedFill")
  } noraise {
    _ => fail("expected MalformedFill")
  }
}

// --- PatternFill ---

///|
test "Fill: pattFill with fgClr and bgClr" {
  let inner = "<a:pattFill prst=\"dkUpDiag\">" +
    "<a:fgClr><a:srgbClr val=\"000000\"/></a:fgClr>" +
    "<a:bgClr><a:srgbClr val=\"FFFFFF\"/></a:bgClr>" +
    "</a:pattFill>"
  let f = parse_inner_fill(inner)
  match f {
    PatternFill(p) => {
      debug_inspect(p.preset, content="\"dkUpDiag\"")
      match p.fg.base {
        Srgb(rgb) => debug_inspect(rgb.to_hex(), content="\"000000\"")
        _ => fail("expected Srgb fg")
      }
      match p.bg.base {
        Srgb(rgb) => debug_inspect(rgb.to_hex(), content="\"FFFFFF\"")
        _ => fail("expected Srgb bg")
      }
    }
    _ => fail("expected PatternFill")
  }
}

///|
test "Fill: pattFill missing fgClr rejected" {
  let inner = "<a:pattFill prst=\"x\">" +
    "<a:bgClr><a:srgbClr val=\"FFFFFF\"/></a:bgClr>" +
    "</a:pattFill>"
  try parse_inner_fill(inner) catch {
    MalformedFill(_) => ()
    _ => fail("expected MalformedFill")
  } noraise {
    _ => fail("expected MalformedFill")
  }
}

// --- BlipFill ---

///|
test "Fill: blipFill with stretch + fillRect" {
  let inner = "<a:blipFill>" +
    "<a:blip r:embed=\"rId7\"/>" +
    "<a:stretch><a:fillRect/></a:stretch>" +
    "</a:blipFill>"
  let f = parse_inner_fill(inner)
  match f {
    BlipFillVariant(b) => {
      debug_inspect(b.embed_id, content="\"rId7\"")
      debug_inspect(b.link_id, content="\"\"")
      match b.fill_mode {
        Stretch(rect) => {
          let r = rect.unwrap()
          debug_inspect(r.left, content="Percentage(0)")
        }
        _ => fail("expected Stretch")
      }
    }
    _ => fail("expected BlipFill")
  }
}

///|
test "Fill: blipFill with srcRect crop and tile mode" {
  let inner = "<a:blipFill>" +
    "<a:blip r:embed=\"rId1\"/>" +
    "<a:srcRect l=\"10000\" t=\"20000\" r=\"5000\" b=\"5000\"/>" +
    "<a:tile tx=\"100\" ty=\"200\" sx=\"50000\" sy=\"50000\" flip=\"xy\" algn=\"ctr\"/>" +
    "</a:blipFill>"
  let f = parse_inner_fill(inner)
  match f {
    BlipFillVariant(b) => {
      let sr = b.src_rect.unwrap()
      debug_inspect(sr.left, content="Percentage(10)")
      debug_inspect(sr.top, content="Percentage(20)")
      match b.fill_mode {
        Tile(t) => {
          debug_inspect(t.tx.unwrap(), content="Emu(100)")
          debug_inspect(t.ty.unwrap(), content="Emu(200)")
          debug_inspect(t.sx.unwrap(), content="Percentage(50)")
          debug_inspect(t.flip.unwrap() is FlipXy, content="true")
          debug_inspect(t.alignment.unwrap() is AlignCenter, content="true")
        }
        _ => fail("expected Tile")
      }
    }
    _ => fail("expected BlipFill")
  }
}

///|
test "Fill: blipFill with linked rId only" {
  let inner = "<a:blipFill><a:blip r:link=\"rId9\"/></a:blipFill>"
  let f = parse_inner_fill(inner)
  match f {
    BlipFillVariant(b) => {
      debug_inspect(b.embed_id, content="\"\"")
      debug_inspect(b.link_id, content="\"rId9\"")
    }
    _ => fail("expected BlipFill")
  }
}

///|
test "Fill: blipFill with neither embed nor link rejected" {
  let inner = "<a:blipFill><a:blip/></a:blipFill>"
  try parse_inner_fill(inner) catch {
    MalformedFill(_) => ()
    _ => fail("expected MalformedFill")
  } noraise {
    _ => fail("expected MalformedFill")
  }
}

// --- error / unknown ---

///|
test "Fill: unknown wrapper rejected" {
  try parse_inner_fill("<a:weirdFill/>") catch {
    UnknownFillElement(_) => ()
    _ => fail("expected UnknownFillElement")
  } noraise {
    _ => fail("expected UnknownFillElement")
  }
}

///|
test "Fill: gs with bad color wrapped as ColorFailure" {
  let inner = "<a:gradFill>" +
    "<a:gsLst><a:gs pos=\"0\"><a:srgbClr val=\"GGGGGG\"/></a:gs></a:gsLst>" +
    "<a:lin ang=\"0\"/>" +
    "</a:gradFill>"
  try parse_inner_fill(inner) catch {
    ColorFailure(_) => ()
    _ => fail("expected ColorFailure")
  } noraise {
    _ => fail("expected ColorFailure")
  }
}
