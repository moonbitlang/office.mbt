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
  mut none : Bool
  mut major_grid_lines : Bool
  mut minor_grid_lines : Bool
  mut major_unit : Double
  mut tick_label_position : ChartTickLabelPositionType
  mut tick_label_skip : Int
  mut reverse_order : Bool
  mut secondary : Bool
  mut maximum : Double?
  mut minimum : Double?
  mut alignment : Alignment
  mut font : Font
  mut log_base : Double
  mut num_fmt : ChartNumFmt
  mut title : String
  mut title_rich : Array[RichTextRun]?
  mut ax_id : Int
} derive(Eq, Show)

///|
pub fn ChartAxis::new() -> ChartAxis {
  {
    none: false,
    major_grid_lines: false,
    minor_grid_lines: false,
    major_unit: 0.0,
    tick_label_position: NextToAxis,
    tick_label_skip: 0,
    reverse_order: false,
    secondary: false,
    maximum: None,
    minimum: None,
    alignment: Alignment::new(),
    font: Font::new(),
    log_base: 0.0,
    num_fmt: ChartNumFmt::new(),
    title: "",
    title_rich: None,
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
    raise InvalidSheetOperation(msg="chart dimension must be > 0")
  }
  { width, height }
}

///|
pub(all) struct ChartLine {
  mut typ : ChartLineType
  mut dash : ChartDashType
  mut color : String
  mut transparency : Int
  mut smooth : Bool
  mut width : Double
} derive(Eq, Show)

///|
pub fn ChartLine::new() -> ChartLine {
  {
    typ: Unset,
    dash: Unset,
    color: "",
    transparency: 0,
    smooth: false,
    width: 0.0,
  }
}

///|
pub(all) struct ChartUpDownBar {
  mut fill_color : String
  mut border : ChartLine
} derive(Eq, Show)

///|
pub fn ChartUpDownBar::new() -> ChartUpDownBar {
  { fill_color: "", border: ChartLine::new() }
}

///|
pub(all) struct ChartPlotArea {
  mut show_val : Bool
  mut show_cat_name : Bool
  mut show_ser_name : Bool
  mut show_percent : Bool
  mut show_leader_lines : Bool
  mut show_bubble_size : Bool
  mut show_data_table : Bool
  mut show_data_table_keys : Bool
  mut second_plot_values : Int
  mut num_fmt : ChartNumFmt
  mut up_bars : ChartUpDownBar
  mut down_bars : ChartUpDownBar
  mut fill_color : String
  mut fill_transparency : Int
} derive(Eq, Show)

///|
pub fn ChartPlotArea::new() -> ChartPlotArea {
  {
    show_val: false,
    show_cat_name: false,
    show_ser_name: false,
    show_percent: false,
    show_leader_lines: false,
    show_bubble_size: false,
    show_data_table: false,
    show_data_table_keys: false,
    second_plot_values: 0,
    num_fmt: ChartNumFmt::new(),
    up_bars: ChartUpDownBar::new(),
    down_bars: ChartUpDownBar::new(),
    fill_color: "",
    fill_transparency: 0,
  }
}

///|
pub(all) struct ChartLegend {
  mut position : String
  mut show_legend_key : Bool
  mut font : Font?
} derive(Eq, Show)

///|
pub fn ChartLegend::new(
  position? : String = "bottom",
  show_legend_key? : Bool = false,
) -> ChartLegend {
  { position, show_legend_key, font: None }
}

///|
pub(all) struct ChartMarker {
  mut symbol : String
  mut size : Int
  mut fill_color : String
  mut fill_transparency : Int
  mut border : ChartLine
} derive(Eq, Show)

///|
pub fn ChartMarker::new(symbol? : String = "", size? : Int = 0) -> ChartMarker {
  {
    symbol,
    size,
    fill_color: "",
    fill_transparency: 0,
    border: ChartLine::new(),
  }
}

///|
pub(all) struct ChartDataLabel {
  mut font : Font
  mut alignment : Alignment
  mut fill_color : String
  mut fill_transparency : Int
} derive(Eq, Show)

///|
pub fn ChartDataLabel::new() -> ChartDataLabel {
  {
    font: Font::new(),
    alignment: Alignment::new(),
    fill_color: "",
    fill_transparency: 0,
  }
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
  mut bubble_size : String?
  mut fill_color : String
  mut fill_transparency : Int
  mut line : ChartLine
  mut marker : ChartMarker
  mut data_label : ChartDataLabel
  mut data_label_position : ChartDataLabelPositionType
  data_point : Array[ChartDataPoint]
} derive(Eq, Show)

///|
pub fn ChartSeries::new(
  categories : String,
  values : String,
  name? : String = "",
) -> ChartSeries raise XlsxError {
  if categories == "" || values == "" {
    raise InvalidSheetOperation(
      msg="chart series categories/values must be non-empty",
    )
  }
  {
    name,
    categories,
    values,
    bubble_size: None,
    fill_color: "",
    fill_transparency: 0,
    line: ChartLine::new(),
    marker: ChartMarker::new(),
    data_label: ChartDataLabel::new(),
    data_label_position: BestFit,
    data_point: [],
  }
}

///|
pub fn ChartSeries::set_bubble_size(
  self : ChartSeries,
  bubble_size : String,
) -> Unit raise XlsxError {
  if bubble_size == "" {
    raise InvalidSheetOperation(msg="bubble size range empty")
  }
  self.bubble_size = Some(bubble_size)
}

///|
pub(all) struct ChartOptions {
  typ : ChartType
  series : Array[ChartSeries]
  combo_charts : Array[ChartComboOptions]
  mut format : GraphicOptions
  mut dimension : ChartDimension
  mut legend : ChartLegend
  mut title : String
  mut title_rich : Array[RichTextRun]?
  mut fill_color : String
  mut fill_transparency : Int
  mut border : ChartLine
  mut vary_colors : Bool
  mut x_axis : ChartAxis
  mut y_axis : ChartAxis
  mut plot_area : ChartPlotArea
  mut show_blanks_as : String
  mut gap_width : Int?
  mut overlap : Int?
  mut hole_size : Int?
  mut bubble_scale : Int?
} derive(Eq, Show)

///|
pub(all) struct ChartComboOptions {
  typ : ChartType
  series : Array[ChartSeries]
  mut x_axis : ChartAxis
  mut y_axis : ChartAxis
  mut plot_area : ChartPlotArea
  mut vary_colors : Bool
  mut gap_width : Int?
  mut overlap : Int?
  mut hole_size : Int?
  mut bubble_scale : Int?
} derive(Eq, Show)

///|
fn ChartComboOptions::from_chart_options(
  opts : ChartOptions,
) -> ChartComboOptions {
  {
    typ: opts.typ,
    series: opts.series,
    x_axis: opts.x_axis,
    y_axis: opts.y_axis,
    plot_area: opts.plot_area,
    vary_colors: opts.vary_colors,
    gap_width: opts.gap_width,
    overlap: opts.overlap,
    hole_size: opts.hole_size,
    bubble_scale: opts.bubble_scale,
  }
}

///|
pub fn ChartOptions::new(typ : ChartType) -> ChartOptions {
  {
    typ,
    series: [],
    combo_charts: [],
    format: GraphicOptions::new(),
    dimension: ChartDimension::new(),
    legend: ChartLegend::new(),
    title: "",
    title_rich: None,
    fill_color: "",
    fill_transparency: 0,
    border: ChartLine::new(),
    vary_colors: true,
    x_axis: ChartAxis::new(),
    y_axis: ChartAxis::new(),
    plot_area: ChartPlotArea::new(),
    show_blanks_as: "gap",
    gap_width: None,
    overlap: None,
    hole_size: None,
    bubble_scale: None,
  }
}

///|
pub fn ChartOptions::add_combo_chart(
  self : ChartOptions,
  combo : ChartOptions,
) -> Unit {
  self.combo_charts.push(ChartComboOptions::from_chart_options(combo))
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
    Col => ("barChart", Some("col"))
    ColStacked => ("barChart", Some("col"))
    ColPercentStacked => ("barChart", Some("col"))
    Bar => ("barChart", Some("bar"))
    BarStacked => ("barChart", Some("bar"))
    BarPercentStacked => ("barChart", Some("bar"))
    Col3D
    | Col3DClustered
    | Col3DStacked
    | Col3DPercentStacked
    | Col3DCone
    | Col3DConeClustered
    | Col3DConeStacked
    | Col3DConePercentStacked
    | Col3DPyramid
    | Col3DPyramidClustered
    | Col3DPyramidStacked
    | Col3DPyramidPercentStacked
    | Col3DCylinder
    | Col3DCylinderClustered
    | Col3DCylinderStacked
    | Col3DCylinderPercentStacked => ("bar3DChart", Some("col"))
    Bar3DClustered
    | Bar3DStacked
    | Bar3DPercentStacked
    | Bar3DConeClustered
    | Bar3DConeStacked
    | Bar3DConePercentStacked
    | Bar3DPyramidClustered
    | Bar3DPyramidStacked
    | Bar3DPyramidPercentStacked
    | Bar3DCylinderClustered
    | Bar3DCylinderStacked
    | Bar3DCylinderPercentStacked => ("bar3DChart", Some("bar"))
    Line => ("lineChart", None)
    Line3D => ("line3DChart", None)
    Area => ("areaChart", None)
    AreaStacked => ("areaChart", None)
    AreaPercentStacked => ("areaChart", None)
    Area3D => ("area3DChart", None)
    Area3DStacked => ("area3DChart", None)
    Area3DPercentStacked => ("area3DChart", None)
    Pie => ("pieChart", None)
    Pie3D => ("pie3DChart", None)
    PieOfPie => ("ofPieChart", None)
    BarOfPie => ("ofPieChart", None)
    Doughnut => ("doughnutChart", None)
    Radar => ("radarChart", None)
    Scatter => ("scatterChart", None)
    Bubble => ("bubbleChart", None)
    Bubble3D => ("bubbleChart", None)
    Surface3D | WireframeSurface3D => ("surface3DChart", None)
    Contour | WireframeContour => ("surfaceChart", None)
    StockHighLowClose => ("stockChart", None)
    StockOpenHighLowClose => ("stockChart", None)
  }
}

///|
fn chart_grouping(kind : ChartType) -> String? {
  match kind {
    Line | Line3D | Area | Area3D => Some("standard")
    Col | Bar | Col3DClustered | Bar3DClustered => Some("clustered")
    Col3DConeClustered
    | Bar3DConeClustered
    | Col3DPyramidClustered
    | Bar3DPyramidClustered
    | Col3DCylinderClustered
    | Bar3DCylinderClustered => Some("clustered")
    Col3D | Col3DCone | Col3DPyramid | Col3DCylinder => Some("standard")
    ColStacked
    | BarStacked
    | AreaStacked
    | Col3DStacked
    | Bar3DStacked
    | Area3DStacked
    | Col3DConeStacked
    | Bar3DConeStacked
    | Col3DPyramidStacked
    | Bar3DPyramidStacked
    | Col3DCylinderStacked
    | Bar3DCylinderStacked => Some("stacked")
    ColPercentStacked
    | BarPercentStacked
    | AreaPercentStacked
    | Col3DPercentStacked
    | Bar3DPercentStacked
    | Area3DPercentStacked
    | Col3DConePercentStacked
    | Bar3DConePercentStacked
    | Col3DPyramidPercentStacked
    | Bar3DPyramidPercentStacked
    | Col3DCylinderPercentStacked
    | Bar3DCylinderPercentStacked => Some("percentStacked")
    _ => None
  }
}

///|
fn plot_supports_vary_colors(plot_tag : StringView) -> Bool {
  plot_tag == "areaChart" ||
  plot_tag == "area3DChart" ||
  plot_tag == "barChart" ||
  plot_tag == "bar3DChart" ||
  plot_tag == "bubbleChart" ||
  plot_tag == "doughnutChart" ||
  plot_tag == "lineChart" ||
  plot_tag == "line3DChart" ||
  plot_tag == "ofPieChart" ||
  plot_tag == "pieChart" ||
  plot_tag == "pie3DChart" ||
  plot_tag == "radarChart" ||
  plot_tag == "scatterChart" ||
  plot_tag == "surface3DChart"
}

///|
fn write_plot_vary_colors(sb : StringBuilder, vary_colors : Bool) -> Unit {
  let value = if vary_colors { "1" } else { "0" }
  sb.write_view("        <c:varyColors val=\"\{value}\"/>\n")
}

///|
fn legend_position_value(position : String) -> String? {
  let normalized = position.trim().to_lower().to_string()
  match normalized {
    "none" => None
    "b" | "bottom" => Some("b")
    "t" | "top" => Some("t")
    "l" | "left" => Some("l")
    "r" | "right" => Some("r")
    "tr" | "topright" | "top_right" | "top-right" | "top right" => Some("tr")
    _ => Some(normalized)
  }
}

///|
fn chart_shape(kind : ChartType) -> String? {
  match kind {
    Bar3DConeClustered
    | Bar3DConeStacked
    | Bar3DConePercentStacked
    | Col3DCone
    | Col3DConeClustered
    | Col3DConeStacked
    | Col3DConePercentStacked => Some("cone")
    Bar3DPyramidClustered
    | Bar3DPyramidStacked
    | Bar3DPyramidPercentStacked
    | Col3DPyramid
    | Col3DPyramidClustered
    | Col3DPyramidStacked
    | Col3DPyramidPercentStacked => Some("pyramid")
    Bar3DCylinderClustered
    | Bar3DCylinderStacked
    | Bar3DCylinderPercentStacked
    | Col3DCylinder
    | Col3DCylinderClustered
    | Col3DCylinderStacked
    | Col3DCylinderPercentStacked => Some("cylinder")
    _ => None
  }
}

///|
fn write_drawingml_r_pr(
  sb : StringBuilder,
  indent : StringView,
  font : RichTextFont?,
) -> Unit {
  match font {
    Some(value) => {
      sb.write_view(indent)
      sb.write_view("<a:rPr")
      sb.write_view(" lang=\"en-US\"")
      if value.bold {
        sb.write_view(" b=\"1\"")
      }
      if value.italic {
        sb.write_view(" i=\"1\"")
      }
      if value.strike {
        sb.write_view(" strike=\"sngStrike\"")
      }
      match value.underline {
        Some(u) => {
          sb.write_view(" u=\"")
          sb.write_view(escape_xml_attr(u))
          sb.write_view("\"")
        }
        None => ()
      }
      match value.size {
        Some(size) =>
          sb.write_view(" sz=\"\{(size * 100.0).round().to_int()}\"")
        None => ()
      }
      sb.write_view(">")
      match value.family {
        Some(family) => {
          sb.write_view("<a:latin typeface=\"")
          sb.write_view(escape_xml_attr(family))
          sb.write_view("\"/>")
          sb.write_view("<a:ea typeface=\"")
          sb.write_view(escape_xml_attr(family))
          sb.write_view("\"/>")
          sb.write_view("<a:cs typeface=\"")
          sb.write_view(escape_xml_attr(family))
          sb.write_view("\"/>")
        }
        None => ()
      }
      match value.color {
        Some(color) => {
          let normalized = color.replace_all(old="#", new="").to_upper()
          sb.write_view("<a:solidFill><a:srgbClr val=\"")
          sb.write_view(escape_xml_attr(normalized))
          sb.write_view("\"/></a:solidFill>")
        }
        None => ()
      }
      sb.write_view("</a:rPr>\n")
    }
    None => {
      sb.write_view(indent)
      sb.write_view("<a:rPr lang=\"en-US\"/>\n")
    }
  }
}

///|
fn write_drawingml_run(
  sb : StringBuilder,
  indent : StringView,
  run : RichTextRun,
) -> Unit {
  sb.write_view(indent)
  sb.write_view("<a:r>\n")
  write_drawingml_r_pr(sb, "\{indent.to_string()}  ", run.font)
  let text_value = if run.text == "" { " " } else { run.text }
  sb.write_view(indent)
  if text_value.has_prefix(" ") ||
    text_value.has_suffix(" ") ||
    text_value.contains("\n") {
    sb.write_view("  <a:t xml:space=\"preserve\">")
  } else {
    sb.write_view("  <a:t>")
  }
  sb.write_view(escape_xml_text(text_value))
  sb.write_view("</a:t>\n")
  sb.write_view(indent)
  sb.write_view("</a:r>\n")
}

///|
fn write_chart_rich_tx(
  sb : StringBuilder,
  tx_indent : StringView,
  runs : ArrayView[RichTextRun],
) -> Unit {
  let base = tx_indent.to_string()
  sb.write_view(base)
  sb.write_view("<c:tx>\n")
  sb.write_view("\{base}  <c:rich>\n")
  sb.write_view("\{base}    <a:bodyPr/>\n")
  sb.write_view("\{base}    <a:lstStyle/>\n")
  sb.write_view("\{base}    <a:p>\n")
  let run_indent = "\{base}      "
  for run in runs {
    write_drawingml_run(sb, run_indent, run)
  }
  sb.write_view("\{base}    </a:p>\n")
  sb.write_view("\{base}  </c:rich>\n")
  sb.write_view(base)
  sb.write_view("</c:tx>\n")
}

///|
fn write_chart_title(
  sb : StringBuilder,
  title : String,
  title_rich : Array[RichTextRun]?,
) -> Unit {
  match title_rich {
    Some(runs) => {
      if runs.length() == 0 {
        return
      }
      sb.write_view("    <c:title>\n")
      write_chart_rich_tx(sb, "      ", runs[:])
      sb.write_view("    </c:title>\n")
    }
    None =>
      if title != "" {
        sb.write_view("    <c:title>\n")
        write_chart_rich_tx(sb, "      ", [{ text: title, font: None }][:])
        sb.write_view("    </c:title>\n")
      }
  }
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
fn chart_dash_value(dash : ChartDashType) -> StringView? {
  match dash {
    Unset => None
    Solid => Some("solid")
    Dot => Some("dot")
    Dash => Some("dash")
    LgDash => Some("lgDash")
    SashDot => Some("dashDot")
    LgDashDot => Some("lgDashDot")
    LgDashDotDot => Some("lgDashDotDot")
    SysDash => Some("sysDash")
    SysDot => Some("sysDot")
    SysDashDot => Some("sysDashDot")
    SysDashDotDot => Some("sysDashDotDot")
  }
}

///|
fn data_label_pos_value(pos : ChartDataLabelPositionType) -> StringView {
  match pos {
    Center => "ctr"
    Left => "l"
    Right => "r"
    Top => "t"
    Bottom => "b"
    BestFit => "bestFit"
    InEnd => "inEnd"
    OutEnd => "outEnd"
  }
}

///|
fn write_chart_series_sppr(sb : StringBuilder, series : ChartSeries) -> Unit {
  let line = series.line
  if series.fill_color == "" &&
    line.typ == Unset &&
    line.dash == Unset &&
    line.color == "" &&
    line.transparency == 0 &&
    line.width == 0.0 {
    return
  }
  sb.write_view("          <c:spPr>\n")
  if series.fill_color != "" {
    let fill = series.fill_color.replace_all(old="#", new="").to_upper()
    sb.write_view("            <a:solidFill><a:srgbClr val=\"")
    sb.write_view(escape_xml_attr(fill))
    let t = series.fill_transparency
    let transparency = if t < 0 { 0 } else if t > 100 { 100 } else { t }
    if transparency > 0 {
      let alpha = (100 - transparency) * 1000
      sb.write_view(
        "\"><a:alpha val=\"\{alpha}\"/></a:srgbClr></a:solidFill>\n",
      )
    } else {
      sb.write_view("\"/></a:solidFill>\n")
    }
  }
  if line.typ == NoLine {
    sb.write_view("            <a:ln><a:noFill/></a:ln>\n")
    sb.write_view("          </c:spPr>\n")
    return
  }
  sb.write_view("            <a:ln")
  if line.width > 0.0 {
    let w = (line.width * 12700.0).round().to_int()
    sb.write_view(" w=\"\{w}\"")
  }
  let dash = chart_dash_value(line.dash)
  if line.color == "" && dash is None {
    sb.write_view("/>\n")
    sb.write_view("          </c:spPr>\n")
    return
  }
  sb.write_view(">\n")
  if line.color != "" {
    let color = line.color.replace_all(old="#", new="").to_upper()
    sb.write_view("              <a:solidFill><a:srgbClr val=\"")
    sb.write_view(escape_xml_attr(color))
    let t = line.transparency
    let transparency = if t < 0 { 0 } else if t > 100 { 100 } else { t }
    if transparency > 0 {
      let alpha = (100 - transparency) * 1000
      sb.write_view(
        "\"><a:alpha val=\"\{alpha}\"/></a:srgbClr></a:solidFill>\n",
      )
    } else {
      sb.write_view("\"/></a:solidFill>\n")
    }
  }
  match dash {
    Some(value) => {
      sb.write_view("              <a:prstDash val=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"/>\n")
    }
    None => ()
  }
  sb.write_view("            </a:ln>\n")
  sb.write_view("          </c:spPr>\n")
}

///|
fn write_chart_series_marker(sb : StringBuilder, marker : ChartMarker) -> Unit {
  let border = marker.border
  let has_border = border.typ != Unset ||
    border.dash != Unset ||
    border.color != "" ||
    border.width != 0.0
  let has_fill = marker.fill_color != ""
  if marker.symbol == "" && marker.size == 0 && !has_border && !has_fill {
    return
  }
  let sym = if marker.symbol == "" { "auto" } else { marker.symbol }
  sb.write_view("          <c:marker>\n")
  sb.write_view("            <c:symbol val=\"")
  sb.write_view(escape_xml_attr(sym))
  sb.write_view("\"/>\n")
  if marker.size > 0 {
    sb.write_view("            <c:size val=\"\{marker.size}\"/>\n")
  }
  if has_border || has_fill {
    sb.write_view("            <c:spPr>\n")
    if has_fill {
      let fill = marker.fill_color.replace_all(old="#", new="").to_upper()
      sb.write_view("              <a:solidFill><a:srgbClr val=\"")
      sb.write_view(escape_xml_attr(fill))
      let t = marker.fill_transparency
      let transparency = if t < 0 { 0 } else if t > 100 { 100 } else { t }
      if transparency > 0 {
        let alpha = (100 - transparency) * 1000
        sb.write_view(
          "\"><a:alpha val=\"\{alpha}\"/></a:srgbClr></a:solidFill>\n",
        )
      } else {
        sb.write_view("\"/></a:solidFill>\n")
      }
    }
    if has_border {
      if border.typ == NoLine {
        sb.write_view("              <a:ln><a:noFill/></a:ln>\n")
      } else {
        sb.write_view("              <a:ln")
        if border.width > 0.0 {
          let w = (border.width * 12700.0).round().to_int()
          sb.write_view(" w=\"\{w}\"")
        }
        let dash = chart_dash_value(border.dash)
        if border.color == "" && dash is None {
          sb.write_view("/>\n")
        } else {
          sb.write_view(">\n")
          if border.color != "" {
            let color = border.color.replace_all(old="#", new="").to_upper()
            sb.write_view("                <a:solidFill><a:srgbClr val=\"")
            sb.write_view(escape_xml_attr(color))
            let t = border.transparency
            let transparency = if t < 0 { 0 } else if t > 100 { 100 } else { t }
            if transparency > 0 {
              let alpha = (100 - transparency) * 1000
              sb.write_view(
                "\"><a:alpha val=\"\{alpha}\"/></a:srgbClr></a:solidFill>\n",
              )
            } else {
              sb.write_view("\"/></a:solidFill>\n")
            }
          }
          match dash {
            Some(value) => {
              sb.write_view("                <a:prstDash val=\"")
              sb.write_view(escape_xml_attr(value))
              sb.write_view("\"/>\n")
            }
            None => ()
          }
          sb.write_view("              </a:ln>\n")
        }
      }
    }
    sb.write_view("            </c:spPr>\n")
  }
  sb.write_view("          </c:marker>\n")
}

///|
fn write_chart_series_dlbls(sb : StringBuilder, series : ChartSeries) -> Unit {
  let pos_set = series.data_label_position != BestFit
  let has_font = series.data_label.font != Font::new()
  let has_alignment = series.data_label.alignment != Alignment::new()
  let has_fill = series.data_label.fill_color != ""
  if !pos_set && !has_font && !has_alignment && !has_fill {
    return
  }
  sb.write_view("          <c:dLbls>\n")
  if pos_set {
    sb.write_view("            <c:dLblPos val=\"")
    sb.write_view(
      escape_xml_attr(data_label_pos_value(series.data_label_position)),
    )
    sb.write_view("\"/>\n")
  }
  if has_fill {
    let fill = series.data_label.fill_color
      .replace_all(old="#", new="")
      .to_upper()
    sb.write_view("            <c:spPr>\n")
    sb.write_view("              <a:solidFill><a:srgbClr val=\"")
    sb.write_view(escape_xml_attr(fill))
    let t = series.data_label.fill_transparency
    let transparency = if t < 0 { 0 } else if t > 100 { 100 } else { t }
    if transparency > 0 {
      let alpha = (100 - transparency) * 1000
      sb.write_view(
        "\"><a:alpha val=\"\{alpha}\"/></a:srgbClr></a:solidFill>\n",
      )
    } else {
      sb.write_view("\"/></a:solidFill>\n")
    }
    sb.write_view("            </c:spPr>\n")
  }
  if has_font || has_alignment {
    write_drawingml_tx_pr_with_font_and_alignment(
      sb,
      "            ",
      series.data_label.font,
      series.data_label.alignment,
    )
  }
  sb.write_view("          </c:dLbls>\n")
}

///|
fn write_chart_series_dpt(sb : StringBuilder, point : ChartDataPoint) -> Unit {
  if point.fill_color == "" {
    return
  }
  let color = point.fill_color.replace_all(old="#", new="").to_upper()
  sb.write_view("          <c:dPt>\n")
  sb.write_view("            <c:idx val=\"\{point.index}\"/>\n")
  sb.write_view("            <c:spPr>\n")
  sb.write_view("              <a:solidFill><a:srgbClr val=\"")
  sb.write_view(escape_xml_attr(color))
  sb.write_view("\"/></a:solidFill>\n")
  sb.write_view("            </c:spPr>\n")
  sb.write_view("          </c:dPt>\n")
}

///|
fn write_chart_series(
  sb : StringBuilder,
  series : ChartSeries,
  idx : Int,
  order_base : Int,
) -> Unit {
  let global_idx = order_base + idx
  sb.write_view("        <c:ser>\n")
  sb.write_view("          <c:idx val=\"\{global_idx}\"/>\n")
  sb.write_view("          <c:order val=\"\{global_idx}\"/>\n")
  write_chart_series_tx(sb, series.name)
  write_chart_series_sppr(sb, series)
  write_chart_series_marker(sb, series.marker)
  if series.line.smooth {
    sb.write_view("          <c:smooth val=\"1\"/>\n")
  }
  for point in series.data_point {
    write_chart_series_dpt(sb, point)
  }
  write_chart_series_dlbls(sb, series)
  sb.write_view("          <c:cat><c:strRef><c:f>")
  sb.write_view(escape_xml_text(series.categories))
  sb.write_view("</c:f></c:strRef></c:cat>\n")
  sb.write_view("          <c:val><c:numRef><c:f>")
  sb.write_view(escape_xml_text(series.values))
  sb.write_view("</c:f></c:numRef></c:val>\n")
  sb.write_view("        </c:ser>\n")
}

///|
fn write_chart_series_scatter(
  sb : StringBuilder,
  series : ChartSeries,
  idx : Int,
  order_base : Int,
) -> Unit {
  let global_idx = order_base + idx
  sb.write_view("        <c:ser>\n")
  sb.write_view("          <c:idx val=\"\{global_idx}\"/>\n")
  sb.write_view("          <c:order val=\"\{global_idx}\"/>\n")
  write_chart_series_tx(sb, series.name)
  write_chart_series_sppr(sb, series)
  write_chart_series_marker(sb, series.marker)
  if series.line.smooth {
    sb.write_view("          <c:smooth val=\"1\"/>\n")
  }
  for point in series.data_point {
    write_chart_series_dpt(sb, point)
  }
  write_chart_series_dlbls(sb, series)
  sb.write_view("          <c:xVal><c:numRef><c:f>")
  sb.write_view(escape_xml_text(series.categories))
  sb.write_view("</c:f></c:numRef></c:xVal>\n")
  sb.write_view("          <c:yVal><c:numRef><c:f>")
  sb.write_view(escape_xml_text(series.values))
  sb.write_view("</c:f></c:numRef></c:yVal>\n")
  sb.write_view("        </c:ser>\n")
}

///|
fn write_chart_series_for_plot(
  sb : StringBuilder,
  plot_tag : StringView,
  series : ChartSeries,
  idx : Int,
  order_base : Int,
) -> Unit raise XlsxError {
  if plot_tag == "scatterChart" {
    write_chart_series_scatter(sb, series, idx, order_base)
  } else if plot_tag == "bubbleChart" {
    let bubble_size = match series.bubble_size {
      Some(value) => value
      None => raise InvalidSheetOperation(msg="bubble size missing")
    }
    let global_idx = order_base + idx
    sb.write_view("        <c:ser>\n")
    sb.write_view("          <c:idx val=\"\{global_idx}\"/>\n")
    sb.write_view("          <c:order val=\"\{global_idx}\"/>\n")
    write_chart_series_tx(sb, series.name)
    write_chart_series_sppr(sb, series)
    write_chart_series_marker(sb, series.marker)
    if series.line.smooth {
      sb.write_view("          <c:smooth val=\"1\"/>\n")
    }
    for point in series.data_point {
      write_chart_series_dpt(sb, point)
    }
    write_chart_series_dlbls(sb, series)
    sb.write_view("          <c:xVal><c:numRef><c:f>")
    sb.write_view(escape_xml_text(series.categories))
    sb.write_view("</c:f></c:numRef></c:xVal>\n")
    sb.write_view("          <c:yVal><c:numRef><c:f>")
    sb.write_view(escape_xml_text(series.values))
    sb.write_view("</c:f></c:numRef></c:yVal>\n")
    sb.write_view("          <c:bubbleSize><c:numRef><c:f>")
    sb.write_view(escape_xml_text(bubble_size))
    sb.write_view("</c:f></c:numRef></c:bubbleSize>\n")
    sb.write_view("        </c:ser>\n")
  } else {
    write_chart_series(sb, series, idx, order_base)
  }
}

///|
fn write_chart_sppr(
  sb : StringBuilder,
  fill_color : String,
  border : ChartLine,
) -> Unit {
  if fill_color == "" &&
    (border.typ == Unset || border.typ == Automatic) &&
    border.dash == Unset &&
    border.color == "" &&
    border.transparency == 0 &&
    border.width == 0.0 {
    return
  }
  sb.write_view("            <c:spPr>\n")
  if fill_color != "" {
    let fill = fill_color.replace_all(old="#", new="").to_upper()
    sb.write_view("              <a:solidFill><a:srgbClr val=\"")
    sb.write_view(escape_xml_attr(fill))
    sb.write_view("\"/></a:solidFill>\n")
  }
  if border.typ == NoLine {
    sb.write_view("              <a:ln><a:noFill/></a:ln>\n")
  } else if border.color != "" || border.width != 0.0 || border.dash != Unset {
    sb.write_view("              <a:ln")
    if border.width > 0.0 {
      let w = (border.width * 12700.0).round().to_int()
      sb.write_view(" w=\"\{w}\"")
    }
    let dash = chart_dash_value(border.dash)
    if border.color == "" && dash is None {
      sb.write_view("/>\n")
    } else {
      sb.write_view(">\n")
      if border.color != "" {
        let color = border.color.replace_all(old="#", new="").to_upper()
        sb.write_view("                <a:solidFill><a:srgbClr val=\"")
        sb.write_view(escape_xml_attr(color))
        let t = border.transparency
        let transparency = if t < 0 { 0 } else if t > 100 { 100 } else { t }
        if transparency > 0 {
          let alpha = (100 - transparency) * 1000
          sb.write_view(
            "\"><a:alpha val=\"\{alpha}\"/></a:srgbClr></a:solidFill>\n",
          )
        } else {
          sb.write_view("\"/></a:solidFill>\n")
        }
      }
      match dash {
        Some(value) => {
          sb.write_view("                <a:prstDash val=\"")
          sb.write_view(escape_xml_attr(value))
          sb.write_view("\"/>\n")
        }
        None => ()
      }
      sb.write_view("              </a:ln>\n")
    }
  }
  sb.write_view("            </c:spPr>\n")
}

///|
fn tick_label_pos_value(pos : ChartTickLabelPositionType) -> StringView {
  match pos {
    NextToAxis => "nextTo"
    High => "high"
    Low => "low"
    NoTickLabels => "none"
  }
}

///|
fn val_axis_tick_label_pos(
  kind : ChartType,
  pos : ChartTickLabelPositionType,
) -> StringView {
  match kind {
    Contour | WireframeContour => "none"
    _ => tick_label_pos_value(pos)
  }
}

///|
fn val_axis_cross_between(kind : ChartType) -> StringView {
  match kind {
    Area
    | AreaStacked
    | AreaPercentStacked
    | Area3D
    | Area3DStacked
    | Area3DPercentStacked
    | Surface3D
    | WireframeSurface3D
    | Contour
    | WireframeContour
    | Bubble
    | Bubble3D => "midCat"
    _ => "between"
  }
}

///|
fn axis_position_value(
  axis_tag : StringView,
  axis : ChartAxis,
  axis_pos : StringView,
) -> StringView {
  if !axis.reverse_order {
    return axis_pos
  }
  if axis_pos == "b" &&
    (axis_tag == "catAx" || axis_tag == "dateAx" || axis_tag == "serAx") {
    return "t"
  }
  if axis_pos == "l" && axis_tag == "valAx" {
    return "r"
  }
  axis_pos
}

///|
fn axis_crosses_value(
  axis_tag : StringView,
  axis_pos : StringView,
) -> StringView? {
  if axis_tag == "valAx" {
    if axis_pos == "r" {
      Some("max")
    } else {
      Some("autoZero")
    }
  } else if axis_tag == "catAx" || axis_tag == "dateAx" {
    Some("autoZero")
  } else {
    None
  }
}

///|
fn axis_id_or_default(axis : ChartAxis, fallback : Int) -> Int {
  if axis.ax_id > 0 {
    axis.ax_id
  } else {
    fallback
  }
}

///|
fn write_axis_title(
  sb : StringBuilder,
  title : String,
  title_rich : Array[RichTextRun]?,
) -> Unit {
  match title_rich {
    Some(runs) => {
      if runs.length() == 0 {
        return
      }
      sb.write_view("        <c:title>\n")
      write_chart_rich_tx(sb, "          ", runs[:])
      sb.write_view("        </c:title>\n")
    }
    None =>
      if title != "" {
        sb.write_view("        <c:title>\n")
        write_chart_rich_tx(sb, "          ", [{ text: title, font: None }][:])
        sb.write_view("        </c:title>\n")
      }
  }
}

///|
fn write_axis_num_fmt(sb : StringBuilder, fmt : ChartNumFmt) -> Unit {
  if fmt.custom_num_fmt == "" && fmt.source_linked {
    return
  }
  let code = if fmt.custom_num_fmt == "" {
    "General"
  } else {
    fmt.custom_num_fmt
  }
  sb.write_view("        <c:numFmt formatCode=\"")
  sb.write_view(escape_xml_attr(code))
  sb.write_view("\" sourceLinked=\"")
  sb.write_view(if fmt.source_linked { "1" } else { "0" })
  sb.write_view("\"/>\n")
}

///|
fn drawingml_text_vertical_value(value : StringView) -> StringView? {
  match value {
    "horz" => Some("horz")
    "vert" => Some("vert")
    "vert270" => Some("vert270")
    "wordArtVert" => Some("wordArtVert")
    "eaVert" => Some("eaVert")
    "mongolianVert" => Some("mongolianVert")
    "wordArtVertRtl" => Some("wordArtVertRtl")
    _ => None
  }
}

///|
fn drawingml_paragraph_align_value(value : StringView) -> StringView? {
  match value {
    "left" => Some("l")
    "center" => Some("ctr")
    "right" => Some("r")
    "justify" => Some("just")
    "distributed" => Some("dist")
    "centerContinuous" => Some("ctr")
    _ => None
  }
}

///|
fn drawingml_underline_value(value : StringView) -> StringView? {
  match value {
    "none" => Some("none")
    "words" => Some("words")
    "sng" => Some("sng")
    "dbl" => Some("dbl")
    "heavy" => Some("heavy")
    "dotted" => Some("dotted")
    "dottedHeavy" => Some("dottedHeavy")
    "dash" => Some("dash")
    "dashHeavy" => Some("dashHeavy")
    "dashLong" => Some("dashLong")
    "dashLongHeavy" => Some("dashLongHeavy")
    "dotDash" => Some("dotDash")
    "dotDashHeavy" => Some("dotDashHeavy")
    "dotDotDash" => Some("dotDotDash")
    "dotDotDashHeavy" => Some("dotDotDashHeavy")
    "wavy" => Some("wavy")
    "wavyHeavy" => Some("wavyHeavy")
    "wavyDbl" => Some("wavyDbl")
    _ => None
  }
}

///|
fn write_drawingml_def_r_pr_from_font(
  sb : StringBuilder,
  indent : StringView,
  font : Font,
) -> Unit {
  sb.write_view(indent)
  sb.write_view("<a:defRPr")
  match font.bold {
    Some(true) => sb.write_view(" b=\"1\"")
    _ => ()
  }
  match font.italic {
    Some(true) => sb.write_view(" i=\"1\"")
    _ => ()
  }
  match font.strike {
    Some(true) => sb.write_view(" strike=\"sngStrike\"")
    _ => ()
  }
  match font.underline {
    Some(u) =>
      match drawingml_underline_value(u) {
        Some(v) => sb.write_view(" u=\"\{v.to_string()}\"")
        None => ()
      }
    None => ()
  }
  match font.size {
    Some(size) =>
      if size > 0.0 {
        sb.write_view(" sz=\"\{(size * 100.0).round().to_int()}\"")
      }
    None => ()
  }
  sb.write_view(">")
  match font.family {
    Some(family) => {
      sb.write_view("<a:latin typeface=\"")
      sb.write_view(escape_xml_attr(family))
      sb.write_view("\"/>")
      sb.write_view("<a:ea typeface=\"")
      sb.write_view(escape_xml_attr(family))
      sb.write_view("\"/>")
      sb.write_view("<a:cs typeface=\"")
      sb.write_view(escape_xml_attr(family))
      sb.write_view("\"/>")
    }
    None => ()
  }
  match font.color {
    Some(color) => {
      let normalized = color.replace_all(old="#", new="").to_upper()
      sb.write_view("<a:solidFill><a:srgbClr val=\"")
      sb.write_view(escape_xml_attr(normalized))
      sb.write_view("\"/></a:solidFill>")
    }
    None => ()
  }
  sb.write_view("</a:defRPr>\n")
}

///|
fn write_drawingml_tx_pr_with_font(
  sb : StringBuilder,
  tx_pr_indent : StringView,
  font : Font,
) -> Unit {
  let base = tx_pr_indent.to_string()
  sb.write_view(base)
  sb.write_view("<c:txPr>\n")
  sb.write_view("\{base}  <a:bodyPr/>\n")
  sb.write_view("\{base}  <a:lstStyle/>\n")
  sb.write_view("\{base}  <a:p>\n")
  sb.write_view("\{base}    <a:pPr>\n")
  write_drawingml_def_r_pr_from_font(sb, "\{base}      ", font)
  sb.write_view("\{base}    </a:pPr>\n")
  sb.write_view("\{base}    <a:endParaRPr lang=\"en-US\"/>\n")
  sb.write_view("\{base}  </a:p>\n")
  sb.write_view(base)
  sb.write_view("</c:txPr>\n")
}

///|
fn write_drawingml_tx_pr_with_font_and_alignment(
  sb : StringBuilder,
  tx_pr_indent : StringView,
  font : Font,
  alignment : Alignment,
) -> Unit {
  let base = tx_pr_indent.to_string()
  sb.write_view(base)
  sb.write_view("<c:txPr>\n")
  sb.write_view("\{base}  <a:bodyPr")
  match alignment.text_rotation {
    Some(value) =>
      if value >= -90 && value <= 90 {
        sb.write_view(" rot=\"\{value * 60000}\"")
      }
    None => ()
  }
  match alignment.vertical {
    Some(value) =>
      match drawingml_text_vertical_value(value) {
        Some(v) => sb.write_view(" vert=\"\{v.to_string()}\"")
        None => ()
      }
    None => ()
  }
  sb.write_view("/>\n")
  sb.write_view("\{base}  <a:lstStyle/>\n")
  sb.write_view("\{base}  <a:p>\n")
  let algn = match alignment.horizontal {
    Some(v) => drawingml_paragraph_align_value(v)
    None => None
  }
  match algn {
    Some(v) => sb.write_view("\{base}    <a:pPr algn=\"\{v.to_string()}\">\n")
    None => sb.write_view("\{base}    <a:pPr>\n")
  }
  if font == Font::new() {
    sb.write_view("\{base}      <a:defRPr/>\n")
  } else {
    write_drawingml_def_r_pr_from_font(sb, "\{base}      ", font)
  }
  sb.write_view("\{base}    </a:pPr>\n")
  sb.write_view("\{base}    <a:endParaRPr lang=\"en-US\"/>\n")
  sb.write_view("\{base}  </a:p>\n")
  sb.write_view(base)
  sb.write_view("</c:txPr>\n")
}

///|
fn write_axis_tx_pr(sb : StringBuilder, axis : ChartAxis) -> Unit {
  let has_font = axis.font != Font::new()
  let mut needs = has_font
  match axis.alignment.text_rotation {
    Some(_) => needs = true
    None => ()
  }
  match axis.alignment.vertical {
    Some(_) => needs = true
    None => ()
  }
  if !needs {
    return
  }
  sb.write_view("        <c:txPr>\n")
  sb.write_view("          <a:bodyPr")
  match axis.alignment.text_rotation {
    Some(value) =>
      if value >= -90 && value <= 90 {
        sb.write_view(" rot=\"\{value * 60000}\"")
      }
    None => ()
  }
  match axis.alignment.vertical {
    Some(value) =>
      match drawingml_text_vertical_value(value) {
        Some(v) => sb.write_view(" vert=\"\{v.to_string()}\"")
        None => ()
      }
    None => ()
  }
  sb.write_view("/>\n")
  sb.write_view("          <a:lstStyle/>\n")
  sb.write_view("          <a:p>\n")
  sb.write_view("            <a:pPr>\n")
  if !has_font {
    sb.write_view("              <a:defRPr/>\n")
  } else {
    write_drawingml_def_r_pr_from_font(sb, "              ", axis.font)
  }
  sb.write_view("            </a:pPr>\n")
  sb.write_view("            <a:endParaRPr lang=\"en-US\"/>\n")
  sb.write_view("          </a:p>\n")
  sb.write_view("        </c:txPr>\n")
}

///|
fn write_axis(
  sb : StringBuilder,
  axis_tag : StringView,
  axis : ChartAxis,
  ax_id : Int,
  cross_ax_id : Int,
  axis_pos : StringView,
  kind : ChartType,
) -> Unit {
  let is_category_like = axis_tag == "catAx" || axis_tag == "dateAx"
  let is_value_like = axis_tag == "valAx"
  let resolved_axis_pos = axis_position_value(axis_tag, axis, axis_pos)
  sb.write_view("      <c:\{axis_tag.to_string()}>\n")
  sb.write_view("        <c:axId val=\"\{ax_id}\"/>\n")
  sb.write_view("        <c:scaling>")
  if axis.reverse_order {
    sb.write_view("<c:orientation val=\"maxMin\"/>")
  } else {
    sb.write_view("<c:orientation val=\"minMax\"/>")
  }
  match axis.log_base {
    0.0 => ()
    value => sb.write_view("<c:logBase val=\"\{value}\"/>")
  }
  match axis.maximum {
    Some(value) => sb.write_view("<c:max val=\"\{value}\"/>")
    None => ()
  }
  match axis.minimum {
    Some(value) => sb.write_view("<c:min val=\"\{value}\"/>")
    None => ()
  }
  sb.write_view("</c:scaling>\n")
  sb.write_view("        <c:delete val=\"")
  sb.write_view(if axis.none { "1" } else { "0" })
  sb.write_view("\"/>\n")
  sb.write_view("        <c:axPos val=\"")
  sb.write_view(escape_xml_attr(resolved_axis_pos))
  sb.write_view("\"/>\n")
  if axis.major_grid_lines {
    sb.write_view("        <c:majorGridlines/>\n")
  }
  if axis.minor_grid_lines {
    sb.write_view("        <c:minorGridlines/>\n")
  }
  write_axis_title(sb, axis.title, axis.title_rich)
  write_axis_num_fmt(sb, axis.num_fmt)
  if axis_tag != "serAx" {
    sb.write_view("        <c:majorTickMark val=\"none\"/>\n")
    sb.write_view("        <c:minorTickMark val=\"none\"/>\n")
  }
  let tick_lbl_pos = if is_value_like {
    val_axis_tick_label_pos(kind, axis.tick_label_position)
  } else {
    tick_label_pos_value(axis.tick_label_position)
  }
  sb.write_view("        <c:tickLblPos val=\"")
  sb.write_view(escape_xml_attr(tick_lbl_pos))
  sb.write_view("\"/>\n")
  write_axis_tx_pr(sb, axis)
  sb.write_view("        <c:crossAx val=\"\{cross_ax_id}\"/>\n")
  match axis_crosses_value(axis_tag, resolved_axis_pos) {
    Some(value) => {
      sb.write_view("        <c:crosses val=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"/>\n")
    }
    None => ()
  }
  if is_value_like {
    sb.write_view("        <c:crossBetween val=\"")
    sb.write_view(escape_xml_attr(val_axis_cross_between(kind)))
    sb.write_view("\"/>\n")
  }
  if is_category_like {
    sb.write_view("        <c:auto val=\"1\"/>\n")
    sb.write_view("        <c:lblAlgn val=\"ctr\"/>\n")
    sb.write_view("        <c:lblOffset val=\"100\"/>\n")
    sb.write_view("        <c:noMultiLvlLbl val=\"0\"/>\n")
  }
  if is_category_like && axis.tick_label_skip > 0 {
    sb.write_view("        <c:tickLblSkip val=\"\{axis.tick_label_skip}\"/>\n")
  }
  if is_value_like && axis.major_unit > 0.0 {
    sb.write_view("        <c:majorUnit val=\"\{axis.major_unit}\"/>\n")
  }
  sb.write_view("      </c:\{axis_tag.to_string()}>\n")
}

///|
fn write_chart_dlbls(
  sb : StringBuilder,
  plot_tag : StringView,
  show_legend_key : Bool,
  plot_area : ChartPlotArea,
) -> Unit {
  if plot_tag == "surface3DChart" || plot_tag == "surfaceChart" {
    return
  }
  let fmt = plot_area.num_fmt
  let need_num_fmt = fmt.custom_num_fmt != "" || !fmt.source_linked
  let has_flags = show_legend_key ||
    plot_area.show_val ||
    plot_area.show_cat_name ||
    plot_area.show_ser_name ||
    plot_area.show_percent ||
    plot_area.show_leader_lines ||
    plot_area.show_bubble_size ||
    need_num_fmt
  if !has_flags {
    return
  }
  sb.write_view("        <c:dLbls>\n")
  if need_num_fmt {
    let code = if fmt.custom_num_fmt == "" {
      "General"
    } else {
      fmt.custom_num_fmt
    }
    sb.write_view("          <c:numFmt formatCode=\"")
    sb.write_view(escape_xml_attr(code))
    sb.write_view("\" sourceLinked=\"")
    sb.write_view(if fmt.source_linked { "1" } else { "0" })
    sb.write_view("\"/>\n")
  }
  if show_legend_key {
    sb.write_view("          <c:showLegendKey val=\"1\"/>\n")
  }
  if plot_area.show_val {
    sb.write_view("          <c:showVal val=\"1\"/>\n")
  }
  if plot_area.show_cat_name {
    sb.write_view("          <c:showCatName val=\"1\"/>\n")
  }
  if plot_area.show_ser_name {
    sb.write_view("          <c:showSerName val=\"1\"/>\n")
  }
  if plot_area.show_percent {
    sb.write_view("          <c:showPercent val=\"1\"/>\n")
  }
  if plot_area.show_leader_lines {
    sb.write_view("          <c:showLeaderLines val=\"1\"/>\n")
  }
  if plot_area.show_bubble_size {
    sb.write_view("          <c:showBubbleSize val=\"1\"/>\n")
  }
  sb.write_view("        </c:dLbls>\n")
}

///|
fn write_plot_area_sppr(sb : StringBuilder, opts : ChartOptions) -> Unit {
  let fill_color = opts.plot_area.fill_color
  if fill_color == "" {
    return
  }
  let fill = fill_color.replace_all(old="#", new="").to_upper()
  sb.write_view("      <c:spPr>\n")
  sb.write_view("        <a:solidFill><a:srgbClr val=\"")
  sb.write_view(escape_xml_attr(fill))
  let t = opts.plot_area.fill_transparency
  let transparency = if t < 0 { 0 } else if t > 100 { 100 } else { t }
  if transparency > 0 {
    let alpha = (100 - transparency) * 1000
    sb.write_view("\"><a:alpha val=\"\{alpha}\"/></a:srgbClr></a:solidFill>\n")
  } else {
    sb.write_view("\"/></a:solidFill>\n")
  }
  sb.write_view("      </c:spPr>\n")
}

///|
fn write_plot_area_d_table(
  sb : StringBuilder,
  plot_tag : StringView,
  opts : ChartOptions,
) -> Unit {
  if !opts.plot_area.show_data_table {
    return
  }
  if plot_tag != "barChart" &&
    plot_tag != "bar3DChart" &&
    plot_tag != "areaChart" &&
    plot_tag != "area3DChart" &&
    plot_tag != "lineChart" &&
    plot_tag != "line3DChart" {
    return
  }
  sb.write_view("      <c:dTable>\n")
  sb.write_view("        <c:showHorzBorder val=\"1\"/>\n")
  sb.write_view("        <c:showVertBorder val=\"1\"/>\n")
  sb.write_view("        <c:showOutline val=\"1\"/>\n")
  if opts.plot_area.show_data_table_keys {
    sb.write_view("        <c:showKeys val=\"1\"/>\n")
  } else {
    sb.write_view("        <c:showKeys val=\"0\"/>\n")
  }
  sb.write_view("      </c:dTable>\n")
}

///|
fn write_chart_sppr_root(sb : StringBuilder, opts : ChartOptions) -> Unit {
  if opts.fill_color == "" &&
    (opts.border.typ == Unset || opts.border.typ == Automatic) &&
    opts.border.dash == Unset &&
    opts.border.color == "" &&
    opts.border.transparency == 0 &&
    opts.border.width == 0.0 {
    return
  }
  sb.write_view("    <c:spPr>\n")
  if opts.fill_color != "" {
    let fill = opts.fill_color.replace_all(old="#", new="").to_upper()
    sb.write_view("      <a:solidFill><a:srgbClr val=\"")
    sb.write_view(escape_xml_attr(fill))
    let t = opts.fill_transparency
    let transparency = if t < 0 { 0 } else if t > 100 { 100 } else { t }
    if transparency > 0 {
      let alpha = (100 - transparency) * 1000
      sb.write_view(
        "\"><a:alpha val=\"\{alpha}\"/></a:srgbClr></a:solidFill>\n",
      )
    } else {
      sb.write_view("\"/></a:solidFill>\n")
    }
  }
  let border = opts.border
  if border.typ == NoLine {
    sb.write_view("      <a:ln><a:noFill/></a:ln>\n")
  } else if border.color != "" || border.width != 0.0 || border.dash != Unset {
    sb.write_view("      <a:ln")
    if border.width > 0.0 {
      let w = (border.width * 12700.0).round().to_int()
      sb.write_view(" w=\"\{w}\"")
    }
    let dash = chart_dash_value(border.dash)
    if border.color == "" && dash is None {
      sb.write_view("/>\n")
    } else {
      sb.write_view(">\n")
      if border.color != "" {
        let color = border.color.replace_all(old="#", new="").to_upper()
        sb.write_view("        <a:solidFill><a:srgbClr val=\"")
        sb.write_view(escape_xml_attr(color))
        let t = border.transparency
        let transparency = if t < 0 { 0 } else if t > 100 { 100 } else { t }
        if transparency > 0 {
          let alpha = (100 - transparency) * 1000
          sb.write_view(
            "\"><a:alpha val=\"\{alpha}\"/></a:srgbClr></a:solidFill>\n",
          )
        } else {
          sb.write_view("\"/></a:solidFill>\n")
        }
      }
      match dash {
        Some(value) => {
          sb.write_view("        <a:prstDash val=\"")
          sb.write_view(escape_xml_attr(value))
          sb.write_view("\"/>\n")
        }
        None => ()
      }
      sb.write_view("      </a:ln>\n")
    }
  }
  sb.write_view("    </c:spPr>\n")
}

///|
pub fn chart_options_to_xml(opts : ChartOptions) -> String raise XlsxError {
  if opts.series.length() == 0 {
    raise InvalidSheetOperation(msg="chart series empty")
  }
  if opts.combo_charts.length() > 0 {
    for combo in opts.combo_charts {
      if combo.series.length() == 0 {
        raise InvalidSheetOperation(msg="combo chart series empty")
      }
    }
  }
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n",
  )
  sb.write_view("  <c:chart>\n")
  write_chart_title(sb, opts.title, opts.title_rich)
  sb.write_view("    <c:plotArea>\n")
  sb.write_view("      <c:layout/>\n")
  write_plot_area_sppr(sb, opts)
  let has_combo = opts.combo_charts.length() > 0
  if !has_combo {
    let (plot_tag, bar_dir) = chart_type_to_plot(opts.typ)
    if plot_tag == "" {
      raise UnsupportedFeature(msg="unsupported chart type")
    }
    if plot_tag == "stockChart" {
      let expected = match opts.typ {
        StockHighLowClose => 3
        StockOpenHighLowClose => 4
        _ => 0
      }
      if expected > 0 && opts.series.length() != expected {
        raise InvalidSheetOperation(
          msg="stock chart requires \{expected} series",
        )
      }
    }
    sb.write_view("      <c:\{plot_tag}>\n")
    if plot_tag == "barChart" || plot_tag == "bar3DChart" {
      match bar_dir {
        Some(dir) => {
          sb.write_view("        <c:barDir val=\"")
          sb.write_view(escape_xml_attr(dir))
          sb.write_view("\"/>\n")
        }
        None => ()
      }
    }
    if plot_tag == "barChart" ||
      plot_tag == "bar3DChart" ||
      plot_tag == "lineChart" ||
      plot_tag == "line3DChart" ||
      plot_tag == "areaChart" ||
      plot_tag == "area3DChart" {
      match chart_grouping(opts.typ) {
        Some(value) => {
          sb.write_view("        <c:grouping val=\"")
          sb.write_view(escape_xml_attr(value))
          sb.write_view("\"/>\n")
        }
        None => ()
      }
    }
    if plot_tag == "scatterChart" {
      sb.write_view("        <c:scatterStyle val=\"lineMarker\"/>\n")
    }
    if plot_tag == "radarChart" {
      sb.write_view("        <c:radarStyle val=\"standard\"/>\n")
    }
    if plot_tag == "ofPieChart" {
      let typ = if opts.typ == BarOfPie { "bar" } else { "pie" }
      sb.write_view("        <c:ofPieType val=\"")
      sb.write_view(escape_xml_attr(typ))
      sb.write_view("\"/>\n")
    }
    if plot_tag == "surface3DChart" && opts.typ == WireframeSurface3D {
      sb.write_view("        <c:wireframe val=\"1\"/>\n")
    }
    if plot_tag == "surfaceChart" && opts.typ == WireframeContour {
      sb.write_view("        <c:wireframe val=\"1\"/>\n")
    }
    if plot_supports_vary_colors(plot_tag) {
      write_plot_vary_colors(sb, opts.vary_colors)
    }
    let cat_ax_id = 1
    let val_ax_id = 2
    let ser_ax_id = 3
    for i, series in opts.series {
      write_chart_series_for_plot(sb, plot_tag, series, i, 0)
    }
    write_chart_dlbls(sb, plot_tag, opts.legend.show_legend_key, opts.plot_area)
    if plot_tag == "stockChart" {
      sb.write_view("        <c:hiLowLines/>\n")
      if opts.typ == StockOpenHighLowClose {
        sb.write_view("        <c:upDownBars>\n")
        sb.write_view("          <c:gapWidth val=\"150\"/>\n")
        sb.write_view("          <c:upBars>\n")
        write_chart_sppr(
          sb,
          opts.plot_area.up_bars.fill_color,
          opts.plot_area.up_bars.border,
        )
        sb.write_view("          </c:upBars>\n")
        sb.write_view("          <c:downBars>\n")
        write_chart_sppr(
          sb,
          opts.plot_area.down_bars.fill_color,
          opts.plot_area.down_bars.border,
        )
        sb.write_view("          </c:downBars>\n")
        sb.write_view("        </c:upDownBars>\n")
      }
    }
    if plot_tag == "bubbleChart" && opts.typ == Bubble3D {
      sb.write_view("        <c:bubble3D val=\"1\"/>\n")
    }
    if plot_tag == "bubbleChart" {
      match opts.bubble_scale {
        Some(value) =>
          if value > 0 && value <= 300 {
            sb.write_view("        <c:bubbleScale val=\"\{value}\"/>\n")
          }
        None => ()
      }
    }
    if plot_tag == "ofPieChart" {
      if opts.plot_area.second_plot_values > 0 {
        sb.write_view(
          "        <c:splitPos val=\"\{opts.plot_area.second_plot_values}\"/>\n",
        )
      }
      sb.write_view("        <c:serLines/>\n")
    }
    if plot_tag == "doughnutChart" {
      let raw = match opts.hole_size {
        Some(v) => v
        None => 75
      }
      let hole = if raw > 0 && raw <= 90 { raw } else { 75 }
      sb.write_view("        <c:holeSize val=\"\{hole}\"/>\n")
    }
    match opts.gap_width {
      Some(value) =>
        if plot_tag == "barChart" || plot_tag == "bar3DChart" {
          sb.write_view("        <c:gapWidth val=\"\{value}\"/>\n")
        }
      None => ()
    }
    match opts.overlap {
      Some(value) =>
        if plot_tag == "barChart" || plot_tag == "bar3DChart" {
          sb.write_view("        <c:overlap val=\"\{value}\"/>\n")
        }
      None => ()
    }
    if plot_tag == "bar3DChart" {
      match chart_shape(opts.typ) {
        Some(value) => {
          sb.write_view("        <c:shape val=\"")
          sb.write_view(escape_xml_attr(value))
          sb.write_view("\"/>\n")
        }
        None => ()
      }
    }
    if plot_tag != "pieChart" &&
      plot_tag != "pie3DChart" &&
      plot_tag != "ofPieChart" &&
      plot_tag != "doughnutChart" {
      if plot_tag == "surface3DChart" || plot_tag == "surfaceChart" {
        sb.write_view("        <c:axId val=\"\{cat_ax_id}\"/>\n")
        sb.write_view("        <c:axId val=\"\{val_ax_id}\"/>\n")
        sb.write_view("        <c:axId val=\"\{ser_ax_id}\"/>\n")
      } else {
        sb.write_view("        <c:axId val=\"\{cat_ax_id}\"/>\n")
        sb.write_view("        <c:axId val=\"\{val_ax_id}\"/>\n")
      }
    }
    sb.write_view("      </c:\{plot_tag}>\n")
    if plot_tag != "pieChart" &&
      plot_tag != "pie3DChart" &&
      plot_tag != "ofPieChart" &&
      plot_tag != "doughnutChart" {
      let x_id = axis_id_or_default(opts.x_axis, cat_ax_id)
      let y_id = axis_id_or_default(opts.y_axis, val_ax_id)
      let x_axis_tag = if plot_tag == "scatterChart" ||
        plot_tag == "bubbleChart" {
        "valAx"
      } else if plot_tag == "stockChart" {
        "dateAx"
      } else {
        "catAx"
      }
      write_axis(sb, x_axis_tag, opts.x_axis, x_id, y_id, "b", opts.typ)
      write_axis(sb, "valAx", opts.y_axis, y_id, x_id, "l", opts.typ)
      if plot_tag == "surface3DChart" || plot_tag == "surfaceChart" {
        write_axis(sb, "serAx", opts.y_axis, ser_ax_id, y_id, "r", opts.typ)
      }
    }
    write_plot_area_d_table(sb, plot_tag, opts)
  } else {
    let plots : Array[ChartComboOptions] = [
      ChartComboOptions::from_chart_options(opts),
    ]
    for combo in opts.combo_charts {
      plots.push(combo)
    }
    let (main_plot_tag, _main_bar_dir) = chart_type_to_plot(opts.typ)
    if main_plot_tag == "" {
      raise UnsupportedFeature(msg="unsupported chart type")
    }
    let mut has_cat_val = false
    let mut has_xy = false
    let mut has_stock = false
    let mut data_table_tag : String? = None
    for plot in plots {
      let (plot_tag, _bar_dir) = chart_type_to_plot(plot.typ)
      if plot_tag == "" {
        raise UnsupportedFeature(msg="unsupported chart type")
      }
      if plot_tag == "pieChart" ||
        plot_tag == "pie3DChart" ||
        plot_tag == "ofPieChart" ||
        plot_tag == "doughnutChart" ||
        plot_tag == "surface3DChart" ||
        plot_tag == "surfaceChart" {
        raise UnsupportedFeature(msg="combo chart type unsupported")
      }
      if plot_tag == "scatterChart" || plot_tag == "bubbleChart" {
        has_xy = true
      } else {
        has_cat_val = true
        if plot_tag == "stockChart" {
          has_stock = true
        }
      }
      if data_table_tag is None &&
        (
          plot_tag == "barChart" ||
          plot_tag == "bar3DChart" ||
          plot_tag == "areaChart" ||
          plot_tag == "area3DChart" ||
          plot_tag == "lineChart" ||
          plot_tag == "line3DChart"
        ) {
        data_table_tag = Some(plot_tag.to_string())
      }
    }
    let cat_axis_tag = if has_stock { "dateAx" } else { "catAx" }
    let primary_cat_id = axis_id_or_default(opts.x_axis, 1)
    let primary_val_id = axis_id_or_default(opts.y_axis, 2)
    let mut secondary_plot : ChartComboOptions? = None
    if has_cat_val {
      for i in 1..<plots.length() {
        let plot = plots[i]
        let (plot_tag, _bar_dir) = chart_type_to_plot(plot.typ)
        if plot_tag != "scatterChart" &&
          plot_tag != "bubbleChart" &&
          plot.y_axis.secondary {
          secondary_plot = Some(plot)
          break
        }
      }
    }
    let (secondary_cat_id, secondary_val_id) = match secondary_plot {
      Some(plot) =>
        (axis_id_or_default(plot.x_axis, 3), axis_id_or_default(plot.y_axis, 4))
      None => (0, 0)
    }
    let mut next_xy_axis_id = if secondary_plot is Some(_) { 5 } else { 3 }
    let mut xy_primary_plot : ChartComboOptions? = None
    let mut xy_secondary_plot : ChartComboOptions? = None
    if has_xy {
      for plot_idx in 0..<plots.length() {
        let plot = plots[plot_idx]
        let (plot_tag, _bar_dir) = chart_type_to_plot(plot.typ)
        if plot_tag == "scatterChart" || plot_tag == "bubbleChart" {
          if plot_idx > 0 && plot.y_axis.secondary {
            if xy_secondary_plot is None {
              xy_secondary_plot = Some(plot)
            }
          } else if xy_primary_plot is None {
            xy_primary_plot = Some(plot)
          }
        }
      }
      if xy_primary_plot is None {
        xy_primary_plot = xy_secondary_plot
      }
    }
    let (xy_primary_x_id, xy_primary_y_id) = match xy_primary_plot {
      Some(plot) => {
        let x_id = axis_id_or_default(plot.x_axis, next_xy_axis_id)
        let y_id = axis_id_or_default(plot.y_axis, next_xy_axis_id + 1)
        next_xy_axis_id = next_xy_axis_id + 2
        (x_id, y_id)
      }
      None => (0, 0)
    }
    let (xy_secondary_x_id, xy_secondary_y_id) = match xy_secondary_plot {
      Some(plot) => {
        let x_id = axis_id_or_default(plot.x_axis, next_xy_axis_id)
        let y_id = axis_id_or_default(plot.y_axis, next_xy_axis_id + 1)
        (x_id, y_id)
      }
      None => (0, 0)
    }
    let mut order_base = 0
    for plot_idx in 0..<plots.length() {
      let plot = plots[plot_idx]
      let (plot_tag, bar_dir) = chart_type_to_plot(plot.typ)
      if plot_tag == "" {
        raise UnsupportedFeature(msg="unsupported chart type")
      }
      if plot_tag == "stockChart" {
        let expected = match plot.typ {
          StockHighLowClose => 3
          StockOpenHighLowClose => 4
          _ => 0
        }
        if expected > 0 && plot.series.length() != expected {
          raise InvalidSheetOperation(
            msg="stock chart requires \{expected} series",
          )
        }
      }
      if plot_tag == "pieChart" ||
        plot_tag == "pie3DChart" ||
        plot_tag == "ofPieChart" ||
        plot_tag == "doughnutChart" ||
        plot_tag == "surface3DChart" ||
        plot_tag == "surfaceChart" {
        raise UnsupportedFeature(msg="combo chart type unsupported")
      }
      let is_xy = plot_tag == "scatterChart" || plot_tag == "bubbleChart"
      let use_secondary = plot_idx > 0 && plot.y_axis.secondary
      let (x_ax_id, y_ax_id) = if is_xy {
        if use_secondary && xy_secondary_x_id > 0 && xy_secondary_y_id > 0 {
          (xy_secondary_x_id, xy_secondary_y_id)
        } else {
          (xy_primary_x_id, xy_primary_y_id)
        }
      } else if use_secondary && secondary_cat_id > 0 && secondary_val_id > 0 {
        (secondary_cat_id, secondary_val_id)
      } else {
        (primary_cat_id, primary_val_id)
      }
      sb.write_view("      <c:\{plot_tag}>\n")
      if plot_tag == "barChart" || plot_tag == "bar3DChart" {
        match bar_dir {
          Some(dir) => {
            sb.write_view("        <c:barDir val=\"")
            sb.write_view(escape_xml_attr(dir))
            sb.write_view("\"/>\n")
          }
          None => ()
        }
      }
      if plot_tag == "barChart" ||
        plot_tag == "bar3DChart" ||
        plot_tag == "lineChart" ||
        plot_tag == "line3DChart" ||
        plot_tag == "areaChart" ||
        plot_tag == "area3DChart" {
        match chart_grouping(plot.typ) {
          Some(value) => {
            sb.write_view("        <c:grouping val=\"")
            sb.write_view(escape_xml_attr(value))
            sb.write_view("\"/>\n")
          }
          None => ()
        }
      }
      if plot_tag == "scatterChart" {
        sb.write_view("        <c:scatterStyle val=\"lineMarker\"/>\n")
      }
      if plot_tag == "radarChart" {
        sb.write_view("        <c:radarStyle val=\"standard\"/>\n")
      }
      if plot_supports_vary_colors(plot_tag) {
        write_plot_vary_colors(sb, plot.vary_colors)
      }
      for i, series in plot.series {
        write_chart_series_for_plot(sb, plot_tag, series, i, order_base)
      }
      write_chart_dlbls(
        sb,
        plot_tag,
        opts.legend.show_legend_key,
        plot.plot_area,
      )
      if plot_tag == "stockChart" {
        sb.write_view("        <c:hiLowLines/>\n")
        if plot.typ == StockOpenHighLowClose {
          sb.write_view("        <c:upDownBars>\n")
          sb.write_view("          <c:gapWidth val=\"150\"/>\n")
          sb.write_view("          <c:upBars>\n")
          write_chart_sppr(
            sb,
            plot.plot_area.up_bars.fill_color,
            plot.plot_area.up_bars.border,
          )
          sb.write_view("          </c:upBars>\n")
          sb.write_view("          <c:downBars>\n")
          write_chart_sppr(
            sb,
            plot.plot_area.down_bars.fill_color,
            plot.plot_area.down_bars.border,
          )
          sb.write_view("          </c:downBars>\n")
          sb.write_view("        </c:upDownBars>\n")
        }
      }
      if plot_tag == "bubbleChart" && plot.typ == Bubble3D {
        sb.write_view("        <c:bubble3D val=\"1\"/>\n")
      }
      if plot_tag == "bubbleChart" {
        match plot.bubble_scale {
          Some(value) =>
            if value > 0 && value <= 300 {
              sb.write_view("        <c:bubbleScale val=\"\{value}\"/>\n")
            }
          None => ()
        }
      }
      match plot.gap_width {
        Some(value) =>
          if plot_tag == "barChart" || plot_tag == "bar3DChart" {
            sb.write_view("        <c:gapWidth val=\"\{value}\"/>\n")
          }
        None => ()
      }
      match plot.overlap {
        Some(value) =>
          if plot_tag == "barChart" || plot_tag == "bar3DChart" {
            sb.write_view("        <c:overlap val=\"\{value}\"/>\n")
          }
        None => ()
      }
      if plot_tag == "bar3DChart" {
        match chart_shape(plot.typ) {
          Some(value) => {
            sb.write_view("        <c:shape val=\"")
            sb.write_view(escape_xml_attr(value))
            sb.write_view("\"/>\n")
          }
          None => ()
        }
      }
      sb.write_view("        <c:axId val=\"\{x_ax_id}\"/>\n")
      sb.write_view("        <c:axId val=\"\{y_ax_id}\"/>\n")
      sb.write_view("      </c:\{plot_tag}>\n")
      order_base = order_base + plot.series.length()
    }
    if has_cat_val {
      write_axis(
        sb,
        cat_axis_tag,
        opts.x_axis,
        primary_cat_id,
        primary_val_id,
        "b",
        opts.typ,
      )
      write_axis(
        sb,
        "valAx",
        opts.y_axis,
        primary_val_id,
        primary_cat_id,
        "l",
        opts.typ,
      )
      match secondary_plot {
        Some(value) => {
          write_axis(
            sb,
            cat_axis_tag,
            opts.x_axis,
            secondary_cat_id,
            secondary_val_id,
            "b",
            value.typ,
          )
          write_axis(
            sb,
            "valAx",
            value.y_axis,
            secondary_val_id,
            secondary_cat_id,
            "r",
            value.typ,
          )
        }
        None => ()
      }
    }
    match xy_primary_plot {
      Some(value) => {
        write_axis(
          sb,
          "valAx",
          value.x_axis,
          xy_primary_x_id,
          xy_primary_y_id,
          "b",
          value.typ,
        )
        write_axis(
          sb,
          "valAx",
          value.y_axis,
          xy_primary_y_id,
          xy_primary_x_id,
          "l",
          value.typ,
        )
      }
      None => ()
    }
    match xy_secondary_plot {
      Some(value) =>
        if xy_secondary_x_id > 0 && xy_secondary_y_id > 0 {
          write_axis(
            sb,
            "valAx",
            value.x_axis,
            xy_secondary_x_id,
            xy_secondary_y_id,
            "t",
            value.typ,
          )
          write_axis(
            sb,
            "valAx",
            value.y_axis,
            xy_secondary_y_id,
            xy_secondary_x_id,
            "r",
            value.typ,
          )
        }
      None => ()
    }
    match data_table_tag {
      Some(tag) => write_plot_area_d_table(sb, tag, opts)
      None => write_plot_area_d_table(sb, main_plot_tag, opts)
    }
  }
  sb.write_view("    </c:plotArea>\n")
  match legend_position_value(opts.legend.position) {
    Some(value) => {
      sb.write_view("    <c:legend>\n")
      sb.write_view("      <c:legendPos val=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"/>\n")
      match opts.legend.font {
        Some(font) =>
          if font != Font::new() {
            write_drawingml_tx_pr_with_font(sb, "      ", font)
          }
        None => ()
      }
      sb.write_view("    </c:legend>\n")
    }
    None => ()
  }
  sb.write_view("    <c:plotVisOnly val=\"1\"/>\n")
  if opts.show_blanks_as != "" {
    sb.write_view("    <c:dispBlanksAs val=\"")
    sb.write_view(escape_xml_attr(opts.show_blanks_as))
    sb.write_view("\"/>\n")
  }
  write_chart_sppr_root(sb, opts)
  sb.write_view("  </c:chart>\n")
  sb.write_view("</c:chartSpace>")
  sb.to_string()
}
