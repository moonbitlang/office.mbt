///|
fn count_xml_tag_unknown_ext(xml : String, tag : String) -> Int {
  let mut count = 0
  let mut first = true
  for _ in xml.split(tag) {
    if first {
      first = false
      continue
    }
    count = count + 1
  }
  count
}

///|
test "integration unknown worksheet ext roundtrip with mixed known ext" {
  let workbook = Workbook::new()
  let data = workbook.add_sheet("Data")
  ignore(workbook.add_sheet("Dash"))

  data.set_cell_value("A1", String("Region"))
  data.set_cell_value("B1", String("Value"))
  data.set_cell_value("A2", String("North"))
  data.set_cell_value("B2", Numeric(12.0))
  data.set_cell_value("A3", String("South"))
  data.set_cell_value("B3", Numeric(9.0))
  data.set_cell_value("A4", String("East"))
  data.set_cell_value("B4", Numeric(15.0))
  data.set_cell_value("A5", String("West"))
  data.set_cell_value("B5", Numeric(11.0))

  ignore(
    workbook.add_table_with_columns("Data", "A1:B5", "MixTable", [
      "Region", "Value",
    ]),
  )
  workbook.add_slicer(
    "Dash",
    SlicerOptions::new("Region", "A1", "Data", "MixTable"),
  )

  let sparkline_opts = SparklineOptions::new(["G2", "G3", "G4"], [
    "'Data'!B2:B5", "'Data'!B2:B5", "'Data'!B2:B5",
  ])
  sparkline_opts.set_markers(true)
  workbook.add_sparkline_options("Dash", sparkline_opts)

  let cf_opt = ConditionalFormatOptions::new("data_bar")
  cf_opt.set_min_type("min")
  cf_opt.set_max_type("max")
  cf_opt.set_bar_color("#638EC6")
  cf_opt.set_bar_direction("rightToLeft")
  cf_opt.set_bar_solid(true)
  cf_opt.set_bar_border_color("#0000FF")
  workbook.set_conditional_format("Dash", "C2:C4", [cf_opt])

  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet2.xml")
  }
  let unknown_ext = "    <ext uri=\"{11111111-2222-3333-4444-555555555555}\"><mbt:payload xmlns:mbt=\"urn:mbtexcel:unknown\"><mbt:value>keep-me</mbt:value></mbt:payload></ext>\n"
  let updated_sheet = if sheet_xml.contains("  </extLst>\n</worksheet>") {
    sheet_xml.replace_all(
      old="  </extLst>\n</worksheet>",
      new="\{unknown_ext}  </extLst>\n</worksheet>",
    )
  } else {
    fail("expected extLst in worksheet xml")
  }

  let updated_archive = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() != "xl/worksheets/sheet2.xml" {
      updated_archive.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  updated_archive.add(
    "xl/worksheets/sheet2.xml",
    @encoding/utf8.encode(updated_sheet),
  )
  let updated_bytes = @zip.write(updated_archive) catch {
    err => fail("zip write failed: \{repr(err)}")
  }

  let parsed = read(updated_bytes)
  let parsed_dash = match parsed.sheet("Dash") {
    Some(value) => value
    None => fail("missing parsed dash")
  }
  inspect(parsed_dash.sparkline_groups().length(), content="1")
  let slicers = parsed.get_slicers("Dash")
  inspect(slicers.length(), content="1")
  let formats = parsed.get_conditional_formats("Dash")
  let opts = match formats.get("C2:C4") {
    Some(value) => value
    None => fail("missing data bar conditional format")
  }
  inspect(opts.length(), content="1")
  inspect(opts[0].format_type, content="data_bar")
  inspect(opts[0].bar_direction, content="rightToLeft")

  let roundtrip_archive = @zip.read(write(parsed)) catch {
    err => fail("zip read failed: \{err}")
  }
  let roundtrip_sheet_xml = match
    roundtrip_archive.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing roundtrip sheet2.xml")
  }

  inspect(
    roundtrip_sheet_xml.contains("{11111111-2222-3333-4444-555555555555}"),
    content="true",
  )
  inspect(
    roundtrip_sheet_xml.contains("<mbt:value>keep-me</mbt:value>"),
    content="true",
  )
  inspect(roundtrip_sheet_xml.contains("x14:sparklineGroups"), content="true")
  inspect(
    roundtrip_sheet_xml.contains("x14:conditionalFormattings"),
    content="true",
  )
  inspect(roundtrip_sheet_xml.contains("x14:slicerList"), content="true")
  inspect(
    count_xml_tag_unknown_ext(
      roundtrip_sheet_xml, "{11111111-2222-3333-4444-555555555555}",
    ),
    content="1",
  )
}
