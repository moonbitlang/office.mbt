// Helpers shared by batch ops and their CLI subcommand twins: style
// construction, chart-type naming, and series-range qualification. They
// live here (not in the executable) so both callers use one definition.

///|
/// Builds a style from the CLI's flag vocabulary; an empty string means
/// "leave unset". Shared by the `style` subcommand and the batch `style`
/// op so the two cannot drift apart.
pub fn build_style(
  bold~ : Bool,
  italic~ : Bool,
  number_format~ : String,
  fill~ : String,
  font_color~ : String,
  align~ : String,
) -> @xlsx.Style {
  let mut style = if number_format != "" {
    @xlsx.Style::number_format(number_format)
  } else {
    @xlsx.Style::new()
  }
  if bold || italic || font_color != "" {
    let font = if font_color != "" {
      @xlsx.Font::with_values(bold~, italic~, color=font_color)
    } else {
      @xlsx.Font::with_values(bold~, italic~)
    }
    style = style.with_font(font)
  }
  if fill != "" {
    style = style.with_fill(@xlsx.Fill::solid(fill))
  }
  if align != "" {
    style = style.with_alignment(@xlsx.Alignment::with_values(horizontal=align))
  }
  style
}

///|
/// Maps a friendly chart-type name to a `ChartType`. Covers the common
/// 2-D chart kinds; an unknown name raises a `BatchError` listing the
/// choices.
pub fn chart_type_of(name : String) -> @xlsx.ChartType raise BatchError {
  match name {
    "col" | "column" => Col
    "bar" => Bar
    "line" => Line
    "pie" => Pie
    "area" => Area
    "scatter" => Scatter
    "doughnut" | "donut" => Doughnut
    "radar" => Radar
    _ =>
      raise BatchError(
        "unknown chart type '\{name}' (expected one of: col, bar, line, pie, area, scatter, doughnut, radar)",
      )
  }
}

///|
/// Qualifies a cell range with its sheet for a chart series reference. A
/// range the caller already qualified (contains `!`) is left as-is;
/// otherwise the sheet name is prepended using the library's formula
/// sheet-ref quoting — wrapped in single quotes with embedded apostrophes
/// doubled — so names with spaces or punctuation (e.g. `O'Brien`, `R&D`)
/// stay valid.
pub fn qualify_range(sheet : String, range : String) -> String {
  if range.contains("!") {
    range
  } else {
    "'" + sheet.replace_all(old="'", new="''") + "'!" + range
  }
}
