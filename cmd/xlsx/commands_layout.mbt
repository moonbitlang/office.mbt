// Layout and sheet-management subcommands — column widths, frozen panes,
// auto-filters, and adding a sheet to an existing workbook.

///|
async fn run_width(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let sheet = arg(m, "sheet")
  let target = arg(m, "column")
  let width_text = arg(m, "width")
  let width = @string.parse_double(width_text) catch {
    _ =>
      raise CliError("error: invalid width '\{width_text}' (expected a number)")
  }
  let workbook = @lib.open_file(file)
  // A `:` (e.g. "A:C") sets a whole column range; otherwise a single column.
  if target.contains(":") {
    workbook.set_col_width_range(sheet, target, width)
  } else {
    workbook.set_col_width(sheet, @lib.column_name_to_number(target), width)
  }
  write_file(file, @lib.write(workbook))
  println("set width of \{sheet}!\{target} to \{width}")
}

///|
async fn run_freeze(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let sheet = arg(m, "sheet")
  let cell = arg(m, "cell")
  // Freeze every row above and every column left of `cell`: the columns/rows
  // before it become the frozen split, and `cell` is the first scrollable cell.
  let (col, row) = @lib.cell_name_to_coordinates(cell)
  let workbook = @lib.open_file(file)
  workbook.set_panes(
    sheet,
    @xl.Panes::with_values(
      freeze=true,
      x_split=col - 1,
      y_split=row - 1,
      top_left_cell=cell,
    ),
  )
  write_file(file, @lib.write(workbook))
  println("froze panes above and left of \{sheet}!\{cell}")
}

///|
async fn run_filter(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let sheet = arg(m, "sheet")
  let range = arg(m, "range")
  let workbook = @lib.open_file(file)
  workbook.auto_filter(sheet, range, [])
  write_file(file, @lib.write(workbook))
  println("added auto-filter to \{sheet}!\{range}")
}

///|
async fn run_add_sheet(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let name = arg(m, "name")
  let workbook = @lib.open_file(file)
  ignore(workbook.add_sheet(name))
  write_file(file, @lib.write(workbook))
  println("added sheet \{name}")
}
