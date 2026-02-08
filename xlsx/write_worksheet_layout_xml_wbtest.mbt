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
  let bad : Result[String, Error] = try? write_auto_filter_xml(out_of_range)
  inspect(bad is Err(XlsxError::InvalidAutoFilter(_)), content="true")
}
