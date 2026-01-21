///|
pub(all) enum StreamState {
  Idle
  Writing
  Flushed
} derive(Eq)

///|
pub struct StreamCell {
  value : String
  value_type : CellValueType
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
  { value, value_type: CellValueType::String, formula: formula_value, style_id }
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
    formula: formula_value,
    style_id,
  }
}

///|
pub struct StreamWriter {
  sheet : Worksheet
  mut last_row : Int
  style_count : Int
  mut closed : Bool
}

///|
fn StreamWriter::new(sheet : Worksheet, style_count : Int) -> StreamWriter {
  { sheet, last_row: 0, style_count, closed: false }
}

///|
fn StreamWriter::ensure_open(self : StreamWriter) -> Unit raise XlsxError {
  if self.closed {
    raise XlsxError::StreamWriterClosed
  }
}

///|
pub fn StreamWriter::set_row(
  self : StreamWriter,
  start_ref : String,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  let cells : Array[StreamCell] = []
  for value in values {
    cells.push(StreamCell::new(value))
  }
  self.set_row_cells(start_ref, cells)
}

///|
pub fn StreamWriter::set_row_cells(
  self : StreamWriter,
  start_ref : String,
  values : ArrayView[StreamCell],
) -> Unit raise XlsxError {
  self.ensure_open()
  let (row, start_col) = cell_ref_to_rc(start_ref)
  if row <= self.last_row {
    raise XlsxError::StreamRowOrder(last=self.last_row, next=row)
  }
  let mut col = start_col
  for cell in values {
    if cell.style_id < 0 || cell.style_id >= self.style_count {
      raise XlsxError::InvalidStyleId(index=cell.style_id)
    }
    let reference = cell_ref_from(row, col)
    self.sheet.cells.push({
      reference,
      row,
      col,
      value: cell.value,
      value_type: cell.value_type,
      formula: cell.formula,
      style_id: cell.style_id,
    })
    col = col + 1
  }
  self.last_row = row
}

///|
pub fn StreamWriter::flush(self : StreamWriter) -> Unit raise XlsxError {
  self.ensure_open()
  self.sheet.stream_state = StreamState::Flushed
  self.closed = true
}

///|
pub struct RowStream {
  cells : Array[Cell]
  mut index : Int
}

///|
pub fn RowStream::new(sheet : Worksheet) -> RowStream {
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
