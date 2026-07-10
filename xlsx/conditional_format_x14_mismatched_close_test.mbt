///|
test "x14 conditional formatting mismatched close rejects read" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }
  let ext_block = "  <extLst><ext uri=\"{78C0D931-6437-407d-A8EE-F0AAD7539E65}\"><x14:conditionalFormattings xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" xmlns:xm=\"http://schemas.microsoft.com/office/excel/2006/main\"></x14:conditionalFormatting></x14:conditionalFormattings></ext></extLst>\n"
  let updated_sheet = sheet_xml.replace_all(
    old="</worksheet>",
    new="\{ext_block}</worksheet>",
  )
  if !updated_sheet.contains("</x14:conditionalFormatting>") {
    fail("fixture not injected")
  }
  let updated_archive = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() != "xl/worksheets/sheet1.xml" {
      updated_archive.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  updated_archive.add(
    "xl/worksheets/sheet1.xml",
    @encoding/utf8.encode(updated_sheet),
  )
  let updated_bytes = @zip.write(updated_archive) catch {
    err => fail("zip write failed: \{repr(err)}")
  }
  let result : Result[@xlsx.Workbook, Error] = Ok(@xlsx.read(updated_bytes)) catch {
    e => Err(e)
  }
  match result {
    Ok(_) => fail("expected invalid xml error")
    Err(@xlsx.XlsxError::InvalidXml(_)) => ()
    Err(err) => fail("unexpected error: \{err}")
  }
}
