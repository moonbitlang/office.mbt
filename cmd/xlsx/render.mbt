// Pure text-formatting helpers for CLI output. These have no IO and are
// straightforward to test in isolation.

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
  let border = ascii_border(widths)
  let lines = [border, ascii_row(rows[0], widths)]
  if rows.length() > 1 {
    lines.push(border)
    for i in 1..<rows.length() {
      lines.push(ascii_row(rows[i], widths))
    }
  }
  lines.push(border)
  lines.join("\n")
}

///|
/// A `+---+---+` horizontal rule sized to the given column widths.
fn ascii_border(widths : Array[Int]) -> String {
  "+" + widths.map(w => "-".repeat(w + 2)).join("+") + "+"
}

///|
/// A `| a | b |` table row, padding each cell to its column width.
fn ascii_row(cells : Array[String], widths : Array[Int]) -> String {
  let segs = []
  for c in 0..<widths.length() {
    let cell = if c < cells.length() { cells[c] } else { "" }
    segs.push(" " + cell.pad_end(widths[c], ' ') + " ")
  }
  "|" + segs.join("|") + "|"
}

///|
/// Quotes a CSV field when it contains a comma, quote, CR, or LF. CR must be
/// quoted too: an unquoted `\r` is consumed as a line terminator by the `csv`
/// importer's parser, so leaving it bare would lose data on a round-trip.
fn csv_field(value : String) -> String {
  if value.contains(",") ||
    value.contains("\"") ||
    value.contains("\n") ||
    value.contains("\r") {
    "\"" + value.replace_all(old="\"", new="\"\"") + "\""
  } else {
    value
  }
}
