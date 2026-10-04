///|
/// A format 12 cmap subtable of `groups` (start, end, first glyph),
/// declaring `declared` of them.
fn truetype_format12_subtable_for_test(
  groups : ArrayView[(Int, Int, Int)],
  declared? : Int = groups.length(),
) -> Array[Int] {
  let output : Array[Int] = []
  truetype_push_u16_for_test(output, 12)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u32_for_test(output, 16 + groups.length() * 12)
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
