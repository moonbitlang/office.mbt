///|
priv struct RowValues {
  row : Int
  values : Array[String]
}

///|
struct RowCells {
  row : Int
  cells : Array[Cell]
  max_col : Int
}

///|
pub struct RowOpts {
  height : Double
  hidden : Bool
  style_id : Int
  outline_level : Int
} derive(Eq, Show)

///|
pub fn RowOpts::with_values(
  height? : Double = 0.0,
  hidden? : Bool = false,
  style_id? : Int = 0,
  outline_level? : Int = 0,
) -> RowOpts {
  { height, hidden, style_id, outline_level }
}

///|
pub struct Rows {
  sheet : Worksheet
  entries : Array[RowCells]
  mut index : Int
  styles : Array[Style]?
  options : Options
}

///|
fn collect_row_cells(sheet : Worksheet) -> Array[RowCells] {
  let cells = sheet.sorted_cells()
  let row_cells : Map[Int, Array[Cell]] = {}
  for cell in cells {
    let entries = row_cells.get(cell.row).unwrap_or([])
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
  let entries : Array[RowCells] = []
  for row in row_keys {
    let row_entries = row_cells.get(row).unwrap_or([])
    if row_entries.is_empty() {
      entries.push({ row, cells: [], max_col: 0 })
      continue
    }
    let mut max_col = 0
    for cell in row_entries {
      if cell.col > max_col {
        max_col = cell.col
      }
    }
    entries.push({ row, cells: row_entries, max_col })
  }
  entries
}

///|
fn Rows::new(sheet : Worksheet) -> Rows {
  Rows::new_with_options(sheet, None, Options::new())
}

///|
fn Rows::new_with_options(
  sheet : Worksheet,
  styles : Array[Style]?,
  options : Options,
) -> Rows {
  { sheet, entries: collect_row_cells(sheet), index: 0, styles, options }
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
pub fn Rows::columns(
  self : Rows,
  options? : Options,
) -> Array[String] raise XlsxError {
  if self.index <= 0 || self.index > self.entries.length() {
    return []
  }
  let entry = self.entries[self.index - 1]
  if entry.max_col == 0 {
    return []
  }
  let resolved_options = match options {
    Some(value) => value
    None => self.options
  }
  let values : Array[String] = Array::make(entry.max_col, "")
  match self.styles {
    Some(styles) =>
      for cell in entry.cells {
        let formatted = format_cell_value_for_workbook(
          styles, cell, false, resolved_options,
        )
        values[cell.col - 1] = formatted
      }
    None =>
      for cell in entry.cells {
        values[cell.col - 1] = cell.value
      }
  }
  values
}

///|
pub fn Rows::row_index(self : Rows) -> Int? {
  if self.index <= 0 || self.index > self.entries.length() {
    return None
  }
  Some(self.entries[self.index - 1].row)
}

///|
fn default_row_height(sheet : Worksheet) -> Double {
  let props = sheet.sheet_props()
  match props.default_row_height {
    Some(value) => value
    None => 15.0
  }
}

///|
fn row_opts_for_row(sheet : Worksheet, row : Int) -> RowOpts {
  let dim = sheet.row_dimension_value(row)
  let height = match dim.height {
    Some(value) => value
    None => default_row_height(sheet)
  }
  let style_id = match dim.style_id {
    Some(value) => value
    None => 0
  }
  { height, hidden: dim.hidden, style_id, outline_level: dim.outline_level }
}

///|
pub fn Rows::get_row_opts(self : Rows) -> RowOpts {
  match self.row_index() {
    Some(row) => row_opts_for_row(self.sheet, row)
    None => RowOpts::with_values(height=default_row_height(self.sheet))
  }
}

///|
pub fn Rows::error(_self : Rows) -> XlsxError? {
  None
}

///|
pub fn Rows::close(_self : Rows) -> Unit {
  ()
}

///|
pub struct Cols {
  sheet : Worksheet
  columns : Array[Array[Cell]]
  max_row : Int
  mut index : Int
  styles : Array[Style]?
  options : Options
  mut err : XlsxError?
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
fn collect_column_cells(sheet : Worksheet, max_col : Int) -> Array[Array[Cell]] {
  let columns : Array[Array[Cell]] = []
  for _ in 0..<max_col {
    columns.push([])
  }
  for cell in sheet.cells {
    if cell.col >= 1 && cell.col <= max_col {
      columns[cell.col - 1].push(cell)
    }
  }
  columns
}

///|
fn collect_row_entries_with_options(
  sheet : Worksheet,
  styles : ArrayView[Style],
  options : Options,
) -> Array[RowValues] raise XlsxError {
  let cells = sheet.sorted_cells()
  let row_cells : Map[Int, Array[Cell]] = {}
  for cell in cells {
    let entries = row_cells.get(cell.row).unwrap_or([])
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
  let entries : Array[RowValues] = []
  for row in row_keys {
    let row_entries = row_cells.get(row).unwrap_or([])
    if row_entries.is_empty() {
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
    let entries = col_cells.get(cell.col).unwrap_or([])
    entries.push((cell.row, formatted))
    col_cells[cell.col] = entries
  }
  let columns : Array[Array[String]] = []
  for col in 1..<=max_col {
    let values : Array[String] = Array::make(max_row, "")
    for entry in col_cells.get(col).unwrap_or([]) {
      let (row, value) = entry
      if row >= 1 && row <= max_row {
        values[row - 1] = value
      }
    }
    columns.push(values)
  }
  columns
}

///|
fn Cols::new(sheet : Worksheet) -> Cols {
  Cols::new_with_options(sheet, None, Options::new())
}

///|
fn Cols::new_with_options(
  sheet : Worksheet,
  styles : Array[Style]?,
  options : Options,
) -> Cols {
  let max_col = sheet.max_col()
  let columns = if max_col <= 0 {
    []
  } else {
    collect_column_cells(sheet, max_col)
  }
  let max_row = if max_col <= 0 { 0 } else { max_row_for_columns(sheet) }
  { sheet, columns, max_row, index: 0, styles, options, err: None }
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
pub fn Cols::rows(self : Cols, options? : Options) -> Array[String] {
  if self.index <= 0 || self.index > self.columns.length() {
    return []
  }
  let resolved_options = match options {
    Some(value) => value
    None => self.options
  }
  if self.max_row <= 0 {
    return []
  }
  let entry = self.columns[self.index - 1]
  let values : Array[String] = Array::make(self.max_row, "")
  match self.styles {
    Some(styles) =>
      for cell in entry {
        if cell.row < 1 || cell.row > self.max_row {
          continue
        }
        let formatted = format_cell_value_for_workbook(
          styles, cell, false, resolved_options,
        ) catch {
          err => {
            if self.err is None {
              self.err = Some(err)
            }
            ""
          }
        }
        if self.err is Some(_) {
          return values
        }
        values[cell.row - 1] = formatted
      }
    None =>
      for cell in entry {
        if cell.row < 1 || cell.row > self.max_row {
          continue
        }
        values[cell.row - 1] = cell.value
      }
  }
  values
}

///|
pub fn Cols::col_index(self : Cols) -> Int? {
  if self.index <= 0 || self.index > self.columns.length() {
    return None
  }
  Some(self.index)
}

///|
pub fn Cols::error(self : Cols) -> XlsxError? {
  self.err
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
  let entries = collect_row_cells(self)
  let results : Array[Array[String]] = []
  let mut max_with_values = 0
  for entry in entries {
    let current = entry.row
    let values = if entry.max_col == 0 {
      []
    } else {
      let row_values : Array[String] = Array::make(entry.max_col, "")
      for cell in entry.cells {
        row_values[cell.col - 1] = cell.value
      }
      row_values
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
  check_sheet_name(sheet_name)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise SheetNotFound(name=sheet_name.to_string())
  }
  Rows::new_with_options(sheet, Some(self.styles), self.options)
}

///|
pub fn Workbook::cols(
  self : Workbook,
  sheet_name : StringView,
) -> Cols raise XlsxError {
  check_sheet_name(sheet_name)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise SheetNotFound(name=sheet_name.to_string())
  }
  Cols::new_with_options(sheet, Some(self.styles), self.options)
}

///|
pub fn Workbook::get_rows(
  self : Workbook,
  sheet_name : StringView,
  options? : Options,
) -> Array[Array[String]] raise XlsxError {
  check_sheet_name(sheet_name)
  let resolved_options = match options {
    Some(value) => value
    None => self.options
  }
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise SheetNotFound(name=sheet_name.to_string())
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
  check_sheet_name(sheet_name)
  let resolved_options = match options {
    Some(value) => value
    None => self.options
  }
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise SheetNotFound(name=sheet_name.to_string())
  }
  collect_columns_with_options(sheet, self.styles, resolved_options)
}
