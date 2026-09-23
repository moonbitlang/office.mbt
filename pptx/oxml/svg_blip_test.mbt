// @oxml SVG-blip builder tests.

///|
test "BlipFill::svg: fallback embed + svgBlip extension structure" {
  let bf = @oxml.BlipFill::svg("rId2", "rId3")
  // The raster fallback is the typed embed.
  debug_inspect(bf.embed_id, content="\"rId2\"")
  debug_inspect(bf.link_id, content="\"\"")
  // The captured <a:blip> carries r:embed=fallback + extLst→ext→svgBlip.
  debug_inspect(bf.extension.length(), content="1")
  let blip = bf.extension[0]
  debug_inspect(blip.name.uri == @oxml.drawing_ns, content="true")
  debug_inspect(blip.name.local_name, content="\"blip\"")
  debug_inspect(blip.attributes[0].1, content="\"rId2\"")
  match blip.children[0] {
    Element(ext_lst) => {
      debug_inspect(ext_lst.name.local_name, content="\"extLst\"")
      match ext_lst.children[0] {
        Element(ext) => {
          debug_inspect(ext.name.local_name, content="\"ext\"")
          // The ext is keyed by the fixed SVG-blip GUID.
          debug_inspect(
            ext.attributes[0].1 == @oxml.svg_blip_ext_uri,
            content="true",
          )
          match ext.children[0] {
            Element(sb) => {
              debug_inspect(sb.name.uri == @oxml.svg_ns, content="true")
              debug_inspect(sb.name.local_name, content="\"svgBlip\"")
              debug_inspect(sb.attributes[0].1, content="\"rId3\"")
            }
            _ => fail("expected <asvg:svgBlip>")
          }
        }
        _ => fail("expected <a:ext>")
      }
    }
    _ => fail("expected <a:extLst>")
  }
}
