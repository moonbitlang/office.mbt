///|
pub struct Cell {
  reference : String
  row : Int
  col : Int
  value : String
  value_type : CellValueType
  rich_text : Array[RichTextRun]?
  formula : String?
  formula_type : FormulaType?
  formula_ref : String?
  formula_shared_index : Int?
  style_id : Int
}

///|
pub struct Image {
  reference : String
  data : Bytes
  extension : String
  content_type : String
  offset_x : Int
  offset_y : Int
  scale_x : Double
  scale_y : Double
  width_emu : Int
  height_emu : Int
  print_object : Bool
  locked : Bool
  hyperlink : String
  hyperlink_type : HyperlinkType
  name : String
  alt_text : String
  lock_aspect_ratio : Bool
  positioning : PicturePositioning
}

///|
pub struct Chart {
  reference : String
  xml : String
  offset_x : Int
  offset_y : Int
  width_emu : Int
  height_emu : Int
  print_object : Bool
  locked : Bool
  positioning : PicturePositioning
}

///|
pub enum SheetState {
  Visible
  Hidden
  VeryHidden
} derive(Eq, Debug)

///|
pub struct RowDimension {
  height : Double?
  hidden : Bool
  outline_level : Int
  style_id : Int?
}

///|
pub struct ColDimension {
  width : Double?
  hidden : Bool
  outline_level : Int
  style_id : Int?
}

///|
pub struct Worksheet {
  mut name : String
  sheet_views : Array[SheetView]
  mut dimension_ref : String?
  cells : Array[Cell]
  cell_index : Map[String, Int]
  mut cell_index_valid : Bool
  merged_cells : Array[String]
  hyperlinks : Array[Hyperlink]
  tables : Array[Table]
  sparkline_groups : Array[SparklineGroup]
  pivot_tables : Array[PivotTable]
  images : Array[Image]
  header_footer_images : Array[HeaderFooterImage]
  charts : Array[Chart]
  shapes : Array[Shape]
  form_controls : Array[FormControl]
  slicers : Array[Slicer]
  data_validations : Array[String]
  conditional_formats : Array[String]
  x14_data_bars : Map[String, X14DataBarProps]
  unknown_ext_blocks : Array[String]
  mut x14_cf_rule_id_counter : Int
  ignored_errors : Array[IgnoredError]
  comments : Array[Comment]
  mut auto_filter : AutoFilter?
  mut page_margins : PageLayoutMarginsOptions?
  mut page_layout : PageLayoutOptions?
  mut header_footer : HeaderFooterOptions?
  mut sheet_protection : SheetProtection?
  mut sheet_props : SheetPropsOptions?
  mut sheet_background : SheetBackground?
  row_breaks : Array[PageBreak]
  col_breaks : Array[PageBreak]
  row_dimensions : Map[Int, RowDimension]
  col_dimensions : Map[Int, ColDimension]
  mut state : SheetState
  mut stream_state : StreamState
  mut vml_drawing_xml : String?
  mut vml_drawing_hf_xml : String?
  /// Cell value-metadata (`vm`) indices captured on read, keyed by
  /// canonical cell reference. Links a cell to its rich-value embedded
  /// image; lives on the worksheet so it survives rename/copy/delete.
  cell_vm : Map[String, Int]
}

///|
pub fn Worksheet::new(name : String) -> Worksheet {
  {
    name,
    sheet_views: [],
    dimension_ref: None,
    cells: [],
    cell_index: Map([]),
    cell_index_valid: false,
    merged_cells: [],
    hyperlinks: [],
    tables: [],
    sparkline_groups: [],
    pivot_tables: [],
    images: [],
    header_footer_images: [],
    charts: [],
    shapes: [],
    form_controls: [],
    slicers: [],
    data_validations: [],
    conditional_formats: [],
    x14_data_bars: Map([]),
    unknown_ext_blocks: [],
    x14_cf_rule_id_counter: 1,
    ignored_errors: [],
    comments: [],
    auto_filter: None,
    page_margins: None,
    page_layout: None,
    header_footer: None,
    sheet_protection: None,
    sheet_props: None,
    sheet_background: None,
    row_breaks: [],
    col_breaks: [],
    row_dimensions: Map([]),
    col_dimensions: Map([]),
    state: Visible,
    stream_state: Idle,
    vml_drawing_xml: None,
    vml_drawing_hf_xml: None,
    cell_vm: Map([]),
  }
}

///|
pub fn Worksheet::name(self : Worksheet) -> String {
  self.name
}

///|
pub fn Worksheet::state(self : Worksheet) -> SheetState {
  self.state
}

///|
fn Worksheet::cells(self : Worksheet) -> ArrayView[Cell] {
  self.cells
}

///|
pub fn Worksheet::merged_cells(self : Worksheet) -> ArrayView[String] {
  self.merged_cells
}

///|
fn Worksheet::hyperlinks(self : Worksheet) -> ArrayView[Hyperlink] {
  self.hyperlinks
}

///|
pub fn Worksheet::tables(self : Worksheet) -> ArrayView[Table] {
  self.tables
}

///|
pub fn Worksheet::sparkline_groups(
  self : Worksheet,
) -> ArrayView[SparklineGroup] {
  self.sparkline_groups
}

///|
pub fn Worksheet::pivot_tables(self : Worksheet) -> ArrayView[PivotTable] {
  self.pivot_tables
}

///|
pub fn Worksheet::images(self : Worksheet) -> ArrayView[Image] {
  self.images
}

///|
pub fn Worksheet::charts(self : Worksheet) -> ArrayView[Chart] {
  self.charts
}

///|
pub fn Worksheet::shapes(self : Worksheet) -> ArrayView[Shape] {
  self.shapes
}

///|
fn Worksheet::form_controls(self : Worksheet) -> ArrayView[FormControl] {
  self.form_controls
}

///|
/// Returns the slicers attached to this worksheet in stored order.
pub fn Worksheet::slicers(self : Worksheet) -> ArrayView[Slicer] {
  self.slicers
}

///|
pub fn Worksheet::data_validations(self : Worksheet) -> ArrayView[String] {
  self.data_validations
}

///|
pub fn Worksheet::conditional_formats(self : Worksheet) -> ArrayView[String] {
  self.conditional_formats
}

///|
pub fn Worksheet::ignored_errors(self : Worksheet) -> ArrayView[IgnoredError] {
  self.ignored_errors
}

///|
pub fn Worksheet::comments(self : Worksheet) -> ArrayView[Comment] {
  self.comments
}

///|
pub fn Worksheet::auto_filter(self : Worksheet) -> AutoFilter? {
  match self.auto_filter {
    Some(filter) => Some(clone_auto_filter(filter))
    None => None
  }
}

///|
fn Worksheet::page_margins(self : Worksheet) -> PageLayoutMarginsOptions {
  page_margins_with_defaults(self.page_margins)
}

///|
fn Worksheet::page_layout(self : Worksheet) -> PageLayoutOptions {
  page_layout_with_defaults(self.page_layout)
}

///|
fn Worksheet::header_footer(self : Worksheet) -> HeaderFooterOptions? {
  self.header_footer
}

///|
pub fn Worksheet::get_header_footer_images(
  self : Worksheet,
) -> Array[HeaderFooterImageOptions] {
  let images : Array[HeaderFooterImageOptions] = []
  for image in self.header_footer_images {
    images.push(
      HeaderFooterImageOptions::new(
        image.position,
        image.data,
        image.extension,
        is_footer=image.is_footer,
        first_page=image.first_page,
        width=image.width,
        height=image.height,
      ),
    )
  }
  images
}

///|
pub fn Worksheet::sheet_protection(self : Worksheet) -> SheetProtection? {
  self.sheet_protection
}

///|
fn Worksheet::sheet_props(self : Worksheet) -> SheetPropsOptions {
  sheet_props_with_defaults(self.sheet_props)
}

///|
pub fn Worksheet::sheet_background(self : Worksheet) -> SheetBackground? {
  self.sheet_background
}

///|
pub fn Worksheet::row_breaks(self : Worksheet) -> ArrayView[PageBreak] {
  self.row_breaks
}

///|
pub fn Worksheet::col_breaks(self : Worksheet) -> ArrayView[PageBreak] {
  self.col_breaks
}

///|
pub fn Worksheet::vml_drawing_xml(self : Worksheet) -> String? {
  self.vml_drawing_xml
}

///|
pub fn Worksheet::vml_drawing_hf_xml(self : Worksheet) -> String? {
  self.vml_drawing_hf_xml
}
