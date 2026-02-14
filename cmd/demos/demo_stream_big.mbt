///|
fn parse_int(s : StringView) -> Int? {
  let text = s.to_string().trim()
  if text == "" {
    return None
  }
  let mut first = true
  let mut neg = false
  let mut seen_digit = false
  let mut value = 0
  for ch in text {
    if first {
      first = false
      if ch == '-' {
        neg = true
        continue
      }
      if ch == '+' {
        continue
      }
    }
    if ch < '0' || ch > '9' {
      return None
    }
    seen_digit = true
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  if !seen_digit {
    return None
  }
  Some(if neg { -value } else { value })
}

///|
pub fn demo_stream_big_bytes(
  rows? : Int = 20000,
) -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  ignore(workbook.add_sheet("Big"))
  let header_font = @xlsx.Font::with_values(bold=true, color="FFFFFF")
  let header_style = @xlsx.Style::new()
  let header_style = @xlsx.Style::with_font(header_style, header_font)
  let header_style = @xlsx.Style::with_fill(
    header_style,
    @xlsx.Fill::solid("0F4C81"),
  )
  let header_style_id = workbook.new_style(header_style)
  let writer = workbook.new_stream_writer("Big")
  writer.set_col_width(1, 1, 10.0)
  writer.set_col_width(2, 2, 14.0)
  writer.set_col_width(3, 3, 14.0)
  writer.set_col_width(4, 4, 18.0)
  writer.set_col_width(5, 5, 24.0)
  writer.set_panes(
    @xlsx.Panes::with_values(
      freeze=true,
      y_split=1,
      top_left_cell="A2",
      active_pane="bottomLeft",
      selection=[
        @xlsx.Selection::with_values(
          sqref="A2",
          active_cell="A2",
          pane="bottomLeft",
        ),
      ],
    ),
  )
  writer.set_row(
    "A1",
    ["ID", "Value", "Value^2", "Tag", "Note"],
    row_opts=@xlsx.RowOpts::with_values(style_id=header_style_id),
  )
  let total_rows = if rows < 1 { 1 } else { rows }
  for i in 1..<=total_rows {
    let id = i
    let v = i % 997 + 1
    let v2 = v * v
    let tag = if i % 2 == 0 { "even" } else { "odd" }
    writer.set_row("A\{i + 1}", [
      "\{id}",
      "\{v}",
      "\{v2}",
      tag,
      "stream row \{i}",
    ])
  }
  ignore(
    writer.add_table(
      "A1:E\{total_rows + 1}",
      "BigTable",
      ["ID", "Value", "Value^2", "Tag", "Note"],
      style_name="TableStyleLight11",
      show_row_stripes=true,
    ),
  )
  writer.flush()
  @excel.write(workbook)
}

///|
fn demo_stream_big_rows_from_args(args : ArrayView[String]) -> Int {
  match args {
    [] => 20000
    [value, ..] =>
      match parse_int(value) {
        Some(v) if v > 0 => v
        _ => 20000
      }
  }
}
