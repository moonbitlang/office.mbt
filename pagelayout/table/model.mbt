///|
// Engine input for one table. Frontends translate OOXML `w:tbl` into
// these types; widths stay in their authored form (twips or percent)
// until `resolve_columns` turns them into points against a concrete
// available width.

///|
/// A table or cell width as OOXML authors it (`w:tblW`, `w:tcW`).
pub(all) enum Width {
  /// `w:type="auto"` — size to content within the available space.
  Auto
  /// `w:type="dxa"` — an absolute width in twips.
  Twips(@pagelayout.Twips)
  /// `w:type="pct"` — fiftieths of a percent, as OOXML stores it.
  Percent(Double)
  /// `w:type="nil"` — explicitly zero.
  Nil
} derive(Eq, Debug, ToJson)

///|
/// Word's two column-sizing algorithms.
pub(all) enum TableLayout {
  /// `w:tblLayout w:type="fixed"` — honor the grid and cell widths.
  Fixed
  /// The default: widths are hints, and content may widen a column.
  Autofit
} derive(Eq, Debug, ToJson)

///|
/// One side of a border. `none` is represented by `Border?::None` at the
/// use site, so a present border always paints.
pub(all) struct Border {
  width : @pagelayout.EighthPoints
  color : @pagelayout.Color
} derive(Eq, Debug, ToJson)

///|
/// The four borders of a table or cell.
pub(all) struct Borders {
  top : Border?
  bottom : Border?
  left : Border?
  right : Border?
} derive(Eq, Debug, ToJson)

///|
/// No borders on any side.
pub fn Borders::none() -> Borders {
  { top: None, bottom: None, left: None, right: None, }
}

///|
/// Padding inside a cell, between its border and its content.
pub(all) struct CellMargins {
  top : @pagelayout.Twips
  bottom : @pagelayout.Twips
  left : @pagelayout.Twips
  right : @pagelayout.Twips
} derive(Eq, Debug, ToJson)

///|
/// Word's default cell padding: 0 vertical, 108 twips (0.075") each side.
pub fn CellMargins::default() -> CellMargins {
  { top: Twips(0), bottom: Twips(0), left: Twips(108), right: Twips(108), }
}

///|
/// How a cell participates in a vertical merge.
pub(all) enum VMerge {
  /// Not merged, or the first row of a merge (`w:vMerge w:val="restart"`).
  VStart
  /// A continuation row (`w:vMerge` with no val, or val="continue").
  VContinue
} derive(Eq, Debug, ToJson)

///|
/// One cell. `content` is the block flow inside it; `grid_span` is how
/// many grid columns it covers (`w:gridSpan`).
pub(all) struct Cell {
  content : Array[@paragraph.ParagraphInput]
  width : Width
  grid_span : Int
  vmerge : VMerge
  borders : Borders
  margins : CellMargins
  shading : @pagelayout.Color?
} derive(Eq, Debug, ToJson)

///|
/// A cell with Word's defaults, spanning one column.
pub fn Cell::new(
  content : Array[@paragraph.ParagraphInput],
  width? : Width = Auto,
  grid_span? : Int = 1,
  vmerge? : VMerge = VStart,
  borders? : Borders = Borders::none(),
  margins? : CellMargins = CellMargins::default(),
  shading? : @pagelayout.Color? = None,
) -> Cell {
  { content, width, grid_span, vmerge, borders, margins, shading, }
}

///|
/// One row. `header` marks `w:tblHeader` — repeated at the top of each
/// page a split table continues onto.
pub(all) struct Row {
  cells : Array[Cell]
  header : Bool
  /// `w:cantSplit` — keep the row's lines together on one page.
  cant_split : Bool
  /// `w:trHeight w:hRule="atLeast"` minimum, if any.
  min_height : @pagelayout.Twips?
} derive(Eq, Debug, ToJson)

///|
/// A row of cells, with Word's defaults.
pub fn Row::new(
  cells : Array[Cell],
  header? : Bool = false,
  cant_split? : Bool = false,
  min_height? : @pagelayout.Twips? = None,
) -> Row {
  { cells, header, cant_split, min_height, }
}

///|
/// A whole table. `grid` is `w:tblGrid`: the authored width of each grid
/// column, which fixed layout honors and autofit treats as a hint.
pub(all) struct Table {
  rows : Array[Row]
  grid : Array[@pagelayout.Twips]
  width : Width
  layout : TableLayout
  borders : Borders
  indent : @pagelayout.Twips
} derive(Eq, Debug, ToJson)

///|
/// A table with Word's defaults: autofit, no borders, no indent.
pub fn Table::new(
  rows : Array[Row],
  grid? : Array[@pagelayout.Twips] = [],
  width? : Width = Auto,
  layout? : TableLayout = Autofit,
  borders? : Borders = Borders::none(),
  indent? : @pagelayout.Twips = Twips(0),
) -> Table {
  { rows, grid, width, layout, borders, indent, }
}

///|
/// The number of grid columns the table actually uses: the wider of the
/// authored grid and the widest row's total span, so a row that spans
/// past the declared grid still gets columns.
pub fn Table::column_count(self : Table) -> Int {
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
