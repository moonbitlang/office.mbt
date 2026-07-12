///|
/// Emit the shared `<?xml ...?>` + opening `<Relationships>` preamble.
fn write_rels_open(sb : StringBuilder) -> Unit {
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n",
  )
}

///|
/// Emit one `<Relationship>` element (two-space indented, newline-terminated).
/// `external` adds `TargetMode="External"`. Centralizing the element format
/// keeps every rels writer byte-identical.
fn write_relationship(
  sb : StringBuilder,
  rel_id : Int,
  rel_type : String,
  target : String,
  external? : Bool = false,
) -> Unit {
  sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
  sb.write_view(rel_type)
  sb.write_view("\" Target=\"")
  sb.write_view(escape_xml_attr(target))
  if external {
    sb.write_view("\" TargetMode=\"External\"/>\n")
  } else {
    sb.write_view("\"/>\n")
  }
}

///|
fn write_sheet_rels_xml(
  drawing_target : String?,
  table_targets : ArrayView[String],
  pivot_table_targets : ArrayView[String],
  slicer_targets : ArrayView[String],
  hyperlink_targets : ArrayView[String],
  comment_targets : ArrayView[String],
  vml_targets : ArrayView[String],
  image_targets : ArrayView[String],
) -> String {
  let sb = StringBuilder::new()
  write_rels_open(sb)
  let mut rel_id = 1
  match drawing_target {
    Some(target) => {
      write_relationship(sb, rel_id, rel_drawing, target)
      rel_id = rel_id + 1
    }
    None => ()
  }
  for target in table_targets {
    write_relationship(sb, rel_id, rel_table, target)
    rel_id = rel_id + 1
  }
  for target in pivot_table_targets {
    write_relationship(sb, rel_id, rel_pivot_table, target)
    rel_id = rel_id + 1
  }
  for target in slicer_targets {
    write_relationship(sb, rel_id, rel_slicer, target)
    rel_id = rel_id + 1
  }
  for target in hyperlink_targets {
    write_relationship(sb, rel_id, rel_hyperlink, target, external=true)
    rel_id = rel_id + 1
  }
  for target in comment_targets {
    write_relationship(sb, rel_id, rel_comments, target)
    rel_id = rel_id + 1
  }
  for target in vml_targets {
    write_relationship(sb, rel_id, rel_vml, target)
    rel_id = rel_id + 1
  }
  for target in image_targets {
    write_relationship(sb, rel_id, rel_image, target)
    rel_id = rel_id + 1
  }
  sb.write_view("</Relationships>")
  sb.to_string()
}

///|
fn write_pivot_table_rels_xml(cache_id : Int) -> String {
  let sb = StringBuilder::new()
  write_rels_open(sb)
  write_relationship(
    sb,
    1,
    rel_pivot_cache,
    "../pivotCache/pivotCacheDefinition\{cache_id}.xml",
  )
  sb.write_view("</Relationships>")
  sb.to_string()
}

///|
fn write_pivot_cache_rels_xml(cache_id : Int) -> String {
  let sb = StringBuilder::new()
  write_rels_open(sb)
  write_relationship(
    sb,
    1,
    rel_pivot_cache_records,
    "pivotCacheRecords\{cache_id}.xml",
  )
  sb.write_view("</Relationships>")
  sb.to_string()
}

///|
fn write_drawing_rels_xml(
  image_targets : Array[(Int, String)],
  chart_targets : Array[(Int, String)],
  hyperlink_targets : Array[DrawingHyperlink],
) -> String {
  let sb = StringBuilder::new()
  write_rels_open(sb)
  for entry in image_targets {
    let (rel_id, target) = entry
    write_relationship(sb, rel_id, rel_image, target)
  }
  for entry in chart_targets {
    let (rel_id, target) = entry
    write_relationship(sb, rel_id, rel_chart, target)
  }
  for entry in hyperlink_targets {
    write_relationship(
      sb,
      entry.rel_id,
      rel_hyperlink,
      entry.target,
      external=entry.link_type == External,
    )
  }
  sb.write_view("</Relationships>")
  sb.to_string()
}

///|
fn write_vml_rels_xml(image_targets : Array[String]) -> String {
  let sb = StringBuilder::new()
  write_rels_open(sb)
  let mut rel_id = 1
  for target in image_targets {
    write_relationship(sb, rel_id, rel_image, target)
    rel_id = rel_id + 1
  }
  sb.write_view("</Relationships>")
  sb.to_string()
}

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
