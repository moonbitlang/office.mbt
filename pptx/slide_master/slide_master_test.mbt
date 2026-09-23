// Modified for office.mbt: follow the workspace warning conventions.
// Slide master parser tests.

///|
let p_ns : String = @oxml.presentation_ns

///|
let r_ns : String = @oxml.office_relationships_ns

///|
fn office_like_master() -> FixedArray[Byte] {
  // A trimmed-down sldMaster: clrMap, sldLayoutIdLst with three layouts,
  // plus a deliberately noisy cSld + txStyles to verify skip behaviour.
  let a_ns = @oxml.drawing_ns
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldMaster xmlns:p=\"" +
    p_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\">" +
    "<p:cSld>" +
    "<p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>" +
    "<p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/></p:nvGrpSpPr>" +
    "</p:spTree>" +
    "</p:cSld>" +
    "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
    "<p:sldLayoutIdLst>" +
    "<p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/>" +
    "<p:sldLayoutId id=\"2147483650\" r:id=\"rId2\"/>" +
    "<p:sldLayoutId id=\"2147483651\" r:id=\"rId3\"/>" +
    "</p:sldLayoutIdLst>" +
    "<p:txStyles>" +
    "<p:titleStyle/><p:bodyStyle/><p:otherStyle/>" +
    "</p:txStyles>" +
    "<p:hf sldNum=\"0\" hdr=\"0\" ftr=\"0\" dt=\"0\"/>" +
    "</p:sldMaster>"
  @oxml.string_to_bytes(xml)
}

// --- ColorMapping ---

///|
test "parse: clrMap maps every slide-level slot to a theme color" {
  let m = @slide_master.SlideMaster::parse(office_like_master())
  let cm = m.color_mapping
  debug_inspect(cm.bg1 is Lt1, content="true")
  debug_inspect(cm.tx1 is Dk1, content="true")
  debug_inspect(cm.bg2 is Lt2, content="true")
  debug_inspect(cm.tx2 is Dk2, content="true")
  debug_inspect(cm.accent1 is Accent1, content="true")
  debug_inspect(cm.accent6 is Accent6, content="true")
  debug_inspect(cm.hlink is Hlink, content="true")
  debug_inspect(cm.fol_hlink is FolHlink, content="true")
}

///|
test "ColorMapping::resolve looks up slide-level slots" {
  let m = @slide_master.SlideMaster::parse(office_like_master())
  let cm = m.color_mapping
  // bg1 → lt1 per fixture
  debug_inspect(cm.resolve(Bg1).unwrap() is Lt1, content="true")
  // accent3 → accent3 (identity)
  debug_inspect(cm.resolve(Accent3).unwrap() is Accent3, content="true")
  // master-level slot is not a mapping key
  debug_inspect(cm.resolve(Dk1) is None, content="true")
  debug_inspect(cm.resolve(PhClr) is None, content="true")
}

// --- SlideLayoutRef ---

///|
test "parse: layout id list preserves order and unsigned ids" {
  let m = @slide_master.SlideMaster::parse(office_like_master())
  debug_inspect(m.layout_refs.length(), content="3")
  // OOXML uses xsd:unsignedInt for sldLayoutId/@id; values often exceed
  // 2^31. Verify Int64 storage carries them correctly.
  debug_inspect(m.layout_refs[0].id, content="2147483649")
  debug_inspect(m.layout_refs[0].r_id, content="\"rId1\"")
  debug_inspect(m.layout_refs[1].id, content="2147483650")
  debug_inspect(m.layout_refs[2].id, content="2147483651")
  debug_inspect(m.layout_refs[2].r_id, content="\"rId3\"")
}

// --- skip behaviour ---

///|
test "parse: cSld and txStyles and hf are skipped without error" {
  // The fixture's cSld has nested elements, txStyles has three children,
  // hf has four attributes. None of these are modelled by SlideMaster;
  // they all round-trip via `extension`. If subtree skipping
  // leaked state, parse() would raise — this test asserts the
  // tolerant-skip contract by name.
  let _ = @slide_master.SlideMaster::parse(office_like_master())
}

// --- error cases ---

///|
test "parse: missing clrMap is rejected" {
  let xml = "<?xml version=\"1.0\"?><p:sldMaster xmlns:p=\"" +
    p_ns +
    "\">" +
    "<p:sldLayoutIdLst/></p:sldMaster>"
  try @slide_master.SlideMaster::parse(@oxml.string_to_bytes(xml)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "parse: clrMap missing required slot is rejected" {
  let xml = "<?xml version=\"1.0\"?><p:sldMaster xmlns:p=\"" +
    p_ns +
    "\">" +
    "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\"/>" + // folHlink missing
    "</p:sldMaster>"
  try @slide_master.SlideMaster::parse(@oxml.string_to_bytes(xml)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "parse: clrMap with unknown enum value is rejected" {
  let xml = "<?xml version=\"1.0\"?><p:sldMaster xmlns:p=\"" +
    p_ns +
    "\">" +
    "<p:clrMap bg1=\"weirdo\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
    "</p:sldMaster>"
  try @slide_master.SlideMaster::parse(@oxml.string_to_bytes(xml)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "parse: sldLayoutId without r:id is rejected" {
  let xml = "<?xml version=\"1.0\"?><p:sldMaster xmlns:p=\"" +
    p_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\">" +
    "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
    "<p:sldLayoutIdLst><p:sldLayoutId id=\"1\"/></p:sldLayoutIdLst>" +
    "</p:sldMaster>"
  try @slide_master.SlideMaster::parse(@oxml.string_to_bytes(xml)) catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "parse: malformed XML wraps as XmlFailure" {
  try
    @slide_master.SlideMaster::parse(@oxml.string_to_bytes("<p:sldMaster"))
  catch {
    XmlFailure(_, _) => ()
    _ => fail("expected XmlFailure")
  } noraise {
    _ => fail("expected XmlFailure")
  }
}
