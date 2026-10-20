///|
test "TrueType and CFF programs travel from the catalog into standalone SVG" {
  for program in [probe_ttf(), probe_cff()] {
    let fonts = @fonts.FontRegistry::new()
    let face = fonts.register("Probe", program)
    inspect(face.ascent_pt(10), content="8")
    inspect(face.typographic_descent_pt(10), content="-3")
    inspect(face.typographic_line_height_pt(10), content="11")
    inspect(face.underline_offset_pt(10), content="1.2")
    inspect(face.underline_width_pt(10), content="0.6")
    inspect(face.kerning_pt(65, 66, 10), content="-1")
    inspect(face.kerning_pt(66, 65, 10), content="-0.5")
    inspect(face.kerning_pt(65, 32, 10), content="0")
    let body =
      #|<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr sz="1200"><a:latin typeface="Probe"/></a:rPr><a:t>A  B</a:t></a:r></a:p></p:txBody>
    let layout = layout_presentation(
      source_package([source_slide(source_shape(body))], [0]),
      fonts~,
    )
    assert_eq(
      layout.fonts.registered_face("Probe").unwrap().sfnt,
      Some(program),
    )
    let svg = @svg.render_page(layout.model, 0, fonts=layout.fonts)
    assert_true(svg.contains("@font-face"))
    assert_true(svg.contains("data:font/otf;base64,"))
    assert_true(svg.contains("text-rendering=\"geometricPrecision\""))
    assert_true(svg.contains("xml:space=\"preserve\""))
    assert_true(svg.contains(">A  B</text>"))
  }
}

///|
test "kerning crosses rich text runs and honors the run's size threshold" {
  let fonts = @fonts.FontRegistry::new()
  fonts.register("Probe", probe_ttf()) |> ignore
  fn render(threshold : String) -> Array[@pagelayout.GlyphRun] raise {
    let body = "<p:txBody><a:bodyPr lIns=\"0\" tIns=\"0\"/><a:lstStyle/><a:p>" +
      "<a:r><a:rPr sz=\"1200\" kern=\"\{threshold}\"><a:latin typeface=\"Probe\"/></a:rPr><a:t>A</a:t></a:r>" +
      "<a:r><a:rPr sz=\"1200\" kern=\"\{threshold}\"><a:latin typeface=\"Probe\"/><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:rPr><a:t>BA</a:t></a:r>" +
      "</a:p></p:txBody>"
    text_runs(
      layout_presentation(
        source_package([source_slide(source_shape(body))], [0]),
        fonts~,
      ).model,
      0,
    )
  }
  debug_inspect(
    render("100").map(run => (run.text, run.x_pt, run.advances_pt)),
    content=(
      #|[("A", 0, [6.05]), ("BA", 6.05, [6.65, 7.25])]
    ),
  )
  debug_inspect(
    render("0").map(run => (run.text, run.x_pt, run.advances_pt)),
    content=(
      #|[("A", 0, [7.25]), ("BA", 7.25, [7.25, 7.25])]
    ),
  )
  debug_inspect(
    render("2000").map(run => (run.text, run.x_pt, run.advances_pt)),
    content=(
      #|[("A", 0, [7.25]), ("BA", 7.25, [7.25, 7.25])]
    ),
  )
}

///|
test "absent kerning threshold disables pair adjustments" {
  let fonts = @fonts.FontRegistry::new()
  fonts.register("Probe", probe_ttf()) |> ignore
  let body =
    #|<p:txBody><a:bodyPr lIns="0" tIns="0"/><a:lstStyle/><a:p><a:r><a:rPr sz="1000"><a:latin typeface="Probe"/></a:rPr><a:t>AB</a:t></a:r></a:p></p:txBody>
  let runs = text_runs(
    layout_presentation(
      source_package([source_slide(source_shape(body))], [0]),
      fonts~,
    ).model,
    0,
  )
  debug_inspect(runs[0].advances_pt, content="[6, 6]")
}

///|
test "PPTX uses the run language for default kinsoku and respects an explicit override" {
  let body =
    #|<p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" sz="1200"><a:latin typeface="Probe"/><a:ea typeface="Probe"/></a:rPr><a:t>中中，中</a:t></a:r></a:p></p:txBody>
  fn layout_for(language : String, custom : Bool) -> Array[String] raise {
    let shape = source_shape(body.replace(old="en-US", new=language)).replace(
      old="cx=\"1270000\"",
      new="cx=\"184150\"",
    )
    let bytes = source_package([source_slide(shape)], [0])
    let fonts = @fonts.FontRegistry::new()
    fonts.register("Probe", probe_ttf()) |> ignore
    let bytes = if custom {
      let archive = @zip.read(bytes)
      let source = @utf8.decode(archive.get("ppt/presentation.xml").unwrap())
      archive.replace(
        "ppt/presentation.xml",
        @utf8.encode(
          source.replace(
            old="</p:presentation>",
            new="<p:kinsoku lang=\"zh-CN\" invalStChars=\"\" invalEndChars=\"\"/></p:presentation>",
          ),
        ),
      )
      |> ignore
      @zip.write(archive)
    } else {
      bytes
    }
    text_runs(layout_presentation(bytes, fonts~).model, 0).map(run => run.text)
  }
  debug_inspect(
    layout_for("en-US", false),
    content=(
      #|["中中", "，中"]
    ),
  )
  debug_inspect(
    layout_for("zh-CN", false),
    content=(
      #|["中", "中，", "中"]
    ),
  )
  debug_inspect(
    layout_for("ko-KR", false),
    content=(
      #|["中中", "，中"]
    ),
  )
  debug_inspect(
    layout_for("zh-CN", true),
    content=(
      #|["中中", "，中"]
    ),
  )
}

///|
test "a supplied face takes precedence before decoding an unsupported embedded container" {
  let fonts = @fonts.FontRegistry::new()
  fonts.register("Probe", probe_ttf()) |> ignore
  let source =
    #|<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:embeddedFontLst><p:embeddedFont><p:font typeface="Probe"/><p:regular r:id="unneeded"/></p:embeddedFont></p:embeddedFontLst></p:presentation>
  register_embedded_fonts(
    @opc.Package::new(),
    "/ppt/presentation.xml",
    parse_root(@utf8.encode(source).to_fixedarray()),
    fonts,
  )
  assert_false(fonts.is_sealed())
  assert_eq(fonts.registered_face("Probe").unwrap().sfnt, Some(probe_ttf()))
}

///|
test "missing glyphs fail before exporting a slide with replacement boxes" {
  let body =
    #|<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr><a:latin typeface="Probe"/></a:rPr><a:t>Z</a:t></a:r></a:p></p:txBody>
  try
    layout_presentation(
      source_package([source_slide(source_shape(body))], [0]),
      fonts=probe_fonts(),
    )
  catch {
    MissingFont(message) =>
      if !message.to_lower().contains("lacks u+5a") {
        fail(message)
      }
    error => raise error
  } noraise {
    _ => fail("a missing glyph must not become a replacement box")
  }
}

///|
test "a pair of em dashes can end a line before a Latin word" {
  let fonts = @fonts.FontRegistry::new()
  let face = @fonts.FaceMetrics::new(
    family="Dash",
    units_per_em=1000,
    ascender=800,
    descender=-200,
    line_gap=0,
    advances=[600, 600],
    cmap=Map([(32, 1), (65, 1), (66, 1), (0x4e2d, 1), (0x2014, 1)]),
  )
  fonts.register_standard("Dash", face, standard="Helvetica") |> ignore
  let body =
    #|<p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" sz="1000"><a:latin typeface="Dash"/><a:ea typeface="Dash"/></a:rPr><a:t>中——AB</a:t></a:r></a:p></p:txBody>
  let shape = source_shape(body).replace(
    old="cx=\"1270000\"",
    new="cx=\"304800\"",
  )
  let runs = text_runs(
    layout_presentation(source_package([source_slide(shape)], [0]), fonts~).model,
    0,
  )
  assert_eq(runs.map(run => run.text), ["中", "——", "AB"])
  assert_eq(runs[0].baseline_pt, runs[1].baseline_pt)
  assert_true(runs[2].baseline_pt > runs[1].baseline_pt)
}

///|
test "explicit breaks are layout controls rather than missing font glyphs" {
  let body =
    #|<p:txBody><a:bodyPr lIns="0" tIns="0"/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1200"><a:latin typeface="Probe"/></a:defRPr></a:pPr><a:r><a:t>A</a:t></a:r><a:br><a:rPr sz="1200"><a:latin typeface="Probe"/></a:rPr></a:br><a:r><a:t>B</a:t></a:r></a:p></p:txBody>
  let runs = text_runs(
    layout_presentation(
      source_package([source_slide(source_shape(body))], [0]),
      fonts=probe_fonts(),
    ).model,
    0,
  )
  assert_eq(runs.map(run => run.text), ["A", "B"])
  assert_true(runs[1].baseline_pt > runs[0].baseline_pt)
}

///|
test "PowerPoint measurement rounding is symmetric across runtimes" {
  assert_eq(pptx_advance(1.0625), 1.125)
  assert_eq(pptx_advance(-1.0625), -1.125)
  assert_eq(pptx_round(-0.125, 100), -0.13)
}
