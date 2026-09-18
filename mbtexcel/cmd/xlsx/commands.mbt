// Subcommand handlers and their shared helpers. Each handler reads its
// parsed arguments from `Matches`, performs the workbook operation, and
// prints a result.

///|
/// Returns the single value of a positional/option, or "" when absent.
fn arg(m : @argparse.Matches, name : String) -> String {
  match m.values.get(name) {
    Some(values) if values.length() > 0 => values[0]
    _ => ""
  }
}

///|
/// The sheet to operate on: the requested name, or the first sheet when
/// none was given.
fn resolve_sheet(workbook : @xl.Workbook, requested : String) -> String {
  if requested != "" {
    requested
  } else {
    workbook.get_sheet_name(0).unwrap_or("")
  }
}

///|
/// Set a cell, storing plain numbers as real numeric cells (so formulas
/// evaluate and number formats render) and everything else as text.
fn set_cell_auto(
  workbook : @xl.Workbook,
  sheet : String,
  cell : String,
  raw : String,
) -> Unit raise @xl.XlsxError {
  match classify_cell_value(raw) {
    AsInt(value) => workbook.set_cell_int(sheet, cell, value)
    AsFloat(value) => workbook.set_cell_float(sheet, cell, value)
    AsText => workbook.set_cell(sheet, cell, raw)
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
  set_cell_auto(workbook, sheet, cell, value)
  write_file(file, @lib.write(workbook))
  println("set \{sheet}!\{cell} = \{value}")
}

///|
async fn run_get(m : @argparse.Matches) -> Unit {
  if flag(m, "json") {
    run_get_json(m)
    return
  }
  let workbook = @lib.open_file(arg(m, "file"))
  let sheet = arg(m, "sheet")
  let cell = arg(m, "cell")
  let value = workbook.get_cell(sheet, cell).unwrap_or("")
  if value != "" {
    println(value)
  } else {
    // A formula cell has no cached value (the tool doesn't evaluate formulas),
    // so fall back to showing the formula itself rather than a blank line.
    match workbook.get_cell_formula(sheet, cell) {
      Some(formula) => println("=" + formula)
      None => println("")
    }
  }
}

///|
async fn run_calc(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let workbook = @lib.open_file(file)
  // `--json` prints the typed computed value (xlsx.calc/1) — the gap
  // `get --json` leaves for an uncached formula. Otherwise print the string:
  // `--raw` is the unformatted result; the default applies the cell's number
  // format, like Excel's displayed value.
  if flag(m, "json") {
    println(
      @inspect.calc(workbook, file~, arg(m, "sheet"), arg(m, "cell")).stringify(
        indent=2,
      ),
    )
    return
  }
  println(
    workbook.calc_cell_value(
      arg(m, "sheet"),
      arg(m, "cell"),
      raw=flag(m, "raw"),
    ),
  )
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
async fn run_import_csv(m : @argparse.Matches) -> Unit {
  let input = arg(m, "input")
  let output = arg(m, "output")
  let sheet = arg(m, "sheet")
  let text = @encoding/utf8.decode(@async/fs.read_file(input).binary())
  let rows = parse_csv(text)
  let workbook = @lib.new_workbook()
  ignore(workbook.add_sheet(sheet))
  for r in 0..<rows.length() {
    let cols = rows[r]
    for c in 0..<cols.length() {
      // Write every field, including empty ones: an explicit empty cell keeps
      // the used range, so a CSV's shape (trailing/interior blank cells, blank
      // rows) survives a `csv` -> `rows` round-trip. Plain numbers are stored
      // as real numeric cells.
      set_cell_auto(
        workbook,
        sheet,
        @lib.coordinates_to_cell_name(c + 1, r + 1),
        cols[c],
      )
    }
  }
  write_file(output, @lib.write(workbook))
  println("imported \{rows.length()} row(s) into \{output} (sheet \{sheet})")
}

///|
async fn run_view(m : @argparse.Matches) -> Unit {
  let workbook = @lib.open_file(arg(m, "file"))
  let sheet = resolve_sheet(workbook, arg(m, "sheet"))
  println(render_ascii_table(workbook.get_rows(sheet)))
}

///|
async fn run_validate(m : @argparse.Matches) -> Unit {
  // Validate the file's own bytes, not a re-serialized copy: opening and
  // rewriting would hide input-package defects the reader tolerates.
  let bytes = @async/fs.read_file(arg(m, "file")).binary()
  let problems = @xl.validate_ooxml_package(bytes)
  if problems.length() == 0 {
    println("valid")
  } else {
    for problem in problems {
      println(problem)
    }
  }
}

///|
async fn write_file(path : String, bytes : Bytes) -> Unit {
  @async/fs.write_file(
    path,
    bytes,
    create_mode=CreateOrTruncate,
    permission=0o644,
  )
}
