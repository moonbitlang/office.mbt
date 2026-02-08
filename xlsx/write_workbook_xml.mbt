///|
fn write_workbook_xml(
  workbook : Workbook,
  chartsheet_rel_start : Int,
  pivot_cache_rel_entries : ArrayView[(Int, String)],
  slicer_cache_rel_ids_x14 : ArrayView[String],
  slicer_cache_rel_ids_x15 : ArrayView[String],
) -> String {
  fn write_pivot_caches_xml(
    pivot_cache_rel_entries : ArrayView[(Int, String)],
  ) -> String? {
    if pivot_cache_rel_entries.length() == 0 {
      return None
    }
    let sb = StringBuilder::new()
    sb.write_view("  <pivotCaches>\n")
    for entry in pivot_cache_rel_entries {
      let (cache_id, rel_id) = entry
      sb.write_view("    <pivotCache cacheId=\"\{cache_id}\" r:id=\"")
      sb.write_view(escape_xml_attr(rel_id))
      sb.write_view("\"/>\n")
    }
    sb.write_view("  </pivotCaches>\n")
    Some(sb.to_string())
  }

  fn write_workbook_ext_lst_xml(
    slicer_cache_rel_ids_x14 : ArrayView[String],
    slicer_cache_rel_ids_x15 : ArrayView[String],
  ) -> String? {
    if slicer_cache_rel_ids_x14.length() == 0 &&
      slicer_cache_rel_ids_x15.length() == 0 {
      return None
    }
    let sb = StringBuilder::new()
    sb.write_view("  <extLst>\n")
    if slicer_cache_rel_ids_x14.length() > 0 {
      sb.write_view(
        "    <ext uri=\"{BBE1A952-AA13-448e-AADC-164F8A28A991}\">\n",
      )
      sb.write_view(
        "      <x14:slicerCaches xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\">\n",
      )
      for id in slicer_cache_rel_ids_x14 {
        sb.write_view("        <x14:slicerCache r:id=\"")
        sb.write_view(escape_xml_attr(id))
        sb.write_view("\"/>\n")
      }
      sb.write_view("      </x14:slicerCaches>\n")
      sb.write_view("    </ext>\n")
    }
    if slicer_cache_rel_ids_x15.length() > 0 {
      sb.write_view(
        "    <ext uri=\"{46BE6895-7355-4a93-B00E-2C351335B9C9}\">\n",
      )
      sb.write_view(
        "      <x15:slicerCaches xmlns:x15=\"http://schemas.microsoft.com/office/spreadsheetml/2010/11/main\" xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\">\n",
      )
      for id in slicer_cache_rel_ids_x15 {
        sb.write_view("        <x14:slicerCache r:id=\"")
        sb.write_view(escape_xml_attr(id))
        sb.write_view("\"/>\n")
      }
      sb.write_view("      </x15:slicerCaches>\n")
      sb.write_view("    </ext>\n")
    }
    sb.write_view("  </extLst>\n")
    Some(sb.to_string())
  }

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
      Worksheet(idx) => idx + 1
      ChartSheet(idx) => worksheet_count + idx + 1
    }
    let rel_id = match entry {
      Worksheet(idx) => idx + 1
      ChartSheet(idx) => chartsheet_rel_start + idx
    }
    sb.write_view("    <sheet name=\"")
    sb.write_view(escape_xml_attr(workbook.sheet_entry_name(entry)))
    sb.write_view("\" sheetId=\"")
    sb.write_view("\{sheet_id}\"")
    sb.write_view(" r:id=\"rId\{rel_id}\"")
    match workbook.sheet_entry_state(entry) {
      Visible => ()
      Hidden => sb.write_view(" state=\"hidden\"")
      VeryHidden => sb.write_view(" state=\"veryHidden\"")
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
  match write_pivot_caches_xml(pivot_cache_rel_entries) {
    Some(value) => sb.write_view(value)
    None => ()
  }
  match
    write_workbook_ext_lst_xml(
      slicer_cache_rel_ids_x14, slicer_cache_rel_ids_x15,
    ) {
    Some(xml) => sb.write_view(xml)
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
