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
  let result : Result[Int, Error] = try? normalize_view_index(0, 0)
  inspect(result is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}
