///|
pub fn Workbook::get_active_sheet_index(self : Workbook) -> Int {
  self.active_sheet_index()
}

///|
pub fn Workbook::get_sheet_index(
  self : Workbook,
  name : StringView,
) -> Int raise XlsxError {
  self.sheet_index(name)
}

///|
pub fn Workbook::get_sheet_name(self : Workbook, index : Int) -> String? {
  self.sheet_name(index)
}

///|
pub fn Workbook::get_sheet_visible(
  self : Workbook,
  name : StringView,
) -> Bool raise XlsxError {
  self.sheet_visible(name)
}

///|
pub fn Workbook::charset_transcoder(
  self : Workbook,
  transcoder : (String, Bytes) -> String raise XlsxError,
) -> Workbook {
  self.charset_transcoder = Some(transcoder)
  self
}

///|
pub fn Workbook::get_row_outline_level(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Int raise XlsxError {
  self.row_outline_level(sheet_name, row)
}

///|
pub fn Workbook::get_col_outline_level(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Int raise XlsxError {
  self.col_outline_level(sheet_name, col)
}

///|
pub fn Workbook::get_row_visible(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Bool raise XlsxError {
  self.row_visible(sheet_name, row)
}

///|
pub fn Workbook::get_col_visible(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Bool raise XlsxError {
  self.col_visible(sheet_name, col)
}

///|
pub fn Workbook::get_defined_name(self : Workbook) -> Array[DefinedName] {
  self.get_defined_names()
}

///|
pub fn Workbook::new_sheet(
  self : Workbook,
  name : String,
) -> Worksheet raise XlsxError {
  self.add_sheet(name)
}

///|
pub fn Workbook::auto_filter(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
  options : ArrayView[AutoFilterOption],
) -> Unit raise XlsxError {
  self.set_auto_filter(sheet_name, range_ref, options)
}

///|
pub fn Workbook::set_sheet_row(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let (row, col) = cell_ref_to_rc(cell)
  let mut col_index = col
  for value in values {
    let reference = cell_ref_from(row, col_index)
    sheet.set_cell(reference, value)
    col_index = col_index + 1
  }
}

///|
pub fn Workbook::set_sheet_col(
  self : Workbook,
  sheet_name : StringView,
  cell : StringView,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let (row, col) = cell_ref_to_rc(cell)
  let mut row_index = row
  for value in values {
    let reference = cell_ref_from(row_index, col)
    sheet.set_cell(reference, value)
    row_index = row_index + 1
  }
}

///|
pub fn Workbook::set_sheet_background_from_bytes(
  self : Workbook,
  sheet_name : StringView,
  extension : String,
  data : Bytes,
) -> Unit raise XlsxError {
  self.set_sheet_background(sheet_name, data, extension)
}

///|
fn parse_column_range(columns : StringView) -> (Int, Int) raise XlsxError {
  let text = columns.to_string()
  let parts : Array[StringView] = []
  for part in text.split(":") {
    parts.push(part)
  }
  if parts.length() == 0 || parts.length() > 2 {
    raise XlsxError::InvalidCellRef(value=text)
  }
  let start = column_name_to_number(parts[0])
  let end = if parts.length() == 2 {
    column_name_to_number(parts[1])
  } else {
    start
  }
  if end < start {
    raise XlsxError::InvalidCellRef(value=text)
  }
  (start, end)
}

///|
pub fn Workbook::set_col_width_range(
  self : Workbook,
  sheet_name : StringView,
  columns : StringView,
  width : Double,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let (start, end) = parse_column_range(columns)
  for col in start..<=end {
    sheet.set_col_width(col, width)
  }
}

///|
pub fn Workbook::set_col_visible_range(
  self : Workbook,
  sheet_name : StringView,
  columns : StringView,
  visible : Bool,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let (start, end) = parse_column_range(columns)
  for col in start..<=end {
    sheet.set_col_visible(col, visible)
  }
}

///|
pub fn Workbook::set_col_outline_level_range(
  self : Workbook,
  sheet_name : StringView,
  columns : StringView,
  level : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let (start, end) = parse_column_range(columns)
  for col in start..<=end {
    sheet.set_col_outline_level(col, level)
  }
}

///|
pub fn Workbook::set_col_style_range(
  self : Workbook,
  sheet_name : StringView,
  columns : StringView,
  style_id : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let (start, end) = parse_column_range(columns)
  for col in start..<=end {
    sheet.set_col_style(col, style_id)
  }
}

///|
pub fn Workbook::update_linked_value(self : Workbook) -> Unit raise XlsxError {
  self.calc_props = CalcPropsOptions::new()
  for sheet in self.sheets {
    sheet.ensure_stream_idle()
    for i, cell in sheet.cells {
      match cell.formula {
        Some(_) =>
          if cell.value != "" {
            sheet.cells[i] = {
              reference: cell.reference,
              row: cell.row,
              col: cell.col,
              value: "",
              value_type: cell.value_type,
              rich_text: cell.rich_text,
              formula: cell.formula,
              style_id: cell.style_id,
            }
          }
        None => ()
      }
    }
  }
}

///|
pub fn Workbook::add_vbaproject(
  self : Workbook,
  data : Bytes,
) -> Unit raise XlsxError {
  self.add_vba_project(data)
}
