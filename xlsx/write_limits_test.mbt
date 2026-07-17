///|
fn write_limit_fixture() -> @xlsx.Workbook raise {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Data"))
  workbook.set_cell("Data", "A1", "bounded write")
  workbook.set_cell_formula("Data", "B1", "=LEN(A1)")
  workbook
}

///|
fn archive_uncompressed_stats(bytes : BytesView) -> (Int, Int, Int) raise {
  let archive = @zip.read(bytes)
  let mut largest = 0
  let mut total = 0
  for entry in archive.entries() {
    let size = entry.data().length()
    if size > largest {
      largest = size
    }
    total = total + size
  }
  (archive.entries().length(), largest, total)
}

///|
test "bounded writes reject aggregate archive growth before ZIP output" {
  let workbook = write_limit_fixture()
  let ordinary = @xlsx.write(workbook)
  let (entry_count, largest, total) = archive_uncompressed_stats(ordinary)
  assert_true(total > largest)
  let result : Result[Bytes, Error] = Ok(
    @xlsx.write_limited(
      workbook,
      @xlsx.WriteLimits::with_values(
        max_output_bytes=ordinary.length() + 1024,
        max_archive_entries=entry_count,
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
  let (entry_count, largest, total) = archive_uncompressed_stats(ordinary)
  let result : Result[Bytes, Error] = Ok(
    @xlsx.write_limited(
      workbook,
      @xlsx.WriteLimits::with_values(
        max_output_bytes=ordinary.length() - 1,
        max_archive_entries=entry_count,
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

///|
test "bounded writes stream escaped style attributes into the part budget" {
  let baseline = write_limit_fixture()
  let baseline_bytes = @xlsx.write(baseline)
  let (_, largest, total) = archive_uncompressed_stats(baseline_bytes)
  let workbook = write_limit_fixture()
  let style_id = workbook.add_style(
    @xlsx.Style::number_format("&".repeat(largest)),
  )
  workbook.set_cell_style("Data", "A1", style_id)
  let result : Result[Bytes, Error] = Ok(
    @xlsx.write_limited(
      workbook,
      @xlsx.WriteLimits::with_values(
        max_output_bytes=baseline_bytes.length() * 16,
        max_archive_entries=64,
        max_entry_uncompressed_bytes=largest + 1024,
        max_total_uncompressed_bytes=total * 16,
      ),
    ),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="entry_uncompressed_bytes")
      assert_eq(limit, largest + 1024)
      assert_true(actual > limit)
    }
    _ => fail("expected escaped style XML to honor the entry budget")
  }
}

///|
test "bounded writes preflight retained raw chart XML before UTF-8 encoding" {
  let baseline = write_limit_fixture()
  let baseline_bytes = @xlsx.write(baseline)
  let (_, largest, total) = archive_uncompressed_stats(baseline_bytes)
  let workbook = write_limit_fixture()
  workbook.add_chart(
    "Data",
    "C3",
    "<chart>" + "x".repeat(largest + 1024) + "</chart>",
  )
  let result : Result[Bytes, Error] = Ok(
    @xlsx.write_limited(
      workbook,
      @xlsx.WriteLimits::with_values(
        max_output_bytes=baseline_bytes.length() * 16,
        max_archive_entries=64,
        max_entry_uncompressed_bytes=largest + 512,
        max_total_uncompressed_bytes=total * 16,
      ),
    ),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@xlsx.ResourceLimitExceeded(kind~, limit~, actual~)) => {
      inspect(kind, content="entry_uncompressed_bytes")
      assert_eq(limit, largest + 512)
      assert_true(actual > limit)
    }
    _ => fail("expected raw chart XML to honor the entry budget")
  }
}
