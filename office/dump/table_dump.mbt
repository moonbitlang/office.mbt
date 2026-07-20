///|
/// Whether a single produced op parses through the batch engine on its own.
/// Ops with strict validation (table names, ranges) use this so a source
/// value the engine would reject degrades to a residual instead of failing
/// the whole dump's self-check.
fn op_is_replayable(op : Json) -> Bool {
  let script = Json::object({
    "schema": Json::string(XLSX_BATCH_SCHEMA),
    "ops": Json::array([op]),
  })
  (try? @batch.parse_script(script)) is Ok(_)
}

///|
/// Emits a `table` op per worksheet table, degrading to a residual when the
/// batch engine would reject the table (e.g. a name it does not accept).
/// Follows the cell/style ops so the header cells the engine reads for
/// column names already exist.
fn dump_sheet_tables(
  worksheet : @xlsx.Worksheet,
  sheet : String,
  ops : Array[Json],
  residual : Array[DumpResidual],
) -> Unit raise {
  for table in worksheet.tables {
    let params : Map[String, Json] = {
      "sheet": Json::string(sheet),
      "range": Json::string(table.range_ref),
      "name": Json::string(table.name),
      "header_row": Json::boolean(table.show_header_row),
      "row_stripes": Json::boolean(table.show_row_stripes),
      "first_column": Json::boolean(table.show_first_column),
      "last_column": Json::boolean(table.show_last_column),
      "column_stripes": Json::boolean(table.show_column_stripes),
    }
    if table.style_name != "" {
      params["style"] = Json::string(table.style_name)
    }
    let op = Json::object({
      "op": Json::string("table"),
      "params": Json::object(params),
    })
    if op_is_replayable(op) {
      ops.push(op)
    } else {
      residual.push({
        code: "xlsx.table_unsupported",
        severity: "dropped",
        scope: "cells",
        location: dump_location(sheet, "range", table.range_ref),
        asset: None,
        detail: "table \"\{table.name}\" is not expressible in \{XLSX_BATCH_SCHEMA} (name, range, or style rejected)",
      })
    }
  }
}
