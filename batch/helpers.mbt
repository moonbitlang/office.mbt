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

///|
/// Maps a `validate` op's `type` string to a `DataValidationType`. Uses the
/// OOXML tokens (as the engine emits them), so a written validation reads
/// back with the same names. Private: the `validate` op has no CLI twin.
fn validation_type_of(
  name : String,
) -> @xlsx.DataValidationType raise BatchError {
  match name {
    "list" => List
    "whole" => Whole
    "decimal" => Decimal
    "date" => Date
    "time" => Time
    "textLength" => TextLength
    "custom" => Custom
    _ =>
      raise BatchError(
        "validate: unknown type '\{name}' (expected one of: list, whole, decimal, date, time, textLength, custom)",
      )
  }
}

///|
/// Maps a `validate` op's `operator` string to a `DataValidationOperator`.
fn validation_operator_of(
  name : String,
) -> @xlsx.DataValidationOperator raise BatchError {
  match name {
    "between" => Between
    "notBetween" => NotBetween
    "equal" => Equal
    "notEqual" => NotEqual
    "greaterThan" => GreaterThan
    "greaterThanOrEqual" => GreaterThanOrEqual
    "lessThan" => LessThan
    "lessThanOrEqual" => LessThanOrEqual
    _ =>
      raise BatchError(
        "validate: unknown operator '\{name}' (expected one of: between, notBetween, equal, notEqual, greaterThan, greaterThanOrEqual, lessThan, lessThanOrEqual)",
      )
  }
}

///|
/// Maps a `validate` op's `error_style` string to a
/// `DataValidationErrorStyle`. An empty string means the Excel default
/// (`stop`).
fn validation_error_style_of(
  name : String,
) -> @xlsx.DataValidationErrorStyle raise BatchError {
  match name {
    "" | "stop" => Stop
    "warning" => Warning
    "information" => Information
    _ =>
      raise BatchError(
        "validate: unknown error_style '\{name}' (expected one of: stop, warning, information)",
      )
  }
}

///|
/// Rejects `operator`/`formula1`/`formula2` a `validate` type does not use,
/// so an agent hears about an irrelevant param instead of it being silently
/// dropped. Callers pass `formula1=""` for a type that legitimately uses it
/// (e.g. `custom`) so only the truly-unused ones are checked.
fn reject_unused_validate_params(
  validation_type : String,
  operator~ : String,
  formula1~ : String,
  formula2~ : String,
) -> Unit raise BatchError {
  if operator != "" {
    raise BatchError(
      "validate: type '\{validation_type}' does not take 'operator'",
    )
  }
  if formula1 != "" {
    raise BatchError(
      "validate: type '\{validation_type}' does not take 'formula1'",
    )
  }
  if formula2 != "" {
    raise BatchError(
      "validate: type '\{validation_type}' does not take 'formula2'",
    )
  }
}

///|
/// Rejects the list-only params (`values`/`source`) for a non-list `validate`
/// type.
fn reject_list_only_validate_params(
  validation_type : String,
  values~ : Array[String],
  source~ : String,
) -> Unit raise BatchError {
  if !values.is_empty() {
    raise BatchError(
      "validate: type '\{validation_type}' does not take 'values'",
    )
  }
  if source != "" {
    raise BatchError(
      "validate: type '\{validation_type}' does not take 'source'",
    )
  }
}

///|
/// Rejects inline dropdown values the engine's comma-join + quote cannot
/// faithfully represent: a value containing a comma (it would split into two
/// options) or a leading `=` on the first value (read as a formula, not a
/// literal list). Steers the caller to `source` with a cell range instead.
fn check_inline_list_values(values : Array[String]) -> Unit raise BatchError {
  for value in values {
    if value.contains(",") {
      raise BatchError(
        "validate: inline list value '\{value}' contains a comma; use 'source' with a cell range instead",
      )
    }
  }
  if values.length() > 0 && values[0].has_prefix("=") {
    raise BatchError(
      "validate: an inline list value must not start with '='; use 'source' with a cell range instead",
    )
  }
}

///|
/// The conditional-formatting `type` values the `cf` op supports — a focused
/// dashboard subset of the engine's full CF vocabulary.
let cf_supported_types : Array[String] = [
  "cell", "formula", "2_color_scale", "3_color_scale", "data_bar", "icon_set",
]

///|
fn is_supported_cf_type(cf_type : String) -> Bool {
  cf_supported_types.contains(cf_type)
}

///|
/// The classic (non-x14) icon-set styles valid in a plain `<iconSet>`.
/// `3Stars`, `3Triangles`, and `5Boxes` are x14-only — emitting them through
/// the classic element is schema-invalid — so the basic `cf` op excludes
/// them (they belong to the x14 CF op).
let cf_classic_icon_styles : Array[String] = [
  "3Arrows", "3ArrowsGray", "3Flags", "3Signs", "3Symbols", "3Symbols2", "3TrafficLights1",
  "3TrafficLights2", "4Arrows", "4ArrowsGray", "4Rating", "4RedToBlack", "4TrafficLights",
  "5Arrows", "5ArrowsGray", "5Quarters", "5Rating",
]

///|
/// Rejects an `icon_style` the classic `<iconSet>` cannot represent.
fn check_cf_icon_style(icon_style : String) -> Unit raise BatchError {
  if !cf_classic_icon_styles.contains(icon_style) {
    raise BatchError(
      "cf: icon_style '\{icon_style}' is not a classic icon set (expected one of: \{cf_classic_icon_styles.join(", ")}); 3Stars, 3Triangles, and 5Boxes are x14-only",
    )
  }
}

///|
/// Rejects a color-scale / data-bar stop `type` outside the classic cfvo
/// enum, which would otherwise be written verbatim as an invalid
/// `<cfvo type="...">`. An empty value keeps the engine default.
fn check_cfvo_type(param : String, value : String) -> Unit raise BatchError {
  match value {
    "" | "num" | "min" | "max" | "percent" | "percentile" | "formula" => ()
    _ =>
      raise BatchError(
        "cf: '\{param}' '\{value}' is not a valid stop type (expected one of: num, min, max, percent, percentile, formula)",
      )
  }
}

///|
/// Rejects a conditional-format color that is not a 6-digit hex RGB (an
/// optional leading `#` is allowed). The engine prepends the alpha byte, so
/// anything else — a name like `red`, a 3-digit shorthand, or an 8-digit
/// ARGB — would land in the `rgb` attribute as invalid OOXML.
fn check_cf_color(param : String, value : String) -> Unit raise BatchError {
  let hex = if value.has_prefix("#") { value[1:].to_owned() } else { value }
  let mut ok = hex.length() == 6
  if ok {
    for i in 0..<hex.length() {
      let c = hex[i].to_int()
      let is_num = c >= '0'.to_int() && c <= '9'.to_int()
      let is_upper = c >= 'A'.to_int() && c <= 'F'.to_int()
      let is_lower = c >= 'a'.to_int() && c <= 'f'.to_int()
      if !(is_num || is_upper || is_lower) {
        ok = false
        break
      }
    }
  }
  if !ok {
    raise BatchError(
      "cf: '\{param}' '\{value}' is not a 6-digit hex RGB color (e.g. FF0000)",
    )
  }
}

///|
/// Rejects a `cell` criteria outside the cellIs comparison operators. The
/// engine's shared criteria normalizer also accepts text and time-period
/// words (e.g. `today`, `containing`), which `build_cell_rule` would write
/// as an invalid cellIs `operator`; keep only the documented comparators.
fn check_cf_cell_criteria(criteria : String) -> Unit raise BatchError {
  match criteria.to_lower() {
    ">"
    | ">="
    | "<"
    | "<="
    | "="
    | "=="
    | "!="
    | "<>"
    | "between"
    | "not between"
    | "notbetween" => ()
    _ =>
      raise BatchError(
        "cf: cell criteria '\{criteria}' is not a comparison operator (expected one of: >, >=, <, <=, =, !=, between, not between)",
      )
  }
}

///|
/// The mode-specific params each `cf` type uses; any *other* non-default
/// param the script supplies is rejected so an agent hears about it instead
/// of it being silently dropped. (`sheet`/`range`/`type` are always allowed
/// and are not listed here.)
fn cf_allowed_params(cf_type : String) -> Array[String] {
  match cf_type {
    "cell" =>
      [
        "criteria", "value", "min_value", "max_value", "fill", "font_color", "bold",
        "italic", "stop_if_true",
      ]
    "formula" =>
      ["formula", "fill", "font_color", "bold", "italic", "stop_if_true"]
    "2_color_scale" =>
      [
        "min_type", "min_value", "min_color", "max_type", "max_value", "max_color",
      ]
    "3_color_scale" =>
      [
        "min_type", "min_value", "min_color", "mid_type", "mid_value", "mid_color",
        "max_type", "max_value", "max_color",
      ]
    "data_bar" =>
      [
        "bar_color", "min_type", "min_value", "max_type", "max_value",
        // x14 extended-bar options (any triggers the x14 data bar).
         "bar_solid", "bar_direction", "bar_border_color",
      ]
    "icon_set" => ["icon_style", "reverse_icons"]
    _ => []
  }
}
