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
let chart_type_values : Array[String] = [
  "col", "column", "bar", "line", "pie", "area", "scatter", "doughnut", "donut",
  "radar",
]

///|
let sheet_action_values : Array[String] = [
  "rename", "delete", "hide", "show", "very-hide",
]

///|
let row_action_values : Array[String] = ["hide", "show", "height"]

///|
let column_action_values : Array[String] = ["hide", "show"]

///|
let border_style_values : Array[String] = [
  "thin", "medium", "thick", "dashed", "dotted", "double", "hair",
]

///|
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
let validation_type_values : Array[String] = [
  "list", "whole", "decimal", "date", "time", "textLength", "custom",
]

///|
let validation_operator_values : Array[String] = [
  "between", "notBetween", "equal", "notEqual", "greaterThan", "greaterThanOrEqual",
  "lessThan", "lessThanOrEqual",
]

///|
let validation_error_style_values : Array[String] = [
  "stop", "warning", "information",
]

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
/// Validates every data-validation enum and action-dependent parameter without
/// touching a workbook. Batch parsing calls this before source package I/O;
/// application repeats the checks defensively while constructing the engine
/// object.
fn validate_data_validation_contract(
  validation_type : String,
  operator : String,
  formula1 : String,
  formula2 : String,
  values : Array[String],
  source : String,
  error_style : String,
) -> Unit raise BatchError {
  ignore(validation_error_style_of(error_style))
  match validation_type {
    "list" => {
      reject_unused_validate_params(
        validation_type,
        operator~,
        formula1~,
        formula2~,
      )
      if !values.is_empty() {
        check_inline_list_values(values)
      } else if source == "" {
        raise BatchError("validate: type 'list' requires 'values' or 'source'")
      }
    }
    "custom" => {
      reject_unused_validate_params(
        validation_type,
        operator~,
        formula1="",
        formula2~,
      )
      reject_list_only_validate_params(validation_type, values~, source~)
      if formula1 == "" {
        raise BatchError("validate: type 'custom' requires 'formula1'")
      }
    }
    "whole" | "decimal" | "date" | "time" | "textLength" => {
      reject_list_only_validate_params(validation_type, values~, source~)
      if operator == "" {
        raise BatchError(
          "validate: type '\{validation_type}' requires 'operator'",
        )
      }
      if formula1 == "" {
        raise BatchError(
          "validate: type '\{validation_type}' requires 'formula1'",
        )
      }
      ignore(validation_operator_of(operator))
      let two_bound = operator == "between" || operator == "notBetween"
      if two_bound && formula2 == "" {
        raise BatchError("validate: operator '\{operator}' requires 'formula2'")
      }
      if !two_bound && formula2 != "" {
        raise BatchError(
          "validate: operator '\{operator}' does not take 'formula2'",
        )
      }
      ignore(validation_type_of(validation_type))
    }
    other =>
      raise BatchError(
        "validate: unknown type '\{other}' (expected one of: \{validation_type_values.join(", ")})",
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
let cf_stop_type_values : Array[String] = [
  "num", "min", "max", "percent", "percentile", "formula",
]

///|
let cf_bar_direction_values : Array[String] = ["leftToRight", "rightToLeft"]

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
/// Whether `value` is a 6-digit hex RGB color (an optional leading `#`).
fn is_hex6_color(value : String) -> Bool {
  let hex = if value.has_prefix("#") { value[1:].to_owned() } else { value }
  if hex.length() != 6 {
    return false
  }
  for i in 0..<hex.length() {
    let c = hex[i].to_int()
    let is_num = c >= '0'.to_int() && c <= '9'.to_int()
    let is_upper = c >= 'A'.to_int() && c <= 'F'.to_int()
    let is_lower = c >= 'a'.to_int() && c <= 'f'.to_int()
    if !(is_num || is_upper || is_lower) {
      return false
    }
  }
  true
}

///|
fn check_cf_color(param : String, value : String) -> Unit raise BatchError {
  if !is_hex6_color(value) {
    raise BatchError(
      "cf: '\{param}' '\{value}' is not a 6-digit hex RGB color (e.g. FF0000)",
    )
  }
}

///|
/// Maps a `style` op's border-style name to its OOXML style code.
fn border_style_of(name : String) -> Int raise BatchError {
  match name {
    "thin" => 1
    "medium" => 2
    "dashed" => 3
    "dotted" => 4
    "thick" => 5
    "double" => 6
    "hair" => 7
    _ =>
      raise BatchError(
        "style: unknown border style '\{name}' (expected one of: thin, medium, thick, dashed, dotted, double, hair)",
      )
  }
}

///|
/// Builds the `Border` list for a `style` op: `all` applies to every side, a
/// non-empty per-side value overrides it for that side, and `color` (a 6-hex
/// RGB, validated) colors the lines. Empty when no border is requested.
fn build_cell_borders(
  all~ : String,
  top~ : String,
  bottom~ : String,
  left~ : String,
  right~ : String,
  color~ : String,
) -> Array[@xlsx.Border] raise BatchError {
  if color != "" && !is_hex6_color(color) {
    raise BatchError(
      "style: 'border_color' '\{color}' is not a 6-digit hex RGB color (e.g. FF0000)",
    )
  }
  let borders = []
  fn add_side(side : String, style_name : String) -> Unit raise BatchError {
    let resolved = if style_name != "" { style_name } else { all }
    if resolved != "" {
      let code = border_style_of(resolved)
      borders.push(
        if color != "" {
          @xlsx.Border::with_values(side, color~, style=code)
        } else {
          @xlsx.Border::with_values(side, style=code)
        },
      )
    }
  }

  add_side("top", top)
  add_side("bottom", bottom)
  add_side("left", left)
  add_side("right", right)
  borders
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

///|
fn validate_conditional_format_contract(
  cf_type : String,
  criteria : String,
  value : String,
  min_value : String,
  max_value : String,
  formula : String,
  fill : String,
  font_color : String,
  bold : Bool?,
  italic : Bool?,
  min_type : String,
  mid_type : String,
  max_type : String,
  mid_value : String,
  min_color : String,
  mid_color : String,
  max_color : String,
  bar_color : String,
  bar_solid : Bool?,
  bar_direction : String,
  bar_border_color : String,
  icon_style : String,
  reverse_icons : Bool?,
  stop_if_true : Bool?,
) -> Unit raise BatchError {
  if !is_supported_cf_type(cf_type) {
    raise BatchError(
      "cf: unknown type '\{cf_type}' (expected one of: \{cf_supported_types.join(", ")})",
    )
  }
  let present : Array[(String, Bool)] = [
    ("criteria", criteria != ""),
    ("value", value != ""),
    ("min_value", min_value != ""),
    ("max_value", max_value != ""),
    ("formula", formula != ""),
    ("fill", fill != ""),
    ("font_color", font_color != ""),
    ("bold", bold is Some(_)),
    ("italic", italic is Some(_)),
    ("min_type", min_type != ""),
    ("mid_type", mid_type != ""),
    ("max_type", max_type != ""),
    ("mid_value", mid_value != ""),
    ("min_color", min_color != ""),
    ("mid_color", mid_color != ""),
    ("max_color", max_color != ""),
    ("bar_color", bar_color != ""),
    ("bar_solid", bar_solid is Some(_)),
    ("bar_direction", bar_direction != ""),
    ("bar_border_color", bar_border_color != ""),
    ("icon_style", icon_style != ""),
    ("reverse_icons", reverse_icons is Some(_)),
    ("stop_if_true", stop_if_true is Some(_)),
  ]
  let allowed = cf_allowed_params(cf_type)
  for entry in present {
    let (name, supplied) = entry
    if supplied && !allowed.contains(name) {
      raise BatchError("cf: type '\{cf_type}' does not take '\{name}'")
    }
  }
  let style_set = fill != "" ||
    font_color != "" ||
    bold is Some(true) ||
    italic is Some(true)
  match cf_type {
    "cell" => {
      if criteria == "" {
        raise BatchError("cf: type 'cell' requires 'criteria'")
      }
      check_cf_cell_criteria(criteria)
      if !style_set {
        raise BatchError(
          "cf: type 'cell' requires a highlight (fill, font_color, bold, or italic)",
        )
      }
      let normalized = criteria.to_lower()
      let between = normalized == "between" ||
        normalized == "not between" ||
        normalized == "notbetween"
      if between {
        if min_value == "" || max_value == "" {
          raise BatchError(
            "cf: a '\{criteria}' rule requires 'min_value' and 'max_value'",
          )
        }
        if value != "" {
          raise BatchError(
            "cf: a '\{criteria}' rule takes 'min_value'/'max_value', not 'value'",
          )
        }
      } else {
        if value == "" {
          raise BatchError("cf: type 'cell' requires 'value'")
        }
        if min_value != "" || max_value != "" {
          raise BatchError(
            "cf: only a between/notBetween rule takes 'min_value'/'max_value'",
          )
        }
      }
    }
    "formula" => {
      if formula == "" {
        raise BatchError("cf: type 'formula' requires 'formula'")
      }
      if !style_set {
        raise BatchError(
          "cf: type 'formula' requires a highlight (fill, font_color, bold, or italic)",
        )
      }
    }
    "2_color_scale" => {
      if min_color == "" || max_color == "" {
        raise BatchError(
          "cf: type '2_color_scale' requires 'min_color' and 'max_color'",
        )
      }
      check_cf_color("min_color", min_color)
      check_cf_color("max_color", max_color)
      check_cfvo_type("min_type", min_type)
      check_cfvo_type("max_type", max_type)
    }
    "3_color_scale" => {
      if min_color == "" || mid_color == "" || max_color == "" {
        raise BatchError(
          "cf: type '3_color_scale' requires 'min_color', 'mid_color', and 'max_color'",
        )
      }
      check_cf_color("min_color", min_color)
      check_cf_color("mid_color", mid_color)
      check_cf_color("max_color", max_color)
      check_cfvo_type("min_type", min_type)
      check_cfvo_type("mid_type", mid_type)
      check_cfvo_type("max_type", max_type)
    }
    "data_bar" => {
      check_cfvo_type("min_type", min_type)
      check_cfvo_type("max_type", max_type)
      if bar_color != "" {
        check_cf_color("bar_color", bar_color)
      }
      if bar_direction != "" && !cf_bar_direction_values.contains(bar_direction) {
        raise BatchError(
          "cf: bar_direction '\{bar_direction}' is not valid (expected leftToRight or rightToLeft)",
        )
      }
      if bar_border_color != "" {
        check_cf_color("bar_border_color", bar_border_color)
      }
    }
    "icon_set" => {
      if icon_style == "" {
        raise BatchError("cf: type 'icon_set' requires 'icon_style'")
      }
      check_cf_icon_style(icon_style)
    }
    _ => ()
  }
  if fill != "" {
    check_cf_color("fill", fill)
  }
  if font_color != "" {
    check_cf_color("font_color", font_color)
  }
}
