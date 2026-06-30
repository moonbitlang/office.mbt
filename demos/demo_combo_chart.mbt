///|
pub fn demo_combo_chart_bytes() -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  let sheet = workbook.add_sheet("Metrics")
  sheet.set_col_width(1, 14.0)
  sheet.set_col_width(2, 14.0)
  sheet.set_col_width(3, 14.0)
  sheet.set_col_width(4, 14.0)
  sheet.set_row(1, ["Month", "New MRR", "Churn %", "Active Users"])
  let months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  let new_mrr = [12, 18, 22, 24, 30, 28, 34, 40, 38, 45, 52, 60]
  let churn = [6.2, 5.5, 5.0, 4.8, 4.4, 4.6, 4.2, 3.9, 3.8, 3.6, 3.4, 3.1]
  let users = [
    1200, 1350, 1500, 1650, 1900, 2100, 2350, 2600, 2750, 3000, 3300, 3600,
  ]
  for i in 0..<months.length() {
    let r = i + 2
    sheet.set_cell("A\{r}", months[i])
    sheet.set_cell("B\{r}", "\{new_mrr[i]}")
    sheet.set_cell("C\{r}", "\{churn[i]}")
    sheet.set_cell("D\{r}", "\{users[i]}")
  }

  // Light formatting: currency + percent.
  let mrr_style = workbook.new_style(@xlsx.Style::number_format("$#,##0"))
  let pct_style = workbook.new_style(@xlsx.Style::number_format("0.0%"))
  let users_style = workbook.new_style(@xlsx.Style::number_format("#,##0"))
  for r in 2..<=13 {
    sheet.set_cell_style("B\{r}", mrr_style)
    sheet.set_cell_style("C\{r}", pct_style)
    sheet.set_cell_style("D\{r}", users_style)
  }

  // Build a combo chart:
  // - Column for New MRR (left axis)
  // - Line for Churn% (right axis)
  // - Area for Active Users (left axis, lightly styled)
  let col = @xlsx.ChartOptions::new(Col)
  col.title = "SaaS Metrics (Combo Chart)"
  col.series.push(
    @xlsx.ChartSeries::new(
      "Metrics!$A$2:$A$13",
      "Metrics!$B$2:$B$13",
      name="Metrics!$B$1",
    ),
  )
  col.y_axis.title = "MRR ($)"
  col.x_axis.title = "Month"
  let line = @xlsx.ChartOptions::new(Line)
  line.series.push(
    @xlsx.ChartSeries::new(
      "Metrics!$A$2:$A$13",
      "Metrics!$C$2:$C$13",
      name="Metrics!$C$1",
    ),
  )
  line.y_axis.secondary = true
  line.y_axis.title = "Churn (%)"
  line.y_axis.num_fmt = @xlsx.ChartNumFmt::new(
    custom_num_fmt="0.0%",
    source_linked=false,
  )
  line.plot_area.show_val = true
  line.series[0].line.color = "C00000"
  line.series[0].marker.symbol = "circle"
  line.series[0].marker.size = 6
  line.series[0].marker.fill_color = "C00000"
  line.series[0].marker.border.color = "C00000"
  col.add_combo_chart(line)
  let area = @xlsx.ChartOptions::new(Area)
  area.series.push(
    @xlsx.ChartSeries::new(
      "Metrics!$A$2:$A$13",
      "Metrics!$D$2:$D$13",
      name="Metrics!$D$1",
    ),
  )
  area.series[0].fill_color = "9DC3E6"
  area.series[0].fill_transparency = 60
  col.add_combo_chart(area)

  // Place the chart on a "dashboard-like" spot.
  col.format = @xlsx.GraphicOptions::with_values(positioning=TwoCell)
  workbook.add_chart_with_options("Metrics", "F2", col)
  @excel.write(workbook)
}
