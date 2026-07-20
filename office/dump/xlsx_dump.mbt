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
  let cells = worksheet.cells.copy()
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
/// Emits `merge` ops sorted by their top-left coordinate.
fn dump_sheet_merges(
  workbook : @xlsx.Workbook,
  sheet : String,
  ops : Array[Json],
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
  keyed.sort_by((a, b) => if a.0 == b.0 { a.1 - b.1 } else { a.0 - b.0 })
  for entry in keyed {
    ops.push(
      dump_op("merge", {
        "sheet": Json::string(sheet),
        "range": Json::string(entry.2),
      }),
    )
  }
}

///|
/// Emits the `freeze` op for frozen panes; non-freeze splits are recorded
/// as residual rather than approximated into a different view state.
fn dump_sheet_panes(
  worksheet : @xlsx.Worksheet,
  sheet : String,
  ops : Array[Json],
  residual : Array[DumpResidual],
) -> Unit raise {
  let panes = worksheet.get_panes()
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
  } else if panes.split {
    residual.push({
      code: "xlsx.split_panes_unsupported",
      severity: "dropped",
      scope: "sheet",
      location: Json::object({ "sheet": Json::string(sheet) }),
      asset: None,
      detail: "non-freeze split panes are not expressible in \{XLSX_BATCH_SCHEMA}",
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
  ops.push(
    dump_op("filter", {
      "sheet": Json::string(sheet),
      "range": Json::string(filter.range_ref),
    }),
  )
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
    ("xlsx.styles_not_dumped", styled_cell_count(worksheet)),
    ("xlsx.tables_not_dumped", worksheet.tables.length()),
    ("xlsx.images_not_dumped", worksheet.images.length()),
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
      (workbook.get_conditional_formats(sheet) catch { _ => Map::new() }).size(),
    ),
    (
      "xlsx.comments_not_dumped",
      (workbook.get_comments(sheet) catch { _ => [] }).length(),
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
}

///|
fn styled_cell_count(worksheet : @xlsx.Worksheet) -> Int {
  let mut count = 0
  for cell in worksheet.cells {
    if cell.style_explicit {
      count += 1
    }
  }
  count
}

///|
/// The dump-time self-check: every produced op chunk must parse through
/// the real batch parser, so a dump can never emit a script its own
/// engine refuses.
fn self_check_ops(ops : Array[Json]) -> Unit raise {
  let mut start = 0
  while start < ops.length() {
    let end = if start + @batch.MAX_BATCH_OPS < ops.length() {
      start + @batch.MAX_BATCH_OPS
    } else {
      ops.length()
    }
    let chunk : Array[Json] = []
    for index in start..<end {
      chunk.push(ops[index])
    }
    let script = Json::object({
      "schema": Json::string(XLSX_BATCH_SCHEMA),
      "ops": Json::array(chunk),
    })
    ignore(
      @batch.parse_script(script) catch {
        error => raise DumpSelfCheckFailed("\{error}")
      },
    )
    start = end
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
  cancelled? : () -> Bool = () => false,
) -> DumpEnvelope raise {
  let ops : Array[Json] = []
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
  for name in worksheet_names {
    check_cancelled(cancelled)
    guard workbook.sheet(name) is Some(worksheet) else { continue }
    dump_sheet_cells(workbook, worksheet, name, ops, residual, cancelled)
    dump_sheet_merges(workbook, name, ops)
    dump_sheet_panes(worksheet, name, ops, residual)
    dump_sheet_filter(workbook, name, ops, residual)
    dump_sheet_coverage_residuals(workbook, worksheet, name, residual)
  }
  // visibility last: the engine's keep-one-visible guard sees the final
  // sheet population
  for name in worksheet_names {
    guard workbook.sheet(name) is Some(worksheet) else { continue }
    match worksheet.state() {
      Hidden =>
        ops.push(
          dump_op("sheet", {
            "action": Json::string("hide"),
            "name": Json::string(name),
          }),
        )
      VeryHidden =>
        ops.push(
          dump_op("sheet", {
            "action": Json::string("very-hide"),
            "name": Json::string(name),
          }),
        )
      _ => ()
    }
  }
  check_cancelled(cancelled)
  self_check_ops(ops)
  {
    format: "xlsx",
    source_file,
    source_bytes,
    batch_schema: XLSX_BATCH_SCHEMA,
    create_sheet: Some(create_sheet),
    ops,
    residual,
    warnings,
  }
}
