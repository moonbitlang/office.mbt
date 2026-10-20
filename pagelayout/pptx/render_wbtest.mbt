///|
fn probe_fonts() -> @fonts.FontRegistry raise {
  let registry = @fonts.FontRegistry::new()
  let metrics = @fonts.FaceMetrics::new(
    family="Probe",
    units_per_em=1000,
    ascender=800,
    descender=-200,
    line_gap=0,
    advances=[600, 600],
    cmap=Map([(65, 1), (66, 1), (32, 1)]),
  )
  registry.register_standard("Probe", metrics, standard="Helvetica") |> ignore
  registry
}

///|
fn source_slide(shapes : String, background~ : String = "") -> String {
  "<p:sld xmlns:p=\"" +
  @oxml.presentation_ns +
  "\" xmlns:a=\"" +
  @oxml.drawing_ns +
  "\"><p:cSld>" +
  background +
  "<p:spTree>" +
  shapes +
  "</p:spTree></p:cSld></p:sld>"
}

///|
fn source_shape(
  body : String,
  id~ : Int32 = 1,
  fill~ : String = "<a:noFill/>",
) -> String {
  "<p:sp><p:nvSpPr><p:cNvPr id=\"\{id}\" name=\"probe\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"1270000\" cy=\"1270000\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>" +
  fill +
  "</p:spPr>" +
  body +
  "</p:sp>"
}

///|
fn source_package(slides : Array[String], order : Array[Int32]) -> Bytes raise {
  let archive = @zip.Archive::Archive()
  archive.add(
    "[Content_Types].xml",
    @utf8.encode(
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>",
    ),
  )
  archive.add(
    "_rels/.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rMain\" Type=\"" +
      @opc.rt_office_document +
      "\" Target=\"ppt/presentation.xml\"/></Relationships>",
    ),
  )
  let ids = order
    .map(index => "<p:sldId id=\"\{256 + index}\" r:id=\"r\{index}\"/>")
    .join("")
  archive.add(
    "ppt/presentation.xml",
    @utf8.encode(
      "<p:presentation xmlns:p=\"" +
      @oxml.presentation_ns +
      "\" xmlns:r=\"" +
      @oxml.office_relationships_ns +
      "\"><p:sldIdLst>" +
      ids +
      "</p:sldIdLst><p:sldSz cx=\"9144000\" cy=\"5143500\"/></p:presentation>",
    ),
  )
  let rels = StringBuilder()
  rels.write_string(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
  )
  for index, slide in slides {
    rels.write_string(
      "<Relationship Id=\"r\{index}\" Type=\"" +
      @opc.rt_slide +
      "\" Target=\"slides/slide\{index}.xml\"/>",
    )
    archive.add("ppt/slides/slide\{index}.xml", @utf8.encode(slide))
  }
  rels.write_string("</Relationships>")
  archive.add("ppt/_rels/presentation.xml.rels", @utf8.encode(rels.to_string()))
  @zip.write(archive)
}

///|
fn text_runs(
  model : @pagelayout.PageModel,
  page : Int32,
) -> Array[@pagelayout.GlyphRun] {
  let result = []
  for item in model.pages[page].items {
    if item is Graphic(graphic) {
      for op in graphic.ops {
        if op is Text(run) {
          result.push(run)
        }
      }
    }
  }
  result
}

///|
test "render retains presentation relationship order, dimensions and source bytes" {
  let first = source_slide(
    source_shape(
      "",
      fill="<a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill>",
    ),
  )
  let second = source_slide(
    source_shape(
      "",
      fill="<a:solidFill><a:srgbClr val=\"00FF00\"/></a:solidFill>",
    ),
  )
  let bytes = source_package([first, second], [1, 0])
  let original = bytes.to_array()
  let layout = layout_presentation(bytes)
  debug_inspect(
    layout.slide_parts,
    content=(
      #|["/ppt/slides/slide1.xml", "/ppt/slides/slide0.xml"]
    ),
  )
  debug_inspect(
    (layout.model.pages[0].width_pt, layout.model.pages[0].height_pt),
    content="(720, 405)",
  )
  debug_inspect(layout.model.validate(), content="[]")
  assert_eq(bytes.to_array(), original)
  guard layout.model.pages[0].items[0] is Graphic(graphic) &&
    graphic.ops[3] is Path(path) else {
    fail("missing first shape")
  }
  assert_eq(path.fill, Some(Solid(@pagelayout.Color::rgb(0, 255, 0))))
}

///|
test "fixed line spacing includes paragraph-end metrics even with mixed run sizes" {
  let body =
    #|<p:txBody><a:bodyPr lIns="0" tIns="0" rIns="0" bIns="0"/>
    #|<a:lstStyle><a:lvl1pPr><a:defRPr sz="1800"><a:latin typeface="Probe"/></a:defRPr></a:lvl1pPr></a:lstStyle>
    #|<a:p><a:pPr><a:lnSpc><a:spcPts val="2000"/></a:lnSpc></a:pPr><a:r><a:rPr sz="1200"/><a:t>A</a:t></a:r><a:endParaRPr sz="1800"/></a:p>
    #|<a:p><a:pPr><a:lnSpc><a:spcPts val="2000"/></a:lnSpc></a:pPr><a:r><a:rPr sz="600"/><a:t>B</a:t></a:r><a:endParaRPr sz="1800"/></a:p></p:txBody>
  let caller = probe_fonts()
  let layout = layout_presentation(
    source_package([source_slide(source_shape(body))], [0]),
    fonts=caller,
  )
  let runs = text_runs(layout.model, 0)
  debug_inspect(
    runs.map(run => (run.text, run.size_pt, run.baseline_pt)),
    content=(
      #|[("A", 12, 16.4), ("B", 6, 36.4)]
    ),
  )
  assert_false(caller.is_sealed())
  assert_true(layout.fonts.is_sealed())
}

///|
test "style cascade keeps explicit false and zero, and never copies placeholder prompts" {
  let body =
    #|<p:txBody><a:bodyPr lIns="0"/><a:lstStyle/><a:p><a:pPr marL="0"/><a:r><a:rPr b="0"/><a:t>A</a:t></a:r></a:p></p:txBody>
  let slide = parse_root(
    @utf8.encode(source_slide(source_shape(body))).to_fixedarray(),
  )
  let style =
    #|<p:defaultTextStyle xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:lvl1pPr marL="12700"><a:defRPr sz="1800" b="1"><a:latin typeface="Probe"/></a:defRPr></a:lvl1pPr></p:defaultTextStyle>
  let defaults = parse_root(@utf8.encode(style).to_fixedarray())
  let resolved = resolved_slide(slide, None, None, Some(defaults))
  guard resolved.shapes[0] is AutoShape(shape) &&
    shape.text_body is Some(body) &&
    body.paragraphs[0].content[0] is RunContent(run) else {
    fail("missing text")
  }
  assert_eq(run.properties.bold, Some(false))
  assert_eq(run.properties.font_size, Some(Pt(18)))
  assert_eq(run.properties.latin, Some("Probe"))
  assert_eq(body.paragraphs[0].properties.margin_left, Some(Emu(0L)))
  assert_eq(body.body_properties.unwrap().left_inset, Some(Emu(0L)))
}

///|
test "font compatibility normalization is restricted to the known namespace defect" {
  let pkg = @opc.Package::new()
  let malformed =
    #|<r:Relationships xmlns:r="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="font" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/font" Target="fonts/test.fntdata"/></r:Relationships>
  pkg.add_part(
    @opc.Part::new(
      "/ppt/_rels/presentation.xml.rels",
      "application/vnd.openxmlformats-package.relationships+xml",
      @utf8.encode(malformed).to_fixedarray(),
    ),
  )
  debug_inspect(
    relationships(pkg, "/ppt/presentation.xml")
    .by_id("font")
    .map(rel => rel.target),
    content=(
      #|Some("fonts/test.fntdata")
    ),
  )
  let bad = malformed.replace(
    old="/relationships/font",
    new="/relationships/slide",
  )
  pkg.replace_part(
    @opc.Part::new(
      "/ppt/_rels/presentation.xml.rels",
      "application/vnd.openxmlformats-package.relationships+xml",
      @utf8.encode(bad).to_fixedarray(),
    ),
  )
  |> ignore
  try relationships(pkg, "/ppt/presentation.xml") catch {
    @opc.OpcError::MalformedPackage(_) => ()
    error => raise error
  } noraise {
    _ => fail("non-font namespace defects must stay errors")
  }
}

///|
test "EOT validates bounds and supports the documented XOR flag" {
  let raw : FixedArray[Byte] = FixedArray::make(94, 0x00)
  raw[0] = 94
  raw[4] = 12
  raw[10] = 1
  raw[34] = 0x4c
  raw[35] = 0x50
  raw[83] = 1
  let plain = eot_program(Bytes::from_array(raw))
  raw[15] = 0x10
  for index in 82..<94 {
    raw[index] = (raw[index].to_int() ^ 0x50).to_byte()
  }
  assert_eq(eot_program(Bytes::from_array(raw)), plain)
  raw[4] = 95
  try eot_program(Bytes::from_array(raw)) catch {
    InvalidPresentation(_) => ()
    error => raise error
  } noraise {
    _ => fail("truncated EOT must stay an error")
  }
}
