///|
/// A format 12 (or `format` 13) cmap subtable of `groups` (start, end, first
/// glyph), declaring `declared` of them in `length` bytes.
fn truetype_format12_subtable_for_test(
  groups : ArrayView[(Int, Int, Int)],
  declared? : Int = groups.length(),
  length? : Int = 16 + groups.length() * 12,
  format? : Int = 12,
) -> Array[Int] {
  let output : Array[Int] = []
  truetype_push_u16_for_test(output, format)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u32_for_test(output, length)
  truetype_push_u32_for_test(output, 0)
  truetype_push_u32_for_test(output, declared)
  for group in groups {
    truetype_push_u32_for_test(output, group.0)
    truetype_push_u32_for_test(output, group.1)
    truetype_push_u32_for_test(output, group.2)
  }
  output
}

///|
test "pdf_truetype_cmap_glyphs reads format 12 groups, beyond the BMP too" {
  let font = truetype_cmap_font_for_test([
    (
      3,
      10,
      truetype_format12_subtable_for_test([
        (0x41, 0x42, 5),
        (0x1F600, 0x1F602, 40),
      ]),
    ),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 0x41, glyph_index: 5, },
    { codepoint: 0x42, glyph_index: 6, },
    { codepoint: 0x1F600, glyph_index: 40, },
    { codepoint: 0x1F601, glyph_index: 41, },
    { codepoint: 0x1F602, glyph_index: 42, },
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyph(font, 0x1F601), Some(41))
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyph(font, 0x1F603), None)
}

///|
test "pdf_truetype_cmap_glyphs merges format 12 with the BMP's format 4" {
  // a font's usual pair: (3, 1) format 4 for the BMP, (3, 10) format 12 for
  // everything; the later table's mappings replace the earlier's
  let font = truetype_cmap_font_for_test([
    (3, 1, truetype_format6_subtable_for_test(0x41, [7, 8])),
    (
      3,
      10,
      truetype_format12_subtable_for_test([
        (0x42, 0x42, 9),
        (0x20000, 0x20000, 10),
      ]),
    ),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 0x41, glyph_index: 7, },
    { codepoint: 0x42, glyph_index: 9, },
    { codepoint: 0x20000, glyph_index: 10, },
  ])
}

///|
test "pdf_truetype_cmap_glyphs passes over format 12 groups that are not in order" {
  let font = truetype_cmap_font_for_test([
    (
      3,
      10,
      truetype_format12_subtable_for_test(
        [
          (0x30, 0x31, 1),
          // overlapping the one before, and out of order
          (0x31, 0x40, 2),
          (0x10, 0x11, 3),
          // backwards; past the last codepoint; past the last glyph
          (0x50, 0x4F, 4),
          (0x10FFFF, 0x110000, 5),
          (0x60, 0x61, 0xFFFF),
          // the whole of Unicode again and again would take for ever
          (0, 0x10FFFF, 0),
          (0, 0x10FFFF, 0),
          (0x70, 0x70, 6),
        ],
        // (more declared than there are: only those there are read)
        declared=0x7FFFFFFF,
      ),
    ),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 0x30, glyph_index: 1, },
    { codepoint: 0x31, glyph_index: 2, },
    { codepoint: 0x70, glyph_index: 6, },
  ])
}

///|
test "pdf_truetype_cmap_glyphs reads a format 12 table cut short" {
  let font = truetype_cmap_font_for_test([
    (
      3,
      10,
      truetype_format12_subtable_for_test([(0x41, 0x42, 5), (0x50, 0x51, 9)]),
    ),
  ])
  // without its last group's last bytes, and without its group count
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font[:font.length() - 2]), [
    { codepoint: 0x41, glyph_index: 5, },
    { codepoint: 0x42, glyph_index: 6, },
  ])
  @test.assert_eq(
    @pdflite.pdf_truetype_cmap_glyphs(font[:font.length() - 26]),
    [],
  )
}

///|
test "pdf_truetype_cmap_glyphs reads format 12 groups within the table's length" {
  // two groups declared, in a table whose length has room for one: the
  // bytes after it are not its groups
  let font = truetype_cmap_font_for_test([
    (
      3,
      10,
      truetype_format12_subtable_for_test(
        [(0x41, 0x41, 5), (0x50, 0x50, 9)],
        length=28,
      ),
    ),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 0x41, glyph_index: 5, },
  ])
}

///|
test "pdf_truetype_cmap_glyphs reads format 13, each group one glyph" {
  let font = truetype_cmap_font_for_test([
    (
      3,
      10,
      truetype_format12_subtable_for_test(
        [(0x41, 0x42, 5), (0x1F600, 0x1F601, 0xFFFF)],
        format=13,
      ),
    ),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 0x41, glyph_index: 5, },
    { codepoint: 0x42, glyph_index: 5, },
    { codepoint: 0x1F600, glyph_index: 0xFFFF, },
    { codepoint: 0x1F601, glyph_index: 0xFFFF, },
  ])
}

///|
/// A format 10 cmap subtable: `glyphs` for the codepoints from `first`,
/// declaring `declared` of them.
fn truetype_format10_subtable_for_test(
  first : Int,
  glyphs : ArrayView[Int],
  declared? : Int = glyphs.length(),
) -> Array[Int] {
  let output : Array[Int] = []
  truetype_push_u16_for_test(output, 10)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u32_for_test(output, 20 + glyphs.length() * 2)
  truetype_push_u32_for_test(output, 0)
  truetype_push_u32_for_test(output, first)
  truetype_push_u32_for_test(output, declared)
  for glyph in glyphs {
    truetype_push_u16_for_test(output, glyph)
  }
  output
}

///|
test "pdf_truetype_cmap_glyphs reads format 10, a run of codepoints' glyphs" {
  let font = truetype_cmap_font_for_test([
    (3, 10, truetype_format10_subtable_for_test(0x1F600, [3, 4])),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 0x1F600, glyph_index: 3, },
    { codepoint: 0x1F601, glyph_index: 4, },
  ])
  // no more than there are, and none past the last codepoint
  let more = truetype_cmap_font_for_test([
    (
      3,
      10,
      truetype_format10_subtable_for_test(0x10FFFF, [3, 4], declared=0x7FFFFFFF),
    ),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(more), [
    { codepoint: 0x10FFFF, glyph_index: 3, },
  ])
}

///|
test "pdf_truetype_cmap_glyphs reads a cmap of tables without end to a bound" {
  // every table maps all of Unicode again: read for ever, tables enough
  // would take for ever. The reading stops once every codepoint has been
  // mapped a few times over.
  let all = truetype_format12_subtable_for_test([(0, 0x10FFFF, 1)], format=13)
  let font = truetype_cmap_font_for_test(Array::makei(20, i => (3, i, all)))
  let entries = @pdflite.pdf_truetype_cmap_glyphs(font)
  @test.assert_eq(entries.length(), 0x110000)
  @test.assert_eq(entries[0x10FFFF], { codepoint: 0x10FFFF, glyph_index: 1, })
}

///|
test "pdf_truetype_cmap_glyphs reads groups that map nothing to a bound too" {
  // records without end of groups that are passed over: looking at a group
  // is a step of the reading as mapping a codepoint is
  let nothing = truetype_format12_subtable_for_test(
    Array::make(4000, (0x50, 0x4F, 1)),
  )
  let font = truetype_cmap_font_for_test(
    [
      (3, 1, truetype_format6_subtable_for_test(0x41, [7])),
      ..Array::makei(3000, i => (3, i, nothing)),
      (3, 10, truetype_format6_subtable_for_test(0x42, [8])),
    ],
  )
  // 12 million groups to look at are past the budget: the last table is
  // not reached
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 0x41, glyph_index: 7, },
  ])
}
