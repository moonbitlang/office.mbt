///|
test "time_to_excel_date epochs and Lotus bug" {
  // Excel 1900 date system: Jan 1 1900 is serial 1, Feb 28 1900 is 59,
  // the phantom Feb 29 1900 makes Mar 1 1900 serial 61
  inspect(@xlsx.time_to_excel_date(@time.date_time(1900, 1, 1)), content="1")
  inspect(@xlsx.time_to_excel_date(@time.date_time(1900, 2, 28)), content="59")
  inspect(@xlsx.time_to_excel_date(@time.date_time(1900, 3, 1)), content="61")
  inspect(
    @xlsx.time_to_excel_date(@time.date_time(2021, 1, 1, hour=12)),
    content="44197.5",
  )
  // 1904 date system starts at zero
  inspect(
    @xlsx.time_to_excel_date(@time.date_time(1904, 1, 1), use_1904_format=true),
    content="0",
  )
  inspect(
    @xlsx.time_to_excel_date(@time.date_time(1904, 1, 2), use_1904_format=true),
    content="1",
  )
  // before the epoch clamps to zero
  inspect(@xlsx.time_to_excel_date(@time.date_time(1899, 6, 1)), content="0")
  // roundtrip through the existing reverse conversion
  let dt = @xlsx.excel_date_to_time(
    @xlsx.time_to_excel_date(@time.date_time(2024, 7, 3, hour=15, minute=30)),
  )
  inspect(dt.year(), content="2024")
  inspect(dt.month(), content="7")
  inspect(dt.day(), content="3")
  inspect(dt.hour(), content="15")
  inspect(dt.minute(), content="30")
}

///|
test "set_cell_time stores serial and default date style" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  // midnight, not first of month -> numFmt 14
  workbook.set_cell_time("Sheet1", "A1", @time.date_time(2024, 7, 3))
  debug_inspect(
    workbook.get_cell("Sheet1", "A1"),
    content=(
      #|Some("45476")
    ),
  )
  // first of month -> numFmt 17
  workbook.set_cell_time("Sheet1", "A2", @time.date_time(2024, 7, 1))
  // with time of day -> numFmt 22
  workbook.set_cell_time(
    "Sheet1",
    "A3",
    @time.date_time(2024, 7, 3, hour=15, minute=30),
  )
  let fmt_of = (reference : String) => {
    let idx = match workbook.get_cell_style("Sheet1", reference) {
      Some(value) => value
      None => fail("missing style for \{reference}")
    }
    let style = workbook.get_style(idx)
    guard style.number_format is Some(@xlsx.NumberFormat::Builtin(id)) else {
      fail("missing builtin number_format for \{reference}")
    }
    guard style.num_fmt is Some(mirror) && mirror == id else {
      fail("num_fmt mirror out of sync for \{reference}")
    }
    id
  }
  inspect(fmt_of("A1"), content="14")
  inspect(fmt_of("A2"), content="17")
  inspect(fmt_of("A3"), content="22")
  // pre-epoch datetimes fall back to ISO-8601 text
  workbook.set_cell_time("Sheet1", "A4", @time.date_time(1899, 6, 1))
  debug_inspect(
    workbook.get_cell("Sheet1", "A4"),
    content=(
      #|Some("1899-06-01T00:00:00Z")
    ),
  )
  // date-1904 workbooks shift the serial
  let wb1904 = @xlsx.Workbook::new()
  ignore(wb1904.add_sheet("Sheet1"))
  wb1904.set_workbook_props(
    Some(@xlsx.WorkbookPropsOptions::with_values(date_1904=true)),
  )
  wb1904.set_cell_time("Sheet1", "B1", @time.date_time(1904, 1, 2))
  debug_inspect(
    wb1904.get_cell("Sheet1", "B1"),
    content=(
      #|Some("1")
    ),
  )
}

///|
test "set_cell_duration stores day fraction and elapsed style" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  // whole minutes -> numFmt 20
  workbook.set_cell_duration(
    "Sheet1",
    "A1",
    @time.Duration::of(hours=1, minutes=30),
  )
  debug_inspect(
    workbook.get_cell("Sheet1", "A1"),
    content=(
      #|Some("0.0625")
    ),
  )
  // seconds -> numFmt 21
  workbook.set_cell_duration(
    "Sheet1",
    "A2",
    @time.Duration::of(minutes=1, seconds=30),
  )
  // >= 24h -> numFmt 46
  workbook.set_cell_duration("Sheet1", "A3", @time.Duration::of(hours=25))
  let fmt_of = (reference : String) => {
    let idx = match workbook.get_cell_style("Sheet1", reference) {
      Some(value) => value
      None => fail("missing style for \{reference}")
    }
    let style = workbook.get_style(idx)
    guard style.number_format is Some(@xlsx.NumberFormat::Builtin(id)) else {
      fail("missing builtin number_format for \{reference}")
    }
    guard style.num_fmt is Some(mirror) && mirror == id else {
      fail("num_fmt mirror out of sync for \{reference}")
    }
    id
  }
  inspect(fmt_of("A1"), content="20")
  inspect(fmt_of("A2"), content="21")
  inspect(fmt_of("A3"), content="46")
}

///|
test "set_cell_time pre-epoch non-UTC fallback shifts by zone offset" {
  // Excelize adds the zone offset to the wall clock before formatting
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let zone = @time.fixed_zone("CST", 8 * 3600)
  workbook.set_cell_time("Sheet1", "A1", @time.date_time(1899, 6, 1, zone~))
  debug_inspect(
    workbook.get_cell("Sheet1", "A1"),
    content=(
      #|Some("1899-06-01T08:00:00+08:00")
    ),
  )
}

///|
test "set_cell_time inherits row and column styles like prepareCellStyle" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  // give row 2 a bold style, column C an italic style
  let bold_idx = workbook.new_style(
    @xlsx.Style::font(@xlsx.Font::with_values(bold=true)),
  )
  let italic_idx = workbook.new_style(
    @xlsx.Style::font(@xlsx.Font::with_values(italic=true)),
  )
  workbook.set_row_style("Sheet1", 2, bold_idx)
  workbook.set_col_style("Sheet1", 3, italic_idx)
  // A cell in the styled row keeps bold and gains the date format
  workbook.set_cell_time("Sheet1", "A2", @time.date_time(2024, 7, 3))
  let a2_style = match workbook.get_cell_style("Sheet1", "A2") {
    Some(idx) => workbook.get_style(idx)
    None => fail("missing A2 style")
  }
  debug_inspect(a2_style.num_fmt, content="Some(14)")
  inspect(
    a2_style.font is Some(font) && font.bold is Some(true),
    content="true",
  )
  // A cell in the styled column (row unstyled) keeps italic
  workbook.set_cell_time("Sheet1", "C5", @time.date_time(2024, 7, 3))
  let c5_style = match workbook.get_cell_style("Sheet1", "C5") {
    Some(idx) => workbook.get_style(idx)
    None => fail("missing C5 style")
  }
  debug_inspect(c5_style.num_fmt, content="Some(14)")
  inspect(
    c5_style.font is Some(font) && font.italic is Some(true),
    content="true",
  )
}

///|
test "pre-epoch fallback cell still inherits row style" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bold_idx = workbook.new_style(
    @xlsx.Style::font(@xlsx.Font::with_values(bold=true)),
  )
  workbook.set_row_style("Sheet1", 3, bold_idx)
  workbook.set_cell_time("Sheet1", "B3", @time.date_time(1899, 6, 1))
  debug_inspect(
    workbook.get_cell("Sheet1", "B3"),
    content=(
      #|Some("1899-06-01T00:00:00Z")
    ),
  )
  let style = match workbook.get_cell_style("Sheet1", "B3") {
    Some(idx) => workbook.get_style(idx)
    None => fail("missing B3 style")
  }
  inspect(style.font is Some(font) && font.bold is Some(true), content="true")
  // no number format is forced onto the text fallback
  inspect(style.num_fmt is None || style.num_fmt is Some(0), content="true")
}

///|
test "set_cell_time date format survives into styles.xml" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_time("Sheet1", "A1", @time.date_time(2024, 7, 3))
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let styles_xml = match archive.get("xl/styles.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing styles.xml")
  }
  inspect(styles_xml.contains("numFmtId=\"14\""), content="true")
}
