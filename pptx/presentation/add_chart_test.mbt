// Modified for office.mbt: follow the workspace warning conventions.
// Tests for `Presentation::add_chart_mut` + `add_chart_ex_mut`.

///|
fn small_chart_data() -> @chart.ChartData {
  @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_series("Revenue", [100.0, 200.0])
}

///|
test "add_chart_mut: bar chart lands as /ppt/charts/chart1.xml" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let chart = @chart.Chart::of_bar(small_chart_data())
  prs.add_chart_mut(
    0,
    chart,
    x=Emu(914_400L),
    y=Emu(914_400L),
    cx=Emu(6_858_000L),
    cy=Emu(4_572_000L),
  )
  let chart_part = prs
    .opc_package()
    .part_by_name("/ppt/charts/chart1.xml")
    .unwrap()
  debug_inspect(chart_part.content_type == @oxml.ct_chart, content="true")
  // Slide tree gains a GraphicFrame with ChartContent.
  let slide = prs.slides()[0]
  debug_inspect(slide.shapes.length(), content="1")
  match slide.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        ChartContent(rid) => debug_inspect(rid, content="\"rId2\"")
        _ => fail("expected ChartContent")
      }
    _ => fail("expected GraphicFrame shape")
  }
}

///|
test "add_chart_mut: content_types gains Override for the chart part" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    @chart.Chart::of_pie(small_chart_data()),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  let cts = prs.opc_package().content_types()
  let has_chart_override = cts
    .overrides()
    .iter()
    .any(kv => kv.0 == "/ppt/charts/chart1.xml" && kv.1 == @oxml.ct_chart)
  debug_inspect(has_chart_override, content="true")
}

///|
test "add_chart_mut: second chart gets chart2 and a fresh rId" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    @chart.Chart::of_bar(small_chart_data()),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  prs.add_chart_mut(
    0,
    @chart.Chart::of_line(small_chart_data()),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  debug_inspect(
    prs.opc_package().part_by_name("/ppt/charts/chart1.xml") is Some(_),
    content="true",
  )
  debug_inspect(
    prs.opc_package().part_by_name("/ppt/charts/chart2.xml") is Some(_),
    content="true",
  )
  let slide = prs.slides()[0]
  debug_inspect(slide.shapes.length(), content="2")
}

///|
test "add_chart_mut: round-trips through save → open" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    @chart.Chart::of_bar(small_chart_data()),
    x=Emu(914_400L),
    y=Emu(914_400L),
    cx=Emu(6_858_000L),
    cy=Emu(4_572_000L),
  )
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  debug_inspect(prs2.charts().length(), content="1")
  let slide = prs2.slides()[0]
  match slide.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        ChartContent(rid) => debug_inspect(rid, content="\"rId2\"")
        _ => fail("expected ChartContent")
      }
    _ => fail("expected GraphicFrame")
  }
}

///|
test "add_chart_mut: rejects out-of-range slide index" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  try
    prs.add_chart_mut(
      99,
      @chart.Chart::of_bar(small_chart_data()),
      x=Emu(0L),
      y=Emu(0L),
      cx=Emu(100L),
      cy=Emu(100L),
    )
  catch {
    Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
/// Minimal spec-shaped `<cx:chartSpace>` (a waterfall) for the
/// `add_chart_ex_mut` direct test — mirrors the chart_ex parser fixture.
fn waterfall_chart_ex() -> @chart_ex.ChartEx raise {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
    "<cx:chartSpace xmlns:cx=\"http://schemas.microsoft.com/office/drawing/2014/chartex\">" +
    "<cx:chartData><cx:data id=\"0\">" +
    "<cx:strDim type=\"cat\"><cx:lvl ptCount=\"2\"><cx:pt idx=\"0\">A</cx:pt><cx:pt idx=\"1\">B</cx:pt></cx:lvl></cx:strDim>" +
    "<cx:numDim type=\"val\"><cx:lvl ptCount=\"2\" formatCode=\"General\"><cx:pt idx=\"0\">10</cx:pt><cx:pt idx=\"1\">20</cx:pt></cx:lvl></cx:numDim>" +
    "</cx:data></cx:chartData>" +
    "<cx:chart><cx:plotArea><cx:plotAreaRegion>" +
    "<cx:plotSurface/>" +
    "<cx:series layoutId=\"waterfall\" formatIdx=\"0\"><cx:dataId val=\"0\"/></cx:series>" +
    "</cx:plotAreaRegion></cx:plotArea></cx:chart>" +
    "</cx:chartSpace>"
  @chart_ex.ChartEx::parse(@oxml.string_to_bytes(xml))
}

///|
test "add_chart_ex_mut: chartEx part + rels + content type + reopen" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_ex_mut(
    0,
    waterfall_chart_ex(),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(5_000_000L),
    cy=Emu(3_000_000L),
  )
  // The chartEx part exists with its content-type override.
  debug_inspect(
    prs.opc_package().part_by_name("/ppt/charts/chartEx1.xml") is Some(_),
    content="true",
  )
  let ct = @oxml.bytes_to_string(
    prs.opc_package().part_by_name("/[Content_Types].xml").unwrap().bytes(),
  )
  debug_inspect(ct.find("chartex") is Some(_), content="true")
  // The slide references it and the deck survives save → reopen.
  let slide_xml = @oxml.bytes_to_string(
    prs.opc_package().part_by_name("/ppt/slides/slide1.xml").unwrap().bytes(),
  )
  debug_inspect(
    slide_xml.find("chartEx") is Some(_) ||
    slide_xml.find("graphicFrame") is Some(_),
    content="true",
  )
  let prs2 = @presentation.Presentation::open(prs.save())
  debug_inspect(prs2.slides()[0].shapes.length(), content="1")
}

// --- embedded data workbook (embed_data) ---

///|
fn add_bar_with_embed(prs : @presentation.Presentation) -> Unit raise {
  prs.add_chart_mut(
    0,
    @chart.Chart::of_bar(small_chart_data()),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
    embed_data=small_chart_data(),
  )
}

///|
test "add_chart_mut embed_data: chart gains externalData + workbook part" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  add_bar_with_embed(prs)
  // The chart XML references the workbook, autoUpdate off.
  let chart_xml = @oxml.bytes_to_string(
    prs.opc_package().require_part("/ppt/charts/chart1.xml").bytes(),
  )
  debug_inspect(
    chart_xml.contains(
      "<c:externalData r:id=\"rId1\"><c:autoUpdate val=\"0\"/></c:externalData>",
    ),
    content="true",
  )
  // Its rels resolve rId1 to the embedded package.
  let rels = prs.opc_package().relationships_for("/ppt/charts/chart1.xml")
  let rel = rels.by_id("rId1").unwrap()
  debug_inspect(rel.rel_type == @opc.rt_package, content="true")
  debug_inspect(
    rel.target,
    content="\"../embeddings/Microsoft_Excel_Worksheet1.xlsx\"",
  )
  // The part exists with the xlsx content type and a Default entry.
  let emb = prs
    .opc_package()
    .part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    .unwrap()
  debug_inspect(emb.content_type == @oxml.ct_xlsx_sheet, content="true")
  let has_default = prs
    .opc_package()
    .content_types()
    .defaults()
    .iter()
    .any(kv => kv.0 == "xlsx" && kv.1 == @oxml.ct_xlsx_sheet)
  debug_inspect(has_default, content="true")
}

///|
test "add_chart_mut embed_data: the workbook is a valid OPC package with the data" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  add_bar_with_embed(prs)
  let emb = prs
    .opc_package()
    .part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    .unwrap()
  let xlsx = @opc.Package::open(emb.bytes())
  // Root rels reach the workbook; workbook rels reach the sheet.
  let wb_rel = xlsx.relationships_for("/").by_id("rId1").unwrap()
  debug_inspect(wb_rel.target, content="\"xl/workbook.xml\"")
  let sheet_rel = xlsx
    .relationships_for("/xl/workbook.xml")
    .by_id("rId1")
    .unwrap()
  debug_inspect(sheet_rel.target, content="\"worksheets/sheet1.xml\"")
  // The sheet mirrors the ChartData layout.
  let sheet = @oxml.bytes_to_string(
    xlsx.require_part("/xl/worksheets/sheet1.xml").bytes(),
  )
  debug_inspect(
    sheet.contains("<c r=\"B1\" t=\"inlineStr\"><is><t>Revenue</t></is></c>"),
    content="true",
  )
  debug_inspect(
    sheet.contains("<c r=\"A2\" t=\"inlineStr\"><is><t>Q1</t></is></c>"),
    content="true",
  )
  debug_inspect(sheet.contains("<c r=\"B3\"><v>200</v></c>"), content="true")
}

///|
test "add_chart_mut embed_data: survives save -> reopen, rides extension" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  add_bar_with_embed(prs)
  let reopened = @presentation.Presentation::open(prs.save())
  // The workbook part is still there…
  debug_inspect(
    reopened
    .opc_package()
    .part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    is Some(_),
    content="true",
  )
  // …and the parsed chart carries <c:externalData> in its extension,
  // so a second embed attempt is rejected.
  let chart = @chart.Chart::parse(
    reopened.opc_package().require_part("/ppt/charts/chart1.xml").bytes(),
  )
  let mut found = false
  for ext in chart.extension {
    if ext.name.local_name == "externalData" {
      found = true
    }
  }
  debug_inspect(found, content="true")
  let _ = reopened.add_slide_mut(0)
  try
    reopened.add_chart_mut(
      1,
      chart,
      x=Emu(0L),
      y=Emu(0L),
      cx=Emu(100L),
      cy=Emu(100L),
      embed_data=small_chart_data(),
    )
  catch {
    Malformed(_) => ()
    _ => fail("expected Malformed for a chart that already has externalData")
  } noraise {
    _ => fail("expected Malformed for a chart that already has externalData")
  }
}

///|
test "add_chart_mut embed_data: two embedded charts get separate workbooks" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  add_bar_with_embed(prs)
  add_bar_with_embed(prs)
  debug_inspect(
    prs
    .opc_package()
    .part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    is Some(_),
    content="true",
  )
  debug_inspect(
    prs
    .opc_package()
    .part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet2.xlsx")
    is Some(_),
    content="true",
  )
  debug_inspect(
    prs
    .opc_package()
    .relationships_for("/ppt/charts/chart2.xml")
    .by_id("rId1")
    .unwrap().target,
    content="\"../embeddings/Microsoft_Excel_Worksheet2.xlsx\"",
  )
}

///|
test "add_chart_mut without embed_data: no workbook, no externalData" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    @chart.Chart::of_bar(small_chart_data()),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
  )
  debug_inspect(
    prs
    .opc_package()
    .part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    is None,
    content="true",
  )
  let chart_xml = @oxml.bytes_to_string(
    prs.opc_package().require_part("/ppt/charts/chart1.xml").bytes(),
  )
  debug_inspect(!chart_xml.contains("externalData"), content="true")
}

///|
test "add_chart_mut embed_data: 26+ series spill into double-letter columns" {
  let mut data = @chart.ChartData::new().with_category("only")
  for i in 0..<27 {
    data = data.with_series("S" + i.to_string(), [i.to_double()])
  }
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    @chart.Chart::of_bar(data),
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(100L),
    cy=Emu(100L),
    embed_data=data,
  )
  let emb = prs
    .opc_package()
    .part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    .unwrap()
  let sheet = @oxml.bytes_to_string(
    @opc.Package::open(emb.bytes())
    .require_part("/xl/worksheets/sheet1.xml")
    .bytes(),
  )
  // Column A is the category column, so series 24 (0-based) lands in
  // Z and series 25 wraps to AA.
  debug_inspect(
    sheet.contains("<c r=\"Z1\" t=\"inlineStr\"><is><t>S24</t></is></c>"),
    content="true",
  )
  debug_inspect(
    sheet.contains("<c r=\"AA1\" t=\"inlineStr\"><is><t>S25</t></is></c>"),
    content="true",
  )
  debug_inspect(sheet.contains("<c r=\"AA2\"><v>25</v></c>"), content="true")
}
