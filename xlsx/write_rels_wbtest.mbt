///|
test "write rels xml: sheet relationships include expected relationship types" {
  let xml = write_sheet_rels_xml(
    Some("../drawings/drawing7.xml"),
    ["../tables/table2.xml"],
    ["../pivotTables/pivotTable5.xml"],
    ["../slicers/slicer4.xml"],
    ["https://example.com"],
    ["../comments1.xml"],
    ["../drawings/vmlDrawing3.vml"],
    ["../media/image8.png"],
  )
  inspect(
    xml.contains(
      "Id=\"rId1\" Type=\"\{rel_drawing}\" Target=\"../drawings/drawing7.xml\"",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "Id=\"rId2\" Type=\"\{rel_table}\" Target=\"../tables/table2.xml\"",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "Id=\"rId3\" Type=\"\{rel_pivot_table}\" Target=\"../pivotTables/pivotTable5.xml\"",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "Id=\"rId4\" Type=\"\{rel_slicer}\" Target=\"../slicers/slicer4.xml\"",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "Id=\"rId5\" Type=\"\{rel_hyperlink}\" Target=\"https://example.com\" TargetMode=\"External\"",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "Id=\"rId6\" Type=\"\{rel_comments}\" Target=\"../comments1.xml\"",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "Id=\"rId7\" Type=\"\{rel_vml}\" Target=\"../drawings/vmlDrawing3.vml\"",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "Id=\"rId8\" Type=\"\{rel_image}\" Target=\"../media/image8.png\"",
    ),
    content="true",
  )
}

///|
test "write rels xml: pivot table and cache rels point to cache parts" {
  let pivot_xml = write_pivot_table_rels_xml(12)
  inspect(
    pivot_xml.contains(
      "Type=\"\{rel_pivot_cache}\" Target=\"../pivotCache/pivotCacheDefinition12.xml\"",
    ),
    content="true",
  )
  let cache_xml = write_pivot_cache_rels_xml(12)
  inspect(
    cache_xml.contains(
      "Type=\"\{rel_pivot_cache_records}\" Target=\"pivotCacheRecords12.xml\"",
    ),
    content="true",
  )
}

///|
test "write rels xml: drawing relationships preserve hyperlink target modes" {
  let xml = write_drawing_rels_xml(
    [(2, "../media/image1.png")],
    [(3, "../charts/chart1.xml")],
    [
      { rel_id: 4, target: "https://example.com", link_type: External },
      { rel_id: 5, target: "Sheet1!A1", link_type: Location },
    ],
  )
  inspect(
    xml.contains(
      "Id=\"rId2\" Type=\"\{rel_image}\" Target=\"../media/image1.png\"",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "Id=\"rId3\" Type=\"\{rel_chart}\" Target=\"../charts/chart1.xml\"",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "Id=\"rId4\" Type=\"\{rel_hyperlink}\" Target=\"https://example.com\" TargetMode=\"External\"",
    ),
    content="true",
  )
  inspect(
    xml.contains("Id=\"rId5\" Type=\"\{rel_hyperlink}\" Target=\"Sheet1!A1\"/>"),
    content="true",
  )
}

///|
test "write rels xml: vml rels enumerate image targets with incremental rIds" {
  let xml = write_vml_rels_xml(["../media/image1.png", "../media/image2.png"])
  inspect(
    xml.contains(
      "Id=\"rId1\" Type=\"\{rel_image}\" Target=\"../media/image1.png\"",
    ),
    content="true",
  )
  inspect(
    xml.contains(
      "Id=\"rId2\" Type=\"\{rel_image}\" Target=\"../media/image2.png\"",
    ),
    content="true",
  )
}
