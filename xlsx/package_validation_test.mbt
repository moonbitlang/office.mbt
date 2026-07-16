///|
test "validate_ooxml_package accepts a well-formed workbook" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", String("hello"))
  sheet.set_cell_value("B2", Numeric(42.0))
  let problems = @xlsx.validate_ooxml_package(@xlsx.write(workbook))
  debug_inspect(
    problems,
    content=(
      #|[]
    ),
  )
}

///|
test "validate_ooxml_package flags a missing relationship target" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  // drop xl/workbook.xml so the root rels target dangles
  let archive = @zip.read(@xlsx.write(workbook))
  let broken = @zip.Archive::new()
  for entry in archive.entries() {
    if entry.name() != "xl/workbook.xml" {
      broken.add(entry.name(), entry.data())
    }
  }
  let problems = @xlsx.validate_ooxml_package(@zip.write(broken))
  inspect(
    problems.iter().any(fn(p) { p.contains("missing required part") }),
    content="true",
  )
  inspect(
    problems.iter().any(fn(p) { p.contains("points to a missing part") }),
    content="true",
  )
}

///|
test "validate_ooxml_package flags an undeclared content type" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let archive = @zip.read(@xlsx.write(workbook))
  let broken = @zip.Archive::new()
  for entry in archive.entries() {
    broken.add(entry.name(), entry.data())
  }
  // add a part with an extension no Default/Override covers
  broken.add("xl/mystery.dat", b"\x00\x01\x02")
  let problems = @xlsx.validate_ooxml_package(@zip.write(broken))
  inspect(
    problems
    .iter()
    .any(fn(p) {
      p.contains("no declared content type") && p.contains("mystery.dat")
    }),
    content="true",
  )
}

///|
test "validate_ooxml_package flags a corrupt archive" {
  let problems = @xlsx.validate_ooxml_package(b"not a zip at all")
  inspect(
    problems.iter().any(fn(p) { p.contains("not a readable zip") }),
    content="true",
  )
}

///|
test "validate_ooxml_package classifies CRC corruption as unreadable" {
  let archive = @zip.Archive::new()
  archive.add("payload.bin", b"alpha")
  let bytes = @zip.write(archive).to_array()
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
  debug_inspect(
    @xlsx.validate_ooxml_package(Bytes::from_array(bytes)),
    content=(
      #|["archive is not a readable zip"]
    ),
  )
}

///|
test "OOXML validation reuses bounded archives and rejects unbounded ones" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let bytes = @xlsx.write(workbook)
  let limits = @xlsx.ReadLimits::new()
  let bounded = @zip.read_limited(
    bytes,
    max_package_bytes=limits.max_package_bytes(),
    max_entries=limits.max_archive_entries(),
    max_entry_uncompressed_bytes=limits.max_entry_uncompressed_bytes(),
    max_total_uncompressed_bytes=limits.max_total_uncompressed_bytes(),
    max_total_preserved_source_bytes=limits.max_total_preserved_source_bytes(),
  )
  debug_inspect(
    @xlsx.validate_ooxml_bounded_archive(bounded, limits~),
    content=(
      #|[]
    ),
  )
  let unbounded : Result[Array[String], Error] = Ok(
    @xlsx.validate_ooxml_bounded_archive(@zip.read(bytes)),
  ) catch {
    error => Err(error)
  }
  inspect(unbounded is Err(@xlsx.UnboundedArchive), content="true")
}

///|
test "OOXML validation applies XML limits before scanning relationships" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let limits = @xlsx.ReadLimits::with_values(max_xml_part_bytes=1)
  let result : Result[Array[String], Error] = Ok(
    @xlsx.validate_ooxml_package(@xlsx.write(workbook), limits~),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="xml_part_bytes")
      assert_eq(limit, 1)
      assert_true(actual > limit)
    }
    _ => fail("expected validation XML limit")
  }
}
