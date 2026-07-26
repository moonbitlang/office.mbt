///|
test "hyperlink roundtrip" {
  let workbook = @xlsx.Workbook::new()
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
  let parsed = @xlsx.read(@xlsx.write(workbook))
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
  let workbook = @xlsx.Workbook::new()
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
  debug_inspect(
    sheet.get_cell_hyperlink("B2"),
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
  sheet.remove_cell_hyperlink("C3")
  debug_inspect(sheet.get_cell_hyperlink("A1"), content="None")
  debug_inspect(sheet.get_cell_hyperlink("B2"), content="None")
}

///|
test "hyperlink created before merge moves to the merged anchor" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_hyperlink("B2", "https://before.example", External)
  sheet.merge_cells("A1:C3")
  inspect(sheet.get_hyperlinks().length(), content="1")
  inspect(sheet.get_hyperlinks()[0].reference, content="A1")
  debug_inspect(
    sheet.get_cell_hyperlink("A1").map(link => link.target),
    content="Some(\"https://before.example\")",
  )
  debug_inspect(
    sheet.get_cell_hyperlink("B2").map(link => link.target),
    content="Some(\"https://before.example\")",
  )
  sheet.set_cell_hyperlink("C3", "https://after.example", External)
  inspect(sheet.get_hyperlinks().length(), content="1")
  debug_inspect(
    sheet.get_cell_hyperlink("A1").map(link => link.target),
    content="Some(\"https://after.example\")",
  )
  sheet.remove_cell_hyperlink("B2")
  debug_inspect(sheet.get_cell_hyperlink("A1"), content="None")
}

///|
test "merge rejects conflicting hyperlink identities atomically" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_hyperlink("A1", "https://a.example", External)
  sheet.set_cell_hyperlink("B2", "https://b.example", External)
  let result : Result[Unit, Error] = Ok(sheet.merge_cells("A1:C3")) catch {
    error => Err(error)
  }
  inspect(
    result is Err(@xlsx.XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  inspect(sheet.merged_cells().length(), content="0")
  inspect(sheet.get_hyperlinks().length(), content="2")
  debug_inspect(
    sheet.get_cell_hyperlink("A1").map(link => link.target),
    content="Some(\"https://a.example\")",
  )
  debug_inspect(
    sheet.get_cell_hyperlink("B2").map(link => link.target),
    content="Some(\"https://b.example\")",
  )
}

///|
test "reader canonicalizes a merged non-anchor hyperlink identity" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_hyperlink("A1", "https://legacy.example", External)
  sheet.merge_cells("A1:C3")
  let archive = @zip.read(@xlsx.write(workbook))
  let patched = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() == "xl/worksheets/sheet1.xml" {
      let xml = @encoding/utf8.decode(entry.data())
      let mutated = xml.replace(
        old="<hyperlink ref=\"A1\"",
        new="<hyperlink ref=\"B2\"",
      )
      patched.add(entry.name(), @encoding/utf8.encode(mutated))
    } else {
      patched.add(entry.name(), entry.data())
    }
  }
  let parsed = @xlsx.read(@zip.write(patched))
  inspect(parsed.get_hyperlinks("Sheet1").length(), content="1")
  inspect(parsed.get_hyperlinks("Sheet1")[0].reference, content="A1")
  debug_inspect(
    parsed.get_cell_hyperlink("Sheet1", "B2").map(link => link.target),
    content="Some(\"https://legacy.example\")",
  )
  let rewritten = @xlsx.read(@xlsx.write(parsed))
  inspect(rewritten.get_hyperlinks("Sheet1")[0].reference, content="A1")
  parsed.remove_cell_hyperlink("Sheet1", "C3")
  inspect(parsed.get_hyperlinks("Sheet1").length(), content="0")
}

///|
test "reader rejects conflicting hyperlink identities in one merged range" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink("Sheet1", "A1", "https://a.example", External)
  workbook.set_cell_hyperlink("Sheet1", "B2", "https://b.example", External)
  let archive = @zip.read(@xlsx.write(workbook))
  let patched = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() == "xl/worksheets/sheet1.xml" {
      let xml = @encoding/utf8.decode(entry.data())
      let mutated = xml.replace(
        old="</sheetData>",
        new="</sheetData><mergeCells count=\"1\"><mergeCell ref=\"A1:C3\"/></mergeCells>",
      )
      patched.add(entry.name(), @encoding/utf8.encode(mutated))
    } else {
      patched.add(entry.name(), entry.data())
    }
  }
  let result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(@zip.write(patched)),
  ) catch {
    error => Err(error)
  }
  inspect(result is Err(@xlsx.XlsxError::InvalidXml(_)), content="true")
}

///|
test "hyperlink remove keeps other links" {
  let workbook = @xlsx.Workbook::new()
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
  let workbook = @xlsx.Workbook::new()
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
  let workbook = @xlsx.Workbook::new()
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
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = @xlsx.HyperlinkOpts::with_values(tooltip="Tip")
  workbook.set_cell_hyperlink_opts(
    "Sheet1",
    "A1",
    "https://example.com",
    External,
    opts~,
  )
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
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
  let parsed = @xlsx.read(bytes)
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
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let opts = @xlsx.HyperlinkOpts::with_values(display="Shown")
  workbook.set_cell_hyperlink_opts(
    "Sheet1",
    "A1",
    "https://example.com",
    External,
    opts~,
  )
  let parsed = @xlsx.read(@xlsx.write(workbook))
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
  let workbook = @xlsx.Workbook::new()
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
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let set_result : Result[Unit, Error] = Ok(
    workbook.set_cell_hyperlink("Sheet1", "", "https://example.com", External),
  ) catch {
    e => Err(e)
  }
  inspect(set_result is Err(@xlsx.XlsxError::InvalidCellRef(_)), content="true")
  let get_result : Result[@xlsx.Hyperlink?, Error] = Ok(
    workbook.get_cell_hyperlink("Sheet1", ""),
  ) catch {
    e => Err(e)
  }
  inspect(get_result is Err(@xlsx.XlsxError::InvalidCellRef(_)), content="true")
  let remove_result : Result[Unit, Error] = Ok(
    workbook.remove_cell_hyperlink("Sheet1", ""),
  ) catch {
    e => Err(e)
  }
  inspect(
    remove_result is Err(@xlsx.XlsxError::InvalidCellRef(_)),
    content="true",
  )
}

///|
test "hyperlink relationship reader matches writer record and target boundaries" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  for index in 0..<16_385 {
    workbook.set_cell_hyperlink(
      "Sheet1",
      "A\{index + 1}",
      "https://example.test/\{index}",
      External,
    )
  }
  let long_target = "x".repeat(4097)
  workbook.set_cell_hyperlink("Sheet1", "B1", long_target, External)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  assert_eq(
    parsed.get_cell_hyperlink("Sheet1", "A16385").map(link => link.target),
    Some("https://example.test/16384"),
  )
  assert_eq(
    parsed.get_cell_hyperlink("Sheet1", "B1").map(link => link.target),
    Some(long_target),
  )
}

///|
test "hyperlink writer rejects targets that cannot fit the read policy" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  try
    workbook.set_cell_hyperlink(
      "Sheet1",
      "A1",
      "x".repeat(1024 * 1024 + 1),
      External,
    )
  catch {
    InvalidHyperlink(msg~) =>
      inspect(msg, content="hyperlink target is too long")
    _ => fail("unexpected hyperlink target error")
  } noraise {
    _ => fail("expected hyperlink target limit")
  }
}

///|
test "hyperlink remove clears range reference" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://github.com/xuri/excelize",
    External,
  )
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
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
    err => fail("zip write failed: \{repr(err)}")
  }
  let parsed = @xlsx.read(updated_bytes)
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
test "hyperlink invalid ref rejected on read" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://github.com/xuri/excelize",
    External,
  )
  let bytes = @xlsx.write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{repr(err)}")
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
    err => fail("zip write failed: \{repr(err)}")
  }
  let result : Result[@xlsx.Workbook, Error] = Ok(@xlsx.read(updated_bytes)) catch {
    error => Err(error)
  }
  inspect(result is Err(@xlsx.XlsxError::InvalidXml(_)), content="true")
}

///|
test "get_hyperlink_cells filters by link type" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink("Sheet1", "A1", "https://example.com", External)
  workbook.set_cell_hyperlink("Sheet1", "B2", "https://example.org", External)
  workbook.set_cell_hyperlink("Sheet1", "C3", "Sheet1!D4", Location)
  debug_inspect(
    workbook.get_hyperlink_cells("Sheet1"),
    content=(
      #|["A1", "B2", "C3"]
    ),
  )
  debug_inspect(
    workbook.get_hyperlink_cells("Sheet1", link_type=External),
    content=(
      #|["A1", "B2"]
    ),
  )
  debug_inspect(
    workbook.get_hyperlink_cells("Sheet1", link_type=Location),
    content=(
      #|["C3"]
    ),
  )
  debug_inspect(
    workbook.get_hyperlink_cells("Sheet1", link_type=Unset),
    content="[]",
  )
  debug_inspect(
    workbook.get_hyper_link_cells("Sheet1", link_type=External),
    content=(
      #|["A1", "B2"]
    ),
  )
  let missing : Result[Array[String], Error] = Ok(
    workbook.get_hyperlink_cells("Missing"),
  ) catch {
    e => Err(e)
  }
  inspect(missing is Err(_), content="true")
}

///|
test "typed hyperlink enumeration returns full filtered records" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink(
    "Sheet1",
    "A1",
    "https://example.com",
    External,
    display="Example",
    tooltip="Open example",
  )
  workbook.set_cell_hyperlink("Sheet1", "B2", "Sheet1!D4", Location)
  let all = workbook.get_hyperlinks("Sheet1")
  inspect(all.length(), content="2")
  inspect(all[0].reference, content="A1")
  inspect(all[0].target, content="https://example.com")
  debug_inspect(
    all[0].display,
    content=(
      #|Some("Example")
    ),
  )
  debug_inspect(
    all[0].tooltip,
    content=(
      #|Some("Open example")
    ),
  )
  inspect(all[1].reference, content="B2")
  debug_inspect(all[1].link_type, content="Location")
  let external = workbook.get_hyperlinks("Sheet1", link_type=External)
  inspect(external.length(), content="1")
  inspect(external[0].reference, content="A1")
  let locations = workbook.get_hyperlinks("Sheet1", link_type=Location)
  inspect(locations.length(), content="1")
  inspect(locations[0].reference, content="B2")
  inspect(
    workbook.get_hyperlinks("Sheet1", link_type=Unset).length(),
    content="0",
  )
  let missing : Result[Array[@xlsx.Hyperlink], Error] = Ok(
    workbook.get_hyperlinks("Missing"),
  ) catch {
    error => Err(error)
  }
  inspect(missing is Err(@xlsx.XlsxError::SheetNotFound(_)), content="true")
}

///|
test "hyperlink mutation accepts the Office-safe external scheme set" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let targets = [
    "http://example.com", "https://example.com", "mailto:person@example.com", "ftp://example.com/file",
    "ftps://example.com/file", "sftp://example.com/file", "news:comp.lang.moonbit",
    "tel:+123456", "sms:+123456", "file:///tmp/workbook.xlsx", "about:blank", "ppaction://hlinkshowjump?jump=nextslide",
    "relative/path/workbook.xlsx",
  ]
  for index, target in targets {
    sheet.set_cell_hyperlink("A\{index + 1}", target, External)
    let probe = @xlsx.Workbook::new()
    let probe_sheet = probe.add_sheet("Sheet1")
    probe_sheet.set_cell_hyperlink("A1", target, External)
    let parsed_probe = @xlsx.read(@xlsx.write(probe)) catch {
      error => fail("\{target}: safe target roundtrip failed: \{repr(error)}")
    }
    guard parsed_probe.get_cell_hyperlink("Sheet1", "A1") is Some(link) else {
      fail("\{target}: safe target disappeared after roundtrip")
    }
    if link.target != target {
      fail("\{target}: safe target changed after roundtrip to \{link.target}")
    }
  }
  inspect(sheet.get_hyperlinks().length(), content="13")
  let parsed = @xlsx.read(@xlsx.write(workbook)) catch {
    error => fail("combined safe target roundtrip failed: \{repr(error)}")
  }
  inspect(parsed.get_hyperlinks("Sheet1").length(), content="13")
  debug_inspect(
    parsed.get_cell_hyperlink("Sheet1", "A13").map(link => link.target),
    content=(
      #|Some("relative/path/workbook.xlsx")
    ),
  )
}

///|
test "hyperlink mutation rejects empty and unsafe targets atomically" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_hyperlink("A1", "https://before.example", External)
  let rejected : Array[(String, String, @xlsx.HyperlinkType)] = [
    ("empty", "", External),
    ("whitespace", " \t\r\n", External),
    ("javascript", "javascript:alert(1)", External),
    ("data", "DATA:text/html,bad", External),
    ("vbscript", "vbscript:msgbox(1)", External),
    ("unknown", "custom-scheme:value", External),
    ("one-letter unknown", "x:value", External),
    ("malformed authority", "https://[broken", External),
    ("malformed percent escape", "https://host/%GG", External),
    ("malformed port", "https://[::1]:port/path", External),
    ("control in scheme", "java\tscript:alert(1)", External),
    ("backslash path", "C:\\workbooks\\book.xlsx", External),
    ("location URI", "https://example.com", Location),
  ]
  for rejected_case in rejected {
    let (label, target, link_type) = rejected_case
    let result : Result[Unit, Error] = Ok(
      sheet.set_cell_hyperlink("A1", target, link_type),
    ) catch {
      error => Err(error)
    }
    if !(result is Err(@xlsx.XlsxError::InvalidHyperlink(_))) {
      fail("\{label}: expected InvalidHyperlink")
    }
    guard sheet.get_cell_hyperlink("A1") is Some(existing) else {
      fail("\{label}: existing hyperlink disappeared")
    }
    if existing.target != "https://before.example" {
      fail("\{label}: existing hyperlink changed")
    }
  }
  let empty_location : Result[Unit, Error] = Ok(
    sheet.set_cell_hyperlink("B2", " ", Location),
  ) catch {
    error => Err(error)
  }
  inspect(
    empty_location is Err(@xlsx.XlsxError::InvalidHyperlink(_)),
    content="true",
  )
  inspect(sheet.get_hyperlinks().length(), content="1")
}

///|
test "location hyperlink accepts unqualified A1 ranges" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let targets = ["A1:B2", "A:A", "$A$1:$B$2", "$A:$B"]
  for index, target in targets {
    workbook.set_cell_hyperlink("Sheet1", "A\{index + 1}", target, Location)
  }
  let parsed = @xlsx.read(@xlsx.write(workbook))
  for index, target in targets {
    debug_inspect(
      parsed
      .get_cell_hyperlink("Sheet1", "A\{index + 1}")
      .map(link => link.target),
      content="Some(\"\{target}\")",
    )
  }
}

///|
test "hyperlink mutation rejects XML-illegal text before mutation" {
  let sheet = @xlsx.Worksheet::new("Sheet1")
  let control = String::from_array([Int::unsafe_to_char(1)])
  let cases : Array[(String, String, String, String)] = [
    ("target", "https://example.com/\{control}", "", ""),
    ("display", "https://example.com", "bad\{control}", ""),
    ("tooltip", "https://example.com", "", "bad\{control}"),
  ]
  for invalid_case in cases {
    let (label, target, display, tooltip) = invalid_case
    let result : Result[Unit, Error] = Ok(
      sheet.set_cell_hyperlink("A1", target, External, display~, tooltip~),
    ) catch {
      error => Err(error)
    }
    if !(result is Err(@xlsx.XlsxError::InvalidHyperlink(_))) {
      fail("\{label}: expected InvalidHyperlink")
    }
  }
  inspect(sheet.get_hyperlinks().length(), content="0")
}

///|
test "hyperlink with both r:id and location matches both filters" {
  // Build a workbook with an external hyperlink, then inject a location
  // attribute into the sheet XML the way another producer could
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_hyperlink("Sheet1", "A1", "https://example.com", External)
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
    parsed.get_hyperlink_cells("Sheet1", link_type=External),
    content=(
      #|["A1"]
    ),
  )
  debug_inspect(
    parsed.get_hyperlink_cells("Sheet1", link_type=Location),
    content=(
      #|["A1"]
    ),
  )
  inspect(
    parsed.get_hyperlinks("Sheet1", link_type=External).length(),
    content="1",
  )
  inspect(
    parsed.get_hyperlinks("Sheet1", link_type=Location).length(),
    content="1",
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
