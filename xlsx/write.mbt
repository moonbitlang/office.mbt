///|
fn collect_shared_strings(
  workbook : Workbook,
) -> (Array[SharedStringEntry], Map[String, Int], Map[String, Int], Int) {
  let shared_strings : Array[SharedStringEntry] = []
  let text_map : Map[String, Int] = {}
  let rich_text_map : Map[String, Int] = {}
  let mut total = 0
  for sheet in workbook.sheets() {
    for cell in sheet.cells() {
      if cell.formula is None && cell.value_type == CellValueType::String {
        total = total + 1
        match cell.rich_text {
          Some(runs) => {
            let idx = shared_strings.length()
            shared_strings.push({
              text: rich_text_plain_text(runs),
              runs: Some(runs),
            })
            rich_text_map.set(cell.reference, idx)
          }
          None =>
            match text_map.get(cell.value) {
              Some(_) => ()
              None => {
                let idx = shared_strings.length()
                shared_strings.push({ text: cell.value, runs: None })
                text_map.set(cell.value, idx)
              }
            }
        }
      }
    }
  }
  (shared_strings, text_map, rich_text_map, total)
}

///|
fn write_workbook_xml(
  workbook : Workbook,
  chartsheet_rel_start : Int,
) -> String {
  let sheets = workbook.sheet_order
  let worksheet_count = workbook.sheets().length()
  let sb = StringBuilder::new()
  let sheet_index : Map[String, Int] = {}
  for i, entry in sheets {
    sheet_index.set(normalize_sheet_name(workbook.sheet_entry_name(entry)), i)
  }
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n",
  )
  match write_workbook_pr_xml(workbook.workbook_props()) {
    Some(value) => sb.write_view(value)
    None => ()
  }
  if sheets.length() > 0 {
    let active_index = workbook.active_sheet_index()
    let safe_active = if active_index < 0 || active_index >= sheets.length() {
      0
    } else {
      active_index
    }
    sb.write_view("  <bookViews>\n")
    sb.write_view("    <workbookView activeTab=\"\{safe_active}\"/>\n")
    sb.write_view("  </bookViews>\n")
  }
  sb.write_view("  <sheets>\n")
  for _i, entry in sheets {
    let sheet_id = match entry {
      SheetEntry::Worksheet(idx) => idx + 1
      SheetEntry::ChartSheet(idx) => worksheet_count + idx + 1
    }
    let rel_id = match entry {
      SheetEntry::Worksheet(idx) => idx + 1
      SheetEntry::ChartSheet(idx) => chartsheet_rel_start + idx
    }
    sb.write_view("    <sheet name=\"")
    sb.write_view(escape_xml_attr(workbook.sheet_entry_name(entry)))
    sb.write_view("\" sheetId=\"")
    sb.write_view("\{sheet_id}\"")
    sb.write_view(" r:id=\"rId\{rel_id}\"")
    match workbook.sheet_entry_state(entry) {
      SheetState::Visible => ()
      SheetState::Hidden => sb.write_view(" state=\"hidden\"")
      SheetState::VeryHidden => sb.write_view(" state=\"veryHidden\"")
    }
    sb.write_view("/>\n")
  }
  sb.write_view("  </sheets>\n")
  if workbook.defined_names.length() > 0 {
    let mut wrote = false
    for defined in workbook.defined_names {
      if defined.name == "" || defined.refers_to == "" {
        continue
      }
      if !wrote {
        sb.write_view("  <definedNames>\n")
        wrote = true
      }
      sb.write_view("    <definedName name=\"")
      sb.write_view(escape_xml_attr(defined.name))
      sb.write_view("\"")
      if defined.comment != "" {
        sb.write_view(" comment=\"")
        sb.write_view(escape_xml_attr(defined.comment))
        sb.write_view("\"")
      }
      let scope = normalize_defined_name_scope(defined.scope)
      if scope != "Workbook" {
        let key = normalize_sheet_name(scope)
        match sheet_index.get(key) {
          Some(local_id) => sb.write_view(" localSheetId=\"\{local_id}\"")
          None => ()
        }
      }
      sb.write_view(">")
      sb.write_view(escape_xml_text(defined.refers_to))
      sb.write_view("</definedName>\n")
    }
    if wrote {
      sb.write_view("  </definedNames>\n")
    }
  }
  match workbook.workbook_protection {
    Some(value) => sb.write_view(write_workbook_protection_xml(value))
    None => ()
  }
  match write_calc_pr_xml(workbook.calc_props()) {
    Some(value) => sb.write_view(value)
    None => ()
  }
  sb.write_view("</workbook>")
  sb.to_string()
}

///|
fn write_workbook_pr_xml(options : WorkbookPropsOptions) -> String? {
  if workbook_props_is_empty(options) {
    return None
  }
  let sb = StringBuilder::new()
  sb.write_view("  <workbookPr")
  match options.date_1904 {
    Some(value) => sb.write_view(" date1904=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.filter_privacy {
    Some(value) => sb.write_view(" filterPrivacy=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.code_name {
    Some(value) => {
      sb.write_view(" codeName=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"")
    }
    None => ()
  }
  sb.write_view("/>\n")
  Some(sb.to_string())
}

///|
fn write_calc_pr_xml(options : CalcPropsOptions) -> String? {
  if calc_props_is_empty(options) {
    return None
  }
  let sb = StringBuilder::new()
  sb.write_view("  <calcPr")
  match options.calc_id {
    Some(value) => sb.write_view(" calcId=\"\{value}\"")
    None => ()
  }
  match options.calc_mode {
    Some(value) => sb.write_view(" calcMode=\"\{value}\"")
    None => ()
  }
  match options.full_calc_on_load {
    Some(value) => sb.write_view(" fullCalcOnLoad=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.ref_mode {
    Some(value) => sb.write_view(" refMode=\"\{value}\"")
    None => ()
  }
  match options.iterate {
    Some(value) => sb.write_view(" iterate=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.iterate_count {
    Some(value) => sb.write_view(" iterateCount=\"\{value}\"")
    None => ()
  }
  match options.iterate_delta {
    Some(value) => sb.write_view(" iterateDelta=\"\{value}\"")
    None => ()
  }
  match options.full_precision {
    Some(value) => sb.write_view(" fullPrecision=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.calc_completed {
    Some(value) => sb.write_view(" calcCompleted=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.calc_on_save {
    Some(value) => sb.write_view(" calcOnSave=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.concurrent_calc {
    Some(value) => sb.write_view(" concurrentCalc=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.concurrent_manual_count {
    Some(value) => sb.write_view(" concurrentManualCount=\"\{value}\"")
    None => ()
  }
  match options.force_full_calc {
    Some(value) => sb.write_view(" forceFullCalc=\"\{bool_attr(value)}\"")
    None => ()
  }
  sb.write_view("/>\n")
  Some(sb.to_string())
}

///|
fn write_workbook_protection_xml(protection : WorkbookProtection) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <workbookProtection")
  if protection.lock_structure {
    sb.write_view(" lockStructure=\"1\"")
  }
  if protection.lock_windows {
    sb.write_view(" lockWindows=\"1\"")
  }
  if protection.algorithm_name != "" {
    sb.write_view(" workbookAlgorithmName=\"")
    sb.write_view(escape_xml_attr(protection.algorithm_name))
    sb.write_view("\"")
  }
  if protection.hash_value != "" {
    sb.write_view(" workbookHashValue=\"")
    sb.write_view(escape_xml_attr(protection.hash_value))
    sb.write_view("\"")
  }
  if protection.salt_value != "" {
    sb.write_view(" workbookSaltValue=\"")
    sb.write_view(escape_xml_attr(protection.salt_value))
    sb.write_view("\"")
  }
  if protection.spin_count > 0 {
    sb.write_view(" workbookSpinCount=\"\{protection.spin_count}\"")
  }
  sb.write_view("/>\n")
  sb.to_string()
}

///|
fn write_shared_strings_xml(
  values : Array[SharedStringEntry],
  total_count : Int,
) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"\{total_count}\" uniqueCount=\"\{values.length()}\">\n",
  )
  for entry in values {
    match entry.runs {
      Some(runs) => {
        sb.write_view("  <si>\n")
        for run in runs {
          sb.write_view("    <r>")
          match run.font {
            Some(font) => {
              sb.write_view("<rPr>")
              if font.bold {
                sb.write_view("<b/>")
              }
              if font.italic {
                sb.write_view("<i/>")
              }
              match font.underline {
                Some(value) =>
                  sb.write_view("<u val=\"\{escape_xml_attr(value)}\"/>")
                None => ()
              }
              match font.size {
                Some(size) => sb.write_view("<sz val=\"\{size}\"/>")
                None => ()
              }
              match font.family {
                Some(family) =>
                  sb.write_view("<rFont val=\"\{escape_xml_attr(family)}\"/>")
                None => ()
              }
              match font.color {
                Some(color) => {
                  let normalized = color.replace_all(old="#", new="")
                  let rgb = if normalized.length() == 6 {
                    "FF" + normalized
                  } else {
                    normalized
                  }
                  sb.write_view("<color rgb=\"\{escape_xml_attr(rgb)}\"/>")
                }
                None => ()
              }
              sb.write_view("</rPr>")
            }
            None => ()
          }
          if run.text.has_prefix(" ") ||
            run.text.has_suffix(" ") ||
            run.text.contains("\n") {
            sb.write_view("<t xml:space=\"preserve\">")
          } else {
            sb.write_view("<t>")
          }
          sb.write_view(escape_xml_text(run.text))
          sb.write_view("</t></r>\n")
        }
        sb.write_view("  </si>\n")
      }
      None => {
        sb.write_view("  <si>")
        if entry.text.has_prefix(" ") ||
          entry.text.has_suffix(" ") ||
          entry.text.contains("\n") {
          sb.write_view("<t xml:space=\"preserve\">")
        } else {
          sb.write_view("<t>")
        }
        sb.write_view(escape_xml_text(entry.text))
        sb.write_view("</t></si>\n")
      }
    }
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
        Some(value) =>
          if value != "" {
            formula_cells.push((sheet_id, cell.reference))
          }
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
let rel_worksheet = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"

///|
let rel_image = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"

///|
let rel_chart = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart"

///|
let rel_chartsheet = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/chartsheet"

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
let rel_slicer = "http://schemas.microsoft.com/office/2007/relationships/slicer"

///|
let rel_vba_project = "http://schemas.microsoft.com/office/2006/relationships/vbaProject"

///|
let rel_hyperlink = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink"

///|
let rel_comments = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments"

///|
let ct_drawing = "application/vnd.openxmlformats-officedocument.drawing+xml"

///|
let ct_chart = "application/vnd.openxmlformats-officedocument.drawingml.chart+xml"

///|
let ct_chartsheet = "application/vnd.openxmlformats-officedocument.spreadsheetml.chartsheet+xml"

///|
let ct_table = "application/vnd.openxmlformats-officedocument.spreadsheetml.table+xml"

///|
let ct_pivot_table = "application/vnd.openxmlformats-officedocument.spreadsheetml.pivotTable+xml"

///|
let ct_pivot_cache_def = "application/vnd.openxmlformats-officedocument.spreadsheetml.pivotCacheDefinition+xml"

///|
let ct_pivot_cache_records = "application/vnd.openxmlformats-officedocument.spreadsheetml.pivotCacheRecords+xml"

///|
let ct_workbook_macro = "application/vnd.ms-excel.sheet.macroEnabled.main+xml"

///|
let ct_vba_project = "application/vnd.ms-office.vbaProject"

///|
let ct_slicer = "application/vnd.ms-excel.slicer+xml"

///|
let ct_slicer_cache = "application/vnd.ms-excel.slicerCache+xml"

///|
let ct_vml = "application/vnd.openxmlformats-officedocument.vmlDrawing"

///|
let ct_comments = "application/vnd.openxmlformats-officedocument.spreadsheetml.comments+xml"

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
    if entry.link_type == HyperlinkType::External {
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

///|
priv struct DrawingImage {
  image : Image
  rel_id : Int
  hyperlink_rel_id : Int?
}

///|
priv struct DrawingHyperlink {
  rel_id : Int
  target : String
  link_type : HyperlinkType
}

///|
let emu_per_pixel = 9525

///|
fn write_drawing_xml(
  images : Array[DrawingImage],
  charts : Array[(String, Int)],
  shapes : Array[Shape],
) -> String raise XlsxError {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<xdr:wsDr xmlns:xdr=\"http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n",
  )
  let mut obj_id = 1
  for item in images {
    let image = item.image
    let (row, col) = cell_ref_to_rc(image.reference)
    let col_idx = col - 1
    let row_idx = row - 1
    let pic_id = obj_id
    obj_id = obj_id + 1
    let col_off = image.offset_x * emu_per_pixel
    let row_off = image.offset_y * emu_per_pixel
    let cx = image.width_emu
    let cy = image.height_emu
    let picture_name = if image.name == "" {
      "Image \{pic_id}"
    } else {
      image.name
    }
    match image.positioning {
      PicturePositioning::TwoCell => {
        sb.write_view("  <xdr:twoCellAnchor>\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        sb.write_view("    <xdr:to>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off + cx}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off + cy}</xdr:rowOff>\n")
        sb.write_view("    </xdr:to>\n")
      }
      PicturePositioning::Absolute => {
        sb.write_view("  <xdr:twoCellAnchor editAs=\"absolute\">\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        sb.write_view("    <xdr:to>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off + cx}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off + cy}</xdr:rowOff>\n")
        sb.write_view("    </xdr:to>\n")
      }
      PicturePositioning::OneCell => {
        sb.write_view("  <xdr:oneCellAnchor>\n")
        sb.write_view("    <xdr:from>\n")
        sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
        sb.write_view("      <xdr:colOff>\{col_off}</xdr:colOff>\n")
        sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
        sb.write_view("      <xdr:rowOff>\{row_off}</xdr:rowOff>\n")
        sb.write_view("    </xdr:from>\n")
        sb.write_view("    <xdr:ext cx=\"\{cx}\" cy=\"\{cy}\"/>\n")
      }
    }
    sb.write_view("    <xdr:pic>\n")
    sb.write_view("      <xdr:nvPicPr>\n")
    match item.hyperlink_rel_id {
      Some(link_id) => {
        sb.write_view("        <xdr:cNvPr id=\"\{pic_id}\" name=\"")
        sb.write_view(escape_xml_attr(picture_name))
        sb.write_view("\"")
        if image.alt_text != "" {
          sb.write_view(" descr=\"")
          sb.write_view(escape_xml_attr(image.alt_text))
          sb.write_view("\"")
        }
        sb.write_view(">\n")
        sb.write_view("          <a:hlinkClick r:id=\"rId\{link_id}\"/>\n")
        sb.write_view("        </xdr:cNvPr>\n")
      }
      None => {
        sb.write_view("        <xdr:cNvPr id=\"\{pic_id}\" name=\"")
        sb.write_view(escape_xml_attr(picture_name))
        sb.write_view("\"")
        if image.alt_text != "" {
          sb.write_view(" descr=\"")
          sb.write_view(escape_xml_attr(image.alt_text))
          sb.write_view("\"")
        }
        sb.write_view("/>\n")
      }
    }
    if image.lock_aspect_ratio {
      sb.write_view("        <xdr:cNvPicPr>\n")
      sb.write_view("          <a:picLocks noChangeAspect=\"1\"/>\n")
      sb.write_view("        </xdr:cNvPicPr>\n")
    } else {
      sb.write_view("        <xdr:cNvPicPr/>\n")
    }
    sb.write_view("      </xdr:nvPicPr>\n")
    sb.write_view("      <xdr:blipFill>\n")
    sb.write_view("        <a:blip r:embed=\"rId\{item.rel_id}\"/>\n")
    sb.write_view("        <a:stretch><a:fillRect/></a:stretch>\n")
    sb.write_view("      </xdr:blipFill>\n")
    sb.write_view("      <xdr:spPr>\n")
    sb.write_view("        <a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>\n")
    sb.write_view("      </xdr:spPr>\n")
    sb.write_view("    </xdr:pic>\n")
    sb.write_view(
      "    <xdr:clientData fLocksWithSheet=\"\{bool_attr(image.locked)}\" fPrintsWithSheet=\"\{bool_attr(image.print_object)}\"/>\n",
    )
    match image.positioning {
      PicturePositioning::TwoCell => sb.write_view("  </xdr:twoCellAnchor>\n")
      PicturePositioning::Absolute => sb.write_view("  </xdr:twoCellAnchor>\n")
      PicturePositioning::OneCell => sb.write_view("  </xdr:oneCellAnchor>\n")
    }
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
  for shape in shapes {
    let (row, col) = cell_ref_to_rc(shape.reference)
    let col_idx = col - 1
    let row_idx = row - 1
    let shape_id = obj_id
    obj_id = obj_id + 1
    let cx = (Double::from_int(shape.width * emu_per_pixel) * shape.scale_x)
      .round()
      .to_int()
    let cy = (Double::from_int(shape.height * emu_per_pixel) * shape.scale_y)
      .round()
      .to_int()
    sb.write_view("  <xdr:oneCellAnchor>\n")
    sb.write_view("    <xdr:from>\n")
    sb.write_view("      <xdr:col>\{col_idx}</xdr:col>\n")
    sb.write_view("      <xdr:colOff>0</xdr:colOff>\n")
    sb.write_view("      <xdr:row>\{row_idx}</xdr:row>\n")
    sb.write_view("      <xdr:rowOff>0</xdr:rowOff>\n")
    sb.write_view("    </xdr:from>\n")
    sb.write_view("    <xdr:ext cx=\"\{cx}\" cy=\"\{cy}\"/>\n")
    sb.write_view("    <xdr:sp>\n")
    sb.write_view("      <xdr:nvSpPr>\n")
    let shape_name = if shape.name == "" {
      "Shape \{shape_id}"
    } else {
      shape.name
    }
    sb.write_view("        <xdr:cNvPr id=\"\{shape_id}\" name=\"")
    sb.write_view(escape_xml_attr(shape_name))
    sb.write_view("\"")
    if shape.alt_text != "" {
      sb.write_view(" descr=\"")
      sb.write_view(escape_xml_attr(shape.alt_text))
      sb.write_view("\"")
    }
    sb.write_view("/>\n")
    sb.write_view("        <xdr:cNvSpPr/>\n")
    sb.write_view("      </xdr:nvSpPr>\n")
    sb.write_view("      <xdr:spPr>\n")
    sb.write_view("        <a:xfrm>\n")
    sb.write_view("          <a:off x=\"0\" y=\"0\"/>\n")
    sb.write_view("          <a:ext cx=\"\{cx}\" cy=\"\{cy}\"/>\n")
    sb.write_view("        </a:xfrm>\n")
    if shape.fill_color != "" {
      let fill = shape.fill_color.replace_all(old="#", new="").to_upper()
      sb.write_view("        <a:solidFill><a:srgbClr val=\"")
      sb.write_view(escape_xml_attr(fill))
      if shape.fill_transparency > 0 {
        let alpha = (100 - shape.fill_transparency) * 1000
        sb.write_view(
          "\"><a:alpha val=\"\{alpha}\"/></a:srgbClr></a:solidFill>\n",
        )
      } else {
        sb.write_view("\"/></a:solidFill>\n")
      }
    }
    if shape.line_color != "" || shape.line_width != 1.0 {
      sb.write_view("        <a:ln")
      if shape.line_width != 1.0 {
        let w = (shape.line_width * 12700.0).round().to_int()
        sb.write_view(" w=\"\{w}\"")
      }
      if shape.line_color == "" {
        sb.write_view("/>\n")
      } else {
        let line = shape.line_color.replace_all(old="#", new="").to_upper()
        sb.write_view("><a:solidFill><a:srgbClr val=\"")
        sb.write_view(escape_xml_attr(line))
        sb.write_view("\"/></a:solidFill></a:ln>\n")
      }
    }
    sb.write_view("        <a:prstGeom prst=\"")
    sb.write_view(escape_xml_attr(shape.shape_type.to_lower()))
    sb.write_view("\"><a:avLst/></a:prstGeom>\n")
    sb.write_view("      </xdr:spPr>\n")
    if shape.paragraph.length() > 0 || shape.text != "" {
      sb.write_view("      <xdr:txBody>\n")
      sb.write_view("        <a:bodyPr/>\n")
      sb.write_view("        <a:lstStyle/>\n")
      let runs = if shape.paragraph.length() > 0 {
        shape.paragraph[:]
      } else {
        [{ text: shape.text, font: None }]
      }
      for run in runs {
        sb.write_view("        <a:p>\n")
        sb.write_view("          <a:r>\n")
        match run.font {
          Some(font) => {
            sb.write_view("            <a:rPr")
            sb.write_view(" lang=\"en-US\"")
            if font.bold {
              sb.write_view(" b=\"1\"")
            }
            if font.italic {
              sb.write_view(" i=\"1\"")
            }
            match font.underline {
              Some(value) => sb.write_view(" u=\"\{escape_xml_attr(value)}\"")
              None => ()
            }
            match font.size {
              Some(size) =>
                sb.write_view(" sz=\"\{(size * 100.0).round().to_int()}\"")
              None => ()
            }
            sb.write_view(">")
            match font.family {
              Some(family) => {
                sb.write_view("<a:latin typeface=\"")
                sb.write_view(escape_xml_attr(family))
                sb.write_view("\"/>")
                sb.write_view("<a:ea typeface=\"")
                sb.write_view(escape_xml_attr(family))
                sb.write_view("\"/>")
                sb.write_view("<a:cs typeface=\"")
                sb.write_view(escape_xml_attr(family))
                sb.write_view("\"/>")
              }
              None => ()
            }
            match font.color {
              Some(color) => {
                let normalized = color.replace_all(old="#", new="").to_upper()
                sb.write_view("<a:solidFill><a:srgbClr val=\"")
                sb.write_view(escape_xml_attr(normalized))
                sb.write_view("\"/></a:solidFill>")
              }
              None => ()
            }
            sb.write_view("</a:rPr>\n")
          }
          None => sb.write_view("            <a:rPr lang=\"en-US\"/>\n")
        }
        let text_value = if run.text == "" { " " } else { run.text }
        if text_value.has_prefix(" ") ||
          text_value.has_suffix(" ") ||
          text_value.contains("\n") {
          sb.write_view("            <a:t xml:space=\"preserve\">")
        } else {
          sb.write_view("            <a:t>")
        }
        sb.write_view(escape_xml_text(text_value))
        sb.write_view("</a:t>\n")
        sb.write_view("          </a:r>\n")
        sb.write_view("        </a:p>\n")
      }
      sb.write_view("      </xdr:txBody>\n")
    }
    sb.write_view("    </xdr:sp>\n")
    sb.write_view(
      "    <xdr:clientData fLocksWithSheet=\"\{bool_attr(shape.locked)}\" fPrintsWithSheet=\"\{bool_attr(shape.print_object)}\"/>\n",
    )
    sb.write_view("  </xdr:oneCellAnchor>\n")
  }
  sb.write_view("</xdr:wsDr>")
  sb.to_string()
}

///|
fn write_sheet_pr_xml(options : SheetPropsOptions) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <sheetPr")
  match options.code_name {
    Some(value) => {
      sb.write_view(" codeName=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"")
    }
    None => ()
  }
  match options.enable_format_conditions_calculation {
    Some(value) =>
      sb.write_view(
        " enableFormatConditionsCalculation=\"\{bool_attr(value)}\"",
      )
    None => ()
  }
  match options.published {
    Some(value) => sb.write_view(" published=\"\{bool_attr(value)}\"")
    None => ()
  }
  let has_tab_color = options.tab_color_indexed is Some(_) ||
    options.tab_color_rgb is Some(_) ||
    options.tab_color_theme is Some(_) ||
    options.tab_color_tint is Some(_)
  let has_outline = options.outline_summary_below is Some(_) ||
    options.outline_summary_right is Some(_)
  let has_page_setup = options.auto_page_breaks is Some(_) ||
    options.fit_to_page is Some(_)
  if !has_tab_color && !has_outline && !has_page_setup {
    sb.write_view("/>\n")
    return sb.to_string()
  }
  sb.write_view(">\n")
  if has_tab_color {
    sb.write_view("    <tabColor")
    match options.tab_color_indexed {
      Some(value) => sb.write_view(" indexed=\"\{value}\"")
      None => ()
    }
    match options.tab_color_rgb {
      Some(value) => {
        sb.write_view(" rgb=\"")
        sb.write_view(escape_xml_attr(value))
        sb.write_view("\"")
      }
      None => ()
    }
    match options.tab_color_theme {
      Some(value) => sb.write_view(" theme=\"\{value}\"")
      None => ()
    }
    match options.tab_color_tint {
      Some(value) => sb.write_view(" tint=\"\{value}\"")
      None => ()
    }
    sb.write_view("/>\n")
  }
  if has_outline {
    sb.write_view("    <outlinePr")
    match options.outline_summary_below {
      Some(value) => sb.write_view(" summaryBelow=\"\{bool_attr(value)}\"")
      None => ()
    }
    match options.outline_summary_right {
      Some(value) => sb.write_view(" summaryRight=\"\{bool_attr(value)}\"")
      None => ()
    }
    sb.write_view("/>\n")
  }
  if has_page_setup {
    sb.write_view("    <pageSetUpPr")
    match options.auto_page_breaks {
      Some(value) => sb.write_view(" autoPageBreaks=\"\{bool_attr(value)}\"")
      None => ()
    }
    match options.fit_to_page {
      Some(value) => sb.write_view(" fitToPage=\"\{bool_attr(value)}\"")
      None => ()
    }
    sb.write_view("/>\n")
  }
  sb.write_view("  </sheetPr>\n")
  sb.to_string()
}

///|
fn write_sheet_format_pr_xml(options : SheetPropsOptions) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <sheetFormatPr")
  match options.base_col_width {
    Some(value) => sb.write_view(" baseColWidth=\"\{value}\"")
    None => ()
  }
  match options.default_col_width {
    Some(value) => sb.write_view(" defaultColWidth=\"\{value}\"")
    None => ()
  }
  match options.default_row_height {
    Some(value) => sb.write_view(" defaultRowHeight=\"\{value}\"")
    None => ()
  }
  match options.custom_height {
    Some(value) => sb.write_view(" customHeight=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.zero_height {
    Some(value) => sb.write_view(" zeroHeight=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.thick_top {
    Some(value) => sb.write_view(" thickTop=\"\{bool_attr(value)}\"")
    None => ()
  }
  match options.thick_bottom {
    Some(value) => sb.write_view(" thickBottom=\"\{bool_attr(value)}\"")
    None => ()
  }
  sb.write_view("/>\n")
  sb.to_string()
}

///|
fn write_sheet_views_xml(sheet : Worksheet) -> String? {
  if sheet.sheet_views.length() == 0 {
    return None
  }
  let sb = StringBuilder::new()
  sb.write_view("  <sheetViews>\n")
  for view in sheet.sheet_views {
    sb.write_view("    <sheetView")
    match view.default_grid_color {
      Some(value) => sb.write_view(" defaultGridColor=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.right_to_left {
      Some(value) => sb.write_view(" rightToLeft=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.show_formulas {
      Some(value) => sb.write_view(" showFormulas=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.show_grid_lines {
      Some(value) => sb.write_view(" showGridLines=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.show_row_col_headers {
      Some(value) => sb.write_view(" showRowColHeaders=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.show_ruler {
      Some(value) => sb.write_view(" showRuler=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.show_zeros {
      Some(value) => sb.write_view(" showZeros=\"\{bool_attr(value)}\"")
      None => ()
    }
    match view.top_left_cell {
      Some(value) => {
        sb.write_view(" topLeftCell=\"")
        sb.write_view(escape_xml_attr(value))
        sb.write_view("\"")
      }
      None => ()
    }
    match view.view {
      Some(value) => {
        sb.write_view(" view=\"")
        sb.write_view(escape_xml_attr(value))
        sb.write_view("\"")
      }
      None => ()
    }
    match view.zoom_scale {
      Some(value) => sb.write_view(" zoomScale=\"\{value}\"")
      None => ()
    }
    if view.tab_selected {
      sb.write_view(" tabSelected=\"1\"")
    }
    sb.write_view(" workbookViewId=\"\{view.workbook_view_id}\"")
    if view.pane is None && view.selection.length() == 0 {
      sb.write_view("/>\n")
      continue
    }
    sb.write_view(">\n")
    match view.pane {
      Some(pane) => {
        sb.write_view("      <pane")
        if pane.active_pane != "" {
          sb.write_view(" activePane=\"")
          sb.write_view(escape_xml_attr(pane.active_pane))
          sb.write_view("\"")
        }
        if pane.state != "" {
          sb.write_view(" state=\"")
          sb.write_view(escape_xml_attr(pane.state))
          sb.write_view("\"")
        }
        if pane.top_left_cell != "" {
          sb.write_view(" topLeftCell=\"")
          sb.write_view(escape_xml_attr(pane.top_left_cell))
          sb.write_view("\"")
        }
        if pane.x_split != 0.0 {
          sb.write_view(" xSplit=\"\{pane.x_split}\"")
        }
        if pane.y_split != 0.0 {
          sb.write_view(" ySplit=\"\{pane.y_split}\"")
        }
        sb.write_view("/>\n")
      }
      None => ()
    }
    for selection in view.selection {
      sb.write_view("      <selection")
      if selection.pane != "" {
        sb.write_view(" pane=\"")
        sb.write_view(escape_xml_attr(selection.pane))
        sb.write_view("\"")
      }
      if selection.active_cell != "" {
        sb.write_view(" activeCell=\"")
        sb.write_view(escape_xml_attr(selection.active_cell))
        sb.write_view("\"")
      }
      if selection.sqref != "" {
        sb.write_view(" sqref=\"")
        sb.write_view(escape_xml_attr(selection.sqref))
        sb.write_view("\"")
      }
      sb.write_view("/>\n")
    }
    sb.write_view("    </sheetView>\n")
  }
  sb.write_view("  </sheetViews>\n")
  Some(sb.to_string())
}

///|
fn write_chartsheet_xml(drawing_rel_id : Int) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<chartsheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n",
  )
  sb.write_view("  <sheetViews>\n")
  sb.write_view(
    "    <sheetView zoomScale=\"100\" zoomToFit=\"1\" workbookViewId=\"0\"/>\n",
  )
  sb.write_view("  </sheetViews>\n")
  sb.write_view("  <drawing r:id=\"rId\{drawing_rel_id}\"/>\n")
  sb.write_view("</chartsheet>")
  sb.to_string()
}

///|
fn worksheet_dimension(sheet : Worksheet) -> String? raise XlsxError {
  match sheet.dimension_ref {
    Some(value) => return Some(value)
    None => ()
  }
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
  match sheet.auto_filter() {
    Some(filter) => {
      let (row1, col1, row2, col2) = parse_range_ref(filter.range_ref)
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
    None => ()
  }
  if !has_any {
    return None
  }
  let start_ref = cell_ref_from(min_row, min_col)
  let end_ref = cell_ref_from(max_row, max_col)
  Some("\{start_ref}:\{end_ref}")
}

///|
fn write_row_attributes(sb : StringBuilder, dim : RowDimension) -> Unit {
  match dim.height {
    Some(height) => {
      sb.write_view(" ht=\"")
      sb.write_view(height.to_string())
      sb.write_view("\" customHeight=\"1\"")
    }
    None => ()
  }
  if dim.hidden {
    sb.write_view(" hidden=\"1\"")
  }
  if dim.outline_level > 0 {
    sb.write_view(" outlineLevel=\"\{dim.outline_level}\"")
  }
  match dim.style_id {
    Some(style_id) => sb.write_view(" s=\"\{style_id}\" customFormat=\"1\"")
    None => ()
  }
}

///|
fn write_col_attributes(
  sb : StringBuilder,
  col : Int,
  dim : ColDimension,
) -> Unit {
  sb.write_view("    <col min=\"\{col}\" max=\"\{col}\"")
  match dim.width {
    Some(width) => {
      sb.write_view(" width=\"")
      sb.write_view(width.to_string())
      sb.write_view("\" customWidth=\"1\"")
    }
    None => ()
  }
  if dim.hidden {
    sb.write_view(" hidden=\"1\"")
  }
  if dim.outline_level > 0 {
    sb.write_view(" outlineLevel=\"\{dim.outline_level}\"")
  }
  match dim.style_id {
    Some(style_id) => sb.write_view(" style=\"\{style_id}\"")
    None => ()
  }
  sb.write_view("/>\n")
}

///|
fn page_margin_value(value : Double?, fallback : Double) -> Double {
  match value {
    Some(v) => v
    None => fallback
  }
}

///|
fn write_print_options_xml(options : PageLayoutMarginsOptions) -> String? {
  let has_horizontal = options.horizontally is Some(_)
  let has_vertical = options.vertically is Some(_)
  if !has_horizontal && !has_vertical {
    return None
  }
  let sb = StringBuilder::new()
  sb.write_view("  <printOptions")
  match options.horizontally {
    Some(true) => sb.write_view(" horizontalCentered=\"1\"")
    Some(false) => sb.write_view(" horizontalCentered=\"0\"")
    None => ()
  }
  match options.vertically {
    Some(true) => sb.write_view(" verticalCentered=\"1\"")
    Some(false) => sb.write_view(" verticalCentered=\"0\"")
    None => ()
  }
  sb.write_view("/>\n")
  Some(sb.to_string())
}

///|
fn write_page_margins_xml(options : PageLayoutMarginsOptions) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <pageMargins")
  let left = page_margin_value(options.left, 0.7)
  let right = page_margin_value(options.right, 0.7)
  let top = page_margin_value(options.top, 0.75)
  let bottom = page_margin_value(options.bottom, 0.75)
  let header = page_margin_value(options.header, 0.3)
  let footer = page_margin_value(options.footer, 0.3)
  sb.write_view(" left=\"\{left}\"")
  sb.write_view(" right=\"\{right}\"")
  sb.write_view(" top=\"\{top}\"")
  sb.write_view(" bottom=\"\{bottom}\"")
  sb.write_view(" header=\"\{header}\"")
  sb.write_view(" footer=\"\{footer}\"")
  sb.write_view("/>\n")
  sb.to_string()
}

///|
fn write_page_setup_xml(layout : PageLayoutOptions) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <pageSetup")
  match layout.black_and_white {
    Some(true) => sb.write_view(" blackAndWhite=\"1\"")
    Some(false) => sb.write_view(" blackAndWhite=\"0\"")
    None => ()
  }
  match layout.fit_to_height {
    Some(value) => sb.write_view(" fitToHeight=\"\{value}\"")
    None => ()
  }
  match layout.fit_to_width {
    Some(value) => sb.write_view(" fitToWidth=\"\{value}\"")
    None => ()
  }
  match layout.size {
    Some(value) => sb.write_view(" paperSize=\"\{value}\"")
    None => ()
  }
  match layout.orientation {
    Some(value) => {
      sb.write_view(" orientation=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"")
    }
    None => ()
  }
  match layout.page_order {
    Some(value) => {
      sb.write_view(" pageOrder=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"")
    }
    None => ()
  }
  match layout.first_page_number {
    Some(value) =>
      if value > 0 {
        sb.write_view(" firstPageNumber=\"\{value}\" useFirstPageNumber=\"1\"")
      }
    None => ()
  }
  match layout.adjust_to {
    Some(value) => sb.write_view(" scale=\"\{value}\"")
    None => ()
  }
  sb.write_view("/>\n")
  sb.to_string()
}

///|
fn write_header_footer_xml(options : HeaderFooterOptions) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <headerFooter")
  if options.different_odd_even {
    sb.write_view(" differentOddEven=\"1\"")
  }
  if options.different_first {
    sb.write_view(" differentFirst=\"1\"")
  }
  match options.scale_with_doc {
    Some(value) => {
      let flag = if value { "1" } else { "0" }
      sb.write_view(" scaleWithDoc=\"\{flag}\"")
    }
    None => ()
  }
  match options.align_with_margins {
    Some(value) => {
      let flag = if value { "1" } else { "0" }
      sb.write_view(" alignWithMargins=\"\{flag}\"")
    }
    None => ()
  }
  sb.write_view(">\n")
  if options.odd_header != "" {
    sb.write_view("    <oddHeader>")
    sb.write_view(escape_xml_text(options.odd_header))
    sb.write_view("</oddHeader>\n")
  }
  if options.odd_footer != "" {
    sb.write_view("    <oddFooter>")
    sb.write_view(escape_xml_text(options.odd_footer))
    sb.write_view("</oddFooter>\n")
  }
  if options.even_header != "" {
    sb.write_view("    <evenHeader>")
    sb.write_view(escape_xml_text(options.even_header))
    sb.write_view("</evenHeader>\n")
  }
  if options.even_footer != "" {
    sb.write_view("    <evenFooter>")
    sb.write_view(escape_xml_text(options.even_footer))
    sb.write_view("</evenFooter>\n")
  }
  if options.first_header != "" {
    sb.write_view("    <firstHeader>")
    sb.write_view(escape_xml_text(options.first_header))
    sb.write_view("</firstHeader>\n")
  }
  if options.first_footer != "" {
    sb.write_view("    <firstFooter>")
    sb.write_view(escape_xml_text(options.first_footer))
    sb.write_view("</firstFooter>\n")
  }
  sb.write_view("  </headerFooter>\n")
  sb.to_string()
}

///|
fn write_sheet_protection_xml(protection : SheetProtection) -> String {
  let sb = StringBuilder::new()
  sb.write_view("  <sheetProtection")
  if protection.algorithm_name != "" {
    sb.write_view(" algorithmName=\"")
    sb.write_view(escape_xml_attr(protection.algorithm_name))
    sb.write_view("\"")
  }
  if protection.password != "" {
    sb.write_view(" password=\"")
    sb.write_view(escape_xml_attr(protection.password))
    sb.write_view("\"")
  }
  if protection.hash_value != "" {
    sb.write_view(" hashValue=\"")
    sb.write_view(escape_xml_attr(protection.hash_value))
    sb.write_view("\"")
  }
  if protection.salt_value != "" {
    sb.write_view(" saltValue=\"")
    sb.write_view(escape_xml_attr(protection.salt_value))
    sb.write_view("\"")
  }
  if protection.spin_count > 0 {
    sb.write_view(" spinCount=\"\{protection.spin_count}\"")
  }
  if protection.sheet {
    sb.write_view(" sheet=\"1\"")
  }
  if protection.objects {
    sb.write_view(" objects=\"1\"")
  }
  if protection.scenarios {
    sb.write_view(" scenarios=\"1\"")
  }
  if protection.format_cells {
    sb.write_view(" formatCells=\"1\"")
  }
  if protection.format_columns {
    sb.write_view(" formatColumns=\"1\"")
  }
  if protection.format_rows {
    sb.write_view(" formatRows=\"1\"")
  }
  if protection.insert_columns {
    sb.write_view(" insertColumns=\"1\"")
  }
  if protection.insert_rows {
    sb.write_view(" insertRows=\"1\"")
  }
  if protection.insert_hyperlinks {
    sb.write_view(" insertHyperlinks=\"1\"")
  }
  if protection.delete_columns {
    sb.write_view(" deleteColumns=\"1\"")
  }
  if protection.delete_rows {
    sb.write_view(" deleteRows=\"1\"")
  }
  if protection.select_locked_cells {
    sb.write_view(" selectLockedCells=\"1\"")
  }
  if protection.sort {
    sb.write_view(" sort=\"1\"")
  }
  if protection.auto_filter {
    sb.write_view(" autoFilter=\"1\"")
  }
  if protection.pivot_tables {
    sb.write_view(" pivotTables=\"1\"")
  }
  if protection.select_unlocked_cells {
    sb.write_view(" selectUnlockedCells=\"1\"")
  }
  sb.write_view("/>\n")
  sb.to_string()
}

///|
fn write_page_breaks_xml(
  tag_name : StringView,
  breaks : ArrayView[PageBreak],
) -> String? {
  if breaks.length() == 0 {
    return None
  }
  let sb = StringBuilder::new()
  let mut manual_count = 0
  for brk in breaks {
    if brk.manual {
      manual_count = manual_count + 1
    }
  }
  sb.write_view(
    "  <\{tag_name.to_string()} count=\"\{breaks.length()}\" manualBreakCount=\"\{manual_count}\">\n",
  )
  for brk in breaks {
    sb.write_view("    <brk id=\"\{brk.id}\"")
    if brk.min > 0 {
      sb.write_view(" min=\"\{brk.min}\"")
    }
    if brk.max > 0 {
      sb.write_view(" max=\"\{brk.max}\"")
    }
    if brk.manual {
      sb.write_view(" man=\"1\"")
    }
    sb.write_view("/>\n")
  }
  sb.write_view("  </\{tag_name.to_string()}>\n")
  Some(sb.to_string())
}

///|
fn write_auto_filter_xml(filter : AutoFilter) -> String raise XlsxError {
  let sb = StringBuilder::new()
  let (min_row, min_col, max_row, max_col) = parse_range_ref(filter.range_ref)
  let start_ref = cell_ref_from(min_row, min_col)
  let end_ref = cell_ref_from(max_row, max_col)
  let range_ref = "\{start_ref}:\{end_ref}"
  if filter.columns.length() == 0 {
    sb.write_view("  <autoFilter ref=\"")
    sb.write_view(escape_xml_attr(range_ref))
    sb.write_view("\"/>\n")
    return sb.to_string()
  }
  sb.write_view("  <autoFilter ref=\"")
  sb.write_view(escape_xml_attr(range_ref))
  sb.write_view("\">\n")
  for column in filter.columns {
    if column.col < min_col || column.col > max_col {
      raise XlsxError::InvalidAutoFilter(msg="auto filter column out of range")
    }
    let col_id = column.col - min_col
    sb.write_view("    <filterColumn colId=\"\{col_id}\">\n")
    match column.filters {
      Some(values) => {
        sb.write_view("      <filters>\n")
        for value in values {
          sb.write_view("        <filter val=\"")
          sb.write_view(escape_xml_attr(value))
          sb.write_view("\"/>\n")
        }
        sb.write_view("      </filters>\n")
      }
      None => ()
    }
    match column.custom_filters {
      Some(custom) => {
        sb.write_view("      <customFilters")
        if custom.and_filter {
          sb.write_view(" and=\"1\"")
        }
        sb.write_view(">\n")
        for entry in custom.filters {
          sb.write_view("        <customFilter operator=\"")
          sb.write_view(escape_xml_attr(entry.operator))
          sb.write_view("\" val=\"")
          sb.write_view(escape_xml_attr(entry.value))
          sb.write_view("\"/>\n")
        }
        sb.write_view("      </customFilters>\n")
      }
      None => ()
    }
    sb.write_view("    </filterColumn>\n")
  }
  sb.write_view("  </autoFilter>\n")
  sb.to_string()
}

///|
fn write_worksheet_xml(
  sheet : Worksheet,
  string_map : Map[String, Int],
  rich_text_map : Map[String, Int],
  hyperlink_rel_ids : Map[String, Int],
  hyperlinks : ArrayView[Hyperlink],
  drawing_rel_id : Int?,
  picture_rel_id : Int?,
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
    hyperlink_rel_ids.length() > 0 ||
    legacy_drawing_rel_id is Some(_) ||
    legacy_drawing_hf_rel_id is Some(_) ||
    picture_rel_id is Some(_)
  if needs_rels {
    sb.write_view(
      "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n",
    )
  } else {
    sb.write_view(
      "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">\n",
    )
  }
  match sheet.sheet_props {
    Some(options) =>
      if sheet_props_has_sheet_pr(options) {
        sb.write_view(write_sheet_pr_xml(options))
      }
    None => ()
  }
  match worksheet_dimension(sheet) {
    Some(value) => {
      sb.write_view("  <dimension ref=\"")
      sb.write_view(escape_xml_attr(value))
      sb.write_view("\"/>\n")
    }
    None => ()
  }
  match write_sheet_views_xml(sheet) {
    Some(value) => sb.write_view(value)
    None => ()
  }
  match sheet.sheet_props {
    Some(options) =>
      if sheet_props_has_sheet_format(options) {
        sb.write_view(write_sheet_format_pr_xml(options))
      }
    None => ()
  }
  if sheet.col_dimensions.length() > 0 {
    let cols : Array[Int] = []
    for col, _ in sheet.col_dimensions {
      cols.push(col)
    }
    cols.sort_by((a, b) => a - b)
    sb.write_view("  <cols>\n")
    for col in cols {
      match sheet.col_dimensions.get(col) {
        Some(dim) => write_col_attributes(sb, col, dim)
        None => ()
      }
    }
    sb.write_view("  </cols>\n")
  }
  sb.write_view("  <sheetData>\n")
  let cells = sheet.sorted_cells()
  let row_cells : Map[Int, Array[Cell]] = {}
  for cell in cells {
    let entries = match row_cells.get(cell.row) {
      Some(value) => value
      None => []
    }
    entries.push(cell)
    row_cells[cell.row] = entries
  }
  let row_keys : Array[Int] = []
  let row_present : Map[Int, Bool] = {}
  for row, _ in row_cells {
    row_keys.push(row)
    row_present[row] = true
  }
  for row, _ in sheet.row_dimensions {
    if !row_present.contains(row) {
      row_keys.push(row)
    }
  }
  row_keys.sort_by((a, b) => a - b)
  for row in row_keys {
    let row_entries = match row_cells.get(row) {
      Some(value) => value
      None => []
    }
    sb.write_view("    <row r=\"\{row}\"")
    match sheet.row_dimensions.get(row) {
      Some(dim) => write_row_attributes(sb, dim)
      None => ()
    }
    if row_entries.length() == 0 {
      sb.write_view("/>\n")
      continue
    }
    sb.write_view(">\n")
    for cell in row_entries {
      sb.write_view("      <c r=\"")
      sb.write_view(escape_xml_attr(cell.reference))
      sb.write_view("\"")
      if cell.style_id != 0 {
        sb.write_view(" s=\"\{cell.style_id}\"")
      }
      match cell.formula {
        Some(formula) => {
          match cell.value_type {
            CellValueType::String =>
              if cell.value != "" {
                sb.write_view(" t=\"str\"")
              }
            CellValueType::Bool => sb.write_view(" t=\"b\"")
            CellValueType::Error => sb.write_view(" t=\"e\"")
            CellValueType::Number => ()
          }
          sb.write_view(">")
          sb.write_view("<f")
          match cell.formula_type {
            Some(kind) => {
              sb.write_view(" t=\"")
              sb.write_view(formula_type_to_ooxml(kind))
              sb.write_view("\"")
            }
            None => ()
          }
          match cell.formula_ref {
            Some(value) => {
              sb.write_view(" ref=\"")
              sb.write_view(escape_xml_attr(value))
              sb.write_view("\"")
            }
            None => ()
          }
          match cell.formula_shared_index {
            Some(si) => sb.write_view(" si=\"\{si}\"")
            None => ()
          }
          sb.write_view(">")
          sb.write_view(escape_xml_text(formula))
          sb.write_view("</f>")
          if cell.value != "" {
            sb.write_view("<v>")
            match cell.value_type {
              CellValueType::String =>
                sb.write_view(escape_xml_text(cell.value))
              CellValueType::Error => sb.write_view(escape_xml_text(cell.value))
              _ => sb.write_view(cell.value)
            }
            sb.write_view("</v>")
          }
          sb.write_view("</c>\n")
        }
        None =>
          match cell.value_type {
            CellValueType::String => {
              let idx = match cell.rich_text {
                Some(_) =>
                  match rich_text_map.get(cell.reference) {
                    Some(value) => value
                    None => raise XlsxError::InvalidSharedString(index=cell.row)
                  }
                None =>
                  match string_map.get(cell.value) {
                    Some(value) => value
                    None => raise XlsxError::InvalidSharedString(index=cell.row)
                  }
              }
              sb.write_view(" t=\"s\"><v>\{idx}</v></c>\n")
            }
            CellValueType::Bool => {
              sb.write_view(" t=\"b\"><v>")
              sb.write_view(cell.value)
              sb.write_view("</v></c>\n")
            }
            CellValueType::Error => {
              sb.write_view(" t=\"e\"><v>")
              sb.write_view(escape_xml_text(cell.value))
              sb.write_view("</v></c>\n")
            }
            CellValueType::Number => {
              sb.write_view("><v>")
              sb.write_view(cell.value)
              sb.write_view("</v></c>\n")
            }
          }
      }
    }
    sb.write_view("    </row>\n")
  }
  sb.write_view("  </sheetData>\n")
  match sheet.sheet_protection() {
    Some(protection) => sb.write_view(write_sheet_protection_xml(protection))
    None => ()
  }
  match sheet.auto_filter() {
    Some(filter) => sb.write_view(write_auto_filter_xml(filter))
    None => ()
  }
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
  match write_ignored_errors_xml(sheet.ignored_errors()) {
    Some(value) => sb.write_view(value)
    None => ()
  }
  if hyperlinks.length() > 0 {
    let mut wrote = false
    for link in hyperlinks {
      if link.link_type == HyperlinkType::Unset {
        continue
      }
      if !wrote {
        sb.write_view("  <hyperlinks>\n")
        wrote = true
      }
      sb.write_view("    <hyperlink ref=\"")
      sb.write_view(escape_xml_attr(link.reference))
      sb.write_view("\"")
      match link.link_type {
        HyperlinkType::External =>
          match hyperlink_rel_ids.get(link.reference) {
            Some(rel_id) => sb.write_view(" r:id=\"rId\{rel_id}\"")
            None =>
              raise XlsxError::InvalidHyperlink(
                msg="hyperlink relationship missing",
              )
          }
        HyperlinkType::Location => {
          sb.write_view(" location=\"")
          sb.write_view(escape_xml_attr(link.target))
          sb.write_view("\"")
        }
        HyperlinkType::Unset => ()
      }
      match link.display {
        Some(value) => {
          sb.write_view(" display=\"")
          sb.write_view(escape_xml_attr(value))
          sb.write_view("\"")
        }
        None => ()
      }
      match link.tooltip {
        Some(value) => {
          sb.write_view(" tooltip=\"")
          sb.write_view(escape_xml_attr(value))
          sb.write_view("\"")
        }
        None => ()
      }
      sb.write_view("/>\n")
    }
    if wrote {
      sb.write_view("  </hyperlinks>\n")
    }
  }
  match sheet.page_margins {
    Some(margins) => {
      match write_print_options_xml(margins) {
        Some(xml) => sb.write_view(xml)
        None => ()
      }
      let merged = page_margins_with_defaults(Some(margins))
      sb.write_view(write_page_margins_xml(merged))
    }
    None => ()
  }
  match sheet.page_layout {
    Some(layout) => sb.write_view(write_page_setup_xml(layout))
    None => ()
  }
  match sheet.header_footer() {
    Some(options) => sb.write_view(write_header_footer_xml(options))
    None => ()
  }
  match write_page_breaks_xml("rowBreaks", sheet.row_breaks()) {
    Some(xml) => sb.write_view(xml)
    None => ()
  }
  match write_page_breaks_xml("colBreaks", sheet.col_breaks()) {
    Some(xml) => sb.write_view(xml)
    None => ()
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
  match picture_rel_id {
    Some(rel_id) => sb.write_view("  <picture r:id=\"rId\{rel_id}\"/>\n")
    None => ()
  }
  if sheet.sparkline_groups().length() > 0 {
    sb.write_view(write_sparkline_ext_xml(sheet.sparkline_groups()))
  }
  sb.write_view("</worksheet>")
  sb.to_string()
}

///|
fn truncate_comment_content(comment : Comment) -> (String, Array[RichTextRun]) {
  let mut remaining = max_cell_chars
  let mut text = comment.text
  if text != "" {
    let units = count_utf16_units(text)
    if units > remaining {
      text = truncate_utf16_units(text, remaining)
      remaining = 0
    } else {
      remaining = remaining - units
    }
  }
  let runs = rich_text_truncate_runs(comment.paragraph, remaining)
  (text, runs)
}

///|
fn write_comments_xml(comments : ArrayView[Comment]) -> String {
  let authors : Array[String] = []
  let author_ids : Map[String, Int] = {}
  for comment in comments {
    let base_author = if comment.author == "" {
      "Author"
    } else {
      comment.author
    }
    let author = if count_utf16_units(base_author) > max_comment_author_chars {
      truncate_utf16_units(base_author, max_comment_author_chars)
    } else {
      base_author
    }
    if !author_ids.contains(author) {
      author_ids[author] = authors.length()
      authors.push(author)
    }
  }
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<comments xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">\n",
  )
  sb.write_view("  <authors>\n")
  for author in authors {
    sb.write_view("    <author>")
    sb.write_view(escape_xml_text(author))
    sb.write_view("</author>\n")
  }
  sb.write_view("  </authors>\n")
  sb.write_view("  <commentList>\n")
  for comment in comments {
    let base_author = if comment.author == "" {
      "Author"
    } else {
      comment.author
    }
    let author = if count_utf16_units(base_author) > max_comment_author_chars {
      truncate_utf16_units(base_author, max_comment_author_chars)
    } else {
      base_author
    }
    let author_id = match author_ids.get(author) {
      Some(id) => id
      None => 0
    }
    let (text_value, runs) = truncate_comment_content(comment)
    sb.write_view("    <comment ref=\"")
    sb.write_view(escape_xml_attr(comment.cell))
    sb.write_view("\" authorId=\"\{author_id}\">\n")
    sb.write_view("      <text>")
    if text_value != "" {
      if text_value.has_prefix(" ") ||
        text_value.has_suffix(" ") ||
        text_value.contains("\n") {
        sb.write_view("<t xml:space=\"preserve\">")
      } else {
        sb.write_view("<t>")
      }
      sb.write_view(escape_xml_text(text_value))
      sb.write_view("</t>")
    }
    for run in runs {
      sb.write_view("<r>")
      match run.font {
        Some(font) => {
          sb.write_view("<rPr>")
          if font.bold {
            sb.write_view("<b/>")
          }
          if font.italic {
            sb.write_view("<i/>")
          }
          match font.underline {
            Some(value) =>
              sb.write_view("<u val=\"\{escape_xml_attr(value)}\"/>")
            None => ()
          }
          match font.size {
            Some(size) => sb.write_view("<sz val=\"\{size}\"/>")
            None => ()
          }
          match font.family {
            Some(family) =>
              sb.write_view("<rFont val=\"\{escape_xml_attr(family)}\"/>")
            None => ()
          }
          match font.color {
            Some(color) => {
              let normalized = color.replace_all(old="#", new="")
              let rgb = if normalized.length() == 6 {
                "FF" + normalized
              } else {
                normalized
              }
              sb.write_view("<color rgb=\"\{escape_xml_attr(rgb)}\"/>")
            }
            None => ()
          }
          sb.write_view("</rPr>")
        }
        None => ()
      }
      if run.text.has_prefix(" ") ||
        run.text.has_suffix(" ") ||
        run.text.contains("\n") {
        sb.write_view("<t xml:space=\"preserve\">")
      } else {
        sb.write_view("<t>")
      }
      sb.write_view(escape_xml_text(run.text))
      sb.write_view("</t></r>")
    }
    sb.write_view("</text>\n")
    sb.write_view("    </comment>\n")
  }
  sb.write_view("  </commentList>\n")
  sb.write_view("</comments>")
  sb.to_string()
}

///|
fn write_comments_vml(
  sheet_id : Int,
  comments : ArrayView[Comment],
) -> String raise XlsxError {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:o=\"urn:schemas-microsoft-com:office:office\" xmlns:x=\"urn:schemas-microsoft-com:office:excel\">\n",
  )
  sb.write_view("  <o:shapelayout v:ext=\"edit\">\n")
  sb.write_view("    <o:idmap v:ext=\"edit\" data=\"\{sheet_id}\"/>\n")
  sb.write_view("  </o:shapelayout>\n")
  sb.write_view(
    "  <v:shapetype id=\"_x0000_t202\" coordsize=\"21600,21600\" o:spt=\"202\" path=\"m0,0l0,21600,21600,21600,21600,0xe\">\n",
  )
  sb.write_view("    <v:stroke joinstyle=\"miter\"/>\n")
  sb.write_view("    <v:path o:connecttype=\"rect\"/>\n")
  sb.write_view("  </v:shapetype>\n")
  let mut shape_id = 1025
  for comment in comments {
    let (row, col) = cell_ref_to_rc(comment.cell)
    let row0 = row - 1
    let col0 = col - 1
    let anchor = "\{col0}, 15, \{row0}, 2, \{col0 + 2}, 15, \{row0 + 3}, 16"
    sb.write_view(
      "  <v:shape id=\"_x0000_s\{shape_id}\" type=\"#_x0000_t202\" style=\"position:absolute;73.5pt;width:108pt;height:59.25pt;z-index:1;visibility:hidden\" fillcolor=\"#ffffe1\" o:insetmode=\"auto\">\n",
    )
    sb.write_view("    <v:fill color2=\"#ffffe1\"/>\n")
    sb.write_view("    <v:shadow on=\"t\" color=\"black\" obscured=\"t\"/>\n")
    sb.write_view("    <v:path o:connecttype=\"none\"/>\n")
    sb.write_view("    <v:textbox style=\"mso-direction-alt:auto\">\n")
    sb.write_view("      <div style=\"text-align:left\"/>\n")
    sb.write_view("    </v:textbox>\n")
    sb.write_view("    <x:ClientData ObjectType=\"Note\">\n")
    sb.write_view("      <x:MoveWithCells/>\n")
    sb.write_view("      <x:SizeWithCells/>\n")
    sb.write_view("      <x:Anchor>\{anchor}</x:Anchor>\n")
    sb.write_view("      <x:AutoFill>False</x:AutoFill>\n")
    sb.write_view("      <x:Row>\{row0}</x:Row>\n")
    sb.write_view("      <x:Column>\{col0}</x:Column>\n")
    sb.write_view("    </x:ClientData>\n")
    sb.write_view("  </v:shape>\n")
    shape_id = shape_id + 1
  }
  sb.write_view("</xml>")
  sb.to_string()
}

///|
fn extract_vml_shapetype(xml : StringView) -> String? raise XlsxError {
  let xml_str = xml.to_string()
  let start = match xml_str.find("<v:shapetype") {
    Some(pos) => pos
    None => return None
  }
  let end = match xml_str.find("</v:shapetype>") {
    Some(pos) => pos + "</v:shapetype>".length()
    None => return None
  }
  let slice = xml_str[start:end] catch {
      _ => raise XlsxError::InvalidVmlDrawing(msg="vml shapetype invalid")
    }
  Some(slice.to_string())
}

///|
fn extract_vml_shapes(xml : StringView) -> Array[String] raise XlsxError {
  let shapes : Array[String] = []
  let xml_str = xml.to_string()
  let needle = "<v:shape"
  let mut start_pos = 0
  while start_pos < xml_str.length() {
    let rest = xml_str[start_pos:] catch {
        _ => raise XlsxError::InvalidVmlDrawing(msg="vml shape slice invalid")
      }
    let rel = match rest.find(needle) {
      Some(pos) => pos
      None => break
    }
    let start = start_pos + rel
    let after = start + needle.length()
    let next_char = if after < xml_str.length() {
      xml_str.get_char(after)
    } else {
      None
    }
    let is_shape = match next_char {
      Some(' ') | Some('>') | Some('/') => true
      _ => false
    }
    if !is_shape {
      start_pos = start + 1
      continue
    }
    let shape_rest = xml_str[start:] catch {
        _ => raise XlsxError::InvalidVmlDrawing(msg="vml shape slice invalid")
      }
    let end_rel = match shape_rest.find("</v:shape>") {
      Some(pos) => pos
      None => break
    }
    let end = start + end_rel + "</v:shape>".length()
    let slice = xml_str[start:end] catch {
        _ => raise XlsxError::InvalidVmlDrawing(msg="vml shape slice invalid")
      }
    shapes.push(slice.to_string())
    start_pos = end
  }
  shapes
}

///|
fn vml_shape_id(shape_xml : StringView) -> String? {
  let xml_str = shape_xml.to_string()
  let id_key = "id=\""
  let start = match xml_str.find(id_key) {
    Some(pos) => pos + id_key.length()
    None => return None
  }
  let rest = xml_str[start:] catch { _ => return None }
  let end_rel = match rest.find("\"") {
    Some(pos) => pos
    None => return None
  }
  let end = start + end_rel
  let slice = xml_str[start:end] catch { _ => return None }
  Some(slice.to_string())
}

///|
fn filter_vml_shapes_by_id(
  base_xml : String,
  remove_ids : Array[String],
) -> String raise XlsxError {
  if remove_ids.length() == 0 {
    return base_xml
  }
  if !base_xml.contains("<v:shape") {
    return base_xml
  }
  let remove_map : Map[String, Bool] = {}
  for id in remove_ids {
    remove_map[id] = true
  }
  let shapes = extract_vml_shapes(base_xml)
  let kept : Array[String] = []
  for shape in shapes {
    match vml_shape_id(shape) {
      Some(id) =>
        if remove_map.contains(id) {
          continue
        } else {
          kept.push(shape)
        }
      None => kept.push(shape)
    }
  }
  let insert_at = match base_xml.find("<v:shape") {
    Some(pos) => pos
    None =>
      match base_xml.find("</xml>") {
        Some(pos) => pos
        None => base_xml.length()
      }
  }
  let end = match base_xml.find("</xml>") {
    Some(pos) => pos
    None => base_xml.length()
  }
  let prefix = base_xml[:insert_at] catch {
      _ => raise XlsxError::InvalidVmlDrawing(msg="vml prefix invalid")
    }
  let suffix = base_xml[end:] catch {
      _ => raise XlsxError::InvalidVmlDrawing(msg="vml suffix invalid")
    }
  let sb = StringBuilder::new()
  sb.write_view(prefix)
  for shape in kept {
    sb.write_view(shape)
  }
  sb.write_view(suffix)
  sb.to_string()
}

///|
fn merge_vml_drawings(
  base_xml : String,
  comment_xml : String,
) -> String raise XlsxError {
  if !base_xml.contains("</xml>") {
    return comment_xml
  }
  let mut merged = base_xml
  if !merged.contains("_x0000_t202") {
    match extract_vml_shapetype(comment_xml) {
      Some(shape_type) => {
        let insert_at = match merged.find("<v:shape") {
          Some(pos) => pos
          None =>
            match merged.find("</xml>") {
              Some(pos) => pos
              None => merged.length()
            }
        }
        let prefix = merged[:insert_at] catch {
            _ => raise XlsxError::InvalidVmlDrawing(msg="vml prefix invalid")
          }
        let suffix = merged[insert_at:] catch {
            _ => raise XlsxError::InvalidVmlDrawing(msg="vml suffix invalid")
          }
        let sb = StringBuilder::new()
        sb.write_view(prefix)
        sb.write_view(shape_type)
        sb.write_view(suffix)
        merged = sb.to_string()
      }
      None => ()
    }
  }
  let shapes = extract_vml_shapes(comment_xml)
  if shapes.length() == 0 {
    return merged
  }
  let insert_at = match merged.find("</xml>") {
    Some(pos) => pos
    None => merged.length()
  }
  let prefix = merged[:insert_at] catch {
      _ => raise XlsxError::InvalidVmlDrawing(msg="vml prefix invalid")
    }
  let suffix = merged[insert_at:] catch {
      _ => raise XlsxError::InvalidVmlDrawing(msg="vml suffix invalid")
    }
  let sb = StringBuilder::new()
  sb.write_view(prefix)
  for shape in shapes {
    sb.write_view(shape)
  }
  sb.write_view(suffix)
  sb.to_string()
}

///|
fn merge_vml_drawings_with_shapetype(
  base_xml : String,
  extra_xml : String,
  shape_type_id : StringView,
) -> String raise XlsxError {
  if !base_xml.contains("</xml>") {
    return extra_xml
  }
  let mut merged = base_xml
  let shape_token = "id=\"\{shape_type_id.to_string()}\""
  if !merged.contains(shape_token) {
    match extract_vml_shapetype(extra_xml) {
      Some(shape_type) => {
        let insert_at = match merged.find("<v:shape") {
          Some(pos) => pos
          None =>
            match merged.find("</xml>") {
              Some(pos) => pos
              None => merged.length()
            }
        }
        let prefix = merged[:insert_at] catch {
            _ => raise XlsxError::InvalidVmlDrawing(msg="vml prefix invalid")
          }
        let suffix = merged[insert_at:] catch {
            _ => raise XlsxError::InvalidVmlDrawing(msg="vml suffix invalid")
          }
        let sb = StringBuilder::new()
        sb.write_view(prefix)
        sb.write_view(shape_type)
        sb.write_view(suffix)
        merged = sb.to_string()
      }
      None => ()
    }
  }
  let shapes = extract_vml_shapes(extra_xml)
  if shapes.length() == 0 {
    return merged
  }
  let insert_at = match merged.find("</xml>") {
    Some(pos) => pos
    None => merged.length()
  }
  let prefix = merged[:insert_at] catch {
      _ => raise XlsxError::InvalidVmlDrawing(msg="vml prefix invalid")
    }
  let suffix = merged[insert_at:] catch {
      _ => raise XlsxError::InvalidVmlDrawing(msg="vml suffix invalid")
    }
  let sb = StringBuilder::new()
  sb.write_view(prefix)
  for shape in shapes {
    sb.write_view(shape)
  }
  sb.write_view(suffix)
  sb.to_string()
}

///|
fn write_header_footer_vml(
  sheet_id : Int,
  images : ArrayView[HeaderFooterImage],
) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:o=\"urn:schemas-microsoft-com:office:office\" xmlns:x=\"urn:schemas-microsoft-com:office:excel\">\n",
  )
  sb.write_view("  <o:shapelayout v:ext=\"edit\">\n")
  sb.write_view("    <o:idmap v:ext=\"edit\" data=\"\{sheet_id}\"/>\n")
  sb.write_view("  </o:shapelayout>\n")
  sb.write_view(
    "  <v:shapetype id=\"_x0000_t75\" coordsize=\"21600,21600\" o:spt=\"75\" o:preferrelative=\"t\" path=\"m@4@5l@4@11@9@11@9@5xe\" filled=\"f\" stroked=\"f\">\n",
  )
  sb.write_view("    <v:stroke joinstyle=\"miter\"/>\n")
  sb.write_view("    <v:formulas>\n")
  sb.write_view("      <v:f eqn=\"if lineDrawn pixelLineWidth 0\"/>\n")
  sb.write_view("      <v:f eqn=\"sum @0 1 0\"/>\n")
  sb.write_view("      <v:f eqn=\"sum 0 0 @1\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @2 1 2\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @3 21600 pixelWidth\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @3 21600 pixelHeight\"/>\n")
  sb.write_view("      <v:f eqn=\"sum @0 0 1\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @6 1 2\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @7 21600 pixelWidth\"/>\n")
  sb.write_view("      <v:f eqn=\"sum @8 21600 0\"/>\n")
  sb.write_view("      <v:f eqn=\"prod @7 21600 pixelHeight\"/>\n")
  sb.write_view("      <v:f eqn=\"sum @10 21600 0\"/>\n")
  sb.write_view("    </v:formulas>\n")
  sb.write_view(
    "    <v:path o:extrusionok=\"f\" gradientshapeok=\"t\" o:connecttype=\"rect\"/>\n",
  )
  sb.write_view("    <o:lock v:ext=\"edit\" aspectratio=\"t\"/>\n")
  sb.write_view("  </v:shapetype>\n")
  let mut shape_id = 1025
  let mut rel_id = 1
  for image in images {
    let shape_name = header_footer_image_shape_id(
      image.position,
      image.is_footer,
      image.first_page,
    )
    let style = "position:absolute;margin-left:0;margin-top:0;width:\{image.width};height:\{image.height};z-index:1"
    sb.write_view("  <v:shape id=\"")
    sb.write_view(escape_xml_attr(shape_name))
    sb.write_view(
      "\" o:spid=\"_x0000_s\{shape_id}\" type=\"#_x0000_t75\" style=\"",
    )
    sb.write_view(escape_xml_attr(style))
    sb.write_view("\">\n")
    sb.write_view("    <v:imagedata o:relid=\"rId\{rel_id}\" o:title=\"\"/>\n")
    sb.write_view("    <o:lock v:ext=\"edit\" rotation=\"t\"/>\n")
    sb.write_view("  </v:shape>\n")
    shape_id = shape_id + 1
    rel_id = rel_id + 1
  }
  sb.write_view("</xml>")
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
pub fn write(workbook : Workbook) -> Bytes raise XlsxError {
  let (shared_strings, string_map, rich_text_map, total_count) = collect_shared_strings(
    workbook,
  )
  let include_shared = shared_strings.length() > 0
  let sheet_count = workbook.sheets().length()
  let formula_cells = collect_formula_cells(workbook)
  let include_calc_chain = formula_cells.length() > 0
  let rel_offset = 2 +
    (if include_shared { 1 } else { 0 }) +
    (if include_calc_chain { 1 } else { 0 })
  let chartsheet_rel_start = sheet_count + rel_offset + 1
  let manifest = @ooxml.WorkbookManifest::new(
    sheet_count,
    include_shared_strings=include_shared,
    include_calc_chain~,
  )
  for i, _sheet in workbook.chart_sheets() {
    let sheet_id = i + 1
    manifest.add_content_override(
      "/xl/chartsheets/sheet\{sheet_id}.xml",
      ct_chartsheet,
    )
    manifest.add_workbook_relationship(
      rel_chartsheet,
      "chartsheets/sheet\{sheet_id}.xml",
    )
  }
  match workbook.vba_project {
    Some(_) => {
      manifest.set_workbook_content_type(ct_workbook_macro)
      manifest.add_content_default("bin", ct_vba_project)
      manifest.add_workbook_relationship(rel_vba_project, "vbaProject.bin")
    }
    None => ()
  }
  let archive = @zip.Archive::new()
  archive.add("_rels/.rels", @encoding/utf8.encode(manifest.root_rels_xml()))
  archive.add(
    "xl/workbook.xml",
    @encoding/utf8.encode(write_workbook_xml(workbook, chartsheet_rel_start)),
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
  let mut comment_index = 1
  let mut drawing_index = sheet_count + 1
  let mut slicer_index = 1
  let mut slicer_cache_index = 1
  for i, sheet in workbook.sheets() {
    let sheet_id = i + 1
    let sheet_tables = tables_by_sheet[i]
    let sheet_pivots = pivots_by_sheet[i]
    let has_drawing = sheet.images().length() > 0 ||
      sheet.charts().length() > 0 ||
      sheet.shapes().length() > 0
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
    let sheet_slicers : Array[(Int, Int, Slicer)] = []
    for slicer in sheet.slicers() {
      let slicer_id = slicer_index
      slicer_index = slicer_index + 1
      let cache_id = slicer_cache_index
      slicer_cache_index = slicer_cache_index + 1
      sheet_slicers.push((slicer_id, cache_id, slicer))
    }
    let slicer_targets : Array[String] = []
    for entry in sheet_slicers {
      let (slicer_id, _cache_id, _slicer) = entry
      slicer_targets.push("../slicers/slicer\{slicer_id}.xml")
      rel_id = rel_id + 1
    }
    let hyperlink_targets : Array[String] = []
    let hyperlink_rel_ids : Map[String, Int] = {}
    for link in sheet.hyperlinks() {
      if link.link_type == HyperlinkType::External {
        hyperlink_targets.push(link.target)
        hyperlink_rel_ids[link.reference] = rel_id
        rel_id = rel_id + 1
      }
    }
    let comment_targets : Array[String] = []
    let comment_parts : Array[(Int, String)] = []
    let comment_xml = if sheet.comments().length() > 0 {
      Some(write_comments_xml(sheet.comments()))
    } else {
      None
    }
    let comment_vml_xml = if sheet.comments().length() > 0 {
      Some(write_comments_vml(sheet_id, sheet.comments()))
    } else {
      None
    }
    let form_control_vml_xml = if sheet.form_controls().length() > 0 {
      Some(write_form_controls_vml(sheet_id, sheet.form_controls()))
    } else {
      None
    }
    match comment_xml {
      Some(xml) => {
        let comment_id = comment_index
        comment_index = comment_index + 1
        comment_targets.push("../comments\{comment_id}.xml")
        comment_parts.push((comment_id, xml))
      }
      None => ()
    }
    if comment_targets.length() > 0 {
      rel_id = rel_id + comment_targets.length()
    }
    let vml_targets : Array[String] = []
    let vml_parts : Array[(Int, String)] = []
    let vml_image_rels : Array[(Int, Array[String])] = []
    let base_vml = match sheet.vml_drawing_xml() {
      Some(xml) => Some(xml)
      None => None
    }
    let merged_vml = match base_vml {
      Some(xml) =>
        match form_control_vml_xml {
          Some(control_xml) => Some(merge_vml_drawings(xml, control_xml))
          None => Some(xml)
        }
      None => form_control_vml_xml
    }
    let legacy_drawing_xml = match merged_vml {
      Some(xml) =>
        match comment_vml_xml {
          Some(comment_xml) => Some(merge_vml_drawings(xml, comment_xml))
          None => Some(xml)
        }
      None => comment_vml_xml
    }
    let legacy_drawing_rel_id = match legacy_drawing_xml {
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
    let header_footer_images = sheet.header_footer_images
    let header_footer_vml = if header_footer_images.length() > 0 {
      Some(write_header_footer_vml(sheet_id, header_footer_images))
    } else {
      None
    }
    let header_footer_shape_ids : Array[String] = []
    if header_footer_images.length() > 0 {
      for image in header_footer_images {
        header_footer_shape_ids.push(
          header_footer_image_shape_id(
            image.position,
            image.is_footer,
            image.first_page,
          ),
        )
      }
    }
    let legacy_drawing_hf_xml = match sheet.vml_drawing_hf_xml() {
      Some(xml) =>
        match header_footer_vml {
          Some(extra_xml) => {
            let filtered = filter_vml_shapes_by_id(xml, header_footer_shape_ids)
            Some(
              merge_vml_drawings_with_shapetype(
                filtered, extra_xml, "_x0000_t75",
              ),
            )
          }
          None => Some(xml)
        }
      None => header_footer_vml
    }
    let header_footer_image_targets : Array[String] = []
    if header_footer_images.length() > 0 {
      for image in header_footer_images {
        let file_name = "image\{image_index}.\{image.extension}"
        image_index = image_index + 1
        archive.add("xl/media/\{file_name}", image.data)
        header_footer_image_targets.push("../media/\{file_name}")
        if !added_extensions.contains(image.extension) {
          manifest.add_content_default(image.extension, image.content_type)
          added_extensions.set(image.extension, true)
        }
      }
    }
    let legacy_drawing_hf_rel_id = match legacy_drawing_hf_xml {
      Some(xml) => {
        let id = rel_id
        rel_id = rel_id + 1
        let vml_id = vml_index
        vml_index = vml_index + 1
        vml_targets.push("../drawings/vmlDrawing\{vml_id}.vml")
        vml_parts.push((vml_id, xml))
        if header_footer_image_targets.length() > 0 {
          vml_image_rels.push((vml_id, header_footer_image_targets))
        }
        Some(id)
      }
      None => None
    }
    let picture_targets : Array[String] = []
    let picture_rel_id = match sheet.sheet_background() {
      Some(background) => {
        let id = rel_id
        rel_id = rel_id + 1
        let file_name = "image\{image_index}.\{background.extension}"
        image_index = image_index + 1
        archive.add("xl/media/\{file_name}", background.data)
        picture_targets.push("../media/\{file_name}")
        if !added_extensions.contains(background.extension) {
          manifest.add_content_default(
            background.extension,
            background.content_type,
          )
          added_extensions.set(background.extension, true)
        }
        Some(id)
      }
      None => None
    }
    let sheet_xml = write_worksheet_xml(
      sheet,
      string_map,
      rich_text_map,
      hyperlink_rel_ids,
      sheet.hyperlinks(),
      drawing_rel_id,
      picture_rel_id,
      table_rel_ids,
      pivot_rel_ids,
      legacy_drawing_rel_id,
      legacy_drawing_hf_rel_id,
    )
    archive.add(
      "xl/worksheets/sheet\{sheet_id}.xml",
      @encoding/utf8.encode(sheet_xml),
    )
    if drawing_rel_id is Some(_) ||
      table_targets.length() > 0 ||
      pivot_targets.length() > 0 ||
      slicer_targets.length() > 0 ||
      hyperlink_targets.length() > 0 ||
      comment_targets.length() > 0 ||
      vml_targets.length() > 0 ||
      picture_targets.length() > 0 {
      let drawing_target = match drawing_rel_id {
        Some(_) => Some("../drawings/drawing\{sheet_id}.xml")
        None => None
      }
      let sheet_rels_xml = write_sheet_rels_xml(
        drawing_target, table_targets, pivot_targets, slicer_targets, hyperlink_targets,
        comment_targets, vml_targets, picture_targets,
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
    for entry in sheet_slicers {
      let (slicer_id, cache_id, slicer) = entry
      let slicer_xml = write_slicer_xml(slicer, cache_id)
      archive.add(
        "xl/slicers/slicer\{slicer_id}.xml",
        @encoding/utf8.encode(slicer_xml),
      )
      manifest.add_content_override(
        "/xl/slicers/slicer\{slicer_id}.xml",
        ct_slicer,
      )
      let cache_xml = write_slicer_cache_xml(slicer, cache_id)
      archive.add(
        "xl/slicerCaches/slicerCache\{cache_id}.xml",
        @encoding/utf8.encode(cache_xml),
      )
      manifest.add_content_override(
        "/xl/slicerCaches/slicerCache\{cache_id}.xml",
        ct_slicer_cache,
      )
    }
    for part in comment_parts {
      let (comment_id, xml) = part
      archive.add("xl/comments\{comment_id}.xml", @encoding/utf8.encode(xml))
      manifest.add_content_override(
        "/xl/comments\{comment_id}.xml",
        ct_comments,
      )
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
    for part in vml_image_rels {
      let (vml_id, targets) = part
      if targets.length() == 0 {
        continue
      }
      let vml_rels_xml = write_vml_rels_xml(targets)
      archive.add(
        "xl/drawings/_rels/vmlDrawing\{vml_id}.vml.rels",
        @encoding/utf8.encode(vml_rels_xml),
      )
    }
    if !has_drawing {
      continue
    }
    let image_targets : Array[(Int, String)] = []
    let chart_targets : Array[(Int, String)] = []
    let drawing_images : Array[DrawingImage] = []
    let drawing_hyperlinks : Array[DrawingHyperlink] = []
    let drawing_charts : Array[(String, Int)] = []
    let drawing_shapes : Array[Shape] = []
    let mut rel_id = 1
    for image in sheet.images() {
      let file_name = "image\{image_index}.\{image.extension}"
      image_index = image_index + 1
      archive.add("xl/media/\{file_name}", image.data)
      let image_rel_id = rel_id
      rel_id = rel_id + 1
      let mut hyperlink_rel_id : Int? = None
      if image.hyperlink != "" && image.hyperlink_type != HyperlinkType::Unset {
        let link_rel_id = rel_id
        rel_id = rel_id + 1
        drawing_hyperlinks.push({
          rel_id: link_rel_id,
          target: image.hyperlink,
          link_type: image.hyperlink_type,
        })
        hyperlink_rel_id = Some(link_rel_id)
      }
      image_targets.push((image_rel_id, "../media/\{file_name}"))
      drawing_images.push({ image, rel_id: image_rel_id, hyperlink_rel_id })
      if !added_extensions.contains(image.extension) {
        manifest.add_content_default(image.extension, image.content_type)
        added_extensions.set(image.extension, true)
      }
    }
    for chart in sheet.charts() {
      let file_name = "chart\{chart_index}.xml"
      chart_index = chart_index + 1
      archive.add("xl/charts/\{file_name}", @encoding/utf8.encode(chart.xml))
      chart_targets.push((rel_id, "../charts/\{file_name}"))
      drawing_charts.push((chart.reference, rel_id))
      rel_id = rel_id + 1
      manifest.add_content_override("/xl/charts/\{file_name}", ct_chart)
    }
    manifest.add_content_override(
      "/xl/drawings/drawing\{sheet_id}.xml",
      ct_drawing,
    )
    for shape in sheet.shapes() {
      drawing_shapes.push(shape)
    }
    let drawing_xml = write_drawing_xml(
      drawing_images, drawing_charts, drawing_shapes,
    )
    archive.add(
      "xl/drawings/drawing\{sheet_id}.xml",
      @encoding/utf8.encode(drawing_xml),
    )
    let drawing_rels_xml = write_drawing_rels_xml(
      image_targets, chart_targets, drawing_hyperlinks,
    )
    archive.add(
      "xl/drawings/_rels/drawing\{sheet_id}.xml.rels",
      @encoding/utf8.encode(drawing_rels_xml),
    )
  }
  for i, sheet in workbook.chart_sheets() {
    let sheet_id = i + 1
    let chart_name = "chart\{chart_index}.xml"
    chart_index = chart_index + 1
    archive.add(
      "xl/charts/\{chart_name}",
      @encoding/utf8.encode(sheet.chart_xml()),
    )
    manifest.add_content_override("/xl/charts/\{chart_name}", ct_chart)
    let drawing_id = drawing_index
    drawing_index = drawing_index + 1
    manifest.add_content_override(
      "/xl/drawings/drawing\{drawing_id}.xml",
      ct_drawing,
    )
    let drawing_images : Array[DrawingImage] = []
    let drawing_charts : Array[(String, Int)] = [("A1", 1)]
    let drawing_xml = write_drawing_xml(drawing_images, drawing_charts, [])
    archive.add(
      "xl/drawings/drawing\{drawing_id}.xml",
      @encoding/utf8.encode(drawing_xml),
    )
    let chart_targets : Array[(Int, String)] = [(1, "../charts/\{chart_name}")]
    let drawing_rels_xml = write_drawing_rels_xml([], chart_targets, [])
    archive.add(
      "xl/drawings/_rels/drawing\{drawing_id}.xml.rels",
      @encoding/utf8.encode(drawing_rels_xml),
    )
    let chartsheet_xml = write_chartsheet_xml(1)
    archive.add(
      "xl/chartsheets/sheet\{sheet_id}.xml",
      @encoding/utf8.encode(chartsheet_xml),
    )
    let chartsheet_rels_xml = write_sheet_rels_xml(
      Some("../drawings/drawing\{drawing_id}.xml"),
      [],
      [],
      [],
      [],
      [],
      [],
      [],
    )
    archive.add(
      "xl/chartsheets/_rels/sheet\{sheet_id}.xml.rels",
      @encoding/utf8.encode(chartsheet_rels_xml),
    )
  }
  match workbook.vba_project {
    Some(value) => archive.add("xl/vbaProject.bin", value)
    None => ()
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
    @encoding/utf8.encode(
      write_styles_xml(
        workbook.styles(),
        workbook.conditional_styles(),
        workbook.default_font(),
      ),
    ),
  )
  archive.add("xl/theme/theme1.xml", @encoding/utf8.encode(default_theme_xml))
  archive.add(
    "docProps/core.xml",
    @encoding/utf8.encode(write_core_properties_xml(workbook.core_properties())),
  )
  archive.add(
    "docProps/app.xml",
    @encoding/utf8.encode(write_app_properties_xml(workbook.app_properties())),
  )
  let mut has_custom_props = false
  for prop in workbook.custom_properties() {
    if prop.value is Some(_) {
      has_custom_props = true
      break
    }
  }
  if has_custom_props {
    manifest.add_custom_properties()
    archive.add(
      "docProps/custom.xml",
      @encoding/utf8.encode(
        write_custom_properties_xml(workbook.custom_properties()),
      ),
    )
  }
  archive.add(
    "xl/_rels/workbook.xml.rels",
    @encoding/utf8.encode(manifest.workbook_rels_xml()),
  )
  archive.add(
    "[Content_Types].xml",
    @encoding/utf8.encode(manifest.content_types_xml()),
  )
  match workbook.zip_writer {
    Some(writer) =>
      writer(archive) catch {
        err => raise XlsxError::UnsupportedFeature(msg=err.to_string())
      }
    None =>
      @zip.write(archive) catch {
        err => raise XlsxError::UnsupportedFeature(msg=err.to_string())
      }
  }
}

///|
pub fn write_with_password(
  workbook : Workbook,
  password : String,
) -> Bytes raise XlsxError {
  let raw = write(workbook)
  if password.length() == 0 {
    raw
  } else {
    encrypt_package(raw, password)
  }
}
