///|
test "hyperlink roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://example.com",
    HyperlinkType::External,
    display="Example",
    tooltip="Tip",
  )
  workbook.set_cell_hyperlink(
    "Sheet1",
    "B2",
    "Sheet1!C3",
    HyperlinkType::Location,
  )
  let parsed = read(write(workbook))
  inspect(
    parsed.get_cell_hyperlink("Sheet1", "A1"),
    content=(
      #|Some({reference: "A1", target: "https://example.com", link_type: External, display: Some("Example"), tooltip: Some("Tip")})
    ),
  )
  inspect(
    parsed.get_cell_hyperlink("Sheet1", "B2"),
    content=(
      #|Some({reference: "B2", target: "Sheet1!C3", link_type: Location, display: None, tooltip: None})
    ),
  )
}

///|
test "hyperlink updates on insert" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "B2",
    "https://example.com",
    HyperlinkType::External,
  )
  workbook.insert_rows("Sheet1", 1, 1)
  inspect(workbook.get_cell_hyperlink("Sheet1", "B2"), content="None")
  inspect(
    workbook.get_cell_hyperlink("Sheet1", "B3"),
    content=(
      #|Some({reference: "B3", target: "https://example.com", link_type: External, display: None, tooltip: None})
    ),
  )
  workbook.insert_cols("Sheet1", 1, 1)
  inspect(workbook.get_cell_hyperlink("Sheet1", "B3"), content="None")
  inspect(
    workbook.get_cell_hyperlink("Sheet1", "C3"),
    content=(
      #|Some({reference: "C3", target: "https://example.com", link_type: External, display: None, tooltip: None})
    ),
  )
}

///|
test "hyperlink alias methods" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyper_link(
    "Sheet1",
    "C3",
    "https://example.com",
    HyperlinkType::External,
  )
  inspect(
    workbook.get_cell_hyper_link("Sheet1", "C3"),
    content=(
      #|Some({reference: "C3", target: "https://example.com", link_type: External, display: None, tooltip: None})
    ),
  )
}

///|
test "hyperlink opts helper" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = HyperlinkOpts::with_values(tooltip="Tip")
  workbook.set_cell_hyperlink_opts(
    "Sheet1",
    "A1",
    "https://example.com",
    HyperlinkType::External,
    opts~,
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  inspect(sheet_xml.contains("tooltip=\"Tip\""), content="true")
  inspect(sheet_xml.contains("display="), content="false")
  let parsed = read(bytes)
  inspect(
    parsed.get_cell_hyperlink("Sheet1", "A1"),
    content=(
      #|Some({reference: "A1", target: "https://example.com", link_type: External, display: None, tooltip: Some("Tip")})
    ),
  )
}

///|
test "hyperlink update existing reference" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://github.com",
    HyperlinkType::External,
  )
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://github.com/xuri/excelize",
    HyperlinkType::External,
  )
  inspect(
    workbook.get_cell_hyperlink("Sheet1", "A1"),
    content=(
      #|Some({reference: "A1", target: "https://github.com/xuri/excelize", link_type: External, display: None, tooltip: None})
    ),
  )
}

///|
test "hyperlink validates cell reference" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let set_result : Result[Unit, Error] = try? workbook.set_cell_hyperlink(
    "Sheet1",
    "",
    "https://example.com",
    HyperlinkType::External,
  )
  inspect(set_result is Err(XlsxError::InvalidCellRef(_)), content="true")
  let get_result : Result[Hyperlink?, Error] = try? workbook.get_cell_hyperlink(
    "Sheet1", "",
  )
  inspect(get_result is Err(XlsxError::InvalidCellRef(_)), content="true")
  let remove_result : Result[Unit, Error] = try? workbook.remove_cell_hyperlink(
    "Sheet1", "",
  )
  inspect(remove_result is Err(XlsxError::InvalidCellRef(_)), content="true")
}

///|
test "hyperlink remove clears range reference" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://github.com/xuri/excelize",
    HyperlinkType::External,
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  let updated_sheet = sheet_xml.replace_all(
    old="<hyperlink ref=\"A1\"",
    new="<hyperlink ref=\"A1:D4\"",
  )
  let updated_archive = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name != "xl/worksheets/sheet1.xml" {
      updated_archive.add(
        entry.name,
        entry.data,
        compression=entry.compression,
        data_descriptor=entry.data_descriptor,
      )
    }
  }
  updated_archive.add(
    "xl/worksheets/sheet1.xml",
    @encoding/utf8.encode(updated_sheet),
  )
  let updated_bytes = @zip.write(updated_archive) catch {
    err => fail("zip write failed: \{err}")
  }
  let parsed = read(updated_bytes)
  inspect(
    parsed.get_cell_hyperlink("Sheet1", "B2"),
    content=(
      #|Some({reference: "A1:D4", target: "https://github.com/xuri/excelize", link_type: External, display: None, tooltip: None})
    ),
  )
  parsed.remove_cell_hyperlink("Sheet1", "B2")
  inspect(parsed.get_cell_hyperlink("Sheet1", "B2"), content="None")
  inspect(parsed.get_cell_hyperlink("Sheet1", "A1"), content="None")
}

///|
test "hyperlink invalid ref tolerated on read" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://github.com/xuri/excelize",
    HyperlinkType::External,
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let sheet_xml = match archive.get("xl/worksheets/sheet1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("sheet1.xml utf8 decode failed")
      }
    None => fail("missing sheet1.xml")
  }
  let updated_sheet = sheet_xml.replace_all(
    old="<hyperlink ref=\"A1\"",
    new="<hyperlink ref=\"A:A\"",
  )
  let updated_archive = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name != "xl/worksheets/sheet1.xml" {
      updated_archive.add(
        entry.name,
        entry.data,
        compression=entry.compression,
        data_descriptor=entry.data_descriptor,
      )
    }
  }
  updated_archive.add(
    "xl/worksheets/sheet1.xml",
    @encoding/utf8.encode(updated_sheet),
  )
  let updated_bytes = @zip.write(updated_archive) catch {
    err => fail("zip write failed: \{err}")
  }
  let parsed = read(updated_bytes)
  let get_result : Result[Hyperlink?, Error] = try? parsed.get_cell_hyperlink(
    "Sheet1", "A1",
  )
  inspect(get_result is Err(XlsxError::InvalidCellRef(_)), content="true")
  let remove_result : Result[Unit, Error] = try? parsed.set_cell_hyperlink(
    "Sheet1",
    "B2",
    "",
    HyperlinkType::Unset,
  )
  inspect(remove_result is Err(XlsxError::InvalidCellRef(_)), content="true")
}
