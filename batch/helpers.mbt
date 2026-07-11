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
