///|
test "pdf_truetype_table_directory_search_fields follows OpenType" {
  // (numTables, (searchRange, entrySelector, rangeShift)); the old
  // `int(ln(searchRange / 16))` selector and `numTables * 16` shift were wrong
  // for every count but one
  debug_inspect(
    [1, 2, 3, 4, 5, 8, 9, 12, 16, 17, 32].map(count => {
      (count, pdf_truetype_table_directory_search_fields(count))
    }),
    content=(
      #|[
      #|  (1, (16, 0, 0)),
      #|  (2, (32, 1, 0)),
      #|  (3, (32, 1, 16)),
      #|  (4, (64, 2, 0)),
      #|  (5, (64, 2, 16)),
      #|  (8, (128, 3, 0)),
      #|  (9, (128, 3, 16)),
      #|  (12, (128, 3, 64)),
      #|  (16, (256, 4, 0)),
      #|  (17, (256, 4, 16)),
      #|  (32, (512, 5, 0)),
      #|]
    ),
  )
}

///|
test "pdf_truetype_table_directory_search_fields invariants" {
  for count in 1..<=300 {
    let (search_range, entry_selector, range_shift) = pdf_truetype_table_directory_search_fields(
      count,
    )
    // searchRange is the largest power of two times 16 not above count * 16
    @test.assert_eq(search_range, (1 << entry_selector) * 16)
    assert_true(search_range <= count * 16)
    assert_true(search_range * 2 > count * 16)
    @test.assert_eq(range_shift, count * 16 - search_range)
  }
}
