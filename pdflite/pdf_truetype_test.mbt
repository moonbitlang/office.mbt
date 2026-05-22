///|
fn truetype_bytes_for_test(values : Array[Int]) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for value in values {
    output.push(value.to_byte())
  }
  Bytes::from_array(output)
}

///|
fn truetype_push_u16_for_test(output : Array[Int], value : Int) -> Unit {
  output.push((value >> 8) & 0xFF)
  output.push(value & 0xFF)
}

///|
fn truetype_push_u32_for_test(output : Array[Int], value : Int) -> Unit {
  output.push((value >> 24) & 0xFF)
  output.push((value >> 16) & 0xFF)
  output.push((value >> 8) & 0xFF)
  output.push(value & 0xFF)
}

///|
fn truetype_append_for_test(
  output : Array[Int],
  values : ArrayView[Int],
) -> Unit {
  for value in values {
    output.push(value)
  }
}

///|
fn truetype_cmap_font_for_test(
  subtables : ArrayView[(Int, Int, Array[Int])],
) -> @pdflite.PdfBytes {
  let cmap_offset = 28
  let cmap_header_length = 4 + subtables.length() * 8
  let cmap : Array[Int] = []
  truetype_push_u16_for_test(cmap, 0)
  truetype_push_u16_for_test(cmap, subtables.length())
  let mut subtable_offset = cmap_header_length
  for record in subtables {
    let (platform_id, encoding_id, subtable) = record
    truetype_push_u16_for_test(cmap, platform_id)
    truetype_push_u16_for_test(cmap, encoding_id)
    truetype_push_u32_for_test(cmap, subtable_offset)
    subtable_offset += subtable.length()
  }
  for record in subtables {
    let (_, _, subtable) = record
    truetype_append_for_test(cmap, subtable)
  }

  let output : Array[Int] = []
  truetype_push_u32_for_test(output, 0x00010000)
  truetype_push_u16_for_test(output, 1)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 0)
  truetype_append_for_test(output, [0x63, 0x6D, 0x61, 0x70])
  truetype_push_u32_for_test(output, 0)
  truetype_push_u32_for_test(output, cmap_offset)
  truetype_push_u32_for_test(output, cmap.length())
  truetype_append_for_test(output, cmap)
  truetype_bytes_for_test(output)
}

///|
fn truetype_format6_subtable_for_test(
  first_code : Int,
  glyphs : ArrayView[Int],
) -> Array[Int] {
  let output : Array[Int] = []
  truetype_push_u16_for_test(output, 6)
  truetype_push_u16_for_test(output, 10 + glyphs.length() * 2)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, first_code)
  truetype_push_u16_for_test(output, glyphs.length())
  for glyph in glyphs {
    truetype_push_u16_for_test(output, glyph)
  }
  output
}

///|
fn truetype_format0_subtable_for_test(
  codepoint : Int,
  glyph : Int,
) -> Array[Int] {
  let output : Array[Int] = []
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 262)
  truetype_push_u16_for_test(output, 0)
  for index in 0..<256 {
    output.push(if index == codepoint { glyph } else { 0 })
  }
  output
}

///|
fn truetype_format4_range_offset_subtable_for_test() -> Array[Int] {
  let output : Array[Int] = []
  truetype_push_u16_for_test(output, 4)
  truetype_push_u16_for_test(output, 36)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 4)
  truetype_push_u16_for_test(output, 4)
  truetype_push_u16_for_test(output, 1)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 71)
  truetype_push_u16_for_test(output, 0xFFFF)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 70)
  truetype_push_u16_for_test(output, 0xFFFF)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 1)
  truetype_push_u16_for_test(output, 4)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 15)
  truetype_push_u16_for_test(output, 16)
  output
}

///|
test "pdf_truetype_cmaps returns cmap platform encoding pairs" {
  let font = truetype_bytes_for_test([
    0x00, 0x01, 0x00, 0x00, // scaler type
     0x00, 0x01, // numTables
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // search metadata
     0x63, 0x6D, 0x61, 0x70, // cmap
     0x00, 0x00, 0x00, 0x00, // checksum
     0x00, 0x00, 0x00, 0x1C, // offset
     0x00, 0x00, 0x00, 0x14, // length
     0x00, 0x00, // cmap version
     0x00, 0x02, // cmap records
     0x00, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x14,
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmaps(font), [(1, 0), (3, 1)])
}

///|
test "pdf_truetype_cmaps scans past non-cmap tables" {
  let font = truetype_bytes_for_test([
    0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x68,
    0x65, 0x61, 0x64, // head
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2C, 0x00, 0x00, 0x00, 0x00, 0x63,
    0x6D, 0x61, 0x70, // cmap
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2C, 0x00, 0x00, 0x00, 0x0C, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x03, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x0C,
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmaps(font), [(3, 10)])
}

///|
test "pdf_truetype_cmaps ignores malformed tails after complete records" {
  let font = truetype_bytes_for_test([
    0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x63,
    0x6D, 0x61, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1C, 0x00, 0x00,
    0x00, 0x14, 0x00, 0x00, 0x00, 0x02, 0x00, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x14, 0x00, 0x01, // truncated second record
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmaps(font), [(3, 1)])
  @test.assert_eq(
    @pdflite.pdf_truetype_cmaps(truetype_bytes_for_test([0x00])),
    [],
  )
}

///|
test "pdf_truetype_cmap_glyphs reads source-supported format 6 tables" {
  let font = truetype_cmap_font_for_test([
    (3, 1, truetype_format6_subtable_for_test(30, [7, 8, 9])),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 30, glyph_index: 7 },
    { codepoint: 31, glyph_index: 8 },
    { codepoint: 32, glyph_index: 9 },
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyph(font, 31), Some(8))
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyph(font, 99), None)
}

///|
test "pdf_truetype_cmap_glyphs reads format 4 range-offset glyph arrays" {
  let font = truetype_cmap_font_for_test([
    (3, 1, truetype_format4_range_offset_subtable_for_test()),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 70, glyph_index: 15 },
    { codepoint: 71, glyph_index: 16 },
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyph(font, 70), Some(15))
}

///|
test "pdf_truetype_cmap_glyphs mirrors source table replacement and no-cmap fallback" {
  let format0_font = truetype_cmap_font_for_test([
    (1, 0, truetype_format0_subtable_for_test(65, 9)),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyph(format0_font, 65), Some(9))

  let font = truetype_cmap_font_for_test([
    (3, 1, truetype_format6_subtable_for_test(65, [1])),
    (3, 10, truetype_format6_subtable_for_test(65, [2, 3])),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmaps(font), [(3, 10), (3, 1)])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 65, glyph_index: 2 },
    { codepoint: 66, glyph_index: 3 },
  ])
  @test.assert_eq(
    @pdflite.pdf_truetype_cmap_glyphs(
      truetype_bytes_for_test([
        0x00, 0x01, 0x00, 0x00, // scaler type
         0x00, 0x00, // no table records
         0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]),
    ).length(),
    256,
  )
  @test.assert_eq(
    @pdflite.pdf_truetype_cmap_glyph(
      truetype_bytes_for_test([
        0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]),
      200,
    ),
    Some(200),
  )
}
