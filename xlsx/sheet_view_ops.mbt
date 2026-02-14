///|
fn Worksheet::ensure_sheet_view(
  self : Worksheet,
  view_index : Int,
) -> (SheetView, Int) raise XlsxError {
  if self.sheet_views.length() == 0 {
    self.sheet_views.push(SheetView::new())
  }
  let idx = normalize_view_index(view_index, self.sheet_views.length())
  (self.sheet_views[idx], idx)
}

///|
fn Worksheet::set_sheet_view(
  self : Worksheet,
  view_index : Int,
  options : SheetViewOptions,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (view, _idx) = self.ensure_sheet_view(view_index)
  apply_sheet_view_options(view, options)
}

///|
fn Worksheet::get_sheet_view(
  self : Worksheet,
  view_index : Int,
) -> SheetViewOptions raise XlsxError {
  let (view, _idx) = self.ensure_sheet_view(view_index)
  sheet_view_options_with_defaults(view)
}

///|
pub fn Worksheet::set_panes(
  self : Worksheet,
  panes : Panes,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if self.sheet_views.length() == 0 {
    self.sheet_views.push(SheetView::new())
  }
  let view_index = self.sheet_views.length() - 1
  let view = self.sheet_views[view_index]
  if !panes.freeze && !panes.split {
    view.pane = None
  } else {
    let pane = SheetPane::new()
    pane.active_pane = panes.active_pane
    pane.top_left_cell = panes.top_left_cell
    pane.x_split = Double::from_int(panes.x_split)
    pane.y_split = Double::from_int(panes.y_split)
    if panes.freeze {
      pane.state = "frozen"
    }
    view.pane = Some(pane)
  }
  let selections : Array[Selection] = []
  for item in panes.selection {
    selections.push(item)
  }
  view.selection.clear()
  view.selection.append(selections[:])
}

///|
pub fn Worksheet::get_panes(self : Worksheet) -> Panes {
  if self.sheet_views.length() == 0 {
    return Panes::new()
  }
  let view = self.sheet_views[self.sheet_views.length() - 1]
  let panes = Panes::new()
  let selection : Array[Selection] = []
  for item in view.selection {
    selection.push(item)
  }
  panes.selection = selection
  match view.pane {
    Some(pane) => {
      panes.active_pane = pane.active_pane
      panes.top_left_cell = pane.top_left_cell
      panes.x_split = pane.x_split.to_int()
      panes.y_split = pane.y_split.to_int()
      if pane.state == "frozen" {
        panes.freeze = true
      }
    }
    None => ()
  }
  panes
}

///|
fn Worksheet::set_sheet_dimension(
  self : Worksheet,
  range_ref : StringView,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if range_ref.to_string() == "" {
    self.dimension_ref = None
    return
  }
  self.dimension_ref = Some(normalize_cell_or_range_ref(range_ref))
}

///|
fn Worksheet::sheet_dimension(self : Worksheet) -> String? raise XlsxError {
  match self.dimension_ref {
    Some(value) => Some(value)
    None => worksheet_dimension(self)
  }
}
