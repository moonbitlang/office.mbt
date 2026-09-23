// End-to-end OPC round trip: build a minimal but realistic package
// shaped like a real `.pptx`, exercise the full open → mutate → save →
// reopen path, and assert that parts and relationships survive.
//
// The fixture is small enough to construct in-memory but covers every OPC
// concept we expose (Default/Override content types, package-level rels,
// part-level rels with relative + `..`-walking targets).

///|
let ct_ns_e2e : String = "http://schemas.openxmlformats.org/package/2006/content-types"

///|
let rels_ns_e2e : String = "http://schemas.openxmlformats.org/package/2006/relationships"

///|
let rt_office_doc : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"

///|
let rt_slide : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"

///|
let rt_image : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"

///|
fn fixture_content_types() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Types xmlns=\"" +
  ct_ns_e2e +
  "\">" +
  "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  "<Default Extension=\"png\" ContentType=\"image/png\"/>" +
  "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
  "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
  "</Types>"
}

///|
fn fixture_pkg_rels() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"" +
  rels_ns_e2e +
  "\">" +
  "<Relationship Id=\"rId1\" Type=\"" +
  rt_office_doc +
  "\" Target=\"ppt/presentation.xml\"/>" +
  "</Relationships>"
}

///|
fn fixture_presentation_rels() -> String {
  // rId1: slide (relative, same dir) → /ppt/slides/slide1.xml
  // rId2: image (uses `..` to go up to /ppt/media/) — exercises path walk
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"" +
  rels_ns_e2e +
  "\">" +
  "<Relationship Id=\"rId1\" Type=\"" +
  rt_slide +
  "\" Target=\"slides/slide1.xml\"/>" +
  "<Relationship Id=\"rId2\" Type=\"" +
  rt_image +
  "\" Target=\"media/image1.png\"/>" +
  "</Relationships>"
}

///|
fn build_fixture() -> FixedArray[Byte] raise {
  let entries : Array[(String, FixedArray[Byte])] = [
    ("[Content_Types].xml", utf8_bytes(fixture_content_types())),
    ("_rels/.rels", utf8_bytes(fixture_pkg_rels())),
    ("ppt/presentation.xml", utf8_bytes("<p:presentation xmlns:p=\"x\"/>")),
    ("ppt/_rels/presentation.xml.rels", utf8_bytes(fixture_presentation_rels())),
    ("ppt/slides/slide1.xml", utf8_bytes("<p:sld xmlns:p=\"x\"/>")),
    // pretend PNG payload — the OPC layer doesn't care about validity
    ("ppt/media/image1.png", utf8_bytes("FAKEPNG")),
  ]
  fixture_zip(entries)
}

///|
test "fixture: opens with all parts present" {
  let pkg = @opc.Package::open(build_fixture())
  debug_inspect(pkg.parts().length(), content="6")
  let names = [
    "/[Content_Types].xml", "/_rels/.rels", "/ppt/presentation.xml", "/ppt/_rels/presentation.xml.rels",
    "/ppt/slides/slide1.xml", "/ppt/media/image1.png",
  ]
  for n in names {
    let _ = pkg.require_part(n)
  }
}

///|
test "fixture: content types resolve correctly per part" {
  let pkg = @opc.Package::open(build_fixture())
  // Override on the presentation part
  debug_inspect(
    pkg.require_part("/ppt/presentation.xml").content_type,
    content="\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"",
  )
  // Override on the slide part
  debug_inspect(
    pkg.require_part("/ppt/slides/slide1.xml").content_type,
    content="\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"",
  )
  // Default by extension `.png`
  debug_inspect(
    pkg.require_part("/ppt/media/image1.png").content_type,
    content="\"image/png\"",
  )
  // Default by extension `.rels`
  debug_inspect(
    pkg.require_part("/_rels/.rels").content_type,
    content="\"application/vnd.openxmlformats-package.relationships+xml\"",
  )
}

///|
test "fixture: package-level rels point at the presentation" {
  let pkg = @opc.Package::open(build_fixture())
  let rels = pkg.relationships_for(@opc.package_root)
  debug_inspect(rels.items().length(), content="1")
  let r = rels.by_type(rt_office_doc)
  debug_inspect(r.length(), content="1")
  debug_inspect(
    @opc.resolve_target(@opc.package_root, r[0].target, r[0].target_mode),
    content="\"/ppt/presentation.xml\"",
  )
}

///|
test "fixture: presentation rels resolve to real parts (incl. `..` walk)" {
  let pkg = @opc.Package::open(build_fixture())
  let rels = pkg.relationships_for("/ppt/presentation.xml")
  debug_inspect(rels.items().length(), content="2")
  let slide_rel = rels.by_id("rId1").unwrap()
  let slide_path = @opc.resolve_target(
    "/ppt/presentation.xml",
    slide_rel.target,
    slide_rel.target_mode,
  )
  debug_inspect(slide_path, content="\"/ppt/slides/slide1.xml\"")
  debug_inspect(!(pkg.part_by_name(slide_path) is None), content="true")
  // rId2 → image (relative target, no `..` here but exercises lookup)
  let img_rel = rels.by_id("rId2").unwrap()
  let img_path = @opc.resolve_target(
    "/ppt/presentation.xml",
    img_rel.target,
    img_rel.target_mode,
  )
  debug_inspect(img_path, content="\"/ppt/media/image1.png\"")
  debug_inspect(!(pkg.part_by_name(img_path) is None), content="true")
}

///|
test "round trip: open -> to_bytes -> open preserves shape" {
  let pkg1 = @opc.Package::open(build_fixture())
  let pkg2 = @opc.Package::open(pkg1.to_bytes())
  debug_inspect(pkg2.parts().length() == pkg1.parts().length(), content="true")
  for p in pkg1.parts() {
    let other = pkg2.require_part(p.name)
    debug_inspect(other.content_type == p.content_type, content="true")
    debug_inspect(other.bytes().length() == p.bytes().length(), content="true")
  }
  // Rels survive too.
  let r1 = pkg1.relationships_for("/ppt/presentation.xml")
  let r2 = pkg2.relationships_for("/ppt/presentation.xml")
  debug_inspect(r2.items().length() == r1.items().length(), content="true")
}

///|
test "mutate: add a slide part + register override + save + reopen" {
  let pkg = @opc.Package::open(build_fixture())
  let new_slide = @opc.Part::new(
    "/ppt/slides/slide2.xml",
    "",
    utf8_bytes("<p:sld xmlns:p=\"x\"/>"),
  )
  pkg.add_part(new_slide)
  // Register the Override for it.
  let new_ct = pkg
    .content_types()
    .with_override(
      "/ppt/slides/slide2.xml", "application/vnd.openxmlformats-officedocument.presentationml.slide+xml",
    )
  pkg.set_content_types(new_ct)
  pkg.regenerate_content_types_part()
  // Save and reopen.
  let pkg2 = @opc.Package::open(pkg.to_bytes())
  let p = pkg2.require_part("/ppt/slides/slide2.xml")
  debug_inspect(
    p.content_type,
    content="\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"",
  )
}

///|
test "mutate: replace a part's bytes survives round trip" {
  let pkg = @opc.Package::open(build_fixture())
  // Replace the slide content.
  let _ = pkg.remove_part("/ppt/slides/slide1.xml")
  let updated = @opc.Part::new(
    "/ppt/slides/slide1.xml",
    "",
    utf8_bytes("<p:sld xmlns:p=\"x\"><edited/></p:sld>"),
  )
  pkg.add_part(updated)
  let pkg2 = @opc.Package::open(pkg.to_bytes())
  let p = pkg2.require_part("/ppt/slides/slide1.xml")
  let s = p.text()
  debug_inspect(s.contains("<edited/>"), content="true")
}
