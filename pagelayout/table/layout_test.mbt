///|
fn thin_borders() -> @table.Borders {
  let edge = @table.Border::{
    width: EighthPoints(4), // 0.5pt
    color: @pagelayout.black,
  }
  { top: Some(edge), bottom: Some(edge), left: Some(edge), right: Some(edge), }
}

///|
test "cell content lays out inside the cell's margins" {
  let t = @table.Table::new([@table.Row::new(cells(["Hello", "World"]))], grid=[
    Twips(2880),
    Twips(2880),
  ])
  let laid = @table.layout_table(t, 288)
  json_inspect(laid.columns, content=[144, 144])
  assert_eq(laid.rows.length(), 1)
  let row = laid.rows[0]
  assert_eq(row.cells.length(), 2)
  // second cell starts one column over
  inspect(row.cells[1].x_pt, content="144")
  // default margins are 108 twips (5.4pt) each side
  inspect(row.cells[0].width_pt, content="144")
  // one line of 11pt Calibri in each
  assert_eq(row.cells[0].lines.length(), 1)
  assert_true(row.height_pt > 0)
}

///|
test "row height is the tallest cell plus its vertical margins" {
  let tall = @table.Cell::new([para("one"), para("two"), para("three")])
  let short = @table.Cell::new([para("x")])
  let t = @table.Table::new([@table.Row::new([tall, short])], grid=[
    Twips(2880),
    Twips(2880),
  ])
  let laid = @table.layout_table(t, 288)
  let row = laid.rows[0]
  // three stacked paragraphs set the height
  assert_true(row.height_pt >= row.cells[0].content_height_pt)
  assert_true(row.cells[0].content_height_pt > row.cells[1].content_height_pt)
  inspect(
    row.height_pt,
    content=(
      #|40.283203125
    ),
  )
}

///|
test "trHeight sets a floor but never shrinks a row" {
  let t = @table.Table::new(
    [
      @table.Row::new(cells(["x"]), min_height=Some(Twips(2880))), // 144pt floor
      @table.Row::new(cells(["y"])),
    ],
    grid=[Twips(2880)],
  )
  let laid = @table.layout_table(t, 144)
  inspect(laid.rows[0].height_pt, content="144")
  assert_true(laid.rows[1].height_pt < 144)
  // rows stack: the second starts where the first ends
  inspect(laid.rows[1].y_pt, content="144")
}

///|
test "vertical merge continuations contribute no content or height" {
  let start = @table.Cell::new([para("merged")])
  let cont = @table.Cell::new([para("ignored")], vmerge=VContinue)
  let t = @table.Table::new(
    [@table.Row::new([start]), @table.Row::new([cont])],
    grid=[Twips(2880)],
  )
  let laid = @table.layout_table(t, 144)
  assert_true(laid.rows[0].cells[0].lines.length() > 0)
  assert_eq(laid.rows[1].cells[0].lines.length(), 0)
  inspect(laid.rows[1].height_pt, content="0")
}

///|
test "a spanning cell is laid out across its columns" {
  let t = @table.Table::new(
    [
      @table.Row::new([@table.Cell::new([para("header")], grid_span=2)]),
      @table.Row::new(cells(["a", "b"])),
    ],
    grid=[Twips(1440), Twips(1440)],
  )
  let laid = @table.layout_table(t, 144)
  inspect(laid.rows[0].cells[0].width_pt, content="144")
  inspect(laid.rows[0].cells[0].grid_span, content="2")
  inspect(laid.rows[1].cells[1].x_pt, content="72")
}

///|
test "emitted items paint shading, then borders, then text" {
  let shaded = @table.Cell::new(
    [para("x")],
    borders=thin_borders(),
    shading=Some(@pagelayout.Color::rgb(240, 240, 240)),
  )
  let t = @table.Table::new([@table.Row::new([shaded])], grid=[Twips(2880)])
  let laid = @table.layout_table(t, 144)
  let model = @pagelayout.PageModel::new()
  let items = @table.emit_rows(model, laid, 72, 100, 0, laid.rows.length())
  // first item is the shading rect, last is the text
  guard! items[0] is Rect(shade)
  inspect(shade.fill.unwrap().to_hex(), content="#f0f0f0")
  guard! items[items.length() - 1] is Text(run)
  inspect(run.text, content="x")
  // four borders between them
  let mut rects = 0
  for item in items {
    if item is Rect(_) {
      rects += 1
    }
  }
  inspect(rects, content="5")
}

///|
test "emitted geometry is absolute and validates" {
  let t = @table.Table::new([@table.Row::new(cells(["a", "b"]))], grid=[
    Twips(1440),
    Twips(1440),
  ])
  let laid = @table.layout_table(t, 144)
  let model = @pagelayout.PageModel::new()
  let items = @table.emit_rows(model, laid, 72, 100, 0, laid.rows.length())
  let page = @pagelayout.Page::{ width_pt: 612, height_pt: 792, items: [], }
  for item in items {
    page.items.push(item)
  }
  model.pages.push(page)
  debug_inspect(model.validate(), content="[]")
  // the first run starts at the table origin plus the cell's left margin
  guard! items[0] is Text(first)
  inspect(first.x_pt, content="77.4")
}

///|
test "header rows repeat on a continuation" {
  let t = @table.Table::new(
    [
      @table.Row::new(cells(["H"]), header=true),
      @table.Row::new(cells(["a"])),
      @table.Row::new(cells(["b"])),
    ],
    grid=[Twips(2880)],
  )
  let laid = @table.layout_table(t, 144)
  let model = @pagelayout.PageModel::new()
  // continuing from row 2, the header comes along
  let items = @table.emit_rows(model, laid, 0, 0, 2, 3, repeat_header=true)
  guard! items[0] is Text(first)
  inspect(first.text, content="H")
  guard! items[1] is Text(second)
  inspect(second.text, content="b")
  // and the height accounts for it
  let with_header = @table.rows_height_pt(laid, 2, 3, repeat_header=true)
  let without = @table.rows_height_pt(laid, 2, 3)
  assert_true(with_header > without)
}

///|
test "rows_height_pt sums the requested range" {
  let t = @table.Table::new(
    [
      @table.Row::new(cells(["a"]), min_height=Some(Twips(1440))),
      @table.Row::new(cells(["b"]), min_height=Some(Twips(720))),
    ],
    grid=[Twips(2880)],
  )
  let laid = @table.layout_table(t, 144)
  inspect(@table.rows_height_pt(laid, 0, 2), content="108")
  inspect(@table.rows_height_pt(laid, 1, 2), content="36")
  inspect(@table.rows_height_pt(laid, 0, 0), content="0")
}

///|
test "an empty table lays out to nothing" {
  let laid = @table.layout_table(@table.Table::new([]), 400)
  inspect(laid.height_pt, content="0")
  inspect(laid.width_pt, content="0")
  assert_eq(laid.rows.length(), 0)
}
