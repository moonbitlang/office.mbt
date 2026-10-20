///|
test "a bullet uses its own script font and relative size" {
  let fonts = @fonts.FontRegistry::new()
  for (family, characters) in [("Latin", [65, 8226]), ("CJK", [0x4e2d])] {
    let cmap : Map[Int32, Int32] = Map([])
    for character in characters {
      cmap[character] = 1
    }
    let face = @fonts.FaceMetrics::new(
      family~,
      units_per_em=1000,
      ascender=800,
      descender=-200,
      line_gap=0,
      advances=[600, 600],
      cmap~,
    )
    fonts.register_standard(family, face, standard="Helvetica") |> ignore
  }
  let body =
    #|<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:buSzPct val="50000"/><a:buChar char="•"/></a:pPr><a:r><a:rPr sz="1200"><a:latin typeface="Latin"/><a:ea typeface="CJK"/></a:rPr><a:t>中</a:t></a:r></a:p></p:txBody>
  let layout = layout_presentation(
    source_package([source_slide(source_shape(body))], [0]),
    fonts~,
  )
  let runs = text_runs(layout.model, 0)
  debug_inspect(
    runs.map(run => (run.text, layout.model.fonts[run.font].family, run.size_pt)),
    content="[(\"•\", \"Latin\", 6), (\"中\", \"CJK\", 12)]",
  )
}

///|
test "a recognized unsupported effect aborts instead of returning an incomplete slide" {
  let shape = source_shape("").replace(
    old="</p:spPr>",
    new="<a:effectLst><a:glow rad=\"12700\"><a:srgbClr val=\"FF0000\"/></a:glow></a:effectLst></p:spPr>",
  )
  try layout_presentation(source_package([source_slide(shape)], [0])) catch {
    Unsupported(message) => assert_true(message.contains("shape effects"))
    error => raise error
  } noraise {
    _ => fail("an unsupported glow must not disappear silently")
  }
}

///|
test "negative tracking after a line cannot make another glyph fit" {
  let fonts = @fonts.FontRegistry::new()
  fonts.register("Probe", probe_ttf()) |> ignore
  let body =
    #|<p:txBody><a:bodyPr lIns="0" rIns="0" tIns="0" bIns="0"/><a:lstStyle/><a:p><a:pPr algn="r"/><a:r><a:rPr lang="en-US" sz="1200" spc="-100"><a:latin typeface="Probe"/><a:ea typeface="Probe"/></a:rPr><a:t>中中中</a:t></a:r></a:p></p:txBody>
  let shape = source_shape(body).replace(
    old="cx=\"1270000\"",
    new="cx=\"241300\"",
  )
  let runs = text_runs(
    layout_presentation(source_package([source_slide(shape)], [0]), fonts~).model,
    0,
  )
  debug_inspect(
    runs.map(run => (run.text, run.x_pt, run.advances_pt)),
    content=(
      #|[("中中", 5.5, [6.25, 7.25]), ("中", 11.75, [7.25])]
    ),
  )
}
