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
  assert_eq(s.width.unwrap(), Emu(9525L))
  assert_true(s.cap.unwrap() is CapRound)
  assert_true(s.compound.unwrap() is CmpdDouble)
  assert_true(s.alignment.unwrap() is AlignPenCenter)
}

///|
test "Stroke: missing attributes leave fields None" {
  let s = parse_stroke_inner("<a:ln/>")
  assert_true(s.width is None)
  assert_true(s.cap is None)
  assert_true(s.compound is None)
  assert_true(s.alignment is None)
  assert_true(s.fill is None)
  assert_true(s.dash is None)
  assert_true(s.join is None)
  assert_true(s.head_end is None)
  assert_true(s.tail_end is None)
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
        Srgb(rgb) => assert_eq(rgb.to_hex(), "FF0000")
        _ => fail("expected Srgb base")
      }
    _ => fail("expected SolidFill")
  }
}

///|
test "Stroke: noFill child" {
  let s = parse_stroke_inner("<a:ln><a:noFill/></a:ln>")
  assert_true(s.fill.unwrap() is NoFill)
}

// --- dash / join / arrows ---

///|
test "Stroke: prstDash carries enum" {
  let s = parse_stroke_inner("<a:ln><a:prstDash val=\"dashDot\"/></a:ln>")
  assert_true(s.dash.unwrap() is DashDashDot)
}

///|
test "Stroke: round / bevel / miter line joins" {
  let r = parse_stroke_inner("<a:ln><a:round/></a:ln>")
  assert_true(r.join.unwrap() is JoinRound)
  let b = parse_stroke_inner("<a:ln><a:bevel/></a:ln>")
  assert_true(b.join.unwrap() is JoinBevel)
  let m = parse_stroke_inner("<a:ln><a:miter lim=\"800000\"/></a:ln>")
  match m.join.unwrap() {
    JoinMiter(Some(p)) => assert_eq(p, Percentage(800.0))
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
  assert_true(h.arrow_type is ArrowTriangle)
  assert_true(h.width.unwrap() is SizeMedium)
  assert_true(h.length.unwrap() is SizeLarge)
  let t = s.tail_end.unwrap()
  assert_true(t.arrow_type is ArrowArrow)
  assert_true(t.width.unwrap() is SizeSmall)
  assert_true(t.length is None)
}

///|
test "Stroke: arrowhead with missing type defaults to None" {
  let s = parse_stroke_inner("<a:ln><a:headEnd w=\"med\"/></a:ln>")
  let h = s.head_end.unwrap()
  assert_true(h.arrow_type is ArrowNone)
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
  assert_eq(s.width.unwrap(), Emu(9525L))
  assert_true(s.cap.unwrap() is CapFlat)
  assert_true(s.dash.unwrap() is DashSysDash)
  assert_true(s.join.unwrap() is JoinRound)
  assert_true(s.head_end is None)
  assert_true(s.tail_end.unwrap().arrow_type is ArrowStealth)
}

///|
test "Stroke: unknown enum values collapse to None (graceful)" {
  let s = parse_stroke_inner(
    "<a:ln cap=\"weirdo\"><a:prstDash val=\"alsoUnknown\"/></a:ln>",
  )
  assert_true(s.cap is None)
  assert_true(s.dash is None)
}

///|
test "Stroke: custDash is silently skipped" {
  let inner = "<a:ln><a:custDash><a:ds d=\"100\" sp=\"50\"/></a:custDash></a:ln>"
  let s = parse_stroke_inner(inner)
  assert_true(s.dash is None)
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
