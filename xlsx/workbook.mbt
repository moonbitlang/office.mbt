///|
pub struct Workbook {
  sheets : Array[Worksheet]
}

///|
pub fn Workbook::new() -> Workbook {
  { sheets: [] }
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
