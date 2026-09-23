// Modified for office.mbt: follow the workspace warning conventions.
// Tests for SVG picture support.

///|
/// Build a one-shape slide holding `pic`, so we can serialise it and check
/// the SVG blip round-trips through the writer (which must auto-declare the
/// `asvg` namespace for the synthesised `<asvg:svgBlip>`).
fn slide_of_picture(pic : @slide.Picture) -> @slide.Slide {
  {
    name: "",
    background: None,
    shapes: [Picture(pic)],
    clr_map_override: MasterMapping,
    transition: None,
    timing: None,
    extension: [],
  }
}

///|
test "Picture::of_svg_image wires fallback embed + svgBlip extension" {
  let pic = @slide.Picture::of_svg_image(
    id=5,
    name="Logo",
    png_embed_id="rId2", // raster fallback
    svg_embed_id="rId3", // svg
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(914_400L),
    cy=Emu(914_400L),
  )
  // The blip embeds the raster fallback…
  debug_inspect(pic.blip_fill.embed_id, content="\"rId2\"")
  // …and the captured <a:blip> carries the svgBlip extension referencing
  // the SVG relationship.
  debug_inspect(pic.blip_fill.extension.length(), content="1")
  let blip = pic.blip_fill.extension[0]
  debug_inspect(blip.name.local_name, content="\"blip\"")
  // blip → extLst → ext → svgBlip
  let svg_blip = match blip.children[0] {
    Element(ext_lst) =>
      match ext_lst.children[0] {
        Element(ext) =>
          match ext.children[0] {
            Element(sb) => sb
            _ => fail("expected <asvg:svgBlip>")
          }
        _ => fail("expected <a:ext>")
      }
    _ => fail("expected <a:extLst>")
  }
  debug_inspect(svg_blip.name.local_name, content="\"svgBlip\"")
  debug_inspect(svg_blip.name.uri == @oxml.svg_ns, content="true")
  debug_inspect(svg_blip.attributes[0].1, content="\"rId3\"")
}

///|
test "SVG blip serialises with the svg namespace and round-trips" {
  let pic = @slide.Picture::of_svg_image(
    id=7,
    name="Logo",
    png_embed_id="rId2",
    svg_embed_id="rId3",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  let slide = slide_of_picture(pic)
  let xml = @oxml.bytes_to_string(slide.serialize())
  // The serialised XML must carry the svgBlip and declare the SVG ns.
  debug_inspect(xml.contains("svgBlip"), content="true")
  debug_inspect(xml.contains(@oxml.svg_ns), content="true")
  // And it re-parses with the SVG extension intact.
  let reparsed = @slide.Slide::parse(slide.serialize())
  match reparsed.shapes[0] {
    Picture(p) => {
      debug_inspect(p.blip_fill.embed_id, content="\"rId2\"")
      debug_inspect(p.blip_fill == pic.blip_fill, content="true")
    }
    _ => fail("expected Picture shape")
  }
}
