///|
/// A glyph whose header carries the bounding box `(x_min, y_min, x_max,
/// y_max)`: a one-contour simple glyph, or a composite one (`-1` contours)
/// with the given `(flags, glyph_index, extra_bytes)` components.
fn truetype_boxed_glyph_for_test(
  box : (Int, Int, Int, Int),
  components? : ArrayView[(Int, Int, Int)] = [],
) -> Array[Int] {
  let (x_min, y_min, x_max, y_max) = box
  let output : Array[Int] = []
  truetype_push_i16_for_test(output, if components.is_empty() { 1 } else { -1 })
  truetype_push_i16_for_test(output, x_min)
  truetype_push_i16_for_test(output, y_min)
  truetype_push_i16_for_test(output, x_max)
  truetype_push_i16_for_test(output, y_max)
  for component in components {
    let (flags, glyph_index, extra_bytes) = component
    truetype_push_u16_for_test(output, flags)
    truetype_push_u16_for_test(output, glyph_index)
    for _ in 0..<extra_bytes {
      output.push(0)
    }
  }
  output
}

///|
/// A font whose glyphs are: 0 `.notdef`, 1 `A` (simple), 2 `B` (a
/// composite of glyph 3, with a box of its own), 3 the component, 4 the
/// space, with no outline, and 5 a glyph no character maps to, with a box
/// larger than all the others. Its `head` box is the full font's.
fn truetype_head_bbox_font_for_test(notdef_outline~ : Bool) -> @core.PdfBytes {
  let (glyf, offsets) = truetype_glyf_table_for_test([
    if notdef_outline {
      truetype_boxed_glyph_for_test((50, 0, 450, 700))
    } else {
      []
    },
    truetype_boxed_glyph_for_test((-30, 0, 600, 650)),
    truetype_boxed_glyph_for_test((5, -100, 400, 800), components=[(0, 3, 2)]),
    truetype_boxed_glyph_for_test((0, -250, 100, 100)),
    [],
    truetype_boxed_glyph_for_test((-999, -999, 1999, 1999)),
  ])
  // codes 32 to 66: the space, then A and B
  let codes = Array::make(35, 0)
  codes[0] = 4
  codes[33] = 1
  codes[34] = 2
  truetype_table_font_for_test([
    ("head", truetype_head_table_for_test(1000, -999, -999, 1999, 1999, 1)),
    ("maxp", truetype_maxp_table_for_test(6)),
    (
      "cmap",
      truetype_cmap_table_for_test([
        (3, 1, truetype_format6_subtable_for_test(32, codes)),
      ]),
    ),
    ("loca", truetype_loca_long_table_for_test(offsets)),
    ("glyf", glyf),
  ])
}

///|
/// The `head` bounding box of a font, `(xMin, yMin, xMax, yMax)`.
fn truetype_head_bbox_for_test(font : BytesView) -> (Int, Int, Int, Int) {
  let head = @pdflite.pdf_truetype_table(font, "head").unwrap().offset
  let i16 = (at : Int) => {
    let value = (font[at].to_int() << 8) | font[at + 1].to_int()
    if value >= 0x8000 {
      value - 0x10000
    } else {
      value
    }
  }
  (i16(head + 36), i16(head + 38), i16(head + 40), i16(head + 42))
}

///|
/// The OpenType checksum of `length` bytes from `offset`, zero-padded to
/// whole 32-bit words.
fn truetype_checksum_for_test(
  font : BytesView,
  offset : Int,
  length : Int,
) -> UInt {
  let mut sum = 0U
  for word = offset; word < offset + length; word = word + 4 {
    let mut value = 0U
    for at in word..<(word + 4) {
      value = (value << 8) |
        (if at < offset + length { font[at].to_uint() } else { 0U })
    }
    sum = sum + value
  }
  sum
}

///|
/// Whether every directory checksum matches its table (the `head` table's
/// taken with `checkSumAdjustment` zero) and the whole font sums to
/// `0xB1B0AFBA`.
fn truetype_checksums_valid_for_test(font : BytesView) -> Bool {
  let head = @pdflite.pdf_truetype_table(font, "head").unwrap()
  let adjustment = truetype_checksum_for_test(font, head.offset + 8, 4)
  let tables_valid = @pdflite.pdf_truetype_tables(font)
    .iter()
    .all(record => {
      let sum = truetype_checksum_for_test(font, record.offset, record.length)
      record.checksum ==
      (if record.tag == "head" { sum - adjustment } else { sum })
    })
  tables_valid &&
  truetype_checksum_for_test(font, 0, font.length()) == 0xB1B0AFBAU
}

///|
test "pdf_truetype_subset_font keeps the source head by default" {
  let font = truetype_head_bbox_font_for_test(notdef_outline=true)
  let subset = try! @pdflite.pdf_truetype_subset_font(font, [65])
  @test.assert_eq(truetype_head_bbox_for_test(subset), (-999, -999, 1999, 1999))
}

///|
test "recompute_head unions the boxes of the kept glyphs" {
  let font = truetype_head_bbox_font_for_test(notdef_outline=true)
  // .notdef and A
  @test.assert_eq(
    truetype_head_bbox_for_test(
      try! @pdflite.pdf_truetype_subset_font(font, [65], recompute_head=true),
    ),
    (-30, 0, 600, 700),
  )
  // .notdef, the composite B with its own box, and its component
  @test.assert_eq(
    truetype_head_bbox_for_test(
      try! @pdflite.pdf_truetype_subset_font(font, [66], recompute_head=true),
    ),
    (0, -250, 450, 800),
  )
  // the space has no outline, so only .notdef counts
  @test.assert_eq(
    truetype_head_bbox_for_test(
      try! @pdflite.pdf_truetype_subset_font(font, [32], recompute_head=true),
    ),
    (50, 0, 450, 700),
  )
  // the rewritten cmap path keeps the same glyphs
  @test.assert_eq(
    truetype_head_bbox_for_test(
      try! @pdflite.pdf_truetype_subset_font(
        font,
        [65, 66],
        rewrite_cmap=true,
        recompute_head=true,
      ),
    ),
    (-30, -250, 600, 800),
  )
}

///|
test "recompute_head writes an all-zero box when no kept glyph has an outline" {
  let font = truetype_head_bbox_font_for_test(notdef_outline=false)
  let subset = try! @pdflite.pdf_truetype_subset_font(
    font,
    [32],
    recompute_head=true,
  )
  @test.assert_eq(truetype_head_bbox_for_test(subset), (0, 0, 0, 0))
  assert_true(truetype_checksums_valid_for_test(subset))
}

///|
test "recompute_head counts the stored box of a glyph with no contours" {
  // TTFunk 1.7.0 parity, unlike OpenType: only an empty loca range is
  // skipped, so a glyph with data but numberOfContours == 0 still counts
  let contourless : Array[Int] = []
  for value in [0, 10, 20, 30, 40] {
    truetype_push_i16_for_test(contourless, value)
  }
  // glyph 0 (.notdef) empty, glyph 1 the contourless glyph, mapped from `A`
  let (glyf, offsets) = truetype_glyf_table_for_test([[], contourless])
  let font = truetype_table_font_for_test([
    ("head", truetype_head_table_for_test(1000, -999, -999, 1999, 1999, 1)),
    ("maxp", truetype_maxp_table_for_test(2)),
    (
      "cmap",
      truetype_cmap_table_for_test([
        (3, 1, truetype_format6_subtable_for_test(65, [1])),
      ]),
    ),
    ("loca", truetype_loca_long_table_for_test(offsets)),
    ("glyf", glyf),
  ])
  let subset = try! @pdflite.pdf_truetype_subset_font(
    font,
    [65],
    recompute_head=true,
  )
  @test.assert_eq(truetype_head_bbox_for_test(subset), (10, 20, 30, 40))
  assert_true(truetype_checksums_valid_for_test(subset))
}

///|
test "recompute_head writes valid checksums and only changes the head" {
  let font = truetype_head_bbox_font_for_test(notdef_outline=true)
  let plain = try! @pdflite.pdf_truetype_subset_font(font, [65, 66])
  let subset = try! @pdflite.pdf_truetype_subset_font(
    font,
    [65, 66],
    recompute_head=true,
  )
  assert_false(truetype_checksums_valid_for_test(plain))
  assert_true(truetype_checksums_valid_for_test(subset))
  @test.assert_eq(subset.length(), plain.length())
  // the same tables at the same places; only checksums and head differ
  let plain_tables = @pdflite.pdf_truetype_tables(plain)
  let tables = @pdflite.pdf_truetype_tables(subset)
  @test.assert_eq(
    tables.map(record => (record.tag, record.offset, record.length)),
    plain_tables.map(record => (record.tag, record.offset, record.length)),
  )
  let head = @pdflite.pdf_truetype_table(subset, "head").unwrap()
  let differing : Array[Int] = []
  for at in (12 + tables.length() * 16)..<subset.length() {
    if subset[at] != plain[at] {
      differing.push(at - head.offset)
    }
  }
  // checkSumAdjustment and the box
  @test.assert_eq(differing.filter(at => !(at is (8..=11 | 36..=43))), [])
  @test.assert_eq(truetype_head_bbox_for_test(subset), (-30, -250, 600, 800))
  // the subset still maps and lays out its characters
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyph(subset, 66), Some(2))
}

///|
/// The `(sfntVersion, numTables, searchRange, entrySelector, rangeShift)`
/// fields of a font's 12-byte table directory header.
fn truetype_directory_header_for_test(
  font : BytesView,
) -> (UInt, Int, Int, Int, Int) {
  let u16 = (at : Int) => (font[at].to_int() << 8) | font[at + 1].to_int()
  let version = (u16(0).reinterpret_as_uint() << 16) |
    u16(2).reinterpret_as_uint()
  (version, u16(4), u16(6), u16(8), u16(10))
}

///|
test "subset fonts write OpenType table directory search fields" {
  let font = truetype_head_bbox_font_for_test(notdef_outline=true)
  let plain = try! @pdflite.pdf_truetype_subset_font(font, [65, 66])
  let recomputed = try! @pdflite.pdf_truetype_subset_font(
    font,
    [65, 66],
    recompute_head=true,
  )
  let implicit = try! @pdflite.pdf_truetype_subset_font(
    font,
    [65, 66],
    rewrite_cmap=true,
  )
  for subset in [plain, recomputed, implicit] {
    let (_, count, search_range, entry_selector, range_shift) = truetype_directory_header_for_test(
      subset,
    )
    @test.assert_eq(count, @pdflite.pdf_truetype_tables(subset).length())
    @test.assert_eq(search_range, (1 << entry_selector) * 16)
    assert_true(search_range <= count * 16 && search_range * 2 > count * 16)
    @test.assert_eq(range_shift, count * 16 - search_range)
  }
  debug_inspect(
    truetype_directory_header_for_test(recomputed),
    content=(
      #|(65536, 5, 64, 2, 16)
    ),
  )
}
