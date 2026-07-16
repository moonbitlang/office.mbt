///|
pub struct Selection {
  mut sqref : String
  mut active_cell : String
  mut pane : String
} derive(Debug)

///|
fn Selection::new() -> Selection {
  { sqref: "", active_cell: "", pane: "" }
}

///|
pub fn Selection::with_values(
  sqref? : String,
  active_cell? : String,
  pane? : String,
) -> Selection {
  let selection = Selection::new()
  match sqref {
    Some(value) => selection.sqref = value
    None => ()
  }
  match active_cell {
    Some(value) => selection.active_cell = value
    None => ()
  }
  match pane {
    Some(value) => selection.pane = value
    None => ()
  }
  selection
}

///|
pub struct Panes {
  mut freeze : Bool
  mut split : Bool
  mut x_split : Int
  mut y_split : Int
  mut top_left_cell : String
  mut active_pane : String
  mut selection : Array[Selection]
} derive(Debug)

///|
pub fn Panes::new() -> Panes {
  {
    freeze: false,
    split: false,
    x_split: 0,
    y_split: 0,
    top_left_cell: "",
    active_pane: "",
    selection: [],
  }
}

///|
pub fn Panes::with_values(
  freeze? : Bool,
  split? : Bool,
  x_split? : Int,
  y_split? : Int,
  top_left_cell? : String,
  active_pane? : String,
  selection? : Array[Selection],
) -> Panes {
  let panes = Panes::new()
  match freeze {
    Some(value) => panes.freeze = value
    None => ()
  }
  match split {
    Some(value) => panes.split = value
    None => ()
  }
  match x_split {
    Some(value) => panes.x_split = value
    None => ()
  }
  match y_split {
    Some(value) => panes.y_split = value
    None => ()
  }
  match top_left_cell {
    Some(value) => panes.top_left_cell = value
    None => ()
  }
  match active_pane {
    Some(value) => panes.active_pane = value
    None => ()
  }
  match selection {
    Some(value) => panes.selection = value
    None => ()
  }
  panes
}

///|
pub struct SheetViewOptions {
  mut default_grid_color : Bool?
  mut right_to_left : Bool?
  mut show_formulas : Bool?
  mut show_grid_lines : Bool?
  mut show_row_col_headers : Bool?
  mut show_ruler : Bool?
  mut show_zeros : Bool?
  mut top_left_cell : String?
  mut view : String?
  mut zoom_scale : Double?
} derive(Debug)

///|
pub type ViewOptions = SheetViewOptions

///|
pub fn SheetViewOptions::new() -> SheetViewOptions {
  {
    default_grid_color: None,
    right_to_left: None,
    show_formulas: None,
    show_grid_lines: None,
    show_row_col_headers: None,
    show_ruler: None,
    show_zeros: None,
    top_left_cell: None,
    view: None,
    zoom_scale: None,
  }
}

///|
pub fn SheetViewOptions::with_values(
  default_grid_color? : Bool,
  right_to_left? : Bool,
  show_formulas? : Bool,
  show_grid_lines? : Bool,
  show_row_col_headers? : Bool,
  show_ruler? : Bool,
  show_zeros? : Bool,
  top_left_cell? : String,
  view? : String,
  zoom_scale? : Double,
) -> SheetViewOptions {
  let opts = SheetViewOptions::new()
  match default_grid_color {
    Some(value) => opts.default_grid_color = Some(value)
    None => ()
  }
  match right_to_left {
    Some(value) => opts.right_to_left = Some(value)
    None => ()
  }
  match show_formulas {
    Some(value) => opts.show_formulas = Some(value)
    None => ()
  }
  match show_grid_lines {
    Some(value) => opts.show_grid_lines = Some(value)
    None => ()
  }
  match show_row_col_headers {
    Some(value) => opts.show_row_col_headers = Some(value)
    None => ()
  }
  match show_ruler {
    Some(value) => opts.show_ruler = Some(value)
    None => ()
  }
  match show_zeros {
    Some(value) => opts.show_zeros = Some(value)
    None => ()
  }
  match top_left_cell {
    Some(value) => opts.top_left_cell = Some(value)
    None => ()
  }
  match view {
    Some(value) => opts.view = Some(value)
    None => ()
  }
  match zoom_scale {
    Some(value) => opts.zoom_scale = Some(value)
    None => ()
  }
  opts
}

///|
struct SheetPane {
  mut active_pane : String
  mut state : String
  mut top_left_cell : String
  mut x_split : Double
  mut y_split : Double
} derive(Debug)

///|
struct SheetView {
  mut default_grid_color : Bool?
  mut right_to_left : Bool?
  mut show_formulas : Bool?
  mut show_grid_lines : Bool?
  mut show_row_col_headers : Bool?
  mut show_ruler : Bool?
  mut show_zeros : Bool?
  mut top_left_cell : String?
  mut view : String?
  mut zoom_scale : Double?
  mut tab_selected : Bool
  mut workbook_view_id : Int
  mut pane : SheetPane?
  selection : Array[Selection]
} derive(Debug)

///|
let supported_sheet_view_modes : Array[String] = [
  "normal", "pageLayout", "pageBreakPreview",
]

///|
fn default_sheet_view_options() -> SheetViewOptions {
  SheetViewOptions::with_values(
    default_grid_color=true,
    right_to_left=false,
    show_formulas=true,
    show_grid_lines=true,
    show_row_col_headers=true,
    show_ruler=true,
    show_zeros=true,
    top_left_cell="A1",
    view="normal",
    zoom_scale=100.0,
  )
}

///|
fn SheetView::new() -> SheetView {
  {
    default_grid_color: None,
    right_to_left: None,
    show_formulas: None,
    show_grid_lines: None,
    show_row_col_headers: None,
    show_ruler: None,
    show_zeros: None,
    top_left_cell: None,
    view: None,
    zoom_scale: None,
    tab_selected: false,
    workbook_view_id: 0,
    pane: None,
    selection: [],
  }
}

///|
fn SheetPane::new() -> SheetPane {
  { active_pane: "", state: "", top_left_cell: "", x_split: 0.0, y_split: 0.0 }
}

///|
fn normalize_sheet_view_mode(mode : StringView) -> String? {
  let needle = mode.to_owned().to_lower()
  for supported in supported_sheet_view_modes {
    if supported.to_lower() == needle {
      return Some(supported)
    }
  }
  None
}

///|
fn apply_sheet_view_options(
  view : SheetView,
  options : SheetViewOptions,
) -> Unit raise XlsxError {
  match options.default_grid_color {
    Some(value) => view.default_grid_color = Some(value)
    None => ()
  }
  match options.right_to_left {
    Some(value) => view.right_to_left = Some(value)
    None => ()
  }
  match options.show_formulas {
    Some(value) => view.show_formulas = Some(value)
    None => ()
  }
  match options.show_grid_lines {
    Some(value) => view.show_grid_lines = Some(value)
    None => ()
  }
  match options.show_row_col_headers {
    Some(value) => view.show_row_col_headers = Some(value)
    None => ()
  }
  match options.show_ruler {
    Some(value) => view.show_ruler = Some(value)
    None => ()
  }
  match options.show_zeros {
    Some(value) => view.show_zeros = Some(value)
    None => ()
  }
  match options.top_left_cell {
    Some(value) =>
      view.top_left_cell = Some(normalize_cell_ref_for_write(value))
    None => ()
  }
  match options.view {
    Some(value) =>
      match normalize_sheet_view_mode(value) {
        Some(normalized) => view.view = Some(normalized)
        None => ()
      }
    None => ()
  }
  match options.zoom_scale {
    Some(value) =>
      if value >= 10.0 && value <= 400.0 {
        view.zoom_scale = Some(value)
      }
    None => ()
  }
}

///|
fn sheet_view_options_with_defaults(view : SheetView) -> SheetViewOptions {
  let merged = default_sheet_view_options()
  match view.default_grid_color {
    Some(value) => merged.default_grid_color = Some(value)
    None => ()
  }
  match view.right_to_left {
    Some(value) => merged.right_to_left = Some(value)
    None => ()
  }
  match view.show_formulas {
    Some(value) => merged.show_formulas = Some(value)
    None => ()
  }
  match view.show_grid_lines {
    Some(value) => merged.show_grid_lines = Some(value)
    None => ()
  }
  match view.show_row_col_headers {
    Some(value) => merged.show_row_col_headers = Some(value)
    None => ()
  }
  match view.show_ruler {
    Some(value) => merged.show_ruler = Some(value)
    None => ()
  }
  match view.show_zeros {
    Some(value) => merged.show_zeros = Some(value)
    None => ()
  }
  match view.top_left_cell {
    Some(value) => merged.top_left_cell = Some(value)
    None => ()
  }
  match view.view {
    Some(value) => merged.view = Some(value)
    None => ()
  }
  match view.zoom_scale {
    Some(value) => merged.zoom_scale = Some(value)
    None => ()
  }
  merged
}

///|
fn normalize_view_index(view_index : Int, count : Int) -> Int raise XlsxError {
  if count <= 0 {
    raise InvalidSheetOperation(msg="view index out of range")
  }
  let idx = if view_index < 0 { count + view_index } else { view_index }
  if idx < 0 || idx >= count {
    raise InvalidSheetOperation(msg="view index \{view_index} out of range")
  }
  idx
}

///|
test "sheet view wb: Selection::with_values defaults cover none branches" {
  let selection = Selection::with_values()
  inspect(selection.sqref, content="")
  inspect(selection.active_cell, content="")
  inspect(selection.pane, content="")
}

///|
test "sheet view wb: invalid view mode is ignored and defaults are preserved" {
  let view = SheetView::new()
  apply_sheet_view_options(view, SheetViewOptions::with_values(view="unknown"))
  debug_inspect(view.view, content="None")
  let merged = sheet_view_options_with_defaults(view)
  debug_inspect(merged.top_left_cell, content="Some(\"A1\")")
}

///|
test "sheet view wb: normalize_view_index rejects empty view list" {
  let result : Result[Int, Error] = Ok(normalize_view_index(0, 0)) catch {
    e => Err(e)
  }
  inspect(result is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}
