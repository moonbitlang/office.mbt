// Renderer tests: the full-document snapshot is the visual contract; the
// targeted tests pin bounds, escaping, merges, formulas, and objects.

///|
let tiny_png : Bytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
  0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00,
  0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78,
  0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]

///|
fn showcase_workbook() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Report"))
  workbook.set_cell("Report", "A1", "Quarterly Report")
  workbook.merge_cells("Report", "A1:B1")
  let header = workbook.new_style(
    @xlsx.Style::new()
    .with_font(@xlsx.Font::with_values(bold=true, color="FFFFFF"))
    .with_fill(@xlsx.Fill::solid("4472C4"))
    .with_alignment(@xlsx.Alignment::with_values(horizontal="center")),
  )
  workbook.set_cell_style("Report", "A1", header)
  workbook.set_cell("Report", "A2", "Region")
  workbook.set_cell("Report", "B2", "Sales")
  workbook.set_cell("Report", "A3", "East")
  workbook.set_cell_int("Report", "B3", 1200)
  workbook.set_cell_formula("Report", "B4", "SUM(B3:B3)")
  workbook.set_col_width("Report", 1, 16.0)
  workbook.set_row_height("Report", 1, 24.0)
  workbook.set_panes(
    "Report",
    @xlsx.Panes::with_values(freeze=true, y_split=2, top_left_cell="A3"),
  )
  let chart = @xlsx.ChartOptions::new(Col)
  chart.series.push(
    @xlsx.ChartSeries::new("Report!$A$3:$A$3", "Report!$B$3:$B$3", name="Sales"),
  )
  workbook.add_chart_with_options("Report", "D2", chart)
  workbook.add_image("Report", "D6", tiny_png, "png", "image/png")
  workbook
}

///|
test "full-document snapshot: styles, merge, widths, chart, image, freeze" {
  inspect(
    @xlsx2html.render_workbook(showcase_workbook(), title="report.xlsx"),
    content=(
      #|<!DOCTYPE html>
      #|<html>
      #|<head>
      #|<meta charset="utf-8">
      #|<title>report.xlsx</title>
      #|<style>
      #|body{font-family:Calibri,Arial,sans-serif;margin:16px}
      #|table{border-collapse:collapse;margin-bottom:8px}
      #|td{border:1px solid #d9d9d9;padding:2px 6px;white-space:pre;font-size:11pt}
      #|h2{font-size:13pt;margin:12px 0 4px}
      #|.formula-pending{color:#888;font-style:italic}
      #|.truncated,.frozen-hint{color:#888;font-size:9pt}
      #|.chart-placeholder{border:1px dashed #999;padding:8px;margin:4px 0;color:#555;font-size:10pt}
      #|figure{margin:4px 0}
      #|.s1{font-weight:bold;color:#FFFFFF;background-color:#4472C4;text-align:center;}
      #|</style>
      #|</head>
      #|<body>
      #|<h1>report.xlsx</h1>
      #|<section data-sheet="Report">
      #|<h2>Report</h2>
      #|<table>
      #|<colgroup>
      #|<col style="width:112px">
      #|<col>
      #|</colgroup>
      #|<tr style="height:32px"><td class="s1" colspan="2">Quarterly Report</td></tr>
      #|<tr><td>Region</td><td>Sales</td></tr>
      #|<tr><td>East</td><td>1200</td></tr>
      #|<tr><td></td><td class="formula-pending">=SUM(B3:B3)</td></tr>
      #|</table>
      #|<div class="sheet-objects">
      #|<figure class="image" data-anchor="D6"><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==" alt=""></figure>
      #|<figure class="chart-placeholder" data-anchor="D2">[barChart]<br>series: Report!$A$3:$A$3 → Report!$B$3:$B$3</figure>
      #|<p class="frozen-hint">frozen panes: 2 row(s), 0 column(s)</p>
      #|</div>
      #|</section>
      #|</body>
      #|</html>
      #|
    ),
  )
}

///|
test "hostile cell text and sheet names are escaped everywhere" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("<Bad> & \"Sheet\""))
  workbook.set_cell("<Bad> & \"Sheet\"", "A1", "<script>alert(1)</script>")
  let document = @xlsx2html.render_workbook(workbook, title="<t>&.xlsx")
  assert_true(!document.contains("<script>"))
  assert_true(document.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
  assert_true(document.contains("&lt;Bad&gt; &amp; \"Sheet\""))
  assert_true(
    document.contains("data-sheet=\"&lt;Bad&gt; &amp; &quot;Sheet&quot;\""),
  )
  assert_true(document.contains("<title>&lt;t&gt;&amp;.xlsx</title>"))
}

///|
test "a lone far cell renders bounded, with a truncation marker" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sparse"))
  workbook.set_cell("Sparse", "XFD1048576", "far")
  let document = @xlsx2html.render_workbook(
    workbook,
    title="sparse.xlsx",
    max_rows=5,
    max_cols=4,
  )
  assert_true(
    document.contains("showing 5 of 1048576 rows and 4 of 16384 columns"),
  )
  // The window keeps the document small even though the sheet extent is
  // the full grid.
  assert_true(document.length() < 8000)
  // With DEFAULT bounds the ceiling still applies: the marker names the
  // 1000x256 defaults and the document stays bounded.
  let defaults = @xlsx2html.render_workbook(workbook, title="sparse.xlsx")
  assert_true(
    defaults.contains("showing 1000 of 1048576 rows and 256 of 16384 columns"),
  )
  assert_true(defaults.length() < 4_000_000)
}

///|
test "row-inherited number formats render on the value" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  let priced = workbook.new_style(@xlsx.Style::number_format("0.00"))
  workbook.set_row_style("Data", 1, priced)
  workbook.set_cell_int("Data", "A1", 1)
  let document = @xlsx2html.render_workbook(workbook, title="fmt.xlsx")
  assert_true(document.contains("<td class=\"s\{priced}\">1.00</td>"))
}

///|
test "color-only borders (style zero) draw nothing" {
  let bordered = @xlsx.Style::new().with_border([
    @xlsx.Border::with_values("left", color="FF0000"),
  ])
  inspect(@xlsx2html.style_css(bordered), content="")
  let ruled = @xlsx.Style::new().with_border([
    @xlsx.Border::with_values("left", color="FF0000", style=1),
  ])
  inspect(@xlsx2html.style_css(ruled), content="border-left:1px solid #FF0000;")
}

///|
test "formulas: pending by default, evaluated with calc" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell_int("Data", "A1", 20)
  workbook.set_cell_formula("Data", "A2", "A1*2")
  let pending = @xlsx2html.render_workbook(workbook, title="f.xlsx")
  assert_true(pending.contains("<td class=\"formula-pending\">=A1*2</td>"))
  let calculated = @xlsx2html.render_workbook(
    workbook,
    title="f.xlsx",
    calc=true,
  )
  assert_true(calculated.contains("<td>40</td>"))
}

///|
test "merged anchor spans and covered cells are skipped" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("M"))
  workbook.set_cell("M", "A1", "wide")
  workbook.merge_cells("M", "A1:C2")
  workbook.set_cell("M", "D1", "right")
  let document = @xlsx2html.render_workbook(workbook, title="m.xlsx")
  assert_true(document.contains("colspan=\"3\""))
  assert_true(document.contains("rowspan=\"2\""))
  // 1 anchor + 1 plain cell on row 1, no covered cells emitted there:
  // count td occurrences on the first body row by a crude split.
  let first_row = document.split("<tr>").collect()[1].to_string()
  let mut tds = 0
  for i in 0..<(first_row.length() - 3) {
    if first_row[i] == '<' && first_row[i + 1] == 't' && first_row[i + 2] == 'd' {
      tds += 1
    }
  }
  inspect(tds, content="2")
}

///|
test "no-images drops figures; chart sheets render placeholder sections" {
  let workbook = showcase_workbook()
  let bare = @xlsx2html.render_workbook(
    workbook,
    title="r.xlsx",
    include_images=false,
  )
  assert_true(!bare.contains("data:image/png"))
  assert_true(bare.contains("chart-placeholder"))
  let charted = @xlsx.Workbook::new()
  ignore(charted.add_sheet("Data"))
  charted.set_cell_int("Data", "A1", 1)
  let chart = @xlsx.ChartOptions::new(Line)
  chart.series.push(@xlsx.ChartSeries::new("Data!$A$1:$A$1", "Data!$A$1:$A$1"))
  ignore(charted.add_chart_sheet_with_options("Trend", chart))
  let document = @xlsx2html.render_workbook(charted, title="c.xlsx")
  assert_true(document.contains("data-sheet=\"Trend\""))
  assert_true(document.contains("[lineChart]"))
}

///|
test "sheet selection is case-insensitive; missing sheets fail typed" {
  let workbook = showcase_workbook()
  let one = @xlsx2html.render_workbook(workbook, title="r.xlsx", sheet="report")
  assert_true(one.contains("data-sheet=\"Report\""))
  try
    ignore(@xlsx2html.render_workbook(workbook, title="r.xlsx", sheet="Nope"))
  catch {
    err => inspect(err, content="sheet 'Nope' not found")
  } noraise {
    _ => fail("expected a missing-sheet error")
  }
}
