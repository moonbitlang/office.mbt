// Agent-oriented structured reads: `outline` (workbook map), the `--json`
// mode of `get` (range read), and `query` (content-selector search). All
// print versioned JSON payloads built by the `inspect` library package;
// see docs/agent-json-schemas.md.

///|
async fn run_outline(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let workbook = @lib.open_file(file)
  println(@inspect.outline(workbook, file~).stringify(indent=2))
}

///|
/// `query`: prints the `xlsx.query/1` payload — the cells matching a content
/// selector, scanned over `--range` or the used range.
async fn run_query(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let workbook = @lib.open_file(file)
  println(
    @inspect.query(
      workbook,
      arg(m, "sheet"),
      arg(m, "selector"),
      file~,
      range=arg(m, "range"),
    ).stringify(indent=2),
  )
}

///|
/// `lint`: prints the `xlsx.lint/1` payload — the formula cells that evaluate
/// to an error, across all sheets or only `--sheet`.
async fn run_lint(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let workbook = @lib.open_file(file)
  println(
    @inspect.lint(workbook, file~, sheet=arg(m, "sheet")).stringify(indent=2),
  )
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
