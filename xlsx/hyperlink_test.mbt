///|
test "hyperlink roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://example.com",
    External,
    display="Example",
    tooltip="Tip",
  )
  workbook.set_cell_hyperlink("Sheet1", "B2", "Sheet1!C3", Location)
  let parsed = read(write(workbook))
  debug_inspect(
    parsed.get_cell_hyperlink("Sheet1", "A1"),
    content=(
      #|Some(
      #|  {
      #|    reference: "A1",
      #|    target: "https://example.com",
      #|    link_type: External,
      #|    location: None,
      #|    display: Some("Example"),
      #|    tooltip: Some("Tip"),
      #|  },
      #|)
    ),
  )
  debug_inspect(
    parsed.get_cell_hyperlink("Sheet1", "B2"),
    content=(
      #|Some(
      #|  {
      #|    reference: "B2",
      #|    target: "Sheet1!C3",
      #|    link_type: Location,
      #|    location: Some("Sheet1!C3"),
      #|    display: None,
      #|    tooltip: None,
      #|  },
      #|)
    ),
  )
}

///|
test "hyperlink resolves merged cell anchor" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.merge_cells("A1:C3")
  sheet.set_cell_hyperlink("B2", "https://example.com", External)
  debug_inspect(
    sheet.get_cell_hyperlink("A1"),
    content=(
      #|Some(
      #|  {
      #|    reference: "A1",
      #|    target: "https://example.com",
      #|    link_type: External,
      #|    location: None,
      #|    display: None,
      #|    tooltip: None,
      #|  },
      #|)
    ),
  )
  debug_inspect(sheet.get_cell_hyperlink("B2"), content="None")
}

///|
test "hyperlink remove keeps other links" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_hyperlink("A1", "https://a.example", External)
  sheet.set_cell_hyperlink("B2", "https://b.example", External)
  sheet.remove_cell_hyperlink("A1")
  debug_inspect(sheet.get_cell_hyperlink("A1"), content="None")
  debug_inspect(
    sheet.get_cell_hyperlink("B2"),
    content=(
      #|Some(
      #|  {
      #|    reference: "B2",
      #|    target: "https://b.example",
      #|    link_type: External,
      #|    location: None,
      #|    display: None,
      #|    tooltip: None,
      #|  },
      #|)
    ),
  )
}

///|
test "hyperlink updates on insert" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink("Sheet1", "B2", "https://example.com", External)
  workbook.insert_rows("Sheet1", 1, 1)
  debug_inspect(workbook.get_cell_hyperlink("Sheet1", "B2"), content="None")
  debug_inspect(
    workbook.get_cell_hyperlink("Sheet1", "B3"),
    content=(
      #|Some(
      #|  {
      #|    reference: "B3",
      #|    target: "https://example.com",
      #|    link_type: External,
      #|    location: None,
      #|    display: None,
      #|    tooltip: None,
      #|  },
      #|)
    ),
  )
  workbook.insert_cols("Sheet1", 1, 1)
  debug_inspect(workbook.get_cell_hyperlink("Sheet1", "B3"), content="None")
  debug_inspect(
    workbook.get_cell_hyperlink("Sheet1", "C3"),
    content=(
      #|Some(
      #|  {
      #|    reference: "C3",
      #|    target: "https://example.com",
      #|    link_type: External,
      #|    location: None,
      #|    display: None,
      #|    tooltip: None,
      #|  },
      #|)
    ),
  )
}

///|
test "hyperlink alias methods" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyper_link("Sheet1", "C3", "https://example.com", External)
  debug_inspect(
    workbook.get_cell_hyper_link("Sheet1", "C3"),
    content=(
      #|Some(
      #|  {
      #|    reference: "C3",
      #|    target: "https://example.com",
      #|    link_type: External,
      #|    location: None,
      #|    display: None,
      #|    tooltip: None,
      #|  },
      #|)
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
    External,
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
  debug_inspect(
    parsed.get_cell_hyperlink("Sheet1", "A1"),
    content=(
      #|Some(
      #|  {
      #|    reference: "A1",
      #|    target: "https://example.com",
      #|    link_type: External,
      #|    location: None,
      #|    display: None,
      #|    tooltip: Some("Tip"),
      #|  },
      #|)
    ),
  )
}

///|
test "hyperlink opts helper (display only)" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = HyperlinkOpts::with_values(display="Shown")
  workbook.set_cell_hyperlink_opts(
    "Sheet1",
    "A1",
    "https://example.com",
    External,
    opts~,
  )
  let parsed = read(write(workbook))
  debug_inspect(
    parsed.get_cell_hyperlink("Sheet1", "A1"),
    content=(
      #|Some(
      #|  {
      #|    reference: "A1",
      #|    target: "https://example.com",
      #|    link_type: External,
      #|    location: None,
      #|    display: Some("Shown"),
      #|    tooltip: None,
      #|  },
      #|)
    ),
  )
}

///|
test "hyperlink update existing reference" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink("Sheet1", "A1", "https://github.com", External)
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://github.com/xuri/excelize",
    External,
  )
  debug_inspect(
    workbook.get_cell_hyperlink("Sheet1", "A1"),
    content=(
      #|Some(
      #|  {
      #|    reference: "A1",
      #|    target: "https://github.com/xuri/excelize",
      #|    link_type: External,
      #|    location: None,
      #|    display: None,
      #|    tooltip: None,
      #|  },
      #|)
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
    External,
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
    External,
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
    if entry.name() != "xl/worksheets/sheet1.xml" {
      updated_archive.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
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
  debug_inspect(
    parsed.get_cell_hyperlink("Sheet1", "B2"),
    content=(
      #|Some(
      #|  {
      #|    reference: "A1:D4",
      #|    target: "https://github.com/xuri/excelize",
      #|    link_type: External,
      #|    location: None,
      #|    display: None,
      #|    tooltip: None,
      #|  },
      #|)
    ),
  )
  parsed.remove_cell_hyperlink("Sheet1", "B2")
  debug_inspect(parsed.get_cell_hyperlink("Sheet1", "B2"), content="None")
  debug_inspect(parsed.get_cell_hyperlink("Sheet1", "A1"), content="None")
}

///|
test "hyperlink invalid ref tolerated on read" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://github.com/xuri/excelize",
    External,
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
    if entry.name() != "xl/worksheets/sheet1.xml" {
      updated_archive.add(
        entry.name(),
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
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
    Unset,
  )
  inspect(remove_result is Err(XlsxError::InvalidCellRef(_)), content="true")
}

///|
test "get_hyperlink_cells filters by link type" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://example.com",
    @xlsx.HyperlinkType::External,
  )
  workbook.set_cell_hyperlink(
    "Sheet1",
    "B2",
    "https://example.org",
    @xlsx.HyperlinkType::External,
  )
  workbook.set_cell_hyperlink(
    "Sheet1",
    "C3",
    "Sheet1!D4",
    @xlsx.HyperlinkType::Location,
  )
  debug_inspect(
    workbook.get_hyperlink_cells("Sheet1"),
    content=(
      #|["A1", "B2", "C3"]
    ),
  )
  debug_inspect(
    workbook.get_hyperlink_cells(
      "Sheet1",
      link_type=@xlsx.HyperlinkType::External,
    ),
    content=(
      #|["A1", "B2"]
    ),
  )
  debug_inspect(
    workbook.get_hyperlink_cells(
      "Sheet1",
      link_type=@xlsx.HyperlinkType::Location,
    ),
    content=(
      #|["C3"]
    ),
  )
  debug_inspect(
    workbook.get_hyperlink_cells("Sheet1", link_type=@xlsx.HyperlinkType::Unset),
    content="[]",
  )
  debug_inspect(
    workbook.get_hyper_link_cells(
      "Sheet1",
      link_type=@xlsx.HyperlinkType::External,
    ),
    content=(
      #|["A1", "B2"]
    ),
  )
  let missing : Result[Array[String], Error] = try? workbook.get_hyperlink_cells(
    "Missing",
  )
  inspect(missing is Err(_), content="true")
}

///|
test "hyperlink with both r:id and location matches both filters" {
  // Build a workbook with an external hyperlink, then inject a location
  // attribute into the sheet XML the way another producer could
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://example.com",
    @xlsx.HyperlinkType::External,
  )
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes)
  let patched = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() == "xl/worksheets/sheet1.xml" {
      let xml = @encoding/utf8.decode(entry.data())
      let mutated = xml.replace(
        old="<hyperlink ref=\"A1\"",
        new="<hyperlink ref=\"A1\" location=\"Sheet1!B2\"",
      )
      patched.add(entry.name(), @encoding/utf8.encode(mutated))
    } else {
      patched.add(entry.name(), entry.data())
    }
  }
  let parsed = @xlsx.read(@zip.write(patched))
  let link = match parsed.get_cell_hyperlink("Sheet1", "A1") {
    Some(value) => value
    None => fail("missing hyperlink")
  }
  debug_inspect(link.link_type, content="External")
  debug_inspect(
    link.location,
    content=(
      #|Some("Sheet1!B2")
    ),
  )
  inspect(link.target, content="https://example.com")
  // Excelize filters by attribute presence independently
  debug_inspect(
    parsed.get_hyperlink_cells("Sheet1"),
    content=(
      #|["A1"]
    ),
  )
  debug_inspect(
    parsed.get_hyperlink_cells(
      "Sheet1",
      link_type=@xlsx.HyperlinkType::External,
    ),
    content=(
      #|["A1"]
    ),
  )
  debug_inspect(
    parsed.get_hyperlink_cells(
      "Sheet1",
      link_type=@xlsx.HyperlinkType::Location,
    ),
    content=(
      #|["A1"]
    ),
  )
  // and the location survives a write roundtrip
  let rewritten = @xlsx.read(@xlsx.write(parsed))
  let survived = match rewritten.get_cell_hyperlink("Sheet1", "A1") {
    Some(value) => value
    None => fail("missing rewritten hyperlink")
  }
  debug_inspect(
    survived.location,
    content=(
      #|Some("Sheet1!B2")
    ),
  )
  inspect(survived.target, content="https://example.com")
}
