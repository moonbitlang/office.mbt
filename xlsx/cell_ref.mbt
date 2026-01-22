///|
pub fn cell_ref_to_rc(reference : StringView) -> (Int, Int) raise XlsxError {
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
pub fn cell_ref_from(row : Int, col : Int) -> String raise XlsxError {
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

///|
pub fn column_name_to_number(name : StringView) -> Int raise XlsxError {
  let text = name.to_string()
  if text == "" {
    raise XlsxError::InvalidCellRef(value=text)
  }
  let mut value = 0
  for c in text {
    if !c.is_ascii_alphabetic() {
      raise XlsxError::InvalidCellRef(value=text)
    }
    let upper = c.to_ascii_uppercase()
    value = value * 26 + (upper.to_int() - 'A'.to_int() + 1)
  }
  if value <= 0 {
    raise XlsxError::InvalidCellRef(value=text)
  }
  value
}

///|
pub fn column_number_to_name(col : Int) -> String raise XlsxError {
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}")
  }
  let sb = StringBuilder::new()
  let mut n = col
  while n > 0 {
    let rem = (n - 1) % 26
    let c = Int::unsafe_to_char('A'.to_int() + rem)
    sb.write_char(c)
    n = (n - 1) / 26
  }
  sb.to_string().rev()
}

///|
let cell_ref_max_rows = 1048576

///|
let cell_ref_max_cols = 16384

///|
pub fn split_cell_name(cell : StringView) -> (String, Int) raise XlsxError {
  let text = cell.to_string()
  if text == "" {
    raise XlsxError::InvalidCellRef(value=text)
  }
  let col_sb = StringBuilder::new()
  let row_sb = StringBuilder::new()
  let mut seen_digit = false
  for c in text {
    if !seen_digit && (c.is_ascii_alphabetic() || c == '$') {
      if c.is_ascii_alphabetic() {
        col_sb.write_char(c.to_ascii_uppercase())
      }
    } else if c.is_ascii_digit() {
      seen_digit = true
      row_sb.write_char(c)
    } else {
      raise XlsxError::InvalidCellRef(value=text)
    }
  }
  let col = col_sb.to_string()
  let row_text = row_sb.to_string()
  if col == "" || row_text == "" {
    raise XlsxError::InvalidCellRef(value=text)
  }
  let row = @strconv.parse_int(row_text, base=10) catch {
    _ => raise XlsxError::InvalidCellRef(value=text)
  }
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value=text)
  }
  (col, row)
}

///|
pub fn join_cell_name(col : StringView, row : Int) -> String raise XlsxError {
  let col_number = column_name_to_number(col)
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{row}")
  }
  let col_name = column_number_to_name(col_number)
  "\{col_name}\{row}"
}

///|
pub fn cell_name_to_coordinates(
  cell : StringView,
) -> (Int, Int) raise XlsxError {
  let (col_name, row) = split_cell_name(cell)
  if row > cell_ref_max_rows {
    raise XlsxError::InvalidCellRef(value=cell.to_string())
  }
  let col = column_name_to_number(col_name)
  if col > cell_ref_max_cols {
    raise XlsxError::InvalidCellRef(value=cell.to_string())
  }
  (col, row)
}

///|
pub fn coordinates_to_cell_name(
  col : Int,
  row : Int,
  abs? : Bool = false,
) -> String raise XlsxError {
  if col <= 0 || row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{row}")
  }
  if row > cell_ref_max_rows || col > cell_ref_max_cols {
    raise XlsxError::InvalidCellRef(value="\{col}:\{row}")
  }
  let col_name = column_number_to_name(col)
  let sign = if abs { "$" } else { "" }
  "\{sign}\{col_name}\{sign}\{row}"
}
