///|
test "vba project write" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let vba_header : Array[Byte] = [
    0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1,
  ]
  let vba_bytes : Bytes = Bytes::from_array(vba_header)
  workbook.add_vbaproject(vba_bytes)
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let vba_part = match archive.get("xl/vbaProject.bin") {
    Some(value) => value
    None => fail("missing vba project")
  }
  inspect(vba_part == vba_bytes, content="true")
  let rels_xml = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing workbook rels")
  }
  inspect(rels_xml.contains("vbaProject.bin"), content="true")
  inspect(
    rels_xml.contains(
      "http://schemas.microsoft.com/office/2006/relationships/vbaProject",
    ),
    content="true",
  )
  let types_xml = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(
    types_xml.contains("application/vnd.ms-office.vbaProject"),
    content="true",
  )
  inspect(
    types_xml.contains("application/vnd.ms-excel.sheet.macroEnabled.main+xml"),
    content="true",
  )
}

///|
test "vba project roundtrip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let vba_header : Array[Byte] = [
    0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1,
  ]
  let vba_bytes : Bytes = Bytes::from_array(vba_header)
  workbook.add_vba_project(vba_bytes)
  let bytes = @xlsx.write(workbook)
  let workbook2 = @xlsx.read(bytes)
  let bytes2 = @xlsx.write(workbook2)
  let archive2 = @zip.read(bytes2)
  let vba_part2 = match archive2.get("xl/vbaProject.bin") {
    Some(value) => value
    None => fail("missing vba project after roundtrip")
  }
  inspect(vba_part2 == vba_bytes, content="true")
}

///|
test "vba project invalid bytes" {
  let workbook = @xlsx.Workbook::new()
  let invalid : Bytes = Bytes::from_array([0x00, 0x01, 0x02])
  let result : Result[Unit, Error] = Ok(workbook.add_vba_project(invalid)) catch {
    e => Err(e)
  }
  match result {
    Err(@xlsx.XlsxError::InvalidVBAProject(msg~)) =>
      inspect(msg, content="unsupported vba project")
    _ => fail("expected invalid vba project error")
  }
}
