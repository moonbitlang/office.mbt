///|
pub struct Workbook {
  sheets : Array[Worksheet]
  styles : Array[Style]
  mut core_properties : CoreProperties
  mut app_properties : AppProperties
  mut active_sheet_index : Int
}

///|
let max_sheet_name_length = 31

///|
fn check_sheet_name(name : StringView) -> Unit raise XlsxError {
  let text = name.to_string()
  if text == "" {
    raise XlsxError::InvalidSheetName(msg="sheet name is blank")
  }
  if text.length() > max_sheet_name_length {
    raise XlsxError::InvalidSheetName(msg="sheet name too long")
  }
  if text.has_prefix("'") || text.has_suffix("'") {
    raise XlsxError::InvalidSheetName(
      msg="sheet name cannot start or end with a single quote",
    )
  }
  for c in text {
    match c {
      ':' | '\\' | '/' | '?' | '*' | '[' | ']' =>
        raise XlsxError::InvalidSheetName(
          msg="sheet name contains invalid characters",
        )
      _ => ()
    }
  }
}

///|
fn normalize_sheet_name(name : StringView) -> String {
  name.to_string().to_lower()
}

///|
fn sheet_name_equal(a : StringView, b : StringView) -> Bool {
  normalize_sheet_name(a) == normalize_sheet_name(b)
}

///|
pub fn Workbook::new() -> Workbook {
  {
    sheets: [],
    styles: [Style::new()],
    core_properties: CoreProperties::new(),
    app_properties: AppProperties::new(),
    active_sheet_index: 0,
  }
}

///|
pub fn Workbook::add_sheet(
  self : Workbook,
  name : String,
) -> Worksheet raise XlsxError {
  check_sheet_name(name)
  let normalized = normalize_sheet_name(name)
  for sheet in self.sheets {
    if normalize_sheet_name(sheet.name()) == normalized {
      raise XlsxError::SheetAlreadyExists(name~)
    }
  }
  let sheet = Worksheet::new(name)
  self.sheets.push(sheet)
  if self.sheets.length() == 1 {
    self.active_sheet_index = 0
  }
  sheet
}

///|
pub fn Workbook::new_stream_writer(
  self : Workbook,
  sheet_name : StringView,
) -> StreamWriter raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  if sheet.stream_state != StreamState::Idle {
    raise XlsxError::StreamModeConflict(msg="stream writer already active")
  }
  if sheet.cells().length() > 0 {
    raise XlsxError::StreamModeConflict(msg="worksheet already has data")
  }
  sheet.stream_state = StreamState::Writing
  StreamWriter::new(sheet, self.styles.length())
}

///|
pub fn Workbook::sheet(self : Workbook, name : StringView) -> Worksheet? {
  let needle = normalize_sheet_name(name)
  for sheet in self.sheets {
    if normalize_sheet_name(sheet.name()) == needle {
      return Some(sheet)
    }
  }
  None
}

///|
pub fn Workbook::sheet_name(self : Workbook, index : Int) -> String? {
  if index < 0 || index >= self.sheets.length() {
    return None
  }
  Some(self.sheets[index].name())
}

///|
pub fn Workbook::sheet_index(
  self : Workbook,
  name : StringView,
) -> Int raise XlsxError {
  let needle = normalize_sheet_name(name)
  for i, sheet in self.sheets {
    if normalize_sheet_name(sheet.name()) == needle {
      return i
    }
  }
  raise XlsxError::SheetNotFound(name=name.to_string())
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
pub fn Workbook::core_properties(self : Workbook) -> CoreProperties {
  self.core_properties
}

///|
pub fn Workbook::set_core_properties(
  self : Workbook,
  props : CoreProperties,
) -> Unit {
  self.core_properties = props
}

///|
pub fn Workbook::app_properties(self : Workbook) -> AppProperties {
  self.app_properties
}

///|
pub fn Workbook::set_app_properties(
  self : Workbook,
  props : AppProperties,
) -> Unit {
  self.app_properties = props
}

///|
pub fn Workbook::active_sheet_index(self : Workbook) -> Int {
  self.active_sheet_index
}

///|
pub fn Workbook::set_active_sheet(self : Workbook, index : Int) -> Unit {
  if self.sheets.length() == 0 {
    self.active_sheet_index = 0
    return
  }
  if index < 0 || index >= self.sheets.length() {
    self.active_sheet_index = 0
  } else {
    self.active_sheet_index = index
  }
}

///|
pub fn Workbook::set_sheet_name(
  self : Workbook,
  source : StringView,
  target : String,
) -> Unit raise XlsxError {
  check_sheet_name(source)
  check_sheet_name(target)
  if sheet_name_equal(source, target) {
    return
  }
  let target_norm = normalize_sheet_name(target)
  for sheet in self.sheets {
    if normalize_sheet_name(sheet.name()) == target_norm {
      raise XlsxError::SheetAlreadyExists(name=target)
    }
  }
  let index = self.sheet_index(source)
  self.sheets[index].name = target
}

///|
pub fn Workbook::delete_sheet(
  self : Workbook,
  name : StringView,
) -> Unit raise XlsxError {
  check_sheet_name(name)
  let index = self.sheet_index(name)
  if self.sheets.length() <= 1 {
    raise XlsxError::InvalidSheetOperation(
      msg="workbook must contain at least one sheet",
    )
  }
  ignore(self.sheets.remove(index))
  if self.active_sheet_index == index {
    let fallback = if index >= self.sheets.length() {
      self.sheets.length() - 1
    } else {
      index
    }
    self.active_sheet_index = fallback
  } else if self.active_sheet_index > index {
    self.active_sheet_index = self.active_sheet_index - 1
  }
}

///|
pub fn Workbook::move_sheet(
  self : Workbook,
  source : StringView,
  target : StringView,
) -> Unit raise XlsxError {
  check_sheet_name(source)
  check_sheet_name(target)
  if sheet_name_equal(source, target) {
    return
  }
  let source_index = self.sheet_index(source)
  let target_index = self.sheet_index(target)
  let sheet = self.sheets.remove(source_index)
  let insert_index = if target_index > source_index {
    target_index - 1
  } else {
    target_index
  }
  self.sheets.insert(insert_index, sheet)
  if self.active_sheet_index == source_index {
    self.active_sheet_index = insert_index
  } else if source_index < self.active_sheet_index &&
    insert_index >= self.active_sheet_index {
    self.active_sheet_index = self.active_sheet_index - 1
  } else if source_index > self.active_sheet_index &&
    insert_index <= self.active_sheet_index {
    self.active_sheet_index = self.active_sheet_index + 1
  }
}

///|
pub fn Workbook::copy_sheet(
  self : Workbook,
  from_index : Int,
  to_index : Int,
) -> Unit raise XlsxError {
  if from_index < 0 ||
    to_index < 0 ||
    from_index >= self.sheets.length() ||
    to_index >= self.sheets.length() ||
    from_index == to_index {
    raise XlsxError::InvalidSheetIndex(index=to_index)
  }
  let from_sheet = self.sheets[from_index]
  let to_sheet = self.sheets[to_index]
  let cloned = clone_worksheet(from_sheet, to_sheet.name(), to_sheet.state())
  self.sheets[to_index] = cloned
}

///|
pub fn Workbook::set_sheet_visible(
  self : Workbook,
  name : StringView,
  visible : Bool,
  very_hidden? : Bool = false,
) -> Unit raise XlsxError {
  check_sheet_name(name)
  let index = self.sheet_index(name)
  let state = if visible {
    SheetState::Visible
  } else if very_hidden {
    SheetState::VeryHidden
  } else {
    SheetState::Hidden
  }
  if state != SheetState::Visible {
    let mut visible_count = 0
    for i, sheet in self.sheets {
      let sheet_state = if i == index { state } else { sheet.state() }
      if sheet_state == SheetState::Visible {
        visible_count = visible_count + 1
      }
    }
    if visible_count == 0 {
      raise XlsxError::InvalidSheetOperation(
        msg="workbook must contain at least one visible sheet",
      )
    }
  }
  self.sheets[index].state = state
}

///|
pub fn Workbook::sheet_visible(
  self : Workbook,
  name : StringView,
) -> Bool raise XlsxError {
  check_sheet_name(name)
  let index = self.sheet_index(name)
  self.sheets[index].state() == SheetState::Visible
}

///|
fn clone_strings(values : ArrayView[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_row_dimensions(
  values : Map[Int, RowDimension],
) -> Map[Int, RowDimension] {
  let out : Map[Int, RowDimension] = {}
  for row, dim in values {
    out[row] = dim
  }
  out
}

///|
fn clone_col_dimensions(
  values : Map[Int, ColDimension],
) -> Map[Int, ColDimension] {
  let out : Map[Int, ColDimension] = {}
  for col, dim in values {
    out[col] = dim
  }
  out
}

///|
fn clone_cells(values : ArrayView[Cell]) -> Array[Cell] {
  let out : Array[Cell] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_tables(values : ArrayView[Table]) -> Array[Table] {
  let out : Array[Table] = []
  for value in values {
    let columns : Array[String] = []
    for column in value.columns {
      columns.push(column)
    }
    out.push({
      id: 0,
      name: value.name,
      display_name: value.display_name,
      range_ref: value.range_ref,
      columns,
      style_name: value.style_name,
    })
  }
  out
}

///|
fn clone_sparkline_groups(
  values : ArrayView[SparklineGroup],
) -> Array[SparklineGroup] {
  let out : Array[SparklineGroup] = []
  for value in values {
    let sparklines : Array[Sparkline] = []
    for sparkline in value.sparklines {
      sparklines.push(sparkline)
    }
    out.push({ sparkline_type: value.sparkline_type, sparklines })
  }
  out
}

///|
fn clone_pivot_tables(values : ArrayView[PivotTable]) -> Array[PivotTable] {
  let out : Array[PivotTable] = []
  for value in values {
    out.push({
      table_id: 0,
      cache_id: 0,
      table_xml: value.table_xml,
      cache_definition_xml: value.cache_definition_xml,
      cache_records_xml: value.cache_records_xml,
    })
  }
  out
}

///|
fn clone_images(values : ArrayView[Image]) -> Array[Image] {
  let out : Array[Image] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_charts(values : ArrayView[Chart]) -> Array[Chart] {
  let out : Array[Chart] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn clone_worksheet(
  sheet : Worksheet,
  name : String,
  state : SheetState,
) -> Worksheet {
  {
    name,
    cells: clone_cells(sheet.cells),
    merged_cells: clone_strings(sheet.merged_cells),
    tables: clone_tables(sheet.tables),
    sparkline_groups: clone_sparkline_groups(sheet.sparkline_groups),
    pivot_tables: clone_pivot_tables(sheet.pivot_tables),
    images: clone_images(sheet.images),
    charts: clone_charts(sheet.charts),
    data_validations: clone_strings(sheet.data_validations),
    conditional_formats: clone_strings(sheet.conditional_formats),
    row_dimensions: clone_row_dimensions(sheet.row_dimensions),
    col_dimensions: clone_col_dimensions(sheet.col_dimensions),
    state,
    stream_state: StreamState::Idle,
    vml_drawing_xml: sheet.vml_drawing_xml,
    vml_drawing_hf_xml: sheet.vml_drawing_hf_xml,
  }
}

///|
pub fn Workbook::row_stream(
  self : Workbook,
  sheet_name : StringView,
) -> RowStream raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  RowStream::new(sheet)
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
fn format_cell_value_for_workbook(
  styles : ArrayView[Style],
  cell : Cell,
  raw : Bool,
) -> String raise XlsxError {
  if raw {
    return cell.value
  }
  if cell.style_id < 0 || cell.style_id >= styles.length() {
    raise XlsxError::InvalidStyleId(index=cell.style_id)
  }
  format_cell_value(cell.value_type, cell.value, Some(styles[cell.style_id]))
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
pub fn Workbook::set_cell_value(
  self : Workbook,
  sheet_name : StringView,
  reference : String,
  value : CellValue,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_value(reference, value)
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
pub fn Workbook::get_cell_value_raw(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
) -> CellValue? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_value_raw(reference)
}

///|
pub fn Workbook::get_cell_value(
  self : Workbook,
  sheet_name : StringView,
  reference : StringView,
  raw? : Bool = false,
) -> String? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  let (row, col) = cell_ref_to_rc(reference)
  for cell in sheet.cells() {
    if cell.row == row && cell.col == col {
      return Some(format_cell_value_for_workbook(self.styles, cell, raw))
    }
  }
  None
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
pub fn Workbook::add_vml_drawing_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_vml_drawing_xml(xml)
}

///|
pub fn Workbook::add_vml_drawing_hf_xml(
  self : Workbook,
  sheet_name : StringView,
  xml : String,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_vml_drawing_hf_xml(xml)
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
pub fn Workbook::add_sparkline(
  self : Workbook,
  sheet_name : StringView,
  location : String,
  range_ref : String,
  sparkline_type? : SparklineType = SparklineType::Line,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_sparkline(location, range_ref, sparkline_type~)
}

///|
pub fn Workbook::add_sparkline_group(
  self : Workbook,
  sheet_name : StringView,
  locations : ArrayView[String],
  ranges : ArrayView[String],
  sparkline_type? : SparklineType = SparklineType::Line,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_sparkline_group(locations, ranges, sparkline_type~)
}

///|
pub fn Workbook::add_pivot_table_xml(
  self : Workbook,
  sheet_name : StringView,
  table_xml : String,
  cache_definition_xml : String,
  cache_records_xml? : String = "",
) -> PivotTable raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.add_pivot_table_xml(table_xml, cache_definition_xml, cache_records_xml~)
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
pub fn Workbook::set_cell_value_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  value : CellValue,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_cell_value_rc(row, col, value)
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
pub fn Workbook::get_cell_value_raw_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
) -> CellValue? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_cell_value_raw_rc(row, col)
}

///|
pub fn Workbook::get_cell_value_rc(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  col : Int,
  raw? : Bool = false,
) -> String? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  for cell in sheet.cells() {
    if cell.row == row && cell.col == col {
      return Some(format_cell_value_for_workbook(self.styles, cell, raw))
    }
  }
  None
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

///|
pub fn Workbook::set_row_height(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  height : Double,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_row_height(row, height)
}

///|
pub fn Workbook::get_row_height(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Double? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_row_height(row)
}

///|
pub fn Workbook::set_row_visible(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_row_visible(row, visible)
}

///|
pub fn Workbook::row_visible(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Bool raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.row_visible(row)
}

///|
pub fn Workbook::set_row_outline_level(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  level : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_row_outline_level(row, level)
}

///|
pub fn Workbook::row_outline_level(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Int raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.row_outline_level(row)
}

///|
pub fn Workbook::set_row_style(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.check_style_id(style_id)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_row_style(row, style_id)
}

///|
pub fn Workbook::get_row_style(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
) -> Int? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_row_style(row)
}

///|
pub fn Workbook::set_col_width(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  width : Double,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_col_width(col, width)
}

///|
pub fn Workbook::get_col_width(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Double? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_col_width(col)
}

///|
pub fn Workbook::set_col_visible(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_col_visible(col, visible)
}

///|
pub fn Workbook::col_visible(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Bool raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.col_visible(col)
}

///|
pub fn Workbook::set_col_outline_level(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  level : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_col_outline_level(col, level)
}

///|
pub fn Workbook::col_outline_level(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Int raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.col_outline_level(col)
}

///|
pub fn Workbook::set_col_style(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.check_style_id(style_id)
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.set_col_style(col, style_id)
}

///|
pub fn Workbook::get_col_style(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
) -> Int? raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.get_col_style(col)
}

///|
pub fn Workbook::insert_rows(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  count : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.insert_rows(row, count)
}

///|
pub fn Workbook::remove_rows(
  self : Workbook,
  sheet_name : StringView,
  row : Int,
  count : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.remove_rows(row, count)
}

///|
pub fn Workbook::insert_cols(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  count : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.insert_cols(col, count)
}

///|
pub fn Workbook::remove_cols(
  self : Workbook,
  sheet_name : StringView,
  col : Int,
  count : Int,
) -> Unit raise XlsxError {
  let sheet = match self.sheet(sheet_name) {
    Some(value) => value
    None => raise XlsxError::SheetNotFound(name=sheet_name.to_string())
  }
  sheet.remove_cols(col, count)
}
