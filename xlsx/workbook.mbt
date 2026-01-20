///|
pub struct Workbook {
  sheets : Array[Worksheet]
  styles : Array[Style]
}

///|
pub fn Workbook::new() -> Workbook {
  { sheets: [], styles: [Style::new()] }
}

///|
pub fn Workbook::add_sheet(self : Workbook, name : String) -> Worksheet {
  let sheet = Worksheet::new(name)
  self.sheets.push(sheet)
  sheet
}

///|
pub fn Workbook::sheet(self : Workbook, name : StringView) -> Worksheet? {
  let needle = name.to_string()
  for sheet in self.sheets {
    if sheet.name() == needle {
      return Some(sheet)
    }
  }
  None
}

///|
pub fn Workbook::sheets(self : Workbook) -> ArrayView[Worksheet] {
  self.sheets[:]
}

///|
pub fn Workbook::styles(self : Workbook) -> ArrayView[Style] {
  self.styles[:]
}

///|
pub fn Workbook::add_style(self : Workbook, style : Style) -> Int {
  self.styles.push(style)
  self.styles.length() - 1
}

///|
fn Workbook::check_style_id(
  self : Workbook,
  style_id : Int,
) -> Unit raise XlsxError {
  if style_id < 0 || style_id >= self.styles.length() {
    raise XlsxError::InvalidStyleId(index=style_id)
  }
}

///|
pub fn Workbook::set_cell(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell(reference, value)
}

///|
pub fn Workbook::get_cell(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> String? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell(reference)
}

///|
pub fn Workbook::set_cell_formula(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  formula : String,
  value? : String = "",
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_formula(reference, formula, value~)
}

///|
pub fn Workbook::get_cell_formula(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> String? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_formula(reference)
}

///|
pub fn Workbook::set_cell_style(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  style_id : Int,
) -> Unit raise XlsxError {
  self.check_style_id(style_id)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_style(reference, style_id)
}

///|
pub fn Workbook::get_cell_style(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> Int? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_style(reference)
}

///|
pub fn Workbook::add_image(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  data : Bytes,
  extension : String,
  content_type : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_image(reference, data, extension, content_type)
}

///|
pub fn Workbook::add_chart(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_chart(reference, xml)
}

///|
pub fn Workbook::add_data_validation_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_data_validation_xml(xml)
}

///|
pub fn Workbook::add_data_validation_list(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
  values : ArrayView[String],
  allow_blank? : Bool = true,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_data_validation_list(range_ref, values, allow_blank~)
}

///|
pub fn Workbook::add_conditional_format_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_conditional_format_xml(xml)
}

///|
pub fn Workbook::merge_cells(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.merge_cells(range_ref)
}

///|
pub fn Workbook::unmerge_cells(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.unmerge_cells(range_ref)
}

///|
pub fn Workbook::add_table(
  self : Workbook,
  sheet_name : StringView,
  range_ref : String,
  name : String,
  columns : ArrayView[String],
  display_name? : String = "",
  style_name? : String = "TableStyleMedium9",
) -> Table raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_table(range_ref, name, columns, display_name~, style_name~)
}

///|
pub fn Workbook::set_cell_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  value : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_rc(row, col, value)
}

///|
pub fn Workbook::get_cell_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
) -> String? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_rc(row, col)
}

///|
pub fn Workbook::set_cell_style_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.check_style_id(style_id)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_style_rc(row, col, style_id)
}

///|
pub fn Workbook::get_cell_style_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
) -> Int? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_style_rc(row, col)
}

///|
pub fn Workbook::set_cell_formula_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  formula : String,
  value? : String = "",
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_formula_rc(row, col, formula, value~)
}

///|
pub fn Workbook::set_row(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_row(row, values)
}

///|
pub fn Workbook::get_row(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Array[String] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_row(row)
}

///|
pub fn Workbook::set_col(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_col(col, values)
}

///|
pub fn Workbook::get_col(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Array[String] raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_col(col)
}
