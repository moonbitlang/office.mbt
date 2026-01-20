///|
fn collect_shared_strings(
  workbook : Workbook,
) -> (Array[String], Map[String, Int], Int) {
  let shared_strings : Array[String] = []
  let index_map : Map[String, Int] = {}
  let mut total = 0
  for sheet in workbook.sheets() {
    for cell in sheet.cells() {
      if cell.formula is None {
        total = total + 1
        match index_map.get(cell.value) {
          Some(_) => ()
          None => {
            let idx = shared_strings.length()
            shared_strings.push(cell.value)
            index_map.set(cell.value, idx)
          }
        }
      }
    }
  }
  (shared_strings, index_map, total)
}

///|
fn write_workbook_xml(sheets : ArrayView[Worksheet]) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n",
  )
  sb.write_view("  <sheets>\n")
  for i, sheet in sheets {
    let sheet_id = i + 1
    sb.write_view("    <sheet name=\"")
    sb.write_view(escape_xml_attr(sheet.name()))
    sb.write_view("\" sheetId=\"")
    sb.write_view("\{sheet_id}\"")
    sb.write_view(" r:id=\"rId\{sheet_id}\"/>\n")
  }
  sb.write_view("  </sheets>\n")
  sb.write_view("</workbook>")
  sb.to_string()
}

///|
fn write_shared_strings_xml(
  values : Array[String],
  total_count : Int,
) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"\{total_count}\" uniqueCount=\"\{values.length()}\">\n",
  )
  for value in values {
    sb.write_view("  <si><t>")
    sb.write_view(escape_xml_text(value))
    sb.write_view("</t></si>\n")
  }
  sb.write_view("</sst>")
  sb.to_string()
}

///|
fn collect_formula_cells(workbook : Workbook) -> Array[(Int, String)] {
  let formula_cells : Array[(Int, String)] = []
  for i, sheet in workbook.sheets() {
    let sheet_id = i + 1
    for cell in sheet.cells() {
      match cell.formula {
        Some(_) => formula_cells.push((sheet_id, cell.reference))
        None => ()
      }
    }
  }
  formula_cells
}

///|
fn write_calc_chain_xml(cells : Array[(Int, String)]) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<calcChain xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">\n",
  )
  for cell in cells {
    let (sheet_id, reference) = cell
    sb.write_view("  <c r=\"")
    sb.write_view(escape_xml_attr(reference))
    sb.write_view("\" i=\"\{sheet_id}\"/>\n")
  }
  sb.write_view("</calcChain>")
  sb.to_string()
}

///|
let rel_drawing = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing"

///|
let rel_image = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"

///|
let rel_chart = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart"

///|
let rel_table = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/table"

///|
let rel_pivot_table = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/pivotTable"

///|
let rel_pivot_cache = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/pivotCacheDefinition"

///|
let rel_pivot_cache_records = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/pivotCacheRecords"

///|
let rel_vml = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/vmlDrawing"

///|
let ct_drawing = "application/vnd.openxmlformats-officedocument.drawing+xml"

///|
let ct_chart = "application/vnd.openxmlformats-officedocument.drawingml.chart+xml"

///|
let ct_table = "application/vnd.openxmlformats-officedocument.spreadsheetml.table+xml"

///|
let ct_pivot_table = "application/vnd.openxmlformats-officedocument.spreadsheetml.pivotTable+xml"

///|
let ct_pivot_cache_def = "application/vnd.openxmlformats-officedocument.spreadsheetml.pivotCacheDefinition+xml"

///|
let ct_pivot_cache_records = "application/vnd.openxmlformats-officedocument.spreadsheetml.pivotCacheRecords+xml"

///|
let ct_vml = "application/vnd.openxmlformats-officedocument.vmlDrawing"

///|
fn write_sheet_rels_xml(
  drawing_target : String?,
  table_targets : ArrayView[String],
  pivot_table_targets : ArrayView[String],
  vml_targets : ArrayView[String],
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
  for target in vml_targets {
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_vml)
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
  image_targets : Array[String],
  chart_targets : Array[String],
) -> String {
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
  for target in chart_targets {
    sb.write_view("  <Relationship Id=\"rId\{rel_id}\" Type=\"")
    sb.write_view(rel_chart)
    sb.write_view("\" Target=\"")
    sb.write_view(escape_xml_attr(target))
    sb.write_view("\"/>\n")
    rel_id = rel_id + 1
  }
  sb.write_view("</Relationships>")
  sb.to_string()
}

///|
fn write_drawing_xml(
  images : Array[(String, Int)],
  charts : Array[(String, Int)],
) -> String raise XlsxError {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<xdr:wsDr xmlns:xdr=\"http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n",
  )
  let mut obj_id = 1
  for image in images {
    let (reference, rel_id) = image
    let (row, col) = cell_ref_to_rc(reference)
    let col_idx = col - 1
    let row_idx = row - 1
    let pic_id = obj_id
    obj_id = obj_id + 1
    sb.write_view("  <xdr:oneCellAnchor>\n")
    sb.write_view("    <xdr:from>\n")
    sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
    sb.write_view("      <xdr:colOff>0</xdr:colOff>\n")
    sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
    sb.write_view("      <xdr:rowOff>0</xdr:rowOff>\n")
    sb.write_view("    </xdr:from>\n")
    sb.write_view("    <xdr:ext cx=\"1905000\" cy=\"1524000\"/>\n")
    sb.write_view("    <xdr:pic>\n")
    sb.write_view("      <xdr:nvPicPr>\n")
    sb.write_view(
      "        <xdr:cNvPr id=\"\{pic_id}\" name=\"Image \{pic_id}\"/>\n",
    )
    sb.write_view("        <xdr:cNvPicPr/>\n")
    sb.write_view("      </xdr:nvPicPr>\n")
    sb.write_view("      <xdr:blipFill>\n")
    sb.write_view("        <a:blip r:embed=\"rId\{rel_id}\"/>\n")
    sb.write_view("        <a:stretch><a:fillRect/></a:stretch>\n")
    sb.write_view("      </xdr:blipFill>\n")
    sb.write_view("      <xdr:spPr>\n")
    sb.write_view("        <a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>\n")
    sb.write_view("      </xdr:spPr>\n")
    sb.write_view("    </xdr:pic>\n")
    sb.write_view("    <xdr:clientData/>\n")
    sb.write_view("  </xdr:oneCellAnchor>\n")
  }
  for chart in charts {
    let (reference, rel_id) = chart
    let (row, col) = cell_ref_to_rc(reference)
    let col_idx = col - 1
    let row_idx = row - 1
    let frame_id = obj_id
    obj_id = obj_id + 1
    sb.write_view("  <xdr:oneCellAnchor>\n")
    sb.write_view("    <xdr:from>\n")
    sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
    sb.write_view("      <xdr:colOff>0</xdr:colOff>\n")
    sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
    sb.write_view("      <xdr:rowOff>0</xdr:rowOff>\n")
    sb.write_view("    </xdr:from>\n")
    sb.write_view("    <xdr:ext cx=\"1905000\" cy=\"1524000\"/>\n")
    sb.write_view("    <xdr:graphicFrame>\n")
    sb.write_view("      <xdr:nvGraphicFramePr>\n")
    sb.write_view(
      "        <xdr:cNvPr id=\"\{frame_id}\" name=\"Chart \{frame_id}\"/>\n",
    )
    sb.write_view("        <xdr:cNvGraphicFramePr/>\n")
    sb.write_view("      </xdr:nvGraphicFramePr>\n")
    sb.write_view("      <xdr:xfrm>\n")
    sb.write_view("        <a:off x=\"0\" y=\"0\"/>\n")
    sb.write_view("        <a:ext cx=\"1905000\" cy=\"1524000\"/>\n")
    sb.write_view("      </xdr:xfrm>\n")
    sb.write_view("      <a:graphic>\n")
    sb.write_view(
      "        <a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/chart\">\n",
    )
    sb.write_view(
      "          <c:chart xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" r:id=\"rId\{rel_id}\"/>\n",
    )
    sb.write_view("        </a:graphicData>\n")
    sb.write_view("      </a:graphic>\n")
    sb.write_view("    </xdr:graphicFrame>\n")
    sb.write_view("    <xdr:clientData/>\n")
    sb.write_view("  </xdr:oneCellAnchor>\n")
  }
  sb.write_view("</xdr:wsDr>")
  sb.to_string()
}

///|
fn worksheet_dimension(sheet : Worksheet) -> String? raise XlsxError {
  let mut has_any = false
  let mut min_row = 0
  let mut min_col = 0
  let mut max_row = 0
  let mut max_col = 0
  for cell in sheet.cells() {
    let row = cell.row
    let col = cell.col
    if !has_any {
      has_any = true
      min_row = row
      max_row = row
      min_col = col
      max_col = col
    } else {
      if row < min_row {
        min_row = row
      }
      if row > max_row {
        max_row = row
      }
      if col < min_col {
        min_col = col
      }
      if col > max_col {
        max_col = col
      }
    }
  }
  for range_ref in sheet.merged_cells() {
    let (row1, col1, row2, col2) = parse_range_ref(range_ref)
    if !has_any {
      has_any = true
      min_row = row1
      max_row = row2
      min_col = col1
      max_col = col2
    } else {
      if row1 < min_row {
        min_row = row1
      }
      if row2 > max_row {
        max_row = row2
      }
      if col1 < min_col {
        min_col = col1
      }
      if col2 > max_col {
        max_col = col2
      }
    }
  }
  for table in sheet.tables() {
    let (row1, col1, row2, col2) = parse_range_ref(table.range_ref)
    if !has_any {
      has_any = true
      min_row = row1
      max_row = row2
      min_col = col1
      max_col = col2
    } else {
      if row1 < min_row {
        min_row = row1
      }
      if row2 > max_row {
        max_row = row2
      }
      if col1 < min_col {
        min_col = col1
      }
      if col2 > max_col {
        max_col = col2
      }
    }
  }
  if !has_any {
    return None
  }
  let start_ref = cell_ref_from(min_row, min_col)
  let end_ref = cell_ref_from(max_row, max_col)
  Some("\{start_ref}:\{end_ref}")
}

///|
fn write_worksheet_xml(
  sheet : Worksheet,
  string_map : Map[String, Int],
  drawing_rel_id : Int?,
  table_rel_ids : ArrayView[Int],
  pivot_rel_ids : ArrayView[Int],
  legacy_drawing_rel_id : Int?,
  legacy_drawing_hf_rel_id : Int?,
) -> String raise XlsxError {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  let needs_rels = drawing_rel_id is Some(_) ||
    table_rel_ids.length() > 0 ||
    pivot_rel_ids.length() > 0 ||
    legacy_drawing_rel_id is Some(_) ||
    legacy_drawing_hf_rel_id is Some(_)
  if needs_rels {
    sb.write_view(
      "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n",
    )
  } else {
    sb.write_view(
      "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">\n",
    )
  }
  match worksheet_dimension(sheet) {
    Some(value) => {
      sb.write_view("  <dimension ref=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"/>\n")
    }
    None => ()
  }
  sb.write_view("  <sheetData>\n")
  let cells = sheet.sorted_cells()
  let mut current_row = -1
  for cell in cells {
    if cell.row != current_row {
      if current_row >= 0 {
        sb.write_view("    </row>\n")
      }
      current_row = cell.row
      sb.write_view("    <row r=\"\{current_row}\">\n")
    }
    sb.write_view("      <c r=\"")
    sb.write_view(escape_xml_attr(cell.reference))
    sb.write_view("\"")
    if cell.style_id != 0 {
      sb.write_view(" s=\"\{cell.style_id}\"")
    }
    match cell.formula {
      Some(formula) => {
        if cell.value != "" {
          sb.write_view(" t=\"str\">")
        } else {
          sb.write_view(">")
        }
        sb.write_view("<f>")
        sb.write_view(escape_xml_text(formula))
        sb.write_view("</f>")
        if cell.value != "" {
          sb.write_view("<v>")
          sb.write_view(escape_xml_text(cell.value))
          sb.write_view("</v>")
        }
        sb.write_view("</c>\n")
      }
      None => {
        let idx = match string_map.get(cell.value) {
          Some(value) => value
          None => raise XlsxError::InvalidSharedString(index=cell.row)
        }
        sb.write_view(" t=\"s\"><v>\{idx}</v></c>\n")
      }
    }
  }
  if current_row >= 0 {
    sb.write_view("    </row>\n")
  }
  sb.write_view("  </sheetData>\n")
  if sheet.merged_cells().length() > 0 {
    sb.write_view("  <mergeCells count=\"\{sheet.merged_cells().length()}\">\n")
    for range_ref in sheet.merged_cells() {
      sb.write_view("    <mergeCell ref=\"")
      sb.write_view(escape_xml_attr(range_ref))
      sb.write_view("\"/>\n")
    }
    sb.write_view("  </mergeCells>\n")
  }
  if table_rel_ids.length() > 0 {
    sb.write_view("  <tableParts count=\"\{table_rel_ids.length()}\">\n")
    for rel_id in table_rel_ids {
      sb.write_view("    <tablePart r:id=\"rId\{rel_id}\"/>\n")
    }
    sb.write_view("  </tableParts>\n")
  }
  if pivot_rel_ids.length() > 0 {
    sb.write_view("  <pivotTableParts count=\"\{pivot_rel_ids.length()}\">\n")
    for rel_id in pivot_rel_ids {
      sb.write_view("    <pivotTablePart r:id=\"rId\{rel_id}\"/>\n")
    }
    sb.write_view("  </pivotTableParts>\n")
  }
  for xml in sheet.conditional_formats() {
    sb.write_view("  ")
    sb.write_view(xml)
    sb.write_view("\n")
  }
  if sheet.data_validations().length() > 0 {
    sb.write_view(
      "  <dataValidations count=\"\{sheet.data_validations().length()}\">\n",
    )
    for xml in sheet.data_validations() {
      sb.write_view("    ")
      sb.write_view(xml)
      sb.write_view("\n")
    }
    sb.write_view("  </dataValidations>\n")
  }
  match drawing_rel_id {
    Some(rel_id) => sb.write_view("  <drawing r:id=\"rId\{rel_id}\"/>\n")
    None => ()
  }
  match legacy_drawing_rel_id {
    Some(rel_id) => sb.write_view("  <legacyDrawing r:id=\"rId\{rel_id}\"/>\n")
    None => ()
  }
  match legacy_drawing_hf_rel_id {
    Some(rel_id) =>
      sb.write_view("  <legacyDrawingHF r:id=\"rId\{rel_id}\"/>\n")
    None => ()
  }
  if sheet.sparkline_groups().length() > 0 {
    sb.write_view(write_sparkline_ext_xml(sheet.sparkline_groups()))
  }
  sb.write_view("</worksheet>")
  sb.to_string()
}

///|
let default_theme_xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme">
  #|  <a:themeElements>
  #|    <a:clrScheme name="Office">
  #|      <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
  #|      <a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
  #|      <a:dk2><a:srgbClr val="1F497D"/></a:dk2>
  #|      <a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
  #|      <a:accent1><a:srgbClr val="4F81BD"/></a:accent1>
  #|      <a:accent2><a:srgbClr val="C0504D"/></a:accent2>
  #|      <a:accent3><a:srgbClr val="9BBB59"/></a:accent3>
  #|      <a:accent4><a:srgbClr val="8064A2"/></a:accent4>
  #|      <a:accent5><a:srgbClr val="4BACC6"/></a:accent5>
  #|      <a:accent6><a:srgbClr val="F79646"/></a:accent6>
  #|      <a:hlink><a:srgbClr val="0000FF"/></a:hlink>
  #|      <a:folHlink><a:srgbClr val="800080"/></a:folHlink>
  #|    </a:clrScheme>
  #|    <a:fontScheme name="Office">
  #|      <a:majorFont><a:latin typeface="Calibri"/></a:majorFont>
  #|      <a:minorFont><a:latin typeface="Calibri"/></a:minorFont>
  #|    </a:fontScheme>
  #|    <a:fmtScheme name="Office"/>
  #|  </a:themeElements>
  #|</a:theme>

///|
let default_core_xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
  #| xmlns:dc="http://purl.org/dc/elements/1.1/"
  #| xmlns:dcterms="http://purl.org/dc/terms/"
  #| xmlns:dcmitype="http://purl.org/dc/dcmitype/"
  #| xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  #|  <dc:creator>mbtexcel</dc:creator>
  #|  <cp:lastModifiedBy>mbtexcel</cp:lastModifiedBy>
  #|</cp:coreProperties>

///|
let default_app_xml =
  #|<?xml version="1.0" encoding="UTF-8"?>
  #|<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
  #| xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  #|  <Application>mbtexcel</Application>
  #|</Properties>

///|
pub fn write(workbook : Workbook) -> Bytes raise XlsxError {
  let (shared_strings, string_map, total_count) = collect_shared_strings(
    workbook,
  )
  let include_shared = shared_strings.length() > 0
  let sheet_count = workbook.sheets().length()
  let formula_cells = collect_formula_cells(workbook)
  let include_calc_chain = formula_cells.length() > 0
  let manifest = @ooxml.WorkbookManifest::new(
    sheet_count,
    include_shared_strings=include_shared,
    include_calc_chain~,
  )
  let archive = @zip.Archive::new()
  archive.add("_rels/.rels", @encoding/utf8.encode(manifest.root_rels_xml()))
  archive.add(
    "xl/workbook.xml",
    @encoding/utf8.encode(write_workbook_xml(workbook.sheets())),
  )
  let tables_by_sheet : Array[Array[(Int, Table)]] = []
  let mut next_table_id = 1
  for sheet in workbook.sheets() {
    for table in sheet.tables() {
      if table.id >= next_table_id {
        next_table_id = table.id + 1
      }
    }
  }
  for sheet in workbook.sheets() {
    let sheet_tables : Array[(Int, Table)] = []
    for table in sheet.tables() {
      let table_id = if table.id > 0 {
        table.id
      } else {
        let id = next_table_id
        next_table_id = next_table_id + 1
        id
      }
      sheet_tables.push((table_id, table))
    }
    tables_by_sheet.push(sheet_tables)
  }
  let pivots_by_sheet : Array[Array[(Int, Int, PivotTable)]] = []
  let mut next_pivot_table_id = 1
  let mut next_cache_id = 1
  for sheet in workbook.sheets() {
    for pivot in sheet.pivot_tables() {
      if pivot.table_id >= next_pivot_table_id {
        next_pivot_table_id = pivot.table_id + 1
      }
      if pivot.cache_id >= next_cache_id {
        next_cache_id = pivot.cache_id + 1
      }
    }
  }
  for sheet in workbook.sheets() {
    let sheet_pivots : Array[(Int, Int, PivotTable)] = []
    for pivot in sheet.pivot_tables() {
      let table_id = if pivot.table_id > 0 {
        pivot.table_id
      } else {
        let id = next_pivot_table_id
        next_pivot_table_id = next_pivot_table_id + 1
        id
      }
      let cache_id = if pivot.cache_id > 0 {
        pivot.cache_id
      } else {
        let id = next_cache_id
        next_cache_id = next_cache_id + 1
        id
      }
      sheet_pivots.push((table_id, cache_id, pivot))
    }
    pivots_by_sheet.push(sheet_pivots)
  }
  let added_extensions : Map[String, Bool] = {}
  let mut image_index = 1
  let mut chart_index = 1
  let mut vml_index = 1
  for i, sheet in workbook.sheets() {
    let sheet_id = i + 1
    let sheet_tables = tables_by_sheet[i]
    let sheet_pivots = pivots_by_sheet[i]
    let has_drawing = sheet.images().length() > 0 || sheet.charts().length() > 0
    let mut rel_id = 1
    let drawing_rel_id = if has_drawing {
      let id = rel_id
      rel_id = rel_id + 1
      Some(id)
    } else {
      None
    }
    let table_rel_ids : Array[Int] = []
    let table_targets : Array[String] = []
    for entry in sheet_tables {
      let (table_id, _table) = entry
      table_rel_ids.push(rel_id)
      table_targets.push("../tables/table\{table_id}.xml")
      rel_id = rel_id + 1
    }
    let pivot_rel_ids : Array[Int] = []
    let pivot_targets : Array[String] = []
    for entry in sheet_pivots {
      let (pivot_id, _cache_id, _pivot) = entry
      pivot_rel_ids.push(rel_id)
      pivot_targets.push("../pivotTables/pivotTable\{pivot_id}.xml")
      rel_id = rel_id + 1
    }
    let vml_targets : Array[String] = []
    let vml_parts : Array[(Int, String)] = []
    let legacy_drawing_rel_id = match sheet.vml_drawing_xml() {
      Some(xml) => {
        let id = rel_id
        rel_id = rel_id + 1
        let vml_id = vml_index
        vml_index = vml_index + 1
        vml_targets.push("../drawings/vmlDrawing\{vml_id}.vml")
        vml_parts.push((vml_id, xml))
        Some(id)
      }
      None => None
    }
    let legacy_drawing_hf_rel_id = match sheet.vml_drawing_hf_xml() {
      Some(xml) => {
        let id = rel_id
        rel_id = rel_id + 1
        let vml_id = vml_index
        vml_index = vml_index + 1
        vml_targets.push("../drawings/vmlDrawing\{vml_id}.vml")
        vml_parts.push((vml_id, xml))
        Some(id)
      }
      None => None
    }
    let sheet_xml = write_worksheet_xml(
      sheet, string_map, drawing_rel_id, table_rel_ids, pivot_rel_ids, legacy_drawing_rel_id,
      legacy_drawing_hf_rel_id,
    )
    archive.add(
      "xl/worksheets/sheet\{sheet_id}.xml",
      @encoding/utf8.encode(sheet_xml),
    )
    if drawing_rel_id is Some(_) ||
      table_targets.length() > 0 ||
      pivot_targets.length() > 0 ||
      vml_targets.length() > 0 {
      let drawing_target = match drawing_rel_id {
        Some(_) => Some("../drawings/drawing\{sheet_id}.xml")
        None => None
      }
      let sheet_rels_xml = write_sheet_rels_xml(
        drawing_target, table_targets, pivot_targets, vml_targets,
      )
      archive.add(
        "xl/worksheets/_rels/sheet\{sheet_id}.xml.rels",
        @encoding/utf8.encode(sheet_rels_xml),
      )
    }
    for entry in sheet_tables {
      let (table_id, table) = entry
      let table_xml = write_table_xml(table_id, table)
      archive.add(
        "xl/tables/table\{table_id}.xml",
        @encoding/utf8.encode(table_xml),
      )
      manifest.add_content_override("/xl/tables/table\{table_id}.xml", ct_table)
    }
    for entry in sheet_pivots {
      let (pivot_id, cache_id, pivot) = entry
      archive.add(
        "xl/pivotTables/pivotTable\{pivot_id}.xml",
        @encoding/utf8.encode(pivot.table_xml),
      )
      manifest.add_content_override(
        "/xl/pivotTables/pivotTable\{pivot_id}.xml",
        ct_pivot_table,
      )
      let pivot_rels_xml = write_pivot_table_rels_xml(cache_id)
      archive.add(
        "xl/pivotTables/_rels/pivotTable\{pivot_id}.xml.rels",
        @encoding/utf8.encode(pivot_rels_xml),
      )
      archive.add(
        "xl/pivotCache/pivotCacheDefinition\{cache_id}.xml",
        @encoding/utf8.encode(pivot.cache_definition_xml),
      )
      manifest.add_content_override(
        "/xl/pivotCache/pivotCacheDefinition\{cache_id}.xml",
        ct_pivot_cache_def,
      )
      manifest.add_workbook_relationship(
        rel_pivot_cache,
        "pivotCache/pivotCacheDefinition\{cache_id}.xml",
      )
      match pivot.cache_records_xml {
        Some(records) => {
          archive.add(
            "xl/pivotCache/pivotCacheRecords\{cache_id}.xml",
            @encoding/utf8.encode(records),
          )
          manifest.add_content_override(
            "/xl/pivotCache/pivotCacheRecords\{cache_id}.xml",
            ct_pivot_cache_records,
          )
          let cache_rels_xml = write_pivot_cache_rels_xml(cache_id)
          archive.add(
            "xl/pivotCache/_rels/pivotCacheDefinition\{cache_id}.xml.rels",
            @encoding/utf8.encode(cache_rels_xml),
          )
        }
        None => ()
      }
    }
    for part in vml_parts {
      let (vml_id, xml) = part
      archive.add(
        "xl/drawings/vmlDrawing\{vml_id}.vml",
        @encoding/utf8.encode(xml),
      )
      manifest.add_content_override(
        "/xl/drawings/vmlDrawing\{vml_id}.vml",
        ct_vml,
      )
    }
    if !has_drawing {
      continue
    }
    let image_targets : Array[String] = []
    let chart_targets : Array[String] = []
    let drawing_images : Array[(String, Int)] = []
    let drawing_charts : Array[(String, Int)] = []
    let mut rel_id = 1
    for image in sheet.images() {
      let file_name = "image\{image_index}.\{image.extension}"
      image_index = image_index + 1
      archive.add("xl/media/\{file_name}", image.data)
      image_targets.push("../media/\{file_name}")
      drawing_images.push((image.reference, rel_id))
      rel_id = rel_id + 1
      if !added_extensions.contains(image.extension) {
        manifest.add_content_default(image.extension, image.content_type)
        added_extensions.set(image.extension, true)
      }
    }
    for chart in sheet.charts() {
      let file_name = "chart\{chart_index}.xml"
      chart_index = chart_index + 1
      archive.add("xl/charts/\{file_name}", @encoding/utf8.encode(chart.xml))
      chart_targets.push("../charts/\{file_name}")
      drawing_charts.push((chart.reference, rel_id))
      rel_id = rel_id + 1
      manifest.add_content_override("/xl/charts/\{file_name}", ct_chart)
    }
    manifest.add_content_override(
      "/xl/drawings/drawing\{sheet_id}.xml",
      ct_drawing,
    )
    let drawing_xml = write_drawing_xml(drawing_images, drawing_charts)
    archive.add(
      "xl/drawings/drawing\{sheet_id}.xml",
      @encoding/utf8.encode(drawing_xml),
    )
    let drawing_rels_xml = write_drawing_rels_xml(image_targets, chart_targets)
    archive.add(
      "xl/drawings/_rels/drawing\{sheet_id}.xml.rels",
      @encoding/utf8.encode(drawing_rels_xml),
    )
  }
  if include_shared {
    archive.add(
      "xl/sharedStrings.xml",
      @encoding/utf8.encode(
        write_shared_strings_xml(shared_strings, total_count),
      ),
    )
  }
  if include_calc_chain {
    archive.add(
      "xl/calcChain.xml",
      @encoding/utf8.encode(write_calc_chain_xml(formula_cells)),
    )
  }
  archive.add(
    "xl/styles.xml",
    @encoding/utf8.encode(write_styles_xml(workbook.styles())),
  )
  archive.add("xl/theme/theme1.xml", @encoding/utf8.encode(default_theme_xml))
  archive.add("docProps/core.xml", @encoding/utf8.encode(default_core_xml))
  archive.add("docProps/app.xml", @encoding/utf8.encode(default_app_xml))
  archive.add(
    "xl/_rels/workbook.xml.rels",
    @encoding/utf8.encode(manifest.workbook_rels_xml()),
  )
  archive.add(
    "[Content_Types].xml",
    @encoding/utf8.encode(manifest.content_types_xml()),
  )
  @zip.write(archive) catch {
    err => raise XlsxError::UnsupportedFeature(msg=err.to_string())
  }
}
