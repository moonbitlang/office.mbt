///|
test "write part paths: worksheet and drawing paths are stable" {
  debug_inspect(
    (worksheet_part_path(4), worksheet_rels_part_path(4)),
    content="(\"xl/worksheets/sheet4.xml\", \"xl/worksheets/_rels/sheet4.xml.rels\")",
  )
  debug_inspect(
    (drawing_part_path(3), drawing_rels_part_path(3)),
    content="(\"xl/drawings/drawing3.xml\", \"xl/drawings/_rels/drawing3.xml.rels\")",
  )
  debug_inspect(
    (chartsheet_part_path(2), chartsheet_rels_part_path(2)),
    content="(\"xl/chartsheets/sheet2.xml\", \"xl/chartsheets/_rels/sheet2.xml.rels\")",
  )
  inspect(chart_part_path("chart7.xml"), content="xl/charts/chart7.xml")
}

///|
test "write part paths: pivot and slicer paths are stable" {
  debug_inspect(
    (
      pivot_table_part_path(9),
      pivot_table_rels_part_path(9),
      pivot_cache_definition_part_path(9),
      pivot_cache_definition_rels_part_path(9),
      pivot_cache_records_part_path(9),
    ),
    content=(
      #|(
      #|  "xl/pivotTables/pivotTable9.xml",
      #|  "xl/pivotTables/_rels/pivotTable9.xml.rels",
      #|  "xl/pivotCache/pivotCacheDefinition9.xml",
      #|  "xl/pivotCache/_rels/pivotCacheDefinition9.xml.rels",
      #|  "xl/pivotCache/pivotCacheRecords9.xml",
      #|)
    ),
  )
  debug_inspect(
    (slicer_part_path(5), slicer_cache_part_path(5)),
    content=(
      #|("xl/slicers/slicer5.xml", "xl/slicerCaches/slicerCache5.xml")
    ),
  )
}

///|
test "write part paths: static package part names and override path" {
  debug_inspect(
    (
      root_rels_part_path, content_types_part_path, workbook_part_path, workbook_rels_part_path,
    ),
    content=(
      #|(
      #|  "_rels/.rels",
      #|  "[Content_Types].xml",
      #|  "xl/workbook.xml",
      #|  "xl/_rels/workbook.xml.rels",
      #|)
    ),
  )
  debug_inspect(
    (
      shared_strings_part_path, calc_chain_part_path, styles_part_path, theme_part_path,
      vba_project_part_path,
    ),
    content=(
      #|(
      #|  "xl/sharedStrings.xml",
      #|  "xl/calcChain.xml",
      #|  "xl/styles.xml",
      #|  "xl/theme/theme1.xml",
      #|  "xl/vbaProject.bin",
      #|)
    ),
  )
  debug_inspect(
    (
      core_props_part_path,
      app_props_part_path,
      custom_props_part_path,
      content_override_path(drawing_part_path(6)),
      media_part_path("image3.png"),
    ),
    content=(
      #|(
      #|  "docProps/core.xml",
      #|  "docProps/app.xml",
      #|  "docProps/custom.xml",
      #|  "/xl/drawings/drawing6.xml",
      #|  "xl/media/image3.png",
      #|)
    ),
  )
}

///|
test "write part paths: read-side path helpers are stable" {
  debug_inspect(
    (
      archive_path_from_part_name("/xl/workbook.xml"),
      archive_path_from_part_name("xl/workbook.xml"),
      rels_path_for_part("xl/workbook.xml"),
      rels_path_for_part("workbook.xml"),
    ),
    content=(
      #|(
      #|  "xl/workbook.xml",
      #|  "xl/workbook.xml",
      #|  "xl/_rels/workbook.xml.rels",
      #|  "_rels/workbook.xml.rels",
      #|)
    ),
  )
}

///|
test "write part paths: invalid read-side path helpers raise InvalidXml" {
  let empty_part_result = Ok(archive_path_from_part_name("")) catch {
    e => Err(e)
  }
  match empty_part_result {
    Err(InvalidXml(msg~)) =>
      inspect(msg, content="content type part name empty")
    _ => fail("expected content type part name empty")
  }

  let slash_part_result = Ok(archive_path_from_part_name("/")) catch {
    e => Err(e)
  }
  match slash_part_result {
    Err(InvalidXml(msg~)) =>
      inspect(msg, content="content type part name empty")
    _ => fail("expected content type part name empty for /")
  }

  let empty_rels_result = Ok(rels_path_for_part("")) catch { e => Err(e) }
  match empty_rels_result {
    Err(InvalidXml(msg~)) => inspect(msg, content="part rels path invalid")
    _ => fail("expected part rels path invalid")
  }

  let slash_rels_result = Ok(rels_path_for_part("/xl/workbook.xml")) catch {
    e => Err(e)
  }
  match slash_rels_result {
    Err(InvalidXml(msg~)) => inspect(msg, content="part rels path invalid")
    _ => fail("expected part rels path invalid for leading slash")
  }

  let trailing_slash_rels_result = Ok(rels_path_for_part("xl/")) catch {
    e => Err(e)
  }
  match trailing_slash_rels_result {
    Err(InvalidXml(msg~)) => inspect(msg, content="part rels path invalid")
    _ => fail("expected part rels path invalid for trailing slash")
  }
}

///|
test "write part paths: relationship targets are stable" {
  debug_inspect(
    (
      drawing_rel_target(3),
      table_rel_target(4),
      pivot_table_rel_target(5),
      slicer_rel_target(6),
      comment_rel_target(7),
      vml_rel_target(8),
      media_rel_target("image1.png"),
      chart_rel_target("chart9.xml"),
    ),
    content=(
      #|(
      #|  "../drawings/drawing3.xml",
      #|  "../tables/table4.xml",
      #|  "../pivotTables/pivotTable5.xml",
      #|  "../slicers/slicer6.xml",
      #|  "../comments7.xml",
      #|  "../drawings/vmlDrawing8.vml",
      #|  "../media/image1.png",
      #|  "../charts/chart9.xml",
      #|)
    ),
  )
  debug_inspect(
    (
      chartsheet_workbook_rel_target(2),
      slicer_cache_workbook_rel_target(3),
      pivot_cache_workbook_rel_target(4),
    ),
    content=(
      #|(
      #|  "chartsheets/sheet2.xml",
      #|  "slicerCaches/slicerCache3.xml",
      #|  "pivotCache/pivotCacheDefinition4.xml",
      #|)
    ),
  )
}
