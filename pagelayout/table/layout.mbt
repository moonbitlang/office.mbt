///|
// Table layout: resolve columns, lay each cell's paragraphs out at its
// own width, then stack rows whose height is set by the tallest cell.
// The result is table-relative (x from the table's left edge, y from its
// top) so pagination can place it like any other block.

///|
/// One laid-out cell: where it sits in the table and the lines inside it.
pub(all) struct PlacedCell {
  x_pt : Double
  width_pt : Double
  /// Content height, excluding the cell's own top/bottom margins.
  content_height_pt : Double
  lines : Array[@paragraph.LineBox]
  borders : Borders
  margins : CellMargins
  shading : @pagelayout.Color?
  /// Grid columns this cell covers, for border and merge geometry.
  column : Int
  grid_span : Int
} derive(Eq, Debug, ToJson)

///|
/// One laid-out row, positioned from the table's top edge.
pub(all) struct PlacedRow {
  y_pt : Double
  height_pt : Double
  cells : Array[PlacedCell]
  header : Bool
  cant_split : Bool
} derive(Eq, Debug, ToJson)

///|
/// A fully laid-out table, table-relative.
pub(all) struct TableLayoutResult {
  width_pt : Double
  height_pt : Double
  columns : Array[Double]
  rows : Array[PlacedRow]
} derive(Eq, Debug, ToJson)

///|
/// Lay a cell's paragraphs out at `inner_width`, stacking them, and
/// return the lines with their paragraph offsets folded in plus the
/// total content height.
fn layout_cell_content(
  content : Array[@paragraph.ParagraphInput],
  inner_width : Double,
) -> (Array[@paragraph.LineBox], Double) {
  let lines : Array[@paragraph.LineBox] = []
  let mut y = 0.0
  for input in content {
    let laid = @paragraph.layout_paragraph(input, inner_width)
    for line in laid.lines {
      lines.push({
        baseline_pt: y + line.baseline_pt,
        height_pt: line.height_pt,
        runs: line.runs,
      })
    }
    y += laid.height_pt
  }
  (lines, y)
}

///|
/// Lay out `table` into `available_pt` of horizontal space.
///
/// Row height is the tallest cell's content plus that cell's vertical
/// margins, floored by `w:trHeight`. Vertically-merged continuation
/// cells (`w:vMerge` without restart) contribute no content and no
/// height: their space belongs to the cell that started the merge.
pub fn layout_table(table : Table, available_pt : Double) -> TableLayoutResult {
  let columns = table.resolve_columns(available_pt)
  let rows : Array[PlacedRow] = []
  let mut y = 0.0
  for row in table.rows {
    let placed : Array[PlacedCell] = []
    let mut column = 0
    let mut tallest = 0.0
    for cell in row.cells {
      if column >= columns.length() {
        break
      }
      let span = if cell.grid_span < 1 { 1 } else { cell.grid_span }
      let width = cell_span_pt(columns, column, span)
      let x = column_offset_pt(columns, column)
      let inner = width - cell.margins.left.to_pt() - cell.margins.right.to_pt()
      let (lines, content_height) = match cell.vmerge {
        // a continuation cell shows nothing; the merge's first row owns
        // the content
        VContinue => ([], 0.0)
        VStart =>
          if inner > 0.0 {
            layout_cell_content(cell.content, inner)
          } else {
            ([], 0.0)
          }
      }
      let occupied = content_height +
        cell.margins.top.to_pt() +
        cell.margins.bottom.to_pt()
      if occupied > tallest {
        tallest = occupied
      }
      placed.push({
        x_pt: x,
        width_pt: width,
        content_height_pt: content_height,
        lines,
        borders: cell.borders,
        margins: cell.margins,
        shading: cell.shading,
        column,
        grid_span: span,
      })
      column += span
    }
    let height = match row.min_height {
      Some(min) if min.to_pt() > tallest => min.to_pt()
      _ => tallest
    }
    rows.push({
      y_pt: y,
      height_pt: height,
      cells: placed,
      header: row.header,
      cant_split: row.cant_split,
    })
    y += height
  }
  let mut width = 0.0
  for c in columns {
    width += c
  }
  { width_pt: width, height_pt: y, columns, rows, }
}
