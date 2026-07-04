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
  println(workbook.get_cell(arg(m, "sheet"), arg(m, "cell")).unwrap_or(""))
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
async fn write_file(path : String, bytes : Bytes) -> Unit {
  @async/fs.write_file(
    path,
    bytes,
    create_mode=@async/fs.CreateOrTruncate,
    permission=0o644,
  )
}
