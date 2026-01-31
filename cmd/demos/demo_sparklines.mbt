///|
pub fn demo_sparklines_bytes() -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  let sheet = workbook.add_sheet("KPI")
  sheet.set_col_width(1, 18.0)
  for c in 2..<=13 {
    sheet.set_col_width(c, 8.0)
  }
  sheet.set_col_width(14, 16.0)
  sheet.set_row(1, [
    "Team", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct",
    "Nov", "Dec", "Trend",
  ])
  let teams = ["Alpha", "Beta", "Gamma", "Delta"]
  let data = [
    [3, 4, 3, 5, 6, 7, 8, 7, 7, 8, 9, 10],
    [6, 5, 6, 6, 5, 4, 5, 5, 6, 7, 6, 6],
    [2, 2, 3, 2, 3, 2, 4, 5, 4, 4, 5, 6],
    [8, 7, 8, 9, 8, 9, 10, 10, 9, 8, 9, 11],
  ]
  for i in 0..<teams.length() {
    let r = i + 2
    sheet.set_cell("A\{r}", teams[i])
    for j in 0..<12 {
      let c = j + 2
      sheet.set_cell_rc(r, c, "\{data[i][j]}")
    }
    sheet.set_cell("N\{r}", "")
  }
  let locations = ["N2", "N3", "N4", "N5"]
  let ranges = ["B2:M2", "B3:M3", "B4:M4", "B5:M5"]
  let opts = @xlsx.SparklineOptions::new(locations, ranges)
  opts.set_type(Line)
  opts.set_markers(true)
  opts.set_high(true)
  opts.set_low(true)
  opts.set_style(8)
  opts.set_series_color("1F4E79")
  opts.set_markers_color("C00000")
  sheet.add_sparkline_options(opts)
  @excel.write(workbook)
}
