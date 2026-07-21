///|
/// The source object a candidate op must reproduce on replay.
priv enum ObjectPayload {
  TableObject(@xlsx.Table)
  ValidationObject(@xlsx.DataValidation, String)
}

///|
/// One candidate object op awaiting full-replay validation: the op's index
/// in the stream, the sheet, and the source object to compare readback
/// against.
priv struct TableCandidate {
  op_index : Int
  sheet : String
  payload : ObjectPayload
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
    candidates.push({
      op_index: ops.length(),
      sheet,
      payload: TableObject(table),
    })
    ops.push(
      Json::object({
        "op": Json::string("table"),
        "params": Json::object(params),
      }),
    )
  }
}

///|
/// Whether a replayed workbook carries `candidate`'s object faithfully.
/// `peers` is the current candidate list (ascending op order); validations
/// use it to pair the n-th candidate on a region with the n-th replayed
/// validation on that region, so two rules on the same range never compare
/// against each other's replay.
fn object_replayed_faithfully(
  source : @xlsx.Workbook,
  replayed : @xlsx.Workbook,
  candidate : TableCandidate,
  peers : Array[TableCandidate],
) -> Bool {
  match candidate.payload {
    TableObject(table) =>
      table_replayed_faithfully(source, replayed, candidate.sheet, table)
    ValidationObject(validation, region) => {
      let mut ordinal = 0
      for peer in peers {
        if peer.op_index >= candidate.op_index {
          break
        }
        if peer.sheet == candidate.sheet &&
          peer.payload is ValidationObject(_, peer_region) &&
          peer_region == region {
          ordinal += 1
        }
      }
      validation_replayed_faithfully(
        replayed,
        candidate.sheet,
        validation,
        region,
        ordinal,
      )
    }
  }
}

///|
/// Whether a replayed workbook carries the table faithfully:
/// every table field equals the source, and the header-row cells still
/// carry the source's values (table creation synthesizes names for blank
/// or duplicate headers, which would silently change cell content).
fn table_replayed_faithfully(
  source : @xlsx.Workbook,
  replayed : @xlsx.Workbook,
  candidate_sheet : String,
  wanted : @xlsx.Table,
) -> Bool {
  guard (try? replayed.sheet(candidate_sheet)) is Ok(Some(sheet)) else {
    return false
  }
  let mut found : @xlsx.Table? = None
  for table in sheet.tables {
    if table.name == wanted.name {
      found = Some(table)
      break
    }
  }
  guard found is Some(replayed_table) else { return false }
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
      candidate_sheet, reference,
    )
    let replayed_value = try? replayed.get_cell_value_raw(
      candidate_sheet, reference,
    )
    match (source_value, replayed_value) {
      (Ok(a), Ok(b)) => if !cell_values_equal(a, b) { return false }
      _ => return false
    }
    // a header formula must survive as a formula: table creation can
    // synthesize a literal whose text happens to equal the cached value,
    // silently replacing the formula. Presence is compared through the
    // formula-info accessor because get_cell_formula returns None for
    // shared-formula followers with empty stored text — presence, not
    // text, is what a follower loses.
    let source_info = match source.sheet(candidate_sheet) {
      Some(source_sheet) => try? source_sheet.get_cell_formula_info_rc(row, col)
      None => return false
    }
    let replayed_info = match replayed.sheet(candidate_sheet) {
      Some(replayed_sheet) =>
        try? replayed_sheet.get_cell_formula_info_rc(row, col)
      None => return false
    }
    match (source_info, replayed_info) {
      (Ok(a), Ok(b)) => {
        if (a is Some(_)) != (b is Some(_)) {
          return false
        }
        match (a, b) {
          (Some(sa), Some(sb)) => if sa.formula != sb.formula { return false }
          _ => ()
        }
      }
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
  guard candidates.length() > 0 else { return ops }
  // parse pre-filter: a candidate op the batch parser rejects outright
  // (e.g. a range at the grid boundary the expansion refuses) can never
  // replay; residualize it here so a chunk parse failure below always
  // means a non-candidate dump bug
  let parse_dropped : Set[Int] = Set::new()
  for candidate in candidates {
    let script = Json::object({
      "schema": Json::string(XLSX_BATCH_SCHEMA),
      "ops": Json::array([ops[candidate.op_index]]),
    })
    if (try? @batch.parse_script(script)) is Err(error) {
      parse_dropped.add(candidate.op_index)
      residual.push(table_residual(candidate, "\{error}"))
    }
  }
  let mut current_ops = ops
  let mut current = candidates
  if !parse_dropped.is_empty() {
    let (next_ops, next) = remove_dropped(current_ops, current, parse_dropped)
    current_ops = next_ops
    current = next
  }
  // replay-verify loop: every returned stream has passed a full replay,
  // even after the last candidate was dropped
  for ;; {
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
      ChunkParseFailed(span_start, span_end, message) => {
        // aggregate limits are cumulative, so the last candidate in the
        // failing chunk is the marginal contributor: drop it, disclose it,
        // and re-validate. With no candidate in the span this is a
        // non-candidate dump bug.
        let mut last : TableCandidate? = None
        for candidate in current {
          if candidate.op_index >= span_start && candidate.op_index < span_end {
            last = Some(candidate)
          }
        }
        match last {
          Some(candidate) => {
            dropped.add(candidate.op_index)
            residual.push(table_residual(candidate, message))
          }
          None =>
            raise DumpSelfCheckFailed(
              "chunk [\{span_start}, \{span_end}) failed to parse during validation: \{message}",
            )
        }
      }
      Replayed(replayed) => {
        for candidate in current {
          if !object_replayed_faithfully(source, replayed, candidate, current) {
            dropped.add(candidate.op_index)
            residual.push(
              table_residual(candidate, "readback diverges from the source"),
            )
          }
        }
        if dropped.is_empty() {
          // the stream we return replayed cleanly with every remaining
          // table faithful
          return current_ops
        }
      }
    }
    let (next_ops, next) = remove_dropped(current_ops, current, dropped)
    current_ops = next_ops
    current = next
  }
}

///|
/// Rebuilds the op stream without the dropped indices and re-maps the
/// remaining candidates to their new positions.
fn remove_dropped(
  ops : Array[Json],
  candidates : Array[TableCandidate],
  dropped : Set[Int],
) -> (Array[Json], Array[TableCandidate]) {
  let next_ops : Array[Json] = []
  let index_map : Map[Int, Int] = {}
  for index, op in ops {
    if !dropped.contains(index) {
      index_map[index] = next_ops.length()
      next_ops.push(op)
    }
  }
  let next : Array[TableCandidate] = []
  for candidate in candidates {
    if !dropped.contains(candidate.op_index) {
      match index_map.get(candidate.op_index) {
        Some(new_index) =>
          next.push({
            op_index: new_index,
            sheet: candidate.sheet,
            payload: candidate.payload,
          })
        None => ()
      }
    }
  }
  (next_ops, next)
}

///|
fn table_residual(candidate : TableCandidate, reason : String) -> DumpResidual {
  match candidate.payload {
    TableObject(table) =>
      {
        code: "xlsx.table_unsupported",
        severity: "dropped",
        scope: "cells",
        location: dump_location(candidate.sheet, "range", table.range_ref),
        asset: None,
        detail: "table \"\{table.display_name}\" does not replay faithfully through \{XLSX_BATCH_SCHEMA}: " +
        bounded_reason(reason),
      }
    ValidationObject(_, region) =>
      {
        code: "xlsx.validation_unsupported",
        severity: "dropped",
        scope: "cells",
        location: dump_location(candidate.sheet, "range", region),
        asset: None,
        detail: "data validation does not replay faithfully through \{XLSX_BATCH_SCHEMA}: " +
        bounded_reason(reason),
      }
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
