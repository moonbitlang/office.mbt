// White-box half of the issue #292 regression suite.
//
// `PageLayoutOptions`/`PageLayoutMarginsOptions` fields are `mut` but not
// `pub mut`, so only code inside this package can mutate a merged result. That
// is exactly where the defect lived, so the sharing has to be pinned down from
// in here: mutate one merge result and assert an independently produced one is
// untouched.

///|
test "merged page layout never aliases the shared default" {
  let merged = page_layout_with_defaults(
    Some(PageLayoutOptions::with_values(orientation="landscape")),
  )
  debug_inspect(
    merged.orientation,
    content=(
      #|Some("landscape")
    ),
  )
  // The merge must not have written through to the default.
  debug_inspect(
    page_layout_with_defaults(None).orientation,
    content=(
      #|Some("portrait")
    ),
  )
  // Mutating a merged result must not be visible to the next merge.
  merged.adjust_to = Some(42)
  debug_inspect(page_layout_with_defaults(None).adjust_to, content="Some(100)")
  // The `None` branch must hand back a fresh value too, not the default itself.
  let plain = page_layout_with_defaults(None)
  plain.size = Some(9)
  plain.orientation = Some("landscape")
  debug_inspect(page_layout_with_defaults(None).size, content="Some(0)")
  debug_inspect(
    page_layout_with_defaults(None).orientation,
    content=(
      #|Some("portrait")
    ),
  )
  // Two merges are independent objects.
  let one = page_layout_with_defaults(
    Some(PageLayoutOptions::with_values(first_page_number=7)),
  )
  let two = page_layout_with_defaults(
    Some(PageLayoutOptions::with_values(first_page_number=9)),
  )
  debug_inspect(one.first_page_number, content="Some(7)")
  debug_inspect(two.first_page_number, content="Some(9)")
}

///|
test "merged page margins never alias the shared default" {
  let merged = page_margins_with_defaults(
    Some(PageLayoutMarginsOptions::with_values(top=3.5)),
  )
  debug_inspect(merged.top, content="Some(3.5)")
  debug_inspect(page_margins_with_defaults(None).top, content="Some(0.75)")
  merged.left = Some(4.25)
  debug_inspect(page_margins_with_defaults(None).left, content="Some(0.7)")
  let plain = page_margins_with_defaults(None)
  plain.top = Some(9.5)
  plain.footer = Some(9.5)
  debug_inspect(page_margins_with_defaults(None).top, content="Some(0.75)")
  debug_inspect(page_margins_with_defaults(None).footer, content="Some(0.3)")
  let one = page_margins_with_defaults(
    Some(PageLayoutMarginsOptions::with_values(bottom=1.25)),
  )
  let two = page_margins_with_defaults(
    Some(PageLayoutMarginsOptions::with_values(bottom=2.25)),
  )
  debug_inspect(one.bottom, content="Some(1.25)")
  debug_inspect(two.bottom, content="Some(2.25)")
}

///|
/// `sheet_props_with_defaults` and `sheet_view_options_with_defaults` already
/// built their base from a factory function and were never affected; pin that
/// down so the two correct neighbours cannot silently regress into the same
/// shape.
test "sheet props and sheet view merges are independent too" {
  let merged = sheet_props_with_defaults(
    Some(SheetPropsOptions::with_values(base_col_width=20)),
  )
  debug_inspect(merged.base_col_width, content="Some(20)")
  debug_inspect(
    sheet_props_with_defaults(None).base_col_width,
    content="Some(8)",
  )
  merged.published = Some(false)
  debug_inspect(sheet_props_with_defaults(None).published, content="Some(true)")
  let plain = sheet_props_with_defaults(None)
  plain.base_col_width = Some(99)
  debug_inspect(
    sheet_props_with_defaults(None).base_col_width,
    content="Some(8)",
  )
  let view = sheet_view_options_with_defaults(SheetView::new())
  debug_inspect(view.zoom_scale, content="Some(100)")
  view.zoom_scale = Some(55)
  debug_inspect(
    sheet_view_options_with_defaults(SheetView::new()).zoom_scale,
    content="Some(100)",
  )
}
