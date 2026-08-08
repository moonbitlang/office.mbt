///|
// Column width resolution. OOXML gives three sources of truth that can
// disagree — `w:tblGrid`, each cell's `w:tcW`, and the table's own
// `w:tblW` — and two algorithms for reconciling them. This resolves them
// into one point width per grid column, which the layout pass then treats
// as fact.

///|
/// Convert an authored width to points against `available_pt`, or None
/// when the width does not determine a size on its own (`Auto`).
fn width_pt(w : Width, available_pt : Double) -> Double? {
  match w {
    Auto => None
    Nil => Some(0.0)
    Twips(t) => Some(t.to_pt())
    // OOXML percent is in fiftieths of a percent: 5000 == 100%
    Percent(p) => Some(available_pt * p / 5000.0)
  }
}

///|
/// The table's own outer width, in points.
pub fn Table::width_pt(self : Table, available_pt : Double) -> Double {
  let usable = available_pt - self.indent.to_pt()
  match width_pt(self.width, available_pt) {
    Some(w) if w > 0.0 => if w < usable { w } else { usable }
    // auto/nil tables take the full measure, as Word does for a table
    // with no explicit width
    _ => usable
  }
}

///|
/// Per-column widths in points, one entry per grid column.
///
/// Fixed layout honors the authored grid, scaled to the table width.
/// Autofit starts from the grid, fills unspecified columns from what is
/// left, and then scales the result to the table width — Word's
/// behavior for a table whose grid and cell widths disagree.
///
/// Cell `w:tcW` values refine the grid for the columns a cell covers,
/// which matters when the grid is absent (some generators omit it).
/// Columns that no source sizes share the remainder equally; if nothing
/// is left, every column falls back to an equal share so a table always
/// has positive widths.
pub fn Table::resolve_columns(
  self : Table,
  available_pt : Double,
) -> Array[Double] {
  let count = self.column_count()
  if count == 0 {
    return []
  }
  let table_pt = self.width_pt(available_pt)
  let widths : Array[Double?] = Array::make(count, None)

  // 1. the authored grid
  for i in 0..<count {
    if i < self.grid.length() {
      let pt = self.grid[i].to_pt()
      if pt > 0.0 {
        widths[i] = Some(pt)
      }
    }
  }

  // 2. cell widths, for columns the grid left unsized. A cell spanning
  //    several columns only speaks for them if none is sized yet, and
  //    then divides its width evenly across them.
  for row in self.rows {
    let mut column = 0
    for cell in row.cells {
      let span = if cell.grid_span < 1 { 1 } else { cell.grid_span }
      if column >= count {
        break
      }
      let last = if column + span > count { count } else { column + span }
      match width_pt(cell.width, table_pt) {
        Some(pt) if pt > 0.0 => {
          let mut all_unsized = true
          for i in column..<last {
            if widths[i] is Some(_) {
              all_unsized = false
            }
          }
          if all_unsized {
            let each = pt / (last - column).to_double()
            for i in column..<last {
              widths[i] = Some(each)
            }
          }
        }
        _ => ()
      }
      column = last
    }
  }

  // 3. share what is left among still-unsized columns
  let mut assigned = 0.0
  let mut unsized = 0
  for w in widths {
    match w {
      Some(pt) => assigned += pt
      None => unsized += 1
    }
  }
  if unsized > 0 {
    let remaining = table_pt - assigned
    let each = if remaining > 0.0 {
      remaining / unsized.to_double()
    } else {
      // nothing left: fall back to an equal share so no column is zero
      table_pt / count.to_double()
    }
    for i in 0..<count {
      if widths[i] is None {
        widths[i] = Some(each)
      }
    }
  }

  // 4. scale to the table width. Fixed layout scales only when the grid
  //    overflows; autofit always normalizes, since its inputs are hints.
  let resolved : Array[Double] = []
  let mut total = 0.0
  for w in widths {
    let pt = match w {
      Some(v) => if v < 0.0 { 0.0 } else { v }
      None => 0.0
    }
    resolved.push(pt)
    total += pt
  }
  if total <= 0.0 {
    let each = table_pt / count.to_double()
    for i in 0..<count {
      resolved[i] = each
    }
    return resolved
  }
  let should_scale = match self.layout {
    Autofit => true
    Fixed => total > table_pt
  }
  if should_scale {
    let factor = table_pt / total
    for i in 0..<count {
      resolved[i] = resolved[i] * factor
    }
  }
  resolved
}

///|
/// The point width of the columns a cell covers, starting at grid column
/// `column`. Spans past the grid are clamped to what exists.
pub fn cell_span_pt(
  columns : Array[Double],
  column : Int,
  grid_span : Int,
) -> Double {
  let span = if grid_span < 1 { 1 } else { grid_span }
  let last = if column + span > columns.length() {
    columns.length()
  } else {
    column + span
  }
  let mut width = 0.0
  for i in column..<last {
    width += columns[i]
  }
  width
}

///|
/// The horizontal offset of grid column `column` from the table's left
/// edge, in points.
pub fn column_offset_pt(columns : Array[Double], column : Int) -> Double {
  let last = if column > columns.length() { columns.length() } else { column }
  let mut x = 0.0
  for i in 0..<last {
    x += columns[i]
  }
  x
}
