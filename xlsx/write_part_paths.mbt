///|
let root_rels_part_path = "_rels/.rels"

///|
let content_types_part_path = "[Content_Types].xml"

///|
let workbook_part_path = "xl/workbook.xml"

///|
let workbook_rels_part_path = "xl/_rels/workbook.xml.rels"

///|
let shared_strings_part_path = "xl/sharedStrings.xml"

///|
let calc_chain_part_path = "xl/calcChain.xml"

///|
let styles_part_path = "xl/styles.xml"

///|
let theme_part_path = "xl/theme/theme1.xml"

///|
let core_props_part_path = "docProps/core.xml"

///|
let app_props_part_path = "docProps/app.xml"

///|
let custom_props_part_path = "docProps/custom.xml"

///|
let vba_project_part_path = "xl/vbaProject.bin"

///|
fn chart_part_path(file_name : String) -> String {
  "xl/charts/\{file_name}"
}

///|
fn worksheet_part_path(sheet_id : Int) -> String {
  "xl/worksheets/sheet\{sheet_id}.xml"
}

///|
fn worksheet_rels_part_path(sheet_id : Int) -> String {
  "xl/worksheets/_rels/sheet\{sheet_id}.xml.rels"
}

///|
fn drawing_part_path(drawing_id : Int) -> String {
  "xl/drawings/drawing\{drawing_id}.xml"
}

///|
fn drawing_rels_part_path(drawing_id : Int) -> String {
  "xl/drawings/_rels/drawing\{drawing_id}.xml.rels"
}

///|
fn chartsheet_part_path(sheet_id : Int) -> String {
  "xl/chartsheets/sheet\{sheet_id}.xml"
}

///|
fn chartsheet_rels_part_path(sheet_id : Int) -> String {
  "xl/chartsheets/_rels/sheet\{sheet_id}.xml.rels"
}

///|
fn table_part_path(table_id : Int) -> String {
  "xl/tables/table\{table_id}.xml"
}

///|
fn pivot_table_part_path(pivot_id : Int) -> String {
  "xl/pivotTables/pivotTable\{pivot_id}.xml"
}

///|
fn pivot_table_rels_part_path(pivot_id : Int) -> String {
  "xl/pivotTables/_rels/pivotTable\{pivot_id}.xml.rels"
}

///|
fn pivot_cache_definition_part_path(cache_id : Int) -> String {
  "xl/pivotCache/pivotCacheDefinition\{cache_id}.xml"
}

///|
fn pivot_cache_definition_rels_part_path(cache_id : Int) -> String {
  "xl/pivotCache/_rels/pivotCacheDefinition\{cache_id}.xml.rels"
}

///|
fn pivot_cache_records_part_path(cache_id : Int) -> String {
  "xl/pivotCache/pivotCacheRecords\{cache_id}.xml"
}

///|
fn slicer_part_path(part_id : Int) -> String {
  "xl/slicers/slicer\{part_id}.xml"
}

///|
fn slicer_cache_part_path(cache_id : Int) -> String {
  "xl/slicerCaches/slicerCache\{cache_id}.xml"
}

///|
fn comment_part_path(comment_id : Int) -> String {
  "xl/comments\{comment_id}.xml"
}

///|
fn vml_part_path(vml_id : Int) -> String {
  "xl/drawings/vmlDrawing\{vml_id}.vml"
}

///|
fn vml_rels_part_path(vml_id : Int) -> String {
  "xl/drawings/_rels/vmlDrawing\{vml_id}.vml.rels"
}

///|
fn media_part_path(file_name : String) -> String {
  "xl/media/\{file_name}"
}

///|
fn content_override_path(part_path : String) -> String {
  "/\{part_path}"
}

///|
fn archive_path_from_part_name(
  part_name : StringView,
) -> String raise XlsxError {
  let part = part_name.to_string()
  if part == "" {
    raise InvalidXml(msg="content type part name empty")
  }
  match part.strip_prefix("/") {
    Some(rest) => {
      let path = rest.to_string()
      if path == "" {
        raise InvalidXml(msg="content type part name empty")
      }
      path
    }
    None => part
  }
}

///|
fn rels_path_for_part(part_path : StringView) -> String raise XlsxError {
  let part = part_path.to_string()
  if part == "" || part.has_prefix("/") {
    raise InvalidXml(msg="part rels path invalid")
  }
  let segments = Array::from_iter(part.split("/"))
  let file_name = segments[segments.length() - 1].to_string()
  if file_name == "" {
    raise InvalidXml(msg="part rels path invalid")
  }
  if segments.length() == 1 {
    return "_rels/\{file_name}.rels"
  }
  let folder_parts : Array[String] = []
  for i, segment in segments {
    if i + 1 < segments.length() {
      folder_parts.push(segment.to_string())
    }
  }
  let folder = folder_parts.join("/")
  "\{folder}/_rels/\{file_name}.rels"
}

///|
fn drawing_rel_target(sheet_id : Int) -> String {
  "../drawings/drawing\{sheet_id}.xml"
}

///|
fn table_rel_target(table_id : Int) -> String {
  "../tables/table\{table_id}.xml"
}

///|
fn pivot_table_rel_target(pivot_id : Int) -> String {
  "../pivotTables/pivotTable\{pivot_id}.xml"
}

///|
fn slicer_rel_target(part_id : Int) -> String {
  "../slicers/slicer\{part_id}.xml"
}

///|
fn comment_rel_target(comment_id : Int) -> String {
  "../comments\{comment_id}.xml"
}

///|
fn vml_rel_target(vml_id : Int) -> String {
  "../drawings/vmlDrawing\{vml_id}.vml"
}

///|
fn media_rel_target(file_name : String) -> String {
  "../media/\{file_name}"
}

///|
fn chart_rel_target(file_name : String) -> String {
  "../charts/\{file_name}"
}

///|
fn chartsheet_workbook_rel_target(sheet_id : Int) -> String {
  "chartsheets/sheet\{sheet_id}.xml"
}

///|
fn slicer_cache_workbook_rel_target(cache_id : Int) -> String {
  "slicerCaches/slicerCache\{cache_id}.xml"
}

///|
fn pivot_cache_workbook_rel_target(cache_id : Int) -> String {
  "pivotCache/pivotCacheDefinition\{cache_id}.xml"
}
