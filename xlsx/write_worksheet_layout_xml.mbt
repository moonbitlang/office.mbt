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

///|
test "write worksheet layout wb: margins print options and page setup branches" {
  let print_opts = PageLayoutMarginsOptions::with_values(
    horizontally=false,
    vertically=false,
  )
  let print_xml = write_print_options_xml(print_opts)
  inspect(print_xml is Some(_), content="true")
  match print_xml {
    Some(xml) => {
      inspect(xml.contains("horizontalCentered=\"0\""), content="true")
      inspect(xml.contains("verticalCentered=\"0\""), content="true")
    }
    None => fail("expected printOptions xml")
  }
  let vertical_only = PageLayoutMarginsOptions::with_values(vertically=true)
  let vertical_xml = write_print_options_xml(vertical_only)
  inspect(vertical_xml is Some(_), content="true")
  match vertical_xml {
    Some(xml) => {
      inspect(xml.contains("verticalCentered=\"1\""), content="true")
      inspect(xml.contains("horizontalCentered="), content="false")
    }
    None => fail("expected vertical-only printOptions xml")
  }

  let margin_xml = write_page_margins_xml(PageLayoutMarginsOptions::new())
  inspect(margin_xml.contains("left=\"0.7\""), content="true")
  inspect(margin_xml.contains("right=\"0.7\""), content="true")
  inspect(margin_xml.contains("top=\"0.75\""), content="true")
  inspect(margin_xml.contains("bottom=\"0.75\""), content="true")
  inspect(margin_xml.contains("header=\"0.3\""), content="true")
  inspect(margin_xml.contains("footer=\"0.3\""), content="true")

  let setup = PageLayoutOptions::with_values(
    size=9,
    first_page_number=2,
    black_and_white=false,
  )
  let setup_xml = write_page_setup_xml(setup)
  inspect(setup_xml.contains("blackAndWhite=\"0\""), content="true")
  inspect(setup_xml.contains("paperSize=\"9\""), content="true")
  inspect(
    setup_xml.contains("firstPageNumber=\"2\" useFirstPageNumber=\"1\""),
    content="true",
  )
  inspect(setup_xml.contains(" orientation=\""), content="false")
}

///|
test "write worksheet layout wb: header footer option branches" {
  let header_footer = HeaderFooterOptions::with_values(
    align_with_margins=true,
    different_odd_even=true,
    scale_with_doc=false,
    odd_header="odd-h",
    odd_footer="odd-f",
    even_header="even-h",
    even_footer="even-f",
    first_header="first-h",
    first_footer="first-f",
  )
  let xml = write_header_footer_xml(header_footer)
  inspect(xml.contains("differentOddEven=\"1\""), content="true")
  inspect(xml.contains("scaleWithDoc=\"0\""), content="true")
  inspect(xml.contains("alignWithMargins=\"1\""), content="true")
  inspect(xml.contains("<evenHeader>even-h</evenHeader>"), content="true")
}

///|
test "write worksheet layout wb: sheet protection and page breaks branches" {
  let protection : SheetProtection = {
    algorithm_name: "SHA-512",
    password: "ABCD",
    hash_value: "HASHVALUE",
    salt_value: "SALTVALUE",
    spin_count: 100000,
    sheet: true,
    objects: true,
    scenarios: true,
    format_cells: false,
    format_columns: false,
    format_rows: false,
    insert_columns: false,
    insert_rows: false,
    insert_hyperlinks: false,
    delete_columns: false,
    delete_rows: false,
    select_locked_cells: true,
    sort: true,
    auto_filter: true,
    pivot_tables: false,
    select_unlocked_cells: false,
  }
  let protection_xml = write_sheet_protection_xml(protection)
  inspect(protection_xml.contains("algorithmName=\"SHA-512\""), content="true")
  inspect(protection_xml.contains("hashValue=\"HASHVALUE\""), content="true")
  inspect(protection_xml.contains("saltValue=\"SALTVALUE\""), content="true")
  inspect(protection_xml.contains("spinCount=\"100000\""), content="true")
  inspect(protection_xml.contains("autoFilter=\"1\""), content="true")

  let breaks : Array[PageBreak] = [{ id: 7, min: 1, max: 10, manual: true }]
  let breaks_xml = write_page_breaks_xml("rowBreaks", breaks)
  inspect(breaks_xml is Some(_), content="true")
  match breaks_xml {
    Some(xml) => inspect(xml.contains("min=\"1\""), content="true")
    None => fail("expected page breaks xml")
  }
}

///|
test "write worksheet layout wb: auto-filter custom and invalid-column branches" {
  let custom_filter : AutoFilter = {
    range_ref: "A1:C10",
    columns: [
      {
        col: 2,
        filters: None,
        custom_filters: Some({
          and_filter: true,
          filters: [
            { operator: "greaterThan", value: "1" },
            { operator: "lessThan", value: "9" },
          ],
        }),
      },
    ],
  }
  let custom_xml = write_auto_filter_xml(custom_filter)
  inspect(custom_xml.contains("<customFilters and=\"1\">"), content="true")

  let out_of_range : AutoFilter = {
    range_ref: "A1:B2",
    columns: [{ col: 3, filters: None, custom_filters: None }],
  }
  let bad : Result[String, Error] = Ok(write_auto_filter_xml(out_of_range)) catch {
    e => Err(e)
  }
  inspect(bad is Err(XlsxError::InvalidAutoFilter(_)), content="true")
}
