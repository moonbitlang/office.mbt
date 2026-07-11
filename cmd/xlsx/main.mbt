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
///   xlsx width <file> <sheet> <col> <width>    set a column (or A:C) width
///   xlsx freeze <file> <sheet> <cell>          freeze panes above/left of cell
///   xlsx filter <file> <sheet> <range>         add an auto-filter over a range
///   xlsx add-sheet <file> <name>               add a sheet to a workbook
///   xlsx chart <file> <sheet> <anchor> [opts]  add a chart from a data range
///   xlsx batch <file> <script.json> [--dry-run] apply a JSON op script
///   xlsx get <file> <sheet> <cell> [--json]    print a cell value (or a
///                                              cell/range as JSON)
///   xlsx outline <file>                        print a workbook map as JSON
///   xlsx html <file> [--sheet --out ...]       render sheets as HTML
///   xlsx calc <file> <sheet> <cell> [--raw]    evaluate a cell's formula
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
  let matches = command.parse(argv=args, env=Map([]))
  match matches.subcommand {
    Some(("create", m)) => run_create(m)
    Some(("csv", m)) => run_import_csv(m)
    Some(("set", m)) => run_set(m)
    Some(("formula", m)) => run_formula(m)
    Some(("style", m)) => run_style(m)
    Some(("merge", m)) => run_merge(m)
    Some(("width", m)) => run_width(m)
    Some(("freeze", m)) => run_freeze(m)
    Some(("filter", m)) => run_filter(m)
    Some(("add-sheet", m)) => run_add_sheet(m)
    Some(("chart", m)) => run_chart(m)
    Some(("batch", m)) => run_batch(m)
    Some(("get", m)) => run_get(m)
    Some(("outline", m)) => run_outline(m)
    Some(("query", m)) => run_query(m)
    Some(("lint", m)) => run_lint(m)
    Some(("capabilities", m)) => run_capabilities(m)
    Some(("html", m)) => run_html(m)
    Some(("calc", m)) => run_calc(m)
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
  Command(
    "xlsx",
    about="Create, inspect, and validate xlsx spreadsheets",
    subcommand_required=true,
    subcommands=[
      Command(
        "create",
        about="Create a new empty workbook",
        positionals=[PositionArg("output", about="output .xlsx path")],
        options=[
          OptionArg("sheet", long="sheet", about="name of the first sheet", default_values=[
            "Sheet1",
          ]),
        ],
      ),
      Command(
        "csv",
        about="Import a CSV file into a new workbook",
        positionals=[
          PositionArg("input", about="input .csv path"),
          PositionArg("output", about="output .xlsx path"),
        ],
        options=[
          OptionArg(
            "sheet",
            long="sheet",
            about="name of the sheet to create",
            default_values=["Sheet1"],
          ),
        ],
      ),
      Command("set", about="Set a cell value and save the file in place", positionals=[
        PositionArg("file"),
        PositionArg("sheet"),
        PositionArg("cell"),
        PositionArg("value"),
      ]),
      Command(
        "formula",
        about="Set a cell formula (leading '=' optional) and save in place",
        positionals=[
          PositionArg("file"),
          PositionArg("sheet"),
          PositionArg("cell"),
          PositionArg("formula", about="e.g. =SUM(B2:B10)"),
        ],
      ),
      Command(
        "style",
        about="Apply a style to a cell or range and save in place",
        positionals=[
          PositionArg("file"),
          PositionArg("sheet"),
          PositionArg("range", about="a cell (A1) or range (A1:B2)"),
        ],
        flags=[
          FlagArg("bold", long="bold", about="bold font"),
          FlagArg("italic", long="italic", about="italic font"),
        ],
        options=[
          OptionArg(
            "number-format",
            long="number-format",
            about="number format code, e.g. \"#,##0.00\" or \"0%\"",
          ),
          OptionArg(
            "fill",
            long="fill",
            about="solid fill color as hex RGB, e.g. FFFF00",
          ),
          OptionArg(
            "font-color",
            long="font-color",
            about="font color as hex RGB, e.g. FFFFFF (white)",
          ),
          OptionArg(
            "align",
            long="align",
            about="horizontal alignment: left, center, or right",
          ),
        ],
      ),
      Command(
        "merge",
        about="Merge a cell range (e.g. A1:B2) and save in place",
        positionals=[
          PositionArg("file"),
          PositionArg("sheet"),
          PositionArg("range", about="range to merge, e.g. A1:B2"),
        ],
      ),
      Command(
        "width",
        about="Set a column's (or a column range's) width and save in place",
        positionals=[
          PositionArg("file"),
          PositionArg("sheet"),
          PositionArg("column", about="a column (A) or range (A:C)"),
          PositionArg("width", about="width in character units, e.g. 18"),
        ],
      ),
      Command(
        "freeze",
        about="Freeze panes above and left of a cell (e.g. A2 freezes row 1)",
        positionals=[
          PositionArg("file"),
          PositionArg("sheet"),
          PositionArg("cell", about="first scrollable cell, e.g. A2"),
        ],
      ),
      Command(
        "filter",
        about="Add an auto-filter over a range and save in place",
        positionals=[
          PositionArg("file"),
          PositionArg("sheet"),
          PositionArg("range", about="range to filter, e.g. A1:C10"),
        ],
      ),
      Command(
        "add-sheet",
        about="Add a new empty sheet to an existing workbook",
        positionals=[
          PositionArg("file"),
          PositionArg("name", about="name of the new sheet"),
        ],
      ),
      Command(
        "chart",
        about="Add a chart (col/bar/line/pie/…) from a data range and save in place",
        positionals=[
          PositionArg("file"),
          PositionArg("sheet"),
          PositionArg("anchor", about="top-left cell of the chart, e.g. E2"),
        ],
        options=[
          OptionArg(
            "type",
            long="type",
            about="chart type: col (default), bar, line, pie, area, scatter, doughnut, radar",
          ),
          OptionArg(
            "categories",
            long="categories",
            about="category-label range, e.g. A2:A6",
          ),
          OptionArg(
            "values",
            long="values",
            about="series value range, e.g. B2:B6",
          ),
          OptionArg(
            "name",
            long="name",
            about="series legend label (a literal; for a cell use a qualified ref like Sheet1!B1)",
          ),
          OptionArg("title", long="title", about="chart title"),
        ],
      ),
      Command(
        "batch",
        about="Apply an xlsx.batch/1 JSON op script and save in place",
        positionals=[
          PositionArg("file"),
          PositionArg(
            "script",
            about="path of the op script (see docs/agent-json-schemas.md)",
          ),
        ],
        flags=[
          FlagArg(
            "dry-run",
            long="dry-run",
            about="parse and apply in memory but do not write the file",
          ),
        ],
      ),
      Command(
        "get",
        about="Print a single cell value (or a cell/range as JSON)",
        positionals=[
          PositionArg("file"),
          PositionArg("sheet"),
          PositionArg(
            "cell",
            about="a cell (A1) or, with --json, a range (A1:B2)",
          ),
        ],
        flags=[
          FlagArg(
            "json",
            long="json",
            about="print the cell or range as a structured JSON payload",
          ),
        ],
      ),
      Command(
        "capabilities",
        about="Print the batch op catalog this build supports (JSON)",
      ),
      Command("outline", about="Print a workbook structure map as JSON", positionals=[
        PositionArg("file"),
      ]),
      Command(
        "query",
        about="Find cells matching a content selector, as JSON",
        positionals=[
          PositionArg("file"),
          PositionArg("sheet"),
          PositionArg(
            "selector",
            about="e.g. cell[type=formula], cell[value>100], cell[formula~=SUM]",
          ),
        ],
        options=[
          OptionArg(
            "range",
            long="range",
            about="limit the scan to this range (default: the used range)",
          ),
        ],
      ),
      Command(
        "lint",
        about="Report formula cells that evaluate to an error, as JSON",
        positionals=[PositionArg("file")],
        options=[
          OptionArg(
            "sheet",
            long="sheet",
            about="lint only this sheet (default: all sheets)",
          ),
        ],
      ),
      Command(
        "html",
        about="Render sheets as a self-contained HTML document",
        positionals=[PositionArg("file")],
        options=[
          OptionArg(
            "sheet",
            long="sheet",
            about="render only this sheet (default: all sheets)",
          ),
          OptionArg(
            "out",
            long="out",
            about="write the document here instead of stdout",
          ),
          OptionArg(
            "max-rows",
            long="max-rows",
            about="rows to render per sheet (default 1000)",
          ),
          OptionArg(
            "max-cols",
            long="max-cols",
            about="columns to render per sheet (default 256)",
          ),
        ],
        flags=[
          FlagArg(
            "no-images",
            long="no-images",
            about="skip embedding images as data: URIs",
          ),
          FlagArg(
            "calc",
            long="calc",
            about="evaluate formulas that have no cached result",
          ),
        ],
      ),
      Command(
        "calc",
        about="Evaluate a cell's formula and print the computed value",
        positionals=[
          PositionArg("file"),
          PositionArg("sheet"),
          PositionArg("cell"),
        ],
        flags=[
          FlagArg(
            "raw",
            long="raw",
            about="print the unformatted computed value",
          ),
          FlagArg(
            "json",
            long="json",
            about="print the typed computed value as a JSON payload",
          ),
        ],
      ),
      Command("sheets", about="List the sheet names in a workbook", positionals=[
        PositionArg("file"),
      ]),
      Command(
        "rows",
        about="Print a sheet as CSV",
        positionals=[PositionArg("file")],
        options=[
          OptionArg(
            "sheet",
            long="sheet",
            about="sheet to export (default: first sheet)",
          ),
        ],
      ),
      Command(
        "view",
        about="Print a sheet as an ASCII table",
        positionals=[PositionArg("file")],
        options=[
          OptionArg(
            "sheet",
            long="sheet",
            about="sheet to view (default: first sheet)",
          ),
        ],
      ),
      Command(
        "validate",
        about="Report OOXML package structure problems (empty = valid)",
        positionals=[PositionArg("file")],
      ),
    ],
  )
}
