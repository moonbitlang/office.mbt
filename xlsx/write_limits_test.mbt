///|
fn write_limit_fixture() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "bounded write")
  workbook.set_cell_formula("Data", "B1", "=LEN(A1)")
  workbook
}

///|
test "bounded writes reject aggregate archive growth before ZIP output" {
  let workbook = write_limit_fixture()
  let ordinary = @xlsx.write(workbook)
  let archive = @zip.read(ordinary)
  let mut largest = 0
  let mut total = 0
  for entry in archive.entries() {
    let size = entry.data().length()
    if size > largest {
      largest = size
    }
    total = total + size
  }
  assert_true(total > largest)
  let result : Result[Bytes, Error] = Ok(
    @xlsx.write_limited(
      workbook,
      @xlsx.WriteLimits::with_values(
        max_output_bytes=ordinary.length() + 1024,
        max_archive_entries=archive.entries().length(),
        max_entry_uncompressed_bytes=largest,
        max_total_uncompressed_bytes=total - 1,
      ),
    ),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="total_uncompressed_bytes")
      assert_eq(limit, total - 1)
      assert_true(actual > limit)
    }
    _ => fail("expected aggregate bounded-write rejection")
  }
}

///|
test "bounded writes size ZIP output before allocating an oversized package" {
  let workbook = write_limit_fixture()
  let ordinary = @xlsx.write(workbook)
  let archive = @zip.read(ordinary)
  let mut largest = 0
  let mut total = 0
  for entry in archive.entries() {
    let size = entry.data().length()
    if size > largest {
      largest = size
    }
    total = total + size
  }
  let result : Result[Bytes, Error] = Ok(
    @xlsx.write_limited(
      workbook,
      @xlsx.WriteLimits::with_values(
        max_output_bytes=ordinary.length() - 1,
        max_archive_entries=archive.entries().length(),
        max_entry_uncompressed_bytes=largest,
        max_total_uncompressed_bytes=total,
      ),
    ),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="output_bytes")
      assert_eq(limit, ordinary.length() - 1)
      assert_true(actual > limit)
    }
    _ => fail("expected bounded ZIP output rejection")
  }
}
