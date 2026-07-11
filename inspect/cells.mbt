// Builds the `xlsx.cells/1` payload: a structured read of a cell range with
// formatted values, typed raw values, formulas, and a deduplicated style
// map. Bounded by `parse_range`'s cell cap.

///|
/// Builds the `xlsx.cells/1` JSON payload for `range` (a single cell or an
/// `A1:B2`-style range) on `sheet`. A cell appears in `cells` when it has a
/// stored non-empty value, a formula, or a non-default effective style
/// (cell → row → column precedence, so a blank cell inside a styled row or
/// column is reported); fully-absent cells are omitted, so absence means
/// blank-and-unstyled. Raises `RangeError` for a malformed reference or an
/// oversized range and `@xlsx.XlsxError` for a missing sheet.
pub fn cells(
  workbook : @xlsx.Workbook,
  file~ : String,
  sheet : String,
  range : String,
) -> Json raise {
  let parsed = parse_range(range)
  let entries = []
  let style_order : Array[Int] = []
  let style_seen : Map[Int, Unit] = Map([])
  for row in parsed.row_lo..<=parsed.row_hi {
    for col in parsed.col_lo..<=parsed.col_hi {
      let cell = @xlsx.coordinates_to_cell_name(col, row)
      match
        cell_json(workbook, sheet, cell, row~, col~, style_order, style_seen) {
        Some(entry) => entries.push(entry)
        None => ()
      }
    }
  }
  let styles : Map[String, Json] = Map([])
  for style_id in style_order {
    styles["\{style_id}"] = style_to_json(workbook.get_style(style_id))
  }
  Json::object({
    "schema": Json::string(SCHEMA_CELLS),
    "file": Json::string(file),
    "sheet": Json::string(sheet),
    "range": Json::string(parsed.range_ref()),
    "cells": Json::array(entries),
    "styles": Json::object(styles),
  })
}

///|
/// The style that formats this coordinate, mirroring the write-side
/// precedence (excelize's `prepareCellStyle`): the cell's own non-zero
/// style, else the row style, else the column style, else 0.
pub fn effective_style_id(
  workbook : @xlsx.Workbook,
  sheet : String,
  cell : String,
  row~ : Int,
  col~ : Int,
) -> Int raise @xlsx.XlsxError {
  match workbook.get_cell_style(sheet, cell) {
    Some(style_id) if style_id != 0 => style_id
    _ =>
      match workbook.get_row_style(sheet, row) {
        Some(style_id) if style_id != 0 => style_id
        _ =>
          match workbook.get_col_style(sheet, col) {
            Some(style_id) if style_id != 0 => style_id
            _ => 0
          }
      }
  }
}

///|
/// One cell's entry, or `None` for a fully-absent cell. Appends newly seen
/// style ids to `style_order` (in first-reference order); `style_seen`
/// makes membership O(1).
fn cell_json(
  workbook : @xlsx.Workbook,
  sheet : String,
  cell : String,
  row~ : Int,
  col~ : Int,
  style_order : Array[Int],
  style_seen : Map[Int, Unit],
) -> Json? raise @xlsx.XlsxError {
  // An empty-string cell is a synthetic blank — `set_cell_style` on a bare
  // cell and an uncached formula both store one — so it carries no `value`;
  // reporting it would make a blank look like it contains "".
  let raw = match workbook.get_cell_value_raw(sheet, cell) {
    Some(String("")) => None
    other => other
  }
  let formula = workbook.get_cell_formula(sheet, cell)
  let style_id = effective_style_id(workbook, sheet, cell, row~, col~)
  if raw is None && formula is None && style_id == 0 {
    return None
  }
  let out : Map[String, Json] = { "ref": Json::string(cell) }
  match raw {
    Some(value) => {
      // The formatted display string applies the cell's own number format
      // (excelize-parity: `GetCellValue` does not inherit row/column
      // formats), while `style_id` reports the effective style.
      out["value"] = Json::string(
        workbook.get_cell_value(sheet, cell).unwrap_or(""),
      )
      out["raw"] = raw_json(value)
    }
    None => ()
  }
  match formula {
    Some(formula) => out["formula"] = Json::string(formula)
    None => ()
  }
  if style_id != 0 {
    out["style_id"] = Json::number(style_id.to_double())
    if !style_seen.contains(style_id) {
      style_seen[style_id] = ()
      style_order.push(style_id)
    }
  }
  Some(Json::object(out))
}

///|
fn raw_json(value : @xlsx.CellValue) -> Json {
  match value {
    String(text) =>
      Json::object({
        "type": Json::string("string"),
        "value": Json::string(text),
      })
    Numeric(number) =>
      Json::object({
        "type": Json::string("number"),
        "value": Json::number(number),
      })
    Bool(flag) =>
      Json::object({
        "type": Json::string("bool"),
        "value": Json::boolean(flag),
      })
    Error(code) =>
      Json::object({
        "type": Json::string("error"),
        "value": Json::string(code),
      })
  }
}
