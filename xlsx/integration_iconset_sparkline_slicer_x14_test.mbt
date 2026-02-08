///|
test "integration x14 icon-set with sparkline and slicer coexistence" {
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

  let sparkline_opts = SparklineOptions::new(
    ["G2", "G3", "G4"],
    ["'Data'!B2:B5", "'Data'!B2:B5", "'Data'!B2:B5"],
  )
  sparkline_opts.set_markers(true)
  workbook.add_sparkline_options("Dash", sparkline_opts)

  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing dash xml")
  }
  let icon_ext_block = "    <ext uri=\"{78C0D931-6437-407d-A8EE-F0AAD7539E65}\"><x14:conditionalFormattings xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" xmlns:xm=\"http://schemas.microsoft.com/office/excel/2006/main\"><x14:conditionalFormatting><xm:sqref>C2:C4</xm:sqref><x14:cfRule type=\"iconSet\" priority=\"1\" stopIfTrue=\"1\"><x14:iconSet iconSet=\"3Stars\" showValue=\"0\" reverse=\"1\"/></x14:cfRule></x14:conditionalFormatting></x14:conditionalFormattings></ext>\n"
  let updated_sheet = if sheet_xml.contains("</extLst>\n</worksheet>") {
    sheet_xml.replace_all(
      old="</extLst>\n</worksheet>",
      new="\{icon_ext_block}  </extLst>\n</worksheet>",
    )
  } else {
    fail("expected extLst for sparkline+slicer worksheet")
  }

  let updated_archive = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name != "xl/worksheets/sheet2.xml" {
      updated_archive.add(
        entry.name,
        entry.data,
        compression=entry.compression,
        data_descriptor=entry.data_descriptor,
      )
    }
  }
  updated_archive.add(
    "xl/worksheets/sheet2.xml",
    @encoding/utf8.encode(updated_sheet),
  )
  let updated_bytes = @zip.write(updated_archive) catch {
    err => fail("zip write failed: \{err}")
  }

  let updated = @zip.read(updated_bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let updated_sheet_xml = match updated.get("xl/worksheets/sheet2.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing updated dash xml")
  }
  inspect(updated_sheet_xml.contains("{78C0D931-6437-407d-A8EE-F0AAD7539E65}"), content="true")
  inspect(updated_sheet_xml.contains("{05C60535-1F16-4fd2-B633-F4F36F0B64E0}"), content="true")
  inspect(
    updated_sheet_xml.contains("{A8765BA9-456A-4dab-B4F3-ACF838C121DE}") ||
      updated_sheet_xml.contains("{3A4CF648-6AED-40f4-86FF-DC5316D8AED3}"),
    content="true",
  )
  inspect(updated_sheet_xml.contains("x14:conditionalFormattings"), content="true")
  inspect(updated_sheet_xml.contains("x14:sparklineGroups"), content="true")
  inspect(updated_sheet_xml.contains("x14:slicerList"), content="true")

  let parsed = read(updated_bytes)
  let dash = match parsed.sheet("Dash") {
    Some(value) => value
    None => fail("missing parsed dash")
  }
  inspect(dash.sparkline_groups().length(), content="1")
  let slicers = parsed.get_slicers("Dash")
  inspect(slicers.length(), content="1")
  let formats = parsed.get_conditional_formats("Dash")
  let opts = match formats.get("C2:C4") {
    Some(value) => value
    None => fail("missing x14 icon-set conditional format")
  }
  inspect(opts.length(), content="1")
  inspect(opts[0].format_type, content="icon_set")
  inspect(opts[0].icon_style, content="3Stars")
  inspect(opts[0].icons_only, content="true")
  inspect(opts[0].reverse_icons, content="true")
  inspect(opts[0].stop_if_true, content="true")
}
