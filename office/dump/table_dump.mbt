///|
/// Emits a `table` op per worksheet table, but only when the op provably
/// round-trips: the op is applied to a scratch workbook carrying the same
/// header cells, and the resulting table is compared field-by-field to the
/// source. Any divergence — an apply-time-rejected name, a range the
/// add-table API re-transforms, a lost display name or column set — makes
/// the table a residual instead of a lossy op. Runs after the cell and
/// style ops so the header cells exist for column derivation.
fn dump_sheet_tables(
  workbook : @xlsx.Workbook,
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
    if table_op_round_trips(workbook, sheet, table, op) {
      ops.push(op)
    } else {
      residual.push({
        code: "xlsx.table_unsupported",
        severity: "dropped",
        scope: "cells",
        location: dump_location(sheet, "range", table.range_ref),
        asset: None,
        detail: "table \"\{table.display_name}\" does not round-trip through \{XLSX_BATCH_SCHEMA} (name, range, style, display name, or columns diverge on replay)",
      })
    }
  }
}

///|
/// Applies the table op to a fresh workbook seeded with the source table's
/// header-row cells, then checks the resulting table equals the source in
/// every field the dump claims to preserve.
fn table_op_round_trips(
  workbook : @xlsx.Workbook,
  sheet : String,
  source : @xlsx.Table,
  op : Json,
) -> Bool {
  guard (try? table_header_cells(workbook, sheet, source)) is Ok(headers) else {
    return false
  }
  let scratch = @xlsx.Workbook::new()
  guard (try? scratch.add_sheet(sheet)) is Ok(_) else { return false }
  for cell in headers {
    guard (try? scratch.set_cell(sheet, cell.0, cell.1)) is Ok(_) else {
      return false
    }
  }
  guard (try? @batch.parse_script(
      Json::object({
        "schema": Json::string(XLSX_BATCH_SCHEMA),
        "ops": Json::array([op]),
      }),
    ))
    is Ok(parsed) else {
    return false
  }
  for parsed_op in parsed {
    guard (try? @batch.apply_op(scratch, parsed_op)) is Ok(_) else {
      return false
    }
  }
  guard (try? scratch.sheet(sheet)) is Ok(Some(replayed_sheet)) else {
    return false
  }
  guard replayed_sheet.tables is [replayed] else { return false }
  replayed.range_ref == source.range_ref &&
  replayed.name == source.name &&
  replayed.display_name == source.display_name &&
  replayed.columns == source.columns &&
  replayed.show_header_row == source.show_header_row &&
  replayed.show_row_stripes == source.show_row_stripes &&
  replayed.show_first_column == source.show_first_column &&
  replayed.show_last_column == source.show_last_column &&
  replayed.show_column_stripes == source.show_column_stripes
}

///|
/// The source table's header-row cells (top row of its range) as
/// (reference, text) pairs, so a scratch replay derives the same columns.
fn table_header_cells(
  workbook : @xlsx.Workbook,
  sheet : String,
  table : @xlsx.Table,
) -> Array[(String, String)] raise {
  let (start, end) = match table.range_ref.find(":") {
    Some(colon) =>
      (
        table.range_ref.substring(start=0, end=colon),
        table.range_ref.substring(start=colon + 1, end=table.range_ref.length()),
      )
    None => (table.range_ref, table.range_ref)
  }
  let (c1, r1) = @xlsx.cell_name_to_coordinates(start)
  let (c2, _) = @xlsx.cell_name_to_coordinates(end)
  let cells : Array[(String, String)] = []
  for col in c1..<=c2 {
    let reference = @xlsx.coordinates_to_cell_name(col, r1)
    let text = match
      (workbook.get_cell_value_raw(sheet, reference) catch { _ => None }) {
      Some(String(value)) => value
      Some(Numeric(value)) => "\{value}"
      Some(Bool(value)) => if value { "TRUE" } else { "FALSE" }
      Some(Error(value)) => value
      None => ""
    }
    cells.push((reference, text))
  }
  cells
}
