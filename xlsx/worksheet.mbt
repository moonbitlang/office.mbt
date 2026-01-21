///|
pub struct Cell {
  reference : String
  row : Int
  col : Int
  value : String
  value_type : CellValueType
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
pub enum SheetState {
  Visible
  Hidden
  VeryHidden
} derive(Eq, Show)

///|
pub struct RowDimension {
  height : Double?
  hidden : Bool
  outline_level : Int
  style_id : Int?
}

///|
pub struct ColDimension {
  width : Double?
  hidden : Bool
  outline_level : Int
  style_id : Int?
}

///|
pub struct Worksheet {
  mut name : String
  cells : Array[Cell]
  merged_cells : Array[String]
  tables : Array[Table]
  sparkline_groups : Array[SparklineGroup]
  pivot_tables : Array[PivotTable]
  images : Array[Image]
  charts : Array[Chart]
  data_validations : Array[String]
  conditional_formats : Array[String]
  row_dimensions : Map[Int, RowDimension]
  col_dimensions : Map[Int, ColDimension]
  mut state : SheetState
  mut stream_state : StreamState
  mut vml_drawing_xml : String?
  mut vml_drawing_hf_xml : String?
}

///|
pub fn Worksheet::new(name : String) -> Worksheet {
  {
    name,
    cells: [],
    merged_cells: [],
    tables: [],
    sparkline_groups: [],
    pivot_tables: [],
    images: [],
    charts: [],
    data_validations: [],
    conditional_formats: [],
    row_dimensions: {},
    col_dimensions: {},
    state: SheetState::Visible,
    stream_state: StreamState::Idle,
    vml_drawing_xml: None,
    vml_drawing_hf_xml: None,
  }
}

///|
pub fn Worksheet::name(self : Worksheet) -> String {
  self.name
}

///|
pub fn Worksheet::state(self : Worksheet) -> SheetState {
  self.state
}

///|
pub fn Worksheet::set_state(self : Worksheet, state : SheetState) -> Unit {
  self.state = state
}

///|
pub fn Worksheet::cells(self : Worksheet) -> ArrayView[Cell] {
  self.cells[:]
}

///|
pub fn Worksheet::merged_cells(self : Worksheet) -> ArrayView[String] {
  self.merged_cells[:]
}

///|
pub fn Worksheet::tables(self : Worksheet) -> ArrayView[Table] {
  self.tables[:]
}

///|
pub fn Worksheet::sparkline_groups(
  self : Worksheet,
) -> ArrayView[SparklineGroup] {
  self.sparkline_groups[:]
}

///|
pub fn Worksheet::pivot_tables(self : Worksheet) -> ArrayView[PivotTable] {
  self.pivot_tables[:]
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
pub fn Worksheet::vml_drawing_xml(self : Worksheet) -> String? {
  self.vml_drawing_xml
}

///|
pub fn Worksheet::vml_drawing_hf_xml(self : Worksheet) -> String? {
  self.vml_drawing_hf_xml
}

///|
fn Worksheet::ensure_stream_idle(self : Worksheet) -> Unit raise XlsxError {
  if self.stream_state != StreamState::Idle {
    raise XlsxError::StreamModeConflict(
      msg="worksheet is in stream writer mode",
    )
  }
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
fn parse_range_ref(
  range_ref : StringView,
) -> (Int, Int, Int, Int) raise XlsxError {
  let parts : Array[String] = []
  for part in range_ref.to_string().split(":") {
    parts.push(part.to_string())
  }
  if parts.length() != 2 {
    raise XlsxError::InvalidCellRef(value=range_ref.to_string())
  }
  let (row1, col1) = cell_ref_to_rc(parts[0])
  let (row2, col2) = cell_ref_to_rc(parts[1])
  let min_row = if row1 < row2 { row1 } else { row2 }
  let max_row = if row1 > row2 { row1 } else { row2 }
  let min_col = if col1 < col2 { col1 } else { col2 }
  let max_col = if col1 > col2 { col1 } else { col2 }
  (min_row, min_col, max_row, max_col)
}

///|
fn normalize_range_ref(range_ref : StringView) -> String raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
  let start_ref = cell_ref_from(min_row, min_col)
  let end_ref = cell_ref_from(max_row, max_col)
  "\{start_ref}:\{end_ref}"
}

///|
pub fn Worksheet::set_cell(
  self : Worksheet,
  reference : String,
  value : String,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference: canonical,
        row,
        col,
        value,
        value_type: CellValueType::String,
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
    value_type: CellValueType::String,
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
pub fn Worksheet::set_cell_value(
  self : Worksheet,
  reference : String,
  value : CellValue,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  let value_type = cell_value_type(value)
  let raw_value = cell_value_raw_string(value)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference: canonical,
        row,
        col,
        value: raw_value,
        value_type,
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
    value: raw_value,
    value_type,
    formula: None,
    style_id: 0,
  })
}

///|
pub fn Worksheet::get_cell_value_raw(
  self : Worksheet,
  reference : StringView,
) -> CellValue? raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  for cell in self.cells {
    if cell.row == row && cell.col == col {
      return Some(cell_value_from_raw(cell.value_type, cell.value))
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
  self.ensure_stream_idle()
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference: canonical,
        row,
        col,
        value,
        value_type: CellValueType::String,
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
    value_type: CellValueType::String,
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
  self.ensure_stream_idle()
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
        value_type: cell.value_type,
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
    value_type: CellValueType::String,
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
  self.ensure_stream_idle()
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
        value_type: cell.value_type,
        formula: cell.formula,
        style_id,
      }
      return
    }
  }
  self.cells.push({
    reference,
    row,
    col,
    value: "",
    value_type: CellValueType::String,
    formula: None,
    style_id,
  })
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
pub fn Worksheet::merge_cells(
  self : Worksheet,
  range_ref : String,
) -> Unit raise XlsxError {
  let normalized = normalize_range_ref(range_ref)
  for existing in self.merged_cells {
    if existing == normalized {
      return
    }
  }
  self.merged_cells.push(normalized)
}

///|
pub fn Worksheet::unmerge_cells(
  self : Worksheet,
  range_ref : String,
) -> Unit raise XlsxError {
  let normalized = normalize_range_ref(range_ref)
  for i, existing in self.merged_cells {
    if existing == normalized {
      ignore(self.merged_cells.remove(i))
      return
    }
  }
}

///|
pub fn Worksheet::add_table(
  self : Worksheet,
  range_ref : String,
  name : String,
  columns : ArrayView[String],
  display_name? : String = "",
  style_name? : String = "TableStyleMedium9",
) -> Table raise XlsxError {
  let table = Table::new(name, range_ref, columns, display_name~, style_name~)
  self.tables.push(table)
  table
}

///|
pub fn Worksheet::add_sparkline(
  self : Worksheet,
  location : String,
  range_ref : String,
  sparkline_type? : SparklineType = SparklineType::Line,
) -> Unit raise XlsxError {
  self.add_sparkline_group([location], [range_ref], sparkline_type~)
}

///|
pub fn Worksheet::add_sparkline_group(
  self : Worksheet,
  locations : ArrayView[String],
  ranges : ArrayView[String],
  sparkline_type? : SparklineType = SparklineType::Line,
) -> Unit raise XlsxError {
  if locations.length() == 0 || ranges.length() == 0 {
    raise XlsxError::InvalidSparkline(msg="sparkline inputs empty")
  }
  if locations.length() != ranges.length() {
    raise XlsxError::InvalidSparkline(msg="sparkline inputs mismatch")
  }
  let sparklines : Array[Sparkline] = []
  for i, location in locations {
    let (row, col) = cell_ref_to_rc(location)
    let canonical_loc = cell_ref_from(row, col)
    let normalized_range = normalize_range_ref(ranges[i])
    sparklines.push({ range_ref: normalized_range, location: canonical_loc })
  }
  self.sparkline_groups.push({ sparkline_type, sparklines })
}

///|
pub fn Worksheet::add_pivot_table_xml(
  self : Worksheet,
  table_xml : String,
  cache_definition_xml : String,
  cache_records_xml? : String = "",
) -> PivotTable raise XlsxError {
  let pivot = PivotTable::new(
    table_xml,
    cache_definition_xml,
    cache_records_xml~,
  )
  self.pivot_tables.push(pivot)
  pivot
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
pub fn Worksheet::add_vml_drawing_xml(
  self : Worksheet,
  xml : String,
) -> Unit raise XlsxError {
  if xml == "" {
    raise XlsxError::InvalidVmlDrawing(msg="vml drawing xml empty")
  }
  self.vml_drawing_xml = Some(xml)
}

///|
pub fn Worksheet::add_vml_drawing_hf_xml(
  self : Worksheet,
  xml : String,
) -> Unit raise XlsxError {
  if xml == "" {
    raise XlsxError::InvalidVmlDrawing(msg="vml drawing hf xml empty")
  }
  self.vml_drawing_hf_xml = Some(xml)
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
  self.ensure_stream_idle()
  let reference = cell_ref_from(row, col)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference,
        row,
        col,
        value,
        value_type: CellValueType::String,
        formula: None,
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
    value_type: CellValueType::String,
    formula: None,
    style_id: 0,
  })
}

///|
pub fn Worksheet::set_cell_value_rc(
  self : Worksheet,
  row : Int,
  col : Int,
  value : CellValue,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let reference = cell_ref_from(row, col)
  let value_type = cell_value_type(value)
  let raw_value = cell_value_raw_string(value)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference,
        row,
        col,
        value: raw_value,
        value_type,
        formula: None,
        style_id: cell.style_id,
      }
      return
    }
  }
  self.cells.push({
    reference,
    row,
    col,
    value: raw_value,
    value_type,
    formula: None,
    style_id: 0,
  })
}

///|
pub fn Worksheet::set_cell_formula_rc(
  self : Worksheet,
  row : Int,
  col : Int,
  formula : String,
  value? : String = "",
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let reference = cell_ref_from(row, col)
  for i, cell in self.cells {
    if cell.row == row && cell.col == col {
      self.cells[i] = {
        reference,
        row,
        col,
        value,
        value_type: CellValueType::String,
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
    value_type: CellValueType::String,
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
pub fn Worksheet::get_cell_value_raw_rc(
  self : Worksheet,
  row : Int,
  col : Int,
) -> CellValue? raise XlsxError {
  if row <= 0 || col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{row}")
  }
  for cell in self.cells {
    if cell.row == row && cell.col == col {
      return Some(cell_value_from_raw(cell.value_type, cell.value))
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
fn default_row_dimension() -> RowDimension {
  { height: None, hidden: false, outline_level: 0, style_id: None }
}

///|
fn default_col_dimension() -> ColDimension {
  { width: None, hidden: false, outline_level: 0, style_id: None }
}

///|
fn row_dimension_is_default(dim : RowDimension) -> Bool {
  dim.height is None &&
  dim.hidden == false &&
  dim.outline_level == 0 &&
  dim.style_id is None
}

///|
fn col_dimension_is_default(dim : ColDimension) -> Bool {
  dim.width is None &&
  dim.hidden == false &&
  dim.outline_level == 0 &&
  dim.style_id is None
}

///|
fn Worksheet::row_dimension_value(self : Worksheet, row : Int) -> RowDimension {
  match self.row_dimensions.get(row) {
    Some(value) => value
    None => default_row_dimension()
  }
}

///|
fn Worksheet::col_dimension_value(self : Worksheet, col : Int) -> ColDimension {
  match self.col_dimensions.get(col) {
    Some(value) => value
    None => default_col_dimension()
  }
}

///|
fn Worksheet::set_row_dimension(
  self : Worksheet,
  row : Int,
  dim : RowDimension,
) -> Unit {
  if row_dimension_is_default(dim) {
    self.row_dimensions.remove(row)
  } else {
    self.row_dimensions[row] = dim
  }
}

///|
fn Worksheet::set_col_dimension(
  self : Worksheet,
  col : Int,
  dim : ColDimension,
) -> Unit {
  if col_dimension_is_default(dim) {
    self.col_dimensions.remove(col)
  } else {
    self.col_dimensions[col] = dim
  }
}

///|
pub fn Worksheet::set_row_height(
  self : Worksheet,
  row : Int,
  height : Double,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  if height < 0.0 {
    raise XlsxError::InvalidSheetOperation(msg="row height is negative")
  }
  let dim = self.row_dimension_value(row)
  let updated : RowDimension = {
    height: Some(height),
    hidden: dim.hidden,
    outline_level: dim.outline_level,
    style_id: dim.style_id,
  }
  self.set_row_dimension(row, updated)
}

///|
pub fn Worksheet::get_row_height(
  self : Worksheet,
  row : Int,
) -> Double? raise XlsxError {
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  match self.row_dimensions.get(row) {
    Some(dim) => dim.height
    None => None
  }
}

///|
pub fn Worksheet::set_row_visible(
  self : Worksheet,
  row : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  let dim = self.row_dimension_value(row)
  let updated : RowDimension = {
    height: dim.height,
    hidden: !visible,
    outline_level: dim.outline_level,
    style_id: dim.style_id,
  }
  self.set_row_dimension(row, updated)
}

///|
pub fn Worksheet::row_visible(
  self : Worksheet,
  row : Int,
) -> Bool raise XlsxError {
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  match self.row_dimensions.get(row) {
    Some(dim) => !dim.hidden
    None => true
  }
}

///|
pub fn Worksheet::set_row_outline_level(
  self : Worksheet,
  row : Int,
  level : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  if level < 0 || level > 7 {
    raise XlsxError::InvalidSheetOperation(msg="row outline level out of range")
  }
  let dim = self.row_dimension_value(row)
  let updated : RowDimension = {
    height: dim.height,
    hidden: dim.hidden,
    outline_level: level,
    style_id: dim.style_id,
  }
  self.set_row_dimension(row, updated)
}

///|
pub fn Worksheet::row_outline_level(
  self : Worksheet,
  row : Int,
) -> Int raise XlsxError {
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  match self.row_dimensions.get(row) {
    Some(dim) => dim.outline_level
    None => 0
  }
}

///|
pub fn Worksheet::set_row_style(
  self : Worksheet,
  row : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  let dim = self.row_dimension_value(row)
  let style = if style_id > 0 { Some(style_id) } else { None }
  let updated : RowDimension = {
    height: dim.height,
    hidden: dim.hidden,
    outline_level: dim.outline_level,
    style_id: style,
  }
  self.set_row_dimension(row, updated)
}

///|
pub fn Worksheet::get_row_style(
  self : Worksheet,
  row : Int,
) -> Int? raise XlsxError {
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  match self.row_dimensions.get(row) {
    Some(dim) => dim.style_id
    None => None
  }
}

///|
pub fn Worksheet::set_col_width(
  self : Worksheet,
  col : Int,
  width : Double,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  if width < 0.0 {
    raise XlsxError::InvalidSheetOperation(msg="column width is negative")
  }
  let dim = self.col_dimension_value(col)
  let updated : ColDimension = {
    width: Some(width),
    hidden: dim.hidden,
    outline_level: dim.outline_level,
    style_id: dim.style_id,
  }
  self.set_col_dimension(col, updated)
}

///|
pub fn Worksheet::get_col_width(
  self : Worksheet,
  col : Int,
) -> Double? raise XlsxError {
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  match self.col_dimensions.get(col) {
    Some(dim) => dim.width
    None => None
  }
}

///|
pub fn Worksheet::set_col_visible(
  self : Worksheet,
  col : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  let dim = self.col_dimension_value(col)
  let updated : ColDimension = {
    width: dim.width,
    hidden: !visible,
    outline_level: dim.outline_level,
    style_id: dim.style_id,
  }
  self.set_col_dimension(col, updated)
}

///|
pub fn Worksheet::col_visible(
  self : Worksheet,
  col : Int,
) -> Bool raise XlsxError {
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  match self.col_dimensions.get(col) {
    Some(dim) => !dim.hidden
    None => true
  }
}

///|
pub fn Worksheet::set_col_outline_level(
  self : Worksheet,
  col : Int,
  level : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  if level < 0 || level > 7 {
    raise XlsxError::InvalidSheetOperation(
      msg="column outline level out of range",
    )
  }
  let dim = self.col_dimension_value(col)
  let updated : ColDimension = {
    width: dim.width,
    hidden: dim.hidden,
    outline_level: level,
    style_id: dim.style_id,
  }
  self.set_col_dimension(col, updated)
}

///|
pub fn Worksheet::col_outline_level(
  self : Worksheet,
  col : Int,
) -> Int raise XlsxError {
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  match self.col_dimensions.get(col) {
    Some(dim) => dim.outline_level
    None => 0
  }
}

///|
pub fn Worksheet::set_col_style(
  self : Worksheet,
  col : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  let dim = self.col_dimension_value(col)
  let style = if style_id > 0 { Some(style_id) } else { None }
  let updated : ColDimension = {
    width: dim.width,
    hidden: dim.hidden,
    outline_level: dim.outline_level,
    style_id: style,
  }
  self.set_col_dimension(col, updated)
}

///|
pub fn Worksheet::get_col_style(
  self : Worksheet,
  col : Int,
) -> Int? raise XlsxError {
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  match self.col_dimensions.get(col) {
    Some(dim) => dim.style_id
    None => None
  }
}

///|
pub fn Worksheet::insert_rows(
  self : Worksheet,
  row : Int,
  count : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  if count <= 0 {
    raise XlsxError::InvalidSheetOperation(msg="row count must be positive")
  }
  for i, cell in self.cells {
    if cell.row >= row {
      let new_row = cell.row + count
      let reference = cell_ref_from(new_row, cell.col)
      self.cells[i] = {
        reference,
        row: new_row,
        col: cell.col,
        value: cell.value,
        value_type: cell.value_type,
        formula: cell.formula,
        style_id: cell.style_id,
      }
    }
  }
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    updated_merges.push(adjust_range_after_row_insert(range_ref, row, count))
  }
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges[:])
  let updated_tables : Array[Table] = []
  for table in self.tables {
    updated_tables.push(adjust_table_after_row_insert(table, row, count))
  }
  self.tables.clear()
  self.tables.append(updated_tables[:])
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_row_insert(group, row, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines[:])
  let updated_images : Array[Image] = []
  for image in self.images {
    let reference = adjust_cell_after_row_insert(image.reference, row, count)
    updated_images.push({
      reference,
      data: image.data,
      extension: image.extension,
      content_type: image.content_type,
    })
  }
  self.images.clear()
  self.images.append(updated_images[:])
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    let reference = adjust_cell_after_row_insert(chart.reference, row, count)
    updated_charts.push({ reference, xml: chart.xml })
  }
  self.charts.clear()
  self.charts.append(updated_charts[:])
  let updated_rows : Map[Int, RowDimension] = {}
  for row_index, dim in self.row_dimensions {
    let new_row = if row_index >= row { row_index + count } else { row_index }
    updated_rows[new_row] = dim
  }
  self.row_dimensions.clear()
  for row_index, dim in updated_rows {
    self.row_dimensions[row_index] = dim
  }
}

///|
pub fn Worksheet::remove_rows(
  self : Worksheet,
  row : Int,
  count : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if row <= 0 {
    raise XlsxError::InvalidCellRef(value="\{0}:\{row}")
  }
  if count <= 0 {
    raise XlsxError::InvalidSheetOperation(msg="row count must be positive")
  }
  let end_row = row + count - 1
  let updated_cells : Array[Cell] = []
  for cell in self.cells {
    if cell.row < row {
      updated_cells.push(cell)
      continue
    }
    if cell.row <= end_row {
      continue
    }
    let new_row = cell.row - count
    let reference = cell_ref_from(new_row, cell.col)
    updated_cells.push({
      reference,
      row: new_row,
      col: cell.col,
      value: cell.value,
      value_type: cell.value_type,
      formula: cell.formula,
      style_id: cell.style_id,
    })
  }
  self.cells.clear()
  self.cells.append(updated_cells[:])
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    match adjust_range_after_row_remove(range_ref, row, count) {
      Some(value) => updated_merges.push(value)
      None => ()
    }
  }
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges[:])
  let updated_tables : Array[Table] = []
  for table in self.tables {
    match adjust_table_after_row_remove(table, row, count) {
      Some(value) => updated_tables.push(value)
      None => ()
    }
  }
  self.tables.clear()
  self.tables.append(updated_tables[:])
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_row_remove(group, row, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines[:])
  let updated_images : Array[Image] = []
  for image in self.images {
    match adjust_cell_after_row_remove(image.reference, row, count) {
      Some(reference) =>
        updated_images.push({
          reference,
          data: image.data,
          extension: image.extension,
          content_type: image.content_type,
        })
      None => ()
    }
  }
  self.images.clear()
  self.images.append(updated_images[:])
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    match adjust_cell_after_row_remove(chart.reference, row, count) {
      Some(reference) => updated_charts.push({ reference, xml: chart.xml })
      None => ()
    }
  }
  self.charts.clear()
  self.charts.append(updated_charts[:])
  let updated_rows : Map[Int, RowDimension] = {}
  for row_index, dim in self.row_dimensions {
    if row_index < row {
      updated_rows[row_index] = dim
    } else if row_index > end_row {
      updated_rows[row_index - count] = dim
    }
  }
  self.row_dimensions.clear()
  for row_index, dim in updated_rows {
    self.row_dimensions[row_index] = dim
  }
}

///|
pub fn Worksheet::insert_cols(
  self : Worksheet,
  col : Int,
  count : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  if count <= 0 {
    raise XlsxError::InvalidSheetOperation(msg="column count must be positive")
  }
  for i, cell in self.cells {
    if cell.col >= col {
      let new_col = cell.col + count
      let reference = cell_ref_from(cell.row, new_col)
      self.cells[i] = {
        reference,
        row: cell.row,
        col: new_col,
        value: cell.value,
        value_type: cell.value_type,
        formula: cell.formula,
        style_id: cell.style_id,
      }
    }
  }
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    updated_merges.push(adjust_range_after_col_insert(range_ref, col, count))
  }
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges[:])
  let updated_tables : Array[Table] = []
  for table in self.tables {
    updated_tables.push(adjust_table_after_col_insert(table, col, count))
  }
  self.tables.clear()
  self.tables.append(updated_tables[:])
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_col_insert(group, col, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines[:])
  let updated_images : Array[Image] = []
  for image in self.images {
    let reference = adjust_cell_after_col_insert(image.reference, col, count)
    updated_images.push({
      reference,
      data: image.data,
      extension: image.extension,
      content_type: image.content_type,
    })
  }
  self.images.clear()
  self.images.append(updated_images[:])
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    let reference = adjust_cell_after_col_insert(chart.reference, col, count)
    updated_charts.push({ reference, xml: chart.xml })
  }
  self.charts.clear()
  self.charts.append(updated_charts[:])
  let updated_cols : Map[Int, ColDimension] = {}
  for col_index, dim in self.col_dimensions {
    let new_col = if col_index >= col { col_index + count } else { col_index }
    updated_cols[new_col] = dim
  }
  self.col_dimensions.clear()
  for col_index, dim in updated_cols {
    self.col_dimensions[col_index] = dim
  }
}

///|
pub fn Worksheet::remove_cols(
  self : Worksheet,
  col : Int,
  count : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if col <= 0 {
    raise XlsxError::InvalidCellRef(value="\{col}:\{0}")
  }
  if count <= 0 {
    raise XlsxError::InvalidSheetOperation(msg="column count must be positive")
  }
  let end_col = col + count - 1
  let updated_cells : Array[Cell] = []
  for cell in self.cells {
    if cell.col < col {
      updated_cells.push(cell)
      continue
    }
    if cell.col <= end_col {
      continue
    }
    let new_col = cell.col - count
    let reference = cell_ref_from(cell.row, new_col)
    updated_cells.push({
      reference,
      row: cell.row,
      col: new_col,
      value: cell.value,
      value_type: cell.value_type,
      formula: cell.formula,
      style_id: cell.style_id,
    })
  }
  self.cells.clear()
  self.cells.append(updated_cells[:])
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    match adjust_range_after_col_remove(range_ref, col, count) {
      Some(value) => updated_merges.push(value)
      None => ()
    }
  }
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges[:])
  let updated_tables : Array[Table] = []
  for table in self.tables {
    match adjust_table_after_col_remove(table, col, count) {
      Some(value) => updated_tables.push(value)
      None => ()
    }
  }
  self.tables.clear()
  self.tables.append(updated_tables[:])
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_col_remove(group, col, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines[:])
  let updated_images : Array[Image] = []
  for image in self.images {
    match adjust_cell_after_col_remove(image.reference, col, count) {
      Some(reference) =>
        updated_images.push({
          reference,
          data: image.data,
          extension: image.extension,
          content_type: image.content_type,
        })
      None => ()
    }
  }
  self.images.clear()
  self.images.append(updated_images[:])
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    match adjust_cell_after_col_remove(chart.reference, col, count) {
      Some(reference) => updated_charts.push({ reference, xml: chart.xml })
      None => ()
    }
  }
  self.charts.clear()
  self.charts.append(updated_charts[:])
  let updated_cols : Map[Int, ColDimension] = {}
  for col_index, dim in self.col_dimensions {
    if col_index < col {
      updated_cols[col_index] = dim
    } else if col_index > end_col {
      updated_cols[col_index - count] = dim
    }
  }
  self.col_dimensions.clear()
  for col_index, dim in updated_cols {
    self.col_dimensions[col_index] = dim
  }
}

///|
fn adjust_bounds_for_insert(
  min : Int,
  max : Int,
  start : Int,
  count : Int,
) -> (Int, Int) {
  if start <= min {
    (min + count, max + count)
  } else if start <= max {
    (min, max + count)
  } else {
    (min, max)
  }
}

///|
fn adjust_bounds_for_remove(
  min : Int,
  max : Int,
  start : Int,
  count : Int,
) -> (Int, Int)? {
  let end = start + count - 1
  if end < min {
    return Some((min - count, max - count))
  }
  if start > max {
    return Some((min, max))
  }
  let removed_before = if start < min { min - start } else { 0 }
  let overlap_start = if start > min { start } else { min }
  let overlap_end = if end < max { end } else { max }
  let removed_inside = overlap_end - overlap_start + 1
  let new_min = min - removed_before
  let new_max = max - removed_before - removed_inside
  if new_max < new_min {
    None
  } else {
    Some((new_min, new_max))
  }
}

///|
fn adjust_range_after_row_insert(
  range_ref : String,
  row : Int,
  count : Int,
) -> String raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
  let (new_min_row, new_max_row) = adjust_bounds_for_insert(
    min_row, max_row, row, count,
  )
  let start_ref = cell_ref_from(new_min_row, min_col)
  let end_ref = cell_ref_from(new_max_row, max_col)
  "\{start_ref}:\{end_ref}"
}

///|
fn adjust_range_after_row_remove(
  range_ref : String,
  row : Int,
  count : Int,
) -> String? raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
  match adjust_bounds_for_remove(min_row, max_row, row, count) {
    Some((new_min_row, new_max_row)) => {
      let start_ref = cell_ref_from(new_min_row, min_col)
      let end_ref = cell_ref_from(new_max_row, max_col)
      Some("\{start_ref}:\{end_ref}")
    }
    None => None
  }
}

///|
fn adjust_range_after_col_insert(
  range_ref : String,
  col : Int,
  count : Int,
) -> String raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
  let (new_min_col, new_max_col) = adjust_bounds_for_insert(
    min_col, max_col, col, count,
  )
  let start_ref = cell_ref_from(min_row, new_min_col)
  let end_ref = cell_ref_from(max_row, new_max_col)
  "\{start_ref}:\{end_ref}"
}

///|
fn adjust_range_after_col_remove(
  range_ref : String,
  col : Int,
  count : Int,
) -> String? raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
  match adjust_bounds_for_remove(min_col, max_col, col, count) {
    Some((new_min_col, new_max_col)) => {
      let start_ref = cell_ref_from(min_row, new_min_col)
      let end_ref = cell_ref_from(max_row, new_max_col)
      Some("\{start_ref}:\{end_ref}")
    }
    None => None
  }
}

///|
fn adjust_cell_after_row_insert(
  reference : String,
  row : Int,
  count : Int,
) -> String raise XlsxError {
  let (cell_row, cell_col) = cell_ref_to_rc(reference)
  let new_row = if cell_row >= row { cell_row + count } else { cell_row }
  cell_ref_from(new_row, cell_col)
}

///|
fn adjust_cell_after_row_remove(
  reference : String,
  row : Int,
  count : Int,
) -> String? raise XlsxError {
  let (cell_row, cell_col) = cell_ref_to_rc(reference)
  let end_row = row + count - 1
  if cell_row < row {
    Some(cell_ref_from(cell_row, cell_col))
  } else if cell_row <= end_row {
    None
  } else {
    Some(cell_ref_from(cell_row - count, cell_col))
  }
}

///|
fn adjust_cell_after_col_insert(
  reference : String,
  col : Int,
  count : Int,
) -> String raise XlsxError {
  let (cell_row, cell_col) = cell_ref_to_rc(reference)
  let new_col = if cell_col >= col { cell_col + count } else { cell_col }
  cell_ref_from(cell_row, new_col)
}

///|
fn adjust_cell_after_col_remove(
  reference : String,
  col : Int,
  count : Int,
) -> String? raise XlsxError {
  let (cell_row, cell_col) = cell_ref_to_rc(reference)
  let end_col = col + count - 1
  if cell_col < col {
    Some(cell_ref_from(cell_row, cell_col))
  } else if cell_col <= end_col {
    None
  } else {
    Some(cell_ref_from(cell_row, cell_col - count))
  }
}

///|
fn clone_table_columns(columns : ArrayView[String]) -> Array[String] {
  let out : Array[String] = []
  for column in columns {
    out.push(column)
  }
  out
}

///|
fn table_default_column_name(index : Int) -> String {
  "Column\{index}"
}

///|
fn adjust_table_after_row_insert(
  table : Table,
  row : Int,
  count : Int,
) -> Table raise XlsxError {
  let range_ref = adjust_range_after_row_insert(table.range_ref, row, count)
  {
    id: table.id,
    name: table.name,
    display_name: table.display_name,
    range_ref,
    columns: clone_table_columns(table.columns),
    style_name: table.style_name,
  }
}

///|
fn adjust_table_after_row_remove(
  table : Table,
  row : Int,
  count : Int,
) -> Table? raise XlsxError {
  match adjust_range_after_row_remove(table.range_ref, row, count) {
    Some(range_ref) =>
      Some({
        id: table.id,
        name: table.name,
        display_name: table.display_name,
        range_ref,
        columns: clone_table_columns(table.columns),
        style_name: table.style_name,
      })
    None => None
  }
}

///|
fn adjust_table_after_col_insert(
  table : Table,
  col : Int,
  count : Int,
) -> Table raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(table.range_ref)
  let (new_min_col, new_max_col) = adjust_bounds_for_insert(
    min_col, max_col, col, count,
  )
  let columns = clone_table_columns(table.columns)
  if col > min_col && col <= max_col {
    let insert_index = col - min_col
    let base = columns.length() + 1
    let mut i = 0
    while i < count {
      columns.insert(insert_index + i, table_default_column_name(base + i))
      i = i + 1
    }
  }
  let start_ref = cell_ref_from(min_row, new_min_col)
  let end_ref = cell_ref_from(max_row, new_max_col)
  {
    id: table.id,
    name: table.name,
    display_name: table.display_name,
    range_ref: "\{start_ref}:\{end_ref}",
    columns,
    style_name: table.style_name,
  }
}

///|
fn adjust_table_after_col_remove(
  table : Table,
  col : Int,
  count : Int,
) -> Table? raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(table.range_ref)
  match adjust_bounds_for_remove(min_col, max_col, col, count) {
    Some((new_min_col, new_max_col)) => {
      let columns = clone_table_columns(table.columns)
      let end_col = col + count - 1
      if !(end_col < min_col || col > max_col) {
        let overlap_start = if col > min_col { col } else { min_col }
        let overlap_end = if end_col < max_col { end_col } else { max_col }
        let remove_count = overlap_end - overlap_start + 1
        let remove_index = overlap_start - min_col
        let mut i = 0
        while i < remove_count {
          ignore(columns.remove(remove_index))
          i = i + 1
        }
      }
      let start_ref = cell_ref_from(min_row, new_min_col)
      let end_ref = cell_ref_from(max_row, new_max_col)
      Some({
        id: table.id,
        name: table.name,
        display_name: table.display_name,
        range_ref: "\{start_ref}:\{end_ref}",
        columns,
        style_name: table.style_name,
      })
    }
    None => None
  }
}

///|
fn adjust_sparkline_group_after_row_insert(
  group : SparklineGroup,
  row : Int,
  count : Int,
) -> SparklineGroup raise XlsxError {
  let updated : Array[Sparkline] = []
  for sparkline in group.sparklines {
    let range_ref = adjust_range_after_row_insert(
      sparkline.range_ref,
      row,
      count,
    )
    let location = adjust_cell_after_row_insert(sparkline.location, row, count)
    updated.push({ range_ref, location })
  }
  { sparkline_type: group.sparkline_type, sparklines: updated }
}

///|
fn adjust_sparkline_group_after_row_remove(
  group : SparklineGroup,
  row : Int,
  count : Int,
) -> SparklineGroup raise XlsxError {
  let updated : Array[Sparkline] = []
  for sparkline in group.sparklines {
    let range_ref = adjust_range_after_row_remove(
      sparkline.range_ref,
      row,
      count,
    )
    let location = adjust_cell_after_row_remove(sparkline.location, row, count)
    match (range_ref, location) {
      (Some(range_ref), Some(location)) => updated.push({ range_ref, location })
      _ => ()
    }
  }
  { sparkline_type: group.sparkline_type, sparklines: updated }
}

///|
fn adjust_sparkline_group_after_col_insert(
  group : SparklineGroup,
  col : Int,
  count : Int,
) -> SparklineGroup raise XlsxError {
  let updated : Array[Sparkline] = []
  for sparkline in group.sparklines {
    let range_ref = adjust_range_after_col_insert(
      sparkline.range_ref,
      col,
      count,
    )
    let location = adjust_cell_after_col_insert(sparkline.location, col, count)
    updated.push({ range_ref, location })
  }
  { sparkline_type: group.sparkline_type, sparklines: updated }
}

///|
fn adjust_sparkline_group_after_col_remove(
  group : SparklineGroup,
  col : Int,
  count : Int,
) -> SparklineGroup raise XlsxError {
  let updated : Array[Sparkline] = []
  for sparkline in group.sparklines {
    let range_ref = adjust_range_after_col_remove(
      sparkline.range_ref,
      col,
      count,
    )
    let location = adjust_cell_after_col_remove(sparkline.location, col, count)
    match (range_ref, location) {
      (Some(range_ref), Some(location)) => updated.push({ range_ref, location })
      _ => ()
    }
  }
  { sparkline_type: group.sparkline_type, sparklines: updated }
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
