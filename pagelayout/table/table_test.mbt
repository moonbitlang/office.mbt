///|
fn para(text : String) -> @paragraph.ParagraphInput {
  {
    runs: [
      {
        text,
        field: NotAField,
        style: {
          family: "Calibri",
          size_pt: 11,
          bold: false,
          italic: false,
          color: @pagelayout.black,
        },
      },
    ],
    style: @paragraph.ParagraphStyle::default(),
  }
}

///|
fn cells(texts : Array[String]) -> Array[@table.Cell] {
  let out : Array[@table.Cell] = []
  for t in texts {
    out.push(@table.Cell::new([para(t)]))
  }
  out
}

///|
test "column count takes the wider of grid and row spans" {
  let three_wide = @table.Table::new(
    [@table.Row::new(cells(["a", "b", "c"]))],
    grid=[Twips(1440), Twips(1440)],
  )
  // the row needs three columns even though the grid declares two
  inspect(three_wide.column_count(), content="3")
  let spanning = @table.Table::new(
    [@table.Row::new([@table.Cell::new([para("wide")], grid_span=4)])],
    grid=[Twips(1440)],
  )
  inspect(spanning.column_count(), content="4")
}

///|
test "grid widths resolve to points and scale to the table width" {
  // 1in + 2in grid in a 216pt table: scales 3in (216pt) exactly
  let t = @table.Table::new([@table.Row::new(cells(["a", "b"]))], grid=[
    Twips(1440),
    Twips(2880),
  ])
  let columns = t.resolve_columns(216)
  json_inspect(columns, content=[72, 144])
}

///|
test "autofit normalizes a grid that disagrees with the table width" {
  // grid totals 4in (288pt) but only 144pt is available
  let t = @table.Table::new([@table.Row::new(cells(["a", "b"]))], grid=[
    Twips(2880),
    Twips(2880),
  ])
  let columns = t.resolve_columns(144)
  json_inspect(columns, content=[72, 72])
  let mut total = 0.0
  for c in columns {
    total += c
  }
  inspect(total, content="144")
}

///|
test "fixed layout keeps an under-wide grid instead of stretching it" {
  let t = @table.Table::new(
    [@table.Row::new(cells(["a", "b"]))],
    grid=[Twips(720), Twips(720)],
    layout=Fixed,
  )
  // 0.5in + 0.5in = 72pt, well under the 400pt measure: stays 72pt
  let columns = t.resolve_columns(400)
  json_inspect(columns, content=[36, 36])
}

///|
test "fixed layout still shrinks a grid that overflows" {
  let t = @table.Table::new(
    [@table.Row::new(cells(["a", "b"]))],
    grid=[Twips(2880), Twips(2880)],
    layout=Fixed,
  )
  let columns = t.resolve_columns(144)
  let mut total = 0.0
  for c in columns {
    total += c
  }
  inspect(total, content="144")
}

///|
test "cell widths size columns the grid leaves out" {
  // no grid at all: the cells' own widths decide
  let t = @table.Table::new([
    @table.Row::new([
      @table.Cell::new([para("a")], width=Twips(1440)),
      @table.Cell::new([para("b")], width=Twips(2880)),
    ]),
  ])
  let columns = t.resolve_columns(216)
  json_inspect(columns, content=[72, 144])
}

///|
test "a spanning cell divides its width across the columns it covers" {
  let t = @table.Table::new([
    @table.Row::new([
      @table.Cell::new([para("wide")], width=Twips(2880), grid_span=2),
    ]),
    @table.Row::new(cells(["a", "b"])),
  ])
  let columns = t.resolve_columns(200)
  json_inspect(columns, content=[100, 100])
}

///|
test "unsized columns share the remaining width" {
  let t = @table.Table::new(
    [@table.Row::new(cells(["a", "b", "c"]))],
    grid=[Twips(1440)],
    width=Twips(4320), // 3in
  )
  // 1in is spoken for; the other two columns split the remaining 2in
  let columns = t.resolve_columns(400)
  json_inspect(columns, content=[72, 72, 72])
}

///|
test "percent widths resolve against the available measure" {
  let t = @table.Table::new(
    [@table.Row::new(cells(["a", "b"]))],
    // 2500 fiftieths of a percent == 50%
    width=Percent(2500),
    grid=[Twips(1440), Twips(1440)],
  )
  let columns = t.resolve_columns(400)
  let mut total = 0.0
  for c in columns {
    total += c
  }
  inspect(total, content="200")
}

///|
test "table indent reduces the usable width" {
  let t = @table.Table::new(
    [@table.Row::new(cells(["a"]))],
    indent=Twips(720), // 0.5in
  )
  inspect(t.width_pt(400), content="364")
}

///|
test "a table with no usable widths still gets positive columns" {
  let t = @table.Table::new([
    @table.Row::new([
      @table.Cell::new([para("a")], width=Nil),
      @table.Cell::new([para("b")], width=Nil),
    ]),
  ])
  let columns = t.resolve_columns(200)
  json_inspect(columns, content=[100, 100])
  for c in columns {
    assert_true(c > 0)
  }
}

///|
test "column geometry helpers span and offset correctly" {
  let columns = [50.0, 30.0, 20.0]
  inspect(@table.cell_span_pt(columns, 0, 2), content="80")
  inspect(@table.cell_span_pt(columns, 1, 1), content="30")
  // a span past the end clamps to what exists
  inspect(@table.cell_span_pt(columns, 1, 9), content="50")
  inspect(@table.column_offset_pt(columns, 0), content="0")
  inspect(@table.column_offset_pt(columns, 2), content="80")
  inspect(@table.column_offset_pt(columns, 9), content="100")
}

///|
test "an empty table resolves to no columns" {
  let t = @table.Table::new([])
  json_inspect(t.resolve_columns(400), content=[])
}
