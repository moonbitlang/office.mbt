// Tests for ADT-driven chart options.

///|
fn opt_data() -> @chart.ChartData {
  @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_series("Revenue", [100.0, 200.0])
}

// --- title ---

///|
test "ChartOption Title: sets a rich-text title and serialises the text" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([Title("Revenue")])
  debug_inspect(chart.chart.title is Some(_), content="true")
  debug_inspect(chart.chart.auto_title_deleted is None, content="true")
  // The text reaches the serialised XML inside <c:title>.
  let xml = @oxml.bytes_to_string(chart.serialize())
  debug_inspect(xml.contains("<c:title>"), content="true")
  debug_inspect(xml.contains("Revenue"), content="true")
  // And the whole thing round-trips structurally.
  debug_inspect(@chart.Chart::parse(chart.serialize()) == chart, content="true")
}

///|
test "ChartOption TitleDeleted: clears title + sets autoTitleDeleted" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    Title("X"),
    TitleDeleted,
  ])
  debug_inspect(chart.chart.title is None, content="true")
  debug_inspect(chart.chart.auto_title_deleted, content="Some(true)")
}

// --- legend ---

///|
test "ChartOption Legend: sets the legend position" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    Legend(LegendBottom),
  ])
  match chart.chart.legend {
    Some(lg) => debug_inspect(lg.legend_pos, content="Some(LegendBottom)")
    None => fail("expected a legend")
  }
  debug_inspect(@chart.Chart::parse(chart.serialize()) == chart, content="true")
}

///|
test "ChartOption Legend: later option wins; LegendHidden clears" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    Legend(LegendRight),
    Legend(LegendTop),
  ])
  match chart.chart.legend {
    Some(lg) => debug_inspect(lg.legend_pos, content="Some(LegendTop)")
    None => fail("expected a legend")
  }
  let hidden = chart.with_options([LegendHidden])
  debug_inspect(hidden.chart.legend is None, content="true")
}

// --- data labels ---

///|
test "ChartOption DataLabels: sets value labels on the bar plot" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    DataLabels(DLblOutEnd),
  ])
  match chart.chart.plot_area.plots[0] {
    BarChart(b) =>
      match b.d_lbls {
        Some(d) => {
          debug_inspect(d.d_lbl_pos, content="Some(DLblOutEnd)")
          debug_inspect(d.show_val, content="Some(true)")
        }
        None => fail("expected d_lbls")
      }
    _ => fail("expected BarChart")
  }
  debug_inspect(@chart.Chart::parse(chart.serialize()) == chart, content="true")
}

///|
test "ChartOption DataLabels: applies to a pie plot too" {
  let chart = @chart.Chart::of_pie(opt_data()).with_options([
    DataLabels(DLblCenter),
  ])
  match chart.chart.plot_area.plots[0] {
    PieChart(b) => debug_inspect(b.d_lbls is Some(_), content="true")
    _ => fail("expected PieChart")
  }
}

///|
test "ChartOption DataLabelsHidden: clears data labels" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    DataLabels(DLblOutEnd),
    DataLabelsHidden,
  ])
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => debug_inspect(b.d_lbls is None, content="true")
    _ => fail("expected BarChart")
  }
}

///|
test "ChartOption DataLabels: surface charts are left untouched (no-op)" {
  let base = @chart.Chart::of_surface(opt_data())
  let labelled = base.with_options([DataLabels(DLblOutEnd)])
  // Surface has no <c:dLbls>; the option must not change anything.
  debug_inspect(labelled == base, content="true")
}

// --- data table ---

///|
test "ChartOption DataTable: toggles the plot-area data table" {
  let on = @chart.Chart::of_bar(opt_data()).with_options([DataTable(true)])
  debug_inspect(on.chart.plot_area.data_table is Some(_), content="true")
  let off = on.with_options([DataTable(false)])
  debug_inspect(off.chart.plot_area.data_table is None, content="true")
  debug_inspect(@chart.Chart::parse(on.serialize()) == on, content="true")
}

// --- scalar chartSpace / chart toggles ---

///|
test "ChartOption scalar toggles set their fields" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    Style(7),
    RoundedCorners(false),
    PlotVisibleOnly(true),
    DisplayBlanks(Gap),
  ])
  debug_inspect(chart.style, content="Some(7)")
  debug_inspect(chart.rounded_corners, content="Some(false)")
  debug_inspect(chart.chart.plot_vis_only, content="Some(true)")
  debug_inspect(chart.chart.disp_blanks_as, content="Some(Gap)")
  debug_inspect(@chart.Chart::parse(chart.serialize()) == chart, content="true")
}

// --- composition + immutability ---

///|
test "with_options: applies many options and round-trips" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    Title("Quarterly revenue"),
    Legend(LegendBottom),
    DataLabels(DLblOutEnd),
    DataTable(true),
    Style(2),
    RoundedCorners(false),
    PlotVisibleOnly(true),
    DisplayBlanks(Zero),
  ])
  debug_inspect(chart.chart.title is Some(_), content="true")
  debug_inspect(chart.chart.legend is Some(_), content="true")
  debug_inspect(@chart.Chart::parse(chart.serialize()) == chart, content="true")
}

///|
test "with_options: does not mutate the original chart" {
  let base = @chart.Chart::of_bar(opt_data())
  let _ = base.with_options([Title("X"), Legend(LegendTop)])
  debug_inspect(base.chart.title is None, content="true")
  debug_inspect(base.chart.legend is None, content="true")
}

///|
test "with_options: empty list is the identity" {
  let base = @chart.Chart::of_bar(opt_data())
  debug_inspect(base.with_options([]) == base, content="true")
}
