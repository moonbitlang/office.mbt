// Regression tests for issue #292.
//
// `page_layout_with_defaults` / `page_margins_with_defaults` used to bind the
// module-level default struct with `let` and then mutate it. MoonBit structs
// are reference types, so the "merged" value *was* the default: reading one
// sheet's page setup rewrote the process-global default, and every later read —
// a sibling sheet, and every `Workbook` constructed later in the same process —
// reported the first sheet's setup instead.
//
// The three leak paths get one test each so that each fails on its own rather
// than being hidden behind an earlier assertion in the same block. Each test
// mutates state through one path and asserts an unrelated path is untouched, so
// re-introducing any form of sharing fails them rather than merely producing a
// different snapshot.

///|
/// Leak path 1: a sibling sheet in the same workbook must not observe the setup
/// of a sheet that was read before it.
test "page layout: reading one sheet leaves its sibling untouched" {
  let wb = @xlsx.Workbook::new()
  ignore(wb.new_sheet("Landscape"))
  ignore(wb.new_sheet("Untouched"))
  debug_inspect(
    wb.get_page_layout("Untouched").orientation,
    content=(
      #|Some("portrait")
    ),
  )
  wb.set_page_layout(
    "Landscape",
    Some(@xlsx.PageLayoutOptions::with_values(orientation="landscape")),
  )
  ignore(wb.get_page_layout("Landscape"))
  debug_inspect(
    wb.get_page_layout("Untouched").orientation,
    content=(
      #|Some("portrait")
    ),
  )
  debug_inspect(wb.get_page_layout("Untouched").adjust_to, content="Some(100)")
}

///|
/// Leak path 2: a `Workbook` constructed after the read must not inherit
/// anything. This is the assertion that proves the module-level default itself
/// is still intact — nothing about the first workbook is reachable from here.
test "page layout: a later workbook is unaffected by an earlier one" {
  let first = @xlsx.Workbook::new()
  ignore(first.new_sheet("Landscape"))
  first.set_page_layout(
    "Landscape",
    Some(
      @xlsx.PageLayoutOptions::with_values(
        orientation="landscape",
        adjust_to=120,
        first_page_number=7,
      ),
    ),
  )
  ignore(first.get_page_layout("Landscape"))
  let second = @xlsx.Workbook::new()
  ignore(second.new_sheet("FreshWorkbook"))
  let fresh = second.get_page_layout("FreshWorkbook")
  debug_inspect(
    fresh.orientation,
    content=(
      #|Some("portrait")
    ),
  )
  debug_inspect(fresh.adjust_to, content="Some(100)")
  debug_inspect(fresh.first_page_number, content="Some(1)")
  debug_inspect(fresh.size, content="Some(0)")
}

///|
/// Leak path 3: removing the sharing must not break the feature — the sheet
/// that was set still reads back its own value, with unset fields filled in
/// from the defaults.
test "page layout: the sheet that was set still reads back correctly" {
  let wb = @xlsx.Workbook::new()
  ignore(wb.new_sheet("Landscape"))
  wb.set_page_layout(
    "Landscape",
    Some(
      @xlsx.PageLayoutOptions::with_values(
        orientation="landscape",
        adjust_to=120,
      ),
    ),
  )
  let layout = wb.get_page_layout("Landscape")
  debug_inspect(
    layout.orientation,
    content=(
      #|Some("landscape")
    ),
  )
  debug_inspect(layout.adjust_to, content="Some(120)")
  debug_inspect(layout.size, content="Some(0)")
  debug_inspect(layout.first_page_number, content="Some(1)")
  // Reading twice must give the same answer.
  debug_inspect(
    wb.get_page_layout("Landscape").orientation,
    content=(
      #|Some("landscape")
    ),
  )
  debug_inspect(wb.get_page_layout("Landscape").adjust_to, content="Some(120)")
}

///|
/// Leak path 1 for page margins, the second merge function the issue names.
test "page margins: reading one sheet leaves its sibling untouched" {
  let wb = @xlsx.Workbook::new()
  ignore(wb.new_sheet("WideMargins"))
  ignore(wb.new_sheet("Untouched"))
  debug_inspect(wb.get_page_margins("Untouched").top, content="Some(0.75)")
  wb.set_page_margins(
    "WideMargins",
    Some(@xlsx.PageLayoutMarginsOptions::with_values(top=3.5)),
  )
  ignore(wb.get_page_margins("WideMargins"))
  debug_inspect(wb.get_page_margins("Untouched").top, content="Some(0.75)")
  debug_inspect(wb.get_page_margins("Untouched").left, content="Some(0.7)")
}

///|
/// Leak path 2 for page margins.
test "page margins: a later workbook is unaffected by an earlier one" {
  let third = @xlsx.Workbook::new()
  ignore(third.new_sheet("WideMargins"))
  third.set_page_margins(
    "WideMargins",
    Some(@xlsx.PageLayoutMarginsOptions::with_values(top=3.5, left=2.5)),
  )
  ignore(third.get_page_margins("WideMargins"))
  let fourth = @xlsx.Workbook::new()
  ignore(fourth.new_sheet("FreshWorkbook"))
  let fresh = fourth.get_page_margins("FreshWorkbook")
  debug_inspect(fresh.top, content="Some(0.75)")
  debug_inspect(fresh.bottom, content="Some(0.75)")
  debug_inspect(fresh.left, content="Some(0.7)")
  debug_inspect(fresh.right, content="Some(0.7)")
  debug_inspect(fresh.header, content="Some(0.3)")
  debug_inspect(fresh.footer, content="Some(0.3)")
}

///|
/// Leak path 3 for page margins.
test "page margins: the sheet that was set still reads back correctly" {
  let wb = @xlsx.Workbook::new()
  ignore(wb.new_sheet("WideMargins"))
  wb.set_page_margins(
    "WideMargins",
    Some(
      @xlsx.PageLayoutMarginsOptions::with_values(top=3.5, horizontally=true),
    ),
  )
  let wide = wb.get_page_margins("WideMargins")
  debug_inspect(wide.top, content="Some(3.5)")
  debug_inspect(wide.horizontally, content="Some(true)")
  debug_inspect(wide.bottom, content="Some(0.75)")
  debug_inspect(wide.left, content="Some(0.7)")
  debug_inspect(wide.right, content="Some(0.7)")
  debug_inspect(wide.header, content="Some(0.3)")
  debug_inspect(wide.footer, content="Some(0.3)")
  debug_inspect(wb.get_page_margins("WideMargins").top, content="Some(3.5)")
}

///|
/// The writer merges each sheet's margins with the defaults on its way out
/// (`write.mbt`), so the shared default corrupted the bytes on disk too: the
/// first sheet written leaked its margins into every later sheet's
/// `<pageMargins>`. Written-then-read is the end-to-end form of that.
test "written margins stay per-sheet across a write/read roundtrip" {
  let wb = @xlsx.Workbook::new()
  ignore(wb.new_sheet("First"))
  ignore(wb.new_sheet("Second"))
  wb.set_page_margins(
    "First",
    Some(@xlsx.PageLayoutMarginsOptions::with_values(top=3.5)),
  )
  wb.set_page_margins(
    "Second",
    Some(@xlsx.PageLayoutMarginsOptions::with_values(left=2.5)),
  )
  let parsed = @xlsx.read(@xlsx.write(wb))
  let first = parsed.get_page_margins("First")
  debug_inspect(first.top, content="Some(3.5)")
  debug_inspect(first.left, content="Some(0.7)")
  let second = parsed.get_page_margins("Second")
  debug_inspect(second.left, content="Some(2.5)")
  debug_inspect(second.top, content="Some(0.75)")
}

///|
/// Two sheets that each set a different part of the page setup must not observe
/// each other's values through the shared default, in either read order.
test "per-sheet page setup stays independent in both read orders" {
  let wb = @xlsx.Workbook::new()
  ignore(wb.new_sheet("A"))
  ignore(wb.new_sheet("B"))
  wb.set_page_layout(
    "A",
    Some(@xlsx.PageLayoutOptions::with_values(orientation="landscape")),
  )
  wb.set_page_layout(
    "B",
    Some(@xlsx.PageLayoutOptions::with_values(adjust_to=120)),
  )
  wb.set_page_margins(
    "A",
    Some(@xlsx.PageLayoutMarginsOptions::with_values(top=3.5)),
  )
  wb.set_page_margins(
    "B",
    Some(@xlsx.PageLayoutMarginsOptions::with_values(left=2.5)),
  )
  // B first, then A, then B again: A must not inherit B's adjust_to, and B must
  // not inherit A's orientation on the second read.
  debug_inspect(wb.get_page_layout("B").adjust_to, content="Some(120)")
  debug_inspect(
    wb.get_page_layout("B").orientation,
    content=(
      #|Some("portrait")
    ),
  )
  debug_inspect(
    wb.get_page_layout("A").orientation,
    content=(
      #|Some("landscape")
    ),
  )
  debug_inspect(wb.get_page_layout("A").adjust_to, content="Some(100)")
  debug_inspect(wb.get_page_layout("B").adjust_to, content="Some(120)")
  debug_inspect(
    wb.get_page_layout("B").orientation,
    content=(
      #|Some("portrait")
    ),
  )
  // Same for margins.
  debug_inspect(wb.get_page_margins("B").left, content="Some(2.5)")
  debug_inspect(wb.get_page_margins("B").top, content="Some(0.75)")
  debug_inspect(wb.get_page_margins("A").top, content="Some(3.5)")
  debug_inspect(wb.get_page_margins("A").left, content="Some(0.7)")
  debug_inspect(wb.get_page_margins("B").left, content="Some(2.5)")
  debug_inspect(wb.get_page_margins("B").top, content="Some(0.75)")
}
