///|
test "composition budget debits retained intermediates cumulatively" {
  let limits = WriteLimits::with_values(
    max_output_bytes=64,
    max_archive_entries=8,
    max_entry_uncompressed_bytes=8,
    max_total_uncompressed_bytes=12,
  )
  let tracker : WriteCompositionBudgetTracker = {
    limits: Some(limits),
    archived_bytes: 4,
    retained_bytes: 0,
  }
  tracker.consume("12345")
  let result : Result[Unit, Error] = Ok(tracker.consume("1234")) catch {
    error => Err(error)
  }
  match result {
    Err(ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="total_uncompressed_bytes")
      assert_eq(limit, 12)
      assert_true(actual > limit)
    }
    _ => fail("expected cumulative composition-budget rejection")
  }
}

///|
test "composition budget retains the individual entry ceiling" {
  let limits = WriteLimits::with_values(
    max_output_bytes=64,
    max_archive_entries=8,
    max_entry_uncompressed_bytes=8,
    max_total_uncompressed_bytes=32,
  )
  let tracker : WriteCompositionBudgetTracker = {
    limits: Some(limits),
    archived_bytes: 0,
    retained_bytes: 0,
  }
  let result : Result[Unit, Error] = Ok(tracker.consume("123456789")) catch {
    error => Err(error)
  }
  match result {
    Err(ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="entry_uncompressed_bytes")
      assert_eq(limit, 8)
      assert_true(actual > limit)
    }
    _ => fail("expected per-entry composition-budget rejection")
  }
}
