///|
test "read: missing legacyDrawing vml relationship errors" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_form_control("Sheet1", @xlsx.FormControl::new("A1", "Button"))
  let bytes = @xlsx.write(workbook)

  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let bad_rels =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|</Relationships>
  let updated = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() != "xl/worksheets/_rels/sheet1.xml.rels" {
      updated.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  updated.add(
    "xl/worksheets/_rels/sheet1.xml.rels",
    @encoding/utf8.encode(bad_rels),
  )
  let updated_bytes = @zip.write(updated) catch {
    err => fail("zip write failed: \{repr(err)}")
  }

  let result : Result[@xlsx.Workbook, Error] = Ok(@xlsx.read(updated_bytes)) catch {
    e => Err(e)
  }
  match result {
    Err(@xlsx.XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="vml drawing relationship missing")
    _ => fail("expected InvalidXml for missing legacyDrawing vml relationship")
  }
}

///|
test "read: missing legacyDrawingHF vml relationship errors" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_header_footer(
    Some(@xlsx.HeaderFooterOptions::with_values(odd_header="&L&G")),
  )
  sheet.add_header_footer_image(
    @xlsx.HeaderFooterImageOptions::new(
      Left,
      [1, 2, 3],
      ".png",
      width="10pt",
      height="10pt",
    ),
  )
  let bytes = @xlsx.write(workbook)

  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let bad_rels =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    #|</Relationships>
  let updated = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() != "xl/worksheets/_rels/sheet1.xml.rels" {
      updated.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  updated.add(
    "xl/worksheets/_rels/sheet1.xml.rels",
    @encoding/utf8.encode(bad_rels),
  )
  let updated_bytes = @zip.write(updated) catch {
    err => fail("zip write failed: \{repr(err)}")
  }

  let result : Result[@xlsx.Workbook, Error] = Ok(@xlsx.read(updated_bytes)) catch {
    e => Err(e)
  }
  match result {
    Err(@xlsx.XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="vml drawing hf relationship missing")
    _ =>
      fail("expected InvalidXml for missing legacyDrawingHF vml relationship")
  }
}
