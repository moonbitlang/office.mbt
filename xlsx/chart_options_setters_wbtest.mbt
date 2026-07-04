///|
test "chart options: setter coverage and basic validation" {
  let bad_dim : Result[ChartDimension, Error] = Ok(
    ChartDimension::with_values(0, 1),
  ) catch {
    e => Err(e)
  }
  inspect(bad_dim is Err(XlsxError::InvalidSheetOperation(_)), content="true")
  let bad_series : Result[ChartSeries, Error] = Ok(
    ChartSeries::new("", "Sheet1!$A$1:$A$2"),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_series is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let series = ChartSeries::new(
    "Sheet1!$A$1:$A$2",
    "Sheet1!$B$1:$B$2",
    name="S1",
  )
  let bad_bubble : Result[Unit, Error] = Ok(series.set_bubble_size("")) catch {
    e => Err(e)
  }
  inspect(
    bad_bubble is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  series.set_bubble_size("Sheet1!$C$1:$C$2")
  inspect(series.sizes, content="Sheet1!$C$1:$C$2")
  inspect(series.legend.position, content="bottom")
  let opts = ChartOptions::new(Scatter)
  opts.series.push(series)
  opts.format = GraphicOptions::new()
  opts.dimension = ChartDimension::with_values(320, 240)
  opts.legend = ChartLegend::new(position="top", show_legend_key=true)
  opts.title = "T"
  opts.vary_colors = false
  let x_axis = ChartAxis::new()
  x_axis.major_grid_lines = true
  x_axis.tick_label_position = Low
  x_axis.title = "X"
  opts.x_axis = x_axis
  let y_axis = ChartAxis::new()
  y_axis.minor_grid_lines = true
  y_axis.reverse_order = true
  y_axis.title = "Y"
  opts.y_axis = y_axis
  let plot = ChartPlotArea::new()
  plot.show_val = true
  plot.show_cat_name = true
  plot.show_percent = true
  opts.plot_area = plot
  opts.show_blanks_as = "span"
  opts.gap_width = Some(150)
  opts.overlap = Some(25)
  let xml = chart_options_to_xml(opts)
  inspect(xml.contains("scatterChart"), content="true")
  inspect(xml.contains("<c:title>"), content="true")
}
