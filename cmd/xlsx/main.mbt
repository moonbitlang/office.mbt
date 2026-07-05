///|
/// A small command-line tool for common spreadsheet operations, built on
/// the mbtexcel library. Subcommands:
///
///   xlsx create <output> [--sheet NAME]        create a new workbook
///   xlsx csv <input> <output> [--sheet NAME]   import a CSV file into a workbook
///   xlsx set <file> <sheet> <cell> <value>     set a cell (in place)
///   xlsx formula <file> <sheet> <cell> <expr>  set a cell formula
///   xlsx style <file> <sheet> <range> [flags]  apply a cell style
///   xlsx merge <file> <sheet> <range>          merge a cell range
///   xlsx get <file> <sheet> <cell>             print a cell value
///   xlsx sheets <file>                         list sheet names
///   xlsx rows <file> [--sheet NAME]            print a sheet as CSV
///   xlsx view <file> [--sheet NAME]            print a sheet as an ASCII table
///   xlsx validate <file>                       check OOXML package validity
///
/// The subcommand handlers live in `commands.mbt` (and `commands_style.mbt`
/// for formula/style/merge); pure output formatting lives in `render.mbt`.
async fn main {
  run_cli() catch {
    // `--help`/`--version` are handled inside argparse (exit 0). Anything
    // that reaches here is a real failure. Re-raising it as a `CliError`
    // lets it escape `main`, which prints the message once and exits
    // non-zero (the async runtime exposes no public exit()). Errors go to
    // stdout on both targets, since the wasm backend has no stderr.
    err => {
      // argparse's own errors already start with "error:"; don't double it.
      let msg = "\{err}"
      raise CliError(
        if msg.has_prefix("error:") {
          msg
        } else {
          "error: " + msg
        },
      )
    }
  }
}

///|
/// A formatted, user-facing CLI error. Its `Show` writes exactly the
/// message, so the runtime's uncaught-error print produces one clean line.
suberror CliError {
  CliError(String)
}

///|
impl Show for CliError with fn output(self, logger) {
  match self {
    CliError(message) => logger.write_string(message)
  }
}

///|
/// Parses arguments and dispatches to the selected subcommand. Argument
/// errors from `parse` propagate to `main`.
async fn run_cli() -> Unit {
  let argv = @env.args()
  let args = if argv.length() > 0 { argv[1:].to_owned() } else { [] }
  let command = build_command()
  let matches = command.parse(argv=args[:], env={})
  match matches.subcommand {
    Some(("create", m)) => run_create(m)
    Some(("csv", m)) => run_import_csv(m)
    Some(("set", m)) => run_set(m)
    Some(("formula", m)) => run_formula(m)
    Some(("style", m)) => run_style(m)
    Some(("merge", m)) => run_merge(m)
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
        "csv",
        about="Import a CSV file into a new workbook",
        positionals=[
          @argparse.PositionArg("input", about="input .csv path"),
          @argparse.PositionArg("output", about="output .xlsx path"),
        ],
        options=[
          @argparse.OptionArg(
            "sheet",
            long="sheet",
            about="name of the sheet to create",
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
      @argparse.Command(
        "formula",
        about="Set a cell formula (leading '=' optional) and save in place",
        positionals=[
          @argparse.PositionArg("file"),
          @argparse.PositionArg("sheet"),
          @argparse.PositionArg("cell"),
          @argparse.PositionArg("formula", about="e.g. =SUM(B2:B10)"),
        ],
      ),
      @argparse.Command(
        "style",
        about="Apply a style to a cell or range and save in place",
        positionals=[
          @argparse.PositionArg("file"),
          @argparse.PositionArg("sheet"),
          @argparse.PositionArg("range", about="a cell (A1) or range (A1:B2)"),
        ],
        flags=[
          @argparse.FlagArg("bold", long="bold", about="bold font"),
          @argparse.FlagArg("italic", long="italic", about="italic font"),
        ],
        options=[
          @argparse.OptionArg(
            "number-format",
            long="number-format",
            about="number format code, e.g. \"#,##0.00\" or \"0%\"",
          ),
          @argparse.OptionArg(
            "fill",
            long="fill",
            about="solid fill color as hex RGB, e.g. FFFF00",
          ),
          @argparse.OptionArg(
            "align",
            long="align",
            about="horizontal alignment: left, center, or right",
          ),
        ],
      ),
      @argparse.Command(
        "merge",
        about="Merge a cell range (e.g. A1:B2) and save in place",
        positionals=[
          @argparse.PositionArg("file"),
          @argparse.PositionArg("sheet"),
          @argparse.PositionArg("range", about="range to merge, e.g. A1:B2"),
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
