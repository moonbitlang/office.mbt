///|
test "slicer: Slicer::new validation and cache sanitization" {
  let empty : Result[Slicer, Error] = try? Slicer::new("")
  inspect(empty is Err(XlsxError::InvalidSheetOperation(_)), content="true")
  let s1 = Slicer::new("1.a")
  inspect(s1.cache, content="Slicer__.a")
  let s2 = Slicer::new("A-1")
  inspect(s2.cache, content="Slicer_A_1")
}

///|
test "slicer: pivot cache xml generation" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  // Minimal pivot that exposes a cacheField named \"Region\" for slicer discovery.
  ignore(
    sheet.add_pivot_table_xml(
      "<pivotTableDefinition name=\"Pivot1\"/>",
      "<pivotCacheDefinition><cacheFields count=\"1\"><cacheField name=\"Region\"/></cacheFields></pivotCacheDefinition>",
      name="Pivot1",
    ),
  )
  let opts = SlicerOptions::new("Region", "E1", "Sheet1", "Pivot1")
  opts.set_item_desc(true)
  workbook.add_slicer("Sheet1", opts)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let cache_xml = match archive.get("xl/slicerCaches/slicerCache1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing slicerCache1.xml")
  }
  inspect(cache_xml.contains("<pivotTables>"), content="true")
  inspect(cache_xml.contains("name=\"Pivot1\""), content="true")
  inspect(cache_xml.contains("sortOrder=\"descending\""), content="true")
  inspect(
    cache_xml.contains(
      "xmlns:xr10=\"http://schemas.microsoft.com/office/spreadsheetml/2016/revision10\"",
    ),
    content="true",
  )
  inspect(
    cache_xml.contains(
      "xmlns:xr10=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\"",
    ),
    content="false",
  )
  inspect(cache_xml.contains("pivotCacheId=\"1\""), content="true")
  let slicer_xml = match archive.get("xl/slicers/slicer1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing slicer1.xml")
  }
  inspect(
    slicer_xml.contains(
      "xmlns:xr10=\"http://schemas.microsoft.com/office/spreadsheetml/2016/revision10\"",
    ),
    content="true",
  )
  let pivot_cache_xml = match
    archive.get("xl/pivotCache/pivotCacheDefinition1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing pivotCacheDefinition1.xml")
  }
  inspect(
    pivot_cache_xml.contains(
      "xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\"",
    ),
    content="true",
  )
  inspect(
    pivot_cache_xml.contains("<x14:pivotCacheDefinition pivotCacheId=\"1\"/>"),
    content="true",
  )
  let parsed = read(bytes)
  let slicers = parsed.get_slicers("Sheet1")
  inspect(slicers.length(), content="1")
  inspect(slicers[0].source_name, content="Region")
  inspect(slicers[0].item_desc, content="true")
}
