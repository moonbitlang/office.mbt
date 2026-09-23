// Lossless preservation tests (ADR-004) for the @oxml ADTs. Color,
// Fill (Gradient / Pattern / BlipFill), Stroke, and EffectList all
// carry an `extension : Array[@xml.XmlElement]` field; these tests
// assert that the unmodelled long-tail children round-trip.

// `parse_inner_fill` is defined in fill_test.mbt and shared via the
// blackbox test package; we reuse it here.

// --- Color.extension: unmodelled colour modifiers ---

///|
test "ADR-004: Color captures hueMod / redMod modifiers" {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\">" +
    "<a:srgbClr val=\"112233\">" +
    "<a:tint val=\"50000\"/>" +
    "<a:hueMod val=\"180000\"/>" +
    "<a:redMod val=\"50000\"/>" +
    "</a:srgbClr>" +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch { _ => fail("wrapper open") }
  let ev = (r.next() catch { _ => fail("read inner") }).unwrap()
  let color = match ev {
    StartElement(n, a) =>
      @oxml.parse_color_element(r, n, a) catch {
        _ => fail("parse_color")
      }
    _ => fail("not a start element")
  }
  // tint was modelled → in transforms; hueMod + redMod fell through → in extension.
  debug_inspect(color.transforms.length(), content="1")
  debug_inspect(color.extension.length(), content="2")
  let names = []
  for el in color.extension {
    names.push(el.name.local_name)
  }
  debug_inspect(names.contains("hueMod"), content="true")
  debug_inspect(names.contains("redMod"), content="true")
}

// --- BlipFill.extension: <a:blip> colour-mod children survive ---

///|
test "ADR-004: BlipFill captures <a:blip> with nested duotone" {
  let inner = "<a:blipFill>" +
    "<a:blip r:embed=\"rId7\">" +
    "<a:duotone><a:srgbClr val=\"FF0000\"/><a:srgbClr val=\"00FF00\"/></a:duotone>" +
    "</a:blip>" +
    "<a:stretch/>" +
    "</a:blipFill>"
  let f = parse_inner_fill(inner)
  match f {
    BlipFillVariant(bf) => {
      debug_inspect(bf.embed_id, content="\"rId7\"")
      // The <a:blip> subtree is captured wholesale.
      debug_inspect(bf.extension.length(), content="1")
      let blip = bf.extension[0]
      debug_inspect(blip.name.local_name, content="\"blip\"")
      debug_inspect(blip.children.length(), content="1")
      match blip.children[0] {
        Element(duo) => {
          debug_inspect(duo.name.local_name, content="\"duotone\"")
          // duotone has two srgbClr children.
          debug_inspect(duo.children.length(), content="2")
        }
        _ => fail("expected duotone")
      }
    }
    _ => fail("expected BlipFillVariant")
  }
}

// --- Gradient.extension: tileRect survives ---

///|
test "ADR-004: Gradient captures <a:tileRect>" {
  let inner = "<a:gradFill>" +
    "<a:gsLst><a:gs pos=\"0\"><a:srgbClr val=\"FF0000\"/></a:gs>" +
    "<a:gs pos=\"100000\"><a:srgbClr val=\"00FF00\"/></a:gs></a:gsLst>" +
    "<a:lin ang=\"5400000\" scaled=\"0\"/>" +
    "<a:tileRect l=\"0\" t=\"0\" r=\"50000\" b=\"50000\"/>" +
    "</a:gradFill>"
  let f = parse_inner_fill(inner)
  match f {
    GradientFill(g) => {
      debug_inspect(g.stops.length(), content="2")
      debug_inspect(g.extension.length(), content="1")
      debug_inspect(g.extension[0].name.local_name, content="\"tileRect\"")
    }
    _ => fail("expected GradientFill")
  }
}

// --- Stroke.extension: <a:custDash> and <a:extLst> survive ---

///|
test "ADR-004: Stroke captures custDash and extLst" {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\">" +
    "<a:ln w=\"19050\">" +
    "<a:solidFill><a:srgbClr val=\"000000\"/></a:solidFill>" +
    "<a:custDash><a:ds d=\"100000\" sp=\"50000\"/></a:custDash>" +
    "<a:extLst><a:ext uri=\"{x}\"/></a:extLst>" +
    "</a:ln>" +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch { _ => fail("wrapper open") }
  let ev = (r.next() catch { _ => fail("read ln") }).unwrap()
  let stroke = match ev {
    StartElement(_, attrs) =>
      @oxml.parse_stroke(r, attrs) catch {
        _ => fail("parse_stroke")
      }
    _ => fail("not a start element")
  }
  debug_inspect(stroke.extension.length(), content="2")
  let names = []
  for el in stroke.extension {
    names.push(el.name.local_name)
  }
  debug_inspect(names.contains("custDash"), content="true")
  debug_inspect(names.contains("extLst"), content="true")
}

// --- EffectList.extension: <a:fillOverlay> survives ---

///|
test "ADR-004: EffectList captures fillOverlay" {
  let xml = "<wrapper xmlns:a=\"" +
    @oxml.drawing_ns +
    "\">" +
    "<a:effectLst>" +
    "<a:blur rad=\"40000\"/>" +
    "<a:fillOverlay blend=\"over\"><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:fillOverlay>" +
    "</a:effectLst>" +
    "</wrapper>"
  let r = @xml.XmlReader::new(xml)
  let _ = r.next() catch { _ => fail("wrapper open") }
  let _ev = r.next() catch { _ => fail("read effectLst") }
  let el = @oxml.parse_effect_list(r) catch { _ => fail("parse_effect_list") }
  debug_inspect(el.blur is Some(_), content="true")
  debug_inspect(el.extension.length(), content="1")
  debug_inspect(el.extension[0].name.local_name, content="\"fillOverlay\"")
  debug_inspect(el.extension[0].attributes[0].0.local_name, content="\"blend\"")
  debug_inspect(el.extension[0].attributes[0].1, content="\"over\"")
}
