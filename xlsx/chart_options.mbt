///|
pub(all) enum ChartType {
  Area
  AreaStacked
  AreaPercentStacked
  Area3D
  Area3DStacked
  Area3DPercentStacked
  Bar
  BarStacked
  BarPercentStacked
  Bar3DClustered
  Bar3DStacked
  Bar3DPercentStacked
  Bar3DConeClustered
  Bar3DConeStacked
  Bar3DConePercentStacked
  Bar3DPyramidClustered
  Bar3DPyramidStacked
  Bar3DPyramidPercentStacked
  Bar3DCylinderClustered
  Bar3DCylinderStacked
  Bar3DCylinderPercentStacked
  Col
  ColStacked
  ColPercentStacked
  Col3D
  Col3DClustered
  Col3DStacked
  Col3DPercentStacked
  Col3DCone
  Col3DConeClustered
  Col3DConeStacked
  Col3DConePercentStacked
  Col3DPyramid
  Col3DPyramidClustered
  Col3DPyramidStacked
  Col3DPyramidPercentStacked
  Col3DCylinder
  Col3DCylinderClustered
  Col3DCylinderStacked
  Col3DCylinderPercentStacked
  Doughnut
  Line
  Line3D
  Pie
  Pie3D
  PieOfPie
  BarOfPie
  Radar
  Scatter
  Surface3D
  WireframeSurface3D
  Contour
  WireframeContour
  Bubble
  Bubble3D
  StockHighLowClose
  StockOpenHighLowClose
} derive(Eq, Show)

///|
pub(all) enum ChartDashType {
  Unset
  Solid
  Dot
  Dash
  LgDash
  SashDot
  LgDashDot
  LgDashDotDot
  SysDash
  SysDot
  SysDashDot
  SysDashDotDot
} derive(Eq, Show)

///|
pub(all) enum ChartLineType {
  Unset
  Solid
  NoLine
  Automatic
} derive(Eq, Show)

///|
pub(all) enum ChartTickLabelPositionType {
  NextToAxis
  High
  Low
  NoTickLabels
} derive(Eq, Show)

///|
pub(all) enum ChartDataLabelPositionType {
  Center
  Left
  Right
  Top
  Bottom
  BestFit
  InEnd
  OutEnd
} derive(Eq, Show)

///|
pub(all) struct ChartNumFmt {
  custom_num_fmt : String
  source_linked : Bool
} derive(Eq, Show)

///|
pub fn ChartNumFmt::new(
  custom_num_fmt? : String = "",
  source_linked? : Bool = true,
) -> ChartNumFmt {
  { custom_num_fmt, source_linked }
}

///|
pub(all) struct ChartAxis {
  none : Bool
  major_grid_lines : Bool
  minor_grid_lines : Bool
  major_unit : Double
  tick_label_position : ChartTickLabelPositionType
  tick_label_skip : Int
  reverse_order : Bool
  secondary : Bool
  maximum : Double?
  minimum : Double?
  log_base : Double
  num_fmt : ChartNumFmt
  title : String
  ax_id : Int
} derive(Eq, Show)

///|
pub fn ChartAxis::new() -> ChartAxis {
  {
    none: false,
    major_grid_lines: false,
    minor_grid_lines: false,
    major_unit: 0.0,
    tick_label_position: ChartTickLabelPositionType::NextToAxis,
    tick_label_skip: 0,
    reverse_order: false,
    secondary: false,
    maximum: None,
    minimum: None,
    log_base: 0.0,
    num_fmt: ChartNumFmt::new(),
    title: "",
    ax_id: 0,
  }
}

///|
pub(all) struct ChartDimension {
  width : Int
  height : Int
} derive(Eq, Show)

///|
pub fn ChartDimension::new() -> ChartDimension {
  { width: 480, height: 260 }
}

///|
pub fn ChartDimension::with_values(
  width : Int,
  height : Int,
) -> ChartDimension raise XlsxError {
  if width <= 0 || height <= 0 {
    raise XlsxError::InvalidSheetOperation(msg="chart dimension must be > 0")
  }
  { width, height }
}

///|
pub(all) struct ChartLine {
  typ : ChartLineType
  dash : ChartDashType
  color : String
  smooth : Bool
  width : Double
} derive(Eq, Show)

///|
pub fn ChartLine::new() -> ChartLine {
  {
    typ: ChartLineType::Unset,
    dash: ChartDashType::Unset,
    color: "",
    smooth: false,
    width: 0.0,
  }
}

///|
pub(all) struct ChartUpDownBar {
  fill_color : String
  border : ChartLine
} derive(Eq, Show)

///|
pub fn ChartUpDownBar::new() -> ChartUpDownBar {
  { fill_color: "", border: ChartLine::new() }
}

///|
pub(all) struct ChartPlotArea {
  show_val : Bool
  num_fmt : ChartNumFmt
  up_bars : ChartUpDownBar
  down_bars : ChartUpDownBar
} derive(Eq, Show)

///|
pub fn ChartPlotArea::new() -> ChartPlotArea {
  {
    show_val: false,
    num_fmt: ChartNumFmt::new(),
    up_bars: ChartUpDownBar::new(),
    down_bars: ChartUpDownBar::new(),
  }
}

///|
pub(all) struct ChartLegend {
  position : String
  show_legend_key : Bool
} derive(Eq, Show)

///|
pub fn ChartLegend::new(
  position? : String = "bottom",
  show_legend_key? : Bool = false,
) -> ChartLegend {
  { position, show_legend_key }
}

///|
pub(all) struct ChartMarker {
  symbol : String
  size : Int
} derive(Eq, Show)

///|
pub fn ChartMarker::new(symbol? : String = "", size? : Int = 0) -> ChartMarker {
  { symbol, size }
}

///|
pub(all) struct ChartDataLabel {
  alignment : String
} derive(Eq, Show)

///|
pub fn ChartDataLabel::new(alignment? : String = "") -> ChartDataLabel {
  { alignment, }
}

///|
pub(all) struct ChartDataPoint {
  index : Int
  fill_color : String
} derive(Eq, Show)

///|
pub fn ChartDataPoint::new(
  index : Int,
  fill_color? : String = "",
) -> ChartDataPoint {
  { index, fill_color }
}

///|
pub(all) struct ChartSeries {
  name : String
  categories : String
  values : String
  line : ChartLine
  marker : ChartMarker
  data_label : ChartDataLabel
  data_label_position : ChartDataLabelPositionType
  data_point : Array[ChartDataPoint]
} derive(Eq, Show)

///|
pub fn ChartSeries::new(
  categories : String,
  values : String,
  name? : String = "",
) -> ChartSeries raise XlsxError {
  if categories == "" || values == "" {
    raise XlsxError::InvalidSheetOperation(
      msg="chart series categories/values must be non-empty",
    )
  }
  {
    name,
    categories,
    values,
    line: ChartLine::new(),
    marker: ChartMarker::new(),
    data_label: ChartDataLabel::new(),
    data_label_position: ChartDataLabelPositionType::BestFit,
    data_point: [],
  }
}

///|
pub(all) struct ChartOptions {
  typ : ChartType
  series : Array[ChartSeries]
  mut format : GraphicOptions
  mut dimension : ChartDimension
  mut legend : ChartLegend
  mut title : String
  mut vary_colors : Bool
  mut x_axis : ChartAxis
  mut y_axis : ChartAxis
  mut plot_area : ChartPlotArea
  mut show_blanks_as : String
  mut gap_width : Int?
  mut overlap : Int?
} derive(Eq, Show)

///|
pub fn ChartOptions::new(typ : ChartType) -> ChartOptions {
  {
    typ,
    series: [],
    format: GraphicOptions::new(),
    dimension: ChartDimension::new(),
    legend: ChartLegend::new(),
    title: "",
    vary_colors: true,
    x_axis: ChartAxis::new(),
    y_axis: ChartAxis::new(),
    plot_area: ChartPlotArea::new(),
    show_blanks_as: "gap",
    gap_width: None,
    overlap: None,
  }
}

///|
pub fn ChartOptions::set_format(
  self : ChartOptions,
  format : GraphicOptions,
) -> Unit {
  self.format = format
}

///|
pub fn ChartOptions::set_dimension(
  self : ChartOptions,
  dimension : ChartDimension,
) -> Unit {
  self.dimension = dimension
}

///|
pub fn ChartOptions::set_legend(
  self : ChartOptions,
  legend : ChartLegend,
) -> Unit {
  self.legend = legend
}

///|
pub fn ChartOptions::set_title(self : ChartOptions, title : String) -> Unit {
  self.title = title
}

///|
pub fn ChartOptions::set_vary_colors(
  self : ChartOptions,
  vary_colors : Bool,
) -> Unit {
  self.vary_colors = vary_colors
}

///|
pub fn ChartOptions::set_x_axis(self : ChartOptions, axis : ChartAxis) -> Unit {
  self.x_axis = axis
}

///|
pub fn ChartOptions::set_y_axis(self : ChartOptions, axis : ChartAxis) -> Unit {
  self.y_axis = axis
}

///|
pub fn ChartOptions::set_plot_area(
  self : ChartOptions,
  plot_area : ChartPlotArea,
) -> Unit {
  self.plot_area = plot_area
}

///|
pub fn ChartOptions::set_show_blanks_as(
  self : ChartOptions,
  show_blanks_as : String,
) -> Unit {
  self.show_blanks_as = show_blanks_as
}

///|
pub fn ChartOptions::set_gap_width(
  self : ChartOptions,
  gap_width : Int?,
) -> Unit {
  self.gap_width = gap_width
}

///|
pub fn ChartOptions::set_overlap(self : ChartOptions, overlap : Int?) -> Unit {
  self.overlap = overlap
}

///|
fn chart_type_to_plot(kind : ChartType) -> (String, String?) {
  match kind {
    ChartType::Col => ("barChart", Some("col"))
    ChartType::Bar => ("barChart", Some("bar"))
    ChartType::Line => ("lineChart", None)
    _ => ("", None)
  }
}

///|
fn write_chart_title(sb : StringBuilder, title : String) -> Unit {
  if title == "" {
    return
  }
  sb.write_view("    <c:title>\n")
  sb.write_view("      <c:tx>\n")
  sb.write_view("        <c:rich>\n")
  sb.write_view("          <a:bodyPr/>\n")
  sb.write_view("          <a:lstStyle/>\n")
  sb.write_view("          <a:p>\n")
  sb.write_view("            <a:r>\n")
  sb.write_view("              <a:t>")
  sb.write_view(escape_xml_text(title))
  sb.write_view("</a:t>\n")
  sb.write_view("            </a:r>\n")
  sb.write_view("          </a:p>\n")
  sb.write_view("        </c:rich>\n")
  sb.write_view("      </c:tx>\n")
  sb.write_view("    </c:title>\n")
}

///|
fn write_chart_series_tx(sb : StringBuilder, name : String) -> Unit {
  if name == "" {
    return
  }
  sb.write_view("          <c:tx>")
  if name.contains("!") {
    sb.write_view("<c:strRef><c:f>")
    sb.write_view(escape_xml_text(name))
    sb.write_view("</c:f></c:strRef>")
  } else {
    sb.write_view("<c:v>")
    sb.write_view(escape_xml_text(name))
    sb.write_view("</c:v>")
  }
  sb.write_view("</c:tx>\n")
}

///|
fn write_chart_series(
  sb : StringBuilder,
  series : ChartSeries,
  idx : Int,
) -> Unit {
  sb.write_view("        <c:ser>\n")
  sb.write_view("          <c:idx val=\"\{idx}\"/>\n")
  sb.write_view("          <c:order val=\"\{idx}\"/>\n")
  write_chart_series_tx(sb, series.name)
  sb.write_view("          <c:cat><c:strRef><c:f>")
  sb.write_view(escape_xml_text(series.categories))
  sb.write_view("</c:f></c:strRef></c:cat>\n")
  sb.write_view("          <c:val><c:numRef><c:f>")
  sb.write_view(escape_xml_text(series.values))
  sb.write_view("</c:f></c:numRef></c:val>\n")
  sb.write_view("        </c:ser>\n")
}

///|
pub fn chart_options_to_xml(opts : ChartOptions) -> String raise XlsxError {
  if opts.series.length() == 0 {
    raise XlsxError::InvalidSheetOperation(msg="chart series empty")
  }
  let (plot_tag, bar_dir) = chart_type_to_plot(opts.typ)
  if plot_tag == "" {
    raise XlsxError::UnsupportedFeature(msg="unsupported chart type")
  }
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n",
  )
  sb.write_view("  <c:chart>\n")
  write_chart_title(sb, opts.title)
  sb.write_view("    <c:plotArea>\n")
  sb.write_view("      <c:layout/>\n")
  sb.write_view("      <c:\{plot_tag}>\n")
  match bar_dir {
    Some(dir) => {
      sb.write_view("        <c:barDir val=\"")
      sb.write_view(escape_xml_attr(dir))
      sb.write_view("\"/>\n")
    }
    None => ()
  }
  let cat_ax_id = 1
  let val_ax_id = 2
  for i, series in opts.series {
    write_chart_series(sb, series, i)
  }
  sb.write_view("        <c:axId val=\"\{cat_ax_id}\"/>\n")
  sb.write_view("        <c:axId val=\"\{val_ax_id}\"/>\n")
  sb.write_view("      </c:\{plot_tag}>\n")
  sb.write_view("      <c:catAx>\n")
  sb.write_view("        <c:axId val=\"\{cat_ax_id}\"/>\n")
  sb.write_view(
    "        <c:scaling><c:orientation val=\"minMax\"/></c:scaling>\n",
  )
  sb.write_view("        <c:axPos val=\"b\"/>\n")
  sb.write_view("        <c:crossAx val=\"\{val_ax_id}\"/>\n")
  sb.write_view("        <c:tickLblPos val=\"nextTo\"/>\n")
  sb.write_view("      </c:catAx>\n")
  sb.write_view("      <c:valAx>\n")
  sb.write_view("        <c:axId val=\"\{val_ax_id}\"/>\n")
  sb.write_view(
    "        <c:scaling><c:orientation val=\"minMax\"/></c:scaling>\n",
  )
  sb.write_view("        <c:axPos val=\"l\"/>\n")
  sb.write_view("        <c:crossAx val=\"\{cat_ax_id}\"/>\n")
  sb.write_view("        <c:tickLblPos val=\"nextTo\"/>\n")
  sb.write_view("      </c:valAx>\n")
  sb.write_view("    </c:plotArea>\n")
  sb.write_view("    <c:legend>\n")
  sb.write_view("      <c:legendPos val=\"")
  sb.write_view(escape_xml_attr(opts.legend.position))
  sb.write_view("\"/>\n")
  sb.write_view("    </c:legend>\n")
  sb.write_view("    <c:plotVisOnly val=\"1\"/>\n")
  sb.write_view("  </c:chart>\n")
  sb.write_view("</c:chartSpace>")
  sb.to_string()
}
