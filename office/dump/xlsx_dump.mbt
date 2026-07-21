///|
/// Errors raised while producing a dump. Self-check failures mean the dump
/// engine produced an op its own batch parser refuses — a dump bug, never
/// silently emitted.
pub suberror DumpError {
  DumpCancelled
  DumpUnsupported(String)
  DumpSelfCheckFailed(String)
} derive(@debug.Debug)

///|
/// The XLSX batch schema every dump op stream targets.
pub const XLSX_BATCH_SCHEMA : String = "xlsx.batch/1"

///|
fn dump_op(op : String, params : Map[String, Json]) -> Json {
  Json::object({ "op": Json::string(op), "params": Json::object(params) })
}

///|
fn dump_location(sheet : String, key : String, value : String) -> Json {
  let fields : Map[String, Json] = { "sheet": Json::string(sheet) }
  fields[key] = Json::string(value)
  Json::object(fields)
}

///|
fn check_cancelled(cancelled : () -> Bool) -> Unit raise DumpError {
  if cancelled() {
    raise DumpCancelled
  }
}

///|
/// Canonical batch JSON for a typed cell value. Numbers pass through as
/// doubles: integral doubles become integer cells at apply time, matching
/// the engine's own normalization.
fn cell_value_json(value : @xlsx.CellValue) -> Json? {
  match value {
    String(text) => Some(Json::string(text))
    Numeric(number) => Some(Json::number(number))
    Bool(flag) => Some(Json::boolean(flag))
    Error(_) => None
  }
}

///|
/// Emits width/row/col dimension ops in canonical ascending order (columns
/// before rows), with residual records for outline levels and line-default
/// styles the op vocabulary cannot express. These precede cell ops so a
/// replayed sheet sizes itself before it fills.
fn dump_sheet_dimensions(
  worksheet : @xlsx.Worksheet,
  sheet : String,
  ops : Array[Json],
  residual : Array[DumpResidual],
) -> Unit raise {
  let cols = worksheet.materialized_col_dimensions()
  cols.sort_by((a, b) => a.0 - b.0)
  for entry in cols {
    let (index, dim) = entry
    let name = @xlsx.column_number_to_name(index)
    match dim.width {
      Some(width) =>
        ops.push(
          dump_op("width", {
            "sheet": Json::string(sheet),
            "column": Json::string(name),
            "width": Json::number(width),
          }),
        )
      None => ()
    }
    if dim.hidden {
      ops.push(
        dump_op("col", {
          "sheet": Json::string(sheet),
          "action": Json::string("hide"),
          "at": Json::string(name),
        }),
      )
    }
    dump_dimension_residuals(
      sheet,
      "col",
      name,
      dim.outline_level,
      dim.style_id,
      residual,
    )
  }
  let rows = worksheet.materialized_row_dimensions()
  rows.sort_by((a, b) => a.0 - b.0)
  for entry in rows {
    let (index, dim) = entry
    match dim.height {
      Some(height) =>
        ops.push(
          dump_op("row", {
            "sheet": Json::string(sheet),
            "action": Json::string("height"),
            "at": Json::number(index.to_double()),
            "height": Json::number(height),
          }),
        )
      None => ()
    }
    if dim.hidden {
      ops.push(
        dump_op("row", {
          "sheet": Json::string(sheet),
          "action": Json::string("hide"),
          "at": Json::number(index.to_double()),
        }),
      )
    }
    dump_dimension_residuals(
      sheet,
      "row",
      index.to_string(),
      dim.outline_level,
      dim.style_id,
      residual,
    )
  }
}

///|
/// Records the dimension attributes no op parameter carries: outline
/// (grouping) levels and line-default style ids.
fn dump_dimension_residuals(
  sheet : String,
  axis : String,
  at : String,
  outline_level : Int,
  style_id : Int?,
  residual : Array[DumpResidual],
) -> Unit {
  let location = Json::object({
    "sheet": Json::string(sheet),
    "axis": Json::string(axis),
    "at": Json::string(at),
  })
  if outline_level > 0 {
    residual.push({
      code: "xlsx.\{axis}_outline_level_dropped",
      severity: "dropped",
      scope: "sheet",
      location,
      asset: None,
      detail: "\{axis} outline level \{outline_level} is not expressible in \{XLSX_BATCH_SCHEMA}",
    })
  }
  if style_id is Some(_) {
    residual.push({
      code: "xlsx.\{axis}_default_style_dropped",
      severity: "dropped",
      scope: "sheet",
      location,
      asset: None,
      detail: "\{axis}-level default style is not expressible in \{XLSX_BATCH_SCHEMA}",
    })
  }
}

///|
/// Emits the row-major `set`/`formula` ops for one worksheet's stored
/// cells, with residual records for every stored cell the op vocabulary
/// cannot express.
fn dump_sheet_cells(
  workbook : @xlsx.Workbook,
  worksheet : @xlsx.Worksheet,
  sheet : String,
  ops : Array[Json],
  residual : Array[DumpResidual],
  cancelled : () -> Bool,
) -> Unit raise {
  // The reader may return more than one entry for a coordinate in a
  // noncanonical sheet; its defined behavior takes the first occurrence,
  // so dedup by reference keeping the first before sorting. Sorting on the
  // now-unique (row, col) is total, so the emitted order is deterministic
  // regardless of the sort's stability.
  let seen : Set[String] = Set::new()
  let cells : Array[@xlsx.Cell] = []
  for cell in worksheet.cells {
    if seen.contains(cell.reference) {
      continue
    }
    seen.add(cell.reference)
    cells.push(cell)
  }
  cells.sort_by((a, b) => {
    if a.row == b.row {
      a.col - b.col
    } else {
      a.row - b.row
    }
  })
  for cell in cells {
    check_cancelled(cancelled)
    match cell.formula {
      Some(_) => {
        // formula cells: cached values are intentionally dropped (they
        // cannot be replayed); shared formulas translate per cell
        match cell.formula_type {
          Some(Array) | Some(DataTable) => {
            residual.push({
              code: "xlsx.array_formula_unsupported",
              severity: "dropped",
              scope: "cell",
              location: dump_location(sheet, "cell", cell.reference),
              asset: None,
              detail: "array/data-table formulas are not expressible in \{XLSX_BATCH_SCHEMA}",
            })
            continue
          }
          _ => ()
        }
        let text = match cell.formula_shared_index {
          Some(index) =>
            match worksheet.shared_formula_master(index, cancelled~) {
              Some(master) => master.translate_to(cell.row, cell.col)
              None => {
                residual.push({
                  code: "xlsx.shared_formula_master_missing",
                  severity: "dropped",
                  scope: "cell",
                  location: dump_location(sheet, "cell", cell.reference),
                  asset: None,
                  detail: "shared formula group \{index} has no master in range",
                })
                continue
              }
            }
          None =>
            match cell.formula {
              Some(stored) => stored
              None => continue
            }
        }
        if text == "" {
          residual.push({
            code: "xlsx.empty_formula_dropped",
            severity: "dropped",
            scope: "cell",
            location: dump_location(sheet, "cell", cell.reference),
            asset: None,
            detail: "stored formula cell carries no formula text",
          })
          continue
        }
        ops.push(
          dump_op("formula", {
            "sheet": Json::string(sheet),
            "cell": Json::string(cell.reference),
            "formula": Json::string(text),
          }),
        )
      }
      None => {
        if cell.rich_text is Some(runs) {
          // flatten to plain text, and say so
          let flattened = StringBuilder::new()
          for run in runs {
            flattened.write_string(run.text)
          }
          ops.push(
            dump_op("set", {
              "sheet": Json::string(sheet),
              "cell": Json::string(cell.reference),
              "value": Json::string(flattened.to_string()),
            }),
          )
          residual.push({
            code: "xlsx.rich_text_flattened",
            severity: "approximated",
            scope: "cell",
            location: dump_location(sheet, "cell", cell.reference),
            asset: None,
            detail: "in-cell rich text runs flattened to plain text",
          })
          continue
        }
        match
          (workbook.get_cell_value_raw(sheet, cell.reference) catch {
            _ => None
          }) {
          Some(Error(text)) =>
            residual.push({
              code: "xlsx.error_cell_unsupported",
              severity: "dropped",
              scope: "cell",
              location: dump_location(sheet, "cell", cell.reference),
              asset: None,
              detail: "literal error cell (\{text}) has no set representation",
            })
          Some(value) =>
            match cell_value_json(value) {
              Some(encoded) =>
                ops.push(
                  dump_op("set", {
                    "sheet": Json::string(sheet),
                    "cell": Json::string(cell.reference),
                    "value": encoded,
                  }),
                )
              None => ()
            }
          None => ()
          // blank stored cells (style-only) emit nothing here: replaying
          // a `set` would materialize a string cell where none existed
        }
      }
    }
  }
}

///|
/// The number of cells a `start:end` range covers, or None when either
/// endpoint is unparseable. Computed directly from coordinates so it never
/// hits the reader's own range cap.
fn range_cell_count(range : String) -> Int64? {
  let (start, end) = match range.find(":") {
    Some(colon) =>
      (
        range.substring(start=0, end=colon),
        range.substring(start=colon + 1, end=range.length()),
      )
    None => (range, range)
  }
  guard (try? @xlsx.cell_name_to_coordinates(start)) is Ok((c1, r1)) else {
    return None
  }
  guard (try? @xlsx.cell_name_to_coordinates(end)) is Ok((c2, r2)) else {
    return None
  }
  let cols = (c2 - c1).abs() + 1
  let rows = (r2 - r1).abs() + 1
  Some(cols.to_int64() * rows.to_int64())
}

///|
/// Whether a range is small enough for the batch parser to accept
/// (`@inspect.parse_range` enforces `MAX_RANGE_CELLS`). A larger range must
/// degrade to a residual, never to a self-check failure.
fn range_within_batch_ceiling(range : String) -> Bool {
  match range_cell_count(range) {
    Some(count) => count <= @inspect.MAX_RANGE_CELLS
    None => true
  }
}

///|
/// Emits `merge` ops sorted by their top-left coordinate, then by full
/// range text so shared top-left coordinates stay deterministic. Ranges
/// beyond the batch range ceiling degrade to a residual.
fn dump_sheet_merges(
  workbook : @xlsx.Workbook,
  sheet : String,
  ops : Array[Json],
  residual : Array[DumpResidual],
) -> Unit raise {
  let merges = workbook.get_merge_cells(sheet).copy()
  let keyed : Array[(Int, Int, String)] = []
  for range in merges {
    let start = match range.find(":") {
      Some(colon) => range.substring(start=0, end=colon)
      None => range
    }
    let (col, row) = @xlsx.cell_name_to_coordinates(start) catch {
      _ => continue
    }
    keyed.push((row, col, range))
  }
  keyed.sort_by((a, b) => {
    if a.0 == b.0 {
      if a.1 == b.1 {
        a.2.compare(b.2)
      } else {
        a.1 - b.1
      }
    } else {
      a.0 - b.0
    }
  })
  for entry in keyed {
    if range_within_batch_ceiling(entry.2) {
      ops.push(
        dump_op("merge", {
          "sheet": Json::string(sheet),
          "range": Json::string(entry.2),
        }),
      )
    } else {
      residual.push({
        code: "xlsx.merge_range_too_large",
        severity: "dropped",
        scope: "cells",
        location: dump_location(sheet, "range", entry.2),
        asset: None,
        detail: "merge range exceeds the batch range ceiling of \{@inspect.MAX_RANGE_CELLS} cells",
      })
    }
  }
}

///|
/// Emits the `freeze` op for frozen panes; non-freeze splits are recorded
/// as residual rather than approximated into a different view state.
fn dump_sheet_panes(
  workbook : @xlsx.Workbook,
  worksheet : @xlsx.Worksheet,
  sheet : String,
  ops : Array[Json],
  residual : Array[DumpResidual],
) -> Unit raise {
  let panes = worksheet.get_panes()
  let sheet_location = Json::object({ "sheet": Json::string(sheet) })
  let anchor = sheet_scroll_anchor(workbook, worksheet, sheet)
  if panes.freeze && (panes.x_split > 0 || panes.y_split > 0) {
    let cell = @xlsx.coordinates_to_cell_name(
      panes.x_split + 1,
      panes.y_split + 1,
    )
    ops.push(
      dump_op("freeze", {
        "sheet": Json::string(sheet),
        "cell": Json::string(cell),
      }),
    )
    // the freeze op captures only the split boundary; a persisted scroll
    // position (anchor beyond the boundary), active pane, or selection is
    // not replayable
    let scroll_lost = anchor != "" && anchor != "A1" && anchor != cell
    if panes.selection.length() > 0 || panes.active_pane != "" || scroll_lost {
      residual.push({
        code: "xlsx.freeze_pane_state_approximated",
        severity: "approximated",
        scope: "sheet",
        location: sheet_location,
        asset: None,
        detail: "frozen-pane scroll position, active pane, and selection are not replayable",
      })
    }
  } else if panes.split || panes.x_split > 0 || panes.y_split > 0 {
    // get_panes() reports split=false for some persisted split panes, so
    // a non-zero split offset without freeze is the reliable signal
    residual.push({
      code: "xlsx.split_panes_unsupported",
      severity: "dropped",
      scope: "sheet",
      location: sheet_location,
      asset: None,
      detail: "non-freeze split panes are not expressible in \{XLSX_BATCH_SCHEMA}",
    })
  } else if anchor != "" && anchor != "A1" {
    // a plain scrolled sheet (no frozen or split panes) still carries a
    // scroll position the op vocabulary cannot reproduce
    residual.push({
      code: "xlsx.sheet_scroll_position_dropped",
      severity: "dropped",
      scope: "sheet",
      location: sheet_location,
      asset: None,
      detail: "sheet scroll position is not expressible in \{XLSX_BATCH_SCHEMA}",
    })
  }
}

///|
/// Emits the `filter` op; column criteria have no op parameters, so their
/// presence degrades to an explicit approximation record.
fn dump_sheet_filter(
  workbook : @xlsx.Workbook,
  sheet : String,
  ops : Array[Json],
  residual : Array[DumpResidual],
) -> Unit raise {
  guard workbook.get_auto_filter(sheet) is Some(filter) else { return }
  if range_within_batch_ceiling(filter.range_ref) {
    ops.push(
      dump_op("filter", {
        "sheet": Json::string(sheet),
        "range": Json::string(filter.range_ref),
      }),
    )
  } else {
    residual.push({
      code: "xlsx.filter_range_too_large",
      severity: "dropped",
      scope: "sheet",
      location: dump_location(sheet, "range", filter.range_ref),
      asset: None,
      detail: "auto-filter range exceeds the batch range ceiling of \{@inspect.MAX_RANGE_CELLS} cells",
    })
  }
  if filter.columns.length() > 0 {
    residual.push({
      code: "xlsx.filter_criteria_dropped",
      severity: "approximated",
      scope: "sheet",
      location: Json::object({ "sheet": Json::string(sheet) }),
      asset: None,
      detail: "\{filter.columns.length()} filter column criteria replay as an unfiltered range",
    })
  }
}

///|
/// Ceiling on one captured asset's payload.
let dump_max_asset_bytes : Int = 8 * 1024 * 1024

///|
/// Ceiling on the total captured asset payload per dump.
let dump_max_total_asset_bytes : Int = 32 * 1024 * 1024

///|
/// Captures anchored pictures as content-addressed assets. No batch op can
/// place an image, so every picture is a residual either way; when the
/// payload fits the allowance it is carried inline (base64) under a
/// sha256-addressed id, deduplicated across sheets, so nothing binary is
/// silently lost.
fn dump_sheet_images(
  worksheet : @xlsx.Worksheet,
  sheet : String,
  assets : Map[String, DumpAsset],
  total_asset_bytes : Ref[Int],
  residual : Array[DumpResidual],
) -> Unit {
  for image in worksheet.images {
    let digest = sha256_hex_bytes(image.data)
    let id = "sha256-" + digest
    let within = image.data.length() <= dump_max_asset_bytes &&
      total_asset_bytes.val + image.data.length() <= dump_max_total_asset_bytes
    if within {
      if !assets.contains(id) {
        total_asset_bytes.val += image.data.length()
        assets[id] = {
          content_type: image.content_type,
          size: image.data.length(),
          data: @base64.encode(image.data),
        }
      }
      residual.push({
        code: "xlsx.image_unsupported",
        severity: "dropped",
        scope: "object",
        location: dump_location(sheet, "anchor", image.reference),
        asset: Some(id),
        detail: "anchored picture; \{XLSX_BATCH_SCHEMA} has no image op (payload carried as an inline asset)",
      })
    } else {
      residual.push({
        code: "xlsx.image_unsupported",
        severity: "dropped",
        scope: "object",
        location: dump_location(sheet, "anchor", image.reference),
        asset: None,
        detail: "anchored picture \{id}; payload exceeds the inline asset allowance and is not carried",
      })
    }
  }
}

///|
/// Coarse per-feature residuals for source content PR1 does not yet dump
/// as ops. Every record names the feature and its count so nothing is
/// silently missing from the replayed document.
fn dump_sheet_coverage_residuals(
  workbook : @xlsx.Workbook,
  worksheet : @xlsx.Worksheet,
  sheet : String,
  residual : Array[DumpResidual],
) -> Unit raise {
  let counts : Array[(String, Int)] = [
    ("xlsx.tables_not_dumped", worksheet.tables.length()),
    ("xlsx.charts_not_dumped", worksheet.charts.length()),
    ("xlsx.hyperlinks_not_dumped", worksheet.hyperlinks.length()),
    ("xlsx.sparklines_not_dumped", worksheet.sparkline_groups.length()),
    ("xlsx.pivot_tables_not_dumped", worksheet.pivot_tables.length()),
    (
      "xlsx.validations_not_dumped",
      (workbook.get_data_validations(sheet) catch { _ => [] }).length(),
    ),
    (
      "xlsx.conditional_formats_not_dumped",
      (workbook.get_conditional_formats(sheet) catch { _ => Map::new() }).length(),
    ),
    (
      "xlsx.comments_not_dumped",
      (workbook.get_comments(sheet) catch { _ => [] }).length(),
    ),
    ("xlsx.shapes_not_dumped", worksheet.shapes.length()),
    ("xlsx.form_controls_not_dumped", worksheet.form_controls.length()),
    ("xlsx.slicers_not_dumped", worksheet.slicers.length()),
    (
      "xlsx.header_footer_images_not_dumped",
      worksheet.header_footer_images.length(),
    ),
  ]
  for entry in counts {
    let (code, count) = entry
    if count > 0 {
      residual.push({
        code,
        severity: "dropped",
        scope: "sheet",
        location: Json::object({ "sheet": Json::string(sheet) }),
        asset: None,
        detail: "\{count} not yet covered by the dump (planned follow-up)",
      })
    }
  }
  // present-or-absent sheet features the op vocabulary cannot express
  if worksheet.sheet_background is Some(_) {
    residual.push({
      code: "xlsx.sheet_background_dropped",
      severity: "dropped",
      scope: "sheet",
      location: Json::object({ "sheet": Json::string(sheet) }),
      asset: None,
      detail: "sheet background image is not expressible in \{XLSX_BATCH_SCHEMA}",
    })
  }
  if worksheet.row_breaks.length() > 0 || worksheet.col_breaks.length() > 0 {
    residual.push({
      code: "xlsx.page_breaks_dropped",
      severity: "dropped",
      scope: "sheet",
      location: Json::object({ "sheet": Json::string(sheet) }),
      asset: None,
      detail: "manual page breaks are not expressible in \{XLSX_BATCH_SCHEMA}",
    })
  }
  // non-default primary sheet-view state (RTL, grid lines, zoom, …)
  if (try? workbook.get_sheet_view(sheet, 0)) is Ok(view) &&
    sheet_view_is_nondefault(view) {
    residual.push({
      code: "xlsx.sheet_view_state_dropped",
      severity: "dropped",
      scope: "sheet",
      location: Json::object({ "sheet": Json::string(sheet) }),
      asset: None,
      detail: "non-default sheet-view state (e.g. right-to-left, grid lines, zoom) is not expressible in \{XLSX_BATCH_SCHEMA}",
    })
  }
  // retained sheet-level state the op vocabulary cannot express: each is
  // stored as an Option on the worksheet, so Some means present
  let present : Array[(String, Bool)] = [
    ("xlsx.page_margins_dropped", worksheet.page_margins is Some(_)),
    ("xlsx.page_layout_dropped", worksheet.page_layout is Some(_)),
    ("xlsx.header_footer_dropped", worksheet.header_footer is Some(_)),
    ("xlsx.sheet_protection_dropped", worksheet.sheet_protection is Some(_)),
    ("xlsx.sheet_properties_dropped", worksheet.sheet_props is Some(_)),
    ("xlsx.ignored_errors_dropped", worksheet.ignored_errors.length() > 0),
  ]
  for entry in present {
    let (code, is_present) = entry
    if is_present {
      residual.push({
        code,
        severity: "dropped",
        scope: "sheet",
        location: Json::object({ "sheet": Json::string(sheet) }),
        asset: None,
        detail: "retained sheet state is not expressible in \{XLSX_BATCH_SCHEMA}",
      })
    }
  }
}

///|
/// Whether a primary sheet view carries display state the `office dump` op
/// vocabulary cannot reproduce. Only fields whose non-default value is
/// unambiguous are tested: the reader materializes some fields with their
/// defaults (e.g. `show_formulas`/`show_zeros`), so testing those would
/// false-positive on ordinary sheets. `top_left_cell` is pane scroll state
/// disclosed by the freeze/split pane path instead.
fn sheet_view_is_nondefault(view : @xlsx.SheetViewOptions) -> Bool {
  // materialized defaults (measured on a plain sheet): every boolean is
  // Some(true), zoom Some(100), view Some("normal"); anything else is real
  view.right_to_left is Some(true) ||
  view.show_grid_lines is Some(false) ||
  view.show_row_col_headers is Some(false) ||
  view.show_formulas is Some(false) ||
  view.show_zeros is Some(false) ||
  view.show_ruler is Some(false) ||
  view.default_grid_color is Some(false) ||
  (view.zoom_scale is Some(zoom) && zoom != 100.0) ||
  (view.view is Some(mode) && mode != "" && mode != "normal")
}

///|
/// The primary sheet view's scroll anchor, preferring the pane's value and
/// falling back to the sheet view's, or the "A1" default when unset.
fn sheet_scroll_anchor(
  workbook : @xlsx.Workbook,
  worksheet : @xlsx.Worksheet,
  sheet : String,
) -> String {
  let pane_anchor = worksheet.get_panes().top_left_cell
  if pane_anchor != "" {
    return pane_anchor
  }
  match (try? workbook.get_sheet_view(sheet, 0)) {
    Ok(view) =>
      match view.top_left_cell {
        Some(cell) => cell
        None => "A1"
      }
    Err(_) => "A1"
  }
}

///|
/// Workbook-scoped residuals for content the per-sheet passes cannot see:
/// defined names, active-sheet selection, document properties, and the
/// date system (a correctness hazard, not merely lossy).
fn dump_workbook_residuals(
  workbook : @xlsx.Workbook,
  residual : Array[DumpResidual],
) -> Unit raise {
  let document = Json::object({ "scope": Json::string("workbook") })
  let defined = (try? workbook.get_defined_names()).unwrap_or([])
  // The auto-filter internal name `_xlnm._FilterDatabase` is reconstructed
  // by a replayed `filter` op, so exclude it — but ONLY when it names a
  // sheet that actually has an auto-filter, and only on an exact-name
  // match (a distinct name like `_xlnm._FilterDatabaseNote` is a real
  // drop).
  // sheet lookup is case-insensitive, so normalize both sides
  let filter_sheets : Set[String] = Set::new()
  for sheet in workbook.get_sheet_list() {
    if (try? workbook.get_auto_filter(sheet)) is Ok(Some(_)) {
      filter_sheets.add(sheet.to_lower())
    }
  }
  let mut dropped_names = 0
  for name in defined {
    let reconstructed = name.name == "_xlnm._FilterDatabase" &&
      filter_sheets.contains(name.scope.to_lower())
    if !reconstructed {
      dropped_names += 1
    }
  }
  if dropped_names > 0 {
    residual.push({
      code: "xlsx.defined_names_dropped",
      severity: "dropped",
      scope: "document",
      location: document,
      asset: None,
      detail: "\{dropped_names} defined name(s) are not expressible in \{XLSX_BATCH_SCHEMA}",
    })
  }
  if workbook.get_active_sheet_index() != 0 {
    residual.push({
      code: "xlsx.active_sheet_dropped",
      severity: "dropped",
      scope: "document",
      location: document,
      asset: None,
      detail: "the active-sheet selection is not expressible in \{XLSX_BATCH_SCHEMA}",
    })
  }
  let custom = workbook.get_custom_props()
  if custom.length() > 0 {
    residual.push({
      code: "xlsx.custom_properties_dropped",
      severity: "dropped",
      scope: "document",
      location: document,
      asset: None,
      detail: "\{custom.length()} custom document propert(ies) are not expressible in \{XLSX_BATCH_SCHEMA}",
    })
  }
  if workbook.get_workbook_props().date_1904 is Some(true) {
    residual.push({
      code: "xlsx.date1904_dropped",
      severity: "dropped",
      scope: "document",
      location: document,
      asset: None,
      detail: "source uses the 1904 date system; replay into a 1900-system workbook shifts date-formatted serials",
    })
  }
}

///|
/// A produced op is a new-style op when the batch parser would count it
/// against the per-script `MAX_TOTAL_NEW_STYLES` budget.
fn op_creates_style(op : Json) -> Bool {
  op is Object({ "op": String("style"), .. })
}

///|
/// Splits the single op stream into batch scripts, each within BOTH the
/// op-count ceiling and the new-style budget. The self-check and replay
/// share this one chunking policy, so a dump the self-check accepts is
/// exactly a dump replay can consume.
pub fn xlsx_dump_op_chunks(ops : Array[Json]) -> Array[Array[Json]] {
  let chunks : Array[Array[Json]] = []
  let mut start = 0
  while start < ops.length() {
    let chunk : Array[Json] = []
    let mut styles = 0
    while start < ops.length() &&
          chunk.length() < @batch.MAX_BATCH_OPS &&
          styles < @batch.MAX_TOTAL_NEW_STYLES {
      let op = ops[start]
      if op_creates_style(op) {
        styles += 1
      }
      chunk.push(op)
      start += 1
    }
    chunks.push(chunk)
  }
  chunks
}

///|
/// The dump-time self-check: every produced op chunk must PARSE through the
/// real batch parser (schema, per-op shape, and aggregate plan limits), so
/// a dump can never emit a script the parser rejects. Apply-time,
/// state-dependent validation (e.g. table-name uniqueness) is proven
/// separately by replay, not here.
fn self_check_ops(ops : Array[Json]) -> Unit raise {
  for chunk in xlsx_dump_op_chunks(ops) {
    let script = Json::object({
      "schema": Json::string(XLSX_BATCH_SCHEMA),
      "ops": Json::array(chunk),
    })
    ignore(
      @batch.parse_script(script) catch {
        error => raise DumpSelfCheckFailed("\{error}")
      },
    )
  }
}

///|
/// Dumps a workbook into an `office.dump/1` envelope: canonical ordered
/// `xlsx.batch/1` ops plus explicit residual records for everything the op
/// vocabulary cannot express.
pub fn dump_xlsx_workbook(
  workbook : @xlsx.Workbook,
  source_file~ : String,
  source_bytes~ : Int,
  source_sha256? : String? = None,
  cancelled? : () -> Bool = () => false,
) -> DumpEnvelope raise {
  let ops : Array[Json] = []
  let assets : Map[String, DumpAsset] = {}
  let total_asset_bytes : Ref[Int] = Ref::new(0)
  let residual : Array[DumpResidual] = []
  let warnings : Array[DumpWarning] = []
  let sheet_names = workbook.get_sheet_list()
  let worksheet_names : Array[String] = []
  for name in sheet_names {
    check_cancelled(cancelled)
    match workbook.sheet(name) {
      Some(_) => worksheet_names.push(name)
      None =>
        residual.push({
          code: "xlsx.chart_sheet_unsupported",
          severity: "dropped",
          scope: "sheet",
          location: Json::object({ "sheet": Json::string(name) }),
          asset: None,
          detail: "chart sheets cannot be created by \{XLSX_BATCH_SCHEMA}",
        })
    }
  }
  guard worksheet_names is [create_sheet, .. rest] else {
    raise DumpUnsupported("workbook contains no worksheets to dump")
  }
  for name in rest {
    ops.push(dump_op("add-sheet", { "name": Json::string(name) }))
  }
  let style_ctx : StyleContext = {
    workbook,
    extracts: {},
    reported: Set::new(),
  }
  for name in worksheet_names {
    check_cancelled(cancelled)
    guard workbook.sheet(name) is Some(worksheet) else { continue }
    dump_sheet_dimensions(worksheet, name, ops, residual)
    dump_sheet_cells(workbook, worksheet, name, ops, residual, cancelled)
    dump_sheet_styles(style_ctx, worksheet, name, ops, residual)
    dump_sheet_images(worksheet, name, assets, total_asset_bytes, residual)
    dump_sheet_merges(workbook, name, ops, residual)
    dump_sheet_panes(workbook, worksheet, name, ops, residual)
    dump_sheet_filter(workbook, name, ops, residual)
    dump_sheet_coverage_residuals(workbook, worksheet, name, residual)
  }
  dump_workbook_residuals(workbook, residual)
  // Visibility ops come last so the engine's keep-one-visible guard sees
  // the final sheet population. The replayed workbook contains only
  // worksheets (chart sheets were dropped), so if every worksheet is
  // hidden in the source, one hide would be refused at apply time — keep
  // the first worksheet visible and record that as a residual.
  let mut visible_worksheets = 0
  for name in worksheet_names {
    guard workbook.sheet(name) is Some(worksheet) else { continue }
    if worksheet.state() is Visible {
      visible_worksheets += 1
    }
  }
  let mut force_visible = visible_worksheets == 0
  for name in worksheet_names {
    guard workbook.sheet(name) is Some(worksheet) else { continue }
    let action = match worksheet.state() {
      Hidden => Some("hide")
      VeryHidden => Some("very-hide")
      _ => None
    }
    match action {
      Some(verb) =>
        if force_visible {
          // this worksheet must stay visible so replay keeps one visible
          force_visible = false
          residual.push({
            code: "xlsx.sheet_visibility_forced_visible",
            severity: "approximated",
            scope: "sheet",
            location: Json::object({ "sheet": Json::string(name) }),
            asset: None,
            detail: "every worksheet is hidden in the source (visibility carried by a dropped chart sheet); replay keeps this one visible",
          })
        } else {
          ops.push(
            dump_op("sheet", {
              "action": Json::string(verb),
              "name": Json::string(name),
            }),
          )
        }
      None => ()
    }
  }
  check_cancelled(cancelled)
  self_check_ops(ops)
  {
    format: "xlsx",
    source_file,
    source_bytes,
    source_sha256,
    batch_schema: XLSX_BATCH_SCHEMA,
    create_sheet: Some(create_sheet),
    ops,
    assets,
    residual,
    warnings,
  }
}
