///|
fn flat_sqref(
  sqref : StringView,
) -> Map[Int, Array[(Int, Int)]] raise XlsxError {
  let cells : Map[Int, Array[(Int, Int)]] = {}
  for part in sqref.to_string().split(" ") {
    let text = part.to_string().trim().to_string()
    if text == "" {
      continue
    }
    if text.contains(":") {
      let (min_row, min_col, max_row, max_col) = parse_range_ref(text)
      for col in min_col..<=max_col {
        for row in min_row..<=max_row {
          let entries = match cells.get(col) {
            Some(value) => value
            None => []
          }
          entries.push((col, row))
          cells[col] = entries
        }
      }
    } else {
      let (row, col) = cell_ref_to_rc(text)
      let entries = match cells.get(col) {
        Some(value) => value
        None => []
      }
      entries.push((col, row))
      cells[col] = entries
    }
  }
  for col, entries in cells {
    entries.sort_by((left, right) => {
      let (_, row_left) = left
      let (_, row_right) = right
      row_left - row_right
    })
    cells[col] = entries
  }
  cells
}

///|
fn in_coordinates(cells : Array[(Int, Int)], target : (Int, Int)) -> Int {
  for i, cell in cells {
    if cell == target {
      return i
    }
  }
  -1
}

///|
fn range_ref_from_coords(
  start_cell : (Int, Int),
  end_cell : (Int, Int),
) -> String raise XlsxError {
  let (start_col, start_row) = start_cell
  let (end_col, end_row) = end_cell
  let start_ref = cell_ref_from(start_row, start_col)
  if start_col == end_col && start_row == end_row {
    return start_ref
  }
  let end_ref = cell_ref_from(end_row, end_col)
  "\{start_ref}:\{end_ref}"
}

///|
fn squash_sqref(cells : Array[(Int, Int)]) -> Array[String] raise XlsxError {
  if cells.length() == 0 {
    return []
  }
  if cells.length() == 1 {
    return [range_ref_from_coords(cells[0], cells[0])]
  }
  let refs : Array[String] = []
  let mut start = 0
  let mut end = 0
  for i in 1..<cells.length() {
    let (_, prev_row) = cells[end]
    let (_, row) = cells[i]
    if row - prev_row > 1 {
      refs.push(range_ref_from_coords(cells[start], cells[end]))
      start = i
      end = i
    } else {
      end = i
    }
  }
  refs.push(range_ref_from_coords(cells[start], cells[end]))
  refs
}

///|
fn delete_cells_from_sqref(
  sqref : StringView,
  del_cells : Map[Int, Array[(Int, Int)]],
) -> String raise XlsxError {
  let col_cells = flat_sqref(sqref)
  for col, cells in del_cells {
    match col_cells.get(col) {
      Some(existing) => {
        let updated : Array[(Int, Int)] = []
        for cell in existing {
          if in_coordinates(cells, cell) == -1 {
            updated.push(cell)
          }
        }
        col_cells[col] = updated
      }
      None => ()
    }
  }
  let refs : Array[String] = []
  let cols : Array[Int] = []
  for col, _ in col_cells {
    cols.push(col)
  }
  cols.sort_by((a, b) => a - b)
  for col in cols {
    match col_cells.get(col) {
      Some(entries) => refs.append(squash_sqref(entries)[:])
      None => ()
    }
  }
  refs.join(" ")
}
