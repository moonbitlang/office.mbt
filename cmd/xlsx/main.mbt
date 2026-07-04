///|
/// A small command-line tool for common spreadsheet operations, built on
/// the mbtexcel library. Subcommands:
///
///   xlsx create <output> [--sheet NAME]        create a new workbook
///   xlsx set <file> <sheet> <cell> <value>     set a cell (in place)
///   xlsx get <file> <sheet> <cell>             print a cell value
///   xlsx sheets <file>                         list sheet names
///   xlsx rows <file> [--sheet NAME]            print a sheet as CSV
///   xlsx view <file> [--sheet NAME]            print a sheet as an ASCII table
///   xlsx validate <file>                       check OOXML package validity
///
/// The subcommand handlers live in `commands.mbt`; pure output formatting
/// lives in `render.mbt`.
async fn main {
  let argv = @env.args()
  let args = if argv.length() > 0 { argv[1:].to_owned() } else { [] }
  let command = build_command()
  let matches = command.parse(argv=args[:], env={}) catch {
    err => {
      // argparse prints help/usage itself; surface anything else.
      println("error: \{err}")
      return
    }
  }
  match matches.subcommand {
    Some(("create", m)) => run_create(m)
    Some(("set", m)) => run_set(m)
    Some(("get", m)) => run_get(m)
    Some(("sheets", m)) => run_sheets(m)
    Some(("rows", m)) => run_rows(m)
    Some(("view", m)) => run_view(m)
    Some(("validate", m)) => run_validate(m)
    _ => println(command.render_help())
  }
}

///|
/// Builds the argparse command tree.
fn build_command() -> @argparse.Command {
  @argparse.Command(
    "xlsx",
    about="Create, inspect, and validate xlsx spreadsheets",
    subcommand_required=true,
    subcommands=[
      @argparse.Command(
        "create",
        about="Create a new empty workbook",
        positionals=[@argparse.PositionArg("output", about="output .xlsx path")],
        options=[
          @argparse.OptionArg(
            "sheet",
            long="sheet",
            about="name of the first sheet",
            default_values=["Sheet1"],
          ),
        ],
      ),
      @argparse.Command(
        "set",
        about="Set a cell value and save the file in place",
        positionals=[
          @argparse.PositionArg("file"),
          @argparse.PositionArg("sheet"),
          @argparse.PositionArg("cell"),
          @argparse.PositionArg("value"),
        ],
      ),
      @argparse.Command("get", about="Print a single cell value", positionals=[
        @argparse.PositionArg("file"),
        @argparse.PositionArg("sheet"),
        @argparse.PositionArg("cell"),
      ]),
      @argparse.Command("sheets", about="List the sheet names in a workbook", positionals=[
        @argparse.PositionArg("file"),
      ]),
      @argparse.Command(
        "rows",
        about="Print a sheet as CSV",
        positionals=[@argparse.PositionArg("file")],
        options=[
          @argparse.OptionArg(
            "sheet",
            long="sheet",
            about="sheet to export (default: first sheet)",
          ),
        ],
      ),
      @argparse.Command(
        "view",
        about="Print a sheet as an ASCII table",
        positionals=[@argparse.PositionArg("file")],
        options=[
          @argparse.OptionArg(
            "sheet",
            long="sheet",
            about="sheet to view (default: first sheet)",
          ),
        ],
      ),
      @argparse.Command(
        "validate",
        about="Report OOXML package structure problems (empty = valid)",
        positionals=[@argparse.PositionArg("file")],
      ),
    ],
  )
}
