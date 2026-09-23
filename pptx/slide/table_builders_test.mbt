// Modified for office.mbt: follow the workspace warning conventions.
// Table builder tests.

///|
test "TableCell::of_text: carries text + default span / merge" {
  let c = @slide.TableCell::of_text("Hello")
  debug_inspect(c.text_body.unwrap().plain_text(), content="\"Hello\"")
  debug_inspect(c.grid_span, content="1")
  debug_inspect(c.row_span, content="1")
  debug_inspect(!c.h_merge, content="true")
  debug_inspect(!c.v_merge, content="true")
  // Synthesises an empty <a:tcPr/>.
  debug_inspect(c.properties is Some(_), content="true")
}

///|
test "TableCell::merged_origin: spans columns and rows" {
  let c = @slide.TableCell::merged_origin("Joined", grid_span=3, row_span=2)
  debug_inspect(c.grid_span, content="3")
  debug_inspect(c.row_span, content="2")
  // The origin cell itself is NOT covered — only the cells it
  // spans into are.
  debug_inspect(!c.h_merge, content="true")
  debug_inspect(!c.v_merge, content="true")
}

///|
test "TableCell::*_merge_covered: carry the right flags" {
  let h = @slide.TableCell::h_merge_covered()
  debug_inspect(h.h_merge, content="true")
  debug_inspect(!h.v_merge, content="true")
  let v = @slide.TableCell::v_merge_covered()
  debug_inspect(!v.h_merge, content="true")
  debug_inspect(v.v_merge, content="true")
  let hv = @slide.TableCell::hv_merge_covered()
  debug_inspect(hv.h_merge, content="true")
  debug_inspect(hv.v_merge, content="true")
}

///|
test "Table::of_grid: produces correctly-sized empty grid" {
  let t = @slide.Table::of_grid(
    rows=3,
    cols=4,
    col_width=Emu(914400L),
    row_height=Emu(457200L),
  )
  debug_inspect(t.grid.length(), content="4")
  debug_inspect(t.rows.length(), content="3")
  for row in t.rows {
    debug_inspect(row.cells.length(), content="4")
    debug_inspect(row.height, content="Emu(457200)")
  }
  // Each column gets the requested width.
  for col_w in t.grid {
    debug_inspect(col_w, content="Emu(914400)")
  }
}

///|
test "Table::of_rows: custom cell mix" {
  let row0 = @slide.TableRow::of_cells(
    [@slide.TableCell::of_text("A1"), @slide.TableCell::of_text("B1")],
    height=Emu(457200L),
  )
  let row1 = @slide.TableRow::of_cells(
    [
      @slide.TableCell::merged_origin("A2-merged", grid_span=2),
      @slide.TableCell::h_merge_covered(),
    ],
    height=Emu(457200L),
  )
  let t = @slide.Table::of_rows([row0, row1], col_widths=[
    Emu(914400L),
    Emu(914400L),
  ])
  debug_inspect(t.rows.length(), content="2")
  debug_inspect(t.rows[1].cells[0].grid_span, content="2")
  debug_inspect(t.rows[1].cells[1].h_merge, content="true")
}

///|
test "GraphicFrame::of_table: id / name / transform / content" {
  let t = @slide.Table::of_grid(
    rows=1,
    cols=1,
    col_width=Emu(914400L),
    row_height=Emu(457200L),
  )
  let gf = @slide.GraphicFrame::of_table(
    id=42,
    name="Grid 1",
    x=Emu(100L),
    y=Emu(200L),
    cx=Emu(300L),
    cy=Emu(400L),
    t,
  )
  debug_inspect(gf.id, content="42")
  debug_inspect(gf.name, content="\"Grid 1\"")
  let xfrm = gf.transform.unwrap()
  debug_inspect(xfrm.offset.x, content="Emu(100)")
  debug_inspect(xfrm.extent.cy, content="Emu(400)")
  match gf.content {
    TableContent(_) => ()
    _ => fail("expected TableContent")
  }
}

///|
test "GraphicFrame::of_table: round-trips via Slide::serialize" {
  // Build a slide → add a table-bearing graphicFrame → serialise →
  // reparse. The structural-equivalence floor matches what the
  // AutoShape builder test asserts (first round-trip adds captured
  // wrappers).
  let base_xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let base = @slide.Slide::parse(@oxml.string_to_bytes(base_xml))
  let t = @slide.Table::of_grid(
    rows=2,
    cols=2,
    col_width=Emu(914400L),
    row_height=Emu(457200L),
  )
  let gf = @slide.GraphicFrame::of_table(
    id=7,
    name="Table 1",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(1828800L),
    cy=Emu(914400L),
    t,
  )
  let s = base.with_shape(GraphicFrame(gf))
  let s_reparsed = @slide.Slide::parse(s.serialize())
  debug_inspect(s_reparsed.shapes.length(), content="1")
  match s_reparsed.shapes[0] {
    GraphicFrame(parsed_gf) => {
      debug_inspect(parsed_gf.id, content="7")
      debug_inspect(parsed_gf.name, content="\"Table 1\"")
      match parsed_gf.content {
        TableContent(parsed_t) => {
          debug_inspect(parsed_t.grid.length(), content="2")
          debug_inspect(parsed_t.rows.length(), content="2")
        }
        _ => fail("expected TableContent")
      }
    }
    _ => fail("expected GraphicFrame")
  }
}

///|
test "GraphicFrame::of_table: second round-trip is Eq-stable" {
  let t = @slide.Table::of_grid(
    rows=2,
    cols=2,
    col_width=Emu(914400L),
    row_height=Emu(457200L),
  )
  let gf = @slide.GraphicFrame::of_table(
    id=7,
    name="Tbl",
    x=Emu(0L),
    y=Emu(0L),
    cx=Emu(914400L),
    cy=Emu(914400L),
    t,
  )
  let base_xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let base = @slide.Slide::parse(@oxml.string_to_bytes(base_xml))
  let s1 = @slide.Slide::parse(base.with_shape(GraphicFrame(gf)).serialize())
  let s2 = @slide.Slide::parse(s1.serialize())
  debug_inspect(s1 == s2, content="true")
}
