///|
test "page margins and layout roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let margins = PageLayoutMarginsOptions::with_values(
    top=1.1,
    bottom=1.2,
    left=0.9,
    right=0.8,
    horizontally=true,
  )
  workbook.set_page_margins("Sheet1", Some(margins))
  let layout = PageLayoutOptions::with_values(
    orientation="landscape",
    adjust_to=120,
    page_order="overThenDown",
  )
  workbook.set_page_layout("Sheet1", Some(layout))
  let bytes = write(workbook)
  let parsed = read(bytes)
  let parsed_margins = parsed.get_page_margins("Sheet1")
  inspect(parsed_margins.top, content="Some(1.1)")
  inspect(parsed_margins.bottom, content="Some(1.2)")
  inspect(parsed_margins.left, content="Some(0.9)")
  inspect(parsed_margins.horizontally, content="Some(true)")
  let parsed_layout = parsed.get_page_layout("Sheet1")
  inspect(
    parsed_layout.orientation,
    content=(
      #|Some("landscape")
    ),
  )
  inspect(parsed_layout.adjust_to, content="Some(120)")
  inspect(
    parsed_layout.page_order,
    content=(
      #|Some("overThenDown")
    ),
  )
}

///|
test "page layout validation" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bad_orientation = PageLayoutOptions::with_values(orientation="sideways")
  let result : Result[Unit, Error] = try? workbook.set_page_layout(
    "Sheet1",
    Some(bad_orientation),
  )
  inspect(result is Err(XlsxError::InvalidPageLayout(_)), content="true")
  let bad_adjust = PageLayoutOptions::with_values(adjust_to=5)
  let result2 : Result[Unit, Error] = try? workbook.set_page_layout(
    "Sheet1",
    Some(bad_adjust),
  )
  inspect(result2 is Err(XlsxError::InvalidPageLayout(_)), content="true")
}

///|
test "header footer roundtrip and limits" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let options = HeaderFooterOptions::with_values(
    different_first=true,
    odd_header="&R&P",
    even_footer="&L&D",
  )
  workbook.set_header_footer("Sheet1", Some(options))
  let bytes = write(workbook)
  let parsed = read(bytes)
  let parsed_opts = match parsed.get_header_footer("Sheet1") {
    Some(value) => value
    None => fail("missing header footer")
  }
  inspect(parsed_opts.different_first, content="true")
  inspect(parsed_opts.odd_header, content="&R&P")
  inspect(parsed_opts.even_footer, content="&L&D")
  let long_text = "a".repeat(256)
  let bad_opts = HeaderFooterOptions::with_values(odd_header=long_text)
  let result : Result[Unit, Error] = try? workbook.set_header_footer(
    "Sheet1",
    Some(bad_opts),
  )
  inspect(result is Err(XlsxError::InvalidHeaderFooter(_)), content="true")
  workbook.set_header_footer("Sheet1", None)
  inspect(workbook.get_header_footer("Sheet1"), content="None")
}

///|
test "sheet protection xor and sha512" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let xor_opts = SheetProtectionOptions::with_values(password="secret")
  workbook.protect_sheet("Sheet1", xor_opts)
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  let protection = match sheet.sheet_protection() {
    Some(value) => value
    None => fail("missing protection")
  }
  inspect(protection.password.length() > 0, content="true")
  let bad_unprotect : Result[Unit, Error] = try? workbook.unprotect_sheet(
    "Sheet1",
    password="bad",
  )
  inspect(
    bad_unprotect is Err(XlsxError::InvalidSheetProtection(_)),
    content="true",
  )
  workbook.unprotect_sheet("Sheet1")
  inspect(sheet.sheet_protection(), content="None")
  let sha_opts = SheetProtectionOptions::with_values(
    algorithm_name="SHA-512",
    password="secret",
    select_locked_cells=true,
  )
  workbook.protect_sheet("Sheet1", sha_opts)
  let sha_protection = match sheet.sheet_protection() {
    Some(value) => value
    None => fail("missing protection")
  }
  inspect(sha_protection.algorithm_name, content="SHA-512")
  inspect(sha_protection.salt_value.length(), content="24")
  inspect(sha_protection.hash_value.length(), content="88")
  inspect(sha_protection.spin_count, content="100000")
  workbook.unprotect_sheet("Sheet1", password="secret")
  inspect(sheet.sheet_protection(), content="None")
}

///|
test "sheet background roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let data = Bytes::from_array([0x89, 0x50, 0x4e, 0x47])
  workbook.set_sheet_background("Sheet1", data, ".png")
  let bytes = write(workbook)
  let parsed = read(bytes)
  let sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  let background = match sheet.sheet_background() {
    Some(value) => value
    None => fail("missing background")
  }
  inspect(background.extension, content="png")
  inspect(background.content_type, content="image/png")
  inspect(background.data.length(), content="4")
}

///|
test "defined names set delete and adjust" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  ignore(workbook.add_sheet("Sheet2"))
  workbook.set_defined_name(DefinedName::new("Amount", "Sheet1!$A$1:$B$2"))
  workbook.set_defined_name(
    DefinedName::new("Scoped", "Sheet1!$C$1", scope="Sheet1"),
  )
  inspect(workbook.get_defined_names().length(), content="2")
  let dup : Result[Unit, Error] = try? workbook.set_defined_name(
    DefinedName::new("Amount", "Sheet1!$A$1"),
  )
  inspect(dup is Err(XlsxError::DefinedNameDuplicate(_)), content="true")
  workbook.insert_rows("Sheet1", 1, 1)
  let mut amount_ref = ""
  for dn in workbook.get_defined_names() {
    if dn.name == "Amount" {
      amount_ref = dn.refers_to
    }
  }
  inspect(amount_ref, content="Sheet1!$A$2:$B$3")
  workbook.set_sheet_name("Sheet1", "Main")
  let mut scoped_scope = ""
  let mut scoped_ref = ""
  for dn in workbook.get_defined_names() {
    if dn.name == "Scoped" {
      scoped_scope = dn.scope
      scoped_ref = dn.refers_to
    }
  }
  inspect(scoped_scope, content="Main")
  inspect(scoped_ref, content="Main!$C$2")
  workbook.delete_defined_name(
    DefinedName::new("Scoped", "Main!$C$1", scope="Main"),
  )
  inspect(workbook.get_defined_names().length(), content="1")
  let missing : Result[Unit, Error] = try? workbook.delete_defined_name(
    DefinedName::new("Missing", "Sheet1!$A$1"),
  )
  inspect(missing is Err(XlsxError::DefinedNameScope(_)), content="true")
}

///|
test "page break insert remove and shift" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  workbook.insert_page_break("Sheet1", "A1")
  workbook.insert_page_break("Sheet1", "B2")
  inspect(sheet.row_breaks().length(), content="1")
  inspect(sheet.col_breaks().length(), content="1")
  if sheet.row_breaks().length() > 0 {
    inspect(sheet.row_breaks()[0].id, content="1")
  }
  workbook.insert_rows("Sheet1", 1, 1)
  if sheet.row_breaks().length() > 0 {
    inspect(sheet.row_breaks()[0].id, content="2")
  }
  workbook.remove_page_break("Sheet1", "B3")
  inspect(sheet.row_breaks().length(), content="0")
  inspect(sheet.col_breaks().length(), content="0")
}

///|
test "sheet props roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let props = SheetPropsOptions::with_values(
    code_name="SheetCode",
    enable_format_conditions_calculation=false,
    published=false,
    auto_page_breaks=false,
    fit_to_page=true,
    tab_color_rgb="FF0000",
    tab_color_theme=3,
    tab_color_tint=0.25,
    outline_summary_below=false,
    outline_summary_right=false,
    base_col_width=9,
    default_col_width=12.5,
    default_row_height=18.0,
    custom_height=true,
    zero_height=true,
    thick_top=true,
    thick_bottom=false,
  )
  workbook.set_sheet_props("Sheet1", Some(props))
  let bytes = write(workbook)
  let parsed = read(bytes)
  let parsed_props = parsed.get_sheet_props("Sheet1")
  inspect(parsed_props.code_name, content="Some(\"SheetCode\")")
  inspect(
    parsed_props.enable_format_conditions_calculation,
    content="Some(false)",
  )
  inspect(parsed_props.published, content="Some(false)")
  inspect(parsed_props.auto_page_breaks, content="Some(false)")
  inspect(parsed_props.fit_to_page, content="Some(true)")
  inspect(parsed_props.tab_color_rgb, content="Some(\"FF0000\")")
  inspect(parsed_props.tab_color_theme, content="Some(3)")
  inspect(parsed_props.tab_color_tint, content="Some(0.25)")
  inspect(parsed_props.outline_summary_below, content="Some(false)")
  inspect(parsed_props.outline_summary_right, content="Some(false)")
  inspect(parsed_props.base_col_width, content="Some(9)")
  inspect(parsed_props.default_col_width, content="Some(12.5)")
  inspect(parsed_props.default_row_height, content="Some(18)")
  inspect(parsed_props.custom_height, content="Some(true)")
  inspect(parsed_props.zero_height, content="Some(true)")
  inspect(parsed_props.thick_top, content="Some(true)")
  inspect(parsed_props.thick_bottom, content="Some(false)")
}

///|
test "sheet props defaults on set" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_sheet_props(
    "Sheet1",
    Some(SheetPropsOptions::with_values(code_name="OnlyCode")),
  )
  let props = workbook.get_sheet_props("Sheet1")
  inspect(props.code_name, content="Some(\"OnlyCode\")")
  inspect(props.default_row_height, content="Some(15)")
  inspect(props.base_col_width, content="Some(8)")
}
