// Reverse lookup from builtin number-format ids to format-code strings.
//
// The forward knowledge lives in `format_number_builtin`
// (`value_format.mbt`): it renders builtin ids either through
// `format_number_simple` (ids 1-4, 9, 10 — whose behavior matches the codes
// "0", "0.00", "#,##0", "#,##0.00", "0%", "0.00%") or through
// `format_excel_date` with a literal pattern (ids 14-22). This table is that
// mapping inverted, entry for entry; `builtin_num_fmt_test.mbt` pins the
// equivalence by rendering every covered id against its code over a value
// battery.

///|
/// Returns the format-code string equivalent to builtin number-format `id`,
/// or `None` when the engine has no fixed code for it.
///
/// Coverage is exactly the ids the engine's value formatter
/// (`format_number_builtin`) renders with a fixed, culture-independent
/// pattern under default `Options`:
///
/// - 1: `0`
/// - 2: `0.00`
/// - 3: `#,##0`
/// - 4: `#,##0.00`
/// - 9: `0%`
/// - 10: `0.00%`
/// - 14: `mm-dd-yy`
/// - 15: `d-mmm-yy`
/// - 16: `d-mmm`
/// - 17: `mmm-yy`
/// - 18: `h:mm AM/PM`
/// - 19: `h:mm:ss AM/PM`
/// - 20: `hh:mm`
/// - 21: `hh:mm:ss`
/// - 22: `m/d/yy hh:mm`
///
/// Every other id returns `None`:
///
/// - 0 (General) is the default rendering — the formatter passes the raw
///   value through, which no explicit format code reproduces exactly;
/// - 27-36, 50-62 and 67-81 are language builtins whose meaning depends on
///   the workbook culture (see `Options::culture_info`);
/// - the remaining builtin ids (5-8, 11-13, 23-26, 37-49, 63-66, ...) are
///   ones the formatter does not implement and renders as the raw value.
///
/// Equivalence domain — the returned code renders identically to the
/// builtin id for **numeric cell values** under default `Options`
/// (`builtin_num_fmt_test.mbt` pins this per id over a value battery).
/// Outside that domain the engine's two paths intentionally differ:
///
/// - text cells render raw under any `Builtin` format but are run through
///   the code's text/literal pattern under a `Custom` format;
/// - for the date-pattern ids (14-22), a value that is not a valid
///   non-negative date serial renders as the raw value under the builtin id
///   while the custom-code path may prefix a minus sign;
/// - ids 14, 15, 20, 21 and 22 honor the `Options` `short_date_pattern` /
///   `long_date_pattern` / `long_time_pattern` overrides when rendered as
///   builtins; the codes returned here are the default patterns used when
///   no override is set.
///
/// # Example
/// ```mbt check
/// test {
///   debug_inspect(
///     @xlsx.builtin_number_format_code(4),
///     content="Some(\"#,##0.00\")",
///   )
///   debug_inspect(
///     @xlsx.builtin_number_format_code(14),
///     content="Some(\"mm-dd-yy\")",
///   )
///   debug_inspect(@xlsx.builtin_number_format_code(0), content="None")
///   debug_inspect(@xlsx.builtin_number_format_code(30), content="None")
/// }
/// ```
pub fn builtin_number_format_code(id : Int) -> String? {
  match id {
    1 => Some("0")
    2 => Some("0.00")
    3 => Some("#,##0")
    4 => Some("#,##0.00")
    9 => Some("0%")
    10 => Some("0.00%")
    14 => Some("mm-dd-yy")
    15 => Some("d-mmm-yy")
    16 => Some("d-mmm")
    17 => Some("mmm-yy")
    18 => Some("h:mm AM/PM")
    19 => Some("h:mm:ss AM/PM")
    20 => Some("hh:mm")
    21 => Some("hh:mm:ss")
    22 => Some("m/d/yy hh:mm")
    _ => None
  }
}
