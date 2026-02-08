///|
test "slicer duplicate names and cache reuse" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(
    workbook.add_table_with_columns("Sheet1", "A1:B4", "Table1", [
      "Column1", "Column2",
    ]),
  )
  let s1 = SlicerOptions::new("Column1", "E1", "Sheet1", "Table1")
  s1.set_caption("Column1")
  workbook.add_slicer("Sheet1", s1)
  let s2 = SlicerOptions::new("Column1", "I1", "Sheet1", "Table1")
  s2.set_caption("Column1")
  workbook.add_slicer("Sheet1", s2)
  let slicers = workbook.get_slicers("Sheet1")
  inspect(slicers.length(), content="2")
  inspect(slicers[0].name, content="Column1")
  inspect(slicers[1].name, content="Column1 1")
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let slicer_xml = match archive.get("xl/slicers/slicer1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing slicer1.xml")
  }
  inspect(slicer_xml.contains("name=\"Column1\""), content="true")
  inspect(slicer_xml.contains("name=\"Column1 1\""), content="true")
  match archive.get("xl/slicerCaches/slicerCache2.xml") {
    Some(_) => fail("unexpected slicerCache2.xml")
    None => ()
  }
}

///|
test "slicer options required-fields and size guards" {
  let missing : Result[SlicerOptions, Error] = try? SlicerOptions::new(
    "",
    "A1",
    "Sheet1",
    "Table1",
  )
  inspect(missing is Err(XlsxError::InvalidSheetOperation(_)), content="true")

  let opts = SlicerOptions::new("Region", "A1", "Sheet1", "Table1")
  let bad_size : Result[Unit, Error] = try? opts.set_size(0, 100)
  inspect(bad_size is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}
