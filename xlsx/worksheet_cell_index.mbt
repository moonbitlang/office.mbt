///|
fn cell_index_key(row : Int, col : Int) -> String {
  "\{row}:\{col}"
}

///|
fn Worksheet::invalidate_cell_index(self : Worksheet) -> Unit {
  self.cell_index_valid = false
}

///|
fn Worksheet::ensure_cell_index(self : Worksheet) -> Unit {
  if self.cell_index_valid {
    return
  }
  self.cell_index.clear()
  for i, cell in self.cells {
    self.cell_index[cell_index_key(cell.row, cell.col)] = i
  }
  self.cell_index_valid = true
}

///|
fn Worksheet::cell_index_of(self : Worksheet, row : Int, col : Int) -> Int? {
  self.ensure_cell_index()
  self.cell_index.get(cell_index_key(row, col))
}

///|
fn Worksheet::record_cell_index_if_valid(
  self : Worksheet,
  row : Int,
  col : Int,
  index : Int,
) -> Unit {
  if self.cell_index_valid {
    self.cell_index[cell_index_key(row, col)] = index
  }
}
