///|
/// Errors raised while replaying a dump into a workbook.
pub suberror ReplayError {
  ReplayInvalidFormat(String)
  ReplayFailed(String)
} derive(@debug.Debug)

///|
/// Replays an `office.dump/1` XLSX envelope into an equivalent workbook by
/// applying its ordered batch ops through the same engine that authored
/// them. The create sheet is added first, then every op in stream order.
/// Apply-time validation runs here exactly as it would during a real
/// `office batch`, so a stream that replays cleanly is genuinely
/// replayable.
pub fn replay_xlsx_dump(envelope : DumpEnvelope) -> @xlsx.Workbook raise {
  guard envelope.format == "xlsx" else {
    raise ReplayInvalidFormat(
      "replay expects an xlsx dump, got \{envelope.format}",
    )
  }
  guard envelope.create_sheet is Some(create_sheet) else {
    raise ReplayInvalidFormat("xlsx dump is missing its create sheet")
  }
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet(create_sheet))
  let script = Json::object({
    "schema": Json::string(envelope.batch_schema),
    "ops": Json::array(envelope.ops),
  })
  let ops = @batch.parse_script(script) catch {
    error => raise ReplayFailed("dump ops did not parse: \{error}")
  }
  for op in ops {
    @batch.apply_op(workbook, op) catch {
      error => raise ReplayFailed("dump op failed to apply: \{error}")
    }
  }
  workbook
}
