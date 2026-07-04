///|
test "x14 conditional formatting iconSet read" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }
  let ext_block = "  <extLst><ext uri=\"{78C0D931-6437-407d-A8EE-F0AAD7539E65}\"><x14:conditionalFormattings xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" xmlns:xm=\"http://schemas.microsoft.com/office/excel/2006/main\"><x14:conditionalFormatting><xm:sqref>A1:A3</xm:sqref><x14:cfRule type=\"iconSet\" priority=\"1\" stopIfTrue=\"1\"><x14:iconSet iconSet=\"3Stars\" showValue=\"0\" reverse=\"1\"/></x14:cfRule></x14:conditionalFormatting></x14:conditionalFormattings></ext></extLst>\n"
  let updated_sheet = sheet_xml.replace_all(
    old="</worksheet>",
    new="\{ext_block}</worksheet>",
  )
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
  let parsed = read(updated_bytes)
  let formats = parsed.get_conditional_formats("Sheet1")
  let opts = match formats.get("A1:A3") {
    Some(value) => value
    None => fail("missing x14 conditional formats")
  }
  inspect(opts.length(), content="1")
  inspect(opts[0].format_type, content="icon_set")
  inspect(opts[0].icon_style, content="3Stars")
  inspect(opts[0].icons_only, content="true")
  inspect(opts[0].reverse_icons, content="true")
  inspect(opts[0].stop_if_true, content="true")
}
