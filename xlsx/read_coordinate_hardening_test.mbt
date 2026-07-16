///|
fn coordinate_hardening_replace_part(
  bytes : BytesView,
  part_name : String,
  old : StringView,
  replacement : StringView,
) -> Bytes raise {
  let source = @zip.read(bytes)
  let updated = @zip.Archive::new()
  let mut replaced = false
  for entry in source.entries() {
    if entry.name() == part_name {
      let xml = @encoding/utf8.decode(entry.data()) catch {
        _ => fail("\{part_name} is not UTF-8")
      }
      if !xml.contains(old) {
        fail("\{part_name} does not contain \{old.to_owned()}")
      }
      updated.add(
        entry.name(),
        @encoding/utf8.encode(xml.replace_all(old~, new=replacement)),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
      replaced = true
    } else {
      updated.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  if !replaced {
    fail("missing package part \{part_name}")
  }
  @zip.write(updated)
}

///|
fn coordinate_hardening_base_bytes() -> Bytes raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  @xlsx.write(workbook)
}

///|
fn coordinate_hardening_append_sheet_xml(
  bytes : BytesView,
  fragment : StringView,
) -> Bytes raise {
  coordinate_hardening_insert_sheet_xml(bytes, "</worksheet>", fragment)
}

///|
fn coordinate_hardening_insert_sheet_xml(
  bytes : BytesView,
  before : StringView,
  fragment : StringView,
) -> Bytes raise {
  coordinate_hardening_replace_part(
    bytes,
    "xl/worksheets/sheet1.xml",
    before,
    "\{fragment.to_owned()}\n\{before.to_owned()}",
  )
}

///|
fn coordinate_hardening_expect_invalid_xml(
  label : StringView,
  result : Result[@xlsx.Workbook, Error],
) -> Unit raise {
  match result {
    Err(@xlsx.XlsxError::InvalidXml(_)) => ()
    Err(error) =>
      fail("\{label.to_owned()}: expected InvalidXml, got \{repr(error)}")
    Ok(_) => fail("\{label.to_owned()}: expected InvalidXml")
  }
}

///|
fn coordinate_hardening_assert_invalid_xml(
  label : StringView,
  bytes : BytesView,
) -> Unit raise {
  let result : Result[@xlsx.Workbook, Error] = Ok(@xlsx.read(bytes)) catch {
    error => Err(error)
  }
  coordinate_hardening_expect_invalid_xml(label, result)
}

///|
fn coordinate_hardening_bounded_archive(
  bytes : BytesView,
) -> @zip.Archive raise {
  @zip.read_limited(
    bytes,
    max_package_bytes=128 * 1024 * 1024,
    max_entries=8192,
    max_entry_uncompressed_bytes=64 * 1024 * 1024,
    max_total_uncompressed_bytes=256 * 1024 * 1024,
    max_total_preserved_source_bytes=128 * 1024 * 1024 + 65_535,
  )
}

///|
test "read rejects every out-of-grid worksheet coordinate ingress" {
  let base = coordinate_hardening_base_bytes()
  let huge_row = "99999999999999999999999999999999999999999999999999"
  let huge_col = "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  let x14_data_validation = "<extLst><ext uri=\"{2F02F2B1-0A8B-4F0A-8C2A-25A9A1B30E6B}\" xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" xmlns:xm=\"http://schemas.microsoft.com/office/excel/2006/main\"><x14:dataValidations><x14:dataValidation type=\"list\"><x14:formula1><xm:f>1</xm:f></x14:formula1><xm:sqref>XFE1</xm:sqref></x14:dataValidation></x14:dataValidations></ext></extLst>"
  let x14_conditional_format = "<extLst><ext uri=\"{78C0D931-6437-407d-A8EE-F0AAD7539E65}\" xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" xmlns:xm=\"http://schemas.microsoft.com/office/excel/2006/main\"><x14:conditionalFormattings><x14:conditionalFormatting><xm:sqref>XFE1</xm:sqref><x14:cfRule type=\"dataBar\" priority=\"1\"><x14:dataBar/></x14:cfRule></x14:conditionalFormatting></x14:conditionalFormattings></ext></extLst>"
  let sparkline = "<extLst><ext uri=\"{05C60535-1F16-4fd2-B633-F4F36F0B64E0}\" xmlns:x14=\"http://schemas.microsoft.com/office/spreadsheetml/2009/9/main\" xmlns:xm=\"http://schemas.microsoft.com/office/excel/2006/main\"><x14:sparklineGroups><x14:sparklineGroup><x14:sparklines><x14:sparkline><xm:f>A1:A2</xm:f><xm:sqref>XFE1</xm:sqref></x14:sparkline></x14:sparklines></x14:sparklineGroup></x14:sparklineGroups></ext></extLst>"
  let in_sheet_data = "  </sheetData>"
  let before_sheet_data = "  <sheetData>"
  let at_worksheet_end = "</worksheet>"
  let cases : Array[(String, String, String)] = [
    ("cell column max+1", in_sheet_data, "<row r=\"1\"><c r=\"XFE1\"/></row>"),
    ("cell row max+1", in_sheet_data, "<row r=\"1\"><c r=\"A1048577\"/></row>"),
    (
      "cell huge row",
      in_sheet_data,
      "<row r=\"1\"><c r=\"A\{huge_row}\"/></row>",
    ),
    (
      "cell huge column",
      in_sheet_data,
      "<row r=\"1\"><c r=\"\{huge_col}1\"/></row>",
    ),
    ("row dimension max+1", in_sheet_data, "<row r=\"1048577\" hidden=\"1\"/>"),
    (
      "row dimension huge",
      in_sheet_data,
      "<row r=\"\{huge_row}\" hidden=\"1\"/>",
    ),
    (
      "column dimension max+1", before_sheet_data, "<cols><col min=\"16385\" max=\"16385\" hidden=\"1\"/></cols>",
    ),
    (
      "column dimension huge",
      before_sheet_data,
      "<cols><col min=\"1\" max=\"\{huge_row}\" hidden=\"1\"/></cols>",
    ),
    (
      "row break id max+1", at_worksheet_end, "<rowBreaks><brk id=\"1048576\" min=\"0\" max=\"16383\" man=\"1\"/></rowBreaks>",
    ),
    (
      "row break span max+1", at_worksheet_end, "<rowBreaks><brk id=\"0\" min=\"0\" max=\"16384\" man=\"1\"/></rowBreaks>",
    ),
    (
      "row break reversed span", at_worksheet_end, "<rowBreaks><brk id=\"0\" min=\"2\" max=\"1\" man=\"1\"/></rowBreaks>",
    ),
    (
      "column break id max+1", at_worksheet_end, "<colBreaks><brk id=\"16384\" min=\"0\" max=\"1048575\" man=\"1\"/></colBreaks>",
    ),
    (
      "column break span max+1", at_worksheet_end, "<colBreaks><brk id=\"0\" min=\"0\" max=\"1048576\" man=\"1\"/></colBreaks>",
    ),
    (
      "column break reversed span", at_worksheet_end, "<colBreaks><brk id=\"0\" min=\"2\" max=\"1\" man=\"1\"/></colBreaks>",
    ),
    (
      "legacy data validation sqref", at_worksheet_end, "<dataValidations count=\"1\"><dataValidation type=\"whole\" sqref=\"XFE1\"/></dataValidations>",
    ),
    (
      "legacy conditional formatting sqref", at_worksheet_end, "<conditionalFormatting sqref=\"A1048577\"><cfRule type=\"cellIs\" priority=\"1\"><formula>1</formula></cfRule></conditionalFormatting>",
    ),
    ("x14 data validation sqref", at_worksheet_end, x14_data_validation),
    (
      "x14 conditional formatting and data bar sqref", at_worksheet_end, x14_conditional_format,
    ),
    (
      "ignored errors sqref", at_worksheet_end, "<ignoredErrors><ignoredError sqref=\"XFE1\" evalError=\"1\"/></ignoredErrors>",
    ),
    (
      "sheet view topLeftCell", before_sheet_data, "<sheetViews><sheetView workbookViewId=\"0\" topLeftCell=\"XFE1\"/></sheetViews>",
    ),
    (
      "pane topLeftCell", before_sheet_data, "<sheetViews><sheetView workbookViewId=\"0\"><pane topLeftCell=\"A1048577\"/></sheetView></sheetViews>",
    ),
    (
      "selection activeCell", before_sheet_data, "<sheetViews><sheetView workbookViewId=\"0\"><selection activeCell=\"XFE1\" sqref=\"A1\"/></sheetView></sheetViews>",
    ),
    (
      "selection sqref", before_sheet_data, "<sheetViews><sheetView workbookViewId=\"0\"><selection activeCell=\"A1\" sqref=\"A1 A1048577\"/></sheetView></sheetViews>",
    ),
    ("dimension ref", before_sheet_data, "<dimension ref=\"A1:XFE1048576\"/>"),
    (
      "formula ref", in_sheet_data, "<row r=\"1\"><c r=\"A1\"><f t=\"array\" ref=\"XFE1\">1</f><v>1</v></c></row>",
    ),
    (
      "hyperlink ref", at_worksheet_end, "<hyperlinks><hyperlink ref=\"A1048577\" location=\"Sheet1!A1\"/></hyperlinks>",
    ),
    (
      "merge ref through shared parser", at_worksheet_end, "<mergeCells count=\"1\"><mergeCell ref=\"A1:XFE1\"/></mergeCells>",
    ),
    (
      "filter ref through shared parser", at_worksheet_end, "<autoFilter ref=\"A1:A1048577\"/>",
    ),
    (
      "filter column negative", at_worksheet_end, "<autoFilter ref=\"A1:B2\"><filterColumn colId=\"-1\"/></autoFilter>",
    ),
    (
      "filter column outside filter range", at_worksheet_end, "<autoFilter ref=\"A1:B2\"><filterColumn colId=\"2\"/></autoFilter>",
    ),
    (
      "filter column huge",
      at_worksheet_end,
      "<autoFilter ref=\"A1:B2\"><filterColumn colId=\"\{huge_row}\"/></autoFilter>",
    ),
    ("sparkline ref through shared parser", at_worksheet_end, sparkline),
  ]
  for case in cases {
    let (label, before, fragment) = case
    coordinate_hardening_assert_invalid_xml(
      label,
      coordinate_hardening_insert_sheet_xml(base, before, fragment),
    )
  }
}

///|
test "all public read entrypoints classify coordinate failures as InvalidXml" {
  let invalid = coordinate_hardening_insert_sheet_xml(
    coordinate_hardening_base_bytes(),
    "  <sheetData>",
    "<dimension ref=\"XFE1\"/>",
  )
  coordinate_hardening_assert_invalid_xml("byte read", invalid)
  let bounded : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read_bounded_archive(coordinate_hardening_bounded_archive(invalid)),
  ) catch {
    error => Err(error)
  }
  coordinate_hardening_expect_invalid_xml("bounded archive read", bounded)
  let options = @xlsx.Options::with_values(password="coordinate-hardening")
  let encrypted = @xlsx.encrypt(invalid, options~)
  let password : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read_with_password(encrypted, "coordinate-hardening"),
  ) catch {
    error => Err(error)
  }
  coordinate_hardening_expect_invalid_xml("password read", password)
}

///|
test "table refs use the bounded shared parser on read" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "Name")
  workbook.set_cell("Sheet1", "B1", "Value")
  workbook.set_cell("Sheet1", "A2", "row")
  workbook.set_cell("Sheet1", "B2", "1")
  ignore(workbook.add_table("Sheet1", @xlsx.TableOptions::new("A1:B2")))
  let invalid = coordinate_hardening_replace_part(
    @xlsx.write(workbook),
    "xl/tables/table1.xml",
    "ref=\"A1:B2\"",
    "ref=\"A1:XFE2\"",
  )
  coordinate_hardening_assert_invalid_xml("table ref", invalid)
}

///|
test "maximum worksheet coordinates survive two read-write cycles" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_formula_opts(
    "XFD1048576",
    "1",
    opts=@xlsx.FormulaOpts::array("XFD1048576:XFD1048576"),
    value="1",
  )
  workbook.set_row_visible("Sheet1", 1048576, false)
  workbook.set_col_visible("Sheet1", 16384, false)
  workbook.insert_page_break("Sheet1", "XFD1048576")
  workbook.set_sheet_dimension("Sheet1", "A1:XFD1048576")
  workbook.add_ignored_errors("Sheet1", "XFD1048576", NumberStoredAsText)
  let validation = @xlsx.DataValidation::new(true)
  validation.set_sqref("XFD1048576")
  validation.set_drop_list(["valid"])
  workbook.add_data_validation("Sheet1", validation)
  let data_bar = @xlsx.ConditionalFormatOptions::new("data_bar")
  data_bar.set_min_type("min")
  data_bar.set_max_type("max")
  data_bar.set_bar_color("#638EC6")
  workbook.set_conditional_format("Sheet1", "XFD1048576", [data_bar])
  workbook.set_sheet_view(
    "Sheet1",
    0,
    @xlsx.SheetViewOptions::with_values(top_left_cell="XFD1048576"),
  )
  workbook.set_panes(
    "Sheet1",
    @xlsx.Panes::with_values(
      freeze=true,
      y_split=1,
      top_left_cell="XFD1048576",
      active_pane="bottomLeft",
      selection=[
        @xlsx.Selection::with_values(
          sqref="XFD1048576",
          active_cell="XFD1048576",
          pane="bottomLeft",
        ),
      ],
    ),
  )
  workbook.set_cell_hyperlink(
    "Sheet1",
    "XFD1048576",
    "https://example.com/max",
    External,
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let parsed_twice = @xlsx.read(@xlsx.write(parsed))
  debug_inspect(
    parsed_twice.get_cell_formula("Sheet1", "XFD1048576"),
    content="Some(\"1\")",
  )
  inspect(parsed_twice.get_row_visible("Sheet1", 1048576), content="false")
  inspect(parsed_twice.get_col_visible("Sheet1", 16384), content="false")
  inspect(parsed_twice.get_sheet_dimension("Sheet1"), content="A1:XFD1048576")
  let parsed_sheet = match parsed_twice.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  assert_eq(parsed_sheet.row_breaks().length(), 1)
  assert_eq(parsed_sheet.row_breaks()[0].id, 1048575)
  assert_eq(parsed_sheet.col_breaks().length(), 1)
  assert_eq(parsed_sheet.col_breaks()[0].id, 16383)
  assert_eq(parsed_sheet.ignored_errors().length(), 1)
  assert_eq(parsed_sheet.ignored_errors()[0].sqref, "XFD1048576")
  assert_eq(parsed_twice.get_data_validations("Sheet1")[0].sqref, "XFD1048576")
  assert_true(
    parsed_twice.get_conditional_formats("Sheet1").contains("XFD1048576"),
  )
  let view = parsed_twice.get_sheet_view("Sheet1", 0)
  assert_eq(view.top_left_cell, Some("XFD1048576"))
  let panes = parsed_twice.get_panes("Sheet1")
  assert_eq(panes.top_left_cell, "XFD1048576")
  assert_eq(panes.selection[0].sqref, "XFD1048576")
  assert_eq(panes.selection[0].active_cell, "XFD1048576")
  assert_true(
    parsed_twice.get_cell_hyperlink("Sheet1", "XFD1048576") is Some(_),
  )
}

///|
test "read normalizes only XML whitespace in sqref fields" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "A")
  sheet.set_cell("B1", "B")
  let validation = @xlsx.DataValidation::new(true)
  validation.set_sqref("A1 B1")
  validation.set_drop_list(["valid"])
  sheet.add_data_validation(validation)
  let format = @xlsx.ConditionalFormatOptions::new("cell")
  format.set_criteria(">")
  format.set_value("0")
  sheet.set_conditional_format("A1 B1", [format])
  sheet.set_panes(
    @xlsx.Panes::with_values(selection=[
      @xlsx.Selection::with_values(sqref="A1 B1", active_cell="A1"),
    ]),
  )
  let whitespace = "mixed='quote' xmlns:x=\"urn:coordinate-hardening\" x:sqref='keep' sqref = ' \tA1\r\nB1 '"
  let patched = coordinate_hardening_replace_part(
    @xlsx.write(workbook),
    "xl/worksheets/sheet1.xml",
    "sqref=\"A1 B1\"",
    whitespace,
  )
  let parsed = @xlsx.read(patched)
  let parsed_sheet = match parsed.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  let normalized_attr = "x:sqref='keep' sqref = 'A1 B1'"
  assert_true(parsed_sheet.data_validations()[0].contains(normalized_attr))
  assert_true(parsed_sheet.conditional_formats()[0].contains(normalized_attr))
  assert_eq(parsed.get_panes("Sheet1").selection[0].sqref, "A1 B1")
  assert_true(parsed.get_conditional_formats("Sheet1").contains("A1 B1"))
  parsed.duplicate_row_to("Sheet1", 1, 2)
  parsed.delete_data_validation("Sheet1", sqrefs=["A1"])
  parsed.unset_conditional_format("Sheet1", "A1")
  ignore(@xlsx.read(@xlsx.write(parsed)))

  let preserved = coordinate_hardening_append_sheet_xml(
    coordinate_hardening_base_bytes(),
    "<dataValidations count=\"1\"><dataValidation type=\"whole\" sqref=\"$B$2:$A$1\t$A$1:$B$2\r\nA1 A1\"/></dataValidations><conditionalFormatting sqref=\"$B$2:$A$1\t$A$1:$B$2\r\nA1 A1\"><cfRule type=\"cellIs\" priority=\"1\"><formula>1</formula></cfRule></conditionalFormatting>",
  )
  let preserved_sheet = match @xlsx.read(preserved).sheet("Sheet1") {
    Some(value) => value
    None => fail("missing preserved Sheet1")
  }
  let expected = "sqref=\"$B$2:$A$1 $A$1:$B$2 A1 A1\""
  assert_true(preserved_sheet.data_validations()[0].contains(expected))
  assert_true(preserved_sheet.conditional_formats()[0].contains(expected))
}
