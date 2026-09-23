// Chart-from-scratch builder tests.

///|
fn quarterly_revenue() -> @chart.ChartData {
  @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_category("Q3")
  .with_category("Q4")
  .with_series("Revenue", [100.0, 200.0, 300.0, 250.0])
  .with_series("Cost", [60.0, 110.0, 180.0, 140.0])
}

// --- ChartData immutable builder ---

///|
test "ChartData::new is empty" {
  let d = @chart.ChartData::new()
  debug_inspect(d.categories.length(), content="0")
  debug_inspect(d.series.length(), content="0")
}

///|
test "ChartData::with_category does not mutate the original" {
  let a = @chart.ChartData::new()
  let b = a.with_category("Q1")
  debug_inspect(a.categories.length(), content="0")
  debug_inspect(b.categories.length(), content="1")
}

///|
test "ChartData::with_series does not mutate the original" {
  let a = @chart.ChartData::new().with_category("Q1")
  let b = a.with_series("Revenue", [100.0])
  debug_inspect(a.series.length(), content="0")
  debug_inspect(b.series.length(), content="1")
  debug_inspect(b.series[0].label, content="\"Revenue\"")
}

// --- Chart::of_bar ---

///|
test "Chart::of_bar: produces a Col bar chart by default" {
  let chart = @chart.Chart::of_bar(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      debug_inspect(b.bar_dir, content="Col")
      debug_inspect(b.grouping is Some(Clustered), content="true")
      debug_inspect(b.series.length(), content="2")
      debug_inspect(b.ax_ids.length(), content="2")
    }
    _ => fail("expected BarChart plot")
  }
  // catAx + valAx pair
  debug_inspect(chart.chart.plot_area.axes.length(), content="2")
  debug_inspect(chart.chart.plot_area.axes[0].local_name(), content="\"catAx\"")
  debug_inspect(chart.chart.plot_area.axes[1].local_name(), content="\"valAx\"")
}

///|
test "Chart::of_bar: horizontal Bar variant" {
  let chart = @chart.Chart::of_bar(
    @chart.ChartData::new().with_category("a").with_series("s", [1.0]),
    bar_dir=Bar,
    grouping=Stacked,
  )
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      debug_inspect(b.bar_dir, content="Bar")
      debug_inspect(b.grouping is Some(Stacked), content="true")
    }
    _ => fail("expected BarChart plot")
  }
}

///|
test "Chart::of_bar: round-trips through serialize → parse" {
  let original = @chart.Chart::of_bar(quarterly_revenue())
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Chart::of_line ---

///|
test "Chart::of_line: standard grouping by default" {
  let chart = @chart.Chart::of_line(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    LineChart(b) => {
      debug_inspect(b.grouping, content="Standard")
      debug_inspect(b.series.length(), content="2")
      debug_inspect(b.ax_ids.length(), content="2")
    }
    _ => fail("expected LineChart plot")
  }
}

///|
test "Chart::of_line: round-trips through serialize → parse" {
  let original = @chart.Chart::of_line(quarterly_revenue(), grouping=Stacked)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Chart::of_pie ---

///|
test "Chart::of_pie: no axes, vary_colors defaults to true" {
  let chart = @chart.Chart::of_pie(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    PieChart(b) => {
      debug_inspect(b.vary_colors.unwrap(), content="true")
      debug_inspect(b.series.length(), content="2")
    }
    _ => fail("expected PieChart plot")
  }
  debug_inspect(chart.chart.plot_area.axes.length(), content="0")
}

///|
test "Chart::of_pie: round-trips through serialize → parse" {
  let original = @chart.Chart::of_pie(quarterly_revenue())
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Chart::of_area ---

///|
test "Chart::of_area: standard grouping by default" {
  let chart = @chart.Chart::of_area(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    AreaChart(b) => {
      debug_inspect(b.grouping is Some(Standard), content="true")
      debug_inspect(b.series.length(), content="2")
      debug_inspect(b.ax_ids.length(), content="2")
    }
    _ => fail("expected AreaChart plot")
  }
}

///|
test "Chart::of_area: round-trips" {
  let original = @chart.Chart::of_area(
    quarterly_revenue(),
    grouping=PercentStacked,
  )
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Chart::of_radar ---

///|
test "Chart::of_radar: marker style by default" {
  let chart = @chart.Chart::of_radar(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    RadarChart(b) => {
      debug_inspect(b.radar_style, content="Marker")
      debug_inspect(b.series.length(), content="2")
    }
    _ => fail("expected RadarChart plot")
  }
}

///|
test "Chart::of_radar: filled variant round-trips" {
  let original = @chart.Chart::of_radar(quarterly_revenue(), radar_style=Filled)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Chart::of_scatter ---

///|
test "Chart::of_scatter: two value axes" {
  let data = @chart.ScatterData::new()
    .with_series("s1", [1.0, 2.0, 3.0], [10.0, 20.0, 30.0])
    .with_series("s2", [1.5, 2.5, 3.5], [12.0, 24.0, 36.0])
  let chart = @chart.Chart::of_scatter(data)
  match chart.chart.plot_area.plots[0] {
    ScatterChart(b) => {
      debug_inspect(b.scatter_style, content="LineMarker")
      debug_inspect(b.series.length(), content="2")
    }
    _ => fail("expected ScatterChart")
  }
  debug_inspect(chart.chart.plot_area.axes.length(), content="2")
  // Both axes for scatter are valAx (not catAx).
  debug_inspect(chart.chart.plot_area.axes[0].local_name(), content="\"valAx\"")
  debug_inspect(chart.chart.plot_area.axes[1].local_name(), content="\"valAx\"")
}

///|
test "Chart::of_scatter: explicit style + round-trip" {
  let data = @chart.ScatterData::new().with_series("s1", [0.0], [0.0])
  let original = @chart.Chart::of_scatter(data, scatter_style=Smooth)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

///|
test "Chart::of_scatter: series carry xVal + yVal (not cat+val)" {
  let data = @chart.ScatterData::new().with_series("s", [1.0, 2.0], [10.0, 20.0])
  let chart = @chart.Chart::of_scatter(data)
  match chart.chart.plot_area.plots[0] {
    ScatterChart(b) => {
      let s = b.series[0]
      debug_inspect(s.x_val is Some(_), content="true")
      debug_inspect(s.y_val is Some(_), content="true")
    }
    _ => fail("expected ScatterChart")
  }
}

// --- Chart::of_bubble ---

///|
test "Chart::of_bubble: triples lift correctly" {
  let data = @chart.BubbleData::new().with_series(
    "growth",
    [1.0, 2.0, 3.0],
    [100.0, 200.0, 150.0],
    [10.0, 20.0, 30.0],
  )
  let chart = @chart.Chart::of_bubble(data)
  match chart.chart.plot_area.plots[0] {
    BubbleChart(b) => debug_inspect(b.series.length(), content="1")
    _ => fail("expected BubbleChart")
  }
}

///|
test "Chart::of_bubble: series carry xVal + yVal + bubbleSize" {
  let data = @chart.BubbleData::new().with_series("s", [1.0], [2.0], [3.0])
  let chart = @chart.Chart::of_bubble(data)
  match chart.chart.plot_area.plots[0] {
    BubbleChart(b) => {
      let s = b.series[0]
      debug_inspect(s.x_val is Some(_), content="true")
      debug_inspect(s.y_val is Some(_), content="true")
      debug_inspect(s.bubble_size is Some(_), content="true")
    }
    _ => fail("expected BubbleChart")
  }
}

///|
test "Chart::of_bubble: round-trips" {
  let data = @chart.BubbleData::new().with_series(
    "s",
    [1.0, 2.0],
    [10.0, 20.0],
    [5.0, 8.0],
  )
  let original = @chart.Chart::of_bubble(data)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Chart::of_doughnut ---

///|
test "Chart::of_doughnut: holeSize lifts" {
  let chart = @chart.Chart::of_doughnut(quarterly_revenue(), hole_size=60)
  match chart.chart.plot_area.plots[0] {
    DoughnutChart(b) => {
      debug_inspect(b.hole_size.unwrap(), content="60")
      debug_inspect(b.vary_colors.unwrap(), content="true")
    }
    _ => fail("expected DoughnutChart")
  }
}

///|
test "Chart::of_doughnut: round-trips" {
  let original = @chart.Chart::of_doughnut(quarterly_revenue())
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Chart::of_of_pie ---

///|
test "Chart::of_of_pie: defaults to Pie + omits Auto split" {
  let chart = @chart.Chart::of_of_pie(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    OfPieChart(b) => {
      debug_inspect(b.of_pie_type, content="Pie")
      // Auto is the schema default — we omit `<c:splitType>` to dodge
      // PowerPoint Online's repair banner.
      debug_inspect(b.split_type is None, content="true")
      // ofPie defaults gapWidth=100 + secondPieSize=75 are emitted
      // explicitly so PowerPoint doesn't normalise them in.
      debug_inspect(b.gap_width is Some(100), content="true")
      debug_inspect(b.second_pie_size is Some(75), content="true")
    }
    _ => fail("expected OfPieChart")
  }
}

///|
test "Chart::of_of_pie: bar variant + Percent split round-trips" {
  let original = @chart.Chart::of_of_pie(
    quarterly_revenue(),
    of_pie_type=Bar,
    split_type=Percent,
  )
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Chart::of_bar_3d ---

///|
test "Chart::of_bar_3d: three axIds + shape default Box" {
  let chart = @chart.Chart::of_bar_3d(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    Bar3DChart(b) => {
      debug_inspect(b.bar_dir, content="Col")
      debug_inspect(b.shape is Some(Box), content="true")
      debug_inspect(b.ax_ids.length(), content="3")
    }
    _ => fail("expected Bar3DChart")
  }
  debug_inspect(chart.chart.plot_area.axes.length(), content="3")
  debug_inspect(chart.chart.plot_area.axes[2].local_name(), content="\"serAx\"")
}

///|
test "Chart::of_bar_3d: cylinder shape + round-trip" {
  let original = @chart.Chart::of_bar_3d(quarterly_revenue(), shape=Cylinder)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Chart::of_line_3d ---

///|
test "Chart::of_line_3d: three axIds" {
  let chart = @chart.Chart::of_line_3d(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    Line3DChart(b) => debug_inspect(b.ax_ids.length(), content="3")
    _ => fail("expected Line3DChart")
  }
}

///|
test "Chart::of_line_3d: round-trips" {
  let original = @chart.Chart::of_line_3d(quarterly_revenue())
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Chart::of_pie_3d ---

///|
test "Chart::of_pie_3d: no axes" {
  let chart = @chart.Chart::of_pie_3d(quarterly_revenue())
  debug_inspect(chart.chart.plot_area.axes.length(), content="0")
  match chart.chart.plot_area.plots[0] {
    Pie3DChart(b) => debug_inspect(b.vary_colors.unwrap(), content="true")
    _ => fail("expected Pie3DChart")
  }
}

// --- Chart::of_surface ---

///|
test "Chart::of_surface: wireframe defaults false" {
  let chart = @chart.Chart::of_surface(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    SurfaceChart(b) => debug_inspect(b.wireframe.unwrap(), content="false")
    _ => fail("expected SurfaceChart")
  }
}

///|
test "Chart::of_surface_3d: three axIds; wireframe lifts" {
  let chart = @chart.Chart::of_surface_3d(quarterly_revenue(), wireframe=true)
  match chart.chart.plot_area.plots[0] {
    Surface3DChart(b) => {
      debug_inspect(b.wireframe.unwrap(), content="true")
      debug_inspect(b.ax_ids.length(), content="3")
    }
    _ => fail("expected Surface3DChart")
  }
  debug_inspect(chart.chart.plot_area.axes.length(), content="3")
}

///|
test "Chart::of_surface_3d: round-trips" {
  let original = @chart.Chart::of_surface_3d(
    quarterly_revenue(),
    wireframe=true,
  )
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- Chart::of_stock ---

///|
test "Chart::of_stock: HLC variant gets 3 series" {
  let data = @chart.ChartData::new()
    .with_category("Jan")
    .with_category("Feb")
    .with_series("High", [100.0, 110.0])
    .with_series("Low", [80.0, 85.0])
    .with_series("Close", [90.0, 105.0])
  let chart = @chart.Chart::of_stock(data)
  match chart.chart.plot_area.plots[0] {
    StockChart(b) => {
      debug_inspect(b.series.length(), content="3")
      debug_inspect(b.hi_low_lines is Some(_), content="true")
    }
    _ => fail("expected StockChart")
  }
}

///|
test "Chart::of_stock: OHLC variant gets 4 series; extras truncated" {
  let data = @chart.ChartData::new()
    .with_category("Jan")
    .with_series("a", [1.0])
    .with_series("b", [2.0])
    .with_series("c", [3.0])
    .with_series("d", [4.0])
    .with_series("e", [5.0]) // excess — should be truncated to 4
  let chart = @chart.Chart::of_stock(data, kind=OHLC)
  match chart.chart.plot_area.plots[0] {
    StockChart(b) => debug_inspect(b.series.length(), content="4")
    _ => fail("expected StockChart")
  }
}

///|
test "Chart::of_stock: insufficient series get zero-padded" {
  let data = @chart.ChartData::new()
    .with_category("Jan")
    .with_category("Feb")
    .with_series("only-one", [1.0, 2.0])
  let chart = @chart.Chart::of_stock(data)
  match chart.chart.plot_area.plots[0] {
    StockChart(b) => debug_inspect(b.series.length(), content="3") // HLC default
    _ => fail("expected StockChart")
  }
}

///|
test "Chart::of_stock: HLC round-trips" {
  let data = @chart.ChartData::new()
    .with_category("Jan")
    .with_series("H", [100.0])
    .with_series("L", [80.0])
    .with_series("C", [90.0])
  let original = @chart.Chart::of_stock(data)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  debug_inspect(re_parsed == original, content="true")
}

// --- series synthesis ---

///|
test "synthesized series: idx + order assigned sequentially" {
  let chart = @chart.Chart::of_bar(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      let s0 = b.series[0]
      debug_inspect(s0.idx, content="0")
      debug_inspect(s0.order, content="0")
      let s1 = b.series[1]
      debug_inspect(s1.idx, content="1")
      debug_inspect(s1.order, content="1")
    }
    _ => fail("expected BarChart")
  }
}

///|
test "synthesized series: every series carries cat + val children" {
  let chart = @chart.Chart::of_bar(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    BarChart(b) =>
      for s in b.series {
        debug_inspect(s.cat is Some(_), content="true")
        debug_inspect(s.val is Some(_), content="true")
        debug_inspect(s.tx is Some(_), content="true")
      }
    _ => fail("expected BarChart")
  }
}

///|
test "synthesized series: shorter values array gets zero-padded" {
  let data = @chart.ChartData::new()
    .with_category("a")
    .with_category("b")
    .with_category("c")
    // Only one value for three categories — emitter pads to ptCount=3.
    .with_series("partial", [42.0])
  let chart = @chart.Chart::of_bar(data)
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      let s = b.series[0]
      // <c:val><c:numLit><c:ptCount val="3"/>…
      let val = s.val.unwrap()
      let num_lit = find_child(val, "numLit")
      let pt_count = find_val(num_lit, "ptCount")
      debug_inspect(pt_count, content="\"3\"")
    }
    _ => fail("expected BarChart")
  }
}

// --- helpers ---

///|
fn find_val(el : @xml.XmlElement, local_name : String) -> String {
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.local_name == local_name {
          for kv in c.attributes {
            if kv.0.local_name == "val" {
              return kv.1
            }
          }
        }
      _ => ()
    }
  }
  ""
}

///|
fn find_child(
  el : @xml.XmlElement,
  local_name : String,
) -> @xml.XmlElement raise {
  for node in el.children {
    match node {
      Element(c) => if c.name.local_name == local_name { return c }
      _ => ()
    }
  }
  fail("child <" + local_name + "> not found")
}
