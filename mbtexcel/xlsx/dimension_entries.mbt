// Read-only enumerators over the materialized row/column dimension records.
//
// Per-index getters (`get_row_height`, `row_visible`, `row_outline_level`,
// `get_row_style` and their column counterparts) can only probe one index at
// a time, and dimension-only lines beyond the stored-cell extent (for
// example a hidden band of rows holding no cells) are invisible to any scan
// bounded by the cell extent. These enumerators surface exactly the stored
// dimension records — the same records counted by
// `Workbook::materialized_row_column_dimension_count` — in ascending index
// order, without synthesizing defaults for unlisted indices.

///|
/// Returns every materialized row dimension record of this worksheet as
/// `(row, dimension)` pairs sorted by ascending 1-based row index.
///
/// Only rows with an explicitly stored dimension record — a custom height, a
/// hidden flag, a non-zero outline level, or a row-level style — are yielded.
/// Rows using the sheet defaults are absent even when they hold cells, and
/// dimension-only rows beyond the stored-cell extent are included. For every
/// yielded pair the fields agree with the per-index getters: `height` with
/// `get_row_height`, `hidden` with `!row_visible`, `outline_level` with
/// `row_outline_level`, and `style_id` with `get_row_style`.
///
/// # Example
/// ```mbt check
/// test {
///   let workbook = @xlsx.Workbook::new()
///   ignore(workbook.add_sheet("Sheet1"))
///   let sheet = workbook.sheet("Sheet1").unwrap()
///   debug_inspect(sheet.materialized_row_dimensions(), content="[]")
///   workbook.set_row_visible("Sheet1", 7000, false)
///   workbook.set_row_height("Sheet1", 2, 24.5)
///   let summary : Array[(Int, Double?, Bool)] = []
///   for entry in sheet.materialized_row_dimensions() {
///     let (row, dim) = entry
///     summary.push((row, dim.height, dim.hidden))
///   }
///   debug_inspect(summary, content="[(2, Some(24.5), false), (7000, None, true)]")
/// }
/// ```
pub fn Worksheet::materialized_row_dimensions(
  self : Worksheet,
) -> Array[(Int, RowDimension)] {
  let entries : Array[(Int, RowDimension)] = []
  for row, dim in self.row_dimensions {
    entries.push((row, dim))
  }
  entries.sort_by((left, right) => left.0.compare(right.0))
  entries
}

///|
/// Returns every materialized column dimension record of this worksheet as
/// `(column, dimension)` pairs sorted by ascending 1-based column index.
///
/// Only columns with an explicitly stored dimension record — a custom width,
/// a hidden flag, a non-zero outline level, or a column-level style — are
/// yielded; columns using the sheet defaults are absent. For every yielded
/// pair the fields agree with the per-index getters: `width` with
/// `get_col_width`, `hidden` with `!col_visible`, `outline_level` with
/// `col_outline_level`, and `style_id` with `get_col_style`.
///
/// # Example
/// ```mbt check
/// test {
///   let workbook = @xlsx.Workbook::new()
///   ignore(workbook.add_sheet("Sheet1"))
///   let sheet = workbook.sheet("Sheet1").unwrap()
///   debug_inspect(sheet.materialized_col_dimensions(), content="[]")
///   workbook.set_col_width("Sheet1", 3, 18.5)
///   workbook.set_col_visible("Sheet1", 1, false)
///   let summary : Array[(Int, Double?, Bool)] = []
///   for entry in sheet.materialized_col_dimensions() {
///     let (col, dim) = entry
///     summary.push((col, dim.width, dim.hidden))
///   }
///   debug_inspect(summary, content="[(1, None, true), (3, Some(18.5), false)]")
/// }
/// ```
pub fn Worksheet::materialized_col_dimensions(
  self : Worksheet,
) -> Array[(Int, ColDimension)] {
  let entries : Array[(Int, ColDimension)] = []
  for col, dim in self.col_dimensions {
    entries.push((col, dim))
  }
  entries.sort_by((left, right) => left.0.compare(right.0))
  entries
}

///|
/// Returns every materialized row dimension record on `sheet_name` as
/// `(row, dimension)` pairs sorted by ascending 1-based row index. See
/// `Worksheet::materialized_row_dimensions` for the record contract.
///
/// Raises `XlsxError` if the sheet name is invalid or no matching sheet
/// exists.
pub fn Workbook::get_row_dimensions(
  self : Workbook,
  sheet_name : StringView,
) -> Array[(Int, RowDimension)] raise XlsxError {
  self.require_sheet(sheet_name).materialized_row_dimensions()
}

///|
/// Returns every materialized column dimension record on `sheet_name` as
/// `(column, dimension)` pairs sorted by ascending 1-based column index. See
/// `Worksheet::materialized_col_dimensions` for the record contract.
///
/// Raises `XlsxError` if the sheet name is invalid or no matching sheet
/// exists.
pub fn Workbook::get_col_dimensions(
  self : Workbook,
  sheet_name : StringView,
) -> Array[(Int, ColDimension)] raise XlsxError {
  self.require_sheet(sheet_name).materialized_col_dimensions()
}
