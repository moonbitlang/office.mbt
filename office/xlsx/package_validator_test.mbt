///|
fn read_validator_archive(bytes : Bytes) -> @zip.Archive raise {
  @zip.read_limited(
    bytes,
    max_package_bytes=64 * 1024 * 1024,
    max_entries=4096,
    max_entry_uncompressed_bytes=32 * 1024 * 1024,
    max_total_uncompressed_bytes=128 * 1024 * 1024,
    max_total_preserved_source_bytes=64 * 1024 * 1024 + 65_535,
  )
}

///|
/// The exported package validator is the exact pre-commit mutation gate: it
/// accepts a workbook written by this library and reports bounded findings
/// for package-graph defects without weakening the parse.
test "package validator matches the mutation gate verdicts" {
  let workbook = @engine.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell("Sheet1", "A1", "hello")
  let bytes = @engine.write(workbook)
  let archive = read_validator_archive(bytes)
  let validator = @xlsx.package_validator()
  let clean = (validator.validate)(@office.DocumentFormat::Xlsx, bytes, archive)
  assert_true(clean is [])
  // an uncovered binary part is a package-graph defect the shared gate
  // reports as a bounded finding rather than a parse failure; the tampered
  // package is rebuilt at the byte level so the archive keeps read_limited
  // provenance (mutated archives are rejected outright by the gate)
  let rebuilt = @zip.read(bytes)
  rebuilt.add("xl/extra.bin", b"\x00\x01")
  let tampered_bytes = @zip.write(rebuilt)
  let tampered = read_validator_archive(tampered_bytes)
  let findings = (validator.validate)(
    @office.DocumentFormat::Xlsx,
    tampered_bytes,
    tampered,
  )
  assert_true(findings.length() > 0)
  assert_true(findings[0].code == "office.xlsx.package")
  // a non-XLSX candidate is rejected before any parsing
  let wrong = try {
    (validator.validate)(@office.DocumentFormat::Docx, bytes, archive) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(wrong)
}
