///|
pub fn demo_tracker_heatmap_bytes() -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  let sheet = workbook.add_sheet("Tracker")
  sheet.set_col_width(1, 10.0)
  for c in 2..<=32 {
    sheet.set_col_width(c, 3.2)
  }
  sheet.set_col_width(33, 12.0)

  // Header row: day numbers 1..31.
  sheet.set_cell("A1", "Month")
  for d in 1..<=31 {
    sheet.set_cell_rc(1, d + 1, "\{d}")
  }
  sheet.set_cell("AG1", "Trend")

  // 12 months x 31 days of scores (0..10). 0 means “missed”, 10 means “nailed it”.
  let months : ReadOnlyArray[String] = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]

  // A deterministic pseudo pattern (no randomness, stable diffs):
  // score = (month_index*7 + day*3) % 11
  for m in 0..<months.length() {
    let r = m + 2
    sheet.set_cell_rc(r, 1, months[m])
    for d in 1..<=31 {
      let score = (m * 7 + d * 3) % 11
      sheet.set_cell_rc(r, d + 1, "\{score}")
    }
    sheet.set_cell_rc(r, 33, "")
  }

  // Heatmap: color scale over the full grid.
  let heat = @xlsx.ConditionalFormatOptions::new("3_color_scale")
  heat.set_min_type("num")
  heat.set_mid_type("num")
  heat.set_max_type("num")
  heat.set_min_value("0")
  heat.set_mid_value("5")
  heat.set_max_value("10")
  heat.set_min_color("F8696B")
  heat.set_mid_color("FFEB84")
  heat.set_max_color("63BE7B")
  sheet.set_conditional_format("B2:AF13", [heat])

  // Trend sparklines: 1 per month.
  let locations : Array[String] = []
  let ranges : Array[String] = []
  for r in 2..<=13 {
    locations.push("AG\{r}")
    ranges.push("B\{r}:AF\{r}")
  }
  let spark = @xlsx.SparklineOptions::new(locations, ranges)
  spark.set_type(Line)
  spark.set_markers(true)
  spark.set_style(8)
  sheet.add_sparkline_options(spark)

  // Make the sheet comfortable to scroll.
  sheet.set_panes(
    @xlsx.Panes::with_values(
      freeze=true,
      x_split=1,
      y_split=1,
      top_left_cell="B2",
      active_pane="bottomRight",
      selection=[
        @xlsx.Selection::with_values(
          sqref="B2",
          active_cell="B2",
          pane="bottomRight",
        ),
      ],
    ),
  )
  @excel.write(workbook)
}
