///|
test "unset_conditional_format updates x14 data bar sqref" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opt = ConditionalFormatOptions::new("data_bar")
  opt.set_min_type("min")
  opt.set_max_type("max")
  opt.set_bar_color("#638EC6")
  opt.set_bar_border_color("#0000FF")
  opt.set_bar_direction("rightToLeft")
  opt.set_bar_solid(true)
  workbook.set_conditional_format("Sheet1", "A5:A10 A15:A20 A3:A4", [opt])
  workbook.unset_conditional_format("Sheet1", "A7")
  let formats = workbook.get_conditional_formats("Sheet1")
  inspect(formats.length(), content="1")
  inspect(formats.get("A3:A6 A8:A10 A15:A20") is Some(_), content="true")
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sheet1.xml")
  }
  inspect(
    sheet_xml.contains("<xm:sqref>A3:A6 A8:A10 A15:A20</xm:sqref>"),
    content="true",
  )
}
