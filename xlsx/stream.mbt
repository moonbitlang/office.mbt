///|
enum StreamState {
  Idle
  Writing
  Flushed
} derive(Eq)

///|
pub struct StreamCell {
  value : String
  value_type : CellValueType
  rich_text : Array[RichTextRun]?
  formula : String?
  style_id : Int
}

///|
pub fn StreamCell::new(
  value : String,
  formula? : String = "",
  style_id? : Int = 0,
) -> StreamCell {
  let formula_value = if formula == "" { None } else { Some(formula) }
  {
    value,
    value_type: String,
    rich_text: None,
    formula: formula_value,
    style_id,
  }
}

///|
pub fn StreamCell::new_value(
  value : CellValue,
  formula? : String = "",
  style_id? : Int = 0,
) -> StreamCell {
  let formula_value = if formula == "" { None } else { Some(formula) }
  {
    value: cell_value_raw_string(value),
    value_type: cell_value_type(value),
    rich_text: None,
    formula: formula_value,
    style_id,
  }
}

///|
pub fn StreamCell::new_rich_text(
  runs : ArrayView[RichTextRun],
  formula? : String = "",
  style_id? : Int = 0,
) -> StreamCell raise XlsxError {
  let total = rich_text_total_units(runs)
  if total > max_cell_chars {
    raise CellTextTooLong(len=total)
  }
  let stored_runs : Array[RichTextRun] = []
  for run in runs {
    stored_runs.push(run)
  }
  let formula_value = if formula == "" { None } else { Some(formula) }
  {
    value: rich_text_plain_text(runs),
    value_type: String,
    rich_text: Some(stored_runs),
    formula: formula_value,
    style_id,
  }
}

///|
pub struct StreamWriter {
  sheet : Worksheet
  sheet_id : Int
  mut last_row : Int
  styles : Array[Style]
  mut closed : Bool
}

///|
fn StreamWriter::new(
  sheet : Worksheet,
  sheet_id : Int,
  styles : Array[Style],
) -> StreamWriter {
  { sheet, sheet_id, last_row: 0, styles, closed: false }
}

///|
pub fn StreamWriter::sheet_id(self : StreamWriter) -> Int {
  self.sheet_id
}

///|
fn StreamWriter::ensure_open(self : StreamWriter) -> Unit raise XlsxError {
  if self.closed {
    raise StreamWriterClosed
  }
}

///|
fn StreamWriter::ensure_before_rows(
  self : StreamWriter,
  action : String,
) -> Unit raise XlsxError {
  if self.last_row > 0 {
    raise StreamModeConflict(msg="\{action} must be called before set_row")
  }
}

///|
fn normalize_col_range(start : Int, end : Int) -> (Int, Int) {
  if start <= end {
    (start, end)
  } else {
    (end, start)
  }
}

///|
fn apply_row_opts(
  sheet : Worksheet,
  row : Int,
  opts : RowOpts,
) -> Unit raise XlsxError {
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  if opts.height < 0.0 {
    raise InvalidSheetOperation(msg="row height is negative")
  }
  if opts.outline_level < 0 || opts.outline_level > 7 {
    raise InvalidSheetOperation(msg="row outline level out of range")
  }
  let dim = sheet.row_dimension_value(row)
  let height = if opts.height > 0.0 { Some(opts.height) } else { dim.height }
  let style = if opts.style_id > 0 { Some(opts.style_id) } else { None }
  let updated : RowDimension = {
    height,
    hidden: opts.hidden,
    outline_level: opts.outline_level,
    style_id: style,
  }
  sheet.set_row_dimension(row, updated)
}

///|
fn set_col_width_stream(
  sheet : Worksheet,
  col : Int,
  width : Double,
) -> Unit raise XlsxError {
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  if width < 0.0 {
    raise InvalidSheetOperation(msg="column width is negative")
  }
  let dim = sheet.col_dimension_value(col)
  let updated : ColDimension = {
    width: Some(width),
    hidden: dim.hidden,
    outline_level: dim.outline_level,
    style_id: dim.style_id,
  }
  sheet.set_col_dimension(col, updated)
}

///|
fn set_col_visible_stream(
  sheet : Worksheet,
  col : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  let dim = sheet.col_dimension_value(col)
  let updated : ColDimension = {
    width: dim.width,
    hidden: !visible,
    outline_level: dim.outline_level,
    style_id: dim.style_id,
  }
  sheet.set_col_dimension(col, updated)
}

///|
fn set_col_outline_level_stream(
  sheet : Worksheet,
  col : Int,
  level : Int,
) -> Unit raise XlsxError {
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  if level < 0 || level > 7 {
    raise InvalidSheetOperation(msg="column outline level out of range")
  }
  let dim = sheet.col_dimension_value(col)
  let updated : ColDimension = {
    width: dim.width,
    hidden: dim.hidden,
    outline_level: level,
    style_id: dim.style_id,
  }
  sheet.set_col_dimension(col, updated)
}

///|
fn set_col_style_stream(
  sheet : Worksheet,
  col : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  let dim = sheet.col_dimension_value(col)
  let style = if style_id > 0 { Some(style_id) } else { None }
  let updated : ColDimension = {
    width: dim.width,
    hidden: dim.hidden,
    outline_level: dim.outline_level,
    style_id: style,
  }
  sheet.set_col_dimension(col, updated)
}

///|
fn set_panes_stream(sheet : Worksheet, panes : Panes) -> Unit {
  if sheet.sheet_views.length() == 0 {
    sheet.sheet_views.push(SheetView::new())
  }
  let view_index = sheet.sheet_views.length() - 1
  let view = sheet.sheet_views[view_index]
  if !panes.freeze && !panes.split {
    view.pane = None
  } else {
    let pane = SheetPane::new()
    pane.active_pane = panes.active_pane
    pane.top_left_cell = panes.top_left_cell
    pane.x_split = Double::from_int(panes.x_split)
    pane.y_split = Double::from_int(panes.y_split)
    if panes.freeze {
      pane.state = "frozen"
    }
    view.pane = Some(pane)
  }
  let selections : Array[Selection] = []
  for item in panes.selection {
    selections.push(item)
  }
  view.selection.clear()
  view.selection.append(selections[:])
}

///|
pub fn StreamWriter::set_row(
  self : StreamWriter,
  start_ref : String,
  values : ArrayView[String],
  row_opts? : RowOpts,
) -> Unit raise XlsxError {
  let cells : Array[StreamCell] = []
  for value in values {
    cells.push(StreamCell::new(value))
  }
  match row_opts {
    Some(value) => self.set_row_cells(start_ref, cells, row_opts=value)
    None => self.set_row_cells(start_ref, cells)
  }
}

///|
pub fn StreamWriter::set_row_cells(
  self : StreamWriter,
  start_ref : String,
  values : ArrayView[StreamCell],
  row_opts? : RowOpts,
) -> Unit raise XlsxError {
  self.ensure_open()
  let (row, start_col) = cell_ref_to_rc(start_ref)
  if row <= self.last_row {
    raise StreamRowOrder(last=self.last_row, next=row)
  }
  let mut col = start_col
  for cell in values {
    if cell.style_id < 0 || cell.style_id >= self.styles.length() {
      raise InvalidStyleId(index=cell.style_id)
    }
    let reference = cell_ref_from(row, col)
    self.sheet.cells.push({
      reference,
      row,
      col,
      value: cell.value,
      value_type: cell.value_type,
      rich_text: cell.rich_text,
      formula: cell.formula,
      formula_type: None,
      formula_ref: None,
      formula_shared_index: None,
      style_id: cell.style_id,
    })
    col = col + 1
  }
  match row_opts {
    Some(opts) => apply_row_opts(self.sheet, row, opts)
    None => ()
  }
  self.last_row = row
}

///|
pub fn StreamWriter::flush(self : StreamWriter) -> Unit raise XlsxError {
  self.ensure_open()
  self.sheet.stream_state = Flushed
  self.closed = true
}

///|
pub fn StreamWriter::insert_page_break(
  self : StreamWriter,
  cell : StringView,
) -> Unit raise XlsxError {
  self.ensure_open()
  self.sheet.insert_page_break(cell)
}

///|
pub fn StreamWriter::add_table(
  self : StreamWriter,
  range_ref : String,
  name : String,
  columns : ArrayView[String],
  display_name? : String = "",
  style_name? : String = "TableStyleMedium9",
  show_first_column? : Bool = false,
  show_last_column? : Bool = false,
  show_row_stripes? : Bool = true,
  show_column_stripes? : Bool = false,
  show_header_row? : Bool = true,
) -> Table raise XlsxError {
  self.ensure_open()
  self.sheet.add_table(
    range_ref,
    name,
    columns,
    display_name~,
    style_name~,
    show_first_column~,
    show_last_column~,
    show_row_stripes~,
    show_column_stripes~,
    show_header_row~,
  )
}

///|
pub fn StreamWriter::merge_cell(
  self : StreamWriter,
  top_left : StringView,
  bottom_right : StringView,
) -> Unit raise XlsxError {
  self.ensure_open()
  self.sheet.merge_cells("\{top_left}:\{bottom_right}")
}

///|
pub fn StreamWriter::set_col_width(
  self : StreamWriter,
  start_col : Int,
  end_col : Int,
  width : Double,
) -> Unit raise XlsxError {
  self.ensure_open()
  self.ensure_before_rows("set_col_width")
  let (min_col, max_col) = normalize_col_range(start_col, end_col)
  for col in min_col..<=max_col {
    set_col_width_stream(self.sheet, col, width)
  }
}

///|
pub fn StreamWriter::set_col_visible(
  self : StreamWriter,
  start_col : Int,
  end_col : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  self.ensure_open()
  self.ensure_before_rows("set_col_visible")
  let (min_col, max_col) = normalize_col_range(start_col, end_col)
  for col in min_col..<=max_col {
    set_col_visible_stream(self.sheet, col, visible)
  }
}

///|
pub fn StreamWriter::set_col_outline_level(
  self : StreamWriter,
  col : Int,
  level : Int,
) -> Unit raise XlsxError {
  self.ensure_open()
  self.ensure_before_rows("set_col_outline_level")
  set_col_outline_level_stream(self.sheet, col, level)
}

///|
pub fn StreamWriter::set_col_style(
  self : StreamWriter,
  start_col : Int,
  end_col : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.ensure_open()
  self.ensure_before_rows("set_col_style")
  if style_id < 0 || style_id >= self.styles.length() {
    raise InvalidStyleId(index=style_id)
  }
  let (min_col, max_col) = normalize_col_range(start_col, end_col)
  for col in min_col..<=max_col {
    set_col_style_stream(self.sheet, col, style_id)
  }
}

///|
pub fn StreamWriter::set_panes(
  self : StreamWriter,
  panes : Panes,
) -> Unit raise XlsxError {
  self.ensure_open()
  self.ensure_before_rows("set_panes")
  set_panes_stream(self.sheet, panes)
}

///|
pub struct RowStream {
  cells : Array[Cell]
  mut index : Int
}

///|
fn RowStream::new(sheet : Worksheet) -> RowStream {
  { cells: sheet.sorted_cells(), index: 0 }
}

///|
pub fn RowStream::next(self : RowStream) -> Array[String]? {
  if self.index >= self.cells.length() {
    return None
  }
  let row = self.cells[self.index].row
  let mut end_index = self.index
  let mut max_col = 0
  while end_index < self.cells.length() && self.cells[end_index].row == row {
    let col = self.cells[end_index].col
    if col > max_col {
      max_col = col
    }
    end_index = end_index + 1
  }
  let values : Array[String] = Array::make(max_col, "")
  let mut i = self.index
  while i < end_index {
    let cell = self.cells[i]
    values[cell.col - 1] = cell.value
    i = i + 1
  }
  self.index = end_index
  Some(values)
}

///|
pub fn Worksheet::row_stream(self : Worksheet) -> RowStream {
  RowStream::new(self)
}
