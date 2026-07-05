// CSV parsing for the `csv` import command. Kept pure (no IO) so it can be
// unit-tested directly; the reverse direction (a sheet -> CSV) is `csv_field`
// in render.mbt.

///|
/// Parse RFC 4180 CSV text into rows of string fields.
///
/// Handles quoted fields (`"..."`), doubled-quote escapes (`""` -> `"`),
/// commas and newlines embedded inside quotes, and both `LF` and `CRLF` line
/// endings. A trailing newline does not produce an extra empty row, and empty
/// input yields no rows. A leading UTF-8 BOM (`U+FEFF`) is stripped.
fn parse_csv(text : String) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  let row : Array[String] = []
  let field = StringBuilder::new()
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  // Strip a leading byte-order mark if present.
  let start = if chars.length() > 0 && chars[0] == '\u{FEFF}' { 1 } else { 0 }
  let n = chars.length()
  let mut i = start
  let mut in_quotes = false
  // Whether the current record has started (a field char, quote, or comma seen
  // since the last row terminator) — used to decide the final flush.
  let mut pending = false
  while i < n {
    let c = chars[i]
    if in_quotes {
      if c == '"' {
        if i + 1 < n && chars[i + 1] == '"' {
          field.write_char('"')
          i += 1
        } else {
          in_quotes = false
        }
      } else {
        field.write_char(c)
      }
    } else if c == '"' {
      in_quotes = true
      pending = true
    } else if c == ',' {
      row.push(field.to_string())
      field.reset()
      pending = true
    } else if c == '\n' {
      row.push(field.to_string())
      field.reset()
      rows.push(row.copy())
      row.clear()
      pending = false
    } else if c == '\r' {
      // Part of a CRLF terminator; the following '\n' does the work.
      ()
    } else {
      field.write_char(c)
      pending = true
    }
    i += 1
  }
  // Flush a final record that had no trailing newline.
  if pending {
    row.push(field.to_string())
    rows.push(row.copy())
  }
  rows
}
