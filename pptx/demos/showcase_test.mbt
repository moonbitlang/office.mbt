// Modified for office.mbt: exercise the shared demo library through its public API.
// Guards that the sample deck is structurally sound — the library must be
// able to re-open the bytes it just produced, and the deck must carry the
// expected slide count + the second (defined) master.

///|
test "sample deck reopens with all feature slides + a defined master" {
  let prs = @presentation.Presentation::open(@demos.build_sample_deck())
  // 26 slides: title, toc, text, shapes, custom-geom, picture, table,
  // 4 chart slides, background, combo, svg, edit, media, smartart,
  // animation, online-video, v0.5.2 / v0.6 / v0.7 feature slides,
  // master, 2 typed-layout slides, closing.
  debug_inspect(prs.slides().length(), content="26")
  // The deck's own master + the one added by sample_master_slide.
  debug_inspect(prs.slide_masters().length(), content="2")
  // Every slide carries a transition.
  for s in prs.slides() {
    debug_inspect(s.transition is Some(_), content="true")
  }
  // The named sections partition the deck and survive the round-trip.
  let sections = prs.sections()
  debug_inspect(sections.length(), content="6")
  debug_inspect(sections[0].title, content="\"Introduction\"")
  debug_inspect(sections[5].start, content="22")
  // Both docProps parts carry their fields.
  debug_inspect(
    prs.app_properties().company.unwrap(),
    content="\"moon-pptx project\"",
  )
  debug_inspect(
    prs.core_properties().title.unwrap(),
    content="\"moon-pptx feature sample deck\"",
  )
  // The combo chart's embedded data workbook is in the package.
  debug_inspect(
    prs
    .opc_package()
    .part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    is Some(_),
    content="true",
  )
}

///|
test "each isolated feature deck reopens cleanly" {
  // Mirrors the CLI split mode: title + one feature must round-trip.
  for i in 0..<22 {
    let prs = @presentation.Presentation::open(@demos.build_sample_isolated(i))
    debug_inspect(prs.slides().length() >= 1, content="true")
  }
}
