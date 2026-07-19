///|
fn bounded_invalid_xlsx_archive() -> @zip.Archive raise {
  let source = @zip.Archive::new()
  source.add("payload.bin", b"not an XLSX workbook")
  let limits = xlsx_read_limits()
  @zip.read_limited(
    @zip.write(source),
    max_package_bytes=limits.max_package_bytes(),
    max_entries=limits.max_archive_entries(),
    max_entry_uncompressed_bytes=limits.max_entry_uncompressed_bytes(),
    max_total_uncompressed_bytes=limits.max_total_uncompressed_bytes(),
    max_total_preserved_source_bytes=limits.max_total_preserved_source_bytes(),
  )
}

///|
test "candidate workbook read failures report the validation phase" {
  let result : Result[@engine.Workbook, Error] = Ok(
    read_transaction_workbook(
      bounded_invalid_xlsx_archive(),
      candidate_validation=true,
    ),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@transaction.TransactionError(code~, message~, details~)) => {
      assert_eq(code, "office.xlsx.candidate_invalid_package")
      assert_true(message.contains("candidate validation"))
      assert_true(details is None)
    }
    _ => fail("expected candidate-specific XLSX validation error")
  }
}

///|
test "source workbook read failures retain the source phase" {
  let result : Result[@engine.Workbook, Error] = Ok(
    read_transaction_workbook(bounded_invalid_xlsx_archive()),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@transaction.TransactionError(code~, message~, details~)) => {
      assert_eq(code, "office.xlsx.invalid_package")
      assert_true(message.contains("source parsing"))
      assert_true(details is None)
    }
    _ => fail("expected source-specific XLSX read error")
  }
}
