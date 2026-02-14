///|
test "read: missing legacyDrawing vml relationship errors" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_form_control("Sheet1", FormControl::new("A1", "Button"))
  let bytes = write(workbook)

  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
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
    err => fail("zip write failed: \{err}")
  }

  let result : Result[Workbook, Error] = try? read(updated_bytes)
  match result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="vml drawing relationship missing")
    _ => fail("expected InvalidXml for missing legacyDrawing vml relationship")
  }
}

///|
test "read: missing legacyDrawingHF vml relationship errors" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_header_footer(
    Some(HeaderFooterOptions::with_values(odd_header="&L&G")),
  )
  sheet.add_header_footer_image(
    HeaderFooterImageOptions::new(
      Left,
      [1, 2, 3],
      ".png",
      width="10pt",
      height="10pt",
    ),
  )
  let bytes = write(workbook)

  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
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
    err => fail("zip write failed: \{err}")
  }

  let result : Result[Workbook, Error] = try? read(updated_bytes)
  match result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="vml drawing hf relationship missing")
    _ =>
      fail("expected InvalidXml for missing legacyDrawingHF vml relationship")
  }
}
