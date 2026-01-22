///|
struct RowEntry {
  row : Int
  values : Array[String]
}

///|
pub struct Rows {
  entries : Array[RowEntry]
  mut index : Int
}

///|
fn collect_row_entries(sheet : Worksheet) -> Array[RowEntry] {
  let cells = sheet.sorted_cells()
  let row_cells : Map[Int, Array[Cell]] = {}
  for cell in cells {
    let entries = match row_cells.get(cell.row) {
      Some(value) => value
      None => []
    }
    entries.push(cell)
    row_cells[cell.row] = entries
  }
  let row_keys : Array[Int] = []
  let row_present : Map[Int, Bool] = {}
  for row, _ in row_cells {
    row_keys.push(row)
    row_present[row] = true
  }
  for row, _ in sheet.row_dimensions {
    if !row_present.contains(row) {
      row_keys.push(row)
    }
  }
  row_keys.sort_by((a, b) => a - b)
  let entries : Array[RowEntry] = []
  for row in row_keys {
    let row_entries = match row_cells.get(row) {
      Some(value) => value
      None => []
    }
    if row_entries.length() == 0 {
      entries.push({ row, values: [] })
      continue
    }
    let mut max_col = 0
    for cell in row_entries {
      if cell.col > max_col {
        max_col = cell.col
      }
    }
    let values : Array[String] = Array::make(max_col, "")
    for cell in row_entries {
      values[cell.col - 1] = cell.value
    }
    entries.push({ row, values })
  }
  entries
}

///|
pub fn Rows::new(sheet : Worksheet) -> Rows {
  { entries: collect_row_entries(sheet), index: 0 }
}

///|
pub fn Rows::next(self : Rows) -> Bool {
  if self.index < self.entries.length() {
    self.index = self.index + 1
    true
  } else {
    false
  }
}

///|
pub fn Rows::columns(self : Rows) -> Array[String] {
  if self.index <= 0 || self.index > self.entries.length() {
    return []
  }
  self.entries[self.index - 1].values
}

///|
pub fn Rows::row_index(self : Rows) -> Int? {
  if self.index <= 0 || self.index > self.entries.length() {
    return None
  }
  Some(self.entries[self.index - 1].row)
}

///|
pub struct Cols {
  columns : Array[Array[String]]
  mut index : Int
}

///|
fn max_row_for_columns(sheet : Worksheet) -> Int {
  let mut max_row = sheet.max_row()
  for row, _ in sheet.row_dimensions {
    if row > max_row {
      max_row = row
    }
  }
  max_row
}

///|
fn collect_columns(sheet : Worksheet) -> Array[Array[String]] {
  let max_col = sheet.max_col()
  if max_col <= 0 {
    return []
  }
  let max_row = max_row_for_columns(sheet)
  let col_cells : Map[Int, Array[(Int, String)]] = {}
  for cell in sheet.cells {
    let entries = match col_cells.get(cell.col) {
      Some(value) => value
      None => []
    }
    entries.push((cell.row, cell.value))
    col_cells[cell.col] = entries
  }
  let columns : Array[Array[String]] = []
  for col in 1..<=max_col {
    let values : Array[String] = Array::make(max_row, "")
    match col_cells.get(col) {
      Some(entries) =>
        for entry in entries {
          let (row, value) = entry
          if row >= 1 && row <= max_row {
            values[row - 1] = value
          }
        }
      None => ()
    }
    columns.push(values)
  }
  columns
}

///|
fn collect_row_entries_with_options(
  sheet : Worksheet,
  styles : ArrayView[Style],
  options : Options,
) -> Array[RowEntry] raise XlsxError {
  let cells = sheet.sorted_cells()
  let row_cells : Map[Int, Array[Cell]] = {}
  for cell in cells {
    let entries = match row_cells.get(cell.row) {
      Some(value) => value
      None => []
    }
    entries.push(cell)
    row_cells[cell.row] = entries
  }
  let row_keys : Array[Int] = []
  let row_present : Map[Int, Bool] = {}
  for row, _ in row_cells {
    row_keys.push(row)
    row_present[row] = true
  }
  for row, _ in sheet.row_dimensions {
    if !row_present.contains(row) {
      row_keys.push(row)
    }
  }
  row_keys.sort_by((a, b) => a - b)
  let entries : Array[RowEntry] = []
  for row in row_keys {
    let row_entries = match row_cells.get(row) {
      Some(value) => value
      None => []
    }
    if row_entries.length() == 0 {
      entries.push({ row, values: [] })
      continue
    }
    let mut max_col = 0
    for cell in row_entries {
      if cell.col > max_col {
        max_col = cell.col
      }
    }
    let values : Array[String] = Array::make(max_col, "")
    for cell in row_entries {
      let formatted = format_cell_value_for_workbook(
        styles, cell, false, options,
      )
      values[cell.col - 1] = formatted
    }
    entries.push({ row, values })
  }
  entries
}

///|
fn collect_columns_with_options(
  sheet : Worksheet,
  styles : ArrayView[Style],
  options : Options,
) -> Array[Array[String]] raise XlsxError {
  let max_col = sheet.max_col()
  if max_col <= 0 {
    return []
  }
  let max_row = max_row_for_columns(sheet)
  let col_cells : Map[Int, Array[(Int, String)]] = {}
  for cell in sheet.cells {
    let formatted = format_cell_value_for_workbook(styles, cell, false, options)
    let entries = match col_cells.get(cell.col) {
      Some(value) => value
      None => []
    }
    entries.push((cell.row, formatted))
    col_cells[cell.col] = entries
  }
  let columns : Array[Array[String]] = []
  for col in 1..<=max_col {
    let values : Array[String] = Array::make(max_row, "")
    match col_cells.get(col) {
      Some(entries) =>
        for entry in entries {
          let (row, value) = entry
          if row >= 1 && row <= max_row {
            values[row - 1] = value
          }
        }
      None => ()
    }
    columns.push(values)
  }
  columns
}

///|
pub fn Cols::new(sheet : Worksheet) -> Cols {
  { columns: collect_columns(sheet), index: 0 }
}

///|
pub fn Cols::next(self : Cols) -> Bool {
  if self.index < self.columns.length() {
    self.index = self.index + 1
    true
  } else {
    false
  }
}

///|
pub fn Cols::rows(self : Cols) -> Array[String] {
  if self.index <= 0 || self.index > self.columns.length() {
    return []
  }
  self.columns[self.index - 1]
}

///|
pub fn Cols::col_index(self : Cols) -> Int? {
  if self.index <= 0 || self.index > self.columns.length() {
    return None
  }
  Some(self.index)
}

///|
pub fn Worksheet::rows(self : Worksheet) -> Rows {
  Rows::new(self)
}

///|
pub fn Worksheet::cols(self : Worksheet) -> Cols {
  Cols::new(self)
}

///|
pub fn Worksheet::get_rows(self : Worksheet) -> Array[Array[String]] {
  let rows = Rows::new(self)
  let results : Array[Array[String]] = []
  let mut max_with_values = 0
  while rows.next() {
    let values = rows.columns()
    let current = match rows.row_index() {
      Some(value) => value
      None => continue
    }
    if values.length() > 0 {
      let empty = current - max_with_values - 1
      if empty > 0 {
        for _ in 0..<empty {
          results.push([])
        }
      }
      results.push(values)
      max_with_values = current
    }
  }
  if max_with_values == 0 {
    []
  } else {
    results
  }
}

///|
pub fn Worksheet::get_cols(self : Worksheet) -> Array[Array[String]] {
  let cols = Cols::new(self)
  let results : Array[Array[String]] = []
  while cols.next() {
    results.push(cols.rows())
  }
  results
}

///|
pub fn Workbook::rows(
  self : Workbook,
  sheet_name : StringView,
) -> Rows raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  Rows::new(sheet)
}

///|
pub fn Workbook::cols(
  self : Workbook,
  sheet_name : StringView,
) -> Cols raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  Cols::new(sheet)
}

///|
pub fn Workbook::get_rows(
  self : Workbook,
  sheet_name : StringView,
  options? : Options,
) -> Array[Array[String]] raise XlsxError {
  let resolved_options = match options {
    Some(value) => value
    None => self.options
  }
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let entries = collect_row_entries_with_options(
    sheet,
    self.styles,
    resolved_options,
  )
  let results : Array[Array[String]] = []
  let mut max_with_values = 0
  for entry in entries {
    if entry.values.length() > 0 {
      let empty = entry.row - max_with_values - 1
      if empty > 0 {
        for _ in 0..<empty {
          results.push([])
        }
      }
      results.push(entry.values)
      max_with_values = entry.row
    }
  }
  if max_with_values == 0 {
    []
  } else {
    results
  }
}

///|
pub fn Workbook::get_cols(
  self : Workbook,
  sheet_name : StringView,
  options? : Options,
) -> Array[Array[String]] raise XlsxError {
  let resolved_options = match options {
    Some(value) => value
    None => self.options
  }
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  collect_columns_with_options(sheet, self.styles, resolved_options)
}
