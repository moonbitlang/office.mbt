///|
/// Deterministic inline-SVG rendering for the chart kinds the previewer
/// supports. Everything is bounded: series count, points per series, and
/// label lengths. Unsupported kinds keep the labeled placeholder so a
/// reader always knows what was omitted.
const CHART_SVG_WIDTH : Int = 480

///|
const CHART_SVG_HEIGHT : Int = 280

///|
const CHART_SVG_PLOT_LEFT : Int = 48

///|
const CHART_SVG_PLOT_TOP : Int = 24

///|
const CHART_SVG_PLOT_WIDTH : Int = 400

///|
const CHART_SVG_PLOT_HEIGHT : Int = 200

///|
const CHART_SVG_MAX_SERIES : Int = 8

///|
const CHART_SVG_MAX_POINTS : Int = 64

///|
const CHART_SVG_MAX_LABEL_CHARS : Int = 24

///|
/// A fixed, deterministic series palette (no theme resolution).
let chart_svg_palette : ReadOnlyArray[String] = [
  "#4472c4", "#ed7d31", "#a5a5a5", "#ffc000", "#5b9bd5", "#70ad47", "#264478", "#9e480e",
]

///|
priv struct ChartSvgSeries {
  name : String
  values : Array[Double]
  present : Array[Bool]
}

///|
priv struct ChartSvgData {
  kind : String
  series : Array[ChartSvgSeries]
  categories : Array[String]
  omitted_series : Int
  omitted_points : Bool
  skipped_values : Int
}

///|
/// Formats an SVG coordinate/length with exactly two deterministic decimal
/// digits computed in integer space (no float-formatting drift).
fn svg_num(value : Double) -> String {
  let scaled = (value * 100.0).round().to_int64()
  let negative = scaled < 0L
  let magnitude = if negative { -scaled } else { scaled }
  let whole = magnitude / 100L
  let fraction = (magnitude % 100L).to_int()
  let sign = if negative { "-" } else { "" }
  let tens = fraction / 10
  let ones = fraction % 10
  "\{sign}\{whole}.\{tens}\{ones}"
}

///|
fn chart_label(text : String) -> String {
  if text.length() <= CHART_SVG_MAX_LABEL_CHARS {
    text
  } else {
    text.substring(start=0, end=CHART_SVG_MAX_LABEL_CHARS - 1) + "\u{2026}"
  }
}

///|
/// Splits a chart data reference like `'My Sheet'!$B$2:$B$9` into its sheet
/// name and plain `B2:B9` range. Returns None for shapes the previewer does
/// not resolve (missing sheet, literal arrays).
fn chart_ref_parts(reference : String) -> (String, String)? {
  guard reference.find("!") is Some(bang) else { return None }
  let sheet_raw = reference.substring(start=0, end=bang)
  let range_raw = reference.substring(start=bang + 1, end=reference.length())
  let sheet = if sheet_raw.length() >= 2 &&
    sheet_raw.has_prefix("'") &&
    sheet_raw.has_suffix("'") {
    sheet_raw
    .substring(start=1, end=sheet_raw.length() - 1)
    .replace_all(old="''", new="'")
  } else {
    sheet_raw
  }
  let range = range_raw.replace_all(old="$", new="")
  if sheet == "" || range == "" {
    None
  } else {
    Some((sheet, range))
  }
}

///|
/// Resolves a chart range to per-cell display values, bounded by
/// CHART_SVG_MAX_POINTS. The Bool marks whether a numeric value was present.
fn chart_range_numbers(
  workbook : @xlsx.Workbook,
  reference : String,
) -> (Array[Double], Array[Bool], Bool, Int)? {
  guard chart_ref_parts(reference) is Some((sheet, range)) else { return None }
  let cells = @inspect.parse_range(range).cells() catch { _ => return None }
  let values : Array[Double] = []
  let present : Array[Bool] = []
  let mut skipped = 0
  let mut truncated = false
  for cell in cells {
    if values.length() >= CHART_SVG_MAX_POINTS {
      truncated = true
      break
    }
    match
      (workbook.get_cell_value_raw(sheet, cell) catch { _ => return None }) {
      Some(Numeric(number)) => {
        values.push(number)
        present.push(true)
      }
      _ => {
        values.push(0.0)
        present.push(false)
        skipped += 1
      }
    }
  }
  Some((values, present, truncated, skipped))
}

///|
fn chart_range_labels(
  workbook : @xlsx.Workbook,
  reference : String,
) -> Array[String] {
  guard chart_ref_parts(reference) is Some((sheet, range)) else { return [] }
  let cells = @inspect.parse_range(range).cells() catch { _ => return [] }
  let labels : Array[String] = []
  for cell in cells {
    if labels.length() >= CHART_SVG_MAX_POINTS {
      break
    }
    let label = match
      (workbook.get_cell_value_raw(sheet, cell) catch { _ => None }) {
      Some(String(text)) => text
      Some(Numeric(number)) => svg_num(number)
      Some(Bool(flag)) => if flag { "TRUE" } else { "FALSE" }
      Some(Error(text)) => text
      _ => ""
    }
    labels.push(label)
  }
  labels
}

///|
/// Series names in chart XML are usually cell references; resolve them to
/// the referenced cell's text when possible.
fn chart_series_display_name(
  workbook : @xlsx.Workbook,
  reference : String,
) -> String {
  guard chart_ref_parts(reference) is Some((sheet, range)) else {
    return reference
  }
  let first_cell = match range.find(":") {
    Some(colon) => range.substring(start=0, end=colon)
    None => range
  }
  match (workbook.get_cell_value_raw(sheet, first_cell) catch { _ => None }) {
    Some(String(text)) if text != "" => text
    Some(Numeric(number)) => svg_num(number)
    _ => reference
  }
}

///|
/// The chart kinds rendered as SVG; everything else keeps the placeholder.
fn chart_svg_supported_kind(kinds : Array[String]) -> String? {
  guard kinds is [kind] else { return None }
  match kind {
    "barChart" | "lineChart" | "pieChart" => Some(kind)
    _ => None
  }
}

///|
fn chart_svg_collect(workbook : @xlsx.Workbook, xml : String) -> ChartSvgData? {
  guard chart_svg_supported_kind(@inspect.chart_kinds(xml)) is Some(kind) else {
    return None
  }
  let metas = @inspect.chart_series(xml)
  guard metas.length() > 0 else { return None }
  let series : Array[ChartSvgSeries] = []
  let mut categories : Array[String] = []
  let mut omitted_points = false
  let mut skipped_values = 0
  for index, meta in metas {
    if index >= CHART_SVG_MAX_SERIES {
      break
    }
    guard meta.values is Some(values_ref) else { return None }
    guard chart_range_numbers(workbook, values_ref)
      is Some((values, present, truncated, skipped)) else {
      return None
    }
    if truncated {
      omitted_points = true
    }
    skipped_values += skipped
    if categories.length() == 0 && meta.categories is Some(categories_ref) {
      categories = chart_range_labels(workbook, categories_ref)
    }
    let name = match meta.name {
      Some(value) if value != "" => chart_series_display_name(workbook, value)
      _ => "series \{index + 1}"
    }
    series.push({ name, values, present })
  }
  guard series.length() > 0 else { return None }
  let omitted_series = if metas.length() > CHART_SVG_MAX_SERIES {
    metas.length() - CHART_SVG_MAX_SERIES
  } else {
    0
  }
  Some({
    kind,
    series,
    categories,
    omitted_series,
    omitted_points,
    skipped_values,
  })
}

///|
fn chart_svg_value_bounds(data : ChartSvgData) -> (Double, Double) {
  let mut low = 0.0
  let mut high = 0.0
  for entry in data.series {
    for value in entry.values {
      if value < low {
        low = value
      }
      if value > high {
        high = value
      }
    }
  }
  if low == 0.0 && high == 0.0 {
    high = 1.0
  }
  (low, high)
}

///|
fn chart_svg_axes(
  svg : StringBuilder,
  data : ChartSvgData,
  low : Double,
  high : Double,
) -> Unit {
  let left = CHART_SVG_PLOT_LEFT
  let top = CHART_SVG_PLOT_TOP
  let bottom = top + CHART_SVG_PLOT_HEIGHT
  let right = left + CHART_SVG_PLOT_WIDTH
  svg.write_string(
    "<line class=\"axis\" x1=\"\{left}\" y1=\"\{top}\" x2=\"\{left}\" y2=\"\{bottom}\"/>",
  )
  svg.write_string(
    "<line class=\"axis\" x1=\"\{left}\" y1=\"\{bottom}\" x2=\"\{right}\" y2=\"\{bottom}\"/>",
  )
  svg.write_string(
    "<text class=\"tick\" x=\"\{left - 4}\" y=\"\{top + 4}\" text-anchor=\"end\">" +
    escape_html(svg_num(high)) +
    "</text>",
  )
  svg.write_string(
    "<text class=\"tick\" x=\"\{left - 4}\" y=\"\{bottom + 4}\" text-anchor=\"end\">" +
    escape_html(svg_num(low)) +
    "</text>",
  )
  let count = chart_svg_point_count(data)
  if count > 0 && data.categories.length() > 0 {
    let step = CHART_SVG_PLOT_WIDTH.to_double() / count.to_double()
    let max_ticks = 8
    let stride = if count <= max_ticks {
      1
    } else {
      (count + max_ticks - 1) / max_ticks
    }
    for index in 0..<count {
      if index % stride != 0 {
        continue
      }
      guard index < data.categories.length() else { break }
      let x = left.to_double() + step * (index.to_double() + 0.5)
      svg.write_string(
        "<text class=\"tick\" x=\"\{svg_num(x)}\" y=\"\{bottom + 16}\" text-anchor=\"middle\">" +
        escape_html(chart_label(data.categories[index])) +
        "</text>",
      )
    }
  }
}

///|
fn chart_svg_point_count(data : ChartSvgData) -> Int {
  let mut count = 0
  for entry in data.series {
    if entry.values.length() > count {
      count = entry.values.length()
    }
  }
  count
}

///|
fn chart_svg_scale_y(value : Double, low : Double, high : Double) -> Double {
  let span = high - low
  let ratio = if span == 0.0 { 0.0 } else { (value - low) / span }
  (CHART_SVG_PLOT_TOP + CHART_SVG_PLOT_HEIGHT).to_double() -
  ratio * CHART_SVG_PLOT_HEIGHT.to_double()
}

///|
fn chart_svg_bars(
  svg : StringBuilder,
  data : ChartSvgData,
  low : Double,
  high : Double,
) -> Unit {
  let count = chart_svg_point_count(data)
  guard count > 0 else { return }
  let group_width = CHART_SVG_PLOT_WIDTH.to_double() / count.to_double()
  let bar_width = group_width * 0.8 / data.series.length().to_double()
  let zero_y = chart_svg_scale_y(0.0, low, high)
  for series_index, entry in data.series {
    let colour = chart_svg_palette[series_index % chart_svg_palette.length()]
    for point_index, value in entry.values {
      if entry.present[point_index] == false {
        continue
      }
      let group_left = CHART_SVG_PLOT_LEFT.to_double() +
        group_width * point_index.to_double() +
        group_width * 0.1
      let x = group_left + bar_width * series_index.to_double()
      let value_y = chart_svg_scale_y(value, low, high)
      let top = if value_y < zero_y { value_y } else { zero_y }
      let height = if value_y < zero_y {
        zero_y - value_y
      } else {
        value_y - zero_y
      }
      svg.write_string(
        "<rect fill=\"\{colour}\" x=\"\{svg_num(x)}\" y=\"\{svg_num(top)}\" width=\"\{svg_num(bar_width)}\" height=\"\{svg_num(height)}\"/>",
      )
    }
  }
}

///|
fn chart_svg_lines(
  svg : StringBuilder,
  data : ChartSvgData,
  low : Double,
  high : Double,
) -> Unit {
  let count = chart_svg_point_count(data)
  guard count > 0 else { return }
  let step = CHART_SVG_PLOT_WIDTH.to_double() / count.to_double()
  for series_index, entry in data.series {
    let colour = chart_svg_palette[series_index % chart_svg_palette.length()]
    let points = StringBuilder()
    let mut first = true
    for point_index, value in entry.values {
      if entry.present[point_index] == false {
        continue
      }
      let x = CHART_SVG_PLOT_LEFT.to_double() +
        step * (point_index.to_double() + 0.5)
      let y = chart_svg_scale_y(value, low, high)
      if !first {
        points.write_string(" ")
      }
      first = false
      points.write_string("\{svg_num(x)},\{svg_num(y)}")
    }
    let rendered = points.to_string()
    if rendered != "" {
      svg.write_string(
        "<polyline fill=\"none\" stroke=\"\{colour}\" stroke-width=\"2\" points=\"\{rendered}\"/>",
      )
    }
  }
}

///|
fn chart_svg_pie(svg : StringBuilder, data : ChartSvgData) -> Unit {
  guard data.series is [entry, ..] else { return }
  let mut total = 0.0
  for index, value in entry.values {
    if entry.present[index] && value > 0.0 {
      total += value
    }
  }
  guard total > 0.0 else { return }
  let cx = (CHART_SVG_WIDTH / 2).to_double()
  let cy = (CHART_SVG_PLOT_TOP + CHART_SVG_PLOT_HEIGHT / 2).to_double()
  let radius = (CHART_SVG_PLOT_HEIGHT / 2).to_double()
  let mut angle = -1.5707963267948966
  let tau = 6.283185307179586
  let mut slice_index = 0
  for index, value in entry.values {
    if entry.present[index] == false || value <= 0.0 {
      continue
    }
    let sweep = value / total * tau
    let end_angle = angle + sweep
    let x1 = cx + radius * @math.cos(angle)
    let y1 = cy + radius * @math.sin(angle)
    let x2 = cx + radius * @math.cos(end_angle)
    let y2 = cy + radius * @math.sin(end_angle)
    let large = if sweep > 3.141592653589793 { 1 } else { 0 }
    let colour = chart_svg_palette[slice_index % chart_svg_palette.length()]
    svg.write_string(
      "<path fill=\"\{colour}\" d=\"M \{svg_num(cx)} \{svg_num(cy)} L \{svg_num(x1)} \{svg_num(y1)} A \{svg_num(radius)} \{svg_num(radius)} 0 \{large} 1 \{svg_num(x2)} \{svg_num(y2)} Z\"/>",
    )
    angle = end_angle
    slice_index += 1
  }
}

///|
fn chart_svg_description(data : ChartSvgData) -> String {
  let text = StringBuilder()
  text.write_string("\{data.kind} with \{data.series.length()} series")
  for entry in data.series {
    text.write_string("; \{entry.name} (\{entry.values.length()} points)")
  }
  if data.omitted_series > 0 {
    text.write_string("; \{data.omitted_series} series omitted")
  }
  if data.omitted_points {
    text.write_string("; later points omitted")
  }
  if data.skipped_values > 0 {
    text.write_string("; \{data.skipped_values} non-numeric values skipped")
  }
  text.to_string()
}

///|
/// Renders a supported chart as a deterministic, self-contained SVG figure,
/// or returns None when the chart should keep its labeled placeholder.
fn chart_svg_figure(
  workbook : @xlsx.Workbook,
  xml : String,
  anchor~ : String,
) -> String? {
  guard chart_svg_collect(workbook, xml) is Some(data) else { return None }
  let (low, high) = chart_svg_value_bounds(data)
  let description = chart_svg_description(data)
  let svg = StringBuilder()
  svg.write_string(
    "<svg role=\"img\" aria-label=\"" +
    escape_html_attribute(description) +
    "\" viewBox=\"0 0 \{CHART_SVG_WIDTH} \{CHART_SVG_HEIGHT}\" width=\"\{CHART_SVG_WIDTH}\" height=\"\{CHART_SVG_HEIGHT}\" xmlns=\"http://www.w3.org/2000/svg\">",
  )
  svg.write_string("<title>\{escape_html(data.kind)}</title>")
  svg.write_string("<desc>\{escape_html(description)}</desc>")
  match data.kind {
    "pieChart" => chart_svg_pie(svg, data)
    "lineChart" => {
      chart_svg_axes(svg, data, low, high)
      chart_svg_lines(svg, data, low, high)
    }
    _ => {
      chart_svg_axes(svg, data, low, high)
      chart_svg_bars(svg, data, low, high)
    }
  }
  // deterministic legend under the plot
  let legend_y = CHART_SVG_PLOT_TOP + CHART_SVG_PLOT_HEIGHT + 34
  for index, entry in data.series {
    let colour = chart_svg_palette[index % chart_svg_palette.length()]
    let x = CHART_SVG_PLOT_LEFT + index % 2 * 200
    let y = legend_y + index / 2 * 16
    svg.write_string(
      "<rect fill=\"\{colour}\" x=\"\{x}\" y=\"\{y - 8}\" width=\"10\" height=\"10\"/>",
    )
    svg.write_string(
      "<text class=\"legend\" x=\"\{x + 14}\" y=\"\{y}\">" +
      escape_html(chart_label(entry.name)) +
      "</text>",
    )
  }
  svg.write_string("</svg>")
  let caption = StringBuilder()
  caption.write_string(escape_html(description))
  ("<figure class=\"chart\" data-anchor=\"" +
  escape_html_attribute(anchor) +
  "\">" +
  svg.to_string() +
  "<figcaption>" +
  caption.to_string() +
  "</figcaption></figure>\n")
  |> Some
}
