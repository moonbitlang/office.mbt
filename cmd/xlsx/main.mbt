///|
/// A small command-line tool for common spreadsheet operations, built on
/// the mbtexcel library. Subcommands:
///
///   xlsx create <output> [--sheet NAME]        create a new workbook
///   xlsx set <file> <sheet> <cell> <value>     set a cell (in place)
///   xlsx get <file> <sheet> <cell>             print a cell value
///   xlsx sheets <file>                         list sheet names
///   xlsx rows <file> [--sheet NAME]            print a sheet as CSV
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
  let sheet = {
    let requested = arg(m, "sheet")
    if requested != "" {
      requested
    } else {
      match workbook.get_sheet_name(0) {
        Some(name) => name
        None => ""
      }
    }
  }
  for row in workbook.get_rows(sheet) {
    println(row.map(csv_field).join(","))
  }
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
  @async/fs.write_file(path, bytes, create=0o644)
}
