///|
/// The outcome of replaying an op stream from scratch: the workbook, or
/// the global index of the first op whose apply failed. A failed apply may
/// leave the scratch workbook partially mutated, so callers must never
/// reuse it — validation always re-replays from scratch after dropping
/// the failing op.
priv enum ReplayOutcome {
  Replayed(@xlsx.Workbook)
  FailedAt(Int, String)
  ChunkParseFailed(Int, Int, String)
}

///|
/// Replays `ops` into a fresh workbook (create sheet first), chunked by the
/// shared policy, reporting the first failing op's global index instead of
/// raising, so object validation can attribute the failure.
fn replay_ops_traced(
  create_sheet : String,
  ops : Array[Json],
) -> ReplayOutcome raise {
  let workbook = @xlsx.Workbook::new()
  ignore(
    workbook.add_sheet(create_sheet) catch {
      _ => raise DumpSelfCheckFailed("create sheet rejected: \{create_sheet}")
    },
  )
  let mut base = 0
  for chunk in xlsx_dump_op_chunks(ops) {
    let script = Json::object({
      "schema": Json::string(XLSX_BATCH_SCHEMA),
      "ops": Json::array(chunk),
    })
    let parsed = @batch.parse_script(script) catch {
      // aggregate plan limits can reject a chunk whose ops each parse
      // alone; report the chunk span so validation can attribute it
      error => return ChunkParseFailed(base, base + chunk.length(), "\{error}")
    }
    for offset, op in parsed {
      match (try? @batch.apply_op(workbook, op)) {
        Ok(_) => ()
        Err(error) => return FailedAt(base + offset, "\{error}")
      }
    }
    base += chunk.length()
  }
  Replayed(workbook)
}

///|
/// Typed cell-value equality for readback comparison.
fn cell_values_equal(a : @xlsx.CellValue?, b : @xlsx.CellValue?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(String(x)), Some(String(y))) => x == y
    (Some(Numeric(x)), Some(Numeric(y))) => x == y
    (Some(Bool(x)), Some(Bool(y))) => x == y
    (Some(Error(x)), Some(Error(y))) => x == y
    _ => false
  }
}
