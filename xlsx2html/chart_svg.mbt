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
  if value.is_nan() {
    return "0.00"
  }
  // beyond the fixed-point window the Int64 scaling would saturate; the
  // core float formatter is deterministic across backends
  if value > 1.0e12 || value < -1.0e12 {
    return "\{value}"
  }
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
    let mut end = CHART_SVG_MAX_LABEL_CHARS - 1
    // never cut a surrogate pair in half: a lone leading surrogate would
    // make the document unencodable
    if text[end - 1].is_leading_surrogate() {
      end -= 1
    }
    text.substring(start=0, end~) + "\u{2026}"
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
/// Every `val` attribute of every `<tag ...>` element in the chart XML, in
/// document order. Tolerates whitespace around `=` and either quote style,
/// so a foreign writer's spelling cannot slip a subtype past the gate.
fn chart_svg_tag_vals(xml : String, tag : String) -> Array[String] {
  let out : Array[String] = []
  let open = "<" + tag
  let mut from = 0
  while from < xml.length() {
    guard xml[from:].find(open) is Some(offset) else { break }
    let after = from + offset + open.length()
    guard after < xml.length() else { break }
    if !(xml[after] is (' ' | '\t' | '\r' | '\n' | '/' | '>')) {
      // a longer tag name such as <c:barDirExt>
      from = after
      continue
    }
    // find the element end while honoring quoted values, so a `>` inside
    // an attribute value cannot end the element scan early
    let mut scan = after
    let mut quote_unit = 0
    while scan < xml.length() {
      let unit : Int = xml[scan].to_int()
      if quote_unit != 0 {
        if unit == quote_unit {
          quote_unit = 0
        }
      } else if unit is ('"' | '\'') {
        quote_unit = unit
      } else if unit is '>' {
        break
      }
      scan += 1
    }
    let element_end = scan
    // tokenize `name = "value"` pairs sequentially; values are consumed
    // atomically, so text inside a value can never read as a name
    let body = xml.substring(start=after, end=element_end)
    let mut cursor = 0
    while cursor < body.length() {
      while cursor < body.length() &&
            body[cursor] is (' ' | '\t' | '\r' | '\n' | '/') {
        cursor += 1
      }
      guard cursor < body.length() else { break }
      let name_start = cursor
      while cursor < body.length() &&
            !(body[cursor] is (' ' | '\t' | '\r' | '\n' | '=' | '/')) {
        cursor += 1
      }
      let attr_name = body.substring(start=name_start, end=cursor)
      guard attr_name != "" else {
        cursor += 1
        continue
      }
      while cursor < body.length() && body[cursor] is (' ' | '\t' | '\r' | '\n') {
        cursor += 1
      }
      guard cursor < body.length() && body[cursor] is '=' else { continue }
      cursor += 1
      while cursor < body.length() && body[cursor] is (' ' | '\t' | '\r' | '\n') {
        cursor += 1
      }
      // unquoted or missing value: stop parsing this malformed element
      guard cursor < body.length() && body[cursor] is ('"' | '\'') else {
        break
      }
      let quote = body[cursor]
      cursor += 1
      let value_start = cursor
      while cursor < body.length() && body[cursor] != quote {
        cursor += 1
      }
      guard cursor < body.length() else { break }
      if attr_name == "val" {
        out.push(body.substring(start=value_start, end=cursor))
      }
      cursor += 1
    }
    from = if element_end > after { element_end } else { after + 1 }
  }
  out
}

///|
/// Only the subtypes whose geometry matches what the renderer draws are
/// accepted; stacked/percent groupings and horizontal bars keep the
/// placeholder instead of being silently drawn as something else. Every
/// plot in the chart space is checked — `chart_kinds` deduplicates, so a
/// clustered plot must not vouch for a stacked one beside it.
fn chart_svg_supported_subtype(xml : String, kind : String) -> Bool {
  if kind is ("barChart" | "lineChart") {
    for grouping in chart_svg_tag_vals(xml, "c:grouping") {
      if grouping is ("stacked" | "percentStacked") {
        return false
      }
    }
  }
  if kind == "barChart" {
    for direction in chart_svg_tag_vals(xml, "c:barDir") {
      if direction != "col" {
        return false
      }
    }
  }
  true
}

///|
fn chart_svg_collect(workbook : @xlsx.Workbook, xml : String) -> ChartSvgData? {
  guard chart_svg_supported_kind(@inspect.chart_kinds(xml)) is Some(kind) else {
    return None
  }
  guard chart_svg_supported_subtype(xml, kind) else { return None }
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
    // non-finite magnitudes cannot be drawn truthfully; count them with
    // the other skipped values
    for value_index, value in values {
      if present[value_index] && (value.is_nan() || value.is_inf()) {
        present[value_index] = false
        skipped_values += 1
      }
    }
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
    for index, value in entry.values {
      // absent slots hold placeholder zeros and skipped non-finites;
      // neither may stretch the axis
      if entry.present[index] == false {
        continue
      }
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
  // the direct span is exact (subnormals included); halved arithmetic is
  // the fallback that keeps opposite-extreme spans finite
  let span = high - low
  let ratio = if span == 0.0 {
    0.0
  } else if span.is_inf() {
    let half_span = high / 2.0 - low / 2.0
    (value / 2.0 - low / 2.0) / half_span
  } else {
    (value - low) / span
  }
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
    let mut plotted = 0
    let mut only = ("", "")
    for point_index, value in entry.values {
      if entry.present[point_index] == false {
        continue
      }
      let x = CHART_SVG_PLOT_LEFT.to_double() +
        step * (point_index.to_double() + 0.5)
      let y = chart_svg_scale_y(value, low, high)
      if plotted > 0 {
        points.write_string(" ")
      }
      only = (svg_num(x), svg_num(y))
      points.write_string("\{only.0},\{only.1}")
      plotted += 1
    }
    // a one-vertex polyline has no visible segment; draw the point itself
    if plotted == 1 {
      svg.write_string(
        "<circle fill=\"\{colour}\" cx=\"\{only.0}\" cy=\"\{only.1}\" r=\"3\"/>",
      )
    } else if plotted > 1 {
      svg.write_string(
        "<polyline fill=\"none\" stroke=\"\{colour}\" stroke-width=\"2\" points=\"\{points.to_string()}\"/>",
      )
    }
  }
}

///|
fn chart_svg_pie(svg : StringBuilder, data : ChartSvgData) -> Unit {
  guard data.series is [entry, ..] else { return }
  // normalize by the largest slice before summing so huge finite values
  // cannot overflow the total into a zero-sweep pie
  let mut largest = 0.0
  for index, value in entry.values {
    if entry.present[index] && value > largest {
      largest = value
    }
  }
  guard largest > 0.0 else { return }
  let mut total = 0.0
  for index, value in entry.values {
    if entry.present[index] && value > 0.0 {
      total += value / largest
    }
  }
  guard total > 0.0 else { return }
  let cx = (CHART_SVG_WIDTH / 2).to_double()
  let cy = (CHART_SVG_PLOT_TOP + CHART_SVG_PLOT_HEIGHT / 2).to_double()
  let radius = (CHART_SVG_PLOT_HEIGHT / 2).to_double()
  let mut positive = 0
  for index, value in entry.values {
    if entry.present[index] && value > 0.0 {
      positive += 1
    }
  }
  // a single slice is the whole disc; the arc form degenerates to zero
  // area because its endpoints coincide
  if positive == 1 {
    svg.write_string(
      "<circle fill=\"\{chart_svg_palette[0]}\" cx=\"\{svg_num(cx)}\" cy=\"\{svg_num(cy)}\" r=\"\{svg_num(radius)}\"/>",
    )
    return
  }
  let mut angle = -1.5707963267948966
  let tau = 6.283185307179586
  let mut slice_index = 0
  for index, value in entry.values {
    if entry.present[index] == false || value <= 0.0 {
      continue
    }
    let sweep = value / largest / total * tau
    let colour = chart_svg_palette[slice_index % chart_svg_palette.length()]
    // a slice sweeping (almost) the full circle degenerates to a zero-area
    // arc with coincident endpoints — draw the dominant slice as the disc;
    // the remaining slices are genuinely negligible at this scale
    if sweep >= tau - 1.0e-4 {
      svg.write_string(
        "<circle fill=\"\{colour}\" cx=\"\{svg_num(cx)}\" cy=\"\{svg_num(cy)}\" r=\"\{svg_num(radius)}\"/>",
      )
      angle += sweep
      slice_index += 1
      continue
    }
    let end_angle = angle + sweep
    let x1 = cx + radius * @math.cos(angle)
    let y1 = cy + radius * @math.sin(angle)
    let x2 = cx + radius * @math.cos(end_angle)
    let y2 = cy + radius * @math.sin(end_angle)
    let large = if sweep > 3.141592653589793 { 1 } else { 0 }
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
    text.write_string(
      "; \{chart_label(entry.name)} (\{entry.values.length()} points)",
    )
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
  // pie slices are colored by slice, so the legend must name slices; the
  // other kinds color by series
  let legend : Array[(String, String)] = []
  if data.kind == "pieChart" && data.series is [entry, ..] {
    let mut slice_index = 0
    for index, value in entry.values {
      if entry.present[index] == false || value <= 0.0 {
        continue
      }
      if slice_index >= CHART_SVG_MAX_SERIES {
        break
      }
      let label = if index < data.categories.length() &&
        data.categories[index] != "" {
        data.categories[index]
      } else {
        "slice \{index + 1}"
      }
      legend.push(
        (label, chart_svg_palette[slice_index % chart_svg_palette.length()]),
      )
      slice_index += 1
    }
  } else {
    for index, entry in data.series {
      legend.push(
        (entry.name, chart_svg_palette[index % chart_svg_palette.length()]),
      )
    }
  }
  // two legend columns; extra rows extend the canvas instead of clipping
  let legend_rows = (legend.length() + 1) / 2
  let legend_base = CHART_SVG_PLOT_TOP + CHART_SVG_PLOT_HEIGHT + 34
  let height = if legend_rows > 1 {
    let needed = legend_base + (legend_rows - 1) * 16 + 12
    if needed > CHART_SVG_HEIGHT {
      needed
    } else {
      CHART_SVG_HEIGHT
    }
  } else {
    CHART_SVG_HEIGHT
  }
  let svg = StringBuilder()
  svg.write_string(
    "<svg role=\"img\" aria-label=\"" +
    escape_html_attribute(description) +
    "\" viewBox=\"0 0 \{CHART_SVG_WIDTH} \{height}\" width=\"\{CHART_SVG_WIDTH}\" height=\"\{height}\" xmlns=\"http://www.w3.org/2000/svg\">",
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
  for index, item in legend {
    let (label, colour) = item
    let x = CHART_SVG_PLOT_LEFT + index % 2 * 200
    let y = legend_base + index / 2 * 16
    svg.write_string(
      "<rect fill=\"\{colour}\" x=\"\{x}\" y=\"\{y - 8}\" width=\"10\" height=\"10\"/>",
    )
    svg.write_string(
      "<text class=\"legend\" x=\"\{x + 14}\" y=\"\{y}\">" +
      escape_html(chart_label(label)) +
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
