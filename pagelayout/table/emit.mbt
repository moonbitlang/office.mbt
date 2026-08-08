///|
// Turning a laid-out table into page-model items. Painter's order
// matters: shading first, then borders, then text on top, so a cell's
// fill never covers its own content.

///|
/// Emit one row's items at absolute `(origin_x, origin_y)`, interning
/// fonts into `model`. `row_top` is the row's y within the table.
fn emit_row(
  model : @pagelayout.PageModel,
  items : Array[@pagelayout.PageItem],
  row : PlacedRow,
  origin_x : Double,
  row_top : Double,
) -> Unit {
  // 1. shading, beneath everything
  for cell in row.cells {
    match cell.shading {
      Some(color) =>
        items.push(
          Rect({
            x_pt: origin_x + cell.x_pt,
            y_pt: row_top,
            w_pt: cell.width_pt,
            h_pt: row.height_pt,
            fill: Some(color),
            stroke: None,
            stroke_w_pt: 0,
          }),
        )
      None => ()
    }
  }
  // 2. borders as thin filled rects — the IR has no stroked-line
  //    primitive, and a filled rect renders identically in every backend
  for cell in row.cells {
    let left = origin_x + cell.x_pt
    let right = left + cell.width_pt
    let top = row_top
    let bottom = row_top + row.height_pt
    emit_border(items, cell.borders.top, left, top, right - left, true)
    emit_border(items, cell.borders.bottom, left, bottom, right - left, true)
    emit_border(items, cell.borders.left, left, top, bottom - top, false)
    emit_border(items, cell.borders.right, right, top, bottom - top, false)
  }
  // 3. content
  for cell in row.cells {
    let content_x = origin_x + cell.x_pt + cell.margins.left.to_pt()
    let content_y = row_top + cell.margins.top.to_pt()
    for line in cell.lines {
      for run in line.runs {
        let font = model.add_font(run.font)
        items.push(
          Text({
            font,
            size_pt: run.size_pt,
            x_pt: content_x + run.x_pt,
            baseline_pt: content_y + line.baseline_pt,
            text: run.text,
            advances_pt: run.advances_pt,
            color: run.color,
          }),
        )
      }
    }
  }
}

///|
/// A border edge, centered on the cell boundary like Word draws it.
/// `horizontal` picks which axis `length` runs along.
fn emit_border(
  items : Array[@pagelayout.PageItem],
  border : Border?,
  x : Double,
  y : Double,
  length : Double,
  horizontal : Bool,
) -> Unit {
  guard border is Some(b) else { return }
  let thickness = b.width.to_pt()
  if thickness <= 0.0 || length <= 0.0 {
    return
  }
  let half = thickness / 2.0
  let rect = if horizontal {
    @pagelayout.RectItem::{
      x_pt: x,
      y_pt: y - half,
      w_pt: length,
      h_pt: thickness,
      fill: Some(b.color),
      stroke: None,
      stroke_w_pt: 0,
    }
  } else {
    {
      x_pt: x - half,
      y_pt: y,
      w_pt: thickness,
      h_pt: length,
      fill: Some(b.color),
      stroke: None,
      stroke_w_pt: 0,
    }
  }
  items.push(Rect(rect))
}

///|
/// Emit the rows `[first, last)` of a laid-out table at absolute
/// `(origin_x, origin_y)`, with the table's own row offsets rebased so a
/// continuation on a later page starts at the given origin. Header rows
/// are emitted first when `repeat_header` is set.
pub fn emit_rows(
  model : @pagelayout.PageModel,
  layout : TableLayoutResult,
  origin_x : Double,
  origin_y : Double,
  first : Int,
  last : Int,
  repeat_header? : Bool = false,
) -> Array[@pagelayout.PageItem] {
  let items : Array[@pagelayout.PageItem] = []
  let mut y = origin_y
  if repeat_header && first > 0 {
    for row in layout.rows {
      if !row.header {
        break
      }
      emit_row(model, items, row, origin_x, y)
      y += row.height_pt
    }
  }
  for i in first..<last {
    if i >= layout.rows.length() {
      break
    }
    let row = layout.rows[i]
    emit_row(model, items, row, origin_x, y)
    y += row.height_pt
  }
  items
}

///|
/// Total height of rows `[first, last)`, plus repeated headers when a
/// continuation would carry them.
pub fn rows_height_pt(
  layout : TableLayoutResult,
  first : Int,
  last : Int,
  repeat_header? : Bool = false,
) -> Double {
  let mut height = 0.0
  if repeat_header && first > 0 {
    for row in layout.rows {
      if !row.header {
        break
      }
      height += row.height_pt
    }
  }
  for i in first..<last {
    if i >= layout.rows.length() {
      break
    }
    height += layout.rows[i].height_pt
  }
  height
}
