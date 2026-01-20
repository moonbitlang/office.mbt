///|
pub struct Cell {
  reference : String
  row : Int
  col : Int
  value : String
  formula : String?
  style_id : Int
}

///|
pub struct Image {
  reference : String
  data : Bytes
  extension : String
  content_type : String
}

///|
pub struct Chart {
  reference : String
  xml : String
}

///|
pub struct Worksheet {
  name : String
  cells : Array[Cell]
  images : Array[Image]
  charts : Array[Chart]
  data_validations : Array[String]
  conditional_formats : Array[String]
}

///|
pub fn Worksheet::new(name : String) -> Worksheet {
  {
    name,
    cells: [],
    images: [],
    charts: [],
    data_validations: [],
    conditional_formats: [],
  }
}

///|
pub fn Worksheet::name(self : Worksheet) -> String {
  self.name
}

///|
pub fn Worksheet::cells(self : Worksheet) -> ArrayView[Cell] {
  self.cells[:]
}

///|
pub fn Worksheet::images(self : Worksheet) -> ArrayView[Image] {
  self.images[:]
}

///|
pub fn Worksheet::charts(self : Worksheet) -> ArrayView[Chart] {
  self.charts[:]
}

///|
pub fn Worksheet::data_validations(self : Worksheet) -> ArrayView[String] {
  self.data_validations[:]
}

///|
pub fn Worksheet::conditional_formats(self : Worksheet) -> ArrayView[String] {
  self.conditional_formats[:]
}

///|
fn Worksheet::sorted_cells(self : Worksheet) -> Array[Cell] {
  let sorted : Array[Cell] = []
  for cell in self.cells {
    sorted.push(cell)
  }
  sort_cells(sorted)
  sorted
}

///|
pub fn Worksheet::set_cell(
  self : Worksheet,
  reference : String,
  value : String,
) -> Unit raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference: canonical,
        row,
        col,
        value,
        formula: None,
        style_id: cell.style_id,
      }
      return
    }
  }
  self.cells.push({
    reference: canonical,
    row,
    col,
    value,
    formula: None,
    style_id: 0,
  })
}

///|
pub fn Worksheet::get_cell(
  self : Worksheet,
  reference : StringView,
) -> String? raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  for cell in self.cells {
    if cell.row == row && cell.col == col {
      return Some(cell.value)
    }
  }
  None
}

///|
pub fn Worksheet::set_cell_formula(
  self : Worksheet,
  reference : String,
  formula : String,
  value? : String = "",
) -> Unit raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference: canonical,
        row,
        col,
        value,
        formula: Some(formula),
        style_id: cell.style_id,
      }
      return
    }
  }
  self.cells.push({
    reference: canonical,
    row,
    col,
    value,
    formula: Some(formula),
    style_id: 0,
  })
}

///|
pub fn Worksheet::get_cell_formula(
  self : Worksheet,
  reference : StringView,
) -> String? raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  for cell in self.cells {
    if cell.row == row && cell.col == col {
      return cell.formula
    }
  }
  None
}

///|
pub fn Worksheet::set_cell_style(
  self : Worksheet,
  reference : String,
  style_id : Int,
) -> Unit raise XlsxError {
  if style_id < 0 {
    raise XlsxError::InvalidStyleId(index=style_id)
  }
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference: canonical,
        row,
        col,
        value: cell.value,
        formula: cell.formula,
        style_id,
      }
      return
    }
  }
  self.cells.push({
    reference: canonical,
    row,
    col,
    value: "",
    formula: None,
    style_id,
  })
}

///|
pub fn Worksheet::get_cell_style(
  self : Worksheet,
  reference : StringView,
) -> Int? raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  for cell in self.cells {
    if cell.row == row && cell.col == col {
      return Some(cell.style_id)
    }
  }
  None
}

///|
pub fn Worksheet::set_cell_style_rc(
  self : Worksheet,
  row : Int,
  col : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  if style_id < 0 {
    raise XlsxError::InvalidStyleId(index=style_id)
  }
  let reference = cell_ref_from(row, col)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference,
        row,
        col,
        value: cell.value,
        formula: cell.formula,
        style_id,
      }
      return
    }
  }
  self.cells.push({ reference, row, col, value: "", formula: None, style_id })
}

///|
pub fn Worksheet::get_cell_style_rc(
  self : Worksheet,
  row : Int,
  col : Int,
) -> Int? raise XlsxError {
  if row <= 0 || col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{row}")
  }
  for cell in self.cells {
    if cell.row == row && cell.col == col {
      return Some(cell.style_id)
    }
  }
  None
}

///|
fn normalize_extension(extension : StringView) -> String raise XlsxError {
  let value = extension.to_string()
  let trimmed = if value.has_prefix(".") {
    if value.length() <= 1 {
      raise XlsxError::UnsupportedFeature(msg="image extension missing")
    }
    let view = value[1:] catch {
        _ => raise XlsxError::UnsupportedFeature(msg="invalid image extension")
      }
    view.to_string()
  } else {
    value
  }
  if trimmed == "" {
    raise XlsxError::UnsupportedFeature(msg="image extension missing")
  }
  trimmed
}

///|
pub fn Worksheet::add_image(
  self : Worksheet,
  reference : String,
  data : Bytes,
  extension : String,
  content_type : String,
) -> Unit raise XlsxError {
  let (_row, _col) = cell_ref_to_rc(reference)
  let ext = normalize_extension(extension)
  self.images.push({ reference, data, extension: ext, content_type })
}

///|
pub fn Worksheet::add_chart(
  self : Worksheet,
  reference : String,
  xml : String,
) -> Unit raise XlsxError {
  let (_row, _col) = cell_ref_to_rc(reference)
  self.charts.push({ reference, xml })
}

///|
pub fn Worksheet::add_data_validation_xml(
  self : Worksheet,
  xml : String,
) -> Unit {
  self.data_validations.push(xml)
}

///|
pub fn Worksheet::add_data_validation_list(
  self : Worksheet,
  range_ref : String,
  values : ArrayView[String],
  allow_blank? : Bool = true,
) -> Unit raise XlsxError {
  if values.length() == 0 {
    raise XlsxError::UnsupportedFeature(msg="empty validation list")
  }
  let sb = StringBuilder::new()
  for i, value in values {
    if i > 0 {
      sb.write_char(',')
    }
    sb.write_view(value)
  }
  let joined = sb.to_string()
  let allow = if allow_blank { "1" } else { "0" }
  let formula = "\"\{joined}\""
  let xml = "<dataValidation type=\"list\" allowBlank=\"\{allow}\" sqref=\"\{escape_xml_attr(range_ref)}\"><formula1>\{escape_xml_text(formula)}</formula1></dataValidation>"
  self.data_validations.push(xml)
}

///|
pub fn Worksheet::add_conditional_format_xml(
  self : Worksheet,
  xml : String,
) -> Unit {
  self.conditional_formats.push(xml)
}

///|
pub fn Worksheet::set_cell_rc(
  self : Worksheet,
  row : Int,
  col : Int,
  value : String,
) -> Unit raise XlsxError {
  let reference = cell_ref_from(row, col)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference,
        row,
        col,
        value,
        formula: None,
        style_id: cell.style_id,
      }
      return
    }
  }
  self.cells.push({ reference, row, col, value, formula: None, style_id: 0 })
}

///|
pub fn Worksheet::set_cell_formula_rc(
  self : Worksheet,
  row : Int,
  col : Int,
  formula : String,
  value? : String = "",
) -> Unit raise XlsxError {
  let reference = cell_ref_from(row, col)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference,
        row,
        col,
        value,
        formula: Some(formula),
        style_id: cell.style_id,
      }
      return
    }
  }
  self.cells.push({
    reference,
    row,
    col,
    value,
    formula: Some(formula),
    style_id: 0,
  })
}

///|
pub fn Worksheet::get_cell_rc(
  self : Worksheet,
  row : Int,
  col : Int,
) -> String? raise XlsxError {
  if row <= 0 || col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{row}")
  }
  for cell in self.cells {
    if cell.row == row && cell.col == col {
      return Some(cell.value)
    }
  }
  None
}

///|
pub fn Worksheet::max_row(self : Worksheet) -> Int {
  let mut max_row = 0
  for cell in self.cells {
    if cell.row > max_row {
      max_row = cell.row
    }
  }
  max_row
}

///|
pub fn Worksheet::max_col(self : Worksheet) -> Int {
  let mut max_col = 0
  for cell in self.cells {
    if cell.col > max_col {
      max_col = cell.col
    }
  }
  max_col
}

///|
pub fn Worksheet::set_row(
  self : Worksheet,
  row : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  for i, value in values {
    self.set_cell_rc(row, i + 1, value)
  }
}

///|
pub fn Worksheet::get_row(
  self : Worksheet,
  row : Int,
) -> Array[String] raise XlsxError {
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  let mut max_col = 0
  for cell in self.cells {
    if cell.row == row && cell.col > max_col {
      max_col = cell.col
    }
  }
  if max_col == 0 {
    return []
  }
  let values : Array[String] = Array::make(max_col, "")
  for cell in self.cells {
    if cell.row == row {
      values[cell.col - 1] = cell.value
    }
  }
  values
}

///|
pub fn Worksheet::set_col(
  self : Worksheet,
  col : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  for i, value in values {
    self.set_cell_rc(i + 1, col, value)
  }
}

///|
pub fn Worksheet::get_col(
  self : Worksheet,
  col : Int,
) -> Array[String] raise XlsxError {
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  let mut max_row = 0
  for cell in self.cells {
    if cell.col == col && cell.row > max_row {
      max_row = cell.row
    }
  }
  if max_row == 0 {
    return []
  }
  let values : Array[String] = Array::make(max_row, "")
  for cell in self.cells {
    if cell.col == col {
      values[cell.row - 1] = cell.value
    }
  }
  values
}

///|
fn compare_cell(a : Cell, b : Cell) -> Int {
  if a.row != b.row {
    a.row - b.row
  } else {
    a.col - b.col
  }
}

///|
fn sort_cells(cells : Array[Cell]) -> Unit {
  let mut i = 1
  while i < cells.length() {
    let key = cells[i]
    let mut j = i - 1
    loop true {
      false => ()
      true => {
        if j < 0 || compare_cell(cells[j], key) <= 0 {
          continue false
        }
        cells[j + 1] = cells[j]
        j = j - 1
        continue true
      }
    }
    cells[j + 1] = key
    i = i + 1
  }
}
