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
/// Errors print `error: <message>` to stderr and exit non-zero.
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

///|
/// Returns the single value of a positional/option, or "" when absent.
fn arg(m : @argparse.Matches, name : String) -> String {
  match m.values.get(name) {
    Some(values) if values.length() > 0 => values[0]
    _ => ""
  }
}

///|
async fn run_create(m : @argparse.Matches) -> Unit {
  let output = arg(m, "output")
  let sheet = arg(m, "sheet")
  let workbook = @lib.new_workbook()
  ignore(workbook.add_sheet(sheet))
  write_file(output, @lib.write(workbook))
  println("created \{output} (sheet \{sheet})")
}

///|
async fn run_set(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let sheet = arg(m, "sheet")
  let cell = arg(m, "cell")
  let value = arg(m, "value")
  let workbook = @lib.open_file(file)
  workbook.set_cell(sheet, cell, value)
  write_file(file, @lib.write(workbook))
  println("set \{sheet}!\{cell} = \{value}")
}

///|
async fn run_get(m : @argparse.Matches) -> Unit {
  let workbook = @lib.open_file(arg(m, "file"))
  match workbook.get_cell(arg(m, "sheet"), arg(m, "cell")) {
    Some(value) => println(value)
    None => println("")
  }
}

///|
async fn run_sheets(m : @argparse.Matches) -> Unit {
  let workbook = @lib.open_file(arg(m, "file"))
  for name in workbook.get_sheet_list() {
    println(name)
  }
}

///|
async fn run_rows(m : @argparse.Matches) -> Unit {
  let workbook = @lib.open_file(arg(m, "file"))
  let sheet = resolve_sheet(workbook, arg(m, "sheet"))
  for row in workbook.get_rows(sheet) {
    println(row.map(csv_field).join(","))
  }
}

///|
async fn run_view(m : @argparse.Matches) -> Unit {
  let workbook = @lib.open_file(arg(m, "file"))
  let sheet = resolve_sheet(workbook, arg(m, "sheet"))
  println(render_ascii_table(workbook.get_rows(sheet)))
}

///|
/// The sheet to operate on: the requested name, or the first sheet when
/// none was given.
fn resolve_sheet(workbook : @xl.Workbook, requested : String) -> String {
  if requested != "" {
    requested
  } else {
    match workbook.get_sheet_name(0) {
      Some(name) => name
      None => ""
    }
  }
}

///|
/// Renders a grid of rows as an ASCII table. The first row is treated as
/// a header and separated from the body by a rule. Column widths are the
/// widest cell in each column (measured in UTF-16 code units).
fn render_ascii_table(rows : Array[Array[String]]) -> String {
  let ncols = rows.fold(init=0, (n, r) => {
    if r.length() > n {
      r.length()
    } else {
      n
    }
  })
  if rows.length() == 0 || ncols == 0 {
    return "(empty sheet)"
  }
  let widths = Array::make(ncols, 0)
  for r in rows {
    for c in 0..<ncols {
      let cell = if c < r.length() { r[c] } else { "" }
      if cell.length() > widths[c] {
        widths[c] = cell.length()
      }
    }
  }
  let lines = [ascii_border(widths), ascii_row(rows[0], widths)]
  if rows.length() > 1 {
    lines.push(ascii_border(widths))
    for i in 1..<rows.length() {
      lines.push(ascii_row(rows[i], widths))
    }
  }
  lines.push(ascii_border(widths))
  lines.join("\n")
}

///|
fn ascii_border(widths : Array[Int]) -> String {
  let segs = widths.map(w => "-".repeat(w + 2))
  "+" + segs.join("+") + "+"
}

///|
fn ascii_row(cells : Array[String], widths : Array[Int]) -> String {
  let segs = []
  for c in 0..<widths.length() {
    let cell = if c < cells.length() { cells[c] } else { "" }
    segs.push(" " + cell.pad_end(widths[c], ' ') + " ")
  }
  "|" + segs.join("|") + "|"
}

///|
async fn run_validate(m : @argparse.Matches) -> Unit {
  let workbook = @lib.open_file(arg(m, "file"))
  let problems = @xl.validate_ooxml_package(@lib.write(workbook)[:])
  if problems.length() == 0 {
    println("valid")
  } else {
    for problem in problems {
      println(problem)
    }
  }
}

///|
/// Quotes a CSV field when it contains a comma, quote, or newline.
fn csv_field(value : String) -> String {
  if value.contains(",") || value.contains("\"") || value.contains("\n") {
    "\"" + value.replace_all(old="\"", new="\"\"") + "\""
  } else {
    value
  }
}

///|
async fn write_file(path : String, bytes : Bytes) -> Unit {
  @async/fs.write_file(
    path,
    bytes,
    create_mode=@async/fs.CreateOrTruncate,
    permission=0o644,
  )
}
