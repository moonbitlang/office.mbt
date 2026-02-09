///|
fn wb_series(name? : String = "Series1") -> ChartSeries {
  try! ChartSeries::new("Sheet1!$A$2:$A$4", "Sheet1!$B$2:$B$4", name~)
}

///|
fn wb_rich_font(
  italic? : Bool = false,
  strike? : Bool = false,
  underline? : String? = None,
  size? : Double? = None,
  color? : String? = None,
  family? : String? = None,
) -> RichTextFont {
  {
    bold: false,
    italic,
    strike,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline,
    size,
    color,
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family,
  }
}

///|
test "chart options wb: helper mappings" {
  inspect(
    chart_type_to_plot(ColPercentStacked),
    content="(\"barChart\", Some(\"col\"))",
  )
  inspect(
    chart_type_to_plot(BarStacked),
    content="(\"barChart\", Some(\"bar\"))",
  )
  inspect(
    chart_type_to_plot(BarPercentStacked),
    content="(\"barChart\", Some(\"bar\"))",
  )
  inspect(
    chart_type_to_plot(Bar3DCylinderPercentStacked),
    content="(\"bar3DChart\", Some(\"bar\"))",
  )
  inspect(chart_type_to_plot(AreaStacked), content="(\"areaChart\", None)")
  inspect(
    chart_type_to_plot(AreaPercentStacked),
    content="(\"areaChart\", None)",
  )
  inspect(chart_type_to_plot(Area3D), content="(\"area3DChart\", None)")
  inspect(chart_type_to_plot(Area3DStacked), content="(\"area3DChart\", None)")
  inspect(
    chart_type_to_plot(Area3DPercentStacked),
    content="(\"area3DChart\", None)",
  )

  inspect(chart_grouping(Col3D), content="Some(\"standard\")")
  inspect(
    chart_grouping(Bar3DCylinderPercentStacked),
    content="Some(\"percentStacked\")",
  )
  inspect(chart_grouping(Pie), content="None")

  inspect(legend_position_value("left"), content="Some(\"l\")")
  inspect(legend_position_value("top-right"), content="Some(\"tr\")")
  inspect(legend_position_value("custom"), content="Some(\"custom\")")

  inspect(chart_shape(Col3DPyramidPercentStacked), content="Some(\"pyramid\")")
  inspect(
    chart_shape(Col3DCylinderPercentStacked),
    content="Some(\"cylinder\")",
  )

  inspect(chart_dash_value(Solid), content="Some(\"solid\")")
  inspect(chart_dash_value(LgDash), content="Some(\"lgDash\")")
  inspect(chart_dash_value(LgDashDot), content="Some(\"lgDashDot\")")
  inspect(chart_dash_value(SashDot), content="Some(\"dashDot\")")
  inspect(chart_dash_value(LgDashDotDot), content="Some(\"lgDashDotDot\")")
  inspect(chart_dash_value(SysDash), content="Some(\"sysDash\")")
  inspect(chart_dash_value(SysDot), content="Some(\"sysDot\")")
  inspect(chart_dash_value(SysDashDot), content="Some(\"sysDashDot\")")
  inspect(chart_dash_value(SysDashDotDot), content="Some(\"sysDashDotDot\")")

  inspect(data_label_pos_value(Center), content="ctr")
  inspect(data_label_pos_value(Left), content="l")
  inspect(data_label_pos_value(Right), content="r")
  inspect(data_label_pos_value(Bottom), content="b")
  inspect(data_label_pos_value(BestFit), content="bestFit")
  inspect(data_label_pos_value(InEnd), content="inEnd")
  inspect(data_label_pos_value(OutEnd), content="outEnd")
  inspect(tick_label_pos_value(NoTickLabels), content="none")

  inspect(drawingml_text_vertical_value("horz"), content="Some(\"horz\")")
  inspect(drawingml_text_vertical_value("vert"), content="Some(\"vert\")")
  inspect(
    drawingml_text_vertical_value("wordArtVert"),
    content="Some(\"wordArtVert\")",
  )
  inspect(drawingml_text_vertical_value("eaVert"), content="Some(\"eaVert\")")
  inspect(
    drawingml_text_vertical_value("mongolianVert"),
    content="Some(\"mongolianVert\")",
  )
  inspect(
    drawingml_text_vertical_value("wordArtVertRtl"),
    content="Some(\"wordArtVertRtl\")",
  )
  inspect(drawingml_paragraph_align_value("left"), content="Some(\"l\")")
  inspect(drawingml_paragraph_align_value("right"), content="Some(\"r\")")
  inspect(drawingml_paragraph_align_value("justify"), content="Some(\"just\")")
  inspect(
    drawingml_paragraph_align_value("distributed"),
    content="Some(\"dist\")",
  )
  inspect(
    drawingml_paragraph_align_value("centerContinuous"),
    content="Some(\"ctr\")",
  )
  inspect(drawingml_paragraph_align_value("unknown"), content="None")
  inspect(drawingml_underline_value("none"), content="Some(\"none\")")
  inspect(drawingml_underline_value("words"), content="Some(\"words\")")
  inspect(drawingml_underline_value("dbl"), content="Some(\"dbl\")")
  inspect(drawingml_underline_value("heavy"), content="Some(\"heavy\")")
  inspect(drawingml_underline_value("dotted"), content="Some(\"dotted\")")
  inspect(
    drawingml_underline_value("dottedHeavy"),
    content="Some(\"dottedHeavy\")",
  )
  inspect(drawingml_underline_value("dash"), content="Some(\"dash\")")
  inspect(drawingml_underline_value("dashHeavy"), content="Some(\"dashHeavy\")")
  inspect(drawingml_underline_value("dashLong"), content="Some(\"dashLong\")")
  inspect(
    drawingml_underline_value("dashLongHeavy"),
    content="Some(\"dashLongHeavy\")",
  )
  inspect(drawingml_underline_value("dotDash"), content="Some(\"dotDash\")")
  inspect(
    drawingml_underline_value("dotDashHeavy"),
    content="Some(\"dotDashHeavy\")",
  )
  inspect(
    drawingml_underline_value("dotDotDash"),
    content="Some(\"dotDotDash\")",
  )
  inspect(
    drawingml_underline_value("dotDotDashHeavy"),
    content="Some(\"dotDotDashHeavy\")",
  )
  inspect(drawingml_underline_value("wavy"), content="Some(\"wavy\")")
  inspect(drawingml_underline_value("wavyHeavy"), content="Some(\"wavyHeavy\")")
  inspect(drawingml_underline_value("wavyDbl"), content="Some(\"wavyDbl\")")
}

///|
test "chart options wb: rich text and title writers" {
  let sb = StringBuilder::new()
  write_drawingml_r_pr(sb, "  ", Some(wb_rich_font(italic=true, strike=true)))
  let xml = sb.to_string()
  inspect(xml.contains(" i=\"1\""), content="true")
  inspect(xml.contains("strike=\"sngStrike\""), content="true")
  inspect(xml.contains(" u=\""), content="false")

  let sb_none = StringBuilder::new()
  write_drawingml_r_pr(sb_none, "  ", None)
  inspect(
    sb_none.to_string().contains("<a:rPr lang=\"en-US\"/>"),
    content="true",
  )

  let title_empty_runs = StringBuilder::new()
  write_chart_title(title_empty_runs, "", Some([]))
  inspect(title_empty_runs.to_string(), content="")

  let axis_title_empty_runs = StringBuilder::new()
  write_axis_title(axis_title_empty_runs, "", Some([]))
  inspect(axis_title_empty_runs.to_string(), content="")

  let def_none_sb = StringBuilder::new()
  write_drawingml_def_r_pr_from_font(def_none_sb, "", Font::new())
  inspect(def_none_sb.to_string().contains("<a:defRPr>"), content="true")

  let def_some_sb = StringBuilder::new()
  let decorated_font = Font::with_values(
    italic=true,
    strike=true,
    underline="invalid",
  )
  write_drawingml_def_r_pr_from_font(def_some_sb, "", decorated_font)
  inspect(def_some_sb.to_string().contains(" i=\"1\""), content="true")
  inspect(
    def_some_sb.to_string().contains("strike=\"sngStrike\""),
    content="true",
  )
  inspect(def_some_sb.to_string().contains(" u=\""), content="false")

  let tx_pr_align_sb = StringBuilder::new()
  let tx_alignment = Alignment::with_values(vertical="vert")
  write_drawingml_tx_pr_with_font_and_alignment(
    tx_pr_align_sb,
    "  ",
    Font::new(),
    tx_alignment,
  )
  inspect(tx_pr_align_sb.to_string().contains("vert=\"vert\""), content="true")

  let tx_pr_align_unknown_sb = StringBuilder::new()
  let tx_alignment_unknown = Alignment::with_values(vertical="unknown")
  write_drawingml_tx_pr_with_font_and_alignment(
    tx_pr_align_unknown_sb,
    "  ",
    Font::new(),
    tx_alignment_unknown,
  )
  inspect(
    tx_pr_align_unknown_sb.to_string().contains(" vert=\""),
    content="false",
  )
}

///|
test "chart options wb: series shape and data label writers" {
  let sppr_no_line = wb_series(name="NoLine")
  sppr_no_line.fill_color = "#112233"
  sppr_no_line.fill_transparency = -1
  sppr_no_line.line.typ = NoLine
  let no_line_sb = StringBuilder::new()
  write_chart_series_sppr(no_line_sb, sppr_no_line)
  inspect(no_line_sb.to_string().contains("<a:noFill/>"), content="true")
  inspect(no_line_sb.to_string().contains("<a:alpha"), content="false")

  let sppr_line = wb_series(name="Line")
  sppr_line.line.color = "#445566"
  sppr_line.line.transparency = 200
  sppr_line.line.dash = Dot
  let line_sb = StringBuilder::new()
  write_chart_series_sppr(line_sb, sppr_line)
  inspect(line_sb.to_string().contains("alpha val=\"0\""), content="true")
  inspect(line_sb.to_string().contains("prstDash val=\"dot\""), content="true")

  let marker_no_line = ChartMarker::new(symbol="square", size=6)
  marker_no_line.fill_color = "#112233"
  marker_no_line.fill_transparency = -1
  marker_no_line.border.typ = NoLine
  let marker_no_line_sb = StringBuilder::new()
  write_chart_series_marker(marker_no_line_sb, marker_no_line)
  inspect(marker_no_line_sb.to_string().contains("<a:noFill/>"), content="true")
  inspect(marker_no_line_sb.to_string().contains("<a:alpha"), content="false")

  let marker_open_ln = ChartMarker::new(symbol="triangle", size=5)
  marker_open_ln.border.typ = Solid
  marker_open_ln.border.width = 1.0
  let marker_open_ln_sb = StringBuilder::new()
  write_chart_series_marker(marker_open_ln_sb, marker_open_ln)
  inspect(
    marker_open_ln_sb.to_string().contains("<a:ln w=\"12700\"/>"),
    content="true",
  )

  let marker_color_ln = ChartMarker::new(symbol="diamond", size=4)
  marker_color_ln.border.typ = Solid
  marker_color_ln.border.color = "#778899"
  marker_color_ln.border.transparency = 200
  let marker_color_ln_sb = StringBuilder::new()
  write_chart_series_marker(marker_color_ln_sb, marker_color_ln)
  inspect(
    marker_color_ln_sb
    .to_string()
    .contains("<a:solidFill><a:srgbClr val=\"778899\"><a:alpha val=\"0\"/>"),
    content="true",
  )

  let dlbl_series = wb_series(name="DataLabel")
  dlbl_series.data_label.fill_color = "#AABBCC"
  dlbl_series.data_label.fill_transparency = -1
  let dlbl_sb = StringBuilder::new()
  write_chart_series_dlbls(dlbl_sb, dlbl_series)
  inspect(
    dlbl_sb.to_string().contains("<a:srgbClr val=\"AABBCC\"/>"),
    content="true",
  )
  inspect(dlbl_sb.to_string().contains("<a:alpha"), content="false")

  let dpt_empty_sb = StringBuilder::new()
  write_chart_series_dpt(dpt_empty_sb, ChartDataPoint::new(0))
  inspect(dpt_empty_sb.to_string(), content="")

  let scatter = wb_series(name="Scatter")
  scatter.line.smooth = true
  scatter.data_point.push(ChartDataPoint::new(0, fill_color="#00FF00"))
  let scatter_sb = StringBuilder::new()
  write_chart_series_for_plot(scatter_sb, "scatterChart", scatter, 0, 0)
  inspect(
    scatter_sb.to_string().contains("<c:smooth val=\"1\"/>"),
    content="true",
  )
  inspect(scatter_sb.to_string().contains("<c:dPt>"), content="true")

  let bubble = wb_series(name="Bubble")
  bubble.line.smooth = true
  bubble.data_point.push(ChartDataPoint::new(1, fill_color="#FF0000"))
  try! bubble.set_bubble_size("Sheet1!$C$2:$C$4")
  let bubble_sb = StringBuilder::new()
  write_chart_series_for_plot(bubble_sb, "bubbleChart", bubble, 0, 0)
  inspect(
    bubble_sb.to_string().contains("<c:smooth val=\"1\"/>"),
    content="true",
  )
  inspect(bubble_sb.to_string().contains("<c:bubbleSize>"), content="true")
}

///|
test "chart options wb: axis and plot area writer branches" {
  let axis = ChartAxis::new()
  axis.ax_id = 7
  axis.log_base = 10.0
  axis.maximum = Some(99.0)
  axis.minimum = Some(1.0)
  axis.tick_label_skip = 2
  axis.alignment = Alignment::with_values(vertical="unknown")
  inspect(axis_id_or_default(axis, 1), content="7")

  let cat_axis_sb = StringBuilder::new()
  write_axis(cat_axis_sb, "catAx", axis, 7, 8, "b", Col)
  inspect(
    cat_axis_sb.to_string().contains("<c:logBase val=\"10"),
    content="true",
  )
  inspect(cat_axis_sb.to_string().contains("<c:max val=\"99"), content="true")
  inspect(cat_axis_sb.to_string().contains("<c:min val=\"1"), content="true")
  inspect(
    cat_axis_sb.to_string().contains("<c:tickLblSkip val=\"2\"/>"),
    content="true",
  )
  inspect(cat_axis_sb.to_string().contains("<a:defRPr/>"), content="true")

  let val_axis = ChartAxis::new()
  val_axis.major_unit = 2.5
  let val_axis_sb = StringBuilder::new()
  write_axis(val_axis_sb, "valAx", val_axis, 2, 1, "l", Col)
  inspect(
    val_axis_sb.to_string().contains("<c:majorUnit val=\"2.5\"/>"),
    content="true",
  )

  let axis_tx_none_vertical = ChartAxis::new()
  axis_tx_none_vertical.alignment = Alignment::with_values(text_rotation=10)
  let axis_tx_none_vertical_sb = StringBuilder::new()
  write_axis_tx_pr(axis_tx_none_vertical_sb, axis_tx_none_vertical)
  inspect(
    axis_tx_none_vertical_sb.to_string().contains("rot=\"600000\""),
    content="true",
  )

  let axis_num_fmt_sb = StringBuilder::new()
  write_axis_num_fmt(axis_num_fmt_sb, ChartNumFmt::new(source_linked=false))
  inspect(
    axis_num_fmt_sb
    .to_string()
    .contains("formatCode=\"General\" sourceLinked=\"0\""),
    content="true",
  )

  let dlbl_plot = ChartPlotArea::new()
  dlbl_plot.num_fmt = ChartNumFmt::new(source_linked=false)
  let dlbl_plot_sb = StringBuilder::new()
  write_chart_dlbls(dlbl_plot_sb, "pieChart", false, dlbl_plot)
  inspect(
    dlbl_plot_sb
    .to_string()
    .contains("formatCode=\"General\" sourceLinked=\"0\""),
    content="true",
  )

  let plot_opts = ChartOptions::new(Col)
  plot_opts.plot_area.fill_color = "#112233"
  plot_opts.plot_area.fill_transparency = -1
  let plot_sppr_sb = StringBuilder::new()
  write_plot_area_sppr(plot_sppr_sb, plot_opts)
  inspect(
    plot_sppr_sb.to_string().contains("<a:srgbClr val=\"112233\"/>"),
    content="true",
  )
  inspect(plot_sppr_sb.to_string().contains("<a:alpha"), content="false")

  let dtable_opts = ChartOptions::new(Col)
  dtable_opts.plot_area.show_data_table = true
  let dtable_skip_sb = StringBuilder::new()
  write_plot_area_d_table(dtable_skip_sb, "scatterChart", dtable_opts)
  inspect(dtable_skip_sb.to_string(), content="")
  let dtable_emit_sb = StringBuilder::new()
  write_plot_area_d_table(dtable_emit_sb, "barChart", dtable_opts)
  inspect(
    dtable_emit_sb.to_string().contains("showKeys val=\"0\""),
    content="true",
  )

  let root_no_line = ChartOptions::new(Col)
  root_no_line.fill_color = "#112233"
  root_no_line.fill_transparency = -1
  root_no_line.border.typ = NoLine
  let root_no_line_sb = StringBuilder::new()
  write_chart_sppr_root(root_no_line_sb, root_no_line)
  inspect(root_no_line_sb.to_string().contains("<a:noFill/>"), content="true")
  inspect(root_no_line_sb.to_string().contains("<a:alpha"), content="false")

  let root_open_ln = ChartOptions::new(Col)
  root_open_ln.border.typ = Solid
  root_open_ln.border.width = 1.0
  let root_open_ln_sb = StringBuilder::new()
  write_chart_sppr_root(root_open_ln_sb, root_open_ln)
  inspect(
    root_open_ln_sb.to_string().contains("<a:ln w=\"12700\"/>"),
    content="true",
  )

  let root_color_ln = ChartOptions::new(Col)
  root_color_ln.border.typ = Solid
  root_color_ln.border.color = "#334455"
  root_color_ln.border.transparency = 200
  let root_color_ln_sb = StringBuilder::new()
  write_chart_sppr_root(root_color_ln_sb, root_color_ln)
  inspect(
    root_color_ln_sb.to_string().contains("alpha val=\"0\""),
    content="true",
  )

  let root_color_ln_zero = ChartOptions::new(Col)
  root_color_ln_zero.border.typ = Solid
  root_color_ln_zero.border.color = "#556677"
  root_color_ln_zero.border.transparency = 0
  let root_color_ln_zero_sb = StringBuilder::new()
  write_chart_sppr_root(root_color_ln_zero_sb, root_color_ln_zero)
  inspect(
    root_color_ln_zero_sb
    .to_string()
    .contains("<a:solidFill><a:srgbClr val=\"556677\"/>"),
    content="true",
  )

  let sppr_return_sb = StringBuilder::new()
  write_chart_sppr(sppr_return_sb, "", ChartLine::new())
  inspect(sppr_return_sb.to_string(), content="")

  let sppr_no_line_border = ChartLine::new()
  sppr_no_line_border.typ = NoLine
  let sppr_no_line_sb = StringBuilder::new()
  write_chart_sppr(sppr_no_line_sb, "", sppr_no_line_border)
  inspect(sppr_no_line_sb.to_string().contains("<a:noFill/>"), content="true")

  let sppr_open_border = ChartLine::new()
  sppr_open_border.typ = Solid
  sppr_open_border.width = 1.0
  let sppr_open_sb = StringBuilder::new()
  write_chart_sppr(sppr_open_sb, "", sppr_open_border)
  inspect(
    sppr_open_sb.to_string().contains("<a:ln w=\"12700\"/>"),
    content="true",
  )

  let sppr_color_alpha = ChartLine::new()
  sppr_color_alpha.typ = Solid
  sppr_color_alpha.color = "#99AABB"
  sppr_color_alpha.transparency = 50
  let sppr_color_alpha_sb = StringBuilder::new()
  write_chart_sppr(sppr_color_alpha_sb, "", sppr_color_alpha)
  inspect(
    sppr_color_alpha_sb.to_string().contains("alpha val=\"50000\""),
    content="true",
  )

  let sppr_color_zero = ChartLine::new()
  sppr_color_zero.typ = Solid
  sppr_color_zero.color = "#112244"
  sppr_color_zero.transparency = 0
  let sppr_color_zero_sb = StringBuilder::new()
  write_chart_sppr(sppr_color_zero_sb, "", sppr_color_zero)
  inspect(
    sppr_color_zero_sb
    .to_string()
    .contains("<a:solidFill><a:srgbClr val=\"112244\"/>"),
    content="true",
  )

  let sppr_dash = ChartLine::new()
  sppr_dash.typ = Solid
  sppr_dash.color = "#CC8844"
  sppr_dash.transparency = 10
  sppr_dash.dash = Dash
  let sppr_dash_sb = StringBuilder::new()
  write_chart_sppr(sppr_dash_sb, "", sppr_dash)
  inspect(
    sppr_dash_sb.to_string().contains("alpha val=\"90000\""),
    content="true",
  )
  inspect(
    sppr_dash_sb.to_string().contains("prstDash val=\"dash\""),
    content="true",
  )

  let sppr_neg = ChartLine::new()
  sppr_neg.typ = Solid
  sppr_neg.color = "#114488"
  sppr_neg.transparency = -1
  let sppr_neg_sb = StringBuilder::new()
  write_chart_sppr(sppr_neg_sb, "", sppr_neg)
  inspect(
    sppr_neg_sb.to_string().contains("<a:solidFill><a:srgbClr val=\"114488\"/>"),
    content="true",
  )

  let sppr_gt = ChartLine::new()
  sppr_gt.typ = Solid
  sppr_gt.color = "#228844"
  sppr_gt.transparency = 200
  sppr_gt.dash = Dot
  let sppr_gt_sb = StringBuilder::new()
  write_chart_sppr(sppr_gt_sb, "", sppr_gt)
  inspect(sppr_gt_sb.to_string().contains("alpha val=\"0\""), content="true")
  inspect(
    sppr_gt_sb.to_string().contains("prstDash val=\"dot\""),
    content="true",
  )
}

///|
test "chart options wb: chart_options_to_xml guard and single-plot branches" {
  let empty = ChartOptions::new(Col)
  let empty_result : Result[String, Error] = try? chart_options_to_xml(empty)
  inspect(
    empty_result
    is Err(XlsxError::InvalidSheetOperation(msg="chart series empty")),
    content="true",
  )

  let combo_empty = ChartOptions::new(Col)
  combo_empty.series.push(wb_series())
  combo_empty.add_combo_chart(ChartOptions::new(Line))
  let combo_empty_result : Result[String, Error] = try? chart_options_to_xml(
    combo_empty,
  )
  inspect(
    combo_empty_result
    is Err(XlsxError::InvalidSheetOperation(msg="combo chart series empty")),
    content="true",
  )

  let contour = ChartOptions::new(WireframeContour)
  contour.series.push(wb_series())
  let contour_xml = chart_options_to_xml(contour)
  inspect(contour_xml.contains("<c:surfaceChart>"), content="true")
  inspect(contour_xml.contains("<c:wireframe val=\"1\"/>"), content="true")

  let doughnut = ChartOptions::new(Doughnut)
  doughnut.series.push(wb_series())
  let doughnut_xml = chart_options_to_xml(doughnut)
  inspect(doughnut_xml.contains("<c:holeSize val=\"75\"/>"), content="true")
}

///|
test "chart options wb: combo branches and guards" {
  let mixed = ChartOptions::new(Col)
  mixed.series.push(wb_series(name="Main"))

  let secondary_xy = ChartOptions::new(Scatter)
  secondary_xy.series.push(wb_series(name="XY"))
  secondary_xy.y_axis.secondary = true
  mixed.add_combo_chart(secondary_xy)

  let radar = ChartOptions::new(Radar)
  radar.series.push(wb_series(name="Radar"))
  mixed.add_combo_chart(radar)

  let bubble3d = ChartOptions::new(Bubble3D)
  let bubble_series = wb_series(name="Bubble")
  try! bubble_series.set_bubble_size("Sheet1!$C$2:$C$4")
  bubble3d.series.push(bubble_series)
  bubble3d.y_axis.secondary = true
  bubble3d.bubble_scale = Some(150)
  mixed.add_combo_chart(bubble3d)

  let bar = ChartOptions::new(Bar)
  bar.series.push(wb_series(name="Bar"))
  bar.gap_width = Some(220)
  bar.overlap = Some(-10)
  mixed.add_combo_chart(bar)

  let bar3d = ChartOptions::new(Bar3DClustered)
  bar3d.series.push(wb_series(name="Bar3D"))
  mixed.add_combo_chart(bar3d)

  let cone3d = ChartOptions::new(Col3DConeClustered)
  cone3d.series.push(wb_series(name="Cone3D"))
  mixed.add_combo_chart(cone3d)

  let mixed_xml = chart_options_to_xml(mixed)
  inspect(
    mixed_xml.contains("<c:radarStyle val=\"standard\"/>"),
    content="true",
  )
  inspect(mixed_xml.contains("<c:bubble3D val=\"1\"/>"), content="true")
  inspect(mixed_xml.contains("<c:bubbleScale val=\"150\"/>"), content="true")
  inspect(mixed_xml.contains("<c:gapWidth val=\"220\"/>"), content="true")
  inspect(mixed_xml.contains("<c:overlap val=\"-10\"/>"), content="true")
  inspect(mixed_xml.contains("<c:shape val=\"cone\"/>"), content="true")
  inspect(mixed_xml.contains("<c:axPos val=\"t\"/>"), content="true")
  inspect(mixed_xml.contains("<c:axPos val=\"r\"/>"), content="true")

  let unsupported_combo = ChartOptions::new(Col)
  unsupported_combo.series.push(wb_series())
  let pie_combo = ChartOptions::new(Pie)
  pie_combo.series.push(wb_series(name="Pie"))
  unsupported_combo.add_combo_chart(pie_combo)
  let unsupported_result : Result[String, Error] = try? chart_options_to_xml(
    unsupported_combo,
  )
  inspect(
    unsupported_result
    is Err(XlsxError::UnsupportedFeature(msg="combo chart type unsupported")),
    content="true",
  )

  let stock_combo_bad = ChartOptions::new(Col)
  stock_combo_bad.series.push(wb_series())
  let stock = ChartOptions::new(StockHighLowClose)
  stock.series.push(wb_series(name="OnlyOne"))
  stock_combo_bad.add_combo_chart(stock)
  let stock_result : Result[String, Error] = try? chart_options_to_xml(
    stock_combo_bad,
  )
  inspect(
    stock_result
    is Err(
      XlsxError::InvalidSheetOperation(msg="stock chart requires 3 series")
    ),
    content="true",
  )

  let xy_only = ChartOptions::new(Scatter)
  xy_only.series.push(wb_series(name="XYMain"))
  let bubble_combo = ChartOptions::new(Bubble)
  let bubble_combo_series = wb_series(name="XYBubble")
  try! bubble_combo_series.set_bubble_size("Sheet1!$C$2:$C$4")
  bubble_combo.series.push(bubble_combo_series)
  xy_only.add_combo_chart(bubble_combo)
  let xy_only_xml = chart_options_to_xml(xy_only)
  inspect(xy_only_xml.contains("<c:dTable>"), content="false")
}
