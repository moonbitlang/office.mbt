// Modified for office.mbt: follow the workspace warning conventions.
// @oxml.Stroke parser tests.

///|
fn parse_stroke_inner(inner : String) -> @oxml.Stroke raise @oxml.StrokeError {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\">" +
    inner +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch {
    _ => raise MalformedStroke("test wrapper open failed")
  }
  while true {
    let ev = r.next() catch {
      _ => raise MalformedStroke("test wrapper inner failed")
    }
    match ev {
      Some(StartElement(_, attrs)) => return @oxml.parse_stroke(r, attrs)
      Some(EndElement(_)) => raise MalformedStroke("empty wrapper")
      Some(_) => ()
      None => raise MalformedStroke("unexpected end of test wrapper")
    }
  }
  raise MalformedStroke("unreachable")
}

// --- attributes ---

///|
test "Stroke: attributes (width / cap / cmpd / algn)" {
  let s = parse_stroke_inner(
    "<a:ln w=\"9525\" cap=\"rnd\" cmpd=\"dbl\" algn=\"ctr\"/>",
  )
  debug_inspect(s.width.unwrap(), content="Emu(9525)")
  debug_inspect(s.cap.unwrap() is CapRound, content="true")
  debug_inspect(s.compound.unwrap() is CmpdDouble, content="true")
  debug_inspect(s.alignment.unwrap() is AlignPenCenter, content="true")
}

///|
test "Stroke: missing attributes leave fields None" {
  let s = parse_stroke_inner("<a:ln/>")
  debug_inspect(s.width is None, content="true")
  debug_inspect(s.cap is None, content="true")
  debug_inspect(s.compound is None, content="true")
  debug_inspect(s.alignment is None, content="true")
  debug_inspect(s.fill is None, content="true")
  debug_inspect(s.dash is None, content="true")
  debug_inspect(s.join is None, content="true")
  debug_inspect(s.head_end is None, content="true")
  debug_inspect(s.tail_end is None, content="true")
}

// --- fill child ---

///|
test "Stroke: solidFill colour child" {
  let s = parse_stroke_inner(
    "<a:ln w=\"6350\"><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:ln>",
  )
  match s.fill.unwrap() {
    SolidFill(c) =>
      match c.base {
        Srgb(rgb) => debug_inspect(rgb.to_hex(), content="\"FF0000\"")
        _ => fail("expected Srgb base")
      }
    _ => fail("expected SolidFill")
  }
}

///|
test "Stroke: noFill child" {
  let s = parse_stroke_inner("<a:ln><a:noFill/></a:ln>")
  debug_inspect(s.fill.unwrap() is NoFill, content="true")
}

// --- dash / join / arrows ---

///|
test "Stroke: prstDash carries enum" {
  let s = parse_stroke_inner("<a:ln><a:prstDash val=\"dashDot\"/></a:ln>")
  debug_inspect(s.dash.unwrap() is DashDashDot, content="true")
}

///|
test "Stroke: round / bevel / miter line joins" {
  let r = parse_stroke_inner("<a:ln><a:round/></a:ln>")
  debug_inspect(r.join.unwrap() is JoinRound, content="true")
  let b = parse_stroke_inner("<a:ln><a:bevel/></a:ln>")
  debug_inspect(b.join.unwrap() is JoinBevel, content="true")
  let m = parse_stroke_inner("<a:ln><a:miter lim=\"800000\"/></a:ln>")
  match m.join.unwrap() {
    JoinMiter(Some(p)) => debug_inspect(p, content="Percentage(800)")
    _ => fail("expected JoinMiter with limit")
  }
}

///|
test "Stroke: miter without limit attribute" {
  let s = parse_stroke_inner("<a:ln><a:miter/></a:ln>")
  match s.join.unwrap() {
    JoinMiter(None) => ()
    _ => fail("expected JoinMiter(None)")
  }
}

///|
test "Stroke: head + tail arrowheads" {
  let s = parse_stroke_inner(
    "<a:ln><a:headEnd type=\"triangle\" w=\"med\" len=\"lg\"/>" +
    "<a:tailEnd type=\"arrow\" w=\"sm\"/></a:ln>",
  )
  let h = s.head_end.unwrap()
  debug_inspect(h.arrow_type is ArrowTriangle, content="true")
  debug_inspect(h.width.unwrap() is SizeMedium, content="true")
  debug_inspect(h.length.unwrap() is SizeLarge, content="true")
  let t = s.tail_end.unwrap()
  debug_inspect(t.arrow_type is ArrowArrow, content="true")
  debug_inspect(t.width.unwrap() is SizeSmall, content="true")
  debug_inspect(t.length is None, content="true")
}

///|
test "Stroke: arrowhead with missing type defaults to None" {
  let s = parse_stroke_inner("<a:ln><a:headEnd w=\"med\"/></a:ln>")
  let h = s.head_end.unwrap()
  debug_inspect(h.arrow_type is ArrowNone, content="true")
}

// --- combined ---

///|
test "Stroke: realistic outline (width + solid colour + dash + arrows)" {
  let inner = "<a:ln w=\"9525\" cap=\"flat\" cmpd=\"sng\" algn=\"ctr\">" +
    "<a:solidFill><a:srgbClr val=\"0000FF\"/></a:solidFill>" +
    "<a:prstDash val=\"sysDash\"/>" +
    "<a:round/>" +
    "<a:tailEnd type=\"stealth\" w=\"med\" len=\"med\"/>" +
    "</a:ln>"
  let s = parse_stroke_inner(inner)
  debug_inspect(s.width.unwrap(), content="Emu(9525)")
  debug_inspect(s.cap.unwrap() is CapFlat, content="true")
  debug_inspect(s.dash.unwrap() is DashSysDash, content="true")
  debug_inspect(s.join.unwrap() is JoinRound, content="true")
  debug_inspect(s.head_end is None, content="true")
  debug_inspect(s.tail_end.unwrap().arrow_type is ArrowStealth, content="true")
}

///|
test "Stroke: unknown enum values collapse to None (graceful)" {
  let s = parse_stroke_inner(
    "<a:ln cap=\"weirdo\"><a:prstDash val=\"alsoUnknown\"/></a:ln>",
  )
  debug_inspect(s.cap is None, content="true")
  debug_inspect(s.dash is None, content="true")
}

///|
test "Stroke: custDash is silently skipped" {
  let inner = "<a:ln><a:custDash><a:ds d=\"100\" sp=\"50\"/></a:custDash></a:ln>"
  let s = parse_stroke_inner(inner)
  debug_inspect(s.dash is None, content="true")
}

// --- error / fill-failure ---

///|
test "Stroke: bad colour inside solidFill wraps as FillFailure" {
  try
    parse_stroke_inner(
      "<a:ln><a:solidFill><a:srgbClr val=\"GGGGGG\"/></a:solidFill></a:ln>",
    )
  catch {
    FillFailure(_) => ()
    _ => fail("expected FillFailure")
  } noraise {
    _ => fail("expected FillFailure")
  }
}
