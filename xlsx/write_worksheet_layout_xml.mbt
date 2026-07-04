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
    "  <\{tag_name.to_owned()} count=\"\{breaks.length()}\" manualBreakCount=\"\{manual_count}\">\n",
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
  sb.write_view("  </\{tag_name.to_owned()}>\n")
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
      raise InvalidAutoFilter(msg="auto filter column out of range")
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
