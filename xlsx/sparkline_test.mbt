///|
test "sparkline write" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_sparkline("B2", "A1:A3")
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("sparklineGroups"), content="true")
  inspect(
    sheet_xml.contains(
      "xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\"",
    ),
    content="true",
  )
  inspect(
    sheet_xml.contains(
      "xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"",
    ),
    content="true",
  )
  inspect(sheet_xml.contains("mc:Ignorable=\"x14\""), content="true")
  inspect(sheet_xml.contains("<xm:f>'Sheet1'!A1:A3</xm:f>"), content="true")
  inspect(sheet_xml.contains("<xm:sqref>B2</xm:sqref>"), content="true")
}

///|
test "sparkline roundtrip" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_sparkline("C3", "A1:A2", sparkline_type=Column)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet")
  }
  inspect(parsed_sheet.sparkline_groups().length(), content="1")
  inspect(
    parsed_sheet.sparkline_groups()[0].sparklines[0].range_ref,
    content="A1:A2",
  )
  inspect(
    parsed_sheet.sparkline_groups()[0].sparklines[0].location,
    content="C3",
  )
}

///|
test "sparkline inputs mismatch" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let result = try sheet.add_sparkline_group(["A1"], ["A1", "A2"]) catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  debug_inspect(
    result,
    content="Err(InvalidSparkline(msg=\"sparkline inputs mismatch\"))",
  )
}
