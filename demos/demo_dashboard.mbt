///|
fn dashboard_styles(workbook : @xlsx.Workbook) -> (Int, Int, Int) {
  let header_font = @xlsx.Font::with_values(
    bold=true,
    size=12.0,
    color="FFFFFF",
    family="Calibri",
  )
  let header_style = @xlsx.Style::new()
  let header_style = @xlsx.Style::with_font(header_style, header_font)
  let header_style = @xlsx.Style::with_fill(
    header_style,
    @xlsx.Fill::solid("4472C4"),
  )
  let header_style = @xlsx.Style::with_alignment(
    header_style,
    @xlsx.Alignment::with_values(horizontal="center", vertical="center"),
  )
  let money_style = @xlsx.Style::number_format("$#,##0")
  let title_font = @xlsx.Font::with_values(
    bold=true,
    size=20.0,
    color="1F4E79",
    family="Calibri",
  )
  let title_style = @xlsx.Style::new()
  let title_style = @xlsx.Style::with_font(title_style, title_font)
  (
    workbook.new_style(header_style),
    workbook.new_style(money_style),
    workbook.new_style(title_style),
  )
}

///|
pub fn demo_dashboard_bytes() -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  let data = workbook.add_sheet("Data")
  let dash = workbook.add_sheet("Dashboard")
  let (header_style_id, money_style_id, title_style_id) = dashboard_styles(
    workbook,
  )
  data.set_panes(
    @xlsx.Panes::with_values(
      freeze=true,
      y_split=1,
      top_left_cell="A2",
      active_pane="bottomLeft",
      selection=[
        @xlsx.Selection::with_values(
          sqref="A2",
          active_cell="A2",
          pane="bottomLeft",
        ),
      ],
    ),
  )
  data.set_col_width(1, 14.0)
  data.set_col_width(2, 12.0)
  data.set_col_width(3, 12.0)
  data.set_col_width(4, 12.0)
  data.set_col_width(5, 14.0)
  data.set_row(1, ["Month", "North", "South", "West", "Total"])
  data.set_row_style(1, header_style_id)
  let months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  let north = [12, 15, 11, 18, 22, 24, 20, 21, 19, 25, 27, 30]
  let south = [9, 10, 8, 11, 13, 14, 13, 15, 16, 18, 19, 21]
  let west = [7, 6, 9, 10, 11, 12, 10, 11, 12, 13, 14, 16]
  for i in 0..<months.length() {
    let row = i + 2
    let sum = north[i] + south[i] + west[i]
    data.set_cell("A\{row}", months[i])
    data.set_cell("B\{row}", "\{north[i]}")
    data.set_cell("C\{row}", "\{south[i]}")
    data.set_cell("D\{row}", "\{west[i]}")
    data.set_cell_formula("E\{row}", "SUM(B\{row}:D\{row})", value="\{sum}")
    data.set_cell_style("B\{row}", money_style_id)
    data.set_cell_style("C\{row}", money_style_id)
    data.set_cell_style("D\{row}", money_style_id)
    data.set_cell_style("E\{row}", money_style_id)
  }
  ignore(
    data.add_table(
      "A1:E13",
      "SalesTable",
      ["Month", "North", "South", "West", "Total"],
      style_name="TableStyleMedium9",
      show_row_stripes=true,
    ),
  )
  let total_scale = @xlsx.ConditionalFormatOptions::new("3_color_scale")
  total_scale.set_min_type("min")
  total_scale.set_mid_type("percentile")
  total_scale.set_max_type("max")
  total_scale.set_mid_value("50")
  total_scale.set_min_color("F8696B")
  total_scale.set_mid_color("FFEB84")
  total_scale.set_max_color("63BE7B")
  data.set_conditional_format("E2:E13", [total_scale])
  dash.set_col_width(1, 4.0)
  dash.set_col_width(2, 18.0)
  dash.set_col_width(3, 18.0)
  dash.set_col_width(4, 18.0)
  dash.set_row_height(1, 32.0)
  dash.set_cell("B1", "Sales Dashboard")
  dash.set_cell_style("B1", title_style_id)
  dash.merge_cells("B1:D1")
  workbook.add_image(
    "Dashboard",
    "A1",
    demo_logo_png,
    "png",
    "image/png",
    scale_x=16.0,
    scale_y=16.0,
    name="Logo",
    alt_text="mbtexcel demo logo",
    lock_aspect_ratio=true,
  )
  workbook.add_shape(
    "Dashboard",
    @xlsx.Shape::new(
      "B3",
      "rect",
      text="Tip: Edit numbers in Data!B2:D13 and watch the chart update.",
      width=520,
      height=30,
      fill_color="FFF2CC",
      fill_transparency=0,
      line_color="D6B656",
      line_width=1.0,
      positioning=TwoCell,
    ),
  )
  let chart = @xlsx.ChartOptions::new(Line)
  chart.title = "Total by Month"
  chart.series.push(
    @xlsx.ChartSeries::new(
      "Data!$A$2:$A$13",
      "Data!$E$2:$E$13",
      name="Data!$E$1",
    ),
  )
  chart.format = @xlsx.GraphicOptions::with_values(offset_x=0, offset_y=0)
  workbook.add_chart_with_options("Dashboard", "B5", chart)
  @excel.write(workbook)
}
