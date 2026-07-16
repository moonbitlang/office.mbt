///|
fn bounded_workbook_fixture() -> Bytes raise @xlsx.XlsxError {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "bounded")
  workbook.set_cell_float("Data", "B2", 42.0)
  @xlsx.write(workbook)
}

///|
fn bounded_fixture_archive(
  bytes : BytesView,
  max_entries? : Int = 8192,
  max_entry_uncompressed_bytes? : Int = 64 * 1024 * 1024,
  max_total_uncompressed_bytes? : Int = 256 * 1024 * 1024,
  max_total_preserved_source_bytes? : Int = 128 * 1024 * 1024 + 65_535,
) -> @zip.Archive raise @zip.ZipError {
  @zip.read_limited(
    bytes,
    max_package_bytes=128 * 1024 * 1024,
    max_entries~,
    max_entry_uncompressed_bytes~,
    max_total_uncompressed_bytes~,
    max_total_preserved_source_bytes~,
  )
}

///|
fn lying_deflate_package() -> Bytes raise {
  let archive = @zip.Archive::new()
  let data = Array::make(4096, b'A')
  archive.add("bomb.xml", Bytes::from_array(data), compression=Deflate)
  let raw = @zip.write(archive).to_array()
  let mut central = -1
  for index in 0..<(raw.length() - 3) {
    if raw[index] == b'P' &&
      raw[index + 1] == b'K' &&
      raw[index + 2] == 0x01 &&
      raw[index + 3] == 0x02 {
      central = index
      break
    }
  }
  if central < 0 {
    fail("missing central directory")
  }
  // Lie in both the local and central uncompressed-size declarations. The
  // inflater must still stop at its streaming ceiling before producing the
  // real 4 KiB payload.
  for offset in [22, central + 24] {
    raw[offset] = 16
    raw[offset + 1] = 0
    raw[offset + 2] = 0
    raw[offset + 3] = 0
  }
  Bytes::from_array(raw)
}

///|
test "bounded archive and byte reads produce equivalent workbooks" {
  let bytes = bounded_workbook_fixture()
  let from_bytes = @xlsx.read(bytes)
  let from_archive = @xlsx.read_bounded_archive(bounded_fixture_archive(bytes))
  debug_inspect(
    from_bytes.get_cell_value("Data", "A1"),
    content="Some(\"bounded\")",
  )
  debug_inspect(
    from_archive.get_cell_value("Data", "A1"),
    content="Some(\"bounded\")",
  )
  inspect(@xlsx.write(from_archive) == @xlsx.write(from_bytes), content="true")
}

///|
test "archive read rejects compatibility and constructed archives" {
  let bytes = bounded_workbook_fixture()
  for archive in [@zip.read(bytes), @zip.Archive::new()] {
    let result : Result[@xlsx.Workbook, Error] = Ok(
      @xlsx.read_bounded_archive(archive),
    ) catch {
      error => Err(error)
    }
    inspect(result is Err(@xlsx.UnboundedArchive), content="true")
  }
}

///|
test "archive read rejects looser bounded provenance" {
  let bytes = bounded_workbook_fixture()
  // The archive was allowed 8,193 entries, which is looser than the XLSX
  // default even though this particular fixture contains only a few parts.
  let archive = bounded_fixture_archive(bytes, max_entries=8193)
  let result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read_bounded_archive(archive),
  ) catch {
    error => Err(error)
  }
  inspect(result is Err(@xlsx.UnboundedArchive), content="true")
}

///|
test "archive mutation invalidates provenance without affecting its source" {
  let bytes = bounded_workbook_fixture()
  let source = bounded_fixture_archive(bytes)
  let changed = source.fork()
  assert_true(changed.replace("xl/workbook.xml", b"<workbook/>"))
  let changed_result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read_bounded_archive(changed),
  ) catch {
    error => Err(error)
  }
  inspect(changed_result is Err(@xlsx.UnboundedArchive), content="true")
  debug_inspect(
    @xlsx.read_bounded_archive(source).get_cell_value("Data", "A1"),
    content="Some(\"bounded\")",
  )
}

///|
test "byte read classifies package and inflation resource limits" {
  let bytes = bounded_workbook_fixture()
  let package_limits = @xlsx.ReadLimits::with_values(
    max_package_bytes=bytes.length() - 1,
  )
  let package_result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(bytes, limits=package_limits),
  ) catch {
    error => Err(error)
  }
  match package_result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="package_bytes")
      assert_eq(limit, bytes.length() - 1)
      assert_eq(actual, bytes.length())
    }
    _ => fail("expected package byte limit")
  }

  let inflation_limits = @xlsx.ReadLimits::with_values(
    max_entry_uncompressed_bytes=1,
    max_total_uncompressed_bytes=1,
    max_xml_part_bytes=1,
  )
  let inflation_result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(bytes, limits=inflation_limits),
  ) catch {
    error => Err(error)
  }
  match inflation_result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="entry_uncompressed_bytes")
      assert_eq(limit, 1)
      assert_true(actual > limit)
    }
    _ => fail("expected inflation limit")
  }
}

///|
test "byte read classifies entry-count, aggregate, and source-copy limits" {
  let bytes = bounded_workbook_fixture()
  let archive = @zip.read(bytes)
  let entries = archive.entries()
  let mut largest_entry = 0
  let mut aggregate = 0
  for entry in entries {
    let size = entry.data().length()
    if size > largest_entry {
      largest_entry = size
    }
    aggregate += size
  }
  assert_true(entries.length() > 1)
  assert_true(largest_entry > 0)
  assert_true(aggregate > largest_entry)

  let entry_count_limit = entries.length() - 1
  let entry_count_result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(
      bytes,
      limits=@xlsx.ReadLimits::with_values(
        max_archive_entries=entry_count_limit,
      ),
    ),
  ) catch {
    error => Err(error)
  }
  match entry_count_result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="entry_count")
      assert_eq(limit, entry_count_limit)
      assert_true(actual > limit)
    }
    _ => fail("expected entry-count limit")
  }

  let aggregate_limit = aggregate - 1
  let aggregate_result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(
      bytes,
      limits=@xlsx.ReadLimits::with_values(
        max_entry_uncompressed_bytes=largest_entry,
        max_total_uncompressed_bytes=aggregate_limit,
        max_xml_part_bytes=largest_entry,
      ),
    ),
  ) catch {
    error => Err(error)
  }
  match aggregate_result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="total_uncompressed_bytes")
      assert_eq(limit, aggregate_limit)
      assert_true(actual > limit)
    }
    _ => fail("expected aggregate inflation limit")
  }

  let source_copy_result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(
      bytes,
      limits=@xlsx.ReadLimits::with_values(max_total_preserved_source_bytes=1),
    ),
  ) catch {
    error => Err(error)
  }
  match source_copy_result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="total_preserved_source_bytes")
      assert_eq(limit, 1)
      assert_true(actual > limit)
    }
    _ => fail("expected preserved source-copy limit")
  }
}

///|
test "XLSX reads stop a deflate stream whose declarations lie" {
  let bytes = lying_deflate_package()
  let limits = @xlsx.ReadLimits::with_values(
    max_entry_uncompressed_bytes=32,
    max_total_uncompressed_bytes=32,
    max_xml_part_bytes=32,
  )
  let result : Result[@xlsx.Workbook, Error] = Ok(@xlsx.read(bytes, limits~)) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="entry_uncompressed_bytes")
      assert_eq(limit, 32)
      assert_eq(actual, 33)
    }
    _ => fail("expected streaming deflate limit")
  }
}

///|
test "archive read enforces XML limits after provenance verification" {
  let bytes = bounded_workbook_fixture()
  let limits = @xlsx.ReadLimits::with_values(max_xml_part_bytes=1)
  let result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read_bounded_archive(bounded_fixture_archive(bytes), limits~),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="xml_part_bytes")
      assert_eq(limit, 1)
      assert_true(actual > limit)
    }
    _ => fail("expected XML part limit")
  }
}

///|
test "logical XML limit follows a worksheet relationship with a non-XML suffix" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "logical XML")
  let source = @zip.read(@xlsx.write(workbook))
  let sheet_path = "xl/worksheets/sheet1.xml"
  let moved_sheet_path = "xl/worksheets/sheet1.dat"
  let sheet_bytes = match source.get(sheet_path) {
    Some(value) => value
    None => fail("missing source worksheet")
  }
  let sheet_xml = @encoding/utf8.decode(sheet_bytes) catch {
    _ => fail("worksheet is not UTF-8")
  }
  let mut xml_limit = 0
  for entry in source.entries() {
    if entry.name() != sheet_path && entry.data().length() > xml_limit {
      xml_limit = entry.data().length()
    }
  }
  xml_limit += 1
  let padded_sheet_xml = sheet_xml.replace_all(
    old="</worksheet>",
    new=" ".repeat(xml_limit + 1024) + "</worksheet>",
  )
  let padded_sheet = @encoding/utf8.encode(padded_sheet_xml)
  assert_true(padded_sheet.length() > xml_limit)
  let updated = @zip.Archive::new()
  for entry in source.entries() {
    if entry.name() == sheet_path ||
      entry.name() == "xl/_rels/workbook.xml.rels" ||
      entry.name() == "[Content_Types].xml" {
      continue
    }
    updated.add(entry.name(), entry.data())
  }
  let workbook_rels = match source.get("xl/_rels/workbook.xml.rels") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("workbook relationships are not UTF-8")
      }
    None => fail("missing workbook relationships")
  }
  let content_types = match source.get("[Content_Types].xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("content types are not UTF-8")
      }
    None => fail("missing content types")
  }
  updated.add(moved_sheet_path, padded_sheet)
  updated.add(
    "xl/_rels/workbook.xml.rels",
    @encoding/utf8.encode(
      workbook_rels.replace_all(
        old="worksheets/sheet1.xml",
        new="worksheets/sheet1.dat",
      ),
    ),
  )
  updated.add(
    "[Content_Types].xml",
    @encoding/utf8.encode(
      content_types.replace_all(
        old="/xl/worksheets/sheet1.xml",
        new="/xl/worksheets/sheet1.dat",
      ),
    ),
  )
  let result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(
      @zip.write(updated),
      limits=@xlsx.ReadLimits::with_values(max_xml_part_bytes=xml_limit),
    ),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="xml_part_bytes")
      assert_eq(limit, xml_limit)
      assert_eq(actual, padded_sheet.length())
    }
    _ => fail("expected logical XML part limit")
  }
}

///|
test "bounded XLSX reads reject a stored entry with a mismatched CRC" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "alpha")
  let source = @zip.read(@xlsx.write(workbook))
  let stored = @zip.Archive::new()
  for entry in source.entries() {
    stored.add(entry.name(), entry.data())
  }
  let stored_bytes = @zip.write(stored)
  let bytes = stored_bytes.to_array()
  let original : Bytes = b"alpha"
  let replacement : Bytes = b"bravo"
  let mut payload_at = -1
  for index in 0..<(bytes.length() - original.length()) {
    if Bytes::from_array(bytes[index:index + original.length()]) == original {
      payload_at = index
      break
    }
  }
  assert_true(payload_at >= 0)
  for index in 0..<replacement.length() {
    bytes[payload_at + index] = replacement[index]
  }
  let result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(Bytes::from_array(bytes)),
  ) catch {
    error => Err(error)
  }
  inspect(
    result is Err(@xlsx.InvalidPackage(msg="ZIP entry CRC mismatch")),
    content="true",
  )
}

///|
test "malformed ZIPs have a stable package classification" {
  let result : Result[@xlsx.Workbook, Error] = Ok(
    @xlsx.read(b"not a ZIP package"),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.InvalidPackage(msg~)) =>
      inspect(msg, content="unreadable ZIP package")
    _ => fail("expected stable invalid package error")
  }
}
