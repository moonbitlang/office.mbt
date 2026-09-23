// Modified for office.mbt: follow the workspace warning conventions.
// Slide master / slide layout writer round-trip tests.

///|
let a_ns : String = @oxml.drawing_ns

///|
fn roundtrip_master(
  bytes : FixedArray[Byte],
) -> @slide_master.SlideMaster raise {
  let first = @slide_master.SlideMaster::parse(bytes)
  @slide_master.SlideMaster::parse(first.serialize())
}

///|
fn roundtrip_layout(
  bytes : FixedArray[Byte],
) -> @slide_master.SlideLayout raise {
  let first = @slide_master.SlideLayout::parse(bytes)
  @slide_master.SlideLayout::parse(first.serialize())
}

// --- SlideMaster ---

///|
fn master_xml_with_default_clr_map() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldMaster xmlns:p=\"" +
    p_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
    "<p:sldLayoutIdLst>" +
    "<p:sldLayoutId id=\"2147483649\" r:id=\"rId1\"/>" +
    "<p:sldLayoutId id=\"2147483650\" r:id=\"rId2\"/>" +
    "</p:sldLayoutIdLst>" +
    "<p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>" +
    "<p:hf sldNum=\"0\" hdr=\"0\" ftr=\"0\" dt=\"0\"/>" +
    "</p:sldMaster>"
  @oxml.string_to_bytes(xml)
}

///|
test "SlideMaster::serialize: round-trips a default-clrMap master" {
  let m0 = @slide_master.SlideMaster::parse(master_xml_with_default_clr_map())
  let m1 = roundtrip_master(master_xml_with_default_clr_map())
  debug_inspect(m0 == m1, content="true")
}

///|
test "SlideMaster::serialize: preserves layout refs in source order" {
  let m1 = roundtrip_master(master_xml_with_default_clr_map())
  debug_inspect(m1.layout_refs.length(), content="2")
  debug_inspect(m1.layout_refs[0].id, content="2147483649")
  debug_inspect(m1.layout_refs[0].r_id, content="\"rId1\"")
  debug_inspect(m1.layout_refs[1].r_id, content="\"rId2\"")
}

///|
test "SlideMaster::serialize: preserves the 12-slot color mapping" {
  let m1 = roundtrip_master(master_xml_with_default_clr_map())
  debug_inspect(m1.color_mapping.bg1, content="Lt1")
  debug_inspect(m1.color_mapping.tx1, content="Dk1")
  debug_inspect(m1.color_mapping.accent6, content="Accent6")
  debug_inspect(m1.color_mapping.fol_hlink, content="FolHlink")
}

///|
test "SlideMaster::serialize: preserves cSld + txStyles + hf via extension" {
  let m1 = roundtrip_master(master_xml_with_default_clr_map())
  let names = m1.extension.map(e => e.name.local_name)
  debug_inspect(names.contains("cSld"), content="true")
  debug_inspect(names.contains("txStyles"), content="true")
  debug_inspect(names.contains("hf"), content="true")
}

///|
test "SlideMaster::serialize: non-default clrMap (bg1=dk1) round-trips" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldMaster xmlns:p=\"" +
    p_ns +
    "\" xmlns:r=\"" +
    r_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\">" +
    "<p:clrMap bg1=\"dk1\" tx1=\"lt1\" bg2=\"dk2\" tx2=\"lt2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/>" +
    "</p:sldMaster>"
  let m0 = @slide_master.SlideMaster::parse(@oxml.string_to_bytes(xml))
  let m1 = roundtrip_master(@oxml.string_to_bytes(xml))
  debug_inspect(m0 == m1, content="true")
  debug_inspect(m1.color_mapping.bg1, content="Dk1")
}

// --- SlideLayout ---

///|
fn layout_xml_title() -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldLayout xmlns:p=\"" +
    p_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\" type=\"title\">" +
    "<p:cSld name=\"Title Slide\"><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>" +
    "</p:sldLayout>"
  @oxml.string_to_bytes(xml)
}

///|
test "SlideLayout::serialize: round-trips a title layout" {
  let l0 = @slide_master.SlideLayout::parse(layout_xml_title())
  let l1 = roundtrip_layout(layout_xml_title())
  debug_inspect(l0 == l1, content="true")
}

///|
test "SlideLayout::serialize: preserves name and type" {
  let l1 = roundtrip_layout(layout_xml_title())
  debug_inspect(l1.name, content="\"Title Slide\"")
  debug_inspect(l1.layout_type, content="Title")
}

///|
test "SlideLayout::serialize: Blank layout (absent type attr) round-trips" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldLayout xmlns:p=\"" +
    p_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "</p:sldLayout>"
  let l0 = @slide_master.SlideLayout::parse(@oxml.string_to_bytes(xml))
  let l1 = roundtrip_layout(@oxml.string_to_bytes(xml))
  debug_inspect(l0 == l1, content="true")
  debug_inspect(l1.layout_type, content="Blank")
}

///|
test "SlideLayout::serialize: overrideClrMapping with custom slots" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sldLayout xmlns:p=\"" +
    p_ns +
    "\" xmlns:a=\"" +
    a_ns +
    "\" type=\"obj\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<p:clrMapOvr><a:overrideClrMapping" +
    " bg1=\"dk1\" tx1=\"lt1\" bg2=\"dk2\" tx2=\"lt2\"" +
    " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
    " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
    " hlink=\"hlink\" folHlink=\"folHlink\"/></p:clrMapOvr>" +
    "</p:sldLayout>"
  let l0 = @slide_master.SlideLayout::parse(@oxml.string_to_bytes(xml))
  let l1 = roundtrip_layout(@oxml.string_to_bytes(xml))
  debug_inspect(l0 == l1, content="true")
  match l1.clr_map_override {
    Override(cm) => debug_inspect(cm.bg1, content="Dk1")
    _ => fail("expected Override")
  }
}

///|
test "SlideLayoutType: round-trip every variant via to_xml -> from_xml" {
  let cases = [
    @slide_master.SlideLayoutType::Title,
    Tx,
    Blank,
    Object,
    TitleOnly,
    Custom,
    PicTx,
    VertTitleAndTxOverChart,
  ]
  for c in cases {
    let xml = c.to_xml()
    let parsed = @slide_master.SlideLayoutType::from_xml(xml)
    debug_inspect(parsed == c, content="true")
  }
}
