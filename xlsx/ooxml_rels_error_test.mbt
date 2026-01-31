///|
fn rewrite_zip_entry(
  archive : @zip.Archive,
  path : String,
  bytes : Bytes,
) -> Bytes raise Error {
  let updated = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name != path {
      updated.add(
        entry.name,
        entry.data,
        compression=entry.compression,
        data_descriptor=entry.data_descriptor,
      )
    }
  }
  updated.add(path, bytes)
  @zip.write(updated)
}

///|
test "ooxml rels: relationship tag not closed" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let bad = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
    "<Relationship "
  let updated = rewrite_zip_entry(
    archive,
    "xl/_rels/workbook.xml.rels",
    @encoding/utf8.encode(bad),
  )
  let result : Result[Workbook, Error] = try? read(updated)
  match result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="relationship tag not closed")
    _ => fail("expected InvalidXml for relationship tag not closed")
  }
}

///|
test "ooxml rels: relationship id missing" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let bad = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
    "  <Relationship Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>\n" +
    "</Relationships>"
  let updated = rewrite_zip_entry(
    archive,
    "xl/_rels/workbook.xml.rels",
    @encoding/utf8.encode(bad),
  )
  let result : Result[Workbook, Error] = try? read(updated)
  match result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="relationship id missing")
    _ => fail("expected InvalidXml for relationship id missing")
  }
}

///|
test "ooxml rels: relationship target missing" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let bad = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
    "  <Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\"/>\n" +
    "</Relationships>"
  let updated = rewrite_zip_entry(
    archive,
    "xl/_rels/workbook.xml.rels",
    @encoding/utf8.encode(bad),
  )
  let result : Result[Workbook, Error] = try? read(updated)
  match result {
    Err(XlsxError::InvalidXml(msg~)) =>
      inspect(msg, content="relationship target missing")
    _ => fail("expected InvalidXml for relationship target missing")
  }
}

///|
test "ooxml rels: expanded Relationship tags still read" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let rels_bytes = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => value
    None => fail("missing workbook.xml.rels")
  }
  let rels_xml = @encoding/utf8.decode(rels_bytes) catch {
    _ => fail("workbook.xml.rels utf8 decode failed")
  }
  let expanded = rels_xml.replace_all(old="/>", new="></Relationship>")
  let updated = rewrite_zip_entry(
    archive,
    "xl/_rels/workbook.xml.rels",
    @encoding/utf8.encode(expanded),
  )
  let parsed = read(updated)
  inspect(parsed.get_sheet_list(), content="[\"Sheet1\"]")
}

///|
test "ooxml rels: workbook targets with ../ prefix" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let rels_bytes = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => value
    None => fail("missing workbook.xml.rels")
  }
  let rels_xml = @encoding/utf8.decode(rels_bytes) catch {
    _ => fail("workbook.xml.rels utf8 decode failed")
  }
  let patched = rels_xml.replace_all(old="Target=\"", new="Target=\"../")
  let updated = rewrite_zip_entry(
    archive,
    "xl/_rels/workbook.xml.rels",
    @encoding/utf8.encode(patched),
  )
  let parsed = read(updated)
  inspect(parsed.get_sheet_list(), content="[\"Sheet1\"]")
}

///|
test "ooxml rels: workbook targets with xl/ prefix" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let rels_bytes = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => value
    None => fail("missing workbook.xml.rels")
  }
  let rels_xml = @encoding/utf8.decode(rels_bytes) catch {
    _ => fail("workbook.xml.rels utf8 decode failed")
  }
  let patched = rels_xml.replace_all(old="Target=\"", new="Target=\"xl/")
  let updated = rewrite_zip_entry(
    archive,
    "xl/_rels/workbook.xml.rels",
    @encoding/utf8.encode(patched),
  )
  let parsed = read(updated)
  inspect(parsed.get_sheet_list(), content="[\"Sheet1\"]")
}
