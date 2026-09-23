// Modified for office.mbt: follow the workspace warning conventions.
// Each test below mirrors a recipe in `examples/README.md`. Keep them
// in lockstep — if you change one, update the other so the docs stay
// honest.

///|
test "example 1: title slide with styled text" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let rp = @slide.RunProperties::default()
    .with_font_size(Pt(44.0))
    .with_bold()
    .with_color(@units.RgbColor::new(0x1F, 0x4E, 0x79))
  let body = @slide.TextBody::of_styled_text("Hello, MoonBit", rp)
  let title = @slide.AutoShape::textbox(
    id=2,
    name="Title",
    x=prs.pct_w(10.0),
    y=prs.pct_h(40.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(20.0),
    "",
  ).with_text_body(body)
  prs.update_slide_mut(0, prs.slides()[0].with_shape(AutoShape(title)))
  let _bytes = prs.save()
  debug_inspect(prs.slides()[0].shapes.length(), content="1")
}

///|
test "example 2: widescreen slide-size" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Widescreen)
  let sz = prs.presentation_part().unwrap().sld_sz.unwrap()
  debug_inspect(sz.cx, content="Emu(12192000)")
  // pct_w now resolves against the widescreen width.
  debug_inspect(prs.pct_w(100.0), content="Emu(12192000)")
}

///|
test "example 3: external + internal hyperlinks" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let link = @slide.RunProperties::default()
    .with_font_size(Pt(20.0))
    .with_color(@units.RgbColor::new(0x0B, 0x5C, 0xD2))
    .with_hyperlink("https://moonbitlang.com", tooltip="docs")
  let jump = @slide.RunProperties::default().with_hyperlink_to_slide(1)
  let tb1 = @slide.TextBody::of_styled_text("moonbitlang.com", link)
  let tb2 = @slide.TextBody::of_styled_text("→ next slide", jump)
  let box1 = @slide.AutoShape::textbox(
    id=2,
    name="ExtLink",
    x=prs.pct_w(10.0),
    y=prs.pct_h(20.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(15.0),
    "",
  ).with_text_body(tb1)
  let box2 = @slide.AutoShape::textbox(
    id=3,
    name="IntLink",
    x=prs.pct_w(10.0),
    y=prs.pct_h(50.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(15.0),
    "",
  ).with_text_body(tb2)
  let s = prs.slides()[0]
    .with_shape(AutoShape(box1))
    .with_shape(AutoShape(box2))
  prs.update_slide_mut(0, s)
  // External + internal hyperlink rels each landed once.
  let mut ext_count = 0
  let mut int_count = 0
  for p in prs.pkg.parts() {
    if p.name.has_prefix("/ppt/slides/") && p.name.has_suffix(".xml") {
      let rels = prs.pkg.relationships_for(p.name)
      ext_count = ext_count + rels.by_type(@opc.rt_hyperlink).length()
      int_count = int_count + rels.by_type(@opc.rt_slide).length()
    }
  }
  debug_inspect(ext_count, content="1")
  debug_inspect(int_count, content="1")
}

///|
test "example 4: speaker notes" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(
    0, "Remember to thank the team — XML-special chars like <&> are escaped automatically.",
  )
  debug_inspect(prs.notes_slides().length(), content="1")
  match prs.notes_slides()[0].shapes[0] {
    AutoShape(a) =>
      debug_inspect(
        a.text_body.unwrap().paragraphs[0].plain_text(),
        content="\"Remember to thank the team — XML-special chars like <&> are escaped automatically.\"",
      )
    _ => fail("expected notes AutoShape")
  }
}

///|
test "example 6: tables with merged cells and styled borders" {
  let red = @units.RgbColor::parse_hex("FF0000")
  let red_stroke : @oxml.Stroke = {
    width: Some(Emu(12_700L)),
    cap: None,
    compound: None,
    alignment: None,
    fill: Some(SolidFill(@oxml.Color::srgb(red))),
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
  let yellow = @units.RgbColor::parse_hex("FFFF00")
  let header_props = @slide.TableCellProperties::default()
    .with_fill(SolidFill(@oxml.Color::srgb(yellow)))
    .with_anchor(AnchorCenter)
    .with_borders(top=red_stroke, bottom=red_stroke)
  let header = @slide.TableCell::merged_origin("Quarter results", grid_span=2)
  let header = { ..header, properties: Some(header_props), }
  let row0 = @slide.TableRow::of_cells(
    [header, @slide.TableCell::h_merge_covered()],
    height=Emu(457_200L),
  )
  let row1 = @slide.TableRow::of_cells(
    [@slide.TableCell::of_text("Q1"), @slide.TableCell::of_text("Q2")],
    height=Emu(457_200L),
  )
  let t = @slide.Table::of_rows([row0, row1], col_widths=[
    Emu(2_286_000L),
    Emu(2_286_000L),
  ])
  // A built-in gallery style restyles the whole table by reference.
  let t = t.with_style(MediumStyle2Accent1)
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let gf = @slide.GraphicFrame::of_table(
    id=10,
    name="Summary",
    x=prs.pct_w(10.0),
    y=prs.pct_h(20.0),
    cx=prs.pct_w(60.0),
    cy=prs.pct_h(50.0),
    t,
  )
  prs.update_slide_mut(0, prs.slides()[0].with_shape(GraphicFrame(gf)))
  // The shape landed, the table has 2 rows, and the gallery style stuck.
  match prs.slides()[0].shapes[0] {
    GraphicFrame(g) =>
      match g.content {
        TableContent(t) => {
          debug_inspect(t.rows.length(), content="2")
          debug_inspect(
            t.properties.unwrap().table_style_id.unwrap() ==
            @slide.TableStylePreset::MediumStyle2Accent1.guid(),
            content="true",
          )
        }
        _ => fail("expected TableContent")
      }
    _ => fail("expected GraphicFrame")
  }
}

///|
test "example 7: bar chart from data" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_category("Q3")
    .with_category("Q4")
    .with_series("Revenue", [100.0, 200.0, 300.0, 250.0])
    .with_series("Cost", [60.0, 110.0, 180.0, 140.0])
  let chart = @chart.Chart::of_bar(data)
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // embed_data generates the editable .xlsx workbook behind
  // PowerPoint's "Edit Data" button.
  prs.add_chart_mut(
    0,
    chart,
    x=prs.pct_w(10.0),
    y=prs.pct_h(15.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(70.0),
    embed_data=data,
  )
  debug_inspect(prs.charts().length(), content="1")
  debug_inspect(
    prs.pkg.part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    is Some(_),
    content="true",
  )
}

///|
test "example 8: 3-slide pitch deck with widescreen + notes + chart + link" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Widescreen)
  let _ = prs.add_slide_mut(0)
  let title_rp = @slide.RunProperties::default()
    .with_font_size(Pt(44.0))
    .with_bold()
    .with_color(@units.RgbColor::new(0x1F, 0x4E, 0x79))
  let title = @slide.AutoShape::textbox(
    id=2,
    name="Title",
    x=prs.pct_w(10.0),
    y=prs.pct_h(40.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(20.0),
    "",
  ).with_text_body(@slide.TextBody::of_styled_text("Q4 results", title_rp))
  prs.update_slide_mut(0, prs.slides()[0].with_shape(AutoShape(title)))
  prs.set_notes_mut(0, "Open with the headline number.")
  let _ = prs.add_slide_mut(0)
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_category("Q3")
    .with_category("Q4")
    .with_series("Revenue", [100.0, 200.0, 300.0, 450.0])
  prs.add_chart_mut(
    1,
    @chart.Chart::of_bar(data),
    x=prs.pct_w(10.0),
    y=prs.pct_h(15.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(70.0),
  )
  let _ = prs.add_slide_mut(0)
  let link_rp = @slide.RunProperties::default()
    .with_font_size(Pt(20.0))
    .with_hyperlink_to_slide(0, tooltip="back to title")
  let closing = @slide.AutoShape::textbox(
    id=2,
    name="Closing",
    x=prs.pct_w(10.0),
    y=prs.pct_h(40.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(15.0),
    "",
  ).with_text_body(@slide.TextBody::of_styled_text("← back", link_rp))
  prs.update_slide_mut(2, prs.slides()[2].with_shape(AutoShape(closing)))
  let bytes = prs.save()
  // Reopen — round-trip survives.
  let prs2 = @presentation.Presentation::open(bytes)
  debug_inspect(prs2.slides().length(), content="3")
  debug_inspect(prs2.charts().length(), content="1")
  debug_inspect(prs2.notes_slides().length(), content="1")
}

///|
test "example 9: typed layout slides (compile-time placeholder schema)" {
  let prs = @presentation.Presentation::new()
  // Each constructor returns a handle that only exposes the layout's
  // placeholders. `.subtitle(...)` exists on a title slide; calling it on
  // a title-and-content handle would not compile.
  let _ = prs
    .add_title_slide_mut()
    .title("Quarterly Review")
    .subtitle("FY2026 · Q3")
    .finish_mut()
  let _ = prs
    .add_title_content_slide_mut()
    .title("Agenda")
    .body("Results · Outlook · Q&A")
    .finish_mut()
  let prs2 = @presentation.Presentation::open(prs.save())
  debug_inspect(prs2.slides().length(), content="2")
  debug_inspect(prs2.slides()[0].title() is Some(_), content="true")
  debug_inspect(prs2.slides()[1].body() is Some(_), content="true")
}

///|
test "example 10: slide transitions" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // A fade that also auto-advances after 3 seconds.
  let s = prs.slides()[0].with_transition(
    @slide.Transition::fade().with_advance_after(3000),
  )
  prs.update_slide_mut(0, s)
  let prs2 = @presentation.Presentation::open(prs.save())
  debug_inspect(prs2.slides()[0].transition is Some(_), content="true")
}

///|
test "example 11: ADT-driven chart options" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [100.0, 200.0])
  let chart = @chart.Chart::of_bar(data).with_options([
    Title("Revenue"),
    Legend(LegendBottom),
    DataLabels(DLblOutEnd),
  ])
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    chart,
    x=prs.pct_w(10.0),
    y=prs.pct_h(15.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(70.0),
  )
  debug_inspect(prs.charts().length(), content="1")
  debug_inspect(prs.charts()[0].chart.title is Some(_), content="true")
}

///|
test "example 12: typed picture builder pipeline" {
  let outline : @oxml.Stroke = {
    width: Some(Emu(12_700L)),
    cap: None,
    compound: None,
    alignment: None,
    fill: None,
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
  // builder → crop → effects → build. Cropping twice would not compile.
  let pic = @slide.Picture::builder(
      id=5,
      name="Logo",
      "rId2",
      x=Emu(0L),
      y=Emu(0L),
      cx=Emu(914_400L),
      cy=Emu(914_400L),
    )
    .with_crop(left=Percentage(10.0), right=Percentage(10.0))
    .with_effects(outline~)
    .build()
  debug_inspect(pic.blip_fill.src_rect is Some(_), content="true")
  debug_inspect(pic.stroke is Some(_), content="true")
}

///|
test "example 13: chart-data validation" {
  // A consistent table validates and composes straight into a builder.
  let good = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [10.0, 20.0])
  let _ = @chart.Chart::of_bar(good.validate())
  // A series with the wrong number of values is caught.
  let bad = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [10.0])
  debug_inspect(bad.is_consistent(), content="false")
  try bad.validate() |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected validate to raise on a mismatched series")
  }
}

///|
test "example 14: entrance animations" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // A shape to animate (shape id 2).
  let box = @slide.AutoShape::textbox(
    id=2,
    name="Box",
    x=prs.pct_w(10.0),
    y=prs.pct_h(30.0),
    cx=prs.pct_w(40.0),
    cy=prs.pct_h(20.0),
    "Fly in!",
  )
  let slide = prs.slides()[0].with_shape(AutoShape(box))
  // A click-driven timeline: the box flies in from the left, then a second
  // click spins it for emphasis.
  let timeline = @slide.Timeline::new()
    .on_click(Entrance(FlyIn(Left)), 2)
    .on_click(Emphasis(Spin(360)), 2)
  let animated = slide.with_animations(timeline)
  debug_inspect(animated.timing is Some(_), content="true")
  prs.update_slide_mut(0, animated)
  // `save()` emits the full canonical `<p:timing>` tree.
  let _bytes = prs.save()
}

///|
test "example 15: SmartArt diagram" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // Per-node colour overrides ride on top of the diagram's quick style.
  let hot = @smartart.Node::leaf("Ship")
    .with_fill(@units.RgbColor::new(0xC0, 0x00, 0x00))
    .with_text_color(@units.RgbColor::new(0xFF, 0xFF, 0xFF))
  let art = @smartart.SmartArt::new(Process, [
    @smartart.Node::leaf("Plan"),
    @smartart.Node::leaf("Build"),
    hot,
  ])
  prs.add_smartart_mut(
    0,
    art,
    x=prs.pct_w(10.0),
    y=prs.pct_h(15.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(70.0),
  )
  // The tree families take nested Nodes; the recursive hierarchy layout
  // definition lays the whole tree out in PowerPoint (see
  // examples/README.md §15).
  let _ = prs.add_slide_mut(0)
  let ceo = @smartart.Node::new("CEO", [
    @smartart.Node::leaf("CTO"),
    @smartart.Node::new("CFO", [@smartart.Node::leaf("Controller")]),
  ])
  prs.add_smartart_mut(
    1,
    @smartart.SmartArt::org_chart(ceo),
    x=prs.pct_w(10.0),
    y=prs.pct_h(15.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(70.0),
  )
  // Each slide gains one graphic-frame shape; the DiagramML parts survive
  // a save → reopen round-trip.
  let saved = prs.save()
  let prs2 = @presentation.Presentation::open(saved)
  debug_inspect(prs2.slides()[0].shapes.length(), content="1")
  debug_inspect(prs2.slides()[1].shapes.length(), content="1")
  // The node's colour overrides reach the saved diagram data part.
  let data = @oxml.bytes_to_string(
    @opc.Package::open(saved).require_part("/ppt/diagrams/data1.xml").bytes,
  )
  debug_inspect(data.contains("<a:srgbClr val=\"C00000\""), content="true")
}

///|
test "example 16: YouTube / online video" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // `add_youtube_video_mut` normalises the URL to the embeddable form and
  // wires the external video relationships; the caller supplies the preview
  // frame (here a tiny synthetic PNG stands in for a real poster image).
  prs.add_youtube_video_mut(
    0,
    "https://youtu.be/dQw4w9WgXcQ",
    minimal_png(),
    x=prs.pct_w(10.0),
    y=prs.pct_h(10.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(80.0),
  )
  debug_inspect(prs.slides()[0].shapes.length(), content="1")
  // `add_online_video_mut(slide, url, poster, x=…)` is the general form for any
  // streaming URL.
  let _bytes = prs.save()
}

///|
test "example 17: plot-type-aware chart validation" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [10.0, 20.0])
  // `outEnd` data labels are valid on a bar chart…
  let bar = @chart.Chart::of_bar(data).with_options([DataLabels(DLblOutEnd)])
  let _ = bar.validate()
  // …but invalid on a line chart — `validate` catches it before PowerPoint
  // would run its repair pass.
  let line = @chart.Chart::of_line(data).with_options([DataLabels(DLblOutEnd)])
  debug_inspect(line.is_consistent(), content="false")
  try line.validate() |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected validate to raise on an invalid label position")
  }
}

///|
test "example 18: slide sections" {
  let prs = @presentation.Presentation::new()
  for _ in 0..<4 {
    let _ = prs.add_slide_mut(0)
  }
  prs.set_sections_mut([
    { title: "Introduction", start: 0, },
    { title: "Content", start: 1, },
    { title: "Conclusion", start: 3, },
  ])
  prs.add_section_mut(title="Details", start=2)
  // Sections partition the deck in slide order and survive save → reopen.
  let reopened = @presentation.Presentation::open(prs.save())
  let sections = reopened.sections()
  debug_inspect(sections.length(), content="4")
  debug_inspect(sections[1] == { title: "Content", start: 1, }, content="true")
  debug_inspect(sections[2] == { title: "Details", start: 2, }, content="true")
  // Removal:
  prs.set_sections_mut([])
  debug_inspect(prs.sections().length(), content="0")
}

///|
/// A minimal valid PNG (signature + IHDR + IDAT + IEND) — enough for the image
/// detector; the cookbook's video poster stands in for a real frame.
fn minimal_png() -> FixedArray[Byte] {
  let raw : Array[Int] = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
    0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
    0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44,
    0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
    0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
    0x60, 0x82,
  ]
  let out = FixedArray::make(raw.length(), b'\x00')
  for i in 0..<raw.length() {
    out[i] = raw[i].to_byte()
  }
  out
}

///|
test "example 19: document properties (core + app)" {
  let prs = @presentation.Presentation::new()
  prs.set_core_properties_mut(
    prs.core_properties().with_title("Q3 Review").with_author("Ada"),
  )
  prs.set_app_properties_mut(
    @presentation.AppProperties::new()
    .with_company("ACME Corp")
    .with_manager("Grace"),
  )
  let reopened = @presentation.Presentation::open(prs.save())
  debug_inspect(
    reopened.core_properties().title.unwrap(),
    content="\"Q3 Review\"",
  )
  debug_inspect(reopened.core_properties().creator.unwrap(), content="\"Ada\"")
  let app = reopened.app_properties()
  debug_inspect(app.company.unwrap(), content="\"ACME Corp\"")
  debug_inspect(app.manager.unwrap(), content="\"Grace\"")
  // The merge kept the template's own Application field.
  debug_inspect(app.application.unwrap(), content="\"moon-pptx\"")
}

///|
test "example 20: right-to-left text and paragraph-mark formatting" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let rp = @slide.RunProperties::default().with_font_size(Pt(28.0))
  let para = @slide.Paragraph::of_styled_text("مرحبا بالعالم", rp).with_rtl(
    true,
  )
  let spacer = @slide.Paragraph::of_text("").with_end_run_properties(
    @slide.RunProperties::default().with_font_size(Pt(12.0)),
  )
  let body = @slide.TextBody::of_paragraphs([para, spacer])
  let shape = @slide.AutoShape::textbox(
    id=2,
    name="Arabic",
    x=prs.pct_w(10.0),
    y=prs.pct_h(30.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(25.0),
    "",
  ).with_text_body(body)
  prs.update_slide_mut(0, prs.slides()[0].with_shape(AutoShape(shape)))
  // Both properties survive save → reopen.
  let reopened = @presentation.Presentation::open(prs.save())
  let paras = match reopened.slides()[0].shapes[0] {
    AutoShape(sp) => sp.text_body.unwrap().paragraphs
    _ => abort("expected the AutoShape back")
  }
  debug_inspect(paras[0].properties.rtl, content="Some(true)")
  debug_inspect(
    paras[1].end_run_properties.unwrap().font_size,
    content="Some(Pt(12))",
  )
  // Unset direction stays unset rather than becoming left-to-right.
  debug_inspect(paras[1].properties.rtl, content="None")
}

///|
test "example 21: Japanese / CJK text and font resolution" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let rp = @slide.RunProperties::default()
    .with_font_size(Pt(28.0))
    .with_font_for_all_scripts("Meiryo")
  let body = @slide.TextBody::of_styled_text("日本語のテキスト", rp)
  let shape = @slide.AutoShape::textbox(
    id=2,
    name="JP",
    x=prs.pct_w(10.0),
    y=prs.pct_h(30.0),
    cx=prs.pct_w(80.0),
    cy=prs.pct_h(25.0),
    "",
  ).with_text_body(body)
  prs.update_slide_mut(0, prs.slides()[0].with_shape(AutoShape(shape)))
  let reopened = @presentation.Presentation::open(prs.save())
  let run_props = match reopened.slides()[0].shapes[0] {
    AutoShape(sp) =>
      match sp.text_body.unwrap().paragraphs[0].content[0] {
        RunContent(r) => r.properties
        _ => abort("expected a run")
      }
    _ => abort("expected the AutoShape back")
  }
  // All three slots survive the round-trip, which is what makes the CJK
  // characters render in Meiryo rather than the theme default.
  debug_inspect(run_props.latin, content="Some(\"Meiryo\")")
  debug_inspect(run_props.east_asian, content="Some(\"Meiryo\")")
  debug_inspect(run_props.complex_script, content="Some(\"Meiryo\")")
  // And the resolver agrees, against the deck's own theme.
  let scheme = reopened.themes()[0].font_scheme
  debug_inspect(
    @slide.resolve_run_font_for_script(run_props, scheme, "Jpan"),
    content="\"Meiryo\"",
  )
}

///|
test "example 22: shape ids without keeping a counter" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let box = @slide.AutoShape::textbox(
    id=1,
    name="Box",
    x=prs.pct_w(10.0),
    y=prs.pct_h(20.0),
    cx=prs.pct_w(35.0),
    cy=prs.pct_h(20.0),
    "left",
  )
  let slide = prs.slides()[0]
    .with_shape_auto_id(AutoShape(box))
    .with_shape_auto_id(AutoShape(box))
  prs.update_slide_mut(0, slide)
  debug_inspect(slide.duplicate_shape_ids().length(), content="0")
  // Both copies were built with id 1; the appends renumbered them.
  debug_inspect(slide.shapes[0].id().unwrap(), content="2")
  debug_inspect(slide.shapes[1].id().unwrap(), content="3")
  let _bytes = prs.save()
}

///|
test "example 23: shape effects (shadow, glow, reflection)" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let navy = @oxml.Color::srgb(@units.RgbColor::parse_hex("1F4E79"))
  let effects = @oxml.EffectList::empty()
    .with_outer_shadow(
      @oxml.OuterShadow::new(
        blur_rad=Emu(76_200L),
        dist=Emu(38_100L),
        dir=@units.Angle::from_ooxml(2_700_000),
        color=navy,
      ).with_alignment(RectTopLeft),
    )
    .with_glow(
      @oxml.Glow::new(
        Emu(63_500L),
        @oxml.Color::srgb(@units.RgbColor::parse_hex("FFC000")),
      ),
    )
  let card = @slide.AutoShape::round_rect(
    id=2,
    name="Card",
    x=prs.pct_w(20.0),
    y=prs.pct_h(30.0),
    cx=prs.pct_w(60.0),
    cy=prs.pct_h(30.0),
  ).with_effects(effects)
  prs.update_slide_mut(0, prs.slides()[0].with_shape(AutoShape(card)))
  // The effect list survives save -> open.
  let reopened = @presentation.Presentation::open(prs.save())
  let fx = match reopened.slides()[0].shapes[0] {
    AutoShape(sp) => sp.effects.unwrap()
    _ => abort("expected the AutoShape back")
  }
  debug_inspect(fx.outer_shadow.unwrap().blur_rad, content="Emu(76200)")
  debug_inspect(
    fx.outer_shadow.unwrap().alignment is Some(RectTopLeft),
    content="true",
  )
  debug_inspect(fx.glow.unwrap().rad, content="Emu(63500)")
}

///|
test "example 24: generating a large deck" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slides_mut(0, 500)
  let all = prs.slides()
  for i, s in all {
    let tb = @slide.AutoShape::textbox(
      id=2,
      name="Title",
      x=prs.pct_w(10.0),
      y=prs.pct_h(40.0),
      cx=prs.pct_w(80.0),
      cy=prs.pct_h(20.0),
      "Slide \{i + 1}",
    )
    prs.update_slide_mut(i, s.with_shape(AutoShape(tb)))
  }
  debug_inspect(prs.slide_count(), content="500")
  // Every slide survives the round-trip, so the batched sldIdLst, rels and
  // content-type overrides all agree.
  let reopened = @presentation.Presentation::open(prs.save())
  debug_inspect(reopened.slides().length(), content="500")
}
