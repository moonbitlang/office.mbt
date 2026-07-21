///|
/// One candidate table op awaiting full-replay validation: the op's index
/// in the stream, the sheet, and the source table to compare readback
/// against.
priv struct TableCandidate {
  op_index : Int
  sheet : String
  table : @xlsx.Table
}

///|
/// Emits a candidate `table` op per worksheet table (after the sheet's cell
/// and style ops, so header cells exist for column derivation) and records
/// it for the post-build full-replay validation pass.
fn dump_sheet_tables(
  worksheet : @xlsx.Worksheet,
  sheet : String,
  ops : Array[Json],
  candidates : Array[TableCandidate],
) -> Unit {
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
    candidates.push({ op_index: ops.length(), sheet, table })
    ops.push(
      Json::object({
        "op": Json::string("table"),
        "params": Json::object(params),
      }),
    )
  }
}

///|
/// Whether a replayed workbook carries `candidate`'s table faithfully:
/// every table field equals the source, and the header-row cells still
/// carry the source's values (table creation synthesizes names for blank
/// or duplicate headers, which would silently change cell content).
fn table_replayed_faithfully(
  source : @xlsx.Workbook,
  replayed : @xlsx.Workbook,
  candidate : TableCandidate,
) -> Bool {
  guard (try? replayed.sheet(candidate.sheet)) is Ok(Some(sheet)) else {
    return false
  }
  let mut found : @xlsx.Table? = None
  for table in sheet.tables {
    if table.name == candidate.table.name {
      found = Some(table)
      break
    }
  }
  guard found is Some(replayed_table) else { return false }
  let wanted = candidate.table
  if replayed_table.range_ref != wanted.range_ref ||
    replayed_table.display_name != wanted.display_name ||
    replayed_table.columns != wanted.columns ||
    replayed_table.show_header_row != wanted.show_header_row ||
    replayed_table.show_row_stripes != wanted.show_row_stripes ||
    replayed_table.show_first_column != wanted.show_first_column ||
    replayed_table.show_last_column != wanted.show_last_column ||
    replayed_table.show_column_stripes != wanted.show_column_stripes ||
    replayed_table.style_name != wanted.style_name {
    return false
  }
  // header-row cells must be untouched by table creation
  guard (try? table_header_span(wanted)) is Ok((row, c1, c2)) else {
    return false
  }
  for col in c1..<=c2 {
    guard (try? @xlsx.coordinates_to_cell_name(col, row)) is Ok(reference) else {
      return false
    }
    let source_value = try? source.get_cell_value_raw(
      candidate.sheet,
      reference,
    )
    let replayed_value = try? replayed.get_cell_value_raw(
      candidate.sheet,
      reference,
    )
    match (source_value, replayed_value) {
      (Ok(a), Ok(b)) => if !cell_values_equal(a, b) { return false }
      _ => return false
    }
  }
  true
}

///|
fn table_header_span(table : @xlsx.Table) -> (Int, Int, Int) raise {
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
  (r1, c1, c2)
}

///|
/// Validates every candidate table op by replaying the FULL op stream from
/// scratch and comparing readback to the source. Any table whose op fails
/// to apply in context (a name the engine rejects, a cross-table
/// collision) or whose readback diverges (a re-transformed range, a
/// synthesized header) is removed from the stream and disclosed as a
/// residual, then the reduced stream is re-validated from scratch — a
/// failed apply may leave the scratch workbook partially mutated, so no
/// state is ever reused across iterations. Terminates because every
/// iteration removes at least one candidate.
fn validate_table_ops(
  source : @xlsx.Workbook,
  create_sheet : String,
  ops : Array[Json],
  candidates : Array[TableCandidate],
  residual : Array[DumpResidual],
  cancelled : () -> Bool,
) -> Array[Json] raise {
  let mut current_ops = ops
  let mut current = candidates
  while current.length() > 0 {
    check_cancelled(cancelled)
    let dropped : Set[Int] = Set::new()
    match replay_ops_traced(create_sheet, current_ops) {
      FailedAt(index, message) => {
        // only a candidate table op may fail in context; anything else is
        // a dump bug
        let mut matched = false
        for candidate in current {
          if candidate.op_index == index {
            matched = true
            dropped.add(index)
            residual.push(table_residual(candidate, message))
            break
          }
        }
        if !matched {
          raise DumpSelfCheckFailed(
            "op \{index} failed to apply during validation: \{message}",
          )
        }
      }
      Replayed(replayed) => {
        for candidate in current {
          if !table_replayed_faithfully(source, replayed, candidate) {
            dropped.add(candidate.op_index)
            residual.push(
              table_residual(candidate, "readback diverges from the source"),
            )
          }
        }
        if dropped.is_empty() {
          // every remaining table op applied and read back faithfully
          return current_ops
        }
      }
    }
    // rebuild the stream without the dropped ops and re-map indices
    let next_ops : Array[Json] = []
    let index_map : Map[Int, Int] = {}
    for index, op in current_ops {
      if !dropped.contains(index) {
        index_map[index] = next_ops.length()
        next_ops.push(op)
      }
    }
    let next : Array[TableCandidate] = []
    for candidate in current {
      if !dropped.contains(candidate.op_index) {
        match index_map.get(candidate.op_index) {
          Some(new_index) =>
            next.push({
              op_index: new_index,
              sheet: candidate.sheet,
              table: candidate.table,
            })
          None => ()
        }
      }
    }
    current_ops = next_ops
    current = next
  }
  current_ops
}

///|
fn table_residual(candidate : TableCandidate, reason : String) -> DumpResidual {
  {
    code: "xlsx.table_unsupported",
    severity: "dropped",
    scope: "cells",
    location: dump_location(candidate.sheet, "range", candidate.table.range_ref),
    asset: None,
    detail: "table \"\{candidate.table.display_name}\" does not replay faithfully through \{XLSX_BATCH_SCHEMA}: " +
    bounded_reason(reason),
  }
}

///|
/// Bounded, deterministic reason text for a residual detail.
fn bounded_reason(reason : String) -> String {
  if reason.length() <= 160 {
    reason
  } else {
    reason.substring(start=0, end=160) + "\u{2026}"
  }
}
