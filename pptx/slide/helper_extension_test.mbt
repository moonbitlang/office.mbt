// Lossless preservation tests for the helper-level skip
// points inside @slide.parser.mbt. Each test wires a helper-internal
// extension element (scene3d / sp3d / extLst / spLocks / hlinkClick /
// custDataLst / audioFile / overrideClrMapping siblings) into a
// minimal slide fixture and asserts the element survives onto the
// surrounding shape's `extension` array.

///|
/// Build a slide with a single auto-shape whose `<p:spPr>` body is the
/// supplied `inner`. The fixture wraps the shape with the minimum
/// metadata `parse_slide_xml` accepts.
fn slide_with_sp_pr_body(inner : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"x\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr>" +
    "<a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm>" +
    inner +
    "</p:spPr>" +
    "</p:sp>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  @oxml.string_to_bytes(xml)
}

///|
fn first_sp_extension(slide : @slide.Slide) -> Array[@xml.XmlElement] {
  match slide.shapes[0] {
    AutoShape(s) => s.extension
    _ => abort("expected AutoShape")
  }
}

///|
fn find_local_inner(
  extension : Array[@xml.XmlElement],
  local_name : String,
) -> @xml.XmlElement? {
  for el in extension {
    if el.name.local_name == local_name {
      return Some(el)
    }
  }
  None
}

// --- spPr-level captures ---

///|
test "parse_sp_pr captures <a:scene3d> + <a:sp3d>" {
  let slide = @slide.Slide::parse(
    slide_with_sp_pr_body(
      "<a:scene3d><a:camera prst=\"orthographicFront\"/><a:lightRig rig=\"threePt\" dir=\"t\"/></a:scene3d>" +
      "<a:sp3d prstMaterial=\"matte\"><a:bevelT w=\"50800\" h=\"50800\"/></a:sp3d>",
    ),
  )
  let ext = first_sp_extension(slide)
  let scene = find_local_inner(ext, "scene3d").unwrap()
  let sp3d = find_local_inner(ext, "sp3d").unwrap()
  // scene3d body is preserved (two children: camera + lightRig).
  debug_inspect(scene.children.length(), content="2")
  // sp3d attribute survives.
  debug_inspect(sp3d.attributes[0].0.local_name, content="\"prstMaterial\"")
  debug_inspect(sp3d.attributes[0].1, content="\"matte\"")
}

///|
test "parse_sp_pr captures <a:extLst>" {
  let slide = @slide.Slide::parse(
    slide_with_sp_pr_body(
      "<a:extLst><a:ext uri=\"{ABC}\"><a:custom flag=\"1\"/></a:ext></a:extLst>",
    ),
  )
  let ext_lst = find_local_inner(first_sp_extension(slide), "extLst").unwrap()
  debug_inspect(ext_lst.children.length(), content="1")
}

///|
test "foreign-namespace <p:spPr> child survives" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:z=\"http://example.org/zz\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"x\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"1\" cy=\"1\"/></a:xfrm>" +
    "<z:wow level=\"9000\"/>" +
    "</p:spPr>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  let wow = find_local_inner(first_sp_extension(slide), "wow").unwrap()
  debug_inspect(wow.name.uri, content="\"http://example.org/zz\"")
}

// --- nvSpPr-level captures (cNvPr body, cNvSpPr) ---

///|
test "cNvPr with <a:hlinkClick> child is preserved" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr>" +
    "<p:cNvPr id=\"2\" name=\"Linked\"><a:hlinkClick r:id=\"rId9\"/></p:cNvPr>" +
    "<p:cNvSpPr><a:spLocks noGrp=\"1\"/></p:cNvSpPr>" +
    "<p:nvPr/>" +
    "</p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"1\" cy=\"1\"/></a:xfrm></p:spPr>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  match slide.shapes[0] {
    AutoShape(s) => {
      // id/name still parsed out.
      debug_inspect(s.id, content="2")
      debug_inspect(s.name, content="\"Linked\"")
      // cNvPr with its hlinkClick body is captured wholesale.
      let cnv_pr = find_local_inner(s.extension, "cNvPr").unwrap()
      debug_inspect(cnv_pr.children.length(), content="1")
      match cnv_pr.children[0] {
        Element(hlink) =>
          debug_inspect(hlink.name.local_name, content="\"hlinkClick\"")
        _ => fail("expected <a:hlinkClick> inside <p:cNvPr>")
      }
      // cNvSpPr with its spLocks child is captured.
      let cnv_sp_pr = find_local_inner(s.extension, "cNvSpPr").unwrap()
      match cnv_sp_pr.children[0] {
        Element(locks) =>
          debug_inspect(locks.name.local_name, content="\"spLocks\"")
        _ => fail("expected <a:spLocks> inside <p:cNvSpPr>")
      }
    }
    _ => fail("expected AutoShape")
  }
}

// --- nvPr-level captures (custDataLst / audioFile etc.) ---

///|
test "<p:nvPr> with <p:custDataLst> is preserved" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr>" +
    "<p:cNvPr id=\"2\" name=\"x\"/><p:cNvSpPr/>" +
    "<p:nvPr><p:custDataLst><p:tags><p:tag name=\"a\" val=\"b\"/></p:tags></p:custDataLst></p:nvPr>" +
    "</p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"1\" cy=\"1\"/></a:xfrm></p:spPr>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  match slide.shapes[0] {
    AutoShape(s) => {
      let cust = find_local_inner(s.extension, "custDataLst").unwrap()
      // <p:tags> survives nested.
      debug_inspect(cust.children.length(), content="1")
    }
    _ => fail("expected AutoShape")
  }
}

// --- grpSpPr-level captures (fill on a group shape) ---

///|
test "parse_grp_sp_pr captures <a:solidFill> on the group" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:grpSp>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"10\" name=\"G\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></p:grpSpPr>" +
    "</p:grpSp>" +
    "</p:spTree></p:cSld></p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  match slide.shapes[0] {
    Group(g) =>
      debug_inspect(
        find_local_inner(g.extension, "solidFill") is Some(_),
        content="true",
      )
    _ => fail("expected Group")
  }
}

// --- prstGeom-level captures ---

///|
test "parse_prst_geom captures <a:extLst> sibling of avLst" {
  let slide = @slide.Slide::parse(
    slide_with_sp_pr_body(
      "<a:prstGeom prst=\"rect\"><a:avLst/><a:extLst><a:ext uri=\"{X}\"/></a:extLst></a:prstGeom>",
    ),
  )
  // The extLst sibling of avLst is captured onto the shape's extension.
  debug_inspect(
    find_local_inner(first_sp_extension(slide), "extLst") is Some(_),
    content="true",
  )
}

// --- clrMapOvr-level captures ---

///|
test "parse_clr_map_ovr captures foreign-namespace sibling" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:x=\"http://example.org/ext\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<p:clrMapOvr><a:masterClrMapping/><x:tweak/></p:clrMapOvr>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(@oxml.string_to_bytes(xml))
  // tweak landed on the slide-level extension (parse_clr_map_ovr funnels there).
  let mut found = false
  for el in slide.extension {
    if el.name.local_name == "tweak" {
      debug_inspect(el.name.uri, content="\"http://example.org/ext\"")
      found = true
    }
  }
  debug_inspect(found, content="true")
}
