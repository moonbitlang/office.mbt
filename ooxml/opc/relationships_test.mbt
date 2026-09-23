// Modified for office.mbt: follow the workspace warning conventions.

///|
let rels_ns_test : String = "http://schemas.openxmlformats.org/package/2006/relationships"

///|
fn rels_xml(body : String) -> String {
  "<?xml version=\"1.0\"?>" +
  "<Relationships xmlns=\"" +
  rels_ns_test +
  "\">" +
  body +
  "</Relationships>"
}

// --- rels_path_for ---

///|
test "rels_path_for: package root" {
  debug_inspect(
    @opc.rels_path_for(@opc.package_root),
    content="\"/_rels/.rels\"",
  )
}

///|
test "rels_path_for: part" {
  debug_inspect(
    @opc.rels_path_for("/ppt/presentation.xml"),
    content="\"/ppt/_rels/presentation.xml.rels\"",
  )
  debug_inspect(
    @opc.rels_path_for("/ppt/slides/slide1.xml"),
    content="\"/ppt/slides/_rels/slide1.xml.rels\"",
  )
}

// --- resolve_target ---

///|
test "resolve_target: relative inside same dir" {
  debug_inspect(
    @opc.resolve_target("/ppt/presentation.xml", "slides/slide1.xml", Internal),
    content="\"/ppt/slides/slide1.xml\"",
  )
}

///|
test "resolve_target: walks `..`" {
  debug_inspect(
    @opc.resolve_target(
      "/ppt/slides/slide1.xml",
      "../media/image1.png",
      Internal,
    ),
    content="\"/ppt/media/image1.png\"",
  )
}

///|
test "resolve_target: absolute target unchanged" {
  debug_inspect(
    @opc.resolve_target(
      "/ppt/slides/slide1.xml",
      "/docProps/core.xml",
      Internal,
    ),
    content="\"/docProps/core.xml\"",
  )
}

///|
test "resolve_target: external target unchanged" {
  debug_inspect(
    @opc.resolve_target(
      "/ppt/slides/slide1.xml",
      "https://example.org/x.png",
      External,
    ),
    content="\"https://example.org/x.png\"",
  )
}

///|
test "resolve_target: from package root" {
  debug_inspect(
    @opc.resolve_target(@opc.package_root, "ppt/presentation.xml", Internal),
    content="\"/ppt/presentation.xml\"",
  )
}

// --- parse / serialize ---

///|
test "parse single Internal relationship" {
  let xml = rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
  )
  let rels = @opc.Relationships::parse(@opc.package_root, utf8_bytes(xml))
  debug_inspect(rels.items().length(), content="1")
  let r = rels.items()[0]
  debug_inspect(r.id, content="\"rId1\"")
  debug_inspect(r.target, content="\"ppt/presentation.xml\"")
  debug_inspect(r.target_mode is Internal, content="true")
}

///|
test "parse External TargetMode" {
  let xml = rels_xml(
    "<Relationship Id=\"rId7\" Type=\"http://example/external\" Target=\"https://example.org/x\" TargetMode=\"External\"/>",
  )
  let rels = @opc.Relationships::parse("/foo.xml", utf8_bytes(xml))
  debug_inspect(rels.items()[0].target_mode is External, content="true")
}

///|
test "parse rejects malformed input" {
  let bad = "<?xml version=\"1.0\"?><Relationships><Relationship/></Relationships>"
  try @opc.Relationships::parse(@opc.package_root, utf8_bytes(bad)) catch {
    MalformedPackage(_) => ()
    _ => fail("expected MalformedPackage")
  } noraise {
    _ => fail("expected MalformedPackage")
  }
  let bad2 = rels_xml("<Relationship Id=\"rId1\" Type=\"x\"/>") // no Target
  try @opc.Relationships::parse(@opc.package_root, utf8_bytes(bad2)) catch {
    MalformedPackage(_) => ()
    _ => fail("expected MalformedPackage")
  } noraise {
    _ => fail("expected MalformedPackage")
  }
  let bad3 = rels_xml(
    "<Relationship Id=\"rId1\" Type=\"x\" Target=\"y\" TargetMode=\"Weird\"/>",
  )
  try @opc.Relationships::parse(@opc.package_root, utf8_bytes(bad3)) catch {
    MalformedPackage(_) => ()
    _ => fail("expected MalformedPackage")
  } noraise {
    _ => fail("expected MalformedPackage")
  }
}

///|
test "serialize -> parse round trip preserves entries" {
  let original = @opc.Relationships::new(@opc.package_root)
    .with_relationship({
      id: "rId1",
      rel_type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
      target: "ppt/presentation.xml",
      target_mode: Internal,
    })
    .with_relationship({
      id: "rId2",
      rel_type: "http://example/external",
      target: "https://example.org/x",
      target_mode: External,
    })
  let bytes = original.serialize()
  let reparsed = @opc.Relationships::parse(@opc.package_root, bytes)
  debug_inspect(reparsed.items().length(), content="2")
  for i in 0..<original.items().length() {
    debug_inspect(reparsed.items()[i] == original.items()[i], content="true")
  }
}

///|
test "with_relationship rejects duplicate ids" {
  let r1 : @opc.Relationship = {
    id: "rId1",
    rel_type: "x",
    target: "a",
    target_mode: Internal,
  }
  let r2 : @opc.Relationship = {
    id: "rId1",
    rel_type: "y",
    target: "b",
    target_mode: Internal,
  }
  let rels = @opc.Relationships::new(@opc.package_root).with_relationship(r1)
  try rels.with_relationship(r2) catch {
    MalformedPackage(_) => ()
    _ => fail("expected MalformedPackage")
  } noraise {
    _ => fail("expected MalformedPackage")
  }
}

///|
test "by_id and by_type lookups" {
  let rels = @opc.Relationships::new(@opc.package_root)
    .with_relationship({
      id: "rId1",
      rel_type: "type-a",
      target: "a",
      target_mode: Internal,
    })
    .with_relationship({
      id: "rId2",
      rel_type: "type-b",
      target: "b",
      target_mode: Internal,
    })
    .with_relationship({
      id: "rId3",
      rel_type: "type-a",
      target: "c",
      target_mode: Internal,
    })
  debug_inspect(rels.by_id("rId2").unwrap().target, content="\"b\"")
  debug_inspect(rels.by_id("missing") is None, content="true")
  debug_inspect(rels.by_type("type-a").length(), content="2")
  debug_inspect(rels.by_type("type-b").length(), content="1")
  debug_inspect(rels.by_type("missing").length(), content="0")
}

// --- Package integration ---

///|
let ct_ns_rt : String = "http://schemas.openxmlformats.org/package/2006/content-types"

///|
fn make_pkg_with_rels(
  extra : Array[(String, String)],
) -> FixedArray[Byte] raise {
  let entries : Array[(String, FixedArray[Byte])] = []
  let ct_xml = "<?xml version=\"1.0\"?><Types xmlns=\"" +
    ct_ns_rt +
    "\">" +
    "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
    "</Types>"
  entries.push(("[Content_Types].xml", utf8_bytes(ct_xml)))
  for kv in extra {
    entries.push((kv.0, utf8_bytes(kv.1)))
  }
  fixture_zip(entries)
}

///|
test "Package::relationships_for: package root" {
  let pkg_rels_xml = "<?xml version=\"1.0\"?><Relationships xmlns=\"" +
    rels_ns_test +
    "\"><Relationship Id=\"rId1\" Type=\"http://t1\" Target=\"ppt/presentation.xml\"/></Relationships>"
  let bytes = make_pkg_with_rels([
    ("_rels/.rels", pkg_rels_xml),
    ("ppt/presentation.xml", "<presentation/>"),
  ])
  let pkg = @opc.Package::open(bytes)
  let rels = pkg.relationships_for(@opc.package_root)
  debug_inspect(rels.items().length(), content="1")
  debug_inspect(rels.items()[0].id, content="\"rId1\"")
}

///|
test "Package::relationships_for: missing rels file returns empty" {
  let bytes = make_pkg_with_rels([("ppt/presentation.xml", "<presentation/>")])
  let pkg = @opc.Package::open(bytes)
  let rels = pkg.relationships_for("/ppt/presentation.xml")
  debug_inspect(rels.items().length(), content="0")
}

///|
test "Package::relationships_for: part-level rels" {
  let part_rels_xml = "<?xml version=\"1.0\"?><Relationships xmlns=\"" +
    rels_ns_test +
    "\"><Relationship Id=\"rId1\" Type=\"http://t/slide\" Target=\"slides/slide1.xml\"/></Relationships>"
  let bytes = make_pkg_with_rels([
    ("ppt/presentation.xml", "<presentation/>"),
    ("ppt/_rels/presentation.xml.rels", part_rels_xml),
    ("ppt/slides/slide1.xml", "<sld/>"),
  ])
  let pkg = @opc.Package::open(bytes)
  let rels = pkg.relationships_for("/ppt/presentation.xml")
  debug_inspect(rels.items().length(), content="1")
  let target = @opc.resolve_target(
    "/ppt/presentation.xml",
    rels.items()[0].target,
    rels.items()[0].target_mode,
  )
  debug_inspect(target, content="\"/ppt/slides/slide1.xml\"")
  // Verify the resolved target is in fact a real part.
  debug_inspect(!(pkg.part_by_name(target) is None), content="true")
}
