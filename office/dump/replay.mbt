///|
/// Errors raised while replaying a dump into a workbook.
pub suberror ReplayError {
  ReplayInvalidFormat(String)
  ReplayFailed(String)
} derive(@debug.Debug)

///|
/// Replays an `office.dump/1` XLSX envelope by applying its ordered batch
/// ops through the same engine that authored them: the create sheet first,
/// then every op in stream order. Apply-time validation runs here as it
/// would during a real `office batch`, so a stream that replays cleanly is
/// genuinely replayable. The result reproduces the dump's REPLAYABLE
/// content only — features recorded as residual (custom properties,
/// images, and so on) are not reconstructed.
pub fn replay_xlsx_dump(
  envelope : DumpEnvelope,
) -> @xlsx.Workbook raise ReplayError {
  guard envelope.format == "xlsx" else {
    raise ReplayInvalidFormat(
      "replay expects an xlsx dump, got \{envelope.format}",
    )
  }
  // validate the batch schema up front — an empty op stream produces no
  // chunks, so the per-chunk parse below would never see a wrong schema
  guard envelope.batch_schema == XLSX_BATCH_SCHEMA else {
    raise ReplayInvalidFormat(
      "xlsx dump has an unexpected batch schema: \{envelope.batch_schema}",
    )
  }
  guard envelope.create_sheet is Some(create_sheet) else {
    raise ReplayInvalidFormat("xlsx dump is missing its create sheet")
  }
  let workbook = @xlsx.Workbook::new()
  ignore(
    workbook.add_sheet(create_sheet) catch {
      _ =>
        raise ReplayInvalidFormat(
          "create sheet name is invalid: \"\{create_sheet}\"",
        )
    },
  )
  // apply the ops in the SAME chunks the dump self-check validated, so a
  // dump spanning the op or new-style ceiling replays exactly as it was
  // checked (one whole-envelope batch would exceed those limits)
  for chunk in xlsx_dump_op_chunks(envelope.ops) {
    let script = Json::object({
      "schema": Json::string(envelope.batch_schema),
      "ops": Json::array(chunk),
    })
    let ops = @batch.parse_script(script) catch {
      error => raise ReplayFailed("dump ops did not parse: \{error}")
    }
    for op in ops {
      @batch.apply_op(workbook, op) catch {
        error => raise ReplayFailed("dump op failed to apply: \{error}")
      }
    }
  }
  workbook
}
