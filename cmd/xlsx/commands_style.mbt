// Formatting subcommands — formula, style, and merge — which surface the
// richer parts of the mbtexcel library (cell formulas, styles, merges) beyond
// plain text cells.

///|
/// Reads a boolean flag from the parsed arguments.
fn flag(m : @argparse.Matches, name : String) -> Bool {
  m.flags.get_or_default(name, false)
}

///|
/// Index of the first `:` in `s`, or `None`.
fn colon_index(s : String) -> Int? {
  for i in 0..<s.length() {
    if s[i] == (':' : UInt16) {
      return Some(i)
    }
  }
  None
}

///|
/// Expand a single cell (`A1`) or an `A1:B2`-style range into the list of
/// individual cell references it covers, in row-major order. The shared
/// bounded parser (`@inspect.parse_range`) guards against a pathological
/// range exhausting memory; a bare cell name passes through untouched, as
/// before.
fn expand_range(target : String) -> Array[String] raise {
  match colon_index(target) {
    None => [target]
    Some(_) => {
      let range = @inspect.parse_range(target) catch {
        RangeTooLarge(count~, ..) =>
          raise CliError(
            "error: range \{target} covers \{count} cells; max is \{@inspect.MAX_RANGE_CELLS}",
          )
        err => raise err
      }
      range.cells()
    }
  }
}

///|
async fn run_formula(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let sheet = arg(m, "sheet")
  let cell = arg(m, "cell")
  // Accept the formula with or without a leading '=' (stored without it).
  let raw = arg(m, "formula")
  let formula = if raw.has_prefix("=") { raw[1:].to_owned() } else { raw }
  let workbook = @lib.open_file(file)
  workbook.set_cell_formula(sheet, cell, formula)
  write_file(file, @lib.write(workbook))
  println("set \{sheet}!\{cell} = =\{formula}")
}

///|
async fn run_merge(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let sheet = arg(m, "sheet")
  let range = arg(m, "range")
  let workbook = @lib.open_file(file)
  workbook.merge_cells(sheet, range)
  write_file(file, @lib.write(workbook))
  println("merged \{sheet}!\{range}")
}

///|
async fn run_style(m : @argparse.Matches) -> Unit {
  let file = arg(m, "file")
  let sheet = arg(m, "sheet")
  let target = arg(m, "range")
  let workbook = @lib.open_file(file)
  // Build a style from the provided flags/options; unset ones are left alone.
  let style = @batch.build_style(
    bold=flag(m, "bold"),
    italic=flag(m, "italic"),
    number_format=arg(m, "number-format"),
    fill=arg(m, "fill"),
    font_color=arg(m, "font-color"),
    align=arg(m, "align"),
  )
  let style_id = workbook.new_style(style)
  let cells = expand_range(target)
  for cell in cells {
    workbook.set_cell_style(sheet, cell, style_id)
  }
  write_file(file, @lib.write(workbook))
  println("styled \{cells.length()} cell(s) in \{sheet}!\{target}")
}
