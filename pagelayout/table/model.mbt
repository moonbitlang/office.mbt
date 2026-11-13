///|
// Engine input for one table. Frontends translate OOXML `w:tbl` into
// these types; widths stay in their authored form (twips or percent)
// until `resolve_columns` turns them into points against a concrete
// available width.

///|
/// A table or cell width as OOXML authors it (`w:tblW`, `w:tcW`).
#derive(Eq, Debug, ToJson)
pub(all) enum Width {
  /// `w:type="auto"` — size to content within the available space.
  Auto
  /// `w:type="dxa"` — an absolute width in twips.
  Twips(@pagelayout.Twips)
  /// `w:type="pct"` — fiftieths of a percent, as OOXML stores it.
  Percent(Double)
  /// `w:type="nil"` — explicitly zero.
  Nil
}

///|
/// Word's two column-sizing algorithms.
#derive(Eq, Debug, ToJson)
pub(all) enum TableLayout {
  /// `w:tblLayout w:type="fixed"` — honor the grid and cell widths.
  Fixed
  /// The default: widths are hints, and content may widen a column.
  Autofit
}

///|
/// One side of a border. `none` is represented by `Border?::None` at the
/// use site, so a present border always paints.
#derive(Eq, Debug, ToJson)
pub(all) struct Border {
  width : @pagelayout.EighthPoints
  color : @pagelayout.Color
}

///|
/// The four borders of a table or cell.
#derive(Eq, Debug, ToJson)
pub(all) struct Borders {
  top : Border?
  bottom : Border?
  left : Border?
  right : Border?
}

///|
/// No borders on any side.
pub fn Borders::none() -> Borders {
  { top: None, bottom: None, left: None, right: None, }
}

///|
/// Padding inside a cell, between its border and its content.
#derive(Eq, Debug, ToJson)
pub(all) struct CellMargins {
  top : @pagelayout.Twips
  bottom : @pagelayout.Twips
  left : @pagelayout.Twips
  right : @pagelayout.Twips
}

///|
/// Word's default cell padding: 0 vertical, 108 twips (0.075") each side.
pub fn CellMargins::default() -> CellMargins {
  { top: Twips(0), bottom: Twips(0), left: Twips(108), right: Twips(108), }
}

///|
/// How a cell participates in a vertical merge.
#derive(Eq, Debug, ToJson)
pub(all) enum VMerge {
  /// Not merged, or the first row of a merge (`w:vMerge w:val="restart"`).
  VStart
  /// A continuation row (`w:vMerge` with no val, or val="continue").
  VContinue
}

///|
/// One cell. `content` is the block flow inside it; `grid_span` is how
/// many grid columns it covers (`w:gridSpan`).
#derive(Eq, Debug, ToJson)
pub(all) struct Cell {
  content : Array[@paragraph.ParagraphInput]
  width : Width
  grid_span : Int32
  vmerge : VMerge
  borders : Borders
  margins : CellMargins
  shading : @pagelayout.Color?
}

///|
/// A cell with Word's defaults, spanning one column.
pub fn Cell::new(
  content : Array[@paragraph.ParagraphInput],
  width~ : Width = Auto,
  grid_span~ : Int32 = 1,
  vmerge~ : VMerge = VStart,
  borders~ : Borders = Borders::none(),
  margins~ : CellMargins = CellMargins::default(),
  shading~ : @pagelayout.Color? = None,
) -> Cell {
  { content, width, grid_span, vmerge, borders, margins, shading, }
}

///|
/// One row. `header` marks `w:tblHeader` — repeated at the top of each
/// page a split table continues onto.
#derive(Eq, Debug, ToJson)
pub(all) struct Row {
  cells : Array[Cell]
  header : Bool
  /// `w:cantSplit` — keep the row's lines together on one page.
  cant_split : Bool
  /// `w:trHeight w:hRule="atLeast"` minimum, if any.
  min_height : @pagelayout.Twips?
}

///|
/// A row of cells, with Word's defaults.
pub fn Row::new(
  cells : Array[Cell],
  header~ : Bool = false,
  cant_split~ : Bool = false,
  min_height~ : @pagelayout.Twips? = None,
) -> Row {
  { cells, header, cant_split, min_height, }
}

///|
/// A whole table. `grid` is `w:tblGrid`: the authored width of each grid
/// column, which fixed layout honors and autofit treats as a hint.
#derive(Eq, Debug, ToJson)
pub(all) struct Table {
  rows : Array[Row]
  grid : Array[@pagelayout.Twips]
  width : Width
  layout : TableLayout
  borders : Borders
  indent : @pagelayout.Twips
}

///|
/// A table with Word's defaults: autofit, no borders, no indent.
pub fn Table::new(
  rows : Array[Row],
  grid~ : Array[@pagelayout.Twips] = [],
  width~ : Width = Auto,
  layout~ : TableLayout = Autofit,
  borders~ : Borders = Borders::none(),
  indent~ : @pagelayout.Twips = Twips(0),
) -> Table {
  { rows, grid, width, layout, borders, indent, }
}

///|
/// The number of grid columns the table actually uses: the wider of the
/// authored grid and the widest row's total span, so a row that spans
/// past the declared grid still gets columns.
pub fn Table::column_count(self : Table) -> Int32 {
  let mut widest = self.grid.length()
  for row in self.rows {
    let mut span = 0
    for cell in row.cells {
      span += if cell.grid_span < 1 { 1 } else { cell.grid_span }
    }
    if span > widest {
      widest = span
    }
  }
  widest
}
