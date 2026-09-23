// Modified for office.mbt: follow the workspace warning conventions.
// Graphic frame + table parser/writer tests.

///|
let table_uri : String = "http://schemas.openxmlformats.org/drawingml/2006/table"

///|
/// Build a one-slide deck whose `<p:spTree>` body is `inner_shapes`.
/// Re-uses the same shape as `slide_with_sp_pr` (geometry_test.mbt)
/// minus the auto-shape wrapping.
fn slide_with_shapes_xml(inner_shapes : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    inner_shapes +
    "</p:spTree></p:cSld></p:sld>"
  @oxml.string_to_bytes(xml)
}

///|
/// A typical 2-column / 2-row table embedded in a graphicFrame.
fn simple_table_graphic_frame_xml() -> String {
  "<p:graphicFrame>" +
  "<p:nvGraphicFramePr>" +
  "<p:cNvPr id=\"7\" name=\"Table 1\"/>" +
  "<p:cNvGraphicFramePr/>" +
  "<p:nvPr/>" +
  "</p:nvGraphicFramePr>" +
  "<p:xfrm>" +
  "<a:off x=\"914400\" y=\"914400\"/>" +
  "<a:ext cx=\"4572000\" cy=\"1828800\"/>" +
  "</p:xfrm>" +
  "<a:graphic><a:graphicData uri=\"" +
  table_uri +
  "\">" +
  "<a:tbl>" +
  "<a:tblPr firstRow=\"1\" bandRow=\"1\"/>" +
  "<a:tblGrid>" +
  "<a:gridCol w=\"2286000\"/>" +
  "<a:gridCol w=\"2286000\"/>" +
  "</a:tblGrid>" +
  "<a:tr h=\"457200\">" +
  "<a:tc>" +
  "<a:txBody><a:bodyPr/><a:lstStyle/>" +
  "<a:p><a:r><a:rPr lang=\"en-US\"/><a:t>A1</a:t></a:r></a:p>" +
  "</a:txBody>" +
  "<a:tcPr/>" +
  "</a:tc>" +
  "<a:tc>" +
  "<a:txBody><a:bodyPr/><a:lstStyle/>" +
  "<a:p><a:r><a:rPr lang=\"en-US\"/><a:t>B1</a:t></a:r></a:p>" +
  "</a:txBody>" +
  "<a:tcPr/>" +
  "</a:tc>" +
  "</a:tr>" +
  "<a:tr h=\"457200\">" +
  "<a:tc>" +
  "<a:txBody><a:bodyPr/><a:lstStyle/>" +
  "<a:p><a:r><a:rPr lang=\"en-US\"/><a:t>A2</a:t></a:r></a:p>" +
  "</a:txBody>" +
  "<a:tcPr/>" +
  "</a:tc>" +
  "<a:tc>" +
  "<a:txBody><a:bodyPr/><a:lstStyle/>" +
  "<a:p><a:r><a:rPr lang=\"en-US\"/><a:t>B2</a:t></a:r></a:p>" +
  "</a:txBody>" +
  "<a:tcPr/>" +
  "</a:tc>" +
  "</a:tr>" +
  "</a:tbl>" +
  "</a:graphicData></a:graphic>" +
  "</p:graphicFrame>"
}

// --- parser ---

///|
test "parse: graphicFrame with table lifts to GraphicFrame(TableContent)" {
  let bytes = slide_with_shapes_xml(simple_table_graphic_frame_xml())
  let slide = @slide.Slide::parse(bytes)
  debug_inspect(slide.shapes.length(), content="1")
  match slide.shapes[0] {
    GraphicFrame(gf) => {
      debug_inspect(gf.id, content="7")
      debug_inspect(gf.name, content="\"Table 1\"")
      // Transform comes from <p:xfrm>.
      let xfrm = gf.transform.unwrap()
      debug_inspect(xfrm.offset.x, content="Emu(914400)")
      debug_inspect(xfrm.extent.cx, content="Emu(4572000)")
      // Content is typed.
      match gf.content {
        TableContent(t) => {
          debug_inspect(t.grid.length(), content="2")
          debug_inspect(t.grid[0], content="Emu(2286000)")
          debug_inspect(t.rows.length(), content="2")
          debug_inspect(t.rows[0].cells.length(), content="2")
          // Cell A1 text:
          let a1 = t.rows[0].cells[0]
          let body = a1.text_body.unwrap()
          debug_inspect(body.plain_text(), content="\"A1\"")
          // Defaults: no merge, span=1.
          debug_inspect(a1.grid_span, content="1")
          debug_inspect(a1.row_span, content="1")
          debug_inspect(!a1.h_merge, content="true")
          debug_inspect(!a1.v_merge, content="true")
        }
        _ => fail("expected TableContent")
      }
    }
    _ => fail("expected GraphicFrame shape")
  }
}

///|
test "parse: gridSpan + rowSpan + hMerge + vMerge attributes preserved" {
  let body = "<p:graphicFrame>" +
    "<p:nvGraphicFramePr>" +
    "<p:cNvPr id=\"3\" name=\"Merged\"/><p:cNvGraphicFramePr/><p:nvPr/>" +
    "</p:nvGraphicFramePr>" +
    "<p:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></p:xfrm>" +
    "<a:graphic><a:graphicData uri=\"" +
    table_uri +
    "\">" +
    "<a:tbl>" +
    "<a:tblGrid><a:gridCol w=\"100\"/><a:gridCol w=\"100\"/></a:tblGrid>" +
    "<a:tr h=\"50\">" +
    "<a:tc gridSpan=\"2\" rowSpan=\"2\"><a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody><a:tcPr/></a:tc>" +
    "<a:tc hMerge=\"1\"><a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody><a:tcPr/></a:tc>" +
    "</a:tr>" +
    "<a:tr h=\"50\">" +
    "<a:tc vMerge=\"1\"><a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody><a:tcPr/></a:tc>" +
    "<a:tc hMerge=\"1\" vMerge=\"1\"><a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody><a:tcPr/></a:tc>" +
    "</a:tr>" +
    "</a:tbl>" +
    "</a:graphicData></a:graphic>" +
    "</p:graphicFrame>"
  let slide = @slide.Slide::parse(slide_with_shapes_xml(body))
  match slide.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        TableContent(t) => {
          let origin = t.rows[0].cells[0]
          debug_inspect(origin.grid_span, content="2")
          debug_inspect(origin.row_span, content="2")
          debug_inspect(!origin.h_merge, content="true")
          debug_inspect(!origin.v_merge, content="true")
          let cov_h = t.rows[0].cells[1]
          debug_inspect(cov_h.h_merge, content="true")
          debug_inspect(!cov_h.v_merge, content="true")
          let cov_v = t.rows[1].cells[0]
          debug_inspect(!cov_v.h_merge, content="true")
          debug_inspect(cov_v.v_merge, content="true")
          let cov_hv = t.rows[1].cells[1]
          debug_inspect(cov_hv.h_merge, content="true")
          debug_inspect(cov_hv.v_merge, content="true")
        }
        _ => fail("expected TableContent")
      }
    _ => fail("expected GraphicFrame")
  }
}

// --- writer ---

///|
test "Slide::serialize: graphicFrame + table round-trips" {
  let bytes_in = slide_with_shapes_xml(simple_table_graphic_frame_xml())
  let s0 = @slide.Slide::parse(bytes_in)
  let s1 = @slide.Slide::parse(s0.serialize())
  debug_inspect(s0 == s1, content="true")
}

///|
test "Slide::serialize: chart graphicFrame round-trips via ChartContent" {
  // Confirms the chart rid survives parse → serialize → parse through
  // the typed `ChartContent(rid)` path.
  let chart_uri = "http://schemas.openxmlformats.org/drawingml/2006/chart"
  let body = "<p:graphicFrame>" +
    "<p:nvGraphicFramePr>" +
    "<p:cNvPr id=\"4\" name=\"Chart\"/><p:cNvGraphicFramePr/><p:nvPr/>" +
    "</p:nvGraphicFramePr>" +
    "<p:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></p:xfrm>" +
    "<a:graphic xmlns:c=\"" +
    chart_uri +
    "\"><a:graphicData uri=\"" +
    chart_uri +
    "\"><c:chart r:id=\"rId7\"/></a:graphicData></a:graphic>" +
    "</p:graphicFrame>"
  let bytes_in = slide_with_shapes_xml(body)
  let s0 = @slide.Slide::parse(bytes_in)
  let s1 = @slide.Slide::parse(s0.serialize())
  debug_inspect(s0 == s1, content="true")
}

///|
test "Slide::serialize: merged-cell flags round-trip" {
  let body = "<p:graphicFrame>" +
    "<p:nvGraphicFramePr>" +
    "<p:cNvPr id=\"3\" name=\"Merged\"/><p:cNvGraphicFramePr/><p:nvPr/>" +
    "</p:nvGraphicFramePr>" +
    "<p:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></p:xfrm>" +
    "<a:graphic><a:graphicData uri=\"" +
    table_uri +
    "\">" +
    "<a:tbl>" +
    "<a:tblGrid><a:gridCol w=\"100\"/><a:gridCol w=\"100\"/></a:tblGrid>" +
    "<a:tr h=\"50\">" +
    "<a:tc gridSpan=\"2\" rowSpan=\"2\"><a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody><a:tcPr/></a:tc>" +
    "<a:tc hMerge=\"1\"><a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody><a:tcPr/></a:tc>" +
    "</a:tr>" +
    "<a:tr h=\"50\">" +
    "<a:tc vMerge=\"1\"><a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody><a:tcPr/></a:tc>" +
    "<a:tc hMerge=\"1\" vMerge=\"1\"><a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody><a:tcPr/></a:tc>" +
    "</a:tr>" +
    "</a:tbl>" +
    "</a:graphicData></a:graphic>" +
    "</p:graphicFrame>"
  let bytes_in = slide_with_shapes_xml(body)
  let s0 = @slide.Slide::parse(bytes_in)
  let s1 = @slide.Slide::parse(s0.serialize())
  debug_inspect(s0 == s1, content="true")
}
