///|
fn rewrite_zip_entry(
  archive : @zip.Archive,
  path : String,
  bytes : Bytes,
) -> Bytes raise Error {
  let updated = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() != path {
      updated.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  updated.add(path, bytes)
  @zip.write(updated)
}

///|
fn decode_zip_entry_utf8(
  archive : @zip.Archive,
  path : String,
) -> String raise Error {
  let value = match archive.get(path) {
    Some(bytes) => bytes
    None => fail("missing \{path}")
  }
  @encoding/utf8.decode(value) catch {
    _ => fail("\{path} utf8 decode failed")
  }
}

///|
fn prepend_relationship(
  rels_xml : String,
  rel_id : String,
  rel_type : String,
  target : String,
) -> String {
  let open_tag = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
  rels_xml.replace_all(
    old=open_tag,
    new=open_tag +
      "\n  <Relationship Id=\"\{rel_id}\" Type=\"\{rel_type}\" Target=\"\{target}\"/>",
  )
}

///|
fn first_drawing_rels_path(archive : @zip.Archive) -> String raise Error {
  for entry in archive.entries() {
    if entry.name().has_prefix("xl/drawings/_rels/drawing") &&
      entry.name().has_suffix(".xml.rels") {
      return entry.name()
    }
  }
  fail("missing drawing rels path")
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
  let result = try? read(updated)
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
  let result = try? read(updated)
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
  let result = try? read(updated)
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
  debug_inspect(parsed.get_sheet_list(), content="[\"Sheet1\"]")
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
  debug_inspect(parsed.get_sheet_list(), content="[\"Sheet1\"]")
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
  debug_inspect(parsed.get_sheet_list(), content="[\"Sheet1\"]")
}

///|
test "ooxml rels: workbook part path discovered from [Content_Types]" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let workbook_xml = match archive.get("xl/workbook.xml") {
    Some(value) => value
    None => fail("missing workbook.xml")
  }
  let workbook_rels = match archive.get("xl/_rels/workbook.xml.rels") {
    Some(value) => value
    None => fail("missing workbook.xml.rels")
  }
  let content_types_xml = match archive.get("[Content_Types].xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("content types utf8 decode failed")
      }
    None => fail("missing [Content_Types].xml")
  }
  let patched_content_types = content_types_xml.replace_all(
    old="PartName=\"/xl/workbook.xml\"",
    new="PartName=\"/xl/workbook2.xml\"",
  )
  let updated = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() == "xl/workbook.xml" ||
      entry.name() == "xl/_rels/workbook.xml.rels" ||
      entry.name() == "[Content_Types].xml" {
      continue
    }
    updated.add(
      entry.name(),
      entry.data(),
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  updated.add("xl/workbook2.xml", workbook_xml)
  updated.add("xl/_rels/workbook2.xml.rels", workbook_rels)
  updated.add(
    "[Content_Types].xml",
    @encoding/utf8.encode(patched_content_types),
  )
  let updated_bytes = @zip.write(updated) catch {
    err => fail("zip write failed: \{err}")
  }
  let parsed = read(updated_bytes)
  debug_inspect(parsed.get_sheet_list(), content="[\"Sheet1\"]")
}

///|
test "ooxml rels: pivot cache rels tolerate stale first entries and mixed targets" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  ignore(
    sheet.add_pivot_table_xml(
      "<pivotTableDefinition name=\"PivotRelTarget\"/>",
      "<pivotCacheDefinition/>",
      cache_records_xml="<pivotCacheRecords count=\"0\"/>",
    ),
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let pivot_rels_path = "xl/pivotTables/_rels/pivotTable1.xml.rels"
  let pivot_rels_xml = decode_zip_entry_utf8(archive, pivot_rels_path)
  let patched_pivot_rels = prepend_relationship(
    pivot_rels_xml, "rId0", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/pivotCacheDefinition",
    "../pivotCache/ghostCache.xml",
  ).replace_all(
    old="Target=\"../pivotCache/pivotCacheDefinition1.xml\"",
    new="Target=\"/xl/pivotCache/pivotCacheDefinition1.xml\"",
  )
  let bytes_after_pivot_rels = rewrite_zip_entry(
    archive,
    pivot_rels_path,
    @encoding/utf8.encode(patched_pivot_rels),
  ) catch {
    err => fail("zip rewrite failed: \{err}")
  }
  let archive_after_pivot_rels = @zip.read(bytes_after_pivot_rels) catch {
    err => fail("zip read after pivot rel rewrite failed: \{err}")
  }
  let cache_rels_path = "xl/pivotCache/_rels/pivotCacheDefinition1.xml.rels"
  let cache_rels_xml = decode_zip_entry_utf8(
    archive_after_pivot_rels, cache_rels_path,
  )
  let patched_cache_rels = prepend_relationship(
    cache_rels_xml, "rId0", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/pivotCacheRecords",
    "pivotCacheGhostRecords.xml",
  ).replace_all(
    old="Target=\"pivotCacheRecords1.xml\"",
    new="Target=\"xl/pivotCache/pivotCacheRecords1.xml\"",
  )
  let updated = rewrite_zip_entry(
    archive_after_pivot_rels,
    cache_rels_path,
    @encoding/utf8.encode(patched_cache_rels),
  ) catch {
    err => fail("zip rewrite failed: \{err}")
  }
  let parsed = read(updated)
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing sheet after read")
  }
  inspect(parsed_sheet.pivot_tables().length(), content="1")
  let pivot = parsed_sheet.pivot_tables()[0]
  inspect(pivot.name, content="PivotRelTarget")
  inspect(pivot.cache_records_xml is Some(_), content="true")
}

///|
test "ooxml rels: chartsheet chart rels tolerate stale first entries and mixed targets" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let chart_xml =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart">
    #|  <c:chart/>
    #|</c:chartSpace>
  ignore(workbook.add_chart_sheet("Chart1", chart_xml))
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_rels_path = first_drawing_rels_path(archive)
  let drawing_rels_xml = decode_zip_entry_utf8(archive, drawing_rels_path)
  let patched_drawing_rels = prepend_relationship(
    drawing_rels_xml, "rId0", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart",
    "../charts/ghostChart.xml",
  ).replace_all(
    old="Target=\"../charts/chart1.xml\"",
    new="Target=\"/xl/charts/chart1.xml\"",
  )
  let updated = rewrite_zip_entry(
    archive,
    drawing_rels_path,
    @encoding/utf8.encode(patched_drawing_rels),
  ) catch {
    err => fail("zip rewrite failed: \{err}")
  }
  let parsed = read(updated)
  inspect(parsed.chart_sheets().length(), content="1")
  let parsed_chart = parsed.chart_sheets()[0]
  inspect(parsed_chart.name(), content="Chart1")
  inspect(parsed_chart.chart_xml().contains("<c:chartSpace"), content="true")
}
