///|
fn parse_cell_ref(reference : StringView) -> (Int, Int) raise XlsxError {
  let mut col = 0
  let row_sb = StringBuilder::new()
  let mut seen_digit = false
  for c in reference {
    if !seen_digit && c.is_ascii_alphabetic() {
      let upper = c.to_ascii_uppercase()
      col = col * 26 + (upper.to_int() - 'A'.to_int() + 1)
    } else if c.is_ascii_digit() {
      seen_digit = true
      row_sb.write_char(c)
    } else {
      raise XlsxError::InvalidCellRef(value=reference.to_string())
    }
  }
  let row_text = row_sb.to_string()
  if col == 0 || row_text == "" {
    raise XlsxError::InvalidCellRef(value=reference.to_string())
  }
  let row = @strconv.parse_int(row_text, base=10) catch {
    _ => raise XlsxError::InvalidCellRef(value=reference.to_string())
  }
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value=reference.to_string())
  }
  (row, col)
}

///|
fn cell_ref_from(row : Int, col : Int) -> String raise XlsxError {
  if row <= 0 || col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{row}")
  }
  let sb = StringBuilder::new()
  let mut n = col
  while n > 0 {
    let rem = (n - 1) % 26
    let c = Int::unsafe_to_char('A'.to_int() + rem)
    sb.write_char(c)
    n = (n - 1) / 26
  }
  let col_rev = sb.to_string()
  let col_name = col_rev.rev()
  "\{col_name}\{row}"
}
