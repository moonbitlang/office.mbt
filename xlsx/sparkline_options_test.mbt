///|
test "sparkline options write" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let opts = SparklineOptions::new(["B2"], ["A1:A3"])
  opts.set_type(WinLoss)
  opts.set_style(31)
  opts.set_markers(true)
  opts.set_high(true)
  opts.set_axis(true)
  opts.set_reverse(true)
  opts.set_series_color("00FF00")
  opts.set_negative_color("FF0000")
  opts.set_markers_color("0000FF")
  opts.set_first_color("112233")
  opts.set_last_color("445566")
  opts.set_high_color("778899")
  opts.set_low_color("AABBCC")
  sheet.add_sparkline_options(opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("type=\"stacked\""), content="true")
  inspect(sheet_xml.contains("displayEmptyCellsAs=\"gap\""), content="true")
  inspect(sheet_xml.contains("markers=\"1\""), content="true")
  inspect(sheet_xml.contains("high=\"1\""), content="true")
  inspect(sheet_xml.contains("displayXAxis=\"1\""), content="true")
  inspect(sheet_xml.contains("rightToLeft=\"1\""), content="true")
  inspect(sheet_xml.contains("x14:colorAxis"), content="true")
  inspect(sheet_xml.contains("rgb=\"FF000000\""), content="true")
  inspect(sheet_xml.contains("x14:colorSeries"), content="true")
  inspect(sheet_xml.contains("rgb=\"FF00FF00\""), content="true")
  inspect(sheet_xml.contains("x14:colorNegative"), content="true")
  inspect(sheet_xml.contains("rgb=\"FFFF0000\""), content="true")
  inspect(sheet_xml.contains("x14:colorMarkers"), content="true")
  inspect(sheet_xml.contains("rgb=\"FF0000FF\""), content="true")
  inspect(sheet_xml.contains("x14:colorFirst"), content="true")
  inspect(sheet_xml.contains("rgb=\"FF112233\""), content="true")
  inspect(sheet_xml.contains("x14:colorLast"), content="true")
  inspect(sheet_xml.contains("rgb=\"FF445566\""), content="true")
  inspect(sheet_xml.contains("x14:colorHigh"), content="true")
  inspect(sheet_xml.contains("rgb=\"FF778899\""), content="true")
  inspect(sheet_xml.contains("x14:colorLow"), content="true")
  inspect(sheet_xml.contains("rgb=\"FFAABBCC\""), content="true")
}

///|
test "sparkline options roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let opts = SparklineOptions::new(["B2"], ["A1:A3"])
  opts.set_type(WinLoss)
  opts.set_style(31)
  opts.set_markers(true)
  opts.set_high(true)
  opts.set_axis(true)
  opts.set_reverse(true)
  opts.set_series_color("00FF00")
  opts.set_negative_color("FF0000")
  opts.set_markers_color("0000FF")
  opts.set_first_color("112233")
  opts.set_last_color("445566")
  opts.set_high_color("778899")
  opts.set_low_color("AABBCC")
  sheet.add_sparkline_options(opts)
  let parsed = read(write(workbook))
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  let group = parsed_sheet.sparkline_groups()[0]
  inspect(group.sparkline_type == WinLoss, content="true")
  inspect(group.options.display_empty_cells_as, content="gap")
  inspect(group.options.markers, content="true")
  inspect(group.options.high, content="true")
  inspect(group.options.display_x_axis, content="true")
  inspect(group.options.right_to_left, content="true")
  match group.options.color_axis {
    Some(color) => inspect(color.rgb, content="Some(\"FF000000\")")
    None => fail("missing colorAxis")
  }
  match group.options.color_series {
    Some(color) => inspect(color.rgb, content="Some(\"FF00FF00\")")
    None => fail("missing colorSeries")
  }
  match group.options.color_negative {
    Some(color) => inspect(color.rgb, content="Some(\"FFFF0000\")")
    None => fail("missing colorNegative")
  }
  match group.options.color_markers {
    Some(color) => inspect(color.rgb, content="Some(\"FF0000FF\")")
    None => fail("missing colorMarkers")
  }
  match group.options.color_first {
    Some(color) => inspect(color.rgb, content="Some(\"FF112233\")")
    None => fail("missing colorFirst")
  }
  match group.options.color_last {
    Some(color) => inspect(color.rgb, content="Some(\"FF445566\")")
    None => fail("missing colorLast")
  }
  match group.options.color_high {
    Some(color) => inspect(color.rgb, content="Some(\"FF778899\")")
    None => fail("missing colorHigh")
  }
  match group.options.color_low {
    Some(color) => inspect(color.rgb, content="Some(\"FFAABBCC\")")
    None => fail("missing colorLow")
  }
}

///|
test "sparkline options style out of range" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let opts = SparklineOptions::new(["B2"], ["A1:A3"])
  opts.set_style(36)
  let result = try sheet.add_sparkline_options(opts) catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    result,
    content="Err(InvalidSparkline(msg=\"sparkline style out of range\"))",
  )
}

///|
test "sparkline options followups" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let opts = SparklineOptions::new(["B2"], ["A1:A3"])
  opts.set_date_axis(true)
  opts.set_hidden(true)
  opts.set_weight(2.0)
  opts.set_manual_min(1)
  opts.set_manual_max(9)
  opts.set_empty_cells("zero")
  sheet.add_sparkline_options(opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("dateAxis=\"1\""), content="true")
  inspect(sheet_xml.contains("displayHidden=\"1\""), content="true")
  inspect(sheet_xml.contains("lineWeight=\"2"), content="true")
  inspect(sheet_xml.contains("manualMin=\"1\""), content="true")
  inspect(sheet_xml.contains("manualMax=\"9\""), content="true")
  inspect(sheet_xml.contains("displayEmptyCellsAs=\"zero\""), content="true")
  let parsed = read(bytes)
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  let group = parsed_sheet.sparkline_groups()[0]
  inspect(group.options.date_axis, content="true")
  inspect(group.options.display_hidden, content="true")
  inspect(group.options.line_weight, content="Some(2)")
  inspect(group.options.manual_min, content="Some(1)")
  inspect(group.options.manual_max, content="Some(9)")
  inspect(group.options.display_empty_cells_as, content="zero")
}

///|
test "sparkline options alias fields" {
  let opts = SparklineOptions::new(["B2"], ["A1:A3"])
  inspect(opts.location, content="[\"B2\"]")
  inspect(opts.range, content="[\"A1:A3\"]")
  inspect(
    (opts.max, opts.cust_max, opts.min, opts.cust_min),
    content="(0, 0, 0, 0)",
  )
  opts.set_manual_max(9)
  opts.set_manual_min(1)
  inspect(
    (opts.max, opts.cust_max, opts.min, opts.cust_min),
    content="(9, 9, 1, 1)",
  )
  opts.clear_manual_max()
  opts.clear_manual_min()
  inspect(
    (opts.max, opts.cust_max, opts.min, opts.cust_min),
    content="(0, 0, 0, 0)",
  )
}
