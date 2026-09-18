///|
/// Sparkline point-highlight flags (first/last/negative) have no public
/// setter, so they are injected into the written XML; the line weight goes
/// through the public set_weight API. Both must be recovered by the parser
/// and preserved through a rewrite.
test "sparkline group flags and weight parse and rewrite" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  for i in 1..<=5 {
    sheet.set_cell_value(
      "A\{i}",
      Numeric(Double::from_int(if i % 2 == 0 { -i } else { i })),
    )
  }
  let weighted = @xlsx.SparklineOptions::new(["C1"], ["Sheet1!A1:A5"])
  weighted.set_weight(2.25)
  workbook.add_sparkline_options("Sheet1", weighted)
  let injected = corrupt_sheet1(
    @xlsx.write(workbook),
    "<x14:sparklineGroup ",
    "<x14:sparklineGroup first=\"1\" last=\"1\" negative=\"1\" markers=\"1\" ",
  )
  let parsed = @xlsx.read(injected)
  let parsed_group = parsed.sheet("Sheet1").unwrap().sparkline_groups()[0]
  debug_inspect(
    parsed_group.options,
    content=(
      #|{
      #|  display_empty_cells_as: "gap",
      #|  date_axis: false,
      #|  line_weight: Some(2.25),
      #|  manual_max: None,
      #|  manual_min: None,
      #|  markers: true,
      #|  high: false,
      #|  low: false,
      #|  first: true,
      #|  last: true,
      #|  negative: true,
      #|  display_x_axis: false,
      #|  display_hidden: false,
      #|  right_to_left: false,
      #|  color_series: Some({ rgb: None, theme: Some(4), tint: Some(-0.499984740745262) }),
      #|  color_negative: Some({ rgb: None, theme: Some(5), tint: None }),
      #|  color_axis: Some({ rgb: Some("FF000000"), theme: None, tint: None }),
      #|  color_markers: Some({ rgb: None, theme: Some(4), tint: Some(-0.499984740745262) }),
      #|  color_first: Some({ rgb: None, theme: Some(4), tint: Some(0.3999755851924192) }),
      #|  color_last: Some({ rgb: None, theme: Some(4), tint: Some(0.3999755851924192) }),
      #|  color_high: Some({ rgb: None, theme: Some(4), tint: None }),
      #|  color_low: Some({ rgb: None, theme: Some(4), tint: None }),
      #|}
    ),
  )
  inspect(parsed_group.sparklines.length(), content="1")
  // and the recovered flags survive a rewrite
  let second = @zip.read(@xlsx.write(parsed))
  let sheet_xml = @encoding/utf8.decode(
    second.get("xl/worksheets/sheet1.xml").unwrap(),
  )
  inspect(sheet_xml.contains("first=\"1\""), content="true")
  inspect(sheet_xml.contains("last=\"1\""), content="true")
  inspect(sheet_xml.contains("negative=\"1\""), content="true")
  inspect(sheet_xml.contains("lineWeight=\"2.25\""), content="true")
}

///|
/// Sparkline option validation raises with pinned messages: empty inputs,
/// location/source mismatch, malformed colors, and bad empty-cell modes.
test "sparkline invalid options raise" {
  let summary = StringBuilder()
  let empty_err = @test.expect_error(() => @xlsx.SparklineOptions::new([], []))
  summary.write_string("empty inputs => \{repr(empty_err)}\n")
  let mismatch_err = @test.expect_error(() => {
    @xlsx.SparklineOptions::new(["A1", "A2"], ["Sheet1!B1:B5"])
  })
  summary.write_string("length mismatch => \{repr(mismatch_err)}\n")
  let opts = @xlsx.SparklineOptions::new(["D1"], ["Sheet1!A1:A5"])
  let mode_err = @test.expect_error(() => opts.set_empty_cells("bogus"))
  summary.write_string("bad empty-cells => \{repr(mode_err)}\n")
  let weight_err = @test.expect_error(() => opts.set_weight(0))
  summary.write_string("non-positive weight => \{repr(weight_err)}\n")
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bad_color = @xlsx.SparklineOptions::new(["D1"], ["Sheet1!A1:A5"])
  bad_color.set_series_color("XYZXYZ")
  let color_err = @test.expect_error(() => {
    workbook.add_sparkline_options("Sheet1", bad_color)
  })
  summary.write_string("non-hex color => \{repr(color_err)}\n")
  let short_color = @xlsx.SparklineOptions::new(["D2"], ["Sheet1!A1:A5"])
  short_color.set_high_color("FFAA")
  let short_err = @test.expect_error(() => {
    workbook.add_sparkline_options("Sheet1", short_color)
  })
  summary.write_string("short color => \{repr(short_err)}\n")
  inspect(
    summary.to_string(),
    content=(
      #|empty inputs => InvalidSparkline(msg="sparkline inputs empty")
      #|length mismatch => InvalidSparkline(msg="sparkline inputs mismatch")
      #|bad empty-cells => InvalidSparkline(msg="sparkline empty cells invalid")
      #|non-positive weight => InvalidSparkline(msg="sparkline weight must be > 0")
      #|non-hex color => InvalidSparkline(msg="sparkline color must be hex")
      #|short color => InvalidSparkline(msg="sparkline color must be RRGGBB or AARRGGBB")
      #|
    ),
  )
}

///|
/// Malformed sparkline XML is rejected on read: non-numeric lineWeight,
/// manualMax, and manualMin attributes each raise InvalidXml.
test "malformed sparkline attributes are rejected" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  for i in 1..<=3 {
    sheet.set_cell_value("A\{i}", Numeric(Double::from_int(i)))
  }
  let opts = @xlsx.SparklineOptions::new(["C1"], ["Sheet1!A1:A3"])
  opts.set_manual_min(-2)
  opts.set_manual_max(9)
  workbook.add_sparkline_options("Sheet1", opts)
  let bytes = @xlsx.write(workbook)
  expect_invalid_xml(
    corrupt_sheet1(
      bytes, "<x14:sparklineGroup ", "<x14:sparklineGroup lineWeight=\"thick\" ",
    ),
  )
  expect_invalid_xml(
    corrupt_sheet1(bytes, "manualMax=\"9\"", "manualMax=\"none\""),
  )
  expect_invalid_xml(
    corrupt_sheet1(bytes, "manualMin=\"-2\"", "manualMin=\"auto\""),
  )
}
