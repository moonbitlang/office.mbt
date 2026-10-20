///|
/// Synthetic text-only deck, generated from rectangles and plain DrawingML.
fn cli_slide_probe() -> Bytes raise {
  let archive = @zip.Archive::Archive()
  archive.add(
    "[Content_Types].xml",
    @utf8.encode(
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Default Extension=\"png\" ContentType=\"image/png\"/><Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/><Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/><Override PartName=\"/ppt/slides/slide2.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/></Types>",
    ),
  )
  archive.add(
    "_rels/.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"main\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/></Relationships>",
    ),
  )
  archive.add(
    "ppt/presentation.xml",
    @utf8.encode(
      "<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"first\"/><p:sldId id=\"257\" r:id=\"second\"/></p:sldIdLst><p:sldSz cx=\"9144000\" cy=\"5143500\"/></p:presentation>",
    ),
  )
  archive.add(
    "ppt/_rels/presentation.xml.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"first\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/><Relationship Id=\"second\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide2.xml\"/></Relationships>",
    ),
  )
  archive.add(
    "ppt/slides/slide1.xml",
    @utf8.encode(
      "<p:sld xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"142F55\"/></a:solidFill></p:bgPr></p:bg><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr><p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Text 2\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"571500\" y=\"571500\"/><a:ext cx=\"7874000\" cy=\"889000\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr lIns=\"0\" rIns=\"0\" tIns=\"0\" bIns=\"0\"/><a:lstStyle/><a:p><a:r><a:rPr lang=\"en-US\" sz=\"3600\"><a:solidFill><a:srgbClr val=\"FFFFFF\"/></a:solidFill><a:latin typeface=\"Arial\"/></a:rPr><a:t>PPTX preview</a:t></a:r></a:p></p:txBody></p:sp><p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Text 3\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"571500\" y=\"1714500\"/><a:ext cx=\"7747000\" cy=\"762000\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr lIns=\"0\" rIns=\"0\" tIns=\"0\" bIns=\"0\"/><a:lstStyle/><a:p><a:r><a:rPr lang=\"en-US\" sz=\"2000\"><a:solidFill><a:srgbClr val=\"FFFFFF\"/></a:solidFill><a:latin typeface=\"Arial\"/></a:rPr><a:t>Read-only slides. Selectable text.</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>",
    ),
  )
  archive.add(
    "ppt/slides/slide2.xml",
    @utf8.encode(
      "<p:sld xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val=\"F1F5F9\"/></a:solidFill></p:bgPr></p:bg><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr><p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Text 2\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"571500\" y=\"571500\"/><a:ext cx=\"7874000\" cy=\"889000\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr lIns=\"0\" rIns=\"0\" tIns=\"0\" bIns=\"0\"/><a:lstStyle/><a:p><a:r><a:rPr lang=\"en-US\" sz=\"3200\"><a:solidFill><a:srgbClr val=\"142F55\"/></a:solidFill><a:latin typeface=\"Arial\"/></a:rPr><a:t>Second slide 中文</a:t></a:r></a:p></p:txBody></p:sp><p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Text 3\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"571500\" y=\"1651000\"/><a:ext cx=\"7747000\" cy=\"762000\"/></a:xfrm><a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr lIns=\"0\" rIns=\"0\" tIns=\"0\" bIns=\"0\"/><a:lstStyle/><a:p><a:r><a:rPr lang=\"en-US\" sz=\"2000\"><a:solidFill><a:srgbClr val=\"142F55\"/></a:solidFill><a:latin typeface=\"Arial\"/></a:rPr><a:t>Search, zoom and page navigation</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>",
    ),
  )
  @zip.write(archive)
}

///|
async test "PPTX preview embeds offline fonts and reports all slides without worksheet caps" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-pptx-preview-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let bytes = cli_slide_probe()
    let path = write_probe_package(directory, "slides.pptx", bytes)
    let source = read_office_package(path, presentation_render=true)
    let matches = preview_command().parse(argv=[
      path,
      "--output",
      directory + "/slides.html",
    ])
    let (html, stats) = office_preview_render_pptx(source, matches)
    assert_eq(stats.slides_rendered, Some(2))
    assert_true(html.contains("PPTX preview"))
    assert_true(html.contains("Second slide"))
    assert_true(html.contains("中文"))
    assert_true(html.contains("data:font/otf;base64,"))
    assert_eq(@afs.read_file(path).binary(), bytes)
    let report = office_preview_report(source, "out.html", html.length(), stats)
    assert_true(
      report
      is { "slides_rendered": Number(2, ..), "format": String("pptx"), .. },
    )
    guard report is { "truncation": Object(limits), .. } else {
      fail("missing preview limits")
    }
    assert_false(limits.contains("max_rows"))
    assert_false(limits.contains("max_cols"))
    assert_false(stats.warnings.is_empty())
    guard @lib.find_capability_command("preview") is Some(capability) else {
      fail("missing preview capability")
    }
    guard report is Object(fields) else {
      fail("preview report is not an object")
    }
    for field, _ in fields {
      assert_true(capability.outputs.any(output => output.name == field))
    }
  }
}

///|
async test "a Word package renamed to PPTX is rejected before producing slides" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-pptx-wrong-format-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let bytes = @afs.read_file(
      "../docx2html/tests/cram/fixtures/single-paragraph.docx",
    ).binary()
    let path = write_probe_package(directory, "wrong.pptx", bytes)
    let source = read_office_package(path, presentation_render=true)
    let matches = preview_command().parse(argv=[
      path,
      "--output",
      directory + "/wrong.html",
    ])
    try office_preview_render_pptx(source, matches) catch {
      CliFailure(error) => assert_eq(error.code, "office.pptx.render_failed")
      error => raise error
    } noraise {
      _ => fail("renamed DOCX was rendered as a presentation")
    }
    assert_eq(@afs.read_file(path).binary(), bytes)
  }
}
