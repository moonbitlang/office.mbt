// Agent-oriented structured reads: `outline` (workbook map) and the
// `--json` mode of `get` (range read). Both print versioned JSON payloads
// built by the `inspect` library package; see docs/agent-json-schemas.md.

///|
async fn run_outline(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let workbook = @lib.open_file(file)
  println(@inspect.outline(workbook, file~).stringify(indent=2))
}

///|
/// The `--json` branch of `get`: prints the `xlsx.cells/1` payload for a
/// cell or range instead of the plain single-cell value.
async fn run_get_json(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let workbook = @lib.open_file(file)
  println(
    @inspect.cells(workbook, file~, arg(m, "sheet"), arg(m, "cell")).stringify(
      indent=2,
    ),
  )
}
