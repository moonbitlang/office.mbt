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
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n",
  )
  let mut rel_id = 1
  match drawing_target {
    Some(target) => {
      sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
      sb.write_view(rel_drawing)
      sb.write_view("\" Target=\"")
      sb.write_view(escape_xml_attr(target))
      sb.write_view("\"/>\n")
      rel_id = rel_id + 1
    }
    None => ()
  }
  for target in table_targets {
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_table)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(target))
    sb.write_view("\"/>\n")
    rel_id = rel_id + 1
  }
  for target in pivot_table_targets {
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_pivot_table)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(target))
    sb.write_view("\"/>\n")
    rel_id = rel_id + 1
  }
  for target in slicer_targets {
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_slicer)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(target))
    sb.write_view("\"/>\n")
    rel_id = rel_id + 1
  }
  for target in hyperlink_targets {
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_hyperlink)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(target))
    sb.write_view("\" TargetMode=\"External\"/>\n")
    rel_id = rel_id + 1
  }
  for target in comment_targets {
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_comments)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(target))
    sb.write_view("\"/>\n")
    rel_id = rel_id + 1
  }
  for target in vml_targets {
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_vml)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(target))
    sb.write_view("\"/>\n")
    rel_id = rel_id + 1
  }
  for target in image_targets {
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_image)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(target))
    sb.write_view("\"/>\n")
    rel_id = rel_id + 1
  }
  sb.write_view("</Relationships>")
  sb.to_string()
}

///|
fn write_pivot_table_rels_xml(cache_id : Int) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n",
  )
  sb.write_view("  <Relationship Id=\"rId1\" Type=\"")
  sb.write_view(rel_pivot_cache)
  sb.write_view(
    "\" Target=\"../pivotCache/pivotCacheDefinition\{cache_id}.xml\"/>\n",
  )
  sb.write_view("</Relationships>")
  sb.to_string()
}

///|
fn write_pivot_cache_rels_xml(cache_id : Int) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n",
  )
  sb.write_view("  <Relationship Id=\"rId1\" Type=\"")
  sb.write_view(rel_pivot_cache_records)
  sb.write_view("\" Target=\"pivotCacheRecords\{cache_id}.xml\"/>\n")
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
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n",
  )
  for entry in image_targets {
    let (rel_id, target) = entry
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_image)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(target))
    sb.write_view("\"/>\n")
  }
  for entry in chart_targets {
    let (rel_id, target) = entry
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_chart)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(target))
    sb.write_view("\"/>\n")
  }
  for entry in hyperlink_targets {
    sb.write_view("  <Relationship Id=\"rId\{entry.rel_id}\" Type=\"")
    sb.write_view(rel_hyperlink)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(entry.target))
    sb.write_view("\"")
    if entry.link_type == External {
      sb.write_view(" TargetMode=\"External\"")
    }
    sb.write_view("/>\n")
  }
  sb.write_view("</Relationships>")
  sb.to_string()
}

///|
fn write_vml_rels_xml(image_targets : Array[String]) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n",
  )
  let mut rel_id = 1
  for target in image_targets {
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_image)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(target))
    sb.write_view("\"/>\n")
    rel_id = rel_id + 1
  }
  sb.write_view("</Relationships>")
  sb.to_string()
}
