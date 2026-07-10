// Builds the `xlsx.cells/1` payload: a structured read of a cell range with
// formatted values, typed raw values, formulas, and a deduplicated style
// map. Bounded by `parse_range`'s cell cap.

///|
/// Builds the `xlsx.cells/1` JSON payload for `range` (a single cell or an
/// `A1:B2`-style range) on `sheet`. A cell appears in `cells` when it has a
/// stored value, a formula, or a style; fully-absent cells are omitted, so
/// absence means blank-and-unstyled. Raises `@xlsx.XlsxError` for malformed
/// references or a missing sheet and `RangeError` for an oversized range.
pub fn cells(
  workbook : @xlsx.Workbook,
  file~ : String,
  sheet : String,
  range : String,
) -> Json raise {
  let parsed = parse_range(range)
  let entries = []
  let style_ids = []
  for row in parsed.row_lo..<=parsed.row_hi {
    for col in parsed.col_lo..<=parsed.col_hi {
      let cell = @xlsx.coordinates_to_cell_name(col, row)
      match cell_json(workbook, sheet, cell, style_ids) {
        Some(entry) => entries.push(entry)
        None => ()
      }
    }
  }
  let styles : Map[String, Json] = {}
  for style_id in style_ids {
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
/// One cell's entry, or `None` for a fully-absent cell. Appends newly seen
/// style ids to `style_ids` (in first-reference order).
fn cell_json(
  workbook : @xlsx.Workbook,
  sheet : String,
  cell : String,
  style_ids : Array[Int],
) -> Json? raise @xlsx.XlsxError {
  let raw = workbook.get_cell_value_raw(sheet, cell)
  let formula = workbook.get_cell_formula(sheet, cell)
  let style_id = workbook.get_cell_style(sheet, cell)
  if raw is None && formula is None && style_id is None {
    return None
  }
  let out : Map[String, Json] = { "ref": Json::string(cell) }
  match raw {
    Some(value) => {
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
  match style_id {
    Some(style_id) => {
      out["style_id"] = Json::number(style_id.to_double())
      if !style_ids.contains(style_id) {
        style_ids.push(style_id)
      }
    }
    None => ()
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
