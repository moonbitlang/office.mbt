///|
fn replace_archive_part(
  data : BytesView,
  name : String,
  replacement : Bytes,
) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  let mut replaced = false
  for entry in source.entries() {
    let entry_data = if entry.name() == name {
      replaced = true
      replacement
    } else {
      entry.data()
    }
    result.add(
      entry.name(),
      entry_data,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  if !replaced {
    fail("test archive did not contain \{name}")
  }
  @zip.write(result)
}

///|
fn prepend_utf8_bom(data : BytesView) -> Bytes {
  let bytes : Array[Byte] = [0xef, 0xbb, 0xbf]
  for byte in data {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}

///|
fn corrupt_stored_payload(data : Bytes, payload : BytesView) -> Bytes raise {
  let bytes = data.to_array()
  let mut payload_at = -1
  for i in 0..<(bytes.length() - payload.length() + 1) {
    let mut matches = true
    for j in 0..<payload.length() {
      if bytes[i + j] != payload[j] {
        matches = false
        break
      }
    }
    if matches {
      payload_at = i
      break
    }
  }
  if payload_at < 0 {
    fail("test payload was not stored verbatim in the archive")
  }
  bytes[payload_at] = b'j'
  Bytes::from_array(bytes)
}

///|
fn relocate_xlsx_main_part(data : BytesView) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  for entry in source.entries() {
    let (name, entry_data) = match entry.name() {
      "xl/workbook.xml" => ("xl/customWorkbook.xml", entry.data())
      "xl/_rels/workbook.xml.rels" =>
        ("xl/_rels/customWorkbook.xml.rels", entry.data())
      "[Content_Types].xml" => {
        let text = @utf8.decode(entry.data(), ignore_bom=true)
        (
          entry.name(),
          @utf8.encode(
            text.replace(old="/xl/workbook.xml", new="/xl/customWorkbook.xml"),
          ),
        )
      }
      "_rels/.rels" => {
        let text = @utf8.decode(entry.data(), ignore_bom=true)
        (
          entry.name(),
          @utf8.encode(
            text.replace(
              old="Target=\"xl/workbook.xml\"",
              new="Target=\"xl/customWorkbook.xml\"",
            ),
          ),
        )
      }
      _ => (entry.name(), entry.data())
    }
    result.add(
      name,
      entry_data,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  @zip.write(result)
}

///|
fn misalign_docx_main_part(data : BytesView) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  for entry in source.entries() {
    let entry_data = if entry.name() == "_rels/.rels" {
      @utf8.encode(
        @utf8.decode(entry.data(), ignore_bom=true).replace(
          old="Target=\"word/document.xml\"",
          new="Target=\"custom/main.xml\"",
        ),
      )
    } else {
      entry.data()
    }
    result.add(
      entry.name(),
      entry_data,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
    if entry.name() == "word/document.xml" {
      result.add(
        "custom/main.xml",
        entry.data(),
        compression=entry.compression(),
        data_descriptor=entry.data_descriptor(),
      )
    }
  }
  @zip.write(result)
}

///|
test "detect_format identifies generated xlsx" {
  let workbook = @excel.new_file()
  let data = @excel.write(workbook)
  inspect(@office.detect_format("book.xlsx", data).name(), content="xlsx")
}

///|
test "detect_format follows a relocated XLSX workbook main part" {
  let relocated = relocate_xlsx_main_part(@excel.write(@excel.new_file()))
  inspect(@office.detect_format("book.xlsx", relocated).name(), content="xlsx")
}

///|
test "detect_format accepts a UTF-8 BOM in content types" {
  let data = @excel.write(@excel.new_file())
  let archive = @zip.read(data)
  let content_types = archive.get("[Content_Types].xml").unwrap()
  let with_bom = replace_archive_part(
    data,
    "[Content_Types].xml",
    prepend_utf8_bom(content_types),
  )
  inspect(@office.detect_format("book.xlsx", with_bom).name(), content="xlsx")
}

///|
test "detect_format requires the XLSX officeDocument relationship" {
  let data = @excel.write(@excel.new_file())
  let broken = replace_archive_part(
    data,
    "_rels/.rels",
    @utf8.encode(
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"></Relationships>",
    ),
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: XLSX root relationships do not declare an officeDocument relationship",
      )
  } noraise {
    _ => fail("expected missing officeDocument relationship")
  }
}

///|
test "detect_format requires an XLSX workbook main-part root" {
  let data = @excel.write(@excel.new_file())
  let broken = replace_archive_part(
    data,
    "xl/workbook.xml",
    @utf8.encode(
      "<notWorkbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"/>",
    ),
  )
  try @office.detect_format("book.xlsx", broken) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: XLSX main part root element is not workbook",
      )
  } noraise {
    _ => fail("expected invalid workbook root")
  }
}

///|
test "detect_format rejects CRC-corrupted XLSX entries" {
  let workbook = @excel.new_file()
  workbook.set_cell("Sheet1", "A1", "hello")
  let corrupted = corrupt_stored_payload(@excel.write(workbook), b"hello")
  try @office.detect_format("book.xlsx", corrupted) catch {
    err =>
      inspect(
        Show::to_string(err).contains(
          "entry data does not match its stored CRC-32",
        ),
        content="true",
      )
  } noraise {
    _ => fail("expected CRC mismatch")
  }
}

///|
test "detect_format identifies generated docx" {
  let data = @word.new_blank_docx()
  inspect(@office.detect_format("report.docx", data).name(), content="docx")
}

///|
test "detect_format binds the DOCX relationship to its declared main part" {
  let broken = misalign_docx_main_part(@word.new_blank_docx())
  try @office.detect_format("report.docx", broken) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: DOCX officeDocument relationship targets 'custom/main.xml', but content types declare 'word/document.xml'",
      )
  } noraise {
    _ => fail("expected DOCX main-part mismatch")
  }
}

///|
test "detect_format rejects extension and package mismatch" {
  let data = @word.new_blank_docx()
  try @office.detect_format("report.xlsx", data) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="file extension says xlsx, but package content is docx",
      )
  } noraise {
    _ => fail("expected format mismatch")
  }
}

///|
test "detect_format rejects unsupported extension before reading content" {
  try @office.detect_format("report.pdf", b"not a package") catch {
    err =>
      inspect(
        Show::to_string(err),
        content="unsupported file extension for 'report.pdf' (expected .xlsx or .docx)",
      )
  } noraise {
    _ => fail("expected unsupported extension")
  }
}

///|
test "detect_format rejects an invalid zip" {
  try @office.detect_format("report.docx", b"not a package") catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: archive is not a readable ZIP",
      )
  } noraise {
    _ => fail("expected invalid package")
  }
}

///|
test "detect_format does not accept a content-type marker in an XML comment" {
  let archive = @zip.Archive::new()
  archive.add(
    "[Content_Types].xml",
    @utf8.encode(
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><!-- application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml --></Types>",
    ),
  )
  let data = @zip.write(archive)
  try @office.detect_format("book.xlsx", data) catch {
    err =>
      inspect(
        Show::to_string(err),
        content="invalid Office package: content types do not declare an XLSX or DOCX main part",
      )
  } noraise {
    _ => fail("expected invalid package")
  }
}
